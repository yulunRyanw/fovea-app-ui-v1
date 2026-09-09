# Bundled fonts

Ten families used by the Home feed's semantic-fingerprint cards. Every one is from
the official Google Fonts repository (github.com/google/fonts) under the
SIL Open Font License 1.1. The matching `OFL-<family>.txt` ships beside each file,
which is what the licence requires for redistribution inside an application.

Registered at launch by `Sources/Fovea/App/FontRegistry.swift` via
`CTFontManagerRegisterFontsForURL`, not via `ATSApplicationFontsPath` — the
Info.plist only exists in `build/Fovea.app`, and `swift run Fovea` has none.

| file | family | role |
|---|---|---|
| InstrumentSerif-Regular.ttf | Instrument Serif | display, one weight |
| Fraunces[SOFT,WONK,opsz,wght].ttf | Fraunces | display, variable |
| EBGaramond[wght].ttf | EB Garamond | display, variable |
| BricolageGrotesque[opsz,wdth,wght].ttf | Bricolage Grotesque | display, variable |
| Syne[wght].ttf | Syne | display, variable |
| Archivo[wdth,wght].ttf | Archivo | display, variable |
| BioRhyme[wdth,wght].ttf | BioRhyme | display, variable |
| SpecialGothicCondensedOne-Regular.ttf | Special Gothic Condensed One | display, one weight |
| DMSans[opsz,wght].ttf | DM Sans | text, variable |
| Karla[wght].ttf | Karla | text, variable |

Refresh with `scripts/fetch-fonts.sh`.
