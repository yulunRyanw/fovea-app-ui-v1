import SwiftUI
import AppKit
import FoveaCore

struct EyeTrackingPage: View {
    @Environment(AppModel.self) private var model
    @State private var calibrating = false
    @State private var lastCalibrated = "3 days ago"
    @State private var testingGaze = false

    private var accessibilityGranted: Bool { model.permissions[.accessibility] ?? true }
    private var enabled: Bool { model.settings.settings.eyeTrackingEnabled }

    var body: some View {
        SettingsPage(title: "Eye Tracking") {
            SettingsSection("Tracking", child: .tracking) {
                SettingsGroup {
                    ToggleRow(label: "Use Eye Tracking", key: .eyeTrackingEnabled, isOn: Binding(
                        get: { enabled },
                        set: { v in model.settings.update(.eyeTrackingEnabled) { $0.eyeTrackingEnabled = v } }))
                }
            }

            SettingsSection("Calibration", child: .calibration) {
                SettingsGroup {
                    ActionRow(label: "Calibrate",
                              detail: calibrating ? "Follow the dot…" : "Last calibrated \(lastCalibrated)",
                              actionTitle: calibrating ? "Calibrating…" : "Calibrate",
                              disabled: !enabled || !accessibilityGranted || calibrating,
                              disabledReason: !enabled ? "Turn on Use Eye Tracking first"
                                : "Calibration needs Accessibility access",
                              inlineStatus: accessibilityGranted ? nil
                                : ("Accessibility access is off", .warning, "Open System Settings", openAccessibilitySettings)) {
                        calibrating = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(1500))
                            calibrating = false
                            lastCalibrated = "just now"
                        }
                    }
                    GroupDivider()
                    ActionRow(label: "Test Gaze",
                              detail: testingGaze ? "Look around the screen — the indicator follows your gaze." : nil,
                              actionTitle: testingGaze ? "Stop" : "Test Gaze",
                              disabled: !enabled,
                              disabledReason: "Turn on Use Eye Tracking first") {
                        testingGaze.toggle()
                    }
                }
            }
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
