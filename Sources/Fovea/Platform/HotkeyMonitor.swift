import AppKit
import ApplicationServices
import Carbon.HIToolbox
import IOKit.hid
import FoveaCore

/// Global press-to-toggle hotkeys. One press starts a session, the next press of the same
/// shortcut ends it; key repeat and releases never reach the Island.
///
/// Chords on a regular key go through Carbon `RegisterEventHotKey`: no permission needed,
/// and the chord never reaches the frontmost app. Bindings on the fn (Globe) key cannot be
/// registered that way, so they are watched as modifier-flag changes through NSEvent
/// monitors, which macOS only delivers to apps trusted for Accessibility (or Input
/// Monitoring). A plain fn tap fires when fn is released without any other key pressed in
/// between; fn plus ⌃ ⌥ ⇧ ⌘ fires on the same release; fn used as a modifier for another
/// key (fn+←, fn+F5) is left alone, and so is the system's own Globe-key action.
@MainActor
final class HotkeyMonitor: HotkeyMonitoring {
    let events: AsyncStream<HotkeyEvent>
    private let continuation: AsyncStream<HotkeyEvent>.Continuation

    // Carbon chords
    private var handler: EventHandlerRef?
    private var registrations: [UInt32: EventHotKeyRef] = [:]
    private var carbonBindings: [UInt32: (ShortcutAction, KeyBinding)] = [:]
    private var escapeRef: EventHotKeyRef?
    /// Chord currently held, and the timer that notices when its modifiers let go first.
    private var held: ShortcutAction?
    private var modifierWatch: Timer?

    // fn key: an event tap suppresses the bare tap (emoji picker) and reports it here.
    private var functionBindings: [ShortcutAction: KeyBinding] = [:]
    private let fnTap = FunctionKeyTap()
    private var accessibilityPrompted = false
    /// Polls for Accessibility trust so the fn tap starts the moment it is granted.
    private var trustRetry: Timer?
    /// Fallback detection: NSEvent monitors are a different subsystem from the event tap,
    /// so if the tap is installed but silently receives nothing, these still fire the
    /// shortcut (the emoji picker is then not suppressed, but the hotkey works).
    private var flagMonitors: [Any] = []
    private var fbDown = false
    private var fbMods: KeyBinding.Modifiers = []
    private var fbUsedWithKey = false
    /// When the tap last reported an fn edge, so the fallback does not double-fire.
    private var lastTapEdge = Date.distantPast
    /// The Shortcuts page listens to raw fn edges through this while recording a chord.
    private var recordingSink: (@MainActor (FunctionKeyTransition) -> Void)?

    private var suspended = false

    private static let signature: OSType = 0x464F5641   // 'FOVA'
    private static let escapeID: UInt32 = 900

    init() {
        var c: AsyncStream<HotkeyEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .bufferingNewest(16)) { c = $0 }
        continuation = c
        fnTap.onTransition = { [weak self] transition in self?.handleFunctionKey(transition) }
    }

    // MARK: HotkeyMonitoring

    func start(bindings: [ShortcutAction: KeyBinding]) throws {
        try installHandlerIfNeeded()
        try update(bindings: bindings)
    }

    func update(bindings: [ShortcutAction: KeyBinding]) throws {
        unregisterAll()
        var firstError: Error?
        for (index, action) in ShortcutAction.allCases.enumerated() {
            guard let binding = bindings[action] else { continue }
            if binding.isFunctionKey {
                functionBindings[action] = binding
                continue
            }
            let id = UInt32(index + 1)
            do {
                let ref = try register(keyCode: UInt32(binding.keyCode), modifiers: Self.carbonModifiers(binding.modifiers), id: id)
                registrations[id] = ref
                carbonBindings[id] = (action, binding)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if functionBindings.isEmpty {
            fnTap.stop()
            removeFallbackMonitors()
            stopTrustRetry()
        } else if !Self.canWatchKeyboard {
            Self.log("fn needs Accessibility (trusted=\(AXIsProcessTrusted()), inputMonitoring=\(Self.inputMonitoringGranted)); prompting and polling")
            promptForAccessibilityOnce()
            // The app was likely launched before Accessibility was granted; poll so the fn
            // key starts working the moment the user flips the switch, without a relaunch.
            startTrustRetry()
            if firstError == nil { firstError = HotkeyError.needsAccessibility }
        } else {
            fnTap.start()
            installFallbackMonitors()
            stopTrustRetry()
            Self.log("fn tap started at launch (trusted=\(AXIsProcessTrusted()), inputMonitoring=\(Self.inputMonitoringGranted), mode=\(fnTap.mode))")
        }
        if let firstError { throw firstError }
    }

    /// Retries the fn tap once Accessibility is granted, so no relaunch is needed.
    private func startTrustRetry() {
        guard trustRetry == nil else { return }
        trustRetry = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.functionBindings.isEmpty, Self.canWatchKeyboard else { return }
                self.fnTap.start()
                self.installFallbackMonitors()
                self.stopTrustRetry()
                Self.log("Accessibility granted; fn tap started (mode=\(self.fnTap.mode))")
            }
        }
    }

    private func stopTrustRetry() {
        trustRetry?.invalidate()
        trustRetry = nil
    }

    func setEscapeCapture(_ enabled: Bool) {
        if enabled, escapeRef == nil {
            escapeRef = try? register(keyCode: UInt32(kVK_Escape), modifiers: 0, id: Self.escapeID)
        } else if !enabled, let ref = escapeRef {
            UnregisterEventHotKey(ref)
            escapeRef = nil
        }
    }

    func setSuspended(_ suspended: Bool) {
        self.suspended = suspended
    }

    func setRecordingSink(_ sink: (@MainActor (FunctionKeyTransition) -> Void)?) {
        recordingSink = sink
        // While recording, the tap keeps swallowing so an fn tap never opens the picker,
        // but the recorder needs the edges even when a session would not start.
    }

    func stop() {
        unregisterAll()
        setEscapeCapture(false)
        fnTap.stop()
        removeFallbackMonitors()
        stopTrustRetry()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        modifierWatch?.invalidate()
        modifierWatch = nil
    }

    // MARK: - Carbon plumbing

    private func installHandlerIfNeeded() throws {
        guard handler == nil else { return }
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            let id = hotKeyID.id
            // Carbon delivers on the main thread.
            MainActor.assumeIsolated { monitor.handle(id: id, pressed: pressed) }
            return noErr
        }, specs.count, &specs, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw HotkeyError.installFailed(status) }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: UInt32) throws -> EventHotKeyRef {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            throw status == OSStatus(eventHotKeyExistsErr) ? HotkeyError.taken : HotkeyError.registerFailed(status)
        }
        return ref
    }

    private func unregisterAll() {
        for ref in registrations.values { UnregisterEventHotKey(ref) }
        registrations.removeAll()
        carbonBindings.removeAll()
        functionBindings.removeAll()
        held = nil
    }

    private func handle(id: UInt32, pressed: Bool) {
        if id == Self.escapeID {
            if pressed { continuation.yield(.escape) }
            return
        }
        guard let (action, binding) = carbonBindings[id] else { return }
        if pressed {
            // Carbon repeats presses while held; only the first one matters.
            guard held == nil else { return }
            held = action
            fire(action)
            watchModifiers(binding.modifiers)
        } else {
            release(action)
        }
    }

    private func release(_ action: ShortcutAction) {
        guard held == action else { return }
        held = nil
        modifierWatch?.invalidate()
        modifierWatch = nil
    }

    /// If the user lets go of ⌥ before Space, Carbon may not send the release; the
    /// modifier state tells us the chord is over and the next press should count.
    private func watchModifiers(_ required: KeyBinding.Modifiers) {
        modifierWatch?.invalidate()
        guard !required.isEmpty else { return }
        modifierWatch = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let action = self.held else { return }
                let flags = KeyBinding.Modifiers(NSEvent.modifierFlags)
                if !flags.isSuperset(of: required) { self.release(action) }
            }
        }
    }

    private static func carbonModifiers(_ m: KeyBinding.Modifiers) -> UInt32 {
        var out: UInt32 = 0
        if m.contains(.command) { out |= UInt32(cmdKey) }
        if m.contains(.option) { out |= UInt32(optionKey) }
        if m.contains(.shift) { out |= UInt32(shiftKey) }
        if m.contains(.control) { out |= UInt32(controlKey) }
        return out
    }

    // MARK: - fn key

    /// Global monitors need Accessibility trust; Input Monitoring works too.
    private static var canWatchKeyboard: Bool { AXIsProcessTrusted() || inputMonitoringGranted }

    private static var inputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// `FOVEA_ISLAND_LOG=1`: permission and tap state on stderr, so a bundle launched with
    /// `open --env FOVEA_ISLAND_LOG=1 --stderr <file>` can be diagnosed without a debugger.
    private static func log(_ message: String) {
        guard ProcessInfo.processInfo.environment["FOVEA_ISLAND_LOG"] != nil else { return }
        FileHandle.standardError.write(Data("hotkeys: \(message)\n".utf8))
    }

    private func promptForAccessibilityOnce() {
        guard !accessibilityPrompted else { return }
        accessibilityPrompted = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func installFallbackMonitors() {
        guard flagMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.observeFallback(event) }
        }) { flagMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.observeFallback(event) }
            return event
        }) { flagMonitors.append(local) }
    }

    private func removeFallbackMonitors() {
        for m in flagMonitors { NSEvent.removeMonitor(m) }
        flagMonitors.removeAll()
        fbDown = false
    }

    /// Only acts when the event tap is not reporting; otherwise the tap owns the fn key.
    private func observeFallback(_ event: NSEvent) {
        let mods = KeyBinding.Modifiers(event.modifierFlags)
        switch event.type {
        case .keyDown:
            if fbDown { fbUsedWithKey = true }
        case .flagsChanged where Int(event.keyCode) == kVK_Function:
            if event.modifierFlags.contains(.function) {
                guard !fbDown else { return }
                fbDown = true; fbMods = mods; fbUsedWithKey = false
            } else if fbDown {
                fbDown = false
                guard !fbUsedWithKey else { return }
                // The tap already handled this press if it reported an edge just now.
                guard Date().timeIntervalSince(lastTapEdge) > 0.3 else { return }
                log("fallback fn up mods=\(fbMods.rawValue) (tap silent)")
                if let (action, _) = functionBindings.first(where: { $0.value.modifiers == fbMods }) {
                    fire(action)
                }
            }
        case .flagsChanged:
            if fbDown { fbMods.formUnion(mods) }
        default:
            break
        }
    }

    private func log(_ message: String) {
        guard ProcessInfo.processInfo.environment["FOVEA_ISLAND_LOG"] != nil else { return }
        FileHandle.standardError.write(Data("hotkey: \(message)\n".utf8))
    }

    private func handleFunctionKey(_ transition: FunctionKeyTransition) {
        lastTapEdge = Date()
        log("tap \(transition.kind) mods=\(transition.modifiers.rawValue)")
        recordingSink?(transition)
        // A bare fn tap (no other key pressed while held) fires the matching binding.
        if case .up(false) = transition.kind,
           let (action, _) = functionBindings.first(where: { $0.value.modifiers == transition.modifiers }) {
            fire(action)
        }
    }

    private func fire(_ action: ShortcutAction) {
        guard !suspended else { log("suppressed (recording) \(action)"); return }
        log("fire \(action)")
        continuation.yield(.pressed(action))
    }
}

enum HotkeyError: Error, LocalizedError {
    case taken
    case needsAccessibility
    case installFailed(OSStatus)
    case registerFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .taken: return "That shortcut is taken by another app."
        case .needsAccessibility: return "The fn shortcut needs Accessibility access. Grant it in System Settings › Privacy & Security."
        case .installFailed(let s): return "Couldn’t listen for shortcuts (\(s))."
        case .registerFailed(let s): return "Couldn’t register the shortcut (\(s))."
        }
    }
}
