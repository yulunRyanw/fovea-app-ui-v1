import SwiftUI
import FoveaCore

/// Multiplies every tokens duration, so an entrance can be studied at 3× or checked at 0.5×.
enum LabMotion {
    nonisolated(unsafe) static var scale: Double = 1
}

enum LabDirection: String, CaseIterable, Identifiable {
    case paper, studio, spaces, threads
    var id: String { rawValue }
    var title: String {
        switch self {
        case .paper: return "Paper"
        case .studio: return "Studio"
        case .spaces: return "Spaces"
        case .threads: return "Threads"
        }
    }
}

enum LabCanvas: String, CaseIterable, Identifiable {
    case white = "FFFFFF", warm = "FBFAF7", field = "F8F6EF"
    var id: String { rawValue }
    var color: Color { Color(hex: UInt32(rawValue, radix: 16)!) }
    var nsColor: NSColor { NSColor(color) }
    var title: String { "#" + rawValue }
}

/// A Chat as the lab sees it: the captures sent to one Chat in one destination.
struct LabSpace: Identifiable, Hashable {
    let id: String
    let name: String
    let destination: AppRef
    let captures: [Capture]          // newest first
    let task: AgentTask?             // the most important live task, if any
    /// The same Chat name exists in another destination, so the destination must be said.
    var ambiguous = false
    var newest: Capture { captures[0] }
    /// "in Cursor", only when the name alone would not do.
    var qualifier: String? { ambiguous ? "in \(destination.name)" : nil }
}

@MainActor @Observable
final class LabState {
    var direction: LabDirection = .paper
    var docked = true
    var showsNeck = true
    var canvas: LabCanvas = .warm
    var motionScale: Double = 1 { didSet { LabMotion.scale = motionScale } }
    var reduceMotion = false
    var paletteVisible = true

    private(set) var captureLog: CaptureLog
    private(set) var ledger: TaskLedger
    /// The capture the Island just handed down, while a direction acknowledges it.
    private(set) var recentCaptureId: String?
    /// The open row, tile or space, by capture or space id. One at a time.
    var openId: String?
    /// Threads: the selected Chat (a LabSpace id). Spaces: the open space.
    var selectedSpaceId: String?
    var searchQuery = ""
    var searchVisible = false
    /// Studio zoom level: 0 small, 1 default, 2 large.
    var studioZoom = 1

    private var acknowledgeTask: Task<Void, Never>?
    private var sent = 0

    init() {
        captureLog = CaptureLog(captures: Fixtures.captures())
        ledger = TaskLedger(tasks: Fixtures.agentTasks())
    }

    // MARK: Reading

    var captures: [Capture] { captureLog.captures }
    var filteredCaptures: [Capture] { CaptureSearch.filter(captures, query: searchQuery) }
    func task(for capture: Capture) -> AgentTask? { ledger.tasks.first { $0.captureId == capture.id } }
    func capture(for task: AgentTask) -> Capture? { task.captureId.flatMap { captureLog.capture($0) } }

    /// Live tasks in the Island's order, each with its capture.
    var now: [(task: AgentTask, capture: Capture)] {
        ledger.sorted.compactMap { t in capture(for: t).map { (t, $0) } }
    }

    /// Captures grouped by Chat, needs-you first, then by the newest capture.
    var spaces: [LabSpace] {
        var byKey: [String: [Capture]] = [:]
        var order: [String] = []
        for c in captures {
            let name = c.chatName ?? (c.intent == .quickAnswer ? "Quick Answer" : (c.destinationApp?.name ?? "Fovea"))
            let key = "\(c.destinationApp?.id ?? "fovea")/\(name)"
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(c)
        }
        let spaces = order.map { key -> LabSpace in
            let caps = byKey[key]!.sorted { $0.createdAt > $1.createdAt }
            let tasks = caps.compactMap { task(for: $0) }
            let top = AgentTask.sorted(tasks).first
            let name = caps[0].chatName ?? (caps[0].intent == .quickAnswer ? "Quick Answer" : (caps[0].destinationApp?.name ?? "Fovea"))
            let dest = caps[0].destinationApp ?? AppRef(id: "fovea", name: "Fovea", symbol: "sparkle")
            return LabSpace(id: key, name: name, destination: dest, captures: caps, task: top)
        }
        var counts: [String: Int] = [:]
        for s in spaces { counts[s.name, default: 0] += 1 }
        return spaces.map { s in
            var s = s
            s.ambiguous = (counts[s.name] ?? 0) > 1
            return s
        }.sorted { a, b in
            let ra = a.task?.state.rank ?? 99, rb = b.task?.state.rank ?? 99
            if ra != rb { return ra < rb }
            return a.newest.createdAt > b.newest.createdAt
        }
    }

    var selectedSpace: LabSpace? {
        let all = spaces
        return all.first { $0.id == selectedSpaceId } ?? all.first
    }

    func selectSpace(offset: Int) {
        let all = spaces
        guard let current = selectedSpace, let i = all.firstIndex(of: current) else { return }
        let j = min(max(0, i + offset), all.count - 1)
        selectedSpaceId = all[j].id
    }

    // MARK: Palette actions

    private static let sampleIntents = [
        "Move the Sign Out button under the Data group and give it the same width as the rows.",
        "Make the empty state one sentence shorter and drop the second line.",
        "This spacing is wrong, match the row height in the settings shell.",
        "Use this photo for the café scene and warm it up a little.",
        "The tab order skips the retention menu, fix the focusable modifier.",
    ]

    /// What the Island does on Send: a capture lands in the log and a task in the ledger.
    func sendCapture() {
        sent += 1
        let space = selectedSpace
        let destination = space?.destination.id == "fovea" ? Fixtures.claudeCode : (space?.destination ?? Fixtures.claudeCode)
        let chat = space?.name == "Quick Answer" ? "Fovea" : (space?.name ?? "Fovea")
        let pool = Fixtures.captures().flatMap(\.referents).filter { $0.kind == .image || $0.kind == .screenshot }
        let referent = pool[(sent - 1) % max(1, pool.count)]
        let transcript = Self.sampleIntents[(sent - 1) % Self.sampleIntents.count]
        let id = "lab-\(sent)"
        let capture = Capture(id: id, intent: .voiceWithAttachment, createdAt: Date(), transcript: transcript,
                              semanticAnchors: CaptureAnchors.extract(from: transcript),
                              referents: [Referent(id: "\(id)-ref", kind: referent.kind, aspect: referent.aspect,
                                                   resource: referent.resource, filename: referent.filename,
                                                   sourceApp: referent.sourceApp, sourceWindowTitle: referent.sourceWindowTitle)],
                              sourceApp: Fixtures.xcode, destinationApp: destination, deliveryStatus: .delivered,
                              tags: ["Lab"], chatName: chat)
        captureLog.append(capture)
        ledger.upsert(AgentTask(id: "lab-task-\(sent)", title: transcript, state: .working, destination: destination,
                                chatName: chat, activity: "Reading the capture", updatedAt: Date(), captureId: id))
        acknowledge(id)
    }

    /// The newest working task stops and asks something.
    func agentNeedsYou() {
        guard let t = ledger.tasks.filter({ $0.state == .working }).max(by: { $0.updatedAt < $1.updatedAt })
                ?? ledger.tasks.max(by: { $0.updatedAt < $1.updatedAt }) else { return }
        ledger.update(id: t.id) { $0.state = .needsYou; $0.activity = "Which of the two spacings?"; $0.updatedAt = Date() }
    }

    /// The most pressing task finishes.
    func completeTask() {
        guard let t = ledger.sorted.first(where: { $0.state == .needsYou || $0.state == .working }) else { return }
        ledger.update(id: t.id) { $0.state = .complete; $0.activity = "Ready to review"; $0.updatedAt = Date() }
    }

    func reset() {
        captureLog = CaptureLog(captures: Fixtures.captures())
        ledger = TaskLedger(tasks: Fixtures.agentTasks())
        recentCaptureId = nil
        openId = nil
        selectedSpaceId = nil
        searchQuery = ""
        searchVisible = false
        sent = 0
    }

    private func acknowledge(_ id: String) {
        acknowledgeTask?.cancel()
        recentCaptureId = id
        acknowledgeTask = Task {
            try? await Task.sleep(for: Tokens.Motion.sentGrace)
            guard !Task.isCancelled else { return }
            recentCaptureId = nil
        }
    }
}
