# Phase 6 — feature 골격 + `device-config` · `power-battery` · `diagnostics` · `probe` · `info` · `network`

> **상태**: 미시작
> **범위**: `features/<name>/{ports,domain,data}` 규약을 확정하고, **가장 작고 얕은 6개 feature** 로 검증한다.
> **선행**: [Phase 5](./phase5-core-layer.md)
> **후행**: [Phase 7](./phase7-feature-scan-split.md) · [Phase 8](./phase8-feature-firmware-process.md) 병렬 가능
> **구조 정본**: ipc-app **ADR-002**·**ADR-011** — `cctv/device/ipc-app/docs/adr/`

---

## 1. 배경

### 1.1 왜 이 6개부터인가

[Phase 7](./phase7-feature-scan-split.md)(scan 4분할)이 r2 최대 위험이므로, **먼저 작은 것으로 `ports/domain/data` 3계층 규약을 세운다** — moana([legacy/r1 Phase 5](../legacy/r1/phase5-feature-worklist-settings.md))와 같은 순서 논리다.

| feature | 현행 | 파일 | LOC |
|---|---|---:|---:|
| `device-config` | `bcd/` | 13 | 3,324 |
| `power-battery` | `deviced/`(2,991) + `modules/msp430_drv` + `tools/max17205.cpp`(629) | | ~3,620 |
| `diagnostics` | `sonon/aging.cpp`(712) + `tools/` 덤프류(`adc_dump.cpp` 723 · `adc_dump_setup.cpp` 603) | | ~2,038 |
| `probe` | `_USING_500L_DEV_` 분기 + `configs/{300l,500l}` | | (분산) |
| `info` | `DEVICE_READ_DEVICE_NAME`·`DEVICE_SPEC_INFO` 등 opcode 처리 | | (분산) |
| `network` | `DEVICE_READ_WIFI_SETUP` 등 | | (분산) |

**공통점**: 전부 [Phase 7](./phase7-feature-scan-split.md)의 실시간 스캔 경로와 **약하게 결합**돼 있다. `sonon_receive_device.cpp`(1,711)가 `DEVICE_*` opcode 20개를 처리하는데, 그중 스캔 무관분(정보·설정·전원)이 이 phase 대상이다.

### 1.2 ADR-011 — domain 에 `#ifdef` 금지

> *"Feature 의 domain 계층은 외부 의존성이 없는 순수 비즈니스 로직만 포함한다 — `#ifdef`, `#if defined()` 등 조건부 컴파일 지시자 사용 금지"*

`probe` feature 가 특히 이 원칙의 시험대다 — 지금 `_USING_500L_DEV_` 로 컴파일 타임에 갈리는 것을 domain 로직(순수 조건 분기)으로 바꿔야 한다. **다만 완전한 런타임화는 [Phase 9](./phase9-runtime-variant.md)** 이고, 이 phase 는 **feature 경계만** 세운다.

### 1.3 목적

1. `features/<name>/{ports,domain,data}` 규약 확정
2. `domain` 유닛테스트 — **belle-fw 최초의 도메인 단위 테스트**
3. 6개 얕은 feature 이관
4. `sonon_receive_device.cpp` 의 20개 opcode 중 스캔 무관분 분리 — [Phase 7](./phase7-feature-scan-split.md) 의 작업량을 줄인다

### 1.4 범위 한계

- **`scan-session`·`scan-b`·`doppler-*`·`mmode` 는 여기서 다루지 않는다** — [Phase 7](./phase7-feature-scan-split.md)
- `_USING_500L_DEV_` 등 매크로를 **제거하지 않는다** — 여기서는 domain 로직으로 감싸기만, 실제 런타임 데이터화는 [Phase 9](./phase9-runtime-variant.md)

---

## 2. 규약

### 2.1 디렉토리 (ADR-002)

```
src/features/<name>/
  ports/
    i_<name>_port.h        인터페이스만
  domain/
    <name>_service.{h,cpp} 순수 로직. core 만 의존. #ifdef 금지(ADR-011)
  data/
    <name>_repository.{h,cpp}  ports 구현. HAL·타 feature 참조 가능
```

### 2.2 의존 규칙 (ADR-001 + ADR-011)

| from → to | 허용 |
|---|---|
| `domain → core` | ✅ |
| `domain → ports` | ✅ |
| `data → domain, ports, core, platforms/hal` | ✅ |
| `domain → data, platforms, 타 feature` | ❌ |
| `domain` 내 `#ifdef` | ❌(ADR-011) |
| `features/A → features/B` | ❌ |

### 2.3 명명

ipc-app 과 동일 — kebab-case 디렉토리, `i_<name>_port.h`, snake_case 파일.

---

## 3. 진행 단계

### Step 6-A. 골격 + 규약

`features/features.cmake` 공통 규칙 + 빈 feature 템플릿 + `tests/unit/features/` + `make test-unit` 신설. `make check-layers` 에 ADR-011 규칙(`domain` 내 `#ifdef` grep) 추가.

### Step 6-B. `device-config`

| # | 작업 |
|---|---|
| B-1 | `ports/i_config_store_port.h` — [Phase 3](./phase3-platform-hal.md)에서 판단 보류했던 것을 여기서 확정 |
| B-2 | `domain/device_config_service` — `bcd`(3,324)의 설정 검증·기본값 규칙 |
| B-3 | `data/config_repository` — 파일 I/O(`core/config` 경유) |
| B-4 | `tests/unit/features/device-config/` |

### Step 6-C. `power-battery`

| # | 작업 |
|---|---|
| C-1 | `deviced/`(2,991) + MSP430 연동 + `tools/max17205.cpp`(629, [Phase 3-D4](./phase3-platform-hal.md)에서 예약된 것) 통합 |
| C-2 | `ports/i_power_port.h` — 배터리 상태·온도 조회 |
| C-3 | `domain/power_service` — 퓨얼게이지 판독값 해석, 임계값 판정 |
| C-4 | `data/power_repository` — I2C HAL 경유(`i_i2c_port`) |
| C-5 | belle-msp(별도 저장소, MSP430 자체 펌웨어)와의 경계 명시 — **이 feature 는 호스트 측만** |

### Step 6-D. `diagnostics`

| # | 작업 |
|---|---|
| D-1 | `sonon/aging.cpp`(712, 별도 `main`) — 내구시험 |
| D-2 | `tools/adc_dump.cpp`(723)·`adc_dump_setup.cpp`(603) — ADC 덤프 |
| D-3 | **[Phase 1](./phase1-regression-baseline.md) 의 하니스와 연동** — `lib/test/` 확장분(B·PW·M)이 궁극적으로 이 feature 의 `domain` 유닛테스트가 될 수 있는지 검토 |

### Step 6-E. `probe`

| # | 작업 |
|---|---|
| E-1 | `domain/probe_service` — 프로브 타입 판별 로직을 순수 함수로. **입력은 `core/entities` 의 프로브 스펙 타입**(Phase 5-C) |
| E-2 | `_USING_500L_DEV_` 매크로가 지금 결정하는 것을 **domain 로 감싸되 매크로 자체는 유지**(ADR-011 완전 준수는 Phase 9) |
| E-3 | `configs/{300l,500l}` 을 `data/` 의 로드 대상으로 |

### Step 6-F. `info` · `network`

| # | 작업 |
|---|---|
| F-1 | `sonon_receive_device.cpp` 의 `DEVICE_READ_DEVICE_NAME`·`DEVICE_SPEC_INFO`·`DEVICE_TIME_SYNC` → `features/info` |
| F-2 | `DEVICE_READ_WIFI_SETUP` 등 → `features/network` |
| F-3 | opcode 20개 중 이 두 feature 로 간 것과 [Phase 7](./phase7-feature-scan-split.md)에 남는 것을 표로 확정 |

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | feature 간 참조 | `grep -rn '#include "features/' src/features/{device-config,power-battery,diagnostics,probe,info,network}` | 자기 것 외 0줄 |
| 4.2 | **domain `#ifdef` 없음(신규 코드 한정)** | `grep -rn '#ifdef\|#if defined' src/features/*/domain/` | 0건(단, `probe` 의 기존 매크로 유지분은 예외로 표시) |
| 4.3 | HAL 경유 | `power-battery`·`device-config` 가 HAL 직접 include, `open()` 직접 호출 없음 | ✓ |
| 4.4 | 유닛 테스트 | `make test-unit` | 6 feature 전부 존재 |
| 4.5 | PC/실장비 빌드 | 양쪽 | exit 0 |
| 4.6 | **동작 불변** | `make test-golden` + 배터리·온도 표시 확인 | 통과 |
| 4.7 | 계층 검사 | `make check-layers` | exit 0 |

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`power-battery` 판독 오류** | 배터리 상태 오판은 안전 문제 | 4.6 에 배터리 표시 확인 명시. 골든에 임계값 케이스 포함 |
| `probe` 의 ADR-011 완전 준수가 이 phase 에서 안 된다 | 목표 미달로 보일 수 있다 | **의도된 단계적 접근.** E-2 주석대로 완전한 매크로 제거는 Phase 9 |
| opcode 20개 분류가 애매 | `info`/`network`/Phase 7 경계 혼란 | F-3 표를 **먼저 만들고** 착수. 애매한 것은 Phase 7 에 남긴다(과분류보다 안전) |
| `diagnostics` 가 aging test 인프라를 건드려 내구시험 데이터가 끊긴다 | 품질 검증 공백 | D-1 이관 후 기존 aging 로그 포맷 유지 확인 |

---

## 6. cross-reference

- [plan.md §2.4·§4](./plan.md)
- ipc-app **ADR-002**(feature 내부 3계층) · **ADR-011**(domain `#ifdef` 금지) — `cctv/device/ipc-app/docs/adr/`
- [../legacy/r1/phase5-feature-worklist-settings.md](../legacy/r1/phase5-feature-worklist-settings.md) — moana 의 같은 성격 phase(작은 것부터)
- [phase9-runtime-variant.md](./phase9-runtime-variant.md) — `probe` 의 완전한 런타임화
