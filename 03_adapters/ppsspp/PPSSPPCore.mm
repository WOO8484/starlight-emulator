//
//  PPSSPPCore.mm
//  Starlight Emulator - PPSSPP Adapter (Bridge)
//
//  upstream(hrydgard/ppsspp)의 NativeApp C++ API 를 호출하는 얇은 브리지.
//  === 통합 지점(반드시 Mac/Xcode 에서 완성·검증) ===
//   1) PPSSPP 를 정적 라이브러리(libPPSSPP*.a / libCommon.a 등)로 빌드해 링크하고
//      전처리기 매크로 PPSSPP_LINKED=1 를 정의한다.
//   2) iOS Metal(MoltenVK) GraphicsContext 생성은 upstream 의
//      ios/ViewControllerMetal.mm 코드를 재사용한다(우리가 재구현하지 않음 - 지시문 7항).
//   3) 플랫폼이 구현해야 하는 System_* 콜백 전체 목록은 upstream UI/NativeApp.cpp 및
//      Common/System/System.h 참조. 아래에는 대표 항목만 예시로 둔다.
//

#import "PPSSPPCore.h"
#import <QuartzCore/CADisplayLink.h>

#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
  #include "Common/System/NativeApp.h"
  #include "Common/System/System.h"
  #include "Common/GraphicsContext.h"
  // 우리 쪽에서 제공/재사용하는 iOS Metal 컨텍스트 팩토리(ViewControllerMetal.mm 기반).
  extern GraphicsContext *StarlightPPSSPPCreateMetalContext(CAMetalLayer *layer);
#endif

@interface PPSSPPCore () {
    PPSSPPCoreState _state;
    CADisplayLink *_displayLink;
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    GraphicsContext *_gfx;
#endif
}
@property (nonatomic, strong) NSURL *dataRoot;
@property (nonatomic, strong) NSURL *resourceRoot;
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, assign) BOOL jitAvailable;
@end

@implementation PPSSPPCore

+ (BOOL)engineLinked {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    return YES;
#else
    return NO;
#endif
}

- (instancetype)initWithDataRoot:(NSURL *)dataRoot
                    resourceRoot:(NSURL *)resourceRoot
                      metalLayer:(CAMetalLayer *)metalLayer
                    jitAvailable:(BOOL)jitAvailable {
    if (self = [super init]) {
        _dataRoot = dataRoot;
        _resourceRoot = resourceRoot;
        _metalLayer = metalLayer;
        _jitAvailable = jitAvailable;
        _state = PPSSPPCoreStateIdle;
    }
    return self;
}

- (void)setState:(PPSSPPCoreState)state {
    _state = state;
    [self.delegate ppssppCoreDidChangeState:state];
}

- (BOOL)isRunning { return _state == PPSSPPCoreStateRunning; }

- (BOOL)bootGameAtPath:(NSString *)path error:(NSError **)error {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    // 1) 코어 초기화. argv[1] 에 게임 경로를 주면 PPSSPP 가 곧바로 해당 게임으로 부팅한다.
    const char *argv[] = { "StarlightEmulator", path.UTF8String };
    CommandLineOptions opts;   // 필요 옵션은 여기서 설정(예: --jit / --interpreter)
    NativeInit(2, argv, opts,
               self.dataRoot.fileSystemRepresentation,     // savegame_dir (MemoryStick 루트)
               self.resourceRoot.fileSystemRepresentation, // external_dir (assets/flash0)
               [self.dataRoot URLByAppendingPathComponent:@"cache"].fileSystemRepresentation);

    // 2) 그래픽 컨텍스트 생성(MoltenVK) 후 그래픽 초기화.
    _gfx = StarlightPPSSPPCreateMetalContext(self.metalLayer);
    if (_gfx == nullptr || !NativeInitGraphics(_gfx)) {
        if (error) *error = [NSError errorWithDomain:@"PPSSPP" code:-2
                              userInfo:@{NSLocalizedDescriptionKey:@"NativeInitGraphics 실패"}];
        [self setState:PPSSPPCoreStateFailed];
        return NO;
    }
    NativeResized();

    // 3) 렌더 루프 시작(NativeFrame). PPSSPP 는 내부에서 EmuThread 를 돌린다.
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderTick)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self setState:PPSSPPCoreStateRunning];
    return YES;
#else
    if (error) *error = [NSError errorWithDomain:@"PPSSPP" code:-100
        userInfo:@{NSLocalizedDescriptionKey:
        @"PPSSPP 엔진이 아직 링크되지 않았습니다(Phase-1 스캐폴드). "
        @"PPSSPP_LINKED=1 로 정적 라이브러리를 링크한 뒤 Mac/Xcode 에서 검증하세요."}];
    [self setState:PPSSPPCoreStateFailed];
    return NO;   // ← 가짜 성공을 기록하지 않는다(지시문 22항)
#endif
}

- (void)renderTick {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    if (_state == PPSSPPCoreStateRunning && _gfx) {
        NativeFrame(_gfx);
    }
#endif
}

- (void)pause {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    Native_NotifyWindowHidden(true);   // 코어 진행 정지
#endif
    _displayLink.paused = YES;
    [self setState:PPSSPPCoreStatePaused];
}

- (void)resume {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    Native_NotifyWindowHidden(false);
#endif
    _displayLink.paused = NO;
    [self setState:PPSSPPCoreStateRunning];
}

- (void)stop {
    [_displayLink invalidate];
    _displayLink = nil;
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    if (_gfx) {
        NativeShutdownGraphics(_gfx);   // GPU 리소스 해제(전환 시 잔류 방지 - 지시문 12항)
        delete _gfx;
        _gfx = nullptr;
    }
#endif
    [self setState:PPSSPPCoreStateStopped];
}

- (void)shutdown {
    if (_displayLink) { [self stop]; }
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    NativeShutdown();
#endif
    _state = PPSSPPCoreStateIdle;
}

@end

// ============================================================================
// 플랫폼이 구현해야 하는 System_* 콜백 (지시문 7항: 코어가 요구하는 최소 훅).
// 전체 목록은 upstream UI/NativeApp.cpp 를 참조. 아래는 대표 예시(가드 처리).
// 실제 값/동작은 Host 환경에 맞춰 채운다.
// ============================================================================
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
bool System_GetPropertyBool(SystemProperty prop) {
    switch (prop) {
        case SYSPROP_HAS_BACK_BUTTON: return false;
        case SYSPROP_CAN_JIT:         return true;   // 실제 값은 JITManager 결과로 대체
        default:                       return false;
    }
}
// System_GetProperty / System_GetPropertyInt / System_PostUIMessage / System_MakeRequest /
// System_Toast / System_Vibrate / System_RunOnMainThread / NativeMix 등 나머지 필수 훅은
// 통합 시 UI/NativeApp.cpp 의 기본 구현을 재사용하거나 Host 용으로 최소 구현한다.
#endif
