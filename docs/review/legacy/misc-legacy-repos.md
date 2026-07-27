# [범위 밖] 300 시리즈 전용·프로토타입 저장소

> **범위 판단**: 아래는 **belle 과 무관하거나 300 시리즈 전용**이라 검토 범위 밖이다.
> **근거**: 코드 직접 읽기(2026-07-27).

## 1. `desktop/legacy/cuattro-sdk` — Windows 호스트 SDK

C++ Win32 DLL(`SononClient.dll`) + **C# WinForms 데모 앱**. .NET Framework 4.7, VS2017.

- **`moana/framework/SononClient` 의 포크**다 — 파일 17개 중 15개 동명(`BasePacket`·`BaseSocket`·`CtrlChannel`·`DataChannel`·`SononClient`·`SononCtrlPacket`·`SononDataPacket`·`SononPacket`), 내용은 분기
- 지원 모델이 **300C·300L 뿐** — 500 계열 문자열 0건. belle 지원 없음
- "Cuattro" 는 별도 제품이 아니라 `#ifdef HAVE_CUATTRO` 브랜딩 스위치. 코드는 전부 `CSononClient`·`Sonon*` 계열
- 58커밋, 2017-10 ~ 2018-12, 단독 저자. 테스트·CI·문서 없음

## 2. `server/` 의 300 시리즈 전용·프로토타입

### 3.1 `russia-server` — 39줄 프로토타입

Flask 개발 서버 1파일. 엔드포인트 2개뿐이다.

| 메서드·경로 | 동작 |
|---|---|
| `POST /api/v1/saveUSMaterials` | JSON 을 **`print()` 만 하고** uuid4 를 반환. 저장하지 않는다 |
| `POST /api/v1/saveUSImage?id=&pointNum=&mimeType=` | 요청 본문 바이트를 `UPLOAD_FOLDER/<id>_<pointNum>.<mimeType>` 로 기록 |

`UPLOAD_FOLDER = 'd:\\release\\ruski_test'` — 개발자 머신 경로. 인증·검증·에러 처리 전무. 커밋 메시지가 스스로 `"Simple REST API test server for Russia ambulance project"` 라고 밝힌다.

### 3.2 `dicomcontroller` — 서버가 아니라 DICOM 클라이언트 라이브러리

DCMTK 기반 C++ 라이브러리 4클래스(1,522 LOC) + iOS 데모 앱(`iOS_Sample/DCMTK4iOS`).

구현된 DICOM 서비스: **C-STORE**(`DcmStorageSCU::sendSOPInstances`) · **C-ECHO** · **모달리티 워크리스트 C-FIND**(`UID_FINDModalityWorklistInformationModel`). **SCP(수신) 코드는 없다** — 항상 `NET_REQUESTOR` 로만 연결한다. 즉 PACS 에 **보내는 쪽**이다.

제품 결합이 명확하다:
- `DicomController.h`: `HEALCERION_UID_ROOT "1.3.6.1.4.1.45207"` (등록된 DICOM UID root), `SONON300C_UID_ROOT`
- `DicomDataAdapter.cpp:20`: `#define kModelName "SONON 300C"`
- `DicomNetworkController.cpp:20`: `#define kApplicationAETitle "SONON300C"`

다만 데모 코드의 접속 정보가 로컬 LAN 하드코딩(`192.168.0.143`, AE title `testSCU`·`OMMWKLST`)이고, JPEG 압축 경로는 주석 처리된 채 남아 있다. 커밋 14개가 다중 프레임·JPEG·메모리 최적화·태그 추가로 이어지는 실제 개선 이력이다.

> **DICOM 기능의 현재 위치는 여기가 아니다.** `sonex-framework` 가 `DicomHandler` 모듈(2,732 LOC)과 DCMTK 3.6.5 를 따로 갖는다. 이 저장소는 **2017년 세대의 선행 구현**이고, 두 구현 사이에 코드 공유 증거는 확인하지 않았다(미확인).
