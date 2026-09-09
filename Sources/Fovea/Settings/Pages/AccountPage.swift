import SwiftUI
import FoveaCore

struct AccountPage: View {
    @Environment(AppModel.self) private var model
    @State private var confirmSignOut = false

    private var settings: SettingsModel { model.settings }

    var body: some View {
        SettingsPage(title: "Account") {
            SettingsSection("Profile", child: .profile) {
                SettingsGroup {
                    SettingsRow(label: "Avatar") {
                        HStack(spacing: Tokens.Space.m) {
                            AvatarDisk(name: settings.settings.displayName, size: 28)
                            QuietButton(title: "Change…", disabled: true,
                                        disabledReason: "Avatar upload isn’t available in the prototype") {}
                        }
                    }
                    GroupDivider()
                    TextRow(label: "Display Name", key: .displayName, text: Binding(
                        get: { settings.settings.displayName },
                        set: { v in settings.update(.displayName) { $0.displayName = v } }))
                    GroupDivider()
                    TextRow(label: "Email Address", text: .constant(settings.settings.email), editable: false)
                }
            }

            SettingsSection("App", child: .app) {
                SettingsGroup {
                    SelectRow(label: "Interface Language", key: .interfaceLanguage,
                              selection: Binding(
                                get: { settings.settings.interfaceLanguage },
                                set: { v in settings.update(.interfaceLanguage) { $0.interfaceLanguage = v } }),
                              options: InterfaceLanguage.all.map { ($0.id, $0.name) })
                    GroupDivider()
                    ToggleRow(label: "Launch at Login", key: .launchAtLogin, isOn: Binding(
                        get: { settings.settings.launchAtLogin },
                        set: { v in settings.update(.launchAtLogin) { $0.launchAtLogin = v } }))
                    GroupDivider()
                    ToggleRow(label: "Show in Dock", detail: "Off keeps Fovea in the menu bar only.",
                              key: .showInDock, isOn: Binding(
                        get: { settings.settings.showInDock },
                        set: { v in settings.update(.showInDock) { $0.showInDock = v } }))
                    GroupDivider()
                    ToggleRow(label: "Automatic Updates", key: .automaticUpdates, isOn: Binding(
                        get: { settings.settings.automaticUpdates },
                        set: { v in settings.update(.automaticUpdates) { $0.automaticUpdates = v } }))
                }
            }

            SettingsSection("Data", child: .data) {
                SettingsGroup {
                    SelectRow(label: "Screenshot Retention",
                              detail: "Captured screenshots are deleted after this period.",
                              key: .screenshotRetentionDays,
                              selection: Binding(
                                get: { RetentionOption.all.first { $0.days == settings.settings.screenshotRetentionDays }?.id ?? "forever" },
                                set: { id in
                                    let days = RetentionOption.all.first { $0.id == id }?.days
                                    settings.update(.screenshotRetentionDays) { $0.screenshotRetentionDays = days }
                                }),
                              options: RetentionOption.all.map { ($0.id, $0.name) })
                }
            }

            HStack {
                QuietButton(title: "Sign Out", destructive: true) { confirmSignOut = true }
                    .confirmationDialog("Sign out of Fovea?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                        Button("Sign Out", role: .destructive) {}
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Captures stay on this Mac. You’ll need to sign in again to deliver captures.")
                    }
                Spacer()
            }
            .padding(.top, Tokens.Space.s)
        }
    }
}
