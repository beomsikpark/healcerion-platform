# Phase 9 — 컴파일 타임 변종 → 런타임 설정 · 단일 유니버설 이미지

> **상태**: 미시작
> **범위**: `_USING_500L_DEV_` 외 5개 매크로를 `core/entities` 데이터로. 시리얼 번호 보드 리비전 판별 복원.
> **선행**: [Phase 5](./phase5-core-layer.md)(`core/entities` 그릇) 뒤 착수 가능, [Phase 7](./phase7-feature-scan-split.md) 뒤 완료
> **근거**: [principles.md §8·§9](../legacy/principles.md) — **`ginny-fw` 가 이미 런타임 선택이었다.**

---

## 1. 배경

### 1.1 실측

| 매크로 | 파일 | 출현 | 의미 |
|---|---:|---:|---|
| **`_USING_500L_DEV_`** | **12** | **57** | 500L 프로브 |
| `_USING_SA_DEV_` | 7 | 11 | 합성개구 수신 |
| `_ES3_DEV_` | 2 | 7 | ES3 보드 리비전 |
| `_CF_SAMPLE_40M_` | 5 | 7 | CF 40MHz 샘플링 |
| `_USING_B_CONVEN_DEV_` | 1 | 2 | **비활성**(주석 처리, `b_conventional.cpp` 컴파일 제외) |
| `_LINEAR_ARRAY` · `_MSPLIB_` | 0 | 0 | [Phase 0-C2](./phase0-hygiene-protocol-sot.md)에서 이미 제거됨 |

`configs/300l/` 이 트리에 남아 있으나 현재 조합으로는 **도달 불가능한 죽은 데이터**([Phase 0-C3](./phase0-hygiene-protocol-sot.md)에서 보류 처리됨 — 여기서 되살아난다).

### 1.2 이전 세대는 런타임이었다

[principles.md §8](../legacy/principles.md):

| | `ginny-fw`(300 시리즈) | 현행 belle |
|---|---|---|
| 변종 선택 | **런타임** — u-boot 환경변수로 5개 모델 선택, **시리얼로 보드 리비전 자동 판별** | 컴파일 타임 |
| 결과 | 단일 유니버설 이미지 | 모델당 별도 빌드 |

**되살리는 것이다.** cctv 관행이 아니라 사내 `ginny-fw` 가 근거다.

### 1.3 belle 은 moana 보다 규모가 작지만 질이 다르다

[legacy/r1 Phase 10](../legacy/r1/phase10-runtime-variant.md) 의 moana `HC_SONON_500L`(81파일 556곳)에 비하면 belle 은 작다(12/57). 그러나:

- **`_ES3_DEV_` 는 보드 리비전** — moana 에는 없는 축. FPGA·AFE 하드웨어 세대 차이일 가능성이 높아 **더 신중해야 한다**
- **`_USING_SA_DEV_`(합성개구)는 수신 알고리즘 자체를 바꾼다** — 단순 파라미터 차이가 아니다

### 1.4 목적

1. 모델·보드 리비전 스펙을 **데이터**로
2. **시리얼 번호 기반 보드 리비전 자동 판별** 복원(ginny-fw 방식)
3. 단일 유니버설 이미지

### 1.5 범위 한계

- `_USING_B_CONVEN_DEV_`(비활성 코드) 되살림 여부는 **힐세리온 판단**([Phase 0-C5](./phase0-hygiene-protocol-sot.md)에서 이미 유보)
- **300 시리즈** 등 단종 라인 지원 복원은 범위 밖. **`500C` 는 단종이 아니므로 이 사유로 제외하지 않는다**(2026-07-29 정정) — 제외 사유는 **belle 과 코드를 공유하지 않는 별도 계통**(Socionext 베어메탈)이라는 것이다

---

## 2. 대상별 처리

| 매크로 | 처리 | 목표 |
|---|---|---|
| `_USING_500L_DEV_`(12/57) | 프로브 스펙 데이터 | `core/entities/probe` |
| `_USING_SA_DEV_`(7/11) | **수신 알고리즘 선택** — 데이터가 아니라 전략 패턴에 가까울 수 있다 | `features/scan-b/domain` 의 전략 인터페이스 |
| `_ES3_DEV_`(2/7) | **보드 리비전 판별** | `core/entities/board` — 시리얼 기반 |
| `_CF_SAMPLE_40M_`(5/7) | 샘플링 파라미터 | `core/entities/probe` |
| `_USING_B_CONVEN_DEV_`(1/2) | **범위 밖** — 힐세리온 판단 대기 | — |

### 2.1 `_USING_SA_DEV_` 은 단순 데이터화가 아닐 수 있다

**여기서 주의가 필요하다.** SA(합성개구) 수신은 B_CONVEN(컨벤셔널) 수신과 **알고리즘 자체가 다르다** — 파라미터 차이가 아니라 서로 다른 신호처리 경로다. `_USING_B_CONVEN_DEV_` 가 지금 비활성인 것도 이 축과 관련 있어 보인다.

| 안 | 내용 |
|---|---|
| A. 데이터 플래그 | `probe` 스펙에 `receive_mode: sa \| conventional` 필드. domain 이 분기 |
| **B. 전략 패턴**(권장) | `features/scan-b/domain/i_receive_strategy.h` — SA/Conventional 구현을 각각 클래스로. `probe` 스펙이 어느 전략을 쓸지 지시 |

**B 가 ADR-011(domain `#ifdef` 금지)에 부합한다.** 단순 데이터 플래그로는 두 알고리즘이 결국 `if/else` 로 남아 domain 순수성이 흔들린다.

### 2.2 시리얼 → 보드 리비전 판별

`ginny-fw` 방식 복원:

| # | 필요 요소 |
|---|---|
| 1 | 시리얼 번호를 읽는 경로 — EEPROM 또는 기존 `deviced`/`i_i2c_port` 경유 |
| 2 | 시리얼 → 리비전 매핑 테이블(데이터) |
| 3 | `_ES3_DEV_` 가 지금 담당하는 하드웨어 차이가 **정확히 무엇인지 먼저 확인** — FPGA 레지스터 맵 차이인지, AFE 채널 수 차이인지 |

> **`_ES3_DEV_` 는 [Phase 3](./phase3-platform-hal.md) 의 HAL 구현(`platforms/zynqmp`)과 맞물린다.** 보드 리비전이 다르면 레지스터 주소가 달라질 수 있으므로, **HAL 어댑터 자체가 리비전별로 갈릴 가능성**을 착수 시 확인한다.

---

## 3. 진행 단계

### Step 9-A. `_USING_500L_DEV_` → 데이터

| # | 작업 |
|---|---|
| A-1 | 12파일 57곳을 읽어 차이 목록 작성 |
| A-2 | `core/entities/probe` 스펙 정의 — 현행 빌드가 내는 값을 **그대로 옮겨 적는다**(설계하지 않는다, [principles.md §3](../legacy/principles.md)) |
| A-3 | `#ifdef` → 스펙 조회로 치환. 파일별 골든 대조 |

### Step 9-B. `_CF_SAMPLE_40M_` → 데이터

같은 방식. `doppler-cf` feature([Phase 7-E](./phase7-feature-scan-split.md))와 연계.

### Step 9-C. `_USING_SA_DEV_` → 전략 패턴

| # | 작업 |
|---|---|
| C-1 | SA/Conventional 두 경로의 실제 차이를 문서화 |
| C-2 | `i_receive_strategy.h` 설계 |
| C-3 | `scan-b` feature([Phase 7-D](./phase7-feature-scan-split.md))의 `domain` 에 두 구현 배치 |
| C-4 | `_USING_B_CONVEN_DEV_` 비활성 코드를 이 구조 안에 넣을지 힐세리온에 확인 |

### Step 9-D. `_ES3_DEV_` → 보드 리비전 판별

| # | 작업 |
|---|---|
| D-1 | ES3 가 담당하는 실제 하드웨어 차이 확인(§2.2) |
| D-2 | 시리얼 판독 경로 확인/구현 |
| D-3 | HAL 어댑터가 리비전별로 갈리는지 확인 — 갈리면 `platforms/zynqmp/` 안에 리비전 서브디렉토리 |
| D-4 | `core/entities/board` 스펙 |

### Step 9-E. `configs/{300l,500l}` 런타임 로드

[Phase 0-C3](./phase0-hygiene-protocol-sot.md)에서 보류했던 `300l` 데이터의 처리를 여기서 확정 — **런타임 선택이 되면 300l 도달이 다시 가능**해지므로, 단종 라인 지원을 실제로 켤지는 **힐세리온 판단**(범위 밖 원칙과 별개로 확인 필요).

### Step 9-F. 단일 이미지 빌드

| # | 작업 |
|---|---|
| F-1 | Buildroot config 에서 모델별 빌드 변형 제거 |
| F-2 | 부팅 시 시리얼 판독 → 스펙 로드 → 정상 동작 확인 |

---

## 4. 검증

**이 phase 는 동작을 바꾸므로 판정이 다르다.**

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | **모델별 동등성** | 500L 등 각 모델에서 이전(`#ifdef`) vs 신(데이터) 골든 대조 | 전부 일치 |
| 4.2 | **SA/Conventional 동등성** | 두 경로 각각 골든 대조 | 일치 |
| 4.3 | 매크로 제거 | `grep -rn '_USING_500L_DEV_\|_USING_SA_DEV_\|_ES3_DEV_\|_CF_SAMPLE_40M_' src/` | 0건(테스트/호환 코드 제외) |
| 4.4 | 시리얼 판별 | 알려진 시리얼로 올바른 리비전 인식 | ✓ |
| 4.5 | **미인식 시리얼 처리** | 알 수 없는 시리얼 | **안전한 거부**. 오동작 금지 — 초음파 파라미터 오설정은 안전 문제 |
| 4.6 | 모델 추가 비용 | 가상 모델 데이터 1건 추가 | 코드 변경 0줄 |
| 4.7 | 단일 이미지 | 빌드 산출물 수 | **1개**(중국 인증 등 규제 예외 있으면 명시) |
| 4.8 | PC/실장비 빌드 | 양쪽 | exit 0 |
| 4.9 | `make test-golden` | | 통과 |

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`_USING_SA_DEV_` 을 단순 데이터로 잘못 처리한다** | domain 에 `#ifdef` 잔존(ADR-011 위반) 또는 알고리즘 오작동 | §2.1 — **전략 패턴으로.** 착수 전 두 경로의 실제 코드 차이를 먼저 diff |
| **`_ES3_DEV_` 가 HAL 과 얽혀 있다** | Phase 3 산출물 재작업 필요 | D-3 에서 확인. 얽혀 있으면 **Phase 3 로 되돌아가 리비전 서브디렉토리 추가** |
| 미인식 시리얼에서 기본값으로 동작 | 안전 문제 — 초음파 출력 오류 | 4.5 — 반드시 거부. 폴백 금지 |
| **시리얼 판독 하드웨어 경로가 belle 에 없다**(ginny-fw 전용 기능이었을 가능성) | D-2 가 막힌다 | 확인 후 없으면 **소프트웨어 설정(펌웨어 업그레이드 시 명시적 지정)으로 대체** — 완전한 자동 판별을 포기하되 컴파일 타임 분기는 제거 |
| `configs/300l` 되살리기가 단종 라인 지원 재개로 오인됨 | 범위 오해 | E — **데이터 구조 정리일 뿐 단종 라인 부활이 아님을 명시**. 실제 활성화는 힐세리온 결정 |

---

## 6. 이 phase 가 닫는 것

| [plan.md §5](./plan.md) 판정 | 기여 |
|---|---|
| 10. 변종 | 모델 추가 = 데이터 1건, 아티팩트 1개 |
| 3. domain 순수성 | `_USING_SA_DEV_` 의 `#ifdef` 제거로 ADR-011 완전 준수 |

그리고 [architecture.md §6.2](../legacy/architecture.md)·[legacy/r1 Phase 10](../legacy/r1/phase10-runtime-variant.md)과 함께 **장비·앱 양쪽에서 "모델 추가 = 데이터 1건" 이 성립**한다.

---

## 7. cross-reference

- [plan.md §1.7·§4](./plan.md)
- [principles.md §8·§9](../legacy/principles.md)
- [../legacy/r1/phase10-runtime-variant.md](../legacy/r1/phase10-runtime-variant.md) — moana 의 대응 phase
- [phase3-platform-hal.md](./phase3-platform-hal.md) — `_ES3_DEV_` 와 HAL 의 관계
- [phase7-feature-scan-split.md](./phase7-feature-scan-split.md) — `_USING_SA_DEV_` 전략 패턴의 배치처
- [phase0-hygiene-protocol-sot.md §2 Step 0-C3](./phase0-hygiene-protocol-sot.md) — `configs/300l` 보류의 재확정
