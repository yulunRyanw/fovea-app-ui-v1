import SwiftUI
import FoveaCore

/// Direction 1, Paper: time-ordered and type-only. A Now group first, dates in the gutter like
/// a printed ledger, no marks, no thumbnails, no hairlines. A row opens in place.
struct PaperView: View {
    @Environment(LabState.self) private var state

    private let gutter: CGFloat = 96
    private let gap: CGFloat = 24
    private let column: CGFloat = 740

    var body: some View {
        let searching = !state.searchQuery.isEmpty
        let now = searching ? [] : state.now
        let liveIds = Set(now.map(\.capture.id))
        let rest = state.filteredCaptures.filter { !liveIds.contains($0.id) }
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                if state.searchVisible {
                    LabSearchField(width: column)
                        .padding(.leading, gutter + gap)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
                if !now.isEmpty {
                    PaperGroup(label: "Now", sublabel: nil) {
                        ForEach(now, id: \.capture.id) { item in
                            PaperRow(capture: item.capture, task: item.task, column: column)
                        }
                    }
                }
                ForEach(DateGrouping.groups(rest)) { group in
                    PaperGroup(label: group.title, sublabel: group.subtitle) {
                        ForEach(group.captures) { capture in
                            PaperRow(capture: capture, task: state.task(for: capture), column: column)
                        }
                    }
                }
                if rest.isEmpty && now.isEmpty {
                    Text(searching ? "No captures match “\(state.searchQuery)”" : "No captures yet")
                        .font(Tokens.Type_.section)
                        .foregroundStyle(Tokens.Colors.textPrimary)
                        .padding(.leading, gutter + gap)
                }
            }
            .frame(width: gutter + gap + column, alignment: .leading)
            .padding(.top, 92)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity)
        }
        .animation(Tokens.Motion.animation(.popover, reduceMotion: state.reduceMotion, fadeOnly: true), value: state.searchVisible)
    }
}

private struct PaperGroup<Content: View>: View {
    let label: String
    let sublabel: String?
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(sublabel ?? " ")
                    .foregroundStyle(Tokens.Colors.textTertiary.opacity(0.7))
            }
            .font(Tokens.Type_.caption)
            .foregroundStyle(Tokens.Colors.textTertiary)
            .frame(width: 96, alignment: .leading)
            .padding(.top, 14)
            VStack(alignment: .leading, spacing: 0) { content }
        }
    }
}

/// Intent at 15 pt, one quiet line of meta, the status word on the first line. Nothing else
/// until it opens.
struct PaperRow: View {
    @Environment(LabState.self) private var state
    @Environment(\.snapshotMode) private var snapshotMode
    let capture: Capture
    let task: AgentTask?
    let column: CGFloat
    @FocusState private var focused: Bool

    private var open: Bool { state.openId == capture.id }
    private var recent: Bool { state.recentCaptureId == capture.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(capture.labTitle)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(open ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                status
            }
            Text(meta)
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Colors.textSecondary)
                .lineLimit(1)
            if open {
                CaptureExpansion(capture: capture)
                    .transition(.labContent)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(width: column + 24, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Ledger.rowRadius)
                .fill(recent ? Tokens.Colors.selection : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused && !snapshotMode, radius: Tokens.Ledger.rowRadius)
        .onKeyPress(.return) { toggle(); return .handled }
        .animation(Tokens.Motion.animation(.accordion, reduceMotion: state.reduceMotion, fadeOnly: true), value: open)
        .foveaAnimation(.highlightFade, value: recent, fadeOnly: true)
        .padding(.horizontal, -12)
    }

    private func toggle() { state.openId = open ? nil : capture.id }

    @ViewBuilder private var status: some View {
        if capture.deliveryStatus == .failed {
            LabRetryChip()
        } else if let task {
            LabStatusWord(state: task.state, font: .system(size: 12, weight: .medium))
        }
    }

    private var meta: String {
        var parts = [capture.labDestinationName]
        if let chat = capture.chatName { parts.append(chat) }
        if let task, task.state != .complete, !task.activity.isEmpty { parts.append(task.activity) }
        else { parts.append(DateGrouping.timeLabel(capture.createdAt)) }
        if let n = capture.labReferentCount { parts.append(n) }
        return parts.joined(separator: " · ")
    }
}
