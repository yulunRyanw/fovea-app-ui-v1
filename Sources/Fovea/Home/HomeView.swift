import SwiftUI
import FoveaCore

// MARK: - Home

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotMode) private var snapshotMode

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - 2 * Tokens.Layout.feedHorizontalPadding
            let feedWidth = max(320, min(Tokens.Layout.feedMaxWidth, available))
            PageScroll {
                VStack(spacing: 0) {
                    HomeHeader()
                        .padding(.top, Tokens.Layout.titlebarInset - 18)
                    FeedContent(width: feedWidth)
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
                        .stroke(Tokens.Colors.emphasis,
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
            .fill(emphasized ? Tokens.Colors.emphasis.opacity(0.18) : Tokens.Colors.control)
            .frame(width: size, height: size)
            .overlay(
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Tokens.Colors.emphasis)
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
                .strokeBorder(focused ? Tokens.Colors.emphasis.opacity(0.5) : .clear, lineWidth: 1.5)
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

// MARK: - Feed

struct FeedContent: View {
    @Environment(AppModel.self) private var model
    let width: CGFloat

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
                VStack(alignment: .leading, spacing: Tokens.Layout.feedGroupGap) {
                    ForEach(DateGrouping.groups(captures)) { group in
                        CaptureDateGroup(group: group, width: width)
                    }
                }
            }
        }
    }
}

struct CaptureDateGroup: View {
    let group: DateGroup
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
                Text(group.title)
                    .font(Tokens.Type_.dateHeading)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                if let subtitle = group.subtitle {
                    Text(subtitle)
                        .font(Tokens.Type_.dateSubtitle)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            CaptureGrid(captures: group.captures, width: width)
        }
    }
}

struct CaptureGrid: View {
    let captures: [Capture]
    let width: CGFloat

    private var rows: [JustifiedRows.Row] {
        let items = captures.map { c in
            JustifiedRows.Item(id: c.id, aspect: c.heroReferent?.aspect ?? fingerprint(c).aspect)
        }
        let cap = width >= Tokens.Layout.wideFeedThreshold
            ? Tokens.Layout.maxItemsPerRowWide : Tokens.Layout.maxItemsPerRowNarrow
        return JustifiedRows.layout(items, width: width.rounded(),
                                    targetHeight: Tokens.Layout.feedRowTargetHeight,
                                    spacing: Tokens.Layout.feedSpacing, maxPerRow: cap,
                                    fixedPerRow: Tokens.Layout.cardsPerRow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Layout.feedRowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: Tokens.Layout.feedSpacing) {
                    ForEach(row.items, id: \.id) { placed in
                        if let capture = captures.first(where: { $0.id == placed.id }) {
                            CaptureCell(capture: capture, width: placed.width, mediaHeight: row.height)
                        }
                    }
                    if !row.justified { Spacer(minLength: 0) }
                }
            }
        }
    }
}

func fingerprint(_ c: Capture) -> SemanticFingerprint {
    SemanticFingerprint.make(captureId: c.id, anchors: c.semanticAnchors, transcript: c.transcript)
}

// MARK: - Cell

struct CaptureCell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotForceActions) private var forceActions
    let capture: Capture
    let width: CGFloat
    let mediaHeight: CGFloat

    @State private var hovering = false
    @State private var frame: CGRect = .zero
    @FocusState private var focused: Bool

    private var showActions: Bool { hovering || focused || forceActions == capture.id }
    /// Only failed / pending deliveries get a status row; cards carry no time.
    private var showsStatus: Bool { capture.deliveryStatus == .failed || capture.deliveryStatus == .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if capture.isVisual {
                media
                if showsStatus { status }
            } else {
                if showsStatus { status }
                SemanticCaptureItem(capture: capture, width: width, height: mediaHeight)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .contentShape(Rectangle())
        // The whole card opens its detail; the Copy pill and Retry sit above and win.
        .onTapGesture { model.openDetail(capture, from: frame) }
        .overlay(alignment: .topTrailing) {
            CaptureActions(capture: capture)
                .padding(Tokens.Space.xs + 2)
                .opacity(showActions ? 1 : 0)
                .allowsHitTesting(showActions)
                .foveaAnimation(.hover, value: showActions, fadeOnly: true)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused, radius: Tokens.Radius.image)
        .onHover { hovering = $0 }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(RootView.coordinateSpace)) } action: { frame = $0 }
        .onKeyPress(.return) { model.openDetail(capture, from: frame); return .handled }
        .onKeyPress("c") { model.copy(capture); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: "Details") { model.openDetail(capture, from: frame) }
        .accessibilityAction(named: "Copy") { model.copy(capture) }
    }

    private var media: some View {
        CapturePreview(referent: capture.heroReferent!, width: width, height: mediaHeight)
    }

    private var status: some View {
        HStack(spacing: Tokens.Space.s) {
            if capture.deliveryStatus == .failed {
                DeliveryFailedBadge(capture: capture)
            } else {
                HStack(spacing: Tokens.Space.xs) {
                    ProgressView().controlSize(.mini)
                    Text("Sending…")
                        .font(Tokens.Type_.caption)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
            }
        }
        .frame(height: Tokens.Layout.feedLabelHeight - 7)
    }

    private var accessibilityLabel: String {
        let time = DateGrouping.timeLabel(capture.createdAt)
        if let ref = capture.heroReferent {
            return "\(ref.kind.rawValue) capture, \(ref.filename ?? ref.title ?? ""), \(time)"
        }
        return "Voice capture: \(capture.semanticAnchors.joined(separator: ", ")), \(time)"
    }
}

struct DeliveryFailedBadge: View {
    @Environment(AppModel.self) private var model
    let capture: Capture

    var body: some View {
        Button {
            model.retryDelivery(capture)
        } label: {
            // A filled chip, not colored text: several palettes put a red or orange
            // in `ink` or `pop`, and a failed capture must never be mistakable for a
            // highlighted word. The shape carries the meaning, so it survives any hue.
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Retry")
                    .font(Tokens.Type_.captionMedium)
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Tokens.Colors.warning))
        }
        .buttonStyle(.plain)
        .help("Not delivered to \(capture.destinationApp?.name ?? "destination"). Click to send again.")
        .accessibilityLabel("Not delivered. Retry")
    }
}

// MARK: - Actions

/// The one action that lives on the card itself, top-right and small. Details open by
/// clicking the card.
struct CaptureActions: View {
    @Environment(AppModel.self) private var model
    let capture: Capture

    var body: some View {
        GlyphButton(symbol: "doc.on.doc", label: "Copy", size: 10, hitSize: 22) { model.copy(capture) }
            .padding(1)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.chip + 2).fill(Tokens.Colors.elevated.opacity(0.96)))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.chip + 2).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
            .accessibilityElement(children: .contain)
    }
}

// MARK: - Semantic capture

struct SemanticCaptureItem: View {
    @Environment(\.foveaTheme) private var theme
    @Environment(AppModel.self) private var model
    let capture: Capture
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let fp = fingerprint(capture)
        // The only place in the app a palette color is used. Two highlights per card
        // at most; everything else stays black.
        let pick = SemanticFingerprint.colorPick(captureId: capture.id, count: theme.colors.count)
        let faces = SemanticFingerprint.fontPick(
            captureId: capture.id,
            display: FeedFont.pool(model.settings.settings.feedFonts, role: .display),
            text: FeedFont.pool(model.settings.settings.feedFonts, role: .text))
        VStack(alignment: .leading, spacing: fp.lineSpacing) {
            ForEach(Array(fp.anchors.enumerated()), id: \.offset) { _, anchor in
                Text(anchor.text)
                    .font(Tokens.Type_.anchor(size: anchor.size, weight: anchor.weight,
                                              face: anchor.isPrimary ? faces.display : faces.text))
                    .tracking(anchor.isPrimary ? -0.4 : -0.1)
                    .foregroundStyle(color(for: anchor.emphasis, pick: pick))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, anchor.indent)
            }
        }
        .padding(.leading, 4)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }

    private func color(for e: SemanticFingerprint.Emphasis, pick: (lead: Int, echo: Int)) -> Color {
        switch e {
        case .lead:  return theme[pick.lead]
        case .echo:  return theme[pick.echo]
        case .quiet: return Tokens.Colors.anchorInk
        }
    }
}

// MARK: - States

struct HomeSkeleton: View {
    let width: CGFloat
    private let aspects: [CGFloat] = [1.4, 1.5, 0.75, 1.5, 1.3, 1.6, 1.2, 1.45]

    var body: some View {
        let cap = width >= Tokens.Layout.wideFeedThreshold
            ? Tokens.Layout.maxItemsPerRowWide : Tokens.Layout.maxItemsPerRowNarrow
        let items = aspects.enumerated().map { JustifiedRows.Item(id: "s\($0.offset)", aspect: $0.element) }
        let rows = JustifiedRows.layout(items, width: width, targetHeight: Tokens.Layout.feedRowTargetHeight,
                                        spacing: Tokens.Layout.feedSpacing, maxPerRow: cap,
                                        fixedPerRow: Tokens.Layout.cardsPerRow)
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            RoundedRectangle(cornerRadius: 4).fill(Tokens.Colors.skeleton).frame(width: 120, height: 14)
            VStack(alignment: .leading, spacing: Tokens.Layout.feedRowGap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: Tokens.Layout.feedSpacing) {
                        ForEach(row.items, id: \.id) { p in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: Tokens.Radius.image)
                                    .fill(Tokens.Colors.skeleton)
                                    .frame(width: p.width, height: row.height)
                                RoundedRectangle(cornerRadius: 3).fill(Tokens.Colors.skeleton).frame(width: 52, height: 10)
                            }
                        }
                        if !row.justified { Spacer(minLength: 0) }
                    }
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
