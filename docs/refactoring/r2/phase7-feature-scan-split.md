# Phase 7 — `scan-b` · `doppler-cf` · `doppler-pw` · `mmode` · `scan-session` ★

> **상태**: 미시작
> **범위**: r2 최대 위험. `sonon_receive_fpga.cpp`(4,048) · `sonon_mode_change_proc.cpp`(879) · `sonon_pw_filter.cpp`(1,605) 외를 5개 feature 로.
> **선행**: [Phase 6](./phase6-feature-config-power-diagnostics.md) — 패턴이 서고 opcode 분류(§F-3)가 끝나야 한다.
> **후행**: [Phase 8](./phase8-feature-firmware-process.md) 과 병렬, [Phase 9](./phase9-runtime-variant.md)
> **feature 이름은 [legacy/r1](../legacy/r1/plan.md) 의 moana 와 공유하도록 잡았던 것**이다 — [architecture.md §5](../legacy/architecture.md). **미확인(2026-07-30)**: `moana` 폐기로 현재 client 트랙은 `sonex-framework`([r1](../r1/plan.md))이고, 이 이름 체계가 그쪽에도 적용되는지는 재확인 전이다 — [plan.md §2.4](./plan.md)

---

## 1. 배경

### 1.1 moana 와 결정적으로 다른 점 — 모드가 열거형이 아니다

[legacy/r1 Phase 8](../legacy/r1/phase8-feature-scan-split.md) 에서 moana 는 `SONON_SCAN_MODE` 열거형을 178곳에서 `switch` 했다. **belle-fw 에는 그 열거형이 없다.**

대신:

| 기전 | 위치 | 실측 |
|---|---|---|
| **이벤트 플래그** | `lib/fpga_define.h:363-364` | `EVENT_DATA_SCAN_MODE_CHANGE` / `_ACK` |
| **전환 상태머신** | `sonon/sonon_mode_change_proc.cpp` | **879 LOC** |
| **패킷 타입으로 모드 구분** | `sonon/sonon_receive.h` | `HER_PACKET_TYPE_{B_ONLY_SCAN_DATA 0x0100, B_C_SCANLINE_DATA 0x0101, B_C_FRAME_DATA 0x0102, PW_FRAME_DATA 0x0104, PW_AUDIO_FRAME_DATA 0x0104, M_FRAME_DATA 0x0106}` |

`sonon.cpp` 의 이벤트 흐름:

```
event_set_data(EVENT_DATA, EVENT_DATA_SCAN_MODE_CHANGE)   ← 모드 전환 요청
last_event = EVENT_DATA_SCAN_MODE_CHANGE
...
if (last_event & EVENT_DATA_SCAN_MODE_CHANGE) { ... }
event_set_data(EVENT_DATA, EVENT_DATA_SCAN_MODE_CHANGE_ACK)  ← 처리 완료
event_wait_clear_timeout(EVENT_DATA, EVENT_DATA_SCAN_MODE_CHANGE, 100)
```

**"모드" 가 데이터가 아니라 제어 흐름에 녹아 있다.** `grep 'PW_MODE'` 같은 기계적 분류가 통하지 않는다.

### 1.2 이 phase 의 절반은 "복원" 이다

**코드를 옮기기 전에 무엇이 어느 모드에 속하는지부터 알아내야 한다.** 이것이 §3 Step 7-A 이고, 산출물은 코드 이동이 아니라 **상태 전이도**다.

### 1.3 규모

| 파일 | LOC | 성격 |
|---|---:|---|
| `sonon_receive_fpga.cpp` | **4,048** | **모든 모드**의 FPGA 명령. 함수 **81개**. r2 최대 파일 |
| `sonon.cpp` | 3,522 | main + 스레드 5(`pthread_create` 13곳) + 소켓 + 상태 |
| `sonon_receive.h` | 2,227 | opcode 82개(이미 [Phase 0-D](./phase0-hygiene-protocol-sot.md)에서 정본화) |
| `sonon_receive_device.cpp` | 1,711 | 장치 명령(스캔 무관분은 [Phase 6-F](./phase6-feature-config-power-diagnostics.md)로 이미 나감) |
| `sonon_pw_filter.cpp` | 1,605 | **PW 필터** |
| `cf-doppler.c`(`lib/`) | 1,585 | **CF 신호처리**(NEON) |
| `fpga_pw.cpp`(`lib/`) | 1,672 | PW FPGA 명령([Phase 3](./phase3-platform-hal.md)에서 레지스터부만 이동됨) |
| `sonon_scanconversion.cpp` | 1,278 | 스캔 컨버전(공통) |
| `sonon_transmit.cpp` | 1,104 | **모든 모드**의 송신 |
| `sonon_pw_m_proc.cpp` | 977 | PW·M 처리 |
| `sonon_receive.cpp` | 950 | |
| `fpga_doppler.cpp`(`lib/`) | 879 | 도플러 FPGA 명령 |
| `sonon_mode_change_proc.cpp` | **879** | **모드 전환 상태머신** |
| `image_proc/b_sa.cpp` | 1,376 | B 합성개구 |
| `sonon_b_sa.cpp` | 358 | 〃 |
| `image_proc/b_conventional.cpp` | 671 | B 컨벤셔널 |
| `sonon_pw_filter.h` | 523 | |

**패킷 타입 실사용**: `B_ONLY_SCAN_DATA` 3파일 3곳 · `B_C_FRAME_DATA` 2/4 · `B_C_SCANLINE_DATA` 2/3 · `PW_FRAME_DATA` 2/3 · `M_FRAME_DATA` 2/3 — **적어서 오히려 흩어진 정도를 못 보여준다.** 실제 분기는 opcode 82개와 함수 81개 안에 녹아 있다.

### 1.4 신호처리와 하드웨어 접근이 [Phase 3](./phase3-platform-hal.md)에서 이미 부분 분리됐다

`fpga_pw.cpp`·`fpga_doppler.cpp` 는 [Phase 3-B3](./phase3-platform-hal.md)에서 **레지스터 쓰기 부분만** `platforms/zynqmp` 로 갔다. **계산 로직은 여기 남아 있다** — 이 phase 가 그것을 가져간다.

### 1.5 목적

1. **모드 경계 복원** — 상태 전이도(신규 산출물)
2. 5개 feature — `scan-session`(공통 상태머신) + 모드 4개
3. `sonon_receive_fpga.cpp` 4,048 LOC 를 opcode 별로 해체
4. **[legacy/r1 moana Phase 8](../legacy/r1/phase8-feature-scan-split.md) 과 같은 이름**으로 정합

### 1.6 범위 한계

- **신호처리 알고리즘 내용을 바꾸지 않는다.** `cf-doppler.c` NEON, 빔포밍, `b_sa.cpp` 는 위치만
- FPGA 레지스터 접근은 [Phase 3](./phase3-platform-hal.md)에서 이미 나갔다 — 여기서는 계산부와 그 호출만

---

## 2. 목표 배치

```
src/features/
  scan-session/
    domain/     mode_transition_service   ← sonon_mode_change_proc 의 상태머신
    ports/      i_scan_geometry_port.h    ← 다른 모드 feature 가 공통 참조
  scan-b/
    domain/     b_sa_service, b_conventional_service
    data/       fpga 호출(레지스터는 platforms/zynqmp 경유)
  doppler-cf/
    domain/     cf_doppler_service        ← cf-doppler.c NEON 계산
    data/
  doppler-pw/
    domain/     pw_filter_service         ← sonon_pw_filter
    data/
  mmode/
    domain/     m_proc_service            ← sonon_pw_m_proc 의 M 부분
    data/
```

### 2.1 공통부의 소속

`sonon_scanconversion.cpp`(1,278) · `sonon_transmit.cpp`(1,104) 는 모드 공통이다.

| 대상 | 목표 |
|---|---|
| 스캔 컨버전 | `core/imaging` 또는 `features/scan-session/domain` — **착수 시 각 모드 의존도로 판단**. 순수 좌표 변환이면 `core`, 모드별 파라미터가 섞이면 `scan-session` |
| 송신 | 각 feature 의 `data/` 로 분배(패킷 타입별) |

---

## 3. 진행 단계

### Step 7-A. 모드 경계 복원 — 독립 산출물

**코드를 옮기기 전에 한다.**

| # | 작업 |
|---|---|
| A-1 | `sonon_mode_change_proc.cpp`(879) 를 전부 읽어 **상태 전이도**를 그린다 — 어느 이벤트가 어느 모드로 전환을 트리거하는지 |
| A-2 | `sonon_receive_fpga.cpp` 함수 81개를 opcode 로 매핑하고, opcode 를 [Phase 0-D](./phase0-hygiene-protocol-sot.md) 프로토콜 정본의 패킷 타입과 대조해 **모드 태깅** |
| A-3 | `sonon_receive_device.cpp`·`sonon_transmit.cpp` 도 같은 방식으로 태깅 |
| A-4 | **산출물** — `docs/refactoring/r2/scan-mode-map.md`(또는 표) 로 함수 81개 + opcode 82개의 소속 모드를 전부 기록 |

> **A-4 자체가 이 phase 의 첫 번째 가치**다. 코드를 한 줄도 옮기지 않아도, 이 매핑표가 있으면 "PW 모드가 어디 있는지" 를 처음으로 답할 수 있게 된다.

### Step 7-B. `features/scan-session`

| # | 작업 |
|---|---|
| B-1 | `sonon_mode_change_proc.cpp` → `domain/mode_transition_service`. **[Phase 5](./phase5-core-layer.md)의 `core/event` 인터페이스를 통해** 이벤트 플래그에 접근(직접 전역 함수 호출 금지) |
| B-2 | `ports/i_scan_geometry_port.h` — 깊이·PRF·스케일 등 다른 모드 feature 가 공통 참조할 정보([legacy/r1 Phase 7](../legacy/r1/phase7-feature-measure.md)의 `i_scan_geometry_port` 와 이름 정합 — **장비 측이 이 정보의 출처**) |
| B-3 | `tests/unit/features/scan-session/` — 상태 전이 유닛테스트. **belle-fw 최초로 상태머신이 domain 유닛테스트 대상이 된다** |

### Step 7-C. `sonon_receive_fpga.cpp` 해체

**A-2 매핑표 기준으로** opcode 그룹별 분해.

| # | 작업 |
|---|---|
| C-1 | B 모드 관련 함수 → `features/scan-b/data` |
| C-2 | CF 관련 → `features/doppler-cf/data` |
| C-3 | PW 관련 → `features/doppler-pw/data` |
| C-4 | M 관련 → `features/mmode/data` |
| C-5 | 공통(모드 무관) 함수 → `features/scan-session/data` 또는 `core` |
| C-6 | 각 그룹 이동마다 [Phase 1](./phase1-regression-baseline.md) 골든 + [Phase 4](./phase4-platform-pc-emulator.md) PC 실행 확인 |

### Step 7-D~G. 모드별 feature

| 순서 | feature | 신호처리 원천 | 방식 |
|---|---|---|---|
| D | `scan-b` | `sonon_b_sa.cpp`(358)+`image_proc/b_sa.cpp`(1,376)+`b_conventional.cpp`(671) | `domain` 으로. **알고리즘 내용 불변** |
| E | `doppler-cf` | `lib/cf-doppler.c`(1,585, NEON) | `domain/cf_doppler_service`. **T1968 작업이 여기서 진행 중이므로 힐세리온과 순서 협의 필수** |
| F | `doppler-pw` | `sonon_pw_filter.cpp`(1,605) + `fpga_pw.cpp` 계산부([Phase 3](./phase3-platform-hal.md)에서 남겨진 것) | `domain/pw_filter_service` |
| G | `mmode` | `sonon_pw_m_proc.cpp`(977)의 M 부분 | `domain/m_proc_service` |

각 feature 마다:

1. `ports/i_<mode>_device_port.h` — HAL 경유 장비 명령
2. `domain/<mode>_service` — 파라미터 검증 · 신호처리 호출
3. `data/<mode>_repository` — HAL·전송 연결
4. `tests/unit/features/<mode>/`

### Step 7-H. 송신 분배

`sonon_transmit.cpp`(1,104) 를 A-3 매핑 기준으로 각 feature `data/` 로.

### Step 7-I. `sonon.cpp` 잔여 해체

3,522 LOC 중 D~H 로 옮긴 뒤 남는 것 — 소켓·스레드 관리는 [Phase 8-C](./phase8-feature-firmware-process.md)(`app/composition`)로, 나머지 상태는 `scan-session`.

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | **모드 매핑 완결성** | A-4 산출물이 함수 81개 + opcode 82개 **전수** 포함 | 100% |
| 4.2 | **feature 응집** | `grep -rln 'cf-doppler\|CF' src/features/` | `doppler-cf` 만(주석·변수명 오탐 배제) |
| 4.3 | feature 간 참조 | `grep -rn '#include "features/' src/features/{scan-session,scan-b,doppler-cf,doppler-pw,mmode}` | 자기 것 외 0줄(단, 전부 `scan-session` 의 `ports` 참조는 허용) |
| 4.4 | HAL 직접 접근 | `domain/` 에서 HAL include | 0건(`data/` 통해서만) |
| 4.5 | **4모드 골든** | [Phase 1](./phase1-regression-baseline.md) 하니스 확장분 | 전부 통과 |
| 4.6 | **PC 에뮬레이터 4모드** | [Phase 4](./phase4-platform-pc-emulator.md) 위에서 앱 접속 스캔 | B·CF·PW·M 전환 정상 |
| 4.7 | 파일 크기 | 자체 코드 1,000 LOC 초과 | 목표 0(불가하면 사유 명시) |
| 4.8 | 실장비 회귀 없음 | `make build TARGET=zynqmp` + 부팅 스캔 | 정상 |
| 4.9 | 알고리즘 무변경 | `git diff` — 신호처리 본문 변경 0줄(경로만) | ✓ |
| 4.10 | 계층 검사 | `make check-layers` | exit 0 |

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **모드 경계 복원(7-A)이 예상보다 오래 걸린다** | 전체 phase 지연 | **그래도 A-4 산출물은 그 자체로 가치가 있다.** 매핑이 부분적이어도 문서화하고, 확실한 부분부터 C·D~G 착수 |
| **`sonon_receive_fpga.cpp` 함수가 여러 모드에 걸쳐 있다**(공용 헬퍼) | C 단계에서 어디로 보낼지 애매 | `scan-session/data` 로 우선 배치. **억지로 4모드 중 하나로 넣지 않는다** |
| **`production-fw-ver2.0` 이 지금 CF 를 고치고 있다**(T1968) | Phase 7-E 와 정면 충돌 | **힐세리온과 반드시 선협의.** CF 를 마지막 순서로 미루거나, 그들의 T1968 완료 후 착수 |
| PC 에뮬레이터가 4모드를 다 지원 못한다 | 4.6 부분 실패 | [Phase 4-B6](./phase4-platform-pc-emulator.md)에서 4모드 녹화를 이미 확보했어야 한다. 미달이면 그 phase 로 되돌아가 보강 |
| `i_scan_geometry_port` 가 [legacy/r1](../legacy/r1/phase7-feature-measure.md) 앱 측과 이름은 같은데 실제 정보가 안 맞는다 | 프로토콜 불일치 | [Phase 0-D](./phase0-hygiene-protocol-sot.md) 정본 필드와 대조해 확정. **이름만 같고 계약이 다르면 안 된다** |
| 알고리즘을 "정리" 하고 싶어진다 | 영상 품질 회귀 | [principles.md §11](../legacy/principles.md) — 위치만. 4.9 게이트 |

---

## 6. cross-reference

- [plan.md §1.3·§2.4·§4](./plan.md)
- [../legacy/r1/phase8-feature-scan-split.md](../legacy/r1/phase8-feature-scan-split.md) — moana 의 대응 phase, **같은 feature 이름**
- [../legacy/r1/phase7-feature-measure.md](../legacy/r1/phase7-feature-measure.md) — `i_scan_geometry_port` 이름의 앱 측 대응
- [phase3-platform-hal.md §2.2](./phase3-platform-hal.md) — `fpga_pw`/`fpga_doppler` 계산부 인계
- [phase4-platform-pc-emulator.md](./phase4-platform-pc-emulator.md) — 4모드 검증의 실행 환경
- [architecture.md §5](../legacy/architecture.md) — device·client 공통 feature 이름 원칙
