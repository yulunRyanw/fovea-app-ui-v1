import SwiftUI
import Foundation

struct ReplayEvent: Codable, Identifiable {
    let id: String; let kind: String; let title: String; let text: String; let summary: String
    let time: String; let elapsed: Int; let returned: Int; let sourceID: String
}
struct ReplayDocument: Codable {
    let threadID: String; let turnID: String; let title: String
    let question: String; let source: String; let events: [ReplayEvent]
    let label: String?
}
@MainActor @Observable final class ProgressReplay {
    let documents: [ReplayDocument]
    var selected = 0
    var revision = 0
    var document: ReplayDocument? { documents.indices.contains(selected) ? documents[selected] : nil }
    var position: String { "\(selected):\(index):\(revision)" }
    var index = 0
    var playing = false
    var enabled = true
    var task: Task<Void, Never>?
    var event: ReplayEvent? { document?.events.indices.contains(index) == true ? document?.events[index] : nil }
    var visibleEvents: [ReplayEvent] { Array((document?.events ?? []).prefix(index + 1)) }
    init() {
        let path = "/private/tmp/fovea-reading-native-01a08bc5/preview-data/replays.json"
        documents = (try? Data(contentsOf: URL(fileURLWithPath: path))).flatMap { try? JSONDecoder().decode([ReplayDocument].self, from: $0) } ?? []
    }
    func pause() { task?.cancel(); task = nil; playing = false }
    func play() {
        guard document != nil else { return }
        pause(); enabled = true
        if index >= (document?.events.count ?? 1) - 1 { index = 0 }
        playing = true
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(Tokens.ReadingPreview.replayInterval)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                if self.index < (self.document?.events.count ?? 1) - 1 { self.index += 1 }
                else { self.pause(); return }
            }
        }
    }
    func seek(_ value: Int) { ReadingPreviewState.shared.following = true; pause(); index = max(0, min(value, (document?.events.count ?? 1) - 1)); revision += 1 }
    func select(_ value: Int) { ReadingPreviewState.shared.following = true; pause(); selected = value; index = 0; revision += 1
        let state = ReadingPreviewState.shared
        state.readAnchor = nil
        if let i = state.cases.firstIndex(where: { $0.id == document?.turnID }) { state.selected = i }
    }
    func restart() { seek(0); play() }
    func step() { seek(index + 1) }
}

struct CompactReplayContent: View {
    @Bindable var replay = ReadingPreviewState.shared.replay
    var body: some View {
        if let event = replay.event {
            let presentation = CompactEventPresentation(event: event, previous: replay.visibleEvents)
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                HStack(spacing: Tokens.Space.s) {
                    Image(systemName: presentation.symbol)
                    Text(presentation.title).font(Tokens.Type_.bodyMedium)
                    Spacer()
                    Text(String(format: "%02d:%02d", event.elapsed / 60, event.elapsed % 60))
                        .font(Tokens.Type_.caption).monospacedDigit().foregroundStyle(.secondary)
                    Button { ReadingPreviewState.shared.toggleConversation() } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.plain).help("左 Control 展开／收起")
                }
                Text(presentation.summary)
                    .font(Tokens.Type_.body).foregroundStyle(.secondary).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(presentation.hint)
                    Spacer()
                    Text("历史回放 · 时间已压缩")
                }.font(Tokens.Type_.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, Tokens.Space.l).padding(.vertical, Tokens.Space.m)
        } else { Text("未读取到回放数据").padding(Tokens.Space.l) }
    }
}

struct ReplayExpandedContent: View {
    @Bindable var state = ReadingPreviewState.shared
    @Bindable var replay = ReadingPreviewState.shared.replay
    var body: some View {
        VStack(spacing: 0) {
            Color.black.frame(height: Tokens.ReadingPreview.notchHeight)
            HStack {
                Text(replay.document?.title ?? "历史回放").font(Tokens.Type_.bodyMedium).lineLimit(1)
                Spacer()
                Button { state.toggleConversation() } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain)
            }.padding(Tokens.Space.l)
            Divider()
            HStack {
                Text(state.following ? "跟随最新内容" : "正在阅读前文").font(Tokens.Type_.caption).foregroundStyle(.secondary)
                Spacer()
                Button("回到最新") { state.following = true; replay.revision += 1 }
            }.padding(.horizontal, Tokens.Space.l)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.l) {
                        if !replay.visibleEvents.contains(where: { $0.kind == "start" }) {
                            ReplayQuestionBody(raw: replay.document?.question ?? "")
                        }
                        ForEach(replay.visibleEvents) { event in
                            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                                Text(event.title + " · " + String(format: "%02d:%02d", event.elapsed / 60, event.elapsed % 60))
                                    .font(Tokens.Type_.caption).foregroundStyle(.secondary)
                                ReplayEventBody(event: event)
                                if event.kind == "final" || event.kind == "progress" { ReplayResultActions(event: event) }
                            }.padding(Tokens.Space.m).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Tokens.Island.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                                .overlay(alignment: .leading) {
                                    if event.id == replay.event?.id { Capsule().fill(.white).frame(width: Tokens.Space.xs).padding(.vertical, Tokens.Space.s) }
                                }
                                .id(event.id)
                        }
                    }.padding(Tokens.Space.l)
                        .background(AnswerScrollPositionObserver(following: $state.following))
                }.frame(height: Tokens.ReadingPreview.replayConversationHeight)
                    .onAppear { proxy.scrollTo(replay.event?.id, anchor: .bottom) }
                    .onChange(of: replay.position) { _, _ in
                        guard state.following else { return }
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo(replay.event?.id, anchor: .bottom)
                        }
                    }
            }
            Text("左 Control 收起 · 收起后回放继续").font(Tokens.Type_.caption).foregroundStyle(.secondary).padding(Tokens.Space.m)
        }.frame(width: Tokens.Island.Layout.slabWidth).background(Tokens.Island.Colors.surface)
            .clipShape(IslandShape(topRadius: Tokens.ReadingPreview.notchEar, bottomRadius: Tokens.ReadingPreview.cardRadius))
            .environment(\.colorScheme, .dark)
    }
}

struct ReplayControls: View {
    @Bindable var state = ReadingPreviewState.shared
    @Bindable var replay = ReadingPreviewState.shared.replay
    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            HStack {
                Picker("阅读方式", selection: Binding(get: { replay.enabled }, set: { value in
                    replay.pause(); replay.enabled = value; state.hidden = false
                    if !value, let index = state.cases.firstIndex(where: { $0.id == replay.document?.turnID }) { state.selected = index }
                })) { Text("过程回放").tag(true); Text("完整会话").tag(false) }.frame(maxWidth: Tokens.Island.Layout.slabWidth)
                Text("真实记录").font(Tokens.Type_.caption)
                Spacer()
                Button(replay.playing ? "暂停" : "播放") { replay.playing ? replay.pause() : replay.play() }
                Button("上一条") { replay.seek(replay.index - 1) }.disabled(replay.index == 0)
                Button("下一条") { replay.step() }.disabled(replay.index >= (replay.document?.events.count ?? 1) - 1)
                Button("重播") { replay.restart() }
            }
            HStack {
                Picker("案例", selection: Binding(get: { replay.selected }, set: { replay.select($0) })) {
                    ForEach(replay.documents.indices, id: \.self) { i in Text(replay.documents[i].label ?? replay.documents[i].title).tag(i) }
                }.frame(maxWidth: .infinity)
                Text("原始 \(replay.document?.events.last?.elapsed ?? 0) 秒")
                Spacer()
                Text("\(replay.index + 1) / \(replay.document?.events.count ?? 0) 条回放事件")
            }.font(Tokens.Type_.caption).foregroundStyle(.secondary)
            Slider(value: Binding(get: { Double(replay.index) }, set: { if Int($0) != replay.index { replay.seek(Int($0)) } }),
                   in: 0...Double(max(1, (replay.document?.events.count ?? 1) - 1)), step: 1)
            Text("每 5 秒前进一条真实事件；拖动可逐时刻对照。收起看摘要，展开看详情；正文仅显示已发生的记录。")
                .font(Tokens.Type_.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, Tokens.Space.xxl).padding(.bottom, Tokens.Space.l)
    }
}

struct ReplayEventBody: View {
    let event: ReplayEvent
    @State private var height: CGFloat = Tokens.Space.xxxl
    var body: some View {
        if event.kind == "progress" || event.kind == "final" {
            CodexAnswerContent(messageID: event.id, markdown: PreviewNativeContent.answer(event.text), artifacts: ReplayReadingActions.item?.artifacts ?? [], height: $height)
                .frame(height: height)
                .onChange(of: height) { _, _ in ReadingPreviewState.shared.replay.revision += 1 }
        } else if event.kind == "result" || event.kind == "rejected" {
            DisclosureGroup("查看原始工具记录") {
                Text(event.text).font(Tokens.Type_.mono).textSelection(.enabled)
            }
        } else if event.kind == "tool" {
            Text("工具正在执行").font(Tokens.Type_.body).foregroundStyle(.secondary)
        } else if event.kind == "start" || event.kind == "user" {
            ReplayQuestionBody(raw: event.text)
        } else {
            Text(event.text).font(Tokens.Type_.body).textSelection(.enabled)
        }
    }
}

struct ReplayQuestionBody: View {
    let raw: String
    var body: some View {
        let question = PreviewNativeContent.question(raw, item: ReplayReadingActions.item)
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(question).font(Tokens.Type_.body).textSelection(.enabled)
            ReplayAttachments()
            if question != raw {
                DisclosureGroup("附带上下文 · 查看原始记录") {
                    Text(raw).font(Tokens.Type_.mono).textSelection(.enabled)
                }.font(Tokens.Type_.caption).foregroundStyle(.secondary)
            }
        }
    }
}
