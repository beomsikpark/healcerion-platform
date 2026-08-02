# Phase 1 — 표시 컴포넌트 · 렌더 계약 접속

> **상태**: 미시작
> **범위**: [r1 Phase 4](../r1/phase4-render-boundary.md) 가 세운 렌더 계약을 `moana` 의 QtQuick 씬그래프에 접속하고, **표시 컴포넌트를 구현**한다. 코드를 이관하지 않는다 — 계약 세부와 성능을 확정한다.
> **선행**: **[r1 Phase 4](../r1/phase4-render-boundary.md) 완료.** 이 계획은 리팩토링된 SDK 를 전제한다 — 현행 SDK(`prepareRender(nativeWindow)`)를 기준으로 삼지 않는다
> **후행**: [Phase 3](./phase3-render-path.md)(이 계약 위에서 렌더 코어를 걷어낸다)
> **근거**: [plan.md §3](./plan.md) · [../r1/phase4-render-boundary.md](../r1/phase4-render-boundary.md) · [../rendering-boundary.md](../rendering-boundary.md)
> **실측 기준**: `moana` `origin/service_QT693`.

---

## 1. 배경

### 1.1 r1 Phase 4 가 주는 것

| | Phase 4 이후 |
|---|---|
| SDK 가 **받는** 것 | **렌더 타겟 크기** — `hc_CreateRenderTarget(width, height)` · `hc_ResizeRenderTarget` |
| SDK 가 **주는** 것 | **완성 프레임** — 공유 서피스(제로카피)가 본선, 픽셀 버퍼가 폴백 |
| 윈도우 핸들 | **공개 API 에서 사라진다**(`hc_PrepareRenderer` 는 deprecated 로만 남는다) |
| 합성 범위 | CF · Spectrum · 눈금 · **측정 오버레이**까지 SDK 가 한 프레임에 합성한다([r1 4-C1](../r1/phase4-render-boundary.md)) |
| 조작 | SDK 가 소유한다(`HCTouchRecognizer`). 앱은 **렌더 타겟 좌표**만 넘긴다([r1 4-B1](../r1/phase4-render-boundary.md)) |

**SDK 가 창을 요구하지 않으므로 컨텍스트를 다툴 일이 없다.** r1 Phase 4 의 목적이 정확히 그것이다.

### 1.2 `moana` 쪽 접속 지점이 이미 맞다 `[실측]`

`moana` 의 최종 합성은 `GLFrameView` = **`QQuickFramebufferObject` + `Renderer`**(`GLFrameView.h:42,524`) — **"GL 로 그린 결과를 QtQuick 씬그래프에 넣는 자리"** 다.

r1 Phase 4 §5 가 목표를 이렇게 적었다 — *"모든 UI 프레임워크가 이미 갖고 있는 표준 이미지 경로에 얹는 일로 줄어든다"*(Flutter `Texture` · WPF `D3DImage` · Android `SurfaceTexture` · Apple `CVPixelBuffer`). **Qt 의 대응물이 `QSGTexture`/`QQuickFramebufferObject` 이고, `moana` 가 이미 그것을 쓰고 있다.**

→ **이 phase 는 "붙을 수 있는가"를 묻지 않는다. 붙이고, 계약 세부를 확정하고, 성능을 잰다.**

### 1.3 반환 형태가 둘이므로 둘 다 다룬다

**폴백을 만드는 것이 아니라 계약이 그렇다** — [r1 4-E4](../r1/phase4-render-boundary.md) 가 *"한 API 뒤에 두 반환 형태를 두고, 공유 서피스 실패 시 픽셀 버퍼로 자동 폴백하되 어느 쪽인지 호출자가 조회할 수 있게 한다"* 로 정했다.

| 반환 형태 | Qt 측 처리 | 플랫폼 |
|---|---|---|
| **공유 서피스**(본선·제로카피) | 플랫폼 핸들 → `QSGTexture` 래핑 | Windows D3D11 shared handle · Apple `IOSurface` · Android `AHardwareBuffer` |
| **픽셀 버퍼**(폴백) | 텍스처 업로드 후 `QSGTexture` | 전 플랫폼 |

**표시 컴포넌트는 두 경로를 모두 처리하고, 어느 쪽이 쓰였는지 기록한다.**

### 1.4 500C/500P 는 프레임 특성이 유리하다

장비가 **완성된 JPEG** 을 보내고 PW 만 raw 스펙트럼이다([../../review/protocol-device.md §5.1](../../review/protocol-device.md)). raw scanline 계열보다 프레임레이트가 낮고 데이터량이 작아, **픽셀 버퍼 폴백이 걸려도 성립할 여지가 넓다.** §2 Step 1-D 가 그것을 수치로 확인한다.

---

## 2. 진행 단계

### Step 1-A. 표시 컴포넌트 구현

| # | 작업 |
|---|---|
| A-1 | `QQuickFramebufferObject::Renderer` 안에서 **공유 서피스를 `QSGTexture` 로 래핑**한다 |
| A-2 | **픽셀 버퍼 경로**도 함께 구현 — 텍스처 업로드 후 동일하게 씬그래프에 삽입 |
| A-3 | **어느 경로가 쓰였는지 조회·기록**한다([r1 4-E4](../r1/phase4-render-boundary.md) 계약) |
| A-4 | 렌더 타겟 생성·리사이즈를 Qt 레이아웃에 연결 — `hc_CreateRenderTarget` · `hc_ResizeRenderTarget` |
| A-6 | **Windows 부터 세운다**([plan.md §0.5](./plan.md) 출시 1순위). 공유 서피스도 **D3D11 shared handle** 이 1순위다. Android·iOS 는 그다음, **macOS 는 대상 아님** |
| A-5 | **모드별 4벌을 만들지 않는다.** SDK 가 모드를 알고 합성하므로 표시 컴포넌트는 모드를 모른다 — `GLFrameB/CF/M/PW` 를 하나로 대체한다([Phase 3-A3](./phase3-render-path.md)) |

### Step 1-B. 계약 세부 확정

**[r1 4-C7](../r1/phase4-render-boundary.md) 이 헤더에 명시하기로 한 항목을 소비자 관점에서 확인한다.**

| # | 작업 |
|---|---|
| B-1 | **픽셀 포맷·원점·스트라이드·버퍼 소유** — 현행 cine 경로는 `orthoMat` 의 t/b swap 으로 GL 단계에서 flip 한다. **Qt 가 기대하는 원점과 맞는지 확인하고, 어긋나면 계약 쪽을 고친다**(표시 컴포넌트가 각자 flip 하기 시작하면 언어별 wrapper 마다 갈린다) |
| B-2 | **프레임 갱신 감지 방식** — SDK 콜백 vs 폴링. [r1 4 §1.6](../r1/phase4-render-boundary.md) 이 미확정으로 남긴 항목이고, **Qt 는 `update()` 호출 시점이 필요**하므로 여기서 정해진다 |
| B-3 | **앱 생명주기** — pause/resume 시 렌더 타겟 처리. 같은 미확정 항목이다 |
| B-4 | 확정 결과를 문서로 남긴다. **[Phase 3](./phase3-render-path.md) 이 이 계약 위에 선다** |

### Step 1-C. 좌표 변환 계약

| # | 작업 |
|---|---|
| C-1 | **위젯 좌표 → 렌더 타겟 좌표** 변환을 표시 컴포넌트 책임으로 구현한다([r1 4-B1](../r1/phase4-render-boundary.md)) |
| C-2 | 터치·마우스 이벤트를 그 좌표로 SDK 에 전달 — 조작 판정은 SDK `HCTouchRecognizer` 가 한다 |
| C-3 | **히트테스트 결과 수신** — 어느 객체를 잡았는지 알아야 커서·햅틱을 낸다([r1 4-B3](../r1/phase4-render-boundary.md)) |
| C-4 | `hc_SetDisplayMultiplier`(density)와 렌더 타겟 크기의 관계를 확인 — **지금은 앱이 추측한다**([r1 4-B4](../r1/phase4-render-boundary.md)) |

> **`moana` 의 `ppcm = contentHeight / (viewDepth/10)`(`MeasureView.cpp:2712`) 가 여기서 대체된다.** app 이 자기 스캔컨버전 기하를 알던 전제가 사라진다.

### Step 1-D. 성능 확인

| # | 작업 |
|---|---|
| D-1 | 공유 서피스·픽셀 버퍼 각각의 **프레임레이트·지연을 잰다** |
| D-2 | 500C/P 실사용 프레임레이트와 대조한다(§1.4) |
| D-3 | **플랫폼별로 어느 경로가 쓰이는지 표로 남긴다** — 공유 서피스가 안 되는 조합은 [r1 4-E4](../r1/phase4-render-boundary.md) 대로 자동 폴백되므로, **성립 여부가 아니라 어느 쪽인지**를 기록한다. **순서는 Windows → Android·iOS**([plan.md §0.5](./plan.md)) |
| D-4 | 저하가 크면 [r1](../r1/plan.md) 에 되돌린다 — **표시 컴포넌트에서 우회하지 않는다** |

### Step 1-E. 회귀 판정 자산 재사용 판정

**[plan.md §2.5](./plan.md) 의 설계를 실물로 잇는다.** 이 phase 가 재생 데이터로 판정하므로 그 부품을 여기서 같이 본다.

| # | 작업 |
|---|---|
| E-1 | **`DummyPlayer`(275줄)·`ScanAutoTestController`(267줄)** — `app/` 에 있어 살아남는다. SDK 프레임 경로 위에서 그대로 도는지 확인 |
| E-2 | **`AgingTestController`(552줄)** — [Phase 0 B-2](./phase0-repo-scope-cut.md) 가 보류로 돌린 자산. 500C/P 에 의미가 있는지, 자동 구동 뼈대로 쓸 수 있는지 판정 |
| E-3 | **재생 경로가 `framework/Record`·`ScanManager` 에 있다** — 걷어낼 대상이므로 ADK `BackupReadWriter` 로 갈아타야 완전해진다([Phase 4](./phase4-data-layer.md)). 이 phase 에서 기존 경로를 임시로 써도 되나 **그 사실을 기록한다** |
| E-4 | **[r1 Phase 1-B](../r1/phase1-regression-baseline.md) mock 장치 서버를 확보한다** — r1 이 `[선행 가능]` 으로 표시한 항목이라 **r1 진행과 무관하게 지금 만들 수 있다.** 없으면 [Phase 2 T-7](./phase2-sdk-adk-adapter.md) 의 배선 판정이 성립하지 않는다 |
| E-5 | **이관 전 명령열을 먼저 녹화한다** — 현행 `moana` 로 대표 시나리오를 돌려 mock 서버가 받은 명령열을 **기준선으로 저장**한다. **Phase 2 가 시작되면 이 기준선을 만들 수 없다** — 그때는 이미 바뀐 코드다 |

---

## 3. 검증

| # | 항목 | 방법 | 기대 |
|---|---|---|---|
| **3.0** | **빌드 게이트** | 매 Step 후 빌드 | 성공. **[plan.md §2.5.3 ①](./plan.md) — Phase 0~2 구간에서 상시 도는 판정** |
| **3.0b** | **이관 전 기준선 확보** | E-5 — 현행 `moana` 명령열 녹화본 | **존재.** 없으면 [Phase 2 T-7](./phase2-sdk-adk-adapter.md) 배선 판정이 성립하지 않으며 **이후 되돌려 뜰 수 없다** |
| 3.1 | 영상 표시 | 재생 데이터로 스캔 화면 | 성공 |
| 3.2 | **QML 오버레이** | 영상 위 QML 요소 | **정상 합성** — 씬그래프 안이므로 z-order 가 Qt 규칙을 따른다 |
| 3.3 | 합성 범위 | CF · Spectrum · 눈금 · 측정이 한 프레임에 | **전부 포함**([r1 4-C1](../r1/phase4-render-boundary.md) 산출물) |
| 3.4 | 리사이즈 | 창 크기 변경 | 깨지지 않음 |
| 3.5 | 반환 형태 | 플랫폼별 공유 서피스/픽셀 버퍼 | **표로 기록.** 폴백은 결함이 아니다 |
| 3.6 | 프레임레이트 | 경로별 fps | 수치 기록. 500C/P 실사용과 대조 |
| 3.7 | 터치 → 히트테스트 | 캘리퍼 핸들 잡기 | SDK 가 판정하고 결과가 앱에 돌아온다 |
| 3.8 | 좌표 정합 | 위젯 좌표 ↔ 렌더 타겟 좌표 | 어긋남 0 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **r1 Phase 4 가 안 끝난 상태에서 착수** | 계약이 확정 안 돼 재작업 | **선행 조건이다.** r1 Phase 4 의 판정 시험 ②(§3.2 — CI 가 창 없이 프레임 획득)가 통과한 뒤 시작한다 |
| 픽셀 원점·flip 규약 불일치 | 영상이 뒤집힌다 | B-1 — **표시 컴포넌트에서 뒤집지 않는다.** 계약을 고친다. 각자 flip 하면 언어별 wrapper 마다 갈린다([r1 4-C7](../r1/phase4-render-boundary.md)) |
| 프레임 갱신 감지 방식 미정 | `update()` 시점을 못 잡아 프레임이 밀린다 | B-2 — r1 미확정 항목이므로 **이 phase 가 요구를 낸다** |
| 공유 서피스가 특정 플랫폼에서 안 된다 | 성능 저하 | **결함이 아니라 계약된 폴백**이다(4-E4). D-3 으로 기록하고, 저하폭이 문제면 r1 에 되돌린다 |
| 성능 저하를 표시 컴포넌트에서 우회 | 부채가 앱으로 옮겨온다 | D-4 — **우회 금지.** Flutter 앱이 그렇게 해서 1,273 LOC 조율 계층이 생겼다 |
| 모드별 표시 컴포넌트를 4벌 만든다 | SDK 가 모드를 아는데 앱도 알게 된다 | A-5 — 1벌로 만든다 |

---

## 5. cross-reference

- [plan.md](./plan.md) §3 Phase 1
- **[../r1/phase4-render-boundary.md](../r1/phase4-render-boundary.md)** — **이 phase 의 선행이자 계약 정의.** 4-A(HAL)·4-B(이벤트·좌표)·4-C(완성 프레임)·4-C7(반환 계약)·4-E(공유 서피스)
- [../rendering-boundary.md](../rendering-boundary.md) — 렌더 경계 사양서
- [phase3-render-path.md](./phase3-render-path.md) — 후행. 이 phase 의 계약 위에서 렌더 코어 13.8k LOC 를 걷어낸다
- [phase5-measure-controls.md](./phase5-measure-controls.md) — C-1 의 좌표 계약이 측정 이관의 전제
- [../../review/protocol-device.md](../../review/protocol-device.md) §5.1 — 500C/P 프레임 특성
