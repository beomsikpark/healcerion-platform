# Phase 8 — `firmware-update` · 프로세스 4종 경계 정리

> **상태**: 미시작
> **범위**: A/B 이중 뱅크 펌웨어 업그레이드를 feature 로. `apps/` 진입점 정리 + `app/composition`(CompositionRoot). `modules/webserver` 유지 여부 판단.
> **선행**: [Phase 6](./phase6-feature-config-power-diagnostics.md) — 패턴 확립 후
> **병렬**: [Phase 7](./phase7-feature-scan-split.md)
> **후행**: 명시적 의존 없음 — [Phase 9](./phase9-runtime-variant.md) 와는 독립 진행 가능(plan.md 의존 그래프에도 P8→P9 간선 없음)

---

## 1. 배경

### 1.1 A/B 이중 뱅크는 이미 있다 — 살린다

[device-firmware.md §4](../../review/device-firmware.md):

| 파티션 | 용도 |
|---|---|
| mtd2/3 | 커널 A/B |
| **mtd4/5** | **hcproc 앱 오버레이 A/B** |

`upgrade.sh` 가 `fw_printenv kernel_imagepart` 로 현재 뱅크를 읽어 **반대편에 기록**한다. [principles.md §6](../legacy/principles.md)(되돌릴 수 있는 단위로 낸다): **이 구조를 살리고 활용한다.**

### 1.2 메인 바이너리가 rootfs 에 없다 — 이 phase 의 배경 사실

[device-firmware.md §3](../../review/device-firmware.md): `sonon` 은 PetaLinux rootfs 에 설치되지 않고, **부팅 시 `hcproc.sh`(S95hcproc)가 UBI 오버레이를 live rootfs 위로 복사**한다. 이것이 A/B 앱 오버레이(mtd4/5) 배포 방식이다.

**r2 는 이 배포 방식 자체를 바꾸지 않는다** — Buildroot 전제([plan.md §0](./plan.md))가 이 배포를 어떻게 다루는지가 이미 별건으로 정해져 있어야 한다. 이 phase 는 **펌웨어 업그레이드 기능(호스트가 받아서 플래시하는 절차)** 을 feature 화하는 것이지, 부팅 배포 메커니즘 변경이 아니다.

### 1.3 프로세스 4종은 유지한다

[principles.md §11](../legacy/principles.md)(해당 안 되지만 r2 에도 적용되는 일반 원칙): **프로세스 구조 변경을 하지 않는다.** `sonon`/`bcd`/`deviced`/`watchdogd` 경계는 지금 동작하므로 **파일 배치만 바꾸고 프로세스 경계는 유지**한다.

### 1.4 목적

1. `features/firmware-update` — 앱과 **같은 이름으로 잡았던 것**([legacy/r1 Phase 9-C](../legacy/r1/phase9-feature-ambulance-ble.md), `moana` 기준·폐기됨). 현재 client 트랙(`sonex-framework`)과의 동일성은 **재확인 전**([plan.md §2.4](./plan.md))
2. `apps/{sonon,bcd,deviced,watchdogd}/main.cpp` 로 진입점 정리
3. `app/composition` — CompositionRoot(ipc-app ADR-003)
4. `modules/webserver`(Flask 진단 서버) 유지/제거 판단

### 1.5 범위 한계

- **부팅 시 UBI 오버레이 복사 메커니즘을 바꾸지 않는다**
- 프로세스를 병합하거나 분할하지 않는다

---

## 2. 진행 단계

### Step 8-A. `features/firmware-update`

| # | 작업 |
|---|---|
| A-1 | `ports/i_firmware_transfer_port.h` — HC 프로토콜 경유 수신([Phase 0-D](./phase0-hygiene-protocol-sot.md) 정본의 펌웨어 관련 opcode) |
| A-2 | `domain/firmware_upgrade_service` — 버전 검증 · A/B 뱅크 전환 판단 로직. `upgrade.sh` 의 판단 부분을 도메인으로 |
| A-3 | `data/` — `fw_printenv`/`fw_setenv` 호출, UBI 쓰기(`platforms/zynqmp` 경유) |
| A-4 | **[legacy/r1 Phase 9-C](../legacy/r1/phase9-feature-ambulance-ble.md)와 프로토콜 계약 대조** — [proof/protocol-sot](../legacy/proof/protocol-sot/) 기준 |
| A-5 | 롤백 시나리오 골든 — 의도적으로 손상된 이미지 수신 시 반대편 뱅크 보존 확인 |

### Step 8-B. `apps/` 정리

| # | 작업 |
|---|---|
| B-1 | `sonon/sonon.cpp` 의 `main()` 진입부만 `apps/sonon/main.cpp` 로. 조립 로직은 `app/composition` |
| B-2 | `bcd/bcd.c`·`deviced/deviced.cpp`·`watchdogd/watchdogd.cpp` 도 동일 |
| B-3 | `gpio/led.cpp` — 별도 실행물인지 확인 후 배치 |

### Step 8-C. `app/composition` — CompositionRoot

ipc-app ADR-003 대응. **belle-fw 는 원래 단일 프로세스가 아니라 4프로세스이므로**, CompositionRoot 는 **프로세스별로 하나씩** 존재한다(ipc-app 의 단일 프로세스 모델과 차이).

| # | 작업 |
|---|---|
| C-1 | `sonon` 용 composition — feature 서비스 조립(scan-session + 4모드 + info/network/probe) |
| C-2 | `bcd`/`deviced`/`watchdogd` 는 각자 더 단순한 조립(feature 1~2개) |

### Step 8-D. `modules/webserver` 판단

`belle_flask`(Flask 로컬 진단 서버) — [device-firmware.md](../../review/device-firmware.md) 는 이것을 "로컬 진단용" 으로 규정했다.

| # | 작업 |
|---|---|
| D-1 | 실제 사용 빈도·주체 확인(개발자용인지 필드 서비스용인지) |
| D-2 | **결정은 힐세리온** — 유지 시 `apps/webserver/` 로 정규 편입, 폐기 시 저장소에서 제거 |

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | feature 격리 | `firmware-update` 가 다른 feature 미참조 | ✓ |
| 3.2 | **A/B 롤백** | 손상 이미지 업그레이드 시도 | 반대편 뱅크 무손상, 부팅 가능 |
| 3.3 | 프로세스 4종 유지 | `ps` 로 확인 | 정확히 4개 |
| 3.4 | IPC 불변 | [Phase 5](./phase5-core-layer.md) 검증 재확인 | 통과 |
| 3.5 | PC/실장비 빌드 | 양쪽 | exit 0 |
| 3.6 | **동작 불변** | `make test-golden` + 실제 업그레이드 1회 | 통과 |
| 3.7 | 계층 검사 | `make check-layers` | exit 0 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **A/B 전환 로직 변경이 필드 업그레이드를 깨뜨린다** | 브릭 위험 | 3.2 필수. **실장비에서 실제 업그레이드-롤백 왕복 테스트** |
| CompositionRoot 도입이 프로세스 시작 순서를 바꾼다 | `watchdogd` 감시 대상 누락 등 | B·C 단계를 프로세스 하나씩, 매번 [Phase 5](./phase5-core-layer.md) 3.4(watchdogd 검증) 재실행 |
| `modules/webserver` 제거가 필드에서 쓰이던 진단 경로를 없앤다 | 현장 지원 공백 | D-1 확인 없이 제거하지 않는다 |

---

## 5. cross-reference

- [plan.md §2.4·§4](./plan.md)
- [principles.md §6](../legacy/principles.md) — 되돌릴 수 있는 단위로 낸다(A/B 뱅크)
- [../legacy/r1/phase9-feature-ambulance-ble.md §2 Step 9-C](../legacy/r1/phase9-feature-ambulance-ble.md) — 앱 측 `firmware-update`
- [../../review/device-firmware.md §3·§4](../../review/device-firmware.md) — A/B 뱅크·UBI 오버레이 실측
