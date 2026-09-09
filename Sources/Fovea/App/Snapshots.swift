import SwiftUI
import AppKit
import FoveaCore

private struct SnapshotVariantKey: EnvironmentKey { static let defaultValue: String? = nil }
extension EnvironmentValues {
    /// Snapshot-only UI state that normally needs interaction (expanded list, recording…).
    var snapshotVariant: String? {
        get { self[SnapshotVariantKey.self] }
        set { self[SnapshotVariantKey.self] = newValue }
    }
}

// Dev-only: `Fovea --snapshot <dir>` renders each route to PNG and exits.
@MainActor
enum Snapshots {
    struct Shot {
        let name: String
        let size: CGSize
        var route: String = "home"
        var demo: String = "no-flaky,ephemeral"
        var search: String = ""
        var forceActions: String? = nil
        var variant: String? = nil
        var theme: ThemeName? = nil
        /// Render the Island in this scenario instead of the window.
        var island: IslandScenario? = nil
        /// Island on a display without a notch.
        var flat = false
    }

    /// True while `--snapshot` renders; the live Island and hotkeys stay off.
    static private(set) var isRunning = false
    static let islandStage = CGSize(width: 900, height: 520)

    static let wide = Tokens.Layout.window

    static let shots: [Shot] = [
        Shot(name: "home-1180", size: wide),
        Shot(name: "home-search", size: wide, search: "prisma"),
        Shot(name: "home-no-results", size: wide, search: "kubernetes"),
        Shot(name: "home-empty", size: wide, demo: "empty,no-flaky,ephemeral"),
        Shot(name: "home-loading", size: wide, demo: "loading,no-flaky,ephemeral"),
        Shot(name: "home-usage-unavailable", size: wide, demo: "usage-unavailable,no-flaky,ephemeral"),
        Shot(name: "home-hover", size: wide, forceActions: "cap-mountain"),
        Shot(name: "home-theme-citrus", size: wide, theme: .citrus),
        Shot(name: "home-theme-orchard", size: wide, theme: .orchard),
        Shot(name: "home-theme-dusk", size: wide, theme: .dusk),
        Shot(name: "home-theme-canyon", size: wide, theme: .canyon),
        Shot(name: "home-theme-blush", size: wide, theme: .blush),
        Shot(name: "home-theme-roast", size: wide, theme: .roast),
        Shot(name: "capture-detail", size: wide, route: "captures/cap-mountain"),
        Shot(name: "capture-detail-code", size: wide, route: "captures/cap-code"),
        Shot(name: "capture-detail-voice", size: wide, route: "captures/cap-error"),
        Shot(name: "capture-detail-quick-answer", size: wide, route: "captures/cap-update"),
        Shot(name: "capture-detail-referents", size: wide, route: "captures/cap-desk"),
        Shot(name: "capture-detail-shelf", size: wide, route: "captures/cap-desk", variant: "detail-shelf"),
        Shot(name: "settings-account", size: wide, route: "settings/account"),
        Shot(name: "settings-account-canyon", size: wide, route: "settings/account", theme: .canyon),
        Shot(name: "settings-typography", size: wide, route: "settings/typography"),
        Shot(name: "settings-eye-tracking", size: wide, route: "settings/eye-tracking"),
        Shot(name: "settings-voice-capture", size: wide, route: "settings/voice-capture"),
        Shot(name: "settings-dictionary", size: wide, route: "settings/dictionary"),
        Shot(name: "settings-dictionary-expanded", size: wide, route: "settings/dictionary", variant: "dictionary-expanded"),
        Shot(name: "settings-dictionary-edit", size: wide, route: "settings/dictionary", variant: "dictionary-edit"),
        Shot(name: "settings-shortcuts", size: wide, route: "settings/shortcuts"),
        Shot(name: "settings-shortcuts-recording", size: wide, route: "settings/shortcuts", variant: "shortcut-recording"),
        Shot(name: "settings-connectors", size: wide, route: "settings/connectors"),
        Shot(name: "settings-connector-detail", size: wide, route: "settings/connectors/cursor"),
        Shot(name: "settings-plan", size: wide, route: "settings/plan"),
    ] + IslandScenario.allCases.map { scenario in
        Shot(name: "island-\(scenario.rawValue)", size: islandStage, island: scenario)
    } + [
        Shot(name: "island-flat-resting", size: islandStage, island: .resting, flat: true),
        Shot(name: "island-flat-hover", size: islandStage, island: .hover, flat: true),
        Shot(name: "island-flat-review", size: islandStage, island: .reviewCollapsed, flat: true),
    ]

    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshot"), args.count > flag + 1 else { return false }
        let dir = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let only = args.firstIndex(of: "--only").flatMap { args.count > $0 + 1 ? args[$0 + 1] : nil }
        isRunning = true

        for shot in shots where only == nil || shot.name == only! {
            if let scenario = shot.island {
                let view = IslandSnapshotStage(scenario: scenario, flat: shot.flat, size: shot.size)
                    .environment(\.snapshotMode, true)
                guard let image = render(view, size: shot.size) else { print("failed \(shot.name)"); continue }
                if let data = image.representation(using: .png, properties: [:]) {
                    try? data.write(to: dir.appendingPathComponent("\(shot.name).png"))
                    print("wrote \(shot.name).png")
                }
                continue
            }
            let model = AppModel(options: DemoOptions.parse(["--demo", shot.demo, "--route", shot.route]))
            model.searchQuery = shot.search
            if let theme = shot.theme {
                model.settings.update(.theme) { $0.theme = theme }
            }
            let view = RootView()
                .environment(model)
                .environment(\.snapshotMode, true)
                .environment(\.snapshotForceActions, shot.forceActions)
                .environment(\.snapshotVariant, shot.variant)
                .preferredColorScheme(.light)
            guard let image = render(view, size: shot.size) else { print("failed \(shot.name)"); continue }
            if let data = image.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent("\(shot.name).png"))
                print("wrote \(shot.name).png")
            }
        }
        return true
    }

    /// Renders through a real (offscreen) window so native controls, scroll views and
    /// layout preferences behave exactly as in the app. Output is at the display's scale.
    static func render<V: View>(_ view: V, size: CGSize) -> NSBitmapImageRep? {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.appearance = NSAppearance(named: .aqua)
        // On-screen (briefly) so AppKit-backed controls draw; borderless, so no chrome.
        window.setFrameOrigin(NSPoint(x: 0, y: 0))
        window.orderFrontRegardless()
        // Let SwiftUI settle layout, preferences and image decoding.
        for _ in 0..<3 {
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        }
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)
        return rep
    }
}

/// A slice of desktop around the notch, so the black island reads in a PNG.
struct IslandSnapshotStage: View {
    let scenario: IslandScenario
    let flat: Bool
    let size: CGSize

    var body: some View {
        let metrics = flat
            ? ScreenMetrics(frame: CGRect(origin: .zero, size: size),
                            visibleFrame: CGRect(x: 0, y: 0, width: size.width, height: size.height - 25),
                            safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0)
            : ScreenMetrics(frame: CGRect(origin: .zero, size: size),
                            visibleFrame: CGRect(x: 0, y: 0, width: size.width, height: size.height - 32),
                            safeAreaTop: 32, auxLeftWidth: (size.width - 200) / 2, auxRightWidth: (size.width - 200) / 2)
        let services = AppServices(options: DemoOptions.parse(["--demo", "no-flaky,ephemeral"]))
        let model = services.makeIslandModel(metrics: metrics, services: .simulated(timing: .instant))
        let _ = model.jump(to: scenario)
        ZStack(alignment: .top) {
            Color(hex: 0x5B6472)
            // Menu bar band; on a notched Mac it is black around the notch.
            Rectangle().fill(Color.black.opacity(flat ? 0.18 : 1)).frame(height: metrics.hasNotch ? 32 : 25)
            if scenario == .qaDetached || scenario == .qaDockReady {
                // Docking: the card sits just under the opened receiver.
                DetachedQuickAnswerView(model: model)
                    .padding(.top, scenario == .qaDockReady ? 124 : 70)
            }
            IslandRootView(model: model)
        }
        .frame(width: size.width, height: size.height)
    }
}
