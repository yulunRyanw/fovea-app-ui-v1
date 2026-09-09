import AppKit
import FoveaCore

/// Reports which zone the pointer is in, from real pointer motion measured against the
/// island's *target* geometry — never the animating shape, so the hover region cannot
/// trail an animation or go stale after an interrupted one.
///
/// Mouse monitors need no permission. The global one skips events over Fovea's own
/// windows, which the local one covers.
@MainActor
final class IslandPointerTracker {
    var zoneProvider: (CGPoint) -> PointerZone = { _ in .outside }
    var onZoneChange: (PointerZone) -> Void = { _ in }
    private(set) var zone: PointerZone = .outside

    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return event
        }) { monitors.append(local) }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }

    /// Real motion: any zone change counts, including entering the notch.
    private func pointerMoved() {
        let next = zoneProvider(NSEvent.mouseLocation)
        guard next != zone else { return }
        zone = next
        onZoneChange(next)
    }

    /// The geometry changed under a still pointer. Only a downgrade counts (the island
    /// shrank away from the pointer); growing under a parked pointer never "enters".
    /// `.outside` is reported again even when unchanged, so a rest can re-arm the hover.
    func reevaluate() {
        let next = zoneProvider(NSEvent.mouseLocation)
        if rank(next) < rank(zone) {
            zone = next
            onZoneChange(next)
        } else if next == .outside, zone == .outside {
            onZoneChange(.outside)
        }
    }

    private func rank(_ z: PointerZone) -> Int {
        switch z {
        case .outside: return 0
        case .near: return 1
        case .inside: return 2
        }
    }
}
