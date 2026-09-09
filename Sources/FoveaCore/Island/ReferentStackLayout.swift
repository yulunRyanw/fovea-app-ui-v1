import Foundation
import CoreGraphics

/// Placement math for the referent stack in Transcript review. Collapsed: the first
/// referent in front with the rest peeking out behind it. Expanded: every referent in
/// rows that wrap when one is full. Pure so the sizes can be tested and never jump.
public enum ReferentStackLayout {
    public struct Placement: Hashable, Sendable {
        public let index: Int
        /// Offset of the thumbnail's leading/top edge from the stack origin.
        public let offset: CGSize
        public let scale: CGFloat
        public let opacity: Double
        /// Higher draws on top.
        public let z: Double
    }

    public struct Config: Hashable, Sendable {
        public var thumb: CGSize
        public var spacing: CGFloat
        /// Vertical gap between wrapped rows.
        public var rowSpacing: CGFloat
        /// How far each background layer peeks out when collapsed.
        public var layerOffset: CGFloat
        public var maxLayers: Int

        public init(thumb: CGSize, spacing: CGFloat, layerOffset: CGFloat, maxLayers: Int = 3,
                    rowSpacing: CGFloat? = nil) {
            self.thumb = thumb; self.spacing = spacing; self.layerOffset = layerOffset
            self.maxLayers = maxLayers; self.rowSpacing = rowSpacing ?? spacing
        }
    }

    /// Front thumbnail at the origin; each layer behind shifts right and shrinks slightly.
    public static func collapsed(count: Int, config: Config) -> [Placement] {
        let layers = min(count, config.maxLayers)
        var out: [Placement] = []
        for i in 0..<layers {
            let shift: CGFloat = CGFloat(i) * config.layerOffset
            let scale: CGFloat = 1 - CGFloat(i) * 0.04
            let fade: Double = 0.85 - Double(i) * 0.2
            let opacity: Double = i == 0 ? 1 : max(0.35, fade)
            out.append(Placement(index: i, offset: CGSize(width: shift, height: 0),
                                 scale: scale, opacity: opacity, z: Double(layers - i)))
        }
        return out
    }

    public static func collapsedWidth(count: Int, config: Config) -> CGFloat {
        guard count > 0 else { return 0 }
        let layers = min(count, config.maxLayers)
        return config.thumb.width + CGFloat(layers - 1) * config.layerOffset
    }

    /// How many thumbnails fit in one row of `availableWidth`; at least one.
    public static func perRow(availableWidth: CGFloat, config: Config) -> Int {
        let pitch = config.thumb.width + config.spacing
        return max(1, Int(((availableWidth + config.spacing) / pitch).rounded(.down)))
    }

    /// Every referent, left to right, wrapping onto a new row when one is full.
    public static func wrapped(count: Int, availableWidth: CGFloat, config: Config) -> (placements: [Placement], size: CGSize) {
        guard count > 0 else { return ([], .zero) }
        let columns = perRow(availableWidth: availableWidth, config: config)
        let placements = (0..<count).map { i in
            let column = i % columns
            let row = i / columns
            return Placement(index: i,
                             offset: CGSize(width: CGFloat(column) * (config.thumb.width + config.spacing),
                                            height: CGFloat(row) * (config.thumb.height + config.rowSpacing)),
                             scale: 1, opacity: 1, z: 1)
        }
        let rows = (count + columns - 1) / columns
        let used = min(count, columns)
        let size = CGSize(width: CGFloat(used) * config.thumb.width + CGFloat(used - 1) * config.spacing,
                          height: CGFloat(rows) * config.thumb.height + CGFloat(rows - 1) * config.rowSpacing)
        return (placements, size)
    }

    /// Leading edge for a preview card under thumbnail `index`: aligned with the thumbnail
    /// and kept inside `contentWidth`.
    public static func previewLeading(index: Int, count: Int, availableWidth: CGFloat,
                                      previewWidth: CGFloat, contentWidth: CGFloat, config: Config) -> CGFloat {
        let layout = wrapped(count: count, availableWidth: availableWidth, config: config)
        guard index >= 0, index < layout.placements.count else { return 0 }
        let leading = layout.placements[index].offset.width
        return max(0, min(leading, contentWidth - previewWidth))
    }
}
