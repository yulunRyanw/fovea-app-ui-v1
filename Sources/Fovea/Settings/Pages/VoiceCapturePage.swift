import SwiftUI
import AppKit
import FoveaCore

struct VoiceCapturePage: View {
    @Environment(AppModel.self) private var model

    private var settings: SettingsModel { model.settings }
    private var micGranted: Bool { model.permissions[.microphone] ?? true }

    var body: some View {
        SettingsPage(title: "Voice & Capture") {
            SettingsSection("Audio", child: .audio) {
                SettingsGroup {
                    if !micGranted {
                        StatusRow(label: "Microphone access", status: "Off", kind: .warning,
                                  actionTitle: "Open System Settings", action: openMicrophoneSettings)
                        GroupDivider()
                    }
                    SelectRow(label: "Microphone", key: .microphoneId,
                              selection: Binding(
                                get: { settings.settings.microphoneId ?? "default" },
                                set: { id in settings.update(.microphoneId) { $0.microphoneId = id == "default" ? nil : id } }),
                              options: Fixtures.audioInputs.map { ($0.id, $0.name) })
                    GroupDivider()
                    ToggleRow(label: "Interaction Sounds", key: .interactionSounds, isOn: Binding(
                        get: { settings.settings.interactionSounds },
                        set: { v in settings.update(.interactionSounds) { $0.interactionSounds = v } }))
                }
            }

            SettingsSection("Voice Processing", child: .voiceProcessing) {
                SettingsGroup {
                    SegmentedControlRow(label: "Voice Processing",
                                        detail: settings.settings.voiceProcessing == .faithful
                                            ? "Keeps your original wording as closely as practical."
                                            : "Organizes your wording into a clearer final expression.",
                                        key: .voiceProcessing,
                                        selection: Binding(
                                            get: { settings.settings.voiceProcessing },
                                            set: { v in settings.update(.voiceProcessing) { $0.voiceProcessing = v } }),
                                        options: VoiceProcessing.allCases.map { ($0, $0.displayName) })
                }
            }
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
