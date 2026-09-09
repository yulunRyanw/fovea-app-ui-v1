import Foundation

// Service boundaries the Island talks to. Real implementations live in the app's
// Platform layer; the simulated ones (SimulatedServices.swift) drive demos, snapshots
// and tests deterministically.

public enum HotkeyEvent: Hashable, Sendable {
    /// The shortcut was pressed. Shortcuts toggle: the first press starts a session, the
    /// next press ends it. Key repeat and the release never reach the Island.
    case pressed(ShortcutAction)
    /// Escape pressed while it is being captured (Listening / Transcribing).
    case escape
}

/// One edge of the fn key as the platform sees it, for the shortcut recorder.
public struct FunctionKeyTransition: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case down
        /// Released; `usedWithKey` when another key was pressed while fn was held.
        case up(usedWithKey: Bool)
    }
    public let kind: Kind
    /// ⌃ ⌥ ⇧ ⌘ held at any point while fn was down.
    public let modifiers: KeyBinding.Modifiers
    public init(kind: Kind, modifiers: KeyBinding.Modifiers) { self.kind = kind; self.modifiers = modifiers }
}

public struct ServiceUnavailable: Error, Hashable, Sendable {
    public let failure: IslandFailure
    public init(_ failure: IslandFailure) { self.failure = failure }
    public init(_ message: String, recovery: IslandFailure.Recovery = .none) {
        self.failure = IslandFailure(message, recovery: recovery)
    }
}

/// Global press-to-toggle hotkeys for VoiceFlow and Quick Answer.
@MainActor public protocol HotkeyMonitoring: AnyObject {
    var events: AsyncStream<HotkeyEvent> { get }
    /// Registers the given bindings; throws when a chord is taken by another app or a
    /// permission is missing. Bindings that could be registered keep working.
    func start(bindings: [ShortcutAction: KeyBinding]) throws
    func update(bindings: [ShortcutAction: KeyBinding]) throws
    /// While listening, Escape is captured globally so the user can cancel without focus.
    func setEscapeCapture(_ enabled: Bool)
    /// While the Shortcuts page records a new chord, presses must not start a session.
    func setSuspended(_ suspended: Bool)
    /// The Shortcuts page listens to raw fn edges through this while recording.
    func setRecordingSink(_ sink: (@MainActor (FunctionKeyTransition) -> Void)?)
    func stop()
}

/// Microphone input level, 0…1, ~30 Hz, already shaped for the waveform.
@MainActor public protocol AudioLevelMetering: AnyObject {
    func start() async throws -> AsyncStream<Float>
    func stop()
}

public enum TranscriptChunk: Hashable, Sendable {
    case partial(String)
    case final(String)
}

/// Streams partial transcripts from the start of the session; `finish()` ends the audio
/// and the stream completes with `.final`. A failed session is retried by listening again.
@MainActor public protocol Transcribing: AnyObject {
    func start() async throws -> AsyncThrowingStream<TranscriptChunk, Error>
    func finish()
    func cancel()
}

/// Predicts which Chat should receive a draft.
@MainActor public protocol ChatRouting: AnyObject {
    func resolve(for draft: ReviewDraft) async throws -> ChatRouteMenu
}

/// What the Chat selector can browse: recent Chats, destinations for a new one, the
/// folders a destination can start in, and a search scoped to one destination.
@MainActor public protocol ChatCatalog: AnyObject {
    /// Most recent first, at most `ChatRouteMenu.maxRecent`.
    func recent(within window: TimeInterval) async throws -> [ChatRoute]
    func destinations() async throws -> [DestinationChoice]
    func folders(for destination: AppRef) async throws -> [ContextFolder]
    func search(_ query: String, in destination: AppRef) async throws -> [ChatRoute]
}

/// Hands payloads to the user's Agent and streams Quick Answers back.
@MainActor public protocol AgentServicing: AnyObject {
    /// Delivers and returns the task the Agent is now working on.
    func deliver(_ draft: ReviewDraft, to route: ChatRoute) async throws -> AgentTask
    /// Streams answer tokens for a Quick Answer turn.
    func ask(_ question: String, history: [String]) -> AsyncThrowingStream<String, Error>
    /// Later state changes for delivered tasks.
    var taskUpdates: AsyncStream<AgentTask> { get }
}

/// Everything the Island needs, bundled so the composition root picks real or simulated.
@MainActor public struct IslandServices {
    public var hotkeys: any HotkeyMonitoring
    public var meter: any AudioLevelMetering
    public var transcriber: any Transcribing
    public var routing: any ChatRouting
    public var catalog: any ChatCatalog
    public var agent: any AgentServicing

    public init(hotkeys: any HotkeyMonitoring, meter: any AudioLevelMetering, transcriber: any Transcribing,
                routing: any ChatRouting, catalog: any ChatCatalog, agent: any AgentServicing) {
        self.hotkeys = hotkeys; self.meter = meter; self.transcriber = transcriber
        self.routing = routing; self.catalog = catalog; self.agent = agent
    }
}
