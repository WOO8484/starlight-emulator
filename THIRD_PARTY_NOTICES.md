# THIRD_PARTY_NOTICES

이 저장소(Starlight Emulator)는 **우리 통합 코드(Host/Adapter/patch/빌드 스크립트/CI/문서)만** 포함한다.
아래 upstream 엔진과 서드파티 라이브러리의 **원본 소스/바이너리는 포함하지 않으며**, 빌드 시
지정된 commit 으로 clone/다운로드된다. 각 구성요소는 자신의 라이선스를 그대로 따른다.

각 라이선스 전문은 해당 upstream 저장소의 지정 commit 안에 있다.

---

## 통합 엔진

### PPSSPP (PSP)
- upstream: https://github.com/hrydgard/ppsspp
- commit: `98e70c8ca3435d532a059add0b4fb90a4a091248`
- license: **GNU GPL-2.0-or-later** (일부 구성요소 별도 라이선스; upstream LICENSE.TXT 참조)
- 우리 변경(patch): `04_patches/ppsspp/append_static_lib.cmake` — CMakeLists 끝에 정적 라이브러리
  타깃 **추가만**(코어 소스 무수정, 빌드 경계 한정)

### ARMSX2 (PS2, PCSX2 fork)
- upstream: https://github.com/ARMSX2/ARMSX2
- commit: `de57f431c41218a17b0eecae2aabaf5d3b01c16f`
- license: **GNU GPL-3.0-or-later** (PCSX2 계열)
- 우리 변경(patch): `04_patches/armsx2/0001-embed-frontend.patch` — `pcsx2-sdl/Main.cpp` 의
  `main()`/렌더그룹을 `#ifndef ARMSX2_EMBED` 로 가드(코어 무수정, 빌드 경계 한정)

### MeloNX (Switch, Ryujinx fork)
- repository: https://github.com/AzureDominus/melonx (공식 Forgejo 미러/포크)
- branch: `XC-ios-ht`
- commit: `55f84af15144e40d7fbe8984747855534d2a8ec1`
- license: **MeloNX 저장소 LICENSE 참조** (기반 Ryujinx 는 **MIT**)
- 우리 변경(patch): **없음** (빌드 스크립트만 사용)
- 공식 upstream(git.ryujinx.app) 과의 차이는 `00_docs/BUILD_NOTES.md §3` 참조

---

## 서드파티 라이브러리 (엔진이 링크/동봉)

| 라이브러리 | 사용 엔진 | 라이선스(대표) |
|---|---|---|
| SDL2 | MeloNX | zlib |
| SDL3 | ARMSX2 | zlib |
| MoltenVK | 3엔진(Vulkan→Metal) | Apache-2.0 |
| FFmpeg (libav*) | PPSSPP, MeloNX | LGPL-2.1+/GPL (빌드 구성에 따름) |
| fmt | ARMSX2 | MIT |
| Dear ImGui | PPSSPP, ARMSX2 | MIT |
| zlib | PPSSPP, ARMSX2 | zlib |
| libzip | PPSSPP, ARMSX2 | BSD-3-Clause |
| cubeb | ARMSX2 | ISC |
| SoundTouch | ARMSX2 | LGPL-2.1 |
| libchdr | ARMSX2 | 각 구성요소별 |
| .NET / ARMeilleure | MeloNX | MIT |

> 위 표는 대표 라이선스 요약이다. 정확·최신 정보는 각 upstream 의 지정 commit 내 라이선스 파일을 따른다.

---

## 결합 저작물 관련 안내
- 이 프로젝트를 실제 빌드하면 GPL-2.0+(PPSSPP)·GPL-3.0+(ARMSX2)·MIT(MeloNX/Ryujinx) 구성요소가
  하나의 바이너리로 결합되며, 그 **결합 결과물은 GPL-3.0** 조건을 따른다.
- 따라서 이 저장소의 **우리 코드도 GPL-3.0-or-later** 로 배포한다(`LICENSE` 참조).
- **BIOS / prod.keys / firmware / 게임 / 인증서는 이 저장소에 포함되지 않으며 배포하지 않는다.**
  사용자가 본인 실기기에서만 합법적으로 확보·사용한다.
- 소스 저장소 공개와 완성 IPA의 공개 배포는 **별개 사안**으로 취급한다(IPA 공개 배포는 각 엔진
  라이선스·저작권 검토 후 별도 결정).
