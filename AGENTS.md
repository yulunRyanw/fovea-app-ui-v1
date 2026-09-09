# Fovea — AGENTS.md

macOS app. Read this before writing code.

---

## Current task

Two surfaces, one app, both runnable prototypes:

- The **window UI** (Home + Settings), driven by `AppModel` (`Sources/Fovea/App/AppModel.swift`). Spec: `FABLE_5_1_MASTER_BUILD_PROMPT.md` in the agent handoff folder.
- The **Island** around the notch (hover task list, Listening → Transcribing → Transcript review → Send, Quick Answer attached/detached), driven by `IslandModel` (`Sources/Fovea/Island/IslandModel.swift`) over the pure reducer in `FoveaCore/Island/`. Spec: `docs/island/FOVEA_DYNAMIC_ISLAND_PRD.md` plus `docs/island/AMENDMENTS.md` (the amendments win). Motion guidance: `docs/motion/NOTES.md`. Eval loop: `docs/eval/README.md`.
- Typed fixtures in `FoveaCore/Fixtures.swift`; settings, dictionary, shortcuts, connectors and island prefs persist to UserDefaults through `PersistentStore`. Capture history and Agent tasks live in `CaptureLog` / `TaskLedger` (in-memory stores shared by both surfaces).
- What is real: the press-to-toggle hotkeys (`fn` for VoiceFlow, `fn ⌃` for Quick Answer: one press starts, the next stops; Carbon for regular chords, an NSEvent monitor needing Accessibility for the fn key), the microphone level and on-device transcription (only when running as `build/Fovea.app`, or with `--demo island-real`). What is simulated: Chat routing, delivery, Agent answers and task progress (`FoveaCore/Island/SimulatedServices.swift`).
- Where the specs conflict with the older rules below, the specs win.

---

## What this is

Fovea lets you point at anything on your screen and send it to an AI coding agent without switching windows.

Press the hotkey, circle regions of the screen with the mouse while speaking, say where it goes, press it again. Fovea compiles the circled objects plus the speech into an anchored payload and delivers it to Codex / Claude Code / Cursor.

The hard problem is **reference resolution**: connecting the words "this one" / "the second one" / "that part" in the speech to the specific regions the user circled.

---

## Vocabulary — use these exact nouns in code and in UI copy

| Term | Meaning |
|---|---|
| **Capture** | One session, hotkey-down to hotkey-up. The atomic unit. |
| **Referent** | One circled or selected screen region. Has: index (1-based, by draw order), bounds, thumbnail, extracted text, source app, source window title. |
| **Intent** | The speech transcript for this capture. |
| **Destination** | A configured target agent or app. |
| **Payload** | The compiled output: intent + ordered referents + metadata. What actually gets delivered. |
| **Channel** | How a payload reaches a destination. Four tiers: official API/CLI → local process/IPC → clipboard+keyboard → UI automation. Reliability drops down the list, and delivery confidence is bound to the tier — the top two may report "Delivered", the bottom two only "Sent". |
| **Binding** | The mapping from deictic phrases in the intent to referent indices. |
| **Disambiguation** | The step where binding is ambiguous and the user confirms. |
| **Island** | Fovea's surface around the notch (top-center software island on other displays). Its states are phases of `IslandState`. |
| **Agent task** | One delivered payload an Agent is working on: Working / Needs you / Complete / Failed. Shown in the Island's hover list. |
| **Chat** | The conversation inside a destination that receives the payload. Fovea predicts it (`ChatRoute`); the user may change it, never must. |
| **Quick Answer** | A short question-and-answer session with the default Agent, shown in the Island. Past sessions are listed in Home (the PRD places them in the main app), titled by the question. |

No synonyms. Not "clip", "snippet", "item", "selection", "attachment", "context". A referent is a referent (the PRD's "attachment stack" is the referent stack in code).

---

## Surfaces

Three, with very different weight. Only the third is in scope right now.

**Menu bar (idle)** — one icon, states idle / capturing / needs attention. The only evidence the app is alive. **Closing the window does not quit**; quit is only from here.

**Overlay (session)** — full-screen overlay plus a capture bar (circling regions). Not in scope yet. The **Island** is the part of the session surface that is built: it lives at the notch, is a non-activating panel (the frontmost app keeps focus), and hosts listening, review, the Agent task list and Quick Answer.

**Window (container)** — opened maybe once a week, with a specific goal. Two modes: **Home** (a quiet, visual capture history with no sidebar — review, search, inspect) and **Settings** (flat sidebar + detail pane). Most Settings pages are reached by deep link from the overlay or menu bar. **Design it to be left quickly, not to be lived in.** No dashboard, no landing summary, no reason to linger.

---

## Architecture

Layers, top depends on bottom. Lower layers never import upper ones. Only `UI/Window` exists today; the rest are the target shape, so do not create empty scaffolding for them yet.

- **Core** — Capture, Referent, Intent, Payload, Destination, Channel types, plus binding and disambiguation logic. Pure. Imports no UI, no platform APIs.
- **Platform** — wrappers over system capabilities: global hotkey, screen capture, accessibility text extraction, microphone, permissions.
- **Delivery** — the four channel tiers. One adapter per channel behind a single interface.
- **Store** — capture persistence and the quadruple log.
- **UI/Overlay** — overlay, capture bar, circle drawing, disambiguation, toasts.
- **UI/Window** — Home (capture feed, search, capture detail) and Settings (Account, Eye Tracking, Voice & Capture, Dictionary, Shortcuts, Connectors, Usage & Plan).
- **UI/MenuBar** — icon and status.

Three rules that matter more than the folder names:

1. **Core imports nothing above it.** Binding and disambiguation must be unit testable with no screen attached. First-try rate is the metric for that logic, so it has to be testable in isolation.
2. **Each delivery channel is an adapter behind one interface.** Adding a destination must not touch any other file.
3. **UI/Overlay and UI/Window never import each other.** They communicate only through Core and Store. Their lifecycles are completely different — one lives for seconds, the other sits open.

Current layout: `Sources/FoveaCore` (Core + Store: models, fixtures, pure logic, persistence protocol — no SwiftUI/AppKit; `FoveaCore/Island/` holds the Island state machine, geometry, service protocols and simulated services), `Sources/Fovea/Platform` (notch panel, press-to-toggle hotkeys, AVAudioEngine metering, Speech transcription, screen observer), `Sources/Fovea/Island` (the Island UI), `Sources/Fovea` (UI/Window), `Sources/Fovea/App/AppServices.swift` (composition root shared by both), `Tests/FoveaCoreTests`. The Island reaches the window only through `AppCommandBus`. Propose changes to this layout before scaffolding new layers.

**All colors, type scale, spacing and motion constants live in one tokens file** (`Sources/Fovea/Tokens.swift`). Never hardcode a color or a duration in a view. The window is ink on paper: `Tokens.Colors.ink` (`#0C0C0C`) on `canvas` (`#FBFAF7`), and every window neutral is the ink at an opacity, exactly as every Island neutral is white at an opacity on black. Home rows (`Tokens.Ledger`) copy the Island's Agent list row: same anatomy, same 44×32 thumbnail, same status words. No palettes, no custom faces: SF Pro on both surfaces. The six Island *geometry* numbers are the one exception: they live in `IslandLayoutSpec` (Core) so `FoveaCoreTests` can assert the shipped values, and Tokens re-exports them.

---

## Never do these

- No dashboard, landing summary, stat cards, Insights, or monthly reports. Home is a capture ledger, not a dashboard. No decoration standing in for content: a row shows the referents, the words, the destination and the task state, in one face and one ink.
- No efficiency metrics — no time saved, words per minute, or streaks. The only usage figures are the plan quota on Usage & Plan and the usage arc on the Home avatar (an arc only, no full track circle) with its hover popover.
- No window page that renders an agent's output content. Claude Code and Cursor already have agent views; we are a remote control, not a display. (Quick Answer is the one exception the PRD defines: a short answer in the Island, and that question and answer again in the capture's detail card.)
- The Island never shows a task count, execution steps or logs (one line of current activity per task is fine); never opens an empty hover panel; never shows a provider icon or model name inside Quick Answer; never uses gradients.
- No stored "learned facts" or inferred user profiles, and no UI for curating them. Captures are logged raw.
- Do not add a Settings category beyond the seven in the spec (no General, Privacy, Memory, Security, Notifications, Access).
- Closing the window must not quit the app.

---

## Tech

- Language / framework: Swift 5 language mode, SwiftUI + AppKit, Swift Package (no Xcode project needed).
- Minimum macOS version: 14 (Sonoma).
- Local storage: UserDefaults JSON blobs behind `PersistentStore` (`FoveaCore/Stores.swift`), keys in `StoreKeys`.

Required macOS permissions, all with usage descriptions in `Info.plist` (generated by `scripts/bundle-app.sh`): Microphone, Speech Recognition, Screen Recording, Accessibility. The hotkeys need none (Carbon `RegisterEventHotKey`).

---

## Commands

```
build:   swift build
run:     swift run Fovea                       # or scripts/bundle-app.sh → build/Fovea.app
test:    swift test
shots:   swift run Fovea --snapshot <dir>      # renders every route at 1180×800 and 980×680
demo:    swift run Fovea --demo loading|empty|usage-unavailable|no-flaky|ephemeral --route settings/dictionary
island:  swift run Fovea --demo island:<scenario>          # hover, listening, reviewExpandedStack, qaLong, qaDetached… (IslandScenario)
         swift run Fovea --demo island-flat|island-off|island-no-tasks|island-real|island-smoke
         Island menu (⌘⌥1…) jumps the live island to any scenario; press fn / fn⌃ (again to stop) for the real thing
icons:   scripts/fetch-destination-icons.sh    # provider marks → Resources/Destinations
lint:    (none yet)
format:  (none yet)
```

Run the build before saying a task is done.

---

## Working agreement

- Ask before building anything outside the current task.
- When a rule here conflicts with something that looks better, follow the rule and say so. These encode decisions that have reasons behind them.
- Prototype motion and gesture in running code, not static mockups.
- Keep this file short. Detailed specs go in `docs/` and get referenced from here.
