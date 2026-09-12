import AppKit
import SwiftUI
import FoveaCore
import ImageIO
import UniformTypeIdentifiers

/// `--demo island-rehearsal[:auto|:record]`: walks the product's Quick Answer flow on the
/// engine's surface for design review — hold-to-talk recording row, processing rail,
/// summary card, the expand key's single tap (full panel) and double tap (reading),
/// a VoiceFlow interruption that delivers and one that keeps its text, tear-off, dock,
/// close. Content and data are the product's (real history); the shape and motion are
/// the engine's. A caption under the island names each step. Manual mode steps on Space;
/// the real left-Control tap works at any time; Esc closes. `record` captures the screen
/// region around the notch at 20 fps and writes a video.
@MainActor
enum IslandRehearsal {
    struct Step {
        let title: String
        let detail: String
        /// Events with the pause (ms) after each; the step is "settled" after the last.
        let events: [(IslandEvent?, Int)]
    }

    static let voiceFlowScript = "把刚才的结论整理成三条，发到当前对话里。"
    static let voiceFlowKeptScript = "这个问题先记下来，等会儿贴到设计文档的第三节。"
    /// Two clean taps within this window are a double tap.
    static let doubleTapWindow: TimeInterval = 0.3

    /// Services for the rehearsal: simulated everything, with the product's real text.
    static func services(from base: IslandServices) -> IslandServices {
        var s = base
        // Read the current case at use time, so the console can switch cases live.
        s.transcriber = AlternatingTranscriber(scripts: { [RehearsalData.current.question, voiceFlowScript, voiceFlowKeptScript] })
        s.agent = RehearsalAgentService(answer: { RehearsalData.current.answer }, startDelay: 4.2,
                                        tasks: SimulatedAgentService(shortAnswer: "", longAnswer: ""))
        s.meter = IslandServices.simulated().meter
        return s
    }

    static func run(controller: IslandController, mode: String) {
        let session = Session(controller: controller, mode: mode)
        Self.session = session
        session.start()
        if mode == "console" {
            let console = IslandRehearsalConsole(session: session)
            Self.console = console
            console.show()
        }
    }

    private static var session: Session?
    private static var console: IslandRehearsalConsole?

    // MARK: - Steps (the product's rounds)

    static var steps: [Step] {
        let d = RehearsalData.current
        let notes = d.notes + ["Reading the delivery log", "Comparing both receipts"]
        let choices = FoveaDestinationPanel.choices(query: "", data: d)
        let gridStart = FoveaDestinationPanel.gridStart(data: d)
        let picked = choices[min(gridStart + 4, choices.count - 1)]
        return [
            Step(title: "静息", detail: "什么都没发生时刘海是光的，岛不显示。", events: [(nil, 1200)]),
            Step(title: "按住提问键", detail: "岛长出录音条：波形、去向「自动 L⌃」、附件数、Esc。按住期间材料陆续被采集。",
                 events: [(.hotkeyDown(.quickAnswer), 700), (.materialsCaptured(3), 600), (.materialsCaptured(d.chips.count), 900)]),
            Step(title: "录音中按左 Control：选择会话", detail: "岛横向展开成会话选择：「自动」「Codex +」、搜索与筛选、最近会话卡片（本机真实会话）、键盘提示。",
                 events: [(.toggleDestinationMenu, 2200)]),
            Step(title: "↓ 移动、回车：选一个旧会话", detail: "高亮沿卡片移动，回车选中；面板收回录音条，去向胶囊换成所选会话。",
                 events: [(.destinationMove(by: gridStart, count: choices.count), 500), (.destinationMove(by: 3, count: choices.count), 500),
                          (.destinationMove(by: 1, count: choices.count), 600), (.commitDestination(picked), 1600)]),
            Step(title: "松手：处理", detail: "同一条岛换成处理行：sparkles、「正在准备提问」、底部进度轨。",
                 events: [(.hotkeyUp(.quickAnswer), 1800)]),
            Step(title: "岛长出摘要卡", detail: "处理完成，表面长成摘要卡：「问题已提交」、用时、展开提示。",
                 events: [(.processingFinished(.answered), 1500)]),
            Step(title: "回合进行", detail: "工具调用与公开进展行更新摘要卡；随后回答正文开始流式，状态词跟着变。",
                 events: [(.toolsInFlight(true), 200), (.progressNote(notes[0]), 900), (.toolReturned, 700),
                          (.progressNote(notes[1]), 900), (.toolReturned, 700), (.toolReturned, 600),
                          (.toolsInFlight(false), 2200)]),
            Step(title: "左 Control 单击：展开", detail: "摘要卡长成完整面板（宽 560，内容高 420）：身份条、固定问题、材料、正文、进度行、动作行。",
                 events: [(.toggleQuickAnswerDensity, 2400)]),
            Step(title: "左 Control 双击：阅读态", detail: "同一块表面长到屏幕大部分：宽最多 960，高到屏幕底部留 24，正文行宽限制 720 居中。",
                 events: [(.doubleTapExpandKey, 2600)]),
            Step(title: "单击：回到完整", detail: "阅读态收回完整面板。", events: [(.toggleQuickAnswerDensity, 1800)]),
            Step(title: "单击：收起摘要卡", detail: "完整面板收回摘要卡，回答仍在进行。", events: [(.toggleQuickAnswerDensity, 1600)]),
            Step(title: "VoiceFlow 插入：按住", detail: "摘要卡让位，收成 VoiceFlow 录音条（蓝色波形、Esc）；回答在后面继续。",
                 events: [(.hotkeyDown(.voiceFlow), 900), (.materialsCaptured(2), 800)]),
            Step(title: "松手：处理 → 已送达 → 回来", detail: "处理行 → 「已送达 Claude」停 0.55 秒 → 岛空出来，摘要卡以原密度回来。",
                 events: [(.hotkeyUp(.voiceFlow), 1600), (.processingFinished(.delivered(RehearsalData.deliveryTarget)), 2400)]),
            Step(title: "VoiceFlow：没有输入框", detail: "再来一次，这次找不到输入框：岛留下「已为你保留」卡（复制 / 投递到这个输入框 / 再投递一次）。",
                 events: [(.hotkeyDown(.voiceFlow), 700), (.materialsCaptured(1), 600), (.hotkeyUp(.voiceFlow), 1500),
                          (.processingFinished(.retained(voiceFlowKeptScript)), 2400)]),
            Step(title: "关掉保留卡", detail: "岛空出来，摘要卡以原密度回来。", events: [(.dismissRetained, 1800)]),
            Step(title: "展开后拖出", detail: "左 Control 展开，拖把手把面板拖成浮卡；岛回到光刘海。",
                 events: [(.toggleQuickAnswerDensity, 1600), (.detach, 1800)]),
            Step(title: "拖回岛", detail: "靠近：岛张开接收口；就位：松手贴回，长回完整面板。",
                 events: [(.setDockZone(.near), 900), (.setDockZone(.ready), 900), (.redock, 1800)]),
            Step(title: "Esc 关闭", detail: "完整面板收回，岛回到光刘海。", events: [(.escape, 1400)]),
        ]
    }

    // MARK: - Session

    @MainActor
    final class Session {
        let controller: IslandController
        let mode: String
        private let caption = CaptionPanel()
        private var monitor: Any?
        private var controlArmed = false
        private var lastTapAt: Date?
        private(set) var index = -1 { didSet { onStepChanged?(index) } }
        private var stepping = false
        private(set) var recorder: Recorder?
        private var autoTask: Task<Void, Never>?
        /// The console mirrors these.
        var onStepChanged: ((Int) -> Void)?
        var isAutoPlaying: Bool { autoTask != nil }
        var isRecording: Bool { recorder != nil }
        var stepCount: Int { steps.count }
        var stepTitles: [(String, String)] { steps.map { ($0.title, $0.detail) } }
        private var usesCaption: Bool { mode != "console" }

        // MARK: Console API

        func stepNext() { Task { @MainActor in await self.advance() } }

        func stepPrevious() {
            let target = max(0, index - 1)
            jump(to: target)
        }

        /// Replays every step up to `target` without pauses, then shows it.
        func jump(to target: Int) {
            stopAuto()
            model.reset()
            guard target >= 0, target < steps.count else { index = -1; return }
            for k in 0...target {
                for (event, _) in steps[k].events { if let event { model.send(event) } }
            }
            index = target
            if usesCaption { caption.update(step: (target + 1, steps[target]), total: steps.count, mode: mode) }
        }

        func restartFromConsole() { stopAuto(); restart() }

        func toggleAuto() {
            if autoTask != nil { stopAuto(); return }
            autoTask = Task { @MainActor in
                let from = index + 1
                for i in from..<steps.count {
                    if Task.isCancelled { break }
                    index = i
                    await perform(steps[i], number: i + 1)
                }
                autoTask = nil
            }
        }

        func stopAuto() { autoTask?.cancel(); autoTask = nil }

        func startRecording() {
            guard recorder == nil else { return }
            recorder = Recorder(metrics: controller.model.metrics, panel: controller.panel)
            recorder?.start()
        }

        func stopRecording() async -> URL? {
            guard let recorder else { return nil }
            self.recorder = nil
            await recorder.finish()
            return recorder.directory
        }

        init(controller: IslandController, mode: String) {
            self.controller = controller
            self.mode = mode
        }

        var model: IslandModel { controller.model }

        func start() {
            if usesCaption {
                caption.show(below: controller.model.metrics)
                caption.update(step: nil, total: steps.count, mode: mode)
            }
            installMonitor()
            if mode != "manual" {
                // An unattended run must never take the keyboard: while a recording ran, the
                // panel became key and swallowed keystrokes typed into another app.
                controller.model.onRequestKey = {}
            }
            if mode == "record" {
                recorder = Recorder(metrics: controller.model.metrics, panel: controller.panel)
                recorder?.start()
            }
            if mode == "auto" || mode == "record" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    await self.runAll()
                }
            }
        }

        private func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self else { return event }
                return MainActor.assumeIsolated { self.observe(event) ? nil : event }
            }
        }

        /// Returns true when the event was consumed.
        private func observe(_ event: NSEvent) -> Bool {
            switch event.type {
            case .flagsChanged:
                guard event.keyCode == 59 else { controlArmed = false; return false }
                if event.modifierFlags.contains(.control) {
                    controlArmed = event.modifierFlags.intersection([.command, .option, .shift]).isEmpty && NSEvent.pressedMouseButtons == 0
                } else {
                    let fire = controlArmed; controlArmed = false
                    if fire { expandKeyTapped() }
                }
                return false
            case .keyDown:
                controlArmed = false
                if model.state.destinationMenuOpen, pickerKey(event) { return true }
                switch event.keyCode {
                case 49: // space
                    guard mode == "manual" else { return false }
                    Task { @MainActor in await self.advance() }
                    return true
                case 53: // esc
                    model.send(.escape)
                    return true
                case 15 where event.modifierFlags.contains(.command): // ⌘R restart
                    restart()
                    return true
                default:
                    return false
                }
            default:
                controlArmed = false
                return false
            }
        }

        /// Keys inside the conversation picker: arrows move the highlight (three columns of
        /// cards), Return commits, Delete edits the filter, other characters type into it.
        private func pickerKey(_ event: NSEvent) -> Bool {
            let choices = FoveaDestinationPanel.choices(query: model.state.destinationQuery, data: RehearsalData.current)
            let gridStart = FoveaDestinationPanel.gridStart(data: RehearsalData.current)
            let h = model.state.destinationHighlight
            switch event.keyCode {
            case 126: model.send(.destinationMove(by: h >= gridStart + 3 ? -3 : -1, count: choices.count)); return true
            case 125: model.send(.destinationMove(by: h >= gridStart ? 3 : 1, count: choices.count)); return true
            case 123: model.send(.destinationMove(by: -1, count: choices.count)); return true
            case 124: model.send(.destinationMove(by: 1, count: choices.count)); return true
            case 36:
                let i = min(max(0, model.state.destinationHighlight), choices.count - 1)
                model.send(.commitDestination(choices[i])); return true
            case 51:
                model.send(.destinationSearch(String(model.state.destinationQuery.dropLast()))); return true
            default:
                guard let chars = event.characters, !chars.isEmpty, !event.modifierFlags.contains(.command),
                      chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return false }
                model.send(.destinationSearch(model.state.destinationQuery + chars)); return true
            }
        }

        /// The first tap acts at once; a second tap inside the window converts to the
        /// reading density instead, so a single tap never waits. While recording the tap
        /// means the destination (the product rule), with no double-tap meaning.
        private func expandKeyTapped() {
            if model.phase == .listening {
                lastTapAt = nil
                model.send(.toggleDestinationMenu)
                return
            }
            let now = Date()
            if let last = lastTapAt, now.timeIntervalSince(last) <= IslandRehearsal.doubleTapWindow {
                lastTapAt = nil
                model.send(.doubleTapExpandKey)
            } else {
                lastTapAt = now
                model.send(.toggleQuickAnswerDensity)
            }
        }

        private func restart() {
            model.reset()
            index = -1
            if usesCaption { caption.update(step: nil, total: steps.count, mode: mode) }
        }

        private func advance() async {
            guard !stepping else { return }
            let next = index + 1
            guard next < steps.count else {
                restart()
                return
            }
            stepping = true
            index = next
            await perform(steps[next], number: next + 1)
            stepping = false
        }

        private func runAll() async {
            index = -1
            for (i, step) in steps.enumerated() {
                index = i
                await perform(step, number: i + 1)
            }
            if usesCaption { caption.update(step: nil, total: steps.count, mode: mode, finished: true) }
            if let recorder, mode != "console" {
                await recorder.finish()
                print("rehearsal recorded → \(recorder.directory.path)")
                NSApp.terminate(nil)
            }
        }

        private func perform(_ step: Step, number: Int) async {
            if usesCaption { caption.update(step: (number, step), total: steps.count, mode: mode) }
            for (event, pause) in step.events {
                if let event { model.send(event) }
                try? await Task.sleep(for: .milliseconds(pause))
            }
            recorder?.markStill(number: number, title: step.title)
            // The still is the next captured frame; give the capture thread that frame before
            // the next step's first event changes the picture.
            if recorder != nil { try? await Task.sleep(for: .milliseconds(120)) }
        }
    }

    // MARK: - Caption

    @MainActor
    final class CaptionPanel {
        private var panel: NSPanel?
        private let state = CaptionState()

        func show(below metrics: ScreenMetrics) {
            let width: CGFloat = 640, height: CGFloat = 84
            // Under the tallest surface the sequence shows; the reading density is the exception
            // and the caption sits on it, which is fine for review.
            let bottom = max(metrics.frame.minY, metrics.visibleFrame.minY)
            let frame = CGRect(x: metrics.frame.midX - width / 2, y: bottom + 120, width: width, height: height)
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: CaptionView(state: state))
            panel.orderFrontRegardless()
            self.panel = panel
        }

        func update(step: (Int, Step)?, total: Int, mode: String, finished: Bool = false) {
            panel?.orderFrontRegardless()
            state.number = step?.0 ?? 0
            state.total = total
            state.title = finished ? "排练结束" : (step?.1.title ?? "岛过渡排练")
            state.detail = finished ? (mode == "manual" ? "按空格从头再来。" : "已走完全部步骤。")
                : (step?.1.detail ?? (mode == "manual" ? "按空格开始第一步。" : "自动播放中。"))
            state.hint = mode == "manual"
                ? "空格 下一步 · 左 Control 单击 摘要/完整 · 双击 阅读态 · Esc 关闭 · ⌘R 重来"
                : "左 Control 单击切摘要/完整，双击进阅读态 · Esc 关闭"
            let productRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.fovea.mac").isEmpty
            if productRunning { state.hint = "⚠︎ 正式版 Fovea 正在运行，它的岛会和排练重叠，请先退出它 · " + state.hint }
        }
    }

    @Observable @MainActor
    final class CaptionState {
        var number = 0
        var total = 0
        var title = ""
        var detail = ""
        var hint = ""
    }

    struct CaptionView: View {
        let state: CaptionState
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if state.number > 0 {
                        Text("步骤 \(state.number)/\(state.total)")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(state.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                Text(state.detail).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                Text(state.hint).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.16, green: 0.17, blue: 0.20).opacity(0.94)))
            .padding(6)
        }
    }

    // MARK: - Recorder

    /// Captures the top-centre of the display at 20 fps on a background thread, so the
    /// animations on the main thread are untouched, and writes the video at the real
    /// capture timing. Falls back to the panel's own image over a flat backdrop when the
    /// process may not record the screen.
    final class Recorder: @unchecked Sendable {
        let directory: URL
        private let metrics: ScreenMetrics
        private let displayID: CGDirectDisplayID?
        private let windowID: CGWindowID?
        private let region: CGRect
        private let lock = NSLock()
        private var stopped = false
        private var frames: [(name: String, time: TimeInterval)] = []
        private var stills: [(Int, String, String)] = []
        private var screenCaptureWorks: Bool?
        private var pendingStill: (Int, String)?
        private var thread: Thread?

        @MainActor
        init(metrics: ScreenMetrics, panel: NSPanel?) {
            self.metrics = metrics
            let screen = NSScreen.screens.first(where: { $0.frame == metrics.frame }) ?? NSScreen.main
            displayID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
            windowID = panel.map { CGWindowID($0.windowNumber) }
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("rendered/rehearsal-\(stamp)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Display-local, top-left origin, points. Tall enough for the reading density.
            // Wide enough for the conversation picker (1280 + its margins), tall enough for the
            // reading density.
            let width: CGFloat = min(metrics.frame.width, 1360), height: CGFloat = min(metrics.frame.height, 1000)
            region = CGRect(x: (metrics.frame.width - width) / 2, y: 0, width: width, height: height)
        }

        private var startedAbsolute: CFAbsoluteTime = 0
        private var pending: [(index: Int, image: CGImage, still: (Int, String)?)] = []
        private var encoders: [Thread] = []
        private let encoderLimit = 24

        /// The capture thread only grabs the screen; PNG encoding (the slow part) runs on
        /// three encoder threads behind a bounded queue, which roughly triples the frame rate.
        func start() {
            startedAbsolute = CFAbsoluteTimeGetCurrent()
            for _ in 0..<3 {
                let e = Thread { [self] in
                    while true {
                        lock.lock()
                        let item = pending.isEmpty ? nil : pending.removeFirst()
                        let done = stopped && pending.isEmpty
                        lock.unlock()
                        guard let item else { if done { return }; Thread.sleep(forTimeInterval: 0.004); continue }
                        let name = String(format: "frame-%05d", item.index)
                        if write(item.image, named: name), let still = item.still {
                            let stillName = String(format: "step-%02d", still.0)
                            try? FileManager.default.removeItem(at: directory.appendingPathComponent(stillName + ".png"))
                            try? FileManager.default.linkItem(at: directory.appendingPathComponent(name + ".png"),
                                                              to: directory.appendingPathComponent(stillName + ".png"))
                            lock.lock(); stills.append((still.0, stillName, still.1)); lock.unlock()
                        }
                    }
                }
                e.qualityOfService = .userInitiated
                e.start()
                encoders.append(e)
            }
            let t = Thread { [self] in
                let interval: TimeInterval = 1.0 / 30.0
                var index = 0
                let started = Date()
                while true {
                    lock.lock(); let done = stopped; let backlog = pending.count; lock.unlock()
                    if done { break }
                    // Wait for the encoders without touching the pending still: consuming it
                    // here and then skipping the frame lost that step's still whenever the
                    // backlog was full.
                    if backlog >= encoderLimit { Thread.sleep(forTimeInterval: 0.005); continue }
                    let tick = Date()
                    if let image = grab() {
                        let name = String(format: "frame-%05d", index)
                        lock.lock()
                        let still = pendingStill; pendingStill = nil
                        frames.append((name, tick.timeIntervalSince(started)))
                        pending.append((index, image, still))
                        lock.unlock()
                        index += 1
                    }
                    let elapsed = Date().timeIntervalSince(tick)
                    if elapsed < interval { Thread.sleep(forTimeInterval: interval - elapsed) }
                }
            }
            t.qualityOfService = .userInteractive
            t.start()
            thread = t
        }

        /// The next captured frame is also saved as this step's still.
        func markStill(number: Int, title: String) {
            lock.lock(); pendingStill = (number, title); lock.unlock()
        }

        func finish() async {
            // Let the last step's still be captured before the capture thread stops.
            try? await Task.sleep(for: .milliseconds(250))
            lock.lock(); stopped = true; lock.unlock()
            while thread?.isFinished == false || encoders.contains(where: { !$0.isFinished }) { try? await Task.sleep(for: .milliseconds(30)) }
            lock.lock(); let frames = self.frames; let stills = self.stills.sorted { $0.0 < $1.0 }; lock.unlock()
            guard frames.count > 1 else { return }
            // Real timing: each frame lasts until the next one was taken.
            var list = ""
            for (i, f) in frames.enumerated() {
                let next = i + 1 < frames.count ? frames[i + 1].time : f.time + 0.05
                list += "file '\(f.name).png'\nduration \(String(format: "%.4f", max(0.01, next - f.time)))\n"
            }
            list += "file '\(frames.last!.name).png'\n"
            let listURL = directory.appendingPathComponent("frames.txt")
            try? list.write(to: listURL, atomically: true, encoding: .utf8)
            let ffmpeg = "/opt/homebrew/bin/ffmpeg"
            guard FileManager.default.isExecutableFile(atPath: ffmpeg) else { return }
            let mp4 = directory.appendingPathComponent("rehearsal.mp4").path
            let gif = directory.appendingPathComponent("rehearsal.gif").path
            await run(ffmpeg, ["-y", "-f", "concat", "-safe", "0", "-i", listURL.path, "-vsync", "vfr",
                               "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-pix_fmt", "yuv420p", mp4])
            await run(ffmpeg, ["-y", "-i", mp4, "-vf", "fps=12,scale=780:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse", gif])
            let fps = Double(frames.count) / max(0.1, frames.last!.time - frames.first!.time)
            let index = stills.map { "\($0.1).png\t\($0.2)" }.joined(separator: "\n")
            try? (index + "\n").write(to: directory.appendingPathComponent("steps.tsv"), atomically: true, encoding: .utf8)
            try? String(format: "%d frames, %.1f s, %.1f fps captured\nstarted=%.3f\n", frames.count, frames.last!.time - frames.first!.time, fps, startedAbsolute)
                .write(to: directory.appendingPathComponent("timing.txt"), atomically: true, encoding: .utf8)
            var times = ""
            for f in frames { times += String(format: "%@\t%.3f\n", f.name, startedAbsolute + f.time) }
            try? times.write(to: directory.appendingPathComponent("frame-times.tsv"), atomically: true, encoding: .utf8)
        }

        private func run(_ launchPath: String, _ args: [String]) async {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                let p = Process()
                p.executableURL = URL(fileURLWithPath: launchPath)
                p.arguments = args
                p.standardOutput = FileHandle.nullDevice
                p.standardError = FileHandle.nullDevice
                p.terminationHandler = { _ in c.resume() }
                do { try p.run() } catch { c.resume() }
            }
        }

        private func write(_ image: CGImage, named name: String) -> Bool {
            let url = directory.appendingPathComponent(name + ".png")
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
            CGImageDestinationAddImage(dest, image, nil)
            return CGImageDestinationFinalize(dest)
        }

        private func grab() -> CGImage? {
            if screenCaptureWorks != false, let image = grabScreen() {
                if screenCaptureWorks == nil {
                    screenCaptureWorks = !Self.looksBlank(image)
                    if screenCaptureWorks == false { print("rehearsal: screen capture blank (no Screen Recording permission?) — falling back to the island window") }
                }
                if screenCaptureWorks == true { return image }
            }
            screenCaptureWorks = false
            return grabWindow()
        }

        private func grabScreen() -> CGImage? {
            guard let displayID else { return nil }
            return CGDisplayCreateImage(displayID, rect: region)
        }

        private func grabWindow() -> CGImage? {
            guard let windowID else { return nil }
            let bounds = CGRect(x: metrics.frame.minX + region.minX, y: region.minY, width: region.width, height: region.height)
            guard let island = CGWindowListCreateImage(bounds, [.optionIncludingWindow], windowID, [.bestResolution]) else { return nil }
            let scale = CGFloat(island.width) / region.width
            let width = island.width, height = island.height
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.setFillColor(CGColor(red: 0.80, green: 0.82, blue: 0.83, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let menuBar = metrics.safeAreaTop > 0 ? metrics.safeAreaTop : 25
            ctx.setFillColor(CGColor(gray: 0.93, alpha: 1))
            ctx.fill(CGRect(x: 0, y: CGFloat(height) - menuBar * scale, width: CGFloat(width), height: menuBar * scale))
            ctx.draw(island, in: CGRect(x: 0, y: 0, width: width, height: height))
            return ctx.makeImage()
        }

        private static func looksBlank(_ image: CGImage) -> Bool {
            guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return true }
            let count = CFDataGetLength(data)
            guard count > 64 else { return true }
            let stride = max(1, count / 4096)
            let first: UInt8 = ptr[0]
            var i = 0
            while i < count { if ptr[i] != first { return false }; i += stride }
            return true
        }
    }
}

// MARK: - Rehearsal data (the product's real history)

/// One real turn for the rehearsal: the question and answer, the round's materials,
/// the agent's public progress lines and tool count. From `FOVEA_REHEARSAL_DATA`, the
/// bundle's `rehearsal-data.json`, or the built-in fixture.
struct RehearsalData {
    struct Chip {
        let label: String
        let kind: String
        let image: NSImage?
    }

    /// One of the machine's recent conversations, for the picker (product
    /// `QuickAnswerDestinationEntry`): title, provider, last activity, turns, availability.
    struct Conversation: Identifiable {
        let id: String
        let provider: String
        let title: String
        let lastActivity: Date
        let turnCount: Int
        let resumable: Bool
        let workspace: String

        var availabilityLabel: String { resumable ? "可继续提问" : "暂不能在这里续聊" }
        var relativeTime: String {
            let minutes = Int(Date().timeIntervalSince(lastActivity) / 60)
            if minutes < 1 { return "刚刚" }
            if minutes < 60 { return "\(minutes) 分钟前" }
            if minutes < 60 * 24 { return "\(minutes / 60) 小时前" }
            return "\(minutes / (60 * 24)) 天前"
        }
    }

    let title: String
    let model: String
    let question: String
    let answer: String
    let chips: [Chip]
    let notes: [String]
    let toolCount: Int
    let durationMs: Int
    let conversations: [Conversation]
    /// The console's case label ("长回答 · 表格与代码"); the default case has none.
    var caseLabel: String = ""
    var status: String = "completed"
    var failureMessage: String? = nil

    /// Every case the data file offers; `current` is the one on stage. The console switches.
    nonisolated(unsafe) static var cases: [RehearsalData] = []
    nonisolated(unsafe) static var currentIndex = 0
    static func select(_ index: Int) {
        guard index >= 0, index < cases.count else { return }
        currentIndex = index
        current = cases[index]
    }
    /// Providers that are on and connected, in the product's order; the picker offers a
    /// new conversation with each and marks its rows.
    var providers: [String] {
        let present = Set(conversations.map(\.provider))
        return ["codex", "claude-code", "cursor"].filter { present.contains($0) }
    }

    static let deliveryTarget = "Claude"
    nonisolated(unsafe) static var current: RehearsalData = load()

    /// "codex:gpt-6-astra:max" → "GPT-6-Astra · 最高", as the product's attribution row reads.
    var modelLabel: String {
        let parts = model.split(separator: ":").map(String.init)
        let name = parts.count > 1 ? parts[1] : model
        let strength: String? = parts.count > 2 ? parts[2] : nil
        let pretty = name.split(separator: "-").map { $0.lowercased() == "gpt" ? "GPT" : $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "-")
        let level = ["max": "最高", "high": "高", "medium": "中", "low": "低"][strength ?? ""] ?? strength
        return level.map { "\(pretty) · \($0)" } ?? pretty
    }

    /// "GPT-6-Astra", the model alone, for narrow headers.
    var modelName: String { modelLabel.components(separatedBy: " · ").first ?? modelLabel }

    static func load() -> RehearsalData {
        let sampleConversations: [Conversation] = [
            ("codex", "Quick Answer 意图路由设计", 3, 12, true), ("claude-code", "材料采集：剪贴板与截图", 26, 41, true),
            ("codex", "灵动岛过渡动画排练", 70, 8, true), ("claude-code", "Zotero 取材插件可行性", 300, 2, false),
            ("codex", "润色模型回归定位", 900, 17, true), ("codex", "采集任务卡需求基线", 2600, 5, false),
        ].enumerated().map { i, c in
            Conversation(id: "sample-\(i)", provider: c.0, title: c.1, lastActivity: Date().addingTimeInterval(-Double(c.2) * 60), turnCount: c.3, resumable: c.4, workspace: "")
        }
        let fallback = RehearsalData(title: "Fovea 与 Codex 连接：功能与验收", model: "codex:gpt-6-astra:max",
                                     question: Fixtures.quickAnswerQuestion, answer: Fixtures.quickAnswerLong,
                                     chips: [], notes: ["Locating recent logs", "Reading the delivery log"], toolCount: 4, durationMs: 129_000,
                                     conversations: sampleConversations)
        let url: URL? = ProcessInfo.processInfo.environment["FOVEA_REHEARSAL_DATA"].map { URL(fileURLWithPath: $0) }
            ?? Bundle.main.url(forResource: "rehearsal-data", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let question = json["question"] as? String, let answer = json["answer"] as? String,
              !question.isEmpty, !answer.isEmpty else { return fallback }
        let conversations = (json["conversations"] as? [[String: Any]] ?? []).enumerated().map { i, c -> Conversation in
            Conversation(id: "conversation-\(i)", provider: c["provider"] as? String ?? "codex", title: c["title"] as? String ?? "",
                         lastActivity: Date(timeIntervalSince1970: c["lastActivity"] as? Double ?? 0),
                         turnCount: c["turnCount"] as? Int ?? 1,
                         resumable: (c["availability"] as? String) == "resumable",
                         workspace: c["workspace"] as? String ?? "")
        }
        let chips = (json["chips"] as? [[String: Any]] ?? []).map { c -> Chip in
            let image = (c["imageBase64"] as? String).flatMap { Data(base64Encoded: $0) }.flatMap { NSImage(data: $0) }
            return Chip(label: c["label"] as? String ?? "材料", kind: c["kind"] as? String ?? "text", image: image)
        }
        let base = RehearsalData(
            title: json["title"] as? String ?? fallback.title,
            model: json["model"] as? String ?? fallback.model,
            question: question, answer: answer, chips: chips,
            notes: json["notes"] as? [String] ?? fallback.notes,
            toolCount: (json["tools"] as? [Any])?.count ?? fallback.toolCount,
            durationMs: json["durationMs"] as? Int ?? fallback.durationMs,
            conversations: conversations.isEmpty ? sampleConversations : conversations)
        // Further cases share the model and the machine's conversations; only the turn differs.
        var all: [RehearsalData] = []
        for (i, c) in (json["cases"] as? [[String: Any]] ?? []).enumerated() {
            guard let q = c["question"] as? String, let a = c["answer"] as? String else { continue }
            let caseChips = i == 0 ? chips : (c["chips"] as? [[String: Any]] ?? []).map { Chip(label: $0["label"] as? String ?? "材料", kind: $0["kind"] as? String ?? "text", image: nil) }
            var item = RehearsalData(title: c["title"] as? String ?? base.title, model: base.model, question: q, answer: a, chips: caseChips,
                                     notes: c["notes"] as? [String] ?? [], toolCount: (c["tools"] as? [Any])?.count ?? 0,
                                     durationMs: c["durationMs"] as? Int ?? 60_000, conversations: base.conversations)
            item.caseLabel = c["label"] as? String ?? "案例 \(i + 1)"
            item.status = c["status"] as? String ?? "completed"
            item.failureMessage = c["failureMessage"] as? String
            all.append(item)
        }
        cases = all.isEmpty ? [base] : all
        return cases[0]
    }
}

/// Two sessions, two scripts: the Quick Answer question first, then the VoiceFlow lines.
@MainActor
final class AlternatingTranscriber: Transcribing {
    private let scripts: () -> [String]
    private var index = 0
    private var current: SimulatedTranscriber?

    init(scripts: @escaping () -> [String]) { self.scripts = scripts }

    func start() async throws -> AsyncThrowingStream<TranscriptChunk, Error> {
        let list = scripts()
        let transcriber = SimulatedTranscriber(script: list[index % list.count])
        index += 1
        current = transcriber
        return try await transcriber.start()
    }

    func finish() { current?.finish() }
    func cancel() { current?.cancel() }
}

/// Streams the real answer a few characters at a time after a start delay (the round's
/// tool calls come first); delivery and task updates come from the simulation.
@MainActor
final class RehearsalAgentService: AgentServicing {
    private let answerProvider: () -> String
    private let startDelay: TimeInterval
    private let tasks: SimulatedAgentService
    /// Streaming pace, adjustable from the console.
    nonisolated(unsafe) static var chunkSize = 5
    nonisolated(unsafe) static var intervalMs = 45

    init(answer: @escaping () -> String, startDelay: TimeInterval, tasks: SimulatedAgentService) {
        self.answerProvider = answer; self.startDelay = startDelay; self.tasks = tasks
    }

    var taskUpdates: AsyncStream<AgentTask> { tasks.taskUpdates }

    func deliver(_ draft: ReviewDraft, to route: ChatRoute) async throws -> AgentTask {
        try await tasks.deliver(draft, to: route)
    }

    func ask(_ question: String, history: [String]) -> AsyncThrowingStream<String, Error> {
        let answer = answerProvider()
        let size = max(1, Self.chunkSize)
        let chunks = stride(from: 0, to: answer.count, by: size).map { start -> String in
            let from = answer.index(answer.startIndex, offsetBy: start)
            let to = answer.index(from, offsetBy: size, limitedBy: answer.endIndex) ?? answer.endIndex
            return String(answer[from..<to])
        }
        let delay = startDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                for chunk in chunks {
                    if Task.isCancelled { continuation.finish(); return }
                    continuation.yield(chunk)
                    try? await Task.sleep(for: .milliseconds(max(5, Self.intervalMs)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
