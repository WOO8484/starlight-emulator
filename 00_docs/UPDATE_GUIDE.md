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

## 1단계 모의 검증 (지시문 19항)
최소 한 엔진(예: PPSSPP)에서 다음을 확인하고 결과를 PHASE1_RESULT 에 기록:
```
기존 upstream → Adapter 분리 확인 → upstream clean checkout/교체 → patch 재적용
→ Adapter 재연결 → 빌드
```
Adapter 가 upstream 내부에 깊게 침투했다면(= upstream 파일을 직접 광범위 수정) 구조를 단순화한다.
현재 설계는 upstream 무수정(0 patch) 을 기본으로 하므로 이 모의 검증은 "patch 0개 → 교체 후 그대로 재빌드"
가 성립하는지 확인하는 형태다.
