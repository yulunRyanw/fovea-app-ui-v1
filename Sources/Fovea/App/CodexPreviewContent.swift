import SwiftUI
import WebKit
import AppKit

struct PreviewEvent: Codable { let title: String; let detail: String; let raw: String }
struct PreviewArtifact: Codable, Identifiable { let id: String; let title: String; let path: String?; let sourcePath: String }

// Uses the existing Fovea renderer bundle, without coupling to a live QA session.
struct CodexAnswerContent: NSViewRepresentable {
    let messageID: String
    let markdown: String
    let status: String
    let light: Bool
    let artifacts: [PreviewArtifact]
    var imageSources: [String: [String:String]] = [:]
    @Binding var height: CGFloat
    init(item: HistoryPreviewCase, light: Bool, height: Binding<CGFloat>) {
        self.init(messageID: item.id, markdown: PreviewNativeContent.answer(item.answer), status: item.status, light: light, artifacts: item.artifacts ?? [], height: height)
        imageSources = PreviewRecordedImages.sources(item.materials)
    }
    init(messageID: String, markdown: String, status: String = "completed", light: Bool = false, artifacts: [PreviewArtifact] = [], height: Binding<CGFloat>) {
        self.artifacts = artifacts
        self.messageID = messageID; self.markdown = markdown; self.status = status
        self.light = light; self._height = height
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "answerContent")
        let view = AnswerContentWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        let root = URL(fileURLWithPath: "/private/tmp/fovea-reading-native-01a08bc5/preview-data/AnswerContent")
        view.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
        context.coordinator.webView = view
        ContentReviewVerification.webView = view
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update()
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.evaluateJavaScript("window.FoveaAnswer?.dispose()")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "answerContent")
        view.navigationDelegate = nil
        ReadingPreviewState.shared.selectedMessageIDs.remove(coordinator.parent.messageID)
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: CodexAnswerContent; weak var webView: WKWebView?
        var ready = false
        var lastPayload: Data?
        var revision = 0
        let instanceID = UUID().uuidString
        init(_ parent: CodexAnswerContent) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; update() }
        func update() {
            guard ready, let webView else { return }
            var payload: [String: Any] = ["messageID": parent.messageID, "instanceID": instanceID,
                "markdown": parent.markdown,
                "phase": ["streaming", "interrupted", "failed"].contains(parent.status) ? parent.status : "completed",
                "imageSources": parent.imageSources,
                "theme": ["foreground": parent.light ? Tokens.ReadingPreview.answerLight : Tokens.ReadingPreview.answerDark,
                          "fontSize": Tokens.ReadingPreview.answerFontSize]]
            guard let fingerprint = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), fingerprint != lastPayload else { return }
            lastPayload = fingerprint
            revision += 1; payload["revision"] = revision
            guard let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.FoveaAnswer.update(\(json))")
            let css = parent.light ? Tokens.ReadingPreview.lightAnswerCSS : Tokens.ReadingPreview.darkAnswerCSS
            if let cssData = try? JSONSerialization.data(withJSONObject: [css]), let cssJSON = String(data: cssData, encoding: .utf8) {
                webView.evaluateJavaScript("{let s=document.getElementById('preview-theme');if(!s){s=document.createElement('style');s.id='preview-theme';document.head.append(s)}s.textContent=\(cssJSON)[0];}")
            }
        }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], body["messageID"] as? String == parent.messageID,
                  body["instanceID"] as? String == instanceID,
                  body["revision"] as? Int == revision else { return }
            if body["kind"] as? String == "selectionChanged", let text = body["text"] as? String {
                let state = ReadingPreviewState.shared
                if !text.isEmpty { state.following = false; state.selectedMessageIDs.insert(parent.messageID) }
                else { state.selectedMessageIDs.remove(parent.messageID) }
            }
            if body["kind"] as? String == "heightChanged", let value = body["height"] as? Double {
                DispatchQueue.main.async { self.parent.height = max(Tokens.Space.xxl, value) }
            }
            if body["kind"] as? String == "openLinkRequested", let url = body["url"] as? String { ReplayReadingActions.link(url, artifacts: parent.artifacts) }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.isFileURL == true ? .allow : .cancel)
        }
    }
}

enum PreviewRecordedImages {
    static func sources(_ materials: [HistoryPreviewMaterial]) -> [String:[String:String]] {
        var sources: [String:[String:String]] = [:]
        for material in materials {
            guard let path = material.imagePath,
                  PreviewArtifactPolicy.evaluate(path: path, allowedRoots: [URL(fileURLWithPath:"/private/tmp/fovea-reading-native-01a08bc5/preview-data").resolvingSymlinksInPath().path]) == .opened,
                  let image = NSImage(contentsOfFile:path), let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data:tiff), let data = bitmap.representation(using:.png,properties:[:]) else { continue }
            let value = ["src":"data:image/png;base64," + data.base64EncodedString(),
                         "width":String(bitmap.pixelsWide),"height":String(bitmap.pixelsHigh)]
            sources[path] = value
            if let original = material.storedImageName { sources[original] = value }
        }
        return sources
    }
}

struct CodexPreviewBody: View {
    @Bindable var state = ReadingPreviewState.shared
    @State private var contentHeight: CGFloat = Tokens.Space.xxxl
    var body: some View {
        if let item = state.current {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    ForEach(Array((item.events ?? []).enumerated()), id: \.offset) { _, event in
                        DisclosureGroup {
                            Text(event.raw).font(Tokens.Type_.mono).textSelection(.enabled)
                        } label: {
                            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                                Text(event.title).font(Tokens.Type_.captionMedium)
                                Text(event.detail).font(Tokens.Type_.body).textSelection(.enabled)
                            }
                        }.padding(Tokens.Space.m).background(Tokens.Island.Colors.field, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                    }
                    CodexAnswerContent(item: item, light: state.isLight, height: $contentHeight)
                        .frame(height: contentHeight).id(item.id)
                }
            }.frame(maxHeight: Tokens.ReadingPreview.answerRegionHeight)
        }
    }
}

struct OfflineArtifactPreview: NSViewRepresentable {
    let path: String
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();config.websiteDataStore = .nonPersistent()
        // Restricts the inspected offline artifact to local content.
        let policy = "{\"trigger\":{\"url-filter\":\"^https?://\"},\"action\":{\"type\":\"block\"}}"
        let view = WKWebView(frame: .zero, configuration: config)
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "FoveaOfflinePreview", encodedContentRuleList: "[" + policy + "]") { list, _ in
            guard let list else { return }
            view.configuration.userContentController.add(list)
            let url = URL(fileURLWithPath: path)
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
