//
//  MeloNXAdapter.swift
//  Starlight Emulator - MeloNX Adapter
//
//  EmulatorModule 을 MeloNX(Ryujinx) C ABI 코어에 연결한다.
//  블로킹 SN_main_ryujinx_sdl 은 전용 스레드에서 돌리고, 렌더 surface 는
//  set_native_window 로 전달한다. argv 구성은 원본 Ryujinx.swift(start(with:))를 따른다.
//

import Foundation
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif

public final class MeloNXAdapter: NSObject, EmulatorModule {

    public let id = "melonx"
    public let system: EmulatorSystem = .switchNX
    public weak var delegate: EmulatorModuleDelegate?
    private(set) public var state: EmulatorState = .idle {
        didSet { delegate?.module(self, didChangeState: state) }
    }

    private var context: EmulatorContext?
    private var ryuThread: Thread?
    private var running = false

    public func initialize(context: EmulatorContext) throws {
        // 데이터 격리(지시문 13항): keys/firmware/설정/세이브/셰이더캐시 분리.
        //  - <dataRoot>/system/prod.keys, title.keys   (Ryujinx 키 위치)
        //  - <dataRoot>/bis/                            (설치된 firmware)
        try StarlightPaths.ensureSubdirectories(under: context.dataRoot,
            names: ["system", "bis", "games", "sdcard", "shader_cache", "logs"])
        self.context = context
        // 런타임/ JIT 준비. dynamic-codesigning 없으면 dual-mapped 로 확보 시도.
        if MeloNXCore.engineLinked {
            if !MeloNXCore.initializeRuntime(jitAvailable: context.jitAvailable) {
                throw EmulatorError.jitUnavailable(
                    "Switch 코어 JIT 확보 실패(dynamic-codesigning 또는 dual-mapped 필요).")
            }
        }
        state = .initialized
    }

    public func canHandle(_ game: GameDescriptor) -> Bool { defaultCanHandle(game) }

    public func launch(_ game: GameDescriptor) throws {
        guard let context = context else { throw EmulatorError.notInitialized }

        guard MeloNXCore.engineLinked else {
            state = .failed
            throw EmulatorError.launchFailed(
                "MeloNX 엔진이 아직 링크되지 않았습니다(Phase-1 스캐폴드). "
                + "Ryujinx NativeAOT 라이브러리 + SDL2 를 링크하고 MELONX_LINKED=1 로 검증하세요.")
        }
        // firmware/keys 검증(지시문 9항 "firmware/keys 경로 연결").
        let keys = context.dataRoot.appendingPathComponent("system/prod.keys")
        if !FileManager.default.fileExists(atPath: keys.path) {
            throw EmulatorError.missingResource(
                "prod.keys 가 없습니다: \(keys.path) (Switch 부팅에 필수).")
        }

        state = .launching
        MeloNXCore.setNativeWindow(context.metalLayer)

        let argv = buildArguments(gamePath: game.url.path, context: context)
        let t = Thread { [weak self] in
            let code = MeloNXCore.runMain(argv: argv)   // 블로킹
            DispatchQueue.main.async {
                self?.running = false
                self?.state = (code == 0 ? .stopped : .failed)
                if let self = self { self.delegate?.moduleDidRequestReturnToHost(self) }
            }
        }
        t.name = "MeloNX.Ryujinx"
        t.stackSize = 16 * 1024 * 1024
        ryuThread = t
        running = true
        t.start()
        state = .running
    }

    /// 원본 Ryujinx.swift 의 start(with:) argv 구성을 1단계에 필요한 만큼 추린 것.
    private func buildArguments(gamePath: String, context: EmulatorContext) -> [String] {
        var args = ["StarlightEmulator", gamePath]
        args += ["--graphics-backend", "Vulkan"]          // iOS 는 MoltenVK
        args += ["--memory-manager-mode", "HostMappedUnsafe"]
        args += ["--exclusive-fullscreen", "true"]
        #if canImport(UIKit)
        let b = UIScreen.main.bounds
        args += ["--exclusive-fullscreen-width", "\(Int(b.width))"]
        args += ["--exclusive-fullscreen-height", "\(Int(b.height))"]
        #endif
        if context.jitAvailable { args += ["--has-memory-entitlement"] }
        // hypervisor 사용 여부(사설 entitlement 보유 시). Phase-1 기본 off.
        // if hypervisorAvailable { args += ["--use-hypervisor"] }
        args += ["--ignore-missing-services"]
        return args
    }

    public func pause() throws  { MeloNXCore.pause(true);  state = .paused }
    public func resume() throws { MeloNXCore.pause(false); state = .running }

    public func stop() throws {
        MeloNXCore.stop()
        // 스레드가 SN_main 에서 빠져나올 때까지 대기(전환 안전성 - 지시문 12항).
        var spins = 0
        while running && spins < 2500 { usleep(2000); spins += 1 }
        running = false
        ryuThread = nil
        state = .stopped
    }

    public func isRunning() -> Bool { running }

    public func shutdown() {
        if running { try? stop() }
        state = .idle
    }
}
