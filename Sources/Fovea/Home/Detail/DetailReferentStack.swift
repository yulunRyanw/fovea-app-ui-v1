import SwiftUI
import FoveaCore

/// A hovered shelf thumbnail and where it sits in the card, so the card can float its
/// enlarged preview above it.
struct ReferentHover: Equatable {
    let referent: Referent
    let frame: CGRect
}

/// Collapsed referent affordance in the metadata bar: up to three overlapping thumbnails
/// with white rims, plus `+N`. Hovering or focusing it asks the card to unfold the shelf.
struct DetailReferentStack: View {
    let referents: [Referent]
    @Binding var hot: Bool
    let expanded: Bool
    @FocusState private var focused: Bool

    private var config: ReferentStackLayout.Config { Tokens.Detail.Layout.stackConfig }

    var body: some View {
        let placements = ReferentStackLayout.collapsed(count: referents.count, config: config)
        let width = ReferentStackLayout.collapsedWidth(count: referents.count, config: config)
        let hidden = referents.count - placements.count
        HStack(spacing: Tokens.Space.xs + 2) {
            ZStack(alignment: .leading) {
                ForEach(placements.reversed(), id: \.index) { p in
                    DetailThumb(referent: referents[p.index], size: config.thumb)
                        .scaleEffect(p.scale, anchor: .leading)
                        .offset(x: p.offset.width)
                        .zIndex(p.z)
                }
            }
            .frame(width: width + Tokens.Detail.Layout.thumbRim, height: config.thumb.height, alignment: .leading)
            if hidden > 0 {
                Text("+\(hidden)")
                    .font(Tokens.Detail.Type_.meta)
                    .foregroundStyle(Tokens.Detail.Colors.muted)
                    .fixedSize()
            }
        }
        .padding(.horizontal, Tokens.Space.xs)
        .frame(height: Tokens.Detail.Layout.tagHeight)
        .contentShape(Rectangle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused, radius: Tokens.Detail.Radius.thumb)
        .onHover { hot = $0 || focused }
        .onChange(of: focused) { _, f in hot = f }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("View \(referents.count) referent\(referents.count == 1 ? "" : "s")")
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Shows each one above the bar")
    }
}

/// The unfolded shelf above the metadata bar: every referent, in order. Hovering or
/// focusing one shows it enlarged; nothing needs a click.
struct DetailReferentShelf: View {
    let referents: [Referent]
    @Binding var hot: Bool
    @Binding var hover: ReferentHover?
    let maxWidth: CGFloat
    @FocusState private var focusedId: String?
    @State private var frames: [String: CGRect] = [:]

    var body: some View {
        let row = HStack(spacing: Tokens.Detail.Layout.shelfGap) {
            ForEach(referents) { referent in
                DetailThumb(referent: referent, size: Tokens.Detail.Layout.shelfThumb)
                    .scaleEffect(hover?.referent.id == referent.id ? 1.06 : 1)
                    .focusable()
                    .focused($focusedId, equals: referent.id)
                    .focusEffectDisabled()
                    .focusRing(focusedId == referent.id, radius: Tokens.Detail.Radius.thumb)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(DetailCard.coordinateSpace)) } action: {
                        frames[referent.id] = $0
                    }
                    .onHover { inside in
                        if inside { show(referent) } else if hover?.referent.id == referent.id { hover = nil }
                    }
                    .help(title(referent))
                    .accessibilityLabel(title(referent))
                    .accessibilityHint("Shows it larger while hovered or focused")
            }
        }
        .padding(Tokens.Detail.Layout.shelfPadding)

        Group {
            if shelfWidth > maxWidth {
                ScrollView(.horizontal) { row }
                    .scrollIndicators(.hidden)
                    .frame(width: maxWidth)
            } else {
                row
            }
        }
        .background(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.shelf, style: .continuous).fill(Tokens.Detail.Colors.shelfSurface))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.shelf, style: .continuous).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
        .shadow(color: Tokens.Detail.Colors.shadowContact, radius: Tokens.Detail.Layout.shadowContactRadius, y: Tokens.Detail.Layout.shadowContactY)
        .onHover { hot = $0 || focusedId != nil }
        .onChange(of: focusedId) { _, id in
            hot = id != nil
            if let id, let referent = referents.first(where: { $0.id == id }) { show(referent) }
            else if id == nil, hover != nil, !hotPointer { hover = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Referents")
    }

    private var hotPointer: Bool { hover != nil && hot }

    private var shelfWidth: CGFloat {
        CGFloat(referents.count) * Tokens.Detail.Layout.shelfThumb.width
            + CGFloat(max(0, referents.count - 1)) * Tokens.Detail.Layout.shelfGap
            + Tokens.Detail.Layout.shelfPadding * 2
    }

    private func show(_ referent: Referent) {
        guard let frame = frames[referent.id] else { return }
        hover = ReferentHover(referent: referent, frame: frame)
    }

    private func title(_ referent: Referent) -> String {
        referent.filename ?? referent.title ?? referent.kind.rawValue.capitalized
    }
}

/// Rounded-square thumbnail with a white rim and a soft shadow: the image when there is
/// one, otherwise the kind's glyph on a quiet tile.
struct DetailThumb: View {
    let referent: Referent
    let size: CGSize

    var body: some View {
        Group {
            if let resource = referent.resource, let image = PreviewImageCache.shared.image(for: resource) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Tokens.Colors.field
                    Image(systemName: referent.kind.symbol)
                        .font(.system(size: size.height * 0.4, weight: .medium))
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.thumb, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.thumb, style: .continuous)
            .strokeBorder(Tokens.Detail.Colors.thumbRim, lineWidth: Tokens.Detail.Layout.thumbRim))
        .shadow(color: Tokens.Detail.Colors.thumbShadow, radius: 2, y: 1)
    }
}

/// The enlarged look at one referent while it is hovered or focused in the shelf.
struct ReferentHoverPreview: View {
    let referent: Referent

    static func height(for referent: Referent) -> CGFloat {
        imageHeight(for: referent) + Tokens.Detail.Layout.previewCaption + Tokens.Space.s * 2
    }

    static func imageHeight(for referent: Referent) -> CGFloat {
        (Tokens.Detail.Layout.previewWidth / max(0.6, referent.aspect)).rounded()
    }

    var body: some View {
        let width = Tokens.Detail.Layout.previewWidth
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            CapturePreview(referent: referent, width: width - Tokens.Space.s * 2,
                           height: Self.imageHeight(for: referent) - Tokens.Space.s * 2, detail: true)
            HStack(spacing: Tokens.Space.s) {
                Text(referent.filename ?? referent.title ?? referent.kind.rawValue.capitalized)
                    .font(Tokens.Type_.bodyMedium)
                    .foregroundStyle(Tokens.Detail.Colors.foreground)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let app = referent.sourceApp {
                    Text([app, referent.sourceWindowTitle].compactMap { $0 }.joined(separator: " · "))
                        .font(Tokens.Type_.secondary)
                        .foregroundStyle(Tokens.Detail.Colors.muted)
                        .lineLimit(1)
                }
            }
            .frame(height: Tokens.Detail.Layout.previewCaption - Tokens.Space.s)
        }
        .padding(Tokens.Space.s)
        .frame(width: width, height: Self.height(for: referent))
        .background(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.preview, style: .continuous).fill(Tokens.Detail.Colors.previewSurface))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.preview, style: .continuous).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
        .shadow(color: Tokens.Detail.Colors.shadowPrimary, radius: Tokens.Detail.Layout.shadowPrimaryRadius / 2, y: Tokens.Detail.Layout.shadowPrimaryY / 2)
        .accessibilityHidden(true)
    }
}
