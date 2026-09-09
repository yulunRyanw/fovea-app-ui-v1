import SwiftUI
import AppKit
import FoveaCore

/// One continuous surface: the question, the streamed answer, a compact follow-up field
/// with Send inside it, an ✕ that ends the session, and a grabber. From four questions a
/// bookmark rail down the right margin indexes them. No destination, model or provider
/// anywhere. The same view fills the attached slab and the detached panel.
struct QuickAnswerView: View {
    enum Host { case attached, detached }

    let model: IslandModel
    let host: Host
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotMode) private var snapshotMode
    @State private var detaching = false
    /// A question the user jumped to from the rail; streaming stops auto-scrolling until
    /// the next question arrives.
    @State private var pinnedQuestion: Int?

    private var qa: QuickAnswerState? { model.state.quickAnswer }
    private var innerWidth: CGFloat {
        host == .attached ? Tokens.Island.Layout.slabWidth : Tokens.Island.Layout.detachedDefault.width
    }

    var body: some View {
        if let qa {
            VStack(alignment: .leading, spacing: 0) {
                Text(qa.question)
                    .font(Tokens.Island.Type_.question)
                    .foregroundStyle(Tokens.Island.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Tokens.Space.m)
                    .accessibilityAddTraits(.isHeader)

                Rectangle().fill(Tokens.Island.Colors.hairline).frame(height: 1)

                answerRegion(qa)
                    .padding(.vertical, Tokens.Space.l)

                HStack(alignment: .center, spacing: Tokens.Space.s) {
                    followUp(qa)
                    Spacer(minLength: Tokens.Space.s)
                    IslandIconButton(symbol: "xmark", label: "End Quick Answer",
                                     size: Tokens.Island.Layout.closeGlyphSize) { model.send(.closeQuickAnswer) }
                        .accessibilityHint("Closes this Quick Answer")
                }

                grabber
            }
            .padding(.horizontal, Tokens.Island.Layout.slabPadding)
            .padding(.top, Tokens.Space.l)
            .frame(width: innerWidth)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quick Answer")
        }
    }

    // MARK: Answer

    /// Every question of the session, earliest first; the header shows the last.
    private func questions(_ qa: QuickAnswerState) -> [String] {
        qa.turns.map(\.question) + [qa.question]
    }

    @ViewBuilder
    private func answerRegion(_ qa: QuickAnswerState) -> some View {
        let maxHeight = Tokens.Island.Layout.slabMaxHeight - 150
        let questions = questions(qa)
        let showRail = questions.count >= Tokens.Island.Layout.bookmarkRailMinQuestions
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    ForEach(Array(qa.turns.enumerated()), id: \.offset) { index, turn in
                        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                            Text(turn.question)
                                .font(Tokens.Island.Type_.secondary)
                                .foregroundStyle(Tokens.Island.Colors.textTertiary)
                            answerText(turn.answer, streaming: false)
                                .foregroundStyle(Tokens.Island.Colors.textSecondary)
                        }
                        .id("turn-\(index)")
                    }
                    Group {
                        if let error = qa.error {
                            HStack(spacing: Tokens.Space.m) {
                                Text(error)
                                    .font(Tokens.Island.Type_.body)
                                    .foregroundStyle(Tokens.Island.Colors.failed)
                                IslandTextButton(title: "Retry", prominent: true) { model.send(.retry) }
                            }
                            .accessibilityElement(children: .combine)
                        } else if qa.answer.isEmpty && qa.streaming {
                            Text("Thinking…")
                                .font(Tokens.Island.Type_.answer)
                                .foregroundStyle(Tokens.Island.Colors.textTertiary)
                                .accessibilityLabel("Waiting for the answer")
                        } else {
                            answerText(qa.answer, streaming: qa.streaming)
                                .foregroundStyle(Tokens.Island.Colors.textPrimary)
                                .textSelection(.enabled)
                                .accessibilityAddTraits(qa.streaming ? .updatesFrequently : [])
                        }
                    }
                    .id("current")
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .topTrailing) {
                if showRail {
                    QuestionBookmarkRail(questions: questions, current: pinnedQuestion ?? questions.count - 1) { index in
                        pinnedQuestion = index
                        withAnimation(Tokens.Motion.animation(.selectorStep, reduceMotion: reduceMotion)) {
                            proxy.scrollTo(index < qa.turns.count ? "turn-\(index)" : "current", anchor: .top)
                        }
                    }
                    // The rail lives in the right margin, so the text never reflows around it.
                    .offset(x: Tokens.Island.Layout.slabPadding - Tokens.Island.Layout.bookmarkRailInset)
                    .transition(.opacity)
                }
            }
            .onChange(of: qa.answer.count) { _, _ in
                guard qa.streaming, !snapshotMode, pinnedQuestion == nil else { return }
                proxy.scrollTo("end", anchor: .bottom)
            }
            .onChange(of: qa.turns.count) { _, _ in pinnedQuestion = nil }
        }
    }

    private func answerText(_ text: String, streaming: Bool) -> some View {
        let shown = streaming && !snapshotMode ? text + "▍" : text
        let attributed = (try? AttributedString(markdown: shown,
                                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(shown)
        return Text(attributed)
            .font(Tokens.Island.Type_.answer)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Follow-up

    private func followUp(_ qa: QuickAnswerState) -> some View {
        let width = (innerWidth - Tokens.Island.Layout.slabPadding * 2) * Tokens.Island.Layout.followUpWidthFraction
        return HStack(spacing: Tokens.Space.xs) {
            ZStack(alignment: .leading) {
                if qa.followUp.isEmpty {
                    Text("Ask a follow-up…")
                        .font(Tokens.Island.Type_.body)
                        .foregroundStyle(Tokens.Island.Colors.textTertiary)
                        .padding(.leading, 1)
                        .allowsHitTesting(false)
                }
                IslandTextView(
                    text: Binding(get: { model.state.quickAnswer?.followUp ?? "" },
                                  set: { model.send(.editFollowUp($0)) }),
                    font: .systemFont(ofSize: 13.5),
                    placeholder: "Ask a follow-up",
                    submitOnReturn: true,
                    onSubmit: { model.send(.submitFollowUp) },
                    onEscape: { model.send(.escape) },
                    focusToken: model.focusRequest.target == .followUp ? model.focusRequest.token : 0,
                    insets: NSSize(width: 0, height: 0)
                )
                .frame(height: 18)
            }
            SendButton(enabled: !qa.followUp.trimmingCharacters(in: .whitespaces).isEmpty && !qa.streaming,
                       size: 20) { model.send(.submitFollowUp) }
        }
        .padding(.leading, Tokens.Space.m)
        .padding(.trailing, Tokens.Space.xs + 1)
        .frame(width: width, height: Tokens.Island.Layout.followUpHeight)
        .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.field).fill(Tokens.Island.Colors.field))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.field).strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Follow-up")
    }

    // MARK: Grabber

    private var grabber: some View {
        Capsule()
            .fill(Tokens.Island.Colors.textTertiary)
            .frame(width: Tokens.Island.Layout.grabber.width, height: Tokens.Island.Layout.grabber.height)
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Island.Layout.grabberHitHeight)
            .contentShape(Rectangle())
            .gesture(host == .attached ? dragToDetach : nil)
            .padding(.top, Tokens.Space.xs)
            .accessibilityElement()
            .accessibilityLabel(host == .attached ? "Drag to detach" : "Drag to move")
            .accessibilityHint(host == .attached ? "Pulls the Quick Answer off the notch into a floating panel" : "")
    }

    private var dragToDetach: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { _ in
                guard !detaching else { return }
                detaching = true
                model.detachFromGesture()
            }
            .onEnded { _ in detaching = false }
    }
}

/// The floating card version: same content on a slightly lifted surface with a frame.
/// Dragging its background moves the window (the controller's drag engine does the
/// moving); the card reports its size so the window can follow it, top edge fixed.
struct DetachedQuickAnswerView: View {
    let model: IslandModel
    var onSize: ((CGSize) -> Void)? = nil
    var onDragBegin: (() -> Void)? = nil
    @State private var dragging = false

    var body: some View {
        QuickAnswerView(model: model, host: .detached)
            .padding(.bottom, Tokens.Space.xs)
            .background(Tokens.Island.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Island.Radius.detached, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Island.Radius.detached, style: .continuous)
                    .strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Island.Radius.detached, style: .continuous))
            .gesture(moveWindow)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize?($0) }
            .environment(\.colorScheme, .dark)
    }

    /// Lower precedence than the controls' own gestures, so text selection, scrolling,
    /// buttons and the follow-up field keep their clicks.
    private var moveWindow: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { _ in
                guard !dragging else { return }
                dragging = true
                onDragBegin?()
            }
            .onEnded { _ in dragging = false }
    }
}
