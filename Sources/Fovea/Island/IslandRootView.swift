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

        content(phase, frames: frames)
            .frame(width: max(0, frames.bodyWidth))
            .padding(.horizontal, frames.topRadius)
            .frame(minHeight: frames.minHeight, alignment: .top)
            .background(Tokens.Island.Colors.surface)
            .clipShape(shape)
            .overlay(alignment: .top) {
                // Kills the hairline between the shape and the physical notch.
                Rectangle()
                    .fill(Tokens.Island.Colors.surface)
                    .frame(height: 1)
                    .padding(.horizontal, frames.topRadius)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.contentBounds = $0 }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Fovea")
            .accessibilityAddTraits(.updatesFrequently)
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
                ListeningView(level: model.audioLevel)
                    .frame(height: Tokens.Island.Layout.voiceBelow)
                    .padding(.top, notchHeight)
            case .transcribing:
                TranscribingView(text: model.state.partialTranscript)
                    .frame(height: Tokens.Island.Layout.voiceBelow)
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
            case .quickAnswer(.attached):
                QuickAnswerView(model: model, host: .attached)
                    .padding(.top, notchHeight)
            }
        }
        .id(model.state.layoutKey)
        .transition(snapshotMode ? .identity : (reduceMotion ? .opacity.animation(.easeOut(duration: 0.1)) : .islandContent))
    }

}
