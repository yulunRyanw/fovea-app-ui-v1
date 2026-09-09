import Foundation
import Observation

/// Store: the capture history Home shows. The Island appends on Send; the window reads.
/// In-memory, seeded from fixtures, in the prototype.
@MainActor @Observable
public final class CaptureLog {
    public private(set) var captures: [Capture]

    public init(captures: [Capture]) { self.captures = captures }

    public func append(_ capture: Capture) { captures.insert(capture, at: 0) }

    public func update(id: String, _ change: (inout Capture) -> Void) {
        guard let i = captures.firstIndex(where: { $0.id == id }) else { return }
        change(&captures[i])
    }

    public func capture(_ id: String) -> Capture? { captures.first { $0.id == id } }
}
