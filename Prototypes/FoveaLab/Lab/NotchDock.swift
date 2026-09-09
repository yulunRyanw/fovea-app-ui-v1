import AppKit
import SwiftUI
import FoveaCore

/// Docks the lab window to the notch. It opens out of the notch and hangs from the neck;
/// drag it away and it detaches (the neck goes); drag it back within the Island's dock zones
/// and release, and it flies home on the tokens' curve. The same zones the Quick Answer
/// panel uses (`IslandLayoutSpec`: approach 200/220, snap 90/110).
@MainActor
final class NotchDock: NSObject, NSWindowDelegate {
    enum Zone { case outside, near, ready }

    let window: NSWindow
    let state: LabState
    private let spec = IslandLayoutSpec()
    private var neck: NeckPanel?
    private var observers: [Any] = []
    private var mouseMonitors: [Any] = []
    private(set) var zone: Zone = .ready
    private(set) var atDock = true
    private var flying = false
    private var dragging = false
    private var closing = false

    init(window: NSWindow, state: LabState) {
        self.window = window
        self.state = state
        super.init()
        window.delegate = self
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.windowMoved() }
        })
    }

    // MARK: Smoke hooks

    var neckAlpha: CGFloat { neck?.panel.alphaValue ?? 0 }
    var neckFrame: NSRect { neck?.panel.frame ?? .zero }

    // MARK: Geometry

    private var screen: NSScreen { window.screen ?? ScreenObserver.screenWithPointer ?? NSScreen.main! }
    var metrics: ScreenMetrics { ScreenObserver.metrics(for: screen) }

    /// Centered under the notch, top edge just below the menu bar (a window cannot overlap it).
    func dockFrame() -> NSRect {
        let m = metrics
        let size = Tokens.Layout.window
        return NSRect(x: (m.frame.midX - size.width / 2).rounded(), y: m.visibleFrame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    /// The narrow frame the window opens from and closes into: the slab's width, a sliver tall.
    private func seedFrame() -> NSRect {
        let target = dockFrame()
        return NSRect(x: target.midX - spec.slabWidth / 2, y: target.maxY - 28, width: spec.slabWidth, height: 28)
    }

    private func distanceToDock(_ frame: NSRect) -> CGFloat {
        let m = metrics
        let dx = frame.midX - m.frame.midX
        let dy = frame.maxY - m.visibleFrame.maxY
        return (dx * dx + dy * dy).squareRoot()
    }

    private func zone(for d: CGFloat, current: Zone) -> Zone {
        if d <= (current == .ready ? spec.dockSnapRelease : spec.dockSnapDistance) { return .ready }
        if d <= (current == .outside ? spec.dockApproachDistance : spec.dockApproachRelease) { return .near }
        return .outside
    }

    // MARK: Open and close

    func present() {
        neck = NeckPanel(metrics: metrics)
        if state.docked {
            open()
        } else {
            var frame = dockFrame()
            frame.origin.y -= 72
            window.setFrame(frame, display: false)
            atDock = false
            zone = .outside
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Out of the notch: the frame grows from the seed on the tokens' curve while the content
    /// waits `contentDelay` and fades in behind it. Geometry first, content later.
    private func open() {
        let target = dockFrame()
        atDock = true
        zone = .ready
        if ProcessInfo.processInfo.environment["FOVEA_LAB_LOG"] != nil {
            let m = metrics
            FileHandle.standardError.write(Data("lab: screen frame=\(m.frame) visible=\(m.visibleFrame) menuBar=\(m.menuBarHeight) notch=\(m.hasNotch)\n".utf8))
            FileHandle.standardError.write(Data("lab: dock frame=\(target) seed=\(seedFrame())\n".utf8))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                FileHandle.standardError.write(Data("lab: after open frame=\(self.window.frame) visible=\(self.window.isVisible) alpha=\(self.window.contentView?.alphaValue ?? -1) screen=\(self.window.screen?.frame ?? .zero)\n".utf8))
            }
        }
        if state.reduceMotion {
            window.setFrame(target, display: true)
            window.contentView?.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
            updateNeck(duration: 0.12)
            return
        }
        window.setFrame(seedFrame(), display: false)
        window.contentView?.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        flying = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Tokens.Motion.Spring.open.seconds * LabMotion.scale
            ctx.timingFunction = Tokens.Motion.caTimingFunction
            window.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in self?.flying = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.contentDelay * LabMotion.scale) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.24 * LabMotion.scale
                ctx.timingFunction = Tokens.Motion.caTimingFunction
                self.window.contentView?.animator().alphaValue = 1
            }
        }
        updateNeck(duration: 0.18)
    }

    /// Back into the notch, then quit: the content leaves first, then the frame.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !closing else { return true }
        closing = true
        let finish = { NSApp.terminate(nil) }
        guard atDock, !state.reduceMotion else { finish(); return false }
        neck?.set(alpha: 0, duration: 0.2)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12 * LabMotion.scale
            window.contentView?.animator().alphaValue = 0
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Tokens.Motion.Spring.close.seconds * LabMotion.scale
            ctx.timingFunction = Tokens.Motion.caTimingFunction
            window.animator().setFrame(seedFrame(), display: true)
        } completionHandler: { finish() }
        return false
    }

    // MARK: Drag, detach, re-dock

    private func windowMoved() {
        guard !flying, !closing else { return }
        if !dragging {
            dragging = true
            installMouseUp()
        }
        let d = distanceToDock(window.frame)
        let z = zone(for: d, current: zone)
        if z != zone {
            zone = z
            if atDock && z != .ready { atDock = false }
            updateNeck(duration: 0.12)
        }
    }

    private func installMouseUp() {
        guard mouseMonitors.isEmpty else { return }
        let handler: () -> Void = { [weak self] in Task { @MainActor in self?.mouseUp() } }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { e in handler(); return e }) { mouseMonitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { _ in handler() }) { mouseMonitors.append(global) }
    }

    private func mouseUp() {
        guard dragging else { return }
        dragging = false
        for m in mouseMonitors { NSEvent.removeMonitor(m) }
        mouseMonitors.removeAll()
        if zone == .ready, state.docked {
            fly(to: dockFrame().origin) { [weak self] in
                self?.atDock = true
                self?.updateNeck(duration: 0.12)
            }
        }
    }

    /// Home on the tokens' curve, the same length as the Island's open spring.
    private func fly(to origin: CGPoint, completion: @escaping () -> Void) {
        flying = true
        if state.reduceMotion {
            window.setFrameOrigin(origin); flying = false; completion(); return
        }
        // The animator proxy honors setFrame(_:display:), not setFrameOrigin.
        let target = NSRect(origin: origin, size: window.frame.size)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Tokens.Motion.Dock.flightDuration * LabMotion.scale
            ctx.timingFunction = Tokens.Motion.caTimingFunction
            window.animator().setFrame(target, display: true)
        } completionHandler: {
            Task { @MainActor in self.flying = false; completion() }
        }
    }

    // MARK: Palette

    /// The Docked switch: on flies the window home; off lets it drop and takes the neck away.
    func setDocked(_ docked: Bool) {
        if docked {
            zone = .ready
            fly(to: dockFrame().origin) { [weak self] in
                self?.atDock = true
                self?.updateNeck(duration: 0.12)
            }
        } else {
            atDock = false
            zone = .outside
            updateNeck(duration: 0.12)
            var origin = window.frame.origin
            origin.y -= 72
            fly(to: origin) {}
        }
    }

    /// The Island handing a capture down.
    func pulseNeck() {
        guard atDock, state.showsNeck else { return }
        neck?.pulse(metrics: metrics)
    }

    func updateNeck(duration: Double) {
        guard let neck else { return }
        neck.layout(metrics: metrics)
        guard state.docked, state.showsNeck else { neck.set(alpha: 0, duration: duration); return }
        let alpha: CGFloat
        if atDock { alpha = 1 }
        else if zone == .ready { alpha = 0.85 }
        else if zone == .near { alpha = 0.45 }
        else { alpha = 0 }
        neck.set(alpha: alpha, duration: duration)
    }
}

extension Tokens.Motion.Spring {
    /// The spring's duration as a plain number, for AppKit animations that mirror it.
    var seconds: Double {
        switch self {
        case .open: return 0.34
        case .close: return 0.30
        case .convert: return 0.28
        case .hover: return 0.18
        }
    }
}
