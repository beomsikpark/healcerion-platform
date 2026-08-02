# Phase 6 — 빌드 · 패키징 · 라이선스 이행

> **상태**: 미시작
> **범위**: 출시 가능한 빌드·패키지를 만들고, **LGPLv3 이행 의무를 실제로 충족**시킨다.
> **선행**: [Phase 5](./phase5-measure-controls.md)
> **후행**: 없음 — r2 의 마지막 phase
> **근거**: [plan.md §0.4·§3 Phase 6](./plan.md) · [../legacy/licensing.md](../legacy/licensing.md)
> **실측 기준**: `moana` `origin/service_QT693`.

---

## 1. 배경

### 1.1 빌드 시스템은 바꾸지 않는다

`moana` 는 **qmake 전용**이고 자체 `CMakeLists.txt` 가 **0건**이다([../../review/moana-app.md §2](../../review/moana-app.md)). 추적된 136건은 전부 벤더 `lib/` 트리다.

**빌드 시스템 교체와 계층 교체를 동시에 하면 회귀 원인을 가를 수 없다.** 이 phase 는 **qmake 를 유지**하고, CMake 이행은 이 계획 밖이다.

> 다만 SDK/ADK 는 MSBuild·CMake·`ndk-build` 3갈래다([r1 Phase 0-F](../r1/phase0-build-reproducibility.md)). **qmake 가 그 산출물을 소비하는 형태**이므로 진입점 정합이 필요하다(§2 Step 6-B).

### 1.2 라이선스 이행 의무가 현재 0/4 다 `[../legacy/licensing.md §4]`

| LGPLv3 요구 | 근거 | 현재 |
|---|---|---|
| LGPLv3 + GPLv3 전문 동봉 | §4(a) | **없음** |
| Qt(LGPL) 사용 사실의 눈에 띄는 고지 | §4(b) | **없음** — 저작권 한 줄뿐 |
| 소스 취득 경로 | §4(d) | **없음** |
| **재링크 수단** | §4(d)(0) | **없음** — iOS 가 여기 걸린다 |

**iOS 는 Qt 정적 링크**이므로 `§4(d)(0)` 에 따라 **앱 오브젝트 파일 아카이브를 산출·제공하는 릴리스 단계**가 필요하다. 이것은 **상용 라이선스라도 동일**하다(Qt for iOS 가 정적 빌드이기 때문) — 즉 LGPLv3 전환으로 새로 생기는 부담이 아니다.

> **iOS anti-tivoization 은 논점이 아니다** — LGPLv3 §4(e)의 설치 정보 의무는 GPLv3 §6 이 발동할 때만 걸리고, 그것은 **User Product 소유권이 이전되는 거래**를 겨냥한다. 앱스토어 다운로드는 아이폰을 파는 거래가 아니다([../legacy/licensing.md §4](../legacy/licensing.md)).

### 1.3 상용 Qt 이탈의 부작용 둘이 여기서 처리된다

[plan.md §0.4](./plan.md) 대체 대상 ①의 부작용이다.

| # | 내용 | 이 phase 의 처리 |
|---|---|---|
| 1 | **LTS 접근 상실** — `Qt 6.8.5 LTS 는 상용 전용`. 오픈소스는 feature release(6.9.x·6.10)만 | **버전 정책을 정한다**(6-C). 그들이 Android 16KB 대응 해법으로 지목한 것이 6.8.5 LTS 였으므로 **대안 경로가 필요하다** |
| 2 | **오프라인 인스톨러 상실** | **Qt 설치를 재현 가능하게 만든다**(6-C). 이미 빌드머신 Qt 설치본을 **손으로 9건 개조**(ffmpeg 플러그인·`libav*` `.bak` 처리·dependencies XML 편집)하고 있어 부담이 겹친다 |

### 1.4 출시 플랫폼 — 확정됐다 `[2026-08-02]`

**Windows 최우선 · Android·iOS 그다음 · Linux 개발용 · macOS 제외**([plan.md §0.5](./plan.md)).

**이 phase 의 순서가 여기서 정해진다** — 패키징·라이선스 이행물을 **Windows 부터** 내고, **iOS 정적 링크 재링크 아카이브**(§1.2)는 2순위다. **macOS 는 빌드 매트릭스에서 뺀다.**

---

## 2. 진행 단계

### Step 6-A. 라이선스 게이트 — **CI 로 판정한다**

**문서로만 지키면 다음 의존에서 다시 깨진다.**

| # | 작업 |
|---|---|
| A-1 | **의존 인벤토리 생성** — 링크되는 라이브러리 전수와 각각의 라이선스. [r1 Phase 0-C-1](../r1/phase0-build-reproducibility.md) 의 SOUP 인벤토리와 같은 형식(CVE·EOL 열 포함) |
| A-2 | **금지 목록을 CI 판정으로** — GPL·AGPL·상용 표기가 산출물에 링크되면 **빌드 실패**. Qt GPL 전용 애드온(Charts·Data Visualization·Virtual Keyboard·Quick 3D·MQTT·HTTP Server·Lottie·Wayland) 포함 |
| A-3 | **`.pro` 의 `QT +=` 를 화이트리스트로 검사** — 현재 선언은 전부 LGPLv3 범위다([plan.md §0.4](./plan.md)). **새 모듈이 들어오면 게이트가 잡는다** |
| A-4 | **CVIE 잔재 검사** — `HC_CVIE_SUPPORT`·`framework/ContextVision`·`.cov`·`cvie64`·`context_vision` 0건([Phase 5 B-3·B-4](./phase5-measure-controls.md)) |
| A-5 | **QCustomPlot 잔재 검사** — `ENABLE_IMAGE_ANALYZER`·`CCustomPlotItem` 0건([Phase 0 B-3](./phase0-repo-scope-cut.md)) |
| A-6 | **FFmpeg 구성 검사** — GPL 전용 코덱(x264·x265·xvid) 심볼이 링크되지 않는지. Qt Multimedia 백엔드와 벤더 `lib/` **양쪽** |
| **A-7** | **단위테스트를 같은 파이프라인에 얹는다** — Phase 2·3·4·5 가 만든 테스트([plan.md §2.6](./plan.md))를 라이선스 게이트와 함께 돌린다. **`moana` 최초의 CI 이므로 둘을 따로 만들지 않는다** |

### Step 6-B. 빌드 진입점 정합

| # | 작업 |
|---|---|
| B-1 | **qmake 유지**(§1.1). `moana` 의 `build.py`(406 LOC) 래퍼를 정리 |
| B-2 | **SDK/ADK 산출물 소비 경로 확정** — [r1 Phase 2](../r1/plan.md) 의 배포 패키지를 소비하는 형태. **개발자 머신 경로로 받는 현재 방식을 끊는다** |
| B-3 | **버전 고정** — 앱↔SDK 호환 조합 선언([r1 Phase 2-D](../r1/plan.md)). 어느 앱 빌드가 어느 SDK 빌드와 짝인지 저장소에서 확인 가능해야 한다 |
| B-4 | **절대경로 제거** — `moana` 의 `~/QtCommercial/`·`/Users/rio/` 계열. [r1 Phase 0-D](../r1/phase0-build-reproducibility.md) 와 같은 작업이며 **회귀 검사 스크립트도 같은 형태로 만든다** |
| B-5 | **`HC_RELEASE_TARGET` 정리** — 출시 타깃이 하나이므로 변종 분기가 불필요하다([Phase 0 C-4](./phase0-repo-scope-cut.md)). **CE/US 뒤바뀜 출하 사고의 무대였던 곳**이다 |
| B-6 | **커밋된 qmake 산출물 제거** — `app/Makefile` 등. [r1 Phase 0-E](../r1/phase0-build-reproducibility.md) 와 같은 위생 작업 |

### Step 6-C. Qt 배포·버전 정책

| # | 작업 |
|---|---|
| C-1 | **Qt 버전 확정** — 오픈소스 feature release 중 택1. `service_QT693` 이 이행 중인 **6.9.3** 이 자연스러우나, 커뮤니티 6.9.3 대신 LTS 를 권고한 그들 문서(`qt693_migration_estimate.remarkup`)와 **LTS 가 상용 전용이라는 사실**이 충돌한다 — **이 충돌을 명시적으로 해소한다** |
| C-2 | **Android 16KB 페이지 대응 경로 확정**(§1.3-1) — 6.8.5 LTS 를 못 쓰므로 대안이 필요하다. `moana` 는 이미 `QT_MEDIA_BACKEND=android` 우회와 `common-page-size` 플래그를 쓰고 있다([../../review/moana-app.md §9](../../review/moana-app.md)) |
| C-3 | **Qt 설치를 재현 가능하게**(§1.3-2) — 손으로 9건 개조하는 현재 방식을 스크립트화하거나 컨테이너 이미지로 고정 |
| C-4 | **상용 Qt 경로 제거** — `build.py:16` 의 `~/QtCommercial/5.15.2/android`. **Android 가 Qt5 상용에 남아 있는 것이 현재 상태**이므로 Qt6 오픈소스로 이행이 함께 필요하다 |
| C-5 | **혼용 구간을 만들지 않는다** — 전환 중 상용·오픈소스가 겹치면 Qt LA §3.4(ix) 가 쟁점이 된다. 일정 관리 사항이다 |

### Step 6-D. LGPLv3 이행물 산출

| # | 작업 |
|---|---|
| D-1 | **LGPLv3 + GPLv3 전문 동봉**(§4(a)) — 앱 내 라이선스 화면 또는 동봉 문서 |
| D-2 | **Qt 사용 사실 고지**(§4(b)) — 눈에 띄는 위치. 현재는 저작권 한 줄뿐이다 |
| D-3 | **소스 취득 경로 명시**(§4(d)) — 사용한 Qt 버전과 취득처 |
| D-4 | **재링크 수단 산출**(§4(d)(0)) — **iOS 오브젝트 파일 아카이브를 릴리스 파이프라인 산출물로 만든다.** 수동 단계로 두면 릴리스마다 빠진다 |
| D-5 | **서드파티 고지 전체** — Qt 외 OpenCV·DCMTK·FFmpeg·OpenSSL·TFLite 등. **현재 고지 0건**이다([../README.md](../README.md) §라이선스) |
| D-6 | **자사 EULA 정합** — `UsageAgreement_ENG.txt` Article 12(저작권)에 *"LGPL 구성요소 제외"* 문구 추가. **리버스 엔지니어링 금지 조항이 없어 LGPLv3 §4 와의 전형적 충돌은 이미 비껴가 있다** |

### Step 6-E. 패키징·출시

| # | 작업 |
|---|---|
| E-1 | **Windows 패키지를 먼저 낸다**(§1.4). Android·iOS 는 그다음, macOS 는 대상 아님 |
| E-2 | 플랫폼별 패키지 산출 자동화 |
| E-3 | **버전 스탬프** — 산출물에서 소스 커밋을 역추적할 수 있게 |
| E-4 | **저장소 크기 정리 판단** — [Phase 0 D-2](./phase0-repo-scope-cut.md) 가 보류한 벤더 `lib/`(6.56G). 의존이 끊긴 것만 제거하고, **`.git` 이력은 재작성하지 않는다** |

---

## 3. 검증

| # | 항목 | 방법 | 기대 |
|---|---|---|---|
| 3.1 | **라이선스 게이트** | CI 가 금지 라이선스 링크를 판정 | 통과. **위반 시 빌드 실패** |
| **3.1b** | **단위테스트** | 같은 파이프라인(A-7) | **전 Phase 분 통과.** 좌표·명령·프레임·상태·데이터·측정·펌웨어 |
| 3.2 | Qt 모듈 화이트리스트 | `.pro` 의 `QT +=` 검사 | LGPLv3 범위 밖 **0건** |
| 3.3 | CVIE·QCustomPlot 잔재 | grep | **0건** |
| 3.4 | FFmpeg 구성 | 링크 심볼 | GPL 전용 코덱 **0건** |
| 3.5 | **상용 Qt 경로** | `build.py`·`.pro` 에서 `QtCommercial` | **0건** |
| 3.6 | 절대경로 | 검사 스크립트 | **0건** |
| 3.7 | **깨끗한 머신 빌드** | 제3의 머신에서 문서 절차만으로 | 성공 |
| 3.8 | LGPLv3 이행물 | D-1~D-5 산출물 존재 | **4/4** (현재 0/4) |
| 3.9 | iOS 재링크 아카이브 | 릴리스 산출물 | **자동 생성됨**(수동 단계 아님) |
| 3.10 | 버전 추적 | 패키지 → 커밋 | 역추적 가능 |

> **3.1 이 이 phase 의 실질 게이트다.** 나머지는 한 번 해 두면 되지만 이것만은 **다음 의존이 들어올 때 다시 판정**한다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **LTS 를 못 써서 Android 16KB 대응이 막힌다** | 출시 불가 | C-2 를 **조기에 확인**한다. 이미 우회(`QT_MEDIA_BACKEND=android`·`common-page-size`)를 쓰고 있으므로 백지가 아니다 |
| **Qt 설치 재현이 안 된다** | 빌드머신 의존이 남는다 | C-3 — 컨테이너 이미지로 고정. 손 개조 9건이 그대로 남으면 [r1 Phase 0](../r1/phase0-build-reproducibility.md) 이 고친 문제를 앱 쪽에서 반복한다 |
| **iOS 재링크 아카이브를 수동 단계로 둔다** | 릴리스마다 빠진다 — 라이선스 위반 | D-4·3.9 — **파이프라인 산출물로 강제** |
| 라이선스 게이트가 문서로만 남는다 | 다음 의존에서 깨진다 | A-2·3.1 — CI 판정. **이것이 이 phase 의 핵심 산출물이다** |
| **Windows 우선이 iOS 재링크 의무를 늦춘다** | iOS 출시 시점에 §4(d)(0) 미충족이 드러난다 | D-4 를 **iOS 착수와 함께** 건다. Windows 만 보고 "라이선스 끝" 으로 판정하지 않는다 |
| 상용·오픈소스 Qt 혼용 구간 | Qt LA §3.4(ix) 쟁점 | C-5 — 일정 관리로 회피 |
| 빌드 시스템까지 바꾸고 싶어진다 | 회귀 원인 특정 불가 | §1.1 — qmake 유지를 명시. CMake 이행은 별도 논제 |

---

## 5. cross-reference

- [plan.md](./plan.md) §0.4(라이선스 대체 대상)·**§0.5(출시 플랫폼)**·§3 Phase 6
- **[../legacy/licensing.md](../legacy/licensing.md)** — **이 phase 의 라이선스 SOT.** §2(모듈 전수)·§3(타깃별 판정)·§4(이행 의무 0/4)·§5.1(QCustomPlot)
- [phase0-repo-scope-cut.md](./phase0-repo-scope-cut.md) — B-5(`HC_RELEASE_TARGET`)·E-4(`lib/`)의 선행
- [phase5-measure-controls.md](./phase5-measure-controls.md) — CVIE 제거의 실행처. 이 phase 는 **검사**한다
- [../r1/phase0-build-reproducibility.md](../r1/phase0-build-reproducibility.md) — 절대경로·커밋된 산출물·SOUP 인벤토리의 선례
- [../r1/plan.md](../r1/plan.md) Phase 2 — SDK/ADK 배포 패키지·버전 계약(B-2·B-3 의 상대)
- [../../review/moana-app.md](../../review/moana-app.md) §2(빌드)·§9(16KB 대응·출하 사고)
