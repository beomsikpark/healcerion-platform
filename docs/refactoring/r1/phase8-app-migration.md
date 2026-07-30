# Phase 8 — `sonex-app` 이관

> **상태**: 미시작
> **범위**: `sonex-app`(Flutter)이 Phase 2~6 산출물(정본 wrapper·새 렌더 계약·버전 고정)을 실제로 소비하도록 갈아끼운다. **도메인 기능(워크리스트·측정·DICOM 등)은 바꾸지 않는다 — SDK/ADK 를 소비하는 배선만 바꾼다.**
> **선행**: [Phase 2](./phase2-release-packaging.md)(버전·바이너리 명명) · [Phase 4](./phase4-render-boundary.md)(렌더 계약) · [Phase 5](./phase5-language-wrappers.md)(wrapper 정본)
> **후행**: 없음 — r1 의 마지막 실행 phase
> **근거**: [gap.md §7](../gap.md) · [rendering-boundary.md §5·§7](../rendering-boundary.md) · [../../review/sonex-app.md](../../review/sonex-app.md)
> **실측 기준**: `sonex-app` 코드 직접 확인(2026-07-29)

---

## 1. 배경

### 1.1 왜 필요한가 — 앞의 여섯 phase 는 "쓰이지 않는 정본"으로 남을 수 있다

Phase 0~6 은 `sonex-framework`(SDK+ADK) 저장소 안에서 계약·산출물을 만든다. 그런데 그 산출물을 실제로 쓰는 유일한 제품은 `sonex-app` 이고, 이 저장소는 지금까지 범위 밖으로 남겨져 있었다. 산출물만 만들고 소비처를 갈아끼우지 않으면:

- Phase 5 의 정본 Flutter wrapper 는 만들어지지만 앱은 여전히 자체 바인딩(`lib/services/sdk/`+`lib/services/adk/`, 14파일 약 7,281 LOC)을 쓴다
- Phase 4 의 새 렌더 계약(윈도우 대신 프레임 반환)이 서도 앱은 여전히 `hwnd` 를 관리한다(`scan_controller.dart` 116+61줄)
- Phase 2 의 바이너리 이름 정책이 바뀌면 앱의 수동 로드 목록(`NativeMethods.dart` DLL 15개)이 **그대로 깨진다**

**즉 이 phase 가 없으면 앞의 여섯 phase 가 만드는 가치의 상당수가 실현되지 않는다.**

### 1.2 이 저장소는 별도 미러다

`client/legacy/sonex-app` 은 `sonex-framework` 와 별개 read-only 미러다. **Phase 0-0 과 같은 재배치가 이 phase 자체의 첫 항목이다**(8-0) — 별도 fork base·별도 반영 방식 협의가 필요하다.

### 1.3 현재 상태 — 실측

| 항목 | 실측 |
|---|---|
| SDK 바인딩 | `lib/services/sdk/` 5파일 **3,732 LOC**(`NativeMethods.dart` 1,869 · `record_reader_ffi` 1,010 · `record_writer_ffi` 597 외) |
| ADK 바인딩 | `lib/services/adk/` 9파일 **3,549 LOC** |
| 패키지 경계 | **없음** — `packages/` 아래 `dr_sono`(음성 모듈) 하나뿐. SDK·ADK 바인딩은 앱 코드에 직접 있다 |
| 렌더 결합 | `open_gl_view.dart`(265, 플랫폼 4갈래) + `native_view_widget.dart`(117). `Texture`/`TextureRegistrar` 사용 **0건**([rendering-boundary.md §5.1](../rendering-boundary.md)) |
| `hwnd` 관리 | `scan_controller.dart`(총 8,299줄) 중 **116줄**, 재생성·폴링 **61줄** |
| 모듈 로드 | Windows: Dart 에서 DLL **15개**를 이름·순서 지정해 로드(`// Sonex 기본 모듈들 (순서 중요)`). Android: `SonexJNI.java` 가 `System.loadLibrary()` 나열 |
| **회귀 이력** | 2026-05-29 — 의존 DLL 목록이 회귀로 누락되어 ADK 미작동. 수동 목록 관리가 원인([gap.md §7.1](../gap.md)) |
| 바인딩 정합성 | 앱이 부르는 `hc_*` 108개 중 **29개**(코어 기준 31개)가 프레임워크에 정의 0건. `NativeMethods.dart` 가 lookup 실패를 `print` + 스텁 함수로 덮는다([gap.md §7.2](../gap.md)) |
| IP·포트 하드코딩 | 6곳·4파일 — `scan_controller.dart:486,2768,3194` · `scan_stabilizer.dart:97` · `scan_launch_helper.dart:258,672` · `home_controller.dart:272` |
| 리뷰 화면 조율 계층 | `review_annotation_overlay.dart`(605)+`review_sdk_measurement_coordinator.dart`(429)+`review_measure_import.dart`(239) = **1,273 LOC**. 재생 프레임을 SDK 파이프라인에 못 넣어 Flutter `RawImage`(영상)+SDK 네이티브 창(측정, 투명 배경 합성)으로 우회([rendering-boundary.md §7.4](../rendering-boundary.md)) |
| 클라우드 경로 중복 | `http_manager.dart`(Dart 직접) 와 `adk_network_service.dart`(ADK 경유)가 **같은 서버**(`sonex.healcerion.com:8080`)를 각각 호출. `login_controller.dart` 가 둘 다 import([gap.md §7.3·§9](../gap.md)) |
| 폐기된 계획 | `flutter_sonex_sdk` 플러그인 — `pubspec.yaml:114-115` 에 주석으로만 남음, 실물 없음 |

### 1.4 목적

1. 자체 바인딩을 Phase 5 정본 wrapper 로 교체
2. Phase 4 새 렌더 계약으로 전환 — `hwnd` 관리 소멸
3. 모듈 로드를 Phase 3 캡슐화 결과에 맞춰 정리
4. 바인딩 오탐(29건) 실제 정정
5. 리뷰 화면 조율 계층(1,273 LOC) 소멸
6. IP·포트·클라우드 경로 정리

### 1.5 범위 한계

- **도메인 기능을 바꾸지 않는다** — 워크리스트·측정·DICOM·백업 등 ADK 응용 로직은 그대로
- **UI/UX 를 바꾸지 않는다** — 배선 교체가 사용자에게 보이지 않아야 한다
- 신호처리·렌더링 알고리즘 자체는 SDK 안에 있으므로 이 phase 대상이 아니다

---

## 2. 진행 단계

### Step 8-0. 저장소 재배치

Phase 0-0 과 동일한 절차 — `client/legacy/sonex-app` → `client/sonex-app` 작업 사본. fork base·힐세리온 반영 방식 협의.

### Step 8-A. Flutter wrapper 교체

| # | 작업 |
|---|---|
| A-1 | Phase 5-D 의 `SonexScanView` 위젯·정본 바인딩을 `pubspec.yaml` 의존성으로 추가 |
| A-2 | `lib/services/sdk/`(3,732 LOC)·`lib/services/adk/`(3,549 LOC)의 자체 FFI 선언을 정본 패키지 호출로 교체. **한 번에 전부 바꾸지 않는다** — 모듈 단위로 순차 전환하고 매 전환 후 회귀 확인 |
| A-3 | 전환 후 자체 바인딩 코드 삭제 |

### Step 8-B. 렌더 경로 전환

| # | 작업 |
|---|---|
| B-1 | `open_gl_view.dart`(265)·`native_view_widget.dart`(117) 를 `SonexScanView(streamIndex: 0)` 한 줄로 대체 |
| B-2 | `scan_controller.dart` 의 `hwnd` 관리(116줄)·재생성 폴링(61줄) 제거 |
| B-3 | **리뷰 경로도 함께 전환** — Phase 4-C 가 재생 프레임 반환 API 를 열면, `review_sdk_measurement_coordinator.dart` 등 1,273 LOC 조율 계층이 같은 위젯으로 흡수된다(8-E 와 연결) |

> **전제**: Phase 4 의 `hc_CreateRenderTarget(width,height)→textureId` 계약이 서 있어야 한다. 그 전에는 8-B 를 시작할 수 없다.

### Step 8-C. 모듈 로드 목록 정리

| # | 작업 |
|---|---|
| C-1 | Phase 3 이 모듈 로드를 캡슐화했으면 — Windows `NativeMethods.dart` 의 DLL 15개 수동 나열을 단일 진입점 호출로 대체 |
| C-2 | Android `SonexJNI.java` 의 `System.loadLibrary()` 나열도 동일하게 정리 |
| C-3 | Phase 2 F-4 의 바이너리 이름 정책 반영 — 이름이 바뀌면 이 목록도 함께 바뀐다 |

### Step 8-D. 바인딩 오탐 정정

| # | 작업 |
|---|---|
| D-1 | Phase 1-D 스크립트로 재확인 — 108개 중 29개(코어 기준 31개) |
| D-2 | 대소문자 오타 2건(`hc_setLogMessageCallback`·`hc_ReleaseWcharPointer` 등) 정정 |
| D-3 | 진짜 부재 심볼(`hc_GrabFrontBufferBgraNow` 등)은 Phase 4-C·4-C2 가 낸 대체 API 로 치환. 방어 코드(`print` 스텁)는 치환 후 제거 |

### Step 8-E. 리뷰 화면 조율 계층 제거

| # | 작업 |
|---|---|
| E-1 | Phase 4-C(완성 프레임 반환 API)가 재생 경로에도 적용되는지 확인 |
| E-2 | 적용되면 `review_annotation_overlay.dart`(605)+`review_sdk_measurement_coordinator.dart`(429)+`review_measure_import.dart`(239) = 1,273 LOC 를 8-B 의 `SonexScanView` 로 흡수 |
| E-3 | 투명창 합성 로직 제거 확인 — 영상·측정이 SDK 가 반환하는 한 장의 프레임으로 통일됐는지 골든 대조 |

### Step 8-F. IP·포트 하드코딩 해소

| # | 작업 |
|---|---|
| F-1 | 6곳·4파일의 `192.168.10.1` 등 리터럴을 설정(빌드 구성 또는 런타임 설정)으로 이동 |
| F-2 | [Phase 1-B mock 장치 서버](./phase1-regression-baseline.md)를 앱 e2e 에서 쓰려면 이 항목이 선행이다(연결 대상을 mock 서버로 바꿔치기 가능해짐) |

### Step 8-G. 클라우드 경로 단일화

| # | 작업 |
|---|---|
| G-1 | `http_manager.dart` 직접 호출과 `adk_network_service.dart` ADK 경유 중 **어느 쪽이 실제 운영 경로인지 확인**(gap.md §9 미확인 항목 해소) |
| G-2 | 하나로 통일 — `login_controller.dart` 가 둘 다 import 하는 상태 해소 |

### Step 8-H. 버전 고정 반영

| # | 작업 |
|---|---|
| H-1 | Phase 2-D 의 앱↔SDK 호환 조합 선언에 맞춰 `pubspec.yaml` 버전을 정본 wrapper 버전과 실제로 묶는다 |

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 자체 바인딩 소멸 | `lib/services/{sdk,adk}/` 의 FFI 선언 코드 | 0(정본 패키지 참조로 대체) |
| 3.2 | `hwnd` 참조 | `grep -rn hwnd lib/` | 0건 |
| 3.3 | 수동 로드 목록 | Windows DLL·Android `.so` 나열 | 0건(캡슐화 진입점 호출로 대체) |
| 3.4 | 바인딩 정합성 | lookup 실패 카운트 | 0건 |
| 3.5 | 리뷰 조율 계층 | 1,273 LOC | 소멸 또는 흡수 |
| 3.6 | IP·포트 리터럴 | `grep -rn '192.168.10.1'` | 0건 |
| 3.7 | **동작 불변** | 기존 기능(연결→스캔→렌더→저장, 워크리스트→DICOM→백업) 전부 정상 | 회귀 0건 |

---

## 4. 위험·대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **선행 phase(2·4·5) 가 안 끝난 상태에서 착수** | 계약이 확정 안 돼 재작업 | 8-A~8-C 각각 해당 phase 완료를 전제조건으로 건다 — 순서 어기지 않는다 |
| 한 번에 전체 전환 시도 | 회귀 범위가 넓어 원인 특정 불가 | A-2 처럼 **모듈 단위 순차 전환** + 매 전환 후 회귀 확인(Phase 1 하니스 재사용) |
| 8-G 에서 실제 운영 경로를 잘못 판단 | 로그인·인증 경로 장애 | G-1 을 코드 정적 분석이 아니라 **실제 트래픽 확인**(로깅·모니터링)으로 판정 |
| 리뷰 화면 회귀(8-E) | 측정 표시 오류는 임상 영향 | E-3 골든 대조를 사람이 육안으로도 재확인 |
| 힐세리온 원본과의 반영 방식 미정 | 작업 사본이 갈라져 되돌릴 수 없어짐 | Phase 0-4 와 같은 원칙 — 8-0 착수 직후 반영 방식 협의, 정해지기 전엔 강제 동기화 안 함 |

---

## 5. cross-reference

- [plan.md §0·§4](./plan.md) — 상위 계획, Phase 8 자리
- [phase2-release-packaging.md](./phase2-release-packaging.md) — 버전·바이너리 명명(8-C·8-H 전제)
- [phase4-render-boundary.md](./phase4-render-boundary.md) — 렌더 계약(8-B 전제)
- [phase5-language-wrappers.md](./phase5-language-wrappers.md) — wrapper 정본(8-A 전제)
- [../gap.md §7·§9](../gap.md) — 앱 바인딩·클라우드 경로 실측
- [../rendering-boundary.md §5·§7.4](../rendering-boundary.md) — 렌더 결합 실측·리뷰 조율 계층
