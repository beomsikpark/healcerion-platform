# Phase 2 — SDK/ADK 어댑터 계층

> **상태**: 미시작
> **범위**: [plan.md §1.1](./plan.md) 의 이음매 넷을 어댑터 뒤로 넣는다. **화면을 바꾸지 않는다** — `moana` UI 가 `framework/` 대신 SDK/ADK 를 보게만 한다.
> **선행**: [Phase 0](./phase0-repo-scope-cut.md)(옮길 대상 축소) · [Phase 1](./phase1-render-composition.md)(프레임을 받을 경로 확정)
> **후행**: [Phase 3](./phase3-render-path.md) 이후 전부
> **근거**: [plan.md §1.1·§1.2](./plan.md)
> **실측 기준**: `moana` `origin/service_QT693` · `sonex-framework` `origin/master` `e17280b2`. `[실측]` 은 2026-08-02 직접 측정분이다.

---

## 1. 배경

### 1.1 이 phase 가 계획에서 가장 큰 작업이다

`moana` 가 다시 장비를 구동하는 것은 **이 phase 가 끝나야**다. [Phase 0](./phase0-repo-scope-cut.md) 이 옛 모델을 지웠고 새 모델은 SDK 에 있으므로, 그 사이 구간은 **빌드는 되지만 동작하지 않는 상태**다.

### 1.2 명령 표면 — 통짜 구조체 vs 개별 request 가 최대 변환 지점 `[실측]`

`SONON_CMD_*` 는 `framework/Include/SononCommon.h:315-402` 에 블록으로 정의된다 — 기본 0~37, `#if HC_SONON_500L` 블록, `#ifdef HC_SONON_500_SN` 블록, `#ifdef HC_POWER_DOPPLER` 블록, 디버그 3종, 99~101.

SDK 는 `sdk/include/HCRequestCommands.h` 에 **약 150개**의 `REQUEST_*` 를 갖는다.

**대응이 명백한 것이 다수다** — 1:1 로 붙는 예:

| moana | SDK | 줄 |
|---|---|---|
| `GAIN`·`DR`·`TGC`·`DEPTH`·`B_FOCAL`·`MULTI_FOCAL`·`FRAMERATE`·`SA_MODE`·`B_TX_FREQUENCY` | `B_GAIN`·`B_DR`·`B_TGC`·`B_DEPTH`·`B_FOCAL`·`B_MULTI_FOCAL`·`B_FRAMERATE`·`B_SA_MODE`·`B_TX_FREQUENCY` | 464~508 |
| `WRITE_C_GAIN`·`CF_FOCAL`·`CF_FILTER_SETTING`·`CF_TX_FREQUENCY`·`DOPPLER_CTRL` | `CF_GAIN`·`CF_FOCAL`·`CF_FILTER`·`CF_TX_FREQUENCY`·`CF_ENABLE_DOPPLER` | 745~751 |
| `FW_UPGRADE_START`·`_PROGRESS`·`_STATUS`·`FW_VERSION`·`FW_UPGRADE_SN_*` | `FIRMWARE_UPGRADE_*` | 370~388 |
| `DEVICE_OPEN`·`SCAN`·`DEVICE_INFO`·`SPEC_INFO`·`WIFI_SETUP`·`RESET`·`SHUTDOWN`·`POWEROFF` | `CONNECT_SCANNER`·`SCAN_START`·`GET_SCANNER_INFO`·`GET_SCANNER_SPEC`·`WIFI_SETTING`·`REBOOT`·`SHUTDOWN`·`POWER_OFF` | 162~377 |

**그러나 구조가 갈리는 지점이 하나 있고, 그것이 이 phase 의 실제 작업량이다.**

> **`moana` 는 PW·CF·M 의 UI 파라미터를 `WRITE_*_PARAM` 통짜 구조체 하나에 묻어 보내고, SDK 는 개별 request 로 쪼개 놓았다.**
>
> SDK 쪽 개별 request 예 — PW: `PW_INVERT`·`PW_STEER`·`PW_PRF`·`PW_GAIN`·`PW_SAMPLE_VOLUME`·`PW_CORRECTION_ANGLE`·`PW_SWEEP_SPEED`·`PW_SOUND_VOLUME`·`PW_CURSOR_POS`·`PW_BASELINE`(774~925) · CF: `CF_INVERT`·`CF_STEER`·`CF_ROI_SIZE`·`CF_FLOW_SPEED`·`CF_ROI_POSITION`·`CF_INIT_PARAM`(678~755) · M: `M_SWEEP_SPEED`·`M_CURSOR_POS`(944·951).
>
> **즉 어댑터는 이름 매핑이 아니라 구조 분해다** — `moana` 가 구조체 하나를 보내던 자리에서 SDK request 여러 개를 순서대로 보내야 하고, **어느 필드가 바뀌었는지 판정하는 책임**이 새로 생긴다.

### 1.3 죽은 명령이 이미 상당수다 — 옮기지 않는다 `[실측]`

| 범주 | 명령 | 근거 |
|---|---|---|
| **app 발신 0건** | `READ_DOPPLER_PARAM` · `READ_PW_PARAM` · `READ_M_PARAM` · `SET/READY/GET_SN_ADC_DUMP` | app 참조 0 |
| **사실상 죽음**(테이블 등록만) | `RESET`(1) · `FULL_ADC_DUMP`(1) · `LINE_DENSITY`(2) · `SAMPLE_512`(2) · `PROBE_FLIP`(2) | `PROBE_FLIP` 은 주석이 사유를 남겼다 — *"OpenGL Flip 으로 대체"*(`SononCtrlPacket.cpp:250`) |
| **죽은 함수** | **`sendCommand_FPGA_B_Func`(`ControlCommand.cpp:2225`) — 호출처 0건** | [plan.md §1.6](./plan.md) 이 지적한 Harmonic·Compound 명령이 정확히 이것이다 |

> **`sendCommand_FPGA_B_Func` 가 이 계획의 표본이다** — `moana` 에 Harmonic·Compound 명령 함수가 있지만 **아무도 부르지 않고 QML UI 도 없다.** 껍데기만 있는 것을 "있다"로 세면 안 된다. 실제 구현은 [Phase 5](./phase5-measure-controls.md) 가 SDK 힌트 위에서 새로 한다.

### 1.4 SDK 에만 있는 것이 많고, 그것이 이득이다 `[실측]`

`moana` 에 대응 명령이 없는 SDK request 군:

| 군 | 예 | 함의 |
|---|---|---|
| **필터** | `FRAME_AVERAGE`·`SRI_FILTER`·`GRAYMAP`·`CVIE_*` 4종(527~624) | `moana` 는 이것을 `framework/ImageProc` 에서 **직접 호출**했다. 명령이 아니라 함수였다 |
| **측정 9종** | `MEASUREMENT_*`(1016~1197) | [Phase 5](./phase5-measure-controls.md) 의 입력 |
| **CF·PW·M UI 파라미터** | §1.2 | 통짜→개별 분해 대상 |
| ADK 영역 | DICOM 12 · DB 25 · Cloud 31 · Backup 5 · Capture/Review 5 | [Phase 4](./phase4-data-layer.md) 의 입력 |
| 기타 | `SET_STREAM_PIPELINE`·`REWIND_FRAME`·`EXPORT_RENDER_IMAGE`·`START/STOP_RECORDING` | — |

**`moana` 에만 있고 SDK 에 대응이 없는 것**: `SCAN_READY` · `KEY_EVENT` · `EMERGENCY_EVENT` · `KEEP_ALIVE` · `PROBE_TYPE` · `TIME_SYNC` · `IMAGE_PROCESS` · `IMAGE_REVERSE` · `M_OFF` · `DEBUG_*` 3종 · `FPGA_B_FUNC`.

> **이 목록을 그냥 버리면 안 된다.** `KEEP_ALIVE`·`EMERGENCY_EVENT`·`KEY_EVENT` 는 장비 세션 유지·물리 버튼·긴급 이벤트라 **기능이 사라지면 티가 난다.** SDK 가 내부에서 처리하는지, 정말 없는지를 Step 2-A 가 가른다.

### 1.5 `SononFrame` → `HC::StreamData` — 이름 매핑이 아니라 의미 변경이 섞여 있다 `[실측]`

`framework/SononClient/SononFrame.h` ↔ `sdk/include/HCStreamData.h:28-148`.

**1:1 로 붙는 것**(대부분): `frame_num`→`frameNo` · `timestamp` · `gain`/`dr`/`tgc1-4`/`depth`/`fl`→`ScanParamB` 대응 · `fps`→`framerate` · `imageWidth/Height`→`ImageData::width/height`.

**구조가 바뀌는 것 — 여기가 위험 지점이다.**

| # | 변경 | 내용 |
|---|---|---|
| ① | **데이터 포인터 5 → 2** | `image`·`cdata`·`pwdata`·`pwsound`·`mdata`(`:262-266`) → `imageData`(`:35`) + `audioData`(`:36`). **타입별 분기가 SDK 안으로 들어갔다** |
| ② | **`scanLine`/`lineNum` → `linePosition` — 의미가 다르다** | `moana` 는 **절대 index**(`:250-252`), SDK 는 **0~1 비율**(`:33`). **단위 변환이 아니라 좌표계 변환**이다 |
| ③ | **`refB` 가 없다** | `moana` 는 PW/M 프레임이 참조 B 프레임 포인터를 들고 다닌다(`:255`). SDK 는 `isFrameForScanMode()`(`:106`)로 타입만 판별한다 — **PW/M 의 B 연동을 재설계해야 한다** |
| ④ | **수명 관리 방식이 다르다** | `moana` = `clone*()` 수동 복제(`:187-190`), SDK = **refcount**(`increase/decreaseReferenceCount`, `:92-104`). **소유권 규약이 바뀐다** |
| ⑤ | **자리가 없는 필드** | `fl2`(multi-focal 2nd) · `multiFocus`/`multiFocusable` · `probeType` · `presetName` · `elem_size` · `dataUnit` · `interval` · `recordStart` |

> **⑤는 어댑터가 사이드카로 들고 있어야 한다.** SDK `StreamData` 에 자리가 없다고 UI 가 그 정보를 안 쓰는 것은 아니다 — `multiFocus` 는 화면 표시에, `presetName` 은 프리셋 UI 에 쓰인다. **어느 것이 SDK 다른 API 로 얻어지고 어느 것이 진짜 없는지를 Step 2-C 가 가른다.**

### 1.6 `ScanContext` — 397회가 한 파일에 몰려 있다 `[실측]`

`framework/Common/ScanContext.h:110-204`. app 접근 397회 중 **`app/Sources/DeviceControl/ScanContextSetting.cpp` 한 파일이 315건**이다.

| 범주 | 필드 | app 접근 |
|---|---|---|
| 스캔 파라미터 | `scanMode`·`probeType`·`probeID`·`presetName`·`lines`·`samples`·`freqIndex` | **직접 write** |
| 영상처리 | `grayMapIndex`·`frameAverage*`·`sriLevel`·`cvlmKey`·`cviePreset`·`cvieSetting` | 직접 write |
| B 파라미터 | `gain`·`dr`·`tgc[4]`·`depth`·`fl`·`fl2`·`mi`·`ti`·`fps`·`reverse` | 대체로 write |
| 모드 구조체 | `bParam`·`dopplerParam`·`pwParam`·`mParam` | **객체 대입은 안 하고 내부 멤버를 직접 write** — dopplerParam 72 · pwParam 48 · bParam 17 · mParam 15 |
| **측정결과** | `measures`·`volumeInfo`·`measureInfo` | **직접 접근 0건** — `addMeasure*()` 26개 메서드 경유(`:32-100`) |
| 세션상태 | `temperature`·`batteryLevel`·`scanCount`·`freezeCount` 등 | **app 접근 0** — framework 가 채운다 |
| 락 | `QMutex mutex`(`:203`) + `lock()/unlock()` | **app 이 수동 호출** |

**두 가지가 유리하다.**
1. **315/397 이 한 파일**이라 어댑터 삽입 지점이 사실상 하나다.
2. **측정결과는 이미 메서드 경유**라 캡슐화가 돼 있다 — [Phase 5](./phase5-measure-controls.md) 가 여기를 갈아끼우면 된다.

**불리한 것**: 세션상태를 framework 가 채우던 것이 SDK 로 넘어가므로 **누가 온도·배터리를 채우는가**가 새로 정해져야 한다.

### 1.7 중복 enum 이 하나 있다 `[실측]`

`app/Sources/Common/AppCommon.h:103-133` 에 `SONON_CMD_*` 0~26 만 담긴 **별도 enum 사본**이 있다. `SononCommon.h` 의 정본과 값이 어긋나면 조용히 잘못된 명령이 나간다.

→ **어댑터 도입 시 이 사본을 먼저 없앤다**(Step 2-A A-4).

---

## 2. 진행 단계

### Step 2-A. 명령 계층 어댑터

**`app/Sources/DeviceControl/ControlCommand.cpp` 가 유일 통로**이므로 여기 한 곳에서 갈린다([plan.md §1.2](./plan.md) — app 에서 `SononClient` 직접 호출 0건).

| # | 작업 |
|---|---|
| A-1 | **죽은 명령을 먼저 제외**한다(§1.3) — 옮기지 않는 것이 가장 싼 이관이다 |
| A-2 | **1:1 대응군을 먼저 붙인다**(§1.2 표) — B·CF·펌웨어·세션 계열. 기계적이라 위험이 낮다 |
| A-3 | **통짜→개별 분해**(§1.2) — `WRITE_PW_PARAM`·`WRITE_DOPPLER_PARAM`·`WRITE_M_PARAM` 을 SDK 개별 request 로 쪼갠다. **변경 필드 판정 책임이 어댑터에 생긴다** — 전체를 매번 보낼지, diff 만 보낼지 정한다 |
| A-4 | **중복 enum 제거**(`AppCommon.h:103-133`, §1.7) — 정본 하나로 |
| A-5 | **대응 없는 moana 명령 판정**(§1.4) — `KEEP_ALIVE`·`EMERGENCY_EVENT`·`KEY_EVENT`·`TIME_SYNC`·`PROBE_TYPE`·`SCAN_READY`·`M_OFF` 이 SDK 내부에서 처리되는지 확인. **없으면 기능 손실이므로 목록으로 낸다** |
| A-6 | `IMAGE_PROCESS`·`IMAGE_REVERSE` 는 **앱측 명령**(99~101 구간)이라 장비로 나가지 않는다 — SDK 필터 request(`SRI_FILTER`·`GRAYMAP` 등)로 대체 |

### Step 2-B. 상태 어댑터 — `ScanContext`

| # | 작업 |
|---|---|
| B-1 | **`ScanContextSetting.cpp`(315건)를 먼저 친다** — 여기가 어댑터 삽입 지점이다 |
| B-2 | **필드 범주별로 끊는다**(§1.6) — 스캔 파라미터 → 영상처리 → B → 모드 구조체 순. **한 번에 397개소를 바꾸지 않는다** |
| B-3 | **세션상태(온도·배터리·카운터) 공급자를 정한다** — framework 가 채우던 것을 SDK 가 채우는지, 앱이 폴링하는지 |
| B-4 | **락 규약을 정리한다** — app 이 `lock()/unlock()` 을 수동 호출하는 구조가 SDK 상태로 옮겨가면 무의미해진다. **어느 것이 SDK 소유이고 어느 것이 앱 로컬인지** 가른다 |
| B-5 | `measures`·`volumeInfo`·`measureInfo` 는 **건드리지 않는다** — [Phase 5](./phase5-measure-controls.md) 소관이고 이미 메서드 경유라 분리돼 있다 |

### Step 2-C. 프레임 어댑터 — `SononFrame` ↔ `StreamData`

| # | 작업 |
|---|---|
| C-1 | **어댑터를 먼저 세운다.** 585개소를 동시에 치환하지 않는다 — `SononFrame` 인터페이스를 유지한 채 내부를 `StreamData` 로 채우는 형태 |
| C-2 | **①포인터 5→2** — 모드별 접근자(`image`/`cdata`/`pwdata`/`mdata`)를 `imageData` 위에서 재현 |
| C-3 | **②`linePosition` 비율 변환** — 절대 index ↔ 0~1 비율. **`samples`/`scanlines` 를 알아야 변환되므로 어댑터가 그 값을 함께 들고 있어야 한다** |
| C-4 | **③`refB` 재설계** — PW/M 프레임이 참조 B 프레임을 어떻게 얻을지 정한다. SDK 가 모드별 스트림을 어떻게 노출하는지 확인이 선행 |
| C-5 | **④수명 규약 전환** — `clone*()` 호출부를 refcount(`increase/decreaseReferenceCount`)로. **누수·이중해제가 나기 쉬운 지점**이라 범위를 좁게 끊는다 |
| C-6 | **⑤사이드카 필드 판정** — `fl2`·`multiFocus*`·`probeType`·`presetName`·`elem_size`·`dataUnit`·`recordStart`. **SDK 다른 API 로 얻어지는 것과 진짜 없는 것을 가른다** |

### Step 2-D. SDK 공개 헤더 문제 대응

**C++ 소비자는 이걸 착수 첫날 만난다.**

| # | 작업 |
|---|---|
| D-1 | `sdk/include/` 를 실제로 include 해 컴파일한다. **`HCScannerModelSpec.h` 는 `-fsyntax-only` 를 통과하지 못한다**(`<list>` 미인클루드·`float_t` 미정의·`String`/`rect` 미정의, [r1 Phase 6 §6-B](../r1/phase6-samples-support.md)) |
| D-2 | 앱이 부르는 `hc_*` 중 **정의 0건인 것**을 목록화한다 — Flutter 기준 108개 중 29개였다([r1 Phase 8 §1.3](../r1/phase8-app-migration.md)). **Qt/C++ 는 링크 에러로 전부 드러난다** |
| D-3 | **해소는 [r1 Phase 3-F](../r1/phase3-layer-boundary.md) 소관이다** — 이 phase 는 **요구 목록을 내고 r1 에 넘긴다.** 자체 우회(스텁·복사 헤더)를 만들지 않는다 |
| D-4 | `moana` 의 `CModel::isValid*()` 30여 종([Phase 0 A-3](./phase0-repo-scope-cut.md) 보류분)을 SDK 값 범위로 교체 |

---

## 3. 검증

| # | 항목 | 방법 | 기대 |
|---|---|---|---|
| 3.1 | **500C 실장비 연결** | 연결 → 장치정보 조회 | **성공. 이 phase 의 첫 실동작 판정이다** |
| 3.2 | 스캔 시작·정지 | B 모드 | 성공 |
| 3.3 | 파라미터 반영 | gain·depth·TGC·focal 변경 | 화면에 반영 |
| 3.4 | **통짜→개별 분해 정합** | PW·CF 파라미터 전체를 UI 로 훑는다 | 모든 필드가 장비에 전달 |
| 3.5 | `framework/` 참조 | `app/` 에서 `SononClient`·`ScanManager` 참조 | **0건** |
| 3.6 | 중복 enum | `AppCommon.h` 의 `SONON_CMD_*` 사본 | **부재** |
| 3.7 | 프레임 수명 | 장시간 스캔 메모리 | 누수 없음 |
| 3.8 | **대응 없는 명령** | §1.4 목록의 기능(세션 유지·물리 버튼·긴급 이벤트) | **동작하거나, 미지원으로 문서화** |
| 3.9 | 바인딩 정합 | 링크 에러 | **0건**(D-2 목록 해소 후) |

> **3.1 이 이 계획 전체의 전환점이다** — [Phase 0](./phase0-repo-scope-cut.md) 이후 처음으로 장비가 돈다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`linePosition` 비율 변환을 놓친다**(§1.5 ②) | PW/M 커서 위치가 어긋난다 — **측정값에 직결** | C-3 — 변환 함수를 한 곳에 두고 단위테스트를 붙인다. **절대/비율 혼용이 가장 잡기 어려운 버그다** |
| **`refB` 부재**(③) | PW/M 화면에서 B 배경이 안 나오거나 어긋난다 | C-4 — SDK 의 모드별 스트림 노출 방식을 **먼저 확인**하고 설계한다 |
| **refcount 전환 중 이중해제·누수**(④) | 크래시 또는 메모리 증가 | C-5 — 범위를 좁게 끊고 3.7 로 판정 |
| **397개소를 한 번에 바꾼다** | 회귀 원인 특정 불가 | B-2 — 범주별 단계. 315건이 한 파일이라 단계화가 쉽다 |
| **통짜→개별 분해에서 필드가 빠진다** | 특정 파라미터가 조용히 전달 안 됨 | 3.4 — UI 로 전 필드를 훑는 검증을 명시. **코드 리뷰로 잡지 않는다** |
| **SDK 헤더가 컴파일되지 않아 착수가 막힌다** | 일정 지연 | D-3 — r1 에 넘기고 **자체 우회를 만들지 않는다.** 우회는 나중에 두 벌 정본을 만든다 |
| **대응 없는 명령을 조용히 버린다**(§1.4) | 세션 끊김·버튼 무동작이 나중에 발견 | A-5·3.8 — 목록으로 내고 미해결분은 **미지원으로 문서화** |
| **`moana` 세션상태 공급자 공백**(B-3) | 온도·배터리 표시가 죽는다 | B-3 을 명시 항목으로. UI 는 남아 있는데 데이터가 없으면 티가 난다 |

---

## 5. cross-reference

- [plan.md](./plan.md) §1.1(이음매 넷)·§1.2(장비 통신 격리)
- [phase0-repo-scope-cut.md](./phase0-repo-scope-cut.md) — 선행. A-3 이 보류한 `isValid*()` 가 여기 D-4 로 온다
- [phase1-render-composition.md](./phase1-render-composition.md) — 선행. 프레임을 받을 경로
- [phase3-render-path.md](./phase3-render-path.md) — 후행. 이 phase 의 프레임 어댑터 위에서 렌더를 교체한다
- [phase4-data-layer.md](./phase4-data-layer.md) — ADK 영역(DICOM·DB·Cloud·Backup request 군)
- [phase5-measure-controls.md](./phase5-measure-controls.md) — 측정 9종 request 와 `addMeasure*()` 교체
- [../r1/phase3-layer-boundary.md](../r1/phase3-layer-boundary.md) — **D-3 의 해소처**(공개 헤더 정본화)
- [../r1/phase6-samples-support.md](../r1/phase6-samples-support.md) §6-B — SDK 헤더가 컴파일되지 않는다는 실측
- [../r1/phase8-app-migration.md](../r1/phase8-app-migration.md) §1.3 — 바인딩 오탐 29/108(Flutter 기준)
