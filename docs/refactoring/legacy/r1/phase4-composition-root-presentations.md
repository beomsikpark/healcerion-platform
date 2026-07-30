# Phase 4 — composition root + `presentations/` 분리

> **상태**: 미시작
> **범위**: `SononApp` → `app/main.cpp` + `AppServices`, 뷰컨트롤러 C++ 과 QML 147개를 `presentations/` 로. 파일명 규약 전환을 **동시에**.
> **선행**: [Phase 3](./phase3-core-layer.md)
> **후행**: [Phase 5](./phase5-feature-worklist-settings.md) 이후 전부
> **구조 정본**: cms-app **ADR-002**(UI 는 최상위 `presentations/`) · **ADR-003**(composition root) — `cctv/desktop/cms-app/docs/adr/`

---

## 1. 배경

### 1.1 이 phase 가 r1 에서 가장 크다

cms-app 실측에서 **`presentations/` 가 242파일 62,340 LOC 로 `src/` 의 53%** 다. moana 도 같은 비중일 것으로 보인다 — QML 147파일 + 뷰컨트롤러 C++.

| cms-app | 파일 | LOC | 비중 |
|---|---:|---:|---:|
| `presentations/` | 242 | **62,340** | **53%** |
| `core/` | 135 | 30,004 | 25% |
| `features/` | 182 | 24,149 | 20% |
| `platforms/` · `app/` | 15 | 1,640 | 1.4% |

**이 분포가 ADR-002 의 결정 근거이기도 하다.** UI 를 feature 안에 넣으면 `features/` 가 다시 거대해져 "feature 하나를 보면 된다" 가 성립하지 않는다.

### 1.2 두 작업이 한 phase 인 이유

뷰컨트롤러를 옮기면 **DI 배선이 함께 바뀐다** — `SononApp.cpp:75-107` 이 뷰컨트롤러 11개를 생성하고 QML context 에 주입하고 소멸시킨다. 나누면 같은 파일을 두 번 옮긴다.

### 1.3 `SononApp` 은 이미 composition root 의 절반이다

```cpp
// app/Sources/Main/SononApp.cpp:75-107 (요약)
mainView->rootContext()->setContextProperty("appSetting", appSetting);
mainView->rootContext()->setContextProperty("mainViewController", mainViewController);
mainView->rootContext()->setContextProperty("settingViewController", settingViewController);
mainView->rootContext()->setContextProperty("workListViewController", workListViewController);
mainView->rootContext()->setContextProperty("patientListViewController", patientListViewController);
mainView->rootContext()->setContextProperty("scanViewController", scanViewController);
mainView->rootContext()->setContextProperty("cloudAPIController", cloudAPIController);
mainView->rootContext()->setContextProperty("languageManager", languageManager);
mainView->rootContext()->setContextProperty("agingTestController", agingTestController);
mainView->rootContext()->setContextProperty("scanAutoTestController", scanAutoTestController);
mainView->rootContext()->setContextProperty("dataListViewController", dataListViewController);
// ... :93-107 에서 전부 nullptr 로 되돌리고 :155-193 에서 delete
```

**cms-app `AppServices` 와 같은 목록이다.** 다만 차이가 둘 있다.

| | cms-app | moana |
|---|---|---|
| 할당 | `main.cpp` **스택 할당** → RAII 자동 소멸(ADR-003) | `new` / `delete` 수동. `SononApp` 에 소멸 코드가 흩어져 있다 |
| 주입 대상 | 서비스(도메인) | **뷰컨트롤러**(UI). 도메인 서비스가 아직 없다 |

즉 `SononApp` 은 **UI 컨트롤러의 composition root** 이고, [Phase 5](./phase5-feature-worklist-settings.md) 이후 feature 서비스가 생기면 그것들도 여기서 조립된다.

### 1.4 QML 이 평평하다

147개 중 **92개가 `app/Resources/QML/` 최상위**에 있다. 하위는 `Setting`(23) · `UserRegistration`(26) · `Mobile`(2) · `Desktop`(2).

**다만 파일명 접두사가 이미 feature 다:**

| 접두사 | 개수 | 목표 feature |
|---|---:|---|
| `Scan*` | 42 | `scan-b` · `doppler-cf` · `doppler-pw` · `mmode` · `measure`(Phase 8 에서 재분배) |
| `Patient*` | 9 | `patient` |
| `Ambulance*` | 3 | `ambulance` |
| `QML/Setting/*` | 23 | `settings` |
| `QML/UserRegistration/*` | 26 | `settings` 또는 `account` |
| `Backup*` · `Import*` · `Record*` · `SnapshotFileList*` · `FileConverter*` | 7 | `recording` · `patient` |
| `Worklist*` · `Calendar*` | 2 | `worklist` · `patient` |
| `Device*` · `FWUpgradeProgress*` | 3 | `firmware-update` |
| `Main*` · `Login*` · `Intro*` · `SelectMode*` · `Debug*` · `Copyright*` · `Security*` · `UIControl*` · `ElapsedTimer` · `SingleShotTimer` · `Alert*` · `DiskSpace*` · `Dummy*` | 나머지 | `presentations/qt/qml/common/` 또는 shell |

**매핑이 기계적이다.**

> **`Scan*`·`Backup*` 등 개수는 적대적 검증으로 재실측했다(2026-07-29)** — 구판은 `Scan*` 33·`Backup*`군 8로 적었으나 실제로는 42·7이다(합계 145와는 정합).

### 1.5 목적

1. `app/main.cpp` + `AppServices` — DI 체인이 한 파일에서 보인다(ADR-003)
2. UI 전부를 `presentations/` 로 — `features/` 를 만들 자리가 비워진다
3. `ControlCommand`(2,672) 를 전송/발행으로 가른다 — Phase 5~9 가 각자 명령을 발행할 수 있게
4. 파일명 규약 전환 — **이동과 동시에 한 번만**

### 1.6 범위 한계

- **`features/` 를 만들지 않는다.** 골격은 [Phase 5-A](./phase5-feature-worklist-settings.md). 이 phase 뒤 도메인 로직은 여전히 뷰컨트롤러 안에 있다
- **QML 내용을 바꾸지 않는다.** 위치와 `.qrc` 만
- **UI 를 재설계하지 않는다**

---

## 2. 목표 배치

```
src/
  app/
    main.cpp              ← 진입점 + composition root
    app_services.h        ← 의존성 구조체 (non-owning 포인터)
    callback_wiring.cpp   ← 콜백 배선 (cms-app 대응)
  presentations/
    qt/
      core/                 공통 페이지 베이스 · 리스너 mixin
      common/               공통 위젯 유틸
      features/<name>/      뷰컨트롤러 C++ — qt_*.{h,cpp}
      qml/
        features/<name>/    feature QML
        common/             공통 QML (UIControlGroup · SingleShotTimer …)
        shell/              main.qml · MainView · Intro · SelectMode · Login
      locale/               .ts / .qm 10개 언어
    common/<feature>/       백엔드 무관 프레젠테이션 로직 (레이아웃 계산 등)
```

**cms-app 대응** (`presentations/qt/`): `core/`(managed_page · *_listener_mixin) · `common/`(qt_icon_utils) · `features/`(13개) · `locale/`.

---

## 3. 진행 단계

### Step 4-A. composition root

| # | 작업 |
|---|---|
| A-1 | `src/app/main.cpp` — 현 `app/main.cpp`(진입) + `Main/SononApp`(조립) 통합 |
| A-2 | `src/app/app_services.h` — §1.3 의 11개를 non-owning 포인터 구조체로 |
| A-3 | **`new`/`delete` → 스택 할당** 전환. `SononApp.cpp:155-193` 의 소멸 코드가 사라진다(RAII) |
| A-4 | QML context property 등록을 `main.cpp` 한곳으로. **11줄 등록 + 11줄 해제 → 등록만** |
| A-5 | `Main/` 잔여 재배치 — `MainViewController`·`DebugView`·`RecordView` → `presentations/qt/features/`, `LanguageManager` → `presentations/qt/locale/`, `FirmwareUpdater` → `framework/` 에 임시 존치([Phase 9-D](./phase9-feature-ambulance-ble.md)) |

> **A-3 이 회귀 위험이 있다** — 소멸 순서가 바뀐다. cms-app 은 "스코프 종료 시 역순 자동 소멸"(ADR-003)인데, 현행 `SononApp` 의 `delete` 순서와 다를 수 있다. **[Phase 1](./phase1-regression-baseline.md) 골든으로는 종료 경로를 못 잡으므로 수동 확인이 필요하다.**

### Step 4-B. 뷰컨트롤러 → `presentations/qt/features/`

feature 별로 하나씩. **각각 별도 커밋 + 6타깃 빌드 + 골든.**

| 순서 | 대상 | 목표 |
|---|---|---|
| B-1 | `WorkList/`(8파일 955) | `presentations/qt/features/worklist/` |
| B-2 | `Setting/`(29파일 6,667) | `presentations/qt/features/settings/` |
| B-3 | `Cloud/`(2파일 1,440) | `presentations/qt/features/cloud/` |
| B-4 | `BLE/`(2파일 724) | `presentations/qt/features/ble/` |
| B-5 | `PatientList/`(40파일 11,193) | `presentations/qt/features/patient/` |
| B-6 | `Measure/`(50파일 12,689) | `presentations/qt/features/measure/` |
| B-7 | `Ambulance/`(27파일 11,465) | `presentations/qt/features/ambulance/` |
| B-8 | `Scan/`(78파일) — **8-A 벤더 분리 먼저** | `presentations/qt/features/scan/` (모드 분할은 [Phase 8](./phase8-feature-scan-split.md)) |
| B-9 | `Test/AgingTestController`(552) | `presentations/qt/features/diagnostics/` |

> **B-8 앞에 qcustomplot 을 뺀다.** `Scan/ImageAnalyzer/qcustomplot.{cpp,h}` **43,303 LOC** 는 서드파티다. `third_party/qcustomplot/` 로 옮기면 `Scan` 이 83,075 → **39,772** 가 된다. [Phase 8-A](./phase8-feature-scan-split.md) 로 미루지 말고 **여기서 한다** — 이동 대상이 절반으로 준다.

### Step 4-C. QML → `presentations/qt/qml/`

§1.4 매핑표대로. `.qrc` 를 feature 별로 분할한다.

| # | 작업 |
|---|---|
| C-1 | `qml/shell/` — `main.qml` · `MainView` · `IntroProcessView` · `SelectModeView` · `LoginView` · `CheckUserRegistrationView` |
| C-2 | `qml/common/` — `UIControlGroup` · `UIControlRect` · `SingleShotTimer` · `ElapsedTimer` · `AlertSavePreset` · `SecurityWarning` · `CopyrightView` · `DiskSpaceView` · `DummyView` |
| C-3 | `qml/features/<name>/` — 접두사 매핑 (Scan 33 · Patient 9 · Ambulance 3 · Setting 23 · UserRegistration 26 …) |
| C-4 | `.qrc` 분할 — feature 별. `qrc:/QML/main.qml` 경로가 바뀌므로 **`main.cpp` 의 `view.setSource()` 및 QML 내부 상대 import 를 일괄 갱신** |
| C-5 | `Mobile/` · `Desktop/` 하위 2쌍(`ImageAnalyzer.qrc`) 처리 — 플랫폼 분기이므로 `platforms/` 규약과 정합 확인 |

> **C-4 가 이 phase 의 조용한 함정이다.** QML 은 컴파일 타임에 경로를 검증하지 않으므로 **경로 오류가 런타임에야 드러난다.** 빌드 성공이 검증이 아니다 — [Phase 1](./phase1-regression-baseline.md) 의 헤드리스 실행이 여기서 값을 한다.

### Step 4-D. `presentations/qt/core/` 공통 베이스

cms-app 대응: `managed_page` · `device_listener_mixin` · `cloud_listener_mixin` · `logging_listener_mixin`(**cctv r1 phase10** (cctv `docs/refactoring/r1/phase10-cms-device-aware-page.md`)).

moana 에도 같은 반복이 있는지 먼저 확인한다 — 뷰컨트롤러 11개가 장비 연결 상태·클라우드 상태를 각자 구독하는 보일러플레이트가 있으면 추출한다. **없으면 만들지 않는다.**

### Step 4-E. `ControlCommand` 분해

`DeviceControl/ControlCommand.cpp` **2,672 LOC** 가 모든 feature 의 장비 명령을 담고 있다. cms-app 이 `device_control` 을 `ptz`·`image-tuning`·`alarm` 으로 분해한 것과 같은 안티패턴이다.

| 부분 | 목표 |
|---|---|
| 소켓·채널·큐 (`SononDeviceConnector` · `CommandQueue`) | `core/services/sonon` (Phase 3 에서 이미 이동한 `SononClient` 옆) |
| 명령 정의 (`SononCommand.h` · `SononReserveCommand.h`) | `core/protocol` |
| 스캔 파라미터 명령 | `features/{scan-b,doppler-cf,doppler-pw,mmode}/data` — [Phase 8](./phase8-feature-scan-split.md) 에 예약 |
| 프리셋·설정 명령 | `features/settings/data` — [Phase 5](./phase5-feature-worklist-settings.md) 에 예약 |
| 펌웨어 명령 | `features/firmware-update/data` — [Phase 9](./phase9-feature-ambulance-ble.md) 에 예약 |
| `ScanContextSetting`(.cpp+.h **837**) | Phase 8 에서 확정 |

**이 phase 에서는 전송부만 `core/` 로 빼고, 명령 발행부는 `app/Sources/DeviceControl` 에 남긴다.** 갈 곳(`features/*/data`)이 아직 없기 때문이다. **분해 지점을 표로 확정하는 것이 이 단계의 산출물**이다.

### Step 4-F. 파일명 규약 전환

| 대상 | 현행 | 목표 |
|---|---|---|
| 소스 파일 | `ScanPlayer.cpp` | `scan_player.cpp` |
| Qt 프레젠테이션 | `ScanViewController.cpp` | `qt_scan_view_controller.cpp` |
| 클래스명 | `CScanPlayer` | **바꾸지 않는다** |

> **클래스명을 건드리지 않는 이유**: 파일 이동 + 파일명 변경만으로도 diff 가 크다. 클래스명까지 바꾸면 **동작 보존 판정이 diff 에 묻힌다.** `C` prefix 제거는 r1 범위 밖이고, 필요하면 별도 phase 로 낸다.
>
> **`git mv` 로 옮긴다** — 이력이 끊기면 [../../review/change-cost.md](../../review/change-cost.md) 류의 후속 분석이 불가능해진다. moana 는 이미 세대 전환으로 이력이 두 번 끊긴 조직이다([architecture.md](../architecture.md)).

### Step 4-G. `make check-layers` 규칙 추가

```
presentations/**  은  features/ · core/  를 include 할 수 있다   (ADR-001)
core/**  ·  features/**  이  presentations/  를 include 하지 않는다
```

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | 계층 방향 | `grep -rn '#include "presentations/' src/core/ src/features/` | **0줄** |
| 4.2 | composition root | `grep -rn 'setContextProperty' src/` | **`app/main.cpp` 1파일** |
| 4.3 | 수동 소멸 제거 | `grep -c 'delete ' src/app/main.cpp` | 0 (스택 할당) |
| 4.4 | 벤더 분리 | `ls src/presentations/qt/features/scan/ \| grep qcustomplot` | 0건 |
| 4.5 | QML 평탄화 해소 | `ls src/presentations/qt/qml/*.qml \| wc -l` | 0 (전부 하위 디렉토리) |
| 4.6 | **QML 런타임 경로** | `QT_QPA_PLATFORM=offscreen make test-golden` | 통과. **빌드 성공은 검증이 아니다** |
| 4.7 | 6타깃 빌드 | `make build-all` | exit 0 |
| 4.8 | **동작 불변** | `make test-golden` + **종료 경로 수동 확인** | 통과 |
| 4.9 | 이력 보존 | `git log --follow` 가 이동 전 이력을 따라간다 | ✓ |
| 4.10 | 계층 검사 | `make check-layers` | exit 0 |

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **이 phase 가 r1 최대다** (cms-app 기준 53%) | 한 phase 가 비대해져 출하 계통 복귀가 늦어진다 | **B-1~B-9 · C-1~C-5 를 각각 별도 커밋으로.** feature 하나씩 옮기고 매번 병합. 장수 브랜치 금지([principles.md §1](../principles.md)) |
| **QML 경로 오류가 런타임에야 드러난다** | 빌드는 통과하는데 화면이 안 뜬다 | 4.6 이 게이트. **Phase 1 의 헤드리스 실행이 없으면 이 phase 를 안전하게 못 한다** |
| **스택 할당 전환으로 소멸 순서가 바뀐다** | 종료 시 크래시 · 저장 누락 | A-3 을 **별도 커밋**으로. 골든이 종료 경로를 못 잡으므로 6타깃 수동 종료 확인. 위험하면 **스택 전환을 미루고 `AppServices` 구조체만 먼저** |
| **파일명 일괄 변경이 diff 를 폭발시킨다** | 리뷰 불가 · 회귀 은폐 | `git mv` 로 rename 을 명시. **내용 변경 커밋과 rename 커밋을 분리** |
| **`service_QT693` 병행 개발 충돌이 최대** | 대규모 이동 | feature 단위 짧은 창. **힐세리온과 순서 협의 필수** — 그들이 지금 만지는 feature 를 마지막으로 |
| `.qrc` 분할이 Android/iOS 리소스 패키징을 깨뜨린다 | 특정 타깃만 리소스 누락 | C-4 를 6타깃 전부에서 확인. `app.pro` 의 `android{}`·`ios{}` 블록에 `RESOURCES` 가 따로 있다(`:638`·`:936`) |
| `presentations/qt/core/` 를 근거 없이 만든다 | 쓰지 않는 추상화 | Step 4-D 는 **반복이 실제로 있을 때만**. 없으면 건너뛴다 |
| `ControlCommand` 분해가 이 phase 에서 안 끝난다 | 미완 상태로 Phase 5 진입 | **의도된 것이다.** 여기서는 전송부만 빼고 발행부는 남긴다. §3 Step 4-E 표가 Phase 5~9 의 계약 |

---

## 6. 이 phase 가 여는 것

`features/` 자리가 비워진다. 이 phase 뒤 `app/Sources/` 에 남는 것은 **도메인 로직 후보**뿐이고, 그것이 Phase 5~9 의 작업 대상 목록이 된다.

그리고 **`sonex` 이식 관점에서 이 phase 가 결정적이다.** Qt→Flutter 이식에서 presentation 은 어차피 다시 쓴다. UI 를 feature 밖으로 빼 두면 **이식 단위가 `features/<name>/{domain,data}` 로 좁혀진다** — [architecture.md §4.3](../architecture.md) 이 말하는 "이식 단위가 feature 하나로 명확해진다" 의 실제 구현이 여기다.

---

## 7. cross-reference

- [plan.md §3.2·§5](./plan.md)
- **cms-app ADR-002** (cms-app `docs/adr/adr-002-feature-first-folder-structure.md`) — UI 를 최상위 `presentations/` 에 두는 결정
- **cms-app ADR-003** (cms-app `docs/adr/adr-003-composition-root-dependency-injection.md`) — `main.cpp` + `AppServices` 스택 할당
- **cctv r1 phase10** (cctv `docs/refactoring/r1/phase10-cms-device-aware-page.md`) — `presentations/qt/core/` 의 공통 베이스 선례
- [phase8-feature-scan-split.md](./phase8-feature-scan-split.md) — 여기서 옮긴 `Scan/` 을 4분할한다
- [architecture.md §4.3](../architecture.md) — `sonex` 이식 파이프라인
