import Foundation

public enum ShortcutConflicts {
    /// For each action whose binding collides with another action's, the action it collides with.
    public static func detect(_ bindings: [ShortcutAction: KeyBinding]) -> [ShortcutAction: ShortcutAction] {
        var out: [ShortcutAction: ShortcutAction] = [:]
        let entries = bindings.sorted { $0.key.rawValue < $1.key.rawValue }
        for (action, binding) in entries {
            for (other, otherBinding) in entries where other != action {
                if binding.conflicts(with: otherBinding) { out[action] = other; break }
            }
        }
        return out
    }

    /// Would assigning `candidate` to `action` collide with some other action?
    public static func conflict(for action: ShortcutAction, candidate: KeyBinding,
                                in bindings: [ShortcutAction: KeyBinding]) -> ShortcutAction? {
        bindings.first { $0.key != action && $0.value.conflicts(with: candidate) }?.key
    }
}
