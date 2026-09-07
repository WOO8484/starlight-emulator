//
//  PPSSPPCore.mm
//  Starlight Emulator - PPSSPP Adapter (Bridge)
//
//  === 통합 지점(Mac/Xcode 에서 완성·검증) ===
//   1) PPSSPP 를 정적 라이브러리로 빌드(04_patches/ppsspp/0001-static-library-target.patch 로
//      PPSSPPCore STATIC 타깃 추가). 여기엔 core(Core/Common/GPU/ppsspp_ui) + UI/NativeApp.cpp +
//      ios/*.mm(단, ios/main.mm 와 ios/AppDelegate.mm 는 제외)이 포함되어야 한다.
//      전처리기 PPSSPP_LINKED=1 정의.
//   2) libMoltenVK.dylib(ext/vulkan/iOS/Frameworks) + 시스템 프레임워크 링크(BUILD_NOTES §PPSSPP).
//   3) 게임 자산(assets/flash0/lang/shaders...)을 번들 resourceRoot 에 포함.
//
//  이 브리지는 upstream 의 PPSSPPViewControllerMetal 을 원본 그대로 임베드한다. 즉 Vulkan
//  surface 생성/렌더 루프는 재구현하지 않는다(지시문 2·7항).
//

#import "PPSSPPCore.h"

#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
  #include "Common/System/NativeApp.h"
  #include "Common/System/System.h"
  #import  "ios/ViewControllerMetal.h"   // PPSSPPViewControllerMetal
#endif

@interface PPSSPPCore () {
    PPSSPPCoreState _state;
}
@property (nonatomic, strong) NSURL *dataRoot;
@property (nonatomic, strong) NSURL *resourceRoot;
@property (nonatomic, weak)   UIView *containerView;
@property (nonatomic, assign) BOOL jitAvailable;
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
@property (nonatomic, strong) PPSSPPViewControllerMetal *vc;
#endif
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
                   containerView:(id)containerView
                    jitAvailable:(BOOL)jitAvailable {
    if (self = [super init]) {
        _dataRoot = dataRoot;
        _resourceRoot = resourceRoot;
        _containerView = (UIView *)containerView;
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

// 컨테이너 뷰가 속한 UIViewController 를 responder chain 으로 찾는다.
- (UIViewController *)hostViewControllerFor:(UIView *)view {
    UIResponder *r = view;
    while ((r = r.nextResponder)) {
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    }
    return nil;
}

- (BOOL)bootGameAtPath:(NSString *)path error:(NSError **)error {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    UIView *container = self.containerView;
    UIViewController *host = [self hostViewControllerFor:container];
    if (!container || !host) {
        if (error) *error = [NSError errorWithDomain:@"PPSSPP" code:-4
            userInfo:@{NSLocalizedDescriptionKey:@"렌더 컨테이너/HostVC 를 찾지 못했습니다."}];
        [self setState:PPSSPPCoreStateFailed];
        return NO;
    }

    // 1) 비그래픽 초기화 + 부팅 대상 지정. argv 에 게임 경로를 주면 곧바로 부팅한다.
    //    (원래 ios/AppDelegate.mm 이 하던 일을 우리가 대신한다.)
    const char *argv[] = { "StarlightEmulator", path.UTF8String };
    CommandLineOptions opts;
    NativeInit(2, argv, opts,
               self.dataRoot.fileSystemRepresentation,        // savegame_dir(MemoryStick)
               self.resourceRoot.fileSystemRepresentation,    // external_dir(assets/flash0)
               [self.dataRoot URLByAppendingPathComponent:@"cache"].fileSystemRepresentation);

    // 2) upstream 렌더 VC 를 자식으로 임베드 → viewDidLoad/appear 에서 Vulkan 컨텍스트 생성 +
    //    렌더 루프(NativeInitGraphics/NativeFrame) 자동 시작.
    self.vc = [[PPSSPPViewControllerMetal alloc] init];
    [host addChildViewController:self.vc];
    self.vc.view.frame = container.bounds;
    self.vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:self.vc.view];
    [self.vc didMoveToParentViewController:host];

    [self setState:PPSSPPCoreStateRunning];
    return YES;
#else
    if (error) *error = [NSError errorWithDomain:@"PPSSPP" code:-100
        userInfo:@{NSLocalizedDescriptionKey:
        @"PPSSPP 엔진이 아직 링크되지 않았습니다(Phase-1 스캐폴드). "
        @"PPSSPP_LINKED=1 로 정적 라이브러리를 링크한 뒤 Mac/Xcode 에서 검증하세요."}];
    [self setState:PPSSPPCoreStateFailed];
    return NO;   // 가짜 성공을 기록하지 않는다(지시문 22항)
#endif
}

- (void)pause {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    Native_NotifyWindowHidden(true);
#endif
    [self setState:PPSSPPCoreStatePaused];
}
- (void)resume {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    Native_NotifyWindowHidden(false);
#endif
    [self setState:PPSSPPCoreStateRunning];
}

- (void)stop {
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    if (self.vc) {
        // 자식 VC 제거 → viewWillDisappear → requestExitVulkanRenderLoop(내부)로 렌더 루프 종료 +
        // NativeShutdownGraphics 로 GPU 리소스 해제(전환 시 잔류 방지 - 지시문 12항).
        [self.vc willMoveToParentViewController:nil];
        [self.vc.view removeFromSuperview];
        [self.vc removeFromParentViewController];
        self.vc = nil;
    }
#endif
    [self setState:PPSSPPCoreStateStopped];
}

- (void)shutdown {
    if (_state == PPSSPPCoreStateRunning || _state == PPSSPPCoreStatePaused) { [self stop]; }
#if defined(PPSSPP_LINKED) && PPSSPP_LINKED
    NativeShutdown();
#endif
    _state = PPSSPPCoreStateIdle;
}

@end

// ============================================================================
// PPSSPP 코어가 요구하는 System_* 콜백은 upstream UI/NativeApp.cpp + ios/*.mm 에 이미 구현되어
// 있으므로(정적 라이브러리에 포함), Starlight 는 재구현하지 않는다(지시문 7·23항).
// 단, ios/main.mm(=UIApplicationMain 진입)와 ios/AppDelegate.mm 은 라이브러리에서 제외한다.
// (제외 방법: 04_patches/ppsspp/0001-static-library-target.patch 참조)
// ============================================================================
