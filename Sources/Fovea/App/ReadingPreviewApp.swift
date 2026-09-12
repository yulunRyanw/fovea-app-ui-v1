import SwiftUI
import AppKit
import FoveaCore

struct HistoryPreviewMaterial: Codable, Identifiable {
    let id: String; let kind: String; let label: String
    let text: String?; let imagePath: String?; let storedImageName: String?; let isUsed: Bool?
}
struct HistoryPreviewCase: Codable, Identifiable {
    let id: String; let label: String; let question: String; let answer: String
    let status: String; let model: String; let effort: String?; let title: String; let date: String
    let materials: [HistoryPreviewMaterial]; let failure: String?; let notes: [String]
    let rawJSON: String; let sourcePath: String; let audioPath: String?
    let startedAt: Double?
    let origin: String?; let threadID: String?; let events: [PreviewEvent]?; let artifacts: [PreviewArtifact]?
    var modelLabel: String {
        if model == "历史接口未返回模型" { return "模型未记录" }
        let parts = model.split(separator: ":").map(String.init)
        let name = parts.count > 1 ? parts[1] : model
        let strength = parts.count > 2 ? parts[2] : effort
        return name.replacingOccurrences(of: "gpt-", with: "GPT-") + (strength.map { " · " + $0.capitalized } ?? "")
    }
    var statusLabel: String {
        switch status { case "completed": return "回答已完成"; case "failed": return "失败"; case "cancelled": return "已取消"; case "interrupted": return "对话已中断"; default: return "状态未记录" }
    }
}

@MainActor @Observable final class ReadingPreviewState {
    static let shared = ReadingPreviewState()
    let model: IslandModel
    var cases: [HistoryPreviewCase] = []
    var readLimit = QuickAnswerDisplayScope.defaultPairLimit
    var selectedMessageIDs: Set<String> = []
    var following = true
    var readAnchor: Int?
    var selected = 0
    var surface = "原版纯黑"
    var previewPhase = "历史结果"
    var allConversationCases: [HistoryPreviewCase] = []
    var conversation: [HistoryPreviewCase] {
        guard let item = current else { return [] }
        guard let thread = item.threadID else { return [item] }
        return allConversationCases.filter { $0.threadID == thread }.sorted { ($0.startedAt ?? 0) < ($1.startedAt ?? 0) }
    }
    func toggleConversation() { hidden.toggle() }
    func activateControlKey() { toggleConversation() }
    let replay = ProgressReplay()
    var attached = true
    var editing = false; var hidden = true; var expandedQuestion = false
    var inspector = false
    var contentReview = true
    var notice: String?
    var material: HistoryPreviewMaterial?
    var artifact: PreviewArtifact?
    var draft = ""
    var current: HistoryPreviewCase? { cases.indices.contains(selected) ? cases[selected] : nil }
    var isLight: Bool { surface == "浅色毛玻璃" }
    init() {
        let size = Tokens.ReadingPreview.window
        let services = AppServices(options: .parse(["--demo", "no-flaky,ephemeral"]))
        model = services.makeIslandModel(metrics: ScreenMetrics(frame: CGRect(origin: .zero, size: size), visibleFrame: CGRect(origin: .zero, size: size), safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0), services: .simulated(timing: .instant))
        do {
            let url = URL(fileURLWithPath: "/private/tmp/fovea-reading-native-01a08bc5/preview-data/combined-cases.json")
            cases = try JSONDecoder().decode([HistoryPreviewCase].self, from: Data(contentsOf: url))
            allConversationCases = try JSONDecoder().decode([HistoryPreviewCase].self, from: Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent("conversation-cases.json")))
        } catch { notice = "真实数据快照读取失败：\(error.localizedDescription)" }
        refresh()
    }
    func refresh() {
        guard let item = current else { return }
        model.previewAnswer(question: item.question, answer: item.answer, streaming: false)
        expandedQuestion = false; draft = item.question
    }
    func select(_ index: Int) { selected = index; refresh() }
}

struct ReadingPreviewHeader: View {
    @Bindable var state = ReadingPreviewState.shared
    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: "bubble.left")
            Text(state.current?.title ?? "Quick Answer").lineLimit(1).help(state.current?.title ?? "")
            Spacer(minLength: Tokens.Space.s)
            Menu {
                Text("本次回答的历史归属")
                Text(state.current?.model ?? "未记录")
                Text("推理强度：\(state.current?.effort ?? "历史未保存")")
                Text("历史快照不改变下一次请求的模型")
            } label: { Text(state.current?.modelLabel ?? "未记录").lineLimit(1) }
                .menuStyle(.borderlessButton).fixedSize()
            Button { state.notice = "本预览只呈现可验证的历史决定。拒绝执行案例有对应日志，尚未确认已批准案例。\n\n回答 completed 只能证明回答完成，不能据此显示“已批准”。" } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.plain).help("历史权限信息")
            Button { state.hidden = true } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain).help("收起回答")
        }.font(Tokens.Type_.caption).foregroundStyle(Tokens.Island.Colors.textSecondary)
            .padding(.bottom, Tokens.Space.l)
    }
}

struct ReadingPreviewQuestion: View {
    @Bindable var state = ReadingPreviewState.shared
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(alignment: .top) {
                Text(state.model.state.quickAnswer?.question ?? "未读取到问题")
                    .font(Tokens.Island.Type_.question).lineLimit(state.expandedQuestion ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                Spacer(minLength: Tokens.Space.s)
                Button { state.editing = true } label: { Image(systemName: "pencil") }.buttonStyle(.plain).help("编辑副本草稿")
            }
            if (state.current?.question.count ?? 0) > 110 {
                Button(state.expandedQuestion ? "收起问题" : "展开完整问题") { state.expandedQuestion.toggle() }
                    .buttonStyle(.plain).font(Tokens.Type_.caption).foregroundStyle(.secondary)
            }
        }.padding(.bottom, Tokens.Space.m)
    }
}

struct ReadingPreviewMaterials: View {
    @Bindable var state = ReadingPreviewState.shared
    var body: some View {
        if let item = state.current, !item.materials.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Space.s) {
                    ForEach(item.materials) { value in
                        Button { state.material = value } label: {
                            HStack(spacing: Tokens.Space.s) {
                                if let path = value.imagePath, let image = NSImage(contentsOfFile: path) {
                                    Image(nsImage: image).resizable().scaledToFill()
                                        .frame(width: Tokens.ReadingPreview.thumbnail, height: Tokens.ReadingPreview.thumbnail)
                                        .clipped().clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.chip))
                                } else { Image(systemName: value.kind == "selected_text" ? "text.quote" : "photo") }
                                VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                                    Text(value.kind == "active_window_frame" ? "窗口截图" : value.label).lineLimit(1)
                                    Text(value.isUsed == true ? "已使用" : value.isUsed == false ? "未标记使用" : "使用情况未记录")
                                        .foregroundStyle(.secondary)
                                }.font(Tokens.Type_.caption)
                            }.padding(Tokens.Space.s).background(Tokens.Island.Colors.field, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(.bottom, Tokens.Space.m)
        }
    }
}

struct ReadingPreviewFooter: View {
    @Bindable var state = ReadingPreviewState.shared
    var body: some View {
        if let item = state.current {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                ForEach(item.artifacts ?? []) { artifact in
                    HStack {
                        Label(artifact.title, systemImage: "doc.richtext")
                        Spacer()
                        Button("打开交互预览") { state.artifact = artifact }.disabled(artifact.path == nil)
                    }.font(Tokens.Type_.body).padding(Tokens.Space.m)
                        .background(Tokens.Island.Colors.field, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                }
                if let failure = item.failure {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .font(Tokens.Type_.body).foregroundStyle(Tokens.Colors.warning)
                        .padding(Tokens.Space.m).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Tokens.Island.Colors.field, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                }
                if let note = item.notes.first(where: { $0.contains("外部记录") }) {
                    Label(note, systemImage: "photo.badge.exclamationmark").font(Tokens.Type_.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label(item.statusLabel, systemImage: item.status == "completed" ? "checkmark.circle" : "exclamationmark.circle")
                    Text(item.date).lineLimit(1)
                    Spacer()
                    Button("来源与缺失字段") { state.inspector = true }
                }.font(Tokens.Type_.caption).foregroundStyle(Tokens.Island.Colors.textSecondary)
                Rectangle().fill(Tokens.Island.Colors.hairline).frame(height: 1)
                HStack(spacing: Tokens.Space.l) {
                    Button {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.answer, forType: .string)
                    } label: { Label("复制", systemImage: "doc.on.doc") }.disabled(item.answer.isEmpty)
                    Button {} label: { Label("重新回答", systemImage: "arrow.clockwise") }.disabled(true).help("只读历史尚未连接提交接口")
                    Spacer()
                    Button { state.notice = "已保留原始会话信息供核对。预览不向该会话发送内容。请在“来源与缺失字段”中查看具体关联。" } label: { Label("在 Codex 中继续", systemImage: "arrow.up.right") }.disabled(true).help("预览未连接会话跳转")
                    Menu {
                        Button("下载音频") { state.notice = item.audioPath }.disabled(item.audioPath == nil)
                        Button("保存图片") {}.disabled(true)
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                }.font(Tokens.Type_.caption).buttonStyle(.plain).foregroundStyle(Tokens.Island.Colors.textSecondary)
            }
        }
    }
}

struct HistoryGlass: NSViewRepresentable {
    let light: Bool
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.blendingMode = .withinWindow; view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = light ? .sidebar : .hudWindow
        view.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
    }
}

struct HistorySourceInspector: View {
    @Bindable var state = ReadingPreviewState.shared
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            HStack { Text("真实来源与数据缺口").font(Tokens.Type_.section); Spacer(); Button("关闭") { state.inspector = false } }
            Text("编辑版本链尚未确认；补充指令以独立消息展示。\n拒绝执行有日志佐证，已批准尚未确认。对话中断与单条命令完成分别显示。")
                .font(Tokens.Type_.body).foregroundStyle(.secondary)
            if let item = state.current {
                Text("History ID：\(item.id)").font(Tokens.Type_.caption).textSelection(.enabled)
                ForEach(item.notes, id: \.self) { Text($0).font(Tokens.Type_.caption) }
                ScrollView { Text(item.rawJSON).font(Tokens.Type_.mono).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }.padding(Tokens.Space.xl).frame(width: Tokens.ReadingPreview.inspectorWidth, height: Tokens.ReadingPreview.inspectorHeight)
    }
}

struct ReadingPreviewStage: View {
    @Bindable var state = ReadingPreviewState.shared
    var body: some View {
        ZStack {
            Tokens.ReadingPreview.canvas
            HStack(spacing: Tokens.Space.xxxl) {
                RoundedRectangle(cornerRadius: Tokens.ReadingPreview.cardRadius).fill(Tokens.ReadingPreview.backdropBlue)
                RoundedRectangle(cornerRadius: Tokens.ReadingPreview.cardRadius).fill(Tokens.ReadingPreview.backdropSand)
            }.padding(Tokens.Space.xxxl).rotationEffect(.degrees(Tokens.ReadingPreview.backdropAngle))
            VStack(spacing: 0) {
                HStack {
                    Text("Finder").font(Tokens.Type_.captionMedium)
                    Spacer()
                    Image(systemName: "wifi")
                    Text("10:30").font(Tokens.Type_.caption)
                }.padding(.horizontal, Tokens.Space.l)
                    .frame(height: Tokens.ReadingPreview.notchHeight)
                    .background(Tokens.ReadingPreview.menuBar)
                Spacer()
            }
            VStack(spacing: 0) {
                if state.contentReview { ContentReadingReview() }
                else {
                if state.hidden { CompactConversationPreview() }
                else if state.replay.enabled { ReplayExpandedContent() }
                else { FullConversationPreview() }
                Spacer(minLength: Tokens.Space.l)
                HStack {
                    Button(state.hidden ? "展开完整对话  左 Control" : "收起完整对话  左 Control") { state.toggleConversation() }
                    Spacer()
                    Text("历史过程 · 不执行真实任务").font(Tokens.Type_.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, Tokens.Space.xxl).padding(.bottom, Tokens.Space.l)
                ReplayControls()
                }
                HStack {
                    Toggle("仅评审正文显示", isOn:$state.contentReview)
                    Spacer()
                    Button("来源") { state.notice = "真实来源：" + (state.replay.document?.title ?? "") + "\n回合：" + (state.replay.document?.turnID ?? "") + "\n摘要由公开进度说明提炼；工具事件来自同轮日志。" }
                }.font(Tokens.Type_.caption).padding(.horizontal, Tokens.Space.xxl)
                    .padding(.vertical, Tokens.Space.l)
            }

        }.frame(width: Tokens.ReadingPreview.window.width, height: Tokens.ReadingPreview.window.height)
            .environment(\.colorScheme, .light)
            .preferredColorScheme(.light)
            .sheet(isPresented: $state.inspector) { HistorySourceInspector() }
            .sheet(item: $state.artifact) { artifact in
                VStack(spacing: Tokens.Space.l) {
                    HStack { Text(artifact.title); Spacer(); Button("关闭") { state.artifact = nil } }
                    if let path = artifact.path { OfflineArtifactPreview(path: path) }
                }.padding(Tokens.Space.xl).frame(width: Tokens.ReadingPreview.inspectorWidth, height: Tokens.ReadingPreview.inspectorHeight)
            }
            .sheet(item: $state.material) { material in
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    HStack { Text(material.label).font(Tokens.Type_.section); Spacer(); Button("关闭") { state.material = nil } }
                    if let path = material.imagePath, let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image).resizable().scaledToFit()
                    } else {
                        ScrollView { Text(material.text ?? "History 未保存该附件的内容。") .textSelection(.enabled) }
                    }
                }.padding(Tokens.Space.xl).frame(width: Tokens.ReadingPreview.inspectorWidth, height: Tokens.ReadingPreview.inspectorHeight)
            }
            .sheet(isPresented: $state.editing) {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    Text("编辑副本草稿").font(Tokens.Type_.section)
                    Text("原始 History 保持不变；这不是历史修改记录。").font(Tokens.Type_.caption).foregroundStyle(.secondary)
                    TextEditor(text: $state.draft).frame(height: Tokens.ReadingPreview.editorHeight)
                    HStack { Button("取消") { state.editing = false }; Spacer(); Button("在预览中应用") {
                        if let item = state.current { state.model.previewAnswer(question: state.draft, answer: item.answer, streaming: false) }
                        state.editing = false; state.notice = "已修改本地预览草稿，原回答未重新生成。"
                    } }
                }.padding(Tokens.Space.xl).frame(width: Tokens.ReadingPreview.sheetWidth)
            }
            .alert("历史预览", isPresented: Binding(get: { state.notice != nil }, set: { if !$0 { state.notice = nil } })) {
                Button("好") { state.notice = nil }
            } message: { Text(state.notice ?? "") }
    }
}

struct ReadingPreviewApp: App {
    @NSApplicationDelegateAdaptor(ReadingPreviewDelegate.self) var delegate
    var body: some Scene {
        Window("Quick Answer · B 阅读验收 History", id: "preview") { ReadingPreviewStage() }
            .windowResizability(.contentSize)
            .commands {
                CommandMenu("对话") {
                    Button("展开／收起当前会话") { ReadingPreviewState.shared.toggleConversation() }
                    Button("验证正文显示") {
                        ReadingPreviewState.shared.contentReview = true
                        Task { @MainActor in await ContentReviewVerification.run() }
                    }
                }
            }
    }
}
@MainActor final class ReadingPreviewDelegate: NSObject, NSApplicationDelegate {
    private let controlKey = PreviewControlKey()
    func applicationDidResignActive(_ notification: Notification) { controlKey.reset() }
    func applicationWillTerminate(_ notification: Notification) { controlKey.stop() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
        controlKey.start()
        ReadingPreviewState.shared.replay.pause()
        if CommandLine.arguments.contains("--verify-content") {
            Task { @MainActor in
                try? await Task.sleep(for:.seconds(2))
                await ContentReviewVerification.run()
            }
            return
        }
        guard CommandLine.arguments.contains("--capture-history") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            let state = ReadingPreviewState.shared
            state.contentReview = false
            let replay = state.replay
            let folder = URL(fileURLWithPath:"/private/tmp/fovea-reading-native-01a08bc5/rendered-history")
            for (caseIndex, name) in [(3,"B-result-final"),(2,"B-attachments-final"),(7,"B-format-final")] {
                replay.select(caseIndex); replay.seek(caseIndex == 2 ? 0 : 999); state.hidden = false
                try? await Task.sleep(for: .seconds(3))
                if let view = NSApp.windows.first(where: { $0.isVisible && $0.title.contains("History") })?.contentView,
                   let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                    view.cacheDisplay(in:view.bounds,to:bitmap)
                    if let data = bitmap.representation(using:.png,properties:[:]) { try? data.write(to:folder.appendingPathComponent(name + ".png")) }
                }
            }
            replay.select(3); replay.seek(999)
        }
    }
}
