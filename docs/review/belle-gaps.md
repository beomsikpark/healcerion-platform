# belle — 없는 것과 우선순위

> **범위**: belle 계열(장비 펌웨어·BSP·커널·u-boot·PL) + 앱 SOT(`moana`) + 클라우드.
> **근거**: 코드 직접 읽기(2026-07-28). 상세 = [device-firmware.md](device-firmware.md) · [belle-hardware.md](belle-hardware.md) · [moana-app.md](moana-app.md) · [cloud-server.md](cloud-server.md)

## 1. 빌드 재현 불가 — 최우선

현재 저장소 + PetaLinux 설치만으로는 **부팅 가능한 이미지를 만들 수 없다.**

| 없는 것 | 상태 | 영향 |
|---|---|---|
| **FSBL·PMU 소스** | `belle-fsbl`·`belle-pmu` 저장소가 **비어 있다**(원격 ref·오브젝트 0). 실물은 `belle-bsp/vivado-hw-xsa/es3-fsbl-v00-01-00.elf`·`es3-pmu-v00-01-00.elf` 프리빌트 ELF | **부팅 1단계 재생성 불가.** 하드웨어 리비전 변경 시 대응 경로 없음 |
| **Vivado 하드웨어 프로젝트** | `es3_v00.01.00.xsa` 는 내보낸 아티팩트. 원본 프로젝트 없음 | **PL 설계를 바꿀 수 없다** |
| **커널 모듈 3종** | `plif`·`zynqdma`·`msp430_drv` 에 **Makefile 이 없다.** `readme.makefile` 템플릿 하나뿐이고 BSP 에도 레시피 0건 | 그런데 install 규칙과 `release_elsa.sh` 가 이 `.ko` 를 참조한다. **빌드 경로가 끊겨 있다** |
| **`NE10`** | `sonon` 이 링크하는데 `ne10_lib/` 에 **헤더 8개뿐** | 링크 불가 |
| **PetaLinux 툴체인** | `petalinux-build`·`meta-xilinx`·poky "zeus"·`bootgen` 전부 외부. **릴리스 버전 미확정** | 재현 환경 구성 불가 |
| **`belle-sysroot`** | `release_elsa.sh` 가 참조하나 실물 없음 | 크로스 빌드 환경 부재 |

**모든 절대경로가 특정 개발자 머신에 고정돼 있다** — `/home/jacob/jacob-work-2020/belle_v202002_new/{belle-fw,belle-u-boot,belle-kernel,belle-sysroot}`. `EXTERNALSRC`·`EXT_LOCAL_SRC_PATH` 가 git submodule 이 아니라 이 경로를 가리킨다.

**함정**: 2021-08 빌드 `hcproc.img`(9.5MB)가 git 에 그대로 있다. 산출물로 오인하면 5년 전 앱이 배포된다.

## 2. 소스 없이 바이너리만 있는 것

| 대상 | 위치 | 중요도 |
|---|---|---|
| FSBL·PMU ELF | `belle-bsp/vivado-hw-xsa/` | **높음** — §1 |
| `.xsa` 하드웨어 핸드오프 | 같은 경로 | **높음** — §1 |
| `bootenv.bin` | `belle-fw/tools/` | 중 — 어떤 빌드도 생성하지 않는 정적 blob |
| Marvell WiFi `.ko`·펌웨어 | `belle-fw/modules/wifi/mrvl/` | 중 — 벤더 제공 |
| BLE 도구 | `belle-fw/modules/ble/` | 낮 — 프리빌트 BlueZ |
| ContextVision `cvie` | `moana/lib/*/contextvision/` 113MB | 상용 — 부재가 정상 |
| Flask 웹서버 `.so` | `belle-fw/modules/webserver/belle_flask/ext-library/` | 낮 — 인접 소스가 있으나 빌드가 배선돼 있지 않음 |

## 3. 하드웨어 정보 부재

| 없는 것 | 영향 |
|---|---|
| **회로도·BOM** | [belle-hardware.md](belle-hardware.md) 의 내용은 전부 **소프트웨어에서 역산**한 것이다 |
| QSPI 플래시 실장 부품 | 주석의 `mt25ql02g`(256 MiB)가 유일한 단서. 부팅 로그로 확정 가능 |
| ZynqMP 정확한 부품번호 | `config` 에 없다. `.xsa` 안에 있으나 원본 프로젝트가 없다 |
| 보드 리비전 대응 | `HIT REV1.0`(DT) · `elsa-es3` · `elsa-pp` 세 표기의 관계 |

## 4. 프로토콜 — 정본이 둘로 갈렸다

`'H','C'` 14바이트 헤더가 **belle 을 포함해 7개 코드베이스에 복제**돼 있고, 선언은 두 곳에 있다.

| 계보 | 선언 위치 | `recv_id` |
|---|---|---|
| A `PACKET_HEADER_S` | `500c-sn-fw` (범위 밖 저장소) | `U16` |
| B `COMMON_PACKET_HEADER` | `moana/framework/SononClient/SononPacket.h` | `char[2]` |

**`belle-fw` 는 이 타입을 쓰면서 선언을 자기 저장소에 두지 않는다.** 빌드 시 외부 include 로 주입되는 것으로 보이나 미확정이다.

동기화 장치가 없고 CRC 도 구현돼 있지 않다(`verify_packet_header_and_crc` 함수명과 달리 검사 코드 없음). **위험 낮고 효과 큰 첫 리팩토링 대상**이다.

## 5. 클라우드

| 없는 것 | 영향 |
|---|---|
| `sdi`·`ela` 스키마 DDL | 매퍼가 프로시저를 호출하나 테이블 정의가 저장소에 없다. **서버 재구축 불가** |
| belle 의 클라우드 연결 | `sonex-cloud-backend` 샘플에 `SONON500L-...` 가 있으나 실제 운영 연결 미확인. 그 서버는 사실상 정지 |

**클라우드 스키마가 장비 프로토콜에 묶여 있다** — 디바이스 레코드가 `ctrl_port`·`data_port`·`cv_license` 를 갖는다. 프로토콜을 바꾸면 서버 스키마도 함께 바뀐다.

## 6. 품질 인프라

| 항목 | belle 범위 실측 |
|---|---|
| **CI** | `belle-fw`·`belle-bsp`·`belle-kernel`·`belle-u-boot`·`belle-msp`·`elsa-fpga`·`moana` **전부 0건** |
| 자동 테스트 | belle 계열 **0건**. `moana` 도 0건(`test/` 는 수동 프로토타입 앱) |
| 문서 | `moana` 만 개발자 작성 분석 문서 23건 보유. belle 계열은 없음 |
| 저자 | belle 계열 **전부 `jacob` 단독**. `moana` 만 17명 |

**자동 회귀 판정이 없다.** 변경의 동작 동일성을 확인할 기준선이 없고, 6개 타깃·다수 인증 변종을 **수동으로 검증**하고 있다. 의료기기 규제 검토(판단 대기 5번)의 핵심 공백이다.

> 안전망 자체가 없다는 뜻은 아니다 — `moana` 출하 브랜치에 사내 QA 표기(`[SQA]`)가 **150건** 있다([change-cost.md §5](change-cost.md)). 없는 것은 **자동화된 판정**이다.

## 7. 릴리스·변종 관리

브랜치로 인증·국가·고객사·하드웨어 리비전을 영구 분기한다.

| 저장소 | 예 |
|---|---|
| `belle-fw` | `production-fw` · `production-fw-ver2.0` · `fuji` · `500_integrated` · `T1968-cf-power-integrate` |
| `moana` | `310C_China_Certification` · `500L_Cetification` · `Japan_Vet` · `oem_sphera` · `20201106_Tokopia_SononPet` · `20200121_Laonz_Customizing` |

**비용이 실제로 발생했다** — `moana` 에 `HC_RELEASE_TARGET` 미설정 시 qmake 가 hard-error 를 내도록 강제한 커밋이 있고, 사유는 **CE/US 빌드가 뒤바뀌어 출하된 사고**다.

그리고 **변종 선택이 퇴화했다** — 이전 세대는 u-boot 환경변수로 런타임에 5개 모델을 고르는 단일 유니버설 이미지였는데 belle 은 컴파일 타임 분기다. **런타임 방식으로 되돌리는 것이 명확한 개선 방향이고 사내 선례가 근거**다([legacy/ginny-elsa-firmware.md §3](legacy/ginny-elsa-firmware.md)).

## 8. ⚠ 비밀정보 커밋

값은 확인하지 않았고 위치만 기록한다.

| 저장소 | 위치 | 내용 |
|---|---|---|
| `sonex-cloud-backend` | `Core/.../CoreIndexer.xml` 등 5개 파일 | MariaDB **root 비밀번호** |
| `sonon-cloud` | `functions/sharp-imprint-234606-453329870be0.json` | **GCP 서비스 계정 개인키** (운영 중인 시스템) |

## 9. 우선순위

| 순위 | 항목 | 이유 |
|---|---|---|
| **1** | §1 **빌드 재현** — FSBL·PMU 소스, Vivado 프로젝트, 커널 모듈 Makefile, PetaLinux 버전 | **리팩토링 착수의 전제.** 빌드할 수 없으면 변경 결과를 검증할 수 없다 |
| **2** | §6 **회귀 안전망** — 최소한의 자동 테스트·CI | 1번과 함께 있어야 의미가 있다 |
| **3** | §4 프로토콜 정본 단일화 | 위험 낮고 효과 큼 |
| **4** | §8 비밀정보 | 운영 중인 시스템의 키 |
| **5** | §7 변종 관리 방식 전환 | 출하 사고 이력 있음 |
| 6 | §3 회로도·BOM | HW 판단을 코드 역산에 의존 중 |
| 7 | §5 `sdi`·`ela` DDL | 클라우드 축을 다룰 때 |

## 10. 힐세리온에 요청할 목록

1. **빌드 재현** — FSBL·PMU 소스(또는 생성 절차) · `es3_v00.01.00.xsa` 를 만든 Vivado 프로젝트 · 커널 모듈 3종의 빌드 방법 · PetaLinux 릴리스 버전 · `belle-sysroot` · `libNE10.a`
2. **하드웨어** — 회로도·BOM · QSPI 플래시 부품번호 · ZynqMP 부품번호 · 보드 리비전 표기 대응
3. **프로토콜** — `belle-fw` 가 참조하는 `PACKET_HEADER_S` 선언의 실제 소재
4. **클라우드** — `sdi`·`ela` 스키마 DDL · belle 장비의 클라우드 연결 현황
5. **보안 통보** — §8 두 건
6. **확인 질문** — `belle-fw` 의 실제 출하 브랜치(`production-fw` vs `production-fw-ver2.0`) · `auth` 파티션 사용처

## 11. 미확인

- `belle-fw` `production-fw-ver2.0`(2026-07)과 `production-fw`(2026-06)의 관계
- PetaLinux 릴리스 버전 — `layer.conf` 의 `zeus` 가 단서
- `image_proc` 도입으로 영상 형성 경계가 어디까지 옮겨왔는지
- `auth` 파티션(mtd7) 사용처 — 정의만 있고 펌웨어 스크립트에 접근 흔적 없음
