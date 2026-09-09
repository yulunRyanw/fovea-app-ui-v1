import SwiftUI
import FoveaCore

/// The layer that floats over Home while a capture is open: a transparent click-catcher
/// that closes the card, and the card itself, centered in the usable canvas.
struct DetailLayer: View {
    @Environment(AppModel.self) private var model
    let capture: Capture
    let canvas: CGSize

    var body: some View {
        let frame = DetailCardGeometry.frame(canvas: canvas, topInset: Tokens.Layout.titlebarInset,
                                             spec: Tokens.Detail.Layout.spec)
        ZStack {
            // Clicking anywhere but the card closes it. There is no scrim: the feed stays visible.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.closeDetail() }
                .accessibilityHidden(true)
            DetailCard(capture: capture, size: frame.size)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }
}

/// One glass shell for every capture: the feed shows through as blurred shapes, the
/// content region scrolls, the metadata bar stays fixed. No header, no close control.
struct DetailCard: View {
    static let coordinateSpace = "detailCard"

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotVariant) private var snapshotVariant
    @Environment(\.snapshotMode) private var snapshotMode
    let capture: Capture
    let size: CGSize

    @State private var shelfOpen = false
    @State private var triggerHot = false
    @State private var shelfHot = false
    @State private var shelfGraceTask: Task<Void, Never>?
    @State private var hoverPreview: ReferentHover?
    @State private var barHeight: CGFloat = Tokens.Detail.Layout.barMinHeight
    @FocusState private var contentFocused: Bool

    private var contentWidth: CGFloat { size.width - Tokens.Detail.Layout.contentPaddingH * 2 }
    /// Snapshots force the shelf open through the variant; the renderer does not run onAppear state.
    private var showsShelf: Bool { shelfOpen || snapshotVariant == "detail-shelf" }
    private var opaque: Bool { reduceTransparency || snapshotMode }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Detail.Radius.card, style: .continuous)
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                DetailContent(capture: capture, width: contentWidth)
                    .padding(.horizontal, Tokens.Detail.Layout.contentPaddingH)
                    .padding(.top, Tokens.Detail.Layout.contentPaddingTop)
                    .padding(.bottom, Tokens.Detail.Layout.contentPaddingBottom)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
            .focusable()
            .focused($contentFocused)
            .focusEffectDisabled()
            .accessibilityLabel(capture.intent == .quickAnswer ? "Question and answer" : "Transcript")

            Rectangle()
                .fill(Tokens.Detail.Colors.divider)
                .frame(height: 1)

            DetailMetadataBar(capture: capture, triggerHot: $triggerHot, shelfOpen: showsShelf)
                .padding(.horizontal, Tokens.Detail.Layout.barPaddingH)
                .padding(.vertical, Tokens.Detail.Layout.barPaddingV)
                .frame(minHeight: Tokens.Detail.Layout.barMinHeight)
                .background(Tokens.Detail.Colors.barLift)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
        }
        .background {
            // Translucency lives on the surface only; content above stays fully opaque.
            if opaque {
                shape.fill(Tokens.Detail.Colors.surfaceOpaque)
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Tokens.Detail.Colors.tint)
                }
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(opaque ? Tokens.Detail.Colors.borderFallback : Tokens.Detail.Colors.border, lineWidth: 1))
        .overlay(alignment: .top) {
            // Inner highlight along the top edge.
            Rectangle()
                .fill(Tokens.Detail.Colors.innerHighlight)
                .frame(height: 1)
                .padding(.horizontal, Tokens.Detail.Radius.card)
                .padding(.top, 1)
        }
        .background { DetailShadow(shape: shape) }
        .coordinateSpace(name: DetailCard.coordinateSpace)
        .overlay(alignment: .bottomLeading) {
            if showsShelf, !capture.referents.isEmpty {
                DetailReferentShelf(referents: capture.referents, hot: $shelfHot, hover: $hoverPreview,
                                    maxWidth: size.width - Tokens.Detail.Layout.barPaddingH * 2)
                    .padding(.leading, Tokens.Detail.Layout.barPaddingH)
                    .padding(.bottom, barHeight + 1 + Tokens.Detail.Layout.shelfGap)
                    .transition(snapshotMode ? .identity : .opacity.combined(with: .offset(y: 4)))
            }
        }
        .overlay(alignment: .topLeading) {
            if showsShelf, let hover = hoverPreview {
                ReferentHoverPreview(referent: hover.referent)
                    .offset(previewOffset(for: hover))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        // The offscreen snapshot renderer never advances animations, so it gets none.
        .animation(snapshotMode ? nil : Tokens.Motion.animation(.shelf, reduceMotion: reduceMotion, fadeOnly: true),
                   value: showsShelf)
        .animation(snapshotMode ? nil : Tokens.Motion.animation(.hover, reduceMotion: reduceMotion, fadeOnly: true),
                   value: hoverPreview)
        .background {
            // Escape closes the shelf first, then the card.
            Button("Close") {
                if shelfOpen { closeShelf() } else { model.closeDetail() }
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0).frame(width: 0, height: 0)
        }
        .onChange(of: triggerHot || shelfHot) { _, hot in
            shelfGraceTask?.cancel()
            if hot {
                shelfOpen = true
            } else {
                shelfGraceTask = Task {
                    try? await Task.sleep(for: Tokens.Motion.shelfGrace)
                    guard !Task.isCancelled else { return }
                    shelfOpen = false
                    hoverPreview = nil
                }
            }
        }
        .onAppear { contentFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Capture detail")
        .accessibilityHint("Press Escape to close")
    }

    /// Centers the preview above the hovered thumbnail and keeps it inside the card.
    private func previewOffset(for hover: ReferentHover) -> CGSize {
        let width = Tokens.Detail.Layout.previewWidth
        let height = ReferentHoverPreview.height(for: hover.referent)
        let minX = Tokens.Detail.Layout.barPaddingH
        let maxX = size.width - Tokens.Detail.Layout.barPaddingH - width
        let x = min(max(hover.frame.midX - width / 2, minX), max(minX, maxX))
        let y = max(Tokens.Space.m, hover.frame.minY - Tokens.Detail.Layout.previewGap - height)
        return CGSize(width: x, height: y)
    }

    private func closeShelf() {
        shelfGraceTask?.cancel()
        shelfOpen = false
        hoverPreview = nil
    }
}

/// The card's shadows, drawn only outside its outline so nothing sits behind the glass.
private struct DetailShadow: View {
    let shape: RoundedRectangle

    var body: some View {
        shape
            .fill(Color.black)
            .shadow(color: Tokens.Detail.Colors.shadowPrimary,
                    radius: Tokens.Detail.Layout.shadowPrimaryRadius, y: Tokens.Detail.Layout.shadowPrimaryY)
            .shadow(color: Tokens.Detail.Colors.shadowContact,
                    radius: Tokens.Detail.Layout.shadowContactRadius, y: Tokens.Detail.Layout.shadowContactY)
            .mask {
                ZStack {
                    Rectangle().fill(Color.black).padding(-Tokens.Detail.Layout.shadowPrimaryRadius * 4)
                    shape.fill(Color.black).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
