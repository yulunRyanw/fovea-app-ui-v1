import SwiftUI
import AppKit
import FoveaCore

// Shared primitives used by both Home and Settings.

struct PageScroll<Content: View>: View {
    var axes: Axis.Set = .vertical
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(axes) { content }
    }
}

/// Responds on pointer down: scale(0.97) with a short ease-out; no bounce.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            // Respond on pointer-down (fast), settle on release (slightly slower).
            .animation(Tokens.Motion.animation(configuration.isPressed ? .pressDown : .pressUp, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
    }
}

/// Gray-fill button used for secondary actions (Retry, Manage, Calibrate…); no border.
struct QuietButton: View {
    let title: String
    var prominent = false
    var destructive = false
    var disabled = false
    var disabledReason: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Tokens.Type_.button)
                .foregroundStyle(foreground)
                .padding(.horizontal, Tokens.Space.m + 2)
                .frame(height: Tokens.Layout.controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.control)
                        .fill(background)
                )
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.control))
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .help(disabled ? (disabledReason ?? title) : title)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }

    private var foreground: Color {
        if prominent { return .white }
        if destructive { return Tokens.Colors.destructive }
        return Tokens.Colors.textPrimary
    }

    private var background: Color {
        if prominent { return Tokens.Colors.emphasis.opacity(hovering ? 0.9 : 1) }
        return hovering ? Tokens.Colors.controlHover : Tokens.Colors.control
    }
}

/// "← Title": leaves the current screen (Settings → Home, a connector → Connectors).
/// ⌘[ is registered once by the settings shell, not here.
struct BackLink: View {
    let title: String
    var help: String? = nil
    let action: () -> Void

    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Colors.glyph)
                Text(title)
                    .font(Tokens.Type_.sidebarItem)
                    .foregroundStyle(Tokens.Colors.textPrimary)
            }
            .padding(.horizontal, Tokens.Space.s + 2)
            .frame(height: Tokens.Layout.hitTarget)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.row).fill(hovering ? Tokens.Colors.hover : .clear))
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.row))
        }
        .buttonStyle(PressableStyle())
        .help(help ?? title)
        .accessibilityLabel(help ?? title)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused)
        .onKeyPress(.return) { action(); return .handled }
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

/// Icon-only control with a 32×32 hit target, a tooltip and an accessible name.
struct GlyphButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 13
    var hitSize: CGFloat = Tokens.Layout.hitTarget
    var disabled = false
    var disabledReason: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Tokens.Colors.glyph)
                .frame(width: hitSize, height: hitSize)
                .background(
                    RoundedRectangle(cornerRadius: min(Tokens.Radius.row, hitSize / 3))
                        .fill(hovering ? Tokens.Colors.hover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .help(disabled ? (disabledReason ?? label) : label)
        .accessibilityLabel(label)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

/// Keyboard glyphs for shortcuts.
struct KeyCap: View {
    let labels: [String]
    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(Tokens.Type_.captionMedium)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .padding(.horizontal, Tokens.Space.s)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.chip).fill(Tokens.Colors.keycap))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.chip).strokeBorder(Tokens.Colors.hairlineStrong, lineWidth: 1))
            }
        }
    }
}

/// Small status dot + label. Readable without color.
struct StatusLabel: View {
    enum Kind { case positive, warning, neutral }
    let text: String
    let kind: Kind

    var body: some View {
        HStack(spacing: Tokens.Space.xs + 1) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(Tokens.Type_.captionMedium)
        }
        .foregroundStyle(color)
    }

    private var symbol: String {
        switch kind {
        case .positive: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .neutral: return "circle.fill"
        }
    }

    private var color: Color {
        switch kind {
        case .positive: return Tokens.Colors.positive
        case .warning: return Tokens.Colors.warning
        case .neutral: return Tokens.Colors.textSecondary
        }
    }
}

/// Rounded square tile with an SF Symbol, used for app and connector glyphs. When the
/// app is a destination with a bundled mark (`Resources/Destinations`), the mark is used.
struct AppGlyph: View {
    let symbol: String
    var size: CGFloat = 28
    var appId: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28)
            .fill(Tokens.Colors.field)
            .frame(width: size, height: size)
            .overlay(glyph)
            .overlay(RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private var glyph: some View {
        if let appId, let image = DestinationIcons.image(for: appId) {
            Image(nsImage: image)
                .renderingMode(DestinationIcons.keepsColor(appId) ? .original : .template)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .foregroundStyle(Tokens.Colors.textPrimary.opacity(0.8))
                .frame(width: size * 0.56, height: size * 0.56)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(Tokens.Colors.textPrimary.opacity(0.75))
        }
    }
}

/// Custom focus ring (the system ring is disabled on custom controls).
struct FocusRing: ViewModifier {
    let focused: Bool
    let radius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Tokens.Colors.emphasis, lineWidth: contrast == .increased ? 2.5 : 2)
                .padding(-3)
                .opacity(focused ? 1 : 0)
        )
    }
}

extension View {
    func focusRing(_ focused: Bool, radius: CGFloat = Tokens.Radius.row) -> some View {
        modifier(FocusRing(focused: focused, radius: radius))
    }
}

/// Reports the window so the root can tune AppKit behavior (drag by background).
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { configure(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { configure(window) }
    }
}

/// Loads bundled preview images once.
@MainActor
final class PreviewImageCache {
    static let shared = PreviewImageCache()
    private var images: [String: NSImage] = [:]
    private var missing: Set<String> = []

    func image(for resource: String) -> NSImage? {
        if let image = images[resource] { return image }
        if missing.contains(resource) { return nil }
        guard let url = FoveaResources.url(resource), let image = NSImage(contentsOf: url) else {
            missing.insert(resource)
            return nil
        }
        images[resource] = image
        return image
    }
}

extension NSPasteboard {
    static func copy(_ text: String) {
        general.clearContents()
        general.setString(text, forType: .string)
    }
}
