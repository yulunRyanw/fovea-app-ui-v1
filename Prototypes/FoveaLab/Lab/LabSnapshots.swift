import SwiftUI
import AppKit
import FoveaCore

/// `FoveaLab --snapshot <dir>` renders every direction at rest and open, then exits.
@MainActor
enum LabSnapshots {
    struct Shot {
        let name: String
        let direction: LabDirection
        var openId: String? = nil
        var canvas: LabCanvas = .warm
    }

    static let shots: [Shot] = [
        Shot(name: "paper", direction: .paper),
        Shot(name: "paper-open", direction: .paper, openId: "cap-figma"),
        Shot(name: "studio", direction: .studio),
        Shot(name: "studio-open", direction: .studio, openId: "ref-mountain"),
        Shot(name: "spaces", direction: .spaces),
        Shot(name: "spaces-open", direction: .spaces, openId: "cursor/Settings shell"),
        Shot(name: "threads", direction: .threads),
        Shot(name: "threads-open", direction: .threads, openId: "cap-figma"),
    ]

    static func run(dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for shot in shots {
            let state = LabState()
            state.direction = shot.direction
            state.canvas = shot.canvas
            state.openId = shot.openId
            if shot.direction == .spaces, let id = shot.openId { state.selectedSpaceId = id }
            write(state, to: dir.appendingPathComponent("\(shot.name).png"))
        }
    }

    static func snapshotCurrent(_ state: LabState) {
        let dir = URL(fileURLWithPath: "shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        write(state, to: dir.appendingPathComponent("\(state.direction.rawValue)-\(stamp).png"))
    }

    private static func write(_ state: LabState, to url: URL) {
        let view = LabRootView().environment(state).environment(\.snapshotMode, true)
        guard let rep = render(view, size: Tokens.Layout.window),
              let data = rep.representation(using: .png, properties: [:]) else { print("failed \(url.lastPathComponent)"); return }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }

    /// Renders through a real offscreen window so scroll views and controls lay out as in the app.
    static func render<V: View>(_ view: V, size: CGSize) -> NSBitmapImageRep? {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.appearance = NSAppearance(named: .aqua)
        window.setFrameOrigin(NSPoint(x: 0, y: 0))
        window.orderFrontRegardless()
        for _ in 0..<3 {
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        }
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)
        return rep
    }
}
