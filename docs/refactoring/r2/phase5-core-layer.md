# Phase 5 — `core/` 확립

> **상태**: 미시작
> **범위**: `lib/event`·`lib/common` 을 `core/event`·`core/util`·`core/logging` 로. `core/entities` 신설. IPC 3종(SysV 큐·Unix 소켓·TCP)을 `core/messaging` 으로 통일. `core/config` 신설.
> **선행**: [Phase 4](./phase4-platform-pc-emulator.md) — 에뮬레이터가 서서 이후 변경을 개발 PC 에서 판정할 수 있어야 한다.
> **후행**: [Phase 6](./phase6-feature-config-power-diagnostics.md) 이후 전부

---

## 1. 배경

### 1.1 `core` 는 인프라다 — moana(legacy r1)와 같은 원칙

[legacy/r1 Phase 3](../legacy/r1/phase3-core-layer.md) 의 발견을 반복한다: **`core` 는 도메인이 아니라 인프라·엔티티·공통 유틸리티다.** 도메인은 `features/*/domain` 에 있다(ipc-app ADR-002).

ipc-app `src/core/` 실측(71파일 6,064 LOC): `entities`(19파일 유형) · `db` · `log` · `codec` · `audio` · `services` · `util` · `widgets`.

### 1.2 belle-fw 의 `core` 후보

| 현행 | LOC | 목표 |
|---|---:|---|
| `lib/event.cpp` | 814 | `core/event` — **`EVENT_DATA_SCAN_MODE_CHANGE` 등 모드 전환 이벤트의 근거지**. [Phase 7](./phase7-feature-scan-split.md) 이 이것에 의존 |
| `lib/common.cpp`+`.h` | 633+598 | `core/util` |
| (신설) | — | `core/entities` — 프로브 스펙 · 스캔 파라미터 · 프레임 타입 |
| (신설) | — | `core/logging` — 현재 산재한 `DBG()`·로그 매크로 통합 |
| `bcd/` 일부 | — | `core/config` — 설정 저장 (feature 부분은 [Phase 6](./phase6-feature-config-power-diagnostics.md)) |

### 1.3 IPC 가 3종류 각각 다르다

| 프로세스 | IPC | 구현 |
|---|---|---|
| `sonon` | **TCP 2채널**(1234/1235) | 커스텀 바이너리 프레이밍 |
| `bcd` | **SysV 메시지 큐** | `msgget`/`msgsnd`/`msgrcv` |
| `deviced` | SysV 메시지 큐 | 〃 |
| `watchdogd` | **Unix 도메인 소켓** | |

**ipc-app `core/messaging` 하나로 통일된 것과 대조된다.** 이 phase 가 그 격차를 좁힌다 — 다만 **전송 방식 자체(SysV vs Unix소켓)를 통일하지는 않는다.** 4개 프로세스 경계를 유지하는 [principles.md §11](../legacy/principles.md)(healcerion 전체 원칙, r2 에도 적용)에 따라 **인터페이스만 통일하고 전송 프로토콜은 그대로 둔다.**

### 1.4 목적

1. `core/entities` — [Phase 9](./phase9-runtime-variant.md) 런타임 변종의 그릇을 미리 만든다
2. `lib/event`·`common` 이동
3. IPC 접근을 `core/messaging` 인터페이스로 통일(구현은 프로세스별 유지)
4. `core/config` — 설정 저장 인프라

### 1.5 범위 한계

- **IPC 전송 방식 자체를 바꾸지 않는다.** SysV 큐를 Unix 소켓으로 교체하지 않는다 — 그것은 별도 결정이고 여기 범위가 아니다
- `bcd` 의 feature 부분(설정 브로커 도메인 로직)은 [Phase 6-B](./phase6-feature-config-power-diagnostics.md)

---

## 2. 진행 단계

### Step 5-A. `lib/event` → `core/event`

| # | 작업 |
|---|---|
| A-1 | `event.cpp`(814) 이동. **`EVENT_DATA_SCAN_MODE_CHANGE`/`_ACK` 는 [Phase 7-A](./phase7-feature-scan-split.md) 모드 경계 복원의 재료**이므로 이름 그대로 보존 |
| A-2 | 이벤트 set/wait/clear API 를 `core/event/i_event_bus.h` 로 명시화(현재는 전역 함수 호출) |
| A-3 | 골든([Phase 1](./phase1-regression-baseline.md)) + PC 빌드([Phase 4](./phase4-platform-pc-emulator.md)) 확인 |

### Step 5-B. `lib/common` → `core/util` + `core/logging`

| # | 작업 |
|---|---|
| B-1 | 순수 유틸 함수 → `core/util` |
| B-2 | `DBG()` 등 로그 매크로 → `core/logging`. 산재한 로그 호출부 include 경로만 갱신(매크로 동작 불변) |

### Step 5-C. `core/entities` 신설

| # | 작업 |
|---|---|
| C-1 | 프로브 스펙 타입 정의 — [Phase 9](./phase9-runtime-variant.md) 가 채울 데이터의 스키마 |
| C-2 | 스캔 파라미터 타입 — depth·focal·PRF 등 |
| C-3 | 프레임 타입 — [Phase 4-B](./phase4-platform-pc-emulator.md) 에서 결정한 데이터 층위(RF/IQ)와 일치시킨다 |

> **이 phase 에서는 타입만 정의한다.** 실제 프로브 스펙 데이터 채우기는 [Phase 9](./phase9-runtime-variant.md).

### Step 5-D. IPC 통일 — `core/messaging`

| # | 작업 | 순서 이유 |
|---|---|---|
| D-1 | `core/messaging/i_message_queue.h` — SysV 큐 인터페이스 | `bcd`·`deviced` 가 먼저 |
| D-2 | `bcd` 의 큐 접근을 인터페이스 경유로 | 위험 낮음(설정 브로커) |
| D-3 | `deviced` 동일 | 〃 |
| D-4 | `core/messaging/i_unix_socket.h` — `watchdogd` | **마지막.** watchdogd 는 나머지 전부를 감시하므로 가장 신중히 |
| D-5 | `sonon` 의 TCP 채널은 **[Phase 0-D](./phase0-hygiene-protocol-sot.md) 의 HC 프로토콜 정본과 이미 분리 대상**이므로 여기서는 인터페이스 이름만 맞춘다(`i_tcp_channel.h`), 구현은 손대지 않음 |

**전송 방식은 그대로 두고 접근 인터페이스만 통일**하므로 동작 변경 위험이 낮다. (`watchdogd` 를 마지막에 두는 이유는 [principles.md §11](../legacy/principles.md)의 일반 원칙 — 지금 동작하는 것을 함부로 재배치하지 않는다.)

### Step 5-E. `core/config`

`bcd` 에서 순수 저장 계층(파일 I/O·직렬화)만 분리. 도메인 로직(무엇을 설정하는가)은 [Phase 6-B](./phase6-feature-config-power-diagnostics.md).

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | `core` 독립 빌드 | `core` 서브트리 단독 컴파일 | exit 0 |
| 3.2 | 계층 방향 | `core/** → features/\|app/\|platforms/` include | 0건 |
| 3.3 | IPC 동작 불변 | 4프로세스 간 통신 | 기존과 동일 |
| 3.4 | watchdogd 최종 검증 | 의도적 프로세스 크래시 → 감시·복구 | 정상 |
| 3.5 | PC/실장비 양쪽 빌드 | `make build TARGET=pc\|zynqmp` | 둘 다 exit 0 |
| 3.6 | **동작 불변** | `make test-golden` | 통과 |
| 3.7 | 계층 검사 | `make check-layers` | exit 0 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`watchdogd` 인터페이스 통일이 감시 로직을 깨뜨린다** | 프로세스 크래시 시 복구 실패 — **가장 심각한 회귀** | D-4 를 **마지막이자 별도 커밋**으로. 3.4 필수 검증. 실장비에서 의도적 크래시 테스트 |
| 이벤트 인터페이스 명시화가 타이밍을 바꾼다 | `EVENT_DATA_SCAN_MODE_CHANGE` 대기 로직 회귀 | A-2 는 **래핑만**, 세마포어·타임아웃 값 불변 확인 |
| `core/entities` 타입이 [Phase 4](./phase4-platform-pc-emulator.md) 의 데이터 층위 결정과 어긋난다 | 재작업 | C-3 에서 반드시 Phase 4 산출물 재확인 후 정의 |

---

## 5. cross-reference

- [plan.md §2.2·§4](./plan.md)
- [../legacy/r1/phase3-core-layer.md](../legacy/r1/phase3-core-layer.md) — moana 의 같은 성격 phase, `core` 정의 공유
- [phase7-feature-scan-split.md](./phase7-feature-scan-split.md) — `core/event` 를 모드 경계 복원에 사용
- [phase9-runtime-variant.md](./phase9-runtime-variant.md) — `core/entities` 를 채우는 phase
