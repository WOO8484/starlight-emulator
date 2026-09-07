//
//  PPSSPPAdapter.swift
//  Starlight Emulator - PPSSPP Adapter
//
//  EmulatorModule 프로토콜을 PPSSPP 코어(Obj-C++ 브리지)에 연결한다.
//  Manager/Host 는 이 어댑터만 알고, NativeApp API 는 전혀 노출되지 않는다.
//

import Foundation

public final class PPSSPPAdapter: NSObject, EmulatorModule {

    public let id = "ppsspp"
    public let system: EmulatorSystem = .psp
    public weak var delegate: EmulatorModuleDelegate?
    private(set) public var state: EmulatorState = .idle {
        didSet { delegate?.module(self, didChangeState: state) }
    }

    private var core: PPSSPPCore?
    private var context: EmulatorContext?

    public func initialize(context: EmulatorContext) throws {
        // 데이터 격리 경로 보장(지시문 13항).
        try StarlightPaths.ensureSubdirectories(under: context.dataRoot,
                                                names: ["config", "save", "cache", "screenshots"])
        self.context = context
        let core = PPSSPPCore(dataRoot: context.dataRoot,
                              resourceRoot: context.resourceRoot,
                              containerView: context.renderContainer,
                              jitAvailable: context.jitAvailable)
        core.delegate = self
        self.core = core
        state = .initialized
    }

    public func canHandle(_ game: GameDescriptor) -> Bool { defaultCanHandle(game) }

    public func launch(_ game: GameDescriptor) throws {
        guard let core = core else { throw EmulatorError.notInitialized }
        state = .launching
        do {
            // Obj-C 의 (BOOL … error:) 는 Swift 에서 throws 로 임포트된다.
            try core.bootGame(atPath: game.url.path)
        } catch {
            state = .failed
            throw EmulatorError.launchFailed((error as NSError).localizedDescription)
        }
        // 실제 running 전환은 코어 델리게이트에서 통지된다.
    }

    public func pause() throws  { core?.pause() }
    public func resume() throws { core?.resume() }
    public func stop() throws   { core?.stop() }
    public func isRunning() -> Bool { core?.isRunning() ?? false }

    public func shutdown() {
        core?.shutdown()
        core = nil
        state = .idle
    }
}

// MARK: - PPSSPPCoreDelegate

extension PPSSPPAdapter: PPSSPPCoreDelegate {
    public func ppssppCoreDidChangeState(_ s: PPSSPPCoreState) {
        switch s {
        case .idle:    state = .idle
        case .running: state = .running
        case .paused:  state = .paused
        case .stopped: state = .stopped
        case .failed:  state = .failed
        @unknown default: break
        }
    }
    public func ppssppCoreDidFail(withMessage message: String) {
        delegate?.module(self, didFailWith: .engineInit(message))
    }
    public func ppssppCoreDidRequestReturnToHost() {
        delegate?.moduleDidRequestReturnToHost(self)
    }
}
