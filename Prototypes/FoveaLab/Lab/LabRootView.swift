import SwiftUI
import FoveaCore

/// Switches between the four directions on the chosen canvas, laid out on the shipping
/// design canvas (1180×819) and scaled into the 980×680 window exactly as RootView does.
struct LabRootView: View {
    @Environment(LabState.self) private var state

    var body: some View {
        let canvas = Tokens.Layout.designCanvas
        ZStack {
            switch state.direction {
            case .paper: PaperView().transition(.opacity)
            case .studio: StudioView().transition(.opacity)
            case .spaces: SpacesView().transition(.opacity)
            case .threads: ThreadsView().transition(.opacity)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .background(state.canvas.color)
        .animation(Tokens.Motion.animation(.select, reduceMotion: state.reduceMotion, fadeOnly: true), value: state.direction)
        .scaleEffect(Tokens.Layout.uiScale, anchor: .topLeading)
        .frame(width: Tokens.Layout.window.width, height: Tokens.Layout.window.height, alignment: .topLeading)
        .clipped()
        .background(state.canvas.color)
        .environment(\.labReduceMotion, state.reduceMotion)
        .tint(Tokens.Colors.ink)
        .preferredColorScheme(.light)
    }
}
