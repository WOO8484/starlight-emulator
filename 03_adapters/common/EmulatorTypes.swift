//
//  EmulatorTypes.swift
//  Starlight Emulator - Common Adapter Layer
//
//  Phase 1 공통 타입 정의.
//  지시문 5항: "처음부터 거대한 공통 API를 만들지 않는다. 1단계에서 필요한
//  최소 인터페이스만 구현한다." → 아래 타입은 launch/stop/relaunch 및
//  Host 복귀에 필요한 최소한만 정의한다. 세이브스테이트/치트/메타/커버 등은
//  1단계에서 공통화하지 않는다.
//

import Foundation
import QuartzCore   // CAMetalLayer

// MARK: - 대상 시스템

/// 우리가 통합하는 3개 콘솔. rawValue 는 로그/경로/UI 라벨에 그대로 쓴다.
public enum EmulatorSystem: String, CaseIterable, Sendable {
    case psp    = "PSP"      // PPSSPP
    case ps2    = "PS2"      // ARMSX2 (PCSX2 fork)
    case switchNX = "Switch" // MeloNX (Ryujinx fork)

    /// 데이터 격리 폴더 이름 (지시문 13항). Application Support 하위 서브폴더명.
    public var dataFolderName: String {
        switch self {
        case .psp:      return "PPSSPP"
        case .ps2:      return "ARMSX2"
        case .switchNX: return "MeloNX"
        }
    }

    /// 이 시스템이 흔히 쓰는 게임 파일 확장자(소문자). canHandle 의 1차 힌트.
    public var knownExtensions: Set<String> {
        switch self {
        case .psp:      return ["iso", "cso", "chd", "pbp", "elf", "prx"]
        case .ps2:      return ["iso", "chd", "cso", "bin", "mdf", "gz"]
        case .switchNX: return ["nsp", "xci", "nca", "nro"]
        }
    }
}

// MARK: - 게임 기술자

/// 실행 대상 게임. 시스템이 nil 이면 Manager 가 확장자/헤더로 추론한다.
public struct GameDescriptor: Sendable {
    public let url: URL
    public let system: EmulatorSystem?
    public let displayName: String

    public init(url: URL, system: EmulatorSystem? = nil, displayName: String? = nil) {
        self.url = url
        self.system = system
        self.displayName = displayName ?? url.lastPathComponent
    }
}

// MARK: - 코어 상태

/// 단일 코어의 수명주기 상태. Host UI 는 이 값만 보고 "상태:" 라인을 그린다.
public enum EmulatorState: String, Sendable {
    case idle          // 아직 initialize 전
    case initialized   // initialize 완료, launch 대기
    case launching     // launch 진행 중
    case running       // 게임 실행 중
    case paused        // 일시정지
    case stopping      // stop 진행 중
    case stopped       // 정지 완료, relaunch 가능
    case failed        // 오류로 중단 (lastError 참조)
}

// MARK: - 오류

/// 지시문 6항: "실패 시 오류 전달". Host 로 올려보내는 통합 오류 타입.
public enum EmulatorError: Error, CustomStringConvertible, Sendable {
    case notInitialized
    case alreadyRunning(currentCoreID: String)
    case unsupportedGame(reason: String)
    case engineInit(String)      // 엔진 초기화 실패 (네이티브 코어 리턴 실패 등)
    case launchFailed(String)    // 게임 부팅 실패
    case jitUnavailable(String)  // JIT/entitlement 미충족 (ARMSX2/MeloNX)
    case missingResource(String) // BIOS/firmware/keys 누락
    case renderSurface(String)   // Metal surface 연결 실패
    case internalError(String)

    public var description: String {
        switch self {
        case .notInitialized:                return "코어가 초기화되지 않았습니다."
        case .alreadyRunning(let id):        return "이미 실행 중인 코어가 있습니다: \(id)"
        case .unsupportedGame(let r):        return "지원하지 않는 게임: \(r)"
        case .engineInit(let m):             return "엔진 초기화 실패: \(m)"
        case .launchFailed(let m):           return "게임 실행 실패: \(m)"
        case .jitUnavailable(let m):         return "JIT 사용 불가: \(m)"
        case .missingResource(let m):        return "필수 리소스 누락: \(m)"
        case .renderSurface(let m):          return "렌더 surface 오류: \(m)"
        case .internalError(let m):          return "내부 오류: \(m)"
        }
    }
}

// MARK: - 실행 컨텍스트

/// initialize(context) 로 주입되는 호스트 환경.
/// 각 엔진 어댑터가 렌더/오디오/경로를 여기서 받아간다.
/// 지시문 13항 데이터 격리를 위해 경로는 시스템별로 분리되어 전달된다.
public struct EmulatorContext: Sendable {
    /// 이 코어가 그릴 Metal 레이어. Host 가 소유하고 코어에 대여한다.
    /// ARMSX2(Host::AcquireRenderWindow) / MeloNX(set_native_window) 가 이 포인터를 사용.
    /// 코어 stop 후에도 레이어 자체는 파괴하지 않는다(재실행 대비).
    public let metalLayer: CAMetalLayer

    /// 렌더 컨테이너 뷰(iOS: UIView). PPSSPP 처럼 엔진이 자체 뷰(ViewControllerMetal)를
    /// 임베드하는 경우 여기에 자식 VC 뷰를 붙인다. 공통 계층의 UIKit 의존을 피하려 AnyObject 로 둔다.
    public let renderContainer: AnyObject?

    /// 이 시스템 전용 데이터 루트 (Application Support/<dataFolderName>).
    /// 하위에 config/, save/, cache/, bios/, firmware/, keys/, shader/ 를 둔다.
    public let dataRoot: URL

    /// upstream 엔진이 읽을 리소스(assets/flash0/fonts 등) 경로. 보통 번들 내부.
    public let resourceRoot: URL

    /// 사용자가 지정한 공용 게임 라이브러리(선택). 지시문 13항 단서 조항.
    public let sharedGameLibrary: URL?

    /// JIT 사용 가능 여부(Host 의 JITManager 가 판정해 전달).
    public let jitAvailable: Bool

    public init(metalLayer: CAMetalLayer,
                renderContainer: AnyObject? = nil,
                dataRoot: URL,
                resourceRoot: URL,
                sharedGameLibrary: URL? = nil,
                jitAvailable: Bool) {
        self.metalLayer = metalLayer
        self.renderContainer = renderContainer
        self.dataRoot = dataRoot
        self.resourceRoot = resourceRoot
        self.sharedGameLibrary = sharedGameLibrary
        self.jitAvailable = jitAvailable
    }
}
