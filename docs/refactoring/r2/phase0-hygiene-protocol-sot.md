# Phase 0 — 저장소 위생 · HC 프로토콜 정본

> **상태**: 미시작
> **범위**: 서드파티·생성물 분리, 죽은 코드 제거, HC 프로토콜 정본 도입. **구조를 바꾸지 않는다 — 옮길 대상을 줄인다.**
> **전제**: Buildroot([plan.md §0](./plan.md))
> **후행**: [Phase 1](./phase1-regression-baseline.md)

---

## 1. 배경

### 1.1 절반 이상이 자체 코드가 아니다

**251파일 193,087 LOC 중 104,167(54%)** 이 서드파티·생성물·데이터다.

| 항목 | LOC | 정체 |
|---|---:|---|
| `system_header/strtk.hpp` | 24,293 | **String Toolkit Library** (Arash Partow, 2002-2014) |
| `tools/strtk.hpp` | 24,293 | **같은 파일의 두 번째 사본** |
| `tools/psu_init.h` | 32,749 | Xilinx 생성 PSU 초기화 |
| `tools/read_ddrc.c` | 9,937 | Xilinx DDR 컨트롤러 덤프 |
| `image_proc/lut_header/*.h` | 9,262 | 생성된 LUT 테이블(`Rx_dly_LUT_delta` 4,114 · `Rx_apo_LUT` 4,114 · `dtgc_db_table` 806 · `Tx_dly_LUT_delta` 258) |
| `ne10_lib/` | 3,633 | ARM NE10 SIMD — **헤더 8개뿐**(라이브러리 본체 없음) |

**`strtk.hpp` 가 두 벌**이라는 것이 [principles.md §7](../legacy/principles.md)(정본은 하나) 위반이 서드파티에서도 일어났음을 보여준다.

이 54% 를 걷어내면 **Phase 2 이후가 다루는 대상이 88,920 LOC** 로 준다. 리팩토링 이전에 하는 이유가 그것이다.

### 1.2 죽은 것이 섞여 있다

| 대상 | 근거 |
|---|---|
| `configs/300l/` | 현재 컴파일 플래그 조합으로 **도달 불가능**([device-firmware.md §5](../../review/device-firmware.md)) |
| `_LINEAR_ARRAY` · `_MSPLIB_` | 루트 `CMakeLists.txt` 에 `add_definitions` 로 정의되는데 **소스에서 0회 참조** |
| `_USING_B_CONVEN_DEV_` | 주석 처리돼 `b_conventional.cpp`(671 LOC)가 **컴파일에서 빠진다** |
| `hcproc.img` | **2021-08 빌드 산출물 9.5MB 가 커밋돼 있다.** 산출물로 오인하면 5년 전 앱이 배포된다 |
| `modules/dmatest/` | `dma_testorg.c`(1,141) · `dma_old.c`(1,115) · `dmatest.c`(1,141) — **이름이 사본 관계를 시사** |

### 1.3 프로토콜 정본이 이미 만들어져 있다

`sonon/sonon_receive.h`(**2,227 LOC**)가 belle 측 자체 선언을 갖는다 — `PACKET_HEADER_S`, opcode **82개**(`DEVICE_*` 20 + `FPGA_*` 62), `HER_PACKET_TYPE_*`.

같은 구조체가 `moana`·`500c-sn-fw` 에도 각각 선언돼 **정본이 3벌**이다.

**그런데 통합 산출물이 이미 완성돼 있다** — [proof/protocol-sot/](../legacy/proof/protocol-sot/):

| | |
|---|---|
| 원본 3벌과 바이트 배치 | **동일** |
| 원본 철자 값 보존 | **198개** |
| 명명 불일치 | 41건 (**같은 이름·다른 값 0건** = 무손실 통합 가능) |
| 동작 보존 판정 | **컴파일러가 한다** (`make` 로 재현) |

**남은 것은 힐세리온 승인과 실제 적용뿐이다.**

### 1.4 목적

1. 옮길 대상을 **193,087 → 88,920 LOC** 로 줄인다
2. 프로토콜 선언을 **1벌**로 — 변경 1건이 7곳 → 1곳
3. 죽은 코드·산출물 제거로 이후 phase 의 오판 여지 제거

### 1.5 범위 한계

- **디렉토리 구조를 바꾸지 않는다.** 4계층 골격은 [Phase 2](./phase2-layer-skeleton.md)
- **프로토콜 동작을 바꾸지 않는다** — 선언만 교체. CRC 추가 같은 것은 앱과 동시 변경이라 여기서 하지 않는다(§2 Step 0-E)
- **`b_conventional.cpp` 를 되살리지 않는다** — 판단은 힐세리온

---

## 2. 진행 단계

### Step 0-A. `third_party/` 신설

```
third_party/
  strtk/          strtk.hpp  ← 1벌만 (24,293 LOC 절감)
  ne10/           헤더 8개
  xilinx/         psu_init.h · read_ddrc.c
```

| # | 작업 |
|---|---|
| A-1 | 두 `strtk.hpp` 가 **바이트 동일한지 확인**(md5). 다르면 어느 쪽이 쓰이는지부터 |
| A-2 | `third_party/strtk/` 로 1벌 이동, 나머지 삭제. include 경로 갱신 |
| A-3 | `ne10_lib/` → `third_party/ne10/`. **라이브러리 본체가 저장소에 없다** — Buildroot 가 조달하는지 확인 |
| A-4 | Xilinx 생성물 이동 + 생성 출처를 README 에 기록 |
| A-5 | `third_party/` 는 `make check-layers`([Phase 2-D](./phase2-layer-skeleton.md))의 예외로 등록 |

> **`ne10_lib` 가 헤더뿐인데 `sonon` 이 `NE10` 을 링크한다**([device-firmware.md §9](../../review/device-firmware.md)). Buildroot 전제라면 이 조달 경로가 이미 서 있어야 한다 — **A-3 이 그 전제의 검증을 겸한다.**

### Step 0-B. 데이터 분리

`image_proc/lut_header/` 9,262 LOC 는 **C 헤더 형태의 데이터**다.

| # | 작업 |
|---|---|
| B-1 | `data/lut/` 로 이동. 형식은 유지(헤더 그대로) |
| B-2 | **생성 스크립트 유무 확인** — 없으면 "생성물인데 생성 경로가 없다" 로 기록. `bf-delay-calculation` 저장소가 후보다 |
| B-3 | [Phase 9](./phase9-runtime-variant.md) 의 런타임 로드 후보로 표시 |

### Step 0-C. 죽은 것 제거

| # | 대상 | 처리 |
|---|---|---|
| C-1 | `hcproc.img`(9.5MB) | **삭제** + `.gitignore`. 빌드 산출물이다 |
| C-2 | `_LINEAR_ARRAY` · `_MSPLIB_` | `CMakeLists.txt` 에서 제거(0회 참조) |
| C-3 | `configs/300l/` | **보류.** [Phase 9](./phase9-runtime-variant.md) 에서 런타임 변종을 세울 때 되살아날 수 있다. 지금은 "도달 불가" 주석만 |
| C-4 | `modules/dmatest/` 사본 3벌 | **조사 후 판단** — `dma_testorg`·`dma_old` 가 사본이면 정리, 아니면 유지 |
| C-5 | `_USING_B_CONVEN_DEV_` | **유지.** 되살릴지 지울지는 힐세리온 |

> **C-1 이 중요하다.** [device-firmware.md §9](../../review/device-firmware.md) 가 "함정" 으로 명시한 항목이다 — 5년 전 앱이 배포될 수 있다.

### Step 0-D. HC 프로토콜 정본 도입

| # | 작업 |
|---|---|
| D-1 | [proof/protocol-sot/include/hc_protocol.h](../legacy/proof/protocol-sot/) 를 `src/core/protocol/` 자리에 배치(디렉토리는 Phase 2 에서 생기므로 임시로 `protocol/`) |
| D-2 | `sonon/sonon_receive.h`(2,227)에서 **프로토콜 선언 부분만** 정본 include 로 교체 |
| D-3 | **명명 불일치 41건** 적용 — 정본 이름으로 통일. 같은 이름·다른 값이 0건이므로 무손실 |
| D-4 | **컴파일러가 판정한다** — 바이트 배치가 같으므로 빌드 통과 = 레이아웃 보존 |
| D-5 | `verify_layout` · `compat_test` 를 belle 빌드에 편입 |
| D-6 | opcode 82개가 정본에 전부 있는지 대조. 없으면 정본에 추가 |

> **`sonon_receive.h` 는 2,227 LOC 인데 프로토콜 선언만 있는 것이 아니다** — 구조체·상수·함수 선언이 섞여 있다. D-2 는 **분리 작업**이고, 남는 부분은 Phase 2 이후 각 계층으로 간다.

### Step 0-E. CRC 부재 기록 — 고치지 않는다

`verify_packet_header_and_crc` 가 **이름과 달리 CRC 검사 코드를 갖지 않는다**([device-firmware.md §7](../../review/device-firmware.md)).

**여기서 고치지 않는다.** CRC 추가는 프로토콜 변경이라 앱(`moana`·`sonex`·`cuattro-sdk` 3벌)과 동시에 바꿔야 한다 — [principles.md §5](../legacy/principles.md)(축을 하나씩)에 걸린다.

**대신 기록한다** — 함수명이 거짓말을 하고 있으므로 주석이나 rename 으로 사실을 맞춘다. 이것은 동작 변경이 아니다.

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | strtk 단일화 | `find . -name strtk.hpp` | **1건** |
| 3.2 | 자체 코드 규모 | `src/` 밖으로 뺀 뒤 LOC | 193,087 → **약 88,920** |
| 3.3 | 산출물 미추적 | `git ls-files \| grep -E 'hcproc\.img\|\.ko$'` | 0건 |
| 3.4 | 죽은 매크로 | `grep -n '_LINEAR_ARRAY\|_MSPLIB_' CMakeLists.txt` | 0줄 |
| 3.5 | **프로토콜 정본** | `grep -rn 'PACKET_HEADER_S\|HER_PACKET_TYPE' --include='*.h' \| grep -v third_party` | **정본 1파일** |
| 3.6 | **레이아웃 보존** | `verify_layout` 실행 | 원본 3벌과 바이트 배치 동일 |
| 3.7 | opcode 전수 | 82개가 정본에 존재 | ✓ |
| 3.8 | **동작 불변** | 빌드 산출물 대조 (Phase 0 전후) | **바이너리 동일 또는 차이가 설명 가능** |
| 3.9 | 부팅 | 실장비 부팅 + 앱 접속 | 정상 |

> **3.8 이 이 phase 의 게이트다.** 파일을 옮기고 헤더를 바꿨는데 산출물이 달라졌다면 무언가 놓친 것이다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **두 `strtk.hpp` 가 실제로 다르다** | 한쪽을 지우면 동작이 바뀐다 | A-1 이 선행. 다르면 **diff 를 기록하고 둘 다 유지**한 채 진행 |
| `ne10_lib` 본체 조달 경로가 없다 | 링크 실패 | A-3 이 **Buildroot 전제의 검증**. 없으면 [assessment.md](../legacy/assessment.md) 로 돌아간다 |
| 프로토콜 명명 통일 41건이 앱을 깨뜨린다 | 통신 불가 | **선언만 바꾸고 값은 그대로**다(같은 이름·다른 값 0건). 3.6 이 게이트 |
| `sonon_receive.h` 분리가 광범위 | 컴파일 오류 다발 | D-2 를 **프로토콜 선언만** 으로 한정. 나머지는 Phase 2 |
| `configs/300l` 을 성급히 지운다 | Phase 9 에서 다시 필요 | C-3 — **보류**가 정답 |
| `hcproc.img` 삭제가 배포 스크립트를 깨뜨린다 | 릴리스 불가 | Buildroot 전제라면 이미 생성 경로가 있어야 한다. **없으면 전제 미달** |

---

## 5. cross-reference

- [plan.md §1.1·§4](./plan.md)
- [../proof/protocol-sot/](../legacy/proof/protocol-sot/) — Step 0-D 의 산출물. **이미 완성돼 있다**
- [../../review/device-firmware.md §5·§7·§9](../../review/device-firmware.md) — 죽은 코드·프로토콜·재현 불가 지점
- [principles.md §7](../legacy/principles.md) — 정본은 하나만 둔다
