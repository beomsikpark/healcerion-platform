# 클라우드·서버 구성과 API

> **근거**: `server/legacy/sonex-cloud-backend` · `server/legacy/sonon-cloud` · `web/legacy/sonex-admin-web` 코드 직접 읽기(2026-07-27).
> **범위**: 클라우드는 장비 세대와 독립이므로 belle 범위 안에 둔다. 다만 `sonex-cloud-backend` 의 디바이스 도메인은 SONON 계열 전반을 다루고 belle 전용이 아니다.

## 0. 클라우드가 둘이다

**서로 다른 스택의 독립 제품 2개**가 병존한다. 공통 파일은 `.gitignore` 하나뿐이고 계승 관계가 아니다.

| | **`sonex-cloud-backend`** | **`sonon-cloud`** |
|---|---|---|
| 성격 | **B2B/OEM 장비·계정 관리 백엔드** | **소비자·수의용 앱 백엔드 + 브랜드 사이트** |
| 스택 | Java 8 · Spring MVC 5.2.22 · Spring Security 5.3.13 · MyBatis 3.5.10 · **MariaDB** | **Firebase Cloud Functions**(Node 10) · **Firestore** · Vue2/Quasar SPA |
| 배포 | WAR `CloudService`, **포트 8080** | Firebase Hosting 3타깃 + Functions |
| 호스트 | `sonex.healcerion.com:8080` | `sonon.healcerion.com` |
| 핸들러 | **136개** (SSO 53 · SDI 56 · ELA 23 · Core 4) | HTTPS 함수 **17개** |
| 커밋 | 16 (2022-09, 2025-05 두 시점) | **394** (2019-03 ~ **2026-06-02**, 저자 8명) |
| 상태 | 사실상 정지 | **현재 운영 중** |
| 프론트엔드 | `sonex-admin-web`(정적 HTML) | `admin-dashboard`(Vue2) · `user-dashboard`(Quasar) |

## 1. `sonex-cloud-backend` — 모듈 구성

Maven 멀티모듈. **Core 만 `packaging=war`** 이고 SSO·SDI·ELA 는 JAR 로 그 안에 번들된다.

| 모듈 | 역할 |
|---|---|
| **Core** | 보안 필터·DB 세션·암호화·스케줄러·서블릿 설정. WAR 산출 |
| **SSO** | 인증, 계정(관리자·클라우드 사용자), 가입·인증메일, 사용량 통계 |
| **SDI** | **Sonex Device Interface** — 디바이스 모델·디바이스·배터리·소유관계 |
| **ELA** | **Event Log Archive** — 이벤트 그룹·이벤트·이벤트 로그 |

**URL 이 평면인 이유**: `Servlet.xml` 이 `<context:component-scan base-package="Controller"/>` 로 모듈별 하위 패키지 없이 스캔한다. 컨트롤러가 **하나의 DispatcherServlet** 에 모이므로 `sonex-admin-web` 이 단일 `SERVER_URL = "http://sonex.healcerion.com:8080/Admin/"` 로 전부 호출할 수 있다.

컨트롤러는 모듈마다 **관리자용(`*_ControllerAdmin`, `@RequestMapping("/Admin")`)과 모바일용(`*_Controller`, `ROLE_CLOUD`)이 분리**돼 있다.

## 2. API 인벤토리

### 2.1 SSO — 인증·계정 (관리자 35 + 모바일 18)

**관리자** (`SSO_ControllerAdmin`)

| 분류 | 엔드포인트 |
|---|---|
| 인증 | `LogIn` · `LogOut` · `GetProfile` · `ChangeProfile` · `ChangePassword` |
| 메일·검증 | `RetransmitAuthMail` · `ResendAuthMail` · `VerifyCloudSignUp` · `VerifySignUp` · `ForgotPassword` · `VerifyChangePassword` |
| 관리자 계정 | `GetAdminAccountCount` · `GetAdminAccountList` · `AddAdminAccount` · `DelAdminAccount` · `ModAdminProfile` · `ModAdminPassword` · **`ModAdminRole`** |
| 클라우드 계정 | `GetCloudAccountCount` · `GetCloudAccountList` · `AddCloudAccount` · `DelCloudAccount` · `ModCloudProfile` · `ModCloudPassword` · **`ModCloudState`** |
| 통계 | `GetCountOfSignUpPerDay` · `GetCountOfVerifyPerDay` · `GetCountOfNonVerifyUsers` · `GetCountOfNonDeviceUsers` · `GetCountOfNonUserDevices` · `GetCountOfTotalCloudUsers` · `GetCountOfOldCloudUsers` · `GetCountOfNewCloudUsers` · `GetCountOfSignUpUsers` · `GetCountOfMigrationUsers` |

**모바일** (`SSO_Controller`): `CheckServerModuleSSO` · `InstantSignUp` · **`MigrationUser`** · `RemoveAccount` · `CheckDuplicateID` · `SignUp` · `Withdrawal` · `RetransmitAuthMail` · `ResendAuthMail` · `VerifyCloudSignUp` · `VerifySignUp` · `ForgotPassword` · `VerifyChangePassword` · `LogIn` · `LogOut` · `GetProfile` · `ChangeProfile` · `ChangePassword`

### 2.2 SDI — 디바이스·배터리 (관리자 **44** + 모바일 12)

**관리자** (`SDI_ControllerAdmin`) — 도메인마다 CRUD + Count + List + Info 패턴

| 도메인 | 엔드포인트 |
|---|---|
| 헬스체크 | `CheckServerModuleSDI` |
| 디바이스 모델 | `AddDeviceModel` · `ModDeviceModel` · `DelDeviceModel` · `GetDeviceModelCount` · `GetDeviceModelList` |
| 디바이스 | `AddDevice` · `ModDevice` · `DelDevice` · `GetDeviceCount` · `GetDeviceList` · `GetDeviceInfo` |
| 배터리 | `AddBattery` · `ModBattery` · `DelBattery` · `GetBatteryCount` · `GetBatteryList` · `GetBatteryInfo` |
| 사용자↔디바이스 | `AddUserDevice` · `ModUserDevice` · `DelUserDevice` · `GetUserDeviceCount` · `GetUserDeviceList` · `GetUserDeviceInfo` |
| 사용자↔배터리 | `AddUserBattery` · `ModUserBattery` · `DelUserBattery` · `GetUserBatteryCount` · `GetUserBatteryList` · `GetUserBatteryInfo` |
| **디바이스↔사용자 (역방향 CRUD)** | `AddDeviceUser` · `ModDeviceUser` · `DelDeviceUser` · `GetDeviceUserCount` · `GetDeviceUserList` · `GetDeviceUserInfo` |
| **배터리↔사용자 (역방향 CRUD)** | `AddBatteryUser` · `ModBatteryUser` · `DelBatteryUser` · `GetBatteryUserCount` · `GetBatteryUserList` · `GetBatteryUserInfo` |
| 역조회 | `GetDeviceUserList` · `GetBatteryUserList` |

> **정정 (2026-07-28 적대적 검증)**: 초판은 관리자 **32** 로 적고 아래 두 CRUD 군(`*DeviceUser` 6 · `*BatteryUser` 6)과 `CheckServerModuleSDI` 를 통째로 빠뜨렸다. `SDI_ControllerAdmin.java` 의 method-level `@RequestMapping` 실측은 **44** 다. (대조로 SSO 18/35 · ELA 2/21 · Core 4 는 실측과 정확히 일치했다 — SDI 만 누락이었다.)

> **⚠ 실제 결함**: 같은 파일에 **중복 매핑**이 있다 — `/GetDeviceUserList` 가 **L284·L325**, `/GetBatteryUserList` 가 **L343·L384** 로 각각 두 번 선언된다. Spring MVC 에서 ambiguous mapping 이므로 기동 실패 또는 비결정적 라우팅이 된다. 위 표의 "역조회" 행이 그 중복분이다.

**모바일** (`SDI_Controller`): `CheckServerModuleSDI` · `GetDeviceModelList` · `RegistDevice` · `UpdateDevice` · `DeleteDevice` · `GetDeviceCount` · `GetDeviceList` · `RegistBattery` · `UpdateBattery` · `DeleteBattery` · `GetBatteryCount` · `GetBatteryList`

**디바이스 레코드가 다루는 필드** (`SDI_Mapper.xml`): `probe_id` · `wifi_ssid` · `wifi_pw` · `mac` · `ip` · **`ctrl_port`** · **`data_port`** · `firmware_version` · **`cv_license`**

→ `ctrl_port`·`data_port` 는 장비의 HC 프로토콜 포트(1234/1235)이고 `cv_license` 는 ContextVision 라이선스다. **클라우드가 장비의 통신 파라미터와 상용 필터 라이선스를 관리한다.**

### 2.3 ELA — 이벤트 로그 (관리자 21 + 모바일 2)

`AddEventGroup` · `ModEventGroup` · `DelEventGroup` · `GetEventGroupCount` · `GetEventGroupList` · `SetGroupEventList` · `GetGroupEventList` · `AddEvent` · `ModEvent` · `DelEvent` · `GetEventCount` · `GetEventList` · `AddEventLog` · `DelEventLog` · `GetEventLogCount` · `GetEventLogList` · `GetUserEventLogCount` · `GetUserEventLogList` · `GetDeviceEventLogCount` · `GetDeviceEventLogList`

모바일은 `CheckServerModuleELA` · `AddEventLog` 둘뿐 — **장비·앱이 올리고 관리자가 조회하는 단방향 구조**다.

### 2.4 `sonex-admin-web` 과의 대응

프론트엔드가 호출하는 **48개 중 47개가 일치**한다. 미매칭 1건 `DeleteAccount` 는 서버에 라우트가 없는 죽은 클라이언트 코드다.

## 3. 인증·권한

| 항목 | 구현 |
|---|---|
| 세션 | **`connect_token`(16자)** 이 테이블 `sso.connect_info` 의 **PK**. 클라이언트가 JSON 본문에 실어 보내면 `Security/CustomAuthenticationFilter.java` 가 조회해 Spring Security 컨텍스트를 채운다 |
| 비밀번호 | 프론트엔드가 **`CryptoJS.SHA256`** 으로 해싱 후 전송 |
| 역할 | `Model/RoleModel.java` — `ROLE_ADMIN` · **`ROLE_ADMIN_MASTER`** · **`ROLE_ADMIN_EDITOR`** · **`ROLE_ADMIN_VIEWER`** · `ROLE_CLOUD` |
| 보호 | Admin 엔드포인트 대부분이 `@Secured({...})`. `LogIn`/`LogOut` 만 비보호 |

DB 컬럼 주석(`sso.sql`)은 `'ROLE_CLOUD, ROLE_ADMIN'` 만 적혀 있어 **Java 쪽 세분화된 역할과 어긋난다**(컬럼은 `varchar(32)` 라 저장은 된다).

## 4. 데이터 계층

MariaDB 10.8. MyBatis 매퍼가 **저장 프로시저를 직접 호출**한다(`call sdi.wa_AddDevice(...)`, `call sso.sp_...`).

| 스키마 | DDL 커밋 | 테이블 |
|---|---|---|
| `cloud` | **있음** | `system_configuration` · `system_event_log` · `system_exception` |
| `sso` | **있음** | `account` · `account_info` · `auth_key` · **`connect_info`** · `notification` · `oem_code` |
| `sdi` | **없음** | 매퍼가 프로시저를 호출하나 테이블 정의가 저장소에 없다 |
| `ela` | **없음** | 동일 |

`.gitignore` 가 `SQL - insert data.sql` 을 제외한다 — 시드·실데이터는 의도적으로 뺐다.

## 5. `sonon-cloud` — Firebase 구성

| 구성요소 | 내용 |
|---|---|
| `functions/` | Cloud Functions(Node 10) — `api/` 함수별 파일 1개, `core/`·`cron/`·`trigger/` |
| `admin-dashboard/` | Vue 2.6 + CoreUI Pro. **Cypress e2e** 설정 |
| `user-dashboard/` | Quasar 1.x SPA |
| `sononx-deploy/` | **74MB 정적 사이트** — `sononx`·`sononvet`·`sphera`·`obvius`·`sonon` 5개 브랜드 마이크로사이트, 설치 가이드 PDF, OTA `.plist` |
| `QtLibrary/FireRestExample` | C++/Qt 클라이언트 SDK 예제(`FireRest`/`SononCloud`) |
| `documents/` | 개발 완료 보고서 + 운영 매뉴얼(스크린샷 20장) |

**HTTPS 함수 17개** (`firebase.json` rewrites): `getDate` · `signUp` · `signIn` · `verifyEmail` · `setSampleUser` · `rmUser` · `mkAdmin` · `uploadLog` · **`stolenDevices`** · `registerDevice` · `resendVerifyEmail` · `updateDevice` · `users` · `sendPasswordResetEmail` · `resetPassword` · `updateUser` · `refreshStatisticsCurrent`

Firestore 컬렉션(`functions/constants.js`): `emailVerifications` · `users` · `admins` · `devices` · `settings` · `groups` · `logs` · `daily` + 문서 `statistics/current`

인증은 **Firebase Authentication + custom claims**(`mkAdmin`). `connect_token` 개념이 없고 역할 모델도 다르다.

**`sonex-admin-web` 의 엔드포인트와 0/11 일치**한다 — 이름 규칙부터 다르고(`signIn` vs `LogIn`), 디바이스는 Firestore 범용 컬렉션이라 프로브 모델·배터리 도메인이 없다.

## 6. 앱 세대를 서버가 열거한다

`SSO_Procedure.java:915` 주석:

```
접속타입 (1:Moana mobile app, 10:SoNex mobile app, 100:SonNex cloud web service)
```

`MigrationUser` 엔드포인트도 있어 **Moana → SoNex 계정 이관이 설계돼 있었다.** 다만 SoNex 앱이 미완성이라 이관은 완료되지 않았다.

## 7. `sonex-admin-web`

빌드 도구가 **전혀 없다** — `package.json`·번들러 부재. Keenthemes 관리자 테마를 통째로 커밋한 정적 사이트다(자체 코드는 HTML 2,530줄 + `web-api.js` 622줄).

화면 12개: 로그인 · 대시보드 · 관리자 계정 · 클라우드 계정 · 디바이스 · **배터리** · 로그 · 내정보 + 디버그용 `test.html`.

- 백엔드 호스트 하드코딩 — `assets/js/common/web-api.js:6`, **평문 HTTP**
- 페이지 `<title>` 이 전부 **`Sonon Cloud Admin`** (저장소명은 sonex)
- 커밋 1개(`"Version 2.11.B - 정식 런칭 버전"`)

## 8. ⚠ 비밀정보 커밋

값은 확인하지 않았고 위치만 기록한다.

| 저장소 | 위치 | 내용 |
|---|---|---|
| `sonex-cloud-backend` | `Core/.../CoreIndexer.xml` 등 **5개 파일** | MariaDB **root 비밀번호**, 대상 `sonex.healcerion.com:3306` |
| `sonon-cloud` | `functions/sharp-imprint-234606-453329870be0.json` | **GCP 서비스 계정 개인키** (git 추적, **운영 중인 시스템**) |

## 9. HLAB-2487 함의

| 관측 | 함의 |
|---|---|
| 클라우드가 2개 스택으로 병존 | 계정·디바이스 도메인이 **두 곳에 각각 구현**돼 있다. 사용자층(B2B vs 소비자)이 달라 단순 병합은 아니다 |
| `sonex-cloud-backend` 가 정지 | 완성도는 높으나(핸들러 136개, admin-web 47/48 대응) 유지되지 않는다. **belle 장비의 클라우드 연동을 어디에 둘지 결정이 필요** |
| SDI 에 중복 라우트 2건(§2.2) | 정지 상태라 드러나지 않았을 뿐 **기동 시 ambiguous mapping** 이다. 재가동·이전 시 먼저 걸린다 |
| `sdi`·`ela` DDL 부재 | 서버 재구축 불가 |
| 클라우드가 `ctrl_port`·`data_port`·`cv_license` 관리 | **장비 프로토콜 파라미터와 상용 라이선스가 클라우드 스키마에 박혀 있다.** 프로토콜을 바꾸면 서버 스키마도 함께 바뀐다 |
| `sonon-cloud` 만 실제 테스트 보유 | Mocha 24 + Cypress e2e |
| 비밀정보 커밋 2건 | 운영 중인 시스템의 키 포함 |

## 10. 미확인

- **belle(500L) 장비가 어느 클라우드에 붙는가** — `sonex-cloud-backend` 샘플에 `SONON500L-H-2202050PP` 가 있으나 실제 운영 연결은 미확인
- `sonex-cloud-backend` 정지 이후 그 기능을 무엇이 대신하는가
- `sdi`·`ela` 스키마 정의 소재
