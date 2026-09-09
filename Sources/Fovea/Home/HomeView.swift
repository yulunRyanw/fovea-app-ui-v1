import SwiftUI
import FoveaCore

// MARK: - Home

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotMode) private var snapshotMode
    /// The capture the Island just sent, while the ledger acknowledges it.
    @State private var recentId: String?
    @State private var acknowledgeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - 2 * Tokens.Layout.feedHorizontalPadding
            let feedWidth = max(320, min(Tokens.Layout.feedMaxWidth, available))
            PageScroll {
                VStack(spacing: 0) {
                    HomeHeader()
                        .padding(.top, Tokens.Layout.titlebarInset - 18)
                    FeedContent(width: feedWidth, recentId: recentId)
                        .frame(width: feedWidth, alignment: .topLeading)
                        .padding(.top, 46)
                        .padding(.bottom, 56)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Tokens.Colors.canvas)
        .task {
            // Demo loading state resolves on its own.
            if model.feedState == .loading && !snapshotMode {
                try? await Task.sleep(for: .milliseconds(1400))
                model.finishLoading()
            }
        }
        // A capture the Island appends lands at the top with the same acknowledgement the
        // Island's own list gives the task it just created, then settles.
        .onChange(of: model.captures.count) { old, new in
            guard new > old, !snapshotMode, let first = model.captures.first else { return }
            acknowledgeTask?.cancel()
            recentId = first.id
            acknowledgeTask = Task {
                try? await Task.sleep(for: Tokens.Motion.sentGrace)
                guard !Task.isCancelled else { return }
                recentId = nil
            }
        }
    }
}

// MARK: - Header

struct HomeHeader: View {
    var body: some View {
        HStack(spacing: 20) {
            UsageAvatar()
            CaptureSearchField()
            DictionaryButton()
                .padding(.leading, -2)
        }
        .frame(maxWidth: Tokens.Layout.headerSearchMaxWidth + 120)
        .padding(.horizontal, Tokens.Layout.feedHorizontalPadding)
    }
}

struct UsageAvatar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotMode) private var snapshotMode
    @State private var hovering = false
    @State private var showPopover = false
    @FocusState private var focused: Bool

    private var size: CGFloat { Tokens.Layout.avatarSize }
    private var ringSize: CGFloat { size + 2 * (Tokens.Layout.ringGap + Tokens.Layout.ringWidth) }

    var body: some View {
        // The usage arc only; no full track circle around the disk.
        Button {
            model.showSettings(.account)
        } label: {
            ZStack {
                if case .loaded(let usage) = model.usage {
                    Circle()
                        .trim(from: 0, to: usage.fraction)
                        .stroke(Tokens.Colors.ink,
                                style: StrokeStyle(lineWidth: Tokens.Layout.ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                AvatarDisk(name: model.settings.settings.displayName, size: size, emphasized: focused)
            }
            .frame(width: ringSize, height: ringSize)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        // Keyboard focus deepens the disk instead of drawing a ring around it.
        .foveaAnimation(.hover, value: focused)
        .help("Account")
        .accessibilityLabel(accessibilityText)
        .onHover { hovering = $0 }
        .onChange(of: hovering) { _, h in if !snapshotMode { showPopover = h } }
        .onChange(of: focused) { _, f in if !snapshotMode { showPopover = f } }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            UsagePopover(usage: model.usage)
                .padding(Tokens.Space.m)
        }
    }

    private var accessibilityText: String {
        if case .loaded(let u) = model.usage { return "Account. \(u.percent) percent of \(u.unitLabel) used." }
        return "Account. Usage unavailable."
    }
}

struct AvatarDisk: View {
    let name: String
    let size: CGFloat
    /// Stronger fill, used to show keyboard focus without a ring.
    var emphasized = false

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    var body: some View {
        Circle()
            .fill(emphasized ? Tokens.Colors.ink.opacity(0.18) : Tokens.Colors.control)
            .frame(width: size, height: size)
            .overlay(
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Tokens.Colors.ink)
            )
    }
}

struct UsagePopover: View {
    let usage: UsageState

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            switch usage {
            case .loaded(let u):
                Text("\(u.percent)% used")
                    .font(Tokens.Type_.bodyMedium)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                Text("\(u.used) of \(u.limit) \(u.unitLabel)")
                    .font(Tokens.Type_.secondary)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                Text("Resets \(DateGrouping.shortDate(u.resetsAt))")
                    .font(Tokens.Type_.secondary)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            case .unavailable:
                Text("Usage unavailable")
                    .font(Tokens.Type_.bodyMedium)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                Text("Couldn’t load usage right now.")
                    .font(Tokens.Type_.secondary)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
        .frame(width: 170, alignment: .leading)
    }
}

struct CaptureSearchField: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Tokens.Colors.textSecondary)
            TextField("Search your captures…", text: $model.searchQuery)
                .textFieldStyle(.plain)
                .font(Tokens.Type_.search)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .focused($focused)
                .accessibilityLabel("Search your captures")
            if !model.searchQuery.isEmpty {
                Button {
                    model.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: Tokens.Layout.headerSearchMaxWidth)
        .frame(height: Tokens.Layout.headerSearchHeight)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.field).fill(Tokens.Colors.field))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.field)
                .strokeBorder(focused ? Tokens.Colors.ink.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}

struct DictionaryButton: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button {
            model.showSettings(.dictionary)
        } label: {
            Text("Aa")
                .font(Tokens.Type_.dictionaryAction)
                .foregroundStyle(Tokens.Colors.glyph)
                .frame(width: Tokens.Layout.hitTarget, height: Tokens.Layout.hitTarget)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.pill)
                        .fill(hovering || focused ? Tokens.Colors.hover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .help("Dictionary")
        .accessibilityLabel("Dictionary")
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

// MARK: - Ledger

struct FeedContent: View {
    @Environment(AppModel.self) private var model
    let width: CGFloat
    var recentId: String? = nil

    var body: some View {
        switch model.feedState {
        case .loading:
            HomeSkeleton(width: width)
        case .empty:
            HomeEmptyState()
        case .ready:
            let captures = model.filteredCaptures
            if captures.isEmpty {
                NoResultsState(query: model.searchQuery) { model.searchQuery = "" }
            } else {
                VStack(alignment: .leading, spacing: Tokens.Ledger.groupGap) {
                    ForEach(DateGrouping.groups(captures)) { group in
                        CaptureDateGroup(group: group, recentId: recentId)
                    }
                }
            }
        }
    }
}

/// One day: a quiet heading, then one row per capture. The heading sits in the row's
/// own inset so it lines up with the rows' content, not their hover fill.
struct CaptureDateGroup: View {
    let group: DateGroup
    var recentId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
                Text(group.title)
                    .font(Tokens.Type_.dateHeading)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                if let subtitle = group.subtitle {
                    Text(subtitle)
                        .font(Tokens.Type_.dateSubtitle)
                        .foregroundStyle(Tokens.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Tokens.Ledger.rowPaddingH)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: Tokens.Ledger.rowGap) {
                ForEach(group.captures) { capture in
                    CaptureRow(capture: capture, highlighted: capture.id == recentId)
                }
            }
        }
    }
}

// MARK: - States

struct HomeSkeleton: View {
    let width: CGFloat
    private let titleFractions: [CGFloat] = [0.52, 0.38, 0.61, 0.44, 0.57]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            RoundedRectangle(cornerRadius: 4).fill(Tokens.Colors.skeleton).frame(width: 120, height: 14)
                .padding(.horizontal, Tokens.Ledger.rowPaddingH)
            VStack(spacing: Tokens.Ledger.rowGap) {
                ForEach(Array(titleFractions.enumerated()), id: \.offset) { _, fraction in
                    HStack(spacing: Tokens.Ledger.iconGap) {
                        RoundedRectangle(cornerRadius: Tokens.Ledger.thumbRadius)
                            .fill(Tokens.Colors.skeleton)
                            .frame(width: Tokens.Ledger.thumb.width, height: Tokens.Ledger.thumb.height)
                            .frame(width: Tokens.Ledger.seenColumnWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(Tokens.Colors.skeleton)
                                .frame(width: width * fraction, height: 11)
                            RoundedRectangle(cornerRadius: 3).fill(Tokens.Colors.skeleton)
                                .frame(width: 96, height: 9)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Tokens.Ledger.rowPaddingH)
                    .frame(height: Tokens.Ledger.rowHeight)
                }
            }
        }
        .accessibilityLabel("Loading captures")
    }
}

struct HomeEmptyState: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Text("No captures yet")
                .font(Tokens.Type_.section)
                .foregroundStyle(Tokens.Colors.textPrimary)
            HStack(spacing: Tokens.Space.xs) {
                Text("Press")
                KeyCap(labels: model.shortcuts.bindings[.voiceFlow]?.displayGlyphs ?? [KeyBinding.functionKeyLabel])
                Text("and say what you need.")
            }
            .font(Tokens.Type_.body)
            .foregroundStyle(Tokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

struct NoResultsState: View {
    let query: String
    let clear: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            Text("No captures match “\(query)”")
                .font(Tokens.Type_.section)
                .foregroundStyle(Tokens.Colors.textPrimary)
            QuietButton(title: "Clear search", action: clear)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}
