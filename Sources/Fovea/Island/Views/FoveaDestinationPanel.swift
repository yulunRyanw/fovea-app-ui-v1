import SwiftUI
import FoveaCore

/// The conversation picker, in the engine's language: it drops under the recording row
/// the way `ChatSelectorPanel` drops under the review row — one elevated panel (a step
/// off black, 12 pt radius, hairline), a caption header with the actions on the right,
/// the search field, flat rows with hover / selection fills (no bordered cards, no
/// brand colour on chrome), a caption footer. The content is the product's: Automatic,
/// a new Codex conversation, search and the availability filter, the machine's recent
/// conversations, the keyboard hint and the count.
struct FoveaDestinationPanel: View {
    let model: IslandModel

    private typealias C = Tokens.Island.Colors
    private typealias T = Tokens.Island.Type_
    private typealias L = Tokens.Island.Layout
    private var data: RehearsalData { RehearsalData.current }
    private var state: IslandState { model.state }

    /// Flat keyboard order: 0 automatic, then a new conversation per connected provider,
    /// then the visible rows.
    var choices: [QuickAnswerDestinationChoice] { Self.choices(query: state.destinationQuery, data: data) }

    static func choices(query: String, data: RehearsalData) -> [QuickAnswerDestinationChoice] {
        [.automatic] + data.providers.map { .newConversation(provider: $0) }
            + visible(query: query, data: data).map { .existing(id: $0.id, title: $0.title, provider: $0.provider) }
    }

    /// Index of the first conversation row in the keyboard order.
    static func gridStart(data: RehearsalData) -> Int { 1 + data.providers.count }
    private var gridStart: Int { Self.gridStart(data: data) }

    static func visible(query: String, data: RehearsalData) -> [RehearsalData.Conversation] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return data.conversations }
        return data.conversations.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        let visible = Self.visible(query: state.destinationQuery, data: data)
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            header
            searchField
            automaticRow
            if visible.isEmpty {
                Text("没有匹配的会话").font(T.body).foregroundStyle(C.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                grid(visible)
            }
            footer(visible)
        }
        .padding(L.selectorPanelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill + 3).fill(C.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill + 3).strokeBorder(C.hairline, lineWidth: 1))
        .padding(.horizontal, Tokens.Fovea.Island.horizontalPadding)
        .padding(.bottom, Tokens.Fovea.Island.horizontalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("选择会话")
    }

    // MARK: Header: caption on the left, actions on the right (SelectorHeader)

    /// Caption on the left; on the right a new conversation with each connected provider
    /// (Codex, Claude Code, Cursor… whichever is on and connected, in the product's order)
    /// and the availability filter. The engine's "Choose an AI" rows, folded into one line.
    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            Text("选择会话 · 最近").font(T.chip).foregroundStyle(C.textTertiary)
            Spacer(minLength: Tokens.Space.s)
            Text("新建").font(T.chip).foregroundStyle(C.textTertiary)
            ForEach(Array(data.providers.enumerated()), id: \.element) { offset, provider in
                newConversationButton(provider: provider, index: 1 + offset)
            }
            Rectangle().fill(C.hairline).frame(width: 1, height: 14).padding(.horizontal, Tokens.Space.xs)
            filterButton
        }
        .frame(height: L.selectorHeaderHeight)
        .padding(.horizontal, Tokens.Space.xs)
    }

    private func newConversationButton(provider: String, index: Int) -> some View {
        let highlighted = isHighlighted(index), committed = isCommitted(index)
        return HStack(spacing: Tokens.Space.xs) {
            ProviderMark(name: ProviderMark.assetName(for: provider), size: 14)
            Text(ProviderMark.displayName(for: provider))
            Image(systemName: committed ? "checkmark" : "plus").font(.system(size: 9, weight: .bold))
                .foregroundStyle(committed ? C.textPrimary : C.textTertiary)
        }
        .font(T.pill)
        .foregroundStyle(committed || highlighted ? C.textPrimary : C.textSecondary)
        .padding(.horizontal, Tokens.Space.s + 2)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill).fill(committed ? C.selection : (highlighted ? C.field : .clear)))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill).strokeBorder(C.focus, lineWidth: 1.5).opacity(highlighted ? 1 : 0))
        .contentShape(Rectangle())
        .onTapGesture { model.send(.commitDestination(.newConversation(provider: provider))) }
        .help("在 \(ProviderMark.displayName(for: provider)) 中新建对话")
        .accessibilityLabel("在 \(ProviderMark.displayName(for: provider)) 中新建对话")
    }

    private var filterButton: some View {
        HStack(spacing: Tokens.Space.xs) {
            Text("可继续提问")
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(C.textTertiary)
        }
        .font(T.pill)
        .foregroundStyle(C.textSecondary)
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: 24)
        .help("只看能在这里继续提问的会话；可切到全部会话")
    }

    // MARK: Search (the engine's SearchField, showing the typed filter)

    private var searchField: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundStyle(C.textSecondary)
            Text(state.destinationQuery.isEmpty ? "搜索会话" : state.destinationQuery)
                .font(T.body)
                .foregroundStyle(state.destinationQuery.isEmpty ? C.textTertiary : C.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !state.destinationQuery.isEmpty {
                Image(systemName: "xmark.circle.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(C.textSecondary)
                    .onTapGesture { model.send(.destinationSearch("")) }
            }
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: L.selectorSearchFieldHeight)
        .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.field).fill(C.field))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.field).strokeBorder(C.hairline, lineWidth: 1))
    }

    // MARK: Rows

    private var automaticRow: some View {
        row(index: 0, height: L.selectorRowHeight) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "wand.and.stars").font(.system(size: 12, weight: .medium)).foregroundStyle(C.textSecondary)
                Text("自动").font(T.body).foregroundStyle(C.textPrimary)
                Text("按问题内容决定去哪个会话").font(T.secondary).foregroundStyle(C.textTertiary).lineLimit(1)
                Spacer(minLength: Tokens.Space.s)
                checkmark(isCommitted(0))
            }
        }
        .onTapGesture { model.send(.commitDestination(.automatic)) }
    }

    private func grid(_ visible: [RehearsalData.Conversation]) -> some View {
        let rows = (visible.count + 2) / 3
        let listHeight = CGFloat(rows) * L.selectorResultRowHeight + CGFloat(max(0, rows - 1)) * L.selectorGridSpacing
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: L.selectorGridSpacing), count: 3),
                          spacing: L.selectorGridSpacing) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { offset, conversation in
                        conversationRow(conversation, index: offset + gridStart).id(conversation.id)
                    }
                }
            }
            .scrollIndicators(.automatic)
            .onChange(of: state.destinationHighlight) { _, highlight in
                let i = highlight - gridStart
                if i >= 0, i < visible.count { proxy.scrollTo(visible[i].id) }
            }
        }
        .frame(height: min(listHeight, Self.listViewportMax))
    }

    /// Rows the island can show before the list scrolls: the expansion cap (460) less the
    /// recording row and this panel's own chrome.
    private static let listViewportMax: CGFloat = {
        let expansionCap: CGFloat = 460
        let recordingRow: CGFloat = 36
        let chrome: CGFloat = 24 + 28 + 30 + 20   // header, search, automatic, footer
        let gaps: CGFloat = 8 * 4                 // spacing between the five blocks
        let paddings: CGFloat = 16 + 12           // panel padding, bottom margin
        return expansionCap - recordingRow - chrome - gaps - paddings
    }()

    private func conversationRow(_ c: RehearsalData.Conversation, index: Int) -> some View {
        let committed = isCommitted(index)
        return row(index: index, height: L.selectorResultRowHeight) {
            HStack(spacing: Tokens.Space.s) {
                ProviderMark(name: ProviderMark.assetName(for: c.provider), size: 16)
                conversationLabel(c)
                Spacer(minLength: Tokens.Space.s)
                checkmark(committed)
            }
        }
        .onTapGesture { model.send(.commitDestination(.existing(id: c.id, title: c.title, provider: c.provider))) }
        .help(c.workspace.isEmpty ? c.title : "\(c.title) · \(c.workspace)")
    }

    private func conversationLabel(_ c: RehearsalData.Conversation) -> some View {
        let subtitle = Text(c.availabilityLabel).foregroundStyle(c.resumable ? C.textSecondary : C.textTertiary)
            + Text(" · \(c.relativeTime)").foregroundStyle(C.textTertiary)
        return VStack(alignment: .leading, spacing: 1) {
            Text(c.title).font(T.body).foregroundStyle(C.textPrimary).lineLimit(1)
            subtitle.font(T.secondary).lineLimit(1)
        }
    }

    @ViewBuilder
    private func checkmark(_ shown: Bool) -> some View {
        if shown {
            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(C.textPrimary)
        }
    }

    /// The engine's SelectorRow: flat, `selection` when chosen, `hover` under the pointer,
    /// the focus ring for the keyboard highlight.
    private func row<Content: View>(index: Int, height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        let highlighted = isHighlighted(index), committed = isCommitted(index)
        return content()
            .padding(.horizontal, Tokens.Space.m)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.row)
                .fill(committed ? C.selection : (highlighted ? C.hover : .clear)))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.row)
                .strokeBorder(C.focus, lineWidth: 1.5).opacity(highlighted ? 1 : 0))
            .contentShape(Rectangle())
    }

    private func footer(_ visible: [RehearsalData.Conversation]) -> some View {
        HStack(spacing: Tokens.Space.s) {
            Text("↑ ↓ ← → 移动 · 回车选择 · esc 关闭").font(T.chip).foregroundStyle(C.textTertiary)
            Spacer(minLength: Tokens.Space.s)
            Text("\(visible.count) / \(data.conversations.count)").font(T.chip).foregroundStyle(C.textTertiary)
        }
        .frame(height: 20)
        .padding(.horizontal, Tokens.Space.xs)
    }

    private func isHighlighted(_ index: Int) -> Bool { state.destinationHighlight == index }

    private func isCommitted(_ index: Int) -> Bool {
        switch state.destination {
        case .automatic: return index == 0
        case .newConversation(let provider):
            return index >= 1 && index < gridStart && data.providers[index - 1] == provider
        case .existing(let id, _, _):
            let visible = Self.visible(query: state.destinationQuery, data: data)
            let i = index - gridStart
            return i >= 0 && i < visible.count && visible[i].id == id
        }
    }
}
