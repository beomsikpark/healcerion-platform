# [축별 분리] 500C 펌웨어 (`500c-sn-fw`)

> **범위 판단 (2026-07-29 갱신) — 축마다 다르다.**
>
> | 축 | 판정 | 이유 |
> |---|---|---|
> | **장비 펌웨어 리팩토링** | **범위 밖 유지** | Socionext ARM Cortex-M **베어메탈**이고 belle(ZynqMP + Linux)과 코드·빌드·아키텍처를 전혀 공유하지 않는다. [r2](../../refactoring/r2/plan.md)(Buildroot·Linux 전제)가 그대로 적용되지 않아 **별도 트랙이 필요하다** |
> | **클라이언트 축 판단 근거** | **범위 안 — 한정 조사 1건** | `500C`·`500P` 흡수 가능성이 **`sonex-app` 존폐의 유일한 결정 인자**다([../../refactoring/moana-vs-sonex.md §3.1](../../refactoring/moana-vs-sonex.md)). [r1 Phase 10](../../refactoring/r1/phase10-runtime-variant.md) §4.4 의 판정이 이미 여기에 걸려 있다 |
>
> **초판의 "단종" 전제는 철회됐다** — `origin/FW_1_1_8_0` 최종 2026-04-24, Rev1.7 하드웨어·ABLIC WiFi SDK 전환 진행 중이고 `sonex-framework` 가 2026-07-23 에 펌웨어 굽기를 실장비 검증했다.
>
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

> **범위는 축별로 갈렸다**(상단 표). "belle 만" 을 문자 그대로 적용하면 펌웨어 축에서 제외되고, **"단종 모델 제외" 원칙은 더 이상 적용되지 않는다** — 현행 제품이다.

### 1.1 클라이언트 축에서 답해야 할 것 — 한정 조사

**`moana` 에 500C·500P 지원이 이미 있다 — 미병합 브랜치 `origin/sonon_500c` 에.**

| 실측 | 값 |
|---|---|
| 규모 | **71커밋 / 113파일 / +14,946줄**(출하 계통 `service_QT693` 대비), 최종 **2023-09-19** |
| 모델 등록 | **500C·500P 둘 다** — `Model.cpp` 에 `MODEL_500C` 18곳·`MODEL_500P` 18곳, `InitCapabilityTable_500C`·`_500P` 각각 보유 |
| `Model.cpp` diff | **437줄** |
| 커밋 성격 | *"500C audio sync with PRF"* · *"PW spectrum pre image processing"* · *"M mode crash fix"* · *"fix sweep speed"* — 실기능 |

**조사 항목은 하나다 — `Model.cpp` diff 437줄이 데이터인가 로직인가.**

| 답 | 함의 |
|---|---|
| **데이터**(파라미터 표·capability 플래그) | [Phase 10](../../refactoring/r1/phase10-runtime-variant.md) 이후 흡수가 성립한다 → **`sonex-app` 을 접을 수 있다** |
| **로직**(스캔 시퀀스·빔포밍 분기) | 흡수가 데이터 1건으로 끝나지 않는다 → `sonex-app` 존치 근거가 남는다 |

> **그리고 이것과 별개로 힐세리온에 물어야 할 것이 있다 — 왜 500C 지원이 `moana` 브랜치에서 멈추고 `sonex` 로 넘어갔는가.** 의도적 전략이었다면 `sonex-app` 에 우리가 모르는 위임이 있는 것이고, 표류였다면 [../change-cost.md](../change-cost.md) 논지의 가장 큰 표본이다. **판단이 갈린다.**


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
