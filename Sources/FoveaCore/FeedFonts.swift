import Foundation

/// The faces the Home feed can set its anchor words in.
///
/// Each case maps to one file in `Resources/Fonts`, registered at launch (see
/// `FontRegistry` in the app target). `family` is the name Core Text answers to
/// once the file is registered — for the variable faces this is the family, not the
/// PostScript name, because a variable font's default instance is whatever the
/// designer shipped (Fraunces defaults to Black, Archivo to SemiBold) and asking
/// for it by PostScript name would pin every word to that weight.
public enum FeedFont: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case instrumentSerif = "instrument-serif"
    case fraunces
    case ebGaramond = "eb-garamond"
    case bricolage
    case syne
    case archivo
    case biorhyme
    case specialGothic = "special-gothic"
    case dmSans = "dm-sans"
    case karla

    public var id: String { rawValue }

    /// What a card's highlighted words use (`display`) versus its quiet words (`text`).
    public enum Role: String, Codable, Hashable, Sendable { case display, text }

    public var role: Role {
        switch self {
        case .dmSans, .karla: return .text
        default: return .display
        }
    }

    public var displayName: String {
        switch self {
        case .instrumentSerif: return "Instrument Serif"
        case .fraunces: return "Fraunces"
        case .ebGaramond: return "EB Garamond"
        case .bricolage: return "Bricolage Grotesque"
        case .syne: return "Syne"
        case .archivo: return "Archivo"
        case .biorhyme: return "BioRhyme"
        case .specialGothic: return "Special Gothic Condensed One"
        case .dmSans: return "DM Sans"
        case .karla: return "Karla"
        }
    }

    /// The Core Text family name, post-registration.
    public var family: String { displayName }

    /// Filename under `Resources/Fonts`.
    public var file: String {
        switch self {
        case .instrumentSerif: return "InstrumentSerif-Regular.ttf"
        case .fraunces: return "Fraunces[SOFT,WONK,opsz,wght].ttf"
        case .ebGaramond: return "EBGaramond[wght].ttf"
        case .bricolage: return "BricolageGrotesque[opsz,wdth,wght].ttf"
        case .syne: return "Syne[wght].ttf"
        case .archivo: return "Archivo[wdth,wght].ttf"
        case .biorhyme: return "BioRhyme[wdth,wght].ttf"
        case .specialGothic: return "SpecialGothicCondensedOne-Regular.ttf"
        case .dmSans: return "DMSans[opsz,wght].ttf"
        case .karla: return "Karla[wght].ttf"
        }
    }

    /// Faces that ship a single weight. Asking these for semibold gets a synthetic
    /// smear, so emphasis has to come from size instead.
    public var isSingleWeight: Bool {
        self == .instrumentSerif || self == .specialGothic
    }

    /// One short line for the settings row.
    public var note: String {
        switch self {
        case .instrumentSerif: return "High-contrast editorial display. One weight."
        case .fraunces: return "Old-style with a wonk axis — the characterful one."
        case .ebGaramond: return "Classical old-style. Calms a crowded row down."
        case .bricolage: return "Variable grotesque, drawn to be mixed."
        case .syne: return "Experimental, drawn for an art centre. The wildcard."
        case .archivo: return "Grotesque with a width axis for long words."
        case .biorhyme: return "Wide slab with unusual proportions."
        case .specialGothic: return "Condensed poster face. Long captures fit. One weight."
        case .dmSans: return "Neutral geometric — recedes at 16 pt."
        case .karla: return "Same job with more voice."
        }
    }

    /// Shipped on by default: the whole set, so the feed looks like the proposal
    /// out of the box and can be narrowed from Settings.
    public static let defaultEnabled: [FeedFont] = allCases

    /// The faces a card can pick from, given what the user left enabled.
    /// Falls back to the full set rather than rendering nothing.
    public static func pool(_ enabled: [FeedFont], role: Role) -> [FeedFont] {
        let on = enabled.isEmpty ? allCases : enabled
        let matching = on.filter { $0.role == role }
        if !matching.isEmpty { return matching }
        // No text face left on: quiet words follow whatever is enabled.
        return on
    }
}
