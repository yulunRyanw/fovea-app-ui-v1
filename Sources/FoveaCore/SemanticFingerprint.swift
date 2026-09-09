import Foundation
import CoreGraphics

/// Deterministic typographic composition for a voice-only capture.
/// Same capture id → same composition, with no model call.
public struct SemanticFingerprint: Hashable, Sendable {
    /// How loudly one word is set. A card always has a `lead`; longer cards also get
    /// an `echo` so emphasis isn't stuck on a single word in a fixed position.
    public enum Emphasis: Int, Hashable, Sendable, Codable {
        /// The loudest word — takes the theme's `ink`.
        case lead = 0
        /// The second highlight — takes the theme's `pop`, one step quieter.
        case echo = 1
        /// Everything else — takes the theme's `sub`.
        case quiet = 2
    }

    public struct Anchor: Hashable, Sendable {
        public let text: String
        public let emphasis: Emphasis
        /// Point size within 15…27.
        public let size: CGFloat
        /// 0 = regular, 1 = medium, 2 = semibold.
        public let weight: Int
        /// Leading indent in points, 0…14.
        public let indent: CGFloat

        /// Either highlight colour, as opposed to the quiet reading text.
        public var isPrimary: Bool { emphasis != .quiet }
    }

    public let anchors: [Anchor]
    /// Nominal width / height used by the feed layout.
    public let aspect: CGFloat
    /// Vertical gap between anchors, points.
    public let lineSpacing: CGFloat

    public static let minSize: CGFloat = 15
    public static let maxSize: CGFloat = 27

    public static func make(captureId: String, anchors rawAnchors: [String], transcript: String? = nil) -> SemanticFingerprint {
        var words = rawAnchors.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if words.isEmpty, let transcript { words = extractAnchors(from: transcript) }
        if words.isEmpty { words = ["capture"] }
        words = Array(words.prefix(5))

        var rng = SplitMix64(seed: FNV1a.hash(captureId))

        // Secondary sizes and indents vary by seed.
        let primarySize = CGFloat(22 + Int(rng.next(upperBound: 6)))            // 22…27
        let secondaryBase = CGFloat(15 + Int(rng.next(upperBound: 3)))          // 15…17
        let lineSpacing = CGFloat(2 + Int(rng.next(upperBound: 3)))             // 2…4
        let indentStyle = Int(rng.next(upperBound: 3))                          // 0 flush, 1 stepped, 2 hanging

        // Which words are highlighted is drawn from its own stream, so changing this
        // rule never reshuffles the sizes, spacing or aspect drawn above — those feed
        // the row-packing layout and its tests.
        let emphasis = emphasisPlan(count: words.count,
                                    rng: SplitMix64(seed: FNV1a.hash(captureId + "#emphasis")))

        var anchors: [Anchor] = []
        for (i, word) in words.enumerated() {
            let e = emphasis[i]
            let jitter = CGFloat(Int(rng.next(upperBound: 3))) - 1                // -1…1
            let size: CGFloat
            let weight: Int
            switch e {
            case .lead:
                size = primarySize; weight = 2
            case .echo:
                // A step down from the lead but still inside the primary band, so the
                // two highlights read as a hierarchy rather than a tie.
                size = max(22, primarySize - 3); weight = 1
            case .quiet:
                size = max(minSize, min(19, secondaryBase + jitter)); weight = rng.next(upperBound: 4) == 0 ? 1 : 0
            }
            let indent: CGFloat
            switch indentStyle {
            case 1: indent = e == .quiet ? CGFloat(min(14, 7 * i)) : 0
            case 2: indent = e == .quiet ? 10 : 0
            default: indent = 0
            }
            anchors.append(Anchor(text: word, emphasis: e, size: size, weight: weight, indent: indent))
        }

        // Nominal tile shape varies by seed within 1.05…1.35 so rows pack like the reference;
        // the words are laid out inside whatever frame the row gives them.
        let aspect = 1.05 + CGFloat(rng.next(upperBound: 31)) / 100
        return SemanticFingerprint(anchors: anchors, aspect: aspect, lineSpacing: lineSpacing)
    }

    /// Which faces this card sets its words in.
    ///
    /// Its own seed stream again (`#font`), so narrowing the enabled set in Settings
    /// reshuffles faces without disturbing the composition, the emphasis plan or the
    /// colors. Highlighted words take a display face; quiet words take a text face,
    /// which is the shared spine that keeps a row of mixed display faces legible.
    public static func fontPick(captureId: String,
                                display: [FeedFont],
                                text: [FeedFont]) -> (display: FeedFont?, text: FeedFont?) {
        guard !display.isEmpty || !text.isEmpty else { return (nil, nil) }
        var rng = SplitMix64(seed: FNV1a.hash(captureId + "#font"))
        let d = display.isEmpty ? nil : display[Int(rng.next(upperBound: UInt64(display.count)))]
        let t = text.isEmpty ? d : text[Int(rng.next(upperBound: UInt64(text.count)))]
        return (d ?? t, t)
    }

    /// Which palette members this card's two highlights use.
    ///
    /// Its own stream again, so changing color assignment never disturbs the
    /// composition or the emphasis plan. The echo never repeats the lead, and the
    /// lead is drawn flat across the whole palette, so a feed of a few dozen cards
    /// shows all four colors rather than favouring one.
    public static func colorPick(captureId: String, count: Int) -> (lead: Int, echo: Int) {
        guard count > 1 else { return (0, 0) }
        var rng = SplitMix64(seed: FNV1a.hash(captureId + "#color"))
        let lead = Int(rng.next(upperBound: UInt64(count)))
        let echo = (lead + 1 + Int(rng.next(upperBound: UInt64(count - 1)))) % count
        return (lead, echo)
    }

    /// Picks which words carry emphasis.
    ///
    /// The lead is drawn from the first three words rather than pinned to the first —
    /// always highlighting word one made every card open the same way. A second
    /// highlight (`echo`) appears only on cards with four or more words, and never
    /// adjacent to the lead, so the two colours read as a composition instead of a
    /// run. Fully deterministic: same id, same plan.
    static func emphasisPlan(count: Int, rng: SplitMix64) -> [Emphasis] {
        guard count > 0 else { return [] }
        var rng = rng
        var plan = [Emphasis](repeating: .quiet, count: count)

        let leadWindow = min(3, count)
        let lead = Int(rng.next(upperBound: UInt64(leadWindow)))
        plan[lead] = .lead

        // Two highlights need room: at least four words, and a gap of two so the
        // pair never touches.
        if count >= 4 {
            let candidates = (0..<count).filter { abs($0 - lead) >= 2 }
            if !candidates.isEmpty {
                plan[candidates[Int(rng.next(upperBound: UInt64(candidates.count)))]] = .echo
            }
        }
        return plan
    }

    /// Heuristic anchor extraction for fixtures that only carry a transcript:
    /// proper nouns, identifiers with dots/underscores, and long words, in order.
    public static func extractAnchors(from transcript: String) -> [String] {
        let stop: Set<String> = ["the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "with",
                                 "this", "that", "these", "those", "it", "is", "be", "make", "please",
                                 "under", "more", "into", "from", "at", "by", "as", "so", "then", "them",
                                 "just", "also", "can", "we", "i", "you", "my", "our"]
        let punctuation = CharacterSet(charactersIn: ".,;:!?\"“”()")
        let tokens = transcript.split(separator: " ")
            .map { $0.trimmingCharacters(in: punctuation) }
            .filter { !$0.isEmpty }
        var out: [String] = []
        for t in tokens where !stop.contains(t.lowercased()) {
            let isIdentifier = t.contains(".") || t.contains("_") || t.contains("/")
            let isProper = t.first?.isUppercase == true
            if isIdentifier || isProper || t.count >= 5 {
                if !out.contains(where: { $0.lowercased() == t.lowercased() }) { out.append(t) }
            }
            if out.count == 5 { break }
        }
        return out
    }
}

// MARK: - Seeded randomness

public enum FNV1a {
    public static func hash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return h
    }
}

public struct SplitMix64 {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    public mutating func next(upperBound: UInt64) -> UInt64 { next() % upperBound }
}
