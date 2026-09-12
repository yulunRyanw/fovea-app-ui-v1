# Destination icon sources

Fetched by scripts/fetch-destination-icons.sh and rasterized to 256×256 PNG.
Marks identify the destination (nominative use). lobe-icons is MIT; Raycast's press
kit governs raycast.png. Swap in the official icon package from the PRD checklist
when it is delivered; file names are the destination ids.

- claude-code.png: https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-svg/icons/claude-color.svg
- claude.png: https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-svg/icons/claude-color.svg
- chatgpt.png: https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-svg/icons/openai.svg
- codex.png: https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-svg/icons/codex.svg
- cursor.png: https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-svg/icons/cursor.svg
- raycast.png: https://fz1sd71lwhbqy6sh.public.blob.vercel-storage.com/press/images/logo/raycast-logo-light.svg

- `codex-color.png`: the official Codex product icon (full colour, dark appearance), copied verbatim from fovea-mac `Assets.xcassets/CodexMark.imageset/icon-codex-dark-color.png`, itself taken from the signed ChatGPT app. Rendered as-is, never tinted.

- `../AnswerContent/`: the production answer renderer (`fovea-mac/FoveaMac/Resources/AnswerContent`, built from `tools/answer-content` on 2026-09-11): `index.html`, `answer.js`, `style.css`, KaTeX. Copied verbatim so the rehearsal body renders exactly like the product (tables, code, math, dark palette). Licences in `THIRD-PARTY-LICENSES.txt`.
