import SwiftUI
import FoveaCore

/// Referents captured with the request. Collapsed: the first in front, the rest peeking
/// out behind. Hover or focus fans them all out, wrapping onto rows; hovering one grows a
/// preview beneath the stack. No `+N` — every referent is shown.
struct ReferentStackView: View {
    let model: IslandModel
    /// How wide the fanned-out stack may be before it wraps.
    let availableWidth: CGFloat
    @FocusState private var focused: Bool
    @State private var hovering = false
    @State private var graceTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var draft: ReviewDraft? { model.state.review }
    private var config: ReferentStackLayout.Config { Tokens.Island.Layout.stackConfig }

    var body: some View {
        if let draft, !draft.referents.isEmpty {
            let expanded = draft.stackExpanded || focused
            content(draft.referents, expanded: expanded)
                .contentShape(Rectangle())
                .focusable()
                .focused($focused)
                .focusEffectDisabled()
                .onHover { inside in
                    graceTask?.cancel()
                    if inside {
                        model.send(.setStackExpanded(true))
                    } else {
                        // A short grace so moving between thumbnails does not collapse it.
                        graceTask = Task {
                            try? await Task.sleep(for: Tokens.Motion.stackGrace)
                            guard !Task.isCancelled else { return }
                            model.send(.setStackExpanded(false))
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(draft.referents.count) referents")
                .accessibilityHint("Expands to show each one")
                .popover(isPresented: Binding(
                    get: { draft.inspectingReferentId != nil },
                    set: { if !$0 { model.send(.inspectReferent(nil)) } }
                ), arrowEdge: .bottom) {
                    if let id = draft.inspectingReferentId, let referent = draft.referents.first(where: { $0.id == id }) {
                        ReferentInspector(referent: referent, remove: { model.send(.removeReferent(id)) })
                    }
                }
        }
    }

    @ViewBuilder
    private func content(_ referents: [Referent], expanded: Bool) -> some View {
        if expanded {
            let layout = ReferentStackLayout.wrapped(count: referents.count, availableWidth: availableWidth, config: config)
            ZStack(alignment: .topLeading) {
                ForEach(layout.placements, id: \.index) { p in
                    thumb(referents[p.index], hoverable: true)
                        .offset(x: p.offset.width, y: p.offset.height)
                }
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        } else {
            ZStack(alignment: .leading) {
                ForEach(ReferentStackLayout.collapsed(count: referents.count, config: config).reversed(), id: \.index) { p in
                    thumb(referents[p.index], hoverable: false)
                        .scaleEffect(p.scale, anchor: .leading)
                        .opacity(p.opacity)
                        .offset(x: p.offset.width)
                        .zIndex(p.z)
                }
            }
            .frame(width: ReferentStackLayout.collapsedWidth(count: referents.count, config: config),
                   height: config.thumb.height, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Island.Radius.thumb)
                    .strokeBorder(Tokens.Island.Colors.focus, lineWidth: 1.5)
                    .padding(-3)
                    .opacity(focused ? 1 : 0)
            )
        }
    }

    private func thumb(_ referent: Referent, hoverable: Bool) -> some View {
        let isHovered = model.state.review?.hoveredReferentId == referent.id
        return Button { model.send(.inspectReferent(referent.id)) } label: {
            ReferentThumb(referent: referent, size: config.thumb)
                .scaleEffect(hoverable && isHovered ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            guard hoverable else { return }
            if inside { model.send(.hoverReferent(referent.id)) }
            else if model.state.review?.hoveredReferentId == referent.id { model.send(.hoverReferent(nil)) }
        }
        .accessibilityLabel(referent.filename ?? referent.title ?? referent.kind.rawValue)
        .accessibilityHint("Inspect")
    }
}

/// The larger look at the hovered referent, positioned under its thumbnail so the island
/// grows downward. Never steals the pointer.
struct ReferentPreviewRow: View {
    let referent: Referent
    let index: Int
    let count: Int
    let availableWidth: CGFloat
    let contentWidth: CGFloat

    private var config: ReferentStackLayout.Config { Tokens.Island.Layout.stackConfig }

    var body: some View {
        ReferentPreviewCard(referent: referent)
            .padding(.leading, ReferentStackLayout.previewLeading(
                index: index, count: count, availableWidth: availableWidth,
                previewWidth: Tokens.Island.Layout.referentPreviewWidth, contentWidth: contentWidth, config: config))
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
    }
}

/// One referent, enlarged, on the dark elevated surface.
struct ReferentPreviewCard: View {
    let referent: Referent

    static func imageHeight(for referent: Referent) -> CGFloat {
        min(Tokens.Island.Layout.referentPreviewMaxImageHeight,
            (Tokens.Island.Layout.referentPreviewWidth / max(0.6, referent.aspect)).rounded())
    }

    var body: some View {
        let width = Tokens.Island.Layout.referentPreviewWidth
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            CapturePreview(referent: referent, width: width - Tokens.Space.s * 2,
                           height: Self.imageHeight(for: referent) - Tokens.Space.s * 2, detail: true)
            HStack(spacing: Tokens.Space.s) {
                Text(referent.filename ?? referent.title ?? referent.kind.rawValue.capitalized)
                    .font(Tokens.Island.Type_.bodyMedium)
                    .foregroundStyle(Tokens.Island.Colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let app = referent.sourceApp {
                    Text([app, referent.sourceWindowTitle].compactMap { $0 }.joined(separator: " · "))
                        .font(Tokens.Island.Type_.secondary)
                        .foregroundStyle(Tokens.Island.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(height: Tokens.Island.Layout.referentPreviewCaption - Tokens.Space.s)
        }
        .padding(Tokens.Space.s)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.thumb + 2, style: .continuous).fill(Tokens.Island.Colors.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.thumb + 2, style: .continuous).strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// A small preview: the image itself, or a kind glyph on a dark tile.
struct ReferentThumb: View {
    let referent: Referent
    var size: CGSize

    var body: some View {
        Group {
            if let resource = referent.resource, let image = PreviewImageCache.shared.image(for: resource) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Tokens.Island.Colors.field
                    Image(systemName: symbol)
                        .font(.system(size: size.height * 0.42, weight: .medium))
                        .foregroundStyle(Tokens.Island.Colors.textSecondary)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Island.Radius.thumb))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.thumb).strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
    }

    private var symbol: String { referent.kind.symbol }
}

/// Larger look at one referent, with the only place Remove lives.
struct ReferentInspector: View {
    let referent: Referent
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            ReferentThumb(referent: referent, size: CGSize(width: 260, height: 260 / max(0.6, referent.aspect)))
            HStack(spacing: Tokens.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(referent.filename ?? referent.title ?? referent.kind.rawValue.capitalized)
                        .font(Tokens.Island.Type_.bodyMedium)
                        .foregroundStyle(Tokens.Island.Colors.textPrimary)
                        .lineLimit(1)
                    if let app = referent.sourceApp {
                        Text([app, referent.sourceWindowTitle].compactMap { $0 }.joined(separator: " · "))
                            .font(Tokens.Island.Type_.secondary)
                            .foregroundStyle(Tokens.Island.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                IslandTextButton(title: "Remove", action: remove)
                    .accessibilityHint("Removes this referent from the request")
            }
        }
        .padding(Tokens.Space.m)
        .background(Tokens.Island.Colors.surfaceElevated)
        .environment(\.colorScheme, .dark)
    }
}
