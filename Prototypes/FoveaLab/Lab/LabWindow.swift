import SwiftUI
import AppKit
import FoveaCore

/// The lab's main window: the shipping window's size and chrome, owned by AppKit so it can
/// be placed under the notch and animated. Hosts the lab hotkeys.
@MainActor
final class LabWindowController {
    let window: NSWindow
    let state: LabState
    private var keyMonitor: Any?

    init(state: LabState) {
        self.state = state
        let size = Tokens.Layout.window
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "Fovea Lab"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = state.canvas.nsColor
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: LabRootView().environment(state))
        // The content is a fixed 980×680; without this the hosting view would forbid the
        // narrow frame the window opens from.
        hosting.sizingOptions = []
        window.contentView = hosting
        window.minSize = NSSize(width: 120, height: 28)
        installHotkeys()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    /// ⌘1–⌘4 direction, ⌘⇧L palette, ⌘K search, ⌘+ ⌘- Studio zoom, ⌘[ ⌘] Spaces, Esc closes.
    private func installHotkeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window || event.window == nil else { return event }
            let cmd = event.modifierFlags.contains(.command)
            let shift = event.modifierFlags.contains(.shift)
            let chars = event.charactersIgnoringModifiers ?? ""
            if event.keyCode == 53 {                       // Esc
                if state.openId != nil { state.openId = nil; return nil }
                if state.searchVisible { state.searchVisible = false; state.searchQuery = ""; return nil }
                return event
            }
            guard cmd else { return event }
            switch (chars, shift) {
            case ("1", false): state.direction = .paper; return nil
            case ("2", false): state.direction = .studio; return nil
            case ("3", false): state.direction = .spaces; return nil
            case ("4", false): state.direction = .threads; return nil
            case ("l", true), ("L", true): state.paletteVisible.toggle(); return nil
            case ("k", false): state.searchVisible.toggle(); if !state.searchVisible { state.searchQuery = "" }; return nil
            case ("=", false), ("+", _): state.studioZoom = min(2, state.studioZoom + 1); return nil
            case ("-", false): state.studioZoom = max(0, state.studioZoom - 1); return nil
            case ("[", false): state.selectSpace(offset: -1); return nil
            case ("]", false): state.selectSpace(offset: 1); return nil
            default: return event
            }
        }
    }
}
