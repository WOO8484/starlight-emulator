//
//  MetalHostView.swift
//  Starlight Emulator - Integration Host
//
//  모든 코어가 공유하는 단일 렌더 surface(CAMetalLayer)를 제공한다.
//  세 엔진이 같은 레이어를 순차 사용하므로, 코어 전환 시 이전 코어가 stop 에서
//  반드시 surface 를 해제해야 한다(지시문 12항 "Metal surface 충돌" 검증 대상).
//

import SwiftUI
import QuartzCore

#if canImport(UIKit)
import UIKit

/// layerClass 가 CAMetalLayer 인 UIView.
public final class MetalLayerView: UIView {
    public override class var layerClass: AnyClass { CAMetalLayer.self }
    public var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    public override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        metalLayer.drawableSize = CGSize(width: bounds.width * metalLayer.contentsScale,
                                         height: bounds.height * metalLayer.contentsScale)
    }
}

public struct MetalHostView: UIViewRepresentable {
    /// 생성된 레이어를 상위(ViewModel)로 전달.
    public let onLayer: (CAMetalLayer) -> Void
    public init(onLayer: @escaping (CAMetalLayer) -> Void) { self.onLayer = onLayer }

    public func makeUIView(context: Context) -> MetalLayerView {
        let v = MetalLayerView(frame: .zero)
        v.backgroundColor = .black
        onLayer(v.metalLayer)
        return v
    }
    public func updateUIView(_ uiView: MetalLayerView, context: Context) {}
}
#endif
