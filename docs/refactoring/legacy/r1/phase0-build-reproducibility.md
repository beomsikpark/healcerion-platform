# Phase 0 — 빌드 재현

> **상태**: 미시작
> **범위**: `client/legacy/moana` 빌드 진입점 · 버전 정본 · 릴리스 타깃 정본. **소스 코드 구조는 건드리지 않는다.**
> **선행**: 없음. r1 의 첫 phase.
> **후행**: [Phase 1](./phase1-regression-baseline.md) — 기준선을 잡으려면 먼저 빌드가 재현돼야 한다.
> **근거**: [principles.md §2](../principles.md) — *"바꾼 결과가 기존과 같은지 확인할 수 없으면 리팩토링이 아니라 재작성이다."*
> **실측 기준**: `origin/service_QT693` @ `7b26a9b27` (2026-07-27)

---

## 1. 배경

### 1.1 지금 빌드가 특정 머신에 묶여 있다

| # | 실측 | 위치 |
|---|---|---|
| 1 | qmake 산출 `Makefile` 이 **커밋돼 있다**. `QMAKE = /Users/rio/Qt6/6.6.3/macos/bin/qmake` | 루트 `Makefile` |
| 2 | Qt 경로 하드코딩 — `~/QtCommercial/5.15.2/android` · `~/Qt6/6.6.3/ios` · `C:\QtCommercial\5.15.2\winrt_x64_msvc2019` | `build.py:18-19,35` |
| 3 | Android 툴체인 하드코딩 — NDK `21.3.6528147` · SDK `~/Library/Android/sdk` · `JAVA_HOME=/Library/Java/.../jdk1.8.0_131.jdk` | `build.py:21-24` |
| 4 | 서명 키스토어가 **저장소 밖 부모 디렉토리**를 가리킨다 — `os.path.dirname(SRC_ROOT)/hermioneDroid.jks` | `build.py:25` |
| 5 | iOS/Xcode 하드코딩 — team ID 2개, `/Applications/Xcode.app/Contents/Developer` | `build.py:29-31` |
| 6 | Windows SDK 절대경로 — `C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\...` 4개 | `build.py:42-45` |
| 7 | `.pro` 에도 절대경로 — `INCLUDEPATH += -C:/Program Files(x86)/Windows Kits/10/include/10.0.20348.0/um` | `framework/framework.pro:384`(적대적 검증으로 정정, 2026-07-29 — 구판은 `app/app.pro:384`로 오귀속했으나 그 줄은 무관한 헤더 목록이다) |
| 8 | macOS Homebrew Cellar 절대경로 — `/usr/local/Cellar/opencv/4.7.0_2/include/opencv4` 등 | `framework/framework.pro:665,670,723,727` |

**belle-fw 의 `/home/jacob/...` 와 같은 병리다**([../../review/belle-gaps.md](../../review/belle-gaps.md)). 앱 쪽도 같은 상태라는 것이 이 phase 의 발견이다.

### 1.2 정본이 갈라져 있고 이미 어긋났다

**버전 문자열 3곳:**

| 위치 | 값 | 용도 |
|---|---|---|
| `framework/Common/Def.cpp:9` | **`M2.03.26`** | 런타임. `Def::APP_VERSION` — 클라우드 보고 · DB 마이그레이션 판정 · 정보 화면 |
| `build.py:8` | `M2.03.25` | 패키징 |
| `app/app.pro:511` | `2.3.25.121` | Windows 패키지 버전 |

**세 개가 서로 다르다.** `Def::APP_VERSION` 은 `AppSetting.cpp` 4곳 · `Settings.cpp` · `CloudAPIController.cpp` 에서 실제 판정에 쓰이므로, 패키징 버전과 어긋나면 **설치된 패키지 버전과 앱이 보고하는 버전이 다르다.**

**릴리스 타깃 목록 2곳:**

| 위치 | 값 |
|---|---|
| `build.py:47` | `['CE', 'US', 'OTHER', 'RESEARCH']` |
| `app/app.pro:27-41` · `framework/framework.pro:26-40` | `OTHER` · `LOCAL` · `CE` · `US` · `RU` |

교집합은 `CE`·`US`·`OTHER` 뿐이다. 결과:

- **`RESEARCH`** — `build.py` 는 정식 타깃으로 다루고 프로비저닝 프로파일까지 갖는데(`:50`), `.pro` 의 어떤 `equals()` 에도 걸리지 않아 **`HC_RELEASE_*` 매크로가 하나도 정의되지 않은 채 빌드된다.**
- **`RU`** — `build.py:103` 에 `mMode300CEnable = 'true' if target=='RU' else 'false'` 가 있으나 `:377` 의 `if _.upper() in VALID_TARGETS` 필터가 `RU` 를 걸러내므로 **도달할 수 없다.** 반면 `.pro` 쪽은 `HC_RELEASE_RU` 를 정의하고 소스 **14파일 39곳**이 그것을 본다.
- **`LOCAL`** — `.pro` 에만 있다.

### 1.3 타깃이 두 파일에 수동으로 들어간다

```
app/app.pro:17          error("HC_RELEASE_TARGET is not defined - pass it explicitly
                         (e.g. qmake moana.pro HC_RELEASE_TARGET=US)
                         using the same value as framework.pro")
framework/framework.pro:16   ... using the same value as app.pro")
```

**에러 문구 자체가 "두 파일에 같은 값을 넣어라" 라고 말한다.** 이 hard-error 는 [CE/US 뒤바뀜 출하 사고](../../review/moana-app.md) 이후 추가된 것인데, **미정의**는 잡아도 **불일치**는 잡지 못한다. `app.pro` 에 `CE`, `framework.pro` 에 `US` 를 넘기면 조용히 빌드된다.

### 1.4 목적

1. 깨끗한 머신에서 체크아웃 → 문서화된 절차 → **6개 타깃 산출물**
2. 버전 · 릴리스 타깃 선언을 **각 1곳**으로
3. `make` 진입점 — 이후 phase 의 CI·회귀 판정이 여기에 붙는다

### 1.5 범위 한계

- **`lib/` 벤더 트리(6.56GB)는 손대지 않는다.** 의존성 관리는 별건이고, 이 phase 는 *경로*만 다룬다
- **Qt 버전을 올리지 않는다.** 6.6.3 → 6.9.3 이행은 힐세리온이 진행 중인 별개 작업이다
- **소스 파일을 옮기지 않는다.** 구조 변경은 Phase 2 부터

---

## 2. 진행 단계

### Step 0-A. 커밋된 qmake 산출물 제거

| 작업 | 대상 |
|---|---|
| 추적 해제 | 루트 `Makefile`(qmake 생성, `/Users/rio/...` 포함) |
| `.gitignore` 추가 | `Makefile` · `Makefile.*` · `.qmake.stash` · `build-moana/` · `moc_*` · `qrc_*` · `ui_*` |
| 확인 | `git ls-files` 결과에 생성물이 남지 않는다 |

> 이 파일이 남아 있으면 새 체크아웃에서 `make` 가 **존재하지 않는 macOS 경로의 qmake** 를 부른다.

### Step 0-B. 툴체인 경로 외부화

`build.py` 상단 하드코딩을 설정 파일 + 환경변수로 옮긴다.

| 키 | 현재 하드코딩 | 대체 |
|---|---|---|
| `QTDIR_ANDROID` | `~/QtCommercial/5.15.2/android` | `toolchain.ini` / `MOANA_QTDIR_ANDROID` |
| `QTDIR_IOS` | `~/Qt6/6.6.3/ios` | 〃 |
| `QTDIR_WINDOWS` | `C:\QtCommercial\5.15.2\winrt_x64_msvc2019` | 〃 |
| `ANDROID_NDK_ROOT` | `~/Library/Android/sdk/ndk/21.3.6528147` | 〃 (버전은 값으로 명시) |
| `ANDROID_SDK_ROOT` | `~/Library/Android/sdk` | 〃 |
| `JAVA_HOME` | `.../jdk1.8.0_131.jdk/...` | 〃 |
| `ANDROID_KEYSTORE_FILE` | `dirname(SRC_ROOT)/hermioneDroid.jks` | `MOANA_ANDROID_KEYSTORE` — **저장소 상대경로 금지** |
| `IOS_DEV_TEAM` / `_ENTERPRISE` | 리터럴 2개 | 〃 |
| `XCODE_DEV_DIR` | `/Applications/Xcode.app/...` | `xcode-select -p` 로 탐지 |
| Windows Kits 4종 | `10.0.19041.0` 리터럴 | `vswhere` / 환경변수 |

`.pro` 쪽:

| 위치 | 작업 |
|---|---|
| `framework/framework.pro:384` | `INCLUDEPATH += -C:/Program Files(x86)/Windows Kits/...` — **선행 `-` 는 오타로 보인다**. 변수화하며 함께 확인 |
| `framework/framework.pro:665,670,723,727` | Homebrew Cellar 절대경로 → `pkg-config` 또는 변수 |

**미탐지 시 명시적 에러**를 낸다. 조용한 폴백은 지금 문제의 재생산이다.

### Step 0-C. 버전 정본 1곳

```
version.txt  (또는 build/version.pri)   ← 정본
   ├─ framework/Common/Def.cpp  : 빌드 시 생성 또는 매크로 주입
   ├─ build.py                  : 읽는다
   └─ app/app.pro:511 VERSION   : 읽어서 x.y.z.build 로 변환
```

| 항목 | 판정 |
|---|---|
| 정본 후보 | `Def::APP_VERSION` 이 **실제 판정에 쓰이는 값**이므로 이것이 기준. 정본 파일에서 `Def.cpp` 를 생성하거나 `DEFINES += HC_APP_VERSION=` 로 주입 |
| 회귀 위험 | `Settings.cpp:1290` 이 저장된 `appVer` 와 비교해 **DB 마이그레이션을 판정**한다. 값 형식이 바뀌면 전체 사용자에게 마이그레이션이 걸린다 → **형식(`M2.03.26`)을 유지**한다 |
| 판정 | 세 곳이 같은 값을 낸다. `grep -rn 'M2\.03\.' --include='*.cpp' --include='*.pro' --include='*.py'` 결과가 정본 1곳 |

### Step 0-D. 릴리스 타깃 정본 1곳

```
build/targets.pri   ← 정본: CE · US · RU · LOCAL · OTHER · RESEARCH
   ├─ app/app.pro         : include
   ├─ framework/framework.pro : include
   └─ build.py            : 파싱
```

| 작업 | 내용 |
|---|---|
| D-1 | 6개 타깃을 정본에 정의. 각 타깃 → `HC_RELEASE_<X>` 매핑을 **한 번만** 적는다 |
| D-2 | `RESEARCH` 를 `.pro` 에 추가 — 현재 무정의 빌드 |
| D-3 | `RU` 를 `build.py:47 VALID_TARGETS` 에 추가 → `:103` 의 죽은 분기 활성화 |
| D-4 | `LOCAL` 을 `build.py` 에 추가 |
| D-5 | `app.pro`·`framework.pro` 의 개별 `error()` 를 정본의 검증 1곳으로. **불일치 자체가 불가능해진다** — 두 파일이 같은 파일을 include 하므로 |

> **동작 변화가 발생하는 유일한 지점이 D-2·D-3 이다.** `RESEARCH` 빌드는 지금까지 `HC_RELEASE_*` 없이 나갔고, `RU` 빌드는 `build.py` 로는 만들 수 없었다. **두 타깃의 현행 산출물이 무엇이었는지를 힐세리온에 확인한 뒤 적용한다** — 우리가 조용히 바꿀 항목이 아니다.

### Step 0-E. `make` 진입점

cctv-platform 의 `make` 인터페이스 규약을 따른다([precedent-cctv.md](../precedent-cctv.md)).

| 타겟 | 동작 |
|---|---|
| `make help` | 진입점 |
| `make doctor` | 툴체인 탐지 결과 표시 (Qt · NDK · SDK · JDK · Xcode · Windows Kits) |
| `make build TARGET=<CE\|US\|RU\|LOCAL\|OTHER\|RESEARCH> PLATFORM=<android\|ios\|uwp\|macos\|linux\|windows>` | 단일 산출물 |
| `make build-all` | 6타깃 |
| `make clean` | `build-moana/` 제거 |

`build.py` 를 버리지 않는다 — `make` 가 그것을 부른다. **인터페이스를 표준화하되 구현은 유지**한다.

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 생성물 미추적 | `git ls-files \| grep -E '^Makefile$\|moc_\|qrc_'` | 0줄 |
| 3.2 | 절대경로 잔재 | `grep -rn '/Users/\|/home/\|C:\\\\Program\|/usr/local/Cellar' build.py app/app.pro framework/framework.pro` | 0줄 (설정 파일 예시 주석 제외) |
| 3.3 | 버전 정본 | `grep -rn 'M2\.03\.' --include='*.cpp' --include='*.pro' --include='*.py'` | **1곳** |
| 3.4 | 타깃 정본 | `grep -rn 'VALID_TARGETS\|equals(HC_RELEASE_TARGET' build.py app/app.pro framework/framework.pro` | 정본 include 만 |
| 3.5 | 타깃 불일치 불가 | `app.pro` 에 CE, `framework.pro` 에 US 를 각각 주는 것이 **구조적으로 불가능** | 정본 1파일 include |
| 3.6 | 깨끗한 체크아웃 빌드 | 새 머신 clone → `make doctor` → `make build TARGET=CE PLATFORM=android` | exit 0, APK 산출 |
| 3.7 | 6타깃 | `make build-all` | 6개 산출물 |
| 3.8 | **동작 불변** | Phase 0 전후 동일 타깃 바이너리의 동작 대조 | 산출물 동일 또는 차이가 버전 문자열뿐 |
| 3.9 | 소스 무변경 | `git diff --stat` 에 `app/Sources/` · `framework/*/` 의 `.cpp`/`.h` 변경 **0건** (`Def.cpp` 생성 전환 제외) | ✓ |

> **3.8 이 이 phase 의 진짜 게이트다.** 빌드 시스템을 만졌는데 산출물이 달라졌다면, 지금까지 무엇이 들어갔는지 몰랐다는 뜻이다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| `RESEARCH` 빌드가 지금까지 `HC_RELEASE_*` 없이 나갔다 | D-2 적용 시 **현장 동작이 바뀐다** | 적용 전 힐세리온 확인. 무정의가 의도였다면 정본에 `RESEARCH → (없음)` 을 명시적으로 적는다 |
| `RU` 타깃을 `build.py` 로 만들 수 없었다 | D-3 이 새 산출물을 만든다 | 〃. `build.py:103` 의 `mMode300CEnable` 이 무엇을 켜는지 먼저 확인 |
| 버전 형식 변경이 DB 마이그레이션을 유발 | 전체 사용자 1회 마이그레이션 | 형식 `M2.03.26` 유지. `Settings.cpp:1290` 비교 로직 불변 |
| 툴체인 버전 고정 해제로 빌드가 달라짐 | 산출물 회귀 | 설정 파일에 **현행 버전을 값으로 명시**한다. 외부화 ≠ 자유화 |
| Windows/iOS 검증 환경이 우리에게 없다 | 6타깃 중 일부를 실증할 수 없다 | Android·Linux·macOS 를 먼저 닫고, Windows/UWP·iOS 는 **힐세리온 머신에서 실행 확인**. 미검증 타깃은 미검증으로 표기 |
| `service_QT693` 이 오늘도 커밋된다 | 충돌 | 이 phase 는 소스를 안 만지므로 충돌 면이 `build.py`·`.pro` 로 한정된다. 짧게 끊어 병합 |

---

## 5. cross-reference

- [plan.md §2.6·§5](./plan.md) — 실측 근거와 phase 위치
- [principles.md §2](../principles.md) — 빌드 재현이 모든 것에 선행한다
- [assessment.md](../assessment.md) — 장비 쪽 Buildroot `BR2_EXTERNAL` 과 같은 성격의 작업
- [../../review/moana-app.md §9](../../review/moana-app.md) — CE/US 뒤바뀜 출하 사고
- [../../review/belle-gaps.md](../../review/belle-gaps.md) — 장비 쪽 동일 병리(`/home/jacob/...`)
