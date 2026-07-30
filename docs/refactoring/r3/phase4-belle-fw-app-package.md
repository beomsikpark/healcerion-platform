# Phase 4 — `belle-fw` 앱 패키지 + A/B 뱅크 재현

> **상태**: 미시작
> **범위**: `belle-fw` 를 git SHA 핀 cmake-package 로. `release_elsa.sh` 의 수동 셸 시퀀스를 `post-image.sh` 로 흡수. mtd2~5 A/B 뱅크 재현.
> **선행**: [Phase 2](./phase2-kernel-module-packages.md) · [Phase 3](./phase3-vendor-and-devicetree.md)
> **후행**: [Phase 5](./phase5-first-build-ci-sdk.md)

---

## 1. 배경

### 1.1 `EXTERNALSRC` 절대경로가 이 phase 의 핵심 제거 대상

```
belle-bsp/project-spec/meta-user/conf/petalinuxbsp.conf:15
EXTERNALSRC_pn-sonon = "/home/jacob/jacob-work-2020/belle_v202002_new/belle-fw"
```

`recipes-apps/sonon/sonon.bb` 가 `inherit cmake` 라 이 레시피 하나가 belle-fw 의 CMake 슈퍼프로젝트 전체를 빌드한다([device-firmware.md §2.1](../../review/device-firmware.md)). **이 절대경로가 belle-fw 를 "특정 개발자 머신의 디렉토리" 로 만든다.**

### 1.2 cctv `ipc-app.mk` 가 정확한 대체 형식이다

```make
IPC_APP_VERSION = e93c77eb7601725374ba02af15fd240f1766d925   # git SHA 하드 핀
IPC_APP_SOURCE = ipc-app-$(IPC_APP_VERSION).tar.gz
IPC_APP_SITE = git@github.com:humminglab/ipc-app.git
IPC_APP_SITE_METHOD = git
IPC_APP_GIT_SUBMODULES = YES     # extern/{kvspic,...} 서브모듈 필수

IPC_APP_DEPENDENCIES = \
	nt98566-sdk sqlite zeromq libcurl openssl ... onvif-wrapper

IPC_APP_CONF_OPTS += -DIPC_PLATFORM_NT98566=ON -DIPC_ENABLE_TESTS=OFF

define IPC_APP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/ipc-app $(TARGET_DIR)/usr/bin/ipc-app
	...
endef

$(eval $(cmake-package))
```

**핀 정책 주석이 중요하다**: *"부동 ref(브랜치명) 금지: buildroot dl 캐시 키가 VERSION 문자열이라 브랜치로 핀하면 첫 스냅샷이 dl/ 에 영구 고착된다."* **belle-fw 도 이 정책을 그대로 따른다.**

### 1.3 belle-fw 는 서브모듈이 없다 — cctv 보다 단순

`belle-fw` 는 단일 CMake 슈퍼프로젝트(`add_subdirectory`)이지 서브모듈 구성이 아니다([r2 plan.md §2.2](../r2/plan.md) CMakeLists.txt 실측). **`GIT_SUBMODULES` 옵션은 불필요** — cctv 보다 단순한 `cmake-package` 정의로 충분하다.

### 1.4 4개 실행물 + install 규칙 재정비

현재 `install(TARGETS sonon)` 이 `USING_HCPROC_DIR` 비활성 분기에 있어 **`sonon` 이 rootfs 에 설치되지 않는다**([device-firmware.md §3](../../review/device-firmware.md)). 이 phase 에서 **정규 Buildroot install 로 되돌릴지, 기존 UBI 오버레이 방식(A/B 뱅크)을 유지할지 결정**해야 한다 — 후자가 A/B 롤백 가치를 지키므로 우선한다(§2 Step 4-C).

| 실행물 | 목표 설치 위치 |
|---|---|
| `sonon` | UBI 오버레이(mtd4/5) — A/B 유지 |
| `bcd`·`deviced`·`watchdogd` | 〃 |

### 1.5 `release_elsa.sh` 이중 사본 문제

[device-firmware.md §2.2](../../review/device-firmware.md): 이 스크립트가 belle-fw 와 belle-bsp 양쪽에 **서로 다른 사본**으로 존재하고, belle-fw 쪽 사본은 실행하면 실패한다. **Buildroot `post-image.sh` 하나로 흡수하면 이 이중화 자체가 사라진다.**

### 1.6 목적

1. `belle-fw.mk` — git SHA 핀 cmake-package, `EXTERNALSRC` 절대경로 제거
2. `post-image.sh` — mtd2~5 A/B 뱅크 재현, `sudo mkfs.ubifs`+`ubinize` 자동화
3. `hcproc.sh`(S95 오버레이 복사) 방식 유지 여부 확정

### 1.7 범위 한계

- **belle-fw 내부 CMake 구조를 바꾸지 않는다** — [r2](../r2/plan.md)의 몫. 여기서는 현재 빌드 진입점을 그대로 패키지가 호출한다
- 프로세스 4종의 IPC·경계는 바꾸지 않는다

---

## 2. 진행 단계

### Step 4-A. `belle-fw.mk`

```make
BELLE_FW_VERSION = <belle-fw production-fw-ver2.0 HEAD SHA>
BELLE_FW_SITE = git@<host>:healcerion/belle-fw.git
BELLE_FW_SITE_METHOD = git

BELLE_FW_DEPENDENCIES = \
	plif-driver zynqdma-driver msp430-i2c-driver \
	ne10 xilinx-bitstream

BELLE_FW_CONF_OPTS += \
	-D_USING_500L_DEV_=ON \
	-D_USING_SA_DEV_=ON

define BELLE_FW_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sonon/sonon $(TARGET_DIR)/hcproc/bin/sonon
	$(INSTALL) -D -m 0755 $(@D)/bcd/bcd $(TARGET_DIR)/hcproc/bin/bcd
	$(INSTALL) -D -m 0755 $(@D)/deviced/deviced $(TARGET_DIR)/hcproc/bin/deviced
	$(INSTALL) -D -m 0755 $(@D)/watchdogd/watchdogd $(TARGET_DIR)/hcproc/bin/watchdogd
	# hcproc UBI 오버레이 이미지 생성용 스테이징 — 정규 rootfs 가 아니라 §4-C 의 오버레이 소스
endef

$(eval $(cmake-package))
```

| # | 작업 |
|---|---|
| A-1 | belle-fw HEAD SHA 확정 및 하드 핀 |
| A-2 | `DEPENDENCIES` 에 [Phase 2](./phase2-kernel-module-packages.md)·[3](./phase3-vendor-and-devicetree.md) 패키지 명시 — **`EXTERNALSRC` 절대경로가 하던 암묵적 연결을 명시적 의존 목록으로** |
| A-3 | `CONF_OPTS` 에 현행 컴파일 타임 변종 플래그(`_USING_500L_DEV_` 등) 그대로 전달 — [r2 Phase 9](../r2/phase9-runtime-variant.md) 전까지는 유지 |
| A-4 | `_LINEAR_ARRAY`·`_MSPLIB_`([r2 Phase 0-C2](../r2/phase0-hygiene-protocol-sot.md)에서 제거 대상)는 이 phase 시점에 이미 없을 수도, 아직 있을 수도 — **r2 진행 상태와 무관하게 이 패키지 정의는 항상 현재 belle-fw HEAD 를 그대로 반영** |

> **핵심**: 이 패키지 정의는 **belle-fw 의 내부가 어떻게 리팩토링되든(r2 진행과 무관하게) 항상 유효**해야 한다 — 빌드 진입점(`cmake .. && make`)과 산출물 경로만 알면 되기 때문이다. r2 가 디렉토리를 재배치해도 `INSTALL_TARGET_CMDS` 의 산출물 경로만 갱신하면 된다.

### Step 4-B. 커널 모듈 소스 참조 통일

[Phase 2 §2-B 주석](./phase2-kernel-module-packages.md) 대응 — `plif`·`zynqdma`·`msp430_drv` 의 `local` site 가 **이 belle-fw 핀과 같은 체크아웃**을 가리키게 한다(별도로 belle-fw 를 두 번 clone 하지 않도록).

### Step 4-C. `post-image.sh` — A/B 뱅크 재현

| 파티션 | 생성 로직 |
|---|---|
| mtd0(`BOOT.BIN`) | [Phase 1](./phase1-kernel-uboot-pin.md) 산출물 |
| mtd1(bootenv) | `tools/bootenv.bin` 정적 blob 문제 해소 — **U-Boot env 를 빌드에서 생성**(`mkenvimage`)하도록 전환 |
| mtd2/mtd3(커널 A/B) | Buildroot `Image`/`image.ub` → 동일 이미지를 양쪽 슬롯에 초기 배치 |
| **mtd4/mtd5**(hcproc 앱 오버레이 A/B) | `mkfs.ubifs` + `ubinize` — `release_elsa.sh` 의 로직을 `post-image.sh` 로 이식 |
| mtd6(userdata) | 빈 파티션 유지 |
| mtd7(auth, ContextVision 키) | 기존 방식 유지, 이 phase 범위 아님(앱 측 라이선스 저장) |

```bash
# post-image.sh (요지)
#!/bin/sh
HCPROC_STAGING="${BINARIES_DIR}/hcproc-overlay"
mkdir -p "${HCPROC_STAGING}"/{bin,belle,module}
cp "${TARGET_DIR}"/hcproc/bin/* "${HCPROC_STAGING}/bin/"
mkfs.ubifs -r "${HCPROC_STAGING}" -o "${BINARIES_DIR}/hcproc.img" ${UBIFS_OPTS}
ubinize -o "${BINARIES_DIR}/hcproc.ubi.bin" "${BOARD_DIR}/ubinize.cfg"
```

| # | 작업 |
|---|---|
| C-1 | `release_elsa.sh` 두 사본을 diff — 어느 쪽이 맞는지 확정 후 `post-image.sh` 로 이식 |
| C-2 | `sudo` 필요한 단계(`mkfs.ubifs`)를 Buildroot 빌드 사용자 권한 안에서 처리 가능한지 확인(보통 `fakeroot` 로 우회 가능) |
| C-3 | `upgrade.sh`(현장 업그레이드 스크립트)와의 파티션 이름·오프셋 일치 확인 — [r2 Phase 8-A](../r2/phase8-feature-firmware-process.md)의 `features/firmware-update` 와 계약 일치 |

### Step 4-D. `hcproc.sh` 오버레이 복사 방식 결정

**이 phase 에서는 유지한다.** [device-firmware.md §3](../../review/device-firmware.md)의 "부팅 시 UBI 오버레이를 live rootfs 위로 복사" 메커니즘 자체는 A/B 롤백 가치가 있으므로 **정규 install 로 되돌리지 않는다.** 최종 결정은 [r2 Phase 8-D](../r2/phase8-feature-firmware-process.md)와 함께.

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 패키지 빌드 | `make belle-fw` | 4개 바이너리 생성 |
| 3.2 | 절대경로 제거 | `grep -rn 'EXTERNALSRC\|/home/jacob'` | 0건 |
| 3.3 | 의존 명시성 | `belle-fw.mk` 의 `DEPENDENCIES` | 커널 모듈 3종·NE10·비트스트림 전부 포함 |
| 3.4 | `post-image` 실행 | `make` 전체 흐름 | `hcproc.img`·`hcproc.ubi.bin` 생성 |
| 3.5 | **A/B 파티션 레이아웃 일치** | 생성된 이미지의 오프셋/크기 vs 기존 `upgrade.sh` 기대값 | 일치 |
| 3.6 | 부팅+스캔 | 실장비 플래시 → 부팅 → 앱 접속 → 스캔 | 정상 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`release_elsa.sh` 두 사본이 실제로 다른 절차를 반영** | C-1 판단 오류 시 이미지가 현행과 다름 | diff 결과를 문서화하고, **애매하면 실장비 부팅 결과로 최종 판정**(3.6) |
| `sudo mkfs.ubifs` 를 빌드 자동화에서 권한 없이 못 돌린다 | CI·자동빌드 불가 | `fakeroot` 또는 사용자 네임스페이스 활용. Buildroot 자체가 이미 비슷한 상황(디바이스 노드 생성 등)을 `fakeroot` 로 처리하는 관례가 있다 |
| A/B 오프셋이 기존 `upgrade.sh`(앱 측 스크립트)와 미묘하게 다르다 | 필드 업그레이드 브릭 | 3.5 필수. [r2 Phase 8-A](../r2/phase8-feature-firmware-process.md) 착수 전 반드시 확정 |
| belle-fw 핀 SHA 가 r2 진행과 함께 자주 바뀐다 | 패키지 정의 유지보수 부담 | cctv `script/bump-pin.sh` 대응 스크립트 도입 검토 — Phase 5 이후 필요시 |

---

## 5. cross-reference

- [plan.md §1.1·§1.7·§2.3](./plan.md)
- buildroot-cctv `package/app/ipc-app/ipc-app.mk` — cmake-package + git 핀 정책 원본
- [../../review/device-firmware.md §2·§3·§4](../../review/device-firmware.md) — `EXTERNALSRC`·rootfs 오버레이·A/B 뱅크 실측
- [../r2/phase8-feature-firmware-process.md](../r2/phase8-feature-firmware-process.md) — `features/firmware-update` 와의 계약
- [../r2/phase0-hygiene-protocol-sot.md](../r2/phase0-hygiene-protocol-sot.md) — belle-fw 내부 위생과의 독립성
