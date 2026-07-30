# 500C·500P·500LS 하드웨어 구성 (`500c-sn-fw` · `charm-fpga`)

> **근거**: `500c-sn-fw` `origin/FW_1_1_8_0`(2026-04-24, live)·`master`(3커밋, 초기 스텁 — §7 참조) 드라이버·헤더 직접 읽기, `charm-fpga` `master` 의 RTL·합성 스크립트 직접 읽기(2026-07-30).
> **한계**: 회로도·BOM 은 없다. 아래는 **소프트웨어·합성 산출물이 전제하는 하드웨어**를 역산한 것이다. 확정 필요 항목은 §6 에 모았다.
> **관련**: [500c-firmware.md](500c-firmware.md)(펌웨어 구조·모델 SKU) · [belle-hardware.md](belle-hardware.md)(belle 계열 대조군)

## 1. 시스템 정체

| 항목 | 값 | 출처 |
|---|---|---|
| MCU | Socionext **Cortex-M 베어메탈**(OS 없음) | 전 드라이버 헤더의 `Copyright (C) 2023 Socionext Inc.`, `src/Wrapper/SRC/MCU_OS.c` 의 더미 mutex |
| FPGA | **Efinix Titanium `Ti60F225`** | `charm-fpga/syn/efx/charm.xml`: `<efx:family name="Titanium"/><efx:device name="Ti60F225"/>` |
| 프로젝트 코드명 | **`charm`** | `charm-fpga` 리포명 자체 + `charm.peri.xml` 의 `design_db name="charm"`. CLAUDE.md 의 `[LAB] CHARM` 과 일치 |
| 빌드 환경 | IAR EWARM 5.10(MCU) · Efinity 2022.1(FPGA, `charm.peri.xml` 의 `version="2022.1.226.2.11"`) | `.ewp`·`charm.peri.xml` |
| 개발자 로컬 경로 잔존 | `charm.peri.xml` 의 `location="/home/peter/work/project/charm/fpga_charm/syn/efx"` | 저장소 밖 절대경로 의존 — belle 계열과 같은 패턴 |
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

`FLASH_ADDR_APP`(`0x80000`)이 `FLASH_ADDR_UPD_DATA_0` 매크로와 값이 같고, `FLASH_ADDR_UPD_DATA`(`0x220000`)가 `FLASH_ADDR_UPD_DATA_1` 과 같다 — **belle 의 `kernel`/`kernel2` A/B 뱅크와 같은 구도**로 보인다(현재 앱 vs 신규 다운로드 슬롯). 다만 **부트로더가 실제로 두 슬롯 중 하나를 선택해 부팅하는 코드는 확인하지 못했다** — belle 처럼 완전한 롤백 구조인지, 아니면 다운로드 후 APP 영역에 재기록(덮어쓰기)하는 방식인지 **미확인**(§6).

## 3. FPGA(UDL) — RF 캡처·빔포밍 가속기

`500c-sn-fw` 의 `libudl.a`(소스 없는 프리빌트, [500c-firmware.md §4](500c-firmware.md))가 감싸는 **"UDL" 하드웨어 블록의 실체가 `charm-fpga`** 로 보인다.

| 근거 | 내용 |
|---|---|
| RTL 구성 | `rtl/adc_if`(ADC 캡처) · `rtl/rx`(수신 빔포밍) · `rtl/scan_buf`(스캔 버퍼) · `rtl/ctrl` · `rtl/spi_if`(호스트 통신) |
| MCU↔FPGA 링크 | **SPI, quad(x4)** — MCU 측 `pl022_drv_master.h`(마스터) ↔ FPGA 측 `rtl/spi_if/spix4_slave.v`(슬레이브) |
| MCU 측 UDL 레지스터 베이스 | `BASE_ADDR_UDL 0x41000000`(`MCU_common.h`) — SPI 컨트롤러 레지스터 베이스(`BASE_ADDR_REG_HSSPI 0x40032000`, `BASE_ADDR_SPI0/1 0x40007000`/`0x40008000`)와 **별도** 주소다 |
| 지원 프로브 타입 | `MCU_udl_api.h`: `enMCU_UDL_PRB_TYPE { LINEAR, HF_LNR, CONVEX, SECTOR }` — 4종 |

**미확인 — 제어 경로가 둘로 갈린다.** SPI(quad, 저속 제어/설정 추정)와 별도 메모리매핑 베이스(`0x41000000`, 고속 데이터 추정)가 공존한다. belle 의 PL 인터페이스(§3, `0xB000_0000` 단일 윈도우 + GPIO 인터럽트)처럼 **하나의 버스로 통합돼 있는지, 아니면 SPI=설정/메모리버스=데이터로 역할이 나뉘는지** RTL 을 더 읽어야 확정된다.

`charm-fpga` 는 **Xilinx Artix-7 기반이던 ginny/elsa/fuji 계보(IDCODE `0x03631093`, [ginny-fpga.md](legacy/ginny-fpga.md))와 무관한 별도 FPGA 벤더·계보**다 — Efinix 는 CLAUDE.md 의 FPGA 계보표(§"제품 라인")에 belle 의 `elsa-fpga`(ZynqMP 내장 PL)나 300 시리즈 Artix-7 계보 어디에도 속하지 않는 **세 번째 FPGA 계보**로 추가해야 한다.

## 4. 주변장치

| 버스·장치 | 내용 | 근거 |
|---|---|---|
| **I2C** | **MAX1720x 퓨얼게이지**(`MODELGAUGE_DATA_I2C_ADDR`) + 배터리 NVRAM(`NONVOLATILE_DATA_I2C_ADDR`, 제조일자·시리얼) | `USSDEV_STAT_Battery_Custom.c` — belle 의 MSP430(§5, belle-hardware.md)과 달리 **보조 MCU 없이 호스트 MCU 가 직접** 퓨얼게이지를 읽는다 |
| **MCU 내장 ADC** | **온도 센서 전용**(`SENSOR_THERMO1`·`SENSOR_THERMO2`) — 초음파 RX 신호 경로가 아니다 | `USSDEV_STAT_Thermo_Custom.c` |
| **MCU 내장 DAC** | 초기화만 확인(`MCUg_Dac_Initialize()`), 정확한 용도 미확인 — 펄서 바이어스 전압이나 TGC 아날로그 설정값 후보(추정) | `USSIO.c:43` |
| **SPI(WiFi)** | Redpine **RS9116W**(WiSeConnect SDK) — SPI 로 연결(`rsi_spi_iface_init.c`) | `Middleware/WiFiHost/Module1` |
| **SPI(FPGA)** | §3 — quad, MCU 마스터/FPGA 슬레이브 | — |
| USB | `Driver/USB`(`DPI_*`, `EhdcDev_DPI_Device_Reg.h`) — USB 디바이스 컨트롤러. 용도(공장 프로그래밍·디버그 추정) 미확인 | — |
| UART/GPIO/타이머/WDT | `pl011`(UART) · `exgpio`/`EXIU`(외부 인터럽트) · `timer`(`PIT`) · `wdt` · `acrg`(Clock & Reset Generator) | 드라이버 폴더명 + `acrg_drv.h` 주석 |
| **HS-SPI(플래시)** | `fip006/hsspi_drv.h` — SPI NOR 플래시 전용 고속 SPI 컨트롤러(§2) | — |

**WiFi 모듈 세대 교체**(CLAUDE.md 기확인 사항) — Redpine RS9116W(`Module1`) → 2025년 ABLIC 이전(`Module2`). 기존 트리를 지우지 않고 병존시켜 114,125 LOC 로 늘었다([500c-firmware.md §5](500c-firmware.md)).

## 5. 프로브 식별 — 공장 출하 시 플래시 설정, 실시간 자동인식 아님

| 실측 | 값 |
|---|---|
| 식별 방식 | `USS_FLASH_getCustom_Device()`(12바이트 `device` 문자열) + `getCustom_Probe_Id()`(1바이트) + `getCustom_Probe_Resistance()`(1바이트) — **전부 `USSDebug.c` 디버그 콘솔 명령으로 공장에서 플래시에 기록**하는 값이다 |
| 실시간 검출 경로 | **없음** — 프로브 EEPROM 읽기나 커넥터 ID 핀 감지 코드를 찾지 못했다 |
| UDL 이 실제로 받는 값 | `probe_id` 바이트를 `MCU_Udl_ConvertProbeType()` 이 `enMCU_UDL_PRB_TYPE` 4종(`LINEAR`·`HF_LNR`·`CONVEX`·`SECTOR`) 으로 매핑 |
| 제품명 문자열 → UDL 타입 | `"500C"`→CONVEX · `"500P"`→SECTOR · `"500L"`/`"500LS"`→LINEAR ([500c-firmware.md §1.1](500c-firmware.md)) |

**함의** — 500C/500P/500LS 는 하나의 콘솔에 프로브를 갈아 끼우는 구조가 아니라, **같은 MCU+FPGA 기판 설계를 공유하는 별개의 밀봉형(추정) 유닛**일 가능성이 높다. 공장에서 그 유닛이 어떤 프로브를 담고 있는지를 플래시 문자열로 "선언"할 뿐이다. 이는 [500c-firmware.md §1.1](500c-firmware.md) 이 이미 확인한 **"3-SKU 공용 펌웨어, 런타임(플래시) 설정으로 분기"** 구조와 정확히 같은 층위이고, 여기서는 그 설정이 **소프트웨어 분기(device 문자열)뿐 아니라 UDL 하드웨어 블록의 실제 신호처리 파라미터(`probe_id`→`enMCU_UDL_PRB_TYPE`)까지 함께 바꾼다**는 것을 보탠다.

`enMCU_UDL_PRB_TYPE` 의 **`HF_LNR`(고주파 리니어)는 제품명 문자열 어디에도 대응이 없다** — `500c-sn-fw`·`sonex-framework`·`sonex-app` 어느 쪽 모델 목록에도 없는 **네 번째 UDL 타입**이다. 미출시 SKU 코드 잔존인지, 다른 라인 재사용인지 미확인.

## 6. 확인이 필요한 항목

| 항목 | 현재 상태 |
|---|---|
| MCU 정확한 파트넘버·패키지 | `.ewp` 에 `Default None` — 코드만으론 특정 불가 |
| 보드 리비전 세부(ES1/ES2 등) | `USE_CUSTOM_BOARD` 플래그만 확인, 리비전 값은 미확인 |
| UDL 제어 경로 — SPI vs 메모리버스(`0x41000000`) | 역할 분담 미확인. RTL 추가 정독 필요 |
| 앱 A/B 슬롯(`UPD_DATA_0`/`_1`)이 belle 처럼 진짜 롤백 구조인지 | 부트로더의 슬롯 선택 코드를 찾지 못함 — 다운로드 후 재기록 방식일 수도 있음 |
| MCU 내장 DAC 의 정확한 용도 | 초기화 호출만 확인. 펄서·TGC 관련 추정만 있음 |
| USB 컨트롤러 용도 | 공장 프로그래밍/디버그 추정, 확정 아님 |
| `HF_LNR` UDL 타입에 대응하는 실제 제품 | 미확인 — 4종 중 3종만 제품명과 매칭됨 |
| 500C·500P·500LS 가 정말 별개 기구물(밀봉 핸드헬드)인지 | 프로브 자동인식 회로 부재라는 정황증거뿐. 매뉴얼·사진 등 별도 확인 필요 |
| 회로도·BOM | 없음 — 위 전부 소프트웨어·합성 산출물에서 역산 |

## 7. 조사 함정 — `master` 브랜치

`500c-sn-fw` 의 `master` 는 **커밋 3개짜리 초기 스텁**이고 이 문서가 다룬 내용(UDL 3-SKU 분기, ABLIC WiFi 전환 등) 이전 상태다. 이 저장소를 검색할 때는 반드시 라이브 브랜치(`origin/FW_1_1_4_0`~`origin/FW_1_1_8_0`)를 대상으로 해야 한다 — 상세 = [500c-firmware.md](500c-firmware.md) 상단 콜아웃.
