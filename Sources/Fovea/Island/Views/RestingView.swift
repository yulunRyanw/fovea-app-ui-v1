import SwiftUI
import FoveaCore

/// The resting island is just the notch: no protrusion, no dot, no count. Whether an Agent
/// is working shows only when the user hovers the task list.
struct RestingView: View {
    let tasks: [AgentTask]
    let notchHeight: CGFloat

    private var active: Bool { tasks.contains { $0.state == .working || $0.state == .needsYou } }

    var body: some View {
        Color.clear
            .frame(height: notchHeight)
            .accessibilityLabel(active ? "Fovea. An Agent is working." : "Fovea")
    }
}
