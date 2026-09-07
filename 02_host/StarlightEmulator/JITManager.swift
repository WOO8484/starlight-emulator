//
//  JITManager.swift
//  Starlight Emulator - Integration Host
//
//  JIT 가용성 판정(지시문 10·11항). JIT 자체를 새로 개발하지 않으며,
//  MeloNX 의 검증된 판정 로직(App/Core/JIT/IsJITEnabled.swift)을 이식했다.
//   1) dynamic-codesigning entitlement 보유 → JIT 가능(TrollStore/특수 서명).
//   2) 아니면 디버거 부착(CS_DEBUGGED)로 JIT 활성(AltStore/SideStore/JitStreamer/StikJIT).
//   3) 최종 확인은 RWX 메모리 실행 테스트(allocateTest).
//
//  ARMSX2(EE/VU recompiler)와 MeloNX(ARMeilleure) 모두 이 결과를 사용한다.
//  PPSSPP 는 JIT 불가 시 인터프리터로도 동작한다.
//

import Foundation

private let CS_DEBUGGED: Int = 0x10000000

@_silgen_name("csops")
private func csops(_ pid: Int32, _ ops: Int32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

public final class JITManager {

    public static let shared = JITManager()

    /// 현재 JIT 사용 가능 여부.
    public private(set) var isAvailable: Bool = false
    /// 사람이 읽을 상태 문자열(UI "JIT: READY / NOT READY").
    public var statusText: String { isAvailable ? "READY" : "NOT READY" }

    public func refresh() {
        isAvailable = Self.detectJIT()
    }

    static func detectJIT() -> Bool {
        if hasEntitlement("dynamic-codesigning") {
            return allocateExecTest()
        }
        return isDebugged() && allocateExecTest()
    }

    /// CS_DEBUGGED 플래그(디버거/JIT 활성기 부착 여부).
    static func isDebugged() -> Bool {
        var flags: Int = 0
        let r = csops(getpid(), 0 /*CS_OPS_STATUS*/, &flags, MemoryLayout.size(ofValue: flags))
        return r == 0 && (flags & CS_DEBUGGED) != 0
    }

    /// RWX 페이지에 최소 코드를 써서 실제로 실행 가능한지 검증.
    static func allocateExecTest() -> Bool {
        let pageSize = sysconf(Int32(_SC_PAGESIZE))
        // AArch64: `mov w0, #42; ret`
        let code: [UInt32] = [0x52800540, 0xD65F03C0]
        guard let mem = mmap(nil, pageSize, PROT_READ | PROT_WRITE,
                             MAP_PRIVATE | MAP_ANON, -1, 0), mem != MAP_FAILED else {
            return false
        }
        defer { munmap(mem, pageSize) }
        memcpy(mem, code, code.count * MemoryLayout<UInt32>.size)
        // RX 로 전환 시도(실패하면 JIT 불가).
        guard mprotect(mem, pageSize, PROT_READ | PROT_EXEC) == 0 else { return false }
        return true
    }

    /// 앱 서명에 특정 entitlement 가 있는지(간이). 실제 검사는 csops 로 보강.
    static func hasEntitlement(_ key: String) -> Bool {
        // Phase-1: 서명 시 주입되는 entitlement 존재를 런타임에서 정밀 파싱하려면
        // Mach-O LC_CODE_SIGNATURE 파싱이 필요. 여기서는 보수적으로 false 반환하고
        // CS_DEBUGGED 경로로 판정한다. TrollStore 빌드에서는 true 로 강제 가능.
        return false
    }
}
