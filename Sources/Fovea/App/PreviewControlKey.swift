import AppKit

/// Preview-only local observation. A clean left-Control tap fires on release;
/// chords, pointer gestures, inactive windows and other Control keys do not.
@MainActor final class PreviewControlKey {
    private var monitor: Any?
    private var armed = false
    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.observe(event)
            }
            return event
        }
    }
    private func observe(_ event: NSEvent) {
        guard NSApp.isActive, NSApp.keyWindow?.attachedSheet == nil else { armed = false; return }
        if event.type != .flagsChanged { armed = false; return }
        guard event.keyCode == 59 else { armed = false; return }
        if event.modifierFlags.contains(.control) {
            armed = event.modifierFlags.intersection([.command, .option, .shift]).isEmpty
                && NSEvent.pressedMouseButtons == 0
        } else {
            let trigger = armed; armed = false
            if trigger { ReadingPreviewState.shared.activateControlKey() }
        }
    }
    func reset() { armed = false }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; armed = false }
}
