import Foundation

public enum SettingsCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case account, typography, eyeTracking = "eye-tracking", voiceCapture = "voice-capture",
         dictionary, shortcuts, connectors, plan

    public var title: String {
        switch self {
        case .account: return "Account"
        case .typography: return "Typography"
        case .eyeTracking: return "Eye Tracking"
        case .voiceCapture: return "Voice & Capture"
        case .dictionary: return "Dictionary"
        case .shortcuts: return "Shortcuts"
        case .connectors: return "Connectors"
        case .plan: return "Usage & Plan"
        }
    }

    /// SF Symbol for the category row.
    public var symbol: String {
        switch self {
        case .account: return "person"
        case .typography: return "textformat"
        case .eyeTracking: return "eye"
        case .voiceCapture: return "waveform"
        case .dictionary: return "character.book.closed"
        case .shortcuts: return "command"
        case .connectors: return "link"
        case .plan: return "chart.pie"
        }
    }

    public var children: [SettingsChild] {
        switch self {
        case .account: return [.profile, .appearance, .app, .data]
        case .typography: return [.displayFaces, .textFaces]
        case .eyeTracking: return [.tracking, .calibration]
        case .voiceCapture: return [.audio, .voiceProcessing]
        case .dictionary: return [.learnedWords]
        case .shortcuts: return [.voiceFlow, .quickAnswer]
        case .connectors: return [.connected, .available]
        case .plan: return [.usage, .planDetails, .billing]
        }
    }

    public var defaultRoute: SettingsRoute { SettingsRoute(category: self, child: children[0]) }
}

/// How the settings sidebar lists the categories: every category once, under these headers.
/// Presentation only; routes are still `SettingsCategory`.
public enum SettingsSidebarGroup: String, CaseIterable, Hashable, Sendable {
    case personal, capture, integrations

    public var title: String {
        switch self {
        case .personal: return "Personal"
        case .capture: return "Capture"
        case .integrations: return "Integrations"
        }
    }

    public var categories: [SettingsCategory] {
        switch self {
        case .personal: return [.account, .typography, .plan]
        case .capture: return [.eyeTracking, .voiceCapture, .dictionary, .shortcuts]
        case .integrations: return [.connectors]
        }
    }
}

public enum SettingsChild: String, CaseIterable, Codable, Hashable, Sendable {
    case profile, appearance, app, data
    case displayFaces = "display-faces", textFaces = "text-faces"
    case tracking, calibration
    case audio, voiceProcessing = "voice-processing"
    case learnedWords = "learned-words"
    case voiceFlow = "voiceflow", quickAnswer = "quick-answer"
    case connected, available
    case usage, planDetails = "plan", billing

    public var title: String {
        switch self {
        case .profile: return "Profile"
        case .displayFaces: return "Highlighted Words"
        case .textFaces: return "Everything Else"
        case .appearance: return "Appearance"
        case .app: return "App"
        case .data: return "Data"
        case .tracking: return "Tracking"
        case .calibration: return "Calibration"
        case .audio: return "Audio"
        case .voiceProcessing: return "Voice Processing"
        case .learnedWords: return "Learned Words"
        case .voiceFlow: return "VoiceFlow"
        case .quickAnswer: return "Quick Answer"
        case .connected: return "Connected"
        case .available: return "Available"
        case .usage: return "Usage"
        case .planDetails: return "Plan"
        case .billing: return "Billing"
        }
    }

    public var category: SettingsCategory {
        SettingsCategory.allCases.first { $0.children.contains(self) }!
    }
}

public struct SettingsRoute: Hashable, Codable, Sendable {
    public let category: SettingsCategory
    public let child: SettingsChild

    public init(category: SettingsCategory, child: SettingsChild) {
        self.category = category; self.child = child
    }

    public init(_ child: SettingsChild) {
        self.category = child.category; self.child = child
    }

    public static let `default` = SettingsCategory.account.defaultRoute

    /// `settings/account/appearance` → route. Category-only paths resolve to the first child.
    public static func parse(_ path: String) -> SettingsRoute? {
        var parts = path.split(separator: "/").map(String.init)
        if parts.first == "settings" { parts.removeFirst() }
        guard let first = parts.first, let category = SettingsCategory(rawValue: first) else { return nil }
        if parts.count > 1, let child = SettingsChild(rawValue: parts[1]), child.category == category {
            return SettingsRoute(category: category, child: child)
        }
        return category.defaultRoute
    }

    public var path: String { "settings/\(category.rawValue)/\(child.rawValue)" }
}

public enum AppRoute: Hashable, Sendable {
    case home
    case captureDetail(String)
    case settings(SettingsRoute)
    case connectorDetail(String)

    /// Parses `--route` arguments: `home`, `captures/<id>`, `settings/<category>[/<child>]`,
    /// `settings/connectors/<id>` for a connector detail.
    public static func parse(_ path: String) -> AppRoute? {
        let parts = path.split(separator: "/").map(String.init)
        guard let head = parts.first else { return nil }
        switch head {
        case "", "home": return .home
        case "captures":
            guard parts.count > 1 else { return nil }
            return .captureDetail(parts[1])
        case "settings":
            if parts.count == 3, parts[1] == "connectors", SettingsChild(rawValue: parts[2]) == nil {
                return .connectorDetail(parts[2])
            }
            guard let route = SettingsRoute.parse(path) else { return nil }
            return .settings(route)
        default: return nil
        }
    }

    public var isSettings: Bool {
        switch self {
        case .settings, .connectorDetail: return true
        case .home, .captureDetail: return false
        }
    }
}
