# Phase 3 — `platforms/hal` — vtable 승격

> **상태**: 미시작
> **범위**: `lib/fpga.cpp` 의 함수 포인터 vtable 을 HAL 인터페이스로 승격. `lib/` 전체를 `platforms/zynqmp` 로. HAL 우회 23파일 정리. 런타임 선택 경로 추가.
> **선행**: [Phase 2](./phase2-layer-skeleton.md)
> **후행**: [Phase 4](./phase4-platform-pc-emulator.md) — 이 phase 가 만든 인터페이스에 PC 구현이 붙는다.
> **구조 정본**: ipc-app **ADR-004** — `cctv/device/ipc-app/docs/adr/adr-004-platform-hal-layered-structure.md`

---

## 1. 배경

### 1.1 새 설계가 아니라 있는 것의 승격이다

```c
// lib/fpga_define.h:24-25
#define DEVICE_EBI      (1)
#define DEVICE_DUMMY    (2)

// lib/fpga.cpp:21
RET fpga_init(Handle *handle, int device_type, int subtype)
{
    switch (device_type) {
    case DEVICE_EBI:
        handle->init = ebi_init;
        handle->open = ebi_open;
        ...
        handle->read_reg_32 = ebi_read_reg_32;   // DUMMY 에 없음
        handle->write_reg_32 = ebi_write_reg_32; // DUMMY 에 없음
        handle->mmap = ebi_mmap;                 // DUMMY 에 없음
        break;
    case DEVICE_DUMMY:
        handle->init = dummy_init;
        ...
        break;
    }
}
```

**이것이 이미 ipc-app `platforms/hal/i_*.h` + Platform Adapter 구조의 원시 형태다.** `Handle` 구조체의 함수 포인터 묶음이 인터페이스이고, `ebi_*`/`dummy_*` 가 두 구현체다.

### 1.2 그런데 인터페이스가 아니라 구조체 필드다

C 함수 포인터라 컴파일러가 계약을 강제하지 않는다 — `DEVICE_DUMMY` 분기는 `read_reg_32`·`write_reg_32`·`mmap` 을 **세우지 않고 넘어간다.** 호출하면 널 포인터다. C++ 순가상함수였다면 컴파일 에러였을 것을 런타임 크래시로 미룬 것이다.

### 1.3 우회가 많다 — HAL 이 규약이 아니라 선택지다

| 우회 | 위치 |
|---|---|
| `/dev/i2c-*` 직접 open + `ioctl` | `deviced/deviced.cpp` |
| `open("/dev/mem")` 독자 mmap | `tools/spidev.cpp` |
| MAX1720x 퓨얼게이지 재구현 | `tools/max17205.cpp` |

**`tools/` 아래 23개 파일이 독자적으로 `ioctl()`/`open("/dev...")` 를 호출한다**([device-firmware.md §6.4](../../review/device-firmware.md)).

### 1.4 `lib/` 규모

| 파일 | LOC | 역할 |
|---|---:|---|
| `fpga_ebi_control.cpp` | 4,225 | EBI 레지스터 제어 |
| `fpga_ebi.cpp` | 3,126 | EBI 버스 |
| `fpga_pw.cpp` | 1,672 | PW FPGA 명령 |
| `cf-doppler.c` | 1,585 | **CF 신호처리**(NEON) |
| `fpga_sequence.cpp` | 1,347 | 스캔 시퀀싱 |
| `fpga_doppler.cpp` | 879 | 도플러 FPGA 명령 |
| `event.cpp` | 814 | 이벤트 플래그(`EVENT_DATA_SCAN_MODE_CHANGE` 포함) |
| `common.cpp` | 633 | 공통 유틸 |
| `afe.cpp` | 603 | AFE(아날로그 프론트엔드) |
| `pulser.cpp` | 512 | 펄서 |
| `bufdev.cpp` | 510 | 버퍼 디바이스 |
| `fpga_dummy.cpp` | **117** | PC 경로(§1.1) |

**`fpga_ebi*` 계열(EBI 레지스터 제어)만 7,351 LOC 다.** 신호처리(`cf-doppler.c`)와 하드웨어 접근이 같은 `lib/` 안에 섞여 있다 — Phase 7 이 신호처리를 feature 로 뺄 때 이 phase 의 분리가 전제가 된다.

### 1.5 목적

1. HAL 인터페이스 확립 — `i_fpga_port.h` 외 8종
2. `lib/` 를 `platforms/zynqmp/` 로 (신호처리 제외 — §2.2)
3. HAL 우회 23파일 정리
4. **런타임 선택 경로** — `DEVICE_EBI` 하드코딩 제거

### 1.6 범위 한계

- **`cf-doppler.c` 등 신호처리는 여기서 옮기지 않는다.** `lib/` 안에 있지만 하드웨어 접근이 아니라 계산이므로 [Phase 7](./phase7-feature-scan-split.md) 의 `features/doppler-cf` 로 간다. 이 phase 는 **하드웨어 접근 부분만** 다룬다
- PC 구현은 [Phase 4](./phase4-platform-pc-emulator.md)

---

## 2. 목표 배치

```
src/platforms/
  hal/
    i_fpga_port.h          init/open/close/prepare_scan/read_frame/
                           read_reg/write_reg/read_reg_32/write_reg_32/mmap/
                           read_config/write_config/control   ← C++ 순가상함수로
    i_afe_port.h
    i_pulser_port.h
    i_buffer_port.h
    i_clock_port.h
    i_i2c_port.h
    i_gpio_port.h
    i_msp430_port.h
    i_config_store_port.h
  common/                  ← 여러 플랫폼이 공유하는 어댑터 코드
  zynqmp/
    fpga_ebi_adapter.{h,cpp}      (fpga_ebi.cpp 3,126 + control 4,225)
    afe_adapter.{h,cpp}           (afe.cpp)
    pulser_adapter.{h,cpp}        (pulser.cpp)
    buffer_adapter.{h,cpp}        (bufdev.cpp)
    i2c_adapter.{h,cpp}           (deviced 의 i2c open 이동)
    gpio_adapter.{h,cpp}          (gpio/)
  pc/                      ← Phase 4
```

### 2.1 §2.3(plan.md) HAL 매핑 재확인

| HAL 인터페이스 | 현행 | LOC |
|---|---|---:|
| `i_fpga_port.h` | `lib/fpga.cpp` vtable | 13함수 |
| `i_afe_port.h` | `lib/afe.cpp` | 603 |
| `i_pulser_port.h` | `lib/pulser.cpp` | 512 |
| `i_buffer_port.h` | `lib/bufdev.cpp` | 510 |
| `i_clock_port.h` | `lib/clock.cpp` | — |
| `i_i2c_port.h` | `deviced` 직접 open + `tools/` 23파일 | — |
| `i_gpio_port.h` | `gpio/` | 456 |
| `i_msp430_port.h` | `modules/msp430_drv` | — |
| `i_config_store_port.h` | `bcd/` | 3,324 (→ 실제로는 [Phase 6](./phase6-feature-config-power-diagnostics.md) feature 로 갈 가능성. 착수 시 판단) |

> **`i_config_store_port` 는 HAL 이 아닐 수 있다.** `bcd` 는 하드웨어 접근이 아니라 설정 브로커다. **착수 시 이것이 HAL 인지 feature 인지 재확인** — 애매하면 이 phase 에서는 건드리지 않고 [Phase 6](./phase6-feature-config-power-diagnostics.md) 로 넘긴다.

### 2.2 신호처리와 하드웨어 접근의 경계

| 파일 | 성격 | 목표 |
|---|---|---|
| `fpga_ebi.cpp`·`fpga_ebi_control.cpp` | 레지스터 read/write | `platforms/zynqmp` |
| `fpga_pw.cpp`·`fpga_doppler.cpp` | **FPGA 레지스터 설정값 계산 + 쓰기가 섞여 있다** | **분리 필요** — 계산은 [Phase 7](./phase7-feature-scan-split.md) feature `domain`, 레지스터 쓰기는 `platforms/zynqmp` |
| `cf-doppler.c` | 순수 신호처리(NEON) | [Phase 7](./phase7-feature-scan-split.md) `features/doppler-cf/domain` |
| `event.cpp` | 이벤트 플래그 | [Phase 5](./phase5-core-layer.md) `core/event` |
| `common.cpp` | 유틸 | [Phase 5](./phase5-core-layer.md) `core/util` |

**`fpga_pw.cpp`(1,672)·`fpga_doppler.cpp`(879) 가 이 phase 와 Phase 7 양쪽에 걸린다.** 이 phase 에서는 **레지스터 접근 부분만** 인터페이스 뒤로 넣고, 계산 로직 분리는 Phase 7 로 넘긴다 — 한 번에 다 하지 않는다.

---

## 3. 진행 단계

### Step 3-A. `i_fpga_port.h` 설계

| # | 작업 |
|---|---|
| A-1 | `Handle` 구조체의 13개 함수 포인터를 C++ 순가상함수 인터페이스로. **컴파일러가 구현 누락을 강제**하게 — DUMMY 가 3개를 안 세우던 문제(§1.2)가 여기서 근본 해결 |
| A-2 | `EBI`/`DUMMY` → `Zynqmp`/`Pc` 구현 클래스로 |
| A-3 | 기존 C 코드와의 브릿지 — 한 번에 C++ 화하지 않고, **얇은 C++ 래퍼가 기존 C 함수를 호출**하는 방식으로 시작(리스크 최소화) |

### Step 3-B. `platforms/zynqmp/` 이동

| # | 작업 |
|---|---|
| B-1 | `fpga_ebi.cpp`+`fpga_ebi_control.cpp`(7,351) → `platforms/zynqmp/fpga_ebi_adapter` |
| B-2 | `afe.cpp`·`pulser.cpp`·`bufdev.cpp`·`clock.cpp` 이동 |
| B-3 | `fpga_pw.cpp`·`fpga_doppler.cpp` — **레지스터 쓰기 부분만** 이동. 계산 부분은 원래 자리에 표시만 해 두고 [Phase 7](./phase7-feature-scan-split.md) 로 넘김 |
| B-4 | 각 이동마다 [Phase 1](./phase1-regression-baseline.md) 골든 + 실장비 빌드 확인 |

### Step 3-C. 나머지 HAL

§2.1 표의 `i_afe_port`~`i_gpio_port` 순서로. `i_config_store_port` 는 판단 보류(§2.1 주석).

### Step 3-D. HAL 우회 23파일 정리

| # | 작업 |
|---|---|
| D-1 | `tools/` 23파일 목록화 — 각각 어떤 HAL 로 흡수되는지 매핑 |
| D-2 | `deviced/deviced.cpp` 의 I2C 직접 open → `i_i2c_port` 경유 |
| D-3 | `tools/spidev.cpp` 의 `/dev/mem` 직접 mmap → `i_fpga_port` 또는 별도 `i_spi_port` |
| D-4 | `tools/max17205.cpp` 퓨얼게이지 재구현 — [Phase 6](./phase6-feature-config-power-diagnostics.md) `power-battery` feature 의 `data/` 로 흡수 예약(이 phase 에서는 HAL 경유로만) |
| D-5 | 나머지 19파일 — 진단·공장시험용이면 [Phase 6](./phase6-feature-config-power-diagnostics.md) `diagnostics` 로 이관 예약 |

> **23파일 전부를 이 phase 에서 끝내지 않는다.** HAL 경유로 바꾸는 것까지가 이 phase 고, 어느 feature 로 갈지는 대부분 Phase 6·7 에서 확정된다.

### Step 3-E. 런타임 선택 경로

```
sonon/sonon.cpp:3428   fpga_init(g_handle, DEVICE_EBI, DEVICE_SUB_PRESET1);  ← 상수
```

| # | 작업 |
|---|---|
| E-1 | 환경변수 또는 설정 파일로 `DEVICE_EBI`/`DEVICE_DUMMY` 선택 — `BELLE_PLATFORM=zynqmp\|pc` |
| E-2 | 선택 로직을 `app/bootstrap` 에 |
| E-3 | 기본값은 **`zynqmp`**(현행 동작 보존) — 이 phase 에서 기본 동작을 바꾸지 않는다 |

**이 phase 가 끝나면 `DEVICE_DUMMY` 를 고를 수 있게 되지만, DUMMY 구현 자체(램프 패턴)는 아직 그대로다** — 실제 에뮬레이터는 [Phase 4](./phase4-platform-pc-emulator.md).

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | HAL 인터페이스 존재 | `ls src/platforms/hal/i_*.h` | 9종 |
| 4.2 | 구현 강제 | `i_fpga_port` 미구현 함수 컴파일 | **에러**(순가상함수) |
| 4.3 | 계층 방향 | `platforms/** → features/**` include | 0건 |
| 4.4 | HAL 우회 감소 | `grep -rln 'open("/dev/\|ioctl(' src/features/ src/app/` | 감소 추세(0 은 Phase 6 이후) |
| 4.5 | 런타임 선택 | `BELLE_PLATFORM=pc` 설정 시 `DEVICE_DUMMY` 경로 진입 | 로그로 확인(동작은 Phase 4) |
| 4.6 | 실장비 빌드 | `make build TARGET=zynqmp` | exit 0 |
| 4.7 | **동작 불변** | `make test-golden` + 실장비 부팅·스캔 | 통과 |
| 4.8 | 계층 검사 | `make check-layers` | exit 0 |

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`fpga_pw`·`fpga_doppler` 의 계산/레지스터 분리가 예상보다 얽혀 있다** | Phase 3·7 경계가 흐려진다 | 착수 시 함수 단위로 분류표를 먼저 만든다. 애매한 함수는 **일단 `platforms/zynqmp` 에 두고** Phase 7 에서 재검토 |
| C→C++ 인터페이스 전환이 ABI/성능에 영향 | 실시간성 저하 | 3-A-3 의 **얇은 래퍼** 전략으로 최소화. 가상함수 오버헤드는 이 빈도(스캔 루프)에서 무시 가능한지 측정 |
| `i_config_store_port` 가 HAL 이 아니라 feature 로 판명 | 재배치 필요 | §2.1 주석대로 **판단 보류**가 기본. 되돌리기 쉽게 독립 모듈로 유지 |
| HAL 우회 23파일이 전부 이 phase 에서 안 끝난다 | 계획대로다 | D 표가 명시하듯 **일부는 Phase 6 이관 예약**. 위험이 아니라 설계 |
| 런타임 선택 추가가 기존 배포 스크립트를 깨뜨린다 | 배포 실패 | E-3 — 기본값을 `zynqmp` 로 고정해 **기존 무변경 배포와 동일 동작** 보장 |

---

## 6. cross-reference

- [plan.md §1.6·§2.3·§4](./plan.md)
- ipc-app **ADR-004**(HAL 3단계, 대안 비교) — `cctv/device/ipc-app/docs/adr/adr-004-platform-hal-layered-structure.md`
- [emulator-e2e.md §3](../legacy/emulator-e2e.md) — vtable 이 이미 있다는 실측의 원출처
- [phase4-platform-pc-emulator.md](./phase4-platform-pc-emulator.md) — 이 인터페이스에 PC 구현이 붙는다
- [phase7-feature-scan-split.md](./phase7-feature-scan-split.md) — `fpga_pw`·`fpga_doppler` 계산부의 최종 목적지
