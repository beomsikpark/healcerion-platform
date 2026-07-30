# SoNex 완성 검토

**논제: SoNex 를 원래 개발 목적에 맞게 완성하려면 무엇이 필요한가.**

> **기준일 2026-07-29.** 이전 갈래(`moana` vs `sonex-app` 중 리팩토링 대상 선택)는 전제가 달라져 [legacy/](legacy/) 로 옮겼다.

## 논제

기존 논제는 **"`moana` 와 `sonex-app` 중 무엇을 리팩토링할 것인가"** 였다. 이 질문은 `moana` 가 살아남는다는 가정 위에서만 성립했고, **그 가정이 사라졌다**.

새 논제는 셋이다.

| # | 질문 | 문서 |
|---|---|---|
| 1 | SoNex 의 개발 목적은 무엇이고, **무엇을 만족해야 "완성"인가** | [goal.md](goal.md) |
| 2 | 그 기준 대비 **현재 구현은 어디까지 왔는가** | [gap.md](gap.md) |
| 3 | 완성까지 **무엇을 어떤 순서로** 해야 하는가 | [plan.md](plan.md) |

**심층 분석**

| 주제 | 문서 |
|---|---|
| **렌더링 경계** — 언어별 wrapper 가 수렴하지 않는 기술적 원인과 해소안 | **[rendering-boundary.md](rendering-boundary.md)** |
| **사이버보안 대응** — [review/cybersecurity.md](../review/cybersecurity.md) 실측을 리팩토링 성격(기존 계획에 자리 있음) vs 신규개발 성격(별도 트랙 필요)으로 분리 | **[cybersecurity.md](cybersecurity.md)** |

현행 구조 실측은 [../review/](../review/) 가 SOT 다. 여기는 그 위에서 **목적 대비 판정**을 다룬다.

**실행 계획**

| 트랙 | 문서 | 상태 |
|---|---|---|
| `sonex-framework`(client) — 렌더 경계를 코드 구조로 | [r1/plan.md](r1/plan.md) | 착수 전. ANGLE 은 회수가 아니라 **자체 빌드**로 확보한다(r1 Phase 0-A) — 상위 [plan.md](plan.md) Phase 0-3(배치 회수) 전제는 r1 자체 실측으로 무효화됐다 |
| `belle-fw`(device) | [r2/plan.md](r2/plan.md) | 앱 결정과 무관하게 유효(§아래) |
| Buildroot 도입(device) | [r3/plan.md](r3/plan.md) | 앱 결정과 무관하게 유효(§아래) |

## 전제 셋

**① `moana` 는 SoNex 출시와 동시에 폐기된다.** 힐세리온 CTO 확인(2026-07-29 통화). 따라서 `moana` 리팩토링은 버려질 코드에 대한 투자가 되며, 대상에서 빠진다. **단 이것은 의도에 대한 주장이고, 코드상 미해결 조건이 하나 남아 있다**([goal.md §A2](goal.md) — `moana` 전용 모델 5종).

**② SoNex 의 최대 목적은 `moana` 대체가 아니라 외부 고객사 대상 SDK·ADK 제공이다.** CTO 확인이며, **2023년 개발계획서가 이미 신규 개발 사유로 적어 둔 항목**이다 — *"코드 구조 상 외부 업체의 SDK / ADK 제공 요청 대응 불가 … Framework 또한 QtQML 로 개발되어 있어 외부 제공 시 사용이 어려움"*([../review/SoNex-Requirement/summary.md §2](../review/SoNex-Requirement/summary.md)). 3년 전 창립 사유가 지금도 최우선 목적이다.

**③ 완성 판정 기준이 존재한 적이 없다.** 2023년 계획서의 일정(SDK 2023-11-30 · ADK 2024-02-28)은 **날짜이지 판정 기준이 아니다.** 코드·문서 어디에도 "무엇이 되면 끝인가"가 없다([../review/sonex-app.md §10.6](../review/sonex-app.md)). **끝났는지 판정할 수 없는 일은 끝나지 않는다** — 3년 2개월이 그 결과다.

## 결론 요약

**구조는 계획대로 됐고, 제품화가 비어 있다.**

2023년 설계와 실제 코드를 줄 단위로 대조한 결과, SDK/ADK/APP 3계층 분리·모듈 파이프라인·데이터 모델은 설계대로 구현됐다([../review/SoNex-Requirement/summary.md §14](../review/SoNex-Requirement/summary.md)). 그런데 **그 SDK 를 외부에 실제로 넘길 수 있게 만드는 것들** — 재현 가능한 빌드 · 배포 아티팩트 · 버전 계약 · API 문서 · 라이선스 고지 — 이 전부 없다.

| | 판정 |
|---|---|
| **계층 구조** | 달성 — `sdk/sdk`·`sdk/adk` 경계 유지 |
| **외부 제공 가능성** | **불가** — 고객사가 clone 후 빌드할 수 없다 |

가장 눈에 띄는 것이 ANGLE 이다 — 렌더링 백엔드 선택 자체는 지금도 유효한데(Apple 의 OpenGL ES deprecation 을 Metal 백엔드로 정확히 회피), **바이너리가 저장소에 없고 선언된 경로 세 곳이 서로 다르며 셋 다 존재하지 않는다**([gap.md §3](gap.md)).

**다만 ANGLE 은 원인이 아니라 증상이다.** 원인은 **SDK 책임 범위에 그래픽·UI 레이어가 포함된 것**이고, ANGLE·freetype 재배포 부담과 플랫폼별 결합 4갈래(Windows 901줄)가 거기서 파생된다. 이것이 **언어별 wrapper 가 수렴하지 않는 기술적 원인**이며 목적 1의 최대 장애다 → [rendering-boundary.md](rendering-boundary.md).

→ **따라서 제안은 "리팩토링"이 아니다.** 힐세리온이 2023년에 시작한 것을 **목적대로 끝내는 것**이고, 그 작업 항목이 우연히 리팩토링 항목과 같을 뿐이다.

## 이 결정과 무관한 트랙

앱 선택이 무엇이든 영향받지 않는 것들이다. 뒤집힌 판단이 아니라 **지금도 유효한 실행계획**이라 `r1`과 같은 top-level 에 둔다(2026-07-30, `legacy/r2`·`legacy/r3` 에서 이동) — legacy 안에는 이 트랙에 딸린 배경 문서(`architecture.md`·`assessment.md`·`principles.md`·`emulator-e2e.md` 등)만 남아 있다.

| 트랙 | 위치 | 상태 |
|---|---|---|
| `belle-fw` feature-first 재구성 | [r2/plan.md](r2/plan.md) | 장비 트랙. 앱 결정과 독립 |
| Buildroot `BR2_EXTERNAL` 도입 | [r3/plan.md](r3/plan.md) | 장비 빌드 재현. 즉시 착수 가능 |
| **HC 프로토콜 정본** | [legacy/proof/protocol-sot/](legacy/proof/protocol-sot/) | **이미 만든 실물.** `make` 로 재현되며 장비↔앱 이음매에 그대로 쓰인다 |

## 라이선스 축의 위치

`moana` 폐기로 **Qt·QCustomPlot 라이선스 항목은 소멸한다.** 대신 **재배포 라이선스가 핵심이 된다** — 외부에 넘기는 SDK·ADK 는 서드파티 고지와 재배포 권한이 필수인데 현재 고지 0건이고 CVIE(상용) 재배포 권한이 미확인이다([gap.md §8](gap.md)).

이전 검토 갈래의 문서는 [legacy/](legacy/) 에 있다.
