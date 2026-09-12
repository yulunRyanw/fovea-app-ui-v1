import SwiftUI

struct CompactConversationPreview: View {
    @Bindable var state = ReadingPreviewState.shared
    private var summary: String {
        guard let item = state.current else { return "暂无会话" }
        if state.previewPhase == "提问中" { return "正在提问 · 按快捷键查看对话" }
        if state.previewPhase == "处理中" { return "正在处理 · 可继续使用桌面" }
        if let event = item.events?.first(where: { $0.title == "用户拒绝执行" }) { return event.title }
        if let failure = item.failure { return failure }
        if let result = item.artifacts?.first { return "已生成 " + result.title }
        return item.statusLabel
    }
    var body: some View {
        VStack(spacing: 0) {
            Color.black.frame(height: Tokens.ReadingPreview.notchHeight)
            if state.replay.enabled { CompactReplayContent() } else {
            HStack(spacing: Tokens.Space.m) {
                Image(systemName: state.previewPhase != "历史结果" ? "waveform" : state.current?.status == "completed" ? "checkmark.circle" : "exclamationmark.circle")
                Text(summary).font(Tokens.Type_.body).lineLimit(1)
                Spacer(minLength: Tokens.Space.s)
                if state.previewPhase == "历史结果", let artifact = state.current?.artifacts?.first, artifact.path != nil {
                    Button("查看结果") { state.artifact = artifact }.buttonStyle(.plain)
                }
                Button { state.toggleConversation() } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain).help("展开当前会话 · 左 Control")
            }.padding(.horizontal, Tokens.Space.l).padding(.vertical, Tokens.Space.m)
            }
        }.frame(width: Tokens.ReadingPreview.compactWidth)
            .foregroundStyle(Tokens.Island.Colors.textPrimary).background(Tokens.Island.Colors.surface)
            .clipShape(IslandShape(topRadius: Tokens.ReadingPreview.notchEar, bottomRadius: Tokens.Radius.group))
            .environment(\.colorScheme, .dark)
    }
}


struct ConversationTurnPreview: View {
    let item: HistoryPreviewCase
    @State private var answerHeight: CGFloat = Tokens.Space.xxxl
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack { Text(item.date); Spacer(); Text(item.statusLabel) }.font(Tokens.Type_.caption).foregroundStyle(.secondary)
            Text(PreviewNativeContent.question(item.question, item: item)).font(Tokens.Type_.body).textSelection(.enabled)
            ReplayAttachments(suppliedItem: item)
            if item.answer.isEmpty {
                Text("该轮没有最终回答").foregroundStyle(.secondary)
            } else {
                CodexAnswerContent(item: item, light: false, height: $answerHeight).frame(height: answerHeight)
                ReplayResultActions(event: .init(id:item.id, kind:"final", title:"回答", text:item.answer, summary:"", time:item.date, elapsed:0, returned:0, sourceID:item.id), suppliedItem:item)
            }
            Divider()
        }.padding(.bottom, Tokens.Space.l)
    }
}
struct FullConversationPreview: View {
    @Bindable var state = ReadingPreviewState.shared
    private var visible: [HistoryPreviewCase] {
        let turns = state.conversation
        return QuickAnswerDisplayScope.visibleIndices(count: turns.count, limit: state.readLimit, anchor: state.readAnchor, pinned: Set(turns.indices.filter { state.selectedMessageIDs.contains(turns[$0].id) })).map { turns[$0] }
    }
    var body: some View {
        VStack(spacing: 0) {
            Color.black.frame(height: Tokens.ReadingPreview.notchHeight)
            HStack {
                Text(state.current?.title ?? "完整会话").lineLimit(1)
                Spacer()
                Button { state.toggleConversation() } label: { Image(systemName:"chevron.up") }
            }.padding(Tokens.Space.l)
            HStack {
                Picker("可见轮数", selection:$state.readLimit) { ForEach(QuickAnswerDisplayScope.options, id: \.self) { Text("\($0) 轮").tag($0) } }
                Text("显示 \(visible.count) / \(state.conversation.count) 轮").font(Tokens.Type_.caption)
                Button("回到最新") { state.readAnchor = nil; state.following = true }
            }.padding(.horizontal, Tokens.Space.l)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment:.leading, spacing:Tokens.Space.l) {
                        ForEach(visible) { item in ConversationTurnPreview(item:item).id(item.id) }
                    }.padding(Tokens.Space.l).background(AnswerScrollPositionObserver(following:$state.following))
                }.frame(height:Tokens.ReadingPreview.replayConversationHeight)
                .onAppear { proxy.scrollTo(visible.last?.id, anchor:.bottom) }
                .onChange(of: state.readLimit) { _, _ in if state.following { proxy.scrollTo(visible.last?.id, anchor:.bottom) } }
                .onChange(of: state.following) { _, value in if value { proxy.scrollTo(visible.last?.id, anchor:.bottom) } }
            }
            Text("阅读范围不会删除历史记录").font(Tokens.Type_.caption).foregroundStyle(.secondary).padding(Tokens.Space.m)
        }.frame(width:Tokens.Island.Layout.slabWidth).background(Tokens.Island.Colors.surface)
        .clipShape(IslandShape(topRadius:Tokens.ReadingPreview.notchEar,bottomRadius:Tokens.ReadingPreview.cardRadius)).environment(\.colorScheme,.dark)
    }
}
