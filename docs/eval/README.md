# Island eval loop

Every reported problem has an automated check: a unit test where the logic is pure, a
snapshot where the layout is visual, and a live-panel eval where only real input or real
window behavior can prove it. The loop is: implement → `swift test` → bundle → run the
live suite → fix the root cause on any FAIL (never widen a threshold) → rerun.

## Run

```bash
swift test                                   # 110 pure tests (geometry, reducer, layout, catalog, RelativeTime)
swift run Fovea --snapshot screenshots       # every Island state to PNG (island-<scenario>.png)
CODESIGN_IDENTITY="Apple Development: <you>" scripts/bundle-app.sh debug
FOVEA_NO_ACTIVATE=1 build/Fovea.app/Contents/MacOS/Fovea --demo island-eval:all,island-simulated,ephemeral
```

Grant `build/Fovea.app` Accessibility once (System Settings › Privacy & Security ›
Accessibility). Run the live suite from a terminal with Finder frontmost, and keep hands
off the trackpad while it runs — it warps the real cursor and posts synthetic clicks and
fn taps. Suites: `preflight | p1 | retry | hover | collapse | emoji | dock | all`.

## What each check proves

| Problem | Check | Type | Passes because |
|---|---|---|---|
| P1 voice width | `p1.voiceWidth`, `p1.growsDown` | live | listening width == resting width (191 == 191 on this Mac); height grows, top pinned at row 0 |
| P1 geometry | `NotchGeometryTests` | unit | `.voice` density == resting width, 44 pt below, on notched + flat + forced-software |
| P1b emoji | `emoji.noPicker`, `emoji.startsListening` | live | a synthetic fn tap opens no CharacterPalette window yet still starts a listening session |
| P2 failure | `testEmptyTranscriptFailsWithCountdown`, `testFailureCountdownCollapsesOrHolds` | unit | Retry state schedules a 2 s countdown; elapsing rests (or holds while hovered, then rests on exit) |
| P3 retry | `retry.clickLands`, `retry.panelNotKey` | live | a click on Retry in the non-key panel lands (→ listening) via `acceptsFirstMouse` |
| P3 retry | `testRetryListensAgainKeepingSessionAndReferents` | unit | Retry begins a new session with the same referents (no silent replay) |
| P4 stack | `ReferentStackLayoutTests` (`testWrapped*`, `testPreviewLeadingClamped`) | unit | every referent placed once, wraps onto rows, no `+N`; preview clamps inside the content width |
| P4 preview | `island-reviewStackHover.png` | snapshot | the hovered thumbnail grows a preview beneath the stack |
| P5 selector | `testSelectorNewChatFlow`, `testSelectorSearchFlow`, `testEscapePriorityInReview` | unit | recent → New Chat → AI → folder and Search → AI → results, back-steps, panel stays open |
| P5 selector | `island-selector*.png` | snapshot | S0–S4 match the mockups |
| P5 list | `island-listAfterSend.png`, `testVoiceFlowHappyPath` | snapshot + unit | Send → Agent list with the new task highlighted; two-line rows with activity |
| P5 hover | `hover.dwellOpens/leaveCollapses/brushThrough/approach12/approach40/noReopenUnderPointer` | live | opens only on a deliberate dwell; brushing and approaching-from-below never open; no reopen under a parked pointer |
| P6 collapse | `collapse.noOrderOutMidMorph/monotonic/noVanish` | live | width shrinks with 0 pt uptick, area never drops out, the panel never leaves the screen during the morph |
| Dock | `dock.tearOffUnderNotch/follows1to1/farStaysResting/nearOpensReceiver/readyArms/magnetism/releaseDocks/cardGone/releaseFarStays` | live | a torn-off Quick Answer starts exactly where the slab was and tracks the pointer to 0 pt; the notch opens its receiver at 200 pt and arms at 90 pt with the card leaning toward it; release docks and the card is hidden after its flight; a far release leaves it where it was let go |

## Last full run (2026-09-08)

`17/17` live checks passed (`preflight` 2, `p1` 2, `retry` 2, `hover` 6, `collapse` 3,
`emoji` 2) plus `110/110` unit tests. Report saved to `build/eval/last-run.txt`.

## Rules

- A FAIL is fixed at its root cause. Thresholds are never widened to make a check pass; if
  a check measures the wrong thing, change the check in its own step and note it here.
- `island-simulated` forces the fixtures even in the signed bundle, so the mic/speech are
  never touched during an eval.

## Still owed to the picky bar

- **P6 taste gate**: the numbers prove continuity and no-bounce, but the felt quality of
  the morph is a human call. Watch the live island and, if anything reads cheap, tune only
  the tokens in `Tokens.Motion` (the single knob) — `docs/motion/NOTES.md` has the course's
  recommended values and the CSS→SwiftUI translation table.
- A frame-sampling contact-sheet harness and a two-reviewer taste gate are specced in the
  plan but not built; the current live `collapse` suite covers the objective half.
