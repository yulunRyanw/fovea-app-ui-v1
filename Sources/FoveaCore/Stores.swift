import Foundation

public struct StoreError: Error, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

/// Typed persistence for one aggregate. The prototype uses UserDefaults; a real
/// service replaces the implementation without touching the UI.
public protocol PersistentStore<Value>: Sendable {
    associatedtype Value: Codable & Sendable
    func load() -> Value?
    func save(_ value: Value, changed key: String) async throws
}

public struct UserDefaultsStore<Value: Codable & Sendable>: PersistentStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults; self.key = key
    }

    public func load() -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    public func save(_ value: Value, changed key: String) async throws {
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: self.key)
    }
}

public final class InMemoryStore<Value: Codable & Sendable>: PersistentStore, @unchecked Sendable {
    private var value: Value?
    private let lock = NSLock()
    public private(set) var saveCount = 0

    public init(_ initial: Value? = nil) { value = initial }

    public func load() -> Value? { lock.withLock { value } }

    public func save(_ value: Value, changed key: String) async throws {
        lock.withLock { self.value = value; saveCount += 1 }
    }
}

/// Demo decorator: fails the first `failures` saves of `failingKey`, then succeeds.
/// Used to show the row-level Retry state without a backend.
public final class FlakyStore<Value: Codable & Sendable>: PersistentStore, @unchecked Sendable {
    private let wrapped: any PersistentStore<Value>
    private let failingKey: String
    private var remainingFailures: Int
    private let lock = NSLock()

    public init(wrapping: any PersistentStore<Value>, failingKey: String, failures: Int = 1) {
        self.wrapped = wrapping; self.failingKey = failingKey; self.remainingFailures = failures
    }

    public func load() -> Value? { wrapped.load() }

    public func save(_ value: Value, changed key: String) async throws {
        let shouldFail: Bool = lock.withLock {
            if key == failingKey, remainingFailures > 0 { remainingFailures -= 1; return true }
            return false
        }
        if shouldFail { throw StoreError("Couldn’t save \(key).") }
        try await wrapped.save(value, changed: key)
    }
}

public enum StoreKeys {
    public static let settings = "fovea.settings.v1"
    public static let dictionary = "fovea.dictionary.v1"
    /// v2: shortcuts became press-to-toggle on fn; v1 hold-to-talk chords are dropped.
    public static let shortcuts = "fovea.shortcuts.v2"
    public static let connectors = "fovea.connectors.v1"
    /// Island preferences: last detached Quick Answer frame.
    public static let islandPrefs = "fovea.island.v1"
}

/// What the Island remembers between sessions.
public struct IslandPrefs: Codable, Hashable, Sendable {
    /// Screen-coordinate frame of the detached Quick Answer panel, if it was ever moved.
    public var detachedFrame: CGRect?
    public init(detachedFrame: CGRect? = nil) { self.detachedFrame = detachedFrame }
}
