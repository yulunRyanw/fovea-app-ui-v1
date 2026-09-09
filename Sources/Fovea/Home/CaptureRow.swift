import SwiftUI
import FoveaCore

/// One capture in the Home ledger: the Island's Agent list row (`AgentTaskRow`), on paper.
/// Left to right: what you saw (the referent stack, or the app you were in), what you said
/// over where it went and when, and at the right the same status word the Island shows
/// for the task this capture became.
struct CaptureRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotForceActions) private var forceActions
    let capture: Capture
    /// The row Home just received from the Island; fades back like the Island's own list.
    var highlighted = false

    @State private var hovering = false
    @State private var frame: CGRect = .zero
    @FocusState private var focused: Bool

    private var showActions: Bool { hovering || focused || forceActions == capture.id }
    private var hot: Bool { hovering || forceActions == capture.id }
    /// The Agent task this capture became, when the Island created one.
    private var task: AgentTask? { model.services.ledger.tasks.first { $0.captureId == capture.id } }
    private var title: String { capture.transcript ?? capture.question ?? "" }

    var body: some View {
        HStack(spacing: Tokens.Ledger.iconGap) {
            SeenColumn(capture: capture)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Tokens.Ledger.intent)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                subtitle
            }
            Spacer(minLength: Tokens.Space.s)
            // The one action on the row. Present in layout always, visible on hover or
            // focus, so the status never shifts. No animation: rows are hovered constantly.
            GlyphButton(symbol: "doc.on.doc", label: "Copy", size: 11, hitSize: 24) { model.copy(capture) }
                .opacity(showActions ? 1 : 0)
                .allowsHitTesting(showActions)
            status
        }
        .padding(.horizontal, Tokens.Ledger.rowPaddingH)
        .frame(height: Tokens.Ledger.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Ledger.rowRadius)
                .fill(highlighted ? Tokens.Colors.selection : (hot ? Tokens.Colors.hover : .clear))
        )
        .contentShape(Rectangle())
        // The whole row opens its detail; the Copy glyph and Retry sit above and win.
        .onTapGesture { model.openDetail(capture, from: frame) }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused, radius: Tokens.Ledger.rowRadius)
        .onHover { hovering = $0 }
        .foveaAnimation(.highlightFade, value: highlighted, fadeOnly: true)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(RootView.coordinateSpace)) } action: { frame = $0 }
        .onKeyPress(.return) { model.openDetail(capture, from: frame); return .handled }
        .onKeyPress("c") { model.copy(capture); return .handled }
        .help(title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: "Details") { model.openDetail(capture, from: frame) }
        .accessibilityAction(named: "Copy") { model.copy(capture) }
    }

    /// Where it went and when: destination mark and Chat, or "Quick Answer", then the time.
    private var subtitle: some View {
        HStack(spacing: Tokens.Space.xs + 1) {
            if let destination = capture.destinationApp {
                DestinationMark(app: destination)
                Text(capture.chatName ?? destination.name)
            } else {
                Text("Quick Answer")
            }
            Text("·")
            Text(DateGrouping.timeLabel(capture.createdAt))
        }
        .font(Tokens.Ledger.meta)
        .foregroundStyle(Tokens.Colors.textSecondary)
        .lineLimit(1)
    }

    /// Delivery first (a capture that never arrived stays actionable), then the task's word.
    @ViewBuilder private var status: some View {
        if capture.deliveryStatus == .failed {
            DeliveryFailedBadge(capture: capture)
        } else if capture.deliveryStatus == .pending {
            HStack(spacing: Tokens.Space.xs) {
                ProgressView().controlSize(.mini)
                Text("Sending…")
                    .font(Tokens.Ledger.status)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
            .fixedSize()
        } else if let task {
            TaskStatusWord(state: task.state)
        }
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if let destination = capture.destinationApp {
            parts.append("to \(destination.name) \(capture.chatName ?? "")")
        } else {
            parts.append("Quick Answer")
        }
        parts.append(DateGrouping.timeLabel(capture.createdAt))
        if capture.deliveryStatus == .failed { parts.append("not delivered") }
        else if capture.deliveryStatus == .pending { parts.append("sending") }
        else if let task { parts.append(task.state.label) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - What you saw

/// The leading column: the referent stack when the capture has any, otherwise the app
/// the words were spoken in. Never empty, always the same width, so titles align.
private struct SeenColumn: View {
    let capture: Capture

    var body: some View {
        Group {
            if !capture.referents.isEmpty {
                PaperReferentStack(referents: capture.referents)
            } else if let app = capture.sourceApp {
                AppGlyph(symbol: app.symbol, size: Tokens.Ledger.thumb.height, appId: app.id)
            } else {
                RoundedRectangle(cornerRadius: Tokens.Ledger.thumbRadius)
                    .fill(Tokens.Colors.field)
                    .frame(width: Tokens.Ledger.thumb.width, height: Tokens.Ledger.thumb.height)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: Tokens.Ledger.thumb.height * 0.42, weight: .medium))
                            .foregroundStyle(Tokens.Colors.textSecondary)
                    )
            }
        }
        .frame(width: Tokens.Ledger.seenColumnWidth, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// The Island's collapsed referent stack on paper: the first referent in front, up to two
/// more peeking out behind it. Same Core placement math as the Island and the detail bar.
struct PaperReferentStack: View {
    let referents: [Referent]

    private var config: ReferentStackLayout.Config { Tokens.Ledger.stackConfig }

    var body: some View {
        let placements = ReferentStackLayout.collapsed(count: referents.count, config: config)
        ZStack(alignment: .leading) {
            ForEach(placements.reversed(), id: \.index) { p in
                PaperThumb(referent: referents[p.index], size: config.thumb)
                    .scaleEffect(p.scale, anchor: .leading)
                    .offset(x: p.offset.width)
                    .zIndex(p.z)
            }
        }
        .frame(width: ReferentStackLayout.collapsedWidth(count: referents.count, config: config),
               height: config.thumb.height, alignment: .leading)
    }
}

/// The Island's `ReferentThumb` in ink: the image when there is one, otherwise the kind's
/// glyph on a quiet tile. Every tile is quiet: on this page the ink belongs to the words.
struct PaperThumb: View {
    let referent: Referent
    var size: CGSize = Tokens.Ledger.thumb

    var body: some View {
        Group {
            if let resource = referent.resource, let image = PreviewImageCache.shared.image(for: resource) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Tokens.Colors.field
                    Image(systemName: referent.kind.symbol)
                        .font(.system(size: size.height * 0.42, weight: .medium))
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Ledger.thumbRadius))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Ledger.thumbRadius).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
    }
}

// MARK: - Where it went

/// A destination's mark on paper: the bundled provider mark as a template, or the app's
/// symbol. Bare, no tile: the Island's `DestinationIcon` in ink.
struct DestinationMark: View {
    let app: AppRef
    var size: CGFloat = Tokens.Ledger.markSize
    var color: Color = Tokens.Colors.textSecondary

    var body: some View {
        Group {
            if let image = DestinationIcons.image(for: app.id) {
                Image(nsImage: image)
                    .renderingMode(DestinationIcons.keepsColor(app.id) ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(color)
            } else {
                Image(systemName: app.symbol)
                    .font(.system(size: size * 0.8, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Status

/// The Island's four words, in the Island's order of importance, mixed for paper.
private struct TaskStatusWord: View {
    let state: AgentTaskState

    var body: some View {
        HStack(spacing: 5) {
            if state == .working {
                Circle().fill(Tokens.Colors.textSecondary)
                    .frame(width: Tokens.Ledger.statusDot, height: Tokens.Ledger.statusDot)
            }
            Text(state.label)
                .font(Tokens.Ledger.status)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var color: Color {
        switch state {
        case .needsYou: return Tokens.Colors.needsYou
        case .failed: return Tokens.Colors.failed
        case .complete: return Tokens.Colors.ink
        case .working: return Tokens.Colors.textSecondary
        }
    }
}

struct DeliveryFailedBadge: View {
    @Environment(AppModel.self) private var model
    let capture: Capture

    var body: some View {
        Button {
            model.retryDelivery(capture)
        } label: {
            // A filled chip, not colored text: a failed capture must never be mistakable
            // for a highlighted word. The shape carries the meaning.
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Retry")
                    .font(Tokens.Type_.captionMedium)
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Tokens.Colors.warning))
        }
        .buttonStyle(.plain)
        .help("Not delivered to \(capture.destinationApp?.name ?? "destination"). Click to send again.")
        .accessibilityLabel("Not delivered. Retry")
    }
}
