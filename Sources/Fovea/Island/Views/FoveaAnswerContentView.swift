import SwiftUI
import WebKit
import FoveaCore

/// The product's answer renderer (fovea-mac `AnswerContentView`), hosted for the rehearsal:
/// the same `AnswerContent/` page (Markdown, tables, code, KaTeX, dark palette) in a
/// WKWebView that reports its height. Trimmed to what the rehearsal needs — one message,
/// a growing revision while the answer streams, no selection plumbing.
struct FoveaAnswerContentView: View {
    let messageID: String
    let markdown: String
    let streaming: Bool
    var fontSize: Double = 13.5
    var foreground = "#F2F2F2"
    @State private var height: CGFloat = 1
    @State private var ready = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            FoveaAnswerContentRepresentable(
                messageID: messageID, markdown: markdown, streaming: streaming, fontSize: fontSize, foreground: foreground,
                onHeight: { value in if height != value { height = value } },
                onReady: { ready = true })
                .frame(height: max(1, height))
            if !ready {
                // The page is still loading: the product shows the plain text meanwhile.
                Text(markdown)
                    .font(.system(size: fontSize))
                    .foregroundStyle(Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private final class FoveaAnswerWebView: WKWebView {
    override var mouseDownCanMoveWindow: Bool { false }
}

private struct FoveaAnswerContentRepresentable: NSViewRepresentable {
    let messageID: String
    let markdown: String
    let streaming: Bool
    let fontSize: Double
    let foreground: String
    let onHeight: (CGFloat) -> Void
    let onReady: () -> Void

    /// The page for a message lives as long as the message: the attached slab, the reading
    /// density and the floating card all re-parent the same web view, so switching density
    /// never reloads the page (and never flashes the plain-text fallback).
    @MainActor private static var shared: [String: Coordinator] = [:]

    func makeCoordinator() -> Coordinator {
        if let existing = Self.shared[messageID] { return existing }
        let coordinator = Coordinator()
        Self.shared[messageID] = coordinator
        return coordinator
    }

    func makeNSView(context: Context) -> WKWebView {
        let coordinator = context.coordinator
        coordinator.onHeight = onHeight
        coordinator.onReady = onReady
        if let web = coordinator.webView {
            if coordinator.isReady { onReady() }
            coordinator.reportHeight()
            coordinator.enqueue(messageID: messageID, markdown: markdown, streaming: streaming, fontSize: fontSize, foreground: foreground)
            return web
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(coordinator, name: "answerContent")
        let web = FoveaAnswerWebView(frame: .zero, configuration: configuration)
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = coordinator
        coordinator.webView = web
        coordinator.enqueue(messageID: messageID, markdown: markdown, streaming: streaming, fontSize: fontSize, foreground: foreground)
        if let url = FoveaResources.url("AnswerContent/index.html") {
            coordinator.pageURL = url
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onHeight = onHeight
        context.coordinator.onReady = onReady
        context.coordinator.enqueue(messageID: messageID, markdown: markdown, streaming: streaming, fontSize: fontSize, foreground: foreground)
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        // Shared per message: the next host picks it up. Only its callbacks are dropped.
        coordinator.onHeight = nil
        coordinator.onReady = nil
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let instanceID = UUID().uuidString
        weak var webView: WKWebView?
        var pageURL: URL?
        var onHeight: ((CGFloat) -> Void)?
        var onReady: (() -> Void)?
        private var ready = false
        var isReady: Bool { ready }
        private var lastHeight: CGFloat = 0
        func reportHeight() { if lastHeight > 0 { onHeight?(lastHeight) } }
        private var disposed = false
        private var inFlight = false
        private var scheduled: DispatchWorkItem?
        private var latest: [String: Any]?
        private var latestKey = ""
        private var sentKey = ""
        private var revision = 0
        private var messageID = ""

        func enqueue(messageID: String, markdown: String, streaming: Bool, fontSize: Double, foreground: String) {
            guard !disposed else { return }
            if messageID != self.messageID { self.messageID = messageID; revision = 0 }
            let key = "\(messageID)|\(markdown.count)|\(streaming)|\(fontSize)|\(foreground)"
            guard key != latestKey else { return }
            latestKey = key
            revision += 1
            latest = ["messageID": messageID, "instanceID": instanceID, "revision": revision, "markdown": markdown,
                      "phase": streaming ? "streaming" : "completed",
                      "theme": ["fontSize": fontSize, "foreground": foreground, "dark": true],
                      "accessibilityLabel": "Answer"]
            guard ready, !inFlight else { return }
            if !streaming { scheduled?.cancel(); scheduled = nil; flush(); return }
            guard scheduled == nil else { return }
            let work = DispatchWorkItem { [weak self] in self?.scheduled = nil; self?.flush() }
            scheduled = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }

        private func flush() {
            guard ready, !disposed, !inFlight, let payload = latest, latestKey != sentKey, let webView else { return }
            inFlight = true
            sentKey = latestKey
            webView.callAsyncJavaScript("window.FoveaAnswer.update(input)", arguments: ["input": payload],
                                        in: nil, in: .page) { [weak self] _ in
                guard let self, !self.disposed else { return }
                self.inFlight = false
                if self.latestKey != self.sentKey { self.flush() }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !disposed else { return }
            ready = true
            flush()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.navigationType == .other && navigationAction.request.url == pageURL ? .allow : .cancel)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !disposed, let body = message.body as? [String: Any],
                  body["instanceID"] as? String == instanceID, let kind = body["kind"] as? String else { return }
            switch kind {
            case "heightChanged":
                if let value = body["height"] as? Double, value.isFinite, value >= 0 { lastHeight = CGFloat(value); onHeight?(CGFloat(value)) }
            case "renderStatusChanged":
                if let status = body["status"] as? String, status == "ready" || status == "degraded" { onReady?() }
            default:
                break
            }
        }

        func dispose() {
            guard !disposed else { return }
            disposed = true
            scheduled?.cancel(); scheduled = nil
            if ready { webView?.evaluateJavaScript("window.FoveaAnswer?.dispose()") }
            webView?.stopLoading()
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "answerContent")
            webView?.navigationDelegate = nil
        }
    }
}
