//
//  ARMSX2Adapter.swift
//  Starlight Emulator - ARMSX2 Adapter
//

import Foundation

public final class ARMSX2Adapter: NSObject, EmulatorModule {

    public let id = "armsx2"
    public let system: EmulatorSystem = .ps2
    public weak var delegate: EmulatorModuleDelegate?
    private(set) public var state: EmulatorState = .idle {
        didSet { delegate?.module(self, didChangeState: state) }
    }

    private var core: ARMSX2Core?
    private var context: EmulatorContext?

    public func initialize(context: EmulatorContext) throws {
        // 데이터 격리(지시문 13항): 설정/메모리카드/세이브스테이트/BIOS/셰이더캐시 분리.
        try StarlightPaths.ensureSubdirectories(under: context.dataRoot,
            names: ["config", "memcards", "savestates", "cache", "bios", "shader_cache"])
        self.context = context
        let biosDir = context.dataRoot.appendingPathComponent("bios", isDirectory: true)
        let core = ARMSX2Core(dataRoot: context.dataRoot,
                              resourceRoot: context.resourceRoot,
                              biosDirectory: biosDir,
                              metalLayer: context.metalLayer,
                              jitAvailable: context.jitAvailable)
        core.delegate = self
        self.core = core
        state = .initialized
    }

    public func canHandle(_ game: GameDescriptor) -> Bool { defaultCanHandle(game) }

    public func launch(_ game: GameDescriptor) throws {
        guard let core = core else { throw EmulatorError.notInitialized }
        // PS2 는 JIT(recompiler)가 사실상 필수. 없으면 사용자에게 명확히 알림.
        if !(context?.jitAvailable ?? false) {
            delegate?.module(self, didFailWith: .jitUnavailable(
                "PS2 는 EE/VU recompiler(JIT)가 필요합니다. 인터프리터는 매우 느립니다."))
        }
        guard core.hasValidBIOS() else {
            throw EmulatorError.missingResource("PS2 BIOS 를 <dataRoot>/bios 에 넣어야 합니다.")
        }
        state = .launching
        do {
            // Obj-C 의 (BOOL … error:) 는 Swift 에서 throws 로 임포트된다.
            try core.bootGame(atPath: game.url.path)
        } catch {
            state = .failed
            throw EmulatorError.launchFailed((error as NSError).localizedDescription)
        }
    }

    public func pause() throws  { core?.pause() }
    public func resume() throws { core?.resume() }
    public func stop() throws   { core?.stop() }
    public func isRunning() -> Bool { core?.isRunning() ?? false }
    public func shutdown() { core?.shutdown(); core = nil; state = .idle }
}

extension ARMSX2Adapter: ARMSX2CoreDelegate {
    public func armsx2CoreDidChange(_ s: ARMSX2CoreState) {
        switch s {
        case .idle: state = .idle
        case .running: state = .running
        case .paused: state = .paused
        case .stopped: state = .stopped
        case .failed: state = .failed
        @unknown default: break
        }
    }
    public func armsx2CoreDidFail(withMessage message: String) {
        delegate?.module(self, didFailWith: .engineInit(message))
    }
    public func armsx2CoreDidRequestReturnToHost() {
        delegate?.moduleDidRequestReturnToHost(self)
    }
}
