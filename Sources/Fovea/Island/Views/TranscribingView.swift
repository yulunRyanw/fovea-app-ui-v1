import SwiftUI
import FoveaCore

/// Same outer size as Listening: one centered line and a marching progress hairline. No
/// Cancel button — Escape cancels, captured globally while transcribing.
struct TranscribingView: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotMode) private var snapshotMode

    var body: some View {
        VStack(spacing: Tokens.Island.Layout.voiceRowGap) {
            Text(text.isEmpty ? "Transcribing…" : text)
                .font(Tokens.Island.Type_.body)
                .foregroundStyle(text.isEmpty ? Tokens.Island.Colors.textSecondary : Tokens.Island.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: Tokens.Island.Layout.voiceRowHeight)
                .accessibilityLabel(text.isEmpty ? "Transcribing" : "Transcribing: \(text)")
                .accessibilityHint("Press Escape to cancel")
            IndeterminateBar(reduceMotion: reduceMotion, snapshotMode: snapshotMode)
                .frame(height: Tokens.Island.Layout.voiceProgressHeight)
        }
        .padding(.horizontal, Tokens.Island.Layout.voiceContentPaddingH)
        .padding(.vertical, Tokens.Island.Layout.voicePaddingV)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

/// "Didn't catch that": one Retry, and a bar along the bottom that drains over the
/// countdown. When it empties the island rests.
struct VoiceRetryView: View {
    let failure: IslandFailure
    let retry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotMode) private var snapshotMode

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            IslandTextButton(title: "Retry", prominent: true, action: retry)
                .frame(height: Tokens.Island.Layout.voiceRowHeight)
                .accessibilityLabel("\(failure.message) Retry")
                .accessibilityHint("Listens again")
            Spacer(minLength: 0)
            CountdownBar(reduceMotion: reduceMotion, snapshotMode: snapshotMode)
                .frame(height: Tokens.Island.Layout.voiceProgressHeight)
                .padding(.horizontal, Tokens.Island.Radius.compactBottom)
        }
        .padding(.horizontal, Tokens.Island.Layout.voiceContentPaddingH)
        .padding(.top, Tokens.Island.Layout.voicePaddingV)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

/// A missing permission (mic denied): a message and one action, no countdown.
struct VoiceFailureView: View {
    let failure: IslandFailure
    let act: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Text(failure.message)
                .font(Tokens.Island.Type_.body)
                .foregroundStyle(Tokens.Island.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let title = actionTitle {
                IslandTextButton(title: title, prominent: true, action: act)
            }
            IslandIconButton(symbol: "xmark", label: "Dismiss", action: dismiss)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Island.Layout.voiceContentPaddingH)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var actionTitle: String? {
        switch failure.recovery {
        case .retry: return "Retry"
        case .openSettings: return "Open Settings"
        case .openMainApp: return "Open Fovea"
        case .none: return nil
        }
    }
}

/// A short segment sliding left to right while transcription runs.
private struct IndeterminateBar: View {
    let reduceMotion: Bool
    let snapshotMode: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Island.Colors.progressTrack)
                if reduceMotion || snapshotMode {
                    Capsule().fill(Tokens.Island.Colors.progressFill).frame(width: geo.size.width * 0.6)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                        let segment = geo.size.width * 0.32
                        Capsule()
                            .fill(Tokens.Island.Colors.progressFill)
                            .frame(width: segment)
                            .offset(x: (geo.size.width + segment) * t - segment)
                    }
                }
            }
            .clipShape(Capsule())
        }
        .accessibilityHidden(true)
    }
}

/// Drains from full to empty over the failure countdown, then the island collapses.
private struct CountdownBar: View {
    let reduceMotion: Bool
    let snapshotMode: Bool
    @State private var start = Date()

    private var seconds: Double { Double(Tokens.Motion.failureCountdown.components.seconds) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Island.Colors.progressTrack)
                if snapshotMode {
                    Capsule().fill(Tokens.Island.Colors.progressFill).frame(width: geo.size.width * 0.62)
                } else if reduceMotion {
                    TimelineView(.periodic(from: start, by: 0.5)) { context in
                        let fraction = remaining(at: context.date)
                        Capsule().fill(Tokens.Island.Colors.progressFill).frame(width: geo.size.width * fraction)
                    }
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        let fraction = remaining(at: context.date)
                        Capsule().fill(Tokens.Island.Colors.progressFill).frame(width: geo.size.width * fraction)
                    }
                }
            }
            .clipShape(Capsule())
        }
        .onAppear { start = Date() }
        .accessibilityHidden(true)
    }

    private func remaining(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(start)
        return CGFloat(max(0, min(1, 1 - elapsed / seconds)))
    }
}
