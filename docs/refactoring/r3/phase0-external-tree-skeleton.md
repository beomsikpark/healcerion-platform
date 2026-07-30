# Phase 0 — `BR2_EXTERNAL` 골격

> **상태**: 미시작
> **범위**: `buildroot-healcerion` 저장소 신설. `external.desc`·`external.mk`·`Config.in` + `board/`·`package/{soc,app,lib}`·`configs/`·`script/` 골격.
> **선행**: 없음 — r3 의 첫 phase
> **후행**: [Phase 1](./phase1-kernel-uboot-pin.md) 이후 전부
> **구조 정본**: buildroot-cctv `docs/architecture/directory-structure.md` · `external.mk` · `external.desc` · `Config.in` — `cctv/device/buildroot-cctv/`

---

## 1. 배경

### 1.1 `BR2_EXTERNAL` 이 하는 일

Buildroot 코어는 그대로 두고, **커스텀 패키지·보드 설정만 별도 트리에 둔다.** cctv 는 `buildroot`(포크, `2021.02.3-cctv`)와 `buildroot-cctv`(external tree) 두 저장소를 나란히 클론해 쓴다.

```
cd ../buildroot
make BR2_EXTERNAL=../buildroot-cctv <board>_defconfig
make all
```

**belle 도 같은 형태로 간다** — `buildroot`(포크 또는 upstream) + `buildroot-healcerion`(신설, 이 phase 의 산출물).

### 1.2 belle 은 cctv 보다 단순하다

| | cctv | belle |
|---|---|---|
| 보드 수 | 18 | **1**(500L) — 향후 300C 등 추가 시 확장 |
| 패키지 그룹 | `soc`·`app`·`lib`·`thirdparty`·`web` 5개 | **`soc`·`app`·`lib` 3개** — web UI 없음, thirdparty 는 lib 에 흡수 가능 |
| SoC 벤더 | Novatek·SigmaStar·Eyenix 다수 | **Xilinx ZynqMP 하나** |

**골격은 작게 시작하고, 필요해지면 cctv 만큼 늘린다.**

### 1.3 목적

1. `buildroot-healcerion/{external.desc,external.mk,Config.in}` 확립
2. `board/belle-500l/` · `package/{soc,app,lib}/` · `configs/` · `script/` 디렉토리
3. 최상위 `make` 진입점(cctv `Makefile` 패턴)

### 1.4 범위 한계

- **패키지 내용을 채우지 않는다** — 커널·U-Boot 는 [Phase 1](./phase1-kernel-uboot-pin.md), 커널 모듈은 [Phase 2](./phase2-kernel-module-packages.md), belle-fw 는 [Phase 4](./phase4-belle-fw-app-package.md)
- Buildroot 코어 자체(포크 여부)는 이 phase 에서 확정만 하고 실제 포크는 착수 시점 필요에 따름(§2 Step 0-A)

---

## 2. 진행 단계

### Step 0-A. Buildroot 코어 버전 확정

| # | 작업 |
|---|---|
| A-1 | belle-kernel(2021-10) 시점과 가까운 Buildroot 릴리스 확인 — cctv 가 쓰는 `2021.02.3` 계열이 유력 후보 |
| A-2 | **cctv 처럼 포크가 필요한지 판단** — cctv 는 `buildroot.git` 자체를 포크했다(이유 미확인, 착수 시 diff 확인). belle 은 **upstream Buildroot 를 그대로 쓸 수 있는지 우선 시도**, 안 되면 최소 패치로 포크 |
| A-3 | 버전을 `buildroot-healcerion/README.md` 에 고정 기록 |

### Step 0-B. 최상위 파일

```
external.desc:
name: HEALCERION
desc: belle ultrasound device firmware

external.mk:
include $(sort $(wildcard \
	$(BR2_EXTERNAL_HEALCERION_PATH)/package/*/*.mk))
export LINUX_DIR
export UBOOT_DIR

Config.in:
source "$BR2_EXTERNAL_HEALCERION_PATH/board/Config.in"
source "$BR2_EXTERNAL_HEALCERION_PATH/package/app/belle-fw/Config.in"
# ... (Phase 1~4 에서 패키지가 생길 때마다 추가)
```

**cctv `external.mk` 는 3단계 glob**(`*/*.mk`·`*/*/*.mk`·`*/*/*/*.mk`)이다. belle 은 패키지 그룹이 3개뿐이라 **2단계 glob**(`package/*/*.mk`)로 충분할 수 있다 — 착수 시 실제 필요 깊이 확인.

### Step 0-C. 디렉토리 생성

```
buildroot-healcerion/
  board/belle-500l/{doc,dts,overlay,pmufw}/
  package/{soc,app,lib}/
  configs/
  script/
```

각 디렉토리에 README 1줄(역할 명시).

### Step 0-D. 최상위 `make` 진입점

cctv `Makefile` 패턴 — `BOARD` 필수 인자, `script/build-<board>.sh` 위임.

```make
.DEFAULT_GOAL := help
BOARD ?= belle-500l
JOBS ?= ...

build:
	script/build-$(BOARD).sh --jobs $(JOBS)

clean:
	rm -rf output/$(BOARD)
```

**belle 은 보드가 하나라 `BOARD` 필수화가 지금은 과설계일 수 있다** — 기본값을 `belle-500l` 로 두고, 여러 모델이 생기면 cctv 처럼 필수 인자로 전환.

### Step 0-E. `script/build-belle-500l.sh` 뼈대

cctv `script/build-nt98566-ipc.sh` 의 옵션 구조(`--output-dir`·`--defconfig`·`--jobs`·`--defconfig-only`·`--build-only`)를 이식. **내용은 Phase 5 에서 채운다** — 이 phase 는 옵션 파싱 뼈대만.

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | 골격 존재 | `ls buildroot-healcerion/{external.desc,external.mk,Config.in}` | 전부 존재 |
| 3.2 | Buildroot 인식 | `make BR2_EXTERNAL=../buildroot-healcerion help` (Buildroot 코어에서) | external tree 이름(`HEALCERION`) 표시 |
| 3.3 | 디렉토리 구조 | `find buildroot-healcerion -maxdepth 2 -type d` | §2 Step 0-C 트리와 일치 |
| 3.4 | `make` 진입점 | `make help` | BOARD·JOBS 등 변수 설명 출력 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| Buildroot 코어 포크가 실제로 필요하다 | 착수 지연 | A-2 — cctv 포크 이유를 먼저 diff 로 확인. ZynqMP 지원이 upstream 에 이미 있으면 포크 불필요 가능성 높음 |
| 패키지 그룹 3개로 부족해진다(향후 모델 확장) | 재구조화 | cctv 의 5그룹 규약을 **문서에 미리 적어두고** 필요시 확장. 지금 3개로 시작하는 것 자체는 위험 아님 |

---

## 5. cross-reference

- [plan.md §2.1·§2.2·§4](./plan.md)
- buildroot-cctv `docs/architecture/directory-structure.md` · `external.mk` · `Makefile` — `cctv/device/buildroot-cctv/`
- [phase1-kernel-uboot-pin.md](./phase1-kernel-uboot-pin.md)
