import SwiftUI
import FoveaCore

/// The product's Quick Answer conversation panel, replicated for the rehearsal from
/// `QuickAnswerIslandVisualView` / `QuickAnswerIslandTurnView` in fovea-mac: identity
/// strip, pinned question, materials chips, attribution, body, progress row, action row,
/// grabber. Content comes from `RehearsalData` (real history) and the live answer stream.
/// Three hosts: attached under the notch (560, content ≤ 420), reading (as wide and tall
/// as the display allows, body ≤ 720 centred), detached (the floating card).
struct FoveaConversationPanel: View {
    enum Host: Equatable {
        case attached
        case reading(contentHeight: CGFloat)
        case detached
    }

    let model: IslandModel
    let host: Host

    private typealias C = Tokens.Fovea.Panel
    private var data: RehearsalData { RehearsalData.current }
    private var qa: QuickAnswerState? { model.state.quickAnswer }

    var body: some View {
        VStack(spacing: 0) {
            identityStrip
            hairline
            pinnedQuestion
            hairline
            turns
            hairline
            actionRow
            if host == .attached { grabber }
        }
        .frame(height: panelHeight)
        .environment(\.colorScheme, .dark)
    }

    private var isReading: Bool { if case .reading = host { return true }; return false }
    /// Reading density spreads out: wider side margins and every row aligned to them.
    private var sidePadding: CGFloat { isReading ? C.readingSidePadding : C.horizontalPadding }
    private var bodyFontSize: CGFloat { isReading ? 15 : 13.5 }
    private var bodyLineSpacing: CGFloat { isReading ? 7 : 4 }
    private var questionFontSize: CGFloat { isReading ? 16 : 14 }
    private var secondaryFontSize: CGFloat { isReading ? 12.5 : 11.5 }

    private var panelHeight: CGFloat? {
        switch host {
        case .attached: return C.slabMaxContent
        case .reading(let contentHeight): return contentHeight
        case .detached: return 360
        }
    }

    private var hairline: some View { Rectangle().fill(C.hairline).frame(height: 1) }

    // MARK: Identity strip

    /// Identity strip, one line at every width: the mark and the title on the left, the
    /// title taking whatever the width leaves; the model and permission pills and the close
    /// control on the right (the engine's header grammar: label left, actions right). Narrow
    /// hosts show the model's name alone; the reading density shows its full label and the
    /// conversation status.
    private var identityStrip: some View {
        HStack(spacing: 8) {
            ProviderMark(name: "codex-color", size: 16)
            Text(data.title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(C.textPrimary)
                .lineLimit(1).truncationMode(.tail)
                .layoutPriority(-1)
            if isReading {
                Text("· 已有对话").font(.system(size: 11.5)).foregroundStyle(C.textTertiary).lineLimit(1).fixedSize()
            }
            Spacer(minLength: 8)
            pill { ProviderMark(name: "codex-color", size: 12); Text(isReading ? data.modelLabel : data.modelName).lineLimit(1).fixedSize(); chevron }
            pill { Image(systemName: "checkmark.shield").font(.system(size: 11, weight: .semibold)); Text("Approve for me").lineLimit(1).fixedSize(); chevron }
            iconControl("xmark", size: 10) { model.send(.closeQuickAnswer) }
        }
        .padding(.horizontal, sidePadding)
        .frame(height: 40)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(C.textTertiary)
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 5) { content() }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(C.textSecondary)
            .padding(.horizontal, 10).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 9).fill(C.field))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(C.hairline, lineWidth: 1))
    }

    private func iconControl(_ symbol: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold))
                .foregroundStyle(C.textSecondary).frame(width: 24, height: 24).contentShape(Circle())
        }.buttonStyle(.plain)
    }

    // MARK: Pinned question

    private var pinnedQuestion: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.spokenQuestion(qa?.question ?? data.question))
                .font(.system(size: questionFontSize, weight: .semibold))
                .foregroundStyle(C.textPrimary)
                .lineLimit(isReading ? 5 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
            iconControl("pencil") {}
        }
        .padding(.horizontal, sidePadding)
        .padding(.vertical, isReading ? 14 : 10)
        // Hug the text: the line limit already caps the height, and a maxHeight frame
        // would stretch the block and centre the question in empty space.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Turns

    private var turns: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: isReading ? 14 : 10) {
                    chipsRow
                    attributionRow
                    bodyText
                    progressRow
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, sidePadding)
                .padding(.vertical, isReading ? 18 : 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: qa?.answer.count ?? 0) { _, _ in
                if qa?.streaming == true { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var chipsRow: some View {
        let chips = data.chips
        let shown = Array(chips.prefix(C.chipsPerRow))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("附件").font(.system(size: 10, weight: .semibold)).foregroundStyle(C.textTertiary)
                Text("\(chips.count)").font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(C.textSecondary).padding(.horizontal, 5).frame(height: 16)
                    .background(RoundedRectangle(cornerRadius: 4).fill(C.field))
            }
            HStack(spacing: 6) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, chip in chipView(chip) }
                if chips.count > shown.count {
                    Text("+\(chips.count - shown.count)")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(C.textSecondary)
                        .frame(width: 40, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(C.field))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func chipView(_ chip: RehearsalData.Chip) -> some View {
        HStack(spacing: 6) {
            if let image = chip.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: C.chipThumb.width, height: C.chipThumb.height)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "text.quote").font(.system(size: 11, weight: .semibold)).foregroundStyle(C.textSecondary)
                    .frame(width: C.chipThumb.width, height: C.chipThumb.height)
                    .background(RoundedRectangle(cornerRadius: 4).fill(C.card))
            }
            Text(chip.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(C.textSecondary).lineLimit(1)
        }
        .padding(.leading, 3).padding(.trailing, 10).frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 7).fill(C.field))
        .frame(maxWidth: 210)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Which model answers: the production model picker opens from here.
    private var attributionRow: some View {
        HStack(spacing: 6) {
            ProviderMark(name: "codex-color", size: 14)
            Text("使用 \(data.modelLabel)").font(.system(size: secondaryFontSize)).foregroundStyle(C.textTertiary)
        }
    }

    @ViewBuilder
    private var bodyText: some View {
        if let qa {
            if qa.answer.isEmpty, qa.streaming {
                Text("回答中…").font(.system(size: bodyFontSize)).foregroundStyle(C.textTertiary)
            } else {
                // The product's renderer: tables, code blocks, formulas, the dark palette.
                FoveaAnswerContentView(messageID: "rehearsal-turn", markdown: qa.answer, streaming: qa.streaming,
                                       fontSize: bodyFontSize, foreground: "#F2F2F2")
            }
        }
    }

    private var progressRow: some View {
        HStack(spacing: 6) {
            if let qa {
                Image(systemName: qa.streaming ? "circle.dotted" : "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(C.textSecondary)
                Text(qa.streaming ? (qa.toolsInFlight ? "正在调用工具…" : "正在回答…") : "已完成")
                    .font(.system(size: secondaryFontSize, weight: .medium)).foregroundStyle(C.textSecondary)
                elapsedText(qa).font(.system(size: secondaryFontSize).monospacedDigit()).foregroundStyle(C.textTertiary)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("查看过程").font(.system(size: secondaryFontSize, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(C.textSecondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func elapsedText(_ qa: QuickAnswerState) -> some View {
        if qa.streaming {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("· \(Int(context.date.timeIntervalSince(qa.startedAt))) 秒")
            }
        } else {
            Text("· \(Int((qa.finishedAt ?? Date()).timeIntervalSince(qa.startedAt))) 秒")
        }
    }

    // MARK: Action row

    private var actionRow: some View {
        HStack(spacing: 6) {
            iconControl("arrow.down.circle") {}
            // Shortcut hints the way macOS writes them: key cap, then the verb.
            if host == .attached {
                FoveaKeyHint(keys: ["L⌃"], verb: "收起").padding(.leading, 4)
                FoveaKeyHint(keys: ["L⌃", "×2"], verb: "阅读").padding(.leading, 6)
            } else if isReading {
                FoveaKeyHint(keys: ["L⌃"], verb: "完整").padding(.leading, 4)
                FoveaKeyHint(keys: ["L⌃", "×2"], verb: "摘要").padding(.leading, 6)
                FoveaKeyHint(keys: ["esc"], verb: "完整").padding(.leading, 6)
            }
            Spacer(minLength: 0)
            if qa?.streaming == true {
                pillButton("停止回答", symbol: "stop.fill", prominent: true)
            } else {
                pillButton("复制回答", symbol: "doc.on.doc")
                pillButton("用当前模型重新回答", symbol: "arrow.clockwise")
                HStack(spacing: 5) { ProviderMark(name: "codex-color", size: 12); Text("在 Codex 中继续") }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(C.textPrimary)
                    .padding(.horizontal, 10).frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 9).fill(C.field))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(C.hairline, lineWidth: 1))
            }
        }
        .padding(.horizontal, sidePadding)
        .frame(height: 44)
    }

    private func pillButton(_ title: String, symbol: String, prominent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            Text(title).lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(prominent ? C.textPrimary : C.textSecondary)
        .padding(.horizontal, 10).frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 9).fill(prominent ? C.field : .clear))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(prominent ? C.hairline : .clear, lineWidth: 1))
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium)).foregroundStyle(C.textSecondary)
            .padding(.horizontal, 8).frame(height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(C.field))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(C.hairline, lineWidth: 1))
    }

    private var grabber: some View {
        Capsule().fill(C.textTertiary)
            .frame(width: 36, height: 5)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 6).onChanged { _ in model.send(.detach) })
    }

    // MARK: Markdown (inline only; the product uses its own renderer)

    /// The pinned question shows what the user said. The real transcript also carries the
    /// captured-material block (`<context …>…</context>`) that goes to the provider; the
    /// production panel does not show it either.
    static func spokenQuestion(_ text: String) -> String {
        var cut = text
        for marker in ["\\<context", "<context"] {
            if let range = cut.range(of: marker) { cut = String(cut[..<range.lowerBound]) }
        }
        return cut.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
