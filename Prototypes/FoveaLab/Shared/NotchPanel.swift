// Copied from Sources/Fovea/Platform/NotchPanel.swift for the lab. The lab may drift from the shipping file.

import AppKit
import SwiftUI

// The transparent, always-on-top window the Island draws in. Patterns from
// DynamicNotchKit, NotchDrop, OpenDictation and opennook (all MIT):
//  • .nonactivatingPanel + canBecomeKey: the island can host a text field without
//    activating Fovea, so the frontmost app keeps its menu bar and active title bar.
//  • becomesKeyOnlyIfNeeded: a click makes it key only when it lands on a text view.
//  • level = statusBar + 8: above the menu bar, below .screenSaver (which breaks drags).
//  • The window is created oversized and never resized; only the SwiftUI content moves.

final class NotchPanel: NSPanel {
    static let islandLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
    static let islandBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

    /// Called for key presses that no text view consumed. Return true to swallow.
    var onKeyDown: ((NSEvent) -> Bool)?
    /// Called when the panel gains or loses key status.
    var onKeyChange: ((Bool) -> Void)?
    /// How often the panel left the screen; the motion eval asserts it never does mid-animation.
    private(set) var orderOutCount = 0

    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)
        setAccessibilityIdentifier("fovea.island")
        reassert()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// macOS occasionally demotes panels after sleep or a Space switch; re-apply on show.
    func reassert() {
        level = Self.islandLevel
        collectionBehavior = Self.islandBehavior
    }

    override func orderOut(_ sender: Any?) {
        orderOutCount += 1
        super.orderOut(sender)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    override func becomeKey() {
        super.becomeKey()
        onKeyChange?(true)
    }

    override func resignKey() {
        super.resignKey()
        onKeyChange?(false)
    }
}

/// Hosting view that only exists where the island is drawn: everywhere else in the
/// oversized transparent window, clicks fall through to the desktop and menu bar.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    /// The island's target bounds in SwiftUI (top-down) coordinates of this view.
    var hitRegion: () -> CGRect? = { nil }
    /// The island's outline inside that rect, so clicks beside the ears fall through too.
    var hitPath: () -> Path? = { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let region = hitRegion() else { return nil }
        // AppKit y is up; SwiftUI global space is top-down.
        let flippedPoint = CGPoint(x: point.x, y: bounds.height - point.y)
        guard region.contains(flippedPoint) else { return nil }
        if let path = hitPath(), !path.contains(flippedPoint) { return nil }
        return super.hitTest(point)
    }

    /// The panel is rarely key; the first click on a button must still be the click.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Floating panel for a detached Quick Answer. Same key behavior as the notch panel,
/// with a shadow since it is a card rather than part of the top edge. AppKit never moves
/// it: `DetachedDragEngine` places it from the pointer, so it can lean toward the notch.
final class DetachedPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onKeyChange: ((Bool) -> Void)?
    /// While dragged or flying home the card rises above the menu bar, still under the island.
    static let draggingLevel = NSWindow.Level(rawValue: NotchPanel.islandLevel.rawValue - 1)

    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)
        setAccessibilityIdentifier("fovea.quick-answer")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit would keep the card below the menu bar when it is ordered on screen; it has
    /// to sit exactly where the slab was, top edge on the top of the screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    override func becomeKey() {
        super.becomeKey()
        onKeyChange?(true)
    }

    override func resignKey() {
        super.resignKey()
        onKeyChange?(false)
    }
}

/// Hosting view of the floating card. The panel is rarely key, so the first click on it
/// must be the click; it takes no part in sizing (the controller sizes the window from
/// the card's reported size, top edge fixed).
final class DetachedHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
