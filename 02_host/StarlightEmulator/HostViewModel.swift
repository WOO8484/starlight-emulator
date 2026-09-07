//
//  HostViewModel.swift
//  Starlight Emulator - Integration Host
//
//  Host UI ↔ EmulatorManager 연결. UI 는 오직 이 뷰모델을 통해 Manager 를 호출한다
//  (지시문 6항: 엔진 직접 호출 금지). 코어 등록/컨텍스트 생성/상태 표시를 담당.
//

import Foundation
import QuartzCore
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class HostViewModel: ObservableObject {

    // UI 바인딩(지시문 11항: 현재 코어 / 상태 / 마지막 오류).
    @Published public var jitStatus: String = "확인 중…"
    @Published public var currentCore: String = "-"
    @Published public var state: String = "idle"
    @Published public var lastError: String = "-"
    @Published public var engineLinkStatus: String = ""

    private var manager: EmulatorManager!
    private var metalLayer: CAMetalLayer?
    private var hostView: AnyObject?          // MetalLayerView (PPSSPP 자식VC 컨테이너)
    private var pendingLaunch: GameDescriptor?

    public init() {}

    /// MetalHostView 가 준비되면 호출. 이 시점에 Manager 를 구성한다.
    public func attach(hostView view: MetalLayerView) {
        self.hostView = view
        self.metalLayer = view.metalLayer
        if manager == nil { setup() }
        // 준비 전 눌린 실행 요청이 있으면 지금 처리.
        if let g = pendingLaunch { pendingLaunch = nil; manager.launch(g) }
    }

    private func setup() {
        JITManager.shared.refresh()
        jitStatus = JITManager.shared.statusText

        manager = EmulatorManager(contextProvider: { [weak self] system in
            self!.makeContext(for: system)
        })
        manager.observer = self

        // 세 어댑터 등록(지시문 6항 흐름의 시작점).
        manager.register(PPSSPPAdapter())
        manager.register(ARMSX2Adapter())
        manager.register(MeloNXAdapter())

        engineLinkStatus =
            "PPSSPP:\(PPSSPPCore.engineLinked ? "링크됨" : "미링크")  "
          + "ARMSX2:\(ARMSX2Core.engineLinked ? "링크됨" : "미링크")  "
          + "MeloNX:\(MeloNXCore.engineLinked ? "링크됨" : "미링크")"
    }

    private func makeContext(for system: EmulatorSystem) -> EmulatorContext {
        let dataRoot = (try? StarlightPaths.dataRoot(for: system))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let resourceRoot = StarlightPaths.resourceRoot(for: system)
        return EmulatorContext(metalLayer: metalLayer ?? CAMetalLayer(),
                               renderContainer: hostView,   // PPSSPP 자식VC 임베드용
                               dataRoot: dataRoot,
                               resourceRoot: resourceRoot,
                               sharedGameLibrary: sharedLibraryURL(),
                               jitAvailable: JITManager.shared.isAvailable)
    }

    // MARK: 테스트 버튼 (지시문 11항)

    public func runTest(_ system: EmulatorSystem) {
        guard let game = resolveTestGame(for: system) else {
            lastError = "\(system.rawValue) 테스트 게임 없음: Documents/TestData/\(system.dataFolderName)/ 에 파일을 넣으세요."
            return
        }
        launch(game)
    }

    public func launch(_ game: GameDescriptor) {
        guard manager != nil, metalLayer != nil else { pendingLaunch = game; return }
        manager.launch(game)
    }

    public func stop() { manager?.stopCurrent() }
    public func pause() { manager?.pause() }
    public func resume() { manager?.resume() }

    /// Documents/TestData/<folder>/ 의 첫 매칭 파일을 테스트 대상으로 사용.
    private func resolveTestGame(for system: EmulatorSystem) -> GameDescriptor? {
        guard let docs = try? FileManager.default.url(for: .documentDirectory,
                        in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        let dir = docs.appendingPathComponent("TestData/\(system.dataFolderName)", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir,
                        includingPropertiesForKeys: nil)) ?? []
        let match = files.first { system.knownExtensions.contains($0.pathExtension.lowercased()) }
        return match.map { GameDescriptor(url: $0, system: system) }
    }

    private func sharedLibraryURL() -> URL? {
        guard let docs = try? FileManager.default.url(for: .documentDirectory,
                        in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
        let lib = docs.appendingPathComponent("GameLibrary", isDirectory: true)
        return FileManager.default.fileExists(atPath: lib.path) ? lib : nil
    }
}

// MARK: - EmulatorManagerObserver

extension HostViewModel: EmulatorManagerObserver {
    public func manager(_ m: EmulatorManager, currentModuleDidChange module: EmulatorModule?) {
        currentCore = module?.system.rawValue ?? "-"
    }
    public func manager(_ m: EmulatorManager, stateDidChange state: EmulatorState, for module: EmulatorModule) {
        self.state = "\(module.system.rawValue): \(state.rawValue)"
    }
    public func manager(_ m: EmulatorManager, didEncounter error: EmulatorError, for module: EmulatorModule?) {
        lastError = error.description
    }
    public func managerDidReturnToHost(_ m: EmulatorManager) {
        currentCore = "-"
        state = "Host 복귀"
    }
}
