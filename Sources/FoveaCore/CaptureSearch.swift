import Foundation

public enum CaptureSearch {
    /// Case- and diacritic-insensitive match over transcript, anchors, filenames,
    /// preview text, app names and Quick Answer content. Empty query returns everything.
    public static func filter(_ captures: [Capture], query: String) -> [Capture] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return captures }
        let terms = q.split(separator: " ").map(String.init)
        return captures.filter { capture in
            let haystack = searchableText(capture)
            return terms.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    public static func searchableText(_ c: Capture) -> String {
        var parts: [String] = []
        if let t = c.transcript { parts.append(t) }
        parts.append(contentsOf: c.semanticAnchors)
        if let q = c.question { parts.append(q) }
        if let a = c.answer { parts.append(a) }
        if let s = c.sourceApp { parts.append(s.name) }
        if let d = c.destinationApp { parts.append(d.name) }
        for r in c.referents {
            if let f = r.filename { parts.append(f) }
            if let t = r.title { parts.append(t) }
            if let x = r.text { parts.append(x) }
            if let a = r.sourceApp { parts.append(a) }
            if let w = r.sourceWindowTitle { parts.append(w) }
            parts.append(r.kind.rawValue)
        }
        return parts.joined(separator: "\n")
    }
}
