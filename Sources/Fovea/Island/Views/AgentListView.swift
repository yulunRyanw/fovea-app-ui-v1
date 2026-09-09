import SwiftUI
import FoveaCore

/// Hover list of current Agent tasks. Two-line rows: the Chat and what the Agent is doing,
/// with the destination icon on the left and the state on the right. Five rows, then it
/// scrolls. Never shown when empty.
struct AgentListView: View {
    let model: IslandModel

    var body: some View {
        let tasks = model.state.visibleTasks
        let rows = VStack(spacing: 1) {
            ForEach(tasks) { task in
                AgentTaskRow(task: task, highlighted: task.id == model.state.recentlySentTaskId) {
                    model.send(.takeMeThere(task.id))
                }
                .id(task.id)
            }
        }
        .padding(Tokens.Island.Layout.listPadding)

        Group {
            if tasks.count > Tokens.Island.Layout.listRowsVisible {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) { rows }
                        .frame(height: CGFloat(Tokens.Island.Layout.listRowsVisible) * (Tokens.Island.Layout.listRowHeight + 1)
                               + Tokens.Island.Layout.listPadding * 2)
                        .scrollIndicators(.automatic)
                        .onAppear {
                            if let id = model.state.recentlySentTaskId { proxy.scrollTo(id, anchor: .top) }
                        }
                }
            } else {
                rows
            }
        }
        .frame(width: Tokens.Island.Layout.listWidth - Tokens.Island.Radius.expandedTop * 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Agent tasks")
    }
}

struct AgentTaskRow: View {
    let task: AgentTask
    var highlighted = false
    let open: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: open) {
            HStack(spacing: Tokens.Space.m) {
                DestinationIcon(app: task.destination, size: Tokens.Island.Layout.listIconSize)
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.chatName)
                        .font(Tokens.Island.Type_.body)
                        .foregroundStyle(Tokens.Island.Colors.textPrimary)
                        .lineLimit(1)
                    Text(task.activity)
                        .font(Tokens.Island.Type_.secondary)
                        .foregroundStyle(Tokens.Island.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s)
                HStack(spacing: 5) {
                    if task.state == .working {
                        Circle().fill(Tokens.Island.Colors.progressFill)
                            .frame(width: Tokens.Island.Layout.listStatusDot, height: Tokens.Island.Layout.listStatusDot)
                    }
                    Text(task.state.label)
                        .font(Tokens.Island.Type_.status)
                        .foregroundStyle(stateColor)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, Tokens.Space.m)
            .frame(height: Tokens.Island.Layout.listRowHeight)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Island.Radius.row)
                    .fill(highlighted ? Tokens.Island.Colors.recentHighlight : (hovering ? Tokens.Island.Colors.hover : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Island.Radius.row)
                    .strokeBorder(Tokens.Island.Colors.focus, lineWidth: 1.5)
                    .opacity(focused ? 1 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
        .help(task.title)
        .accessibilityLabel("\(task.chatName), \(task.activity), \(task.state.label), \(task.destination.name)")
        .accessibilityHint(task.state == .working ? "" : "Opens the Chat in \(task.destination.name)")
    }

    private var stateColor: Color {
        switch task.state {
        case .needsYou: return Tokens.Island.Colors.needsYou
        case .failed: return Tokens.Island.Colors.failed
        case .complete: return Tokens.Island.Colors.textPrimary.opacity(0.85)
        case .working: return Tokens.Island.Colors.textSecondary
        }
    }
}
