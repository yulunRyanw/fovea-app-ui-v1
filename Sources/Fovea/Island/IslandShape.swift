import SwiftUI

/// The island outline: concave "ears" at the top that fuse into the menu bar, straight
/// sides, convex bottom corners. With `topRadius == 0` it is the Quick Answer slab —
/// straight top and sides, rounded bottom only.
///
/// Path after DynamicNotchKit's NotchShape (MIT, © Kai Azim). Both radii animate, in
/// the same transaction as the width and the content inset, so the ears, sides and
/// corners move as one shape instead of the ears snapping ahead of the rest.
struct IslandShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topRadius, rect.width / 2))
        let br = max(0, min(bottomRadius, rect.height, rect.width / 2 - tr))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                           control: CGPoint(x: rect.minX + tr, y: rect.minY))
        }
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                       control: CGPoint(x: rect.minX + tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                       control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                           control: CGPoint(x: rect.maxX - tr, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

/// How content enters and leaves the island: opacity with a light blur and a small scale
/// from the top. One modifier for both directions, so exit is enter played backwards.
struct IslandContentTransition: ViewModifier, Animatable {
    /// 0 = hidden, 1 = shown.
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * Tokens.Motion.contentBlur)
            .scaleEffect(Tokens.Motion.contentScale + (1 - Tokens.Motion.contentScale) * progress, anchor: .top)
    }
}

extension AnyTransition {
    /// The island's content crossfade, on its own short ease-out.
    static var islandContent: AnyTransition {
        let timing = Tokens.Motion.animation(.islandContent).delay(Tokens.Motion.contentDelay * Tokens.Motion.slowMotion)
        // Entering content uses the custom modifier (opacity + blur + scale). Leaving content
        // must not: a custom Animatable modifier does not interpolate on a view that is being
        // removed here — the old content stayed at full opacity for the whole duration and then
        // vanished — so removal is built from the primitive opacity and scale transitions.
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: Tokens.Motion.contentScale, anchor: .top)).animation(timing),
            removal: .opacity.combined(with: .scale(scale: Tokens.Motion.contentScale, anchor: .top)).animation(timing))
    }
}


/// Records a named rect (in global coords) into the model for the eval harness to click.
struct ReportRect: ViewModifier {
    let model: IslandModel
    let key: String
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.debugRects[key] = $0 }
    }
}

extension View {
    func reportRect(_ key: String, in model: IslandModel) -> some View { modifier(ReportRect(model: model, key: key)) }
}
