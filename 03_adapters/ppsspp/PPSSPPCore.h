//
//  PPSSPPCore.h
//  Starlight Emulator - PPSSPP Adapter (Bridge)
//
//  PPSSPP 는 C++ + Obj-C(++) 엔진이며, iOS 렌더링 전체를 upstream 의
//  PPSSPPViewControllerMetal(VulkanGraphicsContext/MoltenVK + NativeInitGraphics/NativeFrame 루프)
//  이 담당한다. 우리는 이 VC 를 **원본 그대로 자식 뷰컨트롤러로 재사용**하고,
//  앱 진입부(ios/main.mm, ios/AppDelegate.mm)만 우리 것으로 대체한다(지시문 2·7·23항).
//   - 게임 부팅: NativeInit(argv=[app,gamePath], dirs) 후 VC 를 컨테이너에 임베드
//   - 종료: 자식 VC 제거 → VC 의 requestExitVulkanRenderLoop 자동 호출
//  (참조: 01_sources/PPSSPP/ios/ViewControllerMetal.mm, Common/System/NativeApp.h)
//

#import <Foundation/Foundation.h>
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPSSPPCoreState) {
    PPSSPPCoreStateIdle = 0,
    PPSSPPCoreStateRunning,
    PPSSPPCoreStatePaused,
    PPSSPPCoreStateStopped,
    PPSSPPCoreStateFailed
};

@protocol PPSSPPCoreDelegate <NSObject>
- (void)ppssppCoreDidChangeState:(PPSSPPCoreState)state;
- (void)ppssppCoreDidFailWithMessage:(NSString *)message;
- (void)ppssppCoreDidRequestReturnToHost;
@end

@interface PPSSPPCore : NSObject

@property (nonatomic, weak) id<PPSSPPCoreDelegate> delegate;
@property (nonatomic, readonly) PPSSPPCoreState state;
@property (nonatomic, readonly, class) BOOL engineLinked;   // PPSSPP_LINKED

/// - dataRoot:      MemoryStick 루트(config/save/cache/screenshots). 지시문 13항.
/// - resourceRoot:  assets/flash0 등 upstream 리소스(번들)
/// - containerView: PPSSPP VC 뷰를 붙일 Host 컨테이너(UIView). 지시문의 renderContainer.
/// - jitAvailable:  JIT 가용 여부(불가 시 인터프리터 부팅)
- (instancetype)initWithDataRoot:(NSURL *)dataRoot
                    resourceRoot:(NSURL *)resourceRoot
                   containerView:(nullable id)containerView
                    jitAvailable:(BOOL)jitAvailable NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)bootGameAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)shutdown;
- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
