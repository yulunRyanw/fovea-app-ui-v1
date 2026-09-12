import SwiftUI
import FoveaCore

/// The Quick Answer summary card (Final B look, the product's wording): a status word
/// with the elapsed time, one line distilled from the agent's public progress or the
/// answer, and the expand hint. The chevron and the expand key send the same toggle.
struct QuickAnswerSummaryView: View {
    let model: IslandModel

    private typealias C = Tokens.Fovea.Panel

    var body: some View {
        let qa = model.state.quickAnswer
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: symbol(qa))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint(qa))
                Text(statusWord(qa))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(C.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                elapsed(qa)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(C.textSecondary)
                Button { model.send(.toggleQuickAnswerDensity) } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(C.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("展开当前会话 · 左 Control")
            }
            Text(summary(qa))
                .font(.system(size: 13.5))
                .foregroundStyle(C.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            // Who is answering (provider and model, plus returned tool calls while they run)
            // on the left; the keys on the right. No product name, no "expand to see" prose.
            HStack(spacing: 8) {
                ProviderMark(name: "codex-color", size: 12)
                Text(attribution(qa)).font(.system(size: 12)).foregroundStyle(C.textTertiary).lineLimit(1)
                Spacer(minLength: 8)
                FoveaKeyHint(keys: ["L⌃"], verb: "展开")
                FoveaKeyHint(keys: ["L⌃", "×2"], verb: "阅读")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Wording (mirrors QuickAnswerIslandCompactView in fovea-mac)

    private func symbol(_ qa: QuickAnswerState?) -> String {
        guard let qa else { return "ellipsis.circle" }
        if qa.error != nil { return "exclamationmark.circle" }
        if !qa.streaming { return "checkmark.circle" }
        if qa.toolsInFlight { return "gearshape.2" }
        return qa.answer.isEmpty ? "ellipsis.circle" : "text.bubble"
    }

    private func tint(_ qa: QuickAnswerState?) -> Color {
        guard let qa else { return C.textSecondary }
        return qa.error != nil ? C.failed : C.textPrimary
    }

    private func statusWord(_ qa: QuickAnswerState?) -> String {
        guard let qa else { return "问题已提交" }
        if qa.error != nil { return "回答中断" }
        if !qa.streaming { return "已完成" }
        if qa.toolsInFlight { return "正在调用工具…" }
        return qa.answer.isEmpty ? "问题已提交" : "正在回答…"
    }

    private func summary(_ qa: QuickAnswerState?) -> String {
        guard let qa else { return "等待回答方响应…" }
        if let error = qa.error { return error }
        let answer = qa.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty { return firstSentence(answer) }
        if let note = qa.note, !note.isEmpty { return note }
        // Nothing has come back yet: echo what was asked so the card is never a blank state line.
        let question = qa.question.trimmingCharacters(in: .whitespacesAndNewlines)
        return question.isEmpty ? "等待回答方响应…" : firstSentence(question)
    }

    private func firstSentence(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "[*_`#>|]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
        let first = cleaned.split(whereSeparator: { "。！？.!?".contains($0) }).first.map(String.init) ?? cleaned
        return first.count > 60 ? String(first.prefix(60)) + "…" : first
    }

    private func attribution(_ qa: QuickAnswerState?) -> String {
        let who = "Codex · \(RehearsalData.current.modelLabel)"
        guard let qa, qa.toolsReturned > 0 else { return who }
        return "\(who) · \(qa.toolsReturned) 次工具已返回"
    }

    @ViewBuilder
    private func elapsed(_ qa: QuickAnswerState?) -> some View {
        if let qa {
            if qa.streaming {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.clock(context.date.timeIntervalSince(qa.startedAt)))
                }
            } else {
                Text(Self.clock((qa.finishedAt ?? Date()).timeIntervalSince(qa.startedAt)))
            }
        }
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(C.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(C.field))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(C.hairline, lineWidth: 1))
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
