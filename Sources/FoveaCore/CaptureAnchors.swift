import Foundation

/// Search anchors for a capture that only carries a transcript: proper nouns, identifiers
/// with dots or underscores, and long words, in order. The Island fills
/// `Capture.semanticAnchors` with these on Send; `CaptureSearch` indexes them.
public enum CaptureAnchors {
    public static func extract(from transcript: String) -> [String] {
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
