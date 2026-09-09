#!/bin/zsh
# One-time fetch of free stock photos (Lorem Picsum, Unsplash-licensed) for the demo feed.
# Downscales to <=1200px on the long edge. Re-run to refresh.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)/Sources/FoveaCore/Resources/Photos"
mkdir -p "$DIR"
# name  picsum-id  width  height
PHOTOS=(
  "mountain 1036 1200 800"
  "building 1040 900 1200"
  "coast 1015 1200 800"
  "forest 1018 1200 800"
  "desk 1060 1200 800"
  "street 1074 1200 900"
)
: > "$DIR/SOURCES.md"
echo "# Photo sources" >> "$DIR/SOURCES.md"
echo "All photos from https://picsum.photos (Unsplash license), fetched by scripts/fetch-photos.sh." >> "$DIR/SOURCES.md"
for entry in "${PHOTOS[@]}"; do
  set -- ${=entry}
  name=$1; id=$2; w=$3; h=$4
  url="https://picsum.photos/id/$id/$w/$h"
  echo "fetching $name <- $url"
  curl -fsSL "$url" -o "$DIR/$name.jpg"
  sips -Z 1200 "$DIR/$name.jpg" >/dev/null
  echo "- $name.jpg: $url" >> "$DIR/SOURCES.md"
done
echo done
