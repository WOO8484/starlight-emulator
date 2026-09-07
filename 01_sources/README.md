# 01_sources — upstream 엔진 원본

각 엔진의 **원본(upstream)** 만 둔다. 우리 코드는 절대 여기에 두지 않는다
(우리 코드 = `03_adapters`, 불가피한 변경 = `04_patches`). 지시문 4항.

| 폴더 | upstream | branch | 비고 |
|---|---|---|---|
| PPSSPP | https://github.com/hrydgard/ppsspp | master | submodule 권장, `submodule update --init` 필요 |
| ARMSX2 | https://github.com/ARMSX2/ARMSX2 | master | commit `de57f431…` |
| MeloNX | https://github.com/AzureDominus/melonx | XC-ios-ht | commit `55f84af1…` (공식 Forgejo 의 공개 미러) |

- 대용량이므로 저장소에는 커밋하지 않는다(`.gitignore`). 로컬 디스크/submodule 로만 유지.
- 정확한 commit hash·차이·확보일은 `00_docs/BUILD_NOTES.md` 참조.
- 확보/업데이트 절차는 `00_docs/UPDATE_GUIDE.md` 참조.

## 현재 로컬 상태 (2026-09-08, Windows 분석 환경)
- **MeloNX**: shallow 클론 확보됨(구조 분석 완료).
- **PPSSPP / ARMSX2**: 대용량+빌드 불가로 전체 클론 대신 GitHub API/raw 로 진입점·API 분석 완료.
  Mac 에서 전체 클론(또는 submodule) 필요.
