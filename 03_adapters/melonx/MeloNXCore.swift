//
//  MeloNXCore.swift
//  Starlight Emulator - MeloNX Adapter (Bridge)
//
//  MeloNX(= Ryujinx fork)의 코어는 .NET(NativeAOT)로 컴파일되어 C 심볼을 내보낸다
//  (main_ryujinx_sdl / set_native_window / pause_emulation / stop_emulation / touch_* ...).
//  MeloNX 원본은 이 심볼을 Swift 에서 @_silgen_name 으로 바인딩한다.
//  (참조: 01_sources/MeloNX/src/MeloNX/MeloNX/App/Core/Ryujinx/RyujinxBridge.swift,
//         01_sources/MeloNX/src/Ryujinx.Headless.SDL2/Program.cs — UnmanagedCallersOnly)
//
//  === 통합 지점(Mac/Xcode 에서 완성·검증) ===
//   1) Ryujinx.Headless.SDL2 를 NativeAOT(ios-arm64)로 빌드해 만든 라이브러리
//      (원본은 RyujinxHelper.framework) + SDL2.xcframework + FFmpeg/SPIRV 프레임워크를
//      Host 앱에 링크하고 MELONX_LINKED=1 을 정의한다.
//   2) firmware/keys(prod.keys)는 반드시 이 코어 전용 데이터 경로에 둔다(지시문 13항).
//

import Foundation
import QuartzCore

#if MELONX_LINKED
// 실제 NativeAOT C 심볼 바인딩 (원본 RyujinxBridge.swift 와 동일).
@_silgen_name("initialize")            func SN_initialize()
@_silgen_name("initialize-dualmapped") func SN_initialize_dualmapped() -> Bool
@_silgen_name("main_ryujinx_sdl")      func SN_main_ryujinx_sdl(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32
@_silgen_name("pause_emulation")       func SN_pause_emulation(_ pause: Bool)
@_silgen_name("stop_emulation")        func SN_stop_emulation()
@_silgen_name("set_native_window")     func SN_set_native_window(_ layer: UnsafeMutableRawPointer)
@_silgen_name("set_view_size")         func SN_set_view_size(_ w: Int32, _ h: Int32)
#endif

/// 가드로 감싼 얇은 래퍼. 어댑터는 이 타입만 호출한다.
enum MeloNXCore {
    static var engineLinked: Bool {
        #if MELONX_LINKED
        return true
        #else
        return false
        #endif
    }

    static func initializeRuntime(jitAvailable: Bool) -> Bool {
        #if MELONX_LINKED
        SN_initialize()
        // dynamic-codesigning 이 없으면 dual-mapped RW/RX 로 JIT 확보(원본 IsJITEnabled.swift 로직).
        if !jitAvailable { return SN_initialize_dualmapped() }
        return true
        #else
        return false
        #endif
    }

    /// 렌더 surface(CAMetalLayer) 전달. Ryujinx 는 --graphics-backend Vulkan(MoltenVK)로
    /// 이 레이어에 그린다.
    static func setNativeWindow(_ layer: CAMetalLayer) {
        #if MELONX_LINKED
        SN_set_native_window(Unmanaged.passUnretained(layer).toOpaque())
        #endif
    }

    static func setViewSize(width: Int, height: Int) {
        #if MELONX_LINKED
        SN_set_view_size(Int32(width), Int32(height))
        #endif
    }

    /// 블로킹 메인 루프. 반드시 전용 스레드에서 호출한다. 종료 시 반환.
    @discardableResult
    static func runMain(argv: [String]) -> Int32 {
        #if MELONX_LINKED
        return argv.withCStrings { cs, argc in SN_main_ryujinx_sdl(argc, cs) }
        #else
        return -100   // 미링크: 호출 불가
        #endif
    }

    static func pause(_ shouldPause: Bool) {
        #if MELONX_LINKED
        SN_pause_emulation(shouldPause)
        #endif
    }

    static func stop() {
        #if MELONX_LINKED
        SN_stop_emulation()
        #endif
    }
}

// argv([String]) → C 배열 변환 도우미(원본 MeloNX 와 동일한 역할).
extension Array where Element == String {
    func withCStrings<R>(_ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, Int32) -> R) -> R {
        var cStrings: [UnsafeMutablePointer<CChar>?] = map { strdup($0) }
        cStrings.append(nil)
        defer { cStrings.forEach { free($0) } }
        return cStrings.withUnsafeMutableBufferPointer { buf in
            body(buf.baseAddress!, Int32(self.count))
        }
    }
}
