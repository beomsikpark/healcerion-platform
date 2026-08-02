# Phase 3 — 렌더 경로 교체

> **상태**: 미시작
> **범위**: `moana` 의 스캔 화면 렌더링을 SDK 로 넘긴다. **`GLFrameView` 의 자리는 유지하고 내용을 바꾸며**, 그 아래 스캔컨버전·GL 업로드 계통 **약 13,800 LOC 를 제거**한다.
> **선행**: [Phase 1](./phase1-render-composition.md)(합성 경로 확정) · [Phase 2](./phase2-sdk-adk-adapter.md)(프레임이 SDK 에서 온다)
> **후행**: [Phase 4](./phase4-data-layer.md) · [Phase 5](./phase5-measure-controls.md)
> **근거**: [plan.md §1.3·§2.3](./plan.md)
> **실측 기준**: `moana` `origin/service_QT693`. 줄번호는 2026-08-01 직접 확인분이다.

---

## 1. 배경

### 1.1 제거 대상 — 어디에 무엇이 있는가 `[실측]`

| 책임 | 위치 | 처리 |
|---|---|---|
| **스캔컨버전 정점 메시**(폴라→직교) | `app/Sources/Scan/GLFrameB.cpp:343-600` — `radius`·`cosf/sinf`·`fieldOfView` | **제거** — SDK `HCScanBConvex`·`HCScanBLinear` |
| **스캔컨버전 셰이더** | `app/Resources/Shaders/{Desktop,ES3}/scanConversion.{vert,frag}`, 로드 `GLFrameB.cpp:644-651` | **제거** — SDK `grayscale_*.glsl`·`cf_*.glsl` |
| **GL 텍스처 업로드** | `GLFrameB.cpp:1063-1148`(`allocateStorage`/`setData`) · `GLFrameCF.cpp:1028` | **제거** |
| **PW/M 스펙트로그램 래스터** | `FrameProcessorPWM.cpp:184-189` → `LineBufferTable`·`DispBufferTable` | **제거** — SDK `HCScanSpectrum` |
| **프로브 기하(반경·FOV)** | `app/Sources/Common/Model.cpp:173-175, 285-287, 390-391, 492-494, 530-531` | **제거** — SDK 가 모델별로 안다 |
| **최종 합성** | `GLFrameView.cpp:277-284`(`finalRenderer.*`) · `GLFrameView.h:42,524`(`QQuickFramebufferObject` + `Renderer`) | **자리 유지, 내용 교체** |

합계 **약 13,800 LOC**.

### 1.2 `GLFrameView` 만 남기는 이유

`QQuickFramebufferObject` 는 **"GL 로 뭔가 그려서 QtQuick 씬그래프에 넣는" 자리**다. [Phase 1](./phase1-render-composition.md) 이 확정한 경로가 무엇이든 그 결과를 씬그래프에 넣어야 하므로, **이 자리 자체는 필요하다.** 바뀌는 것은 "무엇을 그리느냐"이지 "어디에 넣느냐"가 아니다.

### 1.3 프레임 전달 경로가 app 쪽에 있다 `[실측]`

지금 큐 소유가 뒤집혀 있다 — framework 가 만들고 app 이 소유한다.

```
framework/ScanManager/FrameworkWrapper.cpp:722,747   SononClient 콜백 → renderQueue->enqueue()
framework/ScanManager/ScanManager.cpp:521,527        B: procImageFilter (NLM·frame-avg·graymap)
framework/ScanManager/ScanManager.cpp:640,644        CF: ProcFilterCdata(..., rgbTable ...)
framework/ScanManager/ScanManager.cpp:583,663,683,692  결과를 새 SononFrame 으로 → glRenderQueue->enqueue()
app/Sources/Scan/ScanPlayer.cpp:2403                 app 이 큐 포인터 주입 (setGLRenderQueue)
app/Sources/Common/FrameStreamer.cpp:129,151         app 스레드가 streamQueue → renderQueue 릴레이 (모드 필터·FPS 동기)
app/Sources/Scan/ScanPlayer.cpp:4287                 dequeue 후 GLFrameView::updateFrame()
```

**SDK 가 그리면 이 사슬 전체가 사라진다** — SDK 내부에서 프레임이 생산·소비되고, app 은 완성 프레임(또는 표시 신호)만 받는다.

> **`FrameStreamer` 의 부가 책임을 놓치면 안 된다** — 단순 릴레이가 아니라 **모드 필터와 FPS 동기**를 한다(`:129,151`). 이 책임이 SDK 로 흡수되는지, app 에 남아야 하는지가 Step 3-C 의 판단이다.

### 1.4 `ScanPlayer.cpp` 는 이 phase 의 대상이 아니다

`ScanPlayer.cpp` 는 **7,526줄 · 메서드 255 · 멤버 415** 로 `moana` 최대 파일이다([../legacy/moana-vs-sonex.md §3](../legacy/moana-vs-sonex.md)). 그러나 그 대부분은 **스캔 화면의 UI 로직·상태 관리**이지 렌더링이 아니다.

**이 phase 는 렌더 코어만 걷어낸다.** `ScanPlayer` 의 분해는 이 계획의 범위 밖이다 — 구조 개선과 계층 교체를 동시에 하면 회귀 원인을 가를 수 없다.

---

## 2. 진행 단계

### Step 3-A. 표시 컴포넌트 교체

| # | 작업 |
|---|---|
| A-1 | `GLFrameView::Renderer` 내부를 [Phase 1 F-4](./phase1-render-composition.md) 가 확정한 계약으로 교체 — 완성 프레임 수신 또는 `adopted` 컨텍스트 위임 |
| A-2 | 리사이즈를 SDK 계약으로 연결 — `onSurfaceChanged(w,h)` 또는 `hc_ResizeRenderTarget` |
| A-3 | **모드별 4벌(`GLFrameB`·`GLFrameCF`·`GLFrameM`·`GLFramePW`)을 1벌로 합친다** — SDK 가 모드를 알고 그리므로 표시 컴포넌트는 모드를 몰라도 된다 |
| A-4 | 프레임 갱신 감지 방식을 정한다 — SDK 콜백 vs 폴링. [r1 4 §1.6](../r1/phase4-render-boundary.md) 이 미확정으로 남긴 항목이다 |

### Step 3-B. 렌더 코어 제거

| # | 작업 |
|---|---|
| B-1 | §1.1 의 6개 책임 중 5개를 제거한다(합성 자리는 유지) |
| B-2 | **한 번에 지우지 않는다** — 스캔컨버전 → 텍스처 업로드 → 셰이더 → PW/M 래스터 → 프로브 기하 순으로 끊고, 매 단계 빌드를 유지한다 |
| B-3 | `app/Resources/Shaders/` 정리 — 스캔컨버전 셰이더가 빠진 뒤 남는 것이 무엇인지 확인. **UI 셰이더가 섞여 있으면 함께 지우지 않는다** |
| B-4 | 제거 후 `.pro`·`.qrc` 항목 정리 |

### Step 3-C. 프레임 전달 사슬 정리

| # | 작업 |
|---|---|
| C-1 | `setGLRenderQueue`(`ScanPlayer.cpp:2403`) 경로 제거 |
| C-2 | **`FrameStreamer` 의 모드 필터·FPS 동기 책임을 판정한다**(§1.3) — SDK 가 대신하면 제거, 아니면 SDK 프레임 위에서 재구현 |
| C-3 | `GLFrameView::updateFrame(SononFrame*)`(`ScanPlayer.cpp:4287`) 시그니처를 SDK 프레임 계약으로 교체 |
| C-4 | `QQueueTS<QPointer<SononFrame>>` 소비처가 0 이 되는지 확인 |

### Step 3-D. 좌표계 이관

| # | 작업 |
|---|---|
| D-1 | `ppcm = contentHeight / (viewDepth/10)`(`MeasureView.cpp:2712`·`MeasureViewPWM.cpp:757,777`)의 근거가 사라진다 — **app 이 자기 스캔컨버전 기하를 알던 전제**가 SDK 로 넘어갔다 |
| D-2 | SDK 가 주는 기하·좌표를 쓰도록 바꾼다. **[Phase 5](./phase5-measure-controls.md) 의 측정 이관과 한 벌이므로 그쪽과 순서를 맞춘다** |
| D-3 | 프리셋 `viewDepth`(`CPresetItem::viewDepthCentimeter()`) 소비처를 정리 — `GLFrameB/CF/M/PW` 와 측정이 같은 소스를 쓰고 있었다 |
| D-4 | **위젯 좌표 → 렌더 타겟 좌표 변환을 표시 컴포넌트 책임으로 명시**([r1 4-B1](../r1/phase4-render-boundary.md)) |

---

## 3. 검증

| # | 항목 | 방법 | 기대 |
|---|---|---|---|
| 3.1 | **영상 표시** | 재생 데이터로 스캔 화면 | Phase 1 시험물과 동등 |
| 3.2 | 모드 전환 | B·M·CF·PW·PD | 전부 표시 |
| 3.3 | 렌더 코어 잔존 | `app/Sources/Scan/` 에서 `scanConversion`·`fieldOfView`·`allocateStorage` grep | **0건** |
| 3.4 | 셰이더 | `app/Resources/Shaders/scanConversion.*` | **부재** |
| 3.5 | `SononFrame` 렌더 소비처 | `updateFrame(SononFrame*)` | **0건** |
| 3.6 | 리사이즈 | 창 크기 변경 | 깨지지 않음 |
| 3.7 | **QML 오버레이** | 영상 위 UI | **유지** — Phase 1 3.2 가 여기서 실코드로 재확인된다 |
| 3.8 | 프레임레이트 | 실장비 스캔 | **Phase 1 수치와 대조.** 저하가 있으면 원인 특정 |

> **3.8 이 이 phase 의 실장비 검증 지점이다.** 나머지는 재생 데이터로 판정할 수 있다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **Phase 1 계약이 확정되지 않은 채 착수** | 두 번 만든다 | 선행 조건을 지킨다. Phase 1 F-4 산출물이 이 phase 의 입력이다 |
| 13.8k LOC 를 한 번에 제거 | 회귀 원인 특정 불가 | B-2 — 5단계로 끊고 매 단계 빌드 유지 |
| **`FrameStreamer` 의 FPS 동기를 놓친다** | 프레임레이트 널뜀 재발 | C-2 — 책임을 명시적으로 판정한다. `moana` 최근 회귀에 **FPS 10~25 널뜀**이 있었다([../../review/moana-app.md §9](../../review/moana-app.md)) |
| 좌표 이관이 측정과 어긋난다 | 측정값 오류 — **임상 영향** | D-2 — Phase 5 와 순서를 맞춘다. 단독 진행 금지 |
| UI 셰이더를 함께 지운다 | 화면 요소 소실 | B-3 — 스캔컨버전 셰이더만 특정해 제거 |
| **`ScanPlayer` 를 "정리하는 김에" 손댄다** | 7,526줄 파일의 회귀가 렌더 교체와 섞인다 | §1.4 — 범위 밖으로 명시. mechanical 제거 외 변경은 별도 커밋 |

---

## 5. cross-reference

- [plan.md](./plan.md) §1.3(렌더 책임 경계)·§2.3(남는 것/사라지는 것)
- [phase1-render-composition.md](./phase1-render-composition.md) — **선행. 이 phase 의 계약을 만든다**
- [phase2-sdk-adk-adapter.md](./phase2-sdk-adk-adapter.md) — 선행. 프레임이 SDK 에서 오게 한다
- [phase5-measure-controls.md](./phase5-measure-controls.md) — D-2 의 짝
- [../r1/phase4-render-boundary.md](../r1/phase4-render-boundary.md) — SDK 측 렌더 계약
- [../../review/moana-app.md](../../review/moana-app.md) §4(스캔 모드 렌더링)·§9(FPS 널뜀 회귀)
