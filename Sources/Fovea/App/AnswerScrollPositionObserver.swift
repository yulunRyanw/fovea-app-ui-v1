import SwiftUI
import AppKit

/// Tracks explicit reader scrolling independently of content-height changes.
/// Streaming may follow the bottom until the reader scrolls up or selects text.
struct AnswerScrollPositionObserver: NSViewRepresentable {
    @Binding var following: Bool
    func makeNSView(context: Context) -> Tracker {
        let view = Tracker()
        view.changed = { following = $0 }
        return view
    }
    func updateNSView(_ view: Tracker, context: Context) { view.changed = { following = $0 } }
    static func dismantleNSView(_ view: Tracker, coordinator: ()) { view.stop() }

    final class Tracker: NSView {
        var changed: ((Bool) -> Void)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let scroll = self.enclosingScrollView,
                      event.window === self.window,
                      scroll.bounds.contains(scroll.convert(event.locationInWindow, from: nil)) else { return event }
                if event.scrollingDeltaY > 0 { self.changed?(false) }
                else if event.scrollingDeltaY < 0 {
                    DispatchQueue.main.async { [weak self, weak scroll] in
                        guard let self, let scroll, let document = scroll.documentView else { return }
                        if scroll.documentVisibleRect.maxY >= document.bounds.maxY - 40 { self.changed?(true) }
                    }
                }
                return event
            }
        }
        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
