# Fovea brand assets

The reverse-F mark on a quiet warm-ivory field; masters and exports from the logo package.

- `fovea-mark.svg` / `fovea-mark-reversed.svg` — the mark in ink / in white, on transparency.
- `fovea-app-icon.svg` / `fovea-app-icon-dark.svg` — rounded-square app icon masters (light field / dark field).
- `fovea-app-icon-dark-1024.png` — dark-field icon export. The light export is `../AppIcon.png`,
  which the app uses for the Dock at runtime and `scripts/bundle-app.sh` turns into the `.icns`.
- `fovea-menubar-16.png`, `-32.png` (ink) and the `-reversed` pair (white) — template marks for the
  menu bar item, once that surface is built.

Geometry: 1024 canvas, corner radius 216, mark height 768 at origin (286, 128).
Field `#F8F6EF`, ink `#0C0C0C` — the same two values `Tokens.Colors` builds the window from.
