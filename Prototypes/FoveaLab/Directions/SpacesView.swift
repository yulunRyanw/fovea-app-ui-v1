import SwiftUI
import AppKit
import CoreImage
import FoveaCore

/// Direction 3, Spaces: by project, not by time. Every Chat is a large quiet tile tinted from
/// its own screenshots, ordered by what needs you. A tile grows into its space.
struct SpacesView: View {
    @Environment(LabState.self) private var state
    @Namespace private var hero

    var body: some View {
        let spaces = state.spaces
        let openSpace = state.openId.flatMap { id in spaces.first { $0.id == id } }
        ZStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                    ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                        SpaceTile(space: space, tall: index < 3)
                            .matchedGeometryEffect(id: space.id, in: hero, isSource: openSpace?.id != space.id)
                            .onTapGesture {
                                state.selectedSpaceId = space.id
                                state.openId = space.id
                            }
                    }
                }
                .padding(.horizontal, 44)
                .padding(.top, 88)
                .padding(.bottom, 80)
            }
            .opacity(openSpace == nil ? 1 : 0)
            .allowsHitTesting(openSpace == nil)

            if openSpace != nil, let space = state.selectedSpace {
                SpaceDetail(space: space)
                    .matchedGeometryEffect(id: space.id, in: hero, isSource: true)
                    .id(space.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .foveaSpring(state.openId == nil ? .close : .open, value: state.openId)
        .foveaSpring(.convert, value: state.selectedSpaceId)
    }
}

/// The average color of a space's newest screenshot, so each tile carries a whisper of its
/// own content. Cached by resource.
@MainActor
enum SpaceTint {
    private static var cache: [String: Color] = [:]

    static func color(for space: LabSpace) -> Color {
        let candidates = space.captures.flatMap(\.referents).filter { $0.kind == .image || $0.kind == .screenshot }
        for r in candidates {
            guard let resource = r.resource else { continue }
            if let c = cache[resource] { return c }
            if let c = average(resource) { cache[resource] = c; return c }
        }
        return Tokens.Colors.ink
    }

    private static func average(_ resource: String) -> Color? {
        guard let url = FoveaResources.url(resource), let ci = CIImage(contentsOf: url) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: CIVector(cgRect: ci.extent)])
        guard let out = filter?.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(out, toBitmap: &px, rowBytes: 4,
                                                                  bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                                                  format: .RGBA8, colorSpace: nil)
        return Color(.sRGB, red: Double(px[0]) / 255, green: Double(px[1]) / 255, blue: Double(px[2]) / 255)
    }
}

private struct SpaceTile: View {
    @Environment(LabState.self) private var state
    let space: LabSpace
    let tall: Bool

    private var recent: Bool { state.recentCaptureId == space.newest.id }

    var body: some View {
        let hasImage = space.captures.flatMap(\.referents).contains { $0.kind == .image || $0.kind == .screenshot }
        let tint = SpaceTint.color(for: space)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                DestinationMark(app: space.destination, size: 14, color: Tokens.Colors.ink.opacity(0.8))
                Text(space.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                if let q = space.qualifier {
                    Text(q).font(Tokens.Type_.caption).foregroundStyle(Tokens.Colors.textTertiary).lineLimit(1)
                }
                Spacer(minLength: 6)
                if let task = space.task { LabStatusWord(state: task.state, font: Tokens.Type_.captionMedium) }
            }
            Text(space.task.map { $0.state == .complete ? space.newest.labTitle : $0.activity } ?? space.newest.labTitle)
                .font(.system(size: 12))
                .lineSpacing(2)
                .foregroundStyle(Tokens.Colors.textSecondary)
                .lineLimit(tall ? 3 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(space.captures.flatMap(\.referents).prefix(3)) { r in
                    PaperThumb(referent: r, size: Tokens.Ledger.thumb)
                }
                Spacer(minLength: 0)
                Text("\(space.captures.count)")
                    .font(Tokens.Type_.caption)
                    .foregroundStyle(Tokens.Colors.textTertiary)
            }
        }
        .padding(16)
        .frame(height: tall ? 176 : 136)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(hasImage ? tint.opacity(0.09) : Tokens.Colors.ink.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(recent ? Tokens.Colors.selection : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foveaAnimation(.highlightFade, value: recent, fadeOnly: true)
    }
}

/// A space, open: the status line as the header, then its captures as Paper rows.
private struct SpaceDetail: View {
    @Environment(LabState.self) private var state
    let space: LabSpace

    var body: some View {
        let tint = SpaceTint.color(for: space)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Colors.glyph)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .onTapGesture { state.openId = nil }
                DestinationMark(app: space.destination, size: 16, color: Tokens.Colors.ink.opacity(0.8))
                Text(space.name).font(.system(size: 17, weight: .medium)).foregroundStyle(Tokens.Colors.ink)
                Text("in \(space.destination.name)").font(Tokens.Type_.secondary).foregroundStyle(Tokens.Colors.textTertiary)
                Spacer()
                if let task = space.task {
                    Text(task.activity).font(Tokens.Type_.secondary).foregroundStyle(Tokens.Colors.textSecondary)
                    LabStatusWord(state: task.state)
                }
            }
            .padding(.horizontal, 44)
            .padding(.top, 70)
            .padding(.bottom, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(space.captures) { capture in
                        PaperRow(capture: capture, task: state.task(for: capture), column: 900)
                    }
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.035))
    }
}
