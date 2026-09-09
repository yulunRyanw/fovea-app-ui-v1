import SwiftUI
import FoveaCore

/// The scrollable region: a transcript, or a Quick Answer in two columns. Text is fixed
/// at 14 pt and never scales; long content scrolls.
struct DetailContent: View {
    let capture: Capture
    let width: CGFloat

    var body: some View {
        if capture.intent == .quickAnswer, let question = capture.question, let answer = capture.answer {
            QuickAnswerColumns(question: question, answer: answer, width: width)
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                DetailSectionLabel("Transcript")
                DetailBody(text: capture.transcript ?? "")
            }
        }
    }
}

struct DetailSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        // Same type as the body; only the color sets it apart.
        Text(text)
            .font(Tokens.Detail.Type_.label)
            .foregroundStyle(Tokens.Detail.Colors.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DetailBody: View {
    let text: String
    var font: Font = Tokens.Detail.Type_.body

    var body: some View {
        Text(text)
            .font(font)
            .lineSpacing(Tokens.Detail.Type_.bodyLineSpacing)
            .foregroundStyle(Tokens.Detail.Colors.foreground)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// QUESTION on the left, ANSWER on the right, a hairline between, both top-aligned. The
/// columns stack only when the card is narrower than its minimum landscape width.
struct QuickAnswerColumns: View {
    let question: String
    let answer: String
    let width: CGFloat

    private var stacked: Bool { width < Tokens.Detail.Layout.minSize.width - Tokens.Detail.Layout.contentPaddingH * 2 }

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                questionColumn
                answerColumn
            }
        } else {
            HStack(alignment: .top, spacing: Tokens.Detail.Layout.columnGap) {
                questionColumn
                    .frame(width: (width - Tokens.Detail.Layout.columnGap * 2 - 1) * Tokens.Detail.Layout.questionFraction,
                           alignment: .topLeading)
                Rectangle()
                    .fill(Tokens.Detail.Colors.divider)
                    .frame(width: 1)
                answerColumn
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var questionColumn: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            DetailSectionLabel("Question")
            DetailBody(text: question, font: Tokens.Detail.Type_.question)
        }
    }

    private var answerColumn: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            DetailSectionLabel("Answer")
            DetailBody(text: answer)
        }
    }
}
