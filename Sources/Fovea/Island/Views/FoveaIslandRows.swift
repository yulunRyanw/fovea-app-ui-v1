import SwiftUI
import FoveaCore

/// The product's compact island rows, replicated for the rehearsal: recording,
/// processing, delivered, and the kept-text card. Layout, copy and colours follow
/// `NotchIslandView` in fovea-mac; only the surface around them is the engine's.
enum FoveaRound {
    case voiceFlow, quickAnswer

    init(_ action: ShortcutAction) { self = action == .quickAnswer ? .quickAnswer : .voiceFlow }

    var brand: Color { self == .quickAnswer ? Tokens.Fovea.Island.quickAnswer : Tokens.Fovea.Island.voiceFlow }
    var accentText: Color { self == .quickAnswer ? Tokens.Fovea.Island.quickAnswerText : Tokens.Fovea.Island.voiceFlowText }
}

/// One compact row inside the island: 28 pt tall, 8 pt gutter below for the rail.
private struct FoveaCompactRow<Content: View>: View {
    var rail: (progress: CGFloat, color: Color)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(height: Tokens.Fovea.Island.rowHeight)
                .padding(.horizontal, Tokens.Fovea.Island.horizontalPadding)
            ZStack {
                if let rail {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Tokens.Fovea.Island.railTrack)
                            Capsule().fill(rail.color).frame(width: max(4, proxy.size.width * min(1, max(0, rail.progress))))
                        }
                    }
                    .frame(height: 2)
                    .padding(.horizontal, Tokens.Fovea.Island.horizontalPadding)
                    .padding(.top, 3)
                }
            }
            .frame(height: Tokens.Fovea.Island.rowBottomPadding)
        }
    }
}

/// The product's key cap (`NotchIslandDestinationButton`'s shortcut label): the glyph
/// on a small rounded control, e.g. `L⌃`, `L⌃ ×2`, `esc`.
struct FoveaKeycap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Tokens.Fovea.Island.subText)
            .padding(.horizontal, 4)
            .frame(height: 16)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Tokens.Fovea.Island.control))
    }
}

/// A key hint the way macOS writes shortcuts: the key cap first, then the verb.
struct FoveaKeyHint: View {
    let keys: [String]
    let verb: String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { FoveaKeycap(text: $0) }
            Text(verb).font(.system(size: 11, weight: .medium)).foregroundStyle(Tokens.Fovea.Island.mutedText)
        }
    }
}

/// The product's waveform: fine 2.5 pt bars, brand colour at 70 %.
struct FoveaWaveBars: View {
    let color: Color
    let level: Float
    var barCount = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = sin(t * 9 + Double(index) * 0.9) * 0.5 + 0.5
                    let height = 2 + 14 * CGFloat(max(0.08, Double(level) * (0.35 + 0.65 * phase)))
                    RoundedRectangle(cornerRadius: 1).fill(color.opacity(0.7)).frame(width: 2.5, height: height)
                }
            }
            .frame(width: Tokens.Fovea.Island.waveformWidth, height: 16)
        }
    }
}

/// Recording: waveform, the Quick Answer destination pill, the attachment count, Esc.
struct FoveaRecordingRow: View {
    let round: FoveaRound
    let level: Float
    let materials: Int
    var destination: QuickAnswerDestinationChoice = .automatic
    var menuOpen = false

    private var chosen: Bool { destination != .automatic }
    private var destinationTitle: String {
        switch destination {
        case .automatic: return "自动"
        case .newConversation: return "新对话"
        case .existing(_, let title, _): return title
        }
    }
    private var destinationProvider: String? {
        switch destination {
        case .automatic: return nil
        case .newConversation(let provider): return provider
        case .existing(_, _, let provider): return provider
        }
    }

    var body: some View {
        FoveaCompactRow {
            HStack(spacing: Tokens.Fovea.Island.itemSpacing) {
                // Production: the VoiceFlow row keeps its width and the waveform narrows when
                // the attachment count appears; the Quick Answer row always reserves the slot.
                FoveaWaveBars(color: round.brand, level: level,
                              barCount: round == .voiceFlow && materials > 0 ? 8 : 14)
                if round == .voiceFlow && materials > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip").font(.system(size: 11, weight: .semibold))
                        Text("\(materials)").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(round.accentText)
                    .frame(width: Tokens.Fovea.Island.accessoryWidth, height: 20)
                    .background(Capsule().fill(round.brand.opacity(0.16)))
                }
                if round == .quickAnswer {
                    // The destination pill (product `NotchIslandDestinationButton`): 「自动」 or the
                    // chosen conversation with its provider mark; chevron flips while the picker
                    // is open; the key cap names the key that opens it.
                    HStack(spacing: 4) {
                        if let provider = destinationProvider { ProviderMark(name: ProviderMark.assetName(for: provider), size: 14) }
                        Text(destinationTitle).font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(chosen ? Tokens.Fovea.Island.subText : Tokens.Fovea.Island.text)
                            .lineLimit(1).truncationMode(.tail)
                        Image(systemName: menuOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold)).foregroundStyle(Tokens.Fovea.Island.mutedText)
                        FoveaKeycap(text: "L⌃")
                    }
                    .padding(.horizontal, 6).frame(height: 20)
                    .background(Capsule().fill(chosen ? round.brand.opacity(0.16) : Tokens.Fovea.Island.control))
                    .frame(width: chosen ? 184 : 132, alignment: .leading)
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip").font(.system(size: 11, weight: .semibold))
                        Text("\(materials)").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(round.accentText)
                    .frame(width: Tokens.Fovea.Island.accessoryWidth, height: 20)
                    .background(Capsule().fill(round.brand.opacity(0.16)))
                }
                HStack(spacing: 3) {
                    Text("Esc").font(.system(size: 11, weight: .medium))
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Tokens.Fovea.Island.mutedText)
                .frame(width: Tokens.Fovea.Island.escControlWidth, height: 20)
            }
        }
    }
}

/// Processing: the round's identity and the estimated progress rail.
struct FoveaProcessingRow: View {
    let round: FoveaRound
    let startedAt: Date?
    let target: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let elapsed = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
            // The product estimates the service time; the rail eases toward 92 % and waits.
            let progress = CGFloat(1 - pow(0.5, elapsed / 1.1)) * 0.92
            FoveaCompactRow(rail: (progress, round.brand)) {
                HStack(spacing: 7) {
                    if round == .quickAnswer {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .medium)).foregroundStyle(round.accentText)
                        Text("正在准备提问").font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.Fovea.Island.text)
                    } else {
                        ProviderMark(name: target, size: 16)
                        Text("正在处理").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Tokens.Fovea.Island.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

/// Delivered: shown 0.55 s, then the island rests.
struct FoveaDeliveredRow: View {
    let target: String

    var body: some View {
        FoveaCompactRow(rail: (1, Tokens.Fovea.Island.success)) {
            HStack(spacing: 8) {
                ProviderMark(name: target, size: 16)
                Text("已送达 \(target)").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Tokens.Fovea.Island.text)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// "Kept for you — no input box was available": the text, copy / put here / deliver again.
struct FoveaRetainedCard: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("已为你保留 — 当时没有可用输入框").font(.system(size: 11)).foregroundStyle(Tokens.Fovea.Island.mutedText)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tokens.Fovea.Island.mutedText)
                        .frame(width: 20, height: 20).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            .frame(height: 26)
            .padding(.bottom, 6)
            Text(text)
                .font(.system(size: 12.5)).foregroundStyle(Tokens.Fovea.Island.text)
                .lineSpacing(3).frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Tokens.Fovea.Island.card))
            HStack(spacing: 8) {
                Spacer()
                actionButton("复制", prominent: false)
                actionButton("投递到这个输入框", prominent: true)
                actionButton("再投递一次", prominent: false)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func actionButton(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(prominent ? Tokens.Fovea.Island.text : Tokens.Fovea.Island.subText)
            .padding(.horizontal, 12).frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(prominent ? Tokens.Fovea.Island.voiceFlow.opacity(0.22) : Tokens.Fovea.Island.control))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Tokens.Fovea.Island.separator))
    }
}

/// A provider / app mark from the bundled destination icons (codex, claude, chatgpt…),
/// or a lettered tile.
struct ProviderMark: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let image = Self.image(for: name) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.6, weight: .bold))
                    .foregroundStyle(Tokens.Fovea.Island.text)
                    .frame(width: size, height: size)
                    .background(Tokens.Fovea.Island.control)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }

    /// Provider id → bundled mark. Codex uses the official colour icon; Claude Code keeps
    /// its colour too (engine rule); everything else is the white glyph.
    static func assetName(for provider: String) -> String {
        provider == "codex" ? "codex-color" : provider
    }

    static func displayName(for provider: String) -> String {
        switch provider {
        case "codex": return "Codex"
        case "claude-code": return "Claude Code"
        case "claude": return "Claude"
        case "cursor": return "Cursor"
        case "chatgpt": return "ChatGPT"
        default: return provider.prefix(1).uppercased() + provider.dropFirst()
        }
    }

    static func image(for name: String) -> NSImage? {
        let key = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let candidates = [key, key.hasPrefix("codex") ? "codex" : key, key.hasPrefix("claude") ? "claude" : key]
        for c in candidates {
            if let url = FoveaResources.url("Destinations/\(c).png"), let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }
}
