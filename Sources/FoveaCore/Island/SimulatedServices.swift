import Foundation

// Deterministic stand-ins for every Island service. Timings are scaled by
// `SimulatedTiming.scale` so tests can run them instantly.

public struct SimulatedTiming: Sendable {
    /// 1 = real-time demo pacing; 0 = no waiting (tests).
    public var scale: Double
    public init(scale: Double = 1) { self.scale = scale }

    public static let live = SimulatedTiming(scale: 1)
    public static let instant = SimulatedTiming(scale: 0)

    func sleep(_ milliseconds: Double) async throws {
        let ms = milliseconds * scale
        guard ms > 0 else { await Task.yield(); return }
        try await Task.sleep(for: .milliseconds(ms))
    }
}

/// Small deterministic generator so waveform and scripts are stable across runs.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Hotkeys

/// Never fires. Used by snapshots and tests; the app drives events through the model directly.
@MainActor public final class NoHotkeys: HotkeyMonitoring {
    public let events: AsyncStream<HotkeyEvent>
    private let continuation: AsyncStream<HotkeyEvent>.Continuation
    public init() {
        var c: AsyncStream<HotkeyEvent>.Continuation!
        events = AsyncStream { c = $0 }
        continuation = c
    }
    public func start(bindings: [ShortcutAction: KeyBinding]) throws {}
    public func update(bindings: [ShortcutAction: KeyBinding]) throws {}
    public func setEscapeCapture(_ enabled: Bool) {}
    public func setSuspended(_ suspended: Bool) {}
    public func setRecordingSink(_ sink: (@MainActor (FunctionKeyTransition) -> Void)?) {}
    public func stop() { continuation.finish() }
}

// MARK: - Microphone

/// Speech-like bursts at 30 Hz.
@MainActor public final class SimulatedAudioMeter: AudioLevelMetering {
    private let timing: SimulatedTiming
    private var task: Task<Void, Never>?
    public init(timing: SimulatedTiming = .live) { self.timing = timing }

    public func start() async throws -> AsyncStream<Float> {
        AsyncStream { continuation in
            task = Task { [timing] in
                var rng = SeededGenerator(seed: 7)
                var level: Float = 0.1
                var phase = 0.0
                while !Task.isCancelled {
                    phase += 0.09
                    // A slow envelope (syllables) with fast jitter on top.
                    let envelope = Float(max(0, sin(phase) * 0.6 + sin(phase * 2.7) * 0.3))
                    let jitter = Float.random(in: -0.12...0.12, using: &rng)
                    let target = min(1, max(0.06, envelope + jitter))
                    level = level * 0.55 + target * 0.45
                    continuation.yield(level)
                    do { try await timing.sleep(33) } catch { break }
                    if timing.scale == 0 { break }
                }
                continuation.finish()
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Transcription

/// Emits the script word by word while "listening", then the final transcript shortly
/// after `finish()`.
@MainActor public final class SimulatedTranscriber: Transcribing {
    public var script: String
    /// Fail the next session once, for the error state.
    public var failNext = false
    /// Hear nothing next session once, for the Retry state.
    public var emptyNext = false
    private let timing: SimulatedTiming
    private let lock = NSLock()
    private var finished = false
    private var cancelled = false
    private var task: Task<Void, Never>?

    public init(script: String, timing: SimulatedTiming = .live) {
        self.script = script; self.timing = timing
    }

    public func start() async throws -> AsyncThrowingStream<TranscriptChunk, Error> {
        lock.withLock { finished = false; cancelled = false }
        return run(speakingPace: 210)
    }

    public func finish() { lock.withLock { finished = true } }

    public func cancel() {
        lock.withLock { cancelled = true }
        task?.cancel()
        task = nil
    }

    private func run(speakingPace: Double) -> AsyncThrowingStream<TranscriptChunk, Error> {
        let words = emptyNext ? [] : script.split(separator: " ").map(String.init)
        let shouldFail = failNext
        failNext = false
        emptyNext = false
        return AsyncThrowingStream { continuation in
            task = Task { [timing] in
                var emitted: [String] = []
                for word in words {
                    let done = lock.withLock { finished }
                    do { try await timing.sleep(done ? 60 : speakingPace) } catch { continuation.finish(); return }
                    if Task.isCancelled || lock.withLock({ cancelled }) { continuation.finish(); return }
                    emitted.append(word)
                    continuation.yield(.partial(emitted.joined(separator: " ")))
                }
                // Wait for the hotkey to be pressed again, then settle.
                while !lock.withLock({ finished }) {
                    if Task.isCancelled { continuation.finish(); return }
                    do { try await timing.sleep(30) } catch { continuation.finish(); return }
                    if timing.scale == 0 { break }
                }
                do { try await timing.sleep(320) } catch { continuation.finish(); return }
                if Task.isCancelled || lock.withLock({ cancelled }) { continuation.finish(); return }
                if shouldFail {
                    continuation.finish(throwing: ServiceUnavailable("Transcription failed.", recovery: .retry))
                } else {
                    continuation.yield(.final(emitted.joined(separator: " ")))
                    continuation.finish()
                }
            }
        }
    }
}

// MARK: - Chat catalog

/// The fixture Chats, folders and destinations behind the selector.
@MainActor public final class SimulatedChatCatalog: ChatCatalog {
    public var chats: [ChatRoute]
    public var folders: [ContextFolder]
    public var choices: [DestinationChoice]
    private let timing: SimulatedTiming
    private let now: @Sendable () -> Date

    public init(chats: [ChatRoute], folders: [ContextFolder], choices: [DestinationChoice],
                timing: SimulatedTiming = .live, now: @escaping @Sendable () -> Date = { Date() }) {
        self.chats = chats; self.folders = folders; self.choices = choices
        self.timing = timing; self.now = now
    }

    public func recent(within window: TimeInterval) async throws -> [ChatRoute] {
        let cutoff = now().addingTimeInterval(-window)
        return chats
            .filter { ($0.lastActiveAt ?? .distantPast) >= cutoff }
            .sorted { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }
            .prefix(ChatRouteMenu.maxRecent)
            .map { $0 }
    }

    public func destinations() async throws -> [DestinationChoice] { choices }

    public func folders(for destination: AppRef) async throws -> [ContextFolder] {
        try await timing.sleep(120)
        return folders
    }

    /// Case-insensitive substring match on the Chat name, most recent first.
    public func search(_ query: String, in destination: AppRef) async throws -> [ChatRoute] {
        try await timing.sleep(180)
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        return chats
            .filter { $0.destination == destination && $0.chatName.lowercased().contains(needle) }
            .sorted { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }
    }
}

// MARK: - Routing

@MainActor public final class SimulatedChatRouting: ChatRouting {
    public var recommended: ChatRoute
    public var failNext = false
    private let catalog: any ChatCatalog
    private let timing: SimulatedTiming

    public init(recommended: ChatRoute, catalog: any ChatCatalog, timing: SimulatedTiming = .live) {
        self.recommended = recommended; self.catalog = catalog; self.timing = timing
    }

    public func resolve(for draft: ReviewDraft) async throws -> ChatRouteMenu {
        try await timing.sleep(650)
        if failNext { failNext = false; throw ServiceUnavailable("Couldn’t reach Claude Code.", recovery: .retry) }
        let recent = try await catalog.recent(within: ChatRouteMenu.recentWindow)
        let destinations = try await catalog.destinations()
        return ChatRouteMenu(recommended: recommended, original: nil, recent: recent,
                             new: .newChat(in: recommended.destination), destinations: destinations)
    }
}

// MARK: - Agent

@MainActor public final class SimulatedAgentService: AgentServicing {
    public var shortAnswer: String
    public var longAnswer: String
    /// Fail delivery once, for the Send-failed state.
    public var failNextDelivery = false
    /// Fail the next answer after this many tokens.
    public var failNextAnswerAfter: Int?
    public let taskUpdates: AsyncStream<AgentTask>
    private let updates: AsyncStream<AgentTask>.Continuation
    private let timing: SimulatedTiming
    private var followers: [Task<Void, Never>] = []

    public init(shortAnswer: String, longAnswer: String, timing: SimulatedTiming = .live) {
        self.shortAnswer = shortAnswer; self.longAnswer = longAnswer; self.timing = timing
        var c: AsyncStream<AgentTask>.Continuation!
        taskUpdates = AsyncStream { c = $0 }
        updates = c
    }

    public func deliver(_ draft: ReviewDraft, to route: ChatRoute) async throws -> AgentTask {
        try await timing.sleep(450)
        if failNextDelivery {
            failNextDelivery = false
            throw ServiceUnavailable("Couldn’t reach \(route.destination.name).", recovery: .retry)
        }
        let id = "task-\(UUID().uuidString.prefix(6))"
        let task = AgentTask(id: id, title: Self.title(for: draft.transcript), state: .working,
                             destination: route.destination, chatName: route.pillTitle, activity: "Reading the request",
                             updatedAt: Date(), captureId: "cap-\(id)")
        // Scripted life: reading → editing → complete, so the list has something to say.
        let follower = Task { [timing, updates] in
            var t = task
            do { try await timing.sleep(2_500) } catch { return }
            t.activity = "Editing the empty state view"
            t.updatedAt = Date()
            updates.yield(t)
            do { try await timing.sleep(6_500) } catch { return }
            t.state = .complete
            t.activity = "Ready to review"
            t.updatedAt = Date()
            updates.yield(t)
        }
        followers.append(follower)
        return task
    }

    public func ask(_ question: String, history: [String]) -> AsyncThrowingStream<String, Error> {
        let answer = question.count > 60 || history.count > 0 ? longAnswer : shortAnswer
        let tokens = Self.tokens(answer)
        let failAfter = failNextAnswerAfter
        failNextAnswerAfter = nil
        return AsyncThrowingStream { continuation in
            let task = Task { [timing] in
                do { try await timing.sleep(500) } catch { continuation.finish(); return }
                for (i, token) in tokens.enumerated() {
                    if Task.isCancelled { continuation.finish(); return }
                    if let failAfter, i >= failAfter {
                        continuation.finish(throwing: ServiceUnavailable("The answer timed out.", recovery: .retry))
                        return
                    }
                    continuation.yield(token)
                    do { try await timing.sleep(26) } catch { continuation.finish(); return }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// First clause of the transcript, sentence-cased, as a task title.
    static func title(for transcript: String) -> String {
        let firstClause = transcript.split(whereSeparator: { ",.;:!?".contains($0) }).first.map(String.init) ?? transcript
        let words = firstClause.split(separator: " ").prefix(6).joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Words with their trailing whitespace, so streaming preserves line breaks.
    static func tokens(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == " " || ch == "\n" { out.append(current); current = "" }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }
}

// MARK: - Bundle

extension IslandServices {
    /// Every service simulated, with the standard fixtures.
    public static func simulated(timing: SimulatedTiming = .live) -> IslandServices {
        let catalog = SimulatedChatCatalog(chats: Fixtures.chatCatalog(), folders: Fixtures.contextFolders,
                                           choices: Fixtures.destinationChoices, timing: timing)
        return IslandServices(hotkeys: NoHotkeys(),
                              meter: SimulatedAudioMeter(timing: timing),
                              transcriber: SimulatedTranscriber(script: Fixtures.transcriptScript, timing: timing),
                              routing: SimulatedChatRouting(recommended: Fixtures.chatRouteMenu.recommended,
                                                            catalog: catalog, timing: timing),
                              catalog: catalog,
                              agent: SimulatedAgentService(shortAnswer: Fixtures.quickAnswerShort,
                                                           longAnswer: Fixtures.quickAnswerLong, timing: timing))
    }
}
