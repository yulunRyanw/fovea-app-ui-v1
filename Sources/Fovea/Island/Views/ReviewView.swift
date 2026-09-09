import SwiftUI
import AppKit
import FoveaCore

/// Transcript review: the editable words dominate; below them the referent stack, the
/// Chat selector and a small circular Send. Hovering a fanned-out referent grows a
/// preview beneath the stack; the selector opens a panel under the row. No Cancel.
struct ReviewView: View {
    let model: IslandModel
    @State private var editorHeight: CGFloat = Tokens.Island.Layout.editorMinHeight

    private var draft: ReviewDraft? { model.state.review }
    private var sending: Bool { model.phase == .sending }

    private var contentWidth: CGFloat {
        Tokens.Island.Layout.reviewWidth - Tokens.Island.Radius.expandedTop * 2 - Tokens.Island.Layout.reviewPadding * 2
    }
    /// The pill and Send get a fixed reservation, so the stack's wrap width never depends
    /// on an async measurement (which would let the fanned-out stack overflow the row).
    private var trailingReserve: CGFloat {
        Tokens.Island.Layout.pillMaxWidth + Tokens.Island.Layout.sendButtonSize + Tokens.Space.m * 2
    }
    private var stackWidth: CGFloat {
        max(Tokens.Island.Layout.thumb.width, contentWidth - trailingReserve)
    }

    var body: some View {
        if let draft {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                IslandTextView(
                    text: Binding(get: { model.state.review?.transcript ?? "" },
                                  set: { model.send(.editTranscript($0)) }),
                    font: .systemFont(ofSize: 14),
                    placeholder: "Transcript",
                    submitOnReturn: false,
                    onEscape: { model.send(.escape) },
                    onHeightChange: { editorHeight = $0 },
                    focusToken: model.focusRequest.target == .editor ? model.focusRequest.token : 0,
                    wantsFocus: { model.phase.isReview && model.state.review?.selector.isOpen != true }
                )
                .frame(height: min(Tokens.Island.Layout.editorMaxHeight,
                                   max(Tokens.Island.Layout.editorMinHeight, editorHeight)))
                .disabled(sending)
                .accessibilityLabel("Transcript")
                .accessibilityHint("Edit before sending")

                HStack(alignment: .top, spacing: Tokens.Space.m) {
                    ReferentStackView(model: model, availableWidth: stackWidth)
                        .frame(maxWidth: stackWidth, alignment: .leading)
                    Spacer(minLength: Tokens.Space.s)
                    HStack(spacing: Tokens.Space.m) {
                        ChatSelectorPill(model: model)
                            .frame(maxWidth: Tokens.Island.Layout.pillMaxWidth)
                        SendButton(enabled: draft.canSend && !sending, busy: sending) { model.send(.send) }
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                }

                if let id = draft.hoveredReferentId, let referent = draft.referents.first(where: { $0.id == id }),
                   let index = draft.referents.firstIndex(where: { $0.id == id }) {
                    ReferentPreviewRow(referent: referent, index: index, count: draft.referents.count,
                                       availableWidth: stackWidth, contentWidth: contentWidth)
                        .transition(.opacity)
                }

                if draft.selector.isOpen {
                    ChatSelectorPanel(model: model)
                        .frame(width: contentWidth)
                        .transition(.opacity)
                }

                if case .sendFailed(let failure) = model.phase {
                    HStack(spacing: Tokens.Space.m) {
                        Text(failure.message)
                            .font(Tokens.Island.Type_.secondary)
                            .foregroundStyle(Tokens.Island.Colors.failed)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        IslandTextButton(title: retryTitle(failure), prominent: true) { model.send(.retry) }
                    }
                    .transition(.opacity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Tokens.Island.Layout.reviewPadding)
            .padding(.top, Tokens.Space.m)
            .padding(.bottom, Tokens.Island.Layout.reviewPadding - Tokens.Space.xs)
            .frame(width: Tokens.Island.Layout.reviewWidth - Tokens.Island.Radius.expandedTop * 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Transcript review")
        }
    }

    private func retryTitle(_ failure: IslandFailure) -> String {
        switch failure.recovery {
        case .openMainApp: return "Open Fovea"
        case .openSettings: return "Open Settings"
        default: return "Retry"
        }
    }
}
