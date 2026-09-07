//
//  ContentView.swift
//  Starlight Emulator - Integration Host
//
//  지시문 11항 최소 검증 UI. 예쁜 디자인 금지(지시문 22항). 목적은 Adapter/엔진 연결 검증뿐.
//
//      Starlight Emulator - Integration Test
//      JIT: READY / NOT READY
//      [ PSP 테스트 ] [ PS2 테스트 ] [ Switch 테스트 ]
//      현재 코어: / 상태: / 마지막 오류:
//      [ 중지 ]
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = HostViewModel()

    var body: some View {
        ZStack {
            // 렌더 surface(항상 존재해야 레이어가 만들어짐). 코어가 여기에 그린다.
            MetalHostView { view in vm.attach(hostView: view) }
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("Starlight Emulator — Integration Test")
                    .font(.headline).foregroundColor(.white)

                Text("JIT: \(vm.jitStatus)")
                    .foregroundColor(vm.jitStatus == "READY" ? .green : .yellow)
                Text(vm.engineLinkStatus)
                    .font(.caption).foregroundColor(.gray)

                HStack(spacing: 8) {
                    Button("PSP 테스트")    { vm.runTest(.psp) }
                    Button("PS2 테스트")    { vm.runTest(.ps2) }
                    Button("Switch 테스트") { vm.runTest(.switchNX) }
                }
                .buttonStyle(.borderedProminent)

                Group {
                    Text("현재 코어: \(vm.currentCore)")
                    Text("상태: \(vm.state)")
                    Text("마지막 오류: \(vm.lastError)")
                        .foregroundColor(.orange)
                }
                .foregroundColor(.white).font(.callout)

                HStack(spacing: 8) {
                    Button("일시정지") { vm.pause() }
                    Button("재개")     { vm.resume() }
                    Button("중지")     { vm.stop() }.tint(.red)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.35))
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
