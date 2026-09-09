import XCTest
@testable import FoveaCore

final class IslandReducerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(_ scenario: IslandScenario = .resting) -> IslandState {
        var s = IslandState()
        scenario.apply(to: &s, now: now)
        return s
    }

    private func hasDeliver(_ fx: [IslandEffect]) -> Bool {
        fx.contains(where: { if case .deliver = $0 { return true }; return false })
    }

    func testVoiceFlowHappyPath() {
        var s = state()
        var fx = IslandReducer.reduce(&s, .hotkeyDown(.voiceFlow))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertTrue(fx.contains(.startMetering))
        XCTAssertTrue(fx.contains(.startTranscription))

        IslandReducer.reduce(&s, .referentsCaptured(Fixtures.reviewReferents))
        IslandReducer.reduce(&s, .transcriptPartial("Make sure"))
        XCTAssertEqual(s.partialTranscript, "Make sure")

        fx = IslandReducer.reduce(&s, .hotkeyUp(.voiceFlow))
        XCTAssertEqual(s.phase, .transcribing)
        XCTAssertTrue(fx.contains(.finishTranscription))
        XCTAssertTrue(fx.contains(.stopMetering))

        fx = IslandReducer.reduce(&s, .transcriptFinal(Fixtures.transcriptScript))
        XCTAssertEqual(s.phase, .review)
        XCTAssertEqual(s.review?.transcript, Fixtures.transcriptScript)
        XCTAssertEqual(s.review?.referents.count, Fixtures.reviewReferents.count)
        XCTAssertEqual(s.review?.routes, .resolving)
        XCTAssertFalse(s.review!.canSend, "no route yet")
        XCTAssertTrue(fx.contains(.requestKey))
        XCTAssertTrue(fx.contains(where: { if case .resolveRoutes = $0 { return true }; return false }))

        IslandReducer.reduce(&s, .routesResolved(Fixtures.chatRouteMenu))
        XCTAssertEqual(s.review?.selectedRoute, Fixtures.chatRouteMenu.recommended)
        XCTAssertTrue(s.review!.canSend)

        fx = IslandReducer.reduce(&s, .send)
        XCTAssertEqual(s.phase, .sending)
        XCTAssertTrue(hasDeliver(fx))

        let task = AgentTask(id: "t", title: "Empty state", state: .working, destination: Fixtures.claudeCode,
                             chatName: "Fovea", activity: "Reading", updatedAt: now)
        fx = IslandReducer.reduce(&s, .sent(task))
        XCTAssertEqual(s.phase, .agentList, "Send acknowledges in the Agent list")
        XCTAssertEqual(s.recentlySentTaskId, "t")
        XCTAssertNil(s.review)
        XCTAssertTrue(s.tasks.contains(task))
        XCTAssertTrue(fx.contains(.releaseKey))
        XCTAssertTrue(fx.contains(.scheduleSentGrace))
    }

    func testPressTogglesListening() {
        var s = state()
        var fx = IslandReducer.reduce(&s, .hotkeyPressed(.voiceFlow))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertTrue(fx.contains(.startMetering))

        // The other shortcut does not interrupt a recording in progress.
        XCTAssertTrue(IslandReducer.reduce(&s, .hotkeyPressed(.quickAnswer)).isEmpty)
        XCTAssertEqual(s.phase, .listening)
        XCTAssertEqual(s.sessionKind, .voiceFlow)

        fx = IslandReducer.reduce(&s, .hotkeyPressed(.voiceFlow))
        XCTAssertEqual(s.phase, .transcribing)
        XCTAssertTrue(fx.contains(.finishTranscription))
        XCTAssertTrue(fx.contains(.stopMetering))

        // Pressing again while transcribing is ignored, as any press during a session in flight.
        XCTAssertTrue(IslandReducer.reduce(&s, .hotkeyPressed(.voiceFlow)).isEmpty)
        XCTAssertEqual(s.phase, .transcribing)
    }

    func testPressTogglesQuickAnswer() {
        var s = state()
        IslandReducer.reduce(&s, .hotkeyPressed(.quickAnswer))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertEqual(s.sessionKind, .quickAnswer)
        IslandReducer.reduce(&s, .hotkeyPressed(.quickAnswer))
        XCTAssertEqual(s.phase, .transcribing)
        IslandReducer.reduce(&s, .transcriptFinal("What does retention mean?"))
        XCTAssertEqual(s.phase, .quickAnswer(.attached))
        // A press while the answer shows starts a fresh session.
        IslandReducer.reduce(&s, .hotkeyPressed(.voiceFlow))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertEqual(s.sessionKind, .voiceFlow)
    }

    // MARK: Failure + Retry

    func testEmptyTranscriptFailsWithCountdown() {
        var s = state(.transcribing)
        let fx = IslandReducer.reduce(&s, .transcriptFinal("   "))
        guard case .transcriptionFailed(let failure) = s.phase else { return XCTFail("expected failure") }
        XCTAssertEqual(failure.message, "Didn’t catch that.")
        XCTAssertEqual(failure.recovery, .retry)
        XCTAssertTrue(fx.contains(.stopMetering))
        XCTAssertTrue(fx.contains(.scheduleFailureCountdown))
    }

    func testFailureCountdownOnlyForRetryRecovery() {
        var s = state(.listening)
        let fx = IslandReducer.reduce(&s, .audioFailed(IslandFailure("Mic denied", recovery: .openSettings(.microphone))))
        XCTAssertFalse(fx.contains(.scheduleFailureCountdown), "a missing permission stays until acted on")
        var t = state(.listening)
        XCTAssertTrue(IslandReducer.reduce(&t, .transcriptionFailed(IslandFailure("x", recovery: .retry)))
            .contains(.scheduleFailureCountdown))
    }

    func testFailureCountdownCollapsesOrHolds() {
        var s = state(.failureRetry)
        let fx = IslandReducer.reduce(&s, .failureCountdownElapsed)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertTrue(fx.contains(.cancelFailureCountdown) || fx.contains(.cancelHoverDwell))

        var t = state(.failureRetry)
        t.pointerZone = .inside
        XCTAssertTrue(IslandReducer.reduce(&t, .failureCountdownElapsed).isEmpty)
        guard case .transcriptionFailed = t.phase else { return XCTFail("holds while hovered") }
        XCTAssertTrue(t.failureHold)
        IslandReducer.reduce(&t, .pointerZoneChanged(.outside))
        XCTAssertEqual(t.phase, .resting, "collapses once the pointer leaves")
        XCTAssertFalse(t.failureHold)
    }

    func testCountdownIgnoredOutsideFailure() {
        var s = state(.reviewCollapsed)
        XCTAssertTrue(IslandReducer.reduce(&s, .failureCountdownElapsed).isEmpty)
        XCTAssertEqual(s.phase, .review)
    }

    func testRetryListensAgainKeepingSessionAndReferents() {
        var s = state(.failureRetry)
        s.sessionKind = .quickAnswer
        let fx = IslandReducer.reduce(&s, .retry)
        XCTAssertEqual(s.phase, .listening)
        XCTAssertEqual(s.sessionKind, .quickAnswer)
        XCTAssertEqual(s.capturedReferents, Fixtures.reviewReferents, "the same referents ride along")
        XCTAssertTrue(fx.contains(.cancelFailureCountdown))
        XCTAssertTrue(fx.contains(.startMetering))
        XCTAssertTrue(fx.contains(.startTranscription))
    }

    func testRetryRoutesToSettingsForPermissionFailure() {
        var s = state(.microphoneDenied)
        XCTAssertEqual(IslandReducer.reduce(&s, .retry), [.openSettings(.microphone)])
        guard case .transcriptionFailed = s.phase else { return XCTFail("stays until the user acts") }
    }

    func testHotkeyFromFailureCancelsCountdown() {
        var s = state(.failureRetry)
        let fx = IslandReducer.reduce(&s, .hotkeyPressed(.voiceFlow))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertTrue(fx.contains(.cancelFailureCountdown))
        XCTAssertTrue(s.capturedReferents.isEmpty, "a fresh press starts a fresh capture")
    }

    func testEscapeFromFailureCancelsCountdown() {
        var s = state(.failureRetry)
        let fx = IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertTrue(fx.contains(.cancelFailureCountdown))
        XCTAssertFalse(fx.contains(.stopMetering), "the mic already stopped when the failure arrived")
    }

    // MARK: Quick Answer

    func testQuickAnswerSessionFromHotkey() {
        var s = state()
        IslandReducer.reduce(&s, .hotkeyDown(.quickAnswer))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertEqual(s.sessionKind, .quickAnswer)
        IslandReducer.reduce(&s, .hotkeyUp(.quickAnswer))
        let fx = IslandReducer.reduce(&s, .transcriptFinal("What does retention mean?"))
        XCTAssertEqual(s.phase, .quickAnswer(.attached))
        XCTAssertEqual(s.quickAnswer?.question, "What does retention mean?")
        XCTAssertTrue(fx.contains(.ask(question: "What does retention mean?", history: [])))

        IslandReducer.reduce(&s, .answerToken("Retention "))
        IslandReducer.reduce(&s, .answerToken("is…"))
        IslandReducer.reduce(&s, .answerFinished)
        XCTAssertEqual(s.quickAnswer?.answer, "Retention is…")
        XCTAssertEqual(s.quickAnswer?.streaming, false)

        IslandReducer.reduce(&s, .editFollowUp("How is it measured?"))
        let followFx = IslandReducer.reduce(&s, .submitFollowUp)
        XCTAssertEqual(s.quickAnswer?.turns.count, 1)
        XCTAssertEqual(s.quickAnswer?.question, "How is it measured?")
        XCTAssertEqual(s.quickAnswer?.answer, "")
        XCTAssertTrue(followFx.contains(.ask(question: "How is it measured?",
                                             history: ["What does retention mean?", "Retention is…"])))
    }

    func testFollowUpIgnoredWhileStreaming() {
        var s = state(.qaStreaming)
        IslandReducer.reduce(&s, .editFollowUp("more"))
        XCTAssertTrue(IslandReducer.reduce(&s, .submitFollowUp).isEmpty)
        XCTAssertEqual(s.quickAnswer?.followUp, "more")
    }

    func testDetachAndRedock() {
        var s = state(.qaStreaming)
        var fx = IslandReducer.reduce(&s, .detach)
        XCTAssertEqual(s.phase, .quickAnswer(.detached))
        XCTAssertTrue(fx.contains(.presentDetached))
        XCTAssertEqual(s.phase.density, .resting, "the notch rests while the answer floats")
        XCTAssertEqual(s.dockZone, .outside)

        fx = IslandReducer.reduce(&s, .setDockZone(.near))
        XCTAssertEqual(s.dockZone, .near)
        XCTAssertFalse(fx.contains(.haptic(.alignment)), "approaching is silent")
        fx = IslandReducer.reduce(&s, .setDockZone(.ready))
        XCTAssertTrue(fx.contains(.haptic(.alignment)), "one tick when release would dock")
        XCTAssertTrue(IslandReducer.reduce(&s, .setDockZone(.ready)).isEmpty, "no repeat haptic")
        XCTAssertTrue(IslandReducer.reduce(&s, .setDockZone(.near)).isEmpty, "backing out is silent")
        IslandReducer.reduce(&s, .setDockZone(.ready))

        fx = IslandReducer.reduce(&s, .redock)
        XCTAssertEqual(s.phase, .quickAnswer(.attached))
        XCTAssertEqual(s.dockZone, .outside)
        XCTAssertTrue(fx.contains(.dismissDetached))
        XCTAssertTrue(fx.contains(.focusFollowUp))
        XCTAssertTrue(IslandReducer.reduce(&s, .setDockZone(.ready)).isEmpty, "zones only exist while detached")
        XCTAssertEqual(s.dockZone, .outside)
    }

    func testDockZoneWithHysteresis() {
        let m = ScreenMetrics.sampleNotched
        let spec = IslandLayoutSpec()
        func zone(_ below: CGFloat, from current: DockZone) -> DockZone {
            NotchGeometry.dockZone(panelTopCenter: CGPoint(x: m.frame.midX, y: m.frame.maxY - below),
                                   current: current, metrics: m, spec: spec)
        }
        XCTAssertEqual(zone(89, from: .outside), .ready)
        XCTAssertEqual(zone(150, from: .outside), .near)
        XCTAssertEqual(zone(201, from: .outside), .outside)
        XCTAssertEqual(zone(100, from: .ready), .ready, "stays armed just past the snap radius")
        XCTAssertEqual(zone(111, from: .ready), .near)
        XCTAssertEqual(zone(95, from: .near), .near, "arms only inside the snap radius")
        XCTAssertEqual(zone(210, from: .near), .near, "stays open just past the approach radius")
        XCTAssertEqual(zone(221, from: .near), .outside)
    }

    func testProjectedPoint() {
        let p = CGPoint(x: 100, y: 100)
        XCTAssertEqual(NotchGeometry.projectedPoint(from: p, velocity: .zero, decelerationRate: 0.99), p)
        let thrown = NotchGeometry.projectedPoint(from: p, velocity: CGVector(dx: 0, dy: 500), decelerationRate: 0.99)
        XCTAssertEqual(thrown.x, 100)
        XCTAssertEqual(thrown.y, 149.5, accuracy: 0.001)
    }

    func testDockReceiverFramesAndTarget() {
        let m = ScreenMetrics.sampleNotched
        let spec = IslandLayoutSpec()
        let receiver = NotchGeometry.frames(density: .receiver, metrics: m, spec: spec)
        XCTAssertEqual(receiver.width, spec.slabWidth)
        XCTAssertEqual(receiver.minHeight, 32 + spec.dockReceiverBelow)
        XCTAssertEqual(receiver.topRadius, 0)
        XCTAssertTrue(receiver.isSlab)
        XCTAssertEqual(NotchGeometry.Density.receiver.rank, NotchGeometry.Density.voice.rank)
        XCTAssertLessThan(NotchGeometry.Density.receiver.rank, NotchGeometry.Density.slab.rank)

        let target = NotchGeometry.dockTargetRect(size: CGSize(width: 520, height: 300), metrics: m, spec: spec)
        XCTAssertEqual(target.midX, m.frame.midX)
        XCTAssertEqual(target.maxY, m.frame.maxY, "the card's top edge lands on the top of the screen")
        XCTAssertEqual(target.size, CGSize(width: 520, height: 300))
        let flat = NotchGeometry.dockTargetRect(size: CGSize(width: 520, height: 300), metrics: .sampleFlat, spec: spec)
        XCTAssertEqual(flat.midX, ScreenMetrics.sampleFlat.frame.midX)
    }

    func testMagnetismIsStatelessAndFadesOut() {
        let spec = IslandLayoutSpec()
        let free = CGPoint(x: 0, y: 0), target = CGPoint(x: 100, y: 100)
        let far = NotchGeometry.magnetized(free: free, target: target, distance: spec.dockSnapDistance, strength: 0.35, spec: spec)
        XCTAssertEqual(far, free, "no pull at the edge of the snap radius")
        let close = NotchGeometry.magnetized(free: free, target: target, distance: 0, strength: 0.35, spec: spec)
        XCTAssertEqual(close.x, 35, accuracy: 0.001)
        XCTAssertEqual(close.y, 35, accuracy: 0.001)
        let beyond = NotchGeometry.magnetized(free: free, target: target, distance: spec.dockSnapDistance * 2, strength: 0.35, spec: spec)
        XCTAssertEqual(beyond, free, "never a negative pull")
    }

    func testCriticalSpringSettlesWithoutOvershoot() {
        let spring = CriticallyDampedSpring(duration: 0.34)
        // At rest: monotone approach, perceptually done by the duration, settled by 1.5×.
        var last = spring.position(at: 0, from: 300, to: 0, velocity: 0)
        for step in 1...60 {
            let t = CGFloat(step) / 60 * 0.51
            let x = spring.position(at: t, from: 300, to: 0, velocity: 0)
            XCTAssertLessThanOrEqual(x, last + 0.0001)
            XCTAssertGreaterThanOrEqual(x, 0)
            last = x
        }
        XCTAssertLessThan(spring.position(at: 0.34, from: 300, to: 0, velocity: 0), 5)
        XCTAssertLessThan(spring.position(at: 0.51, from: 300, to: 0, velocity: 0), 0.5)
        XCTAssertEqual(spring.velocity(at: 0, from: 300, to: 0, velocity: -120), -120, accuracy: 0.001)

        // A throw toward the target is capped so the motion never crosses it; a throw away is dropped.
        let cap = spring.omega * 300
        XCTAssertEqual(spring.clampedVelocity(-100_000, from: 300, to: 0), -cap, accuracy: 0.001)
        XCTAssertEqual(spring.clampedVelocity(-100, from: 300, to: 0), -100)
        XCTAssertEqual(spring.clampedVelocity(500, from: 300, to: 0), 0)
        XCTAssertEqual(spring.clampedVelocity(500, from: 0, to: 0), 0)
        let seeded = spring.clampedVelocity(-100_000, from: 300, to: 0)
        for step in 0...100 {
            let t = CGFloat(step) / 100 * 0.6
            XCTAssertGreaterThanOrEqual(spring.position(at: t, from: 300, to: 0, velocity: seeded), -0.0001)
        }
    }

    func testStateDensityAndLayoutKeyWhileDocking() {
        var s = state(.qaDetached)
        XCTAssertEqual(s.density, .resting)
        XCTAssertEqual(s.layoutKey, "resting")
        s.dockZone = .near
        XCTAssertEqual(s.density, .receiver)
        XCTAssertEqual(s.layoutKey, "dock")
        s.dockZone = .ready
        XCTAssertEqual(s.density, .receiver, "brightening never changes the geometry")
        XCTAssertEqual(s.layoutKey, "dock")
        var attached = state(.qaLong)
        attached.dockZone = .near
        XCTAssertEqual(attached.density, .slab)
        XCTAssertEqual(attached.layoutKey, "qa")
    }

    func testCloseQuickAnswerEndsSession() {
        var a = state(.qaLong)
        let afx = IslandReducer.reduce(&a, .closeQuickAnswer)
        XCTAssertEqual(a.phase, .resting)
        XCTAssertNil(a.quickAnswer)
        XCTAssertTrue(afx.contains(.cancelAsk))
        XCTAssertTrue(afx.contains(.releaseKey))
        XCTAssertFalse(afx.contains(.dismissDetached))

        var d = state(.qaDockReady)
        let dfx = IslandReducer.reduce(&d, .closeQuickAnswer)
        XCTAssertEqual(d.phase, .resting)
        XCTAssertNil(d.quickAnswer)
        XCTAssertEqual(d.dockZone, .outside)
        XCTAssertTrue(dfx.contains(.dismissDetached))
    }

    func testManyTurnsAndDockingScenarios() {
        var s = IslandState()
        IslandScenario.qaManyTurns.apply(to: &s)
        XCTAssertEqual(s.phase, .quickAnswer(.attached))
        XCTAssertGreaterThanOrEqual((s.quickAnswer?.turns.count ?? 0) + 1, 4, "enough questions for the bookmark rail")
        IslandScenario.qaDockReady.apply(to: &s)
        XCTAssertEqual(s.phase, .quickAnswer(.detached))
        XCTAssertEqual(s.dockZone, .ready)
        XCTAssertEqual(s.density, .receiver)
    }

    func testVoiceFlowWhileDetachedKeepsTheSession() {
        var s = state(.qaDetached)
        IslandReducer.reduce(&s, .hotkeyDown(.voiceFlow))
        XCTAssertEqual(s.phase, .listening)
        XCTAssertNotNil(s.quickAnswer, "detached panel stays alive")
        var t = state(.qaDetached)
        let fx = IslandReducer.reduce(&t, .hotkeyDown(.quickAnswer))
        XCTAssertNil(t.quickAnswer, "a new Quick Answer starts a new Chat")
        XCTAssertTrue(fx.contains(.dismissDetached))
    }

    func testQuickAnswerRetryAfterError() {
        var s = state(.qaError)
        let fx = IslandReducer.reduce(&s, .retry)
        XCTAssertNil(s.quickAnswer?.error)
        XCTAssertEqual(s.quickAnswer?.streaming, true)
        XCTAssertTrue(fx.contains(.ask(question: Fixtures.quickAnswerQuestion, history: [])))
    }

    // MARK: Hover

    func testHoverNeedsTasks() {
        var empty = IslandState()
        let fx = IslandReducer.reduce(&empty, .pointerZoneChanged(.inside))
        XCTAssertFalse(fx.contains(.scheduleHoverDwell), "no empty panel")
        IslandReducer.reduce(&empty, .hoverDwellElapsed)
        XCTAssertEqual(empty.phase, .resting)
    }

    func testHoverDwellThenOpen() {
        var s = state()
        let fx = IslandReducer.reduce(&s, .pointerZoneChanged(.inside))
        XCTAssertEqual(fx, [.cancelExitGrace, .scheduleHoverDwell])
        XCTAssertEqual(s.phase, .resting, "nothing opens on the first frame")
        XCTAssertTrue(s.hoverDwellPending)
        IslandReducer.reduce(&s, .hoverDwellElapsed)
        XCTAssertEqual(s.phase, .agentList)
        XCTAssertFalse(s.hoverArmed)
        XCTAssertFalse(s.hoverDwellPending)
    }

    func testDwellNotRescheduledWhileInside() {
        var s = state()
        IslandReducer.reduce(&s, .pointerZoneChanged(.inside))
        XCTAssertFalse(IslandReducer.reduce(&s, .pointerZoneChanged(.inside)).contains(.scheduleHoverDwell))
    }

    func testBrushThroughCancelsDwell() {
        var s = state()
        IslandReducer.reduce(&s, .pointerZoneChanged(.inside))
        let fx = IslandReducer.reduce(&s, .pointerZoneChanged(.outside))
        XCTAssertTrue(fx.contains(.cancelHoverDwell))
        XCTAssertTrue(IslandReducer.reduce(&s, .hoverDwellElapsed).isEmpty)
        XCTAssertEqual(s.phase, .resting)
    }

    func testSlackNeverExpands() {
        var s = state()
        let fx = IslandReducer.reduce(&s, .pointerZoneChanged(.near))
        XCTAssertFalse(fx.contains(.scheduleHoverDwell))
        XCTAssertTrue(IslandReducer.reduce(&s, .hoverDwellElapsed).isEmpty)
        XCTAssertEqual(s.phase, .resting)
    }

    func testExitDuringOpenIsNotDropped() {
        var s = state()
        IslandReducer.reduce(&s, .pointerZoneChanged(.inside))
        IslandReducer.reduce(&s, .hoverDwellElapsed)
        XCTAssertEqual(s.phase, .agentList)
        let fx = IslandReducer.reduce(&s, .pointerZoneChanged(.outside))
        XCTAssertTrue(fx.contains(.scheduleExitGrace), "an exit right after opening still counts")
        IslandReducer.reduce(&s, .exitGraceElapsed)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertTrue(s.hoverArmed, "the pointer is away, so the next approach may open again")
    }

    func testNearKeepsListOpen() {
        var s = state(.hover)
        IslandReducer.reduce(&s, .pointerZoneChanged(.outside))
        let fx = IslandReducer.reduce(&s, .pointerZoneChanged(.near))
        XCTAssertTrue(fx.contains(.cancelExitGrace))
        XCTAssertTrue(IslandReducer.reduce(&s, .exitGraceElapsed).isEmpty)
        XCTAssertEqual(s.phase, .agentList)
    }

    func testNoReopenAfterCollapseUnderPointer() {
        var s = state(.reviewCollapsed)
        s.pointerZone = .inside
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertFalse(s.hoverArmed, "collapsed under the pointer: stay put")
        XCTAssertFalse(IslandReducer.reduce(&s, .pointerZoneChanged(.inside)).contains(.scheduleHoverDwell))
        IslandReducer.reduce(&s, .pointerZoneChanged(.outside))
        XCTAssertTrue(s.hoverArmed)
        XCTAssertTrue(IslandReducer.reduce(&s, .pointerZoneChanged(.inside)).contains(.scheduleHoverDwell))
    }

    func testEscapeFromListDisarmsUntilPointerLeaves() {
        var s = state(.hover)
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertFalse(s.hoverArmed)
        XCTAssertFalse(IslandReducer.reduce(&s, .pointerZoneChanged(.inside)).contains(.scheduleHoverDwell))
    }

    func testExitGraceRespectsFocusAndPins() {
        var s = state(.hover)
        IslandReducer.reduce(&s, .focusChanged(true))
        IslandReducer.reduce(&s, .pointerZoneChanged(.outside))
        IslandReducer.reduce(&s, .exitGraceElapsed)
        XCTAssertEqual(s.phase, .agentList, "focus inside keeps it open")
        IslandReducer.reduce(&s, .focusChanged(false))
        IslandReducer.reduce(&s, .pin)
        IslandReducer.reduce(&s, .exitGraceElapsed)
        XCTAssertEqual(s.phase, .agentList, "pinned")
        XCTAssertEqual(IslandReducer.reduce(&s, .unpin), [.scheduleExitGrace])
        IslandReducer.reduce(&s, .exitGraceElapsed)
        XCTAssertEqual(s.phase, .resting)
    }

    func testTasksEmptyingCollapsesList() {
        var s = state(.hover)
        IslandReducer.reduce(&s, .tasksChanged([]))
        XCTAssertEqual(s.phase, .resting)
    }

    func testHoverDuringVoiceNeverLists() {
        var s = state(.listening)
        IslandReducer.reduce(&s, .pointerZoneChanged(.inside))
        XCTAssertTrue(IslandReducer.reduce(&s, .hoverDwellElapsed).isEmpty)
        XCTAssertEqual(s.phase, .listening)
    }

    // MARK: Sent grace

    func testSentGraceCollapsesWhenPointerOutside() {
        var s = state(.listAfterSend)
        IslandReducer.reduce(&s, .sentGraceElapsed)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertNil(s.recentlySentTaskId)
    }

    func testSentGraceHoldsWhilePointerInside() {
        var s = state(.listAfterSend)
        s.pointerZone = .near
        IslandReducer.reduce(&s, .sentGraceElapsed)
        XCTAssertEqual(s.phase, .agentList)
        XCTAssertNil(s.recentlySentTaskId, "the highlight still fades")
        XCTAssertEqual(IslandReducer.reduce(&s, .pointerZoneChanged(.outside)), [.cancelHoverDwell, .scheduleExitGrace])
        IslandReducer.reduce(&s, .exitGraceElapsed)
        XCTAssertEqual(s.phase, .resting)
    }

    func testExitGraceCannotPreemptSentGrace() {
        var s = state(.listAfterSend)
        IslandReducer.reduce(&s, .focusChanged(false))
        XCTAssertTrue(IslandReducer.reduce(&s, .exitGraceElapsed).isEmpty)
        XCTAssertEqual(s.phase, .agentList)
    }

    func testLeavingListClearsSentHighlight() {
        var s = state(.listAfterSend)
        let fx = IslandReducer.reduce(&s, .takeMeThere("task-sent"))
        XCTAssertNil(s.recentlySentTaskId)
        XCTAssertTrue(fx.contains(.cancelSentGrace))
        XCTAssertTrue(fx.contains(.openTask("task-sent")))
        XCTAssertEqual(s.phase, .resting)
    }

    // MARK: Selector

    func testSelectorNewChatFlow() {
        var s = state(.reviewCollapsed)
        IslandReducer.reduce(&s, .toggleSelector)
        XCTAssertEqual(s.review?.selector, .recent)
        IslandReducer.reduce(&s, .selectorNewChat)
        XCTAssertEqual(s.review?.selector, .newChatAI)
        let fx = IslandReducer.reduce(&s, .chooseDestination(Fixtures.claudeCode))
        XCTAssertEqual(s.review?.selector, .newChatContext(Fixtures.claudeCode))
        XCTAssertEqual(fx, [.loadFolders(Fixtures.claudeCode)])
        IslandReducer.reduce(&s, .foldersLoaded(Fixtures.claudeCode, Fixtures.contextFolders))
        XCTAssertEqual(s.review?.folders.count, Fixtures.contextFolders.count)
        IslandReducer.reduce(&s, .chooseFolder(Fixtures.folderFovea))
        XCTAssertEqual(s.review?.selectedRoute, .newChat(in: Fixtures.claudeCode, context: Fixtures.folderFovea))
        XCTAssertEqual(s.review?.selectedRoute?.pillTitle, "New Chat · fovea")
        XCTAssertEqual(s.review?.selector, .recent, "back to the list to double-check")
    }

    func testNoFolderIsAChoice() {
        var s = state(.selectorNewChatContext)
        IslandReducer.reduce(&s, .chooseFolder(nil))
        XCTAssertEqual(s.review?.selectedRoute?.kind, .new)
        XCTAssertNil(s.review?.selectedRoute?.context)
        XCTAssertEqual(s.review?.selectedRoute?.pillTitle, "New Chat")
    }

    func testFoldersIgnoredForAnotherDestination() {
        var s = state(.selectorNewChatContext)
        s.review?.folders = []
        IslandReducer.reduce(&s, .foldersLoaded(Fixtures.codex, Fixtures.contextFolders))
        XCTAssertEqual(s.review?.folders.count, 0)
    }

    func testSelectorSearchFlow() {
        var s = state(.selectorRecent)
        IslandReducer.reduce(&s, .selectorSearch)
        XCTAssertEqual(s.review?.selector, .searchAI)
        XCTAssertEqual(IslandReducer.reduce(&s, .chooseDestination(Fixtures.codex)), [.focusSearch])
        XCTAssertEqual(s.review?.selector, .searchQuery(Fixtures.codex))
        XCTAssertEqual(IslandReducer.reduce(&s, .editSearch("routing")), [.searchChats(Fixtures.codex, "routing")])
        let hits = Fixtures.chatSearchResults(now: now)
        IslandReducer.reduce(&s, .searchResults(query: "rout", hits))
        XCTAssertEqual(s.review?.searchResults.count, 0, "stale results are ignored")
        IslandReducer.reduce(&s, .searchResults(query: "routing", hits))
        XCTAssertEqual(s.review?.searchResults, hits)
        let fx = IslandReducer.reduce(&s, .chooseRoute(hits[0]))
        XCTAssertEqual(s.review?.selectedRoute, hits[0])
        XCTAssertEqual(s.review?.selector, .recent)
        XCTAssertEqual(s.review?.searchText, "")
        XCTAssertTrue(fx.contains(.cancelSearch))
        XCTAssertTrue(fx.contains(.focusEditor))
    }

    func testEditSearchEmptyCancels() {
        var s = state(.selectorSearchQuery)
        XCTAssertEqual(IslandReducer.reduce(&s, .editSearch("  ")), [.cancelSearch])
        XCTAssertEqual(s.review?.searchResults, [])
    }

    func testChooseRouteKeepsPanelOpen() {
        var s = state(.selectorRecent)
        let route = Fixtures.chatRouteMenu.recent[1]
        IslandReducer.reduce(&s, .chooseRoute(route))
        XCTAssertEqual(s.review?.selectedRoute, route)
        XCTAssertEqual(s.review?.selector, .recent)
    }

    func testSendClosesSelector() {
        var s = state(.selectorRecent)
        IslandReducer.reduce(&s, .send)
        XCTAssertEqual(s.phase, .sending)
        XCTAssertEqual(s.review?.selector, .closed)
    }

    func testSelectorBackMirrorsEscape() {
        var s = state(.selectorNewChatContext)
        IslandReducer.reduce(&s, .selectorBack)
        XCTAssertEqual(s.review?.selector, .newChatAI)
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.review?.selector, .recent)
        XCTAssertEqual(IslandReducer.reduce(&s, .selectorBack), [.focusEditor])
        XCTAssertEqual(s.review?.selector, .closed)
        XCTAssertTrue(IslandReducer.reduce(&s, .selectorBack).isEmpty)
    }

    func testToggleSelectorOnlyInReview() {
        var s = state(.sendFailed)
        XCTAssertTrue(IslandReducer.reduce(&s, .toggleSelector).isEmpty)
        XCTAssertEqual(s.review?.selector, .closed)
    }

    func testEscapePriorityInReview() {
        var s = state(.selectorSearchQuery)
        s.review?.stackExpanded = true
        s.review?.inspectingReferentId = "isl-home"
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.review?.selector, .searchAI); XCTAssertEqual(s.phase, .review)
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.review?.selector, .recent)
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.review?.selector, .closed)
        IslandReducer.reduce(&s, .escape)
        XCTAssertNil(s.review?.inspectingReferentId); XCTAssertEqual(s.phase, .review)
        IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.review?.stackExpanded, false); XCTAssertEqual(s.phase, .review)
        let fx = IslandReducer.reduce(&s, .escape)
        XCTAssertEqual(s.phase, .resting)
        XCTAssertNil(s.review)
        XCTAssertTrue(fx.contains(.releaseKey))
    }

    // MARK: Stack

    func testHoverReferent() {
        var s = state(.reviewExpandedStack)
        IslandReducer.reduce(&s, .hoverReferent("isl-home"))
        XCTAssertEqual(s.review?.hoveredReferentId, "isl-home")
        IslandReducer.reduce(&s, .removeReferent("isl-home"))
        XCTAssertNil(s.review?.hoveredReferentId)
        IslandReducer.reduce(&s, .hoverReferent("isl-desk"))
        IslandReducer.reduce(&s, .setStackExpanded(false))
        XCTAssertNil(s.review?.hoveredReferentId, "collapsing clears the preview")
    }

    func testReferentRemoval() {
        var s = state(.reviewCollapsed)
        let before = s.review!.referents.count
        IslandReducer.reduce(&s, .inspectReferent("isl-home"))
        IslandReducer.reduce(&s, .removeReferent("isl-home"))
        XCTAssertEqual(s.review?.referents.count, before - 1)
        XCTAssertNil(s.review?.inspectingReferentId)
    }

    // MARK: Misc

    func testEscapeCancelsVoiceAndClosesQuickAnswer() {
        var s = state(.listening)
        let fx = IslandReducer.reduce(&s, .escape)
        XCTAssertTrue(fx.contains(.stopMetering))
        XCTAssertTrue(fx.contains(.cancelTranscription))
        XCTAssertEqual(s.phase, .resting)

        var q = state(.qaDetached)
        let qfx = IslandReducer.reduce(&q, .escape)
        XCTAssertEqual(q.phase, .resting)
        XCTAssertNil(q.quickAnswer)
        XCTAssertTrue(qfx.contains(.dismissDetached))
        XCTAssertTrue(qfx.contains(.cancelAsk))
    }

    func testSendingIsProtected() {
        var s = state(.reviewCollapsed)
        IslandReducer.reduce(&s, .send)
        XCTAssertEqual(s.phase, .sending)
        XCTAssertTrue(IslandReducer.reduce(&s, .escape).isEmpty)
        XCTAssertTrue(IslandReducer.reduce(&s, .hotkeyDown(.voiceFlow)).isEmpty)
        IslandReducer.reduce(&s, .sendFailed(IslandFailure("Couldn’t reach Claude Code.")))
        guard case .sendFailed = s.phase else { return XCTFail() }
        XCTAssertNotNil(s.review, "draft preserved")
        let fx = IslandReducer.reduce(&s, .retry)
        XCTAssertEqual(s.phase, .sending)
        XCTAssertTrue(hasDeliver(fx))
    }
}

final class AgentTaskTests: XCTestCase {
    func testDisplayOrder() {
        let now = Date()
        let tasks = Fixtures.agentTasks(now: now) + Fixtures.moreAgentTasks(now: now)
        let sorted = AgentTask.sorted(tasks)
        XCTAssertEqual(sorted.map(\.state), [.needsYou, .complete, .complete, .working, .working, .working, .failed])
        // Within a state, most recent first.
        let completes = sorted.filter { $0.state == .complete }
        XCTAssertGreaterThan(completes[0].updatedAt, completes[1].updatedAt)
    }

    func testFixtureTasksHaveActivity() {
        for task in Fixtures.agentTasks() + Fixtures.moreAgentTasks() + [Fixtures.sentTask()] {
            XCTAssertFalse(task.activity.isEmpty, task.id)
        }
    }

    @MainActor
    func testLedgerUpsert() {
        let ledger = TaskLedger(tasks: Fixtures.agentTasks())
        var t = ledger.tasks[0]
        t.state = .complete
        ledger.upsert(t)
        XCTAssertEqual(ledger.tasks.count, Fixtures.agentTasks().count)
        XCTAssertEqual(ledger.tasks[0].state, .complete)
        ledger.remove(id: t.id)
        XCTAssertNil(ledger.tasks.first { $0.id == t.id })
    }
}

final class ReferentStackLayoutTests: XCTestCase {
    let config = ReferentStackLayout.Config(thumb: CGSize(width: 44, height: 32), spacing: 6, layerOffset: 4, maxLayers: 3)

    func testCollapsedShowsAtMostThreeLayersFrontOnTop() {
        let p = ReferentStackLayout.collapsed(count: 6, config: config)
        XCTAssertEqual(p.count, 3)
        XCTAssertEqual(p[0].offset.width, 0)
        XCTAssertGreaterThan(p[0].z, p[1].z)
        XCTAssertEqual(ReferentStackLayout.collapsed(count: 1, config: config).count, 1)
        XCTAssertTrue(ReferentStackLayout.collapsed(count: 0, config: config).isEmpty)
    }

    func testCollapsedWidths() {
        XCTAssertEqual(ReferentStackLayout.collapsedWidth(count: 0, config: config), 0)
        XCTAssertEqual(ReferentStackLayout.collapsedWidth(count: 1, config: config), 44)
        XCTAssertEqual(ReferentStackLayout.collapsedWidth(count: 6, config: config), 52)
    }

    func testWrappedSingleRow() {
        let (p, size) = ReferentStackLayout.wrapped(count: 6, availableWidth: 302, config: config)
        XCTAssertEqual(p.count, 6)
        XCTAssertEqual(p.map(\.index), Array(0..<6), "every referent placed once")
        XCTAssertEqual(p[1].offset.width, 50)
        XCTAssertTrue(p.allSatisfy { $0.offset.height == 0 })
        XCTAssertEqual(size, CGSize(width: 44 * 6 + 6 * 5, height: 32))
    }

    func testWrappedTwoRows() {
        let (p, size) = ReferentStackLayout.wrapped(count: 10, availableWidth: 302, config: config)
        XCTAssertEqual(ReferentStackLayout.perRow(availableWidth: 302, config: config), 6)
        XCTAssertEqual(p[6].offset, CGSize(width: 0, height: 38))
        XCTAssertEqual(p[9].offset, CGSize(width: 150, height: 38))
        XCTAssertEqual(size, CGSize(width: 294, height: 70))
        XCTAssertTrue(p.allSatisfy { $0.offset.width <= 302 - 44 })
    }

    func testWrappedNarrowWidthKeepsOnePerRow() {
        let (p, size) = ReferentStackLayout.wrapped(count: 3, availableWidth: 10, config: config)
        XCTAssertEqual(ReferentStackLayout.perRow(availableWidth: 10, config: config), 1)
        XCTAssertEqual(p[2].offset, CGSize(width: 0, height: 76))
        XCTAssertEqual(size, CGSize(width: 44, height: 32 * 3 + 12))
    }

    func testPreviewLeadingClamped() {
        let leading = ReferentStackLayout.previewLeading(index: 5, count: 6, availableWidth: 302,
                                                          previewWidth: 260, contentWidth: 486, config: config)
        XCTAssertEqual(leading, 226, "kept inside the content width")
        XCTAssertEqual(ReferentStackLayout.previewLeading(index: 1, count: 6, availableWidth: 302,
                                                          previewWidth: 260, contentWidth: 486, config: config), 50)
    }
}

final class NotchGeometryTests: XCTestCase {
    let spec = IslandLayoutSpec()

    func testProductionSpec() {
        XCTAssertEqual(spec.voiceBelow, 44)
        XCTAssertEqual(spec.reviewWidth, 560)
        XCTAssertEqual(spec.listWidth, 520)
        XCTAssertEqual(spec.slabWidth, 560)
        XCTAssertEqual(spec.compactTopRadius, 6)
        XCTAssertEqual(spec.expandedTopRadius, 19)
        XCTAssertEqual(spec.hoverExitSlack, 8)
    }

    func testNotchedDisplay() {
        let m = ScreenMetrics.sampleNotched
        XCTAssertTrue(m.hasNotch)
        XCTAssertEqual(m.notchWidth, 200)
        let notch = NotchGeometry.notchRect(metrics: m, spec: spec)
        XCTAssertEqual(notch, CGRect(x: 635, y: 0, width: 200, height: 32))
        let resting = NotchGeometry.frames(density: .resting, metrics: m, spec: spec)
        XCTAssertEqual(resting.width, 212, "ears sit outside the notch")
        XCTAssertEqual(resting.bodyWidth, 200)
        XCTAssertEqual(resting.minHeight, 32)
        let voice = NotchGeometry.frames(density: .voice, metrics: m, spec: spec)
        XCTAssertEqual(voice.width, resting.width, "voice states are exactly the notch's width")
        XCTAssertEqual(voice.bodyWidth, 200)
        XCTAssertEqual(voice.minHeight, 32 + 44)
        XCTAssertEqual(voice.minX, resting.minX)
        XCTAssertEqual(voice.topRadius, 6)
        XCTAssertEqual(voice.bottomRadius, 14)
        let list = NotchGeometry.frames(density: .list, metrics: m, spec: spec)
        XCTAssertEqual(list.width, 520)
        let slab = NotchGeometry.frames(density: .slab, metrics: m, spec: spec)
        XCTAssertTrue(slab.isSlab)
        XCTAssertEqual(slab.topRadius, 0)
    }

    func testVoicePhasesShareOneFrame() {
        let m = ScreenMetrics.sampleNotched
        let phases: [IslandPhase] = [.listening, .transcribing, .transcriptionFailed(IslandFailure("x"))]
        let frames = phases.map { NotchGeometry.frames(density: $0.density, metrics: m, spec: spec) }
        XCTAssertTrue(phases.allSatisfy { $0.density == .voice })
        XCTAssertEqual(Set(frames).count, 1)
    }

    func testDensityRank() {
        let order: [NotchGeometry.Density] = [.resting, .voice, .receiver, .list, .review, .slab]
        XCTAssertEqual(order.map(\.rank), [0, 1, 1, 2, 3, 4], "the receiver opens like a voice state and closes back to resting")
    }

    func testFlatDisplayUsesSoftwareIsland() {
        let m = ScreenMetrics.sampleFlat
        XCTAssertFalse(m.hasNotch)
        XCTAssertEqual(m.menuBarHeight, 25)
        let notch = NotchGeometry.notchRect(metrics: m, spec: spec)
        XCTAssertEqual(notch.width, spec.softwareIslandWidth)
        XCTAssertEqual(notch.height, 25)
        XCTAssertEqual(notch.midX, m.frame.midX)
        let voice = NotchGeometry.frames(density: .voice, metrics: m, spec: spec)
        XCTAssertEqual(voice.width, 212)
        XCTAssertEqual(voice.minHeight, 25 + 44)
    }

    func testForcedSoftwareOnNotchedDisplay() {
        let notch = NotchGeometry.notchRect(metrics: .sampleNotched, spec: spec, forceSoftware: true)
        XCTAssertEqual(notch.width, spec.softwareIslandWidth)
        let voice = NotchGeometry.frames(density: .voice, metrics: .sampleNotched, spec: spec, forceSoftware: true)
        XCTAssertEqual(voice.width, 212)
        XCTAssertEqual(voice.minHeight, 32 + 44)
    }

    func testPanelFrameHugsTopEdge() {
        let m = ScreenMetrics.sampleNotched
        let panel = NotchGeometry.panelFrame(metrics: m, spec: spec)
        XCTAssertEqual(panel.maxY, m.frame.maxY)
        XCTAssertEqual(panel.width, m.frame.width)
        XCTAssertEqual(panel.height, 478)
    }

    func testScreenRectConversion() {
        let panel = CGRect(x: 0, y: 478, width: 1470, height: 478)
        let local = CGRect(x: 635, y: 0, width: 200, height: 32)
        let screen = NotchGeometry.screenRect(local, panel: panel)
        XCTAssertEqual(screen, CGRect(x: 635, y: 956 - 32, width: 200, height: 32))
        XCTAssertEqual(NotchGeometry.panelLocalPoint(screen: CGPoint(x: 700, y: 940), panel: panel), CGPoint(x: 700, y: 16))
    }

    func testPointerZones() {
        let m = ScreenMetrics.sampleNotched
        let resting = NotchGeometry.frames(density: .resting, metrics: m, spec: spec)
        // Inside only over the notch itself.
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 16), frames: resting, contentHeight: 42, spec: spec), .inside)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 636, y: 31), frames: resting, contentHeight: 42, spec: spec), .inside)
        // The chin (content taller than the notch) and the slack are near, never inside.
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 38), frames: resting, contentHeight: 42, spec: spec), .near)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 49), frames: resting, contentHeight: 42, spec: spec), .near)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 625, y: 10), frames: resting, contentHeight: 32, spec: spec), .near)
        // Beyond the slack.
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 51), frames: resting, contentHeight: 42, spec: spec), .outside)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 600, y: 10), frames: resting, contentHeight: 32, spec: spec), .outside)
        // An open list is wide and tall: near across its body, inside still only over the notch.
        let list = NotchGeometry.frames(density: .list, metrics: m, spec: spec)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 500, y: 120), frames: list, contentHeight: 190, spec: spec), .near)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 120), frames: list, contentHeight: 190, spec: spec), .near)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 10), frames: list, contentHeight: 190, spec: spec), .inside)
        XCTAssertEqual(NotchGeometry.pointerZone(at: CGPoint(x: 735, y: 199), frames: list, contentHeight: 190, spec: spec), .outside)
    }

    func testDockDistance() {
        let m = ScreenMetrics.sampleNotched
        XCTAssertEqual(NotchGeometry.dockDistance(from: CGPoint(x: 735, y: 956), metrics: m), 0)
        XCTAssertEqual(NotchGeometry.dockDistance(from: CGPoint(x: 735, y: 900), metrics: m), 56)
    }
}

final class IslandScenarioTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(IslandScenario.parse("island:hover"), .hover)
        XCTAssertEqual(IslandScenario.parse("island:qaDetached"), .qaDetached)
        XCTAssertEqual(IslandScenario.parse("island:failureRetry"), .failureRetry)
        XCTAssertEqual(IslandScenario.parse("island:selectorSearchQuery"), .selectorSearchQuery)
        XCTAssertNil(IslandScenario.parse("island:nope"))
        XCTAssertNil(IslandScenario.parse("hover"))
    }

    func testEveryScenarioSeedsAConsistentState() {
        for scenario in IslandScenario.allCases {
            var s = IslandState()
            scenario.apply(to: &s)
            switch s.phase {
            case .review, .sending, .sendFailed: XCTAssertNotNil(s.review, "\(scenario)")
            case .quickAnswer: XCTAssertNotNil(s.quickAnswer, "\(scenario)")
            case .agentList: XCTAssertFalse(s.tasks.isEmpty, "\(scenario)")
            default: break
            }
        }
        var s = IslandState()
        IslandScenario.selectorSearchQuery.apply(to: &s)
        XCTAssertEqual(s.review?.searchResults.count, 3)
        XCTAssertEqual(s.review?.searchResults.map(\.chatName),
                       ["Agent routing", "Model routing benchmarks", "Routing intent tests"])
        IslandScenario.listAfterSend.apply(to: &s)
        XCTAssertTrue(s.tasks.contains { $0.id == s.recentlySentTaskId })
        IslandScenario.reviewStackHover.apply(to: &s)
        XCTAssertTrue(s.review!.referents.contains { $0.id == s.review?.hoveredReferentId })
        for scenario in [IslandScenario.selectorRecent, .selectorNewChatAI, .selectorNewChatContext, .selectorSearchAI] {
            scenario.apply(to: &s)
            XCTAssertTrue(s.review?.selector.isOpen == true, "\(scenario)")
        }
    }
}

@MainActor
final class SimulatedServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func catalog() -> SimulatedChatCatalog {
        let now = now
        return SimulatedChatCatalog(chats: Fixtures.chatCatalog(now: now), folders: Fixtures.contextFolders,
                                    choices: Fixtures.destinationChoices, timing: .instant, now: { now })
    }

    func testTranscriberStreamsThenFinishes() async throws {
        let t = SimulatedTranscriber(script: "one two three", timing: .instant)
        let stream = try await t.start()
        t.finish()
        var chunks: [TranscriptChunk] = []
        for try await c in stream { chunks.append(c) }
        XCTAssertEqual(chunks.last, .final("one two three"))
        XCTAssertEqual(chunks.count, 4)
    }

    func testTranscriberFailNext() async {
        let t = SimulatedTranscriber(script: "one two", timing: .instant)
        t.failNext = true
        do {
            let stream = try await t.start()
            t.finish()
            for try await _ in stream {}
            XCTFail("expected failure")
        } catch let e as ServiceUnavailable {
            XCTAssertEqual(e.failure.recovery, .retry)
        } catch { XCTFail("\(error)") }
    }

    func testTranscriberEmptyNextHearsNothing() async throws {
        let t = SimulatedTranscriber(script: "one two", timing: .instant)
        t.emptyNext = true
        let stream = try await t.start()
        t.finish()
        var chunks: [TranscriptChunk] = []
        for try await c in stream { chunks.append(c) }
        XCTAssertEqual(chunks, [.final("")])
    }

    func testAgentAskTokensReassemble() async throws {
        let agent = SimulatedAgentService(shortAnswer: "Hello there,\nworld.", longAnswer: "long", timing: .instant)
        var out = ""
        for try await token in agent.ask("hi", history: []) { out += token }
        XCTAssertEqual(out, "Hello there,\nworld.")
    }

    func testAgentDeliverFailsOnceThenLinksTheCapture() async throws {
        let agent = SimulatedAgentService(shortAnswer: "a", longAnswer: "b", timing: .instant)
        agent.failNextDelivery = true
        let draft = ReviewDraft(transcript: "Make the navbar padding match, please")
        let route = Fixtures.chatRouteMenu.recommended
        do { _ = try await agent.deliver(draft, to: route); XCTFail() } catch {}
        let task = try await agent.deliver(draft, to: route)
        XCTAssertEqual(task.state, .working)
        XCTAssertEqual(task.title, "Make the navbar padding match")
        XCTAssertEqual(task.destination, route.destination)
        XCTAssertEqual(task.captureId, "cap-\(task.id)")
        XCTAssertFalse(task.activity.isEmpty)
    }

    func testAgentFollowUpUpdatesActivityThenCompletes() async throws {
        let agent = SimulatedAgentService(shortAnswer: "a", longAnswer: "b", timing: .instant)
        let task = try await agent.deliver(ReviewDraft(transcript: "Fix it"), to: Fixtures.chatRouteMenu.recommended)
        var updates: [AgentTask] = []
        for await update in agent.taskUpdates {
            updates.append(update)
            if updates.count == 2 { break }
        }
        XCTAssertEqual(updates.map(\.id), [task.id, task.id])
        XCTAssertEqual(updates[0].state, .working)
        XCTAssertNotEqual(updates[0].activity, task.activity)
        XCTAssertEqual(updates[1].state, .complete)
        XCTAssertEqual(updates[1].activity, "Ready to review")
    }

    func testRoutingFailNextThenResolvesFromCatalog() async throws {
        let r = SimulatedChatRouting(recommended: Fixtures.chatRouteMenu.recommended, catalog: catalog(), timing: .instant)
        r.failNext = true
        do { _ = try await r.resolve(for: ReviewDraft(transcript: "x")); XCTFail() } catch {}
        let menu = try await r.resolve(for: ReviewDraft(transcript: "x"))
        XCTAssertEqual(menu.recommended, Fixtures.chatRouteMenu.recommended)
        XCTAssertEqual(menu.recent.count, 10)
        XCTAssertEqual(menu.destinations, Fixtures.destinationChoices)
    }

    func testRecentSortedAndCapped() async throws {
        let recent = try await catalog().recent(within: ChatRouteMenu.recentWindow)
        XCTAssertEqual(recent.count, 10)
        let dates = recent.compactMap(\.lastActiveAt)
        XCTAssertEqual(dates, dates.sorted(by: >))
        XCTAssertTrue(dates.allSatisfy { now.timeIntervalSince($0) < ChatRouteMenu.recentWindow })
        XCTAssertEqual(recent.first?.chatName, "app-ui-v1 settings")
    }

    func testSearchScopedAndCaseInsensitive() async throws {
        let c = catalog()
        let codex = try await c.search("ROUTING", in: Fixtures.codex)
        XCTAssertEqual(codex.map(\.chatName), ["Agent routing", "Model routing benchmarks", "Routing intent tests"])
        let chatGPT = try await c.search("routing", in: Fixtures.chatGPT)
        XCTAssertEqual(chatGPT.map(\.chatName), ["Model routing"])
        let none = try await c.search("   ", in: Fixtures.codex)
        XCTAssertTrue(none.isEmpty)
    }

    func testDestinationsHaveOneRecommendation() async throws {
        let choices = try await catalog().destinations()
        XCTAssertEqual(choices.filter(\.isRecommended).map(\.app), [Fixtures.claudeCode])
        let folders = try await catalog().folders(for: Fixtures.claudeCode)
        XCTAssertGreaterThan(folders.count, 5, "enough to scroll")
    }
}
