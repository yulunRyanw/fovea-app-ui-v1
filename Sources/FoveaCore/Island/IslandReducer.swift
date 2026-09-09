import Foundation

/// The whole Island transition table in one place. Pure: given a state and an event it
/// mutates the state and returns the side effects the UI target must run.
public enum IslandReducer {

    @discardableResult
    public static func reduce(_ s: inout IslandState, _ e: IslandEvent) -> [IslandEffect] {
        switch e {

        // MARK: Hotkeys

        case .hotkeyPressed(let action):
            // Press once to start listening, press the same shortcut again to stop.
            // The other shortcut is ignored while a session is being recorded.
            guard s.phase == .listening else { return beginVoiceSession(&s, kind: action) }
            return s.sessionKind == action ? reduce(&s, .hotkeyUp(action)) : []

        case .hotkeyDown(let action):
            return beginVoiceSession(&s, kind: action)

        case .hotkeyUp:
            guard s.phase == .listening else { return [] }
            s.phase = .transcribing
            return [.stopMetering, .finishTranscription]

        // MARK: Pointer / focus

        case .pointerZoneChanged(let zone):
            s.pointerZone = zone
            switch zone {
            case .inside:
                var fx: [IslandEffect] = [.cancelExitGrace]
                if s.phase == .resting, !s.tasks.isEmpty, s.hoverArmed, !s.hoverDwellPending {
                    s.hoverDwellPending = true
                    fx.append(.scheduleHoverDwell)
                }
                return fx
            case .near:
                // Over the island's body or its slack: enough to keep an open panel open,
                // never enough to open one.
                s.hoverDwellPending = false
                var fx: [IslandEffect] = [.cancelHoverDwell]
                if s.phase == .agentList { fx.append(.cancelExitGrace) }
                return fx
            case .outside:
                s.hoverDwellPending = false
                var fx: [IslandEffect] = [.cancelHoverDwell]
                switch s.phase {
                case .resting:
                    s.hoverArmed = true
                case .agentList:
                    fx.append(.scheduleExitGrace)
                case .transcriptionFailed where s.failureHold:
                    // The countdown already ran out; the pointer leaving lets it rest.
                    fx += rest(&s)
                default:
                    break
                }
                return fx
            }

        case .hoverDwellElapsed:
            s.hoverDwellPending = false
            guard s.phase == .resting, s.pointerZone == .inside, !s.tasks.isEmpty, s.hoverArmed else { return [] }
            s.hoverArmed = false
            s.phase = .agentList
            return []

        case .exitGraceElapsed:
            guard s.phase == .agentList, !s.pointerInside, !s.focusInside, s.pinCount == 0,
                  s.recentlySentTaskId == nil else { return [] }
            return rest(&s)

        case .focusChanged(let inside):
            s.focusInside = inside
            if !inside, s.phase == .agentList, !s.pointerInside { return [.scheduleExitGrace] }
            return []

        case .pin:
            s.pinCount += 1
            return []

        case .unpin:
            s.pinCount = max(0, s.pinCount - 1)
            if s.pinCount == 0, s.phase == .agentList, !s.pointerInside { return [.scheduleExitGrace] }
            return []

        // MARK: Capture

        case .referentsCaptured(let referents):
            s.capturedReferents = referents
            return []

        case .audioFailed(let failure):
            guard s.phase == .listening || s.phase == .transcribing else { return [] }
            return [.stopMetering, .cancelTranscription] + fail(&s, failure)

        case .transcriptPartial(let text):
            guard s.phase == .listening || s.phase == .transcribing else { return [] }
            s.partialTranscript = text
            return []

        case .transcriptFinal(let text):
            guard s.phase == .listening || s.phase == .transcribing else { return [] }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            s.partialTranscript = trimmed
            guard !trimmed.isEmpty else {
                return [.stopMetering] + fail(&s, IslandFailure("Didn’t catch that.", recovery: .retry))
            }
            switch s.sessionKind {
            case .voiceFlow:
                var draft = ReviewDraft(transcript: trimmed, referents: s.capturedReferents)
                draft.routes = .resolving
                s.review = draft
                s.phase = .review
                return [.stopMetering, .resolveRoutes(draft), .requestKey, .focusEditor]
            case .quickAnswer:
                s.quickAnswer = QuickAnswerState(question: trimmed)
                s.phase = .quickAnswer(.attached)
                return [.stopMetering, .ask(question: trimmed, history: []), .requestKey, .focusFollowUp]
            }

        case .transcriptionFailed(let failure):
            guard s.phase == .listening || s.phase == .transcribing else { return [] }
            return [.stopMetering] + fail(&s, failure)

        case .failureCountdownElapsed:
            guard case .transcriptionFailed = s.phase else { return [] }
            if s.pointerInside {
                // Don't pull the surface out from under the pointer; collapse once it leaves.
                s.failureHold = true
                return []
            }
            return rest(&s)

        // MARK: Review

        case .routesResolved(let menu):
            guard s.review != nil else { return [] }
            s.review?.routes = .resolved(menu)
            if s.review?.selectedRoute == nil { s.review?.selectedRoute = menu.recommended }
            return []

        case .routesFailed:
            guard s.review != nil else { return [] }
            s.review?.routes = .failed
            return []

        case .retryRoutes:
            guard let draft = s.review else { return [] }
            s.review?.routes = .resolving
            return [.resolveRoutes(draft)]

        case .editTranscript(let text):
            guard s.review != nil else { return [] }
            s.review?.transcript = text
            return []

        case .toggleSelector:
            guard s.review != nil, s.phase == .review else { return [] }
            if s.review?.selector.isOpen == true { return closeSelector(&s) + [.focusEditor] }
            s.review?.selector = .recent
            return []

        case .selectorBack:
            guard let draft = s.review, let previous = draft.selector.previous else { return [] }
            var fx: [IslandEffect] = []
            if case .searchQuery = draft.selector { fx += clearSearch(&s) }
            s.review?.selector = previous
            if previous == .closed { fx.append(.focusEditor) }
            return fx

        case .selectorNewChat:
            guard s.review?.selector == .recent else { return [] }
            s.review?.selector = .newChatAI
            return []

        case .selectorSearch:
            guard s.review?.selector == .recent else { return [] }
            s.review?.selector = .searchAI
            return []

        case .chooseDestination(let app):
            guard let draft = s.review else { return [] }
            switch draft.selector {
            case .newChatAI:
                s.review?.selector = .newChatContext(app)
                s.review?.folders = []
                return [.loadFolders(app)]
            case .searchAI:
                s.review?.selector = .searchQuery(app)
                s.review?.searchText = ""
                s.review?.searchResults = []
                return [.focusSearch]
            default:
                return []
            }

        case .foldersLoaded(let app, let folders):
            guard s.review?.selector == .newChatContext(app) else { return [] }
            s.review?.folders = folders
            return []

        case .chooseFolder(let folder):
            guard let draft = s.review, case .newChatContext(let app) = draft.selector else { return [] }
            s.review?.selectedRoute = ChatRoute.newChat(in: app, context: folder)
            s.review?.selector = .recent
            return [.focusEditor]

        case .editSearch(let text):
            guard let draft = s.review, case .searchQuery(let app) = draft.selector else { return [] }
            s.review?.searchText = text
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                s.review?.searchResults = []
                return [.cancelSearch]
            }
            return [.searchChats(app, text)]

        case .searchResults(let query, let routes):
            guard let draft = s.review, case .searchQuery = draft.selector, draft.searchText == query else { return [] }
            s.review?.searchResults = routes
            return []

        case .chooseRoute(let route):
            guard s.review != nil else { return [] }
            s.review?.selectedRoute = route
            var fx: [IslandEffect] = []
            if s.review?.selector.isOpen == true {
                fx += clearSearch(&s)
                // Back to the recent list so the choice can be double-checked before Send.
                s.review?.selector = .recent
                fx.append(.focusEditor)
            }
            return fx

        case .setStackExpanded(let expanded):
            guard s.review != nil else { return [] }
            s.review?.stackExpanded = expanded
            if !expanded { s.review?.hoveredReferentId = nil }
            return []

        case .hoverReferent(let id):
            guard s.review != nil else { return [] }
            s.review?.hoveredReferentId = id
            return []

        case .inspectReferent(let id):
            guard s.review != nil else { return [] }
            s.review?.inspectingReferentId = id
            return []

        case .removeReferent(let id):
            guard s.review != nil else { return [] }
            s.review?.referents.removeAll { $0.id == id }
            if s.review?.inspectingReferentId == id { s.review?.inspectingReferentId = nil }
            if s.review?.hoveredReferentId == id { s.review?.hoveredReferentId = nil }
            return []

        case .send:
            guard s.phase == .review, let draft = s.review, draft.canSend, let route = draft.selectedRoute else { return [] }
            var fx = closeSelector(&s)
            s.review?.inspectingReferentId = nil
            s.review?.hoveredReferentId = nil
            s.phase = .sending
            fx.append(.deliver(draft, route))
            return fx

        case .sent(let task):
            guard s.phase == .sending else { return [] }
            upsert(task, into: &s.tasks)
            s.review = nil
            s.partialTranscript = ""
            s.capturedReferents = []
            // Acknowledge in place: the Agent list shows the new task for a moment.
            s.recentlySentTaskId = task.id
            s.hoverArmed = false
            s.phase = .agentList
            return [.releaseKey, .haptic(.levelChange), .cancelExitGrace, .scheduleSentGrace]

        case .sentGraceElapsed:
            guard s.recentlySentTaskId != nil else { return [] }
            s.recentlySentTaskId = nil
            guard s.phase == .agentList, !s.pointerInside, !s.focusInside, s.pinCount == 0 else { return [] }
            return rest(&s)

        case .sendFailed(let failure):
            guard s.phase == .sending else { return [] }
            s.phase = .sendFailed(failure)
            return []

        // MARK: Quick Answer

        case .answerToken(let token):
            guard s.quickAnswer != nil, s.phase.isQuickAnswer else { return [] }
            s.quickAnswer?.answer += token
            s.quickAnswer?.error = nil
            return []

        case .answerFinished:
            guard s.quickAnswer != nil else { return [] }
            s.quickAnswer?.streaming = false
            return []

        case .answerFailed(let message):
            guard s.quickAnswer != nil else { return [] }
            s.quickAnswer?.streaming = false
            s.quickAnswer?.error = message
            return []

        case .editFollowUp(let text):
            guard s.quickAnswer != nil else { return [] }
            s.quickAnswer?.followUp = text
            return []

        case .submitFollowUp:
            guard var qa = s.quickAnswer, s.phase.isQuickAnswer, !qa.streaming else { return [] }
            let question = qa.followUp.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty else { return [] }
            if qa.error == nil { qa.turns.append(QuickAnswerTurn(question: qa.question, answer: qa.answer)) }
            let history = qa.history
            qa.question = question
            qa.answer = ""
            qa.error = nil
            qa.streaming = true
            qa.followUp = ""
            s.quickAnswer = qa
            return [.ask(question: question, history: history)]

        case .detach:
            guard s.phase == .quickAnswer(.attached) else { return [] }
            s.phase = .quickAnswer(.detached)
            s.dockZone = .outside
            s.hoverArmed = false
            return [.presentDetached, .releaseKey]

        case .redock:
            guard s.phase == .quickAnswer(.detached) else { return [] }
            s.phase = .quickAnswer(.attached)
            s.dockZone = .outside
            return [.dismissDetached, .requestKey, .focusFollowUp]

        case .setDockZone(let zone):
            guard s.phase == .quickAnswer(.detached), s.dockZone != zone else { return [] }
            // One tick the moment release would dock; approaching and backing out are silent.
            let armed = zone == .ready
            s.dockZone = zone
            return armed ? [.haptic(.alignment)] : []

        case .closeQuickAnswer:
            return closeQuickAnswer(&s)

        // MARK: Tasks

        case .tasksChanged(let tasks):
            s.tasks = tasks
            if s.phase == .agentList, tasks.isEmpty { return leaveList(&s) }
            return []

        case .takeMeThere(let id):
            var fx: [IslandEffect] = []
            if s.phase == .agentList { fx += leaveList(&s) }
            fx.append(.openTask(id))
            return fx

        // MARK: Generic

        case .retry:
            switch s.phase {
            case .transcriptionFailed(let failure):
                switch failure.recovery {
                case .retry:
                    // Retry means listen again, with the same referents.
                    return [.cancelFailureCountdown] + beginVoiceSession(&s, kind: s.sessionKind, keepReferents: true)
                case .openSettings(let permission):
                    return [.openSettings(permission)]
                case .openMainApp:
                    return [.openMainApp]
                case .none:
                    return []
                }
            case .sendFailed(let failure):
                switch failure.recovery {
                case .openMainApp:
                    return [.openMainApp]
                case .openSettings(let permission):
                    return [.openSettings(permission)]
                default:
                    guard let draft = s.review, let route = draft.selectedRoute else { return [] }
                    s.phase = .sending
                    return [.deliver(draft, route)]
                }
            case .quickAnswer:
                guard var qa = s.quickAnswer, qa.error != nil else { return [] }
                qa.error = nil
                qa.answer = ""
                qa.streaming = true
                s.quickAnswer = qa
                return [.ask(question: qa.question, history: qa.history)]
            case .review:
                if s.review?.routes == .failed { return reduce(&s, .retryRoutes) }
                return []
            default:
                return []
            }

        case .cancel:
            switch s.phase {
            case .listening, .transcribing:
                return abandonVoice(&s)
            case .transcriptionFailed:
                return [.cancelFailureCountdown] + abandonVoice(&s, stop: false)
            default:
                return []
            }

        case .escape:
            return escape(&s)

        case .notice(let text):
            s.notice = text
            return []
        }
    }

    // MARK: - Helpers

    /// Collapses to resting. Re-arms the hover only when the pointer is already away, so a
    /// collapse under a parked pointer cannot reopen the list until the pointer leaves.
    private static func rest(_ s: inout IslandState) -> [IslandEffect] {
        s.phase = .resting
        s.hoverArmed = s.pointerZone == .outside
        s.hoverDwellPending = false
        s.failureHold = false
        s.recentlySentTaskId = nil
        return [.cancelHoverDwell, .cancelExitGrace, .cancelSentGrace]
    }

    private static func leaveList(_ s: inout IslandState) -> [IslandEffect] {
        rest(&s)
    }

    private static func fail(_ s: inout IslandState, _ failure: IslandFailure) -> [IslandEffect] {
        s.phase = .transcriptionFailed(failure)
        s.failureHold = false
        // Only the plain "listen again" failure counts itself down; a missing permission
        // stays until the user acts on it.
        return failure.recovery == .retry ? [.scheduleFailureCountdown] : []
    }

    private static func beginVoiceSession(_ s: inout IslandState, kind: ShortcutAction,
                                          keepReferents: Bool = false) -> [IslandEffect] {
        var fx: [IslandEffect] = []
        switch s.phase {
        case .resting, .agentList:
            break
        case .transcriptionFailed:
            fx.append(.cancelFailureCountdown)
            s.failureHold = false
        case .quickAnswer(.attached):
            // A new session ends the visible Quick Answer.
            s.quickAnswer = nil
            fx += [.cancelAsk, .releaseKey]
        case .quickAnswer(.detached):
            if kind == .quickAnswer {
                // A new Quick Answer starts a new Chat; the old panel goes away.
                s.quickAnswer = nil
                s.dockZone = .outside
                fx += [.cancelAsk, .dismissDetached]
            }
            // For VoiceFlow the detached session survives; only the notch changes.
        case .listening, .transcribing, .review, .sending, .sendFailed:
            return []   // protect the session in flight
        }
        s.sessionKind = kind
        s.partialTranscript = ""
        if !keepReferents { s.capturedReferents = [] }
        s.recentlySentTaskId = nil
        s.hoverDwellPending = false
        s.hoverArmed = false
        s.phase = .listening
        return fx + [.cancelHoverDwell, .cancelExitGrace, .cancelSentGrace, .startMetering, .startTranscription]
    }

    private static func abandonVoice(_ s: inout IslandState, stop: Bool = true) -> [IslandEffect] {
        s.partialTranscript = ""
        s.capturedReferents = []
        let fx = rest(&s)
        return stop ? [.stopMetering, .cancelTranscription] + fx : fx
    }

    private static func closeQuickAnswer(_ s: inout IslandState) -> [IslandEffect] {
        guard case .quickAnswer(let placement) = s.phase else { return [] }
        s.quickAnswer = nil
        s.dockZone = .outside
        var fx: [IslandEffect] = [.cancelAsk, .releaseKey]
        if placement == .detached { fx.append(.dismissDetached) }
        return fx + rest(&s)
    }

    private static func closeSelector(_ s: inout IslandState) -> [IslandEffect] {
        var fx: [IslandEffect] = []
        if let draft = s.review, case .searchQuery = draft.selector { fx += clearSearch(&s) }
        s.review?.selector = .closed
        return fx
    }

    private static func clearSearch(_ s: inout IslandState) -> [IslandEffect] {
        s.review?.searchText = ""
        s.review?.searchResults = []
        return [.cancelSearch]
    }

    /// Escape closes the innermost thing first.
    private static func escape(_ s: inout IslandState) -> [IslandEffect] {
        switch s.phase {
        case .review, .sendFailed:
            if s.review?.selector.isOpen == true { return reduce(&s, .selectorBack) }
            if s.review?.inspectingReferentId != nil { s.review?.inspectingReferentId = nil; return [] }
            if s.review?.stackExpanded == true || s.review?.hoveredReferentId != nil {
                s.review?.stackExpanded = false
                s.review?.hoveredReferentId = nil
                return []
            }
            s.review = nil
            s.partialTranscript = ""
            s.capturedReferents = []
            return [.releaseKey] + rest(&s)
        case .sending:
            return []
        case .listening, .transcribing:
            return abandonVoice(&s)
        case .transcriptionFailed:
            return [.cancelFailureCountdown] + abandonVoice(&s, stop: false)
        case .quickAnswer:
            return closeQuickAnswer(&s)
        case .agentList:
            return leaveList(&s)
        case .resting:
            return []
        }
    }

    private static func upsert(_ task: AgentTask, into tasks: inout [AgentTask]) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) { tasks[i] = task } else { tasks.append(task) }
    }
}
