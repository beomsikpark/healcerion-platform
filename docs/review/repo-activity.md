# 저장소 활동성 — 실측

> **근거**: 클론된 미러 31건의 `git` 직접 조회 · Phabricator conduit(2026-07-27).
> **측정 기준**: 커밋 수는 **`--all`(전 브랜치)**, 최종일은 **전 브랜치 최신 커밋일**이다. 이 조직은 master 에서 작업하지 않으므로 master 기준 수치는 의미가 없다.

## 1. 실측 데이터

| 저장소 | commits | master 최종 | **전 브랜치 최종** | 작업 브랜치 | 저자 |
|---|---:|---|---|---|---:|
| `client/legacy/moana` | **5,705** | 2022-02-17 | **2026-07-27** | `service_QT693` | 19 (별칭 병합 13) |
| `client/legacy/sonex-framework` | 524 | 2026-07-23 | **2026-07-23** | master | 8 |
| `client/legacy/sonex-app` | 249 | 2026-06-18 | **2026-07-15** | `feature-apply_v1.23.4` | 5 |
| `device/legacy/belle-fw` | 66 | 2021-09-06 | **2026-07-01** | `production-fw-ver2.0` | 1 |
| `server/legacy/sonon-cloud` | 394 | 2026-06-02 | **2026-06-02** | master | 8 |
| `device/legacy/500c-sn-fw` | 71 | 2023-07-03 | **2026-04-24** | `FW_1_1_8_0` | 2 |
| `server/legacy/sonex-cloud-backend` | 16 | 2025-05-09 | 2025-05-09 | master | 2 |
| `device/legacy/ginny-fw` | **1,661** | 2020-04-17 | 2021-07-15 | `ginny-renewal` | 6 |
| `device/legacy/belle-bsp` | 18 | 2021-12-07 | 2022-05-27 | `production-fw` | 1 |
| `device/legacy/belle-u-boot` | 9 | 2022-04-22 | 2022-04-22 | master | 1 |
| `device/legacy/belle-msp` | 6 | 2022-05-09 | 2022-05-09 | master | 1 |
| `device/legacy/belle-kernel` | 5 | 2021-10-06 | 2021-10-06 | master | 2 |
| `device/legacy/elsa-fw` | 74 | 2020-10-06 | 2021-08-20 | `elsa-es-v3` | 1 |
| `fpga/legacy/elsa-fpga` | 107 | 2020-12-24 | 2022-02-03 | `feature/ES2` | 3 |
| `fpga/legacy/ginny-fpga` | 194 | 2017-07-03 | 2019-07-30 | `300L_310C` | 4 |
| `fpga/legacy/ginny-table` | 96 | 2017-04-12 | 2017-04-12 | master | 4 |
| `fpga/legacy/ginny-renewal` | 87 | 2021-01-21 | 2021-01-21 | master | 3 |
| `fpga/legacy/ash-fpga` | 61 | 2017-08-24 | 2017-08-24 | master | 3 |
| `fpga/legacy/elsa-dump-fpga` | 41 | 2019-02-21 | 2019-02-21 | master | 3 |
| `fpga/legacy/fuji-oem-us-fpga` | 20 | 2022-01-04 | 2022-01-04 | master | 2 |
| `fpga/legacy/charm-fpga` | 12 | 2022-12-12 | 2022-12-12 | master | 2 |
| `fpga/legacy/bf-delay-calculation` | 2 | 2018-03-08 | 2018-03-08 | master | 2 |
| `client/legacy/cuattro-sdk` | 58 | 2018-12-17 | 2018-12-17 | master | 1 |
| `device/legacy/elsa-yocto-bsp` | 60 | 2016-08-17 | 2016-08-17 | master | 8 |
| `server/legacy/dicomcontroller` | 14 | 2017-12-11 | 2017-12-11 | master | 1 |
| `client/legacy/ginny-string-table-converter` | 10 | 2017-07-10 | 2017-07-10 | master | 1 |
| `device/legacy/meta-elsa` | 7 | 2016-07-11 | 2016-07-11 | master | 1 |
| `server/legacy/russia-server` | 3 | 2023-03-31 | 2023-03-31 | master | 2 |
| `web/legacy/sonex-admin-web` | 1 | 2023-01-19 | 2023-01-19 | master | 1 |

`device/legacy/belle-fsbl`·`belle-pmu` 는 **빈 저장소**다(원격에 ref·오브젝트 0건).

## 2. 최근 1년 내 활동은 6건

`moana` · `sonex-framework` · `sonex-app` · `belle-fw` · `sonon-cloud` · `500c-sn-fw`.

제품 축으로 보면 **앱 2계열(Moana·sonex) · 장비 펌웨어 2계열(belle·500C) · 클라우드 1계열**이 동시에 살아 있다. 어느 하나가 다른 하나를 대체하는 구도가 아니다.

## 3. master 는 제품이 아니다

**8개 저장소에서 master 가 실제 개발선보다 뒤처져 있다.** 격차가 가장 큰 것은 `belle-fw`(4년 10개월)·`moana`(4년 5개월)·`500c-sn-fw`(2년 9개월)다.

`ginny-fw` 는 브랜치 29개 중 **6개(21%)만 master 로 병합**됐고, master 최종 커밋(2020-04-17) 이후에도 `ginny-renewal` 브랜치가 2021-07 까지 단독으로 이어졌다. 이 브랜치는 2019-04-24 에 분기해 **한 번도 병합되지 않았다.**

→ **"master 기준 리팩토링" 은 최근 수년치 수정을 조용히 버린다.** 착수 전에 각 저장소의 실제 head 를 확정해야 한다(§1 의 "작업 브랜치" 열).

## 4. 브랜치가 변종 관리 수단이다

인증·국가·고객사·하드웨어 리비전을 브랜치로 영구 분기하는 것이 앱·펌웨어 공통 관행이다.

| 저장소 | 예 |
|---|---|
| `moana` | `310C_China_Certification` · `500L_Cetification` · `Japan_Vet` · `300C_Rusia_Enable_Mmode` · `oem_sphera` · `20201106_Tokopia_SononPet` · `20200121_Laonz_Customizing` · `20191029_아이손_Customizing` |
| `ginny-fw` | `CN_CERT` · `certi` · `china` · `ASH` · `factory` · `aging`/`aging2` · `p11-1` · `ginny-renewal` |
| `belle-fw` | `production-fw` · `production-fw-ver2.0` · `fuji` · `500_integrated` · `T1968-cf-power-integrate` |
| `500c-sn-fw` | `FW_1_1_3_0` ~ `FW_1_1_8_0`(릴리스 라인) · `M0.00.05`(폐기) |

**비용이 실제로 발생했다** — `moana` 최근 커밋에 `HC_RELEASE_TARGET` 미설정 시 qmake 가 hard-error 를 내도록 강제한 것이 있고, 사유는 **M2.03.24 에서 CE/US 빌드가 뒤바뀌어 출하된 사고**다.

## 5. 세대 전환마다 이력이 끊긴다

| 저장소 | commits | 성격 |
|---|---:|---|
| `ginny-fw` | 1,661 | 300 시리즈. 태그 34개, 브랜치 29개 — **펌웨어 개발 이력의 본체** |
| `elsa-fw` | 74 | ginny 에서 파생. 공통 커밋 조상 없음 |
| `belle-fw` | 66 | `"first time (migration elsa-fw repo)"` 커밋으로 시작. **현행 생산 라인** |

`ginny-fw` → `elsa-fw` → `belle-fw` 로 두 번 "새 저장소에 임포트" 가 일어났고 그때마다 이력이 끊겼다. 코드는 이어지는데(경로 공유 175~473개) git 이력은 이어지지 않는다. **회귀 원인 추적이 세대를 넘어가지 않는다.**

## 6. 저자 편중

| 저장소 | 편중 |
|---|---|
| `ginny-fw` | `lyle` 1,225커밋(74%, 2015~2017) → `jacob` 174커밋(2017~2021). **순차 단독 소유** |
| `belle-fw`·`belle-bsp`·`belle-u-boot`·`elsa-fw`·`500c-sn-fw`·`belle-msp` | 전부 `jacob` 단독 (`jacob`/`jacob40` 은 동일인) |
| `belle-kernel` | `jacob` 1 + `OpenEmbedded` 4 — 나머지는 업스트림 임포트 커밋이다 |
| `moana` | 저자명 19개, 별칭·대소문자 병합 시 **13명** — 유일하게 팀 규모 |
| `sonon-cloud` | 8명 (`sungyong` 281) |

**장비 펌웨어 전 계열이 사실상 1인 소유**다. 앱·클라우드만 복수 저자다.

## 7. 제품은 활발히 운영 중이다

Maniphest 조회 기준.

- 최신 태스크 **T9224 (2026-07-20)**
- 2025~2026 태스크 대부분이 `[CS]` 접두어의 실제 고객 지원 건
- `300L`·`500L`·`300C` 가 전 세계 출하 중 — 일본(Tokopia·Aison) · 말레이시아(Vigour Medical) · 싱가포르/인도네시아(Elogio) · 브라질(Sheara) · 이란 · 영국(Orca Medical) · 미국(Healcerion USA) · 캄보디아(CTS) · 국내 다수

CS 이슈가 지목하는 소프트웨어는 **SONON X 앱**(T9153 lag · T9097 기동 불가 · T9008 ID/PW 입력 불가) · **PACS/DICOM**(T9045 · T8807 · T8850) · **측정·모드 버그**(T8777 PW RI 고정 · T8824 PRF 변경 시 B모드 정지) · **Windows 앱**(T8927)이다.

`moana` 의 최근 커밋(측정 회귀 · PACS 업로드 밀림 · FPS 널뜀)이 이 CS 주제와 정확히 겹친다.

## 8. `elsa-yocto-bsp` 는 BSP 가 아니라 repo manifest 다

파일 3개(`ChangeLog`·`README`·`default.xml`)뿐이고 `default.xml` 은 `repo` 도구 매니페스트로 10개 프로젝트를 조합한다.

| 출처 | 프로젝트 |
|---|---|
| upstream 9개 | `poky` · `meta-fsl-arm` · `meta-openembedded` · `fsl-community-bsp-base` · `meta-fsl-arm-extra` · `meta-fsl-demos` · `meta-browser` · `meta-qt5` · `meta-fsl-bsp-release` |
| 힐세리온 자작 1개 | `ME/meta-elsa` |

읽히는 것 셋:

- **Yocto `jethro_4.1.15-1.0.0_ga`** — Yocto 2.0(2015) 계열. i.MX6 세대 빌드 스택이 10년 전 버전에 고정돼 있다
- **`meta-qt5` 포함** — 이 세대 장비 UI 가 Qt5 기반이다
- **원격 호스트가 `phabricator.healcerion.com`** — 현재 호스트 `phab.healcerion.com` 과 다르다. 인스턴스 이전 후 갱신되지 않았으므로 지금 `repo sync` 를 돌리면 실패한다

## 9. HLAB-2487 함의

| 관측 | 함의 |
|---|---|
| 최근 활동 6건이 5개 제품 축에 흩어져 있다 | 리팩토링 대상이 sonex 하나가 아니다. 앱 2계열·펌웨어 2계열·클라우드가 동시에 살아 있다 |
| master 가 8개 저장소에서 뒤처짐 | 착수 전 **각 저장소의 실제 head 확정**이 선행돼야 한다 |
| 브랜치 기반 변종 관리(§4) | cctv 형태로 갈 때 가장 크게 바뀌어야 할 관행. 이미 출하 사고가 발생했다 |
| 세대 전환마다 이력 단절(§5) | 회귀 추적이 세대를 넘어가지 않는다 |
| 장비 펌웨어 전 계열 1인 소유(§6) | 버스 팩터. 지식 이전 비용이 여기 집중된다 |
