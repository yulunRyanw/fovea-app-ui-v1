import SwiftUI
import FoveaCore

/// The island's open mouth while a detached Quick Answer is dragged close: an inset well
/// the panel will slide into, with one glyph. `ready` means release will dock. No text.
struct DockReceiverView: View {
    let ready: Bool
    let notchHeight: CGFloat
    let depth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Island.Radius.dockWell, style: .continuous)
                    .fill(ready ? Tokens.Island.Colors.dockWellReady : Tokens.Island.Colors.dockWell)
                RoundedRectangle(cornerRadius: Tokens.Island.Radius.dockWell, style: .continuous)
                    .strokeBorder(ready ? Tokens.Island.Colors.dockOutline : Tokens.Island.Colors.hairline, lineWidth: 1)
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: Tokens.Island.Layout.dockGlyphSize, weight: .semibold))
                    .foregroundStyle(ready ? Tokens.Island.Colors.textPrimary : Tokens.Island.Colors.textTertiary)
            }
            .padding(Tokens.Island.Layout.dockWellInset)
            .frame(height: depth)
        }
        .foveaAnimation(.hover, value: ready)
        .accessibilityElement()
        .accessibilityLabel(ready ? "Release to dock" : "Drag here to dock")
    }
}
