// Copied from Sources/Fovea/Island/DetachedDragEngine.swift for the lab. The lab may drift from the shipping file.

import AppKit
import QuartzCore
import FoveaCore

/// Moves the detached Quick Answer panel by hand and flies it home.
///
/// The pointer is polled on a display link (`NSEvent.mouseLocation` needs neither an event
/// nor a permission), so the panel follows the hand at the display's refresh rate even
/// after the grabber that started the drag has been torn down with the slab. Mouse
/// monitors only shorten the latency between a movement and the next frame. Nothing here
/// uses `performDrag(with:)` or `NSApp.currentEvent`.
@MainActor
final class DetachedDragEngine: NSObject {
    /// Free (pointer-driven) top-left corner → where to draw the panel this frame.
    var onMove: ((CGPoint) -> CGPoint)?
    /// The button came up: free top-left corner and the release velocity, points per second.
    var onRelease: ((CGPoint, CGVector) -> Void)?

    private(set) var isDragging = false
    private(set) var isFlying = false

    private weak var window: NSWindow?
    private var link: CADisplayLink?
    private var monitors: [Any] = []
    /// Pointer offset from the panel's top-left corner, so growth never moves the top edge.
    private var grab = CGPoint.zero
    private var samples: [(time: TimeInterval, point: CGPoint)] = []
    private var flight: Flight?
    private var fade: Fade?
    /// How far back the release velocity looks.
    private let velocityWindow: TimeInterval
    /// Reduce Motion: no travel, just this much fade.
    private let fadeInPlaceDuration: CGFloat = 0.12

    private struct Flight {
        let spring: CriticallyDampedSpring
        let start: CGPoint
        let target: CGPoint
        let velocity: CGVector
        let startTime: TimeInterval
        let distance: CGFloat
        let fadeStart: CGFloat
        let fadeEnd: CGFloat
        let completion: () -> Void
    }

    /// Reduce Motion, or nothing to travel: the card dissolves where it is.
    private struct Fade {
        let startTime: TimeInterval
        let duration: CGFloat
        let completion: () -> Void
    }

    init(velocityWindow: TimeInterval) {
        self.velocityWindow = velocityWindow
        super.init()
    }

    // MARK: - Drag

    /// Starts following the pointer with `window`; the button is already down.
    func beginDrag(_ window: NSWindow) {
        cancel()
        self.window = window
        let mouse = NSEvent.mouseLocation
        grab = CGPoint(x: mouse.x - window.frame.minX, y: window.frame.maxY - mouse.y)
        samples = [(CACurrentMediaTime(), freeTopLeft(mouse))]
        isDragging = true
        startLink(on: window)
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerEvent(up: event.type == .leftMouseUp) }
            return event
        }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerEvent(up: true) }
        }) { monitors.append(global) }
    }

    private func freeTopLeft(_ mouse: CGPoint) -> CGPoint {
        CGPoint(x: mouse.x - grab.x, y: mouse.y + grab.y)
    }

    private func pointerEvent(up: Bool) {
        guard isDragging else { return }
        if up { endDrag() } else { track() }
    }

    /// One frame of dragging: read the pointer, remember it for the velocity, place the panel.
    private func track() {
        guard isDragging, let window else { return }
        if NSEvent.pressedMouseButtons & 1 == 0 { endDrag(); return }
        let free = freeTopLeft(NSEvent.mouseLocation)
        let now = CACurrentMediaTime()
        samples.append((now, free))
        samples.removeAll { now - $0.time > velocityWindow * 2 }
        place(window, topLeft: onMove?(free) ?? free)
    }

    private func endDrag() {
        guard isDragging else { return }
        isDragging = false
        stopLink()
        removeMonitors()
        let free = freeTopLeft(NSEvent.mouseLocation)
        let now = CACurrentMediaTime()
        var velocity = CGVector.zero
        if let first = samples.first(where: { now - $0.time <= velocityWindow }), now - first.time > 0.004 {
            let dt = now - first.time
            velocity = CGVector(dx: (free.x - first.point.x) / dt, dy: (free.y - first.point.y) / dt)
        }
        samples.removeAll()
        onRelease?(free, velocity)
    }

    /// Re-anchors the panel at its top-left corner after its content changed size.
    func resize(_ window: NSWindow, to size: CGSize) {
        let frame = window.frame
        guard abs(frame.width - size.width) > 0.5 || abs(frame.height - size.height) > 0.5 else { return }
        window.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height),
                        display: true)
    }

    private func place(_ window: NSWindow, topLeft: CGPoint) {
        let size = window.frame.size
        let origin = NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        if origin != window.frame.origin { window.setFrameOrigin(origin) }
    }

    // MARK: - Flight home

    /// Springs the panel's top-left corner to `target`'s, seeded with the release velocity,
    /// fading it out over the last part of the way; then `completion` (the caller hides it).
    func fly(_ window: NSWindow, to target: CGRect, velocity: CGVector, duration: CGFloat,
             fadeStart: CGFloat, fadeEnd: CGFloat, reduceMotion: Bool, completion: @escaping () -> Void) {
        cancel()
        self.window = window
        let start = CGPoint(x: window.frame.minX, y: window.frame.maxY)
        let end = CGPoint(x: target.minX, y: target.maxY)
        let distance = hypot(end.x - start.x, end.y - start.y)
        if reduceMotion || distance < 2 {
            fade = Fade(startTime: CACurrentMediaTime(), duration: fadeInPlaceDuration, completion: completion)
            isFlying = true
            startLink(on: window)
            stepFade()
            return
        }
        let spring = CriticallyDampedSpring(duration: duration)
        let seeded = CGVector(dx: spring.clampedVelocity(velocity.dx, from: start.x, to: end.x),
                              dy: spring.clampedVelocity(velocity.dy, from: start.y, to: end.y))
        flight = Flight(spring: spring, start: start, target: end, velocity: seeded, startTime: CACurrentMediaTime(),
                        distance: distance, fadeStart: fadeStart, fadeEnd: fadeEnd, completion: completion)
        isFlying = true
        startLink(on: window)
        stepFlight()
    }

    private func stepFlight() {
        guard isFlying, let flight, let window else { return }
        let t = CGFloat(CACurrentMediaTime() - flight.startTime)
        let x = flight.spring.position(at: t, from: flight.start.x, to: flight.target.x, velocity: flight.velocity.dx)
        let y = flight.spring.position(at: t, from: flight.start.y, to: flight.target.y, velocity: flight.velocity.dy)
        place(window, topLeft: CGPoint(x: x, y: y))
        let remaining = hypot(flight.target.x - x, flight.target.y - y) / flight.distance
        let alpha = min(1, max(0, (remaining - flight.fadeEnd) / (flight.fadeStart - flight.fadeEnd)))
        window.alphaValue = alpha
        if alpha <= 0 || t > flight.spring.duration * 1.5 { finishFlight() }
    }

    private func stepFade() {
        guard isFlying, let fade, let window else { return }
        let t = CGFloat(CACurrentMediaTime() - fade.startTime)
        window.alphaValue = max(0, 1 - t / fade.duration)
        if t >= fade.duration { finishFlight() }
    }

    private func finishFlight() {
        let completion = flight?.completion ?? fade?.completion
        flight = nil
        fade = nil
        isFlying = false
        stopLink()
        completion?()
    }

    /// Stops whatever is in flight. A flight completes immediately so its window is hidden.
    func cancel() {
        removeMonitors()
        stopLink()
        isDragging = false
        samples.removeAll()
        if isFlying { finishFlight() }
    }

    // MARK: - Display link

    private func startLink(on window: NSWindow) {
        stopLink()
        guard let link = (window.screen ?? NSScreen.main)?.displayLink(target: self, selector: #selector(step)) else { return }
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    private func removeMonitors() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }

    @objc private func step(_ link: CADisplayLink) {
        if isDragging { track() } else if flight != nil { stepFlight() } else if fade != nil { stepFade() }
    }
}
