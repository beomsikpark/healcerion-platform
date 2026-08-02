# Phase 4 — 데이터 계층 이관 (ADK)

> **상태**: 미시작
> **범위**: `moana` 의 DB·DICOM·클라우드·백업을 **ADK 로 갈아끼운다.** 화면과 도메인 흐름은 바꾸지 않는다.
> **선행**: [Phase 2](./phase2-sdk-adk-adapter.md)(어댑터 계층)
> **후행**: [Phase 5](./phase5-measure-controls.md)
> **근거**: [plan.md §1.1·§2.3](./plan.md) · **DB 실측 SOT = [../../review/client-database.md](../../review/client-database.md)**
> **실측 기준**: `moana` `origin/service_QT693` · `sonex-framework` `origin/master`. 스키마 대조는 [client-database.md §3.1](../../review/client-database.md) 실측분이다.

---

## 1. 배경

### 1.1 이 phase 가 예상보다 싸다 — DDL 이 이미 같다 `[실측]`

**`moana` 와 ADK 의 DDL 은 9테이블 93컬럼이 전부 동일하다.** `SononDataBaseAdapter.cpp:31-154`(moana)와 `HCDataBaseAdapter.cpp:24-121`(ADK)의 DDL 을 **컬럼명·타입·`NOT NULL`·`PRIMARY KEY` 단위로 전수 파싱해 대조한 결과 차이 0건**이다([client-database.md §3.1](../../review/client-database.md)).

| 함의 | |
|---|---|
| **기존 출하 DB 가 그대로 열린다** | 스키마 마이그레이션이 필요 없다 |
| **바뀌는 것은 구현이지 데이터가 아니다** | `moana` = Qt SQL, ADK = raw sqlite3 C API |
| **`sonex-app` 의 이중 저장 문제가 이 계획에는 없다** | §1.2 |

### 1.2 부수 이득 — `sonex-app` 의 SOT 분열이 애초에 생기지 않는다 `[실측]`

`sonex-app` 은 같은 데이터를 **ADK DB(C++)와 sqflite DB(Dart) 양쪽에 각각 저장**하고, 읽기는 ADK 우선·sqflite 폴백이다. **두 저장소를 맞추는 코드가 없고**, ADK upsert 실패 시 로그만 찍고 넘어가 sqflite 에만 존재하는 환자가 생긴다([client-database.md §6](../../review/client-database.md)).

앱 코드 주석이 이유를 직접 밝힌다 — *"ADK DB가 쓰이는 경우: 목록은 getAllPatientList 기준이므로 SDK에 upsert하지 않으면 직후 fetchAllPatients()에서 방금 등록한 환자가 사라짐"*.

> **`moana` UI 를 쓰면 sqflite 계층 자체가 존재하지 않으므로 이 분열이 발생할 자리가 없다.** 저장 스택이 3벌에서 1벌(ADK)로 수렴한다. **이 계획을 택하는 부수 이득 중 가장 명확한 것이다.**

### 1.3 그러나 옮겨 붙는 결함이 있다 `[실측]`

DDL 이 같다는 것은 **결함도 같다**는 뜻이다. ADK 로 갈아끼워도 자동으로 없어지지 않는 것들:

| # | 결함 | 근거 |
|---|---|---|
| ① | **트랜잭션이 없다** — `BEGIN`/`COMMIT` 호출 **0건**. 환자 삭제처럼 **4테이블 + 파일시스템**을 함께 건드리는 연산이 원자적이지 않다 | [client-database.md §5.3](../../review/client-database.md) |
| ② | **질의를 문자열로 조립한다** — 값이 SQL 문법에 섞인다 | §5.1 |
| ③ | **조회 결과를 위치 기반으로 매핑**한다 — 컬럼 순서가 바뀌면 조용히 어긋난다 | §5.2 |
| ④ | **마이그레이션 버전 번호가 없다** | §5.4 |
| ⑤ | `PatientInfo` 의 `INSERT OR REPLACE` 가 **아무것도 대체하지 않는다** — UNIQUE 제약이 없다. `sonex-app` sqflite 만 `PatientID TEXT NOT NULL UNIQUE` 로 고쳤다 | §7.1 |
| ⑥ | ADK 의 `EncryptKey` 복구가 **없는 테이블을 조회**한다 | §7.2 |

> **이 phase 는 결함을 고치지 않는다.** [../README.md](../README.md) 가 정한 대로 **결함 수정은 리팩토링이 아니라 별도 축(`X`)** 이다 — 동작을 보존하는 게 아니라 바꾸므로 Phase 에 섞으면 회귀 판정이 흐려진다. SOT 는 [../r1/code-defects.md](../r1/code-defects.md) 다.
>
> **다만 ⑤는 예외 후보다** — `moana` 에서 ADK 로 갈아끼우는 순간 `INSERT OR REPLACE` 의 동작이 두 구현에서 같은지 확인해야 하고, 다르면 그 자체가 회귀다. §2 D-3.

### 1.4 절단으로 이미 줄어든 것

`moana` 전용 **Ambulance DB 2테이블**([client-database.md §3.2](../../review/client-database.md))은 [Phase 0 B-1](./phase0-repo-scope-cut.md) 에서 함께 사라진다. 이 phase 의 대상은 **공통 9테이블**이다.

---

## 2. 진행 단계

### Step 4-A. DB 계층 교체

**[plan.md §1.1](./plan.md) 기준 `*Db` 337회 · `CDataManager` 256회.**

| # | 작업 |
|---|---|
| A-1 | **테이블 단위로 끊는다** — 9테이블을 한 번에 바꾸지 않는다. 의존이 얕은 것(설정·프리셋)부터, `PatientInfo` 계열은 나중 |
| A-2 | `moana` 의 `*Db` 클래스(`PatientInfoDb`·`SnapshotInfoDb`·`DcmFileInfoDb`·`DataInfoDb`·`SpotInfoDb` 등)를 ADK request 로 대체 |
| A-3 | `CDataManager`(48파일에서 256회)를 ADK 파사드로 |
| A-4 | **DDL 은 건드리지 않는다**(§1.1) — 스키마가 같으므로 마이그레이션이 없다. **이 사실을 검증으로 확인한다**(§3.2) |

### Step 4-B. 설정 계층 교체

| # | 작업 |
|---|---|
| B-1 | `CSettings`(11파일 223회)를 ADK 설정 경로로 |
| B-2 | **파일 경로 규약을 맞춘다** — 계정 전환·로그인 전 상태·이름 바꾸기 처리가 스택마다 다르다([client-database.md §4](../../review/client-database.md)) |
| B-3 | **상대·절대 경로 판정이 문자열 검색으로 돼 있다**(§4) — 이관 시 그대로 옮기지 말고 ADK 규약을 따른다 |

### Step 4-C. DICOM · 워크리스트 · 클라우드 · 백업

| # | 작업 |
|---|---|
| C-1 | `framework/Dicom/UnifiedDicomAdapter`(C-STORE) → ADK DICOM request **12종** |
| C-2 | `app/Sources/WorkList/`(8파일) → ADK 워크리스트 경로. **`WorkItemInfo` 의 `AccessionNumber` 가 DDL 에 없고 `ALTER` 로만 추가된다**([client-database.md §3.1](../../review/client-database.md)) — 양쪽 동작을 대조한다 |
| C-3 | `app/Sources/Cloud/` + `framework/Network/` → ADK Cloud request **31종** |
| C-4 | 백업/복원 → ADK Backup request **5종** |
| C-5 | **클라우드 엔드포인트가 같은지 확인한다** — `moana` 와 ADK 가 같은 서버를 보는지([../../review/protocol-cloud.md](../../review/protocol-cloud.md)) |

### Step 4-D. 기존 출하 DB 호환 확인 — **이 phase 의 게이트**

| # | 작업 |
|---|---|
| D-1 | **실제 출하 DB 로 시험한다** — 새로 만든 DB 가 아니라 기존 환자 데이터가 든 파일 |
| D-2 | 9테이블 전부 읽기·쓰기 왕복 |
| D-3 | **`INSERT OR REPLACE` 동작 대조**(§1.3 ⑤) — `moana` 구현과 ADK 구현에서 같은 결과가 나오는지. 다르면 **회귀이므로 이 phase 에서 다룬다** |
| D-4 | **암호화 경계 확인** — 플랫폼별 암호화 적용 범위가 스택마다 다르다([client-database.md §7.5](../../review/client-database.md)). ADK 로 옮긴 뒤 어느 플랫폼에서 암호화되는지 실측 |

---

## 3. 검증

| # | 항목 | 방법 | 기대 |
|---|---|---|---|
| 3.1 | **기존 출하 DB 열기** | 실제 환자 데이터가 든 파일 | **성공. 이 phase 의 게이트** |
| 3.2 | 스키마 불변 | 이관 전후 DDL 덤프 대조 | **차이 0** |
| 3.3 | 환자 CRUD | 등록·조회·수정·삭제 | 동작 보존 |
| 3.4 | 스냅샷·검사 기록 | 저장·조회 | 동작 보존 |
| 3.5 | DICOM C-STORE | PACS 전송 | 성공 |
| 3.6 | 워크리스트 | MWL 조회 | 성공. `AccessionNumber` 포함 |
| 3.7 | 클라우드 | 로그인·업로드 | 성공 |
| 3.8 | 백업·복원 | 왕복 | 성공 |
| 3.9 | `moana` DB 계층 잔존 | `app/` 에서 `*Db`·`CDataManager`·`CSettings` 참조 | **0건** |
| 3.10 | **저장 스택 수** | 앱이 여는 DB 파일 | **1벌(ADK)** — sqflite 계층 없음(§1.2) |
| 3.11 | 암호화 | 플랫폼별 DB 파일 헤더 | **D-4 결과대로.** 미적용 플랫폼은 숫자로 명시 |

---

## 4. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **기존 출하 DB 가 안 열린다** | 환자 데이터 접근 불가 — **제품 결격** | D-1 을 **실제 출하 DB** 로 한다. 새로 만든 DB 로 통과시키면 판정이 아니다 |
| **DDL 동일이라는 전제가 틀렸다** | 마이그레이션 필요분을 놓친다 | 3.2 로 재확인. [client-database.md §3.1](../../review/client-database.md) 이 전수 대조했으나 **이 phase 에서 한 번 더 검증**한다 |
| 트랜잭션 부재(§1.3 ①)로 이관 중 데이터 손상 | 부분 저장 상태 | **결함 수정은 범위 밖이나**, 이관 작업 자체는 백업본에서 한다 |
| `INSERT OR REPLACE` 동작 차이(⑤) | 환자 중복 또는 덮어쓰기 | D-3 — **이것만은 이 phase 가 다룬다**(회귀이므로) |
| 위치 기반 컬럼 매핑(③) | 이관 중 컬럼 순서가 어긋나면 조용히 잘못된 값 | 3.3~3.6 을 **값까지 대조**한다. 성공/실패만 보지 않는다 |
| 클라우드 엔드포인트 불일치 | 로그인·업로드 실패 | C-5 를 먼저 확인 |
| **암호화 경계가 플랫폼마다 다르다**(§1.3·D-4) | 특정 플랫폼에서 PHI 가 평문 저장 — **규제 문제** | 3.11 로 실측하고 미적용분을 명시. 해소는 [../cybersecurity.md](../cybersecurity.md)·[r1 Phase 0-C-W](../r1/phase0-build-reproducibility.md) 소관 |

---

## 5. cross-reference

- [plan.md](./plan.md) §1.1(이음매)·§2.3(남는 것/사라지는 것)
- **[../../review/client-database.md](../../review/client-database.md)** — **이 phase 의 실측 SOT.** §3.1(DDL 동일)·§5(처리 방식)·§6(이중 저장)·§7(결함)
- [phase2-sdk-adk-adapter.md](./phase2-sdk-adk-adapter.md) — 선행. ADK request 군
- [phase0-repo-scope-cut.md](./phase0-repo-scope-cut.md) — Ambulance DB 절단
- [../r1/code-defects.md](../r1/code-defects.md) — §1.3 결함의 SOT. **이 phase 는 고치지 않는다**
- [../../review/protocol-cloud.md](../../review/protocol-cloud.md) — C-5 의 근거
- [../cybersecurity.md](../cybersecurity.md) — 암호화 경계 소관
