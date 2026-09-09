import SwiftUI
import AppKit
import FoveaCore

@main
struct FoveaLabMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = LabAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class LabAppDelegate: NSObject, NSApplicationDelegate {
    let state = LabState()
    var windowController: LabWindowController?
    var palette: LabPaletteController?
    var dock: NotchDock?
    private var paletteWatch: Task<Void, Never>?

    func applicationWillFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), args.count > i + 1 {
            LabSnapshots.run(dir: URL(fileURLWithPath: args[i + 1], isDirectory: true))
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = LabMenu.make()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--direction"), args.count > i + 1, let d = LabDirection(rawValue: args[i + 1]) {
            state.direction = d
        }
        if args.contains("--undocked") { state.docked = false }

        let controller = LabWindowController(state: state)
        windowController = controller
        let dock = NotchDock(window: controller.window, state: state)
        self.dock = dock
        dock.present()

        let palette = LabPaletteController(state: state, follows: controller.window)
        self.palette = palette
        if state.paletteVisible { palette.show() }
        paletteWatch = Task { [weak self] in
            // Mirror the palette toggle and the canvas choice onto AppKit state.
            var visible = true
            var canvas = LabCanvas.warm
            var docked = self?.state.docked ?? true
            var neck = self?.state.showsNeck ?? true
            var recent: String? = nil
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(60))
                guard let self else { return }
                if self.state.paletteVisible != visible {
                    visible = self.state.paletteVisible
                    visible ? self.palette?.show() : self.palette?.hide()
                }
                if self.state.canvas != canvas {
                    canvas = self.state.canvas
                    self.windowController?.window.backgroundColor = canvas.nsColor
                }
                if self.state.docked != docked {
                    docked = self.state.docked
                    self.dock?.setDocked(docked)
                }
                if self.state.showsNeck != neck {
                    neck = self.state.showsNeck
                    self.dock?.updateNeck(duration: 0.12)
                }
                if self.state.recentCaptureId != recent {
                    recent = self.state.recentCaptureId
                    if recent != nil { self.dock?.pulseNeck() }
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        if args.contains("--smoke") { LabSmoke.run(state: state, dock: dock) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The minimum menu bar a manual NSApplication needs: Quit, the Edit verbs text fields
/// rely on, and Close.
enum LabMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        let app = NSMenuItem(); main.addItem(app)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Fovea Lab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.submenu = appMenu
        let edit = NSMenuItem(); main.addItem(edit)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        let window = NSMenuItem(); main.addItem(window)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.submenu = windowMenu
        return main
    }
}
