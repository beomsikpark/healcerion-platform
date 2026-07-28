# 검토 문서 색인

HLAB-2487(힐세리온 SW 리팩토링 검토)의 산출물이다. **미러 소스를 다시 읽는 대신 이 문서들을 먼저 읽는다.**

## 검토 범위

**belle 계열**(500L, ZynqMP)이 대상이다. 300 시리즈(ginny·elsa)는 단종 모델이므로 제외한다.

앱은 **둘 다 범위 안**이다 — `moana`(Qt)가 **완성본이자 SOT** 이고, `sonex`(Flutter)는 **진행 중인 재작성**이다. 본 검토의 논제가 리팩토링 타당성이므로 **이미 진행 중인 재작성을 평가하는 것이 핵심**이다(판단 대기 1번).

| 축 | 범위 안 |
|---|---|
| 장비 | `belle-fw` · `belle-bsp` · `belle-kernel` · `belle-u-boot` · `belle-msp` (+ `belle-fsbl`·`belle-pmu` 빈 저장소) |
| PL(FPGA) | `elsa-fpga` — 이름은 elsa 이나 타깃이 `xczu3cg` 로 belle 의 PL 이다 |
| 앱 | `moana`(Qt, **SOT**) · `sonex-app`+`sonex-framework`(Flutter, **진행 중인 재작성**) |
| 클라우드 | `sonex-cloud-backend` · `sonon-cloud` · `sonex-admin-web` |

## 문서

| 문서 | 내용 |
|---|---|
| **[change-cost.md](change-cost.md)** | **변경 1건의 실제 비용 실측** — 재작업·출하 지연·미도달 커밋. **다른 문서의 "효과" 주장은 전부 여기로 수렴한다.** 논지에 불리한 결과도 그대로 적었다 |
| [belle-hardware.md](belle-hardware.md) | 보드·SoC·QSPI 파티션·PL 인터페이스·주변장치·MSP430 |
| [device-firmware.md](device-firmware.md) | 펌웨어 구조 · 빌드/패키징 · 변종 선택 · HC 프로토콜 |
| [moana-app.md](moana-app.md) | **Qt 앱(SOT)** 구조 · 도메인 기능 · 호스트 SW 3종 대조 |
| [sonex-app.md](sonex-app.md) | **Flutter 재작성** 실측 — 타깃·결합 구조·완성도 · **전환 진척 시계열(§10)** |
| [sonex-architecture.md](sonex-architecture.md) | sonex 에 대해 **힐세리온 자체 문서가 주장하는** 아키텍처 |
| [protocol-device.md](protocol-device.md) | **장비↔앱 HC 프로토콜** — 헤더·opcode 전수·정본 3벌 대조 |
| [protocol-cloud.md](protocol-cloud.md) | **클라이언트↔클라우드** — 엔드포인트 3개·커맨드·인증·보안 |
| [cloud-server.md](cloud-server.md) | 클라우드 2종 구성 · **API 인벤토리** · 인증·권한 · 스키마 |
| [belle-gaps.md](belle-gaps.md) | **없는 것 · 우선순위 · 요청 목록** |
| [repo-activity.md](repo-activity.md) | 저장소 활동성 실측 |
| [dev-environment.md](dev-environment.md) | Phabricator 환경 · 접근 정책 |

## 범위 밖 (`legacy/`)

참조용 기록이다. 검토 대상이 아니다.

| 문서 | 내용 |
|---|---|
| [legacy/ginny-elsa-firmware.md](legacy/ginny-elsa-firmware.md) | 300 시리즈 펌웨어. **런타임 변종 선택 등 belle 보다 나은 설계가 여기 있다** |
| [legacy/ginny-fpga.md](legacy/ginny-fpga.md) | Artix-7 기반 FPGA 계보(ginny·ash·fuji·charm) |
| [legacy/500c-firmware.md](legacy/500c-firmware.md) | 500C. belle 비호환(Socionext 베어메탈)이나 **단종은 아니다** |
| [legacy/misc-legacy-repos.md](legacy/misc-legacy-repos.md) | `cuattro-sdk` · `dicomcontroller` · `russia-server` |

## 문서 규약

- **주장과 사실을 구분한다** — 저장소 설명·PPT·그들 문서는 주장이다. 코드·해시·식별자로 확인한 것만 검증됨으로 적는다
- **증거 차원을 섞지 않는다** — 존재·순서·동일성은 별개다. 동일성은 MD5·IDCODE 로만 확정한다
- 미확인은 미확인으로 남긴다. 각 문서 마지막 절이 그 목록이다
