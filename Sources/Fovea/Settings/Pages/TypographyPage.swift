import SwiftUI
import FoveaCore

/// Which faces the feed may use. Two groups, because the two roles are different
/// jobs: display faces carry the one or two highlighted words on a card, text faces
/// carry everything else and are the steady spine underneath the variety.
///
/// Turning a whole group off is allowed — the feed falls back rather than rendering
/// nothing — but the row says so, because it changes how the wall reads.
struct TypographyPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        SettingsPage(title: "Typography") {
            SettingsSection("Highlighted Words", child: .displayFaces) {
                SettingsGroup {
                    ForEach(Array(displayFaces.enumerated()), id: \.element) { i, font in
                        if i > 0 { GroupDivider() }
                        FontRow(font: font, enabled: binding(for: font))
                    }
                }
                FontRoleNote(count: enabled(.display).count, role: .display)
            }

            SettingsSection("Everything Else", child: .textFaces) {
                SettingsGroup {
                    ForEach(Array(textFaces.enumerated()), id: \.element) { i, font in
                        if i > 0 { GroupDivider() }
                        FontRow(font: font, enabled: binding(for: font))
                    }
                }
                FontRoleNote(count: enabled(.text).count, role: .text)
            }
        }
    }

    private var displayFaces: [FeedFont] { FeedFont.allCases.filter { $0.role == .display } }
    private var textFaces: [FeedFont] { FeedFont.allCases.filter { $0.role == .text } }

    private func enabled(_ role: FeedFont.Role) -> [FeedFont] {
        model.settings.settings.feedFonts.filter { $0.role == role }
    }

    private func binding(for font: FeedFont) -> Binding<Bool> {
        Binding(
            get: { model.settings.settings.feedFonts.contains(font) },
            set: { on in
                model.settings.update(.feedFonts) { s in
                    var set = s.feedFonts
                    if on {
                        if !set.contains(font) { set.append(font) }
                    } else {
                        set.removeAll { $0 == font }
                    }
                    // Keep the stored order canonical so the list is stable.
                    s.feedFonts = FeedFont.allCases.filter { set.contains($0) }
                }
            })
    }
}

/// One face: its name set in itself, so the row is its own specimen.
private struct FontRow: View {
    let font: FeedFont
    @Binding var enabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(font.displayName)
                    .font(specimen)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(unavailable ? "Not registered — falls back to the system font." : font.note)
                    .font(Tokens.Type_.secondary)
                    .foregroundStyle(unavailable ? Tokens.Colors.warning : Tokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.Space.l)
            Toggle("", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(unavailable)
        }
        .padding(.horizontal, Tokens.Layout.rowPaddingH)
        .padding(.vertical, Tokens.Layout.rowPaddingV)
        .frame(minHeight: Tokens.Layout.rowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(font.displayName)
        .accessibilityValue(enabled ? "On" : "Off")
    }

    private var unavailable: Bool { !FontRegistry.isAvailable(font) }

    /// 20 pt so the face is actually judgeable, and never bolder than it ships.
    private var specimen: Font {
        Tokens.Type_.anchor(size: 20, weight: font.isSingleWeight ? 0 : 1, face: font)
    }
}

private struct FontRoleNote: View {
    let count: Int
    let role: FeedFont.Role

    var body: some View {
        Text(message)
            .font(Tokens.Type_.secondary)
            .foregroundStyle(count == 0 ? Tokens.Colors.warning : Tokens.Colors.textSecondary)
            .padding(.horizontal, Tokens.Space.xs)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var message: String {
        switch (role, count) {
        case (.display, 0):
            return "No display face on — highlighted words fall back to a text face."
        case (.text, 0):
            return "No text face on — the small words follow each card's display face, which makes a row much busier."
        case (.display, 1):
            return "One face on. Every card's highlights look the same."
        case (.text, 1):
            return "One face on. Every card's small words look the same, which is the steadiest setting."
        case (.display, let n):
            return "\(n) faces on, spread across cards from each capture's own id."
        case (.text, let n):
            return "\(n) faces on, spread across cards from each capture's own id."
        }
    }
}
