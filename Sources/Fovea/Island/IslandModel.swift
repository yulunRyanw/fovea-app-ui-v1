import SwiftUI
import AppKit
import FoveaCore

/// Runs the Island: feeds events to the pure reducer and executes the effects it returns
/// with the injected services. Shared by the notch panel and the detached Quick Answer
/// panel, so one session has exactly one source of truth.
@MainActor @Observable
final class IslandModel {
    private(set) var state = IslandState()
    /// Microphone level 0…1 while listening.
    private(set) var audioLevel: Float = 0
    private(set) var metrics: ScreenMetrics
    /// Draw the software island even on a notched display (`--demo island-flat`).
    var forceSoftwareIsland = false
    /// The island's bounds in the panel's SwiftUI (top-down) coordinates, for hit testing.
    var contentBounds: CGRect = .zero
    /// Bumped when a text view should take first responder.
    private(set) var focusRequest = FocusRequest(target: .none, token: 0)
    /// Rects the eval harness clicks and measures (debug only; cheap to keep).
    var debugRects: [String: CGRect] = [:]

    struct FocusRequest: Equatable {
        enum Target { case none, editor, followUp, search }
        var target: Target
        var token: Int
    }

    let services: IslandServices
    let ledger: TaskLedger
    let captureLog: CaptureLog
    let commands: AppCommandBus
    let shortcuts: ShortcutModel
    /// The user's accent, for the resting point.
    let settings: SettingsModel

    // Hooks the controller installs (window-level effects).
    var onRequestKey: (() -> Void)?
    /// Runs the key hand-back; the controller may schedule it after the collapse settles.
    var onReleaseKey: ((_ animated: Bool) -> Void)?
    /// Show the floating panel; `true` continues the user's live drag (a tear-off).
    var onPresentDetached: ((_ continuingDrag: Bool) -> Void)?
    var onDismissDetached: (() -> Void)?
    var onSessionWillBegin: (() -> Void)?
    /// Re-check the pointer zone against the new geometry (after a phase change).
    var onGeometrySettled: (() -> Void)?

    private var tasks: [String: Task<Void, Never>] = [:]
    private var started = false
    /// Effects deferred to the end of the current phase animation (the key hand-back).
    private var deferredEffects: [IslandEffect] = []
    private var animationGeneration = 0
    /// Set by `detachFromGesture()` so the presented panel continues the live drag.
    private var pendingDetachContinuesDrag = false

    init(services: IslandServices, ledger: TaskLedger, captureLog: CaptureLog, commands: AppCommandBus,
         shortcuts: ShortcutModel, settings: SettingsModel, metrics: ScreenMetrics) {
        self.services = services; self.ledger = ledger; self.captureLog = captureLog
        self.commands = commands; self.shortcuts = shortcuts; self.settings = settings; self.metrics = metrics
        state.tasks = ledger.sorted
    }

    // MARK: - Derived

    var frames: IslandFrames {
        NotchGeometry.frames(density: state.density, metrics: metrics,
                             spec: Tokens.Island.Layout.layoutSpec, forceSoftware: forceSoftwareIsland)
    }

    var phase: IslandPhase { state.phase }

    /// The pointer zone for a screen point, against the island's target geometry.
    func pointerZone(atScreen point: CGPoint, panel: CGRect) -> PointerZone {
        let local = NotchGeometry.panelLocalPoint(screen: point, panel: panel)
        return NotchGeometry.pointerZone(at: local, frames: frames, contentHeight: contentBounds.height,
                                         spec: Tokens.Island.Layout.layoutSpec)
    }

    /// Hit region for the hosting view, in the panel's top-down coordinates: the island at
    /// its target width and measured height, plus a little slack below. Derived from the
    /// target frames, never the animating bounds, so it never trails an animation.
    var hitRegion: CGRect? {
        guard contentBounds.width > 0 else { return nil }
        let f = frames
        let height = max(f.minHeight, contentBounds.height)
        let slack = Tokens.Island.Layout.layoutSpec.hoverExitSlack
        return CGRect(x: contentBounds.minX - slack, y: contentBounds.minY,
                      width: f.width + slack * 2, height: height + slack)
    }

    /// The island outline inside `hitRegion`, so clicks beside the ears fall through.
    var hitPath: Path? {
        guard let region = hitRegion else { return nil }
        let f = frames
        let shape = IslandShape(topRadius: f.topRadius, bottomRadius: f.bottomRadius)
        let inner = CGRect(x: contentBounds.minX, y: contentBounds.minY,
                           width: f.width, height: max(f.minHeight, contentBounds.height))
        var path = shape.path(in: inner)
        // Keep the exit slack clickable below the shape.
        path.addRect(CGRect(x: region.minX, y: inner.maxY, width: region.width, height: region.maxY - inner.maxY))
        return path
    }

    // MARK: - Lifecycle

    func setMetrics(_ m: ScreenMetrics) { metrics = m }

    /// Starts listening to hotkeys, the task ledger and agent updates.
    func start() {
        guard !started else { return }
        started = true
        do {
            try services.hotkeys.start(bindings: shortcuts.bindings)
        } catch {
            send(.notice(error.localizedDescription))
        }
        tasks["hotkeys"] = Task { [weak self] in
            guard let self else { return }
            for await event in self.services.hotkeys.events {
                switch event {
                case .pressed(let action):
                    if self.state.phase == .resting || self.state.phase == .agentList { self.onSessionWillBegin?() }
                    // A press that arrived proves the shortcut works; a stale permission notice can go.
                    if self.state.notice != nil { self.send(.notice(nil)) }
                    self.send(.hotkeyPressed(action))
                case .escape: self.send(.escape)
                }
            }
        }
        tasks["agentUpdates"] = Task { [weak self] in
            guard let self else { return }
            for await task in self.services.agent.taskUpdates { self.ledger.upsert(task) }
        }
        observeLedger()
        observeShortcuts()
        observeRecording()
    }

    /// While the Shortcuts page records a chord, pressing it must not start a session.
    private func observeRecording() {
        withObservationTracking {
            services.hotkeys.setSuspended(shortcuts.recordingAction != nil)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeRecording() }
        }
    }

    private func observeLedger() {
        withObservationTracking {
            _ = ledger.tasks
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.send(.tasksChanged(self.ledger.sorted))
                self.observeLedger()
            }
        }
    }

    private func observeShortcuts() {
        withObservationTracking {
            _ = shortcuts.bindings
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                do { try self.services.hotkeys.update(bindings: self.shortcuts.bindings); self.send(.notice(nil)) }
                catch { self.send(.notice(error.localizedDescription)) }
                self.observeShortcuts()
            }
        }
    }

    // MARK: - Events

    /// `FOVEA_ISLAND_LOG=1` prints every phase change; the eval harness reads `phaseLog`.
    private static let logging = ProcessInfo.processInfo.environment["FOVEA_ISLAND_LOG"] != nil
    private(set) var phaseLog: [(time: CFTimeInterval, phase: IslandPhase)] = []

    func send(_ event: IslandEvent) {
        let before = state
        var next = state
        let effects = IslandReducer.reduce(&next, event)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let anim = Tokens.Motion.islandAnimation(from: before, to: next, reduceMotion: reduceMotion)
        let phaseChanged = before.phase != next.phase

        // Effects split: the key hand-back waits for the collapse to finish so the panel
        // is never hidden and re-shown mid-animation (which cancelled the morph before).
        var immediate = effects
        var deferred: [IslandEffect] = []
        if let i = immediate.firstIndex(of: .releaseKey), anim != nil, phaseChanged {
            immediate.remove(at: i)
            deferred.append(.releaseKey)
        }

        if let anim {
            animationGeneration += 1
            let generation = animationGeneration
            deferredEffects.append(contentsOf: deferred)
            withAnimation(anim) {
                apply(next, before: before.phase, event: event)
            } completion: { [weak self] in
                guard let self, self.animationGeneration == generation else { return }
                let pending = self.deferredEffects
                self.deferredEffects = []
                for effect in pending { self.run(effect) }
            }
        } else {
            apply(next, before: before.phase, event: event)
            for effect in deferred { run(effect) }
        }

        for effect in immediate { run(effect) }
    }

    /// Commits reduced state and the per-phase-change side work.
    private func apply(_ next: IslandState, before: IslandPhase, event: IslandEvent) {
        state = next
        guard state.phase != before else { return }
        if Self.logging { print("island: \(before) → \(state.phase)") }
        phaseLog.append((CACurrentMediaTime(), state.phase))
        if phaseLog.count > 64 { phaseLog.removeFirst(phaseLog.count - 64) }
        services.hotkeys.setEscapeCapture(state.phase.isVoice)
        announce(state.phase)
        // The geometry changed; re-check the pointer zone once it settles.
        onGeometrySettled?()
    }

    /// Seeds a scenario, cancelling anything in flight; optionally keeps its streams alive.
    func jump(to scenario: IslandScenario) {
        cancelAll()
        audioLevel = 0
        scenario.apply(to: &state)
        ledger.removeAll()
        for t in state.tasks { ledger.upsert(t) }
        services.hotkeys.setEscapeCapture(state.phase.isVoice)
        switch scenario {
        case .listening:
            run(.startMetering)
        case .transcribing:
            run(.startTranscription)
            run(.finishTranscription)
        case .failureRetry:
            run(.scheduleFailureCountdown)
        case .listAfterSend:
            run(.scheduleSentGrace)
        case .reviewResolving:
            if let draft = state.review { run(.resolveRoutes(draft)) }
        case .selectorNewChatContext:
            run(.loadFolders(Fixtures.claudeCode))
        case .qaStreaming:
            if let qa = state.quickAnswer { run(.ask(question: qa.question, history: [])) }
        case .qaDetached, .qaDockReady:
            run(.presentDetached)
        default:
            break
        }
        if state.phase.isReview || state.phase == .quickAnswer(.attached) { run(.requestKey) }
        if case .searchQuery = state.review?.selector { run(.focusSearch) }
        else if state.phase.isReview { run(.focusEditor) }
        if state.phase == .quickAnswer(.attached) { run(.focusFollowUp) }
        onGeometrySettled?()
    }

    func reset() {
        cancelAll()
        audioLevel = 0
        deferredEffects = []
        state = IslandState()
        state.tasks = ledger.sorted
        onDismissDetached?()
        onReleaseKey?(false)
    }

    /// Grabber drag in the attached slab: the island collapses on its close spring while the
    /// controller shows the floating panel and keeps following the pointer itself, so no
    /// event has to be captured and nothing can be lost.
    func detachFromGesture() {
        guard state.phase == .quickAnswer(.attached) else { return }
        pendingDetachContinuesDrag = true
        send(.detach)
    }

    /// The pointer moved. Reported by the tracker with the zone it computed.
    func pointerZoneChanged(_ zone: PointerZone) {
        send(.pointerZoneChanged(zone))
    }

    // MARK: - Effects

    private func run(_ effect: IslandEffect) {
        switch effect {
        case .startMetering:
            replace("meter") { [weak self] in
                guard let self else { return }
                do {
                    let stream = try await self.services.meter.start()
                    for await level in stream {
                        if Task.isCancelled { break }
                        self.audioLevel = level
                    }
                } catch let error as ServiceUnavailable {
                    self.send(.audioFailed(error.failure))
                } catch {
                    self.send(.audioFailed(IslandFailure("Microphone unavailable.", recovery: .retry)))
                }
            }

        case .stopMetering:
            cancel("meter")
            services.meter.stop()
            audioLevel = 0

        case .startTranscription:
            // The session captures what the user is looking at; the prototype attaches fixtures.
            send(.referentsCaptured(Fixtures.reviewReferents))
            transcribe { try await self.services.transcriber.start() }

        case .finishTranscription:
            services.transcriber.finish()

        case .cancelTranscription:
            cancel("transcribe")
            services.transcriber.cancel()

        case .resolveRoutes(let draft):
            replace("routes") { [weak self] in
                guard let self else { return }
                do {
                    let menu = try await self.services.routing.resolve(for: draft)
                    self.send(.routesResolved(menu))
                } catch {
                    if !Task.isCancelled { self.send(.routesFailed) }
                }
            }

        case .loadFolders(let app):
            replace("folders") { [weak self] in
                guard let self else { return }
                let folders = (try? await self.services.catalog.folders(for: app)) ?? []
                if !Task.isCancelled { self.send(.foldersLoaded(app, folders)) }
            }

        case .searchChats(let app, let query):
            replace("search") { [weak self] in
                guard let self else { return }
                do { try await Task.sleep(for: Tokens.Motion.searchDebounce) } catch { return }
                let results = (try? await self.services.catalog.search(query, in: app)) ?? []
                if !Task.isCancelled { self.send(.searchResults(query: query, results)) }
            }

        case .cancelSearch:
            cancel("search")

        case .deliver(let draft, let route):
            replace("deliver") { [weak self] in
                guard let self else { return }
                do {
                    let task = try await self.services.agent.deliver(draft, to: route)
                    self.ledger.upsert(task)
                    self.captureLog.append(Self.capture(for: draft, task: task))
                    self.send(.sent(task))
                } catch let error as ServiceUnavailable {
                    self.send(.sendFailed(error.failure))
                } catch {
                    self.send(.sendFailed(IslandFailure("Couldn’t send.", recovery: .retry)))
                }
            }

        case .ask(let question, let history):
            replace("ask") { [weak self] in
                guard let self else { return }
                do {
                    for try await token in self.services.agent.ask(question, history: history) {
                        if Task.isCancelled { return }
                        self.send(.answerToken(token))
                    }
                    if !Task.isCancelled { self.send(.answerFinished) }
                } catch let error as ServiceUnavailable {
                    self.send(.answerFailed(error.failure.message))
                } catch {
                    if !Task.isCancelled { self.send(.answerFailed("The answer timed out.")) }
                }
            }

        case .cancelAsk:
            cancel("ask")

        case .scheduleHoverDwell:
            replace("hoverDwell") { [weak self] in
                try? await Task.sleep(for: Tokens.Motion.hoverDwell)
                guard !Task.isCancelled else { return }
                self?.send(.hoverDwellElapsed)
            }

        case .cancelHoverDwell:
            cancel("hoverDwell")

        case .scheduleExitGrace:
            replace("exitGrace") { [weak self] in
                try? await Task.sleep(for: Tokens.Motion.exitGrace)
                guard !Task.isCancelled else { return }
                self?.send(.exitGraceElapsed)
            }

        case .cancelExitGrace:
            cancel("exitGrace")

        case .scheduleSentGrace:
            replace("sentGrace") { [weak self] in
                try? await Task.sleep(for: Tokens.Motion.sentGrace)
                guard !Task.isCancelled else { return }
                self?.send(.sentGraceElapsed)
            }

        case .cancelSentGrace:
            cancel("sentGrace")

        case .scheduleFailureCountdown:
            replace("failureCountdown") { [weak self] in
                try? await Task.sleep(for: Tokens.Motion.failureCountdown)
                guard !Task.isCancelled else { return }
                self?.send(.failureCountdownElapsed)
            }

        case .cancelFailureCountdown:
            cancel("failureCountdown")

        case .presentDetached:
            onPresentDetached?(pendingDetachContinuesDrag)
            pendingDetachContinuesDrag = false

        case .dismissDetached:
            onDismissDetached?()

        case .requestKey:
            onRequestKey?()

        case .releaseKey:
            onReleaseKey?(true)

        case .focusEditor:
            focusRequest = FocusRequest(target: .editor, token: focusRequest.token + 1)

        case .focusFollowUp:
            focusRequest = FocusRequest(target: .followUp, token: focusRequest.token + 1)

        case .focusSearch:
            focusRequest = FocusRequest(target: .search, token: focusRequest.token + 1)

        case .openTask(let id):
            guard let task = state.tasks.first(where: { $0.id == id }) else { return }
            commands.post(.revealTask(task))

        case .openSettings(let permission):
            commands.post(.openSystemSettings(permission))

        case .openMainApp:
            commands.post(.openMain(.settings(SettingsRoute(.connected))))

        case .haptic(let kind):
            let pattern: NSHapticFeedbackManager.FeedbackPattern = kind == .alignment ? .alignment : .levelChange
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
        }
    }

    private func transcribe(_ open: @escaping () async throws -> AsyncThrowingStream<TranscriptChunk, Error>) {
        replace("transcribe") { [weak self] in
            guard let self else { return }
            do {
                let stream = try await open()
                var sawFinal = false
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    switch chunk {
                    case .partial(let text): self.send(.transcriptPartial(text))
                    case .final(let text): sawFinal = true; self.send(.transcriptFinal(text))
                    }
                }
                // A stream that ends without a final result (speech gave up quietly).
                if !sawFinal, !Task.isCancelled, self.state.phase == .transcribing {
                    self.send(.transcriptFinal(self.state.partialTranscript))
                }
            } catch let error as ServiceUnavailable {
                self.send(.transcriptionFailed(error.failure))
            } catch {
                if !Task.isCancelled { self.send(.transcriptionFailed(IslandFailure("Transcription failed.", recovery: .retry))) }
            }
        }
    }

    private func replace(_ key: String, _ body: @escaping @MainActor () async -> Void) {
        tasks[key]?.cancel()
        tasks[key] = Task { await body() }
    }

    private func cancel(_ key: String) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    private func cancelAll() {
        for key in ["meter", "transcribe", "routes", "folders", "search", "deliver", "ask",
                    "hoverDwell", "exitGrace", "sentGrace", "failureCountdown"] { cancel(key) }
        services.meter.stop()
        services.transcriber.cancel()
    }

    /// What Home shows for a sent payload.
    private static func capture(for draft: ReviewDraft, task: AgentTask) -> Capture {
        Capture(id: task.captureId ?? "cap-\(task.id)", intent: draft.referents.isEmpty ? .voiceOnly : .voiceWithAttachment,
                createdAt: Date(), transcript: draft.transcript,
                semanticAnchors: CaptureAnchors.extract(from: draft.transcript),
                referents: draft.referents, sourceApp: nil, destinationApp: task.destination,
                deliveryStatus: .sent, chatName: task.chatName)
    }

    private func announce(_ phase: IslandPhase) {
        let text: String?
        switch phase {
        case .listening: text = "Listening"
        case .transcribing: text = "Transcribing"
        case .review: text = "Transcript ready"
        case .agentList: text = "Agent tasks"
        case .resting: text = nil
        case .quickAnswer(.attached): text = "Quick Answer"
        case .transcriptionFailed(let f), .sendFailed(let f): text = f.message
        default: text = nil
        }
        guard let text else { return }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
}
