# 장비 ↔ 앱 프로토콜 ("HC" 프로토콜)

> 클라이언트↔클라우드 프로토콜은 [protocol-cloud.md](protocol-cloud.md) 를 본다.

> **근거**: 원본 헤더 직접 읽기(2026-07-28) — `belle-fw` `origin/production-fw-ver2.0:sonon/sonon_receive.h` · `moana` `origin/service_QT693:framework/SononClient/SononPacket.h`.
> **범위**: belle(500L) 기준. 이전 세대·500C 의 차이는 표에 함께 적었다.
> **인용 원칙**: 이 문서의 상수·구조체는 전부 위 두 파일에서 직접 확인한 것이다.

## 0. 요약

TCP 2채널, 14바이트 고정 헤더, 16비트 opcode. **장비가 서버**다.

**리팩토링 관점의 핵심 문제 세 가지**

1. **정본 선언이 3벌** — 장비·앱·500C 가 각각 자기 헤더에 같은 구조체를 정의한다. 동기화 장치가 없다
2. **명명 규약이 장비와 앱에서 다르다** — 장비는 `READ/WRITE` 쌍(짝수/홀수), 앱은 쌍 중 하나만 이름 붙인다. 같은 값에 다른 이름이 붙어 있다
3. **CRC 가 없다** — 검증 함수 이름은 `verify_packet_header_and_crc` 인데 실제 검사 코드가 없다

## 1. 전송 계층

| 항목 | 값 | 출처 |
|---|---|---|
| 프로토콜 | TCP (`SOCK_STREAM`) | `belle-fw/sonon/sonon.cpp:2155,2250` · `moana/framework/SononClient/BaseSocket.cpp`(`QTcpSocket`) |
| 소켓 옵션 | **없음** — `sonon/` 에 `setsockopt` 0건. `TCP_NODELAY` 는 `lib/common.cpp:165` 의 별도 경로에만 있다 | 실측 |
| **제어 채널** | **1234** (`CTRL_PORT` / `SCAN_CTRL_PORT`) | 양쪽 동일 |
| **데이터 채널** | **1235** (`DATA_PORT` / `SCAN_DATA_PORT`) | 양쪽 동일 |
| 역할 | **장비가 서버**(listen/accept), 앱이 클라이언트 | `sonon.cpp` 의 `t_ctrl_message_from_client`·`t_data_message_to_client` |
| 주소 | 장비가 자체 AP, 고정 IP `192.168.10.1` | `moana/framework/Include/SononCommon.h` |
| 동시 접속 | 스레드-per-connection | `sonon.cpp` |

`500c-sn-fw`(범위 밖)는 여기에 **`1236`(aging 제어)** 를 추가했다.

## 2. 공통 헤더 — 14바이트

### 2.1 장비 측 선언 (`belle-fw/sonon/sonon_receive.h:2210`)

```c
struct __attribute__ ((packed)) PACKET_HEADER_S {
    U8  identifier[2];
    U8  version[2];
    U16 recv_id;
    U16 session_id;
    U16 packet_type;
    U32 packet_body_size;
};

struct __attribute__ ((packed)) PACKET_S {
    PACKET_HEADER_S header;
    PACKET_DATA_U   data;
};
```

### 2.2 앱 측 선언 (`moana/framework/SononClient/SononPacket.h`)

```c
typedef struct __common_packet_header {
    char identifier[2];
    char version[2];
    char recv_id[2];              // ← 장비는 U16, 앱은 char[2]
    unsigned short session_id;
    unsigned short packet_type;
    unsigned int packet_body_size;
    char packet_body[1];          // ← 앱만 가변 본문을 구조체에 포함
} __attribute__((packed)) COMMON_PACKET_HEADER;
// Windows 는 #pragma pack(push,1) 로 같은 정의를 중복 기술
```

### 2.3 두 선언의 차이

| 필드 | 오프셋 | 크기 | 장비(`PACKET_HEADER_S`) | 앱(`COMMON_PACKET_HEADER`) |
|---|---:|---:|---|---|
| `identifier` | 0 | 2 | `U8[2]` = `'H'`,`'C'` | `char[2]` |
| `version` | 2 | 2 | `U8[2]` | `char[2]` |
| `recv_id` | 4 | 2 | **`U16`** | **`char[2]`** |
| `session_id` | 6 | 2 | `U16` | `unsigned short` |
| `packet_type` | 8 | 2 | `U16` | `unsigned short` |
| `packet_body_size` | 10 | 4 | `U32` | `unsigned int` |
| — | 14 | — | 별도 `PACKET_S` 로 본문 결합 | `char packet_body[1]` 로 구조체에 포함 |

**바이트 배치는 동일**하고 크기 상수도 양쪽 14로 일치한다(`PACKET_HEADER_SIZE` / `COMMON_PACKET_HEADER_SIZE`). 배치 동일성은 이후 **컴파일 타임 단언으로 확정**했다([../refactoring/proof/protocol-sot/](../refactoring/proof/protocol-sot/)).

> **다만 `sizeof` 는 다르다** — 앱 구조체는 `char packet_body[1]` 을 품고 있어 15바이트다. 앱 코드가 `sizeof` 대신 상수 14를 쓰기 때문에 wire 호환이 유지된다.

### 2.3.1 `recv_id` — 타입 차이가 이미 결함을 만들었다

| | 모델 | 코드 |
|---|---|---|
| 장비 | `U16` | `sonon_receive.cpp:79` — `header->recv_id = HER_TARGET_ID_CLIENT;` (=`0x0002`) |
| 앱 | `char[2]` | `BasePacket.cpp:731` — `if (m_pkt_head->recv_id[1] == m_packet_hdr_info.target_id)` |

리틀엔디언에서 장비는 target 을 **바이트 0** 에 쓴다(`{0x02, 0x00}`). 앱은 **바이트 1** 을 본다. `target_id` 는 `0x0001`·`0x0002` 뿐이므로 **이 조건은 성립할 수 없다 — 도달 불가 코드다.**

실제 target 검증은 바로 위의 `memcmp(m_pkt_head, m_packet_hdr_info.context, 6)` 이 수행한다. `context[4] = target_id`·`context[5] = 0` 이라 이 6바이트 비교가 우연히 `recv_id` 를 덮는다(`BasePacket.cpp:628-633`).

**활성 버그가 아니라 잠복 결함이다.** 현재 동작은 맞고, memcmp 길이를 바꾸거나 필드를 재배치하면 target 검증이 조용히 사라진다. 실행 재현 = 실증 산출물의 `verify_layout.c`.

`identifier` 는 수신 시 검증된다 — `if (header->identifier[0] != 'H' || header->identifier[1] != 'C')`.

### 2.4 정본이 셋이다

| 코드베이스 | 선언 위치 | 타입명 |
|---|---|---|
| `belle-fw` (장비) | `sonon/sonon_receive.h:2210` | `PACKET_HEADER_S` |
| `moana` (앱, SOT) | `framework/SononClient/SononPacket.h` | `COMMON_PACKET_HEADER` |
| `500c-sn-fw` (범위 밖) | `src/App/include/USSCustomCommand.h` | `PACKET_HEADER_S` |

`cuattro-sdk` 는 `moana` 파일의 포크이고, `sonex-framework` 는 선언 없이 상수만 재정의(`HC_PACKET_HEADER_SIZE = 14`)한다. `ginny-fw`·`elsa-fw` 도 각자 갖고 있다.

## 3. 버전 필드가 모델 선택자다

`version[2]` 는 프로토콜 버전이 아니라 **제품 계열 태그**로 쓰인다.

| `version[0].version[1]` | 계열 |
|---|---|
| `0x00 0x01` | 300C |
| `0x00 0x02` | 300L |
| `0x00 0x03` | 300MC |
| **`0x01 0x00`** | **500 시리즈 (belle 포함)** |

**양쪽 다 컴파일 타임에 고정된다.**

```c
// belle-fw
#define HER_PROTOCOL_VER_MAJOR  0x01
#define HER_PROTOCOL_VER_MINOR  0x00

// moana
#if defined(HC_SONON_500L)
#define HC_HEADER_VER_MAJOR 1
#define HC_HEADER_VER_MINOR 0
#else
#define HC_HEADER_VER_MAJOR 0
#define HC_HEADER_VER_MINOR 1
#endif
```

→ **앱도 제품 계열별로 따로 빌드된다.** 하나의 앱 바이너리가 300 계열과 500 계열을 동시에 지원하지 않는다.

**기능 협상 장치가 없다.** 이 2바이트가 전부이고, 모델 세부 구분은 `DEVICE_READ_DEVICE_INFO` 응답의 모델명 문자열에 의존한다.

## 4. `packet_type` — 계열 구분

| 값 | 장비(`HER_PACKET_TYPE_*`) | 앱(`HC_PACKET_TYPE_*`) |
|---|---|---|
| `0x0001` | `DEVICE_COMM` | `DEVICE_COMM` |
| `0x0002` | `DEVICE_RESP` | `DEVICE_RESP` |
| `0x0003` | `FPGA_COMM` | `FPGA_COMM` |
| `0x0004` | `FPGA_RESP` | `FPGA_RESP` |
| `0x0005` | **`AGING_TEST_COMM`** | — (앱에 없음) |
| `0x0006` | **`AGING_TEST_RESP`** | — (앱에 없음) |
| `0x0100` | `B_ONLY_SCAN_DATA` | `SCAN_DATA` / `B_MODE` |
| `0x0101` | **`B_C_SCANLINE_DATA`**(스캔라인 단위) | — (앱에 없음) |
| `0x0102` | `B_C_FRAME_DATA`(프레임 단위) | `CF_MODE` |
| `0x0104` | `PW_FRAME_DATA` = `PW_AUDIO_FRAME_DATA` | `PW_MODE` |
| `0x0106` | `M_FRAME_DATA` | `M_MODE` |

**앱이 모르는 타입이 3개**(`0x0005`·`0x0006`·`0x0101`)다. 장비의 aging 시험 채널과 스캔라인 단위 전송은 앱 쪽에 대응 상수가 없다.

`0x0104` 는 장비 쪽에서 **같은 값에 이름이 둘**이다(`PW_FRAME_DATA`·`PW_AUDIO_FRAME_DATA`).

## 5. 스캔 데이터 부헤더 — 10바이트

데이터 채널은 공통 헤더 뒤에 부헤더가 붙는다(`moana` 선언).

```c
typedef struct __scan_data_packet {
    unsigned short frame_num;     // 0
    unsigned int   timestamp;     // 2
    unsigned short scanlines;     // 6
    unsigned short samples;       // 8
    char frame_data[FRAME_DATA_BODY_MAX_SIZE];   // 10
} __attribute__((packed)) SCAN_DATA_PACKET;
```

| 상수 | 값 |
|---|---|
| `SCAN_DATA_PACKET_HEADER_SIZE` | 10 |
| `FRAME_DATA_BODY_MAX_SIZE` | **262,144** (256 KiB) |
| `CTRL_PACKET_MAX_SIZE` | 14 + 1,024 |
| `RF_DATA_PACKET_MAX_SIZE` | 14 + 10 + 262,144 |

## 6. Opcode — 명명 규약이 갈렸다

**장비는 `READ`/`WRITE` 쌍을 각각 정의**한다(대체로 짝수=READ, 홀수=WRITE). **앱은 쌍 중 하나만 이름 붙인다.**

### 6.1 대응이 어긋나는 예

| 값 | `belle-fw` | `moana` |
|---|---|---|
| `0x0100` | `FPGA_READ_DEPTH` | — |
| `0x0101` | (WRITE) | **`FPGA_DEPTH`** |
| `0x0102` | `FPGA_READ_FOCAL_LENGTH` | — |
| `0x0103` | (WRITE) | **`FPGA_FOCAL`** |
| `0x0207` | `FPGA_READ_LINE_DENSITY` | — |
| `0x0208` | (WRITE) | **`FPGA_LINE_DENSITY`** |
| `0x0209` | `FPGA_READ_SCAN_SAMPLES` | — |
| `0x020A` | (WRITE) | **`FPGA_SAMPLE_512`** |
| `0x020B` | `FPGA_READ_C_MODE_GAIN` | — |
| `0x020C` | (WRITE) | **`FPGA_C_GAIN`** |
| `0x011B` | `FPGA_READ_B_OFFSET_GAIN_CTRL` | — |
| `0x011C` | (WRITE) | **`FPGA_B_GAIN`** |

즉 **앱의 상수는 대부분 WRITE 쪽이고 READ 쪽은 이름이 없다.** 앱이 READ 를 쓰려면 숫자를 직접 넣거나 다른 경로를 쓴다.

### 6.2 같은 값, 다른 이름

| 값 | `belle-fw` | `moana` |
|---|---|---|
| `0x0004` | `DEVICE_POWER_OFF` | `DEVICE_POWEROFF` |
| `0x0005` | `DEVICE_APP_SHUTDOWN` | `DEVICE_SHUTDOWN` |
| `0x00FF` | `DEVICE_EMERGENCY` | `DEVICE_EMR_EVENT` |
| `0x010A` | `FPGA_DBG_ADC_DUMP` | `FPGA_FULL_ADC_DUMP` |
| `0x0200` | `FPGA_COLOR_DOPPLER_CTRL` | `FPGA_DOPPLER_CTRL` |
| `0x0201` | `FPGA_READ_COLOR_DOPPLER_PARAM` | `FPGA_READ_DOPPLER_PARAM` |
| `0x0220` | `FPGA_READ_COLOR_DOPPLER_FILTER_SET` | `FPGA_READ_CF_FILTER_SETTING` |
| `0x0309` | `FPGA_READ_DP_FOCAL_LENGTH` | `FPGA_READ_DP_FOCAL` |

### 6.3 양쪽이 일치하는 것 — **15건뿐이다**

> **전수 기계 대조로 갱신했다**([../refactoring/proof/protocol-sot/](../refactoring/proof/protocol-sot/) `make report`). 아래 §6.1~6.2 는 손으로 고른 표본이라 규모를 과소평가했다.

`DEVICE_SCAN_READY 0x0001` · `DEVICE_SCAN 0x0002` · `DEVICE_KEEP_ALIVE 0x0003` · `DEVICE_FW_UPGRADE 0x0006` · `DEVICE_KEY_EVENT 0x0008` · `DEVICE_SPEC_INFO 0x2001` · `DEVICE_TIME_SYNC 0x2002` · `DEVICE_FW_UPGRADE_PROGRESS 0x2003` · `DEVICE_FW_UPGRADE_STATUS 0x2004` · `FPGA_RESET 0x0001` · `FPGA_PD_WRITE_PARAM 0x6001` · `PACKET_TYPE_DEVICE_COMM/RESP 0x0001/0x0002` · `PACKET_TYPE_FPGA_COMM/RESP 0x0003/0x0004`

> **정정**: 이전 판은 `FPGA_READ_PROBE_TYPE 0x0110` 을 일치 항목으로 적었으나 **앱은 `FPGA_PROBE_TYPE` 이다.** 명명 불일치 쪽에 속한다.

### 6.3.1 전수 대조 결과

`belle-fw` ∪ `moana` = **138개 값**(packet_type · DEVICE · FPGA · target_id).

| 분류 | 건수 |
|---|---:|
| 같은 값, 공유 이름 없음 | **41** |
| 이름까지 일치 | 15 |
| 장비만 선언 | 72 |
| 앱만 선언 | 8 |
| **같은 이름, 다른 값** | **0** |

마지막 줄이 통합 가능성을 결정한다 — 이름 충돌이 0 이므로 원본 철자를 전부 별칭으로 남기는 무손실 통합이 성립한다(실증 완료).

### 6.4 장비에만 있는 것 (앱에 대응 상수 없음)

`DEVICE_READ_BATTERY 0x0106` · `DEVICE_READ_TEMPERATURE 0x0107` · `DEVICE_READ_WIFI_MAC 0x0108` · `DEVICE_READ/WRITE_SETUP_INFO 0x000D/0x000E` · `DEVICE_READ/WRITE_DEVICE_NAME 0x0100/0x0101` · `DEVICE_WRITE_DEVICE_INFO 0x010B` · `DEVICE_READ/WRITE_ENCODE_IMAGE 0x0104/0x0105` · `DEVICE_READ/WRITE_DOPPLER_FF_ENABLE 0x0110/0x0111` · `DEVICE_EMERGENCY_SELF_TEST 0x1001` · `DEVICE_DBG_DEVICE_INFO 0x1002` · `FPGA_PRESET_REG 0x0005` · `FPGA_MEM_DUMP 0x0006` · `FPGA_LOAD_REG 0x0007` · `FPGA_READ_MAX2082_REG 0x0009` · `FPGA_LOAD_MAX2082_REG_LIST 0x000B` · `FPGA_LOAD_MAX2082_REG_FILE 0x000D` · `FPGA_DBG_CAPTURE_FRAME 0x1003` · `FPGA_DBG_ADC_DUMP_DATA 0x1004` · `FPGA_DEBUG_TEST 0xF7` · `FPGA_DBG_DOPPLER_COEF 0x0301` · `FPGA_READ_SA 0x0307` · `FPGA_READ_MANUAL_MODE 0x0121` · `FPGA_READ_MULTI_BLENDING 0x0127`

**디버그·공장시험·저수준 레지스터 접근이 프로토콜에 그대로 노출**돼 있다. `FPGA_LOAD_MAX2082_REG_FILE` 은 AFE 레지스터를 파일로 밀어 넣는 명령이다.

### 6.5 앱에만 있는 것

`DEVICE_WIFI_SETUP 0x0103`(장비는 `DEVICE_WRITE_WIFI_SETUP` 로 같은 값) · `DEVICE_FRAMERATE 0x010D`(장비는 WRITE) · `FPGA_MULTI_FOCAL 0x0126` · `FPGA_TGC 0x0118` · `FPGA_TX_FREQUENCY 0x0124` · `FPGA_DR 0x0109` · `FPGA_PRESET 0x0107` · `FPGA_PROBE_FLIP 0x010F` · `FPGA_B/CF/PW/M_PARAM 0x10~0x13` · `FPGA_READ/WRITE_PW_PARAM 0x4000/0x4001` · `FPGA_READ/WRITE_M_PARAM 0x5000/0x5001` · `INVALID_CMD_TYPE 0xFFFF`

### 6.6 앱 쪽 조건부 컴파일

`moana` 는 제품·기능별로 opcode 집합이 갈린다.

| 매크로 | 추가되는 것 |
|---|---|
| `HC_SONON_500L` | `DEVICE_FW_UPGRADE_PROGRESS/STATUS 0x2003/0x2004` · `FPGA_SA_MODE 0x0306` · `FPGA_READ/WRITE_DP_FOCAL 0x0309/0x0308` · `FPGA_READ/WRITE_CF_FILTER_SETTING 0x0220/0x0221` |
| `HC_SONON_500_SN` | `FPGA_WRITE_B_FUNC 0x1005` · `DEVICE_FW_UPGRADE_SN_START/WRITE/VERIFY/REBOOT 0x00F7~0x00FA` · `FPGA_SET/READY/GET_DEBUG_DUMP 0x0400~0x0402` |
| `HC_POWER_DOPPLER` | `FPGA_PD_WRITE_PARAM 0x6001` |

## 7. 신뢰성

| 항목 | 상태 |
|---|---|
| CRC·체크섬 | **없다.** 검증 함수명은 `verify_packet_header_and_crc` 이나 `//check CRC` 주석만 있고 검사 코드가 없다 |
| 검증 | `identifier` 2바이트 매직 + `version` 튜플 일치 여부뿐 |
| 재전송·순서 | 없음. TCP 에 의존 |
| 세션 | `session_id` 필드가 있으나 장비는 응답 시 요청값을 그대로 반사한다(`tx_header->session_id = rx_header->session_id`) |
| 타임아웃·keepalive | `DEVICE_KEEP_ALIVE 0x0003` 로 앱이 주기 전송 |

## 8. HLAB-2487 함의

| 관측 | 함의 |
|---|---|
| 정본 선언 3벌(§2.4) | **첫 리팩토링 대상.** 단일 헤더로 뽑아 장비·앱이 공유하면 위험 없이 즉시 효과 |
| 명명 규약 불일치(§6) | 같은 값에 다른 이름이라 **문서·검색·리뷰가 전부 어긋난다.** 통합 시 이름 정규화가 선행돼야 함 |
| 앱이 모르는 packet_type 3개(§4) | 장비 기능 일부가 앱에서 도달 불가. 의도인지 누락인지 확인 필요 |
| 앱이 READ 상수를 대부분 안 가짐(§6.1) | 조회 경로가 앱에서 이름 없이 쓰이거나 아예 안 쓰인다 |
| 버전 필드가 컴파일 타임 고정(§3) | **앱도 제품 계열별로 별도 빌드**된다. 변종 관리 문제가 장비뿐 아니라 앱에도 있다 |
| 디버그·레지스터 명령이 노출(§6.4) | 필드 장비에서 AFE 레지스터를 파일로 덮어쓸 수 있다. 보안·안전 검토 대상 |
| CRC 부재(§7) | 의료기기 통신에 무결성 검사가 없다. 규제 검토(판단 대기 5번)에서 지적될 여지 |
| 클라우드 스키마가 포트를 보유 | `sonex-cloud-backend` 의 디바이스 레코드에 `ctrl_port`·`data_port` 가 있다. **프로토콜 변경이 서버 스키마까지 파급**된다 |

## 9. 미확인

- `PACKET_DATA_U`(장비 측 본문 union)의 전체 구성 — 명령별 페이로드 레이아웃은 정리하지 않았다
- 엔디언 — 명시적 변환 코드가 **없다**(확인 완료). 양쪽 다 리틀엔디언 호스트라 성립하고 있을 뿐이다
- ~~`recv_id` 의 실제 용도~~ → §2.3.1 로 확정. 두 값(`0x0001`·`0x0002`)뿐이고, 앱의 검사는 도달 불가다
- 앱이 READ 계열 opcode 를 실제로 어떻게 호출하는지
- `0x0101`(스캔라인 단위 전송)이 belle 에서 실제로 쓰이는지
