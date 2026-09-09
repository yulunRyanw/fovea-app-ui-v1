import SwiftUI
import FoveaCore

/// The panel under the review row. Five steps, each a crossfade of one shared frame:
/// recent Chats, New Chat → AI → folder, Search Chats → AI → query. Choosing returns to
/// the recent step so the pick can be double-checked before Send.
struct ChatSelectorPanel: View {
    let model: IslandModel

    private var draft: ReviewDraft? { model.state.review }

    var body: some View {
        if let draft, let menu = draft.routes.menu {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                step(draft, menu)
            }
            .id(stepKey(draft.selector))
            .transition(.opacity)
            .padding(Tokens.Island.Layout.selectorPanelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill + 3).fill(Tokens.Island.Colors.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill + 3).strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Chat choices")
        }
    }

    @ViewBuilder
    private func step(_ draft: ReviewDraft, _ menu: ChatRouteMenu) -> some View {
        switch draft.selector {
        case .closed:
            EmptyView()
        case .recent:
            recentStep(draft, menu)
        case .newChatAI:
            aiStep(title: "New Chat", choices: menu.destinations, showRecommended: true)
        case .newChatContext(let app):
            contextStep(app: app, draft: draft)
        case .searchAI:
            aiStep(title: "Search Chats", choices: menu.destinations, showRecommended: false)
        case .searchQuery(let app):
            searchStep(app: app, draft: draft)
        }
    }

    // MARK: S0 recent

    @ViewBuilder
    private func recentStep(_ draft: ReviewDraft, _ menu: ChatRouteMenu) -> some View {
        SelectorHeader {
            Text("Recent · Last 24 hours").font(Tokens.Island.Type_.chip).foregroundStyle(Tokens.Island.Colors.textTertiary)
        } trailing: {
            HStack(spacing: Tokens.Space.xs) {
                IslandTextButton(title: "New Chat", symbol: "plus.circle") { model.send(.selectorNewChat) }
                IslandTextButton(title: "Search Chats", symbol: "magnifyingglass") { model.send(.selectorSearch) }
            }
        }
        let rows = menu.recentRows
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Island.Layout.selectorGridSpacing),
                                 count: Tokens.Island.Layout.selectorGridColumns),
                  spacing: Tokens.Island.Layout.selectorGridSpacing) {
            ForEach(rows) { route in
                ChatRow(icon: route.destination, title: route.chatName,
                        trailing: RelativeTime.short(from: route.lastActiveAt ?? Date(), to: Date()),
                        selected: route == draft.selectedRoute) {
                    model.send(.chooseRoute(route))
                }
            }
        }
    }

    // MARK: S1 / S3 choose an AI

    @ViewBuilder
    private func aiStep(title: String, choices: [DestinationChoice], showRecommended: Bool) -> some View {
        SelectorHeader {
            BackTitle(title) { model.send(.selectorBack) }
        } trailing: {
            Text("Choose an AI").font(Tokens.Island.Type_.chip).foregroundStyle(Tokens.Island.Colors.textTertiary)
        }
        VStack(spacing: 1) {
            ForEach(choices, id: \.app.id) { choice in
                DestinationRow(choice: choice, showRecommended: showRecommended) {
                    model.send(.chooseDestination(choice.app))
                }
            }
        }
    }

    // MARK: S2 choose a folder

    @ViewBuilder
    private func contextStep(app: AppRef, draft: ReviewDraft) -> some View {
        SelectorHeader {
            BackTitle("New Chat") { model.send(.selectorBack) }
        } trailing: {
            HStack(spacing: Tokens.Space.xs) {
                DestinationIcon(app: app, size: 14)
                Text(app.name).font(Tokens.Island.Type_.chip).foregroundStyle(Tokens.Island.Colors.textSecondary)
            }
        }
        Text("Choose context").font(Tokens.Island.Type_.chip).foregroundStyle(Tokens.Island.Colors.textTertiary)
        FolderRow(name: "No Folder", path: nil, selected: draft.selectedRoute?.context == nil && draft.selectedRoute?.kind == .new) {
            model.send(.chooseFolder(nil))
        }
        if !draft.folders.isEmpty {
            Text("Folders").font(Tokens.Island.Type_.chip).foregroundStyle(Tokens.Island.Colors.textTertiary)
            let list = VStack(spacing: 1) {
                ForEach(draft.folders, id: \.name) { folder in
                    FolderRow(name: folder.name, path: folder.path,
                              selected: draft.selectedRoute?.context == folder) {
                        model.send(.chooseFolder(folder))
                    }
                }
            }
            if draft.folders.count > Tokens.Island.Layout.folderRowsVisible {
                ScrollView(.vertical) { list }
                    .frame(height: CGFloat(Tokens.Island.Layout.folderRowsVisible) * (Tokens.Island.Layout.selectorRowHeight + 1))
                    .scrollIndicators(.visible)
            } else {
                list
            }
        }
    }

    // MARK: S4 search

    @ViewBuilder
    private func searchStep(app: AppRef, draft: ReviewDraft) -> some View {
        SelectorHeader {
            BackTitle("Search Chats") { model.send(.selectorBack) }
        } trailing: {
            HStack(spacing: Tokens.Space.xs) {
                DestinationIcon(app: app, size: 14)
                Text(app.name).font(Tokens.Island.Type_.chip).foregroundStyle(Tokens.Island.Colors.textSecondary)
            }
        }
        SearchField(model: model)
        if !draft.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(draft.searchResults.isEmpty ? "No chats match" : "\(draft.searchResults.count) results")
                .font(Tokens.Island.Type_.chip)
                .foregroundStyle(Tokens.Island.Colors.textTertiary)
            VStack(spacing: 1) {
                ForEach(draft.searchResults) { route in
                    SearchResultRow(route: route) { model.send(.chooseRoute(route)) }
                }
            }
        }
        Text("Searches all \(app.name) chats")
            .font(Tokens.Island.Type_.chip)
            .foregroundStyle(Tokens.Island.Colors.textTertiary)
    }

    private func stepKey(_ step: SelectorStep) -> String {
        switch step {
        case .closed: return "closed"
        case .recent: return "recent"
        case .newChatAI: return "newAI"
        case .newChatContext: return "newContext"
        case .searchAI: return "searchAI"
        case .searchQuery: return "searchQuery"
        }
    }
}

// MARK: - Pieces

private struct SelectorHeader<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            leading
            Spacer(minLength: Tokens.Space.s)
            trailing
        }
        .frame(height: Tokens.Island.Layout.selectorHeaderHeight)
        .padding(.horizontal, Tokens.Space.xs)
    }
}

private struct BackTitle: View {
    let title: String
    let back: () -> Void
    init(_ title: String, back: @escaping () -> Void) { self.title = title; self.back = back }
    var body: some View {
        Button(action: back) {
            HStack(spacing: Tokens.Space.xs) {
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                Text(title).font(Tokens.Island.Type_.bodyMedium)
            }
            .foregroundStyle(Tokens.Island.Colors.textPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to \(title)")
    }
}

private struct SelectorRow<Content: View>: View {
    let choose: () -> Void
    var selected = false
    var height = Tokens.Island.Layout.selectorRowHeight
    @ViewBuilder let content: Content
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: choose) {
            content
                .padding(.horizontal, Tokens.Space.m)
                .frame(height: height)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.row)
                    .fill(selected ? Tokens.Island.Colors.selection : (hovering || focused ? Tokens.Island.Colors.hover : .clear)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onHover { hovering = $0 }
        .onKeyPress(.return) { if focused { choose(); return .handled }; return .ignored }
    }
}

private struct ChatRow: View {
    let icon: AppRef
    let title: String
    let trailing: String
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        SelectorRow(choose: choose, selected: selected) {
            HStack(spacing: Tokens.Space.s) {
                DestinationIcon(app: icon, size: 14)
                Text(title).font(Tokens.Island.Type_.body).foregroundStyle(Tokens.Island.Colors.textPrimary).lineLimit(1)
                Spacer(minLength: Tokens.Space.s)
                Text(trailing).font(Tokens.Island.Type_.secondary).foregroundStyle(Tokens.Island.Colors.textTertiary)
            }
        }
        .accessibilityLabel("\(title), \(icon.name), \(trailing)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct DestinationRow: View {
    let choice: DestinationChoice
    let showRecommended: Bool
    let choose: () -> Void

    var body: some View {
        SelectorRow(choose: choose) {
            HStack(spacing: Tokens.Space.s) {
                DestinationIcon(app: choice.app, size: 16)
                Text(choice.app.name).font(Tokens.Island.Type_.body).foregroundStyle(Tokens.Island.Colors.textPrimary)
                Spacer(minLength: Tokens.Space.s)
                if showRecommended && choice.isRecommended {
                    Text("Recommended").font(Tokens.Island.Type_.secondary).foregroundStyle(Tokens.Island.Colors.textTertiary)
                }
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tokens.Island.Colors.textTertiary)
            }
        }
        .accessibilityLabel(choice.isRecommended && showRecommended ? "\(choice.app.name), recommended" : choice.app.name)
    }
}

private struct FolderRow: View {
    let name: String
    let path: String?
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        SelectorRow(choose: choose, selected: selected) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: path == nil ? "nosign" : "folder")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.Island.Colors.textSecondary)
                Text(name).font(Tokens.Island.Type_.body).foregroundStyle(Tokens.Island.Colors.textPrimary).lineLimit(1)
                Spacer(minLength: Tokens.Space.s)
                if let path {
                    Text(path).font(Tokens.Island.Type_.secondary).foregroundStyle(Tokens.Island.Colors.textTertiary)
                        .lineLimit(1).truncationMode(.head)
                }
            }
        }
        .accessibilityLabel([name, path].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct SearchResultRow: View {
    let route: ChatRoute
    let choose: () -> Void

    var body: some View {
        SelectorRow(choose: choose, height: Tokens.Island.Layout.selectorResultRowHeight) {
            HStack(spacing: Tokens.Space.s) {
                DestinationIcon(app: route.destination, size: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(route.chatName).font(Tokens.Island.Type_.body).foregroundStyle(Tokens.Island.Colors.textPrimary).lineLimit(1)
                    Text(subtitle).font(Tokens.Island.Type_.secondary).foregroundStyle(Tokens.Island.Colors.textTertiary).lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tokens.Island.Colors.textTertiary)
            }
        }
        .accessibilityLabel("\(route.chatName), \(subtitle)")
    }

    private var subtitle: String {
        let folder = route.context?.name
        let active = route.lastActiveAt.map { RelativeTime.activity(from: $0, to: Date()) }
        return [folder, active].compactMap { $0 }.joined(separator: " · ")
    }
}

/// The Search Chats field: magnifier, the query, a clear button. Auto-focused.
private struct SearchField: View {
    let model: IslandModel
    private var text: String { model.state.review?.searchText ?? "" }

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.Island.Colors.textSecondary)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search chats").font(Tokens.Island.Type_.body).foregroundStyle(Tokens.Island.Colors.textTertiary).allowsHitTesting(false)
                }
                IslandTextView(
                    text: Binding(get: { model.state.review?.searchText ?? "" }, set: { model.send(.editSearch($0)) }),
                    font: .systemFont(ofSize: 13),
                    placeholder: "Search chats",
                    submitOnReturn: true,
                    onSubmit: { if let first = model.state.review?.searchResults.first { model.send(.chooseRoute(first)) } },
                    onEscape: { model.send(.selectorBack) },
                    focusToken: model.focusRequest.target == .search ? model.focusRequest.token : 0,
                    insets: NSSize(width: 0, height: 0),
                    wantsFocus: { if case .searchQuery = model.state.review?.selector { return true }; return false }
                )
                .frame(height: 18)
            }
            if !text.isEmpty {
                IslandIconButton(symbol: "xmark.circle.fill", label: "Clear") { model.send(.editSearch("")) }
            }
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: Tokens.Island.Layout.selectorSearchFieldHeight)
        .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.field).fill(Tokens.Island.Colors.field))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.field).strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search chats")
    }
}
