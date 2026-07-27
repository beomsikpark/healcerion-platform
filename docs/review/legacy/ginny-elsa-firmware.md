# [범위 밖] ginny·elsa 세대 펌웨어

> **범위 판단**: 300 시리즈는 **단종 모델이므로 HLAB-2487 검토 범위 밖**이다. 이 문서는 참조용 기록이며, 현행 검토 대상은 [../device-firmware.md](../device-firmware.md) 를 본다.
> **남겨두는 이유**: ① `belle-fw` 가 이 계보에서 파생됐고 코드 경로 상당수를 물려받았다 ② **런타임 변종 선택 등 belle 보다 나은 설계가 여기 있다**(§3) ③ 펌웨어 개발 이력 1,661커밋이 여기에만 있다.
> **근거**: 코드 직접 읽기(2026-07-27). `ginny-fw` 는 전 브랜치, `elsa-fw` 는 `origin/elsa-es-v3` 기준.

## 1. 대상

| 저장소 | commits | 최종 | 담당 제품 |
|---|---:|---|---|
| `device/legacy/ginny-fw` | **1,661** | 2021-07-15 (`ginny-renewal`) | 300 시리즈 5종 — `300c`·`300c_hermione`·`300l`·`300mc`·`310c` |
| `device/legacy/elsa-fw` | 74 | 2021-08-20 (`elsa-es-v3`) | 과도기 — `300l`·`500l` 두 세대 혼재 |
| `device/legacy/elsa-yocto-bsp` | 60 | 2016-08-17 | i.MX6 세대 BSP (실체는 `repo` 매니페스트) |
| `device/legacy/meta-elsa` | 7 | 2016-07-11 | i.MX6 Yocto 오버레이 |

## 2. 세대 계보

**`ginny-fw` → `elsa-fw` → `belle-fw`** 이고, 전환마다 **새 저장소로 임포트돼 git 이력이 끊겼다.**

| 구간 | 증거 |
|---|---|
| `ginny-fw` → `elsa-fw` | 공통 경로 175개 중 MD5 동일 76개. **공통 커밋 조상 없음** — rename 이 아니라 파생 |
| `elsa-fw` → `belle-fw` | 경로 473개 공유. `belle-fw` 두 번째 커밋 메시지가 `"first time (migration elsa-fw repo)"` |

`elsa-fw` 는 과도기 산물이다 — 300L·500L 두 세대를 한 트리에 담았다가 500 계열만 `belle-fw` 로 이관되면서 역할이 끝났다. **참조 가치는 이력 추적뿐이다.**

## 3. belle 보다 나은 설계 — 런타임 변종 선택

이 계보에서 가장 중요한 기술적 사실이다.

| | `ginny-fw` | `belle-fw`(현행) |
|---|---|---|
| 변종 선택 | **런타임** | **컴파일 타임** |
| 방법 | `bcd`(Board Config Daemon)가 부팅 시 u-boot 환경변수 `device` 를 읽어 `/usr/share/ginny/<model>/` 선택 | `-D_USING_500L_DEV_`·`-D_USING_SA_DEV_`·`-D_ES3_DEV_` |
| 결과 | **단일 유니버설 이미지가 5개 모델 지원** | 모델당 별도 빌드 |

```c
// bcd/bcd_linked.c — get_boot_env() -> popen("fw_printenv -n device")
if (!ret) sprintf(value, "300C");                     // 미설정 시 기본값
if (strcmp(device_type,"300C")==0) {
    need_eco504 = update_eco504_for_300c(serial_no);  // 시리얼로 보드 리비전 판별
    device = need_eco504 ? DEVICE_300C_hermione : DEVICE_300C;
}
```

**하드웨어 리비전까지 시리얼 번호로 자동 판별한다** — `update_eco504_for_30c()` 가 `H-1412`~`H-1506`(2014-12~2015-06 제조, ECO504 이전 보드)을 `300c_hermione` 설정으로 라우팅한다.

u-boot 환경변수는 공장·필드 전환 시 `scripts/convert.sh` 가 `fw_setenv device $probetype` 로 한 번만 쓴다. 즉 **5개 설정은 빌드 산출물이 아니라 플래시 환경변수 한 줄로 갈린다.**

> **belle 세대는 이 구조를 버리고 컴파일 타임 분기로 되돌아갔다.** 리팩토링에서 런타임 변종 선택을 제안할 때, 외부 사례가 아니라 **사내 선례**를 근거로 쓸 수 있다.

## 4. 런타임 구조

프로세스 5종이 SysV 메시지 큐로 묶인다. `scripts/run.sh`(→`/etc/init.d/ginny`)가 기동한다.

| 프로세스 | 역할 |
|---|---|
| `bcd` | 설정 브로커 + NAND 영속화. 다른 데몬이 `message` 정적 라이브러리로 접근 |
| `sonon` | 메인 스캔 데몬. 스레드 5개(`ctrl`·`data`·`management`·`button`·`pipe`) + 모드별 워커 |
| `deviced` | 온도·배터리 I2C 폴링, 팬 제어 |
| `watchdogd` | 프로세스 생존 감시(alive 카운터) + HW 워치독 |
| `monitord` | **공장 시험 하니스**(TCP 10000). 2017-01 비활성화, 소스 1,686 LOC 잔존 |

**`belle-fw` 가 물려받은 것**: `bcd`·`sonon`·`deviced`·`watchdogd`·`gpio`·`lib` 구조 그대로.
**belle 이 추가한 것**: `image_proc`(온디바이스 영상처리), `modules/`(BLE·WiFi·MSP430·ZynqMP DMA).
**belle 이 버린 것**: `monitord` 전체.

## 5. 신호처리 위치

하드웨어 구성(`doc/spec/us-low-api.md` 의 Doxygen 다이어그램): 호스트 CPU —(EIM/EBI 버스)→ **FPGA XC7A100T** —→ 펄서·ADC **MAX2082 ×4** + Mux **MAX4966A ×8** → 프로브.

- **소프트웨어**: CF 도플러(`lib/cf-doppler.c`, 681 LOC, ARM NEON) · PW 스펙트럼(`sonon/sonon_pw_filter.cpp`, 1,234) · M-mode(`sonon_pw_m_proc.cpp`, 694)
- **FPGA 또는 호스트 앱**: 포락선 검출·스캔 변환·로그 압축이 **트리 어디에도 없다**. 장비는 스캔라인 데이터를 넘길 뿐이고 영상 형성은 다른 곳에서 한다

`belle-fw` 가 `image_proc` 을 추가한 것이 이 경계가 옮겨졌다는 뜻이다(추정 — belle 쪽 확인 필요).

## 6. 필드 롤백은 전체 재플래시다

`ginny_to_hermione/` 에 `downgrade.sh` + 전체 이미지 tar 3종(300c·300l·300mc, 55MB)이 들어 있다. "hermione" 는 ginny 이전 제품·저장소 이름이다(`hermione-fw` 병합 커밋 존재).

```sh
killall -q watchdogd; killall -q sonon; umount /userdata
flash_eraseall /dev/mtd0 ... /dev/mtd9      # 전체 NAND 소거
nandwrite -p /dev/mtd0 ${UBOOT}
nandwrite -p /dev/mtd7 ${KERNEL}
nandwrite -p /dev/mtd8 ${ROOTFS}
mount -t yaffs /dev/mtdblock9 /userdata
# 기술자가 입력한 시리얼로 wlan_ap.default SSID 재작성
```

기술자가 SSH 로 접속해 **유닛 시리얼을 수동 입력**한다. OTA·버전 관리 업그레이드가 아니라 통짜 재플래시이며, **의료기기 필드 서비스 도구로는 얇다.**

## 7. BSP 2건 — i.MX6 세대

### 7.1 `elsa-yocto-bsp` 는 BSP 가 아니다

파일 3개(`ChangeLog`·`README`·`default.xml`)뿐이고 `default.xml` 은 `repo` 매니페스트다. 커밋 60개 중 **58개가 Freescale/NXP upstream 이력**(2013~2016)이고 힐세리온 기여는 마지막 2개다.

`revision="jethro_4.1.15-1.0.0_ga"` — Yocto 2.0(2015) 계열, 커널 4.1.15. 원격 호스트가 구 인스턴스(`phabricator.healcerion.com`)라 **지금 `repo sync` 를 돌리면 실패한다.**

### 7.2 `meta-elsa` 는 bbappend 3개

파일 8개 273줄. 머신은 **i.MX6Q**(`SOC_FAMILY = "mx6:mx6q"`, Cortex-A9, `imx6q-elsa.dtb`). 이미지 레시피 없음.

| bbappend | 내용 |
|---|---|
| `linux-imx_4.1.15.bbappend` | 커널을 사내 `elsa-linux.git` 으로 교체, SRCREV 고정 |
| `u-boot-imx_2015.04.bbappend` | u-boot 을 사내 `elsa-u-boot.git` 으로 교체 |
| `u-boot-imx-mfgtool_2015.04.bbappend` | mfgtool 용, 별도 SRCREV |

### 7.3 이 BSP 는 `elsa-fw` 를 빌드하지 않는다

두 저장소 전체에서 `elsa-fw` 문자열 0건, 애플리케이션 레시피 0건. 타깃 SoC 도 다르다(i.MX6Q Cortex-A9 vs `elsa-fw` 현행 빌드의 ZynqMP aarch64).

`ginny-fw` 도 rootfs 를 만들지 않는다 — 프리빌트 `u-boot.bin`·`kernel.img`·`rootfs.img` 를 `nandwrite` 로 굽고 YAFFS2 로 마운트한다.

## 8. 브랜치·릴리스 관리

브랜치 29개 중 **6개(21%)만 master 로 병합**됐다. 그리고 **`master` 최종 커밋(2020-04-17)이 저장소 실제 최종(2021-07-15 `ginny-renewal`)보다 앞선다** — `ginny-renewal` 은 2019-04-24 에 분기해 한 번도 병합되지 않았다.

| 유형 | 브랜치 |
|---|---|
| 릴리스 라인 | `M1.00.04_PW_M` · `M1.00.11` · `M2.00.00` |
| 인증·국가 | `CN_CERT` · `certi` · `china` |
| 고객사·프로젝트 | `ASH` · `ASH-aging` · `p11-1` |
| 공장·QA | `factory` · `aging` · `aging2` |
| 하드웨어 리프레시 | `ginny-renewal` (최장수 미병합) |
| 티켓별 | `T979` · `T2049` · `T2136` · `T2211-PA-VC` |

태그 34개는 규약이 섞여 있다 — `1.02.01`(초기) → `M1.00.11`(이후) + 접미사 `_aging10`·`_db`·`CN4`·`pp52`·`S300MC_PP`.

**이 관행이 `moana`·`belle-fw` 에도 그대로 이어진다** — 상세 = [../repo-activity.md §4](../repo-activity.md).

## 9. 저자

| 저자 | 커밋 | 기간 |
|---|---:|---|
| `lyle` | **1,225 (74%)** | 2015-04 ~ 2017-11 |
| `Alan YS Lee`(yslee) | 221 | 2015-05 ~ 2017-06 |
| `jacob` | 174 | 2017-03 ~ 2021-07 |
| 기타 3명 | 41 | — |

연도별 커밋: 2015년 449 · 2016년 574 · 2017년 502 · 2018년 30 · 2019년 29 · 2020년 63 · 2021년 8. **2015~2017 에 92%가 몰려 있다.**

## 10. 위생

- **25MB `.gch`**(`system_header/strtk.hpp.gch`) 커밋 — 워킹트리의 22%
- `ginny_to_hermione/*.tar` 55MB — 프리빌트 전체 펌웨어 이미지
- **설정 파일 27쌍이 바이트 동일** — 모델별 config 트리를 복붙으로 유지
- 죽은 빌드 코드: `gpio/app/`(미연결, 존재하지 않는 소스 참조) · `tools/`(CMakeLists 없음) · `monitord/`(2017년 이후 미빌드인데 `watchdogd` 감시 테이블은 여전히 참조)
- 테스트·CI **0건**

## 11. 범위 밖 처리에 따른 열린 질문

**300 시리즈는 단종 판정으로 범위에서 뺐으나, 실측과 긴장이 있다** — [../repo-activity.md §7](../repo-activity.md) 의 Maniphest 조회상 `300L`·`300C` 가 2025~2026 CS 티켓에 계속 등장한다.

가능한 설명:
1. 출하는 계속되나 펌웨어는 동결(수정 없이 재고 소진)
2. `ginny-renewal` 이후 작업이 Phabricator 밖에서 진행

**필드에 남은 장비의 유지보수 책임이 어디에 있는지는 별도 확인 사항**이다. 리팩토링 범위와는 분리해서 다룬다.
