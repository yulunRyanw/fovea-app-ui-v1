import Foundation
import CoreGraphics

/// Packs items with known aspect ratios into justified rows, in reading order.
public enum JustifiedRows {
    public struct Item: Hashable, Sendable {
        public let id: String
        /// width / height
        public let aspect: CGFloat
        public init(id: String, aspect: CGFloat) { self.id = id; self.aspect = aspect }
    }

    public struct Placed: Hashable, Sendable {
        public let id: String
        public let width: CGFloat
    }

    public struct Row: Hashable, Sendable {
        public let items: [Placed]
        public let height: CGFloat
        public let justified: Bool
    }

    /// `fixedPerRow` forces exactly that many items on every full row (the last row may be
    /// shorter); otherwise rows pack toward `targetHeight` with at most `maxPerRow` items.
    public static func layout(_ items: [Item], width: CGFloat, targetHeight: CGFloat,
                              spacing: CGFloat, maxPerRow: Int,
                              heightRange: ClosedRange<CGFloat>? = nil,
                              fixedPerRow: Int? = nil) -> [Row] {
        guard width > 0, !items.isEmpty else { return [] }
        if let n = fixedPerRow, n > 0 {
            return fixedLayout(items, width: width, targetHeight: targetHeight, spacing: spacing, perRow: n)
        }
        let range = heightRange ?? (targetHeight * 0.8)...(targetHeight * 1.35)
        let cap = max(1, maxPerRow)
        var rows: [Row] = []
        var pending: [Item] = []

        func flush(justify: Bool) {
            guard !pending.isEmpty else { return }
            let gaps = spacing * CGFloat(pending.count - 1)
            let aspectSum = pending.reduce(CGFloat(0)) { $0 + $1.aspect }
            var height = (width - gaps) / aspectSum
            if justify {
                height = min(max(height, range.lowerBound), range.upperBound)
            } else {
                // Last row: keep the target height unless it would overflow.
                height = min(targetHeight, (width - gaps) / aspectSum)
            }
            // When clamped, widths are scaled so the row still fills exactly.
            let natural = pending.map { $0.aspect * height }
            let naturalSum = natural.reduce(0, +)
            let scale = justify ? (width - gaps) / naturalSum : 1
            let placed = zip(pending, natural).map { Placed(id: $0.id, width: $1 * scale) }
            rows.append(Row(items: placed, height: height, justified: justify))
            pending.removeAll()
        }

        func height(_ items: [Item]) -> CGFloat {
            let gaps = spacing * CGFloat(items.count - 1)
            return (width - gaps) / items.reduce(CGFloat(0)) { $0 + $1.aspect }
        }

        for item in items {
            let without = pending
            pending.append(item)
            let with = height(pending)
            if with <= targetHeight {
                // Adding this item fills the row. Keep it only if that lands closer to the
                // target height than stopping before it; otherwise start the next row with it.
                // Bias toward the fuller row: a slightly short row beats an orphaned item.
                if without.count >= 1, abs(height(without) - targetHeight) < abs(with - targetHeight) * 0.5,
                   height(without) <= range.upperBound {
                    pending = without
                    flush(justify: true)
                    pending = [item]
                    if height(pending) <= targetHeight { flush(justify: true) }
                } else {
                    flush(justify: true)
                }
            } else if pending.count == cap {
                flush(justify: true)
            }
        }
        flush(justify: false)
        return rows
    }

    /// Chunks in reading order. Full rows fill the width exactly (heights kept within a wide
    /// band of the target so extreme aspects stay usable); a short last row keeps natural widths.
    static func fixedLayout(_ items: [Item], width: CGFloat, targetHeight: CGFloat,
                            spacing: CGFloat, perRow n: Int) -> [Row] {
        var rows: [Row] = []
        var index = 0
        while index < items.count {
            let chunk = Array(items[index..<min(index + n, items.count)])
            index += n
            let gaps = spacing * CGFloat(chunk.count - 1)
            let aspectSum = chunk.reduce(CGFloat(0)) { $0 + $1.aspect }
            let natural = (width - gaps) / aspectSum
            if chunk.count == n {
                let height = min(max(natural, targetHeight * 0.6), targetHeight * 1.25)
                let widths = chunk.map { $0.aspect * height }
                let scale = (width - gaps) / widths.reduce(0, +)
                rows.append(Row(items: zip(chunk, widths).map { Placed(id: $0.id, width: $1 * scale) },
                                height: height, justified: true))
            } else {
                // Match the previous row's height so a trailing row reads as part of the grid.
                let height = rows.last?.height ?? min(natural, targetHeight * 1.2)
                let widths = chunk.map { $0.aspect * height }
                let total = widths.reduce(0, +) + gaps
                let scale = total > width ? (width - gaps) / widths.reduce(0, +) : 1
                rows.append(Row(items: zip(chunk, widths).map { Placed(id: $0.id, width: $1 * scale) },
                                height: height, justified: false))
            }
        }
        return rows
    }
}
