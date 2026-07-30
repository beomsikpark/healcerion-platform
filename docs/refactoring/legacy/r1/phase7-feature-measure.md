# Phase 7 — `measure`

> **상태**: 미시작
> **범위**: `app/Measure` 50파일 12,689 LOC 를 `features/measure/{domain,data,ports}` 로. `Scan → Measure` 25건을 port 경유로.
> **선행**: [Phase 5](./phase5-feature-worklist-settings.md)
> **병렬**: [Phase 6](./phase6-feature-patient-dicom-cloud.md) · [Phase 9](./phase9-feature-ambulance-ble.md)
> **후행**: [Phase 8](./phase8-feature-scan-split.md)

---

## 1. 배경

### 1.1 이 feature 는 구조가 이미 좋다

`Measure/` 50파일이 **측정 도구별로 이미 갈려 있다.**

| 도구 | 파일 | LOC |
|---|---|---:|
| `MeasureDDH` | 2 | 1,948 |
| `MeasureObject`(공통 베이스) | 2 | 2,094 |
| `MeasureConverter`(단위·좌표 변환) | 2 | 1,257 |
| `MeasureLengthBVF` · `MeasureBloodVolumeFlow` | 4 | 1,092 |
| `MeasureTrace` · `MeasureLength` · `MeasureRectangle` · `MeasureEllipse` · `MeasurePoint` · `MeasureAngle` · `MeasureText` | 14 | 3,434 |
| **모드 특화** — `*M`(M-mode) · `*PW`(PW-mode), §2 목표배치의 11개 도구 | 22 | 2,488 |
| `MeasureUtilty`·`MeasureUtility`·`MeasureSinglePoint` | 4 | 376 |

**분할이 파일 이동에 가깝다.** [Phase 8](./phase8-feature-scan-split.md) 의 `Scan/`(78파일 한 덩어리)과 대조적이다.

> **적대적 검증으로 재작성(2026-07-29)** — 구판은 이 표를 14/2,822·20/1,940·3/376 으로 적어 §2 목표배치(11개 도구=22파일)와 자체 모순됐고 합도 12,689 에 못 미쳤다. 위 값은 실측 재집계이며 7행 합계(50파일·12,689 LOC)와 정확히 일치한다.

> `MeasureUtilty.cpp`(오타) 와 `MeasureUtility.h` 가 공존한다 — 파일명 규약 전환([Phase 4-F](./phase4-composition-root-presentations.md))에서 함께 정리된다.

### 1.2 그런데 계산과 UI 가 붙어 있다

| 파일 | LOC | 위치(Phase 4 이후) |
|---|---:|---|
| `Scan/MeasureView.cpp` | 3,389 | `presentations/qt/features/scan/` |
| `Scan/MeasureViewPWM.cpp` | 1,381 | 〃 |
| `Scan/MeasureView.h` · `MeasureViewPWM.h` | 1,037 | 〃 |

**측정 UI 가 `Measure/` 가 아니라 `Scan/` 에 있다.** 그래서 `Scan → Measure` 25건이 나온다. 이 phase 는 그 사이를 port 로 가른다.

### 1.3 임상 계산이라 회귀 위험이 특별하다

[../../review/moana-app.md §9](../../review/moana-app.md) 실측 — 최근 60커밋에서 **측정·리뷰 회귀가 최대 군집**이다.

- VOL(BloodVolumeFlow) 측정값이 모드 전환 시 사라짐
- 듀얼 M-mode 에서 Length 도구 누락
- 캡처·리뷰 시 GL 좌표 불일치

**즉 이 영역은 지금도 불안정하다.** 구조 변경 전에 골든이 반드시 있어야 하고, 그것이 [Phase 1-C](./phase1-regression-baseline.md) 의 "측정값" 항목이다.

그리고 **DDH(발달성 고관절 이형성증) · BVF(혈류량) 는 임상 판독에 쓰이는 계산**이다. 값이 달라지면 진단이 달라진다. **허용오차를 0 으로 둔다** — 렌더링과 달리 부동소수 오차를 허용할 근거가 없다.

### 1.4 목적

1. `features/measure/{domain,data,ports}` — **계산을 UI 에서 완전히 분리**
2. `Scan → Measure` 25건을 port 경유로
3. **측정 계산 유닛 테스트** — 지금 회귀가 가장 잦은 영역에 자동 판정을 놓는다
4. 모드 특화(`*M`·`*PW`)를 [Phase 8](./phase8-feature-scan-split.md) 이 재분배할 수 있는 형태로 유지

### 1.5 범위 한계

- **계산식을 바꾸지 않는다.** 위치만
- 모드 특화 파일을 **`measure` 안에 모드 하위 디렉토리로 유지**한다. Phase 8 에서 각 모드 feature 로 옮길지 여기 둘지 확정
- 측정 UI(캘리퍼 드래그 등)를 재설계하지 않는다

---

## 2. 목표 배치

```
src/features/measure/
  domain/
    measure_object.{h,cpp}          공통 베이스 (현 MeasureObject 2,094)
    measure_converter.{h,cpp}       단위·좌표 변환 (현 MeasureConverter 1,257)
    tools/
      length.{h,cpp}  angle  ellipse  trace  rectangle  point  text
      ddh.{h,cpp}                   1,948 — 임상 계산
      blood_volume_flow.{h,cpp}     BVF
      length_bvf.{h,cpp}
    modes/
      m/    length_m  distance_m  text_m  time_m  heartrate_m
      pw/   distance_pw  text_pw  time_pw  heartrate_pw  velocity_pw  velocity_diff_pw
  data/
    measure_repository.{h,cpp}      측정 결과 저장 (core/db)
  ports/
    i_measure_data_port.h           결과 영속화
    i_scan_geometry_port.h          ★ 스캔 기하 정보 조회 — Scan 결합을 끊는 인터페이스

src/presentations/qt/features/measure/
  qt_measure_view.{h,cpp}           현 Scan/MeasureView 3,389
  qt_measure_view_pwm.{h,cpp}       현 Scan/MeasureViewPWM 1,381
```

**`i_scan_geometry_port.h` 가 이 phase 의 핵심 산출물이다.** 측정은 픽셀 좌표를 물리 단위(mm·cm/s)로 바꾸려면 **깊이·PRF·스케일** 을 알아야 하고, 그 정보가 지금은 `Scan` 객체를 직접 잡아서 온다. 이것을 인터페이스로 만들면 **측정 계산이 스캔 없이 테스트 가능**해진다.

---

## 3. 진행 단계

### Step 7-A. `i_scan_geometry_port` 설계

**먼저 `Scan → Measure` 25건과 `Measure` 안의 `Scan` 참조를 읽어 필요한 정보 목록을 확정한다.**

| 후보 | 출처 |
|---|---|
| 깊이 스케일(픽셀 ↔ mm) | `Scan/ScreenAdjustConverter` · `SideRulerView` |
| 속도 스케일(픽셀 ↔ cm/s) | PW 스펙트럼 |
| 시간축 스케일 | M-mode · PW |
| 현재 모드 | `core/entities/scan_mode` (Phase 3 에서 이동) |
| 프로브 스펙 | `core/entities/model` (Phase 3 에서 이동) |

> **`core/entities` 로 이미 나간 것은 port 가 필요 없다** — 직접 include 한다(ADR-001: `features → core` 허용). port 는 **런타임 상태**에만 필요하다.

### Step 7-B. `domain/` 이관

| # | 작업 |
|---|---|
| B-1 | `MeasureObject`(2,094) · `MeasureConverter`(1,257) → `domain/` |
| B-2 | 도구 7종 → `domain/tools/` |
| B-3 | `MeasureDDH`(1,948) · `MeasureBloodVolumeFlow` · `MeasureLengthBVF` → `domain/tools/` |
| B-4 | 모드 특화 20파일 → `domain/modes/{m,pw}/` |
| B-5 | `Scan` 직접 참조를 `i_scan_geometry_port` 경유로 |

### Step 7-C. UI 분리

`Scan/MeasureView`(3,389) · `MeasureViewPWM`(1,381) 은 [Phase 4-B8](./phase4-composition-root-presentations.md) 에서 `presentations/qt/features/scan/` 로 갔다. **여기서 `presentations/qt/features/measure/` 로 재배치**하고 `domain` 만 보게 한다.

`Scan*Measure*.qml` 12개(`ScanMeasureView` · `ScanSubMeasureView` · `ScanMMeasureView` · `ScanSubMMeasureView` · `ScanPWMeasureView` · `ScanSubPWMeasureView` · `ScanMeasureDDHView` · `ScanSubMeasureDDHView` · `ScanMeasureFetalView` · `ScanSubMeasureFetalView` · `ScanMeasureVolumeView` · `ScanSubMeasureVolumeView`) 도 `qml/features/measure/` 로(§5 위험표의 12개와 일치, 적대적 검증으로 정정 2026-07-29 — 구판은 나열은 12개인데 머릿수를 8개로 잘못 적었다).

> **`Sub*` 접두사가 듀얼 뷰(좌/우 화면)를 뜻한다.** 최근 회귀 중 "듀얼 M-mode 에서 Length 도구 누락" 이 이 대칭성 문제다 — **이관 시 `Sub` 계열을 반드시 함께 옮긴다.**

### Step 7-D. `data/` + 영속화

측정 결과가 검사 기록에 저장된다면 `data/measure_repository` 가 `core/db` 를 호출한다. **[Phase 6](./phase6-feature-patient-dicom-cloud.md) 의 `patient` 와 테이블을 공유할 가능성이 높으므로 경계를 확인**한다 — 공유 엔티티는 `core/entities`.

### Step 7-E. 유닛 테스트

**이 phase 의 가장 큰 가치다.**

| 테스트 | 내용 |
|---|---|
| `measure_converter_test` | 픽셀 ↔ 물리 단위. mock `i_scan_geometry_port` |
| `tools/*_test` | 도구별 계산 — 알려진 입력 → 기대값 |
| `ddh_test` | **임상 계산. 허용오차 0** |
| `blood_volume_flow_test` | 〃 |
| `modes/*_test` | 모드별 특화 계산 |

**골든 값의 출처**: 현행 출하본(M2.03.26)을 oracle 로 한다([principles.md §3](../principles.md)). 알려진 입력을 넣어 현행이 내는 값을 기록하고, 그것을 기대값으로 고정한다. **"정답" 이 아니라 "이전 값" 이다** — 회귀 검출에는 그것으로 충분하고, 값이 틀렸다면 그것은 별건이다.

### Step 7-F. `Scan → Measure` 25건 정리

port 경유로 바뀐 뒤 남은 것을 확인한다. **`features/scan-* → features/measure` 직접 include 는 0 이어야 한다**([Phase 5 §2.2](./phase5-feature-worklist-settings.md)).

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | feature 간 참조 | `grep -rn '#include "features/' src/features/measure` | 0줄 |
| 4.2 | UI 격리 | `grep -rn '<QQuick\|<QtWidgets' src/features/measure` | 0줄 |
| 4.3 | `Scan` 결합 제거 | `grep -rn 'ScanView\|ScanPlayer\|GLFrame' src/features/measure` | 0줄 |
| 4.4 | **측정값 회귀** | `make test-unit` 의 measure 스위트 | 전부 통과, **DDH·BVF 허용오차 0** |
| 4.5 | 듀얼 뷰 | 골든 시나리오에 듀얼 M-mode 측정 포함 | 통과 |
| 4.6 | 모드 전환 | 골든 시나리오에 B→PW→M 전환 후 측정값 유지 포함 | 통과 |
| 4.7 | 6타깃 빌드 | `make build-all` | exit 0 |
| 4.8 | **동작 불변** | `make test-golden` | 통과 |
| 4.9 | 계층 검사 | `make check-layers` | exit 0 |

> **4.5·4.6 은 최근 실제 회귀를 겨냥한 것이다** — "VOL 측정값이 모드 전환 시 사라짐", "듀얼 M-mode 에서 Length 도구 누락". 이 phase 가 그 회귀를 **다시 내지 않는다**는 것을 보이려면 시나리오에 넣어야 한다.

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **임상 계산값이 달라진다** | 진단 오류. 의료기기 회귀 | 허용오차 0. 계산식 내용 변경 금지 — 위치만. 4.4 가 게이트 |
| **이 영역이 지금도 불안정하다**(최근 회귀 최대 군집) | 우리 변경과 기존 버그가 섞여 원인을 못 가른다 | **착수 전 현행 HEAD 로 골든을 뜬다.** 그 시점의 버그는 그대로 보존되는 것이 정답이다([principles.md §3](../principles.md)) |
| `i_scan_geometry_port` 가 너무 커진다 | 실질적으로 `Scan` 을 그대로 노출 | Step 7-A 에서 **필요한 값만 목록화**. 25건을 읽고 정하되 "혹시 몰라서" 넣지 않는다 |
| 모드 특화(`*M`·`*PW`)의 최종 소속이 Phase 8 에서 바뀐다 | 두 번 옮긴다 | `domain/modes/{m,pw}/` 로 **미리 격리**해 둔다. Phase 8 은 디렉토리 하나를 옮기면 된다 |
| 측정 결과 테이블이 `patient` 와 겹친다 | 중복 정의 | Step 7-D 에서 확인. 공유 엔티티는 `core/entities` |
| `Sub*`(듀얼 뷰) 파일 누락 | 듀얼 모드 파손 | Step 7-C 주석. QML 12개를 짝으로 확인 |

---

## 6. cross-reference

- [plan.md §3.4·§5](./plan.md)
- [phase1-regression-baseline.md §2 Step 1-C](./phase1-regression-baseline.md) — 골든 산출물 중 "측정값"
- [phase8-feature-scan-split.md](./phase8-feature-scan-split.md) — `domain/modes/` 의 최종 소속 확정
- [../../review/moana-app.md §4·§9](../../review/moana-app.md) — 측정 기능 실측과 최근 회귀
