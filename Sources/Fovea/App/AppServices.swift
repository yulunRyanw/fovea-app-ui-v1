import SwiftUI
import AppKit
import FoveaCore

/// Composition root. Built once per process (or per snapshot) and shared by the window
/// and the Island, which otherwise never see each other.
@MainActor
final class AppServices {
    static let shared = AppServices(options: .parse())

    let options: DemoOptions
    let settings: SettingsModel
    let dictionary: DictionaryModel
    let shortcuts: ShortcutModel
    let connectors: ConnectorsModel
    let ledger: TaskLedger
    let captureLog: CaptureLog
    let commands = AppCommandBus()
    let islandPrefs: any PersistentStore<IslandPrefs>
    /// The window scene's `openWindow`, captured by RootView so AppKit code can reopen it.
    var openMainWindow: (() -> Void)?
    /// Set by the AppDelegate once the island is up.
    var islandController: IslandController?
    /// The live hotkey monitor, so the Shortcuts recorder can hear raw fn edges.
    private(set) var hotkeys: (any HotkeyMonitoring)?

    init(options: DemoOptions, defaults: UserDefaults = .standard) {
        self.options = options
        func store<T: Codable & Sendable>(_ key: String, _ seed: T? = nil) -> any PersistentStore<T> {
            options.persist ? UserDefaultsStore<T>(defaults: defaults, key: key) : InMemoryStore<T>(seed)
        }
        let settingsStore: any PersistentStore<UserSettings> = store(StoreKeys.settings)
        settings = SettingsModel(store: options.flakySave
            ? FlakyStore(wrapping: settingsStore, failingKey: UserSettings.Key.automaticUpdates.rawValue)
            : settingsStore)
        dictionary = DictionaryModel(store: store(StoreKeys.dictionary))
        shortcuts = ShortcutModel(store: store(StoreKeys.shortcuts))
        connectors = ConnectorsModel(store: store(StoreKeys.connectors))
        islandPrefs = store(StoreKeys.islandPrefs)
        ledger = TaskLedger(tasks: options.islandNoTasks ? [] : Fixtures.agentTasks())
        captureLog = CaptureLog(captures: options.feed == .empty ? [] : Fixtures.captures())
    }

    /// Real microphone and speech only when the process can show permission prompts
    /// (a bundle) or the user opted in; hotkeys are always real outside snapshots.
    func makeIslandServices() -> IslandServices {
        let simulated = IslandServices.simulated()
        let snapshot = Snapshots.isRunning
        // `island-simulated` forces the fixtures even when bundled, for the eval harness.
        let real = !snapshot && !options.islandSimulated && (Bundle.main.bundleIdentifier != nil || options.islandReal)
        let hotkeys: any HotkeyMonitoring = snapshot ? NoHotkeys() : HotkeyMonitor()
        self.hotkeys = hotkeys
        return IslandServices(
            hotkeys: hotkeys,
            meter: real ? AVAudioLevelMeter() : simulated.meter,
            transcriber: real ? SpeechTranscriber() : simulated.transcriber,
            routing: simulated.routing,
            catalog: simulated.catalog,
            agent: simulated.agent)
    }

    func makeIslandModel(metrics: ScreenMetrics, services: IslandServices? = nil) -> IslandModel {
        let model = IslandModel(services: services ?? makeIslandServices(), ledger: ledger, captureLog: captureLog,
                                commands: commands, shortcuts: shortcuts, settings: settings, metrics: metrics)
        model.forceSoftwareIsland = options.islandFlat
        return model
    }

    // MARK: - Commands from the Island

    func handle(_ command: AppCommand, appModel: AppModel) {
        switch command {
        case .openMain(let route):
            appModel.open(route)
            showMainWindow()
        case .revealTask(let task):
            if let id = task.captureId, captureLog.capture(id) != nil {
                appModel.open(.captureDetail(id))
            } else {
                appModel.showHome()
            }
            showMainWindow()
        case .openSystemSettings(let permission):
            if let url = URL(string: permission.systemSettingsURL) { NSWorkspace.shared.open(url) }
        }
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let openMainWindow {
            openMainWindow()
        } else if let window = NSApp.windows.first(where: { $0.title == "Fovea" && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // The scene was torn down; a reopen event makes SwiftUI rebuild it.
            let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
                                               targetDescriptor: .currentProcess(),
                                               returnID: AEReturnID(kAutoGenerateReturnID),
                                               transactionID: AETransactionID(kAnyTransactionID))
            _ = try? event.sendEvent(options: [.noReply], timeout: 1)
        }
    }
}
