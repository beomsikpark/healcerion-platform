# Phase 3 — `core/` 확립

> **상태**: 미시작
> **범위**: `framework/` 15모듈과 `app/Sources/Common` 을 **인프라 계층 `core/`** 와 **OS 계층 `platforms/`** 로 가른다. 그 과정에서 `Common` 허브 순환 3쌍이 끊긴다.
> **선행**: [Phase 2](./phase2-layer-boundary.md) — 경계가 컴파일러에게 보여야 이동 결과를 판정할 수 있다.
> **후행**: [Phase 4](./phase4-composition-root-presentations.md)
> **구조 정본**: cms-app **ADR-001** — `cctv/desktop/cms-app/docs/adr/adr-001-3layer-feature-first-clean-architecture.md`

---

## 1. 배경

### 1.1 `core` 는 도메인이 아니라 인프라다

**이 phase 의 가장 흔한 오해가 여기다.** cms-app ADR-001 의 레이어 정의는 이렇다.

| 레이어 | 정의 |
|---|---|
| **Core** | **인프라, 공통 유틸리티, 외부 라이브러리 래퍼** |
| Features | 비즈니스 로직, Feature별 Domain/Data 캡슐화 |
| Presentation | Shell UI |

**도메인은 `features/<name>/domain/` 에 있지 `core/` 에 있지 않다.** `core/` 에 들어가는 것은 여러 feature 가 공유하는 **타입(entities)** 과 **인프라**다.

cms-app `src/core/` 실측 (135파일 30,004 LOC):

```
core/
  entities/       device.h · event.h · stream*.h · setting.h · snapshot.h · cloud.h …  (19파일)
  services/       device_api · rpc_client · wr_config + cloud/ direct/ webrtc/
  db/  log/  codec/  audio/  stream_router/  util/  widgets/  compat/  resources/
```

`entities/` 가 순수 타입 선언이고, 나머지는 전부 인프라다.

### 1.2 moana 의 `framework/` 는 이미 그 자리에 있다

`framework/` 는 static lib(`libframework.a`)이고 `app/` 이 단방향 의존한다. **역의존 6건은 [Phase 2](./phase2-layer-boundary.md) 에서 제거됐다.** 즉 이 phase 는 **새 계층을 만드는 것이 아니라 이름과 배치를 cms-app 정본에 맞추고, 잘못 들어간 것을 골라내는 작업**이다.

골라낼 것이 둘 있다.

| 골라낼 것 | 이유 |
|---|---|
| `framework/Platform`(31파일 3,881) | JNI · UWP · iOS 네이티브 브릿지 = **OS별 코드**. cms-app 의 `platforms/` 에 대응 |
| `framework/Record`(6,571) · `ScanManager`(4,404) · `Dicom`(1,954) · `Ambulance`(3,441) | **비즈니스 로직**이다. cms-app 이라면 `features/{recording, scan-*, dicom, ambulance}` 에 간다 |

반대로 `app/Sources/Common`(15,978)에서 **끌어올릴 것**이 있다.

| 끌어올릴 것 | LOC | 목표 |
|---|---:|---|
| `Model`(프로브·기기 모델 스펙) | 2,839 + 446 | `core/entities` |
| `PresetItem` · `PresetItemModel` | 3,786 + 859 + 276 + 87 | `core/entities` |
| `FrequencyTable` · `GraymapTable` · `ImageFilterTable` · `MI_TI_Table` | 364+117+175+85+162+83+197+73 | `core/entities` |
| `ScanMode.h` · `AppCommon.h`(`SONON_SCAN_MODE` · `SONON_UNIT` · `ExportFileType`) | 71 + 400 | `core/entities` |
| `AppUtility` · `AppDebug` · `BackgroundWorker` · `PerfMon` · `Rect` · `Event` · `ViewInfo` | 476+60+59+105+58+111+95+71+32+54 | `core/util` |
| `SononDeviceInfo.h` · `DeviceSetting.h` · `FrameRate.h` | 94+170+110 | `core/entities` |
| `FrameStreamer` · `BackupWorker` · `UnsafeArea` · `FWUpgradeProgress` | 199+150+74+32+391+85+35 | **feature 로.** Phase 5·8·9 |
| `AppSetting`(도메인 설정 + 저장 + Qt 결합) | 1,964 + 1,340 | **분해.** entities 만 여기서, 나머지는 [Phase 5-D](./phase5-feature-worklist-settings.md) |

### 1.3 순환이 여기서 끊긴다

`Common` 이 [387건 중 248건(64%)](./plan.md)을 받는 허브인데, **역방향 3쌍**을 갖는다.

| 순환 | 정방향 | 역방향 | 역방향의 정체(추정) |
|---|---:|---:|---|
| `Common` ↔ `Scan` | 85 | **3** | `Common` 의 무언가가 스캔 타입을 본다 |
| `Common` ↔ `Setting` | 29 | **5** | `AppSetting` ↔ `Setting` 모델 |
| `Common` ↔ `Ambulance` | 29 | **1** | 〃 |

**`Common` 을 `core/entities` + `core/util` 로 가르면 역방향 9건이 갈 곳이 없어진다** — `core/` 는 `features/` 를 참조할 수 없기 때문이다. 이 9건이 이 phase 의 실제 난이도이고, 나머지는 파일 이동이다.

### 1.4 목적

1. **인프라와 비즈니스 로직을 가른다** — `core/` 에 무엇이 있고 없어야 하는지가 규칙으로 선다
2. OS별 코드를 `platforms/` 로 격리 — 6타깃 대응이 한 디렉토리에 모인다
3. `Common` 허브 순환 3쌍 제거
4. HC 프로토콜 정본을 받을 자리(`core/protocol/`)를 만든다

### 1.5 범위 한계

- **feature 를 만들지 않는다.** `features/` 골격은 [Phase 5](./phase5-feature-worklist-settings.md)
- **UI 를 옮기지 않는다.** `presentations/` 는 [Phase 4](./phase4-composition-root-presentations.md)
- **알고리즘 내용을 바꾸지 않는다** — `ImageProc.cpp`(3,232) · NextSRI · CVIE 래퍼는 **위치만**
- **`.pro` 를 CMake 로 바꾸지 않는다**([plan.md §8](./plan.md))

---

## 2. 대상 매핑

### 2.1 `framework/` → `core/` (그대로 인프라)

| 현행 | LOC | 목표 | cms-app 대응 |
|---|---:|---|---|
| `Common`(`Def` · `SononLog` · `SononUtil` · `SononUtils` · `FileUtil` · `Cipher` · `QAESEncryption` · `BaseThread` · `GlobalContext` · `CommonData` · `JniResultCallback`) | **2,194** | `core/log` + `core/util` | `core/log` · `core/util` |
| `Include`(`SononCommon.h` — 프로토콜·장비 상수) | 740 | **`core/protocol`** | `core/entities` |
| `Database` | 7,487 | `core/db` | `core/db` |
| `SononClient`(HC 프로토콜 클라이언트) | 8,359 | `core/services/sonon` | `core/services/{cloud,direct,webrtc}` |
| `Network`(`SononCloud`) | 4,217 | `core/services/cloud` | `core/services/cloud` |
| `ImageProc` · `ContextVision` · `TensorFlow-Lite` · `VideoProc` | 5,061+683+303+881 | `core/imaging` | `core/codec` |
| `AudioProc` | 1,089 | `core/audio` | `core/audio` |

> **`framework/Common/ScanContext`** 는 이름이 유틸인데 스캔 상태다. **`core/entities` 로 보낼지 `features/scan-*/domain` 으로 보낼지는 Phase 8 에서 확정**하고, 이 phase 에서는 `core/entities` 에 임시 배치한다. 여러 feature 가 공유하면 `core/entities` 가 맞다.
>
> **위 표의 2,194 는 `ScanContext` 를 제외한 11개 파일(로그·유틸)만의 합이다.** `framework/Common/` 디렉토리 전체는 `ScanContext.cpp`(876)+`ScanContext.h`(206)=1,082 를 더해 **3,276**이고, 그 1,082는 방금 말한 대로 `core/entities` 로 별도 배치된다 — `core/log`+`core/util` 이관 작업량 산정에는 2,194 를 쓴다(적대적 검증으로 확인, 2026-07-29).

### 2.2 `framework/Platform` → `platforms/`

31파일 3,881 LOC. cms-app `platforms/` 가 12파일 592 LOC 인 것과 비교하면 **moana 쪽이 6배**인데, 지원 OS 가 6개(Android·iOS·UWP·macOS·Windows·Linux)이고 cms-app 은 3개다.

| 작업 | 내용 |
|---|---|
| 2.2-1 | 31파일을 OS별로 분류 — `platforms/{android,ios,uwp,macos,windows,linux}/` |
| 2.2-2 | 공통 인터페이스가 있으면 `core/` 에 선언, 구현만 `platforms/` |
| 2.2-3 | `app.pro`·`framework.pro` 의 `android{}`·`ios{}`·`win32{}` 블록에서 소스 목록을 `platforms/` 기준으로 재작성 |

**이 작업이 [Phase 10](./phase10-runtime-variant.md) 의 전제 일부다** — OS 분기와 제품 변종 분기가 지금 같은 `.pro` 조건 블록에 섞여 있다.

### 2.3 `framework/` 중 **`core/` 가 아닌 것**

| 현행 | LOC | 목표 | phase |
|---|---:|---|---|
| `Record`(`BackupFile*` · `RecordFile*`, HEAL 포맷) | 6,571 | `features/recording` | [8-J](./phase8-feature-scan-split.md) |
| `ScanManager` | 4,404 | `features/{scan-b,doppler-cf,doppler-pw,mmode}/domain` 분배 | [8](./phase8-feature-scan-split.md) |
| `Dicom`(`UnifiedDicomAdapter`) | 1,954 | `features/dicom/data` | [6-B](./phase6-feature-patient-dicom-cloud.md) |
| `Ambulance` | 3,441 | `features/ambulance` | [9-A](./phase9-feature-ambulance-ble.md) |

**이 phase 에서는 옮기지 않고 `framework/` 자리에 둔다.** 옮길 곳(`features/`)이 아직 없기 때문이다. 다만 **`core/` 로 잘못 딸려 들어가지 않게 목록을 명시한다** — 이 표가 그 목적이다.

> **`ScanManager` 는 `core/services` 로 가고 싶어진다.** 이름이 그렇게 보이기 때문이다. 그러나 스캔 세션 상태·모드 전환 규칙은 **비즈니스 로직**이므로 feature 다. cms-app 이 `stream_router` 를 `core/` 에 둔 것과는 성격이 다르다 — 그것은 토픽 라우팅 인프라다.

### 2.4 `app/Sources/Common` 분해

§1.2 표대로. **이 작업이 이 phase 의 위험 대부분을 차지한다** — 248건이 이 디렉토리를 본다.

| 순서 | 대상 | 이유 |
|---|---|---|
| 2.4-1 | `Rect` · `Event` · `ViewInfo` · `FrameRate` · `ScanMode` · `AppCommon` (헤더 전용, 소형) | 의존이 가장 얕다. 이동으로 패턴 확인 |
| 2.4-2 | `AppUtility` · `AppDebug` · `PerfMon` · `BackgroundWorker` → `core/util` | 순수 인프라 |
| 2.4-3 | `FrequencyTable` · `GraymapTable` · `ImageFilterTable` · `MI_TI_Table` → `core/entities` | 파라미터 표 = 데이터 |
| 2.4-4 | `Model`(2,839) → `core/entities` | **[Phase 10-A](./phase10-runtime-variant.md) 의 그릇**이 여기서 생긴다 |
| 2.4-5 | `PresetItem`(3,786) → `core/entities` | 최대. 프리셋 데이터 |
| 2.4-6 | **`AppSetting`(1,964+1,340)** — entities 부분만 분리 | **마지막.** 나머지는 Phase 5-D |
| 2.4-7 | 잔여(`FrameStreamer` · `BackupWorker` · `UnsafeArea` · `SononDeviceInfo` · `DeviceSetting` · `FWUpgradeProgress`) 는 `app/Sources/Common` 에 남긴다 | feature 확정 전. Phase 5·8·9 에서 각자 간다 |

---

## 3. 진행 단계

### Step 3-A. `src/` 골격 생성

```
src/
  core/{entities,protocol,services,db,imaging,audio,log,util}/
  platforms/{android,ios,uwp,macos,windows,linux}/
```

`.pro` 를 계층별로 분할한다.

| 파일 | 역할 |
|---|---|
| `src/core/core.pro` | static lib `libcore.a` |
| `src/platforms/platforms.pri` | OS별 조건 include |
| `moana.pro` | `SUBDIRS += core app` (기존 `framework` 자리) |

> **`framework/` 디렉토리는 이 phase 가 끝날 때까지 남는다.** §2.3 의 4모듈이 아직 갈 곳이 없기 때문이다. `framework.pro` 는 그 4개만 담게 축소된다 — Phase 6·8·9 에서 하나씩 비고, 마지막에 사라진다.

### Step 3-B. `framework/` → `core/` 이동 (§2.1)

모듈 단위로 하나씩. **각 이동마다 [Phase 1](./phase1-regression-baseline.md) 골든 대조 + 6타깃 빌드.**

| 순서 | 모듈 | 비고 |
|---|---|---|
| B-1 | `Include` → `core/protocol` | 가장 얕다. **[proof/protocol-sot](../proof/protocol-sot/) 정본이 들어올 자리** |
| B-2 | `Common` → `core/log` + `core/util` | 다른 모듈이 참조 — `Record` 22 · `SononClient` 13 · `Database` 11 · `Ambulance` 8 · `ScanManager` 6 · `Platform` 5 · `ImageProc` 4 · `Include` 2 · `Network`·`Dicom`·`AudioProc` 각 1 = **74건**(적대적 검증으로 재집계, 2026-07-29 — 상위 6개만으로는 65건). 먼저 옮겨야 나머지가 따라온다 |
| B-3 | `AudioProc` · `VideoProc` · `ContextVision` · `TensorFlow-Lite` → `core/audio` · `core/imaging` | 소형 |
| B-4 | `ImageProc` → `core/imaging` | **NextSRI 포함. 내용 변경 금지** |
| B-5 | `Database` → `core/db` | |
| B-6 | `Network` → `core/services/cloud` | |
| B-7 | `SononClient` → `core/services/sonon` | **Phase 2-B 에서 역의존 3건을 이미 끊었다** |

### Step 3-C. `framework/Platform` → `platforms/`

§2.2. **6타깃 전부에서 빌드 확인**이 필수다 — Linux 만 보면 JNI·UWP 코드의 이동 오류를 못 본다.

### Step 3-D. `app/Sources/Common` 분해

§2.4 순서대로. **2.4-1 → 2.4-7 을 각각 별도 커밋**으로 낸다.

248건이 이 디렉토리를 보므로 include 갱신 범위가 넓다. [Phase 2-C](./phase2-layer-boundary.md) 에서 경로 규정형(`Common/Model.h`)으로 바꿔 뒀으므로 `sed` 치환이 기계적이다 — `Common/Model.h` → `core/entities/model.h`.

> **파일명 규약(snake_case)은 여기서 바꾸지 않는다.** [Phase 4-G](./phase4-composition-root-presentations.md) 에서 presentations 이동과 함께 일괄 전환한다. 두 번 치환하지 않기 위해서다.

### Step 3-E. 순환 3쌍 제거

`core/` 가 `features/` 를 참조할 수 없으므로 역방향 9건이 반드시 처리된다.

| 유형 | 처리 |
|---|---|
| `core` 쪽이 feature 타입을 **값으로** 쓴다 | 타입을 `core/entities` 로 승격 |
| `core` 쪽이 feature 에 **알림**을 보낸다 | 콜백/시그널로 역전 (cms-app ADR-004 콜백 3-tier) |
| 애초에 잘못 들어간 코드 | 해당 feature 로 내린다 |

### Step 3-F. `make check-layers` 규칙 추가

```
core/**  이  features/ · presentations/ · app/Sources/  를 include 하지 않는다
platforms/**  이  features/ · presentations/  를 include 하지 않는다
```

---

## 4. 검증

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | `core` 독립 빌드 | `core.pro` 단독 | `libcore.a` 생성 |
| 4.2 | 계층 방향 | `grep -rn '#include "\(features\|presentations\|Sources\)/' src/core/ src/platforms/` | **0줄** |
| 4.3 | 순환 제거 | `Common` ↔ `Scan`·`Setting`·`Ambulance` 역방향 | **0건** |
| 4.4 | OS 코드 격리 | `grep -rln 'jni\.h\|__ANDROID__\|Q_OS_WINRT\|<UIKit' src/core/` | 0건 |
| 4.5 | 6타깃 빌드 | `make build-all` | exit 0 |
| 4.6 | **동작 불변** | `make test-golden` | 통과 |
| 4.7 | 계층 검사 | `make check-layers` | exit 0 |
| 4.8 | `framework/` 잔여 | `ls framework/` | `Record`·`ScanManager`·`Dicom`·`Ambulance` **4개만** |
| 4.9 | 알고리즘 무변경 | `git diff` 에서 `ImageProc` · NextSRI · CVIE 의 **내용 변경 0줄** (경로/include 만) | ✓ |

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **`Common` 248건 갱신이 크다** | 충돌 · 누락 | Phase 2-C 에서 경로 규정형이 됐으므로 치환이 기계적. **2.4-1~2.4-7 을 별도 커밋으로 쪼갠다** |
| **`AppSetting` 이 entities·저장·Qt 를 한 클래스에** | 2.4-6 이 광범위 파급 | **마지막에 한다.** 2.4-1~2.4-5 로 먼저 의존을 줄인다. entities 만 꺼내고 나머지는 Phase 5-D 로 넘긴다 |
| **`ScanContext` 의 소속이 불명확** | 잘못 두면 Phase 8 에서 다시 옮긴다 | `core/entities` 에 임시 배치하고 **Phase 8 에서 확정**. 문서에 임시임을 명시 |
| **`framework/Platform` 이동을 Linux 에서만 검증** | Android·iOS·UWP 빌드 파손 | Step 3-C 를 **6타깃 전부**에서 확인. 미검증 타깃은 미검증으로 표기 |
| **`ImageProc` 이동 중 NextSRI 가 바뀐다** | `sonex` 와의 바이트 동일성 파괴 | B-4 의 diff 를 **경로/include 변경만** 인지 검증(4.9). 그들 문서 `NextSRI_vs_Sonex_Comparison.md` 가 대조 기준 |
| **`.pro` 분할이 플랫폼 조건 블록을 깨뜨린다** | 특정 타깃만 링크 실패 | `.pro` 의 `android{}`·`ios{}` 블록을 먼저 읽고 소스 목록을 계층별로 재매핑. app.pro 1,359줄 / framework.pro 835줄 |
| **`core/` 가 비대해진다** — 애매하면 다 넣게 된다 | 다음 phase 에서 다시 꺼내야 한다 | **§2.3 표가 방어선이다.** `Record`·`ScanManager`·`Dicom`·`Ambulance` 는 `core/` 에 넣지 않는다 |
| `service_QT693` 병행 개발 충돌 | 대규모 이동이라 충돌 면이 크다 | 모듈 단위로 짧게 끊어 병합. Step 3-B 는 7커밋 |

---

## 6. cross-reference

- [plan.md §3.2·§5](./plan.md) — 목표 구조와 phase 위치
- **cms-app ADR-001** (cms-app `docs/adr/adr-001-3layer-feature-first-clean-architecture.md`) — Core 의 정의(**인프라**)
- **cms-app ADR-002** (cms-app `docs/adr/adr-002-feature-first-folder-structure.md`) — feature 가 `core/` 가 아닌 이유
- [phase2-layer-boundary.md](./phase2-layer-boundary.md) — 경로 규정형 include 가 이 phase 의 치환을 기계화한다
- [phase10-runtime-variant.md](./phase10-runtime-variant.md) — `core/entities/model` 이 그 작업의 그릇
- [../proof/protocol-sot/](../proof/protocol-sot/) — `core/protocol/` 로 들어올 산출물
