import AppKit
import FoveaCore

/// Which display the Island lives on and when displays change. The island follows the
/// pointer, so it appears on the display the user is working on.
@MainActor
final class ScreenObserver {
    /// Fired when displays are added, removed or resized (not for no-op notifications),
    /// and after wake / Space changes so the panel can re-assert itself.
    var onDisplaysChanged: (() -> Void)?
    var onNeedsReassert: (() -> Void)?

    private var signature: [String] = ScreenObserver.currentSignature()
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onNeedsReassert?() }
            })
        }
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    private func screenParametersChanged() {
        if ProcessInfo.processInfo.environment["FOVEA_ISLAND_LOG"] != nil { print("island: screen parameters changed") }
        let now = Self.currentSignature()
        guard now != signature else { onNeedsReassert?(); return }
        signature = now
        onDisplaysChanged?()
    }

    /// Display identity + frame, so a spurious notification does not rebuild the panel.
    private static func currentSignature() -> [String] {
        NSScreen.screens.map { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "?"
            return "\(id):\(NSStringFromRect(screen.frame)):\(NSStringFromRect(screen.visibleFrame))"
        }
    }

    // MARK: - Screen choice

    /// The display containing the pointer; falls back to the main display.
    /// `FOVEA_ISLAND_SCREEN` pins the island to one display instead (see
    /// `pinnedScreen`), for recordings on a clean external monitor.
    static var screenWithPointer: NSScreen? {
        if let pinned = pinnedScreen { return pinned }
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// `FOVEA_ISLAND_SCREEN=external`: the first display without a camera
    /// housing that is not the primary one; a number: the display at that
    /// index in `NSScreen.screens`. Unset or unmatched: nil (follow the pointer).
    static var pinnedScreen: NSScreen? {
        guard let value = ProcessInfo.processInfo.environment["FOVEA_ISLAND_SCREEN"], !value.isEmpty else { return nil }
        let screens = NSScreen.screens
        if value == "external" {
            return screens.first { $0.safeAreaInsets.top == 0 && $0 !== screens.first } ?? screens.last
        }
        if let index = Int(value), screens.indices.contains(index) { return screens[index] }
        return nil
    }

    static func metrics(for screen: NSScreen) -> ScreenMetrics {
        ScreenMetrics(frame: screen.frame,
                      visibleFrame: screen.visibleFrame,
                      safeAreaTop: screen.safeAreaInsets.top,
                      auxLeftWidth: screen.auxiliaryTopLeftArea?.width ?? 0,
                      auxRightWidth: screen.auxiliaryTopRightArea?.width ?? 0)
    }

    static func screen(matching metrics: ScreenMetrics) -> NSScreen? {
        NSScreen.screens.first { $0.frame == metrics.frame }
    }
}
