# Phase 3 — 비트스트림 · `NE10` · 디바이스 트리

> **상태**: 미시작
> **범위**: PL 비트스트림을 `local` 벤더 패키지로. `NE10` 정체 확인 후 패키지화. `system-user.dtsi` 를 저장소 관리로.
> **선행**: [Phase 1](./phase1-kernel-uboot-pin.md)
> **병렬**: [Phase 2](./phase2-kernel-module-packages.md)
> **후행**: [Phase 4](./phase4-belle-fw-app-package.md)

---

## 1. 배경

### 1.1 비트스트림 — `.xsa` 없이 프리빌트로

[r2 plan.md §1.1](../r2/plan.md)·[assessment.md §1.3](../legacy/assessment.md) 실측: Vivado 원본(`.xsa`) 없이 기존 비트스트림을 그대로 패키징하면 빌드는 된다. **PL 재설계 시에만** 원본이 필요하다.

| 자산 | 위치 |
|---|---|
| 비트스트림 | `configs/500l/top_osc40_cmos_221018.bin`(belle-fw), IDCODE `0x04a42093` |
| `.xsa`(참고용, 재현 안 됨) | `belle-bsp/vivado-hw-xsa/es3_v00.01.00.xsa` |

**cctv `nt98566-sdk.mk` 가 정확히 이 패턴이다** — `SITE_METHOD = local`, prebuilt 를 `STAGING_DIR`/`TARGET_DIR` 에 그대로 복사, 빌드하지 않는다.

### 1.2 `NE10` — 정체가 아직 불확실하다

[r2 plan.md §1.1](../r2/plan.md): `ne10_lib/` 에 **헤더 8개뿐**인데 `sonon` 이 `NE10` 을 링크한다. ARM NE10 은 원래 **오픈소스**(`projectNe10/Ne10`, Apache/BSD 계열) 라이브러리다.

가능성 두 갈래:

| 가설 | 처리 |
|---|---|
| **A. 순정 upstream NE10** — PetaLinux sysroot 가 표준 빌드를 제공했다 | 표준 Buildroot 패키지로(upstream 소스 pin) — cctv 패턴과 무관, 일반 오픈소스 패키지 |
| **B. 벤더/사내 수정판** — 헤더만 저장소에 남고 `.a` 는 어딘가 prebuilt 로 존재 | cctv `nt98566-sdk.mk` 형(`local`, prebuilt) |

**착수 전 확인이 필수다.** 현재 belle-fw 빌드가 `NE10` 을 어디서 링크하는지(`.pro`/CMake 의 `LIBS`/`link_directories`) 를 먼저 읽는다.

### 1.3 디바이스 트리 — 이미 출발점이 있다

`belle-bsp/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi` — PetaLinux 의 `.xsa` 자동생성 DT 위에 얹는 사용자 오버레이. **`.xsa` 자동생성을 포기하는 순간 이 오버레이가 전체 DT 를 직접 기술해야 한다.**

### 1.4 목적

1. 비트스트림 local 패키지
2. `NE10` 실체 확인 후 적절한 패키지 방식 선택
3. 디바이스 트리를 `.xsa` 의존 없이 저장소에서 관리

### 1.5 범위 한계

- PL 설계·비트스트림 내용을 바꾸지 않는다
- `NE10` 라이브러리 자체 최적화·업그레이드는 하지 않는다(존재 확인과 재현 가능한 패키징까지만)

---

## 2. 진행 단계

### Step 3-A. 비트스트림 local 패키지

```make
XILINX_BITSTREAM_VERSION = 500l-221018
XILINX_BITSTREAM_SITE = $(BR2_EXTERNAL_HEALCERION_PATH)/package/soc/zynqmp/xilinx-bitstream
XILINX_BITSTREAM_SITE_METHOD = local
XILINX_BITSTREAM_INSTALL_TARGET = NO

define XILINX_BITSTREAM_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/top_osc40_cmos_221018.bin $(BINARIES_DIR)/bitstream.bin
endef

$(eval $(generic-package))
```

| # | 작업 |
|---|---|
| A-1 | `top_osc40_cmos_221018.bin` 을 `package/soc/zynqmp/xilinx-bitstream/` 로 복사(원본 belle-fw `configs/500l/` 도 유지 — [r2 Phase 9](../r2/phase9-runtime-variant.md)의 런타임 로드 대상과 겹치므로 완전 이관은 그 phase 이후 판단) |
| A-2 | IDCODE 검증 스크립트(있으면) 함께 포함 — belle-hardware.md 의 `0x04a42093` 대조 |
| A-3 | PL 로딩 방식 확인 — U-Boot 단계 로드인지 커널 FPGA manager 경유인지(`fpga_manager` 드라이버 유무 확인) |

### Step 3-B. `NE10` 정체 확인 → 패키지화

| # | 작업 |
|---|---|
| B-1 | belle-fw 빌드 스크립트에서 `NE10` 링크 경로 추적 — PetaLinux sysroot 내 실제 파일 위치 확인 |
| B-2 | 그 파일의 버전/커밋 확인 시도(가능하면 upstream `projectNe10/Ne10` 과 diff) |
| B-3 | **A(순정)면**: upstream 패키지로 — `NE10_SITE_METHOD = git`, upstream 저장소 pin |
| B-3' | **B(수정판)면**: cctv `nt98566-sdk.mk` 형 — `local`, `INSTALL_STAGING` |
| B-4 | 헤더 8개(`ne10_lib/`)와 실제 링크 라이브러리의 API 버전 일치 확인 |

> **B-1 이 막히면(sysroot 접근 불가) 임시로 소스 자체를 재빌드**하는 방안도 검토 — NE10 은 오픈소스이므로 최악의 경우 upstream 에서 새로 빌드해도 ABI 호환 가능성이 높다. 다만 [principles.md §3](../legacy/principles.md)(동작 보존)에 따라 **먼저 기존 산출물과 신 빌드의 신호처리 출력을 [r2 Phase 1](../r2/phase1-regression-baseline.md) 골든으로 대조**해야 한다.

### Step 3-C. 디바이스 트리 저장소 이관

| # | 작업 |
|---|---|
| C-1 | `system-user.dtsi`·`pl-custom.dtsi` 를 `board/belle-500l/dts/` 로 |
| C-2 | `.xsa` 자동생성에 의존하던 베이스 DT(클럭·메모리맵 등)를 **명시적으로 재구성** — Xilinx 표준 ZynqMP DT(`zynqmp.dtsi` 등, U-Boot/커널에 포함)를 베이스로 삼고 그 위에 `system-user.dtsi` 오버레이 |
| C-3 | Buildroot `BR2_LINUX_KERNEL_INTREE_DTS_NAME` 또는 커스텀 DTS 경로로 등록 |

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 비트스트림 배치 | `ls output/images/bitstream.bin` | 존재, IDCODE 일치 |
| 3.2 | NE10 정체 확정 | 문서에 A/B 판정 기록 | ✓ |
| 3.3 | NE10 링크 | `make plif-driver`(또는 belle-fw 빌드 시) | 링크 성공 |
| 3.4 | **NE10 동작 동등성**(B-4/재빌드 시) | [r2 Phase 1](../r2/phase1-regression-baseline.md) 골든(신호처리 함수) | 일치 |
| 3.5 | DT 컴파일 | `dtc` 로 최종 DTB 생성 | 에러 없음 |
| 3.6 | PL 로드 | 실장비 부팅 시 FPGA 초기화 | 정상, `dmesg` 확인 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **NE10 실체를 못 찾는다**(sysroot 접근 불가) | B-3/B-3' 판단 불가 | B-1 최우선 확인. 최악의 경우 upstream 새 빌드 + 3.4 골든 대조로 대체 |
| DT 재구성이 실제 하드웨어 초기화 순서를 놓친다 | 부팅 실패 또는 주변장치 미인식 | `.xsa` 원본(`es3_v00.01.00.xsa`)을 **참고 자료로 남겨두고**(재생성은 안 해도 열람은 가능) 대조하며 작성 |
| 비트스트림 로드 방식이 예상과 다르다(U-Boot vs 커널) | 3-A-3 재작업 | 현재 PetaLinux 부팅 로그에서 실제 로드 시점 확인 후 설계 |

---

## 5. cross-reference

- [plan.md §1.5·§2.3](./plan.md)
- [assessment.md §1.3](../legacy/assessment.md) — 비트스트림 프리빌트 패키징 근거
- buildroot-cctv `package/soc/nt98566/nt98566-sdk/nt98566-sdk.mk` — local 벤더 패키지 형식
- [../../review/belle-hardware.md](../../review/belle-hardware.md) — IDCODE·PL 실측
- [../r2/phase9-runtime-variant.md](../r2/phase9-runtime-variant.md) — 비트스트림 데이터의 런타임 로드 관련
