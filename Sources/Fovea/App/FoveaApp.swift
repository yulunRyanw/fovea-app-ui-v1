import SwiftUI
import AppKit
import FoveaCore

@main
struct FoveaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var model = AppModel(services: .shared)

    var body: some Scene {
        Window("Fovea", id: "main") {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: Tokens.Layout.window.width, height: Tokens.Layout.window.height)
        // The content has one size, so the window cannot be resized or zoomed.
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            IslandCommands()
        }
    }
}

/// Prototype control surface for the Island: jump to any state from the menu bar.
struct IslandCommands: Commands {
    var body: some Commands {
        CommandMenu("Island") {
            ForEach(Array(IslandScenario.allCases.enumerated()), id: \.element) { index, scenario in
                Button(scenario.title) { AppServices.shared.islandController?.model.jump(to: scenario) }
                    .keyboardShortcut(shortcut(index), modifiers: [.command, .option])
            }
            Divider()
            Button("Reset Island") { AppServices.shared.islandController?.model.reset() }
                .keyboardShortcut("r", modifiers: [.command, .option])
        }
    }

    /// ⌘⌥1…9, ⌘⌥0, then ⌘⌥A… for the rest.
    private func shortcut(_ index: Int) -> KeyEquivalent {
        if index < 9 { return KeyEquivalent(Character(String(index + 1))) }
        if index == 9 { return "0" }
        let letters = Array("abcdefghij")
        return KeyEquivalent(letters[min(index - 10, letters.count - 1)])
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if Snapshots.runIfRequested() {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Running from `swift run` doesn't come to the foreground on its own.
        NSApp.setActivationPolicy(.regular)
        if ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == nil {
            NSApp.activate(ignoringOtherApps: true)
        }
        // No app bundle when run from SwiftPM, so the Dock icon is set at runtime.
        if let url = FoveaResources.url("AppIcon.png"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        startIsland()
    }

    /// The Island lives for the whole process, independent of the window.
    private func startIsland() {
        let services = AppServices.shared
        guard services.options.islandEnabled, !Snapshots.isRunning else { return }
        let screen = ScreenObserver.screenWithPointer ?? NSScreen.main
        let metrics = screen.map(ScreenObserver.metrics(for:)) ?? .sampleNotched
        let model = services.makeIslandModel(metrics: metrics)
        let controller = IslandController(model: model)
        services.islandController = controller
        controller.start()
        if let scenario = services.options.islandScenario {
            model.jump(to: scenario)
        }
        if services.options.islandSmoke {
            IslandSmoke.run(controller: controller)
        }
        if let suite = services.options.islandEvalSuite {
            IslandEval.run(controller: controller, suite: suite)
        }
    }

    // The window is a container, not the app. Quit lives in the app menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
