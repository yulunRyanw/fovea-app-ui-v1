import Foundation
import Observation

// An Agent task is one delivered payload that an Agent is working on. The Island's hover
// list shows them; it never shows execution steps or logs.

public enum AgentTaskState: String, Codable, Hashable, CaseIterable, Sendable {
    case working, needsYou, complete, failed

    public var label: String {
        switch self {
        case .working: return "Working"
        case .needsYou: return "Needs you"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    /// Hover-list order: what needs the user first, then what is done, then what is
    /// running, then what failed.
    public var rank: Int {
        switch self {
        case .needsYou: return 0
        case .complete: return 1
        case .working: return 2
        case .failed: return 3
        }
    }

    /// Only these interrupt the user.
    public var isMeaningful: Bool { self != .working }
}

public struct AgentTask: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var state: AgentTaskState
    public var destination: AppRef
    public var chatName: String
    /// One line on what the Agent is doing right now ("Running tests"). A summary, never
    /// a step log.
    public var activity: String
    public var updatedAt: Date
    /// The capture this task came from, when Fovea created it.
    public var captureId: String?

    public init(id: String, title: String, state: AgentTaskState, destination: AppRef,
                chatName: String, activity: String = "", updatedAt: Date, captureId: String? = nil) {
        self.id = id; self.title = title; self.state = state; self.destination = destination
        self.chatName = chatName; self.activity = activity; self.updatedAt = updatedAt; self.captureId = captureId
    }

    /// Rank ascending, then most recent first.
    public static func displayOrder(_ a: AgentTask, _ b: AgentTask) -> Bool {
        if a.state.rank != b.state.rank { return a.state.rank < b.state.rank }
        return a.updatedAt > b.updatedAt
    }

    public static func sorted(_ tasks: [AgentTask]) -> [AgentTask] { tasks.sorted(by: displayOrder) }
}

/// Store: the live list of Agent tasks. Shared by the Island (writes on Send, reads for
/// the hover list) and the window (Home can surface task state). In-memory for the prototype.
@MainActor @Observable
public final class TaskLedger {
    public private(set) var tasks: [AgentTask]

    public init(tasks: [AgentTask] = []) { self.tasks = tasks }

    public var sorted: [AgentTask] { AgentTask.sorted(tasks) }

    public func upsert(_ task: AgentTask) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) { tasks[i] = task } else { tasks.append(task) }
    }

    public func update(id: String, _ change: (inout AgentTask) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[i])
    }

    public func remove(id: String) { tasks.removeAll { $0.id == id } }

    public func removeAll() { tasks.removeAll() }
}
