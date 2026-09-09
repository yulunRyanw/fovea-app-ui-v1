import SwiftUI
import FoveaCore

/// Direction 2, Studio: the wall of what you pointed at. Every referent is a tile in an
/// edge-to-edge justified grid with hairline gaps; captures without referents are text tiles.
/// Days pin as headers. Hover reveals the words; click zooms the tile along a shared path.
struct StudioView: View {
    @Environment(LabState.self) private var state
    @Namespace private var zoom

    struct Tile: Identifiable, Hashable {
        let id: String
        let capture: Capture
        let referent: Referent?
        let aspect: CGFloat
    }

    private static let targets: [CGFloat] = [112, 156, 214]

    var body: some View {
        let width = Tokens.Layout.designCanvas.width
        let target = Self.targets[state.studioZoom]
        let groups = DateGrouping.groups(state.filteredCaptures)
        let all = groups.flatMap { tiles(for: $0.captures) }
        let openTile = state.openId.flatMap { id in all.first { $0.id == id } }
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups) { group in
                        Section {
                            StudioGrid(tiles: tiles(for: group.captures), width: width, target: target,
                                       openId: state.openId, namespace: zoom) { tile in
                                state.openId = tile.id
                            }
                            .padding(.bottom, 2)
                        } header: {
                            StudioHeader(title: group.title, subtitle: group.subtitle)
                        }
                    }
                }
                .padding(.top, 52)
                .padding(.bottom, 80)
            }
            .opacity(openTile == nil ? 1 : 0.35)
            .allowsHitTesting(openTile == nil)

            HStack(spacing: Tokens.Space.s) {
                Spacer()
                if state.searchVisible {
                    LabSearchField(width: 320)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
                Text("Search")
                    .font(Tokens.Type_.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().strokeBorder(Tokens.Colors.hairlineStrong, lineWidth: 1))
                    .background(Capsule().fill(Tokens.Colors.elevated.opacity(0.85)))
                    .contentShape(Capsule())
                    .onTapGesture { state.searchVisible.toggle(); if !state.searchVisible { state.searchQuery = "" } }
            }
            .padding(.trailing, 18)
            .padding(.top, 58)
            .animation(Tokens.Motion.animation(.popover, reduceMotion: state.reduceMotion, fadeOnly: true), value: state.searchVisible)

            if let tile = openTile {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { state.openId = nil }
                StudioDetail(tile: tile, namespace: zoom)
                    .padding(.top, 88)
            }
        }
        .animation(Tokens.Motion.animation(state.openId == nil ? .detailClose : .detailOpen, reduceMotion: state.reduceMotion), value: state.openId)
        .animation(Tokens.Motion.animation(.accordion, reduceMotion: state.reduceMotion, fadeOnly: true), value: state.studioZoom)
    }

    /// A capture with regions yields one tile per region; one without yields a text tile.
    private func tiles(for captures: [Capture]) -> [Tile] {
        captures.flatMap { c -> [Tile] in
            if c.referents.isEmpty {
                return [Tile(id: c.id, capture: c, referent: nil, aspect: 1.3)]
            }
            return c.referents.map { r in
                Tile(id: r.id, capture: c, referent: r, aspect: min(2.2, max(0.6, r.aspect)))
            }
        }
    }
}

private struct StudioHeader: View {
    @Environment(LabState.self) private var state
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Tokens.Colors.textPrimary)
            if let subtitle { Text(subtitle).font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary) }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(state.canvas.color)
    }
}

private struct StudioGrid: View {
    let tiles: [StudioView.Tile]
    let width: CGFloat
    let target: CGFloat
    let openId: String?
    let namespace: Namespace.ID
    let open: (StudioView.Tile) -> Void

    var body: some View {
        let items = tiles.map { JustifiedRows.Item(id: $0.id, aspect: $0.aspect) }
        let rows = JustifiedRows.layout(items, width: width, targetHeight: target, spacing: 2, maxPerRow: 6)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 2) {
                    ForEach(row.items, id: \.id) { placed in
                        if let tile = tiles.first(where: { $0.id == placed.id }) {
                            StudioTile(tile: tile, width: placed.width, height: row.height,
                                       isSource: openId != tile.id, namespace: namespace)
                                .onTapGesture { open(tile) }
                        }
                    }
                    if !row.justified { Spacer(minLength: 0) }
                }
            }
        }
    }
}

private struct StudioTile: View {
    let tile: StudioView.Tile
    let width: CGFloat
    let height: CGFloat
    let isSource: Bool
    let namespace: Namespace.ID
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            StudioMedia(tile: tile, width: width, height: height, detail: false)
                .matchedGeometryEffect(id: tile.id, in: namespace, isSource: isSource)
            if hovering, tile.referent != nil {
                Text(tile.capture.labTitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(2)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(width: width, alignment: .leading)
                    .background(Tokens.Colors.elevated.opacity(0.92))
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering, fadeOnly: true)
    }
}

/// The tile's picture: the region itself for images, the shipping preview for code, terminal,
/// charts, documents and equations, and the words on a quiet tile when there is no region.
private struct StudioMedia: View {
    let tile: StudioView.Tile
    let width: CGFloat
    let height: CGFloat
    let detail: Bool

    var body: some View {
        if let r = tile.referent {
            if (r.kind == .image || r.kind == .screenshot), let resource = r.resource,
               let image = PreviewImageCache.shared.image(for: resource) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: detail ? .fit : .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                CapturePreview(referent: r, width: width, height: height, detail: detail)
            }
        } else {
            Text(tile.capture.labTitle)
                .font(.system(size: detail ? 15 : 12))
                .lineSpacing(2)
                .foregroundStyle(Tokens.Colors.ink)
                .lineLimit(detail ? nil : 6)
                .padding(12)
                .frame(width: width, height: height, alignment: .topLeading)
                .background(Tokens.Colors.field)
        }
    }
}

/// A tile grown into a centered card along its own path: the picture large, the words below.
private struct StudioDetail: View {
    @Environment(LabState.self) private var state
    let tile: StudioView.Tile
    let namespace: Namespace.ID

    var body: some View {
        let cardWidth: CGFloat = 732
        let mediaWidth = cardWidth - 48
        let mediaHeight = min(420, (mediaWidth / tile.aspect).rounded())
        VStack(alignment: .leading, spacing: 16) {
            StudioMedia(tile: tile, width: mediaWidth, height: mediaHeight, detail: true)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))
                .matchedGeometryEffect(id: tile.id, in: namespace, isSource: true)
            Text(tile.capture.labTitle)
                .font(.system(size: 14))
                .lineSpacing(5)
                .foregroundStyle(Tokens.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.s) {
                if let d = tile.capture.destinationApp { DestinationMark(app: d) }
                Text(tile.capture.labPlace)
                if let r = tile.referent, let app = r.sourceApp {
                    Text("·"); Text([app, r.sourceWindowTitle].compactMap { $0 }.joined(separator: " · "))
                }
                Spacer()
                if let task = state.task(for: tile.capture) { LabStatusWord(state: task.state, font: Tokens.Type_.caption) }
                Text(DateGrouping.detailLabel(tile.capture.createdAt))
            }
            .font(Tokens.Type_.caption)
            .foregroundStyle(Tokens.Colors.textTertiary)
            .lineLimit(1)
        }
        .padding(24)
        .frame(width: cardWidth, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.card, style: .continuous).fill(Tokens.Colors.elevated))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Detail.Radius.card, style: .continuous).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
        .shadow(color: Tokens.Detail.Colors.shadowPrimary, radius: Tokens.Detail.Layout.shadowPrimaryRadius, y: Tokens.Detail.Layout.shadowPrimaryY)
        .transition(.opacity)
    }
}
