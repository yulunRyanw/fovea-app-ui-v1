import Foundation
import CoreGraphics

// Pure geometry for the Island. No AppKit: the UI hands in screen metrics and layout
// numbers, and gets back where the island lives and which pointer zone a point is in.
// Unit tested for both notched and flat displays.

/// What the Island needs to know about a display. Frames are in AppKit screen
/// coordinates (origin bottom-left, y up).
public struct ScreenMetrics: Hashable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    /// `NSScreen.safeAreaInsets.top`: the notch height, 0 on displays without one.
    public let safeAreaTop: CGFloat
    /// Widths of `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (the menu bar halves
    /// flanking the notch). 0 when the display has no notch.
    public let auxLeftWidth: CGFloat
    public let auxRightWidth: CGFloat

    public init(frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat,
                auxLeftWidth: CGFloat, auxRightWidth: CGFloat) {
        self.frame = frame; self.visibleFrame = visibleFrame; self.safeAreaTop = safeAreaTop
        self.auxLeftWidth = auxLeftWidth; self.auxRightWidth = auxRightWidth
    }

    public var hasNotch: Bool { safeAreaTop > 0 && auxLeftWidth > 0 && auxRightWidth > 0 }
    public var menuBarHeight: CGFloat { max(0, frame.maxY - visibleFrame.maxY) }
    /// Physical notch width, when there is one.
    public var notchWidth: CGFloat? { hasNotch ? frame.width - auxLeftWidth - auxRightWidth : nil }

    /// 13″ MacBook Air-class display: 1470×956 points, 32 pt notch about 200 pt wide.
    public static let sampleNotched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        visibleFrame: CGRect(x: 0, y: 0, width: 1470, height: 956 - 32),
        safeAreaTop: 32, auxLeftWidth: 635, auxRightWidth: 635)

    /// External / older display without a notch and a 25 pt menu bar.
    public static let sampleFlat = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117 - 25),
        safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0)
}

/// Layout constants the geometry needs. The defaults ARE the production numbers, so
/// FoveaCoreTests can assert what the app ships; `Tokens.Island.Layout` re-exports them.
public struct IslandLayoutSpec: Hashable, Sendable {
    /// Software island on displays without a notch: width of the resting shape.
    public var softwareIslandWidth: CGFloat = 200
    /// Height of the software island when the menu bar is hidden (full-screen apps).
    public var softwareIslandMinHeight: CGFloat = 24
    /// Voice states (Listening, Transcribing, the Retry state) keep the notch's width and
    /// extend this far below it.
    public var voiceBelow: CGFloat = 44
    public var compactTopRadius: CGFloat = 6
    public var compactBottomRadius: CGFloat = 14
    public var expandedTopRadius: CGFloat = 19
    public var expandedBottomRadius: CGFloat = 24
    public var listWidth: CGFloat = 520
    public var reviewWidth: CGFloat = 560
    public var slabWidth: CGFloat = 560
    public var slabBottomRadius: CGFloat = 20
    /// The panel window is this fraction of the screen height (content animates inside it).
    public var panelHeightFraction: CGFloat = 0.5
    /// Docking a dragged Quick Answer, measured from the panel's top-center to the notch's
    /// top-center. Inside `dockApproachDistance` the island opens its receiver; inside
    /// `dockSnapDistance` release docks. A zone is left at its `…Release` radius, so a
    /// hand hovering on a boundary never flickers.
    public var dockApproachDistance: CGFloat = 200
    public var dockApproachRelease: CGFloat = 220
    public var dockSnapDistance: CGFloat = 90
    public var dockSnapRelease: CGFloat = 110
    /// The receiver keeps the slab's width and extends this far below the notch.
    public var dockReceiverBelow: CGFloat = 72
    /// Deceleration per millisecond used to project where a thrown panel would stop
    /// (a scroll view's brisk rate), so a flick toward the notch docks.
    public var dockDecelerationRate: CGFloat = 0.99
    /// Hover: the pointer may drift this far outside the island (left, right, below)
    /// before it counts as having left. Never used for entering.
    public var hoverExitSlack: CGFloat = 8

    public init() {}
}

/// Where things are, for one phase on one display.
public struct IslandFrames: Hashable, Sendable {
    /// The static, oversized, transparent panel window (screen coordinates).
    public let panel: CGRect
    /// The notch (or software island) in panel-local, top-down coordinates.
    public let notch: CGRect
    /// Width of the island shape for this phase, centered on the notch.
    public let width: CGFloat
    /// Minimum height of the shape; content may grow it.
    public let minHeight: CGFloat
    public let topRadius: CGFloat
    public let bottomRadius: CGFloat
    /// True when the shape must start at row 0 with straight sides (Quick Answer slab).
    public let isSlab: Bool

    public var minX: CGFloat { notch.midX - width / 2 }
    /// Width between the ears: what content can use. Equals the notch width when resting.
    public var bodyWidth: CGFloat { width - topRadius * 2 }
    /// The shape's rect in panel-local coordinates, at its minimum height.
    public var rect: CGRect { CGRect(x: minX, y: 0, width: width, height: minHeight) }
}

/// Where the pointer is relative to the island. `inside` means over the notch itself
/// (the only place a hover can start); `near` means over the rest of the island or its
/// exit slack (enough to keep an open panel open); `outside` is everything else.
public enum PointerZone: Hashable, Sendable {
    case outside, near, inside
}

public enum NotchGeometry {
    public enum Density: Hashable, Sendable {
        /// `receiver` is the resting notch opened to take a dragged Quick Answer back.
        case resting, voice, receiver, list, review, slab

        /// Bigger surfaces rank higher; picks the open vs. close motion.
        public var rank: Int {
            switch self {
            case .resting: return 0
            case .voice, .receiver: return 1
            case .list: return 2
            case .review: return 3
            case .slab: return 4
            }
        }
    }

    /// Notch rect in panel-local top-down coordinates. Falls back to a centered software
    /// island sized to the menu bar when the display has no notch.
    public static func notchRect(metrics: ScreenMetrics, spec: IslandLayoutSpec, forceSoftware: Bool = false) -> CGRect {
        let panelWidth = metrics.frame.width
        if !forceSoftware, let width = metrics.notchWidth {
            return CGRect(x: (panelWidth - width) / 2, y: 0, width: width, height: metrics.safeAreaTop)
        }
        let height = max(spec.softwareIslandMinHeight, metrics.menuBarHeight)
        return CGRect(x: (panelWidth - spec.softwareIslandWidth) / 2, y: 0, width: spec.softwareIslandWidth, height: height)
    }

    public static func panelFrame(metrics: ScreenMetrics, spec: IslandLayoutSpec) -> CGRect {
        let height = (metrics.frame.height * spec.panelHeightFraction).rounded()
        return CGRect(x: metrics.frame.minX, y: metrics.frame.maxY - height, width: metrics.frame.width, height: height)
    }

    public static func frames(density: Density, metrics: ScreenMetrics, spec: IslandLayoutSpec,
                              forceSoftware: Bool = false) -> IslandFrames {
        let notch = notchRect(metrics: metrics, spec: spec, forceSoftware: forceSoftware)
        let panel = panelFrame(metrics: metrics, spec: spec)
        switch density {
        case .resting:
            // The shape hugs the notch: the ears live outside the physical notch.
            return IslandFrames(panel: panel, notch: notch,
                                width: notch.width + spec.compactTopRadius * 2,
                                minHeight: notch.height,
                                topRadius: spec.compactTopRadius, bottomRadius: spec.compactBottomRadius,
                                isSlab: false)
        case .voice:
            // Exactly the resting width; only the height grows, downward.
            return IslandFrames(panel: panel, notch: notch,
                                width: notch.width + spec.compactTopRadius * 2,
                                minHeight: notch.height + spec.voiceBelow,
                                topRadius: spec.compactTopRadius, bottomRadius: spec.compactBottomRadius,
                                isSlab: false)
        case .list:
            return IslandFrames(panel: panel, notch: notch,
                                width: max(spec.listWidth, notch.width + spec.expandedTopRadius * 2),
                                minHeight: notch.height,
                                topRadius: spec.expandedTopRadius, bottomRadius: spec.expandedBottomRadius,
                                isSlab: false)
        case .review:
            return IslandFrames(panel: panel, notch: notch,
                                width: max(spec.reviewWidth, notch.width + spec.expandedTopRadius * 2),
                                minHeight: notch.height,
                                topRadius: spec.expandedTopRadius, bottomRadius: spec.expandedBottomRadius,
                                isSlab: false)
        case .slab:
            return IslandFrames(panel: panel, notch: notch,
                                width: max(spec.slabWidth, notch.width + spec.expandedTopRadius * 2),
                                minHeight: notch.height,
                                topRadius: 0, bottomRadius: spec.slabBottomRadius,
                                isSlab: true)
        case .receiver:
            // The slab's mouth: its width and straight top, a shallow depth below the notch.
            return IslandFrames(panel: panel, notch: notch,
                                width: max(spec.slabWidth, notch.width + spec.expandedTopRadius * 2),
                                minHeight: notch.height + spec.dockReceiverBelow,
                                topRadius: 0, bottomRadius: spec.slabBottomRadius,
                                isSlab: true)
        }
    }

    // MARK: - Hover zones

    /// The rects that decide the pointer zone, in panel-local top-down coordinates.
    /// `enter` is the notch itself (chin, ears and slack never count); `exit` is the
    /// island at its target width and measured height, widened by the exit slack on the
    /// left, right and bottom (the top edge is the screen edge).
    public static func hoverRects(frames: IslandFrames, contentHeight: CGFloat,
                                  spec: IslandLayoutSpec) -> (enter: CGRect, exit: CGRect) {
        let height = max(frames.minHeight, contentHeight)
        let island = CGRect(x: frames.minX, y: 0, width: frames.width, height: height)
        let exit = CGRect(x: island.minX - spec.hoverExitSlack, y: 0,
                          width: island.width + spec.hoverExitSlack * 2,
                          height: island.height + spec.hoverExitSlack)
        return (frames.notch, exit)
    }

    public static func pointerZone(at point: CGPoint, frames: IslandFrames, contentHeight: CGFloat,
                                   spec: IslandLayoutSpec) -> PointerZone {
        let rects = hoverRects(frames: frames, contentHeight: contentHeight, spec: spec)
        if rects.enter.contains(point) { return .inside }
        if rects.exit.contains(point) { return .near }
        return .outside
    }

    /// Converts an AppKit screen point (y up) into the panel's top-down coordinates.
    public static func panelLocalPoint(screen: CGPoint, panel: CGRect) -> CGPoint {
        CGPoint(x: screen.x - panel.minX, y: panel.maxY - screen.y)
    }

    /// Distance from a point (screen coordinates) to the notch's top-center.
    public static func dockDistance(from point: CGPoint, metrics: ScreenMetrics) -> CGFloat {
        let anchor = CGPoint(x: metrics.frame.midX, y: metrics.frame.maxY)
        return hypot(point.x - anchor.x, point.y - anchor.y)
    }

    /// Converts a panel-local, top-down rect into screen coordinates.
    public static func screenRect(_ local: CGRect, panel: CGRect) -> CGRect {
        CGRect(x: panel.minX + local.minX,
               y: panel.maxY - local.maxY,
               width: local.width, height: local.height)
    }
}
