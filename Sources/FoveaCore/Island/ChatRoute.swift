import Foundation

// Chat routing: which conversation inside a destination receives the payload. Fovea
// predicts it; the user may change it, but never has to.

public enum ChatRouteKind: String, Codable, Hashable, Sendable {
    case recommended, original, recent, new
}

/// A folder a new Chat starts in (its working context).
public struct ContextFolder: Hashable, Codable, Sendable {
    public let name: String
    /// Display path, home-relative ("~/Documents/fovea").
    public let path: String
    public init(name: String, path: String) { self.name = name; self.path = path }
}

/// A destination the user can start a new Chat in.
public struct DestinationChoice: Hashable, Codable, Sendable {
    public let app: AppRef
    public let isRecommended: Bool
    public init(app: AppRef, isRecommended: Bool = false) { self.app = app; self.isRecommended = isRecommended }
}

public struct ChatRoute: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let kind: ChatRouteKind
    public let destination: AppRef
    public let chatName: String
    /// When the Chat was last active; nil for a Chat that does not exist yet.
    public let lastActiveAt: Date?
    /// The folder the Chat works in, when known.
    public let context: ContextFolder?

    public init(id: String, kind: ChatRouteKind, destination: AppRef, chatName: String,
                lastActiveAt: Date? = nil, context: ContextFolder? = nil) {
        self.id = id; self.kind = kind; self.destination = destination; self.chatName = chatName
        self.lastActiveAt = lastActiveAt; self.context = context
    }

    public static func newChat(in destination: AppRef, context: ContextFolder? = nil) -> ChatRoute {
        ChatRoute(id: "new-\(destination.id)-\(context?.name ?? "none")", kind: .new,
                  destination: destination, chatName: "New Chat", context: context)
    }

    /// What the selector pill shows: the Chat, or "New Chat · folder" for one to be created.
    public var pillTitle: String {
        guard kind == .new else { return chatName }
        if let context { return "New Chat · \(context.name)" }
        return chatName
    }
}

/// What the selector offers: the prediction, recent Chats (any destination, last day),
/// the destinations a new Chat can start in.
public struct ChatRouteMenu: Hashable, Codable, Sendable {
    /// Recent Chats are those active within this window…
    public static let recentWindow: TimeInterval = 24 * 3600
    /// …and at most this many of them.
    public static let maxRecent = 10

    public let recommended: ChatRoute
    public let original: ChatRoute?
    public let recent: [ChatRoute]
    public let new: ChatRoute
    public let destinations: [DestinationChoice]

    public init(recommended: ChatRoute, original: ChatRoute? = nil, recent: [ChatRoute] = [],
                new: ChatRoute, destinations: [DestinationChoice] = []) {
        self.recommended = recommended; self.original = original
        self.recent = Array(recent.prefix(Self.maxRecent)); self.new = new
        self.destinations = destinations
    }

    /// Rows of the recent panel: the original Chat first when there is one.
    public var recentRows: [ChatRoute] {
        var out: [ChatRoute] = []
        if let original { out.append(original) }
        out.append(contentsOf: recent.filter { $0.id != original?.id })
        return out
    }
}

public enum RouteResolution: Hashable, Sendable {
    case resolving
    case resolved(ChatRouteMenu)
    case failed

    public var menu: ChatRouteMenu? {
        if case .resolved(let m) = self { return m }
        return nil
    }
    public var isResolving: Bool { self == .resolving }
}
