# [축별 분리] 500C 펌웨어 (`500c-sn-fw`)

> **범위 판단 — 축마다 다르다.**
>
> | 축 | 판정 | 이유 |
> |---|---|---|
> | **장비 펌웨어 리팩토링** | **범위 밖 유지** | Socionext ARM Cortex-M **베어메탈**이고 belle(ZynqMP + Linux)과 코드·빌드·아키텍처를 전혀 공유하지 않는다. belle 장비 계획(Buildroot·Linux 전제, 2026-08-01 삭제)이 그대로 적용되지 않아 **별도 트랙이 필요하다** |
> | **클라이언트 축 판단 근거** | **범위 안 — 이미 SoNex 완성 범위에 포함** | `500C`·`500P`(+`500L`)는 SoNex 확정 지원 모델 5종에 이미 들어 있다 — [goal.md](../../refactoring/goal.md) · [gap.md A2](../../refactoring/gap.md)(모델 커버리지 **충족**). "`moana` 가 흡수하면 `sonex-app` 이 불필요해진다"는 구도([legacy/moana-vs-sonex.md §3.1](../../refactoring/legacy/moana-vs-sonex.md))는 **2026-07-29 전제 변경으로 무효** — `moana` 는 SoNex 출시와 동시에 폐기되므로 `sonex-app` 은 이 흡수 여부와 무관하게 완성 대상이다([../../refactoring/README.md 전제①](../../refactoring/README.md)). 남은 실질 질문 = §1.1 |
>
> **단종이 아니다** — `origin/FW_1_1_8_0` 최종 2026-04-24, Rev1.7 하드웨어·ABLIC WiFi SDK 전환 진행 중이고 `sonex-framework` 가 2026-07-23 에 펌웨어 굽기를 실장비 검증했다.
>
> **이 저장소는 500C 단일 모델이 아니라 500C·500P 공용 펌웨어다**(§1.1). `500P`(Sector 프로브)는 sonex-framework 자체 문서(`HC_SONON_500_SN` 그룹)와 `sonex-app` 의 컴파일된 배포 바이너리(`libDeviceManager.so`)로 확인된 **현행 출하 모델**이다. `500LS` 는 포함하지 않는다 — 코드에 문자열 분기는 있으나 [phase6-samples-support.md](../refactoring/r1/phase6-samples-support.md)가 이미 지적했듯 `isSupportedModel()` 어디에도 없는 죽은 분기라 실제 출하 제품으로 볼 근거가 없다(§1.1).
>
> **조사 함정**: `500c-sn-fw` 의 `master` 는 **커밋 3개짜리 초기 스텁**(`7d891b8` 최초 임포트 → `4b19ef5` → `c964a57`)이고 500C/500P 분기 로직이 **없다**. 이 리포를 grep 할 때 `master` 만 보면 "500C 단일 모델"로 오판한다 — 반드시 라이브 브랜치(`origin/FW_1_1_4_0`~`origin/FW_1_1_8_0`)를 대상으로 해야 한다(§6).
>
> **근거**: `origin/FW_1_1_8_0` 코드 직접 읽기.

## 1. belle 과의 대조

belle 이 아니지만 **단종도 아니다**(최종 2026-04-24, `FW_1_1_8_0`). Socionext ARM Cortex-M **베어메탈**이고 belle 과 코드를 전혀 공유하지 않는다.

| | `belle-fw` | `500c-sn-fw` |
|---|---|---|
| 플랫폼 | ZynqMP + Linux 5.4 | Socionext Cortex-M, **OS 없음** |
| 빌드 | CMake + PetaLinux | **IAR EWARM**, 7개 독립 프로젝트 |
| 신호처리 | **소프트웨어** | **전용 칩**(UDL, §4) |
| HAL | 우회 다수 | **3층 분리, 일관됨** — `src/App` 에서 `reg_*.h` include 0건 |
| 자체 코드 비중 | — | **약 9%** (벤더 WiFi SDK 55.8% + 프리빌트 바이너리) |

**신호처리의 물리적 위치가 정반대**라 두 라인을 하나의 소프트웨어 아키텍처로 묶으려면 이 경계부터 결정해야 한다.

> **범위는 축별로 갈렸다**(상단 표). "belle 만" 을 문자 그대로 적용하면 펌웨어 축에서 제외되고, **"단종 모델 제외" 원칙은 더 이상 적용되지 않는다** — 현행 제품이다.

### 1.1 클라이언트 축 — 500C·500P 두 SKU, 이미 SoNex 범위 안

`sonex-app` 은 500C·500P 를 이미 구동하고 있으므로 완성 대상은 이 흡수 여부와 무관하다 — [gap.md A2](../../refactoring/gap.md)가 이미 "모델 커버리지 충족"으로 결론 냈다. 아래 실측은 **"500C·500P 가 지금 어디서 어떻게 구동되는가"**를 다룬다.

**펌웨어(`500c-sn-fw`) 자체가 이미 500C·500P 공용이다 — 컴파일 타임 분기가 아니라 공장 출하 시 플래시에 써넣는 런타임 설정이다.**

```c
// src/App/US_Control/USC_Custom_ParamSet.h (origin/FW_1_1_8_0)
typedef enum { CUSTOM_PROBE_ID_CONVEX = 0, CUSTOM_PROBE_ID_SECTOR, CUSTOM_PROBE_ID_LINEAR, CUSTOM_PROBE_ID_MAX } ENM_CUSTOM_PROBE_ID;
```

`USSCustomCommand_Wrapper.c`·`USSDEV_INFO.c`·`StateMachine.c` 전부 공장 설정 문자열(`USS_FLASH_getCustom_Device()`, 12바이트, `USSDebug.c:457` 에서 디버그 콘솔 명령으로 기록)을 읽어 분기한다 — `"500C"`→CONVEX·`"500P"`→SECTOR. **같은 바이너리가 여러 제품이 된다.** 이 패턴은 [r1 Phase 10](../../refactoring/r1/phase10-runtime-variant.md)(컴파일 타임 변종 → 런타임 설정)이 이미 실현된 선례다.

같은 조건문에 `"500L"`/`"500LS"`→LINEAR 분기도 있고, `sonex-framework/docs/sdk/FIRMWARE_UPGRADE_ANALYSIS.md` 도 `HC_SONON_500_SN` 그룹에 500LS 를 함께 언급한다. 하지만 **이 두 곳은 같은 문자열 비교 코드를 각자 서술한 것**이지 독립된 근거가 아니다. [phase6-samples-support.md](../refactoring/r1/phase6-samples-support.md)(E-5)가 이미 확인해 둔 것과 일치한다 — *"`500LS`·`L43K` 는 버전 체커 분기에만 있고 `isSupportedModel()` 에는 어느 셋에도 없다."* `sonex-app` 의 `isSupportedModel()`·`InstructionSet`·SoNex 확정 모델 5종([goal.md](../../refactoring/goal.md)·[gap.md](../../refactoring/gap.md), 300C·300L·500C·500L·500P) 어디에도 `500LS` 는 없다. **출하 제품이 아니라 코드에 남은 죽은 분기로 본다** — 힐세리온 확인이 필요한 항목으로는 남긴다.

**`sonex-app`·`sonex-framework` 는 500C·500P 를 이미 구동한다 — 미병합이 아니라 현행 출하 코드다.**

| 실측 | 값 |
|---|---|
| 명령셋 | `sonex-app/android/app/include/HCInstructionSet{500C,500P}.h`, `isSupportedModel()` 이 각각 `"500C"`·`"500P"` 리터럴 비교 |
| 배포 확인 | 두 헤더 심볼이 컴파일된 `libDeviceManager.so`(arm64-v8a)에 실재 — 소스만 있고 안 쓰는 코드가 아니다 |
| 프로브 지오메트리 | `sonex-framework/sdk/sdk/Main/shared/HCSonexSDKInterface.cpp:1071` — `"500P"` 전용 `SCANNER_TYPE_PHASED_ARRAY`(pitch=3, theta=90), `"500C"` 는 `SCANNER_TYPE_CONVEX`(pitch=55, theta=58.21) 로 별도 정의 |

**`moana` 미병합 브랜치(`origin/sonon_500c`)는 참고 기록일 뿐이다 — `moana` 폐기가 확정된 이상 흡수 여부를 따질 대상이 아니다.**

| 실측 | 값 |
|---|---|
| 규모 | **71커밋 / 113파일 / +14,946줄**(출하 계통 `service_QT693` 대비), 최종 **2023-09-19** |
| 모델 등록 | `Model.cpp` 에 `MODEL_500C` 18곳·`MODEL_500P` 18곳, `InitCapabilityTable_500C`·`_500P` 각각 보유 |
| 성격 | moana 가 한때 500C·500P 구동을 시도하다 2023-09 에 멈췄다는 **이력**. 지금은 그 이상의 의미가 없다 |

**남은 실질 질문 — `moana` 흡수와 무관하다.**

500C·500P 의 명령 시퀀스가 **ADK 에만 있다**([gap.md](../../refactoring/gap.md) — "SDK 는 낱개 명령만 제공, 몇 바이트씩·몇 번·어떤 순서로는 ADK 에만 있다"). SoNex 최우선 목적이 외부 SDK/ADK 제공인데(전제②), 외부 고객사가 SDK 만 받으면 500C/500P 는 상태머신을 스스로 재구현해야 한다 — 이건 실질 갭이다.

### 1.2 벤더 SDK 대조 — 계보 확정(hash 대조)

> **출처**: `/home/beomsik/project/chip/viewphii64/20260414_viewphii64_WPDP_SCS_2.0.0` — 칩벤더(ABLIC, 구 Socionext) 배포 SDK 패키지("viewphii64 WPDP SCS 2.0.0"). `legacy/` 미러가 아니라 별도 경로다. `Probe Firmware/ProbeFW_SourceCode_1.1.8.0.zip`(펌웨어 소스) · `WPDP Application/VP_SDK_Viewer_SourceCode_2.1.0.0.zip`(레퍼런스 호스트 뷰어) · `Document/`(PDF 스펙 8종)로 구성된다. 이하는 `ProbeFW_SourceCode_1.1.8.0.zip`(vendor)과 `git -C 500c-sn-fw archive origin/FW_1_1_8_0`(HC, 버전 문자열이 일치하는 라이브 브랜치)를 파일명·해시로 직접 대조한 것이다.

**파일 매니페스트** — vendor 481건, HC 506건, 공통 파일명 438건.

| | 내용 |
|---|---|
| vendor 전용(43건) | 전부 IAR 빌드 산출물(`.out`·`.bin`·`.dnx`·`*_Setting/`)이거나 `src/Driver/f_i2c/apb/`(HC 는 `dpi_f_i2c/`로 개명 — 4개 대표 파일 바이트 대조로 rename 확인, 내용 변경 없음) |
| HC 전용(68건) | §1.1·§3.2·§7 이 이미 지목한 Healcerion 추가 계층과 정확히 일치 — `USSCustomCommand.c/h`·`USSCustomCommand_Wrapper.c/h`(§3)·`USSFUP_Custom.c`(§3.2)·`USC_Custom_ParamSet.c/h`(§1.1)·`USSAging_Custom.c`·`USSLED_Custom.c/h`·`USSMSP.c/h`·`USSWiFiAuth.c/h`·`USSProduct.c/h`, 그리고 **`MCU_OS.c/h`**(§2 의 "OS 없음" 더미 뮤텍스) — **vendor SDK 에는 이 파일 자체가 없다.** 벤더 베어메탈 설계에는 OS 추상화 개념이 아예 없고, HC 가 자신들의 커스텀 계층을 위해 더미 뮤텍스를 직접 얹은 것으로 확인된다 |

**공통 파일 438건 중 손댄 비율** — `cmp`(바이트 동일) 11건 + `diff -b --strip-trailing-cr`(개행만 다름) 263건 = **274건(62.6%) 내용 무변경**, 나머지 **164건(37.4%)** 이 실제 내용 차이. 164건 대부분은 **삭제보다 추가가 압도적**이다(`#ifdef`/신규 함수로 커스텀 계층을 얹는 패턴, 벤더 로직 자체는 유지):

| 파일 | + | - |
|---|---:|---:|
| `USSDebug.c` | 1247 | 81 |
| `statemachine/StateMachine.c` | 914 | 14 |
| `US_Control/USC_Param.c` | 557 | 6 |

(예: `Wrapper/SRC/MCU_udl.c` 는 `USE_CUSTOM_ADC_CLOCK` 테이블과 `USSDEBUG_TEST_E` 로그 호출을 삽입했을 뿐, 벤더가 짠 UDL 래퍼 로직 자체는 그대로다.)

**결론** — `500c-sn-fw` 는 새로 짠 코드가 아니라 이 vendor SDK 배포본 위에 Healcerion 커스텀 계층을 얹은 결과물이다. §5 의 "자체 코드 9%" 는 파일 *위치* 기준 추정이었는데, 이번 대조로 그 9% 안에서도 상당수가 순수 신규 파일이 아니라 vendor 파일에 훅을 추가한 형태라는 것이 드러났다.

**`libudl.a` — 벤더도 소스를 안 준다.**

```
md5(vendor lib/libudl.a)     = 8e6f6406318446e1ff3bc384b0625fb5
md5(HC     lib/libudl.a)     = 8e6f6406318446e1ff3bc384b0625fb5   ← 동일
md5(vendor lib/libUSSWiFi.a) = aef1fec3a670d45fa5c6661669487879
md5(HC     lib/libUSSWiFi.a) = aef1fec3a670d45fa5c6661669487879   ← 동일
```

§4 가 확인한 "UDL 소스는 어느 브랜치에도 없다"는 사실이 이번 대조로 한 겹 더 좁혀진다 — **HC 가 숨긴 게 아니라 벤더 공식 SDK 배포본 자체가 프리빌트 바이너리만 준다.** UDL 은 Healcerion 도 소스를 받지 못하는 ABLIC(구 Socionext) 독점 IP다.

덤으로 — §7 의 "`libudl*.a` 8개 변종" 중 **`libudl_adcdump.a`와 `libudl_back_20240408.a`는 MD5 가 완전히 같다**(둘 다 `a7770abbe3344c08590cf1d71abc2eea`) — 이름은 다르지만 같은 바이너리를 두 번 커밋한 것이다. "git 대신 비공식 버전관리" 진단의 구체 증거가 하나 늘었다.

**벤더 회사명 변경 — Socionext → ABLIC, HC 는 WiFi 미들웨어만 반영.** vendor SDK 의 `Document/viewphii64_Communication_Interface_Specification[Rev1.5].pdf` 개정 이력이 직접 밝힌다:

> 2025/3/12 Rev1.5 — *"Change of name of the issuing company of this document."*

카피라이트 헤더 집계(`src/App`+`src/Wrapper`+`src/Driver`, 양쪽 동일 범위):

| | vendor SDK(2.0.0) | HC(`origin/FW_1_1_8_0`) |
|---|---:|---:|
| `Copyright (C) 2024/2025 ABLIC Inc.` | 115 | 0 |
| `Copyright (C) 2023 Socionext Inc.` | 67 | 221 |

**벤더는 US3 칩 SDK 전체(App·Driver·Wrapper 포함)를 이미 ABLIC 명의로 재발행**했지만, HC 의 라이브 브랜치는 아직 그 이전 Socionext 스냅샷을 베이스로 한다. 전체 트리에서 `ABLIC Inc` 가 나오는 곳은 `src/Middleware/WiFiHost/WiFiHostSW.c`·`.h` 단 2개 파일뿐이다. CLAUDE.md 의 "ABLIC WiFi SDK 전환 진행 중"은 정확했고, 이번 대조로 진행률이 좁혀진다 — **벤더 쪽에서는 패키지 전체가 이미 ABLIC 명의로 끝났고, HC 쪽은 WiFi 미들웨어 한 곳만 반영했다.**

**Document 8종 — §3·§4 가 참조한 스펙의 실체.**

| 문서 | 대응 |
|---|---|
| `Communication_Interface_Specification[Rev1.5].pdf` | §3 의 "네이티브 Socionext STX/ETX(포트 5000)" 프로토콜의 벤더 원본 스펙(`SET_DEBUG_DUMP`·`NOTIFY_JPEG_DATA`·`GET_PROBE_STATE` 등) |
| `Communication_Interface_Specification(AppendixA)[Rev1.7].pdf`("Scan Parameter List") | §4.1 의 `PRM_ID` 배열이 구현하는 스캔 파라미터(JPEG Q factor·Color Doppler Gain·Sector Angle 등)의 벤더 원본 스펙 |
| `Driver_API_Specification[Rev1.6].pdf` / `Middleware_API_Specification[Rev1.2].pdf` | §2 의 `MCU_*_api.h`(Wrapper)·WiFiHost 미들웨어 계층의 벤더 원본 스펙 |

**참고 — `WPDP Application`(`VP_SDK_Viewer`)은 별도 계보다.** 펌웨어가 아니라 **벤더가 배포하는 레퍼런스 호스트 뷰어**(.NET MAUI, Windows·Android·iOS·MacCatalyst·Tizen 대상, 네임스페이스 `com.viewphii.*`)다. `Platforms/Windows/Infra/Cvie.cs` 가 `cvie64.dll`(라이선스 키 활성화 포함)을 P/Invoke 로 감싸고 있어, CLAUDE.md 가 이미 지목한 **CVIE(Context Vision) 대체 대상이 이 칩 라인의 벤더 권장 레퍼런스 패턴**이었음을 보여준다. 다만 §3.2.1 의 "호스트(C#) `ProbeCtrl.DEF_FUP_TYPE_WIFI1`" 주석이 이 뷰어의 `ProbeCtrl`류 클래스(`PrefsProbeCtrl`·`I_ProbeCtrl`)를 가리키는지는 **미확인**이다 — 이 zip 안에 `DEF_FUP_TYPE_WIFI` 문자열은 0건이라 HC 자체 내부 PC 툴을 가리킬 가능성이 더 커 보이나, 확정할 근거는 없다.

## 2. 빌드 구조

IAR 워크스페이스 `US3_ARM.eww` 가 **독립 링크되는 7개 프로젝트**를 묶는다 — `FlashBoot`(본체) · `BootLoader` · `FlashLoader` · `RamBoot` · `PrmBin` · `RawBin` · `Updater`. IAR EWARM 5.10.

메모리(`Linker/US3_ARM_FlashBoot.icf`): ROM `0x60080000`–`0x600FFFFF`(512KB), I-code SRAM `0x01000000`(512KB), D-code SRAM `0x01100000`(1MB), work SRAM `0x20000000`(64KB).

**OS 가 없다** — `src/Wrapper/SRC/MCU_OS.c` 의 mutex 가 스핀 대기이고 주석이 `/* Create dummy mutxe pointer because OS not present */` 다. 런타임은 단일 슈퍼루프 + 이벤트 테이블 디스패치.

**출하 설정이 "Debug" 구성이다** — "Release" 구성의 `CCDefines` 는 `NDEBUG` 뿐이고, 실제 기능 플래그(`USE_CUSTOM_INTERFACE`·`USE_CUSTOM_BOARD_ES2`·`USE_CUSTOM_WIFI_CONF` 등)는 전부 Debug 구성에 있다.

### 2.1 실행 모델 — 슈퍼루프 + 이벤트 테이블

`main()`(`src/main.c`) → `user_main()`(`USSMain.c`) → `USSAPP_StmInit()`/`USSAPP_StmMain()`(`statemachine/StateMachine.c`) 세 단계로 진입한다.

```c
// StateMachine.c
D_ST_NO (*const c_event_func_tbl[])(D_ST_NO) = { /* 22개 기본 이벤트 + USE_CUSTOM_INTERFACE 9개 = 31개 */ };

void USSAPP_StmMain(void)
{
	D_ST_NO state = D_ST_INIT;
	while(1) {
		while(1) {
			USSWDT_KeepAlive();
			if(state >= D_ST_READY)  USSWIFI_Schedule();   // WiFi 는 협조적 스케줄링
			if(USSAPP_CheckEventExist() == true) break;
		}
		for(event = 0; event < D_EVENT_NONE; event++)
			if(USSAPP_CheckEvent(event)) { state = c_event_func_tbl[event](state); break; }  // 최소 이벤트 번호가 우선
	}
}
```

| 실측 | 값 |
|---|---|
| 이벤트 수 | **31개** — 기본 22개(`INITIALIZE`~`AGING_END`) + `USE_CUSTOM_INTERFACE`(HC 프로토콜) 활성 시 9개 추가(`CUSTOM_CMD_RECEIVED` 등) |
| 디스패치 순서 | 이벤트 번호 오름차순 **우선순위** — 여러 이벤트가 동시에 서 있으면 번호가 작은 쪽만 처리하고 나머지는 다음 루프로 미룬다 |
| WiFi 스케줄링 | `state >= D_ST_READY` 일 때만 `USSWIFI_Schedule()` 호출 — RTOS 없이 **협조적(cooperative) 멀티태스킹** |
| 워치독 | 매 스핀마다 `USSWDT_KeepAlive()` — 이벤트 핸들러 하나가 오래 걸리면 그 안에서 직접 WDT 를 갱신해야 한다(중앙 타임아웃 감시 없음) |

**커맨드 처리와 상태머신이 공유 가변 상태로 결합돼 있다.** `USSAPP_STM_Custom_CommandReceived`(이벤트 핸들러)는 커맨드를 처리한 뒤 **반환값이 아니라** 전역 `_g_cmd_config`(`CD_Config_t`)의 `scan.status`/`scan.cmd_type`/`nop_flag` 필드를 읽어 다음 이벤트(`SCAN_START`/`SCAN_STOP`/`REBOOT`/`DISCONNECTED` 등)를 판단한다 — 커맨드 파싱(§3.1)과 상태 전이가 사이드채널로 묶여 있어, 새 커맨드 타입을 추가하려면 두 계층을 함께 고쳐야 한다.

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

### 3.1 커맨드 디스패치 — 3단 구조, opcode 144개

`wrapper_packet_process()`(`USSCustomCommand_Wrapper.c:5659`)가 `header->packet_type` 하나로 1단 분기하고, 각 타입을 별도 함수가 opcode 로 2단 분기한다.

```c
switch (header->packet_type) {
case HER_PACKET_TYPE_DEVICE_COMM:      ret = wrapper_rx_device_command(...); break;  // 36개 case
case HER_PACKET_TYPE_FPGA_COMM:        ret = wrapper_rx_fpga_command(...);   break;  // 72개 case
case HER_PACKET_TYPE_AGING_TEST_COMM:  ret = wrapper_rx_aging_command(...);  break;  // 36개 case
}
```

| 패킷 타입 | opcode 수 | 대표 명령 |
|---|---:|---|
| `DEVICE_COMM` | **36** | `DEVICE_SCAN`·`DEVICE_FW_UPGRADE_*`(6단계)·`DEVICE_READ_BATTERY`·`DEVICE_READ_DEVICE_NAME`(§1.1 의 문자열이 여기로 오간다) |
| `FPGA_COMM` | **72** | `FPGA_READ_REG`/`WRITE_REG`/`MEM_DUMP`/`DBG_ADC_DUMP` — **UDL(§4) 레지스터에 대한 직접 read/write.** 스캔 파라미터 read/write 쌍(`FPGA_READ_FOCAL_LENGTH`/`WRITE_FOCAL_LENGTH` 등)도 이 타입 안에 있다. 이름은 `FPGA_*` 지만 §4 정정대로 실체는 UDL 전용 칩이다 |
| `AGING_TEST_COMM` | **36** | 공장 번인(aging) 전용, 별도 소켓(`EN_CTRL_AGING_SOCK`)으로 라우팅 |

**opcode 144개 전부가 별도 정본 없이 `USSCustomCommand_Wrapper.c` 한 파일(5,700+ 줄)에 있다** — `verify_packet_header_and_crc()` 하나가 세 타입 공통 검증을 맡고, 그 아래부터는 `case` 마다 독립 구현이라 opcode 간 공통 로직(예: 모델 문자열 분기, §1.1)이 여러 `case` 에 중복 등장한다.

### 3.2 OTA 펌웨어 업데이트 — 서명 없는 덧셈 체크섬

`DEVICE_FW_UPGRADE_*` 6개 opcode(§3.1)가 `USSFUP_*` 모듈로 이어진다. **이 파일이 두 벌이다** — `USSFUP.c`(`#ifndef USE_CUSTOM_INTERFACE`, 네이티브 프로토콜용)와 `USSFUP_Custom.c`(`#ifdef USE_CUSTOM_INTERFACE`, **출하 빌드가 쓰는 실제 구현**). 아래는 전부 후자 기준이다.

#### 3.2.1 이미지 타입 5종 — MAIN·MSP·RECOVERY·WiFi(×2)

```c
// USSCommand.h
typedef enum { E_FUP_TYPE_MAIN = 0x00, E_FUP_TYPE_MSP = 0x01, E_FUP_TYPE_RECOVERY = 0x02, E_FUP_TYPE_MAX } E_FUP_TYPE;
#define DEF_FUP_TYPE_WIFI1    0x10   // NOTE 주석: 원래 0x01 이었다가 E_FUP_TYPE_MSP 와 충돌해 0x10 으로 변경
#define DEF_FUP_TYPE_WIFI2    0x11
#define DEF_FUP_TYPE_WIFIALL  0x1F
```

`WIFI1` 상수값 변경 커밋의 원문 주석(한국어, 힐세리온 작성): *"WIFI1 값이 기존 0x01 → 0x10 으로 변경됨(E_FUP_TYPE_MSP=0x01 와 충돌 회피). 호스트(C#) `ProbeCtrl.DEF_FUP_TYPE_WIFI1` 도 0x10 로 동일하게 맞춰야 함."* — **HC 프로토콜 상수가 장비·호스트(C# `ProbeCtrl`) 양쪽에 각각 선언돼 있고 사람이 수동으로 맞춰야 한다는 것을 만든 사람이 직접 남긴 증거**다. 이미 확인된 "정본 없이 저장소 9곳에 복제된 HC 프로토콜" 문제의 구체 사례가 하나 더 늘었다.

`USSWIFI_GetWifiNum()` 로 WiFi 모듈 개수를 조회한다 — **WiFi 모듈이 최대 2개(WIFI1/WIFI2) 를 전제**한다. Redpine→ABLIC 전환기(§5)에 두 세대가 공존하는 상황과 무관하지 않아 보인다(미확인 — 실제로 2개가 동시 실장되는지, 아니면 코드가 미래 대비로 남겨둔 것인지).

#### 3.2.2 무결성 검증 — 전송 오류 탐지용 덧셈 체크섬뿐, 서명 없음

```c
// USSFUP_Custom.c
for(i=0; i<dataSize; i++) { gCalcSumVal += pData[i]; }   // USSFUP_Write — 바이트 덧셈만
...
if (gRecvParam.checkSumVal != gCalcSumVal) return DEF_CMD_RSP_NG;   // USSFUP_Verify — 같은 덧셈과 대조
```

| 실측 | 값 |
|---|---|
| 알고리즘 | **바이트 단위 덧셈 합**(`uint32_t += uint8_t`, 오버플로 시 랩어라운드) — CRC 도 아니고 해시도 아니다 |
| 서명 검증 | **없음** — 전 파일 검색 기준 서명·공개키·HMAC 관련 코드 0건 |
| Verify 단계가 하는 일 | (1) 전송 중 누적한 합 vs 클라이언트가 보낸 `checkSumVal` 대조, (2) MAIN/RECOVERY 는 **플래시에서 다시 읽어** 같은 덧셈을 한 번 더 — **읽기 경로가 같은 약한 합산이라 이중 검증의 실효성이 낮다** |
| 충돌 용이성 | 바이트 합산은 바이트 순서를 바꾸거나 두 바이트를 다르게 바꿔도(`+1`/`-1`) 같은 합이 나온다 — 임의 변조 탐지용으로는 사실상 무력 |

이것은 [review/cybersecurity.md](cybersecurity.md) 가 이미 SI-09(업데이트 진본성·무결성)에서 지적한 "펌웨어 이미지 무결성 장치가 전송오류 탐지용 단순 바이트합산 체크섬뿐"이라는 결론(그 문서는 `sonex-framework`/`HCFirmwareController.cpp` 등 **호스트 측** 근거)을 **장비 자체 코드로 한 번 더 확인**한 것이다 — 클라이언트·장비 양쪽 다 같은 약한 체크섬으로 왕복 검증할 뿐, 어느 쪽도 서명을 확인하지 않는다.

#### 3.2.3 MAIN/RECOVERY 저장 — belle 식 A/B 롤백이 아니다

```c
if(gRecvParam.updateType == E_FUP_TYPE_MAIN)       upflag = 0;
else if(gRecvParam.updateType == E_FUP_TYPE_RECOVERY) upflag = 1;
result = USS_FLASH_WriteUpdData_ByIndex(upflag, gRecvDataBuff, gRecvDataSize);
```

`upflag` 는 **현재 실행 중인 뱅크에 따라 토글되는 값이 아니라, 이미지 타입에 따라 고정된 인덱스**다(`MAIN`→0, `RECOVERY`→1). [500c-hardware.md §2.1](500c-hardware.md) 의 플래시 맵과 대조하면, **`RECOVERY` 는 `MAIN` 의 교대 사본이 아니라 별도의 고정 rescue 이미지**다 — 두 슬롯을 오가며 롤백하는 구조가 아니다.

**진짜 토글 로직은 존재하지만 죽어 있다.** 같은 파일의 `USSFUP_Procedure()` 는 `upflag ^= 1`(교대) 후 `USS_FLASH_WriteUpdFlag(upflag)` 로 부트 플래그까지 갱신하는 완결된 A/B 롤백 코드를 갖고 있는데, **이 함수는 정의만 있고 어디서도 호출되지 않는다**(`grep` 전수 확인). 실제 커맨드 경로(`USSFUP_Complete`)에서는 부트 플래그를 쓰는 줄이 전부 주석 처리돼 있고 무조건 성공만 반환한다:

```c
uint8_t USSFUP_Complete(void)
{
    ...
    if(gRecvParam.updateType == E_FUP_TYPE_MAIN) {
        // result = USS_FLASH_WriteUpdFlag(upflag);   ← 주석 처리
        result = DEF_CMD_RSP_OK;                       // 무조건 OK
    }
    ...
}
```

**`BootLoader`·`Updater` 프로젝트 소스(`src_BootLoader/main.c`, `src_Updater/main.c`, `.ewp` 파일 목록으로 위치 확인)를 읽으면 나머지 그림이 맞춰진다.**

```c
// src_BootLoader/main.c — 부팅 시 이미지 선택
unsigned int upd_flag = *(unsigned int*)(FLASH_ADDR_UPD_FLAG + BASE_ADDR_MEM_HSSPI);
unsigned int app_addr;

if(upd_flag != 1)      app_addr = FLASH_ADDR_APP + BASE_ADDR_MEM_HSSPI;        // 평소: MAIN(슬롯 0)
#ifdef USE_CUSTOM_INTERFACE
else                   app_addr = FLASH_ADDR_UPD_DATA_1 + BASE_ADDR_MEM_HSSPI; // upd_flag==1: 슬롯 1(RECOVERY) 로 직접 점프
#else
else                   app_addr = FLASH_ADDR_UPDATER + BASE_ADDR_MEM_HSSPI;    // upd_flag==1: Updater 바이너리로 점프
#endif

__set_MSP(*(int*)app_addr);
MCUg_Interrupt_SetVectorAddr(app_addr);
((void (*)())(*((unsigned int*)reset_addr)))();   // 체크섬·CRC 검증 없이 그대로 점프
```

```c
// src_Updater/main.c — UPD_DATA(스테이징, 0x220000) 를 APP(0x80000) 로 안전하게 복사하는 별도의 작은 프로그램
void fw_update() {
	unsigned int upd_size = *(unsigned int*)(FLASH_ADDR_UPD_SIZE + BASE_ADDR_MEM_HSSPI);
	dst_addr = FLASH_ADDR_APP; src_addr = FLASH_ADDR_UPD_DATA;
	while(upd_size > 0) { flash_erase(dst_addr, sz); flash_read(src_addr, buff, sz); flash_program(dst_addr, buff, sz); ... }
	flash_erase(FLASH_ADDR_UPD_FLAG, sizeof(unsigned int));   // 완료 후 플래그 해제
	MCUg_Crg_ReqSoftReset(false);
}
```

**설계상 안전한 갱신 경로가 이미 존재한다 — 단 네이티브(비-HC) 프로토콜 빌드에만 배선돼 있다.** 원래 그림은: ① 앱이 신규 이미지를 스테이징 영역(`FLASH_ADDR_UPD_DATA`, 0x220000)에 받는다 → ② `UPD_FLAG=1` 세팅 후 재부팅 → ③ `BootLoader` 가 `UPD_FLAG==1` 을 보고 **APP 대신 `Updater` 로 점프** → ④ `Updater` 가 스테이징 → `FLASH_ADDR_APP`(라이브 부팅 영역) 복사를 전담하고, 끝나면 `UPD_FLAG` 를 지우고 리셋. 이 경로라면 라이브 영역을 건드리는 위험한 쓰기는 항상 검증된 완전한 이미지를 상대로만 일어난다.

**그런데 출하 빌드(`USE_CUSTOM_INTERFACE`)는 이 경로를 쓰지 않는다.** `USSFUP_Custom.c` 의 실제 커맨드 경로는 `UPD_FLAG` 를 아예 건드리지 않고, `USS_FLASH_WriteUpdData_ByIndex(upflag=0, ...)` 로 **`FLASH_ADDR_APP`(라이브 부팅 영역)에 바로** 쓴다 — `Updater` 바이너리는 이 경로에서 호출될 일이 없다. `UPD_FLAG==1` 일 때 `BootLoader` 가 가는 곳도 `Updater` 가 아니라 **슬롯 1(RECOVERY)로 직접**이라, 저 안전한 간접 경로 자체가 출하 빌드에서는 죽어 있다.

**결론 — OTA 도중 중단되면 벽돌 위험이 실재한다.** `FLASH_ADDR_APP` 쓰기는 64KB 섹터 단위 erase+program 을 반복하며 원자적이지 않고, 부트로더는 점프 전에 어떤 검증도 하지 않는다(위 코드 그대로 `__set_MSP` 후 바로 점프). 전원 손실이 이 erase+program 구간에서 일어나면 다음 부팅은 반쯤 지워진 코드로 점프한다. RECOVERY(슬롯 1)를 미리 구워 뒀더라도 `UPD_FLAG` 를 세팅해 그쪽으로 전환하는 로직이 출하 경로에는 없다 — 자동 복구가 아니라 공장 재플래싱(JTAG, `FlashLoader`/`RawBin` 프로젝트)이 사실상 유일한 복구 수단으로 보인다.

#### 3.2.4 MSP430 업데이트 — SBW/BSL, 기본(공백) 비밀번호로 시도

`E_FUP_TYPE_MSP` 는 `USSFUP_MSP_Upgrade()` 를 부른다 — **500c-sn-fw 보드에도 MSP430 이 있다**([500c-hardware.md](500c-hardware.md) §4, belle 의 MSP430FR2433 과는 별개 실장).

| 실측 | 값 |
|---|---|
| 인터페이스 | **SBW(Spy-Bi-Wire) 비트뱅잉** — `USSIO_MSP_RST/TEST/SBW` 매크로가 `MICOM_SBWTDIO`/`MICOM_SBWTCK` GPIO 를 직접 토글(`USSIO.h`) |
| 진입 시퀀스 | BSL(BootStrap Loader) invoke string `{0xCA,0xFE,0xDE,0xAD,0xBE,0xEF,0xBA,0xBE}` — MSP430 BSL 표준 매직 시퀀스 |
| 비밀번호 | `bslPassword[32]` 를 **전부 `0xFF`(공백/소거 상태 기본값)로 채우고 우선 시도** — 실패하면 재시도할 때도 다시 `0xFF` 로 초기화. 실제 비밀번호를 별도로 관리하는 코드는 찾지 못했다 |
| 전송 | 16바이트(`chunk_size=16`) 단위로 `MSP430BSL_sendData()`, 최대 4회 재시도(`MSP430_I2C_ATTEMPTS`) |

MSP430 BSL 은 물리 접근(디버그 핀)이 전제라 원격 공격 표면은 아니지만, **비밀번호 보호를 사실상 쓰지 않는(공백 고정) 상태**라는 점은 물리 접근 시나리오에서 기록해 둘 값어치가 있다.

#### 3.2.5 메모리 — MAIN/MSP/RECOVERY 는 전체 이미지를 SRAM 에 malloc

`USSFUP_Start()` 가 `updateSize`(최대 512KB, §3.1) 만큼 `malloc()` 하고, `USSFUP_Write()` 가 다 받을 때까지 그 버퍼에 이어 붙인 뒤 **한 번에** 플래시로 쓴다 — WiFi 이미지만 청크 단위로 바로 스트리밍한다(`USSWIFI_FwupLoad`). 512KB malloc 은 [500c-hardware.md §1](500c-hardware.md) 의 D-code SRAM(1MB) 안에서는 가능하지만, 스캔·통신 등 다른 용도와 힙을 나눠 써야 해 **동시에 스캔 중 OTA 를 받으면 메모리 여유가 빠듯할 것으로 추정**된다(실측 아님).

## 4. UDL — 초음파 신호처리 전용 칩

빔포밍·스캔변환·JPEG 을 **UDL 전용 칩이 수행**하고 MCU 는 시퀀서다. `charm-fpga`(Efinix)와는 무관하다 — 상세 근거 = [500c-hardware.md §3](500c-hardware.md).

`App` → `MCU_udl_api.h`(`MCUg_Udl_RegWrite/RegRead`·`SetScenarioId`·`StartScan`) → `udl_prm.h` → **프리빌트 `lib/libudl.a`**.

**UDL 소스는 어느 브랜치에도 없다.** 게다가 live 브랜치가 `libudl*.a` **8개 변종**을 동시에 갖고 있다(`_org`·`_back_20240408`·`_20240524_back`·`_adcdump`·`_Convex_B_PW_SideNoise`·`_1.1.5.0`·`_1.1.7.0`) — 바이너리를 git 대신 비공식 버전관리로 쓰고 있다.

### 4.1 스캔 파라미터 관리 — `PRM_ID` 배열 디스패치

`USC_Param.c`(3,535줄)가 스캔 파라미터를 **ID 인덱스 배열**로 관리한다.

```c
// USC_Param_local.h
typedef enum { ... PRM_ID_CLR_NOISE_REDUCT, PRM_ID_CLR_WALL_FILTER, ...,
               PRM_ID_NUM2, PRM_ID_MAX = 255 } EN_PRM_ID;
```

| 실측 | 값 |
|---|---|
| 상한 | `PRM_ID_MAX = 255` |
| 실제 정의된 상수 | **123개**(`USC_Param_local.h`) — `AFE_HARMO1_F1`·`CLR_NOISE_REDUCT`·`LINE_GAIN_OFS_SC0~2`·`PWR_WALL_FILTER` 등 |
| 조회 방식 | `PRM_ID` 를 인덱스로 쓰는 get/set 함수 포인터 배열(`USC_PRM_Get`/`USC_PRM_Set`) — HC 프로토콜의 `FPGA_READ/WRITE_*`(§3.1)가 최종적으로 이 배열을 통해 UDL 레지스터에 닿는다 |
| 프로브별 분기 | `USC_PRM_Get`류 함수 다수가 `USSDEV_getProbeType()`(§1.1 의 플래시 설정)로 내부 분기 — 파라미터 테이블 자체가 이미 **모델별 데이터 테이블** 형태다 |

**함의** — opcode(§3.1)·파라미터 ID(§4.1)·UDL 레지스터(500c-hardware.md §3) 세 계층이 전부 **평평한 정수 인덱스 배열**로 연결돼 있다. 모델별 차이가 이미 "배열 안 데이터"로 존재하므로, 이 저장소 자체는 [r1 Phase 10](../../refactoring/r1/phase10-runtime-variant.md) 이 목표로 하는 "컴파일 타임 변종 → 런타임 설정 데이터" 구조에 **이미 도달해 있다** — belle-fw(컴파일 플래그 분기, `device-firmware.md`)보다 앞선 설계다.

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
- **일부 주석이 이미 복원 불가능하게 손상돼 있다** — `StateMachine.c`(`USSAPP_STM_Custom_CommandReceived` 등)의 줄 주석을 `xxd` 로 까 보면 `ef bf bd`(U+FFFD, REPLACEMENT CHARACTER)가 반복된다. 원본이 Shift-JIS 등 비-UTF-8 인코딩이었다가 **깨진 문자를 U+FFFD 로 치환하는 손실 변환을 거친 뒤 그 상태로 커밋된 것**으로 보인다 — 지금 시점에서 git 이력을 아무리 되짚어도 원문 자체가 남아 있지 않다(추정)
