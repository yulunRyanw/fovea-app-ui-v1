import Foundation

// The Island's state machine data. Pure values; the reducer moves between them and the
// UI target executes the effects with real or simulated services.

public enum QuickAnswerPlacement: Hashable, Sendable {
    case attached, detached
}

/// How close a dragged Quick Answer is to docking, from its top-center to the notch's.
/// `near` opens the island's receiver; `ready` means release will dock.
public enum DockZone: Int, Hashable, Sendable, Comparable {
    case outside, near, ready
    public static func < (lhs: DockZone, rhs: DockZone) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Something went wrong and the user has one way out.
public struct IslandFailure: Hashable, Sendable {
    public enum Recovery: Hashable, Sendable {
        case retry
        case openSettings(SystemPermission)
        case openMainApp
        case none
    }
    public let message: String
    public let recovery: Recovery

    public init(_ message: String, recovery: Recovery = .retry) {
        self.message = message; self.recovery = recovery
    }
}

public enum IslandPhase: Hashable, Sendable {
    case resting
    case agentList
    case listening
    case transcribing
    case transcriptionFailed(IslandFailure)
    case review
    case sending
    case sendFailed(IslandFailure)
    case quickAnswer(QuickAnswerPlacement)

    /// Listening, Transcribing and the Retry state share one outer size: the notch's
    /// width, grown downward.
    public var isVoice: Bool {
        switch self {
        case .listening, .transcribing, .transcriptionFailed: return true
        default: return false
        }
    }
    public var isReview: Bool {
        switch self {
        case .review, .sending, .sendFailed: return true
        default: return false
        }
    }
    public var isQuickAnswer: Bool {
        if case .quickAnswer = self { return true }
        return false
    }
    /// The notch shows the Quick Answer slab only while it is attached.
    public var showsSlab: Bool { self == .quickAnswer(.attached) }

    public var density: NotchGeometry.Density {
        switch self {
        case .resting: return .resting
        case .quickAnswer(.detached): return .resting
        case .agentList: return .list
        case .listening, .transcribing, .transcriptionFailed: return .voice
        case .review, .sending, .sendFailed: return .review
        case .quickAnswer(.attached): return .slab
        }
    }

    /// Phases that share a layout keep one identity, so edits inside them never re-run
    /// the content transition.
    public var layoutKey: String {
        switch self {
        case .resting, .quickAnswer(.detached): return "resting"
        case .agentList: return "list"
        case .listening: return "listening"
        case .transcribing: return "transcribing"
        case .transcriptionFailed: return "failed"
        case .review, .sending, .sendFailed: return "review"
        case .quickAnswer(.attached): return "qa"
        }
    }
}

/// Where the Chat selector is in its flow. Each step goes back one at a time.
public enum SelectorStep: Hashable, Sendable {
    case closed
    /// Recent Chats across every destination, plus New Chat and Search Chats.
    case recent
    case newChatAI
    case newChatContext(AppRef)
    case searchAI
    case searchQuery(AppRef)

    public var isOpen: Bool { self != .closed }

    /// One step back (back chevron / Escape); nil when already closed.
    public var previous: SelectorStep? {
        switch self {
        case .closed: return nil
        case .recent: return .closed
        case .newChatAI, .searchAI: return .recent
        case .newChatContext: return .newChatAI
        case .searchQuery: return .searchAI
        }
    }
}

public struct ReviewDraft: Hashable, Sendable {
    public var transcript: String
    public var referents: [Referent]
    public var routes: RouteResolution = .resolving
    public var selectedRoute: ChatRoute?
    public var selector: SelectorStep = .closed
    public var stackExpanded = false
    /// Referent open in the inspection view, if any.
    public var inspectingReferentId: String?
    /// Referent under the pointer while the stack is fanned out; it shows a larger preview.
    public var hoveredReferentId: String?
    /// Search Chats: the query and what it found (for the destination in `selector`).
    public var searchText = ""
    public var searchResults: [ChatRoute] = []
    /// New Chat: folders the chosen destination can start in.
    public var folders: [ContextFolder] = []

    public init(transcript: String, referents: [Referent] = []) {
        self.transcript = transcript; self.referents = referents
    }

    public var selectorOpen: Bool { selector.isOpen }

    /// Send needs words and a destination; nothing else is required.
    public var canSend: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedRoute != nil
    }
}

public struct QuickAnswerTurn: Hashable, Sendable {
    public let question: String
    public let answer: String
    public init(question: String, answer: String) { self.question = question; self.answer = answer }
}

public struct QuickAnswerState: Hashable, Sendable {
    public var question: String
    public var answer: String = ""
    public var streaming = true
    public var error: String?
    public var followUp = ""
    /// Earlier turns of this session; the header shows the latest question.
    public var turns: [QuickAnswerTurn] = []

    public init(question: String) { self.question = question }

    public var history: [String] { turns.flatMap { [$0.question, $0.answer] } }
}

public struct IslandState: Hashable, Sendable {
    public var phase: IslandPhase = .resting
    /// Which hotkey started the current voice session.
    public var sessionKind: ShortcutAction = .voiceFlow
    public var partialTranscript = ""
    /// Referents captured for the session in flight, attached to the review draft.
    public var capturedReferents: [Referent] = []
    public var review: ReviewDraft?
    public var quickAnswer: QuickAnswerState?
    public var tasks: [AgentTask] = []
    /// Where the pointer is, as reported by the tracker (target geometry, never the
    /// animating shape).
    public var pointerZone: PointerZone = .outside
    public var pointerInside: Bool { pointerZone != .outside }
    /// A hover may open the list only after the pointer has been outside since the last
    /// collapse, so a collapse under a parked pointer never reopens by itself.
    public var hoverArmed = true
    /// A dwell timer is running for the pointer resting on the notch.
    public var hoverDwellPending = false
    public var focusInside = false
    /// Held > 0 while something outside the island (a detached panel, a menu) needs it to stay put.
    public var pinCount = 0
    /// The task Send just created; the list highlights it and stays for a moment.
    public var recentlySentTaskId: String?
    /// The Retry countdown ran out while the pointer was over the island; collapse on exit.
    public var failureHold = false
    /// How close a dragged Quick Answer is to docking; from `near` the island opens its receiver.
    public var dockZone: DockZone = .outside
    /// One-line, non-blocking message (a hotkey conflict, for instance).
    public var notice: String?
    /// Task list rows sorted per PRD.
    public var visibleTasks: [AgentTask] { AgentTask.sorted(tasks) }

    /// A detached Quick Answer dragged close turns the resting notch into the receiver.
    public var showsReceiver: Bool { phase == .quickAnswer(.detached) && dockZone != .outside }
    /// The island's target geometry: the phase's, or the receiver while docking.
    public var density: NotchGeometry.Density { showsReceiver ? .receiver : phase.density }
    /// Content identity for the crossfade; the receiver has its own, shared by `near` and
    /// `ready` so brightening is never a crossfade.
    public var layoutKey: String { showsReceiver ? "dock" : phase.layoutKey }

    public init() {}
}

public enum HapticKind: Hashable, Sendable { case alignment, levelChange }

public enum IslandEvent: Hashable, Sendable {
    // Hotkeys. `hotkeyPressed` is what the keyboard sends: it toggles between the two
    // primitives, which drive scenarios and tests directly.
    case hotkeyPressed(ShortcutAction)
    case hotkeyDown(ShortcutAction), hotkeyUp(ShortcutAction)
    // Pointer / focus
    case pointerZoneChanged(PointerZone), hoverDwellElapsed, exitGraceElapsed
    case focusChanged(Bool)
    case pin, unpin
    // Capture
    case referentsCaptured([Referent])
    case audioFailed(IslandFailure)
    case transcriptPartial(String), transcriptFinal(String), transcriptionFailed(IslandFailure)
    case failureCountdownElapsed
    // Review
    case routesResolved(ChatRouteMenu), routesFailed, retryRoutes
    case editTranscript(String)
    case toggleSelector, selectorBack, selectorNewChat, selectorSearch
    case chooseDestination(AppRef), foldersLoaded(AppRef, [ContextFolder]), chooseFolder(ContextFolder?)
    case editSearch(String), searchResults(query: String, [ChatRoute])
    case chooseRoute(ChatRoute)
    case setStackExpanded(Bool), hoverReferent(String?), inspectReferent(String?), removeReferent(String)
    case send, sent(AgentTask), sendFailed(IslandFailure), sentGraceElapsed
    // Quick Answer
    case answerToken(String), answerFinished, answerFailed(String)
    case editFollowUp(String), submitFollowUp
    case detach, redock, setDockZone(DockZone), closeQuickAnswer
    // Tasks
    case tasksChanged([AgentTask]), takeMeThere(String)
    // Generic
    case retry, cancel, escape
    case notice(String?)
}

public enum IslandEffect: Hashable, Sendable {
    case startMetering, stopMetering
    case startTranscription, finishTranscription, cancelTranscription
    case resolveRoutes(ReviewDraft)
    case loadFolders(AppRef)
    case searchChats(AppRef, String), cancelSearch
    case deliver(ReviewDraft, ChatRoute)
    case ask(question: String, history: [String])
    case cancelAsk
    case scheduleHoverDwell, cancelHoverDwell
    case scheduleExitGrace, cancelExitGrace
    case scheduleSentGrace, cancelSentGrace
    case scheduleFailureCountdown, cancelFailureCountdown
    case presentDetached, dismissDetached
    case requestKey, releaseKey, focusEditor, focusFollowUp, focusSearch
    case openTask(String)
    case openSettings(SystemPermission)
    case openMainApp
    case haptic(HapticKind)
}
