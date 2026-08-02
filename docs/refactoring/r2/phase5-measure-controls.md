# Phase 5 — 측정 이관 · 필터 대체 · 500C/P 컨트롤

> **상태**: 미시작
> **범위**: 측정 소유권을 SDK 로 넘기고, **상용 CVIE 를 오픈소스 필터로 대체**하며, 500C/P 전용 컨트롤을 신설한다.
> **선행**: [Phase 3](./phase3-render-path.md)(SDK 가 그린다) · [Phase 4](./phase4-data-layer.md)(측정 결과 저장처가 ADK 다)
> **후행**: [Phase 6](./phase6-build-packaging.md)
> **근거**: [plan.md §2.2·§0.4](./plan.md)
> **실측 기준**: `moana` `origin/service_QT693` · `sonex-framework` `origin/master`.

> **이 phase 는 사람 검증이 가장 무겁다.** 세 항목 중 둘(**측정 정확도**·**화질 등가성**)이 임상 판정이라 [plan.md §5](./plan.md) 의 병목이 여기 몰린다. **일정을 짤 때 이 phase 를 뒤로 미루지 않는다** — 검증 회차를 확보해야 한다.

---

## 1. 배경

### 1.1 측정 — 양쪽에 다 있고, SDK 것을 쓴다

| | `moana` | `sonex` SDK |
|---|---|---|
| 구현 | `app/Sources/Measure/` **50파일 12,689 LOC**, 모드별 분리 | `ImageRenderer/shared/measure/` **13종** (Angle·BVF·Depth·Distance·Ellipse·FetalBiometry·Heartrate·Length·Tag·Time·Velocity·VelocityDiff·Volume) |
| 그리기 | `CMeasureView : QQuickPaintedItem` — **QPainter**(`MeasureView.cpp:143`) | **GL 렌더**(SDK 프레임에 합성) |
| 조작 | Qt/QML | **`HCTouchRecognizer`**(`.cpp` 268 + `.h` 83) |
| 좌표 | `ppcm = contentHeight / (viewDepth/10)`(`MeasureView.cpp:2712`) — **app 자체 계산** | SDK 내부 (영상 좌표계 mm 기준) |
| 저장 | `scanContext->addMeasure*()` **26개 메서드**(`ScanContext.h:32-100`) — app 직접 접근 0건 | ADK DB |

**판단 근거는 [plan.md §2.2](./plan.md) 에 있다** — 중복 · 좌표 소유 이전 · [r1 4-C2](../r1/phase4-render-boundary.md) 의 설계 의도(*"고객사가 각자 그려 캘리퍼 표시가 기기마다 갈린다 — 의료기기 품질·인증 문제"*) · **검증 비용**(한 벌만 검증).

**유리한 실측 하나** — `moana` 의 측정 저장이 이미 **메서드 경유**(`addMeasure*()` 26개, 직접 필드 접근 0건)라 **교체 지점이 캡슐화돼 있다**([plan.md §1.6](./plan.md)). 397개 직접 접근과 성격이 다르다.

**남기는 것**: 측정 **결과 표시·리포트 UI**. 그리기와 조작만 넘긴다.

### 1.2 CVIE — 상용이라 대체 대상이고, 코드는 이미 있다 `[실측]`

[plan.md §0.4](./plan.md) 가 정한 대체 대상 ②다.

| 항목 | 실측 |
|---|---|
| 정체 | **ContextVision CVIE SDK 6.0.0.8** — `READMESDK.txt` 첫 줄 *"CONTEXTVISION COMPANY CONFIDENTIAL"* |
| 결합 | `framework/ContextVision/` 래퍼 + `HC_CVIE_SUPPORT` **85곳 / 14파일** |
| 라이선스 방식 | **상용 계약 + 라이선스 매니저** — `.cov` 파일 2개가 저장소에 있고 `Cvie::Instance()` **전에 CVLM 초기화**가 선행된다(`ContextVision.cpp:30`) |
| 부위별 파라미터 | `.us2d6` 3종 — Carotid · MSK · Thyroid |
| **대체 구현** | **이미 출하 코드에 있다** — `framework/ImageProc/HCNextSRIFilter.{cpp,h}`(커밋 `cdafdc970`, 2026-06-24) |
| 대체의 기반 | **OpenCV 단독**(BSD-3) — `cv::fastNlMeansDenoising` · `cv::edgePreservingFilter` · `cv::UMat` |
| **전환 장치** | **런타임 배타 분기가 이미 배선돼 있다** — `ImageProc.cpp:1229-1235` 의 `cvieActive = (getCvieSetting() >= 0)` |

> **즉 "만들어야 하는" 것이 아니라 "기본값을 바꾸는" 것이다.** 코드 작업은 작다.

**그러나 등가성이 미검증이다** `[../legacy/moana-vs-sonex.md §1.2]`

| | |
|---|---|
| 커밋의 *"byte-identical 검증"* | **Python 레퍼런스(`pipeline_v1_20_5.py`)와의 일치**이지 **CVIE 와의 화질 등가가 아니다** |
| **CVIE 가 여전히 기본값이다** | 라이선스가 있으면 CVIE 가 돈다 — 그들이 더 낫다고 판단하고 있다는 뜻 |
| 임상 화질 비교 기록 | 저장소에 **없다** |
| `.us2d6` 부위별 튜닝 | NextSRI 도 anatomy preset 을 갖지만 **1:1 대조되지 않았다** |
| 규제 | 영상 처리 경로 변경은 **재검증 대상** |

> **이 phase 는 "코드를 바꾸는 일"이 아니라 "화질을 판정받는 일"이다.** 그래서 §3.5·§4 가 이 항목의 무게를 진다.

**SDK 쪽도 같은 선택지를 갖는다** — `sonex-framework` 에도 `third_party/context_vision`(82MB)과 자체 필터 8종(`HCNLMFilter`·`HCSRIv20_5`·`HCSRIv22*` 등)이 함께 있다. **어느 쪽 대체 구현을 쓸지**(moana `HCNextSRIFilter` vs SDK `HCSRIv*`)가 이 phase 의 판단이다 — [Phase 3](./phase3-render-path.md) 이후 필터는 SDK 안에 있으므로 **SDK 것이 기본**이다.

### 1.3 500C/P 컨트롤 — 화면이 아니라 토글이다 `[실측]`

[plan.md §1.6](./plan.md) 대로 화면 구성은 모델과 무관하게 같다.

| 항목 | `moana` | SDK |
|---|---|---|
| Harmonic · Spatial Compound | `sendCommand_FPGA_B_Func`(`ControlCommand.cpp:2225`) — **호출처 0건 · QML UI 0건** | 지원 + **UI 힌트 반환**(`HCLiveController.cpp:762` `harmonicSupported`·`harmonicDefault`) |
| 펌웨어 굽기 | `Main/FirmwareUpdater.cpp` **121줄**, `"500L"`·`"L43K"` 문자열 비교뿐 | ADK `HCFirmwareController` — **SN 3단계 상태머신**(`snB3`·`snMsp`·**`snWifi`**) |

**펌웨어 굽기는 화면 형태가 같다**(파일 선택 → 진행률 → 완료). 바뀌는 것은 그 아래 상태머신이고 **그건 ADK 에 이미 있다**([r1 Phase 6 F-2](../r1/phase6-samples-support.md)).

---

## 2. 진행 단계

### Step 5-A. 측정 이관

| # | 작업 |
|---|---|
| A-1 | **`addMeasure*()` 26개 메서드를 SDK 측정 API 로 교체**한다 — 캡슐화돼 있으므로 여기가 단일 교체 지점이다 |
| A-2 | `app/Sources/Measure/` 의 **그리기 코드 제거** — `CMeasureView::paint(QPainter*)` 계열. **결과 표시·리포트 UI 는 남긴다** |
| A-3 | **조작을 SDK 로 위임** — 캘리퍼 드래그·히트테스트를 `HCTouchRecognizer` 로. 앱은 **렌더 타겟 좌표만 넘긴다**([r1 4-B1](../r1/phase4-render-boundary.md)) |
| A-4 | **좌표 변환 제거** — `ppcm` 계산(`MeasureView.cpp:2712`·`MeasureViewPWM.cpp:757,777`)의 근거가 [Phase 3-D](./phase3-render-path.md) 에서 사라진다. **Phase 3-D 와 순서를 맞춘다** |
| A-5 | **측정 결과 조회 경로 신설** — 표시·리포트용으로 SDK 에서 측정값을 받아온다. [r1 4-C2](../r1/phase4-render-boundary.md) 의 `exportMeasurements` C ABI 승격분이 이것이다. **없으면 이 phase 가 막히므로 r1 진행 상황을 먼저 확인한다** |
| A-6 | **측정 종류 대조** — `moana` 8종(Length·Angle·Ellipse·Trace·**DDH**·**BloodVolumeFlow**·Velocity·Heartrate) vs SDK 13종. **`moana` 에만 있는 것이 있으면 목록으로 낸다** — 특히 `DDH`(고관절 이형성) |

> **A-6 이 이 Step 의 함정이다.** 숫자가 큰 쪽(13종)이 포함관계라고 가정하면 안 된다 — [../legacy/moana-vs-sonex.md §8-5](../legacy/moana-vs-sonex.md) 가 모델 집합에서 정확히 같은 오류를 냈다. **원소를 대조한다.**

### Step 5-B. CVIE 대체

| # | 작업 |
|---|---|
| B-1 | **필터 정본을 정한다** — SDK 의 `HCSRIv*` 계열(Phase 3 이후 필터는 SDK 안이므로 기본값) vs `moana` `HCNextSRIFilter`. 둘은 **1:1 포팅 관계**로 문서화돼 있다(`NextSRI_vs_Sonex_Comparison.md`) — 차이는 **UMat/OpenCL(moana) vs Mat/CPU(sonex)** 와 EPF 비활성화 |
| B-2 | **CVIE 경로 비활성화** — `cvieActive` 를 항상 false 로 만들거나 분기 자체를 제거 |
| B-3 | `framework/ContextVision/` 래퍼와 `HC_CVIE_SUPPORT` **85곳/14파일** 제거 |
| B-4 | **`.cov` 라이선스 파일 2개와 `cvie64` 바이너리를 저장소·패키지에서 제외**한다. [r1 Phase 2-A](../r1/plan.md) 의 패키지 제외 목록과 같은 항목이다 |
| B-5 | **SDK 쪽 CVIE 도 함께 판정한다** — `sonex-framework/sdk/third_party/context_vision`(82MB). SDK 는 [r1](../r1/plan.md) 소관이므로 **요구를 r1 에 낸다** |
| B-6 | **`.us2d6` 부위별 파라미터(Carotid·MSK·Thyroid)의 대응 preset 을 확인**한다. NextSRI/SRI 의 anatomy preset 과 1:1 대조되지 않았다(§1.2) |

### Step 5-C. 500C/P 컨트롤 신설

| # | 작업 |
|---|---|
| C-1 | **Harmonic 토글** — SDK `harmonicSupported` 힌트를 읽어 **조건부 표시**. `harmonicDefault` 로 초기값 |
| C-2 | **Spatial Compound 토글** — 동일 방식. SDK 기본값은 OFF |
| C-3 | `sendCommand_FPGA_B_Func`(죽은 함수, [Phase 2 §1.3](./phase2-sdk-adk-adapter.md))는 **되살리지 않는다** — SDK request 로 새로 배선한다 |
| C-4 | **모델별 컨트롤 가시성을 SDK 힌트로 일반화**한다 — 하드코딩 모델 판정([Phase 0 A-2](./phase0-repo-scope-cut.md) 제거분)의 자리를 이것이 대신한다 |

### Step 5-D. 펌웨어 굽기 재배선

| # | 작업 |
|---|---|
| D-1 | `Main/FirmwareUpdater.cpp` 121줄(500L·L43K 문자열 비교)을 **폐기** |
| D-2 | ADK `HCFirmwareController` + `HCFirmwareVersionChecker` 호출로 교체 |
| D-3 | **UI 는 그대로 둔다** — 파일 선택 → 진행률 → 완료 |
| D-4 | **SN 3단계 진행률 표시** — `snB3`·`snMsp`·`snWifi`(RS9116 `.rps`, 약 2MB). 단계가 3개이므로 진행률 UI 가 그것을 표현해야 한다 |
| D-5 | 펌웨어 메타(`.ini`) 취득 경로 확인 — 현재 `500-SN-Firmware.ini` 가 **ADK 샘플 리소스 안에만** 있다([r1 Phase 6-E2](../r1/phase6-samples-support.md)) |

### Step 5-T. 측정·펌웨어 단위테스트

**[plan.md §2.6.3 ⑥⑦](./plan.md).** 이 phase 는 사람 검증이 가장 무거우므로, **자동으로 잡을 수 있는 것을 최대한 앞당긴다.**

| # | 작업 |
|---|---|
| T-1 | **측정 결과 변환**(⑥) — SDK 측정값 ↔ 표시·리포트 값 정합. **단위·자릿수·좌표계 변환**을 값으로 대조한다. **임상 영향이라 자동 판정 가치가 가장 높다** |
| T-2 | **측정 종류 대조 자동화**(A-6) — `moana` 8종 ↔ SDK 13종 원소 대조를 **테스트가 판정**한다. 사람이 표를 보고 세면 빠진다 |
| T-3 | **펌웨어 상태머신**(⑦) — ADK SN 3단계(`snB3`·`snMsp`·`snWifi`) **단계 순서**와 **실패 경로**를 mock 으로. 실장비 전에 잡을 수 있는 것을 여기서 잡는다 |
| T-4 | **진행률 계산** — 3단계 합산이 0~100 을 벗어나지 않는지. 단계가 셋이라 경계가 생긴다(D-4) |

> **T-3 이 실장비 위험을 직접 줄인다** — 펌웨어 굽기 실패는 장비 손상이라([../rendering-boundary.md §7.5](../rendering-boundary.md)) 실장비 시도 자체가 비싸다. **다만 단계 순서·실패 처리만 mock 으로 판정 가능하고, 실제 굽기 성공 여부는 실장비뿐이다.**

---

## 3. 검증

| # | 항목 | 방법 | 판정 주체 |
|---|---|---|---|
| 3.1 | 측정 표시 | 13종이 화면에 그려진다 | 자동 |
| 3.2 | 측정 조작 | 캘리퍼 드래그·핸들 잡기 | 사람(육안) |
| 3.3 | **측정 정확도** | 팬텀 또는 기준 대상으로 실측 | **사람 — 임상 판정** |
| 3.4 | `moana` 측정 잔존 | `Measure/` 의 `paint(QPainter*)` 계열 | 자동. **0건** |
| 3.5 | **화질 등가성** | CVIE 대비 NextSRI/SRI 영상 비교 | **사람 — 임상 판정.** §4 |
| 3.6 | CVIE 잔존 | `HC_CVIE_SUPPORT`·`framework/ContextVision`·`.cov`·`cvie64` | 자동. **0건** |
| 3.7 | Harmonic·Compound | 500C/500P 에서 토글 동작, 300 계열 연결 시 미표시 | 사람(실장비) |
| 3.8 | 펌웨어 굽기 | 500C·500P 실장비 | **사람 — 실패 시 장비 손상** |
| 3.9 | 측정 종류 커버리지 | A-6 대조표 | 자동. **누락 0 또는 목록화** |
| **3.10** | **측정·펌웨어 단위테스트** | Step 5-T | **CI 통과.** 측정값 정합 · 상태머신 순서·실패 경로 |

> **3.3·3.5 가 이 phase 의 일정을 정한다.** 나머지는 자동이거나 한 번 보면 끝나지만, 이 둘은 **판정 기준을 먼저 합의**해야 하고 반복될 수 있다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **NextSRI/SRI 가 CVIE 와 화질이 다르다** | 제품 품질 저하. 규제 재검증 | **가장 먼저 잰다** — 코드 작업(B-2·B-3)보다 **화질 비교(3.5)를 앞세운다.** CVIE 제거는 이미 정해진 것이므로([plan.md §0.4](./plan.md)) **판단이 아니라 측정이 우리 일이다.** 차이가 나오면 그 크기와 부위별 양상을 수치로 내고, 수용 여부 판단은 그 결과 위에서 이뤄진다 — **측정 없이 물으면 답할 근거가 없다** |
| **측정 종류가 SDK 에 없다**(A-6) | 기능 손실 — `DDH`·`BloodVolumeFlow` 등 | 원소 대조를 먼저. 누락분은 **SDK 요구로 [r1](../r1/plan.md) 에 낸다.** 앱에서 자체 구현하면 [r1 4-C2](../r1/phase4-render-boundary.md) 의 설계 의도를 깬다 |
| **측정값 반환 API 가 없다**(A-5) | 결과 표시·리포트가 죽는다 | r1 4-C2 진행 확인이 **착수 조건**. 없으면 이 phase 를 시작하지 않는다 |
| **좌표 이관이 Phase 3 과 어긋난다** | 측정값 오류 — 임상 영향 | A-4 — Phase 3-D 와 순서를 맞춘다. **단독 진행 금지** |
| 측정 정확도 회귀(3.3) | 임상 영향 | 팬텀 기준을 **이관 전에 먼저 측정**해 기준선을 만든다. 사후 비교로는 판정할 수 없다 |
| 펌웨어 굽기 실패(3.8) | **장비 손상** | 실장비 검증을 마지막에 몰지 않는다. [r1](../r1/plan.md) 이 최근 실장비 검증분(2026-07-23)을 가지므로 그 절차를 그대로 쓴다 |
| `.us2d6` 대응 preset 부재(B-6) | 부위별 화질이 갈린다 | 3.5 를 **부위별로** 한다. Carotid·MSK·Thyroid 각각 |
| SDK 쪽 CVIE 가 남는다(B-5) | 라이선스 조건 미충족 | r1 에 요구로 내고 **패키지 제외 목록으로 먼저 막는다** |

---

## 5. cross-reference

- [plan.md](./plan.md) §2.2(측정 소유권 판단)·§0.4(라이선스 대체 대상)·§5(사람 검증 병목)
- [phase3-render-path.md](./phase3-render-path.md) — A-4 의 짝(좌표 이관)
- [phase4-data-layer.md](./phase4-data-layer.md) — 선행. 측정 결과 저장처
- [phase6-build-packaging.md](./phase6-build-packaging.md) — 후행. 라이선스 고지·패키지 제외
- [../r1/phase4-render-boundary.md](../r1/phase4-render-boundary.md) — **4-C2(측정 기하 반환)가 A-5 의 전제** · 4-B(조작 소유)
- [../r1/phase6-samples-support.md](../r1/phase6-samples-support.md) F-2·F-3 — 펌웨어 경계 · CVIE 적용 범위
- [../legacy/moana-vs-sonex.md](../legacy/moana-vs-sonex.md) §1.2 — CVIE 대체 실측과 미검증 항목
- [../../review/moana-app.md](../../review/moana-app.md) §4·§5 — 측정 계층 · 필터 포팅 관계
