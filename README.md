# Fovea — window UI + Island prototype

Native macOS prototype (SwiftUI + AppKit, Swift Package, macOS 14+). Two surfaces in one app:

- The **window**: **Home** (capture history as a ledger, search, capture detail) and **Settings** (flat sidebar + detail pane). The window is ink on paper (`#0C0C0C` on `#FBFAF7`, every gray the ink at an opacity), the Island is the same system inverted; the two share one row anatomy and one thumbnail geometry.
- The **Island**: a black surface around the MacBook notch (top-center on other displays). Hover it for the Agent task list; press `fn` to start speaking, press it again to transcribe, review the transcript, pick the Chat, send; press `fn ⌃` (and again to stop) for a Quick Answer that streams under the notch, tears off into a floating panel from its grabber, and docks back when dragged up to the notch, which opens to receive it.

## Run

```bash
swift run Fovea
```

Or build a double-clickable app:

```bash
scripts/bundle-app.sh          # → build/Fovea.app
open build/Fovea.app
```

## Try the Island

- Hover the notch: the Agent task list (Needs you → Complete → Working → Failed). Click a row for *Take me there*.
- Press `fn`, speak, press `fn` again. From `build/Fovea.app` the waveform follows the real microphone and the transcript comes from on-device speech recognition (macOS asks for Microphone and Speech Recognition once). The `fn` shortcut is watched through an event monitor, so macOS also asks for Accessibility; until it is granted the Island shows a notice and only chords on a regular key work. If a tap of `fn` opens the emoji picker, set *Press 🌐 key to* → *Do Nothing* in System Settings › Keyboard. If Fovea is listed as allowed but `fn` still does nothing, the grant belongs to an older build: run `tccutil reset Accessibility app.fovea.prototype`, relaunch, and allow it again (`open --env FOVEA_ISLAND_LOG=1 --stderr /tmp/fovea.log build/Fovea.app` prints what the app sees). From `swift run` the microphone and transcript are simulated; add `--demo island-real` to opt in. If nothing is recognized, the bar shows one Retry and a two-second countdown, then rests.
- Review: edit the words; hover the referent stack to fan every referent out (rows wrap, and the one under the pointer grows a preview below it), click to inspect/remove. The Chat pill opens recent Chats, New Chat (AI → folder) and Search Chats. `⌘↩` or the arrow sends; after Send the Agent list shows the new task for a few seconds. `Esc` steps back one level at a time.
- Press `fn ⌃`, ask a question, press `fn ⌃` again: the answer streams in the slab. `↩` in the follow-up field asks again (`⇧↩` for a newline). Drag the grabber to detach; the panel follows the pointer anywhere. Drag it back toward the notch: the island opens a receiver, brightens once release will dock (a flick toward it docks too), and the panel springs home. ✕ or `Esc` ends the session; from four questions a rail on the right jumps to each one.
- The **Island** menu (`⌘⌥1`…) jumps the live island to any state for demos. Simulated Chat routing, delivery and answers are deterministic fixtures.

## Try the window

- `⌘,` opens Settings, `⌘[` or the `‹ Home` button returns to Home. The avatar opens Account, `Aa` opens Dictionary.
- The window is a fixed 980×680; the whole layout is designed at 1180 wide and scaled down. Home is a ledger grouped by day, one row per capture, with the anatomy of the Island's Agent list row: what you saw on the left (the referent stack, or the app you were speaking in), what you said as the title, where it went and when underneath, and at the right the Agent task's state in the Island's own four words (Working, Needs you, Complete, Failed; a capture that never arrived shows Retry). A capture the Island sends while Home is open lands at the top with the same acknowledgement the Island gives its list. Click a row (or press `↩` on a focused one) and a frosted detail card zooms out of it over the still-visible ledger: transcript or question/answer, tags, destination Chat and time, with the referents stacked in the bar (hover or Tab to fan every one out; hover a thumbnail to see it large). Click anywhere outside or press `Esc` to zoom back. Hover or Tab-focus a row for the small Copy glyph, or press `C`.
- Search filters live; a query with no matches shows a clear action.
- Automatic Updates (Account → App) fails its first save on purpose so the row-level Retry state is visible.
- Shortcuts: click a binding to record, then tap `fn` (with any modifiers held) or press a chord; `Esc` cancels, `⌫` clears; a colliding chord is flagged inline. Every shortcut is press-to-toggle: once to start, again to stop.

## Demo states

```bash
swift run Fovea --demo loading
swift run Fovea --demo empty
swift run Fovea --demo usage-unavailable
swift run Fovea --demo no-flaky                # settings always save
swift run Fovea --demo ephemeral               # don't touch UserDefaults
swift run Fovea --route settings/connectors/cursor
```

Flags combine: `--demo empty,usage-unavailable`.

Island flags: `island:<scenario>` (`resting`, `hover`, `hoverScroll`, `listAfterSend`, `listening`, `transcribing`, `failureRetry`, `microphoneDenied`, `reviewCollapsed`, `reviewExpandedStack`, `reviewStackHover`, `selectorRecent`, `selectorNewChatAI`, `selectorNewChatContext`, `selectorSearchAI`, `selectorSearchQuery`, `reviewResolving`, `sendFailed`, `qaStreaming`, `qaLong`, `qaFollowUp`, `qaError`, `qaDetached`, `qaManyTurns`, `qaDockReady`), `island-flat`, `island-off`, `island-no-tasks`, `island-real`, `island-simulated` (fixtures even in the bundle), `island-smoke`, `island-eval:<suite>` (live checks, see `docs/eval/README.md`).

## Verify

```bash
swift test                                     # FoveaCore: layout, fingerprint, search, stores, routes
swift run Fovea --snapshot screenshots         # every window route, plus island-<scenario>.png for every Island state
swift run Fovea --demo island-smoke,ephemeral  # live panel regression run
swift run Fovea --demo island-eval:all,island-simulated,ephemeral  # live evals (needs the signed bundle + Accessibility)
```

Keyboard focus traversal of buttons follows the macOS "Keyboard navigation" setting
(System Settings → Keyboard), as in every Mac app.

## Layout

- `Sources/FoveaCore` — models, fixtures, pure logic (justified rows, semantic fingerprint, search, date grouping, shortcut conflicts), `PersistentStore` + UserDefaults implementation. No SwiftUI.
- `Sources/FoveaCore/Island` — Island state machine (`IslandReducer`), notch geometry, referent stack layout, service protocols and simulated services. Tested in `IslandTests.swift`.
- `Sources/Fovea/Platform` — `NotchPanel` (non-activating panel above the menu bar), press-to-toggle hotkeys (Carbon chords plus an fn-key event monitor), AVAudioEngine level meter + on-device `SFSpeechRecognizer`, screen observer.
- `Sources/Fovea/Island` — the Island UI: model, controller, shape, per-state views, detached Quick Answer panel.
- `Sources/Fovea` — the window UI. `Tokens.swift` holds every color, type size, spacing and motion constant (`Tokens.Ledger` for the Home rows, `Tokens.Island` for the black surface). `Home/CaptureRow.swift` is one ledger row.
- `Sources/FoveaCore/Resources/Brand` — the logo masters (mark, reversed mark, app icon, dark app icon)
  and the menu bar marks at 16 and 32 px; `Resources/AppIcon.png` is the 1024 px app icon export, which
  `scripts/bundle-app.sh` turns into the `.icns`.
- `Sources/FoveaCore/Resources/Destinations` — provider marks (Claude, Codex, ChatGPT, Cursor, Raycast) fetched by `scripts/fetch-destination-icons.sh` from lobe-icons (MIT) and Raycast's press kit; nominative use only, to be replaced by the official icon package from the PRD checklist.
- `Tests/FoveaCoreTests` — XCTest against FoveaCore.
- `scripts/fetch-photos.sh` — re-downloads the demo photos (Lorem Picsum, Unsplash license).

## What is simulated

Usage, plan, billing, connectors, permissions and delivery are typed fixtures behind the store protocol. In the Island, Chat routing, delivery, Agent task progress and Quick Answer text are simulated (`SimulatedServices.swift`); the hotkeys are real, and the microphone and transcription are real when running from the bundle.
"Open System Settings" opens the real Privacy pane, but permission states are fixed. The equation preview is styled text, not rendered LaTeX.
