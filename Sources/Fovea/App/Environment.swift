import SwiftUI
import FoveaCore

private struct SnapshotModeKey: EnvironmentKey { static let defaultValue = false }
private struct SnapshotForceActionsKey: EnvironmentKey { static let defaultValue: String? = nil }

extension EnvironmentValues {
    /// ImageRenderer can't render ScrollView, hover, sheets or popovers; views adapt.
    var snapshotMode: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
    /// Capture id whose hover actions should render in a snapshot.
    var snapshotForceActions: String? {
        get { self[SnapshotForceActionsKey.self] }
        set { self[SnapshotForceActionsKey.self] = newValue }
    }
}

extension View {
    /// Applies a named motion, honoring Reduce Motion.
    func foveaAnimation<V: Equatable>(_ kind: Tokens.Motion.Kind, value: V, fadeOnly: Bool = false) -> some View {
        modifier(FoveaAnimation(kind: kind, value: value, fadeOnly: fadeOnly))
    }

    /// Applies an Island spring, honoring Reduce Motion (which turns it into a crossfade).
    func foveaSpring<V: Equatable>(_ spring: Tokens.Motion.Spring, value: V) -> some View {
        modifier(FoveaSpring(spring: spring, value: value))
    }
}

private struct FoveaSpring<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spring: Tokens.Motion.Spring
    let value: V
    func body(content: Content) -> some View {
        content.animation(Tokens.Motion.spring(spring, reduceMotion: reduceMotion), value: value)
    }
}

private struct FoveaAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: Tokens.Motion.Kind
    let value: V
    let fadeOnly: Bool
    func body(content: Content) -> some View {
        content.animation(Tokens.Motion.animation(kind, reduceMotion: reduceMotion, fadeOnly: fadeOnly), value: value)
    }
}
