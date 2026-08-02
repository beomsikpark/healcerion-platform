# 검토 문서 색인

HLAB-2487(힐세리온 SW 리팩토링 검토)의 산출물이다. **미러 소스를 다시 읽는 대신 이 문서들을 먼저 읽는다.**

## 검토 범위

**belle 계열**(500L, ZynqMP)이 대상이다. 300 시리즈(ginny·elsa)는 단종 모델이므로 제외한다.

> **전제 변경 (2026-07-29, 힐세리온 CTO 통화)**: `moana` 는 **SoNex 출시와 동시에 폐기** 예정이고, SoNex 의 최우선 목적은 moana 대체가 아니라 **외부 고객사 대상 SDK·ADK 제공**이다. 이에 따라 검토 논제가 "둘 중 무엇을 리팩토링할 것인가"에서 **"SoNex 를 목적대로 완성하려면 무엇이 필요한가"** 로 바뀌었다 — [../refactoring/](../refactoring/).
>
> **이 문서 갈래(`review/`)의 내용은 그대로 유효하다.** 여기는 판단이 아니라 **코드 실측**이며, 전제가 바뀌어도 측정값은 변하지 않는다. 바뀌는 것은 측정값의 해석이고 그것은 `refactoring/` 소관이다.

앱은 **둘 다 범위 안**이다. `moana`(Qt)는 폐기 예정이나 **기능 정본(SOT)** 으로서 범위에 남는다 — SoNex 가 무엇을 대체해야 하는지가 moana 로 정의되기 때문이다. `sonex`(Flutter)는 **완성 대상**이다.

| 축 | 범위 안 |
|---|---|
| 장비 | `belle-fw` · `belle-bsp` · `belle-kernel` · `belle-u-boot` · `belle-msp` (+ `belle-fsbl`·`belle-pmu` 빈 저장소) |
| PL(FPGA) | `elsa-fpga` — 이름은 elsa 이나 타깃이 `xczu3cg` 로 belle 의 PL 이다 |
| 앱 | `moana`(Qt, **기능 SOT · 폐기 예정**) · `sonex-app`+`sonex-framework`(Flutter, **완성 대상**) |
| 클라우드 | `sonex-cloud-backend` · `sonon-cloud` · `sonex-admin-web` |

## 문서

| 문서 | 내용 |
|---|---|
| **[change-cost.md](change-cost.md)** | **변경 1건의 실제 비용 실측** — 재작업·출하 지연·미도달 커밋. **다른 문서의 "효과" 주장은 전부 여기로 수렴한다.** 논지에 불리한 결과도 그대로 적었다 |
| [belle-hardware.md](belle-hardware.md) | 보드·SoC·QSPI 파티션·PL 인터페이스·주변장치·MSP430 |
| [device-firmware.md](device-firmware.md) | 펌웨어 구조 · 빌드/패키징 · 변종 선택 · HC 프로토콜 · **애플리케이션 내부(스레드·커맨드 파이프라인·Web/BLE 서비스 계통)** |
| [500c-firmware.md](500c-firmware.md) | `500c-sn-fw`(Socionext 베어메탈, belle 비호환·단종 아님). **범위가 축별로 갈린다**: 펌웨어 축 제외 / 클라이언트 축 포함 — **500C·500P 공용 펌웨어**이며 이미 SoNex 확정 모델 범위에 포함됨([gap.md A2](../refactoring/gap.md)) |
| [500c-hardware.md](500c-hardware.md) | `500c-sn-fw`·`charm-fpga` 실측 — **Efinix Titanium FPGA**(UDL 가속기) · SPI NOR 32MB 맵 · 프로브 3-SKU 가 공장 플래시 설정으로 갈리는 구조(자동인식 아님) |
| [moana-app.md](moana-app.md) | **Qt 앱(SOT)** 구조 · 도메인 기능 · 호스트 SW 3종 대조 |
| **[sonex-framework.md](sonex-framework.md)** | **SDK·ADK 코드베이스 실측** — 계층·공개계약·렌더링·장치통신·빌드·서드파티. **리팩토링 수정 대상의 SOT** |
| [sonex-app.md](sonex-app.md) | **Flutter 재작성** 실측 — 타깃·결합 구조·완성도 · **전환 진척 시계열(§10)** |
| **[client-database.md](client-database.md)** | **단말 로컬 DB 실측** — moana·ADK·sqflite **저장 스택 3벌**의 테이블·컬럼 전수, 이중 저장(SOT 분열), 질의 생성·마이그레이션·트랜잭션 처리 방식. moana↔ADK DDL **93컬럼 차이 0** |
| [legacy/sonex-rendering.md](legacy/sonex-rendering.md) | **렌더링 계층 실측** — ANGLE·GLES2 스택 · 플랫폼별 GL 경계 4종 · 스캔변환 수학 대조 · 헤더 4벌 표류 |
| [sonex-architecture.md](sonex-architecture.md) | sonex 에 대해 **힐세리온 자체 문서가 주장하는** 아키텍처 |
| [SoNex-Requirement/summary.md](SoNex-Requirement/summary.md) | **2023년 SoNex 개발계획서·설계서·블록다이어그램·인터페이스 명세** 4건 분석 — 계획 대 실제 구현 대조 |
| [protocol-device.md](protocol-device.md) | **장비↔앱 HC 프로토콜** — 헤더·opcode 전수·정본 3벌 대조 |
| [protocol-cloud.md](protocol-cloud.md) | **클라이언트↔클라우드** — 엔드포인트 3개·커맨드·인증·보안 |
| [cloud-server.md](cloud-server.md) | 클라우드 2종 구성 · **API 인벤토리** · 인증·권한 · 스키마 |
| [belle-gaps.md](belle-gaps.md) | **없는 것 · 우선순위 · 요청 목록** |
| **[cybersecurity.md](cybersecurity.md)** | **식약처 사이버보안 가이드라인 35개 요구사항 대비 belle·sonex 실측** — 인증·전송암호화·업데이트서명 검증 상태, 하드코딩 비밀정보 전수, 결합 공격 경로 |
| [repo-activity.md](repo-activity.md) | 저장소 활동성 실측 |
| [dev-environment.md](dev-environment.md) | Phabricator 환경 · 접근 정책 |

## 범위 밖 (`legacy/`)

참조용 기록이다. 검토 대상이 아니다.

| 문서 | 내용 |
|---|---|
| [legacy/ginny-elsa-firmware.md](legacy/ginny-elsa-firmware.md) | 300 시리즈 펌웨어. **런타임 변종 선택 등 belle 보다 나은 설계가 여기 있다** |
| [legacy/ginny-fpga.md](legacy/ginny-fpga.md) | Artix-7 기반 FPGA 계보(ginny·ash·fuji·charm) |
| [legacy/misc-legacy-repos.md](legacy/misc-legacy-repos.md) | `cuattro-sdk` · `dicomcontroller` · `russia-server` |

## 문서 규약

- **주장과 사실을 구분한다** — 저장소 설명·PPT·그들 문서는 주장이다. 코드·해시·식별자로 확인한 것만 검증됨으로 적는다
- **증거 차원을 섞지 않는다** — 존재·순서·동일성은 별개다. 동일성은 MD5·IDCODE 로만 확정한다
- 미확인은 미확인으로 남긴다. 각 문서 마지막 절이 그 목록이다
