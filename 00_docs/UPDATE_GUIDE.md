# UPDATE_GUIDE.md — 엔진 업데이트 구조 (지시문 4·19항)

## 목표
```
엔진 업데이트 ≈ upstream 교체 + 최소 patch 재적용 + 재빌드
```
Adapter 코드(`03_adapters`)와 upstream(`01_sources`)을 절대 섞지 않는다. 우리 변경은
Adapter 또는 `04_patches/<engine>/*.patch` 로만 존재해야 한다.

## 저장소 배치 원칙
```
01_sources/<ENGINE>   ← upstream (submodule 권장, 우리가 수정하지 않음)
03_adapters/<engine>  ← 우리 코드 (얇은 Adapter/Bridge)
04_patches/<engine>   ← 불가피한 upstream 변경만 (patch 파일)
```

## 권장: submodule 전환 (Mac/온전한 네트워크 환경에서)
현재 `01_sources/MeloNX` 는 분석용 shallow 클론이다. 정식 운영 시 submodule 로 고정:
```bash
git submodule add -b master https://github.com/hrydgard/ppsspp.git 01_sources/PPSSPP
git submodule add https://github.com/ARMSX2/ARMSX2.git             01_sources/ARMSX2
git submodule add -b XC-ios-ht https://github.com/AzureDominus/melonx.git 01_sources/MeloNX
git -C 01_sources/PPSSPP submodule update --init   # ffmpeg 등 하위 submodule
```
각 엔진의 commit hash 는 `BUILD_NOTES.md` §1~3 에 기록/갱신.

## 업데이트 절차 (엔진 1종 기준)
1. `git -C 01_sources/<ENGINE> fetch && git checkout <새 tag/commit>`
2. `04_patches/<engine>/*.patch` 를 `git apply` (충돌 시 최소 수정 후 patch 갱신)
3. Adapter 재빌드: `03_adapters/<engine>` 의 코어 심볼/API 시그니처 변화 확인
   - PPSSPP: `NativeApp.h` 시그니처
   - ARMSX2: `VMManager.h` / `Host.h` 콜백
   - MeloNX: `Ryujinx.Headless.SDL2` 의 `[UnmanagedCallersOnly]` export 이름/인자
4. 회귀 테스트: `06_tests/CORE_SWITCH_CHECKLIST.md` + XCUITest 재실행

## patch 생성 예
```bash
# upstream 내부를 부득이 수정한 경우:
git -C 01_sources/ARMSX2 diff > ../../04_patches/armsx2/0001-<설명>.patch
# 이후 clean checkout 에서:
git -C 01_sources/ARMSX2 apply ../../04_patches/armsx2/0001-<설명>.patch
```

## 현재 upstream 수정 현황 (지시문 4항 — 최소 유지)
| 엔진 | 수정 | 파일 | 성격 |
|---|---|---|---|
| PPSSPP | 1 | `CMakeLists.txt` 끝 append | 정적 라이브러리 타깃 추가(코어 소스 무수정). `04_patches/ppsspp/append_static_lib.cmake` |
| ARMSX2 | 1 | `pcsx2-sdl/Main.cpp` | `main`+렌더그룹 `#ifndef ARMSX2_EMBED` 가드(코어 무수정). `04_patches/armsx2/0001-embed-frontend.patch` |
| MeloNX | 0 | — | 빌드 스크립트만 사용 |

핵심 코어(PPSSPP `Core`, PCSX2 `pcsx2`/`common`, Ryujinx .NET)는 **무수정**. 위 2건은 빌드/링크
경계에만 국한된 얕은 변경이므로 upstream 교체 시 재적용 부담이 작다.

## 1단계 모의 검증 (지시문 19항)
최소 한 엔진(예: MeloNX — patch 0개)에서 다음을 확인하고 결과를 PHASE1_RESULT 에 기록:
```
기존 upstream → Adapter 분리 확인 → upstream clean checkout/교체 → patch 재적용(있으면)
→ Adapter 재연결 → 빌드
```
MeloNX 는 patch 0 이므로 "upstream 교체 → 빌드 스크립트 재실행"만으로 갱신 성립.
PPSSPP/ARMSX2 는 위 얕은 patch 1건만 재적용하면 된다. Adapter 가 upstream 내부에 깊게 침투하지 않도록
(우리 코드는 03_adapters 에만) 유지한다.

## Mac 없는 빌드/업데이트 (GitHub Actions) — CI_BUILD_GUIDE.md 참조
로컬(Windows)에 Mac 이 없으므로 실제 iOS 컴파일은 GitHub Actions macOS 러너가 수행한다.
```
Windows 에서 코어/Adapter/patch 갱신 (기준 commit 교체 시 07_build 스크립트 + BUILD_NOTES 갱신)
→ git push
→ Actions ▸ "iOS Build" ▸ Run workflow
→ 로그/unsigned IPA artifact 회수
→ (실패 시) Windows 에서 수정 → push → 재실행
→ iPhone 16 Pro Max 에서 SideStore/AltStore 재서명·설치 → 실기기 검증
```
빌드 스크립트가 각 엔진을 **기준 commit 으로 clone** 하므로 Actions 는 최신 HEAD 를 임의로 쓰지 않는다.
수동 Xcode GUI 편집이 필요한 구조를 만들지 않는다(모든 설정은 project.yml/스크립트/04_patches).
