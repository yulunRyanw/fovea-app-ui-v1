import SwiftUI
import Charts
import FoveaCore

/// Picks the preview treatment for a referent. Always fills `width × height`.
struct CapturePreview: View {
    let referent: Referent
    let width: CGFloat
    let height: CGFloat
    var detail = false

    var body: some View {
        Group {
            switch referent.kind {
            case .image, .screenshot:
                PhotoPreview(referent: referent, width: width, height: height, detail: detail)
            case .code:
                CodePreview(code: referent.text ?? "", filename: referent.filename, width: width, height: height, detail: detail)
            case .terminal:
                TerminalPreview(output: referent.text ?? "", width: width, height: height, detail: detail)
            case .chart:
                ChartPreview(referent: referent, width: width, height: height, detail: detail)
            case .document, .file:
                DocumentPreview(referent: referent, width: width, height: height, detail: detail)
            case .equation:
                EquationPreview(text: referent.text ?? "", width: width, height: height, detail: detail)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Photos and screenshots

struct PhotoPreview: View {
    let referent: Referent
    let width: CGFloat
    let height: CGFloat
    var detail = false

    var body: some View {
        if let resource = referent.resource, let image = PreviewImageCache.shared.image(for: resource) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: detail ? .fit : .fill)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.image)
                        .strokeBorder(referent.kind == .screenshot ? Tokens.Colors.hairline : .clear, lineWidth: 1)
                )
                .accessibilityLabel(referent.filename ?? "Image")
        } else {
            MissingMediaPreview(referent: referent, width: width, height: height)
        }
    }
}

struct MissingMediaPreview: View {
    let referent: Referent
    let width: CGFloat
    let height: CGFloat

    private var symbol: String {
        switch referent.kind {
        case .image, .screenshot: return "photo"
        case .document: return "doc.richtext"
        default: return "doc"
        }
    }

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Tokens.Colors.textTertiary)
            if let filename = referent.filename {
                Text(filename)
                    .font(Tokens.Type_.captionMedium)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .lineLimit(1)
            }
            Text("Preview unavailable")
                .font(Tokens.Type_.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
        }
        .padding(Tokens.Space.m)
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.image).fill(Tokens.Colors.field))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.image).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
        .accessibilityLabel("\(referent.filename ?? "File"), preview unavailable")
    }
}

// MARK: - Code

enum CodeHighlighter {
    static let keywords: Set<String> = ["def", "if", "else", "elif", "return", "is", "not", "in", "for", "while",
                                        "import", "from", "class", "func", "let", "var", "guard", "async", "await", "const"]
    static let constants: Set<String> = ["None", "True", "False", "nil", "null", "true", "false", "self"]

    static func highlight(_ code: String) -> Text {
        var out = Text("")
        for (i, line) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if i > 0 { out = out + Text("\n") }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                out = out + Text(String(line)).foregroundColor(Tokens.Colors.codeMuted)
                continue
            }
            var buffer = ""
            var inString = false
            for ch in line {
                if ch == "\"" || ch == "'" {
                    if inString {
                        buffer.append(ch)
                        out = out + Text(buffer).foregroundColor(Tokens.Colors.codeString)
                        buffer = ""
                        inString = false
                    } else {
                        out = out + flush(buffer)
                        buffer = String(ch)
                        inString = true
                    }
                    continue
                }
                buffer.append(ch)
            }
            out = out + (inString ? Text(buffer).foregroundColor(Tokens.Colors.codeString) : flush(buffer))
        }
        return out
    }

    private static func flush(_ text: String) -> Text {
        var out = Text("")
        var word = ""
        func emitWord() {
            guard !word.isEmpty else { return }
            let color: Color = keywords.contains(word) ? Tokens.Colors.codeKeyword
                : constants.contains(word) ? Tokens.Colors.codeConstant
                : Int(word) != nil ? Tokens.Colors.codeConstant
                : Tokens.Colors.codeText
            out = out + Text(word).foregroundColor(color)
            word = ""
        }
        for ch in text {
            if ch.isLetter || ch.isNumber || ch == "_" { word.append(ch) }
            else { emitWord(); out = out + Text(String(ch)).foregroundColor(Tokens.Colors.codeText) }
        }
        emitWord()
        return out
    }
}

struct CodePreview: View {
    let code: String
    let filename: String?
    let width: CGFloat
    let height: CGFloat
    var detail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeHighlighter.highlight(code)
                .font(detail ? Tokens.Type_.monoDetail : Tokens.Type_.mono)
                .lineSpacing(detail ? 5 : 3)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(detail ? 24 : 14)
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.image).fill(Tokens.Colors.codeSurface))
        .accessibilityLabel("Code snippet \(filename ?? "")")
    }
}

struct TerminalPreview: View {
    let output: String
    let width: CGFloat
    let height: CGFloat
    var detail = false

    var body: some View {
        VStack(alignment: .leading, spacing: detail ? 6 : 3) {
            ForEach(Array(output.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                let s = String(line)
                if s.hasPrefix("✓") {
                    HStack(spacing: 6) {
                        Text("✓").foregroundStyle(Tokens.Colors.codeSuccess)
                        Text(s.dropFirst().trimmingCharacters(in: .whitespaces)).foregroundStyle(Tokens.Colors.codeText)
                    }
                } else if s.hasPrefix(">") {
                    Text(s).foregroundStyle(Tokens.Colors.codeText).fontWeight(.medium)
                } else {
                    Text(s.isEmpty ? " " : s).foregroundStyle(Tokens.Colors.codeText)
                }
            }
        }
        .font(detail ? Tokens.Type_.monoDetail : Tokens.Type_.mono)
        .minimumScaleFactor(0.7)
        .padding(detail ? 24 : 14)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.image).fill(Tokens.Colors.codeSurface))
        .accessibilityLabel("Terminal output")
    }
}

// MARK: - Chart

struct ChartPreview: View {
    let referent: Referent
    let width: CGFloat
    let height: CGFloat
    var detail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = referent.title {
                Text(title)
                    .font(detail ? Tokens.Type_.bodyMedium : Tokens.Type_.captionMedium)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
            }
            Chart(referent.chartPoints ?? [], id: \.x) { point in
                LineMark(x: .value("Step", point.x), y: .value("Loss", point.y))
                    .foregroundStyle(Tokens.Colors.chartLine)
                    .lineStyle(StrokeStyle(lineWidth: detail ? 2 : 1.5))
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(type: .log)
            .chartXAxis {
                AxisMarks(values: .stride(by: 10_000)) { value in
                    AxisGridLine().foregroundStyle(Tokens.Colors.hairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v == 0 ? "0" : "\(Int(v / 1000))K")
                                .font(.system(size: detail ? 10 : 7.5))
                                .foregroundStyle(Tokens.Colors.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [1, 0.1, 0.01, 0.001]) { value in
                    AxisGridLine().foregroundStyle(Tokens.Colors.hairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v >= 1 ? "10⁰" : v >= 0.1 ? "10⁻¹" : v >= 0.01 ? "10⁻²" : "10⁻³")
                                .font(.system(size: detail ? 10 : 7.5))
                                .foregroundStyle(Tokens.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(detail ? 20 : 10)
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.image).fill(Tokens.Colors.elevated))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.image).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
        .accessibilityLabel("Chart: \(referent.title ?? "")")
    }
}

// MARK: - Document

struct DocumentPreview: View {
    let referent: Referent
    let width: CGFloat
    let height: CGFloat
    var detail = false

    private var ext: String {
        (referent.filename ?? "").split(separator: ".").last.map(String.init)?.uppercased() ?? "FILE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Space.s) {
                Text(ext)
                    .font(.system(size: detail ? 9 : 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(height: detail ? 18 : 14)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Tokens.Colors.warning))
                Text(referent.filename ?? "Document")
                    .font(detail ? Tokens.Type_.bodyMedium : Tokens.Type_.captionMedium)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, detail ? 16 : 10)
            .padding(.vertical, detail ? 12 : 7)
            .background(Tokens.Colors.field)

            HStack(alignment: .top, spacing: 0) {
                Rectangle().fill(Tokens.Colors.hairline).frame(width: 1)
                VStack(alignment: .leading, spacing: detail ? 10 : 5) {
                    if let title = referent.title {
                        Text(title)
                            .font(.system(size: detail ? 13 : 7.5, weight: .semibold))
                            .foregroundStyle(Tokens.Colors.textPrimary)
                    }
                    ForEach(Array((referent.text ?? "").split(separator: "\n").enumerated()), id: \.offset) { _, line in
                        Text(String(line))
                            .font(.system(size: detail ? 12 : 6.5))
                            .foregroundStyle(Tokens.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(detail ? 18 : 10)
                .padding(.leading, detail ? 30 : 16)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Tokens.Colors.elevated)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.image).strokeBorder(Tokens.Colors.hairline, lineWidth: 1))
        .accessibilityLabel("\(ext) document \(referent.filename ?? "")")
    }
}

// MARK: - Equation

struct EquationPreview: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    var detail = false

    var body: some View {
        Text(text)
            .font(detail ? .system(size: 34, weight: .regular, design: .serif) : Tokens.Type_.equation)
            .italic()
            .foregroundStyle(Tokens.Colors.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(Tokens.Space.m)
            .frame(width: width, height: height)
            .accessibilityLabel("Equation: \(text)")
    }
}
