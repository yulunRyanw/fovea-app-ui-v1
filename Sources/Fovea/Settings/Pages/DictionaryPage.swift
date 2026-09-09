import SwiftUI
import FoveaCore

struct DictionaryPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotMode) private var snapshotMode
    @Environment(\.snapshotVariant) private var snapshotVariant

    @State private var query = ""
    @State private var showAll = false
    @State private var ordering: Ordering = .alphabetical
    @State private var editing: DictionaryTerm?
    @FocusState private var fieldFocused: Bool

    enum Ordering: String, CaseIterable { case alphabetical = "A–Z", recent = "Recent" }

    private var dictionary: DictionaryModel { model.dictionary }
    private var expanded: Bool { showAll || snapshotVariant == "dictionary-expanded" }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedQuery.isEmpty && !dictionary.exists(trimmedQuery) }

    private var visibleTerms: [DictionaryTerm] {
        if !trimmedQuery.isEmpty { return dictionary.matches(trimmedQuery) }
        if expanded {
            return ordering == .alphabetical ? dictionary.alphabetical
                : dictionary.terms.sorted { $0.useCount > $1.useCount }
        }
        return dictionary.recent
    }

    var body: some View {
        SettingsPage(title: "Dictionary") {
            SettingsSection(nil, child: .learnedWords) {
                SettingsGroup {
                    ToggleRow(label: "Auto-learn Corrections",
                              detail: "Words you fix after a capture are added here.",
                              isOn: Binding(get: { dictionary.autoLearn }, set: { dictionary.autoLearn = $0 }))
                }
            }

            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                searchField

                VStack(alignment: .leading, spacing: Tokens.Space.s) {
                    HStack {
                        Text(listTitle)
                            .font(Tokens.Type_.settingsSection)
                            .foregroundStyle(Tokens.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        if expanded && trimmedQuery.isEmpty {
                            PillSegmentedControl(label: "Order", selection: $ordering,
                                                 options: Ordering.allCases.map { ($0, $0.rawValue) })
                        }
                    }

                    if visibleTerms.isEmpty {
                        Text(canAdd ? "No match. Press Return to add “\(trimmedQuery)”." : "No words yet.")
                            .font(Tokens.Type_.secondary)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                            .padding(.vertical, Tokens.Space.s)
                    } else {
                        SettingsGroup {
                            ForEach(Array(visibleTerms.enumerated()), id: \.element.id) { i, term in
                                if i > 0 { GroupDivider() }
                                DictionaryTermRow(term: term) { editing = term }
                            }
                        }
                    }

                    if trimmedQuery.isEmpty {
                        Button {
                            withAnimation(Tokens.Motion.animation(.accordion)) { showAll.toggle() }
                        } label: {
                            HStack(spacing: Tokens.Space.xs) {
                                Text(expanded ? "Show Recent" : "Show All · \(dictionary.terms.count)")
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .font(Tokens.Type_.bodyMedium)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                            .padding(.vertical, Tokens.Space.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Tokens.Space.xs)
                    }
                }
            }

            if snapshotMode, let term = editing ?? (snapshotVariant == "dictionary-edit" ? dictionary.recent.first : nil) {
                DictionaryEditSheet(term: term) { editing = nil }
                    .frame(width: 380)
                    .background(Tokens.Colors.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.group))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.group).strokeBorder(Tokens.Colors.hairlineStrong, lineWidth: 1))
            }
        }
        .sheet(item: $editing) { term in
            DictionaryEditSheet(term: term) { editing = nil }
        }
    }

    private var listTitle: String {
        if !trimmedQuery.isEmpty { return "Results" }
        return expanded ? "All Words" : "Recent"
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.Colors.textSecondary)
            TextField("Search or add a word…", text: $query)
                .textFieldStyle(.plain)
                .font(Tokens.Type_.search)
                .focused($fieldFocused)
                .onSubmit {
                    guard canAdd else { return }
                    if let term = dictionary.add(trimmedQuery) {
                        query = ""
                        editing = term
                    }
                }
                .accessibilityLabel("Search or add a word")
            if canAdd {
                Button {
                    if let term = dictionary.add(trimmedQuery) { query = ""; editing = term }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                        Text("Add").font(Tokens.Type_.captionMedium)
                    }
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .padding(.horizontal, Tokens.Space.s)
                    .frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.chip).fill(Tokens.Colors.hover))
                }
                .buttonStyle(PressableStyle())
                .help("Add “\(trimmedQuery)” to the dictionary")
            } else if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Layout.controlHeight + 4)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.control).fill(Tokens.Colors.field))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.control)
            .strokeBorder(fieldFocused ? Tokens.Colors.hairlineStrong : .clear, lineWidth: 1))
    }
}

struct DictionaryTermRow: View {
    let term: DictionaryTerm
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.m) {
                Text(term.preferredSpelling)
                    .font(Tokens.Type_.rowLabel)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                if !term.aliases.isEmpty {
                    Text(term.aliases.joined(separator: ", "))
                        .font(Tokens.Type_.secondary)
                        .foregroundStyle(Tokens.Colors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Colors.textTertiary)
                    .opacity(hovering ? 1 : 0.5)
            }
            .padding(.horizontal, Tokens.Layout.rowPaddingH)
            .frame(height: 42)
            .background(hovering ? Tokens.Colors.hover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusRing(focused, radius: Tokens.Radius.group)
        .onHover { hovering = $0 }
        .foveaAnimation(.hover, value: hovering)
        .help("Edit “\(term.preferredSpelling)”")
    }
}

struct DictionaryEditSheet: View {
    @Environment(AppModel.self) private var model
    let term: DictionaryTerm
    let dismiss: () -> Void

    @State private var spelling: String
    @State private var aliases: String
    @State private var confirmDelete = false

    init(term: DictionaryTerm, dismiss: @escaping () -> Void) {
        self.term = term
        self.dismiss = dismiss
        _spelling = State(initialValue: term.preferredSpelling)
        _aliases = State(initialValue: term.aliases.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Edit Word")
                .font(Tokens.Type_.settingsSection)
                .foregroundStyle(Tokens.Colors.textPrimary)

            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Preferred Spelling")
                    .font(Tokens.Type_.captionMedium)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                TextField("Preferred Spelling", text: $spelling)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Aliases")
                    .font(Tokens.Type_.captionMedium)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                TextField("Other spellings, separated by commas", text: $aliases)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                Text("Any of these will be corrected to the preferred spelling.")
                    .font(Tokens.Type_.caption)
                    .foregroundStyle(Tokens.Colors.textTertiary)
            }

            HStack {
                QuietButton(title: "Delete Word", destructive: true) { confirmDelete = true }
                    .confirmationDialog("Delete “\(term.preferredSpelling)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) { model.dictionary.delete(term.id); dismiss() }
                        Button("Cancel", role: .cancel) {}
                    }
                Spacer()
                QuietButton(title: "Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                QuietButton(title: "Save", prominent: true, disabled: spelling.trimmingCharacters(in: .whitespaces).isEmpty) {
                    var updated = term
                    updated.preferredSpelling = spelling.trimmingCharacters(in: .whitespaces)
                    updated.aliases = aliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    model.dictionary.update(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, Tokens.Space.xs)
        }
        .padding(Tokens.Space.xl)
        .frame(width: 380)
    }
}
