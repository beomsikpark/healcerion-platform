# Phase 10 — 컴파일 타임 변종 → 런타임 설정

> **상태**: 미시작
> **범위**: `#ifdef` 로 박힌 제품 변종 8종을 `core/entities` 데이터와 런타임 설정으로. 릴리스 아티팩트를 **플랫폼당 1개**로.
> **선행**: [Phase 3](./phase3-core-layer.md)(`core/entities/model` 그릇) 뒤 착수 가능, [Phase 8](./phase8-feature-scan-split.md) 뒤 완료
> **근거**: [principles.md §8·§9](../principles.md) · [architecture.md §6.2](../architecture.md)
> **핵심**: **이전 세대가 이미 런타임 선택이었다.** 새 설계가 아니라 복원이다.

---

## 1. 배경

### 1.1 실측

| 매크로 | 파일 | 출현 | 성격 |
|---|---:|---:|---|
| **`HC_SONON_500L`** | **81** | **556** | 제품 모델 |
| `HC_CVIE_SUPPORT` | 12 | 79 | 서드파티 라이선스 |
| `HC_POWER_DOPPLER` | 33 | 63 | 기능 |
| `HC_RELEASE_RU` | 14 | 39 | 국가 |
| `HC_SONON_FUJI_L43K` | 19 | 32 | OEM 모델 |
| `HC_SONON_CERTIFICATION_CHINA` | 7 | 20 | **인증 — 범위 밖(§1.5)** |
| `HC_SCAN_2CM` | 4 | 14 | 기능 |
| `HC_RELEASE_US` / `LOCAL` / `CE` / `OTHER` | 4 / 4 / 4 / 3 | 8 / 8 / 7 / 6 | 배포 |

**QML 쪽 변종 가드는 0건**이다 — 변종이 전부 C++ 에 있다. 즉 이 phase 는 QML 을 건드리지 않는다.

`HC_SONON_500L` 하나가 81파일 556곳으로 나머지를 다 합친 것보다 크다.

### 1.2 이전 세대는 런타임이었다

[principles.md §8](../principles.md) 실측:

| | `ginny-fw`(300 시리즈) | 현행 |
|---|---|---|
| 변종 선택 | **런타임** — u-boot 환경변수로 5개 모델 선택, 시리얼로 보드 리비전 자동 판별 | **컴파일 타임** |
| 결과 | **단일 유니버설 이미지** | 모델당 별도 빌드 |

**"cctv 가 그렇게 한다" 가 아니라 "`ginny-fw` 가 그렇게 했다" 가 근거다.** 조직 수용성이 다르다.

### 1.3 비용이 이미 발생했다

`app.pro:17` · `framework.pro:16` 의 `HC_RELEASE_TARGET` hard-error 는 **CE/US 빌드가 뒤바뀌어 출하된 사고** 이후 추가된 것이다([../../review/moana-app.md §9](../../review/moana-app.md)).

**hard-error 는 미정의를 잡을 뿐 불일치를 못 잡는다** — [Phase 0-D](./phase0-build-reproducibility.md) 가 정본을 1곳으로 만들어 그 결함을 없앴고, 이 phase 는 **분기 자체를 없앤다.**

그리고 `HC_POWER_DOPPLER` 는 **Power Doppler** 다 — [../../review/change-cost.md](../../review/change-cost.md) 실측에서 **출하 계통 3곳에 각각 재적용됐고 patch-id 가 전부 다른** 그 기능이다. 컴파일 플래그로 관리되는 기능이 브랜치로도 관리되고 있었다.

### 1.4 목적

1. 모델 스펙을 **데이터**로 — 모델 추가가 데이터 1건
2. 릴리스 아티팩트를 **플랫폼당 1개**로 — 검증 대상이 N → 1
3. CE/US 뒤바뀜 같은 사고를 **구조적으로 제거**

### 1.5 범위 한계 — 인증은 우리가 판단하지 않는다

[principles.md §9](../principles.md):

> **인증 브랜치(`500L_Cetification` 68 · `310C_China_Certification` 22)는 인증본 동결이 규제 요구일 수 있어 우리가 판단하지 않는다.**

따라서 **`HC_SONON_CERTIFICATION_CHINA`(7파일 20곳)은 이 phase 의 대상이 아니다.** 컴파일 타임으로 남긴다. 그 결과 "플랫폼당 아티팩트 1개" 목표는 **중국 인증본을 예외로 갖는다** — 그렇게 적는다.

`HC_CVIE_SUPPORT` 도 성격이 다르다. ContextVision cvie 는 **상용 라이선스 SDK** 이고 113MB 바이너리다. 런타임 판별로 바꾸면 라이선스 없는 배포본에도 SDK 가 실린다 — **라이선스 계약 확인이 선행**이다.

### 1.6 `500C` 는 단종이 아니다 — 판단 정정 (2026-07-29)

> **초판은 "단종 라인(300 시리즈·500C)은 범위 밖"([principles.md §11](../principles.md))이라 적었다. `500C` 부분을 철회한다.**

| 실측 | 값 |
|---|---|
| `device/legacy/500c-sn-fw` | **71커밋, 최신 브랜치 `FW_1_1_8_0` 2026-04-24** |
| 최근 커밋 내용 | *"migrate to ABLIC WiFi SDK and add **Rev1.7** scan parameters"*(2026-04-21) · *"add WiFi FW upgrade path and wifi_version in device info"*(2026-04-20) · *"tune scan parameters and restructure line gain offset table"*(2026-04-24) |
| `sonex-framework` | **2026-07-23** *"500C/P WiFi(RS9116) 펌웨어 통합 굽기 — 5계층 구현 + 실장비 검증"* |

**신규 하드웨어 리비전(Rev1.7)과 부품 전환(WiFi SDK)이 진행 중이다. 단종 라인의 활동이 아니다.** 300 시리즈에 대한 단종 판정은 유지하되 **`500C`·`500P` 는 뺀다.**

**다만 이것이 이 phase 의 범위를 넓히지는 않는다** — §2.1 대로 **moana 에는 500C·500P 구동 코드가 애초에 없다.** 이 phase 는 **있는 `#ifdef` 를 데이터로 바꾸는 것**이고, 없는 모델을 새로 얹는 것은 **후속 작업**이다(§2.3).

또한:
- **300 시리즈 단종 라인은 범위 밖**([principles.md §11](../principles.md))
- 이 phase 는 **동작을 바꾼다.** 다른 phase 와 성격이 다르므로 §4 의 판정이 특히 중요하다

---

## 2. 대상별 처리

| 매크로 | 처리 | 목표 위치 |
|---|---|---|
| `HC_SONON_500L`(81/556) | **모델 스펙 데이터** | `core/entities/model` — 프로브·주파수·깊이·프리셋 범위 |
| `HC_SONON_FUJI_L43K`(19/32) | 〃 (OEM 모델도 모델이다) | 〃 |
| `HC_SCAN_2CM`(4/14) | 모델 스펙의 깊이 범위 속성 | 〃 |
| `HC_POWER_DOPPLER`(33/63) | **기능 플래그** — 모델 스펙 또는 라이선스 | `core/entities/model` + `features/doppler-cf` |
| `HC_RELEASE_CE/US/RU/LOCAL/OTHER`(29/68) | **배포 설정** — 서버 URL · 규제 문구 · 기본 언어 | `features/settings` + 빌드 시 주입 |
| `HC_CVIE_SUPPORT`(12/79) | **라이선스 런타임 판별** — 단, §1.5 선행 확인 | `core/imaging` |
| `HC_SONON_CERTIFICATION_CHINA`(7/20) | **범위 밖.** 컴파일 타임 유지 | — |

### 2.1 모델 스펙이 무엇이어야 하는가

`Model.cpp`(2,839) 는 [Phase 3-D 2.4-4](./phase3-core-layer.md) 에서 `core/entities` 로 갔다. **그 그릇에 지금 `#ifdef` 로 표현된 차이를 채운다.**

**지원 모델은 8종이다** — `300C` · `310C` · `300MC` · `300VC` · `300L` · `300PA` · `500L` · `FUJI_L43K`.

> **정정 (2026-07-29)**: 초판은 여기에 `500C`·`500P` 를 넣어 **10종**이라 적었다(출처 [../../review/moana-app.md §0](../../review/moana-app.md), 그쪽도 함께 정정). **`Model.cpp` 의 `modelName ==` 분기와 `InitCapabilityTable_*` 에 그 둘이 없다.** `framework/Common/CommonData.cpp:71,73` 의 `deviceModelList` 문자열 목록에만 있다(`700C`·`700L` 도 함께) — **이름만 알고 구동하지 못한다.**
>
> 초판은 §1.5 가 "500C 는 범위 밖(단종)" 이라 하면서 §2.1 이 "500C 를 데이터로 만든다" 고 해 **문서 안에서 모순**이었다. 둘 다 정정했다(§1.6).

| 속성 후보 | 근거 |
|---|---|
| 프로브 타입·주파수 범위 | `Common/FrequencyTable`(→ `core/entities`) |
| 깊이 범위 | `HC_SCAN_2CM` |
| 지원 모드(B·CF·PW·M) | 모드별 `#ifdef` |
| Power Doppler 지원 | `HC_POWER_DOPPLER` |
| MI/TI 표 | `Common/MI_TI_Table`(→ `core/entities`) |
| 프리셋 기본값 | `Common/PresetItem`(→ `core/entities`) |
| BLE 페어링 필요 여부 | 500L·500P |

**형식**: 코드 상수가 아니라 **데이터 파일**(JSON/리소스)이어야 한다. 그래야 "모델 추가 = 데이터 1건" 이 성립한다. 장비 쪽 `configs/*.dat` 을 데이터로 유지하는 결정([architecture.md §3](../architecture.md))과 같은 원리다.

### 2.2 모델을 어떻게 알아내는가

**런타임 판별 경로가 필요하다.** 현재는 컴파일 타임이라 앱이 자기가 어떤 모델용인지 안다.

| 경로 | 근거 |
|---|---|
| **장비 접속 시 프로토콜로 조회** | HC 프로토콜에 장비 식별 필드가 있다([../proof/protocol-sot/](../proof/protocol-sot/)) — **1순위** |
| 사용자 선택(`SelectModeView.qml`) | 이미 있다 |
| `Common/SononDeviceInfo.h`(→ `core/entities`) | 현행 장비 정보 구조 |

> **`ginny-fw` 가 시리얼 번호로 보드 리비전을 자동 판별했다**([principles.md §8](../principles.md)). 같은 방식이 앱에도 성립한다 — **장비가 자기를 밝히면 앱은 데이터를 찾기만 하면 된다.**

### 2.3 후속 작업 — `500C`·`500P` 흡수 (이 phase 밖, 그러나 이 phase 가 전제)

**이 phase 는 없는 모델을 얹지 않는다.** 다만 **이 phase 가 끝나야 그 작업이 싸진다.**

| | |
|---|---|
| **왜 필요한가** | `500C`·`500P` 는 **`sonex-app` 만 구동한다.** 라이선스·CVIE 가 전부 저울에서 빠진 뒤 `sonex-app` 에 남은 **유일한 실질 존재 이유**다 — [../moana-vs-sonex.md §3.1·§3.2](../moana-vs-sonex.md) |
| **순서가 뒤집히면** | 지금 얹으면 `HC_SONON_500L`(81/556) 옆에 **컴파일 분기가 하나 더 는다.** 이 phase 의 대상이 커지고 CE/US 뒤바뀜과 같은 표면이 넓어진다 |
| **이 phase 뒤에 얹으면** | **데이터 1건**이 된다 — §4.4 가 바로 그 판정이다 |

**흡수 범위** (필수 2건):

| 대상 | moana 현재 | sonex |
|---|---|---|
| **명령셋 + 모델 파라미터 테이블** | 출하 계통 0. **그러나 `origin/sonon_500c` 브랜치에 있다** — 71커밋 / 113파일 / **+14,946줄**, **500C·500P 둘 다** capability table 보유(`InitCapabilityTable_500C`·`_500P`), 최종 **2023-09-19** | `HCInstructionSet{500C,500P}` + `DeviceManager` 구현 |
| **500C/P 펌웨어 굽기 경로** | `Main/FirmwareUpdater.cpp` **121줄**, `HC_SONON_500L` 가드 안에서 `"500L"`·`"L43K"` 문자열 비교만 | `HCFirmwareController` + `HCFirmwareVersionChecker` + 모델별 `.ini`(**`500-SN-Firmware.ini`** = Socionext) |
| 영상 파라미터 | **부분 완료** — `HCNextSRIFilter` 가 이미 `500C = idx 1` 분기 보유 | sonex 에서 이미 넘어왔다 |

> **따라서 이 작업은 신규 포팅이 아니라 "미병합 브랜치를 데이터로 흡수하기" 다.** 출발점이 백지가 아니다. 다만 **2023-09 이후 출하 계통이 3년 가까이 앞서갔으므로**(Qt6 이행 포함) 직접 병합은 성립하지 않는다 — **`Model.cpp` diff 437줄에서 스펙을 역산하는 것**이 §Step 10-A A-3 과 같은 작업이다.
>
> **그리고 이 브랜치가 이 phase 의 존재 이유를 증명한다** — 500C 지원이 컴파일 타임 변종 방식 때문에 브랜치로 갈렸고, 갈린 채 출하 계통에 도달하지 못했으며, 그 결과 제품 하나가 다른 앱으로 넘어갔다([../../review/change-cost.md](../../review/change-cost.md)).

**미검증 — 착수 전 확인 항목**: 500C·500P 의 명령셋 차이가 **정말 데이터로 흡수되는지.** 프로토콜은 같으나(`500c-sn-fw` `src/App/Communication/USSCustomCommand.c` 도 HC 프로토콜) **Socionext 베어메탈이라 `500L`(ZynqMP/Linux)과 장비 아키텍처가 다르다.** 스캔 파라미터·빔포밍에 코드 분기가 필요하면 §4.4 의 "코드 변경 0줄" 이 성립하지 않는다.

---

## 3. 진행 단계

### Step 10-A. 모델 스펙 데이터 정의

| # | 작업 |
|---|---|
| A-1 | `HC_SONON_500L` 556곳을 읽어 **차이의 목록**을 만든다. 이것이 스펙 속성의 실제 근거다 |
| A-2 | `HC_SONON_FUJI_L43K`(32) · `HC_SCAN_2CM`(14) 도 같은 방식 |
| A-3 | 모델 **8종** × 속성 표 작성 — **현행 빌드 산출물에서 역산**한다. 각 `#ifdef` 조합이 내는 값이 곧 그 모델의 스펙이다 |
| A-4 | `core/entities/model` 에 데이터 로더 |
| A-5 | 데이터 파일 형식·위치 확정 |

> **A-3 이 이 phase 의 안전장치다.** 스펙을 "설계" 하면 틀린다. **현행 빌드가 내는 값을 그대로 옮겨 적는 것**이 [principles.md §3](../principles.md)(동작 보존)이다.

### Step 10-B. `#ifdef` → 데이터 조회 치환

**모델 단위가 아니라 파일 단위로, 소형부터.**

| 순서 | 대상 | 파일 |
|---|---|---:|
| B-1 | `HC_SCAN_2CM` | 4 |
| B-2 | `HC_SONON_FUJI_L43K` | 19 |
| B-3 | `HC_POWER_DOPPLER` | 33 |
| B-4 | **`HC_SONON_500L`** | **81** |

**각 파일마다 골든 대조.** B-4 는 81파일이므로 **feature 별로 쪼개 커밋**한다 — [Phase 8](./phase8-feature-scan-split.md) 이 끝난 뒤라 파일이 이미 feature 별로 모여 있다.

> **`HC_SONON_500L` 을 마지막에 하는 이유**: 556곳 중 다수가 `Scan/`(→ 모드 feature)에 있고, B-1~B-3 으로 데이터 조회 패턴이 검증된 뒤에 해야 한다.

### Step 10-C. 릴리스 타깃 → 배포 설정

`HC_RELEASE_{CE,US,RU,LOCAL,OTHER}` 29파일 68곳.

| 유형 | 처리 |
|---|---|
| 서버 URL · 엔드포인트 | `features/settings` 설정 값. 빌드 시 주입 또는 설정 파일 |
| 규제 문구 · 라벨 | `presentations/qt/locale` 리소스 |
| 기능 on/off(예: `mMode300CEnable`) | 모델 스펙 또는 배포 설정 |
| 패키지 ID · 서명 | **빌드 설정으로 남는다** — 코드가 아니다 |

**마지막 행이 한계다.** Android 패키지명·iOS bundle ID·프로비저닝 프로파일은 런타임으로 뺄 수 없다. 즉 **아티팩트가 완전히 1개가 되지는 않는다** — 목표는 "코드 분기 0, 아티팩트는 서명 단위로만" 이다.

### Step 10-D. `HC_CVIE_SUPPORT`

**§1.5 의 라이선스 확인이 선행.** 확인 전에는 착수하지 않는다.

확인 후 가능하면: SDK 존재 여부를 런타임에 판별하고, 없으면 NextSRI 로 폴백. **`moana` 는 이미 `NextSRI V1.20.5` 롤아웃에서 "CVIE/HNS 라이선스 분기" 를 하고 있다**([../../review/moana-app.md §9](../../review/moana-app.md)) — 그 분기를 컴파일 타임에서 런타임으로 옮기는 것이다.

### Step 10-E. `ambulance` 의 `HC_RELEASE_RU`

[Phase 9](./phase9-feature-ambulance-ble.md) 에서 `features/ambulance` 로 격리된 뒤. 39곳 중 `ambulance` 안의 것은 **feature 활성화 플래그 하나**로 접힌다.

### Step 10-F. `HC_SONON_CERTIFICATION_CHINA` — 하지 않는다

§1.5. **문서에 "의도적으로 남긴 컴파일 타임 분기" 로 명시**하고, 근거(인증본 동결 가능성)를 함께 적는다. 근거 없이 남으면 다음 사람이 지운다.

### Step 10-G. 빌드 정리

`app.pro` · `framework.pro` 의 `equals(HC_FEATURE_500L, true)` 등 조건 블록 제거. [Phase 0-D](./phase0-build-reproducibility.md) 의 타깃 정본에서 제품 변종 항목이 빠진다.

---

## 4. 검증

**이 phase 는 동작을 바꾸므로 판정이 다르다.**

| # | 항목 | 명령 | 기대 |
|---|---|---|---|
| 4.1 | **모델별 동등성** | 모델 **8종**(§2.1) 각각에 대해 — 이전 빌드(해당 `#ifdef`) vs 신 빌드(데이터 선택) 골든 대조 | **전부 일치** |
| 4.2 | 변종 매크로 제거 | `grep -rn 'HC_SONON_500L\|HC_SONON_FUJI_L43K\|HC_SCAN_2CM\|HC_POWER_DOPPLER\|HC_RELEASE_' src/` | **0건** |
| 4.3 | 의도적 잔존 | `grep -rn 'HC_SONON_CERTIFICATION_CHINA' src/` | 존재 + **문서에 근거 명시** |
| 4.4 | 모델 추가 비용 | **가상 모델이 아니라 `500C` 를 데이터 1건으로 추가**(§2.3) | 코드 변경 0줄 |
| 4.5 | 아티팩트 수 | `make build-all` | **플랫폼당 1개** (+ 서명 변형 · 중국 인증본) |
| 4.6 | 런타임 판별 | 장비 접속 시 모델 자동 인식 | 정상 |
| 4.7 | **미인식 모델 처리** | 알 수 없는 모델 접속 | 안전한 거부 또는 기본값. **오동작 금지** |
| 4.8 | 6타깃 빌드 | `make build-all` | exit 0 |
| 4.9 | `make test-golden` | | 통과 |
| 4.10 | 유닛 테스트 | 모델 스펙 로더 · 모델별 파라미터 범위 | 존재 |

> **4.1 이 이 phase 의 유일한 진짜 게이트다.** 모델 8종 × 4모드 골든이 필요하고, [Phase 1](./phase1-regression-baseline.md) 의 시나리오가 그만큼 확장돼야 한다. **골든 실장비 녹화가 8종 전부에 대해 있는가**가 착수 전 확인 항목이다.

---

## 5. 위험 · 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| **모델 8종 골든 녹화가 없다** | 4.1 을 못 돌린다 | **착수 전 확인.** 없는 모델은 **범위에서 뺀다** — 검증 못 하는 변종을 바꾸지 않는다. 300 시리즈 단종 라인은 어차피 범위 밖 |
| **`#ifdef` 로 코드가 아예 빠지던 것이 이제 실린다** | 바이너리 증가 · 미검증 경로 활성화 | 4.1 로 동작 동등성 확인. 크기 증가는 허용 — 검증 대상 N→1 의 대가 |
| **`HC_SONON_500L` 556곳 중 진짜 모델 차이가 아닌 것이 섞여 있다** | 잘못된 스펙 속성 | A-1 에서 **556곳을 읽어 분류**한다. 임시 우회·버그 회피가 섞여 있으면 그것은 스펙이 아니다 |
| **CVIE 라이선스 위반** | 법적 문제 | D — **계약 확인 전 착수 금지** |
| **인증본이 바뀐다** | 규제 위반 | F — 중국 인증 분기는 손대지 않는다. **다른 매크로 치환이 인증본 빌드에 영향을 주는지도 확인** |
| **미인식 모델에서 오동작** | 현장 사고. 초음파 파라미터가 틀리면 위험하다 | 4.7 — 알 수 없는 모델은 **거부**한다. "적당한 기본값" 으로 스캔하면 안 된다 |
| 아티팩트가 완전히 1개가 안 된다 | 목표 미달 | C — **패키지 ID·서명은 런타임화 불가**. 목표를 "코드 분기 0" 으로 정확히 적는다 |
| Phase 8 이 안 끝났는데 착수 | B-4 가 흩어진 파일을 상대한다 | B-1~B-3 은 Phase 3 뒤 가능, **B-4 는 Phase 8 뒤** |

---

## 6. 이 phase 가 닫는 것

| [plan.md §6](./plan.md) 판정 | 이 phase 의 기여 |
|---|---|
| 10. 변종 | 모델 추가 = 데이터 1건, 아티팩트 플랫폼당 1개. **판정은 `500C` 실제 추가로 한다**(§2.3·§4.4) |
| 2. 정본 단일화 | 릴리스 타깃 분기가 코드에서 사라진다 |

그리고 [principles.md §12](../principles.md) 의 기대효과 중 **"CE/US 뒤바뀜 같은 사고를 구조적으로 제거"** 가 여기서 완료된다 — [Phase 0-D](./phase0-build-reproducibility.md) 가 정본을 1곳으로 모았고, 이 phase 가 분기 자체를 없앤다.

---

## 7. cross-reference

- [plan.md §2.5·§5·§6](./plan.md)
- [principles.md §8·§9](../principles.md) — 사내 선례 우선 · 브랜치 대신 코드로 변종
- [architecture.md §6.2](../architecture.md) — 장비 쪽 동일 작업(`-D_USING_500L_DEV_`)
- [phase0-build-reproducibility.md §2 Step 0-D](./phase0-build-reproducibility.md) — 릴리스 타깃 정본
- [phase3-core-layer.md §2.4](./phase3-core-layer.md) — `core/entities/model` 그릇
- [../../review/change-cost.md](../../review/change-cost.md) — Power Doppler 3중 재적용 실측
