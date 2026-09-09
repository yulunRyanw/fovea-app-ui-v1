import SwiftUI
import FoveaCore

struct SettingsSplitView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar()
                .frame(width: Tokens.Layout.sidebarWidth)
                .background(Tokens.Colors.sidebar)
            SettingsDetailPane()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.Colors.canvas)
        .background {
            // ⌘[ steps back: a connector detail returns to Connectors, anything else to Home.
            // Registered once here; the back links carry no shortcut of their own.
            Button("Back") {
                if case .connectorDetail = model.route { model.back() } else { model.showHome() }
            }
            .keyboardShortcut("[", modifiers: .command)
            .opacity(0).frame(width: 0, height: 0)
        }
    }
}

// MARK: - Sidebar

/// The seven categories as a flat list under group headers; the current one is a neutral pill.
/// Children are sections of the page, reached by deep link, not sidebar rows.
struct SettingsSidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Level with the page title, clear of the traffic lights.
            BackLink(title: "Back to Home", help: "Back to Home (⌘[)") { model.showHome() }
                .padding(.top, Tokens.Layout.titlebarInset - 8)

            PageScroll {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(SettingsSidebarGroup.allCases.enumerated()), id: \.element) { index, group in
                        Text(group.title)
                            .font(Tokens.Type_.sidebarGroup)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                            .padding(.leading, Tokens.Space.s)
                            .padding(.top, index == 0 ? Tokens.Space.xl + 4 : Tokens.Space.l + 4)
                            .padding(.bottom, Tokens.Space.xs + 2)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.categories, id: \.self) { category in
                            SettingsSidebarItem(category: category)
                        }
                    }
                }
                .padding(.bottom, Tokens.Space.xl)
            }
        }
        .padding(.horizontal, Tokens.Layout.sidebarInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings")
    }
}

struct SettingsSidebarItem: View {
    @Environment(AppModel.self) private var model
    let category: SettingsCategory

    @State private var hovering = false
    @FocusState private var focused: Bool

    /// A connector detail keeps Connectors current: `AppModel` pins `settingsRoute` to it.
    private var selected: Bool { model.settingsRoute.category == category }

    var body: some View {
        Button {
            model.showSettings(category)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Tokens.Colors.glyph)
                    .frame(width: 20)
                Text(category.title)
                    .font(Tokens.Type_.sidebarItem)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Space.m)
            .frame(height: Tokens.Layout.sidebarItemHeight)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.row)
                    .fill(selected ? Tokens.Colors.selection : hovering ? Tokens.Colors.hover : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.row))
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused)
        .onKeyPress(.return) { model.showSettings(category); return .handled }
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint("Opens \(category.title)")
    }
}

// MARK: - Detail pane

struct SettingsDetailPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotMode) private var snapshotMode

    var body: some View {
        ScrollViewReader { proxy in
            PageScroll {
                Group {
                    switch model.route {
                    case .connectorDetail(let id):
                        ConnectorDetailPage(connectorId: id)
                    default:
                        switch model.settingsRoute.category {
                        case .account: AccountPage()
                        case .eyeTracking: EyeTrackingPage()
                        case .voiceCapture: VoiceCapturePage()
                        case .dictionary: DictionaryPage()
                        case .shortcuts: ShortcutsPage()
                        case .connectors: ConnectorsPage()
                        case .plan: PlanPage()
                        }
                    }
                }
                // One column, at most `settingsGroupMaxWidth` wide, centered in the pane.
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxWidth: Tokens.Layout.settingsGroupMaxWidth)
                .padding(.horizontal, Tokens.Layout.settingsPagePadding)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, Tokens.Layout.titlebarInset - 8)
                .padding(.bottom, Tokens.Space.xxxl)
            }
            .onChange(of: model.settingsRoute) { _, route in scroll(to: route, with: proxy) }
            // The pane mounts fresh each time Settings opens, so the entry route needs it too.
            .onAppear { scroll(to: model.settingsRoute, with: proxy) }
        }
        .background(Tokens.Colors.canvas)
    }

    /// Deep links land on their section; a category's first child is the top of the page.
    private func scroll(to route: SettingsRoute, with proxy: ScrollViewProxy) {
        guard !snapshotMode else { return }
        if route.child != route.category.children.first {
            withAnimation(nil) { proxy.scrollTo(route.child, anchor: .top) }
        } else {
            withAnimation(nil) { proxy.scrollTo("page-top", anchor: .top) }
        }
    }
}

// MARK: - Page primitives

struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxl) {
            Text(title)
                .font(Tokens.Type_.pageTitle)
                .tracking(-0.3)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .id("page-top")
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    var child: SettingsChild? = nil
    @ViewBuilder var content: Content

    init(_ title: String?, child: SettingsChild? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.child = child; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            if let title {
                Text(title)
                    .font(Tokens.Type_.settingsSection)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .id(child)
    }
}

/// Related rows share one surface; separate rows with `GroupDivider()`.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.group).fill(Tokens.Colors.group))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.group).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
    }
}

/// Hairline between rows, inset on both sides to the row's text.
struct GroupDivider: View {
    var body: some View {
        Rectangle()
            .fill(Tokens.Colors.hairline)
            .frame(height: 1)
            .padding(.horizontal, Tokens.Layout.rowPaddingH)
    }
}
