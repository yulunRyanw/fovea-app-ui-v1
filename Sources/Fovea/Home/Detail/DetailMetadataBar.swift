import SwiftUI
import FoveaCore

/// Fixed bottom bar: referent stack (when any) · tags · destination · time. One row, no
/// labels, everything vertically centered.
struct DetailMetadataBar: View {
    let capture: Capture
    @Binding var triggerHot: Bool
    let shelfOpen: Bool

    var body: some View {
        HStack(spacing: Tokens.Detail.Layout.barGap) {
            if !capture.referents.isEmpty {
                DetailReferentStack(referents: capture.referents, hot: $triggerHot, expanded: shelfOpen)
            }
            DetailTags(tags: capture.tags)
            Spacer(minLength: Tokens.Space.s)
            if let destination = capture.destinationApp {
                let place = capture.chatName ?? destination.name
                HStack(spacing: Tokens.Space.s) {
                    AppGlyph(symbol: destination.symbol, size: Tokens.Detail.Layout.destinationGlyph, appId: destination.id)
                    Text(place)
                        .font(Tokens.Detail.Type_.meta)
                        .foregroundStyle(Tokens.Detail.Colors.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Destination: \(destination.name), \(place)")
            }
            // Plain timestamp, rightmost; no clock glyph (spec).
            Text(DateGrouping.detailLabel(capture.createdAt))
                .font(Tokens.Detail.Type_.meta)
                .foregroundStyle(Tokens.Detail.Colors.muted)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel("Captured \(DateGrouping.fullLabel(capture.createdAt))")
        }
        .frame(maxWidth: .infinity)
    }
}

/// Compact low-contrast pills; the first few, then `+N`. Never wraps.
struct DetailTags: View {
    let tags: [String]

    var body: some View {
        let visible = Array(tags.prefix(Tokens.Detail.Layout.tagMaxVisible))
        let overflow = tags.count - visible.count
        HStack(spacing: Tokens.Space.s) {
            ForEach(visible, id: \.self) { tag in
                pill(tag)
            }
            if overflow > 0 {
                pill("+\(overflow)")
                    .accessibilityLabel("\(overflow) more tags: \(tags.dropFirst(visible.count).joined(separator: ", "))")
            }
        }
        .lineLimit(1)
        .layoutPriority(-1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tags.isEmpty ? "" : "Tags")
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Detail.Type_.meta)
            .foregroundStyle(Tokens.Detail.Colors.foreground)
            .lineLimit(1)
            .padding(.horizontal, Tokens.Space.m)
            .frame(height: Tokens.Detail.Layout.tagHeight)
            .background(Capsule().fill(Tokens.Detail.Colors.tagFill))
    }
}
