# [축별 분리] 500C 펌웨어 (`500c-sn-fw`)

> **범위 판단 (2026-07-29 갱신) — 축마다 다르다.**
>
> | 축 | 판정 | 이유 |
> |---|---|---|
> | **장비 펌웨어 리팩토링** | **범위 밖 유지** | Socionext ARM Cortex-M **베어메탈**이고 belle(ZynqMP + Linux)과 코드·빌드·아키텍처를 전혀 공유하지 않는다. [r2](../../refactoring/r2/plan.md)(Buildroot·Linux 전제)가 그대로 적용되지 않아 **별도 트랙이 필요하다** |
> | **클라이언트 축 판단 근거** | **범위 안 — 이미 SoNex 완성 범위에 포함** | `500C`·`500P`(+`500L`)는 SoNex 확정 지원 모델 5종에 이미 들어 있다 — [goal.md](../../refactoring/goal.md) · [gap.md A2](../../refactoring/gap.md)(모델 커버리지 **충족**). "`moana` 가 흡수하면 `sonex-app` 이 불필요해진다"는 구도([legacy/moana-vs-sonex.md §3.1](../../refactoring/legacy/moana-vs-sonex.md))는 **2026-07-29 전제 변경으로 무효** — `moana` 는 SoNex 출시와 동시에 폐기되므로 `sonex-app` 은 이 흡수 여부와 무관하게 완성 대상이다([../../refactoring/README.md 전제①](../../refactoring/README.md)). 남은 실질 질문 = §1.1 |
>
> **초판의 "단종" 전제는 철회됐다** — `origin/FW_1_1_8_0` 최종 2026-04-24, Rev1.7 하드웨어·ABLIC WiFi SDK 전환 진행 중이고 `sonex-framework` 가 2026-07-23 에 펌웨어 굽기를 실장비 검증했다.
>
> **추가 정정(2026-07-30)** — 이 저장소는 **500C 단일 모델이 아니라 500C·500P·500LS 세 SKU 공용 펌웨어**다(§1.1). `500P`(Sector 프로브)는 sonex-framework 자체 문서(`HC_SONON_500_SN` 그룹)와 `sonex-app` 의 컴파일된 배포 바이너리(`libDeviceManager.so`)로 이미 확인된 **현행 출하 모델**이며, moana 미병합 브랜치보다 강한 증거다.
>
> **조사 함정**: `500c-sn-fw` 의 `master` 는 **커밋 3개짜리 초기 스텁**(`7d891b8` 최초 임포트 → `4b19ef5` → `c964a57`)이고 500C/500P/500LS 분기 로직이 **없다**. 이 리포를 grep 할 때 `master` 만 보면 "500C 단일 모델"로 오판한다 — 반드시 라이브 브랜치(`origin/FW_1_1_4_0`~`origin/FW_1_1_8_0`)를 대상으로 해야 한다(§6).
>
> **근거**: `origin/FW_1_1_8_0` 코드 직접 읽기(2026-07-27, 2026-07-30 500P/500LS 재조사).

## 1. belle 과의 대조

belle 이 아니지만 **단종도 아니다**(최종 2026-04-24, `FW_1_1_8_0`). Socionext ARM Cortex-M **베어메탈**이고 belle 과 코드를 전혀 공유하지 않는다.

| | `belle-fw` | `500c-sn-fw` |
|---|---|---|
| 플랫폼 | ZynqMP + Linux 5.4 | Socionext Cortex-M, **OS 없음** |
| 빌드 | CMake + PetaLinux | **IAR EWARM**, 7개 독립 프로젝트 |
| 신호처리 | **소프트웨어** | **UDL 하드웨어 블록** (`libudl.a` 소스 없음) |
| HAL | 우회 다수 | **3층 분리, 일관됨** — `src/App` 에서 `reg_*.h` include 0건 |
| 자체 코드 비중 | — | **약 9%** (벤더 WiFi SDK 55.8% + 프리빌트 바이너리) |

**신호처리의 물리적 위치가 정반대**라 두 라인을 하나의 소프트웨어 아키텍처로 묶으려면 이 경계부터 결정해야 한다.

> **범위는 축별로 갈렸다**(상단 표). "belle 만" 을 문자 그대로 적용하면 펌웨어 축에서 제외되고, **"단종 모델 제외" 원칙은 더 이상 적용되지 않는다** — 현행 제품이다.

### 1.1 클라이언트 축 — 500C·500P·500LS 세 SKU, 이미 SoNex 범위 안

> **정정(2026-07-30)** — 이 절의 초판은 "`moana` 흡수 가능성이 `sonex-app` 존폐의 유일한 결정 인자"라는 [legacy/moana-vs-sonex.md §3.1](../../refactoring/legacy/moana-vs-sonex.md) 구도를 그대로 따랐다. 그 구도는 **"`moana`·`sonex-app` 중 하나만 리팩토링한다"는 전제 위에서만 성립**했고, 그 전제는 힐세리온 CTO 확인(2026-07-29)으로 폐기됐다 — `moana` 는 SoNex 출시와 동시에 없어진다. **따라서 `sonex-app` 은 이 흡수 여부와 무관하게 완성 대상**이고, 이미 [gap.md A2](../../refactoring/gap.md)가 "모델 커버리지 충족"으로 결론 냈다. 아래 실측 자체는 유효하지만 "`sonex-app` 을 접을 수 있는가"의 근거가 아니라 **"500C·500P·500LS 가 지금 어디서 어떻게 구동되는가"의 실측**으로 읽는다.

**펌웨어(`500c-sn-fw`) 자체가 이미 3-SKU 공용이다 — 컴파일 타임 분기가 아니라 공장 출하 시 플래시에 써넣는 런타임 설정이다.**

```c
// src/App/US_Control/USC_Custom_ParamSet.h (origin/FW_1_1_8_0)
typedef enum { CUSTOM_PROBE_ID_CONVEX = 0, CUSTOM_PROBE_ID_SECTOR, CUSTOM_PROBE_ID_LINEAR, CUSTOM_PROBE_ID_MAX } ENM_CUSTOM_PROBE_ID;
```

`USSCustomCommand_Wrapper.c`·`USSDEV_INFO.c`·`StateMachine.c` 전부 공장 설정 문자열(`USS_FLASH_getCustom_Device()`, 12바이트, `USSDebug.c:457` 에서 디버그 콘솔 명령으로 기록)을 읽어 3분기한다 — `"500C"`→CONVEX·`"500P"`→SECTOR·`"500L"`/`"500LS"`→LINEAR. **같은 바이너리가 세 제품이 된다.** 이 패턴은 [r1 Phase 10](../../refactoring/r1/phase10-runtime-variant.md)(컴파일 타임 변종 → 런타임 설정)이 이미 실현된 선례다.

**힐세리온 자체 문서가 세 SKU 를 명시한다** — `sonex-framework/docs/sdk/FIRMWARE_UPGRADE_ANALYSIS.md`:

| 매크로 | 대상 모델 | 펌웨어 ini |
|---|---|---|
| `HC_SONON_500_SN` | **500C, 500P, 500LS** | `500-SN-Firmware.ini`(Socionext 칩셋, sonex-framework main 브랜치에만 존재) |
| `HC_SONON_500L` | 500L(+300 시리즈 동거) | `500-Firmware.ini`·`Firmware.ini` |

**`sonex-app`·`sonex-framework` 는 500C·500P 를 이미 구동한다 — 미병합이 아니라 현행 출하 코드다.**

| 실측 | 값 |
|---|---|
| 명령셋 | `sonex-app/android/app/include/HCInstructionSet{500C,500P}.h`, `isSupportedModel()` 이 각각 `"500C"`·`"500P"` 리터럴 비교 |
| 배포 확인 | 두 헤더 심볼이 컴파일된 `libDeviceManager.so`(arm64-v8a)에 실재 — 소스만 있고 안 쓰는 코드가 아니다 |
| 프로브 지오메트리 | `sonex-framework/sdk/sdk/Main/shared/HCSonexSDKInterface.cpp:1071` — `"500P"` 전용 `SCANNER_TYPE_PHASED_ARRAY`(pitch=3, theta=90), `"500C"` 는 `SCANNER_TYPE_CONVEX`(pitch=55, theta=58.21) 로 별도 정의 |

**`moana` 미병합 브랜치(`origin/sonon_500c`)는 이제 참고 기록일 뿐이다 — `moana` 폐기가 확정된 이상 흡수 여부를 따질 대상이 아니다.**

| 실측 | 값 |
|---|---|
| 규모 | **71커밋 / 113파일 / +14,946줄**(출하 계통 `service_QT693` 대비), 최종 **2023-09-19** |
| 모델 등록 | `Model.cpp` 에 `MODEL_500C` 18곳·`MODEL_500P` 18곳, `InitCapabilityTable_500C`·`_500P` 각각 보유 |
| 성격 | moana 가 한때 500C·500P 구동을 시도하다 2023-09 에 멈췄다는 **이력**. 지금은 그 이상의 의미가 없다 |

**남은 실질 질문은 둘이다 — 둘 다 `moana` 흡수와 무관하다.**

1. **`500LS` 가 SoNex 확정 모델 5종에 없다.** [goal.md](../../refactoring/goal.md)·[gap.md](../../refactoring/gap.md) 가 확정한 완성 범위는 **300C·300L·500C·500L·500P** 뿐이고, `sonex-app` 의 `InstructionSet` 도 이 5종 + `Default` 6종만 있다. `500c-sn-fw` 펌웨어와 `sonex-framework` 자체 문서(`HC_SONON_500_SN` = 500C/500P/500LS)엔 있는 `500LS` 가 빠져 있다 — 실제 출하 제품인지, 개발 중인지, 폐기됐는지 **미확인**.
2. **500C·500P 의 명령 시퀀스가 ADK 에만 있다**([gap.md](../../refactoring/gap.md) — "SDK 는 낱개 명령만 제공, 몇 바이트씩·몇 번·어떤 순서로는 ADK 에만 있다"). SoNex 최우선 목적이 외부 SDK/ADK 제공인데(전제②), 외부 고객사가 SDK 만 받으면 500C/500P 는 상태머신을 스스로 재구현해야 한다 — 이건 실질 갭이다.

> **역사적 맥락으로만 남기는 질문** — 왜 500C·500P 지원이 `moana` 브랜치에서 멈추고 `sonex` 로 넘어갔는지는 여전히 궁금하지만, 지금 트랙의 결정에는 영향이 없다.


## 2. 빌드 구조

IAR 워크스페이스 `US3_ARM.eww` 가 **독립 링크되는 7개 프로젝트**를 묶는다 — `FlashBoot`(본체) · `BootLoader` · `FlashLoader` · `RamBoot` · `PrmBin` · `RawBin` · `Updater`. IAR EWARM 5.10.

메모리(`Linker/US3_ARM_FlashBoot.icf`): ROM `0x60080000`–`0x600FFFFF`(512KB), I-code SRAM `0x01000000`(512KB), D-code SRAM `0x01100000`(1MB), work SRAM `0x20000000`(64KB).

**OS 가 없다** — `src/Wrapper/SRC/MCU_OS.c` 의 mutex 가 스핀 대기이고 주석이 `/* Create dummy mutxe pointer because OS not present */` 다. 런타임은 단일 슈퍼루프 + 이벤트 테이블 디스패치.

**출하 설정이 "Debug" 구성이다** — "Release" 구성의 `CCDefines` 는 `NDEBUG` 뿐이고, 실제 기능 플래그(`USE_CUSTOM_INTERFACE`·`USE_CUSTOM_BOARD_ES2`·`USE_CUSTOM_WIFI_CONF` 등)는 전부 Debug 구성에 있다.

## 3. HC 프로토콜 — 정본 선언이 여기 있다

`src/App/include/USSCustomCommand.h` 가 **첫 커밋부터** 구조체를 선언한다.

```c
typedef struct __attribute__ ((packed)) {
    U8  identifier[2];   U8  version[2];
    U16 recv_id;         U16 session_id;   U16 packet_type;
    U32 packet_body_size;
} PACKET_HEADER_S;   // PACKET_HEADER_SIZE 14
```

이 저장소는 **프로토콜 스택을 둘 갖는다** — 네이티브 Socionext STX/ETX(포트 5000)와 Healcerion HC 클론(포트 1234/1235). 출하 빌드는 `USE_CUSTOM_INTERFACE` 로 **HC 쪽**을 쓴다. 신규 포트 `1236`(aging 제어)이 추가됐다.

## 4. UDL — 신호처리 하드웨어 블록

빔포밍·스캔변환·JPEG 을 **UDL 하드웨어가 수행**하고 MCU 는 시퀀서다.

`App` → `MCU_udl_api.h`(`MCUg_Udl_RegWrite/RegRead`·`SetScenarioId`·`StartScan`) → `udl_prm.h` → **프리빌트 `lib/libudl.a`**.

**UDL 소스는 어느 브랜치에도 없다.** 게다가 live 브랜치가 `libudl*.a` **8개 변종**을 동시에 갖고 있다(`_org`·`_back_20240408`·`_20240524_back`·`_adcdump`·`_Convex_B_PW_SideNoise`·`_1.1.5.0`·`_1.1.7.0`) — 바이너리를 git 대신 비공식 버전관리로 쓰고 있다.

## 5. 저장소 구성

**자체 코드는 약 9%** 다.

| 버킷 | 비중 |
|---|---:|
| 벤더 WiFi SDK(`src/Middleware/WiFiHost`) | 30.9% |
| 프리빌트 아카이브(`lib/`) | 30.4% |
| Socionext MCU BSP/HAL(`src/Driver`·`src/Wrapper`) | ~14% |
| `PrmBin/` 바이너리 | 2.3% |
| **`src/App`(자체 로직)** | **9.0%** |

WiFi SDK 는 2025년 **ABLIC 이전 시 기존 Redpine 트리를 지우지 않고 `Module1`/`Module2` 로 둘 다 유지**해 114,125 LOC 로 늘었다.

## 6. 브랜치

`master`(3커밋) → `FW_1_1_3_0` → `FW_1_1_5_0` → `FW_1_1_5_1` → `FW_1_1_7_0` → **`FW_1_1_8_0`**(live) 가 **단일 직선**이다. `FW_1_1_4_0`·`M0.00.05` 는 폐기된 작업 브랜치.

버전은 `USSDEV_INFO_Ver.h` 의 `#define` 과 **`#if 0` 주석 블록**에 이중으로 적혀 있고, 외부 릴리스 스크립트가 주석 쪽을 파싱한다. **동기화는 수동**이며 빌드 시 검사가 없다.

## 7. 위생

- 임시·백업 파일 커밋 — `src/App/Communication/MFCF4F72E69.tmp`(1,926줄, IAR 에디터 스왑 파일) · `MCU_udl.c.bak`
- `PrmBin/*.bin` 바이너리 직접 수정 커밋 — `"set the CV serial key to a fixed value"` 는 **사람이 읽을 수 있는 diff 가 없다**
- 테스트·CI·문서 **0건**
