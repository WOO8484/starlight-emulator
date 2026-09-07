# CONFLICT_ANALYSIS.md — 단일 프로세스 통합 충돌 사전 점검 (지시문 4·8·12·14항)

> 소스 수준에서 확인 가능한 범위만 기록한다. 실제 링크/런타임 검증은 Mac 에서 수행하며
> 미검증 항목은 `NOT_TESTED`. **C ABI 를 쓴다는 이유만으로 "충돌 없음"으로 단정하지 않는다.**
> 근거 소스: PPSSPP CMakeLists / ARMSX2 3rdparty 트리 / MeloNX Dependencies.

## 0. 3rd-party 인벤토리 (실측)

| 라이브러리 | PPSSPP | ARMSX2 (PCSX2) | MeloNX (Ryujinx) |
|---|---|---|---|
| SDL | (미사용/자체 입력) | **SDL3** (`#include <SDL3/SDL.h>`, pcsx2-sdl) | **SDL2** (SDL2.xcframework) |
| Vulkan→Metal | libMoltenVK.dylib (ext/vulkan/iOS) | 3rdparty/vulkan (MoltenVK) | libMoltenVK.dylib (동봉) |
| FFmpeg | ffmpeg (submodule, 정적) | (해당 없음/제한적) | libav* (xcframework + dylib) |
| zlib | 정적(add_library zlib) | 3rdparty(zlib/libchdr 경유) | (관리코드) |
| fmt | 자체 | 3rdparty/fmt | (관리코드) |
| imgui | 자체(debugger) | 3rdparty/imgui | (관리코드) |
| 오디오 | OpenAL/CoreAudio(iOSCoreAudio) | cubeb / SDLAudioStream | SDL2 audio / Apple backend |

## 1. 링크타임(정적) 중복 심볼 위험 — 높음

동일 이름 심볼을 **여러 정적 라이브러리가 메인 이미지에 정의**하면 링커가 중복으로 실패할 수 있다.

| 항목 | 충돌원 | 위험 | 상태 |
|---|---|---|---|
| zlib (`inflate`/`deflate`…) | PPSSPP 정적 + ARMSX2 정적 | 링크 중복 정의 | NOT_TESTED |
| fmt | PPSSPP + ARMSX2 각자 정적 | 링크 중복/ODR | NOT_TESTED |
| imgui | PPSSPP + ARMSX2 각자 정적 | 링크 중복/ODR | NOT_TESTED |
| FFmpeg (`av_*`) | PPSSPP 정적 + MeloNX dylib | 정적↔동적 혼재(2단계 네임스페이스로 완화 가능) | NOT_TESTED |

**권장 완화책(핵심):** 각 엔진을 **자기완결형 동적 프레임워크(dylib/.framework)** 로 빌드한다.
- MeloNX 는 이미 dylib(`Ryujinx.Headless.SDL2.dylib`).
- PPSSPP/ARMSX2 도 정적 .a 대신 **SHARED** 로 빌드하면, 각 dylib 내부에 자신의 정적 의존을 감추고
  Apple **two-level namespace** 로 심볼이 각 dylib 에 바인딩되어 링크타임 중복이 사라진다.
- 즉 통합 구조를 "Host 실행파일 + 엔진별 dylib 3개"로 두는 것이 가장 안전하다.
- (07_build 의 build 스크립트는 현재 .a 를 생성한다. 링크 중복이 실제로 발생하면 SHARED 로 전환.)

## 2. SDL2 vs SDL3 공존 — 높음

- MeloNX=SDL2, ARMSX2=SDL3. **두 버전이 같은 심볼명(`SDL_Init`,`SDL_CreateWindow`…)을 다른 ABI 로 export.**
- 한 프로세스에 둘 다 존재하면 잘못된 바인딩→크래시 위험.
- 완화: (a) §1 의 dylib 격리 + two-level namespace 로 각 엔진이 자기 SDL 에만 바인딩,
  (b) **단일 활성 코어 정책**(EmulatorManager 는 한 번에 하나만 실행, 전환 전 이전 코어 stop/shutdown)
  으로 SDL 전역 상태(단일 `SDL_Init`)의 동시 사용을 방지.
- 상태: NOT_TESTED (Mac 링크/런타임 확인 필요).

## 3. MoltenVK 3중 동봉 — 중간

- 3개 엔진이 각자 `libMoltenVK.dylib`(또는 Vulkan loader)를 가져온다. 동일 install name 의 dylib 중복은
  Frameworks/ 에서 충돌.
- 완화: **단일 MoltenVK dylib** 로 통일(가장 최신/호환 버전). 각 엔진이 그 버전으로 동작하는지 확인.
- 상태: NOT_TESTED.

## 4. Objective-C 클래스/카테고리 충돌 — 낮음~중간

- PPSSPP 는 `PPSSPPViewControllerMetal`,`PPSSPPMetalView` 등 접두어가 있어 충돌 가능성 낮음.
  단, `AppDelegate`/`ViewController` 같은 일반명은 우리가 이미 제외(ios/AppDelegate.mm 미포함).
- Obj-C **카테고리** 중복(같은 클래스에 같은 메서드 재정의)은 런타임에 조용히 마지막 것이 이김 → 위험.
  각 엔진이 UIKit 클래스에 카테고리를 추가하는지 Mac 에서 `nm`/`otool -ov` 로 점검.
- 상태: NOT_TESTED.

## 5. Metal 전역 상태 — 낮음 (단일 활성 코어로 완화)

- 각 엔진이 자체 `MTLDevice`/`CAMetalLayer`/커맨드큐 사용. `MTLCreateSystemDefaultDevice` 는 동일 디바이스 반환(공유 OK).
- 리스크는 **surface(layer) 재사용/해제**: 전환 시 이전 코어가 stop 에서 렌더 루프 종료 + surface 참조 해제해야
  잔상/충돌 없음(지시문 12항 "Metal surface 충돌"). PPSSPP 는 자식 VC 제거로, ARMSX2 는 ReleaseRenderWindow,
  MeloNX 는 stop_emulation 으로 처리. 상태: NOT_TESTED.

## 6. 오디오 세션 소유권 — 중간 (단일 활성 코어로 완화)

- AVAudioSession 은 프로세스당 하나. 세 엔진이 각자 활성화/설정 → 전환 시 재설정 필요.
- 완화: stop 시 각 엔진이 오디오 백엔드를 정지/해제하고, 다음 코어가 세션을 재설정.
- 상태: NOT_TESTED.

## 7. JIT 초기화/종료 순서 — 높음 (최우선 검증)

- ARMSX2(EE/IOP/VU recompiler)와 MeloNX(ARMeilleure)가 각각 RWX/dual-map 영역을 요구.
- **단일 활성 코어 정책**으로 동시 2개 JIT 영역을 피한다. 전환 시:
  이전 코어 shutdown 에서 JIT 영역 해제 → 다음 코어 initialize 에서 재확보.
- 하나의 `dynamic-codesigning`/디버거 세션 아래 순차 재확보가 실제로 가능한지 = 최우선 실기기 검증 항목.
- 상태: NOT_TESTED.

## 8. 종합 완화 전략

1. **엔진별 동적 프레임워크 격리**(§1) — 링크타임 중복/ABI 충돌의 근본 완화.
2. **단일 활성 코어 + 전환 전 완전 종료**(EmulatorManager) — SDL/오디오/JIT/Metal 전역 상태 충돌 완화.
3. **공유 자원 단일화**(MoltenVK 1개) — dylib 중복 제거.
4. 위 3가지 적용 후에도 남는 항목은 Mac 에서 `xcodebuild` 링크 로그 + 실기기 런타임으로 확정.

> 결론: 세 코어가 모두 "네이티브 라이브러리 + C 심볼"이라 **구조적 통합 불가 근거는 아직 없음**(지시문 14항).
> 그러나 위 충돌들은 실재하므로, **C ABI 사용이 곧 충돌 없음을 의미하지 않는다.** 모두 NOT_TESTED.
