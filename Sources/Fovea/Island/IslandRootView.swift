import SwiftUI
import FoveaCore

/// Root of the notch panel: an oversized transparent canvas with the island pinned to
/// its top-center. Only the island's content animates; the window never moves.
struct IslandRootView: View {
    let model: IslandModel

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            IslandSurface(model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

/// The black shape and whatever the current phase shows inside it. Geometry changes
/// arrive inside `IslandModel.send`'s animation transaction; the surface itself never
/// changes identity, so every morph is one continuous shape.
struct IslandSurface: View {
    let model: IslandModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotMode) private var snapshotMode

    var body: some View {
        let frames = model.frames
        let phase = model.phase
        let shape = IslandShape(topRadius: frames.topRadius, bottomRadius: frames.bottomRadius)

        // The phase content lives inside one container. Modifiers applied straight to the
        // `Group { switch }` are applied per branch, so during a phase change two black
        // shapes (old and new size) would crossfade for 0.14 s and nothing would morph.
        // With a real container the shape, width and height belong to one identity and
        // animate from one phase's geometry to the next while the content crossfades.
        ZStack(alignment: .top) {
            // One element keyed by the layout key: when the key changes, ForEach removes the
            // old element and inserts the new one in the same pass, so their transitions
            // overlap (a crossfade). Changing `.id()` on a `switch` played them one after
            // the other: the new content only started fading in once the old had gone.
            ForEach([PhaseSlot(key: model.state.layoutKey, phase: phase)]) { slot in
                content(slot.phase, frames: frames)
                    .transition(snapshotMode ? .identity : (reduceMotion ? .opacity.animation(.easeOut(duration: 0.1)) : .islandContent))
            }
        }
            .frame(width: max(0, frames.bodyWidth))
            .padding(.horizontal, frames.topRadius)
            .frame(minHeight: frames.minHeight, alignment: .top)
            .background(Tokens.Island.Colors.surface)
            .clipShape(shape)
            // The product draws no idle island: when nothing is happening the notch is bare.
            .opacity(phase == .resting && !model.state.showsReceiver ? 0 : 1)
            .overlay(alignment: .top) {
                // Kills the hairline between the shape and the physical notch.
                Rectangle()
                    .fill(Tokens.Island.Colors.surface)
                    .frame(height: 1)
                    .padding(.horizontal, frames.topRadius)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bounds in
                model.contentBounds = bounds
                if IslandModel.logging {
                    print("island: bounds \(Int(bounds.width))x\(Int(bounds.height)) t=\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Fovea")
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// The recording row's own width (the compact surface's body), whatever the surface does.
    private var compactRowWidth: CGFloat {
        let spec = Tokens.Island.Layout.layoutSpec
        return NotchGeometry.frames(density: .voice, metrics: model.metrics, spec: spec,
                                    forceSoftware: model.forceSoftwareIsland,
                                    compactContentWidth: model.state.compactContentWidth).bodyWidth
    }

    /// The body width this phase is laid out at. Fixed per phase, so an exiting view keeps
    /// its layout while the surface animates to the next width and simply gets clipped.
    private func bodyWidth(for phase: IslandPhase) -> CGFloat {
        let spec = Tokens.Island.Layout.layoutSpec
        let compact: CGFloat
        switch phase {
        case .listening, .transcribing:
            compact = model.state.sessionKind == .quickAnswer
                ? (model.state.destination == .automatic ? spec.recordingRowWidthQuickAnswer : spec.recordingRowWidthQuickAnswerChosen)
                : spec.recordingRowWidthVoiceFlow
        case .processing: compact = spec.processingRowWidth
        case .delivered: compact = spec.deliveredRowWidth
        default: compact = model.state.compactContentWidth
        }
        // The state's density, not the phase's: the recording phase widens into the
        // conversation picker without changing phase.
        let density = phase == model.phase ? model.state.density : phase.density
        return NotchGeometry.frames(density: density, metrics: model.metrics, spec: spec,
                                    forceSoftware: model.forceSoftwareIsland, compactContentWidth: compact).bodyWidth
    }

    @ViewBuilder
    private func content(_ phase: IslandPhase, frames: IslandFrames) -> some View {
        let notchHeight = frames.notch.height
        Group {
            switch phase {
            case .quickAnswer(.detached) where model.state.showsReceiver:
                DockReceiverView(ready: model.state.dockZone == .ready, notchHeight: notchHeight,
                                 depth: Tokens.Island.Layout.dockReceiverBelow)
            case .resting, .quickAnswer(.detached):
                RestingView(tasks: model.state.tasks, notchHeight: notchHeight)
            case .agentList:
                AgentListView(model: model)
                    .padding(.top, notchHeight)
            case .listening:
                // The row keeps its identity; the picker drops under it (the engine's
                // review row + selector panel) while the surface widens around both.
                VStack(spacing: 0) {
                    FoveaRecordingRow(round: FoveaRound(model.state.sessionKind), level: model.audioLevel,
                                      materials: model.state.capturedMaterials,
                                      destination: model.state.destination, menuOpen: model.state.destinationMenuOpen)
                        // The row keeps its compact width, centred under the notch; only the
                        // surface widens around it.
                        .frame(width: compactRowWidth)
                        .frame(maxWidth: .infinity)
                    if model.state.destinationMenuOpen {
                        FoveaDestinationPanel(model: model)
                            .transition(.opacity)
                    }
                }
                .padding(.top, notchHeight)
            case .transcribing, .processing:
                FoveaProcessingRow(round: FoveaRound(model.state.sessionKind), startedAt: model.state.processingStartedAt,
                                   target: RehearsalData.deliveryTarget)
                    .padding(.top, notchHeight)
            case .delivered(let target):
                FoveaDeliveredRow(target: target)
                    .padding(.top, notchHeight)
            case .retained:
                FoveaRetainedCard(text: model.state.retainedText, onDismiss: { model.send(.dismissRetained) })
                    .padding(.top, notchHeight)
            case .transcriptionFailed(let failure):
                Group {
                    if failure.recovery == .retry {
                        VoiceRetryView(failure: failure, retry: { model.send(.retry) })
                            .reportRect("retry", in: model)
                    } else {
                        VoiceFailureView(failure: failure,
                                         act: { model.send(.retry) },
                                         dismiss: { model.send(.cancel) })
                    }
                }
                .frame(height: Tokens.Island.Layout.voiceBelow)
                .padding(.top, notchHeight)
            case .review, .sending, .sendFailed:
                ReviewView(model: model)
                    .padding(.top, notchHeight)
            case .quickAnswer(.summary):
                QuickAnswerSummaryView(model: model)
                    .padding(.top, notchHeight)
            case .quickAnswer(.attached):
                FoveaConversationPanel(model: model, host: .attached)
                    .padding(.top, notchHeight)
            case .quickAnswer(.reading):
                FoveaConversationPanel(model: model, host: .reading(contentHeight: frames.minHeight - notchHeight))
                    .padding(.top, notchHeight)
            }
        }
        .frame(width: max(0, bodyWidth(for: phase)))
    }

    private struct PhaseSlot: Identifiable {
        let key: String
        let phase: IslandPhase
        var id: String { key }
    }

}
