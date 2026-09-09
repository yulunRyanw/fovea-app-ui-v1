#!/bin/zsh
# Fetches provider marks for destination icons and rasterizes them to PNG.
# Sources: lobe-icons (MIT) for Claude, Claude Code, OpenAI/ChatGPT, Codex and Cursor;
# Raycast's press kit for Raycast. Marks are used nominatively to identify the
# destination; replace with the official icon package when it arrives.
# Re-run to refresh. Needs network; rasterizes with AppKit (no extra tools).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/Sources/FoveaCore/Resources/Destinations"
TMP="$(mktemp -d)"
mkdir -p "$DIR"
LOBE="https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-svg/icons"
# id  url  fill(white|keep)
ICONS=(
  "claude-code $LOBE/claude-color.svg keep"
  "claude $LOBE/claude-color.svg keep"
  "chatgpt $LOBE/openai.svg white"
  "codex $LOBE/codex.svg white"
  "cursor $LOBE/cursor.svg white"
  "raycast https://fz1sd71lwhbqy6sh.public.blob.vercel-storage.com/press/images/logo/raycast-logo-light.svg white"
)
cat > "$TMP/rasterize.swift" <<'SWIFT'
import AppKit
let args = CommandLine.arguments
let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
let size = CGFloat(Int(args[3]) ?? 256)
guard let image = NSImage(contentsOf: input) else { fputs("cannot read \(input.path)\n", stderr); exit(1) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
// Fit the mark in the square with a small safe area.
let inset = size * 0.04
let box = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let aspect = image.size.width / max(1, image.size.height)
var target = box
if aspect > 1 { target.size.height = box.width / aspect; target.origin.y = box.midY - target.height / 2 }
else { target.size.width = box.height * aspect; target.origin.x = box.midX - target.width / 2 }
image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: output)
SWIFT
swiftc -O -o "$TMP/rasterize" "$TMP/rasterize.swift" 2>/dev/null
: > "$DIR/SOURCES.md"
{
  echo "# Destination icon sources"
  echo
  echo "Fetched by scripts/fetch-destination-icons.sh and rasterized to 256×256 PNG."
  echo "Marks identify the destination (nominative use). lobe-icons is MIT; Raycast's press"
  echo "kit governs raycast.png. Swap in the official icon package from the PRD checklist"
  echo "when it is delivered; file names are the destination ids."
  echo
} >> "$DIR/SOURCES.md"
for entry in "${ICONS[@]}"; do
  set -- ${=entry}
  id=$1; url=$2; fill=$3
  echo "fetching $id <- $url"
  curl -fsSL "$url" -o "$TMP/$id.svg"
  # lobe-icons use currentColor at 1em; give them a real size and a color.
  if [[ "$fill" == "white" ]]; then
    sed -i '' -e 's/currentColor/#FFFFFF/g' "$TMP/$id.svg"
  fi
  sed -i '' -e 's/width="1em"/width="256"/; s/height="1em"/height="256"/' "$TMP/$id.svg"
  "$TMP/rasterize" "$TMP/$id.svg" "$DIR/$id.png" 256
  echo "- $id.png: $url" >> "$DIR/SOURCES.md"
done
rm -rf "$TMP"
echo done
