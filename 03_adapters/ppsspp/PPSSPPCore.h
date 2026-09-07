//
//  PPSSPPCore.h
//  Starlight Emulator - PPSSPP Adapter (Bridge)
//
//  PPSSPP 는 C++ 엔진이므로 Swift 에서 직접 부르지 않고 이 Obj-C(++) 브리지를 경유한다.
//  실제 구현(.mm)은 upstream 의 NativeApp API 를 호출한다:
//     NativeInit / NativeInitGraphics / NativeFrame / NativeTouch / NativeKey /
//     NativeMix / NativeShutdownGraphics / NativeShutdown
//  (참조: 01_sources/PPSSPP/Common/System/NativeApp.h, ios/ViewControllerMetal.mm)
//
//  지시문 7항: PPSSPP 의 기존 GUI 를 새로 구현하지 않는다. 코어만 구동한다.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>

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
- (void)ppssppCoreDidRequestReturnToHost;   // 게임 종료 등으로 코어 루프 종료 시
@end

/// PPSSPP 코어의 얇은 래퍼. 하나의 인스턴스가 한 코어 수명주기를 관리한다.
@interface PPSSPPCore : NSObject

@property (nonatomic, weak) id<PPSSPPCoreDelegate> delegate;
@property (nonatomic, readonly) PPSSPPCoreState state;
/// 이 빌드에 PPSSPP 정적 라이브러리가 실제로 링크되었는지(PPSSPP_LINKED).
@property (nonatomic, readonly, class) BOOL engineLinked;

/// 데이터/리소스 경로와 렌더 대상 레이어를 주입한다. (지시문 13항 경로 격리)
///  - dataRoot:     설정/세이브/캐시/샷 (PSP MemoryStick 루트로 매핑)
///  - resourceRoot: assets/flash0 등 upstream 리소스
///  - metalLayer:   렌더 surface (MoltenVK/Vulkan 대상)
///  - jitAvailable: JIT 사용 가능 여부(불가 시 인터프리터로 부팅)
- (instancetype)initWithDataRoot:(NSURL *)dataRoot
                    resourceRoot:(NSURL *)resourceRoot
                      metalLayer:(CAMetalLayer *)metalLayer
                    jitAvailable:(BOOL)jitAvailable NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// 게임 부팅. 성공 시 YES, 실패 시 NO(+error). 내부에서 렌더 루프를 시작한다.
- (BOOL)bootGameAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;

- (void)pause;
- (void)resume;
- (void)stop;        // 게임 정지 + GPU/오디오 해제, 재부팅 가능 상태로 복귀
- (void)shutdown;    // 정적 리소스까지 해제(프로세스 종료 전)
- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
