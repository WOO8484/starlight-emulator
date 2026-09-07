//
//  EmulatorModule.swift
//  Starlight Emulator - Common Adapter Layer
//
//  지시문 5항의 "최소 인터페이스". 프론트엔드/Manager 는 오직 이 프로토콜만
//  알고, 각 엔진(PPSSPP/ARMSX2/MeloNX)의 구체 API 는 어댑터 내부에 숨긴다.
//  (지시문 6항: UI 에서 PPSSPP::Start / VMManager::Initialize / SN_main_ryujinx_sdl
//   를 직접 부르는 것을 금지 → 반드시 이 프로토콜을 경유)
//

import Foundation

/// 코어 상태/오류를 Host 로 비동기 통지하기 위한 델리게이트.
/// 모든 콜백은 메인 스레드에서 호출되도록 어댑터가 보장한다.
public protocol EmulatorModuleDelegate: AnyObject {
    func module(_ module: EmulatorModule, didChangeState state: EmulatorState)
    func module(_ module: EmulatorModule, didFailWith error: EmulatorError)
    /// 코어 루프가 자연 종료되어 Host 화면으로 복귀해야 할 때(지시문 6항 "Host 복귀").
    func moduleDidRequestReturnToHost(_ module: EmulatorModule)
}

/// 지시문 5항 최소 인터페이스. 1단계 범위에 필요한 멤버만 둔다.
public protocol EmulatorModule: AnyObject {

    /// 안정적인 식별자. 로그/등록 키로 사용. 예: "ppsspp", "armsx2", "melonx".
    var id: String { get }

    /// 이 모듈이 담당하는 콘솔.
    var system: EmulatorSystem { get }

    /// 현재 상태(동기 조회).
    var state: EmulatorState { get }

    /// 상태/오류 통지 대상. Manager 가 설정한다.
    var delegate: EmulatorModuleDelegate? { get set }

    /// 엔진을 실행 가능한 상태로 준비한다(데이터 경로 생성, 코어 정적 init 등).
    /// 게임을 부팅하지는 않는다. 여러 번 호출돼도 안전해야 한다(멱등).
    func initialize(context: EmulatorContext) throws

    /// 이 게임을 이 모듈이 실행할 수 있는지(확장자/헤더 기반 1차 판정).
    func canHandle(_ game: GameDescriptor) -> Bool

    /// 게임을 부팅해 실행 상태로 만든다. 반드시 initialize 이후 호출.
    /// 블로킹 엔진(ARMSX2 CPU thread, MeloNX SDL loop)은 내부에서 전용 스레드로 돌린다.
    func launch(_ game: GameDescriptor) throws

    /// 일시정지 / 재개.
    func pause() throws
    func resume() throws

    /// 게임을 정지하고 GPU/오디오/입력 리소스를 해제한다. relaunch 가능 상태로 되돌린다.
    /// (지시문 12항: STOP 후 재실행/코어 전환이 반복 가능해야 함)
    func stop() throws

    /// 실행 중 여부.
    func isRunning() -> Bool

    /// 프로세스 종료 직전 최종 정리(정적 리소스까지 해제). initialize 의 역.
    func shutdown()
}

// MARK: - 선택적 확장 (지시문 5항: "필요한 경우에만 추가")

public protocol EmulatorSettingsProviding {
    func getSettings() -> [String: String]
    func setSettings(_ settings: [String: String])
}

public protocol EmulatorSavePathProviding {
    /// 이 코어의 세이브 데이터 루트(격리 경로). 지시문 13항.
    func getSavePath() -> URL
}

// MARK: - 기본 구현 도우미

public extension EmulatorModule {
    /// 확장자 기반 canHandle 기본 판정. 필요 시 어댑터가 override.
    func defaultCanHandle(_ game: GameDescriptor) -> Bool {
        if let s = game.system { return s == system }
        let ext = game.url.pathExtension.lowercased()
        return system.knownExtensions.contains(ext)
    }
}
