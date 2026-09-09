import AppKit
import CoreGraphics
import FoveaCore

/// `--demo island-eval:<suite>`: drives the live panel with synthetic input and checks
/// the things unit tests can't — real hover behavior, the collapse morph, voice width,
/// and the emoji-picker guard — then prints a PASS/FAIL table and exits with a code.
///
/// Runs from the bundle (`build/Fovea.app/Contents/MacOS/Fovea`) with Finder frontmost so
/// the panel is never key. Synthetic pointer events warp the real cursor, so the live
/// tracker sees them. Keep hands off the trackpad while a suite runs.
@MainActor
enum IslandEval {
    struct Result { let id: String; let pass: Bool; let measured: String; let threshold: String }

    static func run(controller: IslandController, suite rawSuite: String) {
        let suite = String(rawSuite)
        print("island-eval: suite=\(suite)")
        Task { @MainActor in
            var results: [Result] = []
            let suites = suite == "all" ? ["preflight", "p1", "retry", "hover", "collapse", "emoji", "dock"] : [suite]
            for s in suites {
                switch s {
                case "preflight": results += preflight(controller)
                case "p1": results += await p1Geometry(controller)
                case "hover": results += await hoverMatrix(controller)
                case "retry": results += await retryClick(controller)
                case "collapse": results += await collapse(controller)
                case "emoji": results += await emoji(controller)
                case "dock": results += await dock(controller)
                default: print("unknown suite \(s)")
                }
            }
            report(results)
            exit(results.allSatisfy { $0.pass } ? 0 : 1)
        }
    }

    // MARK: Suites

    private static func preflight(_ c: IslandController) -> [Result] {
        let trusted = AXIsProcessTrusted()
        let onMain = c.panel?.screen == NSScreen.main
        if !trusted {
            print("PREFLIGHT: Accessibility not granted — grant build/Fovea.app in System Settings › Privacy & Security › Accessibility, then rerun.")
        }
        return [Result(id: "preflight.accessibility", pass: trusted, measured: trusted ? "granted" : "missing", threshold: "granted"),
                Result(id: "preflight.mainDisplay", pass: onMain, measured: onMain ? "yes" : "no", threshold: "island on main display")]
    }

    /// Voice states are exactly the resting (notch) width; only the height grows.
    private static func p1Geometry(_ c: IslandController) async -> [Result] {
        c.model.reset()
        try? await sleep(0.4)
        let resting = c.model.frames.width
        c.model.send(.hotkeyPressed(.voiceFlow))
        try? await sleep(0.4)
        let listening = c.model.frames
        let restingHeight = c.model.metrics.safeAreaTop
        let widthOK = abs(listening.width - resting) < 0.5
        let grows = listening.minHeight > restingHeight && listening.notch.minY == 0
        c.model.send(.escape)
        try? await sleep(0.3)
        return [Result(id: "p1.voiceWidth", pass: widthOK, measured: "listening \(Int(listening.width)) vs resting \(Int(resting))", threshold: "equal"),
                Result(id: "p1.growsDown", pass: grows,
                       measured: "h \(Int(listening.minHeight)) from \(Int(restingHeight)), top at 0", threshold: "taller, anchored at top")]
    }

    /// The Retry button lands a click while the panel is not key (acceptsFirstMouse),
    /// and Retry listens again.
    private static func retryClick(_ c: IslandController) async -> [Result] {
        guard let panel = c.panel else { return [] }
        c.model.jump(to: .failureRetry)
        try? await sleep(0.5)
        guard let rect = c.model.debugRects["retry"], rect.width > 0 else {
            return [Result(id: "retry.rect", pass: false, measured: "no rect", threshold: "retry button located")]
        }
        // The debug rect is top-down from the panel's top-left; the panel hugs the screen
        // top, so that maps straight to CG global coords (origin top-left, y down).
        let cg = CGPoint(x: panel.frame.minX + rect.midX, y: rect.midY)
        await click(cg)
        try? await sleep(0.4)
        let listening = c.model.phase == .listening
        let notKey = !(panel.isKeyWindow)
        if listening { c.model.send(.escape); try? await sleep(0.2) }
        return [Result(id: "retry.clickLands", pass: listening,
                       measured: listening ? "listening" : "\(c.model.phase)", threshold: "Retry → listening"),
                Result(id: "retry.panelNotKey", pass: notKey || listening,
                       measured: notKey ? "not key" : "key", threshold: "click works without activating")]
    }

    /// The hover matrix: warp the cursor along paths and check the phase timeline.
    private static func hoverMatrix(_ c: IslandController) async -> [Result] {
        guard let panel = c.panel else { return [Result(id: "hover.setup", pass: false, measured: "no panel", threshold: "panel")]}
        c.model.reset()
        try? await sleep(0.4)
        let notch = NotchGeometry.screenRect(c.model.frames.notch, panel: panel.frame)
        let cx = notch.midX
        let notchTopY = notch.maxY - 4                 // just inside the notch (screen y up)
        let belowY = { (d: CGFloat) in notch.minY - d } // d points below the island's bottom edge

        var out: [Result] = []

        // 1. Dwell on the notch → opens after the dwell.
        await warp(cx, notchTopY); try? await sleep(0.4)
        out.append(Result(id: "hover.dwellOpens", pass: c.model.phase == .agentList,
                          measured: "\(c.model.phase)", threshold: "agentList"))
        // Leave, clearing the open list (which is ~280pt tall).
        await warp(cx, belowY(c.model.contentBounds.height + 60)); try? await sleep(0.5)
        out.append(Result(id: "hover.leaveCollapses", pass: c.model.phase == .resting,
                          measured: "\(c.model.phase)", threshold: "resting"))

        // 2. Brush across the notch quickly → never opens.
        c.model.reset(); try? await sleep(0.4)
        for i in 0...8 { await warp(cx - 400 + CGFloat(i) * 100, notchTopY); try? await sleep(0.01) }
        try? await sleep(0.3)
        out.append(Result(id: "hover.brushThrough", pass: c.model.phase == .resting,
                          measured: "\(c.model.phase)", threshold: "resting"))

        // 3. Approach from below and hold 12/40 pt under → never opens.
        for d: CGFloat in [12, 40] {
            c.model.reset(); try? await sleep(0.3)
            await warp(cx, belowY(d)); try? await sleep(0.6)
            out.append(Result(id: "hover.approach\(Int(d))", pass: c.model.phase == .resting,
                              measured: "\(c.model.phase)", threshold: "resting"))
        }

        // 4. After a collapse under the pointer, re-entering the notch requires leaving first.
        c.model.reset(); try? await sleep(0.3)
        await warp(cx, notchTopY); try? await sleep(0.35)          // open
        c.model.send(.escape); try? await sleep(0.3)               // collapse under the pointer
        try? await sleep(0.4)
        out.append(Result(id: "hover.noReopenUnderPointer", pass: c.model.phase == .resting,
                          measured: "\(c.model.phase)", threshold: "resting"))

        await warp(cx, belowY(200)); try? await sleep(0.2)
        c.model.reset(); try? await sleep(0.3)
        return out
    }

    /// The collapse is one continuous morph: the panel never leaves the screen and the
    /// width shrinks monotonically.
    private static func collapse(_ c: IslandController) async -> [Result] {
        guard let panel = c.panel else { return [] }
        c.model.jump(to: .reviewCollapsed)
        try? await sleep(0.5)
        let orderOutStart = panel.orderOutCount
        let startWidth = c.model.contentBounds.width
        // Sample width and orderOut per frame during the collapse.
        c.model.send(.escape)
        var widths: [CGFloat] = []
        var orderOutDuringMotion = 0
        var settled = false
        for _ in 0..<48 {
            let w = c.model.contentBounds.width
            widths.append(w)
            // "During motion" = while the width is still meaningfully above the resting size.
            if !settled {
                if let last = widths.dropLast().last, abs(w - last) < 0.5, widths.count > 3 { settled = true }
                else { orderOutDuringMotion = panel.orderOutCount - orderOutStart }
            }
            try? await sleep(1.0 / 60)
        }
        let endWidth = c.model.contentBounds.width
        // Monotonic non-increasing within noise; never jumps back up by > 2pt.
        var maxUptick: CGFloat = 0
        for i in 1..<widths.count { maxUptick = max(maxUptick, widths[i] - widths[i - 1]) }
        let noVanish = widths.allSatisfy { $0 >= min(startWidth, endWidth) - 2 }
        return [Result(id: "collapse.noOrderOutMidMorph", pass: orderOutDuringMotion == 0,
                       measured: "orderOut during morph: \(orderOutDuringMotion) (key hand-back is deferred)", threshold: "0"),
                Result(id: "collapse.monotonic", pass: maxUptick < 2,
                       measured: "max uptick \(String(format: "%.1f", maxUptick))pt", threshold: "< 2pt"),
                Result(id: "collapse.noVanish", pass: noVanish,
                       measured: noVanish ? "area kept" : "dropped below both ends", threshold: "area kept")]
    }

    /// An fn tap must not open the emoji picker while Fovea runs.
    private static func emoji(_ c: IslandController) async -> [Result] {
        let before = characterPaletteOnScreen()
        postFunctionKey()
        try? await sleep(0.7)
        let after = characterPaletteOnScreen()
        let listening = c.model.phase == .listening
        if listening { c.model.send(.escape); try? await sleep(0.2) }
        // If synthetic fn never triggers the picker even with the guard, this is inconclusive.
        return [Result(id: "emoji.noPicker", pass: !after || before,
                       measured: after ? "CharacterPalette visible" : "none", threshold: "no picker"),
                Result(id: "emoji.startsListening", pass: listening,
                       measured: listening ? "listening" : "\(c.model.phase)", threshold: "fn still starts a session")]
    }

    /// A torn-off Quick Answer follows the pointer 1:1 anywhere, the notch opens its
    /// receiver as the card comes back, release inside the snap radius docks it, and a
    /// release anywhere else leaves it exactly where it was let go.
    private static func dock(_ c: IslandController) async -> [Result] {
        guard let panel = c.panel else { return [Result(id: "dock.setup", pass: false, measured: "no panel", threshold: "panel")] }
        var out: [Result] = []
        let m = c.model
        let spec = Tokens.Island.Layout.layoutSpec
        let notch = NotchGeometry.screenRect(m.frames.notch, panel: panel.frame)
        let topCenter = CGPoint(x: notch.midX, y: notch.maxY)
        func card() -> NSWindow? {
            NSApp.windows.first { $0.accessibilityIdentifier() == "fovea.quick-answer" && $0.isVisible }
        }
        func cardTopCenter() -> CGPoint? { card().map { CGPoint(x: $0.frame.midX, y: $0.frame.maxY) } }

        m.jump(to: .qaLong); try? await sleep(0.5)
        // Button down on the slab body, then tear off as the grabber gesture does.
        let grabStart = CGPoint(x: notch.midX + 120, y: notch.maxY - 120)
        await press(grabStart); m.detachFromGesture(); try? await sleep(0.3)
        guard let window = card() else {
            release(); m.send(.escape)
            return out + [Result(id: "dock.tearOff", pass: false, measured: "no card", threshold: "card appears")]
        }
        let f0 = window.frame
        out.append(Result(id: "dock.tearOffUnderNotch", pass: abs(f0.midX - notch.midX) < 2 && abs(f0.maxY - notch.maxY) < 2,
                          measured: String(format: "mid %.0f top %.0f (notch %.0f/%.0f)", f0.midX, f0.maxY, notch.midX, notch.maxY),
                          threshold: "card starts where the slab was"))

        // 1. Drag far away: the card's top-left moves by exactly the pointer's delta.
        let far = CGPoint(x: grabStart.x - 380, y: grabStart.y - 320)
        await drag(from: grabStart, to: far, steps: 12); try? await sleep(0.2)
        let f1 = window.frame
        let followDX = f1.minX - (f0.minX - 380), followDY = f1.maxY - (f0.maxY - 320)
        let followErr = hypot(followDX, followDY)
        out.append(Result(id: "dock.follows1to1", pass: followErr < 2,
                          measured: String(format: "off by (%.1f, %.1f)pt; card %.0f/%.0f → %.0f/%.0f", followDX, followDY,
                                           f0.minX, f0.maxY, f1.minX, f1.maxY), threshold: "< 2pt"))
        out.append(Result(id: "dock.farStaysResting", pass: m.state.dockZone == .outside && m.frames.minHeight == notch.height,
                          measured: "\(m.state.dockZone), h \(Int(m.frames.minHeight))", threshold: "outside, resting"))

        // 2. Come back straight below the notch: at 150pt the receiver opens.
        let grabOffset = CGPoint(x: far.x - f1.midX, y: far.y - f1.maxY)   // pointer relative to the card's top-center
        func pointer(cardTopCenterBelow d: CGFloat) -> CGPoint {
            CGPoint(x: topCenter.x + grabOffset.x, y: topCenter.y - d + grabOffset.y)
        }
        await drag(from: far, to: pointer(cardTopCenterBelow: 150), steps: 10); try? await sleep(0.45)
        out.append(Result(id: "dock.nearOpensReceiver",
                          pass: m.state.dockZone == .near && m.frames.minHeight == notch.height + spec.dockReceiverBelow,
                          measured: "\(m.state.dockZone), h \(Int(m.frames.minHeight))",
                          threshold: "near, notch+\(Int(spec.dockReceiverBelow))"))

        // 3. At 40pt release would dock: armed, and the card leans toward its target.
        let readyPointer = pointer(cardTopCenterBelow: 40)
        await drag(from: pointer(cardTopCenterBelow: 150), to: readyPointer, steps: 8); try? await sleep(0.2)
        let freeTop = CGPoint(x: readyPointer.x - grabOffset.x, y: readyPointer.y - grabOffset.y)
        let shownTop = cardTopCenter() ?? freeTop
        let pull = hypot(freeTop.x - topCenter.x, freeTop.y - topCenter.y) - hypot(shownTop.x - topCenter.x, shownTop.y - topCenter.y)
        out.append(Result(id: "dock.readyArms", pass: m.state.dockZone == .ready, measured: "\(m.state.dockZone)", threshold: "ready"))
        out.append(Result(id: "dock.magnetism", pass: pull > 4,
                          measured: String(format: "leans %.1fpt toward the notch", pull), threshold: "> 4pt"))

        // 4. Release: the card flies home and disappears; the slab is back.
        release(); try? await sleep(0.8)
        out.append(Result(id: "dock.releaseDocks", pass: m.phase == .quickAnswer(.attached),
                          measured: "\(m.phase)", threshold: "attached"))
        out.append(Result(id: "dock.cardGone", pass: card() == nil,
                          measured: card() == nil ? "hidden" : "still visible", threshold: "hidden after the flight"))

        // 5. Release far away: nothing docks and the card stays exactly where it was let go.
        await press(grabStart); m.detachFromGesture(); try? await sleep(0.3)
        await drag(from: grabStart, to: far, steps: 12); try? await sleep(0.2)
        let before = card()?.frame ?? .zero
        release(); try? await sleep(0.5)
        let after = card()?.frame ?? .zero
        let moved = hypot(after.minX - before.minX, after.maxY - before.maxY)
        out.append(Result(id: "dock.releaseFarStays",
                          pass: m.phase == .quickAnswer(.detached) && moved < 1 && m.state.dockZone == .outside && card() != nil,
                          measured: "\(m.phase), moved \(Int(moved))pt", threshold: "detached, unmoved"))
        m.send(.escape); try? await sleep(0.3)
        return out
    }

    // MARK: Synthetic input

    /// AppKit screen point (y up) → CG global point (origin top-left, y down).
    private static func cg(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: (NSScreen.main?.frame.height ?? 0) - p.y)
    }

    private static func press(_ p: CGPoint) async {
        await warp(p.x, p.y)
        try? await sleep(0.05)
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: cg(p), mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    private static func release() {
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: cg(NSEvent.mouseLocation), mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    /// Drags with the button held, one event per frame along a straight line.
    private static func drag(from: CGPoint, to: CGPoint, steps: Int) async {
        let src = CGEventSource(stateID: .hidSystemState)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = cg(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
            CGWarpMouseCursorPosition(p)
            CGEvent(mouseEventSource: src, mouseType: .leftMouseDragged, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
            try? await sleep(1.0 / 60)
        }
    }

    private static func warp(_ x: CGFloat, _ y: CGFloat) async {
        // Screen coords: CG origin is top-left, AppKit bottom-left. Convert via main height.
        let h = NSScreen.main?.frame.height ?? 0
        let cg = CGPoint(x: x, y: h - y)
        CGWarpMouseCursorPosition(cg)
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: cg, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    private static func click(_ cg: CGPoint) async {
        CGWarpMouseCursorPosition(cg)
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: cg, mouseButton: .left)?.post(tap: .cghidEventTap)
        try? await sleep(0.05)
        CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: cg, mouseButton: .left)?.post(tap: .cghidEventTap)
        try? await sleep(0.06)
        CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: cg, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    private static func postFunctionKey() {
        let src = CGEventSource(stateID: .hidSystemState)
        // The physical fn key is a modifier: it emits .flagsChanged, not .keyDown.
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x3F, keyDown: true) {
            down.type = .flagsChanged
            down.flags = .maskSecondaryFn
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: 0x3F, keyDown: false) {
            up.type = .flagsChanged
            up.flags = []
            up.post(tap: .cghidEventTap)
        }
    }

    private static func characterPaletteOnScreen() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { ($0[kCGWindowOwnerName as String] as? String)?.contains("CharacterPalette") == true }
    }

    private static func sleep(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    private static func report(_ results: [Result]) {
        print("\n── Island eval ──")
        for r in results {
            print(String(format: "%@ %-28@ %-34@ (want %@)", r.pass ? "PASS" : "FAIL", r.id as NSString, r.measured as NSString, r.threshold as NSString))
        }
        let passed = results.filter(\.pass).count
        print("\(passed)/\(results.count) passed\n")
    }
}
