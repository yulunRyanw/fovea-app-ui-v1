import SwiftUI
import AppKit
import FoveaCore

struct RootView: View {
    /// Feed cards report their frames in this space so the detail card can zoom from them.
    static let coordinateSpace = "root"

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Every screen is laid out on the design canvas and scaled into the fixed window,
        // so all proportions survive the smaller size.
        let canvas = Tokens.Layout.designCanvas
        let theme = Tokens.Colors.theme(model.themeName)
        let detailOpen = model.openCaptureId != nil
        ZStack {
            // Home stays mounted so its scroll position and search query survive Settings.
            // While a detail card is open it takes no input; only the outside-click layer does.
            HomeView()
                .opacity(model.isSettings ? 0 : 1)
                .disabled(model.isSettings || detailOpen)
                .scrollDisabled(detailOpen)
                .accessibilityHidden(model.isSettings || detailOpen)

            if model.isSettings {
                SettingsSplitView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let capture = model.openCapture {
                DetailLayer(capture: capture, canvas: canvas)
                    .transition(DetailZoom.transition(origin: model.detailOrigin, canvas: canvas,
                                                      reduceMotion: reduceMotion))
                    .zIndex(2)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .coordinateSpace(name: RootView.coordinateSpace)
        .animation(Tokens.Motion.animation(model.openCaptureId == nil ? .detailClose : .detailOpen,
                                           reduceMotion: reduceMotion, fadeOnly: true), value: model.openCaptureId)
        .animation(Tokens.Motion.animation(.select, reduceMotion: reduceMotion, fadeOnly: true), value: model.isSettings)
        .scaleEffect(Tokens.Layout.uiScale, anchor: .topLeading)
        .frame(width: Tokens.Layout.window.width, height: Tokens.Layout.window.height, alignment: .topLeading)
        .clipped()
        .background(Tokens.Colors.canvas)
        .environment(\.foveaTheme, theme)
        .tint(Tokens.Colors.emphasis)
        .background(WindowAccessor { window in
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
        })
        .background {
            // ⌘, opens Settings, as on every Mac app.
            Button("Settings") { model.showSettings(.account) }
                .keyboardShortcut(",", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
        .onAppear {
            // Lets the Island (AppKit side) bring this window back after it was closed.
            model.services.openMainWindow = { openWindow(id: "main") }
        }
    }
}
