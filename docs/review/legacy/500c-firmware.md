# [범위 밖] 500C 펌웨어 (`500c-sn-fw`)

> **범위 판단**: **belle 과 호환되지 않으므로 검토 범위 밖**이다. Socionext ARM Cortex-M **베어메탈**이고 belle(ZynqMP + Linux)과 코드·빌드·아키텍처를 전혀 공유하지 않는다.
> **단, 단종은 아니다** — `origin/FW_1_1_8_0` 최종 커밋 2026-04-24 로 현재 개발 중이다. 범위에 다시 넣을지는 별도 판단 사항이다.
> **근거**: `origin/FW_1_1_8_0` 코드 직접 읽기(2026-07-27).

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

> 범위 포함 여부는 미결이다. "belle 만" 을 문자 그대로 적용하면 제외되고, "단종 모델 제외" 원칙을 적용하면 현행 제품이라 포함된다.


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
