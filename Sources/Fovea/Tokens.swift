import SwiftUI
import FoveaCore

// Single source of truth for color, type, spacing, shape, layout and motion.
// Views never hardcode any of these values.

enum Tokens {

    // MARK: - Color (ink on paper; the Island is the same system inverted)

    enum Colors {
        /// The logo's ink. Every neutral below is this at an opacity, the way the
        /// Island's neutrals are white at an opacity: one system, two sides.
        static let ink = Color(hex: 0x0C0C0C)

        /// Three surfaces. The canvas is the logo field lifted halfway to white; pure
        /// white is reserved for what sits on top (groups, glass, popovers); the logo
        /// field itself is what sits below (sidebar, keycaps). Surfaces separate by
        /// tone, so hairlines can stay rare.
        static let canvas = Color(hex: 0xFBFAF7)
        static let elevated = Color(hex: 0xFFFFFF)
        static let group = Color(hex: 0xFFFFFF)
        static let sidebar = Color(hex: 0xF8F6EF)
        static let keycap = Color(hex: 0xF8F6EF)

        static let textPrimary = ink
        static let textSecondary = ink.opacity(0.58)
        static let textTertiary = ink.opacity(0.42)
        /// The `Aa` control and other bare glyph actions.
        static let glyph = ink.opacity(0.62)
        static let hairline = ink.opacity(0.08)
        static let hairlineStrong = ink.opacity(0.12)
        static let hover = ink.opacity(0.04)
        static let pressed = ink.opacity(0.07)
        /// The current item in the settings sidebar, and the row Home just received.
        static let selection = ink.opacity(0.08)
        /// Gray-fill controls (quiet buttons, the chosen segment) and their hover step.
        static let control = ink.opacity(0.05)
        static let controlHover = ink.opacity(0.08)
        static let field = ink.opacity(0.05)
        static let ringTrack = ink.opacity(0.10)
        static let skeleton = ink.opacity(0.06)
        static let scrim = ink.opacity(0.42)

        static let positive = Color(hex: 0x1F7A3D)
        static let warning = Color(hex: 0xC2410C)
        static let destructive = Color(hex: 0xC53030)

        /// Agent task state on paper, always beside the word, never color alone. The
        /// Island's amber and coral are mixed for black; these are the same two roles
        /// mixed for the canvas (both above 5:1 on it).
        static let needsYou = Color(hex: 0x8A5A00)
        static let failed = Color(hex: 0xB93A1A)

        // Code / terminal previews: dark tiles, the same on either surface.
        static let codeSurface = Color(hex: 0x1E2029)
        static let codeText = Color(hex: 0xE4E5EB)
        static let codeKeyword = Color(hex: 0xC792EA)
        static let codeConstant = Color(hex: 0xF78C6C)
        static let codeString = Color(hex: 0xC3E88D)
        static let codeMuted = Color(hex: 0x8A8FA3)
        static let codeSuccess = Color(hex: 0x4ADE80)
        static let chartLine = Color(hex: 0x2F6BFF)
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
        /// The Home column: the ledger and its date headings.
        static let feedMaxWidth: CGFloat = 940
        static let feedHorizontalPadding: CGFloat = 36
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

    // MARK: - Ledger (Home rows: the Island's Agent list row, on paper)

    enum Ledger {
        /// The Island list row is 46 pt around 13.5/11.5 pt type; the ledger's 14/12.5 pt
        /// pair beside a 32 pt thumbnail wants a little more.
        static let rowHeight: CGFloat = 52
        static let rowPaddingH: CGFloat = 12
        static let iconGap: CGFloat = 12
        static let rowRadius: CGFloat = 7
        static let rowGap: CGFloat = 1
        static let groupGap: CGFloat = 28
        /// The Island's referent thumbnail, exactly (`Tokens.Island.Layout.thumb`).
        static let thumb = CGSize(width: 44, height: 32)
        static let thumbRadius: CGFloat = 6
        static let stackLayerOffset: CGFloat = 7
        static let stackMaxLayers = 3
        static let stackSpacing: CGFloat = 6
        static let statusDot: CGFloat = 5
        static let markSize: CGFloat = 12
        static let intent = Font.system(size: 14, weight: .regular)
        static let meta = Font.system(size: 12.5, weight: .regular)
        static let status = Font.system(size: 12.5, weight: .medium)

        static var stackConfig: ReferentStackLayout.Config {
            ReferentStackLayout.Config(thumb: thumb, spacing: stackSpacing, layerOffset: stackLayerOffset,
                                       maxLayers: stackMaxLayers)
        }
        /// The "what you saw" column is as wide as a full three-layer stack, so titles
        /// align whether a row shows referents or the source app.
        static var seenColumnWidth: CGFloat {
            ReferentStackLayout.collapsedWidth(count: stackMaxLayers, config: stackConfig)
        }
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
            static let borderFallback = Color(hex: 0x0C0C0C).opacity(0.08)
            static let innerHighlight = Color.white.opacity(0.72)
            static let shadowPrimary = Color(hex: 0x0C0C0C).opacity(0.14)
            static let shadowContact = Color(hex: 0x0C0C0C).opacity(0.08)
            static let foreground = Color(hex: 0x0C0C0C).opacity(0.92)
            static let muted = Color(hex: 0x0C0C0C).opacity(0.55)
            static let divider = Color(hex: 0x0C0C0C).opacity(0.08)
            /// Metadata bar sits on the same glass with a faint lift.
            static let barLift = Color.white.opacity(0.16)
            static let tagFill = Color(hex: 0x0C0C0C).opacity(0.05)
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
