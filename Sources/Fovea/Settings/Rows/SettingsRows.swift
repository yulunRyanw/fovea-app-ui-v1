import SwiftUI
import AppKit
import Carbon.HIToolbox
import FoveaCore

/// Label + optional one-line explanation on the left, control on the right.
/// When `key` is given the row shows its save state (failed → Retry).
struct SettingsRow<Control: View, Leading: View>: View {
    @Environment(AppModel.self) private var model
    let label: String
    var detail: String? = nil
    var key: UserSettings.Key? = nil
    let leading: Leading
    let control: Control

    init(label: String, detail: String? = nil, key: UserSettings.Key? = nil,
         @ViewBuilder leading: () -> Leading = { EmptyView() },
         @ViewBuilder control: () -> Control) {
        self.label = label; self.detail = detail; self.key = key
        self.leading = leading(); self.control = control()
    }

    private var state: RowSaveState { key.map { model.settings.state($0) } ?? .idle }

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.m) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(Tokens.Type_.rowLabel)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                if let detail {
                    Text(detail)
                        .font(Tokens.Type_.secondary)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if case .failed(let message) = state {
                    HStack(spacing: Tokens.Space.s) {
                        StatusLabel(text: message, kind: .warning)
                        Button("Retry") { if let key { model.settings.retry(key) } }
                            .buttonStyle(.plain)
                            .font(Tokens.Type_.captionMedium)
                            .foregroundStyle(Tokens.Colors.warning)
                            .underline()
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: Tokens.Space.l)
            control
        }
        .padding(.horizontal, Tokens.Layout.rowPaddingH)
        .padding(.vertical, Tokens.Layout.rowPaddingV)
        .frame(minHeight: Tokens.Layout.rowHeight)
        .accessibilityElement(children: .contain)
    }
}

struct ToggleRow: View {
    let label: String
    var detail: String? = nil
    var key: UserSettings.Key? = nil
    @Binding var isOn: Bool
    var disabled = false

    var body: some View {
        SettingsRow(label: label, detail: detail, key: key) {
            Toggle(label, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.regular)
                .labelsHidden()
                .disabled(disabled)
        }
    }
}

struct SelectRow<ID: Hashable>: View {
    let label: String
    var detail: String? = nil
    var key: UserSettings.Key? = nil
    @Binding var selection: ID
    let options: [(id: ID, name: String)]

    @State private var hovering = false
    @FocusState private var focused: Bool

    private var currentName: String { options.first { $0.id == selection }?.name ?? "" }

    var body: some View {
        SettingsRow(label: label, detail: detail, key: key) {
            Menu {
                ForEach(options, id: \.id) { option in
                    Button {
                        selection = option.id
                    } label: {
                        if option.id == selection {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(option.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: Tokens.Space.xs + 2) {
                    Text(currentName)
                        .font(Tokens.Type_.rowValue)
                        .foregroundStyle(Tokens.Colors.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
                .padding(.horizontal, Tokens.Space.m)
                .frame(height: Tokens.Layout.controlHeight)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.control)
                    .fill(hovering ? Tokens.Colors.hover : Tokens.Colors.elevated))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.control)
                    .strokeBorder(Tokens.Colors.hairlineStrong, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.control))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(label)
            .accessibilityValue(currentName)
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .focusRing(focused, radius: Tokens.Radius.control)
            .onHover { hovering = $0 }
            .foveaAnimation(.hover, value: hovering)
        }
    }
}

struct SegmentedControlRow<ID: Hashable>: View {
    let label: String
    var detail: String? = nil
    var key: UserSettings.Key? = nil
    @Binding var selection: ID
    let options: [(id: ID, name: String)]

    var body: some View {
        SettingsRow(label: label, detail: detail, key: key) {
            PillSegmentedControl(label: label, selection: $selection, options: options)
        }
    }
}

/// Text pills side by side, the chosen one on a gray fill; no container chrome.
/// Reads to VoiceOver as a standard segmented picker.
struct PillSegmentedControl<ID: Hashable>: View {
    let label: String
    @Binding var selection: ID
    let options: [(id: ID, name: String)]

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            ForEach(options, id: \.id) { option in
                PillSegment(name: option.name, selected: option.id == selection) { selection = option.id }
            }
        }
        .accessibilityRepresentation {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.id) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
        }
        .foveaAnimation(.select, value: selection)
    }
}

private struct PillSegment: View {
    let name: String
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(Tokens.Type_.button)
                .foregroundStyle(selected ? Tokens.Colors.textPrimary : Tokens.Colors.textSecondary)
                .padding(.horizontal, Tokens.Space.m)
                .frame(height: Tokens.Layout.controlHeight)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.control)
                    .fill(selected ? Tokens.Colors.control : hovering ? Tokens.Colors.hover : .clear))
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.control))
        }
        .buttonStyle(PressableStyle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused, radius: Tokens.Radius.control)
        .onKeyPress(.return) { action(); return .handled }
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct NavigationRow<Leading: View>: View {
    let label: String
    var detail: String? = nil
    var value: String? = nil
    var disabled = false
    var disabledReason: String? = nil
    @ViewBuilder var leading: Leading
    let action: () -> Void

    @State private var hovering = false
    @FocusState private var focused: Bool

    init(label: String, detail: String? = nil, value: String? = nil, disabled: Bool = false,
         disabledReason: String? = nil, @ViewBuilder leading: () -> Leading = { EmptyView() },
         action: @escaping () -> Void) {
        self.label = label; self.detail = detail; self.value = value; self.disabled = disabled
        self.disabledReason = disabledReason; self.leading = leading(); self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.m) {
                leading
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(Tokens.Type_.rowLabel)
                        .foregroundStyle(Tokens.Colors.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(Tokens.Type_.secondary)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                    }
                }
                Spacer(minLength: Tokens.Space.l)
                if let value {
                    Text(value)
                        .font(Tokens.Type_.rowValue)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Colors.textTertiary)
            }
            .padding(.horizontal, Tokens.Layout.rowPaddingH)
            .padding(.vertical, Tokens.Layout.rowPaddingV)
            .frame(minHeight: Tokens.Layout.rowHeight)
            .background(hovering && !disabled ? Tokens.Colors.hover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
        .help(disabled ? (disabledReason ?? label) : label)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused, radius: Tokens.Radius.group)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
    }
}

/// Label + status text and an optional action (permissions, connection state).
struct StatusRow: View {
    let label: String
    var detail: String? = nil
    let status: String
    let kind: StatusLabel.Kind
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        SettingsRow(label: label, detail: detail) {
            HStack(spacing: Tokens.Space.m) {
                StatusLabel(text: status, kind: kind)
                if let actionTitle, let action {
                    QuietButton(title: actionTitle, action: action)
                }
            }
        }
    }
}

/// Label + a button.
struct ActionRow: View {
    let label: String
    var detail: String? = nil
    let actionTitle: String
    var prominent = false
    var destructive = false
    var disabled = false
    var disabledReason: String? = nil
    var inlineStatus: (text: String, kind: StatusLabel.Kind, actionTitle: String, action: () -> Void)? = nil
    let action: () -> Void

    var body: some View {
        SettingsRow(label: label, detail: detail) {
            HStack(spacing: Tokens.Space.m) {
                if let inlineStatus {
                    StatusLabel(text: inlineStatus.text, kind: inlineStatus.kind)
                    QuietButton(title: inlineStatus.actionTitle, action: inlineStatus.action)
                }
                QuietButton(title: actionTitle, prominent: prominent, destructive: destructive,
                            disabled: disabled, disabledReason: disabledReason, action: action)
            }
        }
    }
}

/// Inline text editing that saves on commit or focus loss.
struct TextRow: View {
    let label: String
    var key: UserSettings.Key? = nil
    @Binding var text: String
    var editable = true
    @FocusState private var focused: Bool
    @State private var draft: String

    init(label: String, key: UserSettings.Key? = nil, text: Binding<String>, editable: Bool = true) {
        self.label = label; self.key = key; self._text = text; self.editable = editable
        _draft = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        SettingsRow(label: label, key: key) {
            if editable {
                TextField(label, text: $draft)
                    .textFieldStyle(.plain)
                    .font(Tokens.Type_.rowValue)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .frame(width: 220)
                    .padding(.horizontal, Tokens.Space.s)
                    .frame(height: Tokens.Layout.controlHeight)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.row).fill(focused ? Tokens.Colors.field : .clear))
                    .focused($focused)
                    .labelsHidden()
                    .onChange(of: text) { _, new in if !focused { draft = new } }
                    .onSubmit { commit() }
                    .onChange(of: focused) { _, f in if !f { commit() } }
            } else {
                Text(text)
                    .font(Tokens.Type_.rowValue)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != text else { draft = text; return }
        text = trimmed
    }
}

// MARK: - Shortcut row

struct ShortcutRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotMode) private var snapshotMode
    let action: ShortcutAction
    /// Snapshot-only: render the listening state.
    var forceRecording = false

    @State private var recording = false
    @State private var liveModifiers: KeyBinding.Modifiers = []
    /// fn is held; the chord commits when it is released without another key.
    @State private var fnHeld = false
    @State private var fnModifiers: KeyBinding.Modifiers = []
    @State private var fnUsedWithKey = false
    @State private var monitor: Any?
    @State private var hovering = false

    private var binding: KeyBinding? { model.shortcuts.bindings[action] }
    private var conflict: ShortcutAction? { model.shortcuts.conflicts[action] }

    /// Modifiers (and fn) held right now, in display order.
    private var liveGlyphs: [String] {
        KeyBinding(modifiers: liveModifiers, keyCode: fnHeld ? KeyBinding.functionKeyCode : 0,
                   keyLabel: fnHeld ? KeyBinding.functionKeyLabel : "").displayGlyphs.filter { !$0.isEmpty }
    }

    var body: some View {
        SettingsRow(label: action.displayName, detail: conflictText ?? usage) {
            HStack(spacing: Tokens.Space.s) {
                if recording || forceRecording {
                    HStack(spacing: Tokens.Space.s) {
                        if !liveGlyphs.isEmpty {
                            KeyCap(labels: liveGlyphs)
                        }
                        Text("Press shortcut…")
                            .font(Tokens.Type_.rowValue)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                    }
                    .padding(.horizontal, Tokens.Space.m)
                    .frame(height: Tokens.Layout.controlHeight)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.control).fill(Tokens.Colors.field))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.control)
                        .strokeBorder(Tokens.Colors.emphasis, lineWidth: 1.5))
                    .help("Tap fn, or press a chord · Esc cancels · ⌫ removes the shortcut")
                } else {
                    Button {
                        startRecording()
                    } label: {
                        Group {
                            if let binding {
                                KeyCap(labels: binding.displayGlyphs)
                            } else {
                                Text("Not set")
                                    .font(Tokens.Type_.rowValue)
                                    .foregroundStyle(Tokens.Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(height: Tokens.Layout.controlHeight)
                        .background(RoundedRectangle(cornerRadius: Tokens.Radius.control).fill(hovering ? Tokens.Colors.hover : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .help("Click to record a new shortcut")
                    .accessibilityLabel("\(action.displayName) shortcut, \(binding?.displayString ?? "not set")")
                    .accessibilityHint("Activate to record a new shortcut")
                    .onHover { hovering = $0 }
                    if binding != nil {
                        GlyphButton(symbol: "xmark.circle.fill", label: "Remove shortcut", size: 11) {
                            model.shortcuts.set(action, nil)
                        }
                        .opacity(hovering ? 1 : 0.35)
                    }
                }
            }
            .foveaAnimation(.hover, value: hovering)
        }
        .onDisappear { stopRecording() }
    }

    private var conflictText: String? {
        if let conflict { return "Conflicts with \(conflict.displayName)" }
        return nil
    }

    /// Shortcuts toggle: one press starts, the next press of the same shortcut ends.
    private var usage: String {
        switch action {
        case .voiceFlow: return "Press once to start listening, again to stop and review."
        case .quickAnswer: return "Press once to ask, again to stop and get the answer."
        }
    }

    private func startRecording() {
        guard !snapshotMode, monitor == nil else { return }
        recording = true
        liveModifiers = []
        fnHeld = false
        model.shortcuts.recordingAction = action
        // The fn event tap swallows fn globally, so its edges arrive through the sink;
        // the local monitor still handles regular chords, Escape and ⌫.
        AppServices.shared.hotkeys?.setRecordingSink { transition in handleFunctionKey(transition) }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil   // swallow while recording
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        liveModifiers = []
        fnHeld = false
        AppServices.shared.hotkeys?.setRecordingSink(nil)
        if model.shortcuts.recordingAction == action { model.shortcuts.recordingAction = nil }
    }

    private func handleFunctionKey(_ transition: FunctionKeyTransition) {
        switch transition.kind {
        case .down:
            liveModifiers = transition.modifiers.union(.init(rawValue: 0))
            fnHeld = true
        case .up(let usedWithKey):
            fnHeld = false
            liveModifiers = []
            if !usedWithKey {
                model.shortcuts.set(action, .functionKey(transition.modifiers))
                stopRecording()
            }
        }
    }

    private func handle(_ event: NSEvent) {
        let mods = KeyBinding.Modifiers(event.modifierFlags)
        if event.type == .flagsChanged {
            liveModifiers = mods
            if Int(event.keyCode) == kVK_Function {
                // fn edges come through the tap sink; ignore the raw flag here.
            } else if fnHeld {
                fnModifiers.formUnion(mods)
            }
            return
        }
        if fnHeld { fnUsedWithKey = true }
        switch Int(event.keyCode) {
        case kVK_Escape:
            stopRecording()
        case kVK_Delete, kVK_ForwardDelete:
            model.shortcuts.set(action, nil)
            stopRecording()
        default:
            // A bare letter would fire while typing; require a modifier unless it's a function key.
            let isFunctionKey = event.modifierFlags.contains(.function) && (event.keyCode >= 96 && event.keyCode <= 122)
            guard !mods.isEmpty || isFunctionKey else { return }
            let label = KeyBinding.label(forKeyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
            model.shortcuts.set(action, KeyBinding(modifiers: mods, keyCode: event.keyCode, keyLabel: label))
            stopRecording()
        }
    }
}

extension KeyBinding.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var m: KeyBinding.Modifiers = []
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.command) { m.insert(.command) }
        self = m
    }
}

extension KeyBinding {
    static func label(forKeyCode code: UInt16, characters: String?) -> String {
        switch Int(code) {
        case kVK_Function: return KeyBinding.functionKeyLabel
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return (characters ?? "?").uppercased()
        }
    }
}
