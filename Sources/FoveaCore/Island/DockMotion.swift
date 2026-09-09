import Foundation
import CoreGraphics

// Pure motion helpers for docking a detached Quick Answer back into the notch. No AppKit,
// so the zones, the magnetism and the panel's flight home are unit tested without a window.

/// A spring with no bounce (damping ratio 1), in the closed form SwiftUI uses for
/// `.smooth`: mass 1, stiffness (2π/duration)², damping 4π/duration. One axis at a time.
public struct CriticallyDampedSpring: Hashable, Sendable {
    public let duration: CGFloat
    public var omega: CGFloat { 2 * .pi / duration }

    public init(duration: CGFloat) { self.duration = duration }

    public func position(at t: CGFloat, from x0: CGFloat, to target: CGFloat, velocity v0: CGFloat) -> CGFloat {
        let a = x0 - target
        let b = v0 + omega * a
        return target + (a + b * t) * exp(-omega * t)
    }

    public func velocity(at t: CGFloat, from x0: CGFloat, to target: CGFloat, velocity v0: CGFloat) -> CGFloat {
        let a = x0 - target
        let b = v0 + omega * a
        return (b - omega * (a + b * t)) * exp(-omega * t)
    }

    /// The largest release velocity the motion can absorb without crossing the target:
    /// speed toward the target is capped at ω·|distance|, speed away from it is dropped.
    public func clampedVelocity(_ v0: CGFloat, from x0: CGFloat, to target: CGFloat) -> CGFloat {
        let a = x0 - target
        guard a != 0, v0 != 0, (v0 > 0) != (a > 0) else { return 0 }
        let cap = omega * abs(a)
        return v0 > 0 ? min(v0, cap) : max(v0, -cap)
    }
}

public extension NotchGeometry {
    /// Which docking zone a floating panel is in, from its top-center (screen coordinates).
    /// Hysteresis: a zone is entered at its inner radius and left at its outer one, so a
    /// hand hovering on a boundary never flickers the receiver.
    static func dockZone(panelTopCenter: CGPoint, current: DockZone, metrics: ScreenMetrics,
                         spec: IslandLayoutSpec) -> DockZone {
        let d = dockDistance(from: panelTopCenter, metrics: metrics)
        if d <= (current == .ready ? spec.dockSnapRelease : spec.dockSnapDistance) { return .ready }
        if d <= (current == .outside ? spec.dockApproachDistance : spec.dockApproachRelease) { return .near }
        return .outside
    }

    /// Where a thrown panel would come to rest if it decelerated like a scroll view
    /// (velocity in points per second; `decelerationRate` per millisecond, 0.99 = brisk).
    static func projectedPoint(from point: CGPoint, velocity: CGVector, decelerationRate: CGFloat) -> CGPoint {
        let factor = (decelerationRate / 1000) / (1 - decelerationRate)
        return CGPoint(x: point.x + velocity.dx * factor, y: point.y + velocity.dy * factor)
    }

    /// Screen rect a floating panel of `size` docks into: centred on the notch, its top
    /// edge on the top edge of the screen, exactly where the attached slab draws.
    static func dockTargetRect(size: CGSize, metrics: ScreenMetrics, spec: IslandLayoutSpec,
                               forceSoftware: Bool = false) -> CGRect {
        let notch = notchRect(metrics: metrics, spec: spec, forceSoftware: forceSoftware)
        let panel = panelFrame(metrics: metrics, spec: spec)
        return CGRect(x: panel.minX + notch.midX - size.width / 2, y: panel.maxY - size.height,
                      width: size.width, height: size.height)
    }

    /// Magnetism: the drawn position leans from the free (pointer-driven) position toward
    /// the target as the panel closes in; the full `strength` at distance 0, nothing at
    /// `dockSnapDistance` and beyond. Stateless, so it never fights the pointer.
    static func magnetized(free: CGPoint, target: CGPoint, distance: CGFloat, strength: CGFloat,
                           spec: IslandLayoutSpec) -> CGPoint {
        let k = strength * max(0, 1 - distance / spec.dockSnapDistance)
        return CGPoint(x: free.x + (target.x - free.x) * k, y: free.y + (target.y - free.y) * k)
    }
}
