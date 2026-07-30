# Phase 5 — feature 3분할 패턴 확립 (`worklist` · `settings`)

> **상태**: 미시작
> **범위**: `features/<name>/{domain,data,ports}` 골격을 세우고 **가장 작은 feature 둘**로 검증한다. 이 phase 의 산출물은 코드보다 **규약**이다.
> **선행**: [Phase 4](./phase4-composition-root-presentations.md) — UI 가 `presentations/` 로 빠져야 남는 것이 도메인이다.
> **후행**: [Phase 6](./phase6-feature-patient-dicom-cloud.md) · [7](./phase7-feature-measure.md) · [9](./phase9-feature-ambulance-ble.md) 병렬 가능
> **구조 정본**: cms-app **ADR-002** — `cctv/desktop/cms-app/docs/adr/adr-002-feature-first-folder-structure.md`

---

## 1. 배경

### 1.1 왜 이 둘인가

| feature | 현행 | LOC | 수신 include |
|---|---|---:|---:|
| `worklist` | `app/WorkList` 8파일 | 955 | **1** |
| `settings` | `app/Setting` 29파일 + `Common/AppSetting` | 6,667 + 3,304 | **9**(적대적 검증으로 정정, 2026-07-29 — 구판 14) |

`worklist` 는 **moana 에서 가장 얕은 feature** 다 — 수신 1건. 패턴을 세우는 데 실패해도 되돌리기 쉽다.

`settings` 는 **cms-app 대응이 가장 명확하다**. cms-app CLAUDE.md 가 설정 저장 규약을 3계층으로 문서화해 뒀고, moana 의 현행 API 가 **거의 같은 시그니처**다.

| | cms-app | moana 현행 |
|---|---|---|
| port | `ConfigPort::get(name, text)` / `set(name, text)` | `Settings::getAppSettingItem(key)` / `setAppSettingItem(key, value)` |
| domain | `SettingsService` — `onSettingChanged` 발행 | **없음** |
| data | `ConfigStore : ConfigPort` — SQLite 어댑터 | `Settings`(2,566) + `AppSettingsDb` — 암호화 SQLite |
| 저장소 | SQLite `app_configs(id, name, text)` | 암호화 SQLite (wxSQLite3/cipher) |

**port 와 data 는 사실상 있다. 없는 것은 `domain` 과 인터페이스 선언이다.**

그리고 위반이 실측된다 — **`QSettings` 직접 사용 30건**. cms-app CLAUDE.md 가 명시적으로 금지한 그 패턴이다("저장소 일원화 · 도메인 알림 · 패키징 호환 · 다중 프로파일").

### 1.2 목적

1. `features/<name>/{domain,data,ports}` **규약 확정** — 이후 5개 phase 가 이것을 반복한다
2. `.pro` 분할 규약 확정
3. **moana 최초의 자동 유닛 테스트** — `domain/` 은 Qt UI 없이 테스트 가능하다
4. `worklist` · `settings` 이관

### 1.3 범위 한계

- **다른 feature 를 건드리지 않는다.** 규약이 서기 전에 큰 것을 옮기면 두 번 옮긴다
- `presentations/qt/features/{worklist,settings}/` 는 [Phase 4-B](./phase4-composition-root-presentations.md) 에서 이미 이동했다. 이 phase 는 **거기서 도메인을 꺼내는 작업**이다
- `QSettings` 30건 제거는 **범위 안**이지만, 그중 UI 상태(창 크기 등)만 쓰는 것은 **cms-app 규약** (cms-app `CLAUDE.md`)대로 `ConfigPort` 경유로 바꾼다

---

## 2. 규약 (이 phase 의 진짜 산출물)

### 2.1 디렉토리

```
src/features/<name>/            ← kebab-case
  domain/
    <name>_service.{h,cpp}        비즈니스 로직. Qt UI · DB · 소켓 모름
    <entity>.h                    feature 전용 엔티티 (공유 엔티티는 core/entities)
  data/
    <name>_repository.{h,cpp}     ports 인터페이스 구현
    <name>_dto.h                  외부 표현 ↔ 도메인 매핑
  ports/
    i_<name>_data_port.h          인터페이스만. 구현 없음
```

### 2.2 의존 규칙 (cms-app ADR-001)

| from → to | 허용 |
|---|---|
| `domain` → `core` | ✅ |
| `domain` → `ports` | ✅ |
| `data` → `domain` · `ports` · `core` | ✅ |
| `domain` → `data` | ❌ |
| `features/*` → `presentations/*` | ❌ |
| `features/A` → `features/B` | ❌ — 필요하면 `core/entities` 로 승격하거나 콜백으로 역전 |
| `domain` 에 `<QQuick*>` · `<QtWidgets>` · `<QtSql>` include | ❌ |

> **`features/A → features/B` 금지가 [§2.3 순환 12쌍](./plan.md)의 재발을 막는 규칙이다.** cms-app 의 17개 feature 도 서로 참조하지 않고 `core/entities` 를 공유한다.

### 2.3 명명 (cms-app 실측)

| 대상 | 규약 | 실례 |
|---|---|---|
| feature 디렉토리 | kebab-case | `device-registry` · `guard-alarm` · `image-tuning` |
| port 헤더 | `i_<name>_port.h` | `i_settings_data_port.h` · `i_stream_control_port.h` |
| 소스 파일 | snake_case | `settings_service.cpp` · `config_store.cpp` |
| 설정 키 | `<feature_or_widget>.<key>` snake_case | `file_dialog.last_directory` |

### 2.4 `.pro` 분할

```
src/features/features.pro          TEMPLATE = subdirs
src/features/<name>/<name>.pro     static lib  lib<name>.a
```

| 규칙 | |
|---|---|
| feature `.pro` 는 `core` 만 링크한다 | 다른 feature 를 링크하면 §2.2 위반이 링커에서 잡힌다 |
| `INCLUDEPATH` 는 `src/` 루트만 | [Phase 2-C](./phase2-layer-boundary.md) 의 경로 규정형 유지 |

> **링커가 규칙의 두 번째 방어선이다.** `make check-layers`(grep)가 1차, `.pro` 링크 목록이 2차다.

### 2.5 테스트

```
tests/unit/features/<name>/<name>_service_test.cpp
```

`domain/` 은 Qt UI·DB·소켓을 모르므로 **`ports` 를 mock 으로 채우면 순수 유닛 테스트**가 된다. `make test-unit` 신설.

> cms-app 은 "매 수정 직후 `make analyze`, `make test-unit` 은 사람 검증 통과 후" 를 규약으로 쓴다. moana 는 CI 가 0건이므로 **`make test-unit` 을 [Phase 1](./phase1-regression-baseline.md) 의 CI 에 바로 붙인다.**

---

## 3. 진행 단계

### Step 5-A. 골격 + 규약 확정

§2 를 문서화하고 `features/features.pro` · 빈 feature 템플릿 · `tests/unit/` 골격 · `make test-unit` 을 만든다. **`make check-layers` 에 §2.2 규칙 추가.**

### Step 5-B. `worklist`

DICOM Modality Worklist(MWL). `presentations/qt/features/worklist/`(8파일 955) 에서 도메인을 꺼낸다.

| # | 작업 |
|---|---|
| B-1 | `ports/i_worklist_data_port.h` — MWL 질의·결과 인터페이스 |
| B-2 | `domain/worklist_service` — 질의 조건 구성, 결과 필터·정렬 규칙 |
| B-3 | `data/worklist_repository` — `core/services` 의 DICOM 질의 호출. **구현은 [Phase 6-B](./phase6-feature-patient-dicom-cloud.md) 의 `features/dicom` 완성 전까지 `framework/Dicom` 직참** |
| B-4 | `presentations/qt/features/worklist/` 가 `domain` 만 보게 |
| B-5 | `tests/unit/features/worklist/` — **moana 최초의 자동 테스트** |

> **B-3 이 순서 의존이다.** `worklist` 가 `dicom` 을 필요로 하지만 `features/A → features/B` 는 금지다. **해법은 `ports/i_worklist_data_port.h` 를 `worklist` 가 선언하고 `dicom` 쪽이 아니라 `data/` 가 `core/services` 로 내려가 구현하는 것**이다. cms-app 도 같은 형태다 — `features/*/ports` 가 각자 선언하고 구현이 `core/services/*` 를 부른다.

### Step 5-C. `settings`

§1.1 표대로 cms-app 3계층에 맞춘다.

| # | 작업 | cms-app 대응 |
|---|---|---|
| C-1 | `ports/i_settings_data_port.h` — `get(key)` / `set(key, value)` | `i_settings_data_port.h` (`ConfigPort`) |
| C-2 | `data/config_store` — 현 `framework/Database/Settings`(2,566)의 `getAppSettingItem`/`setAppSettingItem` 을 어댑터로 감싼다 | `config_store.h` |
| C-3 | `domain/settings_service` — **변경 알림 발행**. 현재 없다 | `settings_service.h` |
| C-4 | `AppSetting`(1,964+1,340) 분해 — entities 는 [Phase 3-D](./phase3-core-layer.md) 에서 이미 나갔다. 잔여를 `domain`/`data` 로 | — |
| C-5 | **`QSettings` 직접 사용 30건 → `ConfigPort` 경유** | cms-app CLAUDE.md §설정 저장 |
| C-6 | 설정 키를 `<feature>.<key>` snake_case 로 정규화 | 〃 |
| C-7 | `presentations/qt/features/settings/`(29파일) 가 `domain` 만 보게 | |
| C-8 | `tests/unit/features/settings/` — mock `ConfigPort` 로 | |

> **C-5 를 별도 커밋으로 낸다.** 30건 각각이 저장 위치를 바꾸므로 **기존 사용자의 설정이 이관돼야 한다.** 마이그레이션 코드가 필요하고, 그것이 이 phase 의 유일한 사용자 영향 변경이다. 마이그레이션 없이 옮기면 **사용자 설정이 초기화된다** — 회귀다.

### Step 5-D. `Common` 잔여 정리

[Phase 3-D 2.4-7](./phase3-core-layer.md) 에서 남긴 것 중 `settings` 소속분을 가져온다 — `DeviceSetting.h` · `SononDeviceInfo.h` 등. **소속이 모호하면 남긴다.** 억지로 배치하면 Phase 8·9 에서 다시 옮긴다.

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | 계층 방향 | `grep -rn '#include "presentations/' src/features/` | 0줄 |
| 4.2 | UI 격리 | `grep -rn '<QQuick\|<QtWidgets\|<QtQml' src/features/` | **0줄** |
| 4.3 | feature 간 참조 | `grep -rn '#include "features/' src/features/worklist src/features/settings` | 자기 것 외 0줄 |
| 4.4 | domain 순수성 | `grep -rn '<QtSql\|<QtNetwork\|QSettings' src/features/*/domain/` | 0줄 |
| 4.5 | `QSettings` 제거 | `grep -rn 'QSettings' src/` | 0건 (마이그레이션 코드 제외) |
| 4.6 | 유닛 테스트 | `make test-unit` | exit 0, 테스트 **> 0건** |
| 4.7 | 링크 격리 | `features/worklist/worklist.pro` 가 `core` 외 링크 없음 | ✓ |
| 4.8 | 6타깃 빌드 | `make build-all` | exit 0 |
| 4.9 | **동작 불변** | `make test-golden` | 통과 |
| 4.10 | **설정 마이그레이션** | 이전 버전 설정 DB 로 실행 | 설정 전부 보존 |
| 4.11 | 계층 검사 | `make check-layers` | exit 0 |

> **4.6 이 이정표다.** moana 자동 테스트가 0 → N 이 되는 지점이고, [../../review/moana-app.md §8](../../review/moana-app.md) 의 "자동 테스트 없음" 이 깨진다.

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **설정 저장 위치 변경으로 사용자 설정 초기화** | 현장 회귀 | C-5 에 **마이그레이션 필수**. 4.10 이 게이트. 없으면 이 단계를 내지 않는다 |
| **규약을 두 feature 로 검증하기엔 표본이 작다** | Phase 6~9 에서 규약을 고치게 된다 | **의도된 위험이다.** 큰 feature 로 규약을 세우면 고칠 때 비용이 크다. 규약 변경이 필요하면 **Phase 6 착수 전에 한다** |
| `worklist` 가 `dicom` 을 필요로 한다 | `features/A → B` 금지와 충돌 | §3 B-3 — `ports` 는 소비자가 선언하고 `data` 가 `core/services` 로 내려간다 |
| `AppSetting` 잔여가 여전히 크다 | C-4 가 광범위 | entities 는 Phase 3 에서 이미 나갔다. 남은 것이 무엇인지 **먼저 세고 시작한다** |
| `domain` 에 Qt 를 완전히 못 뺀다 (`QString`·`QVariant`) | 4.4 실패 | **`QtCore` 는 허용한다.** cms-app 도 `QString` 을 쓴다. 금지는 `QtQuick`·`QtWidgets`·`QtSql`·`QtNetwork` — **UI 와 I/O** 다 |
| `.pro` 분할로 링크 순서 문제 | 빌드 실패 | static lib 순환 참조가 없어야 한다. §2.2 를 지키면 자동으로 성립 |

---

## 6. cross-reference

- [plan.md §3.2·§3.3·§5](./plan.md)
- **cms-app ADR-002** (cms-app `docs/adr/adr-002-feature-first-folder-structure.md`) — `domain/data` 캡슐화
- **cms-app CLAUDE.md §설정 저장** (cms-app `CLAUDE.md`) — `ConfigPort`/`SettingsService`/`ConfigStore` 3계층과 `QSettings` 금지 근거
- [phase3-core-layer.md](./phase3-core-layer.md) — `AppSetting` entities 분리가 선행
- [phase4-composition-root-presentations.md](./phase4-composition-root-presentations.md) — 뷰컨트롤러가 먼저 이동
