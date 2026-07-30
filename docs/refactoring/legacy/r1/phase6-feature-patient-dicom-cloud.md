# Phase 6 — `patient` · `dicom` · `cloud`

> **상태**: 미시작
> **범위**: 환자·검사기록 · DICOM/PACS · 클라우드 3개 feature. `PatientList ↔ Scan` 순환을 끊어 [Phase 8](./phase8-feature-scan-split.md) 의 전제를 만든다.
> **선행**: [Phase 5](./phase5-feature-worklist-settings.md) — 규약이 서야 한다.
> **병렬**: [Phase 7](./phase7-feature-measure.md) · [Phase 9](./phase9-feature-ambulance-ble.md) 와 동시 진행 가능
> **후행**: [Phase 8](./phase8-feature-scan-split.md)

---

## 1. 배경

### 1.1 대상

| feature | 현행 | 파일 | LOC |
|---|---|---:|---:|
| `patient` | `app/PatientList` | 40 | 11,193 |
| `dicom` | `framework/Dicom`(`UnifiedDicomAdapter`) + `PatientList/DcmFileSaver` | 2+ | 1,954+ |
| `cloud` | `app/Cloud` + `framework/Network`(`SononCloud` 1,438) | 2 + 14 | 1,440 + 4,217 |

`patient` 최대 파일은 `PatientListViewController.cpp` **2,342 LOC** 인데, 이것은 [Phase 4-B5](./phase4-composition-root-presentations.md) 에서 이미 `presentations/qt/features/patient/` 로 옮겨져 있다. **이 phase 는 거기서 도메인을 꺼내는 작업**이다.

### 1.2 셋을 한 phase 로 묶는 이유

**`patient` 가 나머지 둘을 소비한다.**

| 관계 | 근거 |
|---|---|
| `patient` → `dicom` | `PatientList/DcmFileSaver` · `DICOM 내보내기가 리포트 기능을 대신한다`([../../review/moana-app.md §4](../../review/moana-app.md)) |
| `patient` → `cloud` | `PatientList/CloudKeyChecker` · `CloudKeyConverter` — 환자 데이터 암호키가 클라우드 계정에 묶여 있다 |

`features/A → features/B` 가 금지([Phase 5 §2.2](./phase5-feature-worklist-settings.md))이므로 **셋의 port 경계를 동시에 정해야 한다.** 나눠서 하면 중간 상태에서 규칙을 어긴다.

### 1.3 `PatientList ↔ Scan` 순환이 Phase 8 의 전제다

| 순환 | 정방향 | 역방향 |
|---|---:|---:|
| `PatientList` ↔ `Scan` | 10 | **9** |
| `Main` ↔ `PatientList` | 4 | 1 |
| `Ambulance` ↔ `PatientList` | 2 | 1 |

**`PatientList → Scan` 10건과 `Scan → PatientList` 9건이 거의 대칭**이다 — 다른 순환들이 한쪽으로 크게 기운 것과 다르다. 즉 **양방향으로 실제 결합이 있다**는 뜻이고, 이 phase 에서 가장 손이 많이 가는 부분이다.

정체(추정): 스캔 중 환자 컨텍스트(`Scan/ScanPatient.cpp` 372 · `ScanPatientDetailView.cpp` 264)와 환자 목록에서의 스캔 리뷰. **착수 전 실제 include 를 읽어 확정한다.**

### 1.4 목적

1. `patient` · `dicom` · `cloud` 를 `{domain,data,ports}` 로
2. `PatientList ↔ Scan` 순환 제거 — **Phase 8 의 선행 조건**
3. `framework/Dicom` 을 `framework/` 에서 비운다([Phase 3 §2.3](./phase3-core-layer.md))

### 1.5 범위 한계

- **`Ambulance` 는 [Phase 9](./phase9-feature-ambulance-ble.md)** — `patient` 와 순환(2/1)이 있으나 그쪽에서 끊는다
- **`recording`(`framework/Record` 6,571) 은 [Phase 8-J](./phase8-feature-scan-split.md)** — [Phase 1](./phase1-regression-baseline.md) 골든이 이 포맷에 의존한다
- DICOM 프로토콜·PACS 동작을 바꾸지 않는다. **최근 PACS 회귀(업로드 이미지 사선 밀림, 2026-07-22)가 이 영역이다** — 골든 대조 필수

---

## 2. 진행 단계

### Step 6-A. 경계 확정 (3 feature 동시)

**코드를 옮기기 전에 port 3벌을 먼저 정한다.**

| port | 선언 위치 | 내용 |
|---|---|---|
| `i_patient_repository_port.h` | `features/patient/ports/` | 환자·검사 CRUD·검색 |
| `i_dicom_export_port.h` | `features/dicom/ports/` | C-STORE 전송, 파일 저장 |
| `i_cloud_sync_port.h` | `features/cloud/ports/` | 계정·키·업로드 |

**`patient` 가 `dicom`·`cloud` 를 부르는 경로**는 `features/patient/ports/` 에 **소비자 관점 인터페이스**를 선언하고, `features/patient/data/` 구현이 `core/services` 로 내려간다([Phase 5 §3 B-3](./phase5-feature-worklist-settings.md) 과 같은 형태).

### Step 6-B. `dicom`

| # | 작업 |
|---|---|
| B-1 | `framework/Dicom/UnifiedDicomAdapter`(.cpp+.h **1,954**) → `features/dicom/data/` |
| B-2 | `ports/i_dicom_export_port.h` 선언 — C-STORE · 워크리스트 질의 |
| B-3 | `domain/dicom_service` — 태그 매핑 규칙, 전송 정책 |
| B-4 | `PatientList/DcmFileSaver` → `features/dicom/data/` |
| B-5 | [Phase 5-B3](./phase5-feature-worklist-settings.md) 에서 `worklist` 가 임시로 `framework/Dicom` 을 직참하던 것을 `ports` 경유로 정정 |
| B-6 | `tests/unit/features/dicom/` — 태그 매핑 |

### Step 6-C. `cloud`

| # | 작업 |
|---|---|
| C-1 | `framework/Network/SononCloud`(1,438) 은 [Phase 3-B6](./phase3-core-layer.md) 에서 `core/services/cloud` 로 이미 이동 — **인프라(HTTP 클라이언트)** |
| C-2 | `app/Cloud/CloudAPIController`(1,440) 에서 도메인 분리 → `features/cloud/domain/` |
| C-3 | `ports/i_cloud_sync_port.h` |
| C-4 | `data/cloud_repository` — `core/services/cloud` 호출 |
| C-5 | `PatientList/CloudKeyChecker` · `CloudKeyConverter` → `features/cloud/domain/` (암호키 규칙 = 도메인) |
| C-6 | `tests/unit/features/cloud/` |

> **C-1/C-2 의 가름이 이 phase 의 판단점이다.** HTTP 요청 조립·재시도·인증 헤더 = `core/services/cloud`(인프라). 계정 상태·키 파생·동기화 정책 = `features/cloud/domain`. **`SononCloud.cpp:1326` 의 주석**(*"Never fall back to our own Def::APP_BUILD/APP_VERSION here"* — M2.03.24 안드로이드 사고)이 정책 로직이 인프라에 섞여 있다는 증거다.

### Step 6-D. `patient`

| # | 작업 |
|---|---|
| D-1 | `ports/i_patient_repository_port.h` |
| D-2 | `domain/patient_service` — 검사 기록 규칙, 검색·필터 조건 |
| D-3 | `data/patient_repository` — `core/db` 호출. 현 `framework/Database` 의 환자 테이블 접근 |
| D-4 | `PatientItem` · `PatientListModel` · `PatientListSortFilterProxyModel` 가름 — 모델은 `presentations`, 엔티티는 `domain` |
| D-5 | `ResearchFile` · `ResearchFileConverter` · `Mp4FileSaver` → 소속 결정. **`ResearchFile` 은 `RESEARCH` 릴리스 타깃과 연관**([Phase 0-D](./phase0-build-reproducibility.md))이므로 확인 후 배치 |
| D-6 | `tests/unit/features/patient/` |

### Step 6-E. `PatientList ↔ Scan` 순환 제거

**19건(10+9)을 실제로 읽고 유형별로 처리한다.**

| 유형 | 처리 |
|---|---|
| 공유 엔티티(환자·검사 타입) | `core/entities` 로 승격 |
| `Scan` 이 환자 컨텍스트를 **읽는다** | `features/scan-*/ports/i_patient_context_port.h` 로 역전. 구현이 `core/db` 로 |
| `PatientList` 가 스캔 결과를 **읽는다** | 〃 반대 방향 |
| 화면 전환·리뷰 진입 | **`presentations/` 문제다.** [Phase 4](./phase4-composition-root-presentations.md) 에서 이미 UI 로 갔으면 순환이 아니다 |

> **마지막 행이 중요하다.** 19건 중 상당수가 뷰컨트롤러 간 호출일 가능성이 높고, 그것은 Phase 4 이후 `presentations/` 내부 문제이지 `features/` 순환이 아니다. **Phase 4 완료 후 다시 세면 19건이 줄어 있을 것이다** — 착수 시 재측정한다.

---

## 3. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 3.1 | feature 간 참조 | `grep -rn '#include "features/' src/features/{patient,dicom,cloud}` | 자기 것 외 0줄 |
| 3.2 | UI 격리 | `grep -rn '<QQuick\|<QtWidgets' src/features/{patient,dicom,cloud}` | 0줄 |
| 3.3 | 순환 제거 | `PatientList` ↔ `Scan` · `Main` ↔ `PatientList` | **0건** |
| 3.4 | `framework/` 축소 | `ls framework/` | `Record` · `ScanManager` · `Ambulance` **3개** |
| 3.5 | 유닛 테스트 | `make test-unit` | 3 feature 전부 테스트 존재 |
| 3.6 | **DICOM 회귀** | 골든 DICOM 파일 바이트 대조 + C-STORE 패킷 덤프 | 일치 |
| 3.7 | **DB 스키마 불변** | 환자 DB 스키마 덤프 | 일치 |
| 3.8 | 6타깃 빌드 | `make build-all` | exit 0 |
| 3.9 | **동작 불변** | `make test-golden` | 통과 |
| 3.10 | 계층 검사 | `make check-layers` | exit 0 |

> **3.6·3.7 이 이 phase 고유의 게이트다.** 환자 DB 와 DICOM 출력은 **의료기기 기록**이다. 스키마나 태그가 바뀌면 기존 데이터 접근과 PACS 연동이 깨진다.

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **환자 DB 스키마가 바뀐다** | 기존 검사 기록 접근 불가 | 3.7 이 게이트. `data/` 는 어댑터일 뿐 스키마를 건드리지 않는다 |
| **DICOM 태그 매핑이 바뀐다** | PACS 연동 파손. **최근 회귀 이력이 있다**(2026-07-22 사선 밀림) | 3.6 골든 바이트 대조. `UnifiedDicomAdapter` 내용 변경 금지 — 위치만 |
| **클라우드 인프라/도메인 가름이 애매하다** | Step 6-C 판단 지연 | 기준: **재시도·헤더·직렬화 = `core`**, **정책·상태 = `domain`**. 애매하면 `core` 에 두고 Phase 8 이후 재검토 |
| **클라우드 픽스처 커버리지가 `CmdType` 25개에 못 미친다** | 덮이지 않은 커맨드는 **판정 없이 옮겨진다** | [Phase 1 검증 3.7](./phase1-regression-baseline.md) 이 커버리지 숫자를 남긴다. **덮인 커맨드부터 옮기고**, 미달분은 이관 커밋에 "미검증" 을 명시. Step 6-C 착수 전 그 목록을 다시 읽는다 |
| 테스트 서버 접근이 끝내 안 열려 픽스처를 코드에서 역산했다 | 픽스처가 서버 실제 응답과 다를 수 있다 | 그래도 **moana 측 회귀는 잡힌다**(같은 요청을 보내는가). 서버 계약 검증은 이 phase 의 목표가 아님을 이관 문서에 적는다 |
| `PatientList ↔ Scan` 19건이 예상보다 깊다 | Phase 8 지연 | **착수 시 재측정**(§2 Step 6-E 주석). Phase 4 이후 줄어 있을 가능성이 높다 |
| 암호키(`CloudKeyChecker`)를 잘못 옮겨 기존 데이터 복호 실패 | **데이터 손실** | C-5 를 **별도 커밋**으로, 기존 DB 로 복호 검증 후 진행 |
| `ResearchFile` 의 소속·용도 미확인 | 잘못 배치 | D-5 — `RESEARCH` 타깃과의 관계를 [Phase 0-D](./phase0-build-reproducibility.md) 결과와 함께 확인 |

---

## 5. cross-reference

- [plan.md §3.4·§5](./plan.md)
- [phase5-feature-worklist-settings.md](./phase5-feature-worklist-settings.md) — 규약 · `worklist`→`dicom` 임시 직참의 정정
- [phase8-feature-scan-split.md](./phase8-feature-scan-split.md) — 이 phase 의 순환 제거가 전제
- [../../review/moana-app.md §4](../../review/moana-app.md) — 도메인 기능 실측
- [../../review/protocol-cloud.md](../../review/protocol-cloud.md) — 클라우드 프로토콜 현황
