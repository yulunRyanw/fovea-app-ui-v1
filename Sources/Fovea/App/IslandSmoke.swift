import AppKit
import FoveaCore

/// `--demo island-smoke`: drives the live Island through every transition with the
/// simulated services, printing the phase and window state after each step, then quits.
/// A regression check that runs on the real panel without a pointer or a microphone.
@MainActor
enum IslandSmoke {
    static func run(controller: IslandController) {
        let model = controller.model
        let start = Date()
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { n in
            let who = (n.object as? NSWindow)?.accessibilityIdentifier() ?? "?"
            let now = NSApp.keyWindow.map { $0.accessibilityIdentifier().isEmpty ? $0.title : $0.accessibilityIdentifier() } ?? "none"
            print(String(format: "  [%.2fs] resigned key: %@ → key now: %@ active=%@ frontmost=%@", Date().timeIntervalSince(start), who, now,
                         NSApp.isActive ? "yes" : "no", NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"))
        }
        Task { @MainActor in
            @MainActor func step(_ label: String, _ event: IslandEvent? = nil, wait ms: Int = 900) async {
                if let event { model.send(event) }
                try? await Task.sleep(for: .milliseconds(ms))
                let panels = NSApp.windows.compactMap { $0 as? NSPanel }
                let notch = panels.first { $0.accessibilityIdentifier() == "fovea.island" }
                let detached = panels.first { $0.accessibilityIdentifier() == "fovea.quick-answer" }
                let b = model.contentBounds
                let responder = notch?.firstResponder.map { String(describing: type(of: $0)) } ?? "-"
                print(String(format: "%-26@ phase=%@ bounds=%.0fx%.0f@(%.0f,%.0f) key=%@ responder=%@ visible=%@ detached=%@ level=%d",
                             label as NSString, "\(model.phase)" as NSString, b.width, b.height, b.minX, b.minY,
                             (notch?.isKeyWindow ?? false) ? "yes" : "no", responder as NSString,
                             (notch?.isVisible ?? false) ? "yes" : "no",
                             (detached?.isVisible ?? false) ? "yes" : "no", notch?.level.rawValue ?? -1))
            }
            await step("start")
            await step("hover in", .pointerZoneChanged(.inside))
            await step("hover dwell", .hoverDwellElapsed)
            await step("hover out", .pointerZoneChanged(.outside), wait: 1200)
            await step("press fn (voice)", .hotkeyPressed(.voiceFlow), wait: 1500)
            await step("press fn again", .hotkeyPressed(.voiceFlow), wait: 3500)
            await step("edit", .editTranscript("Make the empty state explain what Fovea can see."))
            await step("expand stack", .setStackExpanded(true))
            await step("open selector", .toggleSelector)
            await step("new chat", .selectorNewChat)
            await step("choose AI", .chooseDestination(Fixtures.claudeCode), wait: 400)
            await step("choose folder", .chooseFolder(Fixtures.folderFovea))
            await step("escape (back one step)", .escape)
            await step("escape (closes selector)", .escape)
            await step("send", .send, wait: 1500)
            await step("press fn ⌃ (quick)", .hotkeyPressed(.quickAnswer), wait: 1500)
            await step("press fn ⌃ again", .hotkeyPressed(.quickAnswer), wait: 4500)
            await step("follow-up text", .editFollowUp("How is it measured?"))
            await step("submit follow-up", .submitFollowUp, wait: 3000)
            await step("detach", .detach, wait: 1200)
            await step("dock: near", .setDockZone(.near))
            await step("dock: ready", .setDockZone(.ready))
            await step("redock", .redock, wait: 1200)
            await step("escape (closes QA)", .escape)
            await step("hover again", .pointerZoneChanged(.inside))
            await step("hover dwell", .hoverDwellElapsed, wait: 600)
            await step("done")
            NSApp.terminate(nil)
        }
    }
}
