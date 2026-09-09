import SwiftUI
import FoveaCore

/// Direction 4, Threads: Messages, for agents. Chats as contacts on the left, ordered by what
/// needs you; on the right the thread of everything sent to one Chat, referents attached, the
/// agent's status as the receipt. The notch is the compose bar.
struct ThreadsView: View {
    @Environment(LabState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ChatList()
                .frame(width: 272)
            if let space = state.selectedSpace {
                Thread(space: space)
                    .id(space.id)
            }
        }
    }
}

private struct ChatList: View {
    @Environment(LabState.self) private var state

    var body: some View {
        let spaces = state.spaces
        let selected = state.selectedSpace?.id
        VStack(alignment: .leading, spacing: 0) {
            Text("Chats")
                .font(Tokens.Type_.caption)
                .foregroundStyle(Tokens.Colors.textTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 70)
                .padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(spaces) { space in
                        ChatRow(space: space, selected: space.id == selected)
                            .onTapGesture { state.selectedSpaceId = space.id; state.openId = nil }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.sidebar)
    }
}

private struct ChatRow: View {
    let space: LabSpace
    let selected: Bool

    private var needsYou: Bool { space.task?.state == .needsYou }
    private var lastLine: String {
        if let t = space.task, t.state != .complete, !t.activity.isEmpty { return t.activity }
        return space.newest.labTitle
    }

    var body: some View {
        HStack(spacing: 9) {
            DestinationMark(app: space.destination, size: 14, color: Tokens.Colors.ink.opacity(0.75))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(space.name)
                        .font(.system(size: 13, weight: needsYou ? .medium : .regular))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                    if let q = space.qualifier {
                        Text(q).font(.system(size: 11)).foregroundStyle(Tokens.Colors.textTertiary).lineLimit(1)
                    }
                }
                Text(lastLine)
                    .font(.system(size: 11))
                    .foregroundStyle(needsYou ? Tokens.Colors.needsYou : Tokens.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if needsYou {
                Circle().fill(Tokens.Colors.needsYou).frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: Tokens.Ledger.rowRadius).fill(selected ? Tokens.Colors.selection : .clear))
        .contentShape(Rectangle())
    }
}

/// One Chat's thread, oldest at the top, anchored to the newest.
private struct Thread: View {
    @Environment(LabState.self) private var state
    let space: LabSpace

    private var ordered: [Capture] { space.captures.reversed() }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                DestinationMark(app: space.destination, size: 15, color: Tokens.Colors.ink.opacity(0.8))
                Text(space.name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Tokens.Colors.ink)
                Text("in \(space.destination.name)").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
                Spacer()
                if let task = space.task, task.state != .complete {
                    Text(task.activity).font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textSecondary)
                    LabStatusWord(state: task.state, font: Tokens.Type_.captionMedium)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 70)
            .padding(.bottom, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, capture in
                            let previous = index > 0 ? ordered[index - 1] : nil
                            if let separator = separator(before: capture, previous: previous) {
                                Text(separator)
                                    .font(Tokens.Type_.caption)
                                    .foregroundStyle(Tokens.Colors.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, index == 0 ? 6 : 18)
                                    .padding(.bottom, 10)
                            }
                            Bubble(capture: capture, task: state.task(for: capture))
                                .id(capture.id)
                                .transition(state.recentCaptureId == capture.id ? .labArrival : .opacity)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: ordered.count) { _, _ in
                    if let last = ordered.last {
                        withAnimation(Tokens.Motion.spring(.open, reduceMotion: state.reduceMotion)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .foveaSpring(.open, value: ordered.count)

            HStack(spacing: 8) {
                KeyCap(labels: ["fn"])
                Text("Speak to reply to \(space.name)")
                    .font(Tokens.Type_.secondary)
                    .foregroundStyle(Tokens.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func separator(before capture: Capture, previous: Capture?) -> String? {
        let cal = Calendar.current
        let day = cal.startOfDay(for: capture.createdAt)
        if let previous {
            let sameDay = cal.startOfDay(for: previous.createdAt) == day
            if sameDay && capture.createdAt.timeIntervalSince(previous.createdAt) < 30 * 60 { return nil }
            if sameDay { return DateGrouping.timeLabel(capture.createdAt) }
        }
        let title = DateGrouping.groups([capture]).first?.title ?? ""
        return "\(title) · \(DateGrouping.timeLabel(capture.createdAt))"
    }
}

/// What you said, with what you pointed at inside it; the agent's state as the receipt.
private struct Bubble: View {
    @Environment(LabState.self) private var state
    let capture: Capture
    let task: AgentTask?
    @State private var receiptShown = false

    private var open: Bool { state.openId == capture.id }
    private var recent: Bool { state.recentCaptureId == capture.id }
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 4, topTrailingRadius: 14, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                if !capture.referents.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(capture.referents.prefix(open ? 8 : 4)) { r in
                            if open {
                                CapturePreview(referent: r, width: (150 * min(2, max(0.7, r.aspect))).rounded(), height: 150, detail: true)
                            } else {
                                PaperThumb(referent: r, size: CGSize(width: 60, height: 42))
                            }
                        }
                        if !open, capture.referents.count > 4 {
                            Text("+\(capture.referents.count - 4)").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
                        }
                    }
                }
                Text(capture.labTitle)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(Tokens.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(shape.fill(recent ? Tokens.Colors.selection : Tokens.Colors.field))
            .frame(maxWidth: open ? 720 : 400, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { state.openId = open ? nil : capture.id }
            .foveaAnimation(.highlightFade, value: recent, fadeOnly: true)

            if capture.intent == .quickAnswer, let answer = capture.answer {
                Text(answer)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Colors.elevated))
                    .frame(maxWidth: 400, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            receipt
                .padding(.trailing, 6)
                .opacity(receiptShown ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 5)
        .animation(Tokens.Motion.animation(.accordion, reduceMotion: state.reduceMotion, fadeOnly: true), value: open)
        .task {
            // Geometry first, the receipt 120 ms later, for the capture that just arrived.
            if recent { try? await Task.sleep(for: .milliseconds(Int(120 * LabMotion.scale))) }
            withAnimation(Tokens.Motion.animation(.hover, reduceMotion: state.reduceMotion, fadeOnly: true)) { receiptShown = true }
        }
    }

    @ViewBuilder private var receipt: some View {
        if capture.deliveryStatus == .failed {
            HStack(spacing: 6) { Text("Not delivered").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.failed); LabRetryChip() }
        } else if capture.deliveryStatus == .pending {
            Text("Sending…").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
        } else if let task {
            switch task.state {
            case .needsYou:
                Text("Needs you · \(task.activity)").font(Tokens.Type_.captionMedium).foregroundStyle(Tokens.Colors.needsYou)
            case .failed:
                Text("Failed · \(task.activity)").font(Tokens.Type_.captionMedium).foregroundStyle(Tokens.Colors.failed)
            case .working:
                Text("Delivered · Working").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
            case .complete:
                Text("Delivered · Complete").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
            }
        } else if capture.intent == .quickAnswer {
            Text("Answered").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
        } else {
            Text("Delivered").font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary)
        }
    }
}
