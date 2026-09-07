//
//  ARMSX2Core.h
//  Starlight Emulator - ARMSX2 Adapter (Bridge)
//
//  ARMSX2(= PCSX2 fork, C++)의 코어를 구동하는 Obj-C(++) 브리지.
//  PPSSPP 에서 검증한 패턴(브리지→코어 API)을 그대로 재사용한다(지시문 8항).
//  실제 구현(.mm)은 upstream 의 VMManager 를 별도 CPU 스레드에서 돌린다:
//     VMManager::Initialize(VMBootParameters) → VMManager::Execute() (루프)
//     VMManager::SetState(VMState::Paused/Running/Stopping) → VMManager::Shutdown()
//  (참조: 01_sources/ARMSX2/pcsx2-sdl/Main.cpp, pcsx2/VMManager.h, pcsx2/Host.h)
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ARMSX2CoreState) {
    ARMSX2CoreStateIdle = 0,
    ARMSX2CoreStateRunning,
    ARMSX2CoreStatePaused,
    ARMSX2CoreStateStopped,
    ARMSX2CoreStateFailed
};

@protocol ARMSX2CoreDelegate <NSObject>
- (void)armsx2CoreDidChangeState:(ARMSX2CoreState)state;
- (void)armsx2CoreDidFailWithMessage:(NSString *)message;
- (void)armsx2CoreDidRequestReturnToHost;
@end

@interface ARMSX2Core : NSObject

@property (nonatomic, weak) id<ARMSX2CoreDelegate> delegate;
@property (nonatomic, readonly) ARMSX2CoreState state;
@property (nonatomic, readonly, class) BOOL engineLinked;   // ARMSX2_LINKED

/// - dataRoot:     PCSX2.ini / memcards / savestates / cache (EmuFolders 로 매핑)
/// - resourceRoot: fonts/shaders 등 upstream 리소스(EmuFolders::Resources)
/// - biosDirectory: PS2 BIOS 폴더(지시문 8항 "BIOS 경로 전달")
/// - metalLayer:   렌더 surface(GS: Vulkan/MoltenVK 또는 Metal)
/// - jitAvailable: EE/IOP/VU recompiler(JIT) 사용 가능 여부. 불가 시 인터프리터.
- (instancetype)initWithDataRoot:(NSURL *)dataRoot
                    resourceRoot:(NSURL *)resourceRoot
                    biosDirectory:(NSURL *)biosDirectory
                      metalLayer:(CAMetalLayer *)metalLayer
                    jitAvailable:(BOOL)jitAvailable NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// PS2 BIOS 가 실제로 존재하는지(부팅 전 검증용).
- (BOOL)hasValidBIOS;

- (BOOL)bootGameAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)shutdown;
- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
