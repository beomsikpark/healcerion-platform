# 참고 자료 색인

외부 기관이 발행한 가이드라인·표준 문서를 보관한다. [review/](../review/)(코드 실측)·[refactoring/](../refactoring/)(판단)과 달리 **우리가 작성한 것이 아니다** — 원문·발췌를 그대로 담고, 우리 해석·판단은 섞지 않는다. 필요하면 `refactoring/` 쪽에서 이 폴더를 인용한다.

## 현재 대상 — 의료기기 사이버보안

힐세리온은 의료기기 제조사이므로, SW 구조 리팩토링이 규제 요구와 충돌하지 않는지 참고할 필요가 있다. 국내(식약처) 사이버보안 허가·심사 가이드라인은 확보·정독 완료(아래). 나머지는 관련 분야에서 널리 쓰이는 문서 후보이며 아직 이 폴더에 추가되지 않았다 — 목록이지 보유 확인이 아니다.

- IEC 81001-5-1 (Health software and health IT systems safety, effectiveness and security — Security)
- IEC 62443 (Industrial communication networks — network and system security, 국내판 KS X IEC 62443 포함)
- MDCG 2019-16 (EU 의료기기 사이버보안 가이드)
- AAMI TIR57 (Principles for medical device security — risk management)
- FDA, *Cybersecurity in Medical Devices: Quality System Considerations and Content of Premarket Submissions* (mfds-cybersecurity-guideline.md 참고문헌으로만 인용됨, 원문 미확보)

> IEC 62304(SW 생명주기)·ISO 14971(위험관리)은 사이버보안 전용이 아닌 일반 규제 표준이다. 루트 [CLAUDE.md](../../CLAUDE.md) 미해결 블로커 §6 참조.

## 문서

| 문서 | 발행 기관 | 내용 |
|---|---|---|
| [mfds-cybersecurity-guideline.md](mfds-cybersecurity-guideline.md) + 원문 PDF | 식품의약품안전처 식품의약품안전평가원 (안내서-0995-05, 2025-01-10) | 의료기기 사이버보안 허가·심사 요구사항 30개(IA/UC/SI/DC/TRE/RA) 및 제출자료 범위 — 원문 발췌. belle·sonex 대비 판정은 [../review/cybersecurity.md](../review/cybersecurity.md) |

## 규약

- 원문 PDF 또는 발췌 markdown을 그대로 보관한다. 요약을 쓰더라도 우리 판단은 넣지 않는다
- 파일명: `<발행기관>-<문서번호 또는 축약명>.md` (예: `fda-premarket-cybersecurity.md`, `iec-81001-5-1.md`)
- 저장소 설명·PPT와 마찬가지로 **버전·발행일을 반드시 함께 적는다** — 표준은 개정되므로 어느 판이 참고됐는지 불명확하면 근거로 쓸 수 없다
