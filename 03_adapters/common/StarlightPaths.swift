//
//  StarlightPaths.swift
//  Starlight Emulator - Common Adapter Layer
//
//  데이터 경로 격리(지시문 13항)의 단일 소스. 각 엔진 데이터는 절대 섞지 않는다.
//
//      Application Support/
//      ├─ PPSSPP/   (config, save, cache, screenshots)
//      ├─ ARMSX2/   (config, memcards, savestates, cache, bios, shader_cache)
//      └─ MeloNX/   (system[keys], bis[firmware], games, sdcard, shader_cache, logs)
//
//  사용자가 지정한 공용 게임 라이브러리는 별도 경로로 관리(지시문 13항 단서).
//

import Foundation

public enum StarlightPaths {

    /// 엔진 데이터 루트. Phase-1 실기기 테스트를 위해 **Documents** 하위에 둔다.
    /// (Info.plist 의 UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace 로 Files 앱에서
    ///  keys/firmware/게임을 직접 넣을 수 있어야 하므로. Application Support 는 파일 공유 불가.)
    public static func applicationSupportRoot() throws -> URL {
        let base = try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let root = base.appendingPathComponent("StarlightEmulator", isDirectory: true)
        try ensureDirectory(root)
        return root
    }

    /// 시스템별 격리 데이터 루트. 예: .../StarlightEmulator/PPSSPP
    public static func dataRoot(for system: EmulatorSystem) throws -> URL {
        let url = try applicationSupportRoot().appendingPathComponent(system.dataFolderName, isDirectory: true)
        try ensureDirectory(url)
        return url
    }

    /// 번들 내 upstream 리소스 루트(시스템별). 예: <Bundle>/EngineResources/PPSSPP
    public static func resourceRoot(for system: EmulatorSystem, bundle: Bundle = .main) -> URL {
        let base = bundle.resourceURL ?? bundle.bundleURL
        return base.appendingPathComponent("EngineResources", isDirectory: true)
                   .appendingPathComponent(system.dataFolderName, isDirectory: true)
    }

    public static func ensureDirectory(_ url: URL) throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    public static func ensureSubdirectories(under root: URL, names: [String]) throws {
        try ensureDirectory(root)
        for n in names {
            try ensureDirectory(root.appendingPathComponent(n, isDirectory: true))
        }
    }
}
