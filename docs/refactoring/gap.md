# 목적 대비 현재 구현 — 실측 판정

> **질문**: `[CTO]` "현재 sonex 의 실제 구현이 원래 목적에 맞게 잘 되었는가."
> **근거**: `client/legacy/sonex-framework` `master` `f336e25b`(2026-07-23) · `client/legacy/sonex-app` 코드 직접 확인(2026-07-29). 판정 기준은 [goal.md](goal.md).
> **브랜치 구도**: 로컬 HEAD == `origin/master` == `f336e25b`. **이 저장소는 master 가 주 개발선이고 master 스냅샷이 곧 현행이다** — `dev/adk_v0.51.0`·`adk_work` 는 완전 병합됐고 master 밖은 `feature-apply_v1.23.4` 2커밋뿐이다. 근거 = [../review/sonex-framework.md](../review/sonex-framework.md) 머리말.

## 1. 한 줄 판정

**구조는 계획대로 됐고, 제품화가 비어 있다.**

설계 문서와 코드를 줄 단위로 대조하면 3계층 분리·모듈 파이프라인·데이터 모델은 **설계대로 구현됐다.** 그런데 그 SDK 를 **외부에 실제로 넘길 수 있게 만드는 것들**이 전부 없다.

| 기준 | 판정 | 한 줄 근거 |
|---|---|---|
| **A1** 기능 동등성 | **판정 불가** | `moana` 기능 정본 목록이 존재하지 않는다 |
| **A2** 모델 커버리지 | **충족** | sonex 의 5종(300C·300L·500C·500L·500P)이 존속 제품 라인이고, 미포함 5종은 단종이다 |
| **A3** 출하 경로 | **미착수** | 인증·국가 변종 처리 방식이 정해지지 않았다 |
| **B1** 재현 가능한 빌드 | **불가** | **ANGLE 상수 정의가 저장소에 없어 `ImageRenderer` 가 전 플랫폼 컴파일 불가**(§5.1). Linux 는 지원 대상 자체가 아니다(§5.3) |
| **B2** 배포 아티팩트·버전 | **없음** | 앱↔SDK 버전 고정 장치가 없다 |
| **B3** API 계약 | **약함** | 제네릭 디스패처 — 컴파일러가 오용을 잡지 못한다 |
| **B4** 재배포 라이선스 | **미정리** | 서드파티 고지 0건, CVIE 재배포 권한 미확인 |
| **B5** 샘플·문서 | **부분 달성** | 샘플 9개 실재하고 사용 형태 2종 구조도 있으나, **`언어 × 형태` 12칸 중 6칸이 빈다**(C++·Python·Flutter 양쪽 부재). B1 때문에 고객사가 빌드할 수도 없다 |
| **B6** 지원 경계 | **없음** | 2023년 설계 문서가 제기한 뒤 3년째 미결 |

## 2. 달성한 것 — 먼저 명확히 해 둔다

목적 대비 미달을 논하기 전에, **설계대로 된 것이 상당하다.**

| 항목 | 실측 |
|---|---|
| **3계층 분리** | `sdk/sdk`(SDK) · `sdk/adk`(ADK) 경계 유지. **ADK→SDK 단방향 의존, 역방향 심볼 0건** |
| **모듈 파이프라인** | 2023년 `Module Pipe Interface` 설계가 `HCModulePipeInterface` 에 **함수명까지 거의 그대로** 구현됨. 6개 모듈이 전부 상속 |
| **모듈 내부 API** | `DeviceManager` 의 `connectDevice`·`sendCommand`·`addScanDeviceResultCallback` 등이 **2023년 명세와 시그니처까지 일치** |
| **데이터 모델** | 설계 21종이 `HCScannerInfo`·`HCStreamData`·`HCScannerModelSpec` 등으로 그대로 존재 |
| **ANGLE 기술 선택** | **현 시점에도 유효하다** — §3 |
| **샘플 앱** | Windows C# WPF · Android · iOS 3종 실재 (계획대로) |
| **기능 확장** | 측정 항목이 설계 5종 → **12종**(태아 계측·심박 추가), 렌더 오브젝트가 probe 종류별로 세분화 |

상세 대조 = [../review/SoNex-Requirement/summary.md](../review/SoNex-Requirement/summary.md).

**즉 문제는 설계 능력이나 구현 품질이 아니다.** 만든 것을 **남에게 넘길 수 있는 형태로 포장하는 단계**가 통째로 비어 있다.

## 3. ANGLE — 배포 가능성의 실측

> **층위 주의**: ANGLE 자체는 **원인이 아니라 증상**이다. 원인은 SDK 책임 범위에 그래픽·UI 레이어가 포함된 것이며, 이 절의 결손과 §4 의 계층 침범이 거기서 파생된다. 원인 분석과 해소안 = **[rendering-boundary.md](rendering-boundary.md)**.

### 3.1 기술 판단 자체는 지금도 옳다

2023년 계획서가 ANGLE 을 고른 근거(Android·iOS·Windows 공통, 검증된 안정성)는 3년 뒤에도 성립한다. 그리고 코드는 **Apple 의 OpenGL ES deprecation 을 정확히 회피**하고 있다.

| 플랫폼 | ANGLE 백엔드 우선순위 (`HCImageRenderCore.cpp:775-793`) |
|---|---|
| Windows | D3D11 → D3D9 → Vulkan → OpenGL |
| **iOS / macOS** | **Metal** → Vulkan → OpenGL |
| Android | Vulkan → OpenGL |

EAGL(Apple 이 deprecate 한 API)을 직접 쓰는 `HCiOSGLContext.mm` 은 **CMakeLists 에서 주석 처리돼 빌드되지 않는다** — *"HCiOSGLContext는 ANGLE 사용 시 불필요"*(`sdk/sdk/Main/ios/CMakeLists.txt:68-71`). 죽은 코드로만 남아 있다.

### 3.2 그런데 바이너리가 없고, 선언된 경로 세 곳이 서로 다르다

| 선언 위치 | 선언 경로 | 디스크 |
|---|---|---|
| `third_party/readme.txt` | `third_party/angle/out/{android_v7a,v8a,x64,ios_arm64,ios_x64,windows_x64}` | **부재** |
| iOS CMakeLists | `sdk/adk/library/angle_ios/libEGL.xcframework/…` | **부재** (git 추적 **0건**) |
| macOS CMakeLists | `sdk/third_party/angle_macos/…` + `third_party/angle/include` | **부재** |

실제 `third_party/` 에는 `context_vision`·`nlohmann_json`·`readme.txt` 셋뿐이고, `adk/library/` 의 벤더 디렉토리 13개 중 angle 은 없다.

**의존성 하나가 빠진 문제가 아니다.** 세 문서가 서로 다른 경로를 가리키면서 셋 다 없다는 것은, **빌드 가능한 배치가 각 개발자의 로컬에만 존재하고 저장소에는 그것을 재현할 정보가 일관되게 없다**는 뜻이다.

덧붙여 **Windows·Android 빌드 스크립트에는 ANGLE 참조가 0건**이다(`.vcxproj`·`.props`·`build_all_android.sh`). 그런데 런타임은 Windows 에서 D3D11 ANGLE 을 호출하고 EGL/GLES 라이브러리를 동적 로드한다. 그 바이너리의 출처가 빌드 시스템 어디에도 없다.

### 3.3 부수 리스크

- **커뮤니티 포크 의존** — iOS ANGLE 이 Google 공식이 아니라 `celestiamobile/angle-apple 1.1.26` xcframework 다(CMakeLists 주석 명시). 공급망 주체가 개인 프로젝트다
- **버전 고정이 iOS 에만 있다** — 1.1.26 이 주석으로 적힌 것이 전부이고, macOS·Windows·Android 는 어느 리비전인지 저장소 어디에도 없다. 플랫폼 간 GL 동작 차이가 나도 추적 근거가 없다

## 4. 계층 경계 — 코드에서는 서고 배포에서 무너진다

**계층 분리는 SoNex 의 핵심 자산이자 목적 1의 전제다.** 그런데 코드 수준과 배포 수준의 판정이 갈린다. 이 절은 그 경계를 네 각도로 실측한다 — 의존 방향(§4.1) · 분리 의도와 소속(§4.2) · 프로토콜 소유(§4.3) · ADK 의 SDK 경유 여부(§4.4) · 펌웨어 사례(§4.5).

### 4.0 ANGLE 이 세 계층을 가로지른다

**설계상 ANGLE 은 SDK 소관이다.** 계획서의 계층 범위에서 렌더링은 SDK 에만 있다. 그런데 실측하면 **세 계층 전부에 표면이 있다.**

| 계층 | ANGLE 표면 | 위치 |
|---|---|---|
| **SDK** (정당) | `EGL_PLATFORM_ANGLE_*` 직접 호출, 백엔드 폴백 구현 | `ImageRenderer/shared/HCImageRenderCore.cpp` |
| **ADK** (누수 ①) | **SDK 빌드가 ADK 디렉토리의 바이너리를 참조** — `${SDK_ROOT}/../adk/library/angle_ios/…` (`SDK_ROOT`=`sdk/sdk`). 주석: *"third_party 경로 → sdk/adk/library/ 우리 환경 일치"* | `sdk/sdk/Main/ios/CMakeLists.txt:111-112,134-135` |
| **ADK** (누수 ②) | **ANGLE 때문에 ADK 에 우회 코드 발생** — *"Windows 는 ANGLE HWND 라 C#(WPF)이 화면 픽셀을 직접 못 읽는다. 그래서 ADK 가 captureFrame() 의 …"* | `HCSonexADK.cpp:373` · `HCDicomController.cpp:950` |
| **APP** | Android: `libEGL_angle.so`·`libGLESv2_angle.so` 를 앱 빌드에 링크 / Windows: `libEGL.dll`·`libGLESv2.dll` 을 **Dart 에서 순서를 지켜 명시적 로드** | `android/app/CMakeLists.txt:37-38` · `lib/services/sdk/NativeMethods.dart:93-94` |

**외부 고객사 관점의 결론**: SDK 만 받아서는 동작하지 않는다. ANGLE 바이너리를 배치하고 **정해진 순서로 로드하는 책임이 앱 계층(=고객사)** 에 있는데, **그 순서 지식이 SDK 헤더나 문서가 아니라 힐세리온 자체 앱의 Dart 소스에만** 있다. 고객사는 Flutter 를 쓰지 않을 수 있으므로 이 지식은 전달되지 않는다.

### 4.1 의존 방향 — 코드는 지켜지고 빌드에서 깨진다

**올바른 형태는 상호 무의존이 아니라 단방향이다.** `APP → ADK → SDK` 계층 스택이며, ADK→SDK 는 설계상 정상이고 필수다 — 계획서가 ADK 를 "SDK 위에 얹는 앱 지원 기능"으로 정의하고, *"Application의 기술 독립적 개발 환경을 조성하여 GUI 환경의 경략화"* 라는 목적이 **오케스트레이션을 ADK 에 두도록 강제**하기 때문이다. 금지 대상은 역방향(SDK→ADK) 하나다.

| 방향 | 수준 | 실측 |
|---|---|---|
| ADK → SDK (정상) | 코드 | **7파일**이 SDK 참조 — 설계대로 |
| **SDK → ADK (금지)** | 코드 | **0건** — 지켜지고 있다 |
| **SDK → ADK (금지)** | **빌드** | **iOS CMakeLists 10건** — `../adk/library/{angle,freetype,opencv,openssl}_ios/…` |

**역방향은 iOS 국소 이탈이다.** macOS CMakeLists 는 중립 위치(`../third_party/angle_macos/`)를 쓰며, 이동 주석이 *"Phase 2-C C-2: third_party 경로 → sdk/adk/library/ 우리 환경 일치"* 로 **설계 판단이 아니라 당시 로컬 환경 편의**임을 밝힌다.

**목적 1에서 이것이 왜 문제인가**: 고객사가 **SDK 만** 가져가는 시나리오가 성립해야 한다(초음파 기능만 필요하고 계정·클라우드는 자기 것을 쓰는 경우). 더구나 ADK 는 힐세리온 서버에 결합돼 있어 그대로 넘기기 곤란하다. 그런데 지금 iOS 는 **SDK 만 떼어도 `adk/library/` 를 함께 가져가야 한다** — 계층을 나눈 이유가 배포 단계에서 무효화된다.

**해소 난이도는 낮다** — 코드 역방향이 0건이라 소스는 손댈 것이 없고 iOS CMakeLists 경로 문제다. 다만 [plan.md](plan.md) Phase 1-2(경로 일원화)·0-3(의존성 확보)과 묶여야 실효가 있다. 경로만 되돌려도 §3.2 때문에 여전히 빌드되지 않는다.

> **판정은 기준에 따라 갈린다.** 심볼 의존 기준에서는 역방향이 없다([../review/sonex-app.md §2](../review/sonex-app.md)). **빌드 기준으로는 iOS 에서 SDK → ADK 역방향이 실재한다.** 계층 분리는 코드 수준에서 성립하고 배포 수준에서 성립하지 않는다.

**그리고 이것은 ANGLE 하나의 문제가 아니다** — 같은 `adk/library/` 경로에 freetype·opencv·openssl 이 함께 있다. **서드파티 배치 규약 자체가 계층 경계를 무시**하고 있고 ANGLE 은 가장 눈에 띄는 사례일 뿐이다.

### 4.2 SDK/ADK 분리의 의도와 경계 실측

**분리 의도** `[계획서]` §4 — **SDK = "Ultrasound 기술 총괄" · ADK = "Application 기술 총괄"**. 선은 **초음파 기술 대 응용 서비스**이며, 이 선이 필요했던 이유는 넷이다.

| # | 이유 | 근거 |
|---|---|---|
| 1 | **외부 제공 단위가 둘** | `[계획서]` *"외부 업체의 **SDK / ADK** 제공 요청"* — 요청 자체가 두 단위. 한 덩어리면 "초음파만" 선택지가 없어지고 힐세리온 계정·클라우드를 고객사에 강제하게 된다 |
| 2 | **결합 대상이 달라 변경 축이 갈린다** | SDK 는 **장비**(모델별 `InstructionSet` 5종·펌웨어·HC 프로토콜), ADK 는 **서버**(클라우드 API·PACS) |
| 3 | **`moana` 실패의 교정** | `[계획서]` *"Framework와 App으로 분리되어 있으나 **실제 동작에서는 경계가 모호함**"*. 3계층은 재시도이며, 계층마다 별도 산출물(`.dll`/`.so`)로 **경계를 링커가 강제**한다 |
| 4 | 팀 경계 | `sonex-framework/CLAUDE.md` 가 ADK="담당 영역"·SDK="다른 팀". 단 **같은 저장소**라 저장소 경계와 어긋난다 |

**두 계층의 도메인 모델이 실제로 다르다** — `[실측]` `HC::DeviceManager` 가 양쪽에 각각 있고 뜻이 다르다.

| | SDK (`sdk/sdk/DeviceManager/shared/`) | ADK (`sdk/adk/Main/shared/managers/`) |
|---|---|---|
| "device" 의 뜻 | **물리 스캐너** — 소켓 연결·명령 전송 | **클라우드 등록 자산** — `registerDevice`·`getDeviceList`·`registerBattery` |

분리의 정당성을 뒷받침하는 동시에, **같은 네임스페이스 `HC` 에 동명 클래스가 둘**이라 고객사가 양쪽 헤더를 함께 쓸 때 충돌 위험이 있다(공개 헤더 노출 여부는 §9 미확인).

### 4.3 SDK 는 장치 프로토콜의 정당한 소유자다

`[실측]` `sdk/sdk/DeviceManager/shared/` 가 그대로 프로토콜 스택이다.

| 계층 | 파일 |
|---|---|
| 패킷 정의 | `HCPacketData` — `HC_PACKET_HEADER_SIZE = 14` · `0x48`(`'H'`) · `0x43`(`'C'`) |
| 소켓 전송 | `HCSocketCommunicator` · `HCCompatibleSocket`(Windows·Android·iOS) · `HCSocketEvent` |
| 송수신 스레드 | `HCTxWorker` · `HCRxWorker` |
| 모델별 명령셋 | `HCInstructionSet` + **300C·300L·500C·500L·500P·Default 6종** |

14바이트 `'H','C'` 헤더는 [legacy/proof/protocol-sot/](legacy/proof/protocol-sot/) 의 정본과 같은 프로토콜이다. **계층 배치가 옳다.**

### 4.4 ADK 는 SDK 를 쓰는가 — 원칙은 지켜지고 iOS 에서 무너진다

`[실측]` ADK 트리에 `HC_PACKET_HEADER`·`SocketCommunicator`·`InstructionSet` **0건**. `FirmwareController` 가 흐름을 명시한다 — *"FTP 업로드 → **SDK** `DEVICE_FW_UPGRADE` → 진행률 relay"*. **장비 명령은 SDK 를 거친다.** 그러나 예외가 둘이다.

| 경로 | ADK 가 SDK 를 경유하는가 | 비고 |
|---|---|---|
| HC 프로토콜 장비 명령 | **예** | 자체 구현 0건 |
| **FTP 펌웨어 업로드** | **아니오** | `FTP_SERVER_IP="192.168.10.1"`·`FTP_USER="root"` — 장비 내장 FTP 서버에 직접 접속(`HCFirmwareController.cpp:24-27`). 주석: *"Moana FTP 접속 상수"* |
| **iOS 장치 연결** | **아니오** | `adk/Main/ios/HCSonexSDK_iOS.cpp` 에 `connectToDevice(ip, controlPort, dataPort)` 가 POSIX raw socket 으로 **중복 구현**. control·data 2소켓 구조까지 SDK 와 동일 |

**FTP 는 방어 가능하다** — 범용 네트워크 프로토콜이고 ADK 가 네트워크 담당이다. 다만 접속 대상이 장비라 계층 취지와 어긋나며 moana 상수를 그대로 옮겨왔다.

**iOS 중복 구현은 방어하기 어렵다.** 죽은 코드가 아니다 — `SonexFramework.iOS.xcodeproj` 의 Headers·Sources 에 등록돼 있고 ADK iOS 진입점이 `#include "HCSonexSDK_iOS.cpp" // 직접 포함하여 빌드` 로 소스를 인클루드한다. SDK 샘플(`sdk/sdk/sample/SDK_Sample_iOS/`)도 같은 방식으로 또 한 벌 갖는다.

**그리고 `HC::ResultCode` 가 다른 값으로 재정의돼 있다** — 같은 네임스페이스·같은 이름·같은 숫자·다른 뜻.

| 값 | SDK `HCCommon.h` | ADK `HCSonexSDK_iOS.h` |
|---:|---|---|
| 0 | `SUCCESS` | `SUCCESS` |
| **1** | `PROGRESSING` (진행 중, 오류 아님) | **`NOT_CONNECTED`** (연결 실패) |
| 2 | `PROCESS_CANCELLED` | `NOT_SUPPORTED` |
| 3 | `INVALID_PLATFORM` | `INVALID_PARAMETER` |
| 4 | `INVALID_INSTANCE` | `BUFFER_TOO_SMALL` |
| 5 | `INVALID_COMMAND` | `INTERNAL_ERROR` |

값 1 이 특히 위험하다 — SDK 기준 **정상 진행 중**이 이 헤더로는 **연결 실패**가 된다. `StreamMode` 도 함께 재정의된다. **HC 프로토콜 정본 작업에서 확인한 "같은 이름·다른 값 0건"과 정반대 상황이 SDK/ADK 경계에 있다.**

> **외부 제공 관점**: SDK 만 넘길 때 **iOS 만 다른 물건이 된다.** §4.1 의 빌드 역방향(iOS CMakeLists 10줄)과 합치면 **iOS 가 계층 규약 이탈이 집중된 플랫폼**이다.

### 4.5 펌웨어 업그레이드 — 경계가 장비 계열마다 다르다

**펌웨어 프로토콜은 두 계층에 걸쳐 갈라져 있다.** `SN_*` 명령의 **전송은 SDK 소관**이다 — `HCLiveController.cpp` 가 `REQUEST_FIRMWARE_UPGRADE_SN_START/WRITE/VERIFY/COMPLETE` 를 처리하고 base64 청크를 디코딩해 `DeviceManager::sendCommand` 로 내려보낸다. ADK 에 있는 것은 **순서 상태머신**이다.

| 구성 | 위치 | 판정 |
|---|---|---|
| SN 명령 **전송**(base64 디코딩 → 소켓) | **SDK** `HCLiveController` | 제자리 |
| SN **순서 상태머신**(B3→MSP 단계 전환 · 청크 위치 · 진행률 · stop-and-wait · 768B) | **ADK** `FirmwareController` | 제자리 (정책) — [rendering-boundary.md §7.5](rendering-boundary.md) |
| 펌웨어 버전 판정 · FTP 업로드 오케스트레이션 | **ADK** | 제자리 (정책·네트워크) |

ADK 쪽 주석이 출처를 밝힌다 — *"Moana FirmwareUpdater 미러"*. **moana 에서 옮기며 계층 배치를 재검토하지 않은 흔적이다.**

**남는 문제는 갈라졌다는 사실이 아니라 비대칭이다.**

| 장비 계열 | SDK 만으로 펌웨어 업그레이드 |
|---|---|
| **500L**(belle) | **불가** — `startFirmwareUpdate` 는 `return SUCCESS; // TODO` **껍데기**다(`HCSocketCommunicator.cpp:643`, 2026-07-30 실측). 이전 판의 "단일 호출로 가능"은 **틀렸다** |
| **500C/500P**(Socionext) | **불가** — SDK 는 낱개 명령만 제공. 몇 바이트씩·몇 번·어떤 순서로·B3 다음 MSP 인지가 **ADK 에만** 있다 |

**외부 제공 관점의 귀결**: SDK 만 받은 고객사는 500L 은 한 줄로 처리하고 500C/500P 는 상태머신을 스스로 재구현해야 한다. 같은 기능의 계약이 모델에 따라 다르다.

> **판정**: 분리 의도는 목적 1에 정확히 부합하며 **자산이다.** 문제는 "선이 있는가"가 아니라 **"선이 올바른 위치에 있는가"** 이고, 이는 구조 재설계가 아니라 **몇 개 모듈의 소속 재판정**으로 해소된다 → [plan.md](plan.md) Phase 3.

## 5. B1 재현 가능한 빌드 — 불가

### 5.1 결정적 근거 — ANGLE 상수가 저장소에 정의되어 있지 않다

`[실측]` `EGL_PLATFORM_ANGLE_ANGLE` 등 ANGLE 확장 상수를 저장소 전수 검색한 결과, **유일한 등장처가 소비처인 `HCImageRenderCore.cpp` 하나**다. 번들된 `glad_egl.h`(83KB)에도 `EGL_PLATFORM_ANGLE*` 는 **0건**이다. 정의처는 ANGLE 자체 `eglext.h`(= 부재한 `third_party/angle/include`)뿐이다.

→ **`ImageRenderer` 가 전 플랫폼에서 컴파일되지 않는다.** 링크가 아니라 **컴파일 단계에서 막힌다.**

### 5.2 플랫폼별 의존성 결손

| 플랫폼 | 디스크에 있는 것 | **없는 것** |
|---|---|---|
| Android | opencv · openssl · dcmtk · ffmpeg · cpr · curl (6종) | **angle · freetype** |
| iOS | openssl · minizip | **angle_ios · freetype_ios · opencv_3.4.6_ios** |
| macOS | — | **third_party/angle_macos · angle/include** (+ Homebrew 절대경로 의존) |
| Windows | opencv_msvc64 · ffmpeg_msvc64 | ANGLE DLL 출처가 **빌드 시스템에 없음** |

Android 가 가장 가깝다 — 벤더 6종이 갖춰져 있고 ANGLE·freetype 둘만 결손이다.

> **정확한 서술**: *"빌드가 안 된다"* 가 아니라 **"저장소만으로는 안 되고 각 개발자의 로컬 배치에 의존한다"** 이다. 힐세리온 머신에서는 빌드된다 — 2026-07-23 커밋이 *"500C/P WiFi 펌웨어 통합 굽기 — 5계층 구현 + **실장비 검증**"* 이다. **목적 1에서는 둘이 같은 말이다. 고객사에는 그 로컬 배치가 없다.**

### 5.3 Linux 구현이 현재 0 이다 — 그런데 **범위가 바뀌었다**

> **범위 변경(2026-07-30)**: Linux 가 **주 개발 PC 로 확정**됐다. Linux·Android 에서 일상 개발하고 Windows·iOS 는 포팅 시점에 동작 확인만 한다. **따라서 이 절의 "지원 대상 아님"은 더 이상 유효하지 않다** — 아래 실측은 그대로 유효하되, 그것이 **미지원 근거가 아니라 착수 비용 목록**으로 읽혀야 한다. 대응 = [r1/plan.md §0.1](r1/plan.md) · [r1 Phase 0-G·0-L](r1/phase0-build-reproducibility.md).
>
> **비용이 고르지 않다** — 소켓은 Android 구현이 **순수 POSIX**(Android 전용 API 0건)라 사실상 공짜, **오디오는 신규**(Android 가 OpenSLES), 렌더는 EGL 네이티브라 **오히려 유리**하다.

`[실측]` 플랫폼 디렉토리 분포 — `android` 14 · `ios` 11 · `windows` 14 · `macos` 2 · `shared` 14 · **`linux` 0**.

`HCCommon.h` 의 플랫폼 분기가 Windows / Android / Apple 3갈래이며 **`#else` 절이 없다.**

```c
#if   defined(_WIN32) || defined(_WIN64) || (PLATFORM == 3)      // Windows
#elif defined(__ANDROID__) || (PLATFORM == 1)                    // Android
#elif defined(__APPLE__) || defined(__MACH__) || (PLATFORM == 2)  // Apple
#endif   // else 없음. #error 도 없음
```

Linux 에서는 `OS_WINDOWS`·`OS_ANDROID`·`OS_IOS` 가 **전부 미정의**가 되고, 전처리기가 미정의 식별자를 0 으로 평가하므로 **에러 없이 모든 분기가 조용히 거짓**이 된다 — 플랫폼 구현이 하나도 선택되지 않은 채 링크 에러나 껍데기 바이너리가 나온다. **방어용 `#error` 조차 없다.**

`[계획서]` 2023년 대상은 Windows·Android·iOS 3개였고 macOS 가 후행 추가다. `sonex-app` 의 `linux/` 도 `flutter create` 스텁이다([../review/sonex-app.md §4](../review/sonex-app.md)). **즉 Linux 부재는 결함이 아니라 당시 범위의 결과이며, 범위가 바뀐 지금은 신규 작업 항목이다.**

> **곁가지**: macOS 는 전용 갈래 없이 `__APPLE__` 로 잡혀 **`OS_IOS true`** 가 된다. 렌더러는 `#elif OS_IOS || OS_MACOS` 로 쓰는데 `OS_MACOS` 는 이 헤더에 정의가 없어 0 으로 평가되고, macOS 가 iOS 분기를 타는 구조다. 동작하나 취약한 배선이다.

### 5.4 그 외 개발자 머신 의존

경로가 개발자 머신에 박혀 있다([../review/sonex-app.md §3.2·§6](../review/sonex-app.md)).

| 항목 | 실측 |
|---|---|
| macOS CMake | Homebrew 절대경로 링크 — `/opt/homebrew/Cellar/opencv/4.12.0_11/…` |
| Windows SDK DLL | 미커밋. `copy_sdk_dlls.ps1` 이 `C:\work\flutter\sonex-framework\sdk\_out\x64\bin\Release` 에서 복사 |
| iOS/macOS Framework | 미커밋. `.rb` 스크립트가 `/Users/rio/work/sonex-app/ios/Frameworks/SonexSDK.framework` 를 xcodeproj 에 주입 |
| Android `.so` | **앱 저장소에 커밋** — 39개 103MB. 누가 언제 빌드했는지 추적 불가 |
| 커밋된 빌드 캐시 | `sdk/sdk/Main/macos/build/` 194파일에 `/Users/rio/work/…` 경로가 박혀 있음 |

**고객사 환경에 `C:\work\flutter\…`·`/Users/rio/…`·Homebrew 특정 리비전은 없다.**

## 6. B2 버전 계약 — 없음

- `[실측]` 앱↔프레임워크 **버전 고정 장치가 없다.** 앱이 어느 SDK 빌드와 짝인지 저장소에서 확인할 방법이 없다
- `[실측]` semver 규약 문서(`VERSION_TAGGING.md`)는 있으나 태그가 규약을 이탈한다 — `v1.0.0-macos`(플랫폼 접미사) · 한날 5~6개 소급 태깅 · `adk_v0.51.0` · `0.x`→`3.x` 점프
- `[실측]` **CI 0건**. 산출물이 어느 커밋에서 나왔는지 보장하는 자동 경로가 없다

## 7. B3 API 계약 — 약함

`[실측]` 공개 파사드가 `hc_SendRequest(int requestCode, const wchar_t* jsonParam)` 제네릭 디스패처다. 내부는 `REQUEST_*` 매크로 `switch`-`case` 로 각 모듈에 위임한다.

외부 개발자 관점에서 문제는 셋이다.

1. **요청 코드가 헤더에 없다** — 정수 상수의 정의처가 공개 헤더가 아니다
2. **JSON 파라미터 스키마가 어디에도 선언돼 있지 않다** — 오타·누락이 런타임까지 간다
3. **컴파일러가 오용을 잡지 못한다** — 타입 계약이 `int` 와 문자열로 소거됐다

> **2023년 설계는 이 점에서 더 나았다.** 명세는 `connectDevice(ip, controlPort, dataPort, retryCount, retryInterval)` 같은 **타입 있는 개별 함수**였고, 그 형태가 외부 SDK 에 적합하다. 실제 구현은 반대 방향으로 수렴했다 — FFI 경계를 넘는 심볼 수를 줄이는 데는 유리하지만 **목적 1에서는 멀어진다.**
>
> 다만 **내부 모듈 API 는 설계대로 타입이 살아 있다**(§2). 즉 계약을 복원하는 작업은 새로 설계하는 것이 아니라 **이미 있는 내부 API 를 공개 경계로 끌어올리는 것**에 가깝다.

### 7.1 Flutter wrapper 가 없다 — 있어야 할 자리를 앱이 메우고 있다

`[실측]` 계획된 플러그인 `flutter_sonex_sdk` 는 `pubspec.yaml:114-115` 에 **주석으로만** 남아 있다. 경로가 개발자 로컬(`/Users/rio/work/sonex-framework/flutter_sonex_sdk/`)이고 저장소에 실물이 없으며 `.podspec` 도 없다. **이름으로 보아 SDK 저장소 안에 두려던 산출물인데 만들어지지 않았다.**

현재 실체는 `sonex-app` 안의 앱 코드이며 **SDK·ADK 양쪽 바인딩이 모두 여기 있다**.

| 위치 | 파일 | 줄 수 |
|---|---:|---:|
| `lib/services/sdk/` — SDK 바인딩 | 5 | **3,732** (`NativeMethods.dart` 1,869 · `record_reader_ffi` 1,010 · `record_writer_ffi` 597 외) |
| `lib/services/adk/` — **ADK 바인딩** | 9 | **3,549** (`adk_callback_handler` 593 · `adk_network_service` 468 · `adk_dicom_service` 519 · `adk_backup_service` 400 · `adk_database_service` 386 · `adk_video_encoder_service` 357 · `adk_native_methods` 346 · `adk_manager` 240 · `adk_request_codes` 240) |
| **합계** | **14** | **약 7,281** |

**전부 앱 저장소에 있고 패키지 경계가 없다**(`packages/` 아래는 `dr_sono` 음성 모듈 하나뿐). 외부 고객사에 SDK·ADK 를 넘겨도 **Flutter 결합 코드는 따라가지 않으며 떼어 쓸 수도 없다.**

**모듈 로드를 앱이 수동으로 한다** — Windows 는 Dart 에서 **DLL 15개를 이름·순서 지정해 로드**(`// Sonex 기본 모듈들 (순서 중요)`), Android 는 `SonexJNI.java` 에서 `System.loadLibrary()` 를 모듈별로 나열한다. **앱이 SDK/ADK 의 내부 모듈 분해도와 의존 순서를 알아야 한다.**

**이 구조로 실제 사고가 났다** — `NativeMethods.dart` 주석 기록:

> 2026-05-29 … 의존 DLL 목록이 회귀로 누락되어 **ADK 가 작동 안 함**. `adea11b` 에서 *"Sonex 핵심 모듈들만"* 이라며 `sqlite3`·`opencv_world345`·`BackupReadWriter`·`DatabaseHelper`·`VideoEncoder` 제거 → `SonexFramework.dll` cascade dependency 가 깨져 `DynamicLibrary.open` 시 **ERROR 127**

정상적인 동적 링크라면 import table 을 따라 의존 DLL 이 자동 로드되므로 이 목록 자체가 불필요하다. **수동 나열은 캡슐화 부재의 신호**이며, 목록이 앱 소스에만 있어 정리하면 깨진다. 한 번 깨졌고 되돌리는 데 시간이 걸렸다.

> **목적 1 관점**: Flutter 고객사에게 지금 줄 수 있는 것이 없다. §4 의 ANGLE 로드 책임 문제와 **같은 구조**이며 범위가 더 넓다(모듈 15개 전체). 폐기된 `flutter_sonex_sdk` 가 정확히 이 공백을 메울 물건이었다 → [plan.md](plan.md) Phase 3.

### 7.2 언어별 바인딩이 27벌 흩어져 있고 정본이 없다

`[실측]` Flutter 만의 문제가 아니다. **5개 언어에 바인딩이 27개 파일, 약 14,400 LOC 로 존재하며 정본이 하나도 없다.**

| 언어 | 파일 | 위치 | LOC |
|---|---:|---|---:|
| **Dart** | **14** | 앱 `lib/services/sdk/` 5 + `lib/services/adk/` 9 | **7,281** |
| **ObjC++** (bridge) | 3 | SDK 샘플 1 + 앱 iOS·macOS 2 | 3,146 |
| **C#** (P/Invoke) | 4 | SDK 샘플 3 + `ADK_Sample_Test` 1 | 1,801 |
| **JNI(C++)** | 3 | SDK 샘플 1 + ADK 샘플 1 + 앱 1 | 1,670 |
| **Java** | 3 | SDK 샘플 1 + ADK 샘플 1 + 앱 1 | 465 |
| **합계** | **27** | | **14,363** |

**전부 샘플 또는 앱 안에 있다. 배포 산출물은 0벌이다.**

**이미 표류 중이다** — `SonexSDKBridge.mm` 3벌이 MD5 전부 다르고 `hc_*` 심볼 수가 **20 / 22 / 23** 으로 갈린다. 앱 iOS 와 앱 macOS 는 `hc_SetFontFilePath` 1개 차이라 사실상 복제본이 따로 자란 것이다.

**공개 헤더가 구현 헤더의 절반이다** — `HCSonexSDKInterface.h` 가 **두 벌** 있다.

| | 경로 | 줄 | `hc_*` | 최종 수정 |
|---|---|---:|---:|---|
| **공개** | `sdk/include/` | 341 | **27** | 2026-05-27 |
| **구현** | `sdk/sdk/Main/shared/` | 672 | **54** | 2026-06-01 |

**고객사가 받는 공개 헤더에 실제 API 의 절반만 있다.**

**그리고 앱이 존재하지 않는 심볼을 lookup 한다** — Dart 가 부르는 76개 중 구현 헤더·ADK 헤더 어디에도 없는 것이 **32개**다. 문자열 리터럴 `lookup()` 이라 이름이 정확히 일치해야 하는데, 확인된 3건은 이렇다.

| 앱이 부르는 이름 | 프레임워크 실제 | 결과 |
|---|---|---|
| `hc_setLogMessageCallback` | `hc_SetLogMessageCallback` | **대소문자 불일치** |
| `hc_ReleaseWcharPointer` | `hc_ReleaseWCharPointer` | **대소문자 불일치** |
| `hc_GrabFrontBufferBgraNow` | **부재** | 앱에 `print("[실패] … 함수를 찾을 수 없음")` 방어 코드 존재 |

**손으로 쓴 바인딩이라 컴파일러가 검증하지 못하고, 오타가 런타임까지 간다.** 세 번째 항목은 개발자가 실패를 인지하고 예외 처리로 덮어 둔 상태다.

> **판정**: 언어별 wrapper 는 **새로 만들 것이 아니라 흩어진 27벌을 정본화하는 작업**이다. 재료는 이미 약 14,400 LOC 존재한다. 그리고 이 문제의 형태는 **HC 프로토콜 정본화와 동일**하다 — 복제 다수 · 정본 부재 · 이름 표류. [legacy/proof/protocol-sot/](legacy/proof/protocol-sot/) 에서 검증된 방법(전수 대조 → 정본 1벌 → 컴파일러가 동작 보존 판정)을 그대로 적용할 수 있다.

### 7.3 클라우드 경로 — ADK 소관이 지켜지나 앱이 우회하는 갈래가 있다

**통신 담당의 분리는 잘 지켜진 경계다** `[실측]`.

| 축 | 담당 | 근거 |
|---|---|---|
| **장치** | **SDK** | `HCSocketCommunicator`·`HCPacketData`(14B `'H','C'`)·`InstructionSet` 6종. **ADK 에 HC 프로토콜·소켓 심볼 0건** |
| **클라우드** | **ADK** | `HCNetworkProcess` — HTTP. **SDK 에 클라우드 HTTP 0건** |

`[계획서]` 범위 정의와도 일치한다 — SDK *"SONON 초음파 스캐너 장비 연결, 조작"* · ADK *"네트워크 상태 확인, 서버 web API 호출 등의 통신 기능"*. (예외 둘은 §4.4 — ADK 의 장비 FTP, iOS 장치 소켓 중복 구현)

**아래는 그 분리의 문제가 아니라, 클라우드 경로 안에서 앱이 ADK 를 우회하는 갈래다.**

`[실측]` ADK `HCNetworkProcess.cpp` 가 `base_url = "http://sonex.healcerion.com:8080/API/"`(line 17, line 96 에서 사용)로 **엔드포인트 19개**를 호출한다.

| 묶음 | 엔드포인트 |
|---|---|
| 계정(SSO) | `SignUp` · `LogIn` · `GetProfile` · `ChangeProfile` · `ResendAuthMail` · `ForgotPassword` · `CheckDuplicateID` · `Withdrawal` · `MigrationUser` · `ChangePassword` |
| 장비(SDI) | `GetDeviceModelList` · `GetDeviceList` · `RegistDevice` · `UpdateDevice` · `GetBatteryList` · `RegistBattery` · `UpdateBattery` |
| 로그(ELA) | `AddEventLog` |
| 기타 | `HEAL` |

`adk_network_service.dart` 에 로그인 워크플로우도 있다 — *"signIn → getUserProfile → getDeviceList → getBatteryList"*.

**그런데 앱이 같은 서버를 Dart 에서 직접 호출하는 경로도 있다** — `lib/services/http_manager.dart` 가 `LogIn`·`CheckDuplicateID`·`ForgotPassword`·`GetProfile` 4개를 직접 부르고, **`login_controller.dart` 가 ADK 경로와 `HttpManager` 를 둘 다 import** 한다. 주석(*"[HttpManager.loginPost] 직후 파싱한 result … 진단용"*)으로 보아 `HttpManager` 가 부수 경로로 보이나 확정하지 않았다(§9).

> **외부 제공 관점**: 고객사에 ADK 를 넘기면 **클라우드 호출은 ADK 경로 하나로 정리돼 있어야** 한다(장치 통신은 SDK 소관 그대로). 지금은 힐세리온 앱 안에서도 클라우드로 가는 갈래가 둘이라, 고객사에 "무엇을 쓰라"고 말할 기준이 모호하다.

## 8. B4 재배포 라이선스 — 미정리

**의료기기 SW 재배포라 기준을 일반 OSS 준수보다 높게 잡는다** — 라이선스 적법성과 별개로 IEC 62304 §8.1.2 SOUP 기준(버전 고정·알려진 결함·EOL 상태)을 함께 충족해야 각 구성요소가 "정리됨"으로 판정된다.

| 항목 | 상태 |
|---|---|
| 서드파티 고지 | **0건** — OpenCV·DCMTK·FFmpeg·OpenSSL·FreeType·ANGLE 전부 |
| **CVIE**(ContextVision, 상용) | `sdk/third_party/context_vision` 82MB. **고객사 제품에 재배포할 권한이 있는지 미확인**(§8.1). **의료기기 재배포 전제라 이 미확인은 B4 를 닫지 못하는 blocker** — 확인 전 CVIE 포함 패키지 출하 불가 |
| **OpenSSL 1.1.1d** | **EOL(2023-09 단종) — SOUP 기준 위반.** 라이선스(Apache 2.0)는 문제없으나, 단종 암호 라이브러리는 신규 CVE 가 패치되지 않은 채 재배포된다. 의료기기 SW 에서는 **재배포 적법성과 별개로 그 자체가 결함**이며 3.6 상향이 B4 성공 판정의 필요조건이다([r1/phase0-build-reproducibility.md §C-V](r1/phase0-build-reproducibility.md)) |
| FFmpeg | 번들 빌드의 GPL 구성 여부 미확인. **정책 결정(2026-07-30): 배포판은 LGPL 전용 구성으로 고정한다** — GPL 전용 컴포넌트(`--enable-gpl`, x264·x265·xvid 등) 배제. 현재 번들이 GPL로 빌드됐다면 폐기하고 재빌드([r1/phase2-release-packaging.md §4](r1/phase2-release-packaging.md)) |
| ANGLE | BSD 계열로 재배포 자체는 무리 없으나 **어느 리비전인지 특정 불가**(§3.3). **IEC 62304 기준 SOUP**([r1/phase0-build-reproducibility.md §0-A](r1/phase0-build-reproducibility.md)) |

**외부 제공은 재배포를 뜻하므로 이 항목은 선택이 아니라 전제다.** SDK 와 ADK 가 한 패키지로 나가므로 **검토 범위는 언제나 양쪽 전체**다.

### 8.1 CVIE 현황 — 라이선스는 장비에서 온다

`[실측]` 라이선스 키가 클라우드가 아니라 **스캐너 장비에서** 온다.

```cpp
// HCInstructionSet500L.cpp:393 — 장비 정보 패킷 필드 31
String cvieLicenseKey = packet->getString(31);
info->cvieLicenseKey = cvieLicenseKey;

// HCLiveController.cpp:3078
if (!info->cvieLicenseKey.isEmpty())
    res = filter->cvieValidation(serial, info->cvieLicenseKey);   // 시리얼+키 조합 검증
```

**라이선스가 장비에 바인딩돼 있다** → ADK·클라우드를 쓰지 않는 고객도 장비에서 키를 받는다. 클라우드의 `cv_license`([../review/cloud-server.md](../review/cloud-server.md))는 발급·관리 기록으로 보이며 런타임 경로가 아니다(미확인).

**적용 범위가 좁다.**

| 축 | 범위 |
|---|---|
| 모델 | **500 시리즈만** — `HCInstructionSet500L`·`500P`·`500C` 만 키를 읽는다. 주석도 *"Valid license & valid product (500 series)"*. 300C·300L 은 CVIE 없음 |
| 플랫폼 | `#if !OS_MACOS // CVIE: Windows / Android / iOS (macOS 미지원)` — **macOS 제외** |
| 동작 조건 | 4단 게이트 — `cvLicensePassed && support && enable && settingIndex > -1` |

**대체 경로가 이미 실재한다.** macOS 는 CVIE 미지원이라 **이미 CVIE 없이 돌고 있고**, 그 자리를 CoreML HNS 필터가 채운다(macOS·iOS 실동작 / Windows ONNX·Android tflite 미구현, [../review/sonex-app.md §8](../review/sonex-app.md)). 자체 필터도 `HCNLMFilter`·`HCSRIv20_5`·`HCSRIv22`~`22_5` **7벌**이 있다(CVIE 와 배타인지 병존인지는 §9 미확인).

**배포에서 걸러야 할 것** `[실측]`

| 항목 | 내용 |
|---|---|
| **상용 라이선스 파일이 커밋돼 있다** | `third_party/context_vision/license_key/ID-0001200-001.cov`(4,490 B) |
| **기밀 표기 문서가 함께 있다** | `READMESDK.txt`·`README_CVIESDK.txt` 첫 줄이 **`CONTEXTVISION COMPANY CONFIDENTIAL`**(Copyright 2011-2022 ContextVision AB). 기밀 표기 문서가 제3자에게 전달되는 형태가 된다 |
| 계약서는 저장소에 없다 | `COPYRIGHT.txt` 는 CVIE 가 **포함한 서브컴포넌트**(Khronos·NVIDIA 등) 고지이지 ContextVision↔힐세리온 계약이 아니다. **재배포 조건은 코드로 알 수 없다** |

아티팩트 정의([plan.md](plan.md) Phase 2-1)에서 `.cov`·기밀 문서를 **제외 대상으로 명시**하고, 재배포 조건은 서드파티 인벤토리(Phase 0-2)에서 확인한다.

> **주석 표류**: `HCImageFilter.cpp` 의 `#else` 분기 주석이 *"CVIE: Windows only"* 인데 조건은 `!OS_MACOS`(Windows·Android·iOS)다. 동작은 조건이 맞고 주석이 낡았다.

## 9. 미확인

- **마지막 fetch(2026-07-27) 이후 원격 변화** — 브랜치 구도는 확정됐고(머리말) master 스냅샷이 현행이다. 남은 것은 그 이후 `origin/master` 가 더 나갔는지뿐이다
- **Flutter Impeller 전환**(Skia GL → Metal/Vulkan)과 GL 텍스처 연동의 정합성 — `sonex-app` 렌더 경계를 이 관점으로 보지 않았다
- Android ANGLE Vulkan 백엔드가 1순위인데 기기별 드라이버 편차에서 실제 폴백 발생 빈도
- Windows 런타임이 로드하는 `libEGL.dll`·`libGLESv2.dll` 의 실제 출처
- **외부 고객사 요구사항 문서의 존재 여부** — B2·B6 의 수준이 여기서 정해진다
- `moana` 기능 정본 목록 — A1 판정의 전제
- **`HC::DeviceManager` 동명 클래스 2개가 공개 헤더로 노출되는지**(§4.2) — `sdk/include/` 반출 여부를 확인하지 않았다. 노출된다면 고객사 측 ODR·이름 충돌이 실제 문제가 된다
- **같은 서버로 가는 경로가 둘인 이유**(§7.3) — ADK `NetworkProcess`(C++)와 앱 `http_manager.dart`(Dart 직접)가 **동일 엔드포인트를 각각 호출**하고 `login_controller.dart` 가 둘 다 import 한다. 주석상 `HttpManager` 쪽이 진단용으로 보이나 어느 쪽이 운영 경로인지 확정하지 않았다
- **`adk/Main/ios/HCSonexSDK_iOS.cpp` 가 런타임에 실제로 쓰이는지**(§4.4) — 빌드 포함은 확인했으나, [../review/sonex-app.md §5](../review/sonex-app.md) 는 iOS 앱이 `SonexSDKBridge.mm` 을 쓴다고 기록한다. **미사용 잔재일 가능성이 남아 있다.** 잔재라도 `HC::ResultCode` 재정의는 헤더 포함 시점에 영향을 주므로 제거 대상이다
- **[rendering-boundary.md §7.5](rendering-boundary.md) 의 두 규칙(스캔원본/교환형식 · 기전/정책)이 전 모듈에 성립하는지** — `FirmwareController`·`VideoEncoder`·`DicomHandler`·`FileReadWriter` 로 확인했고 나머지는 전수 대조하지 않았다
- **CVIE 와 자체 SRI 필터(`HCNLMFilter`·`HCSRIv22*` 7벌)의 관계**(§8.1) — 배타 선택인지 파이프라인 병존인지 확인하지 않았다. CVIE 를 뺐을 때 화질이 어디까지 유지되는지가 여기서 갈린다
- **클라우드 `cv_license` 의 역할**(§8.1) — 라이선스 키가 장비에서 오는 것은 확인했으나, 클라우드 필드가 발급 기록인지 별도 런타임 경로인지 대조하지 않았다
