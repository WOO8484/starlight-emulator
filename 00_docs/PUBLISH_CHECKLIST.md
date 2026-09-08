# PUBLISH_CHECKLIST.md — 공개 전 최종 점검 결과

점검 일시: 2026-09-08 · 대상 브랜치: master · 계정: WOO8484 · 공개 예정: public

| 항목 | 상태 | 근거 |
|---|---|---|
| BIOS 없음 | PASS | 이력 전체 파일 스캔에 PS2 BIOS 없음 |
| Switch keys 없음 | PASS | `prod.keys`/`title.keys` 이력에 없음 |
| firmware 없음 | PASS | `firmware/` 이력에 없음 |
| 게임 파일 없음 | PASS | iso/cso/nsp/xci 등 이력에 없음(05_testdata 는 .gitkeep 만) |
| Apple 인증정보 없음 | PASS | p12/mobileprovision/cer/pem 이력에 없음 |
| PAT/토큰/개인키 없음 | PASS | `ghp_`/`github_pat_`/`BEGIN * PRIVATE KEY`/`oauth_token` 이력 검색 0건. gh 토큰은 keyring(저장소 밖) |
| Git 과거 이력 검사 | PASS | `git log --all --name-only`(53 파일) + 전 commit 내용 패턴 검색 clean |
| .gitignore 적용 | PASS | 게임/키/펌웨어/서명/시크릿/세이브/빌드산출물 차단. 추적파일 배제 0 |
| LICENSE 존재 | PASS | GPL-3.0 전문(674줄) |
| THIRD_PARTY_NOTICES.md 존재 | PASS | 엔진 3종 + 서드파티 라이선스/commit/patch 기록 |
| README 공개 상태 정리 | PASS | 목적/대상/상태(NOT_TESTED)/빌드방식/upstream/미포함물/라이선스 명시 |
| Actions 로그 secret 출력 없음 | PASS | 워크플로가 secret 미사용·미출력. env 전체 dump 없음. artifact 에 keys/BIOS/게임 없음 |

## 검사 방법(재현)
```bash
git log --all --pretty=format: --name-only | sort -u          # 이력 파일 목록
git grep -iInE 'ghp_[A-Za-z0-9]{20,}|github_pat_|BEGIN .*PRIVATE KEY|oauth_token' $(git rev-list --all)
git ls-files | git check-ignore --stdin                        # 추적파일 중 무시대상(있으면 문제)
```

## 결론
모든 항목 PASS → 공개(public) 저장소 전환 가능. (⚠ 향후에도 BIOS/keys/firmware/게임/인증서는
`.gitignore` 로 차단되며 커밋 금지. 실기기 데이터는 저장소 밖에서만 관리.)
