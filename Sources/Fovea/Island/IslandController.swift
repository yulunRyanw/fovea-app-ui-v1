import SwiftUI
import AppKit
import Carbon.HIToolbox
import FoveaCore

/// Owns the AppKit side of the Island: the notch panel, its hosting view, the screen it
/// sits on, pointer tracking, and the detached Quick Answer panel. Created once by the
/// AppDelegate.
@MainActor
final class IslandController {
    let model: IslandModel
    private let screens = ScreenObserver()
    private let pointer = IslandPointerTracker()

    private(set) var panel: NotchPanel?
    private(set) var hosting: PassthroughHostingView<IslandRootView>?
    private var detached: DetachedPanel?
    private let drag = DetachedDragEngine(velocityWindow: Tokens.Motion.Dock.velocityWindow)
    /// The throw the user released with; it seeds the flight home.
    private var releaseVelocity = CGVector.zero
    /// A torn-off card starts inside the dock zones; they count only once it has left them,
    /// so tearing off never opens the receiver by itself.
    private var dockArmed = true
    private var pendingKeyCheck: DispatchWorkItem?
    private var settleCheck: Task<Void, Never>?

    init(model: IslandModel) {
        self.model = model
        model.onRequestKey = { [weak self] in self?.requestKey() }
        model.onReleaseKey = { [weak self] _ in self?.releaseKey() }
        // `observeGeometry()` re-checks the pointer zone after a phase change instead.
        model.onPresentDetached = { [weak self] continuing in self?.presentDetached(continuingDrag: continuing) }
        model.onDismissDetached = { [weak self] in self?.dismissDetached() }
        model.onSessionWillBegin = { [weak self] in self?.followPointer() }
        screens.onDisplaysChanged = { [weak self] in self?.rebuild() }
        screens.onNeedsReassert = { [weak self] in self?.reassert() }
        pointer.zoneProvider = { [weak self] point in self?.zone(at: point) ?? .outside }
        pointer.onZoneChange = { [weak model] zone in model?.send(.pointerZoneChanged(zone)) }
    }

    func start() {
        rebuild()
        model.start()
        pointer.start()
        observeGeometry()
    }

    // MARK: - Panel

    private func rebuild() {
        guard let screen = ScreenObserver.screenWithPointer else { return }
        model.setMetrics(ScreenObserver.metrics(for: screen))
        let frame = model.frames.panel
        if let panel {
            panel.setFrame(frame, display: true)
            panel.reassert()
            panel.orderFrontRegardless()
            pointer.reevaluate()
            return
        }
        let panel = NotchPanel(frame: frame)
        let hosting = PassthroughHostingView(rootView: IslandRootView(model: model))
        hosting.hitRegion = { [weak model] in model?.hitRegion }
        hosting.hitPath = { [weak model] in model?.hitPath }
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        // Key changes can arrive from inside a window re-order; never re-enter the reducer.
        panel.onKeyChange = { [weak model] isKey in
            Task { @MainActor [weak model] in model?.send(.focusChanged(isKey)) }
        }
        panel.orderFrontRegardless()
        self.panel = panel
        self.hosting = hosting
    }

    private func reassert() {
        guard let panel else { return }
        panel.reassert()
        if !panel.isOnActiveSpace {
            // Window-server state can go stale across sleep; rebuild once.
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    /// Before a session starts, move to the display the pointer is on.
    private func followPointer() {
        guard let screen = ScreenObserver.screenWithPointer, let panel else { return }
        let metrics = ScreenObserver.metrics(for: screen)
        guard metrics != model.metrics else { return }
        model.setMetrics(metrics)
        panel.setFrame(model.frames.panel, display: true)
        panel.orderFrontRegardless()
        pointer.reevaluate()
    }

    // MARK: - Pointer

    /// Which zone a screen point is in, against the island's target geometry.
    func zone(at screenPoint: CGPoint) -> PointerZone {
        guard let panel else { return .outside }
        let local = NotchGeometry.panelLocalPoint(screen: screenPoint, panel: panel.frame)
        return NotchGeometry.pointerZone(at: local, frames: model.frames, contentHeight: model.contentBounds.height,
                                         spec: Tokens.Island.Layout.layoutSpec)
    }

    /// Geometry changed: re-check the pointer now, and again once the motion has settled.
    private func observeGeometry() {
        withObservationTracking {
            _ = model.phase
            _ = model.contentBounds
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pointer.reevaluate()
                self.settleCheck?.cancel()
                self.settleCheck = Task { [weak self] in
                    try? await Task.sleep(for: Tokens.Motion.settleCheck)
                    guard !Task.isCancelled else { return }
                    self?.pointer.reevaluate()
                }
                self.observeGeometry()
            }
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            model.send(.escape)
            return true
        case kVK_Return where event.modifierFlags.contains(.command):
            if model.phase == .review { model.send(.send); return true }
            return false
        default:
            // Nothing else should beep while the panel briefly holds key during a collapse.
            return !(model.phase.isReview || model.phase.isQuickAnswer)
        }
    }

    // MARK: - Key status (without activating Fovea)

    private func requestKey() {
        guard let panel else { return }
        pendingKeyCheck?.cancel()
        panel.makeKeyAndOrderFront(nil)
        // Key can be lost to a late re-order; check once the run loop has settled.
        let check = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel, !panel.isKeyWindow else { return }
            if self.model.phase.isReview || self.model.phase == .quickAnswer(.attached) { panel.makeKey() }
        }
        pendingKeyCheck = check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: check)
    }

    /// Runs once the collapse has finished (the model defers it), so the re-order never
    /// interrupts a running animation.
    private func releaseKey() {
        pendingKeyCheck?.cancel()
        pendingKeyCheck = nil
        guard let panel else { return }
        panel.makeFirstResponder(nil)
        guard panel.isKeyWindow else { return }
        // A non-activating panel hands key back to the frontmost app when it leaves the
        // screen; re-order it immediately so the island stays visible.
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }

    // MARK: - Detached Quick Answer

    /// Creates the floating panel where the slab was and, for a tear-off, starts following
    /// the pointer at once. A scenario jump drops it a little lower so it can be seen.
    private func presentDetached(continuingDrag: Bool) {
        guard detached == nil, panel != nil else { return }
        let size = CGSize(width: Tokens.Island.Layout.detachedDefault.width, height: detachedStartHeight)
        var frame = dockTarget(for: size)
        if !continuingDrag { frame.origin.y -= Tokens.Island.Layout.detachedScenarioDrop }
        let window = DetachedPanel(frame: frame)
        let host = DetachedHostingView(rootView: DetachedQuickAnswerView(
            model: model,
            onSize: { [weak self] size in self?.detachedContentSized(size) },
            onDragBegin: { [weak self] in self?.beginDrag() }))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        window.onKeyDown = { [weak self] e in self?.handleKey(e) ?? false }
        window.onKeyChange = { _ in }
        window.orderFrontRegardless()
        detached = window
        dockArmed = !continuingDrag
        if continuingDrag || NSEvent.pressedMouseButtons & 1 != 0 { beginDrag() }
    }

    /// The slab's measured height without the notch: the card's height until it reports its own.
    private var detachedStartHeight: CGFloat {
        let bounds = model.contentBounds
        guard bounds.height > 0 else { return Tokens.Island.Layout.detachedDefault.height }
        return max(Tokens.Island.Layout.followUpHeight * 3, bounds.height - model.frames.notch.height + Tokens.Space.xs)
    }

    /// Where a card of `size` docks: centred under the notch, top edge on the screen's.
    private func dockTarget(for size: CGSize) -> CGRect {
        NotchGeometry.dockTargetRect(size: size, metrics: model.metrics, spec: Tokens.Island.Layout.layoutSpec,
                                     forceSoftware: model.forceSoftwareIsland)
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// The card follows the hand from here until the button comes up.
    private func beginDrag() {
        guard let detached, !drag.isDragging, model.phase == .quickAnswer(.detached) else { return }
        detached.level = DetachedPanel.draggingLevel
        drag.onMove = { [weak self] free in self?.dragMoved(free) ?? free }
        drag.onRelease = { [weak self] free, velocity in self?.dragEnded(free, velocity: velocity) }
        drag.beginDrag(detached)
    }

    /// One frame of the drag: update the dock zone and, once release would dock, lean the
    /// card toward the notch. `free` is the pointer-driven top-left corner.
    private func dragMoved(_ free: CGPoint) -> CGPoint {
        guard let detached, model.phase == .quickAnswer(.detached) else { return free }
        let spec = Tokens.Island.Layout.layoutSpec
        let size = detached.frame.size
        let topCenter = CGPoint(x: free.x + size.width / 2, y: free.y)
        var zone = NotchGeometry.dockZone(panelTopCenter: topCenter, current: model.state.dockZone,
                                          metrics: model.metrics, spec: spec)
        if !dockArmed {
            if zone == .outside { dockArmed = true } else { zone = .outside }
        }
        if zone != model.state.dockZone { model.send(.setDockZone(zone)) }
        guard zone == .ready, !reduceMotion else { return free }
        let target = dockTarget(for: size)
        return NotchGeometry.magnetized(free: free, target: CGPoint(x: target.minX, y: target.maxY),
                                        distance: NotchGeometry.dockDistance(from: topCenter, metrics: model.metrics),
                                        strength: Tokens.Motion.Dock.magnetism, spec: spec)
    }

    /// Release: dock when the thrown card would come to rest within reach of the notch.
    private func dragEnded(_ free: CGPoint, velocity: CGVector) {
        guard let detached, model.phase == .quickAnswer(.detached) else { return }
        let spec = Tokens.Island.Layout.layoutSpec
        let size = detached.frame.size
        let topCenter = CGPoint(x: free.x + size.width / 2, y: free.y)
        let rest = NotchGeometry.projectedPoint(from: topCenter, velocity: velocity,
                                                decelerationRate: spec.dockDecelerationRate)
        let zone = dockArmed ? NotchGeometry.dockZone(panelTopCenter: rest, current: model.state.dockZone,
                                                      metrics: model.metrics, spec: spec) : .outside
        dockArmed = true
        if zone == .ready {
            releaseVelocity = velocity
            model.send(.redock)
        } else {
            detached.level = .floating
            model.send(.setDockZone(.outside))
        }
    }

    /// The card's content changed size (the answer streamed); its top edge stays put.
    private func detachedContentSized(_ size: CGSize) {
        guard let detached else { return }
        drag.resize(detached, to: size)
    }

    private func dismissDetached() {
        guard let window = detached else { return }
        detached = nil
        drag.cancel()
        guard model.phase == .quickAnswer(.attached) else {
            window.orderOut(nil)
            return
        }
        // Docking: fly home under the notch and dissolve as the slab takes over.
        let velocity = releaseVelocity
        releaseVelocity = .zero
        window.level = DetachedPanel.draggingLevel
        drag.fly(window, to: dockTarget(for: window.frame.size), velocity: velocity,
                 duration: Tokens.Motion.Dock.flightDuration,
                 fadeStart: Tokens.Motion.Dock.fadeStart, fadeEnd: Tokens.Motion.Dock.fadeEnd,
                 reduceMotion: reduceMotion) {
            window.orderOut(nil)
        }
    }
}
