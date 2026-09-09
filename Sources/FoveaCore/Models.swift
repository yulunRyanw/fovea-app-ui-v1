import Foundation
import CoreGraphics

// Vocabulary follows AGENTS.md: Capture, Referent, Intent, Destination, Payload.
// A referent is one circled or attached region; the intent is the transcript.

// MARK: - Captures

public enum CaptureIntent: String, Codable, Hashable, Sendable {
    case voiceOnly = "voice_only"
    case voiceWithAttachment = "voice_with_attachment"
    case quickAnswer = "quick_answer"
}

public enum ReferentKind: String, Codable, Hashable, Sendable {
    case image, screenshot, document, file, code, terminal, chart, equation

    /// SF Symbol standing in for a referent without a rendered preview.
    public var symbol: String {
        switch self {
        case .image, .screenshot: return "photo"
        case .document: return "doc.text"
        case .file: return "doc"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .terminal: return "terminal"
        case .chart: return "chart.xyaxis.line"
        case .equation: return "function"
        }
    }
}

public struct ChartPoint: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct Referent: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let kind: ReferentKind
    /// width / height of the rendered preview.
    public let aspect: CGFloat
    /// Path under `Resources/` for bundled media (image, screenshot).
    public let resource: String?
    /// Display filename for documents/files, or the media filename.
    public let filename: String?
    /// Text contents for code, terminal, equation and document previews.
    public let text: String?
    /// Chart or document title.
    public let title: String?
    public let chartPoints: [ChartPoint]?
    public let sourceApp: String?
    public let sourceWindowTitle: String?

    public init(id: String, kind: ReferentKind, aspect: CGFloat, resource: String? = nil,
                filename: String? = nil, text: String? = nil, title: String? = nil,
                chartPoints: [ChartPoint]? = nil, sourceApp: String? = nil,
                sourceWindowTitle: String? = nil) {
        self.id = id; self.kind = kind; self.aspect = aspect; self.resource = resource
        self.filename = filename; self.text = text; self.title = title
        self.chartPoints = chartPoints; self.sourceApp = sourceApp
        self.sourceWindowTitle = sourceWindowTitle
    }
}

public enum DeliveryStatus: String, Codable, Hashable, Sendable {
    case pending, sent, delivered, failed

    public var label: String {
        switch self {
        case .pending: return "Pending"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .failed: return "Failed"
        }
    }
}

public struct AppRef: Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    /// SF Symbol used for the app glyph in the prototype.
    public let symbol: String
    public init(id: String, name: String, symbol: String) {
        self.id = id; self.name = name; self.symbol = symbol
    }
}

public struct Capture: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let intent: CaptureIntent
    public let createdAt: Date
    /// The full transcript (Intent, in AGENTS.md vocabulary).
    public let transcript: String?
    public let semanticAnchors: [String]
    public var referents: [Referent]
    public let sourceApp: AppRef?
    public let destinationApp: AppRef?
    public var deliveryStatus: DeliveryStatus
    public let question: String?
    public let answer: String?
    /// Short labels shown in the detail card's metadata bar.
    public var tags: [String]
    /// The Chat inside the destination that received the payload.
    public var chatName: String?

    public init(id: String, intent: CaptureIntent, createdAt: Date, transcript: String? = nil,
                semanticAnchors: [String] = [], referents: [Referent] = [],
                sourceApp: AppRef? = nil, destinationApp: AppRef? = nil,
                deliveryStatus: DeliveryStatus = .delivered,
                question: String? = nil, answer: String? = nil,
                tags: [String] = [], chatName: String? = nil) {
        self.id = id; self.intent = intent; self.createdAt = createdAt
        self.transcript = transcript; self.semanticAnchors = semanticAnchors
        self.referents = referents; self.sourceApp = sourceApp
        self.destinationApp = destinationApp; self.deliveryStatus = deliveryStatus
        self.question = question; self.answer = answer
        self.tags = tags; self.chatName = chatName
    }

    // Older blobs have no tags / chatName; decode them as empty.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        intent = try c.decode(CaptureIntent.self, forKey: .intent)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        transcript = try c.decodeIfPresent(String.self, forKey: .transcript)
        semanticAnchors = try c.decodeIfPresent([String].self, forKey: .semanticAnchors) ?? []
        referents = try c.decodeIfPresent([Referent].self, forKey: .referents) ?? []
        sourceApp = try c.decodeIfPresent(AppRef.self, forKey: .sourceApp)
        destinationApp = try c.decodeIfPresent(AppRef.self, forKey: .destinationApp)
        deliveryStatus = try c.decodeIfPresent(DeliveryStatus.self, forKey: .deliveryStatus) ?? .delivered
        question = try c.decodeIfPresent(String.self, forKey: .question)
        answer = try c.decodeIfPresent(String.self, forKey: .answer)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        chatName = try c.decodeIfPresent(String.self, forKey: .chatName)
    }

    /// The feed shows media when there is any; otherwise the semantic fingerprint.
    public var heroReferent: Referent? { referents.first }
    public var isVisual: Bool { heroReferent != nil }

    /// What `Copy` puts on the pasteboard.
    public var payloadText: String {
        var lines: [String] = []
        if let transcript { lines.append(transcript) }
        if let question { lines.append("Q: \(question)") }
        if let answer { lines.append("A: \(answer)") }
        for r in referents {
            if let filename = r.filename { lines.append("[\(r.kind.rawValue)] \(filename)") }
            else if let text = r.text { lines.append(text) }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Settings

/// A feed palette: four colors used on the highlighted words and nowhere else.
/// `paper` is the neutral default; the other six are Color Hunt palettes, used at
/// their published values (see `Tokens.Colors.theme`).
public enum ThemeName: String, Codable, CaseIterable, Hashable, Sendable {
    case paper, citrus, orchard, dusk, canyon, blush, roast

    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

public enum VoiceProcessing: String, Codable, CaseIterable, Hashable, Sendable {
    case faithful, polished
    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

public struct UserSettings: Codable, Hashable, Sendable {
    public var displayName: String
    public var email: String
    public var theme: ThemeName
    /// Which faces the feed may set anchor words in. Empty = all of them.
    public var feedFonts: [FeedFont]
    public var interfaceLanguage: String
    public var launchAtLogin: Bool
    public var showInDock: Bool
    public var automaticUpdates: Bool
    /// nil = keep forever.
    public var screenshotRetentionDays: Int?
    public var microphoneId: String?
    public var interactionSounds: Bool
    public var voiceProcessing: VoiceProcessing
    public var eyeTrackingEnabled: Bool

    public init(displayName: String = "Yulun Wu",
                email: String = "wuyulun10@gmail.com",
                theme: ThemeName = .paper,
                feedFonts: [FeedFont] = FeedFont.defaultEnabled,
                interfaceLanguage: String = "en",
                launchAtLogin: Bool = true,
                showInDock: Bool = false,
                automaticUpdates: Bool = true,
                screenshotRetentionDays: Int? = 30,
                microphoneId: String? = nil,
                interactionSounds: Bool = true,
                voiceProcessing: VoiceProcessing = .faithful,
                eyeTrackingEnabled: Bool = true) {
        self.displayName = displayName; self.email = email; self.theme = theme
        self.feedFonts = feedFonts
        self.interfaceLanguage = interfaceLanguage; self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock; self.automaticUpdates = automaticUpdates
        self.screenshotRetentionDays = screenshotRetentionDays; self.microphoneId = microphoneId
        self.interactionSounds = interactionSounds; self.voiceProcessing = voiceProcessing
        self.eyeTrackingEnabled = eyeTrackingEnabled
    }

    public static let `default` = UserSettings()

    /// Row identity for optimistic save state.
    public enum Key: String, Codable, Hashable, CaseIterable, Sendable {
        case displayName, email, theme, feedFonts, interfaceLanguage, launchAtLogin, showInDock,
             automaticUpdates, screenshotRetentionDays, microphoneId, interactionSounds,
             voiceProcessing, eyeTrackingEnabled
    }

    // `theme` replaced the old `accentColor` key. Blobs written before the palette
    // change carry `accentColor` with a now-unknown value ("cobalt", "plum", …);
    // the key is simply absent here, so those settings fall back to `.paper`.
    enum CodingKeys: String, CodingKey {
        case displayName, email, theme, feedFonts, interfaceLanguage, launchAtLogin, showInDock,
             automaticUpdates, screenshotRetentionDays, microphoneId, interactionSounds,
             voiceProcessing, eyeTrackingEnabled
    }

    // Decode with defaults so older blobs never fail to load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserSettings.default
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? d.displayName
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? d.email
        // `try?` and not `try`: an unrecognized theme name falls back instead of
        // failing the whole settings decode.
        theme = ((try? c.decodeIfPresent(ThemeName.self, forKey: .theme)) ?? nil) ?? d.theme
        // An unknown font id (a face dropped from the app) is skipped, not fatal.
        feedFonts = ((try? c.decodeIfPresent([FeedFont].self, forKey: .feedFonts)) ?? nil) ?? d.feedFonts
        interfaceLanguage = try c.decodeIfPresent(String.self, forKey: .interfaceLanguage) ?? d.interfaceLanguage
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        showInDock = try c.decodeIfPresent(Bool.self, forKey: .showInDock) ?? d.showInDock
        automaticUpdates = try c.decodeIfPresent(Bool.self, forKey: .automaticUpdates) ?? d.automaticUpdates
        screenshotRetentionDays = c.contains(.screenshotRetentionDays)
            ? try c.decode(Int?.self, forKey: .screenshotRetentionDays) : d.screenshotRetentionDays
        microphoneId = c.contains(.microphoneId)
            ? try c.decode(String?.self, forKey: .microphoneId) : d.microphoneId
        interactionSounds = try c.decodeIfPresent(Bool.self, forKey: .interactionSounds) ?? d.interactionSounds
        voiceProcessing = try c.decodeIfPresent(VoiceProcessing.self, forKey: .voiceProcessing) ?? d.voiceProcessing
        eyeTrackingEnabled = try c.decodeIfPresent(Bool.self, forKey: .eyeTrackingEnabled) ?? d.eyeTrackingEnabled
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(email, forKey: .email)
        try c.encode(theme, forKey: .theme)
        try c.encode(feedFonts, forKey: .feedFonts)
        try c.encode(interfaceLanguage, forKey: .interfaceLanguage)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(showInDock, forKey: .showInDock)
        try c.encode(automaticUpdates, forKey: .automaticUpdates)
        try c.encode(screenshotRetentionDays, forKey: .screenshotRetentionDays)   // writes null
        try c.encode(microphoneId, forKey: .microphoneId)
        try c.encode(interactionSounds, forKey: .interactionSounds)
        try c.encode(voiceProcessing, forKey: .voiceProcessing)
        try c.encode(eyeTrackingEnabled, forKey: .eyeTrackingEnabled)
    }
}

public struct InterfaceLanguage: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public static let all: [InterfaceLanguage] = [
        .init(id: "en", name: "English"),
        .init(id: "zh-Hans", name: "简体中文"),
        .init(id: "ja", name: "日本語"),
        .init(id: "de", name: "Deutsch"),
        .init(id: "fr", name: "Français"),
    ]
}

public struct RetentionOption: Hashable, Sendable, Identifiable {
    public let id: String
    public let days: Int?
    public let name: String
    public static let all: [RetentionOption] = [
        .init(id: "7", days: 7, name: "7 days"),
        .init(id: "30", days: 30, name: "30 days"),
        .init(id: "90", days: 90, name: "90 days"),
        .init(id: "forever", days: nil, name: "Keep forever"),
    ]
}

public struct AudioInput: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let isSystemDefault: Bool
    public init(id: String, name: String, isSystemDefault: Bool = false) {
        self.id = id; self.name = name; self.isSystemDefault = isSystemDefault
    }
}

// MARK: - Dictionary

public struct DictionaryTerm: Identifiable, Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable { case manual, correction, `import` }
    public let id: String
    public var preferredSpelling: String
    public var aliases: [String]
    public var source: Source
    public var createdAt: Date
    /// Higher = used more recently/often; drives the compact "Recent" list.
    public var useCount: Int

    public init(id: String, preferredSpelling: String, aliases: [String] = [],
                source: Source = .manual, createdAt: Date, useCount: Int = 0) {
        self.id = id; self.preferredSpelling = preferredSpelling; self.aliases = aliases
        self.source = source; self.createdAt = createdAt; self.useCount = useCount
    }
}

// MARK: - Shortcuts

public enum ShortcutAction: String, Codable, CaseIterable, Hashable, Sendable {
    case voiceFlow, quickAnswer

    public var displayName: String {
        switch self {
        case .voiceFlow: return "VoiceFlow"
        case .quickAnswer: return "Quick Answer"
        }
    }
}

public struct KeyBinding: Codable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var modifiers: Modifiers
    public var keyCode: UInt16
    /// Human label for the key itself: "Space", "A", "↩", "fn".
    public var keyLabel: String

    public init(modifiers: Modifiers, keyCode: UInt16, keyLabel: String) {
        self.modifiers = modifiers; self.keyCode = keyCode; self.keyLabel = keyLabel
    }

    /// The fn (Globe) key, `kVK_Function`. It is the key of a binding, never a modifier:
    /// pressing it on its own or together with ⌃ ⌥ ⇧ ⌘ fires the shortcut.
    public static let functionKeyCode: UInt16 = 0x3F
    public static let functionKeyLabel = "fn"

    /// The fn key alone, optionally with modifiers held.
    public static func functionKey(_ modifiers: Modifiers = []) -> KeyBinding {
        KeyBinding(modifiers: modifiers, keyCode: functionKeyCode, keyLabel: functionKeyLabel)
    }

    /// Bindings on the fn key cannot go through Carbon and are watched as modifier changes.
    public var isFunctionKey: Bool { keyCode == Self.functionKeyCode }

    /// Glyphs in HIG order: fn first, then ⌃ ⌥ ⇧ ⌘, then the key.
    public var displayGlyphs: [String] {
        var out: [String] = []
        if isFunctionKey { out.append(keyLabel) }
        if modifiers.contains(.control) { out.append("⌃") }
        if modifiers.contains(.option) { out.append("⌥") }
        if modifiers.contains(.shift) { out.append("⇧") }
        if modifiers.contains(.command) { out.append("⌘") }
        if !isFunctionKey { out.append(keyLabel) }
        return out
    }

    public var displayString: String { displayGlyphs.joined(separator: " ") }

    /// Same physical chord, regardless of label.
    public func conflicts(with other: KeyBinding) -> Bool {
        modifiers == other.modifiers && keyCode == other.keyCode
    }
}

public struct ShortcutBindings: Codable, Hashable, Sendable {
    public var bindings: [ShortcutAction: KeyBinding]
    public init(bindings: [ShortcutAction: KeyBinding]) { self.bindings = bindings }

    /// Press once to start, press again to stop: fn for VoiceFlow, fn ⌃ for Quick Answer.
    public static let defaults = ShortcutBindings(bindings: [
        .voiceFlow: .functionKey(),
        .quickAnswer: .functionKey([.control]),
    ])
}

// MARK: - Connectors

public enum ConnectorStatus: String, Codable, Hashable, Sendable {
    case connected, available, error
}

public struct Connector: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    /// SF Symbol standing in for the connector icon in the prototype.
    public let symbol: String
    public var status: ConnectorStatus
    /// Permissions this connector supports; `granted` are the ones currently on.
    public let permissions: [String]
    public var granted: Set<String>
    /// One-line status detail, e.g. the session it is bound to.
    public var detail: String?

    public init(id: String, name: String, symbol: String, status: ConnectorStatus,
                permissions: [String], granted: Set<String>? = nil, detail: String? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.status = status
        self.permissions = permissions; self.granted = granted ?? Set(permissions)
        self.detail = detail
    }
}

// MARK: - Usage & Plan

public struct UsageSummary: Hashable, Codable, Sendable {
    public let used: Int
    public let limit: Int
    public let unitLabel: String
    public let resetsAt: Date

    public init(used: Int, limit: Int, unitLabel: String, resetsAt: Date) {
        self.used = used; self.limit = limit; self.unitLabel = unitLabel; self.resetsAt = resetsAt
    }

    public var fraction: Double { limit > 0 ? min(1, Double(used) / Double(limit)) : 0 }
    public var percent: Int { Int((fraction * 100).rounded()) }
}

public struct PlanInfo: Hashable, Codable, Sendable {
    public let name: String
    public let price: String?
    public let cadence: String?
    public init(name: String, price: String?, cadence: String?) {
        self.name = name; self.price = price; self.cadence = cadence
    }
}

public struct BillingEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let date: Date
    public let amount: String
    public let description: String
    public init(id: String, date: Date, amount: String, description: String) {
        self.id = id; self.date = date; self.amount = amount; self.description = description
    }
}

// MARK: - Permissions (simulated in the prototype)

public enum SystemPermission: String, Codable, Hashable, CaseIterable, Sendable {
    case microphone, screenRecording, accessibility, eyeTracking, speechRecognition

    public var displayName: String {
        switch self {
        case .microphone: return "Microphone"
        case .screenRecording: return "Screen Recording"
        case .accessibility: return "Accessibility"
        case .eyeTracking: return "Eye Tracking"
        case .speechRecognition: return "Speech Recognition"
        }
    }

    /// Deep link into the matching Privacy & Security pane.
    public var systemSettingsURL: String {
        let pane: String
        switch self {
        case .microphone: pane = "Privacy_Microphone"
        case .screenRecording: pane = "Privacy_ScreenCapture"
        case .accessibility: pane = "Privacy_Accessibility"
        case .eyeTracking: pane = "Privacy_Camera"
        case .speechRecognition: pane = "Privacy_SpeechRecognition"
        }
        return "x-apple.systempreferences:com.apple.preference.security?\(pane)"
    }
}
