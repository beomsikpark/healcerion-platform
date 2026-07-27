# 검토 문서 색인

HLAB-2487(힐세리온 전체 SW 리팩토링 검토)의 산출물이다. **미러 소스를 다시 읽는 대신 이 문서들을 먼저 읽는다.** 코드 재탐색은 여기 없는 것을 확인할 때만 한다.

## 그룹별 코드 분석

| 문서 | 대상 | 핵심 |
|---|---|---|
| [device-firmware.md](device-firmware.md) | `device/` 5건 | 3개 무관 스택(Zynq Linux · Socionext 베어메탈 · MSP430). **rootfs 빌드가 미러에 없다.** 호스트와는 단일 "HC" 프로토콜로 만난다 |
| [mobile-codebase.md](mobile-codebase.md) | `mobile/` 2건 | 2.0GB 중 자체 소스 0.3%. 6개 타깃 중 실제는 4개. 앱↔SDK 결합이 플랫폼마다 3가지 |
| [web-server-fpga.md](web-server-fpga.md) | `web/`·`server/`·`fpga/` 6건 | `server/` 에 실 서버가 없다. `fuji` 는 `ginny` 의 포크(MD5 동일 9건). `fpga/` 는 `device/` 와 결합돼 있다 |

## 공백 정리

| 문서 | 내용 |
|---|---|
| [legacy-gaps.md](legacy-gaps.md) | **`legacy/` 구성에서 빠진 것 전부** — 저장소 5건 · 빌드 계통(커널·BSP·툴체인·이미지 레시피) · 소스 없는 바이너리 · 생성 도구 · 모델 빈칸. 우선순위와 요청 목록 포함 |

## 배경·환경

| 문서 | 내용 |
|---|---|
| [dev-environment.md](dev-environment.md) | Phabricator 단일 스택, 접근 권한, 우리 기준(Linear+GitHub) 대비 — **개발 환경의 SOT** |
| [repo-activity.md](repo-activity.md) | 커밋·파일 수 실측과 활동성 해석 — **활동성의 SOT** |
| [sonex-architecture.md](sonex-architecture.md) | 힐세리온 **자체 문서**가 주장하는 sonex 아키텍처·개발 관행 |

> `sonex-architecture.md` 는 **그들의 서술**, `mobile-codebase.md` 는 **코드 실측**이다. 어긋나는 지점은 후자의 §3.3·§8 에 표시했다.

## 문서 간 규약

- **주장과 사실을 구분한다** — 저장소 설명·PPT·그들 문서는 주장이다. 코드·해시·식별자로 확인한 것만 검증됨으로 적는다
- **증거 차원을 섞지 않는다** — 존재·순서·동일성·인과는 별개다. 동일성은 MD5·IDCODE 같은 식별자 일치로만 확정한다
- 미확인은 미확인으로 남긴다. 각 문서 마지막 절이 그 목록이다

## 2026-07-27 권한 확대 — 결론 다수가 뒤집혔다

힐세리온이 계정 권한을 열어 가시 저장소가 **33 → 56건**, 클론본이 **13 → 31건**이 됐다. 그 결과:

| 뒤집힌 결론 | 실제 | 문서 |
|---|---|---|
| 빌드 계통이 통째로 없다 | `belle-bsp` 가 **PetaLinux 프로젝트**로 존재 | [legacy-gaps.md §2](legacy-gaps.md) |
| FPGA 테이블 생성기가 없다 | `bf-delay-calculation` 이 그것(MATLAB) | [web-server-fpga.md §4.5](web-server-fpga.md) |
| `server/` 에 실 서버가 없다 | `sonex-cloud-backend` 가 admin-web 의 서버(47/48 일치) | [web-server-fpga.md §3.3](web-server-fpga.md) |
| 최근 활동은 sonex 2건뿐 | `sonon-cloud`(2026-06)·`belle-fw`(2026-07)도 활발 | [repo-activity.md §0](repo-activity.md) |
| `rHFW` = 데스크톱 호스트 SW | **`ginny-fw`, 300 시리즈 펌웨어**(커밋 1,109개) | [legacy-gaps.md §3](legacy-gaps.md) |
| elsa-fw 의 옛 이름이 ginny-fw | **반증.** 별개 저장소이고 공통 커밋 조상 없음 | [legacy-gaps.md §3](legacy-gaps.md) |

> **방법론 교훈**: 접근이 막힌 상태에서 "부재" 를 결론으로 쓰면 안 된다. 쓸 수 있는 표현은 **"확인 불가"** 뿐이다. 도구 한계도 같다 — 테이블 생성기를 놓친 원인은 ISO-8859 인코딩 파일이 `grep -a` 없이 매칭되지 않은 것이었다.

## 아직 답이 없는 것 (전 그룹 공통)

1. **FSBL·PMU 소스와 Vivado 하드웨어 프로젝트** — 부팅 1단계와 FPGA 이미지가 재생성 불가 = [legacy-gaps.md §2.2](legacy-gaps.md)
2. **PetaLinux 툴체인 버전** — 확정돼야 빌드 재현이 가능하다
3. **프로토콜 정본 정의** — `PACKET_HEADER_S` 가 6개 코드베이스에서 쓰이는데 **선언이 어느 저장소에도 없다** = [device-firmware.md §8.1](device-firmware.md)
4. **⚠ 비밀정보 커밋 2건** — 운영 중인 시스템의 키 포함 = [legacy-gaps.md §10](legacy-gaps.md)
