# 사이버보안 대응 — 리팩토링 vs 신규개발 분리

> **실측 SOT**: [../review/cybersecurity.md](../review/cybersecurity.md). 이 문서는 그 위에서 **판단**한다 — 각 결함이 기존 구조를 정리하면 되는 리팩토링인지, 없던 계층을 새로 설계·구현해야 하는 신규개발인지를 가른다. 실측 자체는 반복하지 않는다.

## 1. 왜 가르는가

리팩토링은 **외부 동작을 보존**하며 내부 구조를 정리하는 작업이고, 검증 기준은 "바꾸기 전후 동작이 같은가"다. 그런데 [review/cybersecurity.md](../review/cybersecurity.md)가 찾은 결함 다수는 **정확히 그 "동작"(인증 없음·평문 전송·서명검증 없음) 자체가 바뀌어야 하는 대상**이다 — 동작 보존이 아니라 동작 변경이 목표이므로, 회귀 테스트로 안전성을 보장하는 리팩토링의 틀이 그대로 적용되지 않는다. 두 갈래를 섞으면 [r1](r1/plan.md)(sonex-framework 완성) 같은 구조 정리 계획에 범위·일정이 불명확한 신규 설계 작업이 끼어들어 진행 판정이 흐려진다.

## 2. 리팩토링 성격 — 저비용, 기존 계획과의 관계가 확인됨

| 결함 | 상태 | 근거 |
|---|---|---|
| sonex DB 암호화 — Windows/macOS 미적용 + "Moana 호환" legacy fallback 죽은 코드([review/cybersecurity.md §DC-01·DC-03](../review/cybersecurity.md)) | **기존 계획에 이미 등록됨** | [r1/plan.md](r1/plan.md) Phase 0-C-W. wxSQLite3 배선이 Android/iOS 엔 이미 있다 — 빌드 타깃 확장 + 재시도 로직 버그 수정이면 됨. 상세 = [../review/sonex-framework.md §8.1b](../review/sonex-framework.md) |
| `belle_flask` 하드코딩 계정 3종(`user`/`admin`/`ncc`)·평문 비밀번호([review/cybersecurity.md §IA-04](../review/cybersecurity.md)) | **기존 계획의 판단 항목에 걸림** | [r2/plan.md](r2/plan.md) Phase 8-D가 이미 "`belle_flask` 유지/제거는 힐세리온 결정"으로 다룬다. **유지로 결정되면** 자격증명 경화(계정 CRUD·비밀번호 정책)를 이 Phase 의 addendum으로 붙이면 된다 — 새 트랙이 필요 없다 |
| **belle `rootfs_config`** — root 비밀번호 평문 하드코딩(`Q!12@W`)·`imagefeature-debug-tweaks=y`·무인증 FTP·SSH 자동기동 등 RA-05 대상 서비스들([review/cybersecurity.md §IA-04·07·RA-05](../review/cybersecurity.md)) | **계획에 아직 없음 — 다만 이유가 명확하다** | 값 자체는 설정 파일 한 줄씩 바꾸는 저비용 작업이나, 이 파일들은 `belle-bsp`(PetaLinux 프로젝트) 소속이고 [r2/plan.md §7](r2/plan.md)이 **"커널·U-Boot·FSBL·PMU·BSP 범위 밖 — 5년째 동결이고 밑단 현대화는 별도 결심"** 이라고 명시적으로 r2 범위에서 뺐다. 즉 이 항목은 새 설계가 필요한 게 아니라, **이미 존재하는 "BSP 현대화 별도 결심" 미결정에 딸려 orphan 상태**다 |

## 3. 신규개발 성격 — 별도 트랙, 범위·일정 미정

| 결함 | 왜 신규개발인가 |
|---|---|
| HC 프로토콜 인증 부재(IA-01) | 프로토콜 자체(장비+앱 양쪽)에 인증 핸드셰이크가 없다 — 추가하려면 프로토콜 버전업이 필요하고, **이미 필드에 배포된 belle 장비와의 하위호환**이 걸린다. [legacy/proof/protocol-sot/](legacy/proof/protocol-sot/)가 정본화는 끝냈지만 인증 추가는 다루지 않는다 |
| 펌웨어 서명검증 부재(SI-09) + 부트 무결성(SI-11) | PKI(서명키 발급·관리) + 장비측 검증 로직(belle) + Xilinx 보안부트 활성화(efuse 굽기 가능성) — 이 전부가 지금 존재하지 않는다. SI-11이 필요로 하는 FSBL·U-Boot 영역은 [r2/plan.md §7](r2/plan.md)이 이미 범위 밖으로 명시한 곳과 겹친다 |
| 클라우드 TLS 전환(SI-01) | 인증서 발급·배포·서버 설정 변경이 필요하고, `sonex-cloud-backend`가 사실상 정지 상태([../review/cloud-server.md](../review/cloud-server.md))라 재가동 여부부터 결정해야 한다 |
| belle 계정 체계 전면 개편(IA-02·03·07, UC-01) | 계정 관리 서브시스템 자체가 설계돼 있지 않다 — LDAP/AD 연동이든 자체 구현이든 신규 |
| sonex 앱 PIN·생체인증(IA-01), 세션 잠금(UC-03), 부인방지용 행위자 식별 컬럼(UC-07) | 클라우드 계정 인증 위에 얹는 로컬 보안 계층이 없다 — UI·데이터모델 신설 필요 |

## 4. 처리 방향

- **§2**는 각 항목이 속한 기존 계획에 이미 실행 지점이 있다 — 해당 Phase 실행 시 자연히 처리된다. `belle rootfs_config` 항목만 예외로, "BSP 현대화 별도 결심"이 내려질 때 함께 처리되도록 표시해 둔다.
- **§3**은 루트 [CLAUDE.md](../../CLAUDE.md) 미해결 블로커 §6("의료기기 규제 제약")과 동일한 성격의 미결 판단이다. 별도 트랙 분리·범위 확정은 **힐세리온과의 협의가 선행**돼야 하며, 이 문서는 그 필요성과 항목 목록만 기록한다 — 구현 계획(Phase 분해)은 협의 이후로 미룬다.
