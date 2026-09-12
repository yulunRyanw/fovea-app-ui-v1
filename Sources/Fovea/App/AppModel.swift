import SwiftUI
import AppKit
import FoveaCore

// MARK: - Demo options (CLI)

struct DemoOptions {
    enum Feed { case populated, loading, empty }
    var feed: Feed = .populated
    var usageUnavailable = false
    /// Fail the first save of Automatic Updates so the row-level Retry state is visible.
    var flakySave = true
    var initialRoute: AppRoute = .home
    var persist = true
    /// Island: start in a scenario, hide it, force the software island, empty task list,
    /// or opt into the real microphone/speech when running unbundled.
    var islandScenario: IslandScenario? = nil
    var islandEnabled = true
    var islandFlat = false
    var islandNoTasks = false
    var islandReal = false
    /// Force the simulated island services even when bundled (for the eval harness).
    var islandSimulated = false
    /// Scripted run through every Island transition on the live panel, then quit.
    var islandSmoke = false
    /// Run an eval suite (`island-eval:<suite>`), then quit with a pass/fail code.
    var islandEvalSuite: String? = nil
    /// Walk the Quick Answer island sequence for design review:
    /// `island-rehearsal` (step with Space), `island-rehearsal:auto`, `island-rehearsal:record`.
    var islandRehearsal: String? = nil

    static func parse(_ args: [String] = CommandLine.arguments) -> DemoOptions {
        var o = DemoOptions()
        // The rehearsal bundle opens straight into the console: every flow, every key, live.
        if Bundle.main.bundleIdentifier?.hasSuffix(".rehearsal") == true {
            o.islandRehearsal = "console"
            o.persist = false
        }
        var i = 0
        while i < args.count {
            let a = args[i]
            func value() -> String? { i + 1 < args.count ? args[i + 1] : nil }
            switch a {
            case "--demo":
                if let v = value() {
                    for flag in v.split(separator: ",") {
                        switch flag {
                        case "loading": o.feed = .loading
                        case "empty": o.feed = .empty
                        case "usage-unavailable": o.usageUnavailable = true
                        case "no-flaky": o.flakySave = false
                        case "ephemeral": o.persist = false
                        case "island-off": o.islandEnabled = false
                        case "island-flat": o.islandFlat = true
                        case "island-no-tasks": o.islandNoTasks = true
                        case "island-real": o.islandReal = true
                        case "island-simulated": o.islandSimulated = true
                        case "island-smoke": o.islandSmoke = true
                        case "island-rehearsal": o.islandRehearsal = "manual"
                        default:
                            if flag.hasPrefix("island-rehearsal:") { o.islandRehearsal = String(flag.dropFirst("island-rehearsal:".count)) }
                            else if flag.hasPrefix("island-eval:") { o.islandEvalSuite = String(flag.dropFirst("island-eval:".count)) }
                            else if let scenario = IslandScenario.parse(String(flag)) { o.islandScenario = scenario }
                        }
                    }
                    i += 1
                }
            case "--route":
                if let v = value(), let r = AppRoute.parse(v) { o.initialRoute = r; i += 1 }
            default: break
            }
            i += 1
        }
        return o
    }
}

// MARK: - Row save state

enum RowSaveState: Equatable {
    case idle, saving, failed(String)
    var isFailed: Bool { if case .failed = self { return true } else { return false } }
}

// MARK: - Settings

@MainActor @Observable
final class SettingsModel {
    private(set) var settings: UserSettings
    private(set) var rowState: [UserSettings.Key: RowSaveState] = [:]
    private let store: any PersistentStore<UserSettings>
    private var lastFailedMutation: [UserSettings.Key: (inout UserSettings) -> Void] = [:]

    init(store: any PersistentStore<UserSettings>) {
        self.store = store
        self.settings = store.load() ?? .default
    }

    func state(_ key: UserSettings.Key) -> RowSaveState { rowState[key] ?? .idle }

    /// Optimistic update: the value changes now, then persists. On failure the row is
    /// marked and keeps the optimistic value so Retry can resend it.
    func update(_ key: UserSettings.Key, _ mutate: @escaping (inout UserSettings) -> Void) {
        mutate(&settings)
        rowState[key] = .saving
        let snapshot = settings
        Task {
            do {
                try await store.save(snapshot, changed: key.rawValue)
                if rowState[key] == .saving { rowState[key] = .idle }
            } catch {
                lastFailedMutation[key] = mutate
                rowState[key] = .failed((error as? StoreError)?.message ?? "Couldn’t save.")
            }
        }
    }

    func retry(_ key: UserSettings.Key) {
        let mutate = lastFailedMutation[key] ?? { _ in }
        lastFailedMutation[key] = nil
        update(key, mutate)
    }
}

// MARK: - Dictionary

@MainActor @Observable
final class DictionaryModel {
    private(set) var terms: [DictionaryTerm]
    var autoLearn: Bool { didSet { persist() } }
    private let store: any PersistentStore<DictionaryState>

    struct DictionaryState: Codable, Sendable {
        var terms: [DictionaryTerm]
        var autoLearn: Bool
    }

    init(store: any PersistentStore<DictionaryState>) {
        self.store = store
        let state = store.load() ?? DictionaryState(terms: Fixtures.dictionary(), autoLearn: true)
        terms = state.terms
        autoLearn = state.autoLearn
    }

    /// Six most-used terms, for the compact page.
    var recent: [DictionaryTerm] {
        Array(terms.sorted { ($0.useCount, $1.createdAt) > ($1.useCount, $0.createdAt) }.prefix(6))
    }

    var alphabetical: [DictionaryTerm] {
        terms.sorted { $0.preferredSpelling.localizedCaseInsensitiveCompare($1.preferredSpelling) == .orderedAscending }
    }

    func matches(_ query: String) -> [DictionaryTerm] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return alphabetical }
        return alphabetical.filter { t in
            t.preferredSpelling.localizedCaseInsensitiveContains(q) ||
            t.aliases.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    func exists(_ word: String) -> Bool {
        terms.contains { $0.preferredSpelling.caseInsensitiveCompare(word) == .orderedSame }
    }

    @discardableResult
    func add(_ word: String) -> DictionaryTerm? {
        let w = word.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !exists(w) else { return nil }
        let term = DictionaryTerm(id: "term-\(UUID().uuidString.prefix(8))", preferredSpelling: w,
                                  aliases: [], source: .manual, createdAt: Date(), useCount: 0)
        terms.insert(term, at: 0)
        persist()
        return term
    }

    func update(_ term: DictionaryTerm) {
        guard let i = terms.firstIndex(where: { $0.id == term.id }) else { return }
        terms[i] = term
        persist()
    }

    func delete(_ id: String) {
        terms.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        let state = DictionaryState(terms: terms, autoLearn: autoLearn)
        Task { try? await store.save(state, changed: "dictionary") }
    }
}

// MARK: - Shortcuts

@MainActor @Observable
final class ShortcutModel {
    private(set) var bindings: [ShortcutAction: KeyBinding]
    /// The row currently recording a new chord, if any. The Island pauses its hotkeys meanwhile.
    var recordingAction: ShortcutAction?
    private let store: any PersistentStore<ShortcutBindings>

    init(store: any PersistentStore<ShortcutBindings>) {
        self.store = store
        bindings = (store.load() ?? .defaults).bindings
    }

    var conflicts: [ShortcutAction: ShortcutAction] { ShortcutConflicts.detect(bindings) }

    func set(_ action: ShortcutAction, _ binding: KeyBinding?) {
        bindings[action] = binding
        let snapshot = ShortcutBindings(bindings: bindings)
        Task { try? await store.save(snapshot, changed: action.rawValue) }
    }
}

// MARK: - Connectors

@MainActor @Observable
final class ConnectorsModel {
    private(set) var connectors: [Connector]
    private(set) var connecting: Set<String> = []
    private(set) var connectError: [String: String] = [:]
    private let store: any PersistentStore<[Connector]>

    init(store: any PersistentStore<[Connector]>) {
        self.store = store
        connectors = store.load() ?? Fixtures.connectors
    }

    var connected: [Connector] { connectors.filter { $0.status != .available } }
    var available: [Connector] { connectors.filter { $0.status == .available } }
    func connector(_ id: String) -> Connector? { connectors.first { $0.id == id } }

    /// Simulated auth flow: a short pending state, then connected.
    func connect(_ id: String) {
        guard connectors.contains(where: { $0.id == id }) else { return }
        connecting.insert(id)
        connectError[id] = nil
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard connecting.contains(id) else { return }   // cancelled
            connecting.remove(id)
            mutate(id) { $0.status = .connected; $0.granted = Set($0.permissions); $0.detail = "Connected just now" }
        }
    }

    func cancelConnect(_ id: String) { connecting.remove(id) }

    func disconnect(_ id: String) {
        mutate(id) { $0.status = .available; $0.detail = nil }
    }

    func setPermission(_ id: String, _ permission: String, granted: Bool) {
        mutate(id) { if granted { $0.granted.insert(permission) } else { $0.granted.remove(permission) } }
    }

    private func mutate(_ id: String, _ change: (inout Connector) -> Void) {
        guard let i = connectors.firstIndex(where: { $0.id == id }) else { return }
        change(&connectors[i])
        let snapshot = connectors
        Task { try? await store.save(snapshot, changed: id) }
    }
}

// MARK: - App

enum UsageState: Equatable {
    case loaded(UsageSummary)
    case unavailable
}

enum FeedState: Equatable {
    case loading, ready, empty
}

@MainActor @Observable
final class AppModel {
    // Navigation
    private(set) var route: AppRoute
    private var history: [AppRoute] = []
    var settingsRoute: SettingsRoute = .default

    // Home
    var searchQuery = ""
    private(set) var feedState: FeedState
    var openCaptureId: String?
    /// Frame (root coordinates) of the feed card the open detail zoomed out of; nil when
    /// opened by route, so the card zooms from the center.
    private(set) var detailOrigin: CGRect?
    private var pendingOrigin: CGRect?
    private(set) var retrying: Set<String> = []
    let usage: UsageState
    let permissions: [SystemPermission: Bool]

    // Settings aggregates
    let settings: SettingsModel
    let dictionary: DictionaryModel
    let shortcuts: ShortcutModel
    let connectors: ConnectorsModel

    /// Capture history, shared with the Island (which appends on Send).
    let captureLog: CaptureLog
    let services: AppServices
    let options: DemoOptions
    private var commandTask: Task<Void, Never>?

    convenience init(options: DemoOptions = .parse(), defaults: UserDefaults = .standard) {
        self.init(services: AppServices(options: options, defaults: defaults))
    }

    init(services: AppServices) {
        self.services = services
        let options = services.options
        self.options = options
        settings = services.settings
        dictionary = services.dictionary
        shortcuts = services.shortcuts
        connectors = services.connectors
        captureLog = services.captureLog

        feedState = options.feed == .loading ? .loading : (options.feed == .empty ? .empty : .ready)
        usage = options.usageUnavailable ? .unavailable : .loaded(Fixtures.usage())
        permissions = Fixtures.permissions

        route = .home
        apply(options.initialRoute)

        commandTask = Task { [weak self] in
            for await command in services.commands.commands {
                guard let self else { return }
                services.handle(command, appModel: self)
            }
        }
    }

    var captures: [Capture] { captureLog.captures }

    var isSettings: Bool { route.isSettings }

    var filteredCaptures: [Capture] { CaptureSearch.filter(captures, query: searchQuery) }
    var openCapture: Capture? { openCaptureId.flatMap { id in captures.first { $0.id == id } } }

    // MARK: Navigation

    func open(_ target: AppRoute) {
        history.append(route)
        apply(target)
    }

    func back() {
        guard let previous = history.popLast() else { showHome(); return }
        apply(previous)
    }

    func showHome() {
        history.removeAll()
        apply(.home)
    }

    func showSettings(_ target: SettingsRoute) {
        if isSettings { apply(.settings(target)) } else { open(.settings(target)) }
    }

    func showSettings(_ category: SettingsCategory) { showSettings(category.defaultRoute) }

    private func apply(_ target: AppRoute) {
        route = target
        switch target {
        case .home:
            openCaptureId = nil
        case .captureDetail(let id):
            openCaptureId = id
            detailOrigin = pendingOrigin
            pendingOrigin = nil
        case .settings(let r):
            settingsRoute = r
        case .connectorDetail:
            settingsRoute = SettingsRoute(.connected)
        }
    }

    // MARK: Captures

    /// `origin` is the clicked feed card's frame in root coordinates; the detail card zooms from it.
    func openDetail(_ capture: Capture, from origin: CGRect? = nil) {
        pendingOrigin = origin
        open(.captureDetail(capture.id))
    }

    func closeDetail() {
        if case .captureDetail = route { back() } else { openCaptureId = nil }
    }

    func copy(_ capture: Capture) { NSPasteboard.copy(capture.payloadText) }

    func retryDelivery(_ capture: Capture) {
        guard captureLog.capture(capture.id) != nil else { return }
        retrying.insert(capture.id)
        captureLog.update(id: capture.id) { $0.deliveryStatus = .pending }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            retrying.remove(capture.id)
            captureLog.update(id: capture.id) { $0.deliveryStatus = .delivered }
        }
    }

    func finishLoading() {
        guard feedState == .loading else { return }
        feedState = captures.isEmpty ? .empty : .ready
    }
}
