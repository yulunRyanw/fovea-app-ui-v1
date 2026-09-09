import SwiftUI
import AppKit
import FoveaCore

struct ShortcutsPage: View {
    @Environment(\.snapshotVariant) private var snapshotVariant

    var body: some View {
        SettingsPage(title: "Shortcuts") {
            SettingsSection(nil, child: .voiceFlow) {
                SettingsGroup {
                    ShortcutRow(action: .voiceFlow, forceRecording: snapshotVariant == "shortcut-recording")
                    GroupDivider()
                    ShortcutRow(action: .quickAnswer)
                        .id(SettingsChild.quickAnswer)
                }
            }
            SettingsSection("fn key") {
                SettingsGroup {
                    SettingsRow(label: "Let Fovea have the fn key",
                                detail: "macOS also acts on a tap of fn (🌐). Set “Press 🌐 key to” to Do Nothing in Keyboard settings so it only reaches Fovea. Noticing fn in other apps needs Accessibility access.") {
                        QuietButton(title: "Keyboard Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
    }
}
