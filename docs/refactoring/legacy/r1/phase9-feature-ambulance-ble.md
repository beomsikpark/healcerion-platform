# Phase 9 — `ambulance` · `ble` · `firmware-update`

> **상태**: 미시작
> **범위**: 남은 feature 3개. `Ambulance` 순환 5쌍을 끊고, `firmware-update` 를 장비와 같은 이름으로 세운다.
> **선행**: [Phase 5](./phase5-feature-worklist-settings.md)
> **병렬**: [Phase 6](./phase6-feature-patient-dicom-cloud.md) · [Phase 7](./phase7-feature-measure.md)
> **후행**: [Phase 10](./phase10-runtime-variant.md)

---

## 1. 배경

### 1.1 `Ambulance` 가 `Measure` 보다 크다

| | 파일 | LOC |
|---|---:|---:|
| `app/Sources/Ambulance` | 27 | 11,465 |
| `framework/Ambulance` | 12 | 3,441 |
| **합** | **39** | **14,906** |

최대 파일은 `Ambulance/ScanAmbulancePlayer.cpp` **4,409 LOC** — moana 에서 `ScanPlayer`(7,526) 다음이다. `framework/Ambulance/AmbulanceManager.cpp` 는 1,905.

러시아 EMS(응급의료) 프로젝트의 앱 측이고 GPS 태그 스캔 업로드를 한다.

### 1.2 순환 5쌍 — 전부 역방향이 2건 이하

| 순환 | 정방향 | 역방향 |
|---|---:|---:|
| `Ambulance` ↔ `Common` | 29 | **1** |
| `Ambulance` ↔ `Scan` | 10 | **1** |
| `Ambulance` ↔ `Main` | 7 | **2** |
| `Ambulance` ↔ `Setting` | 3 | **1** |
| `Ambulance` ↔ `PatientList` | 1 | **2** |

**끊는 비용이 작다.** 역방향 총 7건이고, `Common` 쪽 1건은 [Phase 3-E](./phase3-core-layer.md) 에서, `PatientList` 쪽 2건은 [Phase 6-E](./phase6-feature-patient-dicom-cloud.md) 에서 이미 처리됐을 가능성이 높다. **착수 시 재측정한다.**

### 1.3 `ScanAmbulancePlayer` 가 `ScanPlayer` 의 사본으로 보인다

`Ambulance/ScanAmbulancePlayer.cpp`(4,409) 와 `Scan/ScanPlayer.cpp`(7,526) 의 관계가 **미확인**이다. 이름과 규모로 보아 스캔 재생 경로의 변형일 가능성이 있다.

**만약 사본이라면 [principles.md §7](../principles.md)(정본은 하나) 대상이다.** 그러나 **이 phase 에서 통합하지 않는다** — [Phase 8](./phase8-feature-scan-split.md) 이 `ScanPlayer` 를 해체한 뒤에야 무엇이 공통인지 보인다. **착수 시 diff 를 떠서 관계를 문서에 기록**하고, 통합은 별건으로 낸다.

### 1.4 `firmware-update` 는 흩어져 있다

| 위치 | 내용 |
|---|---|
| `Main/FirmwareUpdater.{h,cpp}` | 펌웨어 전송·진행률 |
| `Setting/FirmwareSetting.{h,cpp}` | 설정 UI 측 |
| `Common/FWUpgradeProgress.h` | 진행 상태 타입 |
| QML `FWUpgradeProgressView.qml` | UI |

**[architecture.md §5](../architecture.md) 가 `firmware_update` 를 장비·클라이언트 공통 feature 로 지정했다** — 장비는 "수신·플래시", 앱은 "전송·진행률". 이름을 맞춰야 변경 추적이 저장소를 넘어 이어진다.

### 1.5 `ble` 는 작다

`app/Sources/BLE` 2파일 724 LOC. 500L·500P 페어링. `SononApp.cpp:86,104` 에서 **`bluetoothController` context property 가 주석 처리**돼 있다 — 현재 배선이 끊겨 있을 가능성이 있다. **착수 시 확인.**

### 1.6 목적

1. `ambulance` 14,906 LOC 를 하나의 feature 로 **격리** — 폐기 판단이 가능한 상태를 만든다
2. 순환 5쌍 제거
3. `firmware-update` 를 장비와 같은 이름으로
4. `ble` 정리 + 현행 활성 여부 확인

### 1.7 범위 한계 — **폐기 판단은 하지 않는다**

[../../review/moana-app.md §11](../../review/moana-app.md) 미확인 항목: *"`Ambulance` 기능의 현재 운영 여부 — 앱 측은 14.9k LOC 인데 서버 측은 39줄 프로토타입뿐이다."*

**우리는 격리까지만 한다.** 격리되면 힐세리온이 판단할 수 있는 상태가 된다 — 지금은 5개 디렉토리에 얽혀 있어 "뺄 수 있는가" 자체를 답할 수 없다.

- `ScanAmbulancePlayer` ↔ `ScanPlayer` 통합 — **별건**(§1.3)
- `HC_RELEASE_RU`(14파일 39곳) 제거 — [Phase 10-E](./phase10-runtime-variant.md)

---

## 2. 진행 단계

### Step 9-A. `ambulance`

| # | 작업 |
|---|---|
| A-1 | 순환 5쌍 **재측정**. Phase 3·6 이후 남은 것만 처리 |
| A-2 | `framework/Ambulance`(12파일 3,441) + `app/Ambulance`(27파일 11,465) 를 `features/ambulance/` 로 통합 |
| A-3 | `ports/i_ambulance_upload_port.h` — GPS 태그 업로드. `features/cloud` 를 직접 부르지 않는다([Phase 5 §2.2](./phase5-feature-worklist-settings.md)) |
| A-4 | `domain/ambulance_service` — `AmbulanceManager`(1,905) 에서 |
| A-5 | `data/` — `AmbulanceCloud`(421) · 업로드 어댑터 |
| A-6 | `presentations/qt/features/ambulance/` — [Phase 4-B7](./phase4-composition-root-presentations.md) 에서 이미 이동. `domain` 만 보게 |
| A-7 | QML `AmbulanceDataListView`·`AmbulanceDataDetailView`·`AmbulanceDataSplitView` → `qml/features/ambulance/` |
| A-8 | **`ScanAmbulancePlayer` ↔ `ScanPlayer` diff 를 떠서 관계 기록** — 통합은 하지 않는다 |
| A-9 | `tests/unit/features/ambulance/` |

### Step 9-B. `ble`

| # | 작업 |
|---|---|
| B-1 | **현행 활성 여부 확인** — `SononApp.cpp:86,104` 주석 처리 상태 |
| B-2 | 비활성이면 **비활성인 채로 격리**한다. 되살리거나 지우지 않는다 |
| B-3 | `features/ble/{domain,data,ports}` — 페어링 상태·기기 검색 |
| B-4 | `platforms/` 의 BLE 네이티브(`framework.pro:294,302` 의 `WinrtBLE`·`WindowsBLE`)와의 경계 확인 |
| B-5 | `presentations/qt/features/ble/` |

### Step 9-C. `firmware-update`

| # | 작업 |
|---|---|
| C-1 | `Main/FirmwareUpdater` + `Setting/FirmwareSetting` + `Common/FWUpgradeProgress` 를 `features/firmware-update/` 로 |
| C-2 | `ports/i_firmware_transfer_port.h` — `core/services/sonon` 경유 전송 |
| C-3 | `domain/firmware_service` — 버전 비교·업그레이드 정책·진행률 상태머신 |
| C-4 | `presentations/qt/features/firmware-update/` + `qml/features/firmware-update/`(`FWUpgradeProgressView.qml` · `DeviceListView`) |
| C-5 | **장비 쪽 `firmware_update` 와 프로토콜 계약 대조** — [../proof/protocol-sot/](../proof/protocol-sot/) 정본 기준 |
| C-6 | `tests/unit/features/firmware-update/` — 버전 비교·상태 전이 |

> **C-5 가 이 feature 의 고유 가치다.** 펌웨어 업데이트는 앱↔장비가 **양쪽 다 구현해야 성립**하는 유일한 feature 이고, 이름이 같아지면 [architecture.md §5](../architecture.md) 가 말하는 "변경 추적이 저장소를 넘어 이어진다" 가 실제로 성립하는 첫 사례가 된다.

### Step 9-D. `app/Sources/` 잔여 정리

[Phase 3-D 2.4-7](./phase3-core-layer.md) 에서 남긴 것 중 이 phase 소속분 — `FrameStreamer` · `BackupWorker` · `UnsafeArea` 등. **소속이 여전히 모호하면 `core/util` 로 보내고 문서에 근거를 적는다.**

이 단계가 끝나면 `app/Sources/` 가 비고 `src/app/` 만 남는다.

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 순환 제거 | `Ambulance` ↔ 5쌍 | **0건** |
| 3.2 | feature 간 참조 | `grep -rn '#include "features/' src/features/{ambulance,ble,firmware-update}` | 자기 것 외 0줄 |
| 3.3 | UI 격리 | `grep -rn '<QQuick\|<QtWidgets' src/features/` | 0줄 |
| 3.4 | **`ambulance` 격리** | `features/ambulance/` + `presentations/qt/features/ambulance/` + `qml/features/ambulance/` 를 제외하고 빌드 | **성공** — 폐기 가능성이 실증된다 |
| 3.5 | `app/Sources/` 소멸 | `ls app/Sources/` | 없음 |
| 3.6 | feature 이름 정합 | `firmware-update` 가 장비 쪽과 동일 | ✓ |
| 3.7 | 유닛 테스트 | `make test-unit` | 3 feature 존재 |
| 3.8 | 6타깃 빌드 | `make build-all` | exit 0 |
| 3.9 | **동작 불변** | `make test-golden` | 통과 |
| 3.10 | 계층 검사 | `make check-layers` | exit 0 |

> **3.4 가 이 phase 의 고유 산출물이다.** "빼면 빌드가 되는가" 는 격리 여부의 기계적 판정이고, 힐세리온이 폐기를 판단할 근거가 된다. **빼서 출하하자는 뜻이 아니다** — 뺄 수 있는 상태가 됐다는 사실만 보인다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`Ambulance` 14,906 LOC 를 정리했는데 버릴 코드일 수 있다** | 헛일 | 3.4 로 폐기 가능 상태를 만들고 **판단은 힐세리온에.** 격리 자체는 순환 제거 효과가 있으므로 헛일이 아니다 |
| `ScanAmbulancePlayer`(4,409) 가 `ScanPlayer` 사본 | 같은 버그를 두 번 고치게 된다 | A-8 — **diff 를 떠서 기록**만. 통합은 Phase 8 이후 별건 |
| `ble` 가 이미 비활성인데 되살린다 | 없던 코드가 동작 | B-2 — **비활성인 채로 격리**. 상태를 바꾸지 않는다 |
| `HC_RELEASE_RU` 39곳이 `ambulance` 에 섞여 있다 | 격리해도 변종 분기가 남는다 | 그대로 들고 이동. [Phase 10-E](./phase10-runtime-variant.md) |
| 러시아 서버(`russia-server` 39줄)와의 실제 계약 미확인 | port 설계가 추측 | 현행 코드의 HTTP 호출을 그대로 어댑터로 감싼다. **계약을 새로 정의하지 않는다** |
| BLE 네이티브가 `platforms/` 와 얽힌다 | 계층 경계 모호 | B-4 — 인터페이스는 `features/ble/ports`, 구현은 `platforms/{windows,android,ios}` |

---

## 5. cross-reference

- [plan.md §3.4·§5](./plan.md)
- [architecture.md §5](../architecture.md) — `firmware_update` 공통 feature 이름
- [../proof/protocol-sot/](../proof/protocol-sot/) — 펌웨어 프로토콜 계약
- [../../review/moana-app.md §4·§11](../../review/moana-app.md) — `Ambulance` 실측과 미확인 항목
- [phase10-runtime-variant.md](./phase10-runtime-variant.md) — `HC_RELEASE_RU` 처리
