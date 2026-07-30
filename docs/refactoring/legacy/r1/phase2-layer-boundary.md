# Phase 2 — 레이어 경계 강제

> **상태**: 미시작
> **범위**: `INCLUDEPATH` 평탄화 해체 · `framework` → `app` 역의존 6건 제거. **파일을 옮기지 않는다.**
> **선행**: [Phase 1](./phase1-regression-baseline.md)
> **후행**: [Phase 3](./phase3-core-layer.md) 이후 전부
> **한 줄**: **지금은 계층을 어겨도 빌드가 통과한다.** 이 phase 가 없으면 이후 feature 분할이 다음 커밋에 다시 섞인다.

---

## 1. 배경

### 1.1 모든 include 가 경로 없는 파일명 하나다

```
app/app.pro:405-418
    INCLUDEPATH += $$PWD/Include
    INCLUDEPATH += $$PWD/Sources
    INCLUDEPATH += $$PWD/Sources/Cloud
    INCLUDEPATH += $$PWD/Sources/Common
    INCLUDEPATH += $$PWD/Sources/DeviceControl
    INCLUDEPATH += $$PWD/Sources/Firmware        ← 존재하지 않는 디렉토리
    INCLUDEPATH += $$PWD/Sources/Main
    INCLUDEPATH += $$PWD/Sources/Measure
    INCLUDEPATH += $$PWD/Sources/PatientList
    INCLUDEPATH += $$PWD/Sources/Scan
    INCLUDEPATH += $$PWD/Sources/Setting
    INCLUDEPATH += $$PWD/Sources/WorkList
    INCLUDEPATH += $$PWD/Sources/Test
    INCLUDEPATH += $$PWD/Sources/Ambulance

app/app.pro:420-433
    INCLUDEPATH += $$PWD/../framework/{Include,Common,SononClient,ImageProc,Record,
                    Database,Dicom,VideoProc,Network,Platform,AudioProc,ScanManager,
                    TensorFlow-Lite,Ambulance}
```

**27개 디렉토리가 전부 평탄화된다.** 그래서 `#include "AppSetting.h"` 를 읽어도 그것이 app 계층인지 framework 계층인지 알 수 없고, **계층을 어긴 include 가 컴파일 에러를 내지 않는다.**

이것이 §1.2 의 순환 12쌍과 §1.3 의 역의존 6건이 생긴 기전이다. 사람이 규율로 막고 있었고, 대체로 지켜졌지만(역의존 6건은 475파일 대비 작다) **도구가 막지 않으므로 반드시 새어 나간다.**

### 1.2 정적 라이브러리가 앱 소스를 include path 에 올린다

```
framework/framework.pro:269
    INCLUDEPATH += $$PWD/../app/Sources

framework/framework.pro:271
    #INCLUDEPATH += $$PWD/../app/Sources/Common     ← 주석 처리 흔적
```

`:271` 이 주석 처리돼 있다는 것은 **누군가 이 의존을 줄이려 했던 흔적**이다. 그러나 `:269` 가 남아 상위 디렉토리를 통째로 올리므로 효과가 없다.

### 1.3 실제 역의존 6건

| # | framework 파일 | include | 실제 대상 |
|---|---|---|---|
| 1 | `SononClient/CtrlChannel.cpp:8` | `"Common/AppSetting.h"` | `app/Sources/Common/AppSetting.h` |
| 2 | `SononClient/SononCtrlPacket.cpp:4` | `"Common/AppSetting.h"` | 〃 |
| 3 | `SononClient/SononDataPacket.cpp:5` | `"Common/AppSetting.h"` | 〃 |
| 4 | `Record/RecordFileWriter.cpp:8` | `"Common/AppSetting.h"` | 〃 |
| 5 | `Record/BackupFileReader.cpp:11` | `"Common/AppSetting.h"` | 〃 |
| 6 | `Database/DataManager.cpp:15` | `"common/AppUtility.h"` | `app/Sources/Common/AppUtility.h` |

**확인 방법**: `app` + `framework` 전체에서 헤더 basename 중복이 **0건**이고, `framework/Common/` 에 `AppSetting.h`·`AppUtility.h` 가 없다. 따라서 위 include 는 전부 `app/Sources/Common/` 을 가리킨다.

**5건이 `AppSetting.h` 하나를 본다.** 즉 실질 대상은 1개 헤더다.

> **`DataManager.cpp:15` 는 별건 결함이다** — `"common/AppUtility.h"` 의 `c` 가 소문자다. 대소문자 구분 파일시스템(Linux)에서는 해석되지 않는다. **Linux 타깃에서 이 파일이 어떻게 컴파일되는지 확인이 필요하다** — 조건부 제외인지, 아니면 Linux 빌드가 이 경로를 안 타는지.

> **검증 시 주의(적대적 검증으로 확인, 2026-07-29)**: `grep -rn '#include "(Common|Scan|...)/' framework/` 처럼 경로 접두어만 보는 패턴은 위 6건 외에 2건을 더 잡는다 — `Record/RecordFileConverter.cpp:9`(`"Common/SononUtil.h"`)와 `Platform/AndroidJNI.cpp:11`(`"Common/JniResultCallback.h"`). 이 둘은 역의존이 **아니다** — `SononUtil.h`·`JniResultCallback.h` 는 `framework/Common/` 에도 존재해(`app/Sources/Common/` 이 아니라) framework 가 자기 자신을 가리킨다. **Step 2-A 로 `framework.pro:269` 를 걷어낸 뒤 실제 컴파일 에러로 남는 것이 6건인지 재확인한다** — 패턴 grep 만으로 "0줄" 목표를 판정하면 이 2건이 거짓 양성으로 남는다.

### 1.4 목적

1. **계층 위반이 컴파일 에러가 된다** — 사람의 규율이 아니라 도구가 막는다
2. 역의존 6건 제거 → `framework` 가 `app` 없이 독립 빌드된다
3. include 가 **어느 계층 것인지 읽어서 알 수 있게** 된다

### 1.5 범위 한계

- **파일을 옮기지 않는다.** `framework/` → `core/`·`platforms/` 재배치는 [Phase 3](./phase3-core-layer.md), 뷰컨트롤러·QML → `presentations/` 는 [Phase 4](./phase4-composition-root-presentations.md)
- **순환 12쌍을 이 phase 에서 끊지 않는다.** app 내부 순환은 파일 이동이 필요하므로 Phase 3 이후
- 디렉토리 이름은 그대로 둔다 — `Sources/` · `framework/` 유지

---

## 2. 진행 단계

### Step 2-A. `framework.pro` 의 app 경로 제거

```diff
- INCLUDEPATH += $$PWD/../app/Sources
- #INCLUDEPATH += $$PWD/../app/Sources/Common
```

**결과: 역의존 6건이 컴파일 에러로 드러난다.** 이 단계의 산출물은 에러 목록 그 자체다 — §1.3 표와 일치하는지 확인한다. 더 나오면 우리 측정이 놓친 것이므로 표를 갱신한다.

### Step 2-B. 역의존 6건 해소

**5건이 `AppSetting.h` 를 본다.** 무엇을 쓰는지에 따라 처리가 갈린다.

| 유형 | 처리 |
|---|---|
| **설정 값을 읽는다** (대부분으로 추정) | 필요한 값만 **인자·생성자로 주입**. `framework` 가 `AppSetting` 자체를 알 필요가 없다 |
| **framework 이 마땅히 알아야 할 값** (예: 프로토콜 타임아웃) | 해당 항목을 `framework/Common/` 으로 내린다 |
| **양방향 상태 공유** | `framework/Common/GlobalContext` 가 이미 있다. 그쪽으로 |

작업 순서:

| # | 대상 | 비고 |
|---|---|---|
| B-1 | `SononClient` 3건 (`CtrlChannel` · `SononCtrlPacket` · `SononDataPacket`) | **프로토콜 계층이 앱 설정을 본다** — 가장 나쁜 형태. [proof/protocol-sot](../proof/protocol-sot/) 정본 도입 시 다시 문제가 되므로 우선 처리 |
| B-2 | `Record` 2건 (`RecordFileWriter` · `BackupFileReader`) | 녹화 경로·포맷 설정으로 추정 |
| B-3 | `Database/DataManager` 1건 | `AppUtility` 의 어느 함수인지 먼저 확인. 소문자 경로 결함(§1.3)도 함께 |
| B-4 | 각 건마다 **[Phase 1](./phase1-regression-baseline.md) 골든 대조** | 프로토콜 패킷 · 녹화 파일 포맷이 골든 대상이라 회귀가 바로 잡힌다 |

### Step 2-C. `app.pro` 의 디렉토리별 `INCLUDEPATH` 제거

```diff
  INCLUDEPATH += $$PWD/Include
  INCLUDEPATH += $$PWD/Sources
- INCLUDEPATH += $$PWD/Sources/Cloud
- INCLUDEPATH += $$PWD/Sources/Common
  ... (12줄)
- INCLUDEPATH += $$PWD/Sources/Firmware      ← 존재하지 않음. 그냥 제거
+ INCLUDEPATH += $$PWD/../framework           ← framework 도 루트만
- INCLUDEPATH += $$PWD/../framework/Include
  ... (14줄)
```

**`$$PWD/Sources` 와 `$$PWD/../framework` 두 줄만 남긴다.** 그러면 모든 include 가 경로 규정형이 된다.

| 이전 | 이후 |
|---|---|
| `#include "AppSetting.h"` | `#include "Common/AppSetting.h"` |
| `#include "ScanPlayer.h"` | `#include "Scan/ScanPlayer.h"` |
| `#include "SononClient.h"` | `#include "SononClient/SononClient.h"` |

**기계적 변환이다** — 헤더 basename 중복이 0건이므로 `basename → 경로` 매핑이 1:1이고, `sed` 로 일괄 처리 가능하다.

| # | 작업 |
|---|---|
| C-1 | `basename → 상대경로` 매핑표 생성 (475파일 중 헤더 전체) |
| C-2 | `app/Sources` · `framework` 전체 `#include "..."` 를 매핑으로 치환 |
| C-3 | `INCLUDEPATH` 27줄 → 2줄 |
| C-4 | 플랫폼별 조건 블록(`android{}` · `ios{}` · `linux{}` · `win32{}`)의 `INCLUDEPATH` 도 확인 — 벤더 라이브러리용은 유지 |
| C-5 | 6타깃 빌드 |

> **이미 부분적으로 그렇게 쓰고 있다** — `ScanAutoTestController.h` 는 `"Common/AppCommon.h"` · `"Common/AppSetting.h"` 로, `DummyPlayer.h` 는 `"Common/Model.h"` 로 이미 경로를 붙였다. 그러면서 같은 파일이 `"ScanContext.h"` · `"SononFrame.h"` 는 경로 없이 쓴다. **관행이 이미 반쯤 와 있고 일관성만 없다.**

### Step 2-D. 계층 규칙을 빌드에 고정

경로 규정형이 되면 규칙을 기계 판정할 수 있다.

| 규칙 | 판정 |
|---|---|
| `framework/**` 이 `Sources/` 로 시작하는 include 를 갖지 않는다 | `grep` |
| `framework/framework.pro` 에 `app` 경로가 없다 | `grep` |
| (Phase 3 이후) `core/**` 이 `features/`·`presentations/` 를 include 하지 않는다 | 〃 |
| (Phase 5 이후) `features/**` 이 `presentations/` 를 include 하지 않는다 | 〃 |
| (Phase 5 이후) `features/**` 에 `<QQuick*>`·`<QtWidgets>` include 가 없다 | 〃 |

**규칙의 정본은 cms-app ADR-001** (cms-app `docs/adr/adr-001-3layer-feature-first-clean-architecture.md`) **이다** — `Presentations → Features → Core`, `Presentations → Core` 직참 허용, 역방향 전부 금지.

**`make check-layers` 로 만들어 CI 에 붙인다.** [Phase 1](./phase1-regression-baseline.md) 의 `make test-golden` 과 나란히 선다.

> 이후 phase 가 계층을 추가할 때마다 이 스크립트에 규칙 1줄이 붙는다. **경계는 문서가 아니라 이 스크립트가 정본이 된다.**

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | framework 독립 빌드 | `framework.pro` 만으로 `libframework.a` | exit 0 |
| 3.2 | 역의존 0 | `grep -rn '#include "\(Common\|Scan\|Measure\|PatientList\|Setting\|Main\|Cloud\|WorkList\|BLE\|Test\|Ambulance\|DeviceControl\)/' framework/` | **0줄** |
| 3.3 | `INCLUDEPATH` 축소 | `grep -c 'INCLUDEPATH += \$\$PWD/Sources' app/app.pro` | **1** |
| 3.4 | 죽은 경로 제거 | `grep -n 'Sources/Firmware' app/app.pro` | 0줄 |
| 3.5 | app 경로 제거 | `grep -n 'app/Sources' framework/framework.pro` | 0줄 |
| 3.6 | 경로 규정형 | `app/Sources`·`framework` 의 자체 include 중 경로 없는 것 | 0건 |
| 3.7 | 6타깃 빌드 | `make build-all` | exit 0 |
| 3.8 | **동작 불변** | `make test-golden` | 통과. **이 phase 는 배선만 바꾸므로 산출물이 달라지면 안 된다** |
| 3.9 | 계층 검사 | `make check-layers` | exit 0 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **Step 2-A 후 에러가 6건보다 많다** | 측정이 불완전했다 | 정상적인 결과다. 에러 목록을 §1.3 표에 반영하고 진행. **컴파일러가 우리보다 정확하다** |
| 플랫폼별 조건 블록에만 있는 역의존을 못 봤다 | Android·iOS·UWP 빌드에서만 깨진다 | Step 2-A 를 **6타깃 전부**에서 확인. Linux 만 보고 넘어가지 않는다 |
| `AppSetting` 의존이 값이 아니라 상태 | 주입으로 안 풀린다 | `framework/Common/GlobalContext` 경유. 그래도 안 되면 **해당 항목만 `framework/Common/` 으로 내린다** — 완벽한 방향보다 역의존 제거가 우선 |
| `DataManager.cpp` 의 소문자 경로가 Linux 에서 원래 안 되던 것 | 고치면 없던 코드가 컴파일된다 | 먼저 **현행 Linux 빌드에서 이 파일이 어떻게 처리되는지 확인**. "고장난 건지 원래 안 되던 건지" 를 가르는 것이 [principles.md §2](../principles.md) 의 요점 |
| include 일괄 치환이 벤더 헤더까지 건드린다 | `lib/` 트리 오염 | 치환 대상을 `app/Sources` · `framework` 로 한정. `lib/` 는 제외 |
| 치환 후 moc 재생성 문제 | 빌드 실패 | 전체 clean 빌드로 확인 |
| `service_QT693` 병행 개발과 충돌 | 대규모 치환이라 충돌 면이 크다 | **Step 2-C 를 한 커밋으로, 짧은 창에** 처리한다. 힐세리온과 타이밍 협의 |

---

## 5. 이 phase 가 여는 것

Phase 3 이후는 전부 "무엇이 무엇을 의존하는가" 를 바꾸는 작업이다. 지금은 **그 질문에 코드가 답하지 않는다** — `#include "AppSetting.h"` 는 아무것도 말해주지 않는다.

이 phase 뒤에는:

- **순환 12쌍이 코드에서 보인다** → Phase 3 이 무엇을 끊어야 하는지 명확
- **계층을 만들 때마다 `make check-layers` 에 규칙 1줄이 붙는다** → 성과가 다음 커밋에 되돌아가지 않는다
- **`framework` 가 독립 빌드된다** → Phase 3 의 `core/`·`platforms/` 재배치가 안전해진다

---

## 6. cross-reference

- [plan.md §2.2·§5](./plan.md) — 실측 근거
- [phase3-core-layer.md](./phase3-core-layer.md) — 독립 빌드된 `framework` 를 `core/`·`platforms/` 로 옮긴다
- [phase4-composition-root-presentations.md](./phase4-composition-root-presentations.md) — UI 를 `presentations/` 로 가른다
- **cms-app ADR-001** (cms-app `docs/adr/adr-001-3layer-feature-first-clean-architecture.md`) — 이 phase 가 강제하려는 의존 규칙의 정본
- [principles.md §7](../principles.md) — 정본은 하나만 둔다
- [../../review/moana-app.md §3](../../review/moana-app.md) — "역의존 없음" 기술의 정정 근거
