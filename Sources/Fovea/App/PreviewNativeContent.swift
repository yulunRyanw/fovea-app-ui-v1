import Foundation

/// Adapt only known native record metadata; raw History stays available unchanged.
enum PreviewNativeContent {
    static func answer(_ raw: String) -> String {
        guard let start = raw.range(of: "\n<oai-mem-citation>"),
              raw.hasSuffix("</oai-mem-citation>"),
              raw[start.lowerBound...].contains("<citation_entries>"),
              raw[start.lowerBound...].contains("<rollout_ids>"),
              raw[..<start.lowerBound].components(separatedBy:"```").count % 2 == 1 else { return raw }
        return String(raw[..<start.lowerBound]).trimmingCharacters(in:.newlines)
    }
    static func question(_ raw: String, item: HistoryPreviewCase?) -> String {
        var text = raw
        for material in item?.materials ?? [] {
            guard let path = material.storedImageName, material.kind == "image" else { continue }
            let pattern = #"(?m)^<image name=\[Image #[0-9]+\] path=\""# + NSRegularExpression.escapedPattern(for:path) + #"\">\s*</image>\s*$"#
            text = text.replacingOccurrences(of:pattern,with:"",options:.regularExpression)
        }
        return QuickAnswerQuestionPresentation.visibleQuestion(text).trimmingCharacters(in:.newlines)
    }
}
