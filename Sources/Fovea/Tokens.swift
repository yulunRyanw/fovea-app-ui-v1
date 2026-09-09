import SwiftUI
import FoveaCore

// Single source of truth for color, type, spacing, shape, layout and motion.
// Views never hardcode any of these values.

enum Tokens {

    // MARK: - Color

    /// A feed palette: four colors, and they reach exactly one thing — the
    /// highlighted words on Home. Not the canvas, not the chrome, not a control.
    /// Everything else in the app stays neutral.
    struct Theme: Equatable {
        /// The four source colors, in palette order. Every one gets used: a
        /// highlighted word takes one of them, picked from the capture's own seed.
        let hexes: [UInt32]
        var colors: [Color] { hexes.map(Color.init(hex:)) }
        subscript(i: Int) -> Color {
            Color(hex: hexes[((i % hexes.count) + hexes.count) % hexes.count])
        }
        init(colors: [UInt32]) { self.hexes = colors }
    }

    enum Colors {
        static let canvas = Color(hex: 0xFFFFFF)
        static let sidebar = Color(hex: 0xF4F4F5)
        static let elevated = Color(hex: 0xFFFFFF)
        /// Grouped setting surface (barely off-white so groups read against the canvas).
        static let group = Color(hex: 0xFFFFFF)
        static let textPrimary = Color(hex: 0x1B1B1F)
        static let textSecondary = Color(hex: 0x6B6E76)
        static let textTertiary = Color(hex: 0x9A9DA5)
        /// The `Aa` control and other bare glyph actions.
        static let glyph = Color(hex: 0x60636B)
        static let hairline = Color.black.opacity(0.08)
        static let hairlineStrong = Color.black.opacity(0.12)
        static let hover = Color.black.opacity(0.04)
        static let pressed = Color.black.opacity(0.07)
        /// The current item in the settings sidebar: a neutral pill, never the accent.
        static let selection = Color.black.opacity(0.08)
        /// Gray-fill controls (quiet buttons, the chosen segment) and their hover step.
        static let control = Color(hex: 0xF0F0F2)
        static let controlHover = Color(hex: 0xE6E6E9)
        static let field = Color(hex: 0xF2F2F4)
        static let ringTrack = Color(hex: 0xE4E4E7)
        static let skeleton = Color(hex: 0xEEEEF0)
        static let scrim = Color.black.opacity(0.42)
        static let positive = Color(hex: 0x1F7A3D)
        static let warning = Color(hex: 0xC2410C)
        static let destructive = Color(hex: 0xC53030)
        static let keycap = Color(hex: 0xF4F4F5)

        // Code / terminal previews
        static let codeSurface = Color(hex: 0x1E2029)
        static let codeText = Color(hex: 0xE4E5EB)
        static let codeKeyword = Color(hex: 0xC792EA)
        static let codeConstant = Color(hex: 0xF78C6C)
        static let codeString = Color(hex: 0xC3E88D)
        static let codeMuted = Color(hex: 0x8A8FA3)
        static let codeSuccess = Color(hex: 0x4ADE80)
        static let chartLine = Color(hex: 0x2F6BFF)

        /// The word every un-highlighted anchor is set in. A warm near-black:
        /// #000000 reads synthetic at this size, and a cool grey fights the palettes.
        static let anchorInk = Color(hex: 0x1A120B)

        /// Neutral emphasis for chrome that used to take the accent — prominent
        /// buttons, focus rings, the usage arc. Deliberately not a palette color:
        /// the palette belongs to the words.
        static let emphasis = Color(hex: 0x1F1A15)

        /// The four palette members, exactly as published on Color Hunt — no
        /// darkening, no substitutions. Several members are pale enough that a word
        /// set in them is very low contrast on white (Citrus `#FFF1D1` is 1.1:1,
        /// Blush is all pastel); that is the intended trade for palette fidelity.
        /// `Tokens.Colors.contrastOnCanvas` reports the real ratios.
        static func theme(_ t: ThemeName) -> Theme {
            switch t {
            case .paper:   return Theme(colors: [c(0x1A120B), c(0x4A342A), c(0x7A6152), c(0xA38B78)])
            case .citrus:  return Theme(colors: [c(0xDF301C), c(0xFF9100), c(0xFFF1D1), c(0x00B7CD)])
            case .orchard: return Theme(colors: [c(0x2A7C13), c(0x76C457), c(0xFFF8CF), c(0xFBE6C2)])
            case .dusk:    return Theme(colors: [c(0xFDF4D2), c(0xB0CDE6), c(0xA290B7), c(0x946D6D)])
            case .canyon:  return Theme(colors: [c(0x0F3040), c(0x464858), c(0xA56F63), c(0xD99B7F)])
            case .blush:   return Theme(colors: [c(0xFFB6B9), c(0xFAE3D9), c(0xBBDED6), c(0x61C0BF)])
            case .roast:   return Theme(colors: [c(0x1A120B), c(0x3C2A21), c(0xD5CEA3), c(0xE5E5CB)])
            }
        }

        /// Contrast of each member against the white feed canvas, for the settings
        /// page to show honestly rather than the app pretending they all work.
        static func contrastOnCanvas(_ t: ThemeName) -> [Double] {
            theme(t).hexes.map { hex in
                func chan(_ v: UInt32) -> Double {
                    let c = Double(v) / 255
                    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
                }
                let l = 0.2126 * chan((hex >> 16) & 0xFF)
                      + 0.7152 * chan((hex >> 8) & 0xFF)
                      + 0.0722 * chan(hex & 0xFF)
                return (1.05) / (l + 0.05)
            }
        }

        private static func c(_ hex: UInt32) -> UInt32 { hex }
    }

    // MARK: - Type (system font, SF Pro on macOS)

    enum Type_ {
        static let pageTitle = Font.system(size: 30, weight: .regular)
        static let section = Font.system(size: 15, weight: .semibold)
        /// Settings section headers; Home's empty states keep `section`.
        static let settingsSection = Font.system(size: 16, weight: .medium)
        static let rowLabel = Font.system(size: 14.5, weight: .regular)
        static let rowValue = Font.system(size: 13.5, weight: .regular)
        static let secondary = Font.system(size: 12.5, weight: .regular)
        static let body = Font.system(size: 13, weight: .regular)
        static let bodyMedium = Font.system(size: 13, weight: .medium)
        static let caption = Font.system(size: 11.5, weight: .regular)
        static let captionMedium = Font.system(size: 11.5, weight: .medium)
        static let sidebarItem = Font.system(size: 14.5, weight: .regular)
        static let sidebarGroup = Font.system(size: 12.5, weight: .regular)
        static let dateHeading = Font.system(size: 15, weight: .semibold)
        static let dateSubtitle = Font.system(size: 12, weight: .regular)
        static let timeLabel = Font.system(size: 12, weight: .regular)
        static let dictionaryAction = Font.system(size: 14.5, weight: .medium)
        static let search = Font.system(size: 13, weight: .regular)
        static let button = Font.system(size: 13, weight: .medium)
        static let mono = Font.system(size: 10.5, design: .monospaced)
        static let monoDetail = Font.system(size: 14, design: .monospaced)
        static let equation = Font.system(size: 20, weight: .regular, design: .serif)
        static let transcript = Font.system(size: 20, weight: .regular)

        /// Anchor words. The single funnel for feed type — everything about which
        /// face a word gets is decided here.
        ///
        /// `face` nil, or a face that failed to register, falls back to the system
        /// font rather than silently rendering the wrong family. Single-weight faces
        /// never get asked for medium or semibold: Core Text would synthesise the
        /// bold and smear the outlines, so their emphasis comes from size alone
        /// (the caller already sizes leads at 22–27 pt against 15–19 pt quiet words).
        static func anchor(size: CGFloat, weight: Int, face: FeedFont? = nil) -> Font {
            let w: Font.Weight = weight >= 2 ? .semibold : (weight == 1 ? .medium : .regular)
            guard let face, FontRegistry.isAvailable(face) else {
                return .system(size: size, weight: w)
            }
            let custom = Font.custom(face.family, size: size)
            return face.isSingleWeight ? custom : custom.weight(w)
        }
    }

    // MARK: - Spacing

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 44
    }

    // MARK: - Shape

    enum Radius {
        static let group: CGFloat = 12
        static let control: CGFloat = 8
        static let row: CGFloat = 7
        static let image: CGFloat = 7
        static let chip: CGFloat = 5
        static let field: CGFloat = 18
        static let pill: CGFloat = 8
    }

    // MARK: - Layout

    enum Layout {
        /// The one window size. It cannot be resized.
        static let window = CGSize(width: 980, height: 680)
        /// Every screen is laid out at this size and scaled down uniformly into the window.
        static let designCanvas = CGSize(width: 1180, height: 819)
        static let uiScale: CGFloat = 980.0 / 1180.0
        /// Room for the traffic lights under the hidden title bar.
        static let titlebarInset: CGFloat = 52
        static let feedMaxWidth: CGFloat = 940
        static let feedHorizontalPadding: CGFloat = 36
        static let feedRowTargetHeight: CGFloat = 130
        static let feedSpacing: CGFloat = 22
        static let feedRowGap: CGFloat = 26
        static let feedGroupGap: CGFloat = 36
        static let feedLabelHeight: CGFloat = 22
        /// Feed widths at or above this use the wide cap.
        static let wideFeedThreshold: CGFloat = 920
        static let maxItemsPerRowWide = 6
        static let maxItemsPerRowNarrow = 4
        /// Every feed row holds this many cards.
        static let cardsPerRow = 6
        static let headerSearchMaxWidth: CGFloat = 540
        static let headerSearchHeight: CGFloat = 36
        static let avatarSize: CGFloat = 30
        static let ringWidth: CGFloat = 1.75
        static let ringGap: CGFloat = 2.5
        static let hitTarget: CGFloat = 32
        static let sidebarWidth: CGFloat = 224
        static let sidebarItemHeight: CGFloat = 38
        static let sidebarInset: CGFloat = 12
        static let settingsGroupMaxWidth: CGFloat = 720
        /// Minimum gutter either side of the centered settings column.
        static let settingsPagePadding: CGFloat = 48
        static let rowHeight: CGFloat = 48
        static let rowPaddingH: CGFloat = 18
        static let rowPaddingV: CGFloat = 13
        /// Buttons, menus, fields and segments inside a row.
        static let controlHeight: CGFloat = 30
    }

    // MARK: - Motion
    //
    // Rules (master build prompt §10, PRD §14): motion explains feedback, state or origin;
    // strong ease-out for entrances, never ease-in; enter and exit along the same path;
    // interruptible; no bounce — geometry moves on critically damped springs.

    enum Motion {
        /// Strong ease-out for entering UI; never ease-in.
        static let curve = UnitCurve.bezier(startControlPoint: .init(x: 0.23, y: 1), endControlPoint: .init(x: 0.32, y: 1))
        /// The same curve for Core Animation (window frame glides).
        static let caTimingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)

        enum Kind {
            case hover, pressDown, pressUp, popover, select, accordion, sheet
            /// Detail card: quick zoom in, slightly quicker zoom out; the referent shelf unfolds.
            case detailOpen, detailClose, shelf
            /// Island content crossfades, selector steps, referent preview, the sent-row highlight.
            case islandContent, selectorStep, preview, highlightFade
            var duration: Double {
                switch self {
                case .hover: return 0.12
                case .pressDown: return 0.08
                case .pressUp: return 0.14
                case .popover: return 0.16
                case .select: return 0.18
                case .accordion: return 0.2
                case .sheet: return 0.24
                case .detailOpen: return 0.2
                case .detailClose: return 0.17
                case .shelf: return 0.18
                case .islandContent: return 0.14
                case .selectorStep: return 0.16
                case .preview: return 0.14
                case .highlightFade: return 0.24
                }
            }
        }

        static func animation(_ kind: Kind) -> Animation {
            .timingCurve(curve, duration: kind.duration)
        }

        /// Reduced motion: movement becomes an instant state change (nil) or a short fade.
        static func animation(_ kind: Kind, reduceMotion: Bool, fadeOnly: Bool = false) -> Animation? {
            guard reduceMotion else { return animation(kind) }
            return fadeOnly ? .easeOut(duration: 0.1) : nil
        }

        /// Island geometry moves on critically damped springs (no overshoot) so it feels
        /// continuous with the top edge and retargets cleanly when interrupted.
        enum Spring {
            case open, close, convert, hover
            var animation: Animation {
                switch self {
                case .open: return .smooth(duration: 0.34)
                case .close: return .smooth(duration: 0.30)
                case .convert: return .smooth(duration: 0.28)
                case .hover: return .smooth(duration: 0.18)
                }
            }
        }

        /// Reduced motion turns springs into short crossfades.
        static func spring(_ s: Spring, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: 0.12) : s.animation
        }

        /// Which spring moves the island between two states; nil when nothing should animate.
        static func islandAnimation(from: IslandState, to: IslandState, reduceMotion: Bool) -> Animation? {
            let before = from.phase, after = to.phase
            // State-level keys: the dock receiver is geometry without a phase of its own.
            if from.layoutKey != to.layoutKey || from.density != to.density {
                if reduceMotion { return .easeOut(duration: 0.12) }
                if before == .agentList || after == .agentList { return Spring.hover.animation }
                let rankBefore = from.density.rank, rankAfter = to.density.rank
                if rankBefore == rankAfter { return Spring.convert.animation }
                return rankAfter > rankBefore ? Spring.open.animation : Spring.close.animation
            }
            if from.review?.selector != to.review?.selector { return spring(.convert, reduceMotion: reduceMotion) }
            if from.review?.stackExpanded != to.review?.stackExpanded
                || from.review?.hoveredReferentId != to.review?.hoveredReferentId {
                return spring(.convert, reduceMotion: reduceMotion)
            }
            if from.recentlySentTaskId != to.recentlySentTaskId { return animation(.highlightFade, reduceMotion: reduceMotion, fadeOnly: true) }
            // near ↔ ready only brightens the receiver; its geometry is the same.
            if from.dockZone != to.dockZone { return animation(.hover, reduceMotion: reduceMotion, fadeOnly: true) }
            return nil
        }

        /// Content crossfade: opacity with a light blur and a small scale from the top.
        static let contentBlur: CGFloat = 4
        static let contentScale: CGFloat = 0.97
        static let contentDelay: Double = 0.05

        /// Docking a detached Quick Answer. The panel flies home on a critically damped
        /// spring as long as the island's open spring, so both land together, and fades
        /// out over the last part of the way so the growing slab swallows it.
        enum Dock {
            static let flightDuration: CGFloat = 0.34
            /// The fade runs between these fractions of the distance still to travel.
            static let fadeStart: CGFloat = 0.45
            static let fadeEnd: CGFloat = 0.05
            /// How far the drawn panel leans toward the notch once release would dock (0…1).
            static let magnetism: CGFloat = 0.35
            /// The release velocity is measured over this window.
            static let velocityWindow: TimeInterval = 0.08
        }

        /// The pointer must rest on the notch this long before the Agent list opens.
        static let hoverDwell: Duration = .milliseconds(100)
        /// Pointer may leave the island this long before it collapses.
        static let exitGrace: Duration = .milliseconds(90)
        /// After a phase change the pointer zone is re-checked once the geometry has settled.
        static let settleCheck: Duration = .milliseconds(400)
        /// After Send the Agent list stays this long with the new task highlighted.
        static let sentGrace: Duration = .milliseconds(3500)
        /// "Didn't catch that" offers Retry for this long, then the island rests.
        static let failureCountdown: Duration = .seconds(2)
        /// Search Chats waits this long after the last keystroke.
        static let searchDebounce: Duration = .milliseconds(150)
        /// The fanned-out referent stack stays open this long after the pointer leaves it.
        static let stackGrace: Duration = .milliseconds(120)
        /// Resting point breathing period, seconds.
        static let breathePeriod: Double = 3.2
        /// Placeholder breathing period ("Choosing Chat"), seconds.
        static let placeholderPulse: Double = 0.9
        /// The referent shelf stays open this long after the pointer leaves it or its trigger.
        static let shelfGrace: Duration = .milliseconds(120)
        /// The referent shelf rises this far as it fades in.
        static let shelfRise: CGFloat = 4
        /// Detail card zoom starts at this scale (about the source card).
        static let detailZoomScale: CGFloat = 0.96
    }

    // MARK: - Detail card (frosted glass, centered over the feed; TRANSLUCENT_CARD_MATERIAL_SPEC)

    enum Detail {
        enum Colors {
            /// White tint over the system material. The spec's 0.80 assumes a bare blur;
            /// `.ultraThinMaterial` already adds whiteness, so 0.40 keeps the feed clearly
            /// visible through it. Calibrate between 0.30 and 0.60 before touching anything else.
            static let tint = Color.white.opacity(0.40)
            /// Reduce Transparency and offscreen renders: opaque surface, spec fallback.
            static let surfaceOpaque = Color.white.opacity(0.94)
            static let border = Color.white.opacity(0.58)
            static let borderFallback = Color(hex: 0x0F172A).opacity(0.08)
            static let innerHighlight = Color.white.opacity(0.72)
            static let shadowPrimary = Color(hex: 0x0F172A).opacity(0.14)
            static let shadowContact = Color(hex: 0x0F172A).opacity(0.08)
            static let foreground = Color(hex: 0x0F172A).opacity(0.92)
            static let muted = Color(hex: 0x0F172A).opacity(0.55)
            static let divider = Color(hex: 0x0F172A).opacity(0.08)
            /// Metadata bar sits on the same glass with a faint lift.
            static let barLift = Color.white.opacity(0.16)
            static let tagFill = Color(hex: 0x0F172A).opacity(0.05)
            static let thumbRim = Color.white
            static let thumbShadow = Color.black.opacity(0.14)
            static let shelfSurface = Color.white
            static let previewSurface = Color.white
        }

        enum Type_ {
            static let body = Font.system(size: 14, weight: .regular)
            /// ~1.55 line height at 14 pt.
            static let bodyLineSpacing: CGFloat = 5
            /// Section labels match the body; they differ by color only.
            static let label = Font.system(size: 14, weight: .regular)
            static let meta = Font.system(size: 14, weight: .regular)
            static let question = Font.system(size: 14, weight: .medium)
        }

        enum Radius {
            static let card: CGFloat = 20
            static let thumb: CGFloat = 7
            static let shelf: CGFloat = 12
            static let preview: CGFloat = 12
        }

        enum Layout {
            static let widthFraction: CGFloat = 0.62
            static let heightFraction: CGFloat = 0.48
            static let maxSize = CGSize(width: 1120, height: 680)
            static let minSize = CGSize(width: 640, height: 400)
            static let margin: CGFloat = 24
            static let contentPaddingTop: CGFloat = 40
            static let contentPaddingH: CGFloat = 48
            static let contentPaddingBottom: CGFloat = 28
            static let barMinHeight: CGFloat = 72
            static let barPaddingV: CGFloat = 14
            static let barPaddingH: CGFloat = 40
            static let barGap: CGFloat = 20
            static let columnGap: CGFloat = 28
            /// Question column share of the content width in Quick Answer.
            static let questionFraction: CGFloat = 0.36
            static let thumb = CGSize(width: 28, height: 28)
            static let thumbRim: CGFloat = 2
            static let stackLayerOffset: CGFloat = 6
            static let stackSpacing: CGFloat = 6
            static let stackMaxLayers = 3
            static let shelfThumb = CGSize(width: 56, height: 56)
            static let shelfPadding: CGFloat = 8
            static let shelfGap: CGFloat = 8
            static let tagMaxVisible = 3
            static let tagHeight: CGFloat = 26
            static let destinationGlyph: CGFloat = 20
            /// Hover preview of one referent, floating above the shelf.
            static let previewWidth: CGFloat = 320
            static let previewGap: CGFloat = 10
            static let previewCaption: CGFloat = 30
            // Spec: 0 24 64 (primary), 0 4 14 (contact). SwiftUI radius ≈ half the CSS blur.
            static let shadowPrimaryRadius: CGFloat = 32
            static let shadowPrimaryY: CGFloat = 24
            static let shadowContactRadius: CGFloat = 7
            static let shadowContactY: CGFloat = 4

            static var spec: DetailCardGeometry.Spec {
                var s = DetailCardGeometry.Spec()
                s.widthFraction = widthFraction
                s.heightFraction = heightFraction
                s.maxSize = maxSize
                s.minSize = minSize
                s.margin = margin
                return s
            }

            static var stackConfig: ReferentStackLayout.Config {
                ReferentStackLayout.Config(thumb: thumb, spacing: stackSpacing, layerOffset: stackLayerOffset,
                                           maxLayers: stackMaxLayers)
            }
        }
    }
    // MARK: - Island (black surface around the notch; PRD: no gradients, SF Pro only)

    enum Island {
        enum Colors {
            static let surface = Color(hex: 0x000000)
            /// Detached panel and menus, one step off black.
            static let surfaceElevated = Color(hex: 0x111114)
            static let textPrimary = Color.white
            static let textSecondary = Color.white.opacity(0.62)
            static let textTertiary = Color.white.opacity(0.40)
            static let hairline = Color.white.opacity(0.10)
            static let hover = Color.white.opacity(0.06)
            static let pressed = Color.white.opacity(0.10)
            static let field = Color.white.opacity(0.08)
            static let waveform = Color.white
            static let progressTrack = Color.white.opacity(0.14)
            static let progressFill = Color.white.opacity(0.85)
            /// Status tints; always paired with the status word.
            static let needsYou = Color(hex: 0xF5B84B)
            static let failed = Color(hex: 0xF06A6A)
            static let dockOutline = Color.white.opacity(0.35)
            /// The receiver's well: dim while the panel approaches, brighter once release docks.
            static let dockWell = Color.white.opacity(0.06)
            static let dockWellReady = Color.white.opacity(0.12)
            static let focus = Color.white.opacity(0.7)
            /// The current choice in a list (No Folder, the selected Chat).
            static let selection = Color.white.opacity(0.12)
            /// The task Send just created, while the list acknowledges it.
            static let recentHighlight = Color.white.opacity(0.10)
        }

        enum Type_ {
            static let body = Font.system(size: 13.5, weight: .regular)
            static let bodyMedium = Font.system(size: 13.5, weight: .medium)
            static let secondary = Font.system(size: 11.5, weight: .regular)
            static let status = Font.system(size: 11.5, weight: .medium)
            static let question = Font.system(size: 14, weight: .semibold)
            static let transcript = Font.system(size: 14, weight: .regular)
            static let answer = Font.system(size: 13.5, weight: .regular)
            static let pill = Font.system(size: 12, weight: .medium)
            static let chip = Font.system(size: 11, weight: .semibold)
        }

        enum Radius {
            static var compactTop: CGFloat { Layout.layoutSpec.compactTopRadius }
            static var compactBottom: CGFloat { Layout.layoutSpec.compactBottomRadius }
            static var expandedTop: CGFloat { Layout.layoutSpec.expandedTopRadius }
            static var expandedBottom: CGFloat { Layout.layoutSpec.expandedBottomRadius }
            static var slabBottom: CGFloat { Layout.layoutSpec.slabBottomRadius }
            static let detached: CGFloat = 16
            /// The receiver's well, concentric with the slab's bottom corners.
            static let dockWell: CGFloat = 12
            static let thumb: CGFloat = 6
            static let pill: CGFloat = 9
            static let field: CGFloat = 9
            static let row: CGFloat = 7
        }

        enum Layout {
            /// Geometry numbers live in Core's `IslandLayoutSpec` (its defaults are the
            /// production values, so FoveaCoreTests can assert them); the tokens below
            /// re-export them. Every other Island number lives here.
            static let layoutSpec = IslandLayoutSpec()
            static var softwareIslandWidth: CGFloat { layoutSpec.softwareIslandWidth }
            static var voiceBelow: CGFloat { layoutSpec.voiceBelow }
            static var listWidth: CGFloat { layoutSpec.listWidth }
            static var reviewWidth: CGFloat { layoutSpec.reviewWidth }
            static var slabWidth: CGFloat { layoutSpec.slabWidth }
            static var dockSnapDistance: CGFloat { layoutSpec.dockSnapDistance }
            static var dockApproachDistance: CGFloat { layoutSpec.dockApproachDistance }
            static var dockReceiverBelow: CGFloat { layoutSpec.dockReceiverBelow }

            // Voice states: content inside the 44 pt below the notch.
            static let voiceContentPaddingH: CGFloat = 16
            static let voicePaddingV: CGFloat = 6
            static let voiceRowHeight: CGFloat = 24
            static let voiceRowGap: CGFloat = 6
            static let voiceProgressHeight: CGFloat = 2
            static let waveformBars = 9
            static let waveformBarWidth: CGFloat = 3
            static let waveformBarGap: CGFloat = 3
            static let waveformMinHeight: CGFloat = 4
            static let waveformMaxHeight: CGFloat = 20

            // Agent list: two-line rows, five visible, then it scrolls.
            static let listRowHeight: CGFloat = 46
            static let listRowsVisible = 5
            static let listPadding: CGFloat = 8
            static let listIconSize: CGFloat = 18
            static let listStatusDot: CGFloat = 5

            // Review
            static let reviewPadding: CGFloat = 18
            static let editorMinHeight: CGFloat = 60
            static let editorMaxHeight: CGFloat = 160
            static let thumb = CGSize(width: 44, height: 32)
            static let stackLayerOffset: CGFloat = 7
            static let stackMaxLayers = 3
            static let stackSpacing: CGFloat = 6
            static let stackRowSpacing: CGFloat = 6
            static let referentPreviewWidth: CGFloat = 260
            static let referentPreviewMaxImageHeight: CGFloat = 180
            static let referentPreviewCaption: CGFloat = 24
            static let referentPreviewGap: CGFloat = 8
            static let pillHeight: CGFloat = 28
            static let pillResolvingWidth: CGFloat = 132
            static let pillMaxWidth: CGFloat = 150
            static let sendButtonSize: CGFloat = 28

            // Chat selector panel
            static let selectorPanelPadding: CGFloat = 8
            static let selectorHeaderHeight: CGFloat = 24
            static let selectorRowHeight: CGFloat = 30
            static let selectorResultRowHeight: CGFloat = 44
            static let selectorGridColumns = 2
            static let selectorGridSpacing: CGFloat = 4
            static let folderRowsVisible = 5
            static let selectorSearchFieldHeight: CGFloat = 28

            // Quick Answer
            static let slabMaxHeight: CGFloat = 420
            static let slabPadding: CGFloat = 30
            static let followUpWidthFraction: CGFloat = 0.46
            static let followUpHeight: CGFloat = 32
            static let grabber = CGSize(width: 36, height: 5)
            static let grabberHitHeight: CGFloat = 20
            static let detachedDefault = CGSize(width: 520, height: 360)
            static let iconSize: CGFloat = 16
            static let restingDot: CGFloat = 4
            static let closeGlyphSize: CGFloat = 10

            // Dock receiver: the notch opened for a returning Quick Answer.
            static let dockWellInset: CGFloat = 10
            static let dockGlyphSize: CGFloat = 12
            /// A scenario jump drops the floating panel this far below the notch.
            static let detachedScenarioDrop: CGFloat = 80

            // Bookmark rail: one tick per question in the right margin, from four questions.
            static let bookmarkRailMinQuestions = 4
            static let bookmarkTick = CGSize(width: 12, height: 2)
            static let bookmarkTickHover: CGFloat = 18
            static let bookmarkRailSpacing: CGFloat = 6
            static let bookmarkRailHit: CGFloat = 20
            static let bookmarkRailInset: CGFloat = 8
            static let bookmarkLabelMaxWidth: CGFloat = 220

            static var stackConfig: ReferentStackLayout.Config {
                ReferentStackLayout.Config(thumb: thumb, spacing: stackSpacing, layerOffset: stackLayerOffset,
                                           maxLayers: stackMaxLayers, rowSpacing: stackRowSpacing)
            }
        }
    }

}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
