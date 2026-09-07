# Phase 1 결과

> 판정 기준(지시문 21항): 이 작업 환경은 **Windows(Xcode/macOS/실기기 없음)** 이므로
> "완전 완료"가 아니라 **"환경상 실기기 테스트 불가"** 경로로 보고한다.
> 빌드/실행/런타임 항목은 모두 `NOT_TESTED` 이며 성공으로 기록하지 않는다(지시문 22항).
> 상태 표기: `PASS`(이 환경에서 실제로 완료·검증) / `FAIL` / `NOT_TESTED`.

## 요약 (지시문 21항 "환경상 실기기 테스트 불가")
```
[PASS]       가능한 모든 소스 통합 (PPSSPP/ARMSX2 구조분석 + MeloNX 소스 확보)
[PASS]       Adapter 구현 (common + ppsspp + armsx2 + melonx)
[PASS]       Host 연결 (EmulatorManager ↔ 최소 Host UI)
[PASS]       빌드 설정 (XcodeGen project.yml, entitlements, bridging header, 빌드 스크립트)
[PASS]       테스트 절차 (체크리스트 + XCUITest 자동화)
[NOT_TESTED] 실기기 항목 (빌드/실행/렌더/오디오/입력/전환/IPA)
```
→ **완전 완료 아님.** 다음 단계는 macOS+Xcode+iPhone 16 Pro Max 에서 엔진 링크(`*_LINKED`) 후 검증.

---

## PPSSPP
- Adapter: **PASS** (구현 완료: PPSSPPAdapter.swift + PPSSPPCore.h/.mm, NativeApp API 기반)
- Build: **NOT_TESTED** (Windows 환경, xcodebuild 없음)
- Launch: **NOT_TESTED**
- Stop/Return: **NOT_TESTED**
- Relaunch: **NOT_TESTED**
- 원본 수정 파일 수: **0** (upstream 무수정; ViewControllerMetal.mm 컨텍스트는 통합 시 재사용)
- 적용 patch: **없음** (04_patches/ppsspp 비어 있음)

## ARMSX2
- Adapter: **PASS** (구현 완료: ARMSX2Adapter.swift + ARMSX2Core.h/.mm, VMManager/CPU스레드 기반)
- Build: **NOT_TESTED**
- Launch: **NOT_TESTED** (PS2 BIOS 필요)
- Stop/Return: **NOT_TESTED**
- Relaunch: **NOT_TESTED**
- 원본 수정 파일 수: **0** (Host:: 콜백은 pcsx2-sdl/Main.cpp 재사용 예정)
- 적용 patch: **없음**

## MeloNX
- Adapter: **PASS** (구현 완료: MeloNXAdapter.swift + MeloNXCore.swift, SN_* C ABI/@_silgen_name 기반)
- 소스 확보: **PASS** — AzureDominus/melonx@XC-ios-ht `55f84af15144e40d7fbe8984747855534d2a8ec1` → 01_sources/MeloNX
- Build: **NOT_TESTED** (Ryujinx NativeAOT 라이브러리 + SDL2 링크 필요)
- Launch: **NOT_TESTED** (prod.keys + firmware 필요)
- Stop/Return: **NOT_TESTED**
- Relaunch: **NOT_TESTED**
- 원본 수정 파일 수: **0**
- 적용 patch: **없음**
- 비고: 공식 upstream(git.ryujinx.app)은 이 환경에서 접근 불가 → 공개 GitHub 미러/포크 사용(BUILD_NOTES §3에 차이 기록).

## 교차 코어 테스트
- PSP → PS2: **NOT_TESTED**
- PS2 → Switch: **NOT_TESTED**
- Switch → PSP: **NOT_TESTED**
- 반복 실행: **NOT_TESTED**
- 자동화 준비: **PASS** (06_tests/StarlightEmulatorUITests/CoreSwitchUITests.swift)
- 체크리스트: **PASS** (06_tests/CORE_SWITCH_CHECKLIST.md)

## 단일 IPA
- 생성 여부: **NOT_TESTED** (빌드 스크립트 07_build/build_ios.sh 준비됨, Mac 에서 실행)
- 설치 여부: **NOT_TESTED**
- 실기기 실행 여부: **NOT_TESTED**
- 대체 산출물: XcodeGen `project.yml` → `xcodegen generate` 로 .xcodeproj/워크스페이스 생성

## 업데이트 구조 (지시문 19항)
- Adapter/upstream 분리: **PASS** (03_adapters ↔ 01_sources ↔ 04_patches 분리, patch 0개)
- upstream 교체 → 재빌드 모의: **NOT_TESTED** (빌드 불가 환경; 절차는 UPDATE_GUIDE 에 명시)

## 남은 문제 / 다음 작업
1. **엔진 정적 라이브러리/프레임워크 빌드**(Mac)
   - PPSSPP: CMake iOS 툴체인으로 정적 라이브러리화
   - ARMSX2: pcsx2 core + common 정적 라이브러리화, pcsx2-sdl Host:: 이식
   - MeloNX: Ryujinx.Headless.SDL2 를 NativeAOT(ios-arm64)로 빌드 → C 심볼 라이브러리 + SDL2/FFmpeg xcframework
   - 재현: `07_build/project.yml` 의 `*_LINKED` 활성 + dependencies/헤더경로 추가 → `xcodegen generate`
2. **PPSSPP GraphicsContext 통합**: `StarlightPPSSPPCreateMetalContext()` 를 ios/ViewControllerMetal.mm 기반으로 구현
3. **ARMSX2 렌더 윈도우**: `Host::AcquireRenderWindow` 가 공유 CAMetalLayer→WindowInfo 반환하도록 구현
4. **MeloNX set_native_window 타이밍**: SN_main 시작 시점과 레이어 전달 순서 실기기 확인
5. **복수 JIT 공존 검증**(BUILD_NOTES §5-1): ARMSX2+MeloNX recompiler 공존 — 최우선
6. **SDL2/SDL3 심볼 충돌 확인**(BUILD_NOTES §5-2)
7. **실기기 전 항목 검증** → 본 문서의 NOT_TESTED 를 실제 결과로 갱신
   - 로그 위치: `08_logs/` (xcodegen.log, xcodebuild.log, 런타임 로그)
   - 재현 방법: `06_tests/CORE_SWITCH_CHECKLIST.md`
