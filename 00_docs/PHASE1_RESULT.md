# Phase 1 결과

> 판정 기준(지시문 21항): 이 작업 환경은 **Windows(Xcode/macOS/실기기 없음)** 이므로
> "완전 완료"가 아니라 **"환경상 실기기 테스트 불가"** 경로로 보고한다.
> 빌드/실행/런타임 항목은 모두 `NOT_TESTED` 이며 성공으로 기록하지 않는다(지시문 22항).
> 상태 표기: `PASS`(이 환경에서 실제로 완료·검증) / `FAIL` / `NOT_TESTED`.

## 요약 (지시문 21항 "환경상 실기기 테스트 불가")
```
[PASS]       가능한 모든 소스 통합 (PPSSPP/ARMSX2 진입점·빌드타깃 확정 + MeloNX 소스 확보)
[PASS]       Adapter 구현 (common + ppsspp + armsx2 + melonx)
[PASS]       Host 연결 (EmulatorManager ↔ 최소 Host UI)
[PASS]       엔진 링크 준비 (빌드 타깃/심볼/헤더/의존성/entitlements/JIT 확정 — BUILD_NOTES §6)
[PASS]       렌더 브리지 (PPSSPP 자식VC / ARMSX2 Host::AcquireRenderWindow / MeloNX set_native_window)
[PASS]       Mac 빌드 스크립트 (build_ppsspp/armsx2/melonx/generate_host/build_all + project.yml 배선)
[PASS]       충돌 사전 점검 (CONFLICT_ANALYSIS.md — 링크/SDL/FFmpeg/MoltenVK/JIT, 전부 NOT_TESTED)
[PASS]       테스트 절차 (체크리스트 + XCUITest 자동화)
[PASS]       CI 빌드 파이프라인 준비 (.github/workflows/ios-build.yml + CI_BUILD_GUIDE.md)
[NOT_TESTED] CI 실제 실행 (GitHub Actions macOS 컴파일/링크/unsigned IPA)
[NOT_TESTED] 실기기 항목 (설치/실행/렌더/오디오/입력/전환)
```
→ **완전 완료 아님.** 이 개발 환경은 Windows(+gh/remote 없음)라 CI 를 직접 실행할 수 없다.
   남은 것은 **사용자가 저장소 push → Actions Run workflow → 로그/IPA artifact 회수** 후
   Windows 에서 오류 수정 루프를 돌리고, iPhone 16 Pro Max 에서 실기기 검증하는 것이다(CI_BUILD_GUIDE.md).

## GitHub Actions (CI 빌드)
- Runner: **NOT_TESTED** (워크플로 준비됨: 기본 `macos-26`, 입력으로 변경 가능)
- macOS / Xcode / iOS SDK / Architecture: **NOT_TESTED** (첫 실행 시 08_logs/ci_environment.log 에 기록)
- 워크플로: `.github/workflows/ios-build.yml` (workflow_dispatch, 엔진→Host→unsigned IPA, artifact 회수)
- 기준 commit 고정: PPSSPP 98e70c8 / ARMSX2 de57f43 / MeloNX 55f84af (임의 최신화 안 함)

---

## PPSSPP
- Adapter: **PASS** (구현 완료: PPSSPPAdapter.swift + PPSSPPCore.h/.mm, NativeApp API 기반)
- Build: **NOT_TESTED** (Windows 환경, xcodebuild 없음)
- Launch: **NOT_TESTED**
- Stop/Return: **NOT_TESTED**
- Relaunch: **NOT_TESTED**
- 링크 준비: **PASS** (빌드타깃 PPSSPPCore, 심볼/헤더/프레임워크 확정 — BUILD_NOTES §6.1)
- 원본 수정 파일 수: **1** (CMakeLists.txt 끝에 정적 라이브러리 타깃 append, 코어 소스 무수정)
- 적용 patch: `04_patches/ppsspp/append_static_lib.cmake`

## ARMSX2
- Adapter: **PASS** (구현 완료: ARMSX2Adapter.swift + ARMSX2Core.h/.mm, VMManager/CPU스레드 기반)
- Build: **NOT_TESTED**
- Launch: **NOT_TESTED** (PS2 BIOS 필요)
- Stop/Return: **NOT_TESTED**
- Relaunch: **NOT_TESTED**
- 링크 준비: **PASS** (빌드타깃 PCSX2+common, Host:: 48개 목록 확정, 렌더 브리지 구현 — BUILD_NOTES §6.2)
- 원본 수정 파일 수: **1** (`pcsx2-sdl/Main.cpp` 의 main+렌더그룹 `#ifndef ARMSX2_EMBED` 가드; 코어 무수정)
- 적용 patch: `04_patches/armsx2/0001-embed-frontend.patch`
- 우리 구현 Host::: AcquireRenderWindow/ReleaseRenderWindow/BeginPresentFrame/GetTopLevelWindowInfo/IsFullscreen/SetFullscreen/RequestResizeHostDisplay (`ARMSX2Host.mm`)

## MeloNX
- Adapter: **PASS** (구현 완료: MeloNXAdapter.swift + MeloNXCore.swift, SN_* C ABI/@_silgen_name 기반)
- 소스 확보: **PASS** — AzureDominus/melonx@XC-ios-ht `55f84af15144e40d7fbe8984747855534d2a8ec1` → 01_sources/MeloNX
- Build: **NOT_TESTED** (Ryujinx NativeAOT 라이브러리 + SDL2 링크 필요)
- Launch: **NOT_TESTED** (prod.keys + firmware 필요)
- Stop/Return: **NOT_TESTED**
- Relaunch: **NOT_TESTED**
- 링크 준비: **PASS** (NativeAOT dylib 빌드법 확정, C ABI 33심볼 목록, 의존 프레임워크 확정 — BUILD_NOTES §6.3)
- 원본 수정 파일 수: **0** (빌드 스크립트만 사용)
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

## 남은 문제 / 다음 작업 (Windows 준비 종료 → Mac 실행만 남음)

**Windows 에서 완료된 링크 준비**(재분석 불필요):
- 3엔진 빌드 타깃/심볼/헤더/의존성/entitlements/JIT 확정(BUILD_NOTES §6)
- 렌더 브리지 구현(PPSSPP 자식VC / ARMSX2 Host 렌더그룹 / MeloNX set_native_window)
- patch 확정(PPSSPP append cmake, ARMSX2 Main.cpp 가드), MeloNX 빌드 레시피 확정
- 빌드 스크립트 5종 + project.yml 링크 배선, 충돌 목록/완화책(CONFLICT_ANALYSIS)

**Mac 에서 해야 할 일(순서)**:
1. `bash 07_build/build_all_ios.sh` — PPSSPP→ARMSX2→MeloNX 라이브러리 빌드 → 프로젝트 생성 → Host 빌드
   - 전제: Xcode, CMake, .NET 8 SDK(+`dotnet workload install ios`)
2. 컴파일/링크 오류 수정
   - 예상 지점: 정적 심볼 중복(zlib/fmt/imgui/ffmpeg) → CONFLICT_ANALYSIS §1 완화(엔진 dylib 격리)
   - SDL2/SDL3 공존, MoltenVK 단일화(§2,§3)
   - project.yml 의 `[LINK ...]` 블록 주석 해제(prebuilt 경로와 매칭)
3. iPhone 16 Pro Max 서명 + JIT 활성(AltStore/SideStore/JitStreamer/StikJIT 또는 TrollStore)
4. 게임/BIOS/keys 배치(체크리스트 사전조건) → `06_tests/CORE_SWITCH_CHECKLIST.md` 실기기 검증
5. 본 문서의 NOT_TESTED → 실제 결과로 갱신
   - 로그 위치: `08_logs/`
   - 최우선 검증: 복수 JIT 공존(CONFLICT_ANALYSIS §7), SDL2/SDL3(§2), Metal surface 전환(§5)
