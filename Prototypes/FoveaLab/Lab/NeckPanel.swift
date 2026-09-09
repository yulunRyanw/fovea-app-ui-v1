import AppKit
import SwiftUI
import FoveaCore

/// The black neck between the notch and the docked window: the Island's slab material,
/// above the menu bar, overlapping the window's top edge so the two read as one object.
/// Non-interactive. On another display it hangs from the software island position.
@MainActor
final class NeckPanel {
    let panel: NotchPanel
    private let spec = IslandLayoutSpec()
    /// How far the neck reaches into the window, so no hairline can open between them.
    static let overlap: CGFloat = 14
    static let bottomRadius: CGFloat = 14

    init(metrics: ScreenMetrics) {
        panel = NotchPanel(frame: Self.frame(for: metrics))
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: NeckView())
        panel.alphaValue = 0
    }

    static func frame(for m: ScreenMetrics, extra: CGFloat = 0) -> NSRect {
        let width = IslandLayoutSpec().slabWidth
        let height = m.menuBarHeight + overlap + extra
        return NSRect(x: (m.frame.midX - width / 2).rounded(), y: m.frame.maxY - height, width: width, height: height)
    }

    func layout(metrics: ScreenMetrics) {
        panel.setFrame(Self.frame(for: metrics), display: true)
    }

    /// 1 while docked, dimmer while the window approaches, 0 when away.
    func set(alpha: CGFloat, duration: Double) {
        panel.reassert()
        if alpha > 0 { panel.orderFrontRegardless() }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration * LabMotion.scale
            ctx.timingFunction = Tokens.Motion.caTimingFunction
            panel.animator().alphaValue = alpha
        } completionHandler: { [weak self] in
            Task { @MainActor in if alpha == 0 { self?.panel.orderOut(nil) } }
        }
    }

    /// The Island handing a capture down: the neck reaches 6 pt further for a moment.
    func pulse(metrics: ScreenMetrics) {
        let out = Self.frame(for: metrics, extra: 6)
        let home = Self.frame(for: metrics)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14 * LabMotion.scale
            ctx.timingFunction = Tokens.Motion.caTimingFunction
            panel.animator().setFrame(out, display: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * LabMotion.scale) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2 * LabMotion.scale
                ctx.timingFunction = Tokens.Motion.caTimingFunction
                self.panel.animator().setFrame(home, display: true)
            }
        }
    }
}

private struct NeckView: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: NeckPanel.bottomRadius,
                               bottomTrailingRadius: NeckPanel.bottomRadius, topTrailingRadius: 0, style: .continuous)
            .fill(Color.black)
            .ignoresSafeArea()
    }
}
