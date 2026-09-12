import SwiftUI
import AppKit
import FoveaCore

/// The rehearsal console: a plain window next to the live island where every flow can be
/// jumped to, every key tried, the round driven by hand, the data case switched, the
/// animation slowed and a recording started — the way the reading-preview program worked.
/// Keys (left Control, Esc, arrows, Return, typing) reach the island whenever this window
/// is in front; the buttons send the same events.
@MainActor
final class IslandRehearsalConsole {
    private let session: IslandRehearsal.Session
    private let state = ConsoleState()
    private var window: NSWindow?

    init(session: IslandRehearsal.Session) {
        self.session = session
        state.stepTitles = session.stepTitles
        state.cases = RehearsalData.cases.map(\.caseLabel)
        state.caseIndex = RehearsalData.currentIndex
        state.slowMotion = Tokens.Motion.slowMotion
        state.chunkSize = RehearsalAgentService.chunkSize
        state.intervalMs = RehearsalAgentService.intervalMs
        session.onStepChanged = { [weak self] index in self?.state.stepIndex = index }
        session.controller.model.onEventLogged = { [weak self] line in
            guard let self else { return }
            self.state.events.append(line)
            if self.state.events.count > 40 { self.state.events.removeFirst(self.state.events.count - 40) }
            self.refreshStatus()
        }
        refreshStatus()
    }

    func show() {
        let metrics = session.controller.model.metrics
        let size = NSSize(width: 980, height: 640)
        let bottom = max(metrics.frame.minY, metrics.visibleFrame.minY)
        let frame = NSRect(x: metrics.frame.midX - size.width / 2, y: bottom + 40, width: size.width, height: size.height)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Fovea 岛排练台"
        window.contentView = NSHostingView(rootView: ConsoleView(state: state, actions: ConsoleActions(session: session, state: state, console: self)))
        window.minSize = NSSize(width: 860, height: 560)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func refreshStatus() {
        let s = session.controller.model.state
        state.phase = String(describing: s.phase).replacingOccurrences(of: "FoveaCore.", with: "")
        state.density = String(describing: s.density)
        switch s.destination {
        case .automatic: state.destination = "自动"
        case .newConversation(let provider): state.destination = "新对话 · \(ProviderMark.displayName(for: provider))"
        case .existing(_, let title, let provider): state.destination = "\(ProviderMark.displayName(for: provider)) · \(title.prefix(18))…"
        }
        state.highlight = s.destinationHighlight
        state.menuOpen = s.destinationMenuOpen
        state.isAuto = session.isAutoPlaying
        state.isRecording = session.isRecording
    }
}

@MainActor @Observable
final class ConsoleState {
    var stepTitles: [(String, String)] = []
    var stepIndex = -1
    var cases: [String] = []
    var caseIndex = 0
    var phase = ""
    var density = ""
    var destination = ""
    var highlight = 0
    var menuOpen = false
    var events: [String] = []
    var isAuto = false
    var isRecording = false
    var slowMotion: Double = 1
    var chunkSize = 5
    var intervalMs = 45
    var notice: String?
}

@MainActor
struct ConsoleActions {
    let session: IslandRehearsal.Session
    let state: ConsoleState
    let console: IslandRehearsalConsole
    var model: IslandModel { session.controller.model }

    func send(_ event: IslandEvent) { model.send(event); console.refreshStatus() }
    func jump(_ i: Int) { session.jump(to: i); console.refreshStatus() }
    func next() { session.stepNext(); console.refreshStatus() }
    func previous() { session.stepPrevious(); console.refreshStatus() }
    func restart() { session.restartFromConsole(); console.refreshStatus() }
    func toggleAuto() { session.toggleAuto(); console.refreshStatus() }

    func selectCase(_ i: Int) {
        RehearsalData.select(i)
        state.caseIndex = i
        session.restartFromConsole()
        console.refreshStatus()
    }

    func setSlowMotion(_ factor: Double) { Tokens.Motion.slowMotion = factor; state.slowMotion = factor }
    func setPace(chunk: Int, interval: Int) {
        RehearsalAgentService.chunkSize = chunk; RehearsalAgentService.intervalMs = interval
        state.chunkSize = chunk; state.intervalMs = interval
    }

    func toggleRecording() {
        if session.isRecording {
            Task { @MainActor in
                let url = await session.stopRecording()
                state.notice = url.map { "录屏已保存：\($0.path)" }
                console.refreshStatus()
            }
        } else {
            session.startRecording()
            console.refreshStatus()
        }
    }

    /// Double tap = two clean taps inside the window; the session's tap logic is not reachable
    /// from a button, so the console sends the model's events directly.
    func expandKey() { send(model.phase == .listening ? .toggleDestinationMenu : .toggleQuickAnswerDensity) }
    func expandKeyTwice() { send(.doubleTapExpandKey) }
}

struct ConsoleView: View {
    @Bindable var state: ConsoleState
    let actions: ConsoleActions

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            flows.frame(width: 300)
            VStack(alignment: .leading, spacing: 12) {
                keys
                round
                HStack(alignment: .top, spacing: 12) { data; display }
                status
            }
        }
        .padding(16)
        .frame(minWidth: 860, minHeight: 560)
        .alert(state.notice ?? "", isPresented: Binding(get: { state.notice != nil }, set: { if !$0 { state.notice = nil } })) {
            Button("好") { state.notice = nil }
        }
    }

    // MARK: Flows

    private var flows: some View {
        GroupBox("流程（点一步直接跳到那一步）") {
            VStack(alignment: .leading, spacing: 6) {
                List(selection: Binding(get: { state.stepIndex >= 0 ? state.stepIndex : nil },
                                        set: { if let i = $0 { actions.jump(i) } })) {
                    ForEach(Array(state.stepTitles.enumerated()), id: \.offset) { i, step in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(i + 1). \(step.0)").font(.system(size: 12.5, weight: i == state.stepIndex ? .semibold : .regular))
                            Text(step.1).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .tag(i)
                    }
                }
                .listStyle(.inset)
                HStack(spacing: 8) {
                    Button("◀ 上一步") { actions.previous() }.disabled(state.stepIndex <= 0)
                    Button("下一步 ▶") { actions.next() }.disabled(state.stepIndex >= state.stepTitles.count - 1)
                    Button(state.isAuto ? "⏸ 暂停" : "▶ 自动播放") { actions.toggleAuto() }
                    Button("从头") { actions.restart() }
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: Keys

    private var keys: some View {
        GroupBox("按键（这个窗口在前面时，真实按键直接作用于岛：左 Control 单击 / 双击、Esc、↑↓←→、回车、打字）") {
            HStack(spacing: 8) {
                Button("按住提问键") { actions.send(.hotkeyDown(.quickAnswer)) }
                Button("松手") { actions.send(.hotkeyUp(.quickAnswer)) }
                Divider().frame(height: 18)
                Button("按住 VoiceFlow") { actions.send(.hotkeyDown(.voiceFlow)) }
                Button("松手 ") { actions.send(.hotkeyUp(.voiceFlow)) }
                Divider().frame(height: 18)
                Button("左 Control") { actions.expandKey() }
                Button("左 Control ×2") { actions.expandKeyTwice() }
                Button("Esc") { actions.send(.escape) }
                Spacer()
            }
            .controlSize(.small)
        }
    }

    // MARK: Round

    private var round: some View {
        GroupBox("回合（回答方那一侧发生的事）") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("处理结果").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    Button("已回答 → 摘要卡") { actions.send(.processingFinished(.answered)) }
                    Button("已送达") { actions.send(.processingFinished(.delivered(RehearsalData.deliveryTarget))) }
                    Button("没有输入框 → 保留卡") { actions.send(.processingFinished(.retained(IslandRehearsal.voiceFlowKeptScript))) }
                    Button("关掉保留卡") { actions.send(.dismissRetained) }
                    Spacer()
                }
                HStack(spacing: 8) {
                    Text("回答中").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    Button("工具开始") { actions.send(.toolsInFlight(true)) }
                    Button("一条进展") { actions.send(.progressNote(RehearsalData.current.notes.randomElement() ?? "Reading the delivery log")) }
                    Button("工具返回") { actions.send(.toolReturned) }
                    Button("工具结束") { actions.send(.toolsInFlight(false)) }
                    Button("回答完成") { actions.send(.answerFinished) }
                    Button("回答失败") { actions.send(.answerFailed(RehearsalData.current.failureMessage ?? "Codex could not finish this answer. Retry the question.")) }
                    Button("+3 附件") { actions.send(.materialsCaptured(3)) }
                    Spacer()
                }
                HStack(spacing: 8) {
                    Text("浮卡").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    Button("拖出") { actions.send(.detach) }
                    Button("靠近岛") { actions.send(.setDockZone(.near)) }
                    Button("就位") { actions.send(.setDockZone(.ready)) }
                    Button("贴回") { actions.send(.redock) }
                    Button("关闭会话") { actions.send(.closeQuickAnswer) }
                    Spacer()
                }
            }
            .controlSize(.small)
        }
    }

    // MARK: Data

    private var data: some View {
        GroupBox("数据（本机真实回合）") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("案例", selection: Binding(get: { state.caseIndex }, set: { actions.selectCase($0) })) {
                    ForEach(Array(state.cases.enumerated()), id: \.offset) { i, label in Text(label).tag(i) }
                }
                HStack {
                    Text("流式：每 \(state.intervalMs) 毫秒 \(state.chunkSize) 字")
                    Slider(value: Binding(get: { Double(state.intervalMs) }, set: { actions.setPace(chunk: state.chunkSize, interval: Int($0)) }), in: 10...200, step: 5)
                }
                Text("换案例会回到静息；问题、回答、材料、进展行随之更换。").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .controlSize(.small)
        }
    }

    // MARK: Display & recording

    private var display: some View {
        GroupBox("显示与录制") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("动画放慢", selection: Binding(get: { state.slowMotion }, set: { actions.setSlowMotion($0) })) {
                    Text("1×").tag(1.0); Text("2×").tag(2.0); Text("5×").tag(5.0)
                }
                .pickerStyle(.segmented)
                HStack {
                    Button(state.isRecording ? "■ 停止录屏" : "● 开始录屏") { actions.toggleRecording() }
                    Text(state.isRecording ? "录制中…" : "存到 rendered/").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .controlSize(.small)
        }
    }

    // MARK: Status

    private var status: some View {
        GroupBox("状态与事件") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 14) {
                    label("阶段", state.phase)
                    label("密度", state.density)
                    label("去向", state.destination)
                    if state.menuOpen { label("高亮", "\(state.highlight)") }
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(state.events.enumerated()), id: \.offset) { i, line in
                                Text(line).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).id(i)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 96)
                    .onChange(of: state.events.count) { _, n in if n > 0 { proxy.scrollTo(n - 1, anchor: .bottom) } }
                }
            }
        }
    }

    private func label(_ name: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(name).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 11.5, design: .monospaced)).lineLimit(1)
        }
    }
}
