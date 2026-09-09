import Foundation

/// Named Island states for `--demo island:<name>`, the Island menu and snapshots. Each
/// case seeds a complete `IslandState` from fixtures; the model can then resume the
/// simulated streams so the scene stays alive.
public enum IslandScenario: String, CaseIterable, Hashable, Sendable {
    case resting
    case hover
    case hoverScroll
    case listAfterSend
    case listening
    case transcribing
    case failureRetry
    case microphoneDenied
    case reviewCollapsed
    case reviewExpandedStack
    case reviewStackHover
    case selectorRecent
    case selectorNewChatAI
    case selectorNewChatContext
    case selectorSearchAI
    case selectorSearchQuery
    case reviewResolving
    case sendFailed
    case qaStreaming
    case qaLong
    case qaFollowUp
    case qaError
    case qaDetached
    case qaManyTurns
    case qaDockReady

    /// `island:hover` → `.hover`.
    public static func parse(_ flag: String) -> IslandScenario? {
        guard flag.hasPrefix("island:") else { return nil }
        return IslandScenario(rawValue: String(flag.dropFirst("island:".count)))
    }

    public var title: String {
        switch self {
        case .resting: return "Resting"
        case .hover: return "Agent list"
        case .hoverScroll: return "Agent list (overflow)"
        case .listAfterSend: return "Agent list (after Send)"
        case .listening: return "Listening"
        case .transcribing: return "Transcribing"
        case .failureRetry: return "Didn’t catch that (Retry)"
        case .microphoneDenied: return "Microphone denied"
        case .reviewCollapsed: return "Review"
        case .reviewExpandedStack: return "Review (referents expanded)"
        case .reviewStackHover: return "Review (referent preview)"
        case .selectorRecent: return "Chat selector (recent)"
        case .selectorNewChatAI: return "Chat selector (New Chat · AI)"
        case .selectorNewChatContext: return "Chat selector (New Chat · folder)"
        case .selectorSearchAI: return "Chat selector (Search · AI)"
        case .selectorSearchQuery: return "Chat selector (Search · results)"
        case .reviewResolving: return "Review (route resolving)"
        case .sendFailed: return "Send failed"
        case .qaStreaming: return "Quick Answer (streaming)"
        case .qaLong: return "Quick Answer (long)"
        case .qaFollowUp: return "Quick Answer (follow-up)"
        case .qaError: return "Quick Answer (error)"
        case .qaDetached: return "Quick Answer (detached)"
        case .qaManyTurns: return "Quick Answer (many questions)"
        case .qaDockReady: return "Quick Answer (docking)"
        }
    }

    /// Whether the simulated streams should continue after seeding (waveform, tokens…).
    public var isLive: Bool {
        switch self {
        case .listening, .transcribing, .qaStreaming, .reviewResolving, .failureRetry, .listAfterSend: return true
        default: return false
        }
    }

    public func apply(to s: inout IslandState, now: Date = Date()) {
        s = IslandState()
        s.tasks = Fixtures.agentTasks(now: now)
        let menu = Fixtures.chatRouteMenu(now: now)
        func review(_ mutate: (inout ReviewDraft) -> Void = { _ in }) {
            var draft = ReviewDraft(transcript: Fixtures.transcriptScript, referents: Fixtures.reviewReferents)
            draft.routes = .resolved(menu)
            draft.selectedRoute = menu.recommended
            mutate(&draft)
            s.review = draft
            s.phase = .review
        }
        func quickAnswer(_ mutate: (inout QuickAnswerState) -> Void = { _ in }) {
            var qa = QuickAnswerState(question: Fixtures.quickAnswerQuestion)
            qa.answer = Fixtures.quickAnswerShort
            qa.streaming = false
            mutate(&qa)
            s.quickAnswer = qa
            s.phase = .quickAnswer(.attached)
        }

        switch self {
        case .resting:
            break
        case .hover:
            s.phase = .agentList
            s.pointerZone = .inside
            s.hoverArmed = false
        case .hoverScroll:
            s.tasks = Fixtures.agentTasks(now: now) + Fixtures.moreAgentTasks(now: now)
            s.phase = .agentList
            s.pointerZone = .inside
            s.hoverArmed = false
        case .listAfterSend:
            let sent = Fixtures.sentTask(now: now)
            s.tasks = Fixtures.agentTasks(now: now) + [sent]
            s.phase = .agentList
            s.recentlySentTaskId = sent.id
            s.hoverArmed = false
        case .listening:
            s.sessionKind = .voiceFlow
            s.phase = .listening
        case .transcribing:
            s.sessionKind = .voiceFlow
            s.phase = .transcribing
            s.partialTranscript = String(Fixtures.transcriptScript.prefix(52))
        case .failureRetry:
            s.sessionKind = .voiceFlow
            s.capturedReferents = Fixtures.reviewReferents
            s.phase = .transcriptionFailed(IslandFailure("Didn’t catch that.", recovery: .retry))
        case .microphoneDenied:
            s.phase = .transcriptionFailed(IslandFailure("Fovea needs microphone access to listen.",
                                                         recovery: .openSettings(.microphone)))
        case .reviewCollapsed:
            review()
        case .reviewExpandedStack:
            review { $0.stackExpanded = true }
        case .reviewStackHover:
            review { $0.stackExpanded = true; $0.hoveredReferentId = "isl-mountain" }
        case .selectorRecent:
            review { $0.selector = .recent }
        case .selectorNewChatAI:
            review { $0.selector = .newChatAI }
        case .selectorNewChatContext:
            review { $0.selector = .newChatContext(Fixtures.claudeCode); $0.folders = Fixtures.contextFolders }
        case .selectorSearchAI:
            review { $0.selector = .searchAI }
        case .selectorSearchQuery:
            review {
                $0.selector = .searchQuery(Fixtures.codex)
                $0.searchText = "routing"
                $0.searchResults = Fixtures.chatSearchResults(now: now)
            }
        case .reviewResolving:
            review { $0.routes = .resolving; $0.selectedRoute = nil }
        case .sendFailed:
            review()
            s.phase = .sendFailed(IslandFailure("Couldn’t reach Claude Code.", recovery: .retry))
        case .qaStreaming:
            quickAnswer { qa in
                qa.answer = String(Fixtures.quickAnswerShort.prefix(88))
                qa.streaming = true
            }
        case .qaLong:
            quickAnswer { $0.answer = Fixtures.quickAnswerLong }
        case .qaFollowUp:
            quickAnswer { qa in
                qa.turns = [QuickAnswerTurn(question: Fixtures.quickAnswerQuestion, answer: Fixtures.quickAnswerShort)]
                qa.question = Fixtures.quickAnswerFollowUp
                qa.answer = Fixtures.quickAnswerFollowUpAnswer
            }
        case .qaError:
            quickAnswer { qa in
                qa.answer = ""
                qa.error = "The answer timed out."
            }
        case .qaDetached:
            quickAnswer()
            s.phase = .quickAnswer(.detached)
        case .qaManyTurns:
            quickAnswer { qa in
                qa.turns = [QuickAnswerTurn(question: Fixtures.quickAnswerQuestion, answer: Fixtures.quickAnswerShort)]
                    + Fixtures.quickAnswerMoreTurns
                qa.question = Fixtures.quickAnswerFollowUp
                qa.answer = Fixtures.quickAnswerFollowUpAnswer
            }
        case .qaDockReady:
            // The floating panel is within reach: the notch has opened its receiver.
            quickAnswer()
            s.phase = .quickAnswer(.detached)
            s.dockZone = .ready
        }
    }
}
