//
//  ARMSX2Core.mm
//  Starlight Emulator - ARMSX2 Adapter (Bridge)
//
//  === 통합 지점(Mac/Xcode 에서 완성·검증) ===
//   1) ARMSX2(PCSX2 fork)의 core(pcsx2)+common 을 정적 라이브러리로 빌드해 링크하고
//      ARMSX2_LINKED=1 을 정의한다. GS/오디오/입력 백엔드(SDL3, Vulkan/MoltenVK) 포함.
//   2) 프론트엔드가 구현해야 하는 Host:: 콜백은 pcsx2-sdl/Main.cpp 의 구현을 재사용한다
//      (우리가 재구현하지 않음 - 지시문 8·23항). 아래엔 대표 항목만 예시로 둔다.
//   3) VMManager 는 반드시 전용 CPU 스레드에서 돌린다(메인 스레드 블로킹 금지).
//

#import "ARMSX2Core.h"
#import <pthread.h>

// Host:: 렌더 브리지(ARMSX2Host.mm)에 공유 CAMetalLayer 를 등록한다.
extern "C" void StarlightARMSX2SetRenderLayer(void *caMetalLayer);

#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
  #include "pcsx2/VMManager.h"
  #include "pcsx2/Host.h"
  #include "pcsx2/GS.h"
  #include "common/Path.h"
  #include "pcsx2/ps2/BiosTools.h"
#endif

@interface ARMSX2Core () {
    ARMSX2CoreState _state;
    NSThread *_cpuThread;
    volatile BOOL _stopRequested;
}
@property (nonatomic, strong) NSURL *dataRoot;
@property (nonatomic, strong) NSURL *resourceRoot;
@property (nonatomic, strong) NSURL *biosDirectory;
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, assign) BOOL jitAvailable;
@property (nonatomic, copy)   NSString *pendingGamePath;
@end

@implementation ARMSX2Core

+ (BOOL)engineLinked {
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
    return YES;
#else
    return NO;
#endif
}

- (instancetype)initWithDataRoot:(NSURL *)dataRoot
                    resourceRoot:(NSURL *)resourceRoot
                    biosDirectory:(NSURL *)biosDirectory
                      metalLayer:(CAMetalLayer *)metalLayer
                    jitAvailable:(BOOL)jitAvailable {
    if (self = [super init]) {
        _dataRoot = dataRoot; _resourceRoot = resourceRoot; _biosDirectory = biosDirectory;
        _metalLayer = metalLayer; _jitAvailable = jitAvailable;
        _state = ARMSX2CoreStateIdle;
    }
    return self;
}

- (void)setState:(ARMSX2CoreState)state {
    _state = state;
    dispatch_async(dispatch_get_main_queue(), ^{ [self.delegate armsx2CoreDidChangeState:state]; });
}
- (BOOL)isRunning { return _state == ARMSX2CoreStateRunning; }

- (BOOL)hasValidBIOS {
    // BIOS 폴더에 유효한 PS2 BIOS 이미지가 하나라도 있는지 확인.
    NSArray<NSURL *> *files = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:self.biosDirectory
      includingPropertiesForKeys:nil options:0 error:nil];
    return files.count > 0;   // 실제로는 IsBIOS() 로 검증(BiosTools.h) - 통합 시 강화
}

- (BOOL)bootGameAtPath:(NSString *)path error:(NSError **)error {
    if (![self hasValidBIOS]) {
        if (error) *error = [NSError errorWithDomain:@"ARMSX2" code:-3
            userInfo:@{NSLocalizedDescriptionKey:
            [NSString stringWithFormat:@"PS2 BIOS 없음: %@ 에 BIOS 를 넣으세요.", self.biosDirectory.path]}];
        [self setState:ARMSX2CoreStateFailed];
        return NO;   // 필수 리소스 누락을 성공으로 기록하지 않는다.
    }
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
    self.pendingGamePath = path;
    _stopRequested = NO;
    // VMManager 는 전용 CPU 스레드에서 구동(지시문 8항).
    _cpuThread = [[NSThread alloc] initWithTarget:self selector:@selector(cpuThreadMain) object:nil];
    _cpuThread.name = @"ARMSX2.CPU";
    _cpuThread.stackSize = 8 * 1024 * 1024;
    [_cpuThread start];
    [self setState:ARMSX2CoreStateRunning];
    return YES;
#else
    if (error) *error = [NSError errorWithDomain:@"ARMSX2" code:-100
        userInfo:@{NSLocalizedDescriptionKey:
        @"ARMSX2 엔진이 아직 링크되지 않았습니다(Phase-1 스캐폴드). "
        @"ARMSX2_LINKED=1 로 정적 라이브러리를 링크한 뒤 Mac/Xcode 에서 검증하세요."}];
    [self setState:ARMSX2CoreStateFailed];
    return NO;
#endif
}

#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
- (void)cpuThreadMain {
    @autoreleasepool {
        // 1) 경로/설정 초기화 (EmuFolders 로 데이터 격리 - 지시문 13항).
        EmuFolders::AppRoot   = std::string(self.dataRoot.fileSystemRepresentation);
        EmuFolders::DataRoot  = std::string(self.dataRoot.fileSystemRepresentation);
        EmuFolders::Resources = std::string(self.resourceRoot.fileSystemRepresentation);
        EmuFolders::Bios      = std::string(self.biosDirectory.fileSystemRepresentation);
        VMManager::Internal::LoadStartupSettings();

        // 렌더 surface 등록: GS 초기화(Host::AcquireRenderWindow) 전에 반드시 수행.
        StarlightARMSX2SetRenderLayer((__bridge void *)self.metalLayer);

        // 2) 부팅 파라미터: 게임 경로 + GS 렌더 대상(metalLayer).
        //    렌더 surface 는 WindowInfo(SetNativeWindow)로 GS 에 전달한다(통합 지점).
        VMBootParameters params;
        params.filename = std::string(self.pendingGamePath.UTF8String);

        if (!VMManager::Initialize(params)) {
            [self failWith:@"VMManager::Initialize 실패"];
            return;
        }
        VMManager::SetState(VMState::Running);

        // 3) 실행 루프. Execute() 는 정지 요청 시까지 블로킹.
        while (!_stopRequested && VMManager::HasValidVM()) {
            VMManager::Execute();   // 내부에서 프레임/오디오/입력 펌프
        }
        VMManager::Shutdown();      // GPU/오디오/JIT/메모리 해제(전환 잔류 방지)
        [self setState:ARMSX2CoreStateStopped];
        dispatch_async(dispatch_get_main_queue(), ^{ [self.delegate armsx2CoreDidRequestReturnToHost]; });
    }
}
- (void)failWith:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{ [self.delegate armsx2CoreDidFailWithMessage:msg]; });
    [self setState:ARMSX2CoreStateFailed];
}
#endif

- (void)pause {
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
    VMManager::SetState(VMState::Paused);
#endif
    [self setState:ARMSX2CoreStatePaused];
}
- (void)resume {
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
    VMManager::SetState(VMState::Running);
#endif
    [self setState:ARMSX2CoreStateRunning];
}
- (void)stop {
    _stopRequested = YES;
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
    if (VMManager::HasValidVM()) VMManager::SetState(VMState::Stopping);
#endif
    // CPU 스레드가 Shutdown 까지 마치도록 대기(전환 안전성).
    while (_cpuThread && ![_cpuThread isFinished]) { usleep(2000); }
    _cpuThread = nil;
    if (_state != ARMSX2CoreStateFailed) [self setState:ARMSX2CoreStateStopped];
}
- (void)shutdown {
    if (_cpuThread) { [self stop]; }
    _state = ARMSX2CoreStateIdle;
}

@end

// ============================================================================
// Host:: 콜백(프론트엔드 필수 구현). 전체는 pcsx2-sdl/Main.cpp 참조. 대표 예시만.
// ============================================================================
#if defined(ARMSX2_LINKED) && ARMSX2_LINKED
// void Host::CommitBaseSettingChanges() { ... }
// void Host::LoadSettings(SettingsInterface&, std::unique_lock<std::mutex>&) { ... }
// void Host::OnVMStarting()/OnVMStarted()/OnVMPaused()/OnVMResumed()/OnVMDestroyed() { ... }
// std::optional<WindowInfo> Host::AcquireRenderWindow(...) { /* metalLayer → WindowInfo */ }
// void Host::ReleaseRenderWindow() { ... }
// → 통합 시 pcsx2-sdl 의 구현을 이식/재사용한다.
#endif
