// Copied from Sources/Fovea/Home/CaptureRow.swift (thumbs, stack, mark) and
// Sources/Fovea/Island/Views/IslandControls.swift (DestinationIcons) for the lab.

import SwiftUI
import AppKit
import FoveaCore

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

enum DestinationIcons {
    private static var cache: [String: NSImage?] = [:]

    static func image(for id: String) -> NSImage? {
        if let cached = cache[id] { return cached }
        let image = FoveaResources.url("Destinations/\(id).png").flatMap { NSImage(contentsOf: $0) }
        cache[id] = image
        return image
    }

    /// Marks that keep their official color; everything else is tinted white.
    static func keepsColor(_ id: String) -> Bool { id == "claude-code" || id == "claude" }
}
