# Dynamic Island — PRD amendments (2026-09-08)

These decisions were made after using the running Island and override the corresponding
lines in `FOVEA_DYNAMIC_ISLAND_PRD.md`. The PRD's own precedence rule ("behavior,
hierarchy, copy, state logic" over mockups) still holds for everything not listed here.

## §8 Hover list — rows and count
- Each row shows, left to right: **destination icon · Chat name (primary) · one line of
  current activity (secondary) · state label (right)**, with a small accent dot on
  `Working`. The activity line is a single human summary ("Editing the folder picker",
  "Build failed · 2 errors"), never steps or logs.
- Show **up to five rows**; more scroll within the panel (was four).

## §8 Hover intent (new)
- Hovering opens the list only after a short **dwell (~150 ms)** on the notch itself.
  Brushing across, or approaching from below and stopping near the island, must not open
  it. Chin growth under a still pointer must not open it. After a collapse the pointer
  must leave the notch before another hover can open the list. (Implemented as an explicit
  pointer-zone tracker measured against the island's target geometry.)

## §10 Transcribing — the "didn't catch that" state
- When nothing was recognized, the Flowing Bar shows a single **Retry** and a two-second
  bar draining along its bottom edge. When it empties, the Island rests. Retry starts a
  **new listening session** with the same referents (it does not replay silence).
- Voice states (Listening, Transcribing, this state) are **exactly the notch's width** and
  grow only downward.

## §11 Attachments — no `+N`
- Every referent is shown; rows **wrap** when one is full (no `+N` chip). Hovering a
  referent grows a **larger preview downward beneath the stack**.

## §11 Chat selector — a browsable flow
- Opening the pill shows **Recent · Last 24 hours** (up to ten Chats across every
  destination, with relative times), plus **New Chat** and **Search Chats**.
  - New Chat → choose an AI (Claude Code recommended, Codex, Cursor) → choose a context
    folder (No Folder, then a scrollable list of `~/…` folders, five visible).
  - Search Chats → choose an AI → a search field whose results are **scoped to that one
    destination** (title, folder, "Active 9h ago").
  - Choosing anything returns to the recent panel with the pill updated, so the choice can
    be double-checked; the panel stays open until Send. Back / Esc step out one level.
- This replaces "Opening the selector shows only Recommended / Original / two recent / New
  Chat" and "Do not expose the user's full Chat history." Search is still bounded: it lists
  one destination at a time and never dumps everything.

## §11 Send — acknowledge in the Agent list
- On Send, show the **Agent list with the new task highlighted for about 3.5 seconds**
  (longer while the pointer or focus is inside), then collapse. This replaces "collapse the
  Island on send."

## §14 Motion
- The whole Island morphs on **critically damped springs (no bounce)**; content crossfades
  with opacity + a light blur + a small scale from the top, on the same path in and out.
  The expanded→resting collapse is one continuous morph (the key hand-back is deferred
  until the morph finishes, so the panel is never hidden and re-shown mid-animation). This
  follows the master build prompt §10 and the project's "no bounce, anywhere" rule; the
  animations.dev course notes (`docs/motion/NOTES.md`) agree that a daily-driver surface
  should not overshoot.

## Input — the fn shortcut and the emoji picker
- VoiceFlow is `fn`, Quick Answer is `fn ⌃`, press-to-toggle. While Fovea runs, a bare fn
  tap is swallowed by an event tap so macOS does not open the emoji picker; fn used as a
  modifier for another key (fn+←, fn+F5) is unaffected. If the tap cannot be installed, the
  Shortcuts page offers to set "Press 🌐 key to → Do Nothing" instead.
