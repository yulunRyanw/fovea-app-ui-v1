import AppKit
import FoveaCore

/// `FoveaLab --smoke`: drives the lab through every palette action on the live window,
/// logs the window frame and the neck at each step to stderr, and quits with 0.
@MainActor
enum LabSmoke {
    static func run(state: LabState, dock: NotchDock) {
        Task { @MainActor in
            // Watchdog: a hung step must not leave the lab open forever.
            Task.detached { try? await Task.sleep(for: .seconds(25)); FileHandle.standardError.write(Data("smoke: TIMEOUT\n".utf8)); exit(2) }
            func log(_ s: String) { FileHandle.standardError.write(Data("smoke: \(s)\n".utf8)) }
            @MainActor func frame() -> String {
                let f = dock.window.frame
                return "window=(\(Int(f.minX)), \(Int(f.minY)), \(Int(f.width)), \(Int(f.height))) neckAlpha=\(String(format: "%.2f", dock.neckAlpha)) neckHeight=\(Int(dock.neckFrame.height)) atDock=\(dock.atDock)"
            }
            func sleep(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
            await sleep(900)
            let home = dock.dockFrame()
            log("open: \(frame()) dock=(\(Int(home.minX)), \(Int(home.minY)))")
            var ok = dock.window.frame == home && dock.neckAlpha > 0.99 && dock.window.contentView?.alphaValue == 1

            for d in LabDirection.allCases {
                state.direction = d
                await sleep(350)
                log("direction \(d.rawValue) shown")
            }
            state.direction = .threads
            await sleep(300)

            let before = state.captures.count
            state.sendCapture()
            await sleep(120)
            log("send: captures \(before)→\(state.captures.count) recent=\(state.recentCaptureId ?? "nil") neck during pulse: \(frame())")
            ok = ok && state.captures.count == before + 1 && state.recentCaptureId != nil && dock.neckFrame.height > NeckPanel.frame(for: dock.metrics).height + 3
            await sleep(600)
            log("after pulse: \(frame())")
            ok = ok && Int(dock.neckFrame.height) == Int(NeckPanel.frame(for: dock.metrics).height)

            state.docked = false
            await sleep(900)
            log("undocked: \(frame())")
            ok = ok && !dock.atDock && dock.neckAlpha < 0.01 && Int(dock.window.frame.minY) == Int(home.minY - 72)

            state.docked = true
            await sleep(900)
            log("re-docked: \(frame())")
            ok = ok && dock.atDock && dock.neckAlpha > 0.99 && dock.window.frame == home

            state.agentNeedsYou()
            await sleep(100)
            let needs = state.ledger.tasks.filter { $0.state == .needsYou }.count
            state.completeTask()
            await sleep(100)
            let complete = state.ledger.tasks.filter { $0.state == .complete }.count
            log("tasks: needsYou=\(needs) complete=\(complete) spaces=\(state.spaces.count)")
            ok = ok && needs >= 1 && complete >= 2

            state.reset()
            await sleep(100)
            log("reset: captures=\(state.captures.count) tasks=\(state.ledger.tasks.count)")
            ok = ok && state.captures.count == Fixtures.captures().count

            state.reduceMotion = true
            state.docked = false
            await sleep(400)
            state.docked = true
            await sleep(400)
            log("reduce motion dock cycle: \(frame())")
            ok = ok && dock.atDock

            log(ok ? "PASS" : "FAIL")
            exit(ok ? 0 : 1)
        }
    }
}
