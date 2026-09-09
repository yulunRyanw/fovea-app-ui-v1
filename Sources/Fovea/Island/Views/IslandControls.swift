import SwiftUI
import AppKit
import FoveaCore

// Small controls that only exist on the black surface. Linear, low emphasis until hover.

struct IslandTextButton: View {
    let title: String
    var prominent = false
    var disabled = false
    /// Optional leading SF Symbol (New Chat, Search Chats).
    var symbol: String? = nil
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.xs) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                }
                Text(title)
            }
                .font(Tokens.Island.Type_.pill)
                .foregroundStyle(prominent ? Tokens.Island.Colors.textPrimary : Tokens.Island.Colors.textSecondary)
                .padding(.horizontal, Tokens.Space.m)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill)
                        .fill(hovering || prominent ? Tokens.Island.Colors.field : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill)
                        .strokeBorder(Tokens.Island.Colors.focus, lineWidth: 1.5)
                        .opacity(focused ? 1 : 0)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .focused($focused)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

struct IslandIconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 11
    var disabled = false
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Tokens.Island.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(hovering ? Tokens.Island.Colors.hover : .clear))
                .overlay(Circle().strokeBorder(Tokens.Island.Colors.focus, lineWidth: 1.5).opacity(focused ? 1 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .focused($focused)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .help(label)
        .accessibilityLabel(label)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

/// The circular Send control: white disc, black arrow. Small, next to what it sends.
struct SendButton: View {
    var enabled: Bool
    var busy = false
    var size: CGFloat = Tokens.Island.Layout.sendButtonSize
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(enabled ? Tokens.Island.Colors.textPrimary : Tokens.Island.Colors.field)
                if busy {
                    ProgressView().controlSize(.mini).tint(Tokens.Island.Colors.surface)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(enabled ? Tokens.Island.Colors.surface : Tokens.Island.Colors.textTertiary)
                }
            }
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Tokens.Island.Colors.focus, lineWidth: 1.5).padding(-3).opacity(focused ? 1 : 0))
            .opacity(hovering && enabled ? 0.88 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .focused($focused)
        .disabled(!enabled || busy)
        .help("Send")
        .accessibilityLabel("Send")
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

/// Destination icon, light on dark. Official artwork when bundled, else the app glyph.
struct DestinationIcon: View {
    let app: AppRef
    var size: CGFloat = Tokens.Island.Layout.iconSize

    var body: some View {
        Group {
            if let image = DestinationIcons.image(for: app.id) {
                Image(nsImage: image)
                    .renderingMode(DestinationIcons.keepsColor(app.id) ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(Tokens.Island.Colors.textPrimary)
            } else {
                Image(systemName: app.symbol)
                    .font(.system(size: size * 0.8, weight: .medium))
                    .foregroundStyle(Tokens.Island.Colors.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(app.name)
    }
}

/// Bundled provider marks, by destination id (`Resources/Destinations/<id>.png`).
@MainActor
enum DestinationIcons {
    private static var cache: [String: NSImage?] = [:]

    static func image(for id: String) -> NSImage? {
        if let cached = cache[id] { return cached }
        let image = FoveaResources.url("Destinations/\(id).png").flatMap { NSImage(contentsOf: $0) }
        cache[id] = image
        return image
    }

    /// Marks that keep their official color; everything else is tinted white.
    static func keepsColor(_ id: String) -> Bool { id == "claude-code" || id == "claude" }
}
