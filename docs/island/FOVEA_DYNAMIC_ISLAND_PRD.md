# Fovea Dynamic Island — Product Requirements Document

**Version:** 1.0  
**Date:** September 7, 2026  
**Status:** Approved product direction; ready for engineering handoff  
**Audience:** Product, Design, macOS Engineering, Agent Integration, QA

## 1. Product intent

Fovea is a lightweight macOS intent layer. It understands what the user is looking at or saying, packages that intent with the relevant context, and hands the request to the user's chosen Agent. Fovea does not execute the requested work itself.

The Dynamic Island must feel like part of the Mac's top edge: present only when useful, visually quiet, and subordinate to the user's work. It must never become a dashboard or a full-screen takeover.

## 2. Locked product principles

1. **Text is the primary content.** Controls, routing, attachments, and status must stay visually secondary to the user's words and the Agent's answer.
2. **Automation by default, control on demand.** Fovea predicts the correct Chat and model route. The user can inspect or change the Chat before sending, but this is not a required step.
3. **Use the user's Agent.** Quick Answer and dictated requests are sent through the user's Agent/provider so conversations remain there and responses reflect the user's existing context and habits.
4. **Fovea passes intent; the Agent executes.** The interface must not imply that Fovea itself performs coding or other Agent work.
5. **Nearly invisible progress.** Running work is not continuously promoted. Hover reveals the task list; only meaningful outcomes interrupt.
6. **One surface, different densities.** Listening and transcription are compact. Review and Quick Answer expand only as much as their content requires.
7. **No gradients.** Use black, white, and neutral gray. Destination icons may retain official brand colors.
8. **SF Pro only.** Use the macOS system SF Pro family for every Fovea label, transcript, answer, input, and control.

## 3. Scope

### In scope

- Resting and hover behavior at the MacBook notch/top edge
- Active Agent status and completion notification
- Listening Flowing Bar
- Transcribing state, progress, and cancellation
- Transcript review, editing, attachments, Chat selection, and send
- Predictive Chat and model routing
- Quick Answer attached and detached states
- Follow-up questions within the current Quick Answer session
- Loading, error, permission, accessibility, and multi-display behavior

### Out of scope

- Full task history
- Full Chat browsing or Chat management
- Privacy and trust settings
- Agent configuration and account management
- Detailed step-by-step Agent execution logs
- Editing or managing old Quick Answer sessions
- Performing the downstream Agent's work inside Fovea

These functions belong in the main Fovea application or the destination Agent.

## 4. Terminology

- **Island:** Fovea's software surface drawn around and below the physical MacBook notch, or at the top center of a display without a notch.
- **Flowing Bar:** The compact Island state shown while listening or transcribing.
- **Agent:** The user's connected AI product or coding Agent, such as Claude, ChatGPT, or Codex.
- **Destination:** The Agent/provider that receives the request.
- **Chat:** The specific conversation inside a destination.
- **Quick Answer:** A short, low-thinking-effort question-and-answer session using the user's default Agent.
- **Attachment stack:** A compact preview of screenshots or files captured with the request.

## 5. Physical notch and display rules

The physical MacBook notch contains no display pixels. Fovea must never place essential content inside it. The software surface is drawn around the notch and extends below it.

On a notched display:

- Compact states may visually connect the left and right areas around the physical notch.
- Expanded Quick Answer begins at pixel row 0, visually absorbs the physical notch, uses straight vertical sides, and has rounded bottom corners only.
- The expanded surface must not appear as a floating card attached by a narrow neck.

On a display without a notch:

- Use a top-center software Island with the same widths, hierarchy, and behavior.
- Keep a small top-edge connection so the surface still feels anchored, not like a generic floating popover.

Fovea appears on the active display: the display containing the pointer when the interaction begins. Moving a detached Quick Answer across displays is allowed.

## 6. Global visual requirements

- Typeface: SF Pro Display for large answer headings only when needed; otherwise SF Pro Text.
- Default text size: 13–14 pt for transcript, question, answer, and follow-up input.
- Secondary labels: 11–12 pt.
- Primary text: white.
- Secondary text: neutral gray with sufficient contrast.
- Surface: near-black or black.
- No gradients, decorative glow fields, glassmorphism, or colored surface fills.
- Destination icons: official provider artwork only; never approximate a provider mark.
- Controls: compact, linear, and low emphasis until hover or keyboard focus.
- Avoid excessive shadows. Separation should come primarily from the black surface against the desktop.
- All layouts must preserve the visible foreground application's usable context; no full-screen takeover.

## 7. Information architecture and state model

```text
Resting
├── Pointer hover → Agent status list
├── Voice hotkey down → Listening
│   └── Hotkey release → Transcribing
│       ├── Cancel → Resting
│       ├── Failure → Transcription error
│       └── Complete → Transcript review
│           ├── Edit transcript
│           ├── Inspect attachments
│           ├── Change Chat
│           └── Send → Agent working → Resting
└── Quick Answer invocation → Quick Answer attached
    ├── Stream answer
    ├── Ask follow-up
    ├── Drag away → Quick Answer detached
    ├── Drag to top edge → Quick Answer attached
    └── Close / Escape / new Quick Answer → End session
```

## 8. Resting and Agent status

### Resting

- Do not show a numeric task count.
- Do not continuously show task details.
- If an active-state affordance is necessary, use one subtle breathing point whose color follows the user's selected accent palette.
- The point's dynamic range applies only to the point, never to the entire Island.
- Respect Reduce Motion by replacing breathing with a static low-contrast point.

### Hover list

Hovering the top-center Island/notch target expands a compact list of currently relevant Agent tasks.

Each row contains:

1. Task or Agent name
2. Short current state, such as `Working`, `Needs you`, `Complete`, or `Failed`
3. Destination icon aligned at the far right

Rules:

- Do not show a separate “Agent accepted” event.
- Do not show detailed execution steps or logs.
- Sort `Needs you` first, then `Complete`, then `Working`, then `Failed`, with recency as the secondary order.
- Show up to four rows; additional tasks scroll within the panel.
- When there are no relevant tasks, hovering must not open an empty panel.
- The panel collapses when the pointer leaves after a short grace period, unless focus is inside it.

### Meaningful notifications

Fovea may interrupt only for:

- `Needs you`
- `Complete`
- `Failed`

For completion, show a brief, quiet notification. Include **Take me there** when Fovea can open the exact destination Chat or result. Selecting it must activate the correct application, Chat, and relevant result location when supported.

## 9. Listening Flowing Bar

Listening begins while the user holds the configured voice hotkey.

- The surface remains compact.
- Show no microphone icon, `Listening` label, close button, or cancel button.
- Show no more than 8–10 short white waveform bars.
- The waveform must be narrow and centered, with restrained amplitude.
- The waveform responds to input volume without causing the Island's outer bounds to pulse.
- Releasing the hotkey immediately transitions to Transcribing.

If microphone access is unavailable, replace the waveform with one concise permission message and a single action that opens the relevant system setting.

## 10. Transcribing

- Keep exactly the same outer dimensions as Listening.
- Show the current transcription in white SF Pro text.
- Show a subtle linear progress indicator.
- Keep one compact `Cancel` action.
- Do not enlarge the Island to fit a long partial transcript; truncate visually while retaining the complete text internally.
- On completion, expand directly into Transcript review without a detached intermediate card.
- On cancellation, discard the draft request and return to Resting.
- On failure, preserve captured audio long enough for an immediate retry, when technically possible.

## 11. Transcript review

The review state lets the user verify exactly what will be sent.

### Content hierarchy

1. Editable transcript text occupying the majority of the surface
2. Collapsed attachment stack
3. Compact Chat selector
4. Small circular Send control

The transcript uses white SF Pro text at approximately the same size as, or slightly smaller than, the foreground application's body text. It must not look like a title.

### Attachments

- At rest, show the first attachment in front with subsequent attachments visibly stacked behind it.
- Hovering or keyboard-focusing the stack expands all attachments horizontally.
- If more attachments exist than fit, show the visible set followed by a `+N` chip.
- Selecting an attachment opens a larger inspection view without losing the draft.
- Removing an attachment is available from the expanded inspection state, not the collapsed stack.
- The stack collapses after pointer exit while preserving all selections.
- The attachment reference images define stacking behavior only; their white background, typography, and card styling are not Fovea visual requirements.

### Chat selector

Place the Chat selector between the attachment stack and Send.

- Default state: compact pill containing destination icon, selected Chat name, and chevron.
- Show the predicted choice immediately when confidence is sufficient.
- If routing is still resolving, reserve the same width and use a subtle breathing/loading state so the layout does not jump.
- Opening the selector shows only:
  - Recommended Chat
  - Original Chat, when invoked from a Fovea result or completion
  - Up to two recent relevant Chats
  - New Chat
- Do not expose the user's full Chat history in the Island.
- Changing the Chat is optional and never blocks sending.

### Send

- Use a small circular linear arrow control.
- Keep it adjacent to the Chat selector.
- Do not show a separate Cancel button in the review state.
- Disable Send only when there is no valid transcript or no authenticated destination.
- On send, provide immediate local acknowledgement and collapse the Island; do not wait for the destination Agent to finish accepting the request.

## 12. Predictive routing and latency

Routing includes two decisions:

1. **Chat routing:** which existing Chat, or a new Chat, should receive the request.
2. **Model routing:** which model and thinking effort the destination Agent should use.

Model routing is automatic and is not exposed as a recurring Island control.

### Required latency pipeline

Routing must not wait for the final transcript before beginning:

1. On voice hotkey down, capture the foreground application, window, project, selected task/result, and current destination context.
2. During speech, stream partial transcription to the intent model and continuously update a small candidate set.
3. Preload candidate Chat metadata and warm the destination connection during transcription and user review.
4. On hotkey release, process only the final transcript delta and rerank existing candidates.
5. Keep the predicted Chat stable unless new evidence materially changes the result.
6. At Send, the destination must already be resolved whenever technically possible.

### Chat routing priority

1. If invoked from a Fovea completion, result, or **Take me there** context, bind to that exact originating Chat.
2. If the active project has exactly one active Agent Chat, use it.
3. If one candidate is clearly relevant from app, project, and semantic context, use it.
4. Otherwise create a New Chat.

Low confidence must not force the user to choose. Prefer New Chat over silently contaminating an unrelated existing Chat.

## 13. Quick Answer

Quick Answer uses the user's configured default Agent and generally requests low thinking effort. The Agent/provider is not shown in the Quick Answer UI because the destination is persistent and not expected to change per question.

### Session behavior

- One initial question and its follow-ups form one new low-effort Agent Chat.
- Follow-ups retain the current Quick Answer context.
- Closing Quick Answer ends the visible session.
- Starting a new Quick Answer starts a new Chat.
- Do not display or browse previous Quick Answer sessions in the Island.

### Attached state

- Expand from screen row 0 into one complete rectangular black slab.
- Use straight top and side edges with rounded bottom corners only.
- Do not use a narrow neck, shoulders, or a separate floating answer card.
- Show the transcribed question at the top.
- Show the Agent answer directly below it in the same continuous surface.
- The answer is the primary visual content.
- Do not show destination, model, thinking effort, or Claude/provider branding.

### Follow-up input

- Place a compact follow-up field below the answer.
- Width: approximately 40–48% of the panel's internal width, not full width.
- Use a small SF Pro input style.
- Put the Send arrow inside the input on its right edge.
- Do not place a separate external Send button.
- Pressing Return submits; Shift–Return inserts a line break.

### Long content

- Stream the answer as it arrives.
- Once content exceeds the available height, keep the question/header and follow-up input fixed while the answer region scrolls.
- Preserve text selection, links, lists, and code formatting supplied by the Agent.
- Do not grow beyond the active display's safe height.

### Dragging and detached state

- Provide a subtle bottom-center grabber.
- Dragging the grabber detaches the entire Quick Answer into an independent rounded floating panel with identical content and session state.
- The physical notch area returns to the compact Resting state as soon as detachment is visually clear.
- Dragging the panel near the top-center target shows a magnetic docking affordance; releasing docks it back into the attached state.
- Escape closes the current Quick Answer. Pointer exit alone does not close it.
- The detached panel remains above normal windows while active but must not steal keyboard focus unless the user clicks or tabs into it.

### Quick Answer errors

- On Agent timeout or network failure, retain the question and follow-up context.
- Show one concise inline error and a compact Retry action in the answer region.
- Authentication failures must route the user to the main Fovea app; account repair does not occur inside the Island.

## 14. Motion

- Expansion and collapse should feel continuous with the top edge, not like a modal appearing.
- Use restrained spring motion for geometry and short opacity transitions for content.
- Do not animate the whole Island in response to Agent progress.
- Attachment expansion originates from the front thumbnail and reveals the stack without reordering items.
- Chat-routing resolution must crossfade in place without changing control width.
- With Reduce Motion enabled, replace spring movement, waveform exaggeration, and breathing with short crossfades or static states.

## 15. Input, keyboard, and accessibility

- Every hover interaction must have a keyboard-focus equivalent.
- Escape cancels Listening/Transcribing when cancellation is available, closes an open selector or attachment inspector first, then closes Quick Answer.
- Tab order follows visible hierarchy and reading order.
- Provide VoiceOver names for task rows, status, attachments, Chat selector, Send, Retry, Take me there, and the drag/dock control.
- Do not encode status using color alone.
- Support increased contrast, Reduce Transparency, and Reduce Motion.
- At larger text sizes, allow the Island to grow vertically within the display safe area; preserve answer-first hierarchy.

## 16. Failure and permission behavior

| Condition | Required behavior |
|---|---|
| Microphone permission missing | Concise inline explanation and Open Settings action |
| Screen capture permission missing | Continue without screenshots when possible; identify the missing attachment context before Send |
| Destination disconnected | Preserve draft; open connection repair in the main Fovea app |
| Transcription failed | Preserve recoverable audio; offer Retry or return to review with available text |
| Chat routing low confidence | Select New Chat; allow optional manual change |
| Send failed | Preserve transcript and attachments; show compact Retry |
| Agent needs user input | Brief notification; hover list promotes `Needs you`; Take me there when possible |
| Agent failed | Brief notification with destination and a path to the original Chat |
| No active tasks | No empty hover panel |
| No physical notch | Use top-center software Island on active display |

## 17. Acceptance criteria

The feature is ready when all of the following are true:

- Listening uses 10 or fewer short white bars and contains no mic, label, close, or cancel control.
- Transcribing has the same outer dimensions as Listening, uses white text, shows progress, and allows cancellation.
- Transcript review makes editable text dominant and orders controls as attachment stack, Chat selector, then small circular Send.
- Attachment hover expands every visible attachment and supports `+N` overflow.
- Chat routing begins during streaming transcription and does not require a mandatory user choice.
- Sending collapses immediately after local handoff and adds the task to the Agent status system without showing an “accepted” message or count.
- Hovering the Island reveals current Agent tasks and destination icons; no empty list appears.
- Meaningful completion can show **Take me there** and opens the exact originating Chat.
- Quick Answer uses the configured default Agent without displaying its icon or model.
- Attached Quick Answer begins at the top edge as one complete slab, not as a panel suspended below the notch.
- The question and answer share one surface; the answer remains primary.
- The follow-up field is compact, does not span the panel, and contains its Send control.
- Quick Answer can detach, move, redock, stream long answers, retain follow-up context, and close with Escape.
- All Fovea text uses SF Pro and no Fovea surface uses gradients.
- Keyboard, VoiceOver, Reduce Motion, permission, offline, retry, notched, non-notched, and multi-display cases pass QA.

## 18. Reference precedence

If references conflict, use this order:

1. This PRD for behavior, hierarchy, copy, and state logic
2. The latest state-specific Fovea mockup for composition and relative scale
3. Attachment reference images for collapsed/expanded stacking behavior only
4. Earlier exploratory mockups for intent only

See `ATTACHMENT_CHECKLIST.md` for the exact submission package and remaining visual coverage.
