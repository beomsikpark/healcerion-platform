# 500C·500P 하드웨어 구성 (`500c-sn-fw`)

> **근거**: `500c-sn-fw` `origin/FW_1_1_8_0`(2026-04-24, live)·`master`(3커밋, 초기 스텁 — §7 참조) 드라이버·헤더 직접 읽기.
> **한계**: 회로도·BOM 은 없다. 아래는 **소프트웨어가 전제하는 하드웨어**를 역산한 것이다. 확정 필요 항목은 §6 에 모았다.
> **관련**: [500c-firmware.md](500c-firmware.md)(펌웨어 구조·모델 SKU) · [belle-hardware.md](belle-hardware.md)(belle 계열 대조군)

## 1. 시스템 정체

| 항목 | 값 | 출처 |
|---|---|---|
| MCU | Socionext **Cortex-M 베어메탈**(OS 없음) | 전 드라이버 헤더의 `Copyright (C) 2023 Socionext Inc.`, `src/Wrapper/SRC/MCU_OS.c` 의 더미 mutex |
| 초음파 신호처리 | **전용 칩**이 담당 — MCU 는 시퀀서 역할. 정확한 칩 정체는 §3 참조 | — |
| 빌드 환경 | IAR EWARM 5.10 | `.ewp` |
| 보드 리비전 플래그 | `USE_CUSTOM_BOARD`(`.ewp` CCDefines) | 세부 리비전 번호(ES1/ES2 등)는 플래그명에서 확인 안 됨 — §6 |

MCU 정확한 파트넘버는 `.ewp` 의 `OGChipSelectEditMenu = Default None`으로 비어 있어 **코드만으로는 확정 불가**하다(§6).

## 2. 저장장치 — SPI NOR 단일 칩, 32MB

```c
// src/Wrapper/InitParam/MCU_spiflash_param.h (origin/FW_1_1_8_0)
const SPIFLASH_INFO_T spiflash_Info = {
    CYPRESS, mid01_quad_enable, mid01_set_protocol, mid01_set_addrmode,
    mid01_erase_bulk, mid01_erase_sect, CYRPESS_ARB, MSEL_32MB
};
```

belle(§2, `jedec,spi-nor` 런타임 자동인식)와 달리 **제조사가 컴파일 타임에 CYPRESS(Infineon) 로 고정**돼 있다 — 자동인식이 아니라 특정 벤더 드라이버(`mid01_*`)를 직접 호출한다. Quad SPI, 용량 **32MB**(`MSEL_32MB`).

### 2.1 플래시 주소 맵

```c
// src/Wrapper/API_include/MCU_common.h
#define FLASH_ADDR_MAX          0x07FFFFFF   // 주소공간은 128MB 까지 정의(실장은 32MB)
#define FLASH_ADDR_BOOT         0x00000000
#define FLASH_ADDR_UPDATER      0x00040000
#define FLASH_ADDR_APP          0x00080000   // = FLASH_ADDR_UPD_DATA_0
#define FLASH_ADDR_PARAM        0x00100000
#define FLASH_ADDR_UPD_FLAG     0x00200000
#define FLASH_ADDR_UPD_SIZE     0x00210000
#define FLASH_ADDR_UPD_DATA     0x00220000   // = FLASH_ADDR_UPD_DATA_1
#define FLASH_ADDR_ACTION_REC   0x002A0000
#define FLASH_ADDR_AGING_DEVINFO 0x00300000  // 1MB
#define FLASH_ADDR_AGING_B_IMAGE 0x00400000  // 3MB
```

| 영역 | 오프셋 | 내용 |
|---|---|---|
| BOOT | `0x000000` | 1차 부트로더(`FlashBoot`) |
| UPDATER | `0x040000` | `Updater` 프로젝트 이미지 |
| **APP / UPD_DATA_0** | `0x080000` | 현재 실행 앱 이미지 |
| PARAM | `0x100000` | 초기 파라미터 영역 — `USS_FLASH.h` 의 `ADR_FLASH_RGN_INI_PRM_*`·`CUSTOM_PRM`(공장 설정: `device`·`probe_id`·`probe_resistance` 등, §5) 이 전부 이 아래 오프셋으로 배치 |
| UPD_FLAG / UPD_SIZE | `0x200000`/`0x210000` | 업데이트 진행 상태 |
| **UPD_DATA / UPD_DATA_1** | `0x220000` | 신규 이미지 다운로드 영역 |
| ACTION_REC | `0x2A0000` | 동작 이력 기록 |
| AGING_DEVINFO | `0x300000`(1MB) | 에이징(공장 번인) 장비정보 |
| AGING_B_IMAGE | `0x400000`(3MB) | 에이징용 B-모드 이미지 패턴 |

`FLASH_ADDR_APP`(`0x80000`)이 `FLASH_ADDR_UPD_DATA_0` 매크로와 값이 같고, `FLASH_ADDR_UPD_DATA`(`0x220000`)가 `FLASH_ADDR_UPD_DATA_1` 과 같다. **인덱스 0/1 은 belle 식 A/B 교대 뱅크가 아니라 이미지 타입별 고정 슬롯이다** — `E_FUP_TYPE_MAIN`→인덱스 0, `E_FUP_TYPE_RECOVERY`→인덱스 1. `RECOVERY` 는 `MAIN` 의 교대 사본이 아니라 별도의 고정 rescue 이미지다. 진짜 뱅크 토글 로직(`upflag ^= 1` + 부트플래그 갱신)이 `USSFUP_Procedure()` 에 있지만 **어디서도 호출되지 않는 죽은 코드**이고, 실제 커맨드 경로(`USSFUP_Complete`)는 부트플래그를 쓰는 줄이 주석 처리된 채 무조건 성공만 반환한다. 새 MAIN 이미지가 실제로 어떻게 부팅에 반영되는지는 이 소스만으로 확인 불가(`Updater`/`BootLoader` 프로젝트 쪽 로직 미확인) — 상세 = [500c-firmware.md §3.2.3](500c-firmware.md).

## 3. UDL — 초음파 신호처리 전용 칩

`500c-sn-fw` 의 `libudl.a`(소스 없는 프리빌트, [500c-firmware.md §4](500c-firmware.md))가 감싸는 "UDL" 하드웨어 블록은 **초음파 신호처리 전용 칩**이 담당한다. MCU 는 이 칩의 시퀀서 역할만 한다.

| 실측 | 값 |
|---|---|
| MCU 측 UDL 레지스터 베이스 | `BASE_ADDR_UDL 0x41000000`(`MCU_common.h`) — SPI 컨트롤러 레지스터 베이스(`BASE_ADDR_REG_HSSPI 0x40032000`, `BASE_ADDR_SPI0/1 0x40007000`/`0x40008000`)와 별도 주소 |
| 초기화 경로 | `MCUg_Udl_Initialize()` → `udl_prm_initialize()` — 비트스트림 로드·config 코드 없음. 고정 하드웨어를 레지스터로 제어하는 패턴에 가깝다 |
| 지원 프로브 타입 | `MCU_udl_api.h`: `enMCU_UDL_PRB_TYPE { LINEAR, HF_LNR, CONVEX, SECTOR }` — 4종 정의, 실제 출하 확인은 **CONVEX(500C)·SECTOR(500P)** 둘뿐(§5) |
| 소스 위치 | 이 칩을 구동하는 신호처리 로직 자체는 `500c-sn-fw` 어느 브랜치에도 없다(`libudl.a` 프리빌트뿐) — **칩 벤더(ABLIC, 구 Socionext)가 별도 제공한다는 것을 확인**([500c-firmware.md §1.2](500c-firmware.md), 벤더 SDK 패키지 대조. 이전에는 "추정"이었다) |

**벤더 문서는 이 블록의 기능을 확정한다, 물리적 정체는 여전히 미확인.** 벤더 SDK(`viewphii64_WPDP_SCS_2.0.0`)의 `Document/viewphii64_UltrasoundProcessingUnit_Specification[Rev1.8].pdf`(79쪽)가 이 블록을 "Ultrasound Processing Unit"으로 명명하고 Transmit Pulse Processor·Delay Processor·Analog Processor·Color/Pulse Doppler Processing·JPEG 인코딩까지 전부 **고정 기능 블록**으로 기술한다 — `libudl.a` 가 감싸는 것이 정확히 이 블록이다. 다만 **"MCU(`US3_ARM`)와 같은 다이인지 별도 칩인지"는 벤더 SDK 를 확보한 뒤에도 여전히 미확인**이다 — 벤더 자신의 IAR 프로젝트(`US3_ARM_FlashBoot.ewp`)도 `OGChipSelectEditMenu` 가 빈 값이고, PDF 스펙 8종 전체를 훑어도 package·die·SoC·ASIC 등 물리적 집적도를 명시한 문장이 없다. `0x41000000`(SPI 컨트롤러 `0x40007000`대와 별도 영역)이 온칩 주변장치 버스인지 별도 다이로 가는 브릿지인지는 **이 자료만으로는 여전히 확정 불가** — 정확한 칩 파트넘버·물리 구성은 미확인으로 남긴다(§6).

**belle 과의 대조 — "구분"은 물리적 칩이 아니라 처리 주체다.** belle(`device/legacy/belle-fw` `origin/production-fw-ver2.0`)의 동급 기능은 정반대로 **일반 ARM 코어 위의 소프트웨어**다 — 컬러 도플러 추정은 `lib/cf-doppler.c`(1,585줄, `arm_neon.h` NEON 인트린식·`ATAN2_TABLE_*` 룩업테이블 기반 오토코릴레이터, `-ffast-math -ftree-vectorize`로 빌드), B-mode 영상 형성은 `image_proc/b_conventional.cpp`(671줄)·`b_sa.cpp` 가 담당한다. `lib/fpga*.cpp`(EBI 를 통해 온칩 PL 에 접근)는 AFE 레지스터 제어·펄서·버퍼 시퀀싱만 하고 빔포밍·도플러 추정 자체는 하지 않는다 — 500c-sn-fw 의 UDL 이 이 전부를 고정 하드웨어 블록으로 흡수한 것과 정확히 대칭이다. 즉 **"물리적으로 몇 개 칩인가"는 두 라인 다 부분적으로 미확인이지만, "신호처리를 누가 하는가"(고정 하드웨어 블록 vs 범용 코어 위 소프트웨어)는 양쪽 소스 모두에서 확인된 사실이다.**

`fpga/legacy/charm-fpga` 는 이 칩과 무관하다 — Xilinx 계 ginny/elsa/fuji 300 시리즈([ginny-fpga.md](legacy/ginny-fpga.md))에서 갈라져 나온 별도 FPGA 이며, 500c-sn-fw·sonon·probe 관련 용어가 커밋 이력에 없다.

## 4. 주변장치

| 버스·장치 | 내용 | 근거 |
|---|---|---|
| **I2C** | **MAX1720x 퓨얼게이지**(`MODELGAUGE_DATA_I2C_ADDR`) + 배터리 NVRAM(`NONVOLATILE_DATA_I2C_ADDR`, 제조일자·시리얼) | `USSDEV_STAT_Battery_Custom.c` — belle 의 MSP430(§5)과 달리 **보조 MCU 없이 호스트 MCU 가 직접** 퓨얼게이지를 읽는다 |
| **MCU 내장 ADC** | **온도 센서 전용**(`SENSOR_THERMO1`·`SENSOR_THERMO2`) — 초음파 RX 신호 경로가 아니다 | `USSDEV_STAT_Thermo_Custom.c` |
| **MCU 내장 DAC** | 초기화만 확인(`MCUg_Dac_Initialize()`), 정확한 용도 미확인 — 펄서 바이어스 전압이나 TGC 아날로그 설정값 후보(추정) | `USSIO.c:43` |
| **SPI(WiFi)** | Redpine **RS9116W**(WiSeConnect SDK) — SPI 로 연결(`rsi_spi_iface_init.c`) | `Middleware/WiFiHost/Module1` |
| USB | `Driver/USB`(`DPI_*`, `EhdcDev_DPI_Device_Reg.h`) — USB 디바이스 컨트롤러. 용도(공장 프로그래밍·디버그 추정) 미확인 | — |
| UART/GPIO/타이머/WDT | `pl011`(UART) · `exgpio`/`EXIU`(외부 인터럽트) · `timer`(`PIT`) · `wdt` · `acrg`(Clock & Reset Generator) | 드라이버 폴더명 + `acrg_drv.h` 주석 |
| **HS-SPI(플래시)** | `fip006/hsspi_drv.h` — SPI NOR 플래시 전용 고속 SPI 컨트롤러(§2) | — |
| **MSP430** | 별도 보조 MCU 실장 — belle 의 MSP430FR2433(I2C 레지스터 인터페이스)과 달리 **SBW(Spy-Bi-Wire) 비트뱅잉 GPIO**(`MICOM_SBWTDIO`/`MICOM_SBWTCK`)로 연결, BSL(BootStrap Loader) 프로토콜로 펌웨어를 직접 재프로그램 | `USSFUP_Custom.c` 의 `USSFUP_MSP_Upgrade()`, `USSIO.h` 의 `USSIO_MSP_RST/TEST/SBW` 매크로 — 상세 = [500c-firmware.md §3.2.4](500c-firmware.md) |

**WiFi 모듈 세대 교체**(CLAUDE.md 기확인 사항) — Redpine RS9116W(`Module1`) → 2025년 ABLIC 이전(`Module2`). 기존 트리를 지우지 않고 병존시켜 114,125 LOC 로 늘었다([500c-firmware.md §5](500c-firmware.md)).

## 5. 프로브 식별 — 공장 출하 시 플래시 설정, 실시간 자동인식 아님

| 실측 | 값 |
|---|---|
| 식별 방식 | `USS_FLASH_getCustom_Device()`(12바이트 `device` 문자열) + `getCustom_Probe_Id()`(1바이트) + `getCustom_Probe_Resistance()`(1바이트) — **전부 `USSDebug.c` 디버그 콘솔 명령으로 공장에서 플래시에 기록**하는 값이다 |
| 실시간 검출 경로 | **없음** — 프로브 EEPROM 읽기나 커넥터 ID 핀 감지 코드를 찾지 못했다 |
| UDL 이 실제로 받는 값 | `probe_id` 바이트를 `MCU_Udl_ConvertProbeType()` 이 `enMCU_UDL_PRB_TYPE` 4종(`LINEAR`·`HF_LNR`·`CONVEX`·`SECTOR`) 으로 매핑 |
| 제품명 문자열 → UDL 타입 | `"500C"`→CONVEX · `"500P"`→SECTOR — 확인된 출하 매핑은 이 둘뿐. `"500L"`/`"500LS"`→LINEAR 분기도 코드에 있으나 출하 확인 안 됨([500c-firmware.md §1.1](500c-firmware.md)) |

**함의** — 확인된 것은 **500C·500P** 두 SKU 다. 하나의 콘솔에 프로브를 갈아 끼우는 구조가 아니라, **같은 MCU+초음파 신호처리 칩 기판 설계를 공유하는 별개의 밀봉형(추정) 유닛**일 가능성이 높다. 공장에서 그 유닛이 어떤 프로브를 담고 있는지를 플래시 문자열로 "선언"할 뿐이다. 이는 [500c-firmware.md §1.1](500c-firmware.md) 이 확인한 **"공용 펌웨어, 런타임(플래시) 설정으로 분기"** 구조와 정확히 같은 층위이고, 여기서는 그 설정이 **소프트웨어 분기(device 문자열)뿐 아니라 UDL 하드웨어 블록의 실제 신호처리 파라미터(`probe_id`→`enMCU_UDL_PRB_TYPE`)까지 함께 바꾼다**는 것을 보탠다.

`enMCU_UDL_PRB_TYPE` 의 `HF_LNR`(고주파 리니어)·`LINEAR` 는 제품명 문자열(500C/500P) 어디에도 실사용 대응이 없다 — UDL 이 지원하는 4종 중 실제 출하가 확인된 것은 CONVEX·SECTOR 둘뿐이다.

## 6. 확인이 필요한 항목

| 항목 | 현재 상태 |
|---|---|
| MCU 정확한 파트넘버·패키지 | `.ewp` 에 `Default None` — 코드만으론 특정 불가 |
| UDL(초음파 신호처리 칩) 정확한 파트넘버·벤더 | `libudl.a` 프리빌트뿐, 데이터시트·소스 없음 — 온칩 블록인지 별도 다이인지도 미확인(§3) |
| 보드 리비전 세부(ES1/ES2 등) | `USE_CUSTOM_BOARD` 플래그만 확인, 리비전 값은 미확인 |
| MAIN 갱신이 실제 부팅에 반영되는 경로 | `Updater`/`BootLoader` 프로젝트 쪽 로직 미확인(§2.1) |
| MCU 내장 DAC 의 정확한 용도 | 초기화 호출만 확인. 펄서·TGC 관련 추정만 있음 |
| USB 컨트롤러 용도 | 공장 프로그래밍/디버그 추정, 확정 아님 |
| `HF_LNR`·`LINEAR` UDL 타입에 대응하는 실제 제품 | 미확인 — 출하 확인은 CONVEX(500C)·SECTOR(500P) 둘뿐 |
| 500C·500P 가 정말 별개 기구물(밀봉 핸드헬드)인지 | 프로브 자동인식 회로 부재라는 정황증거뿐. 매뉴얼·사진 등 별도 확인 필요 |
| 회로도·BOM | 없음 — 위 전부 소프트웨어에서 역산 |

## 7. 조사 함정 — `master` 브랜치

`500c-sn-fw` 의 `master` 는 **커밋 3개짜리 초기 스텁**이고 이 문서가 다룬 내용(UDL 모델별 분기, ABLIC WiFi 전환 등) 이전 상태다. 이 저장소를 검색할 때는 반드시 라이브 브랜치(`origin/FW_1_1_4_0`~`origin/FW_1_1_8_0`)를 대상으로 해야 한다 — 상세 = [500c-firmware.md](500c-firmware.md) 상단 콜아웃.
