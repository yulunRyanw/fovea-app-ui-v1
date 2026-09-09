import SwiftUI
import AppKit
import FoveaCore

/// The control panel: a floating, non-activating utility panel that follows the lab window.
@MainActor
final class LabPaletteController {
    let panel: NSPanel
    private let state: LabState
    private weak var follows: NSWindow?
    private var observers: [Any] = []

    init(state: LabState, follows window: NSWindow) {
        self.state = state
        self.follows = window
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
                        styleMask: [.titled, .utilityWindow, .nonactivatingPanel, .closable],
                        backing: .buffered, defer: false)
        panel.title = "Fovea Lab"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: LabControls().environment(state))
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.follow() }
        })
        observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.follow() }
        })
    }

    func show() { follow(); panel.orderFront(nil) }
    func hide() { panel.orderOut(nil) }

    /// Sits to the right of the lab window, top-aligned; falls to the left when there is no room.
    func follow() {
        guard let w = follows, let screen = w.screen ?? NSScreen.main else { return }
        let f = w.frame
        var x = f.maxX + 12
        if x + panel.frame.width > screen.visibleFrame.maxX { x = f.minX - 12 - panel.frame.width }
        let y = f.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: max(screen.visibleFrame.minY, y)))
    }
}

struct LabControls: View {
    @Environment(LabState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            Picker("Direction", selection: $state.direction) {
                ForEach(LabDirection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Toggle("Docked to the notch", isOn: $state.docked)
            Toggle("Neck", isOn: $state.showsNeck).disabled(!state.docked)
            Toggle("Reduce Motion", isOn: $state.reduceMotion)

            HStack {
                Text("Canvas").frame(width: 56, alignment: .leading)
                Picker("Canvas", selection: $state.canvas) {
                    ForEach(LabCanvas.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            HStack {
                Text("Motion").frame(width: 56, alignment: .leading)
                Slider(value: $state.motionScale, in: 0.5...3, step: 0.25)
                Text(String(format: "%.2g×", state.motionScale)).monospacedDigit().frame(width: 40, alignment: .trailing)
            }

            Divider()

            HStack {
                Button("Send a capture") { state.sendCapture() }
                Button("Agent needs you") { state.agentNeedsYou() }
            }
            HStack {
                Button("Complete a task") { state.completeTask() }
                Button("Reset") { state.reset() }
            }
            Button("Snapshot this direction") { LabSnapshots.snapshotCurrent(state) }

            Divider()
            Text("⌘1–⌘4 direction · ⌘⇧L palette · ⌘K search\n⌘+ ⌘− Studio zoom · ⌘[ ⌘] Spaces · Esc closes")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 320, alignment: .topLeading)
    }
}
