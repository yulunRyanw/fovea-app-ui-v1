import AppKit
import Carbon.HIToolbox
import FoveaCore

/// Watches the fn (Globe) key with an active `CGEventTap`, so a bare fn tap can be
/// swallowed before macOS turns it into the emoji picker, while still telling Fovea the
/// key was pressed. fn used as a modifier for another key (fn+←, fn+F5) is left alone,
/// because the keyboard driver translates those before the tap sees them.
///
/// The tap sits at the session level (an HID-level tap needs root) and on its own run
/// loop so a stalled main thread never delays the keyboard. It needs Accessibility, which
/// Fovea already requires for its hotkeys. The callback runs off the main actor, so the
/// state it touches is lock-guarded and `nonisolated`.
@MainActor
final class FunctionKeyTap {
    enum Mode: Sendable { case active, listenOnly, unavailable }

    /// Called on the main actor for every fn edge.
    var onTransition: ((FunctionKeyTransition) -> Void)?
    private(set) var mode: Mode = .unavailable
    /// How many fn taps were swallowed (the emoji eval reads this).
    private(set) var swallowCount = 0

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?

    /// State shared with the callback thread, all under `Shared.lock`.
    private final class Shared: @unchecked Sendable {
        let lock = NSLock()
        var fnDown = false
        var modifiersSeen: KeyBinding.Modifiers = []
        var usedWithKey = false
        var suppressing = false
        weak var owner: FunctionKeyTap?
        var tap: CFMachPort?
    }
    private let shared = Shared()

    init() { shared.owner = self }

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(shared).toOpaque()
        func make(_ options: CGEventTapOptions) -> CFMachPort? {
            CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: options,
                              eventsOfInterest: mask, callback: Self.callback, userInfo: refcon)
        }
        if let active = make(.defaultTap) {
            tap = active; mode = .active
            shared.lock.lock(); shared.suppressing = true; shared.lock.unlock()
        } else if let listen = make(.listenOnly) {
            tap = listen; mode = .listenOnly
        } else {
            mode = .unavailable
            return
        }
        guard let tap else { return }
        shared.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        let thread = Thread {
            guard let source else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "fovea.fn-tap"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
        if ProcessInfo.processInfo.environment["FOVEA_ISLAND_LOG"] != nil { FileHandle.standardError.write(Data("fn-tap: mode=\(mode)\n".utf8)) }
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopSourceInvalidate(source) }
        tap = nil; runLoopSource = nil; thread = nil
        shared.tap = nil
        mode = .unavailable
    }

    /// Reported by the callback thread; hops to the main actor.
    fileprivate func report(_ transition: FunctionKeyTransition, swallowed: Bool) {
        if swallowed { swallowCount += 1 }
        if ProcessInfo.processInfo.environment["FOVEA_ISLAND_LOG"] != nil { FileHandle.standardError.write(Data("fn-tap: \(transition.kind) mods=\(transition.modifiers.rawValue)\n".utf8)) }
        onTransition?(transition)
    }

    // MARK: - Callback (runs on the tap thread)

    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let shared = Unmanaged<Shared>.fromOpaque(refcon).takeUnretainedValue()
        return handle(shared: shared, type: type, event: event)
    }

    private static func handle(shared: Shared, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = shared.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        // Never touch the keyboard while another app holds secure input.
        if IsSecureEventInputEnabled() { return pass }

        let flags = event.flags
        let modifiers = modifiers(from: flags)

        if type == .keyDown {
            shared.lock.lock(); if shared.fnDown { shared.usedWithKey = true }; shared.lock.unlock()
            return pass
        }
        guard type == .flagsChanged else { return pass }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_Function) else {
            shared.lock.lock(); if shared.fnDown { shared.modifiersSeen.formUnion(modifiers) }; shared.lock.unlock()
            return pass
        }

        let isDown = flags.contains(.maskSecondaryFn)
        var suppressEdge = false
        var transition: FunctionKeyTransition?
        shared.lock.lock()
        if isDown {
            if !shared.fnDown {
                shared.fnDown = true; shared.modifiersSeen = modifiers; shared.usedWithKey = false
                transition = FunctionKeyTransition(kind: .down, modifiers: modifiers)
            }
            suppressEdge = true
        } else if shared.fnDown {
            shared.fnDown = false
            transition = FunctionKeyTransition(kind: .up(usedWithKey: shared.usedWithKey), modifiers: shared.modifiersSeen)
            suppressEdge = true
        }
        let suppressing = shared.suppressing
        let owner = shared.owner
        shared.lock.unlock()

        if let transition {
            let swallowed = suppressing && { if case .up(false) = transition.kind { return true }; return false }()
            Task { @MainActor in owner?.report(transition, swallowed: swallowed) }
        }
        // Swallow both edges of a bare/chorded fn so the system's Globe action never runs.
        // fn-as-a-modifier keeps working: its other key's keyDown is delivered normally.
        return (suppressEdge && suppressing) ? nil : pass
    }

    private static func modifiers(from flags: CGEventFlags) -> KeyBinding.Modifiers {
        var m: KeyBinding.Modifiers = []
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        return m
    }
}
