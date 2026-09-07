# BUILD_NOTES.md — 엔진 원본 추적 · 빌드 · iOS 설정 (지시문 4항)

> 작성 환경: **Windows 11** (cmake/clang/xcodebuild 없음). 아래 "빌드/실기기" 항목은
> 이 환경에서 실행 불가 → 실제 빌드·검증은 macOS/Xcode 에서 수행해야 한다(지시문 16항).
> 작업 루트: `X:\103 통합에뮬` (네트워크 드라이브 `\\woow\02 5T`, git safe.directory 등록됨).

---

## 0. 공통 iOS 통합 요지

| 엔진 | 언어/런타임 | 코어 노출 방식 | 렌더 | 게임 부팅 | 실행 스레드 |
|---|---|---|---|---|---|
| PPSSPP | C++ | `NativeApp` 전역 함수 | MoltenVK(Vulkan)/Metal | argv[1]=경로 | 내부 EmuThread + 메인 DisplayLink |
| ARMSX2 | C++ (PCSX2 fork) | `VMManager::*` + `Host::` 콜백 | GS(Vulkan/MoltenVK) | `VMBootParameters.filename` | 전용 CPU 스레드 |
| MeloNX | C#/.NET **NativeAOT** | C ABI (`main_ryujinx_sdl` 등) | Vulkan(MoltenVK) via `set_native_window` | argv[1]=경로 | 전용 스레드(블로킹 main) |

→ 세 코어 모두 최종적으로 **네이티브 라이브러리 + C 심볼**로 귀결되어 단일 iOS 바이너리에
링크 가능(ABI 비호환 없음). 남는 리스크는 런타임 공존(§5)뿐.

---

## 1. PPSSPP (PSP)

- **upstream URL**: https://github.com/hrydgard/ppsspp
- **branch**: `master` (HEAD)
- **commit hash**: `<클론 시 고정>` (예: `git -C 01_sources/PPSSPP rev-parse HEAD` 결과 기록)
- **가져온 날짜**: 2026-09-08 (트리/헤더만 API 로 분석; 전체 클론은 Mac 에서)
- **서브모듈**: `git submodule update --init` 필요(ffmpeg, native, lang 등)
- **빌드 시스템**: CMake → Xcode 프로젝트
  ```
  mkdir build-ios && cd build-ios
  cmake -DCMAKE_TOOLCHAIN_FILE=../cmake/Toolchains/ios.cmake -GXcode ..
  ```
- **핵심 API** (`Common/System/NativeApp.h`):
  `NativeInit(argc,argv,opts,savegame_dir,external_dir,cache_dir)` /
  `NativeInitGraphics(GraphicsContext*)` / `NativeResized()` / `NativeFrame(GraphicsContext*)` /
  `NativeTouch/NativeKey/NativeAxis` / `NativeMix` / `NativeShutdownGraphics` / `NativeShutdown` /
  `Native_NotifyWindowHidden(bool)`
- **플랫폼 구현 필요**: `System_*` (Common/System/System.h) — 기본 구현은 `UI/NativeApp.cpp` 참조.
- **iOS 진입부**: `ios/AppDelegate.mm`, `ios/SceneDelegate.mm`, `ios/ViewControllerMetal.mm`(MoltenVK 컨텍스트 — 우리 `StarlightPPSSPPCreateMetalContext` 가 이 코드를 재사용).
- **entitlements**: `ios/App.entitlements` = **빈 dict**. → PPSSPP 는 서명 권한으로 JIT 를 얻지 않고,
  실기기에서는 외부 JIT 활성기(AltStore/JitStreamer/TrollStore) 또는 인터프리터로 동작.
- **JIT 요구**: 있으면 성능↑, 없으면 인터프리터 가능(3엔진 중 유일하게 JIT 없이도 실행).
- **iOS 관련 설정**: MoltenVK.xcframework 포함(`ios/MoltenVK`).

## 2. ARMSX2 (PS2)

- **upstream URL**: https://github.com/ARMSX2/ARMSX2
- **branch**: `master`
- **commit hash**: `de57f431c41218a17b0eecae2aabaf5d3b01c16f` (2026-09-08 ls-remote 기준)
- **iOS 대체 참고**: https://github.com/CosmicFusion/iPSX2-src (PCSX2+ARMSX2 iOS 묶음)
- **가져온 날짜**: 2026-09-08 (트리/entitlements/`pcsx2-sdl/Main.cpp` 분석)
- **빌드 시스템**: CMake (`CMakeLists.txt`, `CMakePresets.json`). 프론트엔드 후보:
  `pcsx2-sdl`(SDL3, 모바일 경로) / `pcsx2-qt`(데스크톱) / `pcsx2-libretro`.
  → **통합에는 `pcsx2-sdl/Main.cpp` 의 Host:: 구현 + core(`pcsx2/`,`common/`) 를 사용**.
- **핵심 API** (`pcsx2/VMManager.h`):
  `VMManager::Internal::LoadStartupSettings()` / `VMManager::Initialize(VMBootParameters)` /
  `VMManager::Execute()`(루프) / `VMManager::SetState(VMState::Running/Paused/Stopping)` /
  `VMManager::HasValidVM()` / `VMManager::Shutdown()`
- **데이터 경로**: `EmuFolders::{AppRoot,DataRoot,Resources,Bios,Settings}` (기본 `PCSX2.ini`).
- **플랫폼 구현 필요**: `Host::*` (렌더 윈도우 획득/해제, 설정 로드, VM 이벤트) — `pcsx2-sdl/Main.cpp` 재사용.
- **BIOS**: PS2 BIOS 필수(`pcsx2/ps2/BiosTools.h`, `EmuFolders::Bios`).
- **entitlements** (`pcsx2/Resources/ARMSX2.entitlements`):
  `com.apple.security.cs.allow-jit`, `...allow-unsigned-executable-memory`,
  `...disable-library-validation`, `com.apple.security.device.audio-input`, `...camera`.
- **JIT 요구**: EE/IOP/VU recompiler = 사실상 필수(인터프리터는 실사용 불가 수준으로 느림).
- **오디오**: `pcsx2/Host/SDLAudioStream.cpp`(SDL) 사용.

## 3. MeloNX (Switch)  ← 지시문 9항: 최우선 구조 분석 대상

- **공식 upstream**: `git.ryujinx.app/projects/MeloNX` (Forgejo, **이 작업 환경에서 접근 불가** — 타임아웃).
- **실제 확보한 기준본(미러/포크)**:
  - **URL**: https://github.com/AzureDominus/melonx.git
  - **branch**: `XC-ios-ht`
  - **commit hash**: `55f84af15144e40d7fbe8984747855534d2a8ec1`
  - **commit date**: 2026-06-02, subject "Make LAN remote controller manual-first"
  - **가져온 날짜**: 2026-09-08
  - **로컬 경로**: `01_sources/MeloNX` (shallow, depth=1, 228MB, 5039 files)
- **공식과의 차이(기록)**:
  - 이 저장소는 공식 Forgejo 의 **공개 GitHub 미러/포크**. 브랜치명 `XC-ios-ht` 는 공식 개발 브랜치명과 동일.
  - `MeloNX.xcodeproj` 의 `xcuserdata` 소유자가 `stossy11`(공식 개발자 핸들, melonx.org 연락처와 일치)
    → 원저작자 소스의 충실한 사본으로 판단.
  - 공식 최신 대비 **시점 지연 가능**(위 커밋은 2026-06). 정식 릴리스(예: MeloNX 2.x)와 diff 는
    Mac 에서 공식 접근 가능 시 `git remote add upstream <forgejo>` 후 대조 필요.
  - 대안 포크: `devz906/MelonJR`(동일 `XC-ios-ht`, 2026-05, 더 오래됨).
- **언어/런타임**: **.NET NativeAOT** (Ryujinx). `.NET JIT 불필요`, 그러나 **게스트(Switch) 코드 실행에 JIT/하이퍼바이저 필요**.
- **핵심 아키텍처**:
  - .NET 측 `src/Ryujinx.Headless.SDL2/Program.cs` 가 `[UnmanagedCallersOnly(EntryPoint="…")]` 로 C 심볼 export:
    `main_ryujinx_sdl`, `set_native_window`, `pause_emulation`, `stop_emulation`, `initialize`,
    `initialize-dualmapped`, `set_view_size`, `touch_began/moved/ended`, `set_gamepad_*`,
    `update_settings_external`, `get_current_fps`, `get/set_game_volume`, 계정/DLC 관련 등.
  - Swift 측 `App/Core/Ryujinx/RyujinxBridge.swift` 가 `@_silgen_name` 으로 위 심볼을 `SN_*` 로 바인딩.
  - 브리징 헤더: `App/Core/Headers/Ryujinx-Header.h` (구조체 `GameInfo`/`DlcNcaList` + JIT breakpoint 헬퍼).
  - 프레임워크 의존: `RyujinxHelper.framework`(코어), `SDL2.xcframework`, `Hypervisor.framework`,
    `BreakpointJIT.framework`, FFmpeg(`libav*`), `libSPIRV`.
- **게임 부팅 argv**(원본 `App/Core/Ryujinx/Ryujinx.swift start(with:)`):
  `[프로그램명, 게임경로, --graphics-backend Vulkan, --memory-manager-mode …,
   --exclusive-fullscreen true, --exclusive-fullscreen-width/height, --device-model,
   --system-language, --system-region, (--use-hypervisor), (--has-memory-entitlement),
   --ignore-missing-services, --input-id-* …]` → `main_ryujinx_sdl` 를 **전용 스레드**에서 호출.
- **firmware/keys**: `prod.keys`/`title.keys` = `<dataRoot>/system/`, 설치 firmware = `<dataRoot>/bis/`.
  `SN_install_firmware()` / `SN_installed_firmware_version()` 제공.
- **JIT/entitlement 전략**(원본 `App/Core/JIT/IsJITEnabled.swift`):
  1) `dynamic-codesigning` 보유 → 직접 RWX(JIT). `allocateTest()` 로 실행 검증.
  2) 없으면 `initialize_dualmapped()`(dual-map RW/RX) + `CS_DEBUGGED`(디버거/JIT활성기 부착) 확인.
  3) 활성기 경로: `JitStreamerEB`, `StikJIT/StikDebug` (원본 `App/Core/JIT/*`).
- **entitlements**(`MeloNX-hv.entitlements`, **하이퍼바이저/TrollStore 전용 사설 권한**):
  `com.apple.private.hypervisor`, `platform-application`, `com.apple.private.security.no-sandbox`,
  `com.apple.developer.kernel.increased-memory-limit`, `...extended-virtual-addressing`,
  `com.apple.vm.device-access`, `get-task-allow` 등.

---

## 4. 통합 Host entitlement/JIT 정리 (지시문 10항)

최종 Host(`StarlightEmulator.app`) 기준 2가지 프로파일:

| 프로파일 | 파일 | JIT 경로 | 서명 요구 | 비고 |
|---|---|---|---|---|
| 표준(사이드로드) | `StarlightEmulator.entitlements` | `get-task-allow` + 외부 디버거(CS_DEBUGGED) | 일반 개발자/AltStore/SideStore | dynamic-codesigning 불가 → 실행 시 JIT 활성기 필요 |
| TrollStore/특수 | `StarlightEmulator-TrollStore.entitlements` | `dynamic-codesigning`(+하이퍼바이저) | TrollStore 등 | 최고 성능. 사설 권한 포함 |

- **JIT 활성 조건**: RWX 페이지 mmap→mprotect(RX) 성공(=`JITManager.allocateExecTest`).
- **필요 entitlement**: 위 표. PS2/Switch 는 `increased-memory-limit`,`extended-virtual-addressing` 권장.
- **메모리 제한**: PS2/Switch 는 대용량 → `increased-memory-limit` 없으면 OOM 위험.
- **실행 전 필수 상태**: JIT READY(ARMSX2/MeloNX), BIOS(PS2), prod.keys+firmware(Switch).
- **실패 메시지**: `EmulatorError`(EmulatorTypes.swift) — `jitUnavailable`, `missingResource`, `launchFailed` 등.

---

## 5. 단일 프로세스 공존 리스크 (지시문 8·12·14항 — 실기기 검증 필요)

이 항목들은 **추측이 아니라 실기기에서 검증/판정**해야 한다(지시문 14·15항).

1. **복수 JIT 영역**: ARMSX2(EE/VU recompiler) + MeloNX(ARMeilleure) 가 각자 RWX 영역을 요구.
   하나의 `dynamic-codesigning`/디버거 세션 아래 공존 가능 여부 = 최우선 검증.
2. **SDL 충돌**: MeloNX=SDL2, ARMSX2=SDL3. 두 SDL 이 한 프로세스에서 심볼/이벤트루프 충돌 가능
   → 코어 전환 시 완전 종료(§Adapter stop) 로 회피 시도. 동시 실행은 하지 않음(단일 코어 정책).
3. **Metal surface**: 세 코어가 공유 CAMetalLayer 를 순차 사용 → stop 에서 surface 해제 필수(잔상/충돌).
4. **전역 상태/재실행**: PCSX2/Ryujinx 는 전역 싱글턴이 많음 → relaunch 시 상태 리셋 확인.
5. **오디오 세션**: AVAudioSession 공유 → 전환 시 재설정.

→ 만약 특정 엔진이 구조적으로 단일 프로세스 통합 불가로 판정되면, 지시문 14항에 따라
   **실제 근거(linker 오류/runtime 제약/필수 별도 process 요구 등)** 를 `PHASE1_RESULT.md` 에 남긴다.
   현재까지는 세 코어 모두 "네이티브 라이브러리+C심볼" 이라 **불가 근거 없음**(= 통합 시도 계속).
