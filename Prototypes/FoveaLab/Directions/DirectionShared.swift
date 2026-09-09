import SwiftUI
import FoveaCore

// Pieces the four directions share: the status word, the in-place expansion of a capture,
// the content crossfade, and the arrival of a capture handed down from the notch.

/// The Island's four words in the Island's order, mixed for paper.
struct LabStatusWord: View {
    let state: AgentTaskState
    var font: Font = Tokens.Ledger.status

    var body: some View {
        HStack(spacing: 5) {
            if state == .working {
                Circle().fill(Tokens.Colors.textSecondary)
                    .frame(width: Tokens.Ledger.statusDot, height: Tokens.Ledger.statusDot)
            }
            Text(state.label)
                .font(font)
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

/// The delivery chip: shape carries the meaning, never color alone.
struct LabRetryChip: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10, weight: .semibold))
            Text("Retry").font(Tokens.Type_.captionMedium)
        }
        .foregroundStyle(.white)
        .fixedSize()
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(Tokens.Colors.warning))
    }
}

extension Capture {
    var labTitle: String { transcript ?? question ?? "" }
    var labDestinationName: String {
        if intent == .quickAnswer { return "Quick Answer" }
        return destinationApp?.name ?? "Fovea"
    }
    var labPlace: String { chatName ?? labDestinationName }
    var labReferentCount: String? {
        guard !referents.isEmpty else { return nil }
        return referents.count == 1 ? "1 referent" : "\(referents.count) referents"
    }
}

/// What a capture unfolds into, in place: the referents at a legible size, the answer for a
/// Quick Answer, then tags and where it went. The words above it are already the transcript.
struct CaptureExpansion: View {
    let capture: Capture
    var thumbHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !capture.referents.isEmpty {
                HStack(spacing: 8) {
                    ForEach(capture.referents) { r in
                        CapturePreview(referent: r, width: (thumbHeight * min(2.2, max(0.7, r.aspect))).rounded(),
                                       height: thumbHeight)
                    }
                }
            }
            if capture.intent == .quickAnswer, let answer = capture.answer {
                Text(answer)
                    .font(Tokens.Type_.body)
                    .lineSpacing(4)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Tokens.Space.s) {
                ForEach(capture.tags, id: \.self) { tag in
                    Text(tag)
                        .font(Tokens.Type_.caption)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Tokens.Colors.field))
                }
                Spacer(minLength: 0)
                if let d = capture.destinationApp {
                    DestinationMark(app: d)
                    Text(capture.labPlace)
                }
                Text(DateGrouping.detailLabel(capture.createdAt))
            }
            .font(Tokens.Type_.caption)
            .foregroundStyle(Tokens.Colors.textTertiary)
        }
        .padding(.top, 10)
    }
}

/// Content crossfade: opacity with a light blur and a small scale from the top (the Island's
/// own recipe, `Tokens.Motion.contentBlur/contentScale`).
struct LabContentModifier: ViewModifier {
    let progress: Double
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: Tokens.Motion.contentBlur * (1 - progress))
            .scaleEffect(Tokens.Motion.contentScale + (1 - Tokens.Motion.contentScale) * progress, anchor: .top)
    }
}

/// A capture arriving from the notch: scales from 0.9 at the top edge, drops 6 pt, unblurs.
struct LabArrivalModifier: ViewModifier {
    let progress: Double
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: 4 * (1 - progress))
            .scaleEffect(0.9 + 0.1 * progress, anchor: .top)
            .offset(y: -6 * (1 - progress))
    }
}

extension AnyTransition {
    static var labContent: AnyTransition {
        .modifier(active: LabContentModifier(progress: 0), identity: LabContentModifier(progress: 1))
    }
    static var labArrival: AnyTransition {
        .modifier(active: LabArrivalModifier(progress: 0), identity: LabArrivalModifier(progress: 1))
    }
}

/// A quiet search field on the canvas, focused when it appears.
struct LabSearchField: View {
    @Environment(LabState.self) private var state
    @FocusState private var focused: Bool
    var placeholder = "Search your captures…"
    var width: CGFloat? = nil

    var body: some View {
        @Bindable var state = state
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Tokens.Colors.textSecondary)
            TextField(placeholder, text: $state.searchQuery)
                .textFieldStyle(.plain)
                .font(Tokens.Type_.search)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .focused($focused)
        }
        .padding(.horizontal, 14)
        .frame(width: width)
        .frame(height: Tokens.Layout.headerSearchHeight)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.field).fill(Tokens.Colors.field))
        .onAppear { focused = true }
    }
}
