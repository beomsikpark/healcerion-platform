# Phase 2 — 커널 모듈 3종 패키지화

> **상태**: 미시작
> **범위**: `plif`·`zynqdma`·`msp430_drv` — Makefile 이 없는 커널 모듈 3종을 Buildroot 코어 `kernel-module` 인프라 패키지로.
> **선행**: [Phase 1](./phase1-kernel-uboot-pin.md) — 커널이 핀 고정돼야 `$(LINUX_DIR)` 이 안정적이다.
> **병렬**: [Phase 3](./phase3-vendor-and-devicetree.md)
> **후행**: [Phase 4](./phase4-belle-fw-app-package.md)

---

## 1. 배경

### 1.1 이미 거의 완성된 Makefile 이 있다

`modules/plif/readme.makefile`(belle-fw) 전문:

```make
XILINX_KERNEL_DIR ?= /home/jacob/BELLE_WORK/belle-kernel/linux-xlnx/
ARCH ?= arm64
CROSS_COMPILE ?= aarch64-linux-gnu-
ccflags-y += -I${src}/include -DMY_SPECIAL_MACRO_NAME=1
plif-driver-objs := plif.o plif_dma.o
obj-m += plif-driver.o
all:
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(PWD) -C $(XILINX_KERNEL_DIR) modules
```

**이것은 이미 완전한 Kbuild `obj-m` 파일이다.** `readme.` 접두어 때문에 CMake 가 인식하지 못했을 뿐, 내용은 그대로 쓸 수 있다.

이 phase 의 실체는 새로 작성이 아니라 **①파일명에서 `readme.` 를 떼고 ②`XILINX_KERNEL_DIR` 을 Buildroot 의 `$(LINUX_DIR)` 로 바꾸고 ③Buildroot `kernel-module` 인프라로 감싸는 것**이다.

### 1.2 cctv 에는 이 패턴이 없다 — Buildroot 코어 기능을 직접 쓴다

cctv `directory-structure.md` §"Kernel Module Organization": *"Modules built and packaged via `*-ko/` packages... Binaries staged in `board/<board>/overlay/config/modules/`"* — 이것은 **벤더가 이미 컴파일해 준 `.ko` 를 담는** 패턴이다(SoC 벤더 SDK 배포 관행).

**belle 은 반대다** — 소스가 저장소에 있고 Makefile 만 없다. 이 경우 Buildroot 코어가 제공하는 `package/pkg-kernel-module.mk`(`$(eval $(kernel-module))`)를 **직접** 쓰는 것이 정공법이고, cctv 사례를 참고할 필요조차 없다 — Buildroot 표준 기능이다.

### 1.3 3개 모듈의 성격

| 모듈 | 소스 | LOC | 역할 |
|---|---|---:|---|
| `plif` | `plif.c`+`plif_dma.c`+헤더 | 3,562+1,450 | **PL-PS 인터페이스** — FPGA(PL)와 프로세서(PS) 간 저수준 통신. `sonon` 이 스캔 데이터를 받는 경로의 커널 측 절반 |
| `zynqdma` | `dmaengine.c`+`zynqmp_dma.c` | 1,298+1,286 | DMA 엔진 드라이버. **`zynqmp_dma.c.org` 사본이 함께 있다** |
| `msp430_drv` | `msp430_driver.c`+`.h` | (소형) | **호스트(ZynqMP) 측 I2C 드라이버** — MSP430 감시 MCU 에게 말을 거는 쪽. **`belle-msp`(별도 저장소, TI CCS 로 짜는 MSP430 자체 펌웨어)와는 다른 것** |

### 1.4 `zynqmp_dma.c.org` — 위생 이슈

파일명의 `.org` 는 보통 "원본 백업" 관례다. **어느 것이 실제로 컴파일 대상인지 먼저 확인**해야 한다 — [r2 Phase 0](../r2/phase0-hygiene-protocol-sot.md)의 `strtk.hpp` 이중 사본과 같은 종류의 문제다.

### 1.5 목적

1. `plif`·`zynqdma`·`msp430_drv` 를 Buildroot `kernel-module` 패키지로
2. `zynqmp_dma.c.org` 사본 정리
3. belle-fw(사용자공간)가 이 모듈들의 캐릭터 디바이스/ioctl 인터페이스에 의존하는 지점 확인([r2 Phase 3](../r2/phase3-platform-hal.md)의 HAL 설계와 연결)

### 1.6 범위 한계

- **드라이버 로직을 수정하지 않는다.** 빌드 방식만 바꾼다
- `belle-msp`(MSP430 자체 펌웨어) 는 범위 밖 — 별도 툴체인(TI CCS)

---

## 2. 진행 단계

### Step 2-A. `zynqmp_dma.c.org` 정리

| # | 작업 |
|---|---|
| A-1 | `zynqmp_dma.c` vs `.org` diff — 실제 빌드에 쓰이는 쪽 확인(현재 CMake/셸 스크립트에서 어느 것을 참조하는지) |
| A-2 | 다르면 **왜 다른지** 기록(패치 흔적인지, 실수로 남은 백업인지). 같으면 `.org` 삭제 |

### Step 2-B. `plif` 패키지

Buildroot `kernel-module` 인프라 사용:

```make
################################################################################
#
# plif-driver
#
################################################################################

PLIF_DRIVER_VERSION = <belle-fw 핀 SHA>
PLIF_DRIVER_SITE = $(BR2_EXTERNAL_HEALCERION_PATH)/../belle-fw/modules/plif
PLIF_DRIVER_SITE_METHOD = local

define PLIF_DRIVER_BUILD_CMDS
	$(MAKE) $(LINUX_MAKE_FLAGS) -C $(LINUX_DIR) M=$(@D) modules
endef

define PLIF_DRIVER_INSTALL_TARGET_CMDS
	$(MAKE) $(LINUX_MAKE_FLAGS) -C $(LINUX_DIR) M=$(@D) \
		INSTALL_MOD_PATH=$(TARGET_DIR) modules_install
endef

$(eval $(kernel-module))
$(eval $(generic-package))
```

| # | 작업 |
|---|---|
| B-1 | `readme.makefile` 의 `ccflags-y`(`-DMY_SPECIAL_MACRO_NAME=1` 등 belle 고유 플래그) 를 패키지 `.mk` 로 이전 |
| B-2 | `plif-driver-objs := plif.o plif_dma.o` 를 위한 로컬 `Makefile`(Kbuild) 을 `modules/plif/Makefile` 로 정식 등록(지금은 `readme.makefile`) |
| B-3 | `SITE_METHOD` — **belle-fw 저장소 안의 서브디렉토리**이므로 `local`(현재 checkout) 또는 [Phase 4](./phase4-belle-fw-app-package.md)의 belle-fw 패키지가 git 핀하는 것과 **동일 SHA 를 참조**하도록 설계(중복 소스 관리 방지) |

> **B-3 이 이 phase 와 [Phase 4](./phase4-belle-fw-app-package.md)의 접점이다.** 커널 모듈 소스가 `belle-fw` 저장소 안에 있으므로, 커널 모듈 패키지와 belle-fw 앱 패키지가 **같은 소스 트리를 참조**해야 버전이 갈라지지 않는다. cctv 의 `IPC_APP_GIT_SUBMODULES=YES` 처럼 하나의 pin 이 전체를 결정하게 설계한다.

### Step 2-C. `zynqdma` 패키지

같은 패턴. `dmaengine.c`+`zynqmp_dma.c`(2-A 에서 정리된 쪽).

### Step 2-D. `msp430_drv` 패키지

같은 패턴. **`belle-msp` 저장소와 이름이 유사해 혼동 소지** — 패키지명을 `msp430-i2c-driver` 등으로 명확히 구분.

### Step 2-E. Config.in 등록

`buildroot-healcerion/Config.in` 에 3개 패키지 추가([Phase 0](./phase0-external-tree-skeleton.md)의 골격에 편입).

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 사본 정리 | `find . -name '*.c.org'` | 0건 |
| 3.2 | 모듈 빌드 | `make plif-driver zynqdma-driver msp430-i2c-driver` | `.ko` 3개 생성 |
| 3.3 | 로드 | 실장비에서 `insmod`/`modprobe` | 정상 로드, dmesg 에러 없음 |
| 3.4 | belle-fw 연동 | `sonon` 기동 후 `plif` 캐릭터 디바이스 접근 | 정상 |
| 3.5 | 절대경로 제거 | `grep -rn 'XILINX_KERNEL_DIR\|/home/jacob'` | 0건 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`zynqmp_dma.c.org` 가 실제로 다른 버전**(패치 미적용) | 잘못된 쪽을 빌드하면 DMA 회귀 | A-1 필수. 애매하면 실장비 DMA 동작 테스트로 최종 판정 |
| 커널 헤더 버전 불일치(모듈 vs 커널) | 로드 실패(`disagrees about version`) | [Phase 1](./phase1-kernel-uboot-pin.md)에서 커널을 먼저 핀 고정했으므로 이 phase 시점엔 안정적이어야 함. 착수 시 재확인 |
| belle-fw 소스 참조 방식(B-3)이 순환 의존을 만든다 | 빌드 순서 꼬임 | 커널 모듈은 **모듈 소스 서브디렉토리만** 참조하고 belle-fw 전체를 당기지 않는다 |

---

## 5. cross-reference

- [plan.md §1.4·§2.3](./plan.md)
- [assessment.md §1.3](../legacy/assessment.md) — "커널 모듈 3종에 Makefile 없음" 문제의 원 지적
- [phase4-belle-fw-app-package.md](./phase4-belle-fw-app-package.md) — 소스 참조 방식 접점
- [../r2/phase3-platform-hal.md](../r2/phase3-platform-hal.md) — `plif` 등이 belle-fw HAL 설계와 만나는 지점
