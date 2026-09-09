import Foundation

// The Island and the window never import each other. When the Island needs the window
// (Take me there, permission repair), it posts a command here and the window side
// handles it.

public enum AppCommand: Hashable, Sendable {
    /// Bring the main window forward at a route.
    case openMain(AppRoute)
    /// Open the exact result of a task: its capture, and the destination app.
    case revealTask(AgentTask)
    /// Open the System Settings pane for a permission.
    case openSystemSettings(SystemPermission)
}

public final class AppCommandBus: @unchecked Sendable {
    public let commands: AsyncStream<AppCommand>
    private let continuation: AsyncStream<AppCommand>.Continuation

    public init() {
        var c: AsyncStream<AppCommand>.Continuation!
        commands = AsyncStream(bufferingPolicy: .bufferingNewest(8)) { c = $0 }
        continuation = c
    }

    public func post(_ command: AppCommand) { continuation.yield(command) }
}
