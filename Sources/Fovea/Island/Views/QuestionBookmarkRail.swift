import SwiftUI
import FoveaCore

/// One tick per question of a Quick Answer, down the right margin; the current one is
/// white. Hover shows the question, a click scrolls to it. Only shown once a session has
/// more questions than fit in view comfortably.
struct QuestionBookmarkRail: View {
    let questions: [String]
    let current: Int
    let onSelect: (Int) -> Void
    @State private var hovered: Int?

    var body: some View {
        VStack(alignment: .trailing, spacing: Tokens.Island.Layout.bookmarkRailSpacing) {
            ForEach(questions.indices, id: \.self) { index in
                Button { onSelect(index) } label: {
                    HStack(spacing: Tokens.Space.s) {
                        if hovered == index {
                            Text(questions[index])
                                .font(Tokens.Island.Type_.secondary)
                                .foregroundStyle(Tokens.Island.Colors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, Tokens.Space.s)
                                .frame(height: Tokens.Island.Layout.bookmarkRailHit)
                                .background(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill).fill(Tokens.Island.Colors.surface))
                                .overlay(RoundedRectangle(cornerRadius: Tokens.Island.Radius.pill).strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
                                .frame(maxWidth: Tokens.Island.Layout.bookmarkLabelMaxWidth)
                                .fixedSize(horizontal: true, vertical: false)
                                .transition(.opacity)
                        }
                        Capsule()
                            .fill(index == current ? Tokens.Island.Colors.textPrimary : Tokens.Island.Colors.textTertiary)
                            .frame(width: hovered == index ? Tokens.Island.Layout.bookmarkTickHover : Tokens.Island.Layout.bookmarkTick.width,
                                   height: Tokens.Island.Layout.bookmarkTick.height)
                    }
                    .frame(height: Tokens.Island.Layout.bookmarkRailHit)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { hovered = index } else if hovered == index { hovered = nil }
                }
                .help(questions[index])
                .accessibilityLabel("Question \(index + 1): \(questions[index])")
                .accessibilityHint("Scrolls to this question")
            }
        }
        .foveaAnimation(.hover, value: hovered)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Questions")
    }
}
