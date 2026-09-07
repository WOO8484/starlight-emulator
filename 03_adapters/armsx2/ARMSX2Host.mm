//
//  ARMSX2Host.mm
//  Starlight Emulator - ARMSX2 Adapter (Host:: 렌더 surface 브리지)
//
//  PCSX2(ARMSX2) 코어는 프론트엔드가 Host:: 콜백을 구현하길 요구한다. 그 중 **렌더 윈도우
//  그룹**은 데스크톱 SDL 프론트엔드(pcsx2-sdl/Main.cpp)의 SDL 윈도우 대신, Starlight 가 소유한
//  공유 CAMetalLayer 를 사용해야 하므로 여기서 직접 구현한다.
//
//  나머지 Host:: (설정/OSD/스레딩/게임리스트 등)는 pcsx2-sdl/Main.cpp 의 구현을 재사용한다
//  (04_patches/armsx2/0001-embed-frontend.patch 로 main() 과 아래 렌더 그룹만 제외 컴파일).
//  전체 Host:: 목록은 00_docs/BUILD_NOTES.md §ARMSX2 참조.
//
//  === 통합 지점 ===
//   - ARMSX2_LINKED=1 정의 + PCSX2 core / common 정적 라이브러리 링크
//   - GS 는 --graphics-backend 에 따라 Vulkan(MoltenVK)/Metal 로 이 layer 에 그린다.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>

// Starlight → Host 브리지: 부팅 전에 ARMSX2Core 가 렌더 레이어를 등록한다.
extern "C" void StarlightARMSX2SetRenderLayer(void *caMetalLayer);

#if defined(ARMSX2_LINKED) && ARMSX2_LINKED

#include <optional>
#include "common/WindowInfo.h"
#include "pcsx2/GS/GS.h"     // namespace Host: AcquireRenderWindow / BeginPresentFrame / ReleaseRenderWindow / IsFullscreen
#include "pcsx2/Host.h"      // namespace Host: RequestResizeHostDisplay / GetTopLevelWindowInfo

static CAMetalLayer *g_starlight_layer = nullptr;
static bool          g_fullscreen      = true;

static WindowInfo StarlightMakeWindowInfo(CAMetalLayer *layer) {
    WindowInfo wi;
    wi.type = WindowInfo::Type::MacOS;                 // MoltenVK 는 CAMetalLayer 를 통해 surface 생성
    wi.window_handle  = (__bridge void *)layer;
    wi.surface_handle = (__bridge void *)layer;        // 별도 layer 핸들(Apple 경로)
    CGSize d = layer.drawableSize;
    if (d.width < 1 || d.height < 1) {                 // 아직 레이아웃 전이면 bounds*scale 로 추정
        CGFloat s = layer.contentsScale > 0 ? layer.contentsScale : 1.0;
        d = CGSizeMake(layer.bounds.size.width * s, layer.bounds.size.height * s);
    }
    wi.surface_width  = (u32)d.width;
    wi.surface_height = (u32)d.height;
    wi.surface_scale  = (float)(layer.contentsScale > 0 ? layer.contentsScale : 1.0);
    wi.surface_refresh_rate = 0.0f;
    return wi;
}

// ---- 렌더 윈도우 그룹 (pcsx2/GS/GS.h) ----
std::optional<WindowInfo> Host::AcquireRenderWindow(bool recreate_window) {
    if (!g_starlight_layer) return std::nullopt;       // 레이어 미등록 → GS 초기화 실패로 보고됨
    return StarlightMakeWindowInfo(g_starlight_layer);
}

void Host::ReleaseRenderWindow() {
    // 공유 레이어는 Host 가 소유하므로 파괴하지 않는다(전환/재실행 대비). GS 참조만 해제됨.
}

void Host::BeginPresentFrame() {
    // 프레임 표시 직전 훅. Starlight 는 추가 작업 없음(레이어는 GS 가 직접 present).
}

bool Host::IsFullscreen() { return g_fullscreen; }
void Host::SetFullscreen(bool enabled) { g_fullscreen = enabled; }

// ---- 상위 윈도우/리사이즈 (pcsx2/Host.h) ----
std::optional<WindowInfo> Host::GetTopLevelWindowInfo() {
    if (!g_starlight_layer) return std::nullopt;
    return StarlightMakeWindowInfo(g_starlight_layer);
}

void Host::RequestResizeHostDisplay(s32 width, s32 height) {
    // Starlight 는 전체화면 단일 코어 정책 → 별도 창 리사이즈 처리 없음.
    // 화면 회전/크기 변경은 layer.drawableSize 갱신으로 GS 가 다음 AcquireRenderWindow 에서 반영.
}

#endif // ARMSX2_LINKED

// 가드 밖(항상 정의): 링크 여부와 무관하게 심볼 존재. 미링크 시 no-op.
extern "C" void StarlightARMSX2SetRenderLayer(void *caMetalLayer) {
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
    g_starlight_layer = (__bridge CAMetalLayer *)caMetalLayer;
#else
    (void)caMetalLayer;
#endif
}
