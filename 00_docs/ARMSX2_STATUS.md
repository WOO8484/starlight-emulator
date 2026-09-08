# ARMSX2 (PS2) — 봉인/보류 상태 (2026-09-08)

> 사용자 결정: ARMSX2 는 **iOS 빌드 성공 상태와 분석·로그·문서를 그대로 보존**하고 여기서 보류한다.
> 추가 libretro HW-렌더 프론트엔드 구현은 진행하지 않는다. 향후 ARMSX2/PCSX2 의 iOS 지원이
> 발전하면 재검토. 현재 Phase-1 확정 대상은 **PPSSPP + MeloNX 2엔진**.

## 달성 (CI 실증)
- 기준 소스: `ARMSX2/ARMSX2` @ `de57f431c41218a17b0eecae2aabaf5d3b01c16f`
- **PCSX2 코어 [334/334] iOS(arm64) 컴파일 성공**, `libcommon.a` 링크 성공.
- **정적 라이브러리 19종 생성**: libPCSX2, common, imgui, libchdr, pcsx2-lzma, pcsx2-soundtouch,
  cubeb, vixl, rcheevos, zip, fmt, cpuinfo, ccc, demanglegnu, discord-rpc, freesurround,
  simpleini, pcsx2-rapidyaml, gtest.
- **iOS 의존성 10종 크로스빌드 성공**: libpng, zstd, lz4, webp, SDL3, freetype, plutovg,
  plutosvg, shaderc(+glslang/SPIRV), curl (jpeg 는 CMake4 string 오류로 미빌드였으나 configure 통과).

## 빌드 방법(보존) — 재현 플래그
`07_build/build_armsx2_ios.sh` + `build_armsx2_deps_ios.sh`:
- deps: iOS arm64 정적 + `CMAKE_FIND_ROOT_PATH=$DEPS`(크로스컴파일 find_package 핵심).
- PCSX2: `-G Ninja -DCMAKE_SYSTEM_NAME=iOS -DENABLE_QT_UI=OFF -DENABLE_LIBRETRO=ON`
  `-DDISABLE_ADVANCE_SIMD=ON -DUSE_VULKAN=ON -DCMAKE_CXX_FLAGS=-D_LIBCPP_DISABLE_AVAILABILITY`
  `-DCMAKE_PREFIX_PATH=$DEPS -DCMAKE_FIND_ROOT_PATH=$DEPS`.
- PCSX2 는 OBJECT 라이브러리(DISABLE_ADVANCE_SIMD=ON) → objects 를 `ar` 로 `libPCSX2.a` 아카이브.
- CI: `07_build/build_armsx2_deps_ios.sh` 결과는 actions/cache(키=deps 스크립트 해시)로 캐시됨.
- 워크플로에서 빌드하려면: Run workflow 시 `skip_armsx2=false` (기본은 skip).

## 왜 여기서 멈췄나 (§14 근거)
- 이 포크의 SDL 프론트엔드는 `if(UNIX AND NOT APPLE)` 로 **iOS 에서 추가되지 않는다** → Apple 용
  프론트엔드/Host:: 구현이 없다. 동작하는 iOS Host:: 는 **libretro 코어(pcsx2-libretro)** 에만 존재.
- 따라서 ARMSX2 를 실제 실행하려면 **iOS 에서 libretro HW-렌더 프론트엔드를 신규 구현**해야 한다:
  - libretro `RETRO_ENVIRONMENT_SET_HW_RENDER`(Vulkan) 컨텍스트를 MoltenVK 로 우리 CAMetalLayer 에 연결,
  - retro_load_game/retro_run/retro_unload + video/audio/input 콜백,
  - BIOS(system dir)/세이브 경로.
- 이는 PPSSPP(기존 iOS VC 재사용)·MeloNX(기존 C ABI)와 달리 **처음부터 만드는 대형 작업**이고,
  Metal 위 Vulkan HW 렌더가 핵심 난관 → 별도 단계로 보류.

## 정적 공존 이슈(참고)
- ARMSX2 정적 라이브러리는 PPSSPP 와 다수 중복(imgui/png/glslang/SPIRV/zlib) → Host 에 정적 공존 시
  duplicate symbol(CONFLICT_ANALYSIS §1). 재개 시 ARMSX2 를 **자기완결형 dylib**(libretro 코어 또는
  C ABI 래퍼)로 격리하는 방향 권장.

## 재개 시 다음 단계(요약)
1. libretro 코어를 자기완결형 dylib 로 빌드(pcsx2-libretro, 필요한 iOS 프레임워크 링크).
2. iOS libretro 프론트엔드(HW Vulkan→Metal) 구현: 03_adapters/armsx2 를 libretro API 로 전환.
3. `EmulatorContext.metalLayer` 를 libretro HW 렌더 타깃으로 연결(ARMSX2Host.mm 의 WindowInfo 대체/보완).
4. generate_host 에 ARMSX2 dylib 링크/임베드 추가 + LINK_ARMSX2 활성.
5. 실기기 검증.

## 보존물
- 스크립트: `07_build/build_armsx2_ios.sh`, `07_build/build_armsx2_deps_ios.sh`
- 어댑터(스캐폴드): `03_adapters/armsx2/*` (VMManager 기반 — libretro 전환 시 대체 가능)
- patch: `04_patches/armsx2/0001-embed-frontend.patch`
- 로그: CI artifact(logs) — armsx2_cmake.log / armsx2_build.log / armsx2_deps.log
- 분석: 본 문서 + BUILD_NOTES.md §6.2 + CONFLICT_ANALYSIS.md
