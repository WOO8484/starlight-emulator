//
//  EmulatorManager.swift
//  Starlight Emulator - Common Adapter Layer
//
//  지시문 6항: 프론트엔드가 각 엔진을 직접 호출하지 못하게 하는 단일 관문.
//
//      IntegrationHost → EmulatorManager → EmulatorModule → 각 Adapter → 각 Engine
//
//  역할(지시문 6항):
//   • 등록된 모듈 목록 관리
//   • 실행할 모듈 선택
//   • 현재 실행 중 모듈 상태 관리
//   • 새 코어 실행 전 기존 코어 정상 종료   ← 지시문 12항 코어 전환의 핵심
//   • 실패 시 오류 전달
//   • Host 화면 복귀 처리
//

import Foundation

/// Host UI 가 구독하는 Manager 이벤트.
public protocol EmulatorManagerObserver: AnyObject {
    func manager(_ m: EmulatorManager, currentModuleDidChange module: EmulatorModule?)
    func manager(_ m: EmulatorManager, stateDidChange state: EmulatorState, for module: EmulatorModule)
    func manager(_ m: EmulatorManager, didEncounter error: EmulatorError, for module: EmulatorModule?)
    func managerDidReturnToHost(_ m: EmulatorManager)
}

@MainActor
public final class EmulatorManager: NSObject {

    // MARK: 등록/상태

    private(set) public var modules: [EmulatorModule] = []
    private(set) public var currentModule: EmulatorModule?
    public weak var observer: EmulatorManagerObserver?

    /// 마지막 오류(지시문 11항 Host UI "마지막 오류:" 라인).
    private(set) public var lastError: EmulatorError?

    /// initialize(context:) 에 넘길 컨텍스트를 시스템별로 만들어주는 팩토리.
    /// Host 가 주입한다(데이터 경로 격리·Metal 레이어·JIT 상태 포함).
    private let contextProvider: (EmulatorSystem) -> EmulatorContext

    public init(contextProvider: @escaping (EmulatorSystem) -> EmulatorContext) {
        self.contextProvider = contextProvider
        super.init()
    }

    // MARK: 등록

    public func register(_ module: EmulatorModule) {
        guard !modules.contains(where: { $0.id == module.id }) else { return }
        module.delegate = self
        modules.append(module)
    }

    public func module(for system: EmulatorSystem) -> EmulatorModule? {
        modules.first { $0.system == system }
    }

    /// 게임을 실행할 모듈 선택(지시문 6항 "실행할 모듈 선택").
    public func selectModule(for game: GameDescriptor) -> EmulatorModule? {
        if let s = game.system, let m = module(for: s) { return m }
        return modules.first { $0.canHandle(game) }
    }

    // MARK: 실행 (지시문 6·12항)

    /// 게임 실행. 이미 실행 중인 코어가 있으면 **먼저 정상 종료**한 뒤 새 코어를 띄운다.
    /// 이것이 코어 전환(PPSSPP→ARMSX2→MeloNX…)의 안전성을 보장하는 지점이다.
    public func launch(_ game: GameDescriptor) {
        guard let module = selectModule(for: game) else {
            let err = EmulatorError.unsupportedGame(reason: "처리 가능한 모듈 없음: \(game.url.lastPathComponent)")
            report(err, for: nil)
            return
        }

        do {
            // 1) 기존 코어 정상 종료 (지시문 12항: STOP → 다음 코어)
            if let running = currentModule, running.isRunning() {
                try running.stop()
            }
            // 서로 다른 코어로 전환하는 경우, 이전 코어를 확실히 shutdown 하여
            // GPU/오디오/JIT/메모리 리소스 잔류를 막는다(지시문 8·12항).
            if let prev = currentModule, prev.id != module.id {
                prev.shutdown()
            }

            // 2) 대상 코어 준비 + 부팅
            let ctx = contextProvider(module.system)
            try module.initialize(context: ctx)
            setCurrent(module)
            try module.launch(game)
        } catch let e as EmulatorError {
            report(e, for: module)
        } catch {
            report(.internalError(String(describing: error)), for: module)
        }
    }

    public func pause()  { runOnCurrent { try $0.pause() } }
    public func resume() { runOnCurrent { try $0.resume() } }

    /// 현재 코어 정지 후 Host 화면으로 복귀(지시문 11항 "[ 중지 ]").
    public func stopCurrent() {
        guard let m = currentModule else { returnToHost(); return }
        do {
            try m.stop()
        } catch let e as EmulatorError {
            report(e, for: m)
        } catch {
            report(.internalError(String(describing: error)), for: m)
        }
        returnToHost()
    }

    /// 앱 종료/메모리 경고 시 모든 코어 완전 정리.
    public func shutdownAll() {
        for m in modules {
            if m.isRunning() { try? m.stop() }
            m.shutdown()
        }
        setCurrent(nil)
    }

    // MARK: 내부

    private func runOnCurrent(_ action: (EmulatorModule) throws -> Void) {
        guard let m = currentModule else { return }
        do { try action(m) }
        catch let e as EmulatorError { report(e, for: m) }
        catch { report(.internalError(String(describing: error)), for: m) }
    }

    private func setCurrent(_ m: EmulatorModule?) {
        currentModule = m
        observer?.manager(self, currentModuleDidChange: m)
    }

    private func report(_ error: EmulatorError, for module: EmulatorModule?) {
        lastError = error
        observer?.manager(self, didEncounter: error, for: module)
    }

    private func returnToHost() {
        setCurrent(nil)
        observer?.managerDidReturnToHost(self)
    }
}

// MARK: - EmulatorModuleDelegate (어댑터 → Manager)

extension EmulatorManager: EmulatorModuleDelegate {
    public nonisolated func module(_ module: EmulatorModule, didChangeState state: EmulatorState) {
        Task { @MainActor in
            observer?.manager(self, stateDidChange: state, for: module)
        }
    }
    public nonisolated func module(_ module: EmulatorModule, didFailWith error: EmulatorError) {
        Task { @MainActor in report(error, for: module) }
    }
    public nonisolated func moduleDidRequestReturnToHost(_ module: EmulatorModule) {
        Task { @MainActor in
            // 코어 루프가 스스로 끝난 경우(게임 종료 등) → Host 복귀
            if currentModule?.id == module.id { returnToHost() }
        }
    }
}
