import SwiftUI
import AppKit

@MainActor enum ReplayReadingActions {
    static var item: HistoryPreviewCase? {
        let state = ReadingPreviewState.shared
        return state.allConversationCases.first { $0.id == state.replay.document?.turnID }
    }
    static let root = "/private/tmp/fovea-reading-native-01a08bc5/preview-data"
    static func preview(_ artifact: PreviewArtifact) {
        guard let path = artifact.path,
              PreviewArtifactPolicy.evaluate(path:path,allowedRoots:[URL(fileURLWithPath:root).resolvingSymlinksInPath().path]) == .opened else {
            ReadingPreviewState.shared.notice = "文件已不存在或无法预览。"; return
        }
        ReadingPreviewState.shared.artifact = artifact
    }
    static func open(_ artifact: PreviewArtifact, reveal: Bool = false) {
        guard let path = artifact.path else { ReadingPreviewState.shared.notice = "此文件没有可用的本地副本。"; return }
        let decision = PreviewArtifactPolicy.evaluate(path: path, allowedRoots: [URL(fileURLWithPath: root).standardizedFileURL.resolvingSymlinksInPath().path])
        guard decision == .opened else { ReadingPreviewState.shared.notice = decision == .missing ? "文件已不存在，无法打开。" : "此文件暂不支持从对话中打开。"; return }
        let url = URL(fileURLWithPath: path)
        if reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        else if !NSWorkspace.shared.open(url) { ReadingPreviewState.shared.notice = "未能打开文件。" }
    }
    static func link(_ value: String, artifacts: [PreviewArtifact] = []) {
        if let artifact = artifacts.first(where: { $0.sourcePath == value || $0.path == value || URL(fileURLWithPath: $0.sourcePath).absoluteString == value }) {
            open(artifact); return
        }
        guard let url = URL(string: value), ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") else {
            ReadingPreviewState.shared.notice = "此链接没有可用的结果文件记录。"; return
        }
        if !NSWorkspace.shared.open(url) { ReadingPreviewState.shared.notice = "未能打开链接。" }
    }
}
struct ReplayAttachments: View {
    var suppliedItem: HistoryPreviewCase? = nil
    var body: some View {
        if let item = suppliedItem ?? ReplayReadingActions.item {
            ForEach(item.materials) { material in
                Button { ReadingPreviewState.shared.material = material } label: {
                    HStack {
                        if let path = material.imagePath, let image = NSImage(contentsOfFile: path) {
                            Image(nsImage: image).resizable().scaledToFit().frame(width: Tokens.ReadingPreview.thumbnail, height: Tokens.ReadingPreview.thumbnail)
                        } else { Image(systemName: "doc") }
                        Text(material.label).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }.buttonStyle(.plain)
            }
        }
    }
}
struct ReplayResultActions: View {
    let event: ReplayEvent
    var suppliedItem: HistoryPreviewCase? = nil
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Button(copied ? "已复制" : "复制回答") {
                NSPasteboard.general.clearContents()
                copied = NSPasteboard.general.setString(event.text, forType: .string)
                    && NSPasteboard.general.string(forType: .string) == event.text
            }
            if event.kind == "final", let item = suppliedItem ?? ReplayReadingActions.item {
                ForEach(item.artifacts ?? []) { artifact in
                    HStack {
                        Image(systemName: "doc")
                        Text(artifact.title).lineLimit(1)
                        Spacer()
                        Button("预览") { ReplayReadingActions.preview(artifact) }.disabled(artifact.path == nil)
                        Button("打开") { ReplayReadingActions.open(artifact) }.disabled(artifact.path == nil)
                        Button("在 Finder 中显示") { ReplayReadingActions.open(artifact, reveal: true) }.disabled(artifact.path == nil)
                    }
                }
            }
        }.font(Tokens.Type_.caption)
    }
}
