# Phase 8 — `scan-b` · `doppler-cf` · `doppler-pw` · `mmode` + `recording`

> **상태**: 미시작
> **범위**: r1 최대 작업. `Scan/`(qcustomplot 제외 39,772) + `framework/ScanManager`(4,404) + `framework/Record`(6,571) 을 5개 feature 로.
> **선행**: [Phase 6](./phase6-feature-patient-dicom-cloud.md)(`PatientList↔Scan` 순환 제거) · [Phase 7](./phase7-feature-measure.md)(`Scan→Measure` 25건 정리)
> **후행**: [Phase 10](./phase10-runtime-variant.md)
> **feature 이름은 장비와 공유한다** — [architecture.md §5](../architecture.md)

---

## 1. 배경

### 1.1 절반이 서드파티다

| | LOC |
|---|---:|
| `Scan/` 전체 | 83,075 |
| `Scan/ImageAnalyzer/qcustomplot.cpp` | **35,529** |
| `Scan/ImageAnalyzer/qcustomplot.h` | **7,774** |
| **자체 코드** | **39,772** |

**qcustomplot 43,303 LOC 는 오픈소스 플로팅 라이브러리다.** `app/Sources/Scan/` 안에 통째로 들어와 있어 `Scan` 규모를 2배로 부풀린다.

> **`ENABLE_IMAGE_ANALYZER` 는 `app.pro:74` 에서 주석 처리돼 있다.** 그러나 소스 등록은 `msvc`·`macos` 조건 블록(`:488-497`·`:1135-1144`, 적대적 검증으로 정정 2026-07-29 — 구판은 `win32`·`linux`로 적었으나 실제 블록명은 `msvc{`·`macos{`다. `linux:!android {}` 블록은 1269행에 따로 있고 qcustomplot 을 등록하지 않는다) 안에 있고 그 매크로로 가드되지 않는다 — **데스크톱 빌드(msvc·macos)에서는 컴파일된다.** 모바일(`android{}`·`ios{}`)은 `Mobile/ImageAnalyzer.qrc` 만 넣는다. **착수 시 실제 링크 여부를 확인한다.**

**[Phase 4-B8](./phase4-composition-root-presentations.md) 에서 이미 `third_party/qcustomplot/` 로 뺐다.** 이 phase 는 39,772 LOC 를 다룬다.

### 1.2 god object

| 파일 | LOC | 지표 |
|---|---:|---|
| `Scan/ScanPlayer.cpp` | **7,526** | 메서드 **255개** |
| `Scan/ScanPlayer.h` | 1,589 | 멤버 선언 **415줄** |

**moana 전체에서 가장 큰 자체 파일**이고, 4개 모드의 프레임 파이프라인이 전부 여기 있다.

### 1.3 모드 분기가 178곳에 흩어져 있다

| 모드 | 파일 | 출현 |
|---|---:|---:|
| `PW_MODE` | 23 | 52 |
| `M_MODE` | 21 | 47 |
| `B_MODE` | 16 | 46 |
| `CF_MODE` | 16 | 33 |

`SONON_SCAN_MODE { B_MODE=0, CF_MODE=1, PW_MODE=2, M_MODE=3 }`(`Common/AppCommon.h:80` → Phase 3 에서 `core/entities`).

**"PW 도플러를 바꾼다" 가 지금은 23개 파일을 여는 일이다.** 이 phase 의 목표는 그것을 1개 디렉토리로 만드는 것이다([plan.md §6-5](./plan.md)).

### 1.4 렌더링 계층이 이미 모드별로 갈려 있다

| 파일 | LOC | 모드 |
|---|---:|---|
| `GLFrameB` | 1,882 | B |
| `GLFrameCF` | 1,461 | CF |
| `GLFramePW` | 680 | PW |
| `GLFrameM` | 422 | M |
| `GLFrameViewPWM` | 2,692 | PW+M 공용 |
| `FrameProcessorPWM` | 2,498 | PW+M 공용 |
| `GLBase` · `GLFrame` · `GLFrameView` · `GLCenterLine` | 3,076 | **공통** |

**`*PWM` 이 PW 와 M 을 함께 다룬다** — 둘 다 시간축 스크롤 렌더링이라 공유한다. **분할 시 이 둘의 공통부를 어디에 둘지가 판단점**이다(§2.3).

### 1.5 목적

1. 모드별 feature 4개 + `recording` — **모드 변경이 1개 디렉토리**
2. `ScanPlayer` 7,526 분해 — 1,000 LOC 초과 0 목표([plan.md §6-7](./plan.md))
3. **장비와 같은 feature 이름** — `scan-b`·`doppler-cf`·`doppler-pw`·`mmode`([architecture.md §5](../architecture.md))
4. `framework/` 를 비운다

### 1.6 범위 한계

- **신호처리·렌더링 알고리즘을 다시 쓰지 않는다.** 제품 가치 그 자체다([principles.md §11](../principles.md)) — 위치만
- 모드 전환 UX 를 바꾸지 않는다
- **`HC_SONON_500L`(81파일 556곳) 을 여기서 없애지 않는다.** [Phase 10](./phase10-runtime-variant.md)

---

## 2. 목표 배치

```
src/features/
  scan-b/       domain/  data/  ports/
  doppler-cf/   domain/  data/  ports/
  doppler-pw/   domain/  data/  ports/
  mmode/        domain/  data/  ports/
  recording/    domain/  data/  ports/        ← 현 framework/Record

src/core/
  imaging/scan/                                ← 공통 스캔 파이프라인 (Phase 3 의 core/imaging 하위)

src/presentations/qt/
  core/gl/                                     GLBase · GLFrame · GLFrameView · GLCenterLine
  features/scan-b/  doppler-cf/  doppler-pw/  mmode/
  features/scan-shared/                        SideRulerView · ColormapBar · GraymapBar · ScreenAdjust
  qml/features/<mode>/
```

### 2.1 무엇이 어디로

| 현행 | LOC | 목표 |
|---|---:|---|
| `ScanPlayer`(7,526+1,589) | 9,115 | **분해** — 공통 파이프라인은 `core/imaging/scan`, 모드별은 각 feature `domain/` |
| `ScanView`(2,181+527) · `ScanViewController`(598+205) | 3,511 | `presentations/qt/features/scan-shared/` |
| `GLFrameB`·`GLFrameCF`·`GLFramePW`·`GLFrameM` | 4,445 | 각 모드 `presentations/qt/features/<mode>/` |
| `GLFrameViewPWM`·`FrameProcessorPWM` | 5,190 | §2.3 판단 |
| `GLBase`·`GLFrame`·`GLFrameView`·`GLCenterLine` | 3,382 | `presentations/qt/core/gl/` |
| `SideRulerView`·`ColormapBar`·`GraymapBar`·`ScreenAdjustConverter`·`ImageView`·`BatteryIndicator` | 3,193 | `presentations/qt/features/scan-shared/` |
| `LineBufferTable`·`DispBufferTable`·`DispBuffer` | 618 | `core/imaging/scan` |
| `ScanSetting`(585)·`ScanContextProperty`(152)·`CommandReady`(90) | 827 | 각 feature `domain/` 또는 `core/entities` |
| `ScanPatient`·`ScanPatientDetailView` | 973 | `presentations/` — [Phase 6-E](./phase6-feature-patient-dicom-cloud.md) 순환 정리 결과에 따름 |
| `MouseEventPW`·`MouseEventPWM` | 419 | 각 모드 `presentations/` |
| `SnapshotInfo`·`DummyPlayer`·`DummyView` | 651 | `features/recording` · [Phase 1](./phase1-regression-baseline.md) 자산 |
| `ScanAutoTestController` | 267 | `presentations/qt/features/diagnostics/` ([Phase 4-B9](./phase4-composition-root-presentations.md)) |
| `CustomPlotItem`·`ImageAnalyzerView`·`ScanControlView`·`ScreenAdjust.h`·`ScanSlider.h` | 1,372 | **미배치 — §1.1 이 39,772 자체 코드로 셀 때 이 표에서 누락된 파일들.** `CustomPlotItem`은 qcustomplot 을 감싸는 moana 자체 코드(벤더 아님). 목표 확정 필요 |
| `framework/ScanManager`(4,404) | | 모드별 `domain/` 분배 + 공통은 `core/imaging/scan` |
| `framework/Record`(6,571) | | `features/recording` |

> **적대적 검증으로 재실측(2026-07-29)**: `GLBase` 군은 구판 3,076→3,382(`GLFrameView.cpp` 2,046 이 축소 계산됐던 것으로 보임), `SideRulerView` 군은 2,634→3,193, `SnapshotInfo` 군은 581→651. `Scan/` 78파일을 전수 재검산하면 — 위 표(§2.1, 미배치 행 포함) + §2.2 의 `MeasureView`·`MeasureViewPWM`(5,807) 를 합쳐 **38,400**, 여기에 벤더 qcustomplot **43,303** 을 더하면 **83,075** 로 `Scan/` 전체 LOC 와 정확히 일치한다. 1,372 는 이 전수 재검산 과정에서 §2.1/§2.2 어디에도 이름이 없던 파일들이다.

### 2.2 `MeasureView` 는 여기 없다

`Scan/MeasureView`(3,389+608)·`MeasureViewPWM`(1,381+429) **5,807 LOC**(적대적 검증으로 정정, 2026-07-29 — 구판 4,807은 이 4개 구성요소를 그대로 더해도 나오지 않는 자릿수 오타였다. [phase7-feature-measure.md:37](./phase7-feature-measure.md)의 5,807과 일치)는 **[Phase 7-C](./phase7-feature-measure.md) 에서 `presentations/qt/features/measure/` 로 이미 갔다.**

### 2.3 `*PWM` 공통부 — 이 phase 의 판단점

`GLFrameViewPWM`(2,692) + `FrameProcessorPWM`(2,498) = **5,190 LOC 가 PW 와 M 을 함께 다룬다.**

| 안 | 내용 | 평가 |
|---|---|---|
| **A. `scan-shared` 로 공통화** | 둘 다 `presentations/qt/features/scan-shared/` 에 두고 두 feature 가 쓴다 | **위반 아님** — presentations 계층 내부 공유는 허용. 그러나 "모드 변경이 1개 디렉토리" 가 깨진다 |
| **B. `doppler-pw` 에 두고 `mmode` 가 참조** | `features/A → B` 금지에 걸린다 | ❌ |
| **C. 시간축 스크롤 렌더러를 별도 축으로** | `presentations/qt/core/gl/scrolling_frame_view` 로 승격 | **권장.** 공통부의 정체가 "시간축 스크롤" 이라는 기술 축이므로 `core/gl` 이 맞다 |
| **D. 5,190 LOC 를 실제로 갈라 각 모드로 복제** | 중복 | ❌ [principles.md §7](../principles.md) 위반 |

**착수 시 C 를 전제로 하되, 코드를 읽고 확정한다.** 공통부가 진짜 기술 축인지(스크롤 렌더링) 아니면 두 모드가 우연히 섞인 것인지가 갈림이다.

---

## 3. 진행 단계

**전 단계를 통틀어 각 커밋마다 `make test-golden` + `make build-all`.** 이 phase 는 회귀 위험이 최대다.

### Step 8-A. 벤더 분리 확인

[Phase 4-B8](./phase4-composition-root-presentations.md) 에서 처리됐어야 한다. 안 됐으면 **여기서 먼저 한다.** `third_party/qcustomplot/` + `.pro` 등록. §1.1 주석대로 **실제 링크 여부를 6타깃에서 확인**.

### Step 8-B. 공통 렌더링 승격

`GLBase`·`GLFrame`·`GLFrameView`·`GLCenterLine`(3,076) → `presentations/qt/core/gl/`. **모드 분할보다 먼저** — 이것이 남아 있으면 모드 feature 가 서로를 참조하게 된다.

`SideRulerView`·`ColormapBar`·`GraymapBar`·`ScreenAdjustConverter`(2,634) → `presentations/qt/features/scan-shared/`.

### Step 8-C. `core/imaging/scan` — 공통 파이프라인 추출

`ScanPlayer` 7,526 에서 **모드 무관 부분**을 먼저 뺀다.

| 후보 | 근거 |
|---|---|
| 프레임 수신·버퍼 관리 | `LineBufferTable` · `DispBufferTable` · `DispBuffer` 618 |
| 스캔 컨버전 | 좌표 변환. 모드 무관 |
| 프레임 레이트 | `Common/FrameRate.h`(Phase 3 에서 `core/entities`) |

**메서드 255개를 모드별로 태깅하는 것이 이 단계의 실제 작업**이다. `B_MODE`·`CF_MODE`·`PW_MODE`·`M_MODE` 분기가 178곳이므로 그것이 태깅의 출발점이다.

### Step 8-D~G. 모드별 feature (순서 있음)

**의존이 얕은 것부터. `doppler-pw` 가 가장 흩어져 있으므로 마지막이 아니라 두 번째다** — 패턴이 서기 전에 하면 실패하고, 너무 늦게 하면 앞 단계가 그것을 예상하지 못한 채 굳는다.

| 순서 | feature | 대상 | LOC |
|---|---|---|---:|
| D | **`scan-b`** | `GLFrameB` + B 분기 46곳 + `ScanBControlView.qml`·`ScanBDebugView.qml` | 1,882 + |
| E | **`doppler-cf`** | `GLFrameCF` + CF 분기 33곳 + `ScanCFControlView.qml`·`ScanCFDebugView.qml` | 1,461 + |
| F | **`mmode`** | `GLFrameM` + M 분기 47곳 + `ScanMControlView.qml` | 422 + |
| G | **`doppler-pw`** | `GLFramePW` + PW 분기 52곳 + `MouseEventPW` + `ScanPWControlView.qml`·`ScanPWDebugView.qml` | 680 + |

각 feature 마다:

| # | 작업 |
|---|---|
| 1 | `ports/i_<mode>_device_port.h` — 장비 명령([Phase 4-E](./phase4-composition-root-presentations.md) 에서 예약된 `ControlCommand` 분배분) |
| 2 | `domain/<mode>_service` — 파라미터 검증·모드 전환 규칙. `framework/ScanManager` 해당분 |
| 3 | `data/<mode>_repository` — `core/services/sonon` 호출 |
| 4 | `presentations/qt/features/<mode>/` — `GLFrame*` + 컨트롤 뷰 |
| 5 | `qml/features/<mode>/` |
| 6 | `tests/unit/features/<mode>/` — 파라미터 검증 규칙 |
| 7 | **골든 시나리오에 해당 모드 포함 확인** |

### Step 8-H. `*PWM` 공통부 처리

§2.3 판단. `doppler-pw`·`mmode` 가 둘 다 끝난 뒤에 한다 — **그 시점에야 무엇이 진짜 공통인지 보인다.**

### Step 8-I. `ScanPlayer` 잔여 해체

D~H 를 거치면 `ScanPlayer` 는 껍데기만 남는다. 남은 것을 `core/imaging/scan` 과 각 feature 로 최종 분배하고 **파일을 삭제**한다.

### Step 8-J. `features/recording`

`framework/Record`(6,571) — `BackupFileReader`/`Writer` · `RecordFileReader`/`Writer`, `HEAL` 태그 포맷.

**마지막에 하는 이유**: [Phase 1](./phase1-regression-baseline.md) 의 골든 기준선이 이 포맷을 읽고 쓴다. 이 phase 전체의 판정 수단이므로 **판정 수단을 마지막에 건드린다.**

| # | 작업 |
|---|---|
| J-1 | `ports/i_record_storage_port.h` |
| J-2 | `domain/record_service` — 포맷 정의·세션 규칙 |
| J-3 | `data/` — 파일 I/O |
| J-4 | `DummyPlayer`·`DummyView`·`SnapshotInfo` 재배치 — [Phase 1-A](./phase1-regression-baseline.md) 의 녹화 재생 경로 |
| J-5 | **포맷 바이트 호환 검증** — 기존 녹화 파일이 그대로 읽힌다 |

### Step 8-K. `framework/` 제거

`ScanManager`·`Record` 가 비면 `framework/` 디렉토리와 `framework.pro` 가 사라진다. `moana.pro` 의 `SUBDIRS` 정리.

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | **feature 응집** | `grep -rln 'PW_MODE' src/features/` | **`doppler-pw` 만** (모드 4종 각각) |
| 4.2 | feature 간 참조 | `grep -rn '#include "features/' src/features/{scan-b,doppler-cf,doppler-pw,mmode,recording}` | 자기 것 외 0줄 |
| 4.3 | UI 격리 | `grep -rn '<QQuick\|<QtWidgets\|<QOpenGL' src/features/` | 0줄 |
| 4.4 | **파일 크기** | 자체 코드 1,000 LOC 초과 | **0개** |
| 4.5 | `ScanPlayer` 소멸 | `ls src/**/scan_player.*` | 0건 |
| 4.6 | `framework/` 제거 | `ls framework/` | 없음 |
| 4.7 | 벤더 분리 | `grep -rn qcustomplot src/` | 0건 |
| 4.8 | **4모드 골든** | `make test-golden` — B·CF·PW·M 전부 | 통과 |
| 4.9 | **녹화 포맷 호환** | 기존 `HEAL` 파일 재생 | 성공 |
| 4.10 | 유닛 테스트 | `make test-unit` | 5 feature 전부 존재 |
| 4.11 | 6타깃 빌드 | `make build-all` | exit 0 |
| 4.12 | 계층 검사 | `make check-layers` | exit 0 |
| 4.13 | **장비 이름 정합** | `scan-b`·`doppler-cf`·`doppler-pw`·`mmode` 가 장비 쪽 feature 이름과 동일 | ✓ |

> **4.1 이 이 phase 의 성공 정의다.** [plan.md §6-5](./plan.md) 의 "PW 파라미터 추가가 한 디렉토리 안에서 끝난다" 가 grep 으로 판정된다.

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **r1 에서 회귀 위험이 가장 크다** | 스캔은 제품의 본체다 | **모드 하나씩, 각각 별도 커밋 + 골든.** D→E→F→G 사이에 반드시 병합 |
| **`ScanPlayer` 255 메서드 분해가 크다** | 한 번에 하면 판정 불가 | 8-C(공통 추출) → 8-D~G(모드별) → 8-I(잔여) 3단. **매 단계 골든** |
| **`*PWM` 5,190 LOC 의 소속 미확정** | 잘못 두면 두 모드가 결합 | §2.3 — **8-H 로 미룬다.** PW·M 이 둘 다 끝난 뒤에 판단 |
| **신호처리·렌더링을 "정리" 하고 싶어진다** | 영상 품질 회귀 | [principles.md §11](../principles.md) — **위치만.** diff 에서 알고리즘 본문 변경 0줄 확인 |
| **`recording` 을 건드리면 골든이 깨진다** | 판정 수단 상실 | **8-J 를 마지막에.** J-5 포맷 호환 검증. 깨지면 이 phase 전체가 미검증 상태가 된다 |
| **모바일/데스크톱 렌더링 차이** | 특정 타깃만 회귀 | 골든은 Linux 기준이라 Android·iOS 를 못 덮는다. **6타깃 빌드 + 사내 QA 병행** — 이 phase 는 특히 |
| `HC_SONON_500L` 556곳이 모드 코드에 섞여 있다 | 분할 중 변종 로직 유실 | **여기서 없애지 않는다.** `#ifdef` 를 그대로 들고 이동. Phase 10 이 처리 |
| **`service_QT693` 병행 개발 충돌 최대** | `Scan/` 은 그들이 지금 고치는 곳이다(최근 60커밋의 스캔 모드 전환 버그) | **힐세리온과 순서 협의 필수.** 그들이 작업 중인 모드를 마지막 순서로 재배치 |
| 8-H 결과가 §2.3 안 C 와 다르다 | 앞 단계 재작업 | 8-B 에서 `presentations/qt/core/gl/` 을 이미 만들어 뒀으므로 C 로의 이동 비용이 낮다 |

---

## 6. cross-reference

- [plan.md §3.4·§5·§6](./plan.md)
- [architecture.md §5](../architecture.md) — 장비·클라이언트 공통 feature 이름
- [phase4-composition-root-presentations.md §3 Step 4-E](./phase4-composition-root-presentations.md) — `ControlCommand` 분배 계약
- [phase7-feature-measure.md](./phase7-feature-measure.md) — `MeasureView` 는 그쪽으로 갔다
- [phase10-runtime-variant.md](./phase10-runtime-variant.md) — `HC_SONON_500L` 등 변종 처리
- [../../review/moana-app.md §4·§9](../../review/moana-app.md) — 스캔 기능 실측과 최근 회귀
