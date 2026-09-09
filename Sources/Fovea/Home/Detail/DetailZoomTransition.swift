import SwiftUI
import FoveaCore

/// Opens and closes the detail layer as a quick zoom about the clicked feed card: the whole
/// layer scales from 95 % around the card's center while fading, on the tokens' ease-out
/// curve. Short and directional, never bouncy. Reduce Motion keeps only the fade.
enum DetailZoom {
    static func transition(origin: CGRect?, canvas: CGSize, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let anchor = anchorPoint(origin: origin, canvas: canvas)
        return .modifier(active: ZoomModifier(progress: 0, anchor: anchor),
                         identity: ZoomModifier(progress: 1, anchor: anchor))
    }

    /// The source card's center as a unit point of the canvas; center when there is none.
    static func anchorPoint(origin: CGRect?, canvas: CGSize) -> UnitPoint {
        guard let origin, canvas.width > 0, canvas.height > 0 else { return .center }
        let x = min(1, max(0, origin.midX / canvas.width))
        let y = min(1, max(0, origin.midY / canvas.height))
        return UnitPoint(x: x, y: y)
    }

    struct ZoomModifier: ViewModifier, Animatable {
        var progress: Double
        let anchor: UnitPoint

        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        func body(content: Content) -> some View {
            let scale = Tokens.Motion.detailZoomScale + (1 - Tokens.Motion.detailZoomScale) * progress
            content
                .scaleEffect(scale, anchor: anchor)
                .opacity(progress)
        }
    }
}
