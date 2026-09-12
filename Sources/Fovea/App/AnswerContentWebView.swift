import AppKit
import WebKit
final class AnswerContentWebView: WKWebView {
    override var mouseDownCanMoveWindow: Bool { false }

    /// Vertical scrolling belongs to the conversation, horizontal to the page.
    ///
    /// This view is laid out at the page's FULL content height and the page sets
    /// `overflow: hidden`, so it has nothing to scroll vertically — but WebKit
    /// still consumes the wheel event, and the answer body became a dead zone
    /// where two-finger scrolling did nothing. The whole event is handed to the
    /// enclosing scroll view instead, so phase and momentum stay intact and the
    /// gesture behaves exactly as it does beside the card.
    ///
    /// A predominantly horizontal gesture is left to the page, which is what
    /// scrolls a wide code block, table or formula sideways. Selection, links
    /// and every other interaction are untouched: only wheel events are routed.
    override func scrollWheel(with event: NSEvent) {
        let horizontal = abs(event.scrollingDeltaX)
        let vertical = abs(event.scrollingDeltaY)
        if horizontal > vertical {
            super.scrollWheel(with: event)
            return
        }
        // A gesture with no vertical component either (a rest/ended phase, say)
        // still belongs to whoever owns the vertical axis, so the container sees
        // the complete phase sequence rather than a truncated one.
        guard let container = enclosingScrollView else {
            super.scrollWheel(with: event)
            return
        }
        container.scrollWheel(with: event)
    }
    static func containsResponder(_ responder: NSResponder?) -> Bool {
        var view = responder as? NSView
        while let current = view {
            if current is AnswerContentWebView { return true }
            view = current.superview
        }
        return false
    }
}
