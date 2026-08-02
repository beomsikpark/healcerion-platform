# Phase 0 — 저장소 재배치 · 범위 절단

> **상태**: 미시작
> **범위**: `moana` 쓰기 가능 작업 사본을 만들고, **출시 대상(500C·500P) 밖의 코드를 먼저 걷어낸다.** 구조를 바꾸지 않는다 — **이후 Phase 가 옮길 대상을 줄인다.**
> **선행**: 없음 (0-0 이 이 계획의 첫 항목)
> **후행**: [Phase 1](./phase1-render-composition.md)
> **근거**: [plan.md §3](./plan.md) · 현행 구조 SOT = [../../review/moana-app.md](../../review/moana-app.md)
> **실측 기준**: `moana` `origin/service_QT693`(HEAD `7b26a9b27`, 2026-07-27). 이 문서의 `[실측]` 은 2026-08-02 직접 측정분이다.

---

## 1. 배경

### 1.1 왜 절단이 먼저인가

[plan.md §1.1](./plan.md) 이 잰 이음매는 **`SononFrame` 585회 · `ScanContext` 397회 · `SONON_CMD_*` 505회 · DB/Settings 816회** 다. 이 수치는 **지금 트리 전체 기준**이고, 그 안에는 출시 대상이 아닌 코드가 섞여 있다.

**절단을 나중에 하면 그만큼을 두 번 만진다** — 먼저 어댑터로 옮기고, 나중에 지운다. 순서를 뒤집으면 Phase 2~5 의 대상이 줄어든 상태로 시작한다.

### 1.2 다만 "500 계열"과 "500L"을 혼동하면 안 된다 `[실측 2026-08-02]`

`HC_SONON_500L` 은 **85파일 563곳**에 있어 절단 후보로 가장 커 보인다. **그러나 이것은 모델 매크로가 아니라 릴리스 타깃 매크로다.**

```
app/app.pro:44-45      DEFINES += HC_SONON_500L
app/app.pro:1011       equals(HC_RELEASE_TARGET, HC_SONON_500L) { ... }
framework/framework.pro:42-43   (동일)
```

`HC_RELEASE_TARGET` 이 정하는 **빌드 변종 이름**이고, 그 안에 500 계열 전반의 UI·프리셋·설정이 들어 있다(`Setting/CustomPresetModel.cpp` 한 파일에만 8곳).

**그리고 `moana` 의 app 계층에는 이미 `500P` 언급이 있다** — `app/Resources/QML/{DeviceListView,ScanCFControlView,ScanPWControlView}.qml` · `app/Sources/BLE/BluetoothController.cpp`(2곳) · `app/Sources/Common/SononDeviceInfo.h`(3곳).

> **따라서 `HC_SONON_500L` 563곳을 "500L 은 범위 밖이니 제거"로 처리하면 안 된다.** 이 매크로 뒤에 **500P 에도 필요한 것**이 들어 있다. 절단 전에 **분류가 선행**한다(§2 Step 0-C).
>
> `moana` 가 500C·500P 를 **구동**하지 못하는 것(`Model.cpp` capability table 0건)과, **app 계층이 500P 를 전혀 모르는 것**은 다른 이야기다. 전자는 사실이고 후자는 사실이 아니다.

### 1.3 절단 대상 실측 `[실측 2026-08-02]`

| 대상 | 규모 | 판정 |
|---|---:|---|
| `InitCapabilityTable_*` — **300C·300L·300MC·300PA·300VC·310C·500L·FUJI_L43K 8종** | `Model.cpp` 16곳 · `Model.h` 8곳 | **전부 제거.** 모델 capability 는 SDK 소관이다([plan.md §1.6](./plan.md)) |
| `app/Sources/Ambulance/` + `framework/Ambulance/` | **27 + 12 = 39파일**(14,906 LOC) | **제거** — 러시아 EMS 전용, 대상 제품과 무관 |
| `app/Sources/Test/` | 2파일 | **제거** |
| `HC_CVIE_SUPPORT` | **85곳 / 14파일** | **제거 대상** — CVIE 는 ContextVision **상용**이라 라이선스 조건에 걸린다([plan.md §0.4](./plan.md)). 대체 구현이 이미 출하 코드에 있으나 **화질 등가성이 미검증**이라 실행·판정은 [Phase 5 B](./phase5-measure-controls.md) 소관이다. 이 phase 에서는 **건드리지 않는다** |
| `ENABLE_IMAGE_ANALYZER`(QCustomPlot GPLv3) | 2곳 / 2파일 | **제거** — 정비용 토글이고 기본 비활성이다([../legacy/moana-vs-sonex.md §1.1](../legacy/moana-vs-sonex.md)). 릴리스에서 빼면 GPL 의무가 발동하지 않는다 |
| `HC_SONON_500L` | **563곳 / 85파일** | **분류 선행**(§1.2). 일괄 처리 금지 |
| `app/Sources/BLE/` | 2파일(+ `framework/Platform`) | **유지** — 500P BLE 페어링 대상([../../review/moana-app.md §4](../../review/moana-app.md)) |

### 1.4 저장소 크기는 이 phase 의 목표가 아니다

`moana` 는 9.4GB 이고 그중 벤더 `lib/` 가 **6.56G**, `.git` 이 3.13G 다([../../review/moana-app.md §1](../../review/moana-app.md)). 자체 소스는 8MB 미만이다.

`lib/` 의 상당수(DCMTK 2.06G · OpenCV 1.85G · FFmpeg 0.95G · wxSQLite3 234M)는 **SDK/ADK 가 대신 제공하므로 소비처가 사라진다.** 다만 **`.git` 3.13G 는 이력 재작성 없이 줄지 않고, 이력 재작성은 하지 않는다**([r1 Phase 0-E6](../r1/phase0-build-reproducibility.md) 와 같은 원칙 — 힐세리온 원본 반영 방식이 정해지기 전에는 되돌릴 수 없는 변경을 하지 않는다).

→ **이 phase 는 `lib/` 의존을 끊는 것까지만 하고, 파일 삭제는 Phase 6(패키징)에서 판단한다.**

---

## 2. 진행 단계

### Step 0-0. 저장소 재배치

| # | 작업 |
|---|---|
| 0-1 | **착수 직전 재fetch** — `git -C client/legacy/moana fetch --all --prune` 후 `origin/service_QT693` tip 재확인. 이 저장소는 **오늘도 커밋된다**(최종 2026-07-27) |
| 0-2 | `client/legacy/moana` → **`client/moana`** 쓰기 가능 작업 사본. **fork base = `origin/service_QT693`** |
| 0-3 | **`master` 를 쓰지 않는다** — 2022-02-17 에 멈춰 있고 실제 개발선이 아니다. 루트 `CLAUDE.md` 의 측정 규칙(`--all` 기준)이 이 저장소에 그대로 적용된다 |
| 0-4 | 작업 브랜치 생성. r1 의 선례대로 **`refactor/r2`** |
| 0-5 | 착수 시점 SHA 를 baseline 태그로 기록. 이후 Phase 의 diff 기준선이다 |
| 0-6 | 미러(`client/legacy/moana`)는 **그대로 둔다** — 대조 기준선이자 소유권 표시다 |
| 0-7 | **힐세리온 원본 반영 방식은 미정이어도 비차단** — 별도 브랜치에서만 작업하므로 `service_QT693` 을 건드리지 않는다([r1 Phase 0-4](../r1/phase0-build-reproducibility.md) 와 같은 원칙) |

### Step 0-A. 모델 분기 절단

| # | 작업 |
|---|---|
| A-1 | `InitCapabilityTable_*` **8종 제거** — 300C·300L·300MC·300PA·300VC·310C·500L·FUJI_L43K |
| A-2 | `CModel::isS300C()`·`isS310C()`·`isS300L()`·`isS500L()`·`isFUJI_L43K()` 등 모델 판정 제거 |
| A-3 | `CModel::isValid*()` 30여 종 **보류** — 값 유효범위는 SDK 가 제공하므로 Phase 2 에서 어댑터로 대체한다. **여기서 지우면 UI 가 즉시 깨진다** |
| A-4 | `framework/Common/CommonData.cpp` 의 `deviceModelList` 정리 — 500C·500P·700C·700L 이 문자열로만 있다([../legacy/moana-vs-sonex.md §3.1](../legacy/moana-vs-sonex.md)) |

> **A-3 이 이 Step 의 함정이다.** capability table(A-1)과 값 검증(A-3)은 같은 클래스에 있지만 소비처가 다르다 — 전자는 모델 식별, 후자는 UI 입력 검증이다. **후자를 먼저 지우면 Phase 2 전에 화면이 죽는다.**

### Step 0-B. 범위 밖 기능 절단

| # | 작업 |
|---|---|
| B-1 | `app/Sources/Ambulance/`(27) + `framework/Ambulance/`(12) 제거 — 14,906 LOC |
| B-2 | `app/Sources/Test/`(2) 제거 |
| B-3 | `ENABLE_IMAGE_ANALYZER` 경로 제거 — 래퍼 `CCustomPlotItem` + QML 인스턴스 2곳(`Desktop/ImageAnalyzerView.qml:70,394`). **QCustomPlot(GPLv3) 의존이 함께 사라진다** |
| B-4 | 제거 후 `.pro` 의 대응 항목·`INCLUDEPATH` 정리 |

### Step 0-C. `HC_SONON_500L` 분류 — **일괄 처리 금지**

**§1.2 대로 이 매크로는 릴리스 타깃이지 모델이 아니다.**

| # | 작업 |
|---|---|
| C-1 | **563곳을 3분류한다** — ① 500 계열 공통(500P 에도 필요) ② 500L 전용 ③ 판정 보류 |
| C-2 | 분류 근거를 **주석이 아니라 코드로 확인**한다. 500P 언급이 이미 있는 파일(`SononDeviceInfo.h`·`BluetoothController.cpp`·QML 3벌)이 ①의 출발점이다 |
| C-3 | ②만 제거한다. ①은 **매크로를 걷어내고 무조건 활성**으로 바꾼다 — 출시 타깃이 하나뿐이므로 변종 분기 자체가 불필요하다 |
| C-4 | `HC_RELEASE_TARGET` 체계 정리 — `app.pro:1011` 의 분기가 CE/US 뒤바뀜 출하 사고의 무대였다([../../review/moana-app.md §9](../../review/moana-app.md)). **타깃이 하나면 이 분기가 사라지는 것이 정상이다** |

### Step 0-D. 벤더 `lib/` 의존 조사

| # | 작업 |
|---|---|
| D-1 | `lib/` 7플랫폼 × 라이브러리별로 **누가 아직 링크하는지** 조사. SDK/ADK 가 대신 제공하는 것과 `moana` 자체가 쓰는 것을 가른다 |
| D-2 | **파일은 지우지 않는다**(§1.4) — 의존이 실제로 끊긴 뒤 Phase 6 에서 판단한다 |
| D-3 | Qt5 시절 잔재 확인 — `wxSQLite3`/`CipherSqlitePlugin` 이 **Qt5 5개 버전분(5.12.4·5.14·5.15·5.15.2·5.15.7)** 을 Qt6 이행 후에도 갖고 있다(234M). ADK 가 DB 를 맡으면 전부 소비처가 없다 |

---

## 3. 검증

| # | 항목 | 방법 | 기대 |
|---|---|---|---|
| 3.1 | **빌드 가능** | 절단 후 `moana` 가 그대로 빌드된다 | 성공. **이 phase 는 동작을 바꾸지 않는다** |
| 3.2 | 모델 분기 | `grep -c InitCapabilityTable_` | **0건**(현재 24) |
| 3.3 | Ambulance | `app/Sources/Ambulance`·`framework/Ambulance` | **부재** |
| 3.4 | QCustomPlot | `ENABLE_IMAGE_ANALYZER`·`CCustomPlotItem` | **0건** |
| 3.5 | `HC_SONON_500L` | 잔존 수 | **줄어들되 0 은 아니다** — ①이 남는다. **분류 결과를 문서로 남긴다** |
| 3.6 | 500P 경로 보존 | `SononDeviceInfo.h`·`BluetoothController.cpp`·QML 3벌의 500P 참조 | **보존**(제거 금지) |
| 3.7 | 실장비 | 절단 후 기존 지원 모델로 스캔 | **하지 않는다** — 300 계열·500L 을 이미 지웠으므로 이 시점엔 구동 대상이 없다. §4 참조 |

> **3.7 이 이 phase 의 구조적 특성이다.** 절단이 끝나면 **`moana` 는 어떤 장비도 구동하지 못하는 상태**가 된다 — 옛 모델은 지웠고 새 모델(500C/P)은 아직 SDK 가 안 붙었다. **Phase 2 가 끝나야 다시 돈다.** 이 구간이 이 계획에서 가장 긴 "빌드는 되지만 동작하지 않는" 구간이며, 그래서 §3.1(빌드 가능)이 유일한 자동 판정이다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`HC_SONON_500L` 을 일괄 제거한다** | 500P 에 필요한 UI·프리셋이 함께 사라지고, 그 사실이 Phase 5 까지 드러나지 않는다 | §1.2·0-C. **분류를 코드로 하고 결과를 문서로 남긴다.** 500P 언급이 있는 5개 파일이 출발점 |
| `isValid*()` 를 capability table 과 함께 지운다 | Phase 2 전에 UI 가 죽는다 | A-3 — 보류 대상으로 명시 |
| **동작하지 않는 구간이 길다**(§3.7) | 회귀를 조기에 못 잡는다 | Phase 를 잘게 끊고 **빌드 게이트를 매 Step 유지**한다. 실동작 판정은 Phase 2 완료 시점으로 모인다 |
| 힐세리온이 `service_QT693` 에 계속 커밋한다 | 작업 사본이 갈라진다 | 0-5 의 baseline SHA 로 diff 범위를 항상 계산 가능하게 둔다. 반영 방식은 0-7 |
| Qt 6.9.3 이행과 충돌 | 같은 파일을 두 작업이 만진다 | 이 phase 는 **삭제 위주**라 충돌 면이 작다. 착수 시점 브랜치를 합의한다 |
| `lib/` 를 성급히 지운다 | 아직 링크하는 것이 있어 빌드가 깨진다 | D-2 — 이 phase 에서는 조사만 한다 |

---

## 5. cross-reference

- [plan.md](./plan.md) §3 Phase 0 — 이 문서의 뼈대
- [phase1-render-composition.md](./phase1-render-composition.md) — 후행. 이 phase 가 줄인 트리 위에서 실증한다
- [phase2-sdk-adk-adapter.md](./phase2-sdk-adk-adapter.md) — A-3 이 보류한 `isValid*()` 의 처리처
- [../../review/moana-app.md](../../review/moana-app.md) — `moana` 현행 구조 SOT. §1(저장소 크기)·§4(도메인)·§7(브랜치 변종)·§9(출하 사고)
- [../legacy/moana-vs-sonex.md](../legacy/moana-vs-sonex.md) §1.1(QCustomPlot 제거 경로)·§3.1(모델 집합)
- [../r1/phase0-build-reproducibility.md](../r1/phase0-build-reproducibility.md) — 재배치·반영 방식의 선례
