#!/usr/bin/env bash
# Re-downloads the ten bundled feed fonts and their OFL notices from the official
# Google Fonts repository. Run from the repo root.
#
#   scripts/fetch-fonts.sh
#
# The families are declared once in Sources/FoveaCore/FeedFonts.swift; this list
# has to stay in step with it (FeedFontTests asserts every declared file exists).
set -euo pipefail

base="https://raw.githubusercontent.com/google/fonts/main"
dest="Sources/FoveaCore/Resources/Fonts"
mkdir -p "$dest"

fonts=(
  "instrumentserif|InstrumentSerif-Regular.ttf"
  "fraunces|Fraunces[SOFT,WONK,opsz,wght].ttf"
  "ebgaramond|EBGaramond[wght].ttf"
  "bricolagegrotesque|BricolageGrotesque[opsz,wdth,wght].ttf"
  "syne|Syne[wght].ttf"
  "archivo|Archivo[wdth,wght].ttf"
  "biorhyme|BioRhyme[wdth,wght].ttf"
  "specialgothiccondensedone|SpecialGothicCondensedOne-Regular.ttf"
  "dmsans|DMSans[opsz,wght].ttf"
  "karla|Karla[wght].ttf"
)

for entry in "${fonts[@]}"; do
  dir="${entry%%|*}"; file="${entry##*|}"
  enc=$(printf '%s' "$file" | sed 's/\[/%5B/g; s/\]/%5D/g; s/,/%2C/g')
  curl -sfL -o "$dest/$file"        "$base/ofl/$dir/$enc"
  curl -sfL -o "$dest/OFL-$dir.txt" "$base/ofl/$dir/OFL.txt"
  echo "  $file"
done

echo "Done. $(ls "$dest"/*.ttf | wc -l | tr -d ' ') fonts in $dest"
