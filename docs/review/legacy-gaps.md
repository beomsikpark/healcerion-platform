# legacy 구성의 공백 — 무엇이 없는가

> **근거**: `<컨테이너>/legacy/` 미러 **31건**(+빈 저장소 2건) 코드 직접 읽기. 2026-07-27 권한 확대 반영.
> **표기**: "코드가 이름으로 지목" = 미러 안 소스·스크립트가 그 대상을 문자열로 참조한다는 뜻(검증됨). "증거 없음" = 참조도 확인되지 않음.
> **상세**: [device-firmware.md](device-firmware.md) · [mobile-codebase.md](mobile-codebase.md) · [web-server-fpga.md](web-server-fpga.md)

## 0. 이 문서의 초판은 크게 틀렸다

초판(권한 확대 전, 미러 13건 기준)은 **접근 차단을 부재로 오독**했다. 권한이 열려 31건이 되자 "없다" 고 단정한 것 중 다수가 실재했다.

| 초판 주장 | 실제 |
|---|---|
| 우선순위 1위 — **빌드 계통이 통째로 없다** | **`belle-bsp` 가 PetaLinux 프로젝트로 존재**하고, 커널·u-boot 도 있다(§2) |
| **FPGA 테이블 생성기가 어디에도 없다** | **`bf-delay-calculation` 이 그것이다.** MATLAB, 출력 헤더가 바이트 단위로 일치(§4) |
| `server/` 에 **실 서버가 하나도 없다** | **`sonex-cloud-backend` 가 그 서버**다. 엔드포인트 47/48 일치(§5) |
| `rHFW` = 데스크톱 호스트 SW | **`ginny-fw`, 300 시리즈 장비 펌웨어**(커밋 1,109개) |

> **교훈**: 접근이 막힌 상태에서 "부재" 를 결론으로 쓰면 안 된다. 그때 쓸 수 있는 표현은 "확인 불가" 뿐이다.

지금 남은 공백은 **성격이 다르다** — 저장소가 없는 게 아니라, **저장소 밖에 있다.**

## 1. 빈 저장소 (2건)

| 저장소 | 상태 |
|---|---|
| `device/legacy/belle-fsbl` (id 54) | 원격에 **ref 0 · 오브젝트 0**. 이름만 생성됨 |
| `device/legacy/belle-pmu` (id 55) | 동일 |

id 50~55 가 belle 계열로 연속 할당된 것으로 보아 **한 번에 생성했으나 2건은 push 되지 않았다.**

## 2. 빌드 계통 — 확보된 것과 남은 것

`belle-bsp` 는 **PetaLinux 프로젝트**다(`config.project`, `project-spec/`). BSP 가 애플리케이션을 빌드하는 배선도 명시돼 있다.

```
project-spec/meta-user/conf/petalinuxbsp.conf:
EXTERNALSRC_pn-sonon = "/home/jacob/jacob-work-2020/belle_v202002_new/belle-fw"
```

`recipes-apps/sonon/sonon.bb` 가 `inherit cmake` 이므로 이 한 레시피가 **belle-fw 의 CMake 슈퍼프로젝트 전체**를 빌드한다. 전체 순서는 `release_elsa.sh` 에 있다.

```sh
petalinux-build
petalinux-package --boot --fsbl $FSBL --pmufw $PMU --u-boot
mkfs.ubifs ... hcproc.img ; ubinize ... hcproc.ubi.bin
```

보드 정체도 확정된다 — `system-user.dtsi` 의 `model = "HIT REV1.0"`, 노드 `plif@b0000000`·`msp430@FF0A0000` 가 belle-fw 의 커널 모듈(`modules/plif`·`modules/msp430_drv`)과 정확히 대응한다.

### 2.1 확보됨

| 구성요소 | 실체 |
|---|---|
| 애플리케이션 | `belle-fw` (현행 생산 라인, §3) |
| BSP·머신 정의 | `belle-bsp` — MACHINE `zynqmp-generic`, product `elsa-es3`, 패키지 선택은 `project-spec/configs/rootfs_config` |
| 커널 | `belle-kernel` — **Linux 5.4.0** (linux-xlnx 포크), defconfig `arch/arm64/configs/xilinx_zynqmp_defconfig` |
| 부트로더 | `belle-u-boot` — **v2020.01**, `configs/xilinx_zynqmp_virt_defconfig` |
| 디바이스 트리 | `belle-bsp` 의 `system-user.dtsi`·`pl-custom.dtsi` (커널 트리에는 보드 DT 가 **없다** — PetaLinux 가 `.xsa` 에서 생성) |

### 2.2 여전히 없는 것

| 없는 것 | 왜 문제인가 |
|---|---|
| **PetaLinux/Yocto 툴체인 자체** | `petalinux-build`·`meta-xilinx`·poky "zeus"·`petalinux-image-minimal`·`bootgen` 이 전부 외부. BSP 는 그 위에 얹는 *설정*만 제공한다 |
| **FSBL·PMU 소스** | 저장소가 비어 있고(§1), 실물은 `belle-bsp/vivado-hw-xsa/es3-fsbl-v00-01-00.elf`·`es3-pmu-v00-01-00.elf` **프리빌트 ELF 뿐**. 하드웨어 리비전이 바뀌면 재생성 경로가 없다 |
| **Vivado 하드웨어 프로젝트** | `es3_v00.01.00.xsa`(비트스트림+핀아웃+블록 디자인)의 **원본 프로젝트가 없다.** 내보낸 아티팩트만 있다 |
| **`belle-sysroot`** | `release_elsa.sh` 가 `source .../belle-sysroot/environment-setup-aarch64-xilinx-linux` 를 참조하나 실물 없음 |
| 이미지 레시피 | 커스텀은 없고 표준 `petalinux-image-minimal` 을 이름으로만 참조 (툴체인에 포함되므로 §2.2 첫 항목과 같은 문제) |

**모든 절대경로가 특정 개발자 머신에 고정돼 있다** — `/home/jacob/jacob-work-2020/belle_v202002_new/...`. 다른 호스트에서는 수정 없이 동작하지 않는다.

### 2.3 ginny 세대

`ginny-fw` 도 rootfs 를 만들지 않는다(Yocto·PetaLinux·Buildroot 흔적 0건). 프리빌트 `u-boot.bin`·`kernel.img`·`rootfs.img` 를 `nandwrite` 로 굽고 YAFFS2 로 마운트한다. `meta-elsa`·`elsa-yocto-bsp` 는 i.MX6 용이고 이미지 레시피가 없다.

## 3. 세대 계보 — 확정

**`ginny-fw` → `elsa-fw` → `belle-fw`** 이고, **현행 생산 라인은 `belle-fw`** 다.

| 저장소 | 커밋 | 기간 | 상태 |
|---|---:|---|---|
| `ginny-fw` | **1,661** | 2015-04 ~ 2021-07 | 300 시리즈. 저자 6명, 태그 34개, 브랜치 29개 — **개발 이력의 본체** |
| `elsa-fw` | 74 | 2020-09 ~ 2021-08 | `elsa-es-v3` 브랜치까지. belle 로 이관 후 정지 |
| `belle-fw` | **66** | 2021-08 ~ **2026-07-01** | **현행 생산 라인.** master 는 2021-09 에 멈췄고 실제 작업은 `production-fw-ver2.0` 브랜치 |

`belle-fw` 의 두 번째 커밋 메시지가 `"first time (migration elsa-fw repo)"` 다. `elsa-fw` ↔ `belle-fw` 는 경로 473개 공유. `ginny-fw` ↔ `elsa-fw` 는 공통 경로 175개 중 MD5 동일 76개로, **rename 이 아니라 파생**이다(공통 커밋 조상 없음).

> **초판 정정**: "elsa-fw 의 옛 이름이 ginny-fw" 는 **반증됐다.** `sync_table.sh` 는 별개 저장소를 참조하는 개발자 유틸리티였다.

## 4. 생성 도구 — 대부분 실재했다

| 도구 | 상태 |
|---|---|
| **FPGA 빔포밍 테이블 생성기** | **`bf-delay-calculation` 이 그것이다**(MATLAB `.m` 9개, 3,368 LOC). 출력이 `ginny-table` 의 `.dat` 와 **헤더 문자열·저자명·날짜·`%03d` 배치까지 일치**. Xilinx `.coe` BRAM init 도 생성 |
| 앱 문자열 변환기 | `ginny-string-table-converter` (Python 2, XLSX → iOS `.strings` + Android `strings.xml`) |
| 프로브 파라미터 바이너리 생성기 | **여전히 Excel `.xls`** (`500c-sn-fw/PrmBin/`) |
| **AI 모델 학습 코드** | **여전히 없음.** `sonex-framework` 의 Python 6개는 전부 변환 스크립트 |

> 초판이 생성기를 놓친 이유가 확인됐다 — `ash_total_Rx_delay_table_James_20170615.m` 가 **ISO-8859 인코딩**이라 `grep -a` 없이는 매칭되지 않는다.

## 5. 서버 — 실재했다

| 저장소 | 상태 |
|---|---|
| **`sonex-cloud-backend`** | `sonex-admin-web` 의 **엔드포인트 48개 중 47개 구현**. Java 8 · Spring MVC 5.2 · MyBatis · MariaDB · WAR(`CloudService`) · 포트 8080 · 핸들러 124개. **커밋 16개가 2022-09 와 2025-05 두 시점에만 몰려 있다** |
| **`sonon-cloud`** | 전혀 다른 제품. Firebase Functions + Firestore + Vue2/Quasar. **394커밋, 저자 8명, 최종 2026-06-02 — 현재 운영 중** |

두 저장소는 공통 파일이 `.gitignore` 하나뿐이다. **계승이 아니라 병렬**이다.

**남은 공백**: `sonex-cloud-backend` 에 `sdi`·`ela` 스키마의 DDL 이 없다(mapper 가 `sdi.wa_AddDevice` 등 저장 프로시저를 호출하는데 테이블 정의가 저장소에 없음).

## 6. 소스 없이 바이너리만 있는 것

| 대상 | 위치 | 중요도 |
|---|---|---|
| **FSBL·PMU ELF** | `belle-bsp/vivado-hw-xsa/` | **높음** — 부팅 1단계, 재생성 불가(§2.2) |
| **`.xsa` 하드웨어 핸드오프** | 같은 경로 | **높음** — Vivado 원본 없음 |
| `libudl.a` | `500c-sn-fw/lib/` | **높음** — 500C 의 빔포밍·JPEG 을 수행하는 UDL 블록의 드라이버 |
| `libUSSWiFi.a` | 같은 경로 | 중 |
| `SonexSDK.dll`/`.framework` | 앱 저장소에 미커밋, 개발자 머신에서 복사 | **높음** — 앱↔SDK 버전 고정 장치 없음 |
| Marvell WiFi `.ko` | `elsa-fw`·`belle-fw`/`modules/wifi/mrvl/` | 중 |
| ContextVision `cvie64` | `sonex-framework/sdk/third_party/` 82MB | 상용 — 부재가 정상. 자체 대체 Phase 1 만 완료 |

## 7. 프로토콜 — 정본 정의가 없다

`'H','C'` 14바이트 헤더 프로토콜이 **4개 코드베이스에 각각 하드코딩**돼 있다 — `elsa-fw`·`ginny-fw`·`belle-fw`(장비), `500c-sn-fw`(커스텀 스택), `sonex-framework`(호스트 SDK), `cuattro-sdk`(Windows SDK).

그런데 **구조체 선언이 어느 저장소에도 없다.** `PACKET_HEADER_S` 는 `elsa-fw` 에서 212회 쓰이지만 선언이 없고, 전 워크스페이스 `.h` 파일에서 `session_id` 선언은 **0건**이다. 즉 필드 순서·타입·오프셋을 코드로 확인할 수 없다. 상세 = [device-firmware.md §8](device-firmware.md).

## 8. 대응 빈칸

| 항목 | 상태 |
|---|---|
| `InstructionSet500L`·`500P` | SDK 에 클래스가 있으나 대응 펌웨어 미확인 |
| `MODEL_S300MC` | 펌웨어(`ginny-fw`·`elsa-fw`)에 있으나 SDK 전용 클래스 없음 |
| `DeleteAccount` | `sonex-admin-web` 이 호출하나 서버에 라우트 없음 (죽은 클라이언트 코드) |

## 9. 품질 인프라

| 항목 | 실측 |
|---|---|
| **CI 설정** | **31건 전부 0건** |
| 실제 테스트 | **3건뿐** — `sonon-cloud`(Mocha 24개 + Cypress e2e) · `sonex-app`(2,518 LOC) · `ginny-renewal`/`ash-fpga`(HDL 테스트벤치·C 골든 모델) |
| device 그룹 단위 테스트 | **0건** |
| 문서 | 31건 중 `CLAUDE.md`/`docs/` 보유 2건 |

> **FPGA 팀이 유일하게 회귀 검증 체계를 갖췄다** — 비트정확 C 골든 모델(`ginny-fpga` → `ginny-renewal` 로 7파일 그대로 계승) + Xcelium 테스트벤치 + 기대 벡터.

## 10. ⚠ 비밀정보 커밋

값은 확인하지 않았고 위치만 기록한다. **힐세리온 소유 저장소이므로 우리가 조치할 사안은 아니나, 검토 보고에 포함해야 한다.**

| 저장소 | 위치 | 내용 |
|---|---|---|
| `sonex-cloud-backend` | `Core/.../CoreIndexer.xml` 등 **5개 파일** | MariaDB **root 비밀번호**, 대상 `sonex.healcerion.com:3306` |
| `sonon-cloud` | `functions/sharp-imprint-234606-453329870be0.json` | **GCP 서비스 계정 개인키** (git 추적 중, **현재 운영 중인 시스템**) |

## 11. 우선순위 (개정)

| 순위 | 항목 | 이유 |
|---|---|---|
| **1** | §2.2 **FSBL·PMU 소스 + Vivado 하드웨어 프로젝트** | 부팅 1단계와 FPGA 이미지가 **재생성 불가**. 저장소가 아니라 개발자 머신·Vitis 프로젝트에 있을 가능성이 높다 |
| **2** | §2.2 **PetaLinux 툴체인 버전 확정** | 어느 릴리스인지(2019.2? 2020.x?) 확정돼야 빌드 재현이 가능하다. `layer.conf` 의 `zeus` 가 단서 |
| **3** | §10 **비밀정보** | 운영 중인 시스템의 키가 노출돼 있다 |
| **4** | §6 `libudl.a` 소스 | 500C 신호처리가 블랙박스로 남는다 |
| **5** | §7 프로토콜 정본 정의 | 4개 구현의 조상 헤더 소재 |
| 6 | §5 `sdi`·`ela` 스키마 DDL | 서버 재구축 시 필요 |

## 12. 힐세리온에 요청할 목록 (개정)

1. **빌드 재현** — FSBL·PMU 소스(또는 생성 절차), `es3_v00.01.00.xsa` 를 만든 Vivado 프로젝트, PetaLinux 릴리스 버전, `belle-sysroot`
2. **소스 없는 라이브러리** — `libudl.a`·`libUSSWiFi.a`
3. **프로토콜 정본** — `PACKET_HEADER_S` 를 선언하는 헤더의 소재
4. **DB 스키마** — `sdi`·`ela` 의 테이블·프로시저 DDL
5. **보안 통보** — §10 두 건
6. **확인 질문** — `500L`·`500P` 펌웨어 소재, `300MC` 의 호스트측 처리, "Mirae"·"Ash" 제품의 현재 상태

## 13. 미확인

- `belle-fw` 의 `production-fw-ver2.0`(2026-07-01)과 `master`(2021-09)의 관계 — 실제 출하 브랜치가 어느 쪽인지
- `ash-fpga` 의 SMIC 0.13µm ASIC 이 실제 tapeout 됐는지 — 제품화 여부 불명
- `charm-fpga` 가 **Efinix** 를 타깃하는 이유 — 이 계열에서 유일하게 Xilinx 가 아니다
- `elsa-fw`(Zynq)의 `/userdata/fpga.bin` 과 Artix-7 비트스트림의 관계([web-server-fpga.md §5.2.1](web-server-fpga.md))
- 시뮬레이터·도플러 R&D 5건 — 접근 가능하나 컨테이너 축 미정
