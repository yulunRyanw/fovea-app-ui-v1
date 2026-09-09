import SwiftUI

/// The Listening Flowing Bar: nine short white bars, centered, following the microphone.
/// No icon, no label, no buttons; the outer bounds never move.
struct ListeningView: View {
    let level: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotMode) private var snapshotMode

    private let bars = Tokens.Island.Layout.waveformBars
    /// Center bars carry more of the level than the edges.
    private var profile: [Double] {
        (0..<bars).map { i in
            let x = Double(i) / Double(bars - 1) * 2 - 1
            return 0.45 + 0.55 * (1 - x * x)
        }
    }

    var body: some View {
        Group {
            if snapshotMode {
                waveform(time: 1.3, level: 0.72)
            } else if reduceMotion {
                waveform(time: 0, level: Double(level), still: true)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 40)) { context in
                    waveform(time: context.date.timeIntervalSinceReferenceDate, level: Double(level))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Listening")
        .accessibilityValue(level > 0.5 ? "Loud" : (level > 0.15 ? "Speaking" : "Quiet"))
    }

    private func waveform(time: TimeInterval, level: Double, still: Bool = false) -> some View {
        let minH = Tokens.Island.Layout.waveformMinHeight
        let maxH = Tokens.Island.Layout.waveformMaxHeight
        return HStack(alignment: .center, spacing: Tokens.Island.Layout.waveformBarGap) {
            ForEach(0..<bars, id: \.self) { i in
                let flutter = still ? 1.0 : 0.72 + 0.28 * sin(time * 11 + Double(i) * 1.9)
                let idle = still ? 0.0 : 0.05 * (sin(time * 5.5 + Double(i) * 0.8) + 1)
                let amount = min(1, max(0, level * profile[i] * flutter + idle))
                Capsule(style: .continuous)
                    .fill(Tokens.Island.Colors.waveform)
                    .frame(width: Tokens.Island.Layout.waveformBarWidth,
                           height: minH + (maxH - minH) * CGFloat(amount))
            }
        }
        .frame(height: maxH)
    }
}
