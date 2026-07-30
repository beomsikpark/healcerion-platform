# Phase 1 — 커널·U-Boot git 핀 + FSBL→SPL 대체 + PMU 임베드

> **상태**: 미시작
> **범위**: `belle-kernel`·`belle-u-boot` 를 Buildroot custom git 패키지로. FSBL 미사용(U-Boot SPL 대체) 확정. PMU 프리빌트 ELF 임베드.
> **선행**: [Phase 0](./phase0-external-tree-skeleton.md)
> **후행**: [Phase 2](./phase2-kernel-module-packages.md) · [Phase 3](./phase3-vendor-and-devicetree.md)

---

## 1. 배경

### 1.1 커널·U-Boot 는 이미 별도 저장소다

| | 현행 | cctv 대응 |
|---|---|---|
| 커널 | `belle-kernel`(linux-xlnx 포크, `master` HEAD 2021-10-06) | `linux-cctv.git`(태그 핀) |
| U-Boot | `belle-u-boot`(`master` HEAD 2022-04-22) | `u-boot-cctv.git`(태그 핀) |

**배치가 이미 cctv 와 같다.** 지금 없는 것은 이것을 Buildroot 가 소비하는 방식(`BR2_LINUX_KERNEL_CUSTOM_GIT`)뿐이다 — 지금은 `belle-bsp` 의 `petalinuxbsp.conf` 가 절대경로로 이 둘을 가리킨다.

### 1.2 defconfig 는 이미 표준 이름이다

| | 파일 |
|---|---|
| 커널 | `belle-kernel/arch/arm64/configs/xilinx_zynqmp_defconfig` |
| U-Boot | `belle-u-boot/configs/xilinx_zynqmp_virt_defconfig` |

**Xilinx 표준 defconfig 이름**이라 Buildroot 의 `BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG`/커스텀 defconfig 경로 지정과 바로 맞는다.

### 1.3 FSBL 없이 부팅한다 — SPL 대체

[assessment.md §1.3](../legacy/assessment.md) 실측:

| 확인 | 위치 |
|---|---|
| `psu_init_gpl.c`(17,791줄, MIT, PS 초기화) | `belle-bsp/project-spec/hw-description/` |
| `CONFIG_SPL=y` + `SPL_LOAD_FIT` | `xilinx_zynqmp_virt_defconfig` |

**U-Boot SPL 이 FSBL 의 PS 초기화 역할을 대신할 수 있다.** ZynqMP 부트 시퀀스는 보통 `BOOT.BIN = FSBL + PMU FW + ATF + U-Boot` 인데, SPL 경로에서는 `BOOT.BIN = SPL(PS init 포함) + ATF + U-Boot proper` 로 재구성된다. **`psu_init_gpl.c` 를 SPL 빌드에 링크**하면 FSBL 저장소가 비어 있어도 부팅 가능하다.

### 1.4 PMU 는 프리빌트로 남는다

`belle-bsp/vivado-hw-xsa/es3-pmu-v00-01-00.elf` — PMU(Platform Management Unit) 펌웨어. Buildroot 는 `BR2_TARGET_UBOOT_ZYNQMP_PMUFW` 로 **외부 ELF 를 그대로 `BOOT.BIN` 에 임베드**하는 경로를 제공한다. 소스 재구성 없이 프리빌트를 쓰는 것이 [r2 plan.md §0](../r2/plan.md)의 전제("`.xsa` 재현은 하드웨어 변경 시에만 필요")와 일치한다.

### 1.5 목적

1. `belle-kernel`·`belle-u-boot` git SHA 핀
2. defconfig 이관
3. FSBL 미사용 · SPL + `psu_init_gpl.c` 경로 확정
4. PMU ELF 임베드

### 1.6 범위 한계

- **커널·U-Boot 소스 자체를 수정하지 않는다.** 있는 그대로 핀
- FSBL 소스 복구를 시도하지 않는다

---

## 2. 진행 단계

### Step 1-A. 커널 git 핀

buildroot-cctv `ipc-app.mk` 의 핀 정책을 그대로 따른다 — **git SHA 하드 핀, 브랜치명 금지**(다운로드 캐시 키가 VERSION 문자열이라 브랜치 핀은 첫 스냅샷에 고착).

```make
# Buildroot 코어 kernel 패키지 설정 (BR2_LINUX_KERNEL 하위)
BR2_LINUX_KERNEL_CUSTOM_GIT=y
BR2_LINUX_KERNEL_CUSTOM_REPO_URL="git@<host>:healcerion/belle-kernel.git"
BR2_LINUX_KERNEL_CUSTOM_REPO_VERSION="c73df942c"   # belle-kernel HEAD, 하드 핀
BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$(BR2_EXTERNAL_HEALCERION_PATH)/board/belle-500l/belle-500l_linux_defconfig"
```

| # | 작업 |
|---|---|
| A-1 | `xilinx_zynqmp_defconfig` 를 `board/belle-500l/belle-500l_linux_defconfig` 로 복사(필요 시 조정) |
| A-2 | 커널 SHA 를 defconfig 에 하드 핀. **핀 갱신 스크립트**(cctv `script/bump-pin.sh` 대응) 착수 시 작성 여부 판단 |

### Step 1-B. U-Boot git 핀

```make
BR2_TARGET_UBOOT_CUSTOM_GIT=y
BR2_TARGET_UBOOT_CUSTOM_REPO_URL="git@<host>:healcerion/belle-u-boot.git"
BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION="a0e86cfc"    # belle-u-boot HEAD
BR2_TARGET_UBOOT_USE_CUSTOM_CONFIG=y
BR2_TARGET_UBOOT_CUSTOM_CONFIG_FILE="$(BR2_EXTERNAL_HEALCERION_PATH)/board/belle-500l/belle-500l_uboot_defconfig"
BR2_TARGET_UBOOT_NEEDS_DTC=y
BR2_TARGET_UBOOT_SPL=y                              # FSBL 대체
```

| # | 작업 |
|---|---|
| B-1 | `xilinx_zynqmp_virt_defconfig` 이관 + `CONFIG_SPL=y` 실제 존재 재확인 |
| B-2 | U-Boot SHA 핀 |

### Step 1-C. FSBL 미사용 확정

| # | 작업 |
|---|---|
| C-1 | Buildroot ZynqMP 부트 흐름 문서화 — `BOOT.BIN = SPL(+psu_init_gpl) + ATF + PMU FW + U-Boot proper` |
| C-2 | `psu_init_gpl.c`+`.h` 를 U-Boot SPL 빌드 트리에 배치하는 경로 확정(U-Boot 소스 내 `board/xilinx/zynqmp/` 하위 오버레이 또는 별도 patch) |
| C-3 | **하드웨어 리비전 변경 시 재작업 필요함을 문서에 명시** — 이것이 [r2 plan.md §0](../r2/plan.md)의 "PL 재설계 시에만 `.xsa` 필요" 조건과 일치 |

### Step 1-D. PMU 임베드

```make
BR2_TARGET_UBOOT_ZYNQMP_PMUFW=y
BR2_TARGET_UBOOT_ZYNQMP_PMUFW_IMAGE="$(BR2_EXTERNAL_HEALCERION_PATH)/board/belle-500l/pmufw/es3-pmu-v00-01-00.elf"
```

| # | 작업 |
|---|---|
| D-1 | ELF 를 `board/belle-500l/pmufw/` 로 이관(원본은 belle-bsp 에 남기고 복사 또는 참조) |
| D-2 | `BOOT.BIN` 생성 시 PMU FW 포함 확인 |

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 커널 다운로드 | `make linux-source` | belle-kernel 핀 SHA 체크아웃 |
| 3.2 | U-Boot 다운로드 | `make uboot-source` | belle-u-boot 핀 SHA 체크아웃 |
| 3.3 | 커널 빌드 | `make linux-rebuild` | Image/커널 모듈 생성 |
| 3.4 | U-Boot + SPL 빌드 | `make uboot-rebuild` | `u-boot.itb`·SPL 바이너리 생성, FSBL 산출물 없음 |
| 3.5 | `BOOT.BIN` 조립 | `bootgen`(또는 Buildroot 후크) | SPL+ATF+PMU+U-Boot 포함, **FSBL 슬롯 없음** |
| 3.6 | 절대경로 제거 | `grep -rn '/home/jacob'` | 0건(이 phase 대상 파일 한정) |

> **3.5 가 이 phase 의 게이트다.** §1.3 의 SPL 대체는 실기 부팅으로 확정하며, 그 확인은 [Phase 5](./phase5-first-build-ci-sdk.md)에서 한다 — 필요해지는 시점에 하면 되는 통상적인 검증 단계다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| SPL 이 FSBL 을 완전히 대체 못 한다(예: 특정 PL 초기화가 FSBL 전용) | 부팅 실패 | [Phase 5](./phase5-first-build-ci-sdk.md) 부팅 테스트로 바로 드러난다. 대체 경로가 이미 있다 — FSBL 프리빌트 ELF(`es3-fsbl-v00-01-00.elf`)를 그대로 임베드(Buildroot 표준 지원 경로)하면 되므로 막다른 위험이 아니다 |
| Buildroot 버전과 belle-kernel(2021) 사이 툴체인 비호환 | 빌드 실패 | [Phase 0-A](./phase0-external-tree-skeleton.md)에서 버전 확정 시 함께 확인 |
| PMU ELF 가 현재 비트스트림과 안 맞음 | 전원 시퀀싱 오류 | [Phase 3-A](./phase3-vendor-and-devicetree.md) 비트스트림과 **동일 `.xsa` 세대**(`es3_v00.01.00`)에서 나온 것인지 확인 |

---

## 5. cross-reference

- [plan.md §1.2·§1.3·§2.3](./plan.md)
- [assessment.md §1.3](../legacy/assessment.md) — FSBL→SPL 대체 근거의 원출처
- buildroot-cctv `board/nt98566-ipc/doc/howto-buildroot.md` — custom git kernel/uboot 사용 예
- [phase3-vendor-and-devicetree.md](./phase3-vendor-and-devicetree.md) — 비트스트림·DTS
