import Foundation

// Presentation only: never derive approval or execution success from completion.
struct CompactEventPresentation {
    let title: String
    let summary: String
    let symbol: String
    let hint: String
    init(event: ReplayEvent, previous: [ReplayEvent]) {
        let kind = event.kind
        switch kind {
        case "rejected":
            title = "已拒绝执行"; summary = "此次执行请求已被拒绝。"; symbol = "xmark.circle"; hint = "展开查看请求记录"
        case "interrupted":
            title = "对话已中断"; summary = "本轮已中断，尚无最终回答。"; symbol = "stop.circle"; hint = "展开查看已有内容"
        case "approval":
            title = "等待批准"; summary = Self.clean(event.summary); symbol = "hand.raised"; hint = "展开查看待批准事项"
        case "input":
            title = "需要补充信息"; summary = Self.clean(event.summary); symbol = "questionmark.circle"; hint = "展开查看问题"
        case "failed":
            title = "处理失败"; summary = Self.clean(event.summary); symbol = "exclamationmark.circle"; hint = "展开查看原因"
        case "final" where previous.contains(where: { $0.kind == "rejected" }):
            title = "本轮已结束"; summary = "执行请求已被拒绝；本轮已回复。"; symbol = "xmark.circle"; hint = "展开查看完整回复"
        default:
            title = event.title
            summary = Self.clean(event.summary)
            symbol = kind == "final" ? "checkmark.circle" : "ellipsis.circle"
            hint = kind == "final" ? "展开查看完整结果" : "展开查看当前详情"
        }
    }
    static func clean(_ source: String) -> String {
        var value = source
        func replace(_ pattern: String, _ replacement: String) {
            value = value.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        replace("```[\\s\\S]*?```", "代码内容见详情")
        replace("!?\\[([^\\]]+)\\]\\([^\\n]*?\\)", "$1")
        replace("\\$\\$[\\s\\S]*?\\$\\$|\\\\\\[[\\s\\S]*?\\\\\\]", "公式见详情")
        replace("https?://[^\\s]+", "链接见详情")
        replace("(?:/Users/|/private/|/var/|/tmp/)[^\\s，。；]+", "文件路径见详情")
        replace("(?m)^\\s*(?:#{1,6}\\s+|[-*>]\\s+)", "")
        replace("[*`_]", "")
        replace("\\s+", " ")
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count > 90 {
            let prefix = String(value.prefix(90))
            if let end = prefix.lastIndex(where: { "。；！？".contains($0) }) { return String(prefix[...end]) }
            return String(prefix.prefix(86)) + "…"
        }
        return value.isEmpty ? "展开查看详情" : value
    }
}
