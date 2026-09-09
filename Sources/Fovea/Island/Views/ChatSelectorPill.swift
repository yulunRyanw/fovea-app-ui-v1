import SwiftUI
import FoveaCore

/// Compact pill: destination icon · Chat name · chevron. While routing resolves it keeps
/// its width and breathes, so nothing jumps when the answer arrives. Tapping it toggles
/// the recent-Chats panel under the review row.
struct ChatSelectorPill: View {
    let model: IslandModel
    @State private var hovering = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotMode) private var snapshotMode

    private var draft: ReviewDraft? { model.state.review }

    var body: some View {
        if let draft {
            Button { model.send(.toggleSelector) } label: {
                HStack(spacing: Tokens.Space.s) {
                    switch draft.routes {
                    case .resolving:
                        resolvingLabel
                    case .failed:
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Tokens.Island.Colors.textSecondary)
                        Text("Retry routing")
                            .font(Tokens.Island.Type_.pill)
                            .foregroundStyle(Tokens.Island.Colors.textPrimary)
                    case .resolved:
                        if let route = draft.selectedRoute {
                            DestinationIcon(app: route.destination, size: 14)
                            Text(route.pillTitle)
                                .font(Tokens.Island.Type_.pill)
                                .foregroundStyle(Tokens.Island.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Tokens.Island.Colors.textSecondary)
                            .rotationEffect(.degrees(draft.selector.isOpen ? 180 : 0))
                    }
                }
                .padding(.horizontal, Tokens.Space.m)
                .frame(height: Tokens.Island.Layout.pillHeight)
                .frame(minWidth: Tokens.Island.Layout.pillResolvingWidth)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill)
                        .fill(hovering || draft.selector.isOpen ? Tokens.Island.Colors.pressed : Tokens.Island.Colors.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill)
                        .strokeBorder(Tokens.Island.Colors.focus, lineWidth: 1.5)
                        .opacity(focused ? 1 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill))
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            .focused($focused)
            .onHover { hovering = $0 }
            .disabled(draft.routes.isResolving)
            .foveaAnimation(.hover, value: hovering)
            .foveaAnimation(.select, value: draft.routes)
            .help("Change the Chat this goes to")
            .accessibilityLabel(accessibilityText(draft))
            .accessibilityHint("Opens Chat choices")
            .accessibilityAddTraits(draft.selector.isOpen ? [.isSelected] : [])
        }
    }

    private var resolvingLabel: some View {
        HStack(spacing: Tokens.Space.s) {
            Circle().fill(Tokens.Island.Colors.textTertiary).frame(width: 14, height: 14)
            Text("Choosing Chat")
                .font(Tokens.Island.Type_.pill)
                .foregroundStyle(Tokens.Island.Colors.textSecondary)
        }
        .modifier(Breathing(active: !reduceMotion && !snapshotMode))
    }

    private func accessibilityText(_ draft: ReviewDraft) -> String {
        switch draft.routes {
        case .resolving: return "Choosing Chat"
        case .failed: return "Chat routing failed. Retry"
        case .resolved: return "Send to \(draft.selectedRoute?.pillTitle ?? "") in \(draft.selectedRoute?.destination.name ?? "")"
        }
    }
}

/// Opacity pulse used by placeholders. Static when motion is reduced.
struct Breathing: ViewModifier {
    let active: Bool
    @State private var dim = false
    func body(content: Content) -> some View {
        content
            .opacity(active ? (dim ? 0.45 : 1) : 0.7)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: Tokens.Motion.placeholderPulse).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}
