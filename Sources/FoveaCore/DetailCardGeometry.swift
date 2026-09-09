import Foundation
import CoreGraphics

/// Where the floating detail card sits in the window: a centered landscape card taking
/// most of the usable canvas, never so large that the feed disappears behind it.
public enum DetailCardGeometry {
    public struct Spec: Hashable, Sendable {
        public var widthFraction: CGFloat = 0.62
        public var heightFraction: CGFloat = 0.48
        public var maxSize = CGSize(width: 1120, height: 680)
        public var minSize = CGSize(width: 640, height: 400)
        public var margin: CGFloat = 24
        public init() {}
    }

    /// `canvas` is the window content size; `topInset` is the title-bar band to keep clear.
    /// Returned in top-down coordinates.
    public static func frame(canvas: CGSize, topInset: CGFloat, spec: Spec = Spec()) -> CGRect {
        let usable = CGRect(x: 0, y: topInset, width: canvas.width, height: max(0, canvas.height - topInset))
        // Spec sizes scaled down a step: min(62vw, 1120) × min(48vh, 680), never below 640×400 while the canvas allows.
        var w = min(usable.width * spec.widthFraction, spec.maxSize.width, usable.width - spec.margin * 2)
        var h = min(usable.height * spec.heightFraction, spec.maxSize.height, usable.height - spec.margin * 2)
        w = max(w, min(spec.minSize.width, usable.width - spec.margin * 2))
        h = max(h, min(spec.minSize.height, usable.height - spec.margin * 2))
        w = w.rounded()
        h = h.rounded()
        return CGRect(x: ((usable.width - w) / 2).rounded(), y: (usable.minY + (usable.height - h) / 2).rounded(),
                      width: w, height: h)
    }

    /// Transform origin for the zoom: where the source card's center falls inside the
    /// detail card, as a unit point clamped to the card. Center when there is no source.
    public static func zoomAnchor(origin: CGRect?, card: CGRect) -> CGPoint {
        guard let origin, card.width > 0, card.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let x = (origin.midX - card.minX) / card.width
        let y = (origin.midY - card.minY) / card.height
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }

    /// Small translation toward the source card while zooming, so the card reads as
    /// coming from it without sliding across the window.
    public static func zoomShift(origin: CGRect?, card: CGRect, fraction: CGFloat = 0.06) -> CGSize {
        guard let origin else { return .zero }
        return CGSize(width: (origin.midX - card.midX) * fraction, height: (origin.midY - card.midY) * fraction)
    }
}
