import SwiftUI
import AppKit

/// Editable text on the black surface: transparent NSTextView, white caret, no focus ring.
/// Return submits, Shift-Return inserts a line break, Escape goes to the island.
struct IslandTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 14)
    var placeholder: String? = nil
    var submitOnReturn = true
    var onSubmit: () -> Void = {}
    var onEscape: () -> Void = {}
    var onHeightChange: ((CGFloat) -> Void)? = nil
    /// When this changes to a new non-zero value, the view takes first responder.
    var focusToken: Int = 0
    var insets = NSSize(width: 0, height: 2)
    /// Guards the async focus grab: skip it if the phase moved on before it ran.
    var wantsFocus: () -> Bool = { true }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> TextHost {
        let host = TextHost()
        let tv = host.textView
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.usesFontPanel = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.focusRingType = .none
        tv.insertionPointColor = .white
        tv.textColor = .white
        tv.font = font
        tv.selectedTextAttributes = [.backgroundColor: NSColor.white.withAlphaComponent(0.28)]
        tv.textContainerInset = insets
        tv.textContainer?.lineFragmentPadding = 0
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.setAccessibilityLabel(placeholder ?? "Text")
        tv.string = text
        // A non-zero token at mount means focus was requested before the view existed.
        context.coordinator.lastToken = 0
        return host
    }

    func updateNSView(_ host: TextHost, context: Context) {
        context.coordinator.parent = self
        let tv = host.textView
        if tv.string != text { tv.string = text }
        if tv.font != font { tv.font = font }
        if focusToken != context.coordinator.lastToken {
            context.coordinator.lastToken = focusToken
            guard focusToken != 0 else { return }
            let wantsFocus = self.wantsFocus
            DispatchQueue.main.async {
                // The phase may have moved on before this ran; don't steal key back.
                guard wantsFocus(), let window = tv.window, tv.superview != nil else { return }
                // A non-activating panel only shows a caret while it is key.
                if !window.isKeyWindow { window.makeKey() }
                window.makeFirstResponder(tv)
                tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0))
            }
        }
        context.coordinator.reportHeight(tv)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: IslandTextView
        var lastToken = 0
        private var lastHeight: CGFloat = 0
        init(_ parent: IslandTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            reportHeight(tv)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                guard parent.submitOnReturn else { return false }
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            default:
                return false
            }
        }

        func reportHeight(_ tv: NSTextView) {
            guard let onHeightChange = parent.onHeightChange, let lm = tv.layoutManager, let tc = tv.textContainer else { return }
            lm.ensureLayout(for: tc)
            let h = ceil(lm.usedRect(for: tc).height + tv.textContainerInset.height * 2)
            guard abs(h - lastHeight) > 0.5 else { return }
            lastHeight = h
            DispatchQueue.main.async { onHeightChange(h) }
        }
    }

    /// Plain container that keeps the text view at its own width.
    final class TextHost: NSView {
        let textView = NSTextView()
        override init(frame: NSRect) {
            super.init(frame: frame)
            addSubview(textView)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layout() {
            super.layout()
            textView.frame = bounds
            textView.textContainer?.containerSize = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
        }
        override var acceptsFirstResponder: Bool { true }
        override func becomeFirstResponder() -> Bool { window?.makeFirstResponder(textView) ?? false }
    }
}
