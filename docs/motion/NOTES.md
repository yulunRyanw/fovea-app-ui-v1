# Motion notes for Fovea

Paraphrased notes from Emil Kowalski's paid course "Animations on the Web" (animations.dev), collected 2026-09-08 for the Fovea notch surface. This file carries the rules and the numbers, not the course prose. The private page captures live in `docs/motion/course/` (text + MHTML per lesson, screenshots for demo-heavy lessons). Tags in brackets name the lesson a rule comes from.

## Sources read

| Source | Status |
|---|---|
| animations.dev paid course, all 49 lessons (`https://animations.dev/learn/...`) | Read in full. Logged-in session imported from Chrome (Supabase cookie on `animations.dev`). Every lesson captured as `course/<chapter>--<slug>.txt` and `.mhtml`; 25 screenshots of demo-heavy pages. Videos (Mux-hosted) were listed only, never downloaded. Hidden "View Solution" sandpack code is not in the captures; numbers below come from the visible lesson text and code blocks. |
| `https://animations.dev/learn/easing-curves` (the course's custom curve sheet) | Read; captured as `course/easing-curves.txt`. |
| `https://animations.dev/learn/skills` (official course agent skills page) | Read; captured as `course/skills.txt`. Skills themselves are installed via a personal token (`npx @animationsdev/install --token=...`); not installed. |
| `https://animations.dev/vault`, `/learn/vocabulary`, `/learn/interviews` | Read (vocabulary is a glossary with definitions; interviews are videos, not transcribed). |
| Public fallbacks (emilkowal.ski posts, easings.co, WWDC23 "Animate with springs", Apple HIG Motion, Josh Comeau, Rauno Freiberg) | NOT read. The paid course was accessible so the fallback was not needed. Course lessons link to WWDC23 "Animate with springs" and "The physics behind spring animations" as resources. |

Where a line states a SwiftUI or Motion-library fact rather than course content it is tagged `[SwiftUI API]` / `[Motion docs]`.

## Lesson list

Module 01 Animation Theory: Intro; What makes an animation feel right; The Easing Blueprint; Spring animations; Timing and purpose; Taste; Animations and AI; Prototyping interfaces; Practical Animation Tips; Train your judgement.
Module 02 CSS animations: The beauty of CSS animations; Transforms; Transitions; Keyframe Animations; The Magic of Clip Path.
Module 03 Framer Motion: Why Framer Motion; The Basics; How do I code animations; Feedback popover; Multi-step component; Trash interaction; Hooks and animations; Interactive graph; Animating in public.
Module 04 Good vs Great: The big little details; Performance; Accessibility; Animations of the future.
Walkthroughs: Family Drawer (The analysis, First animations, Crossfade, The finishing touch); Dynamic Island (The Design, Ring view, Timer view, Morph effect); Navigation menu (Know your tools, Animating the menu, Closing thoughts); Hero illustration (SVG introduction, Lines and dashes, Rotation, Click animation, Clock animation, Polish).
Bonuses: Vocabulary; Interviews; Vault; Animations as Proof of Care (guest lesson, Josh Puckett).

## Principles

### Easing
- ease-out for anything that enters or exits, and for anything the user just triggered (dropdown, modal, toast, popover): the fast start reads as responsiveness. [Easing Blueprint]
- ease-in-out for things already on screen that move or change shape: a timeline scrubber, a page morphing into a smaller container, a Dynamic Island resizing. Emil says the Island, converted to a curve, would be ease-in-out; Apple uses springs instead. [Easing Blueprint]
- Never ease-in for UI. Same 300 ms dropdown with ease-in feels much slower than with ease-out; it accelerates at the end, opposite of how things settle. [Easing Blueprint, Practical Tips, Train your judgement]
- linear only for constant motion (marquee, spinner), passage-of-time fills (hold-to-delete), and the 3D coin. [Easing Blueprint]
- CSS `ease` (the default `transition` timing function) for hover color / background / opacity changes and for gentle success states; Sonner uses `ease` instead of ease-out on purpose because it feels more elegant. [Easing Blueprint, Transitions]
- Built-in curves are almost always too weak. Use the custom set; asymmetric curves feel more alive than symmetric ones; if an animation feels flat the curve is probably too weak. [Easing Blueprint, Train your judgement]
- Pure rotation looks best with ease-in-out. [Transforms]
- Emil picks the easing first, then the duration, because the duration depends on the curve. [Family Drawer: The finishing touch]

Custom curves from the course sheet (Benjamin De Cock's set, also used at Linear) [easing-curves]:

```
ease-in-quad      .55,.085,.68,.53     ease-out-quad     .25,.46,.45,.94     ease-in-out-quad   .455,.03,.515,.955
ease-in-cubic     .550,.055,.675,.19   ease-out-cubic    .215,.61,.355,1     ease-in-out-cubic  .645,.045,.355,1
ease-in-quart     .895,.03,.685,.22    ease-out-quart    .165,.84,.44,1      ease-in-out-quart  .77,0,.175,1
ease-in-quint     .755,.05,.855,.06    ease-out-quint    .23,1,.32,1         ease-in-out-quint  .86,0,.07,1
ease-in-expo      .95,.05,.795,.035    ease-out-expo     .19,1,.22,1         ease-in-out-expo   1,0,0,1
ease-in-circ      .6,.04,.98,.335      ease-out-circ     .075,.82,.165,1     ease-in-out-circ   .785,.135,.15,.86
```

Curves the course actually reaches for: ease-out-quart `(0.165, 0.84, 0.44, 1)` is the most used in the demos and is Vaul's open/close curve; ease-out-expo `(0.19, 1, 0.22, 1)`; ease-in-out-cubic `(0.645, 0.045, 0.355, 1)` for on-screen movement; ease-in-out-quart `(0.77, 0, 0.175, 1)` for a 1 s clip-path image reveal; Vaul's iOS-sheet mimic `(0.32, 0.72, 0, 1)` (very steep start, long gentle tail, made by Ionic); Family drawer height `(0.26, 1, 0.5, 1)` with body `(0.26, 0.08, 0.25, 1)`. [Easing Blueprint, Timing and purpose, Clip Path, Keyframes, Family Drawer]

### Duration
- Product UI animations stay under 300 ms as the rule of thumb. 180 ms dropdown feels more responsive than 400 ms. [Timing and purpose, Practical Tips]
- Hovers: 100 to 150 ms; 300 ms is too slow for a hover. [Train your judgement]
- Press feedback: scale 0.97 on press (not 0.9), transition about 150 ms (`transition: transform 150ms ease`). Fovea-relevant: buttons benefit most from having both hover and press feedback. [Easing Blueprint, Transforms, Train your judgement]
- Too fast is as bad as too slow; there is a trackability threshold. [Train your judgement]
- Exits are shorter and simpler than entries. Radix-style example: enter 200 ms ease-out, exit 150 ms ease-out. [Train your judgement, Framer Motion Basics]
- Duration scales with element size and distance travelled. Big elements are "heavier": the Vercel time-machine page morph runs 1 s ease-in-out because the element is huge. [Timing and purpose, Train your judgement]
- A steep curve tolerates a longer duration: Vaul's sheet is 500 ms because `(0.32,0.72,0,1)` front-loads the motion; the same 500 ms with a weak curve would feel slow. [Timing and purpose]
- Family drawer numbers: height animation 0.27 s (not the usual 0.25 or 0.3, chosen by feel); content crossfade opacity duration dynamic from 0.15 s (small height change) to 0.27 s (large change); drawer open/close cut from Vaul's 500 ms default to 200 ms ease-out-quart so the whole thing reads as one entity. [Family Drawer: The finishing touch]
- Icon swap (play/pause): 100 ms tween, scale 0.5 to 1, blur 4 px to 0; wait mode (old out, then new in). [Dynamic Island: Timer view]
- Tooltips: a small delay before the first one appears (prevents accidental activation); once one is open, siblings open with no delay and no animation (Radix / Base UI behaviour; tooltip itself 125 ms ease-out, scale 0.97 to 1). [Practical Tips]
- Frequency drives duration: something used 50 times a day needs speed, not delight; hovers on daily lists often deserve no animation at all. [Timing and purpose, Train your judgement]

### Springs
- Springs have no fixed duration and mirror real physics, so they feel natural by default; they are SwiftUI's default and the reason the Dynamic Island feels like a living organism. [Spring animations]
- Prefer Apple's duration + bounce parametrisation over mass/stiffness/damping. `duration` is the perceptual duration: the time until the motion feels finished, even though a tiny tail continues. [Spring animations]
- Interruptibility is the big win: when re-targeted mid-flight a spring keeps its current velocity. CSS keyframe animations cannot be interrupted (the Sonner enter-animation jump bug); CSS transitions and springs can. Use springs for anything that can be re-targeted while moving (hover in/out, open/close, gesture-driven surfaces). [Spring animations, Transitions, Keyframe Animations]
- Bounce default is 0. Use a small bounce only where physical force is involved, e.g. the end of a drag-to-dismiss; a plain press-to-close gets no bounce. "If I do use bounce it is a very small value." [Spring animations]
- Springs beat curves for motion-heavy interactions (drawers, the trash throw, gestures); color and opacity changes do not need them. [Spring animations, The beauty of CSS animations]
- Emil's workhorse non-bouncy spring for enter/exit: `{ type: "spring", duration: 0.3, bounce: 0 }` (toolbar), `duration: 0.2, bounce: 0` (trash back plate), `duration: 0.5, bounce: 0.2` as a MotionConfig default for the shared-layout throw; a generic `{ type: "spring", duration: 0.5, bounce: 0.2 }` and `duration: 0.3, bounce: 0` for a state-swap component. [Trash interaction, Framer Motion Basics]
- Physical springs the course uses: cursor-follow `mass 0.1, stiffness 71, damping 16` (soft, overdamped follow); number ticker `stiffness 185, damping 25`; generic demo `stiffness 100, damping 10, mass 0.75` (bouncy). Use `useMotionValue` (no spring) when a value must track a gesture 1:1; a spring there feels disconnected. [Hooks and animations]
- Dynamic Island, Apple's brief: "designed to feel like a living organism, with a deliberate elasticity" (Chan Karunamuni, Apple Design). Emil's read: springs with bounce are mandatory for the Island; get the spring wrong and the organism illusion dies. [Dynamic Island: The Design]
- Dynamic Island, course build values: container `layout` spring with bounce chosen per transition, `idle: 0.5`, `ring-idle: 0.5`, `idle-ring: 0.5`, `timer-ring: 0.35`, `ring-timer: 0.35`, `timer-idle: 0.3`, `idle-timer: 0.3`. Reasoning: smaller views need more bounce for it to be noticeable; larger views need more time to settle and would look faster, so they get less bounce. No `duration` is set on these springs, so Motion's default applies (0.8 s when only `bounce` is given `[Motion docs]`). Ring-view width step 128 to 148 px uses bounce 0.5; the bell's red plate and the timer digits use bounce 0.35. [Dynamic Island: Ring view, Morph effect, Timer view]

### Choreography and stagger
- Orchestration is what makes an entrance feel like a wave (Paco's site, Apple's nav columns fading in with a slight delay). It is trial and error until the delay feels right. The course's own demo stylesheets use `animation-delay: calc(30ms * var(--index))` and `calc(50ms + 50ms * var(--index))`. [The big little details, course demo CSS]
- One entrance per container: do not animate the parent and also stagger its children. Vary timing by visual importance; not everything deserves the same animation. [Train your judgement]
- Do not stagger dropdown / menu items; users get to the items faster without it. [What makes an animation feel right]
- Layered timing example (hero illustration click): hand reaches its pose at 40% of a 530 ms ease-out, background scale delayed 200 ms so it lands with the click, motion lines offset 40 ms from each other and drawn in the last 20% of the duration, idle loop 630 ms after a 2 s initial delay. Elements starting and finishing at different moments feel organic; lockstep feels mechanical. On a click the background has no delay because the click must feel instant. [Hero illustration: Click animation]
- Multi-step flows: entering step comes from the direction of travel, exiting step leaves the opposite way; flip on Back. Animate height with a measured value (no magic numbers) so the buttons ride the height. [Multi-step component]

### Crossfade recipe (opacity + blur + scale)
- Blur bridges the gap between two states so the eye reads one object instead of two; add it when a state swap still feels off after easing and duration are right. Values used: 2 px for a small button label swap, 4 px for toolbar / icon / exiting Island content, 5 px for entering Island content. Keep blur under about 20 px for performance (Safari especially). [What makes an animation feel right, Practical Tips, Performance, Dynamic Island]
- Enter/exit template from the course: `opacity 0 to 1, filter blur(4px) to blur(0), y 20px to 0` on a `spring duration 0.3 bounce 0`; alternative `scale 1.2 to 1 + blur 4px + opacity` on `duration 0.2 bounce 0`; unselected items leave with `opacity 0 + blur 4px` in 50 ms. [Trash interaction]
- Never scale in from 0. Start from 0.9 or higher (0.85 to 0.95 is the range; a deflated balloon still has a shape). For a toast Emil pairs scale 0.5 with opacity so the scale is barely perceptible. [Practical Tips, Transforms, Train your judgement]
- Simultaneous crossfade = Motion `popLayout` (both views present); sequential = `wait` (old out, then new in). Copy-to-check uses `wait` with hidden state `{ opacity 0, scale 0.5 }` and `initial={false}` so nothing animates on first mount. [Framer Motion Basics]
- Success-state pattern: form exits downward while success content enters from the top with slight blur, both at once; exit morphs the success card back into the trigger button. [Feedback popover]
- Family drawer crossfade: enter and exit use the same duration; exiting content moves with the height change; opacity duration shrinks from 0.27 s to 0.15 s when the height delta is small so short-to-short swaps do not show too much fade. [Family Drawer: Crossfade, The finishing touch]
- Dynamic Island content: entering view `scale 0.9 to 1, opacity 0 to 1, blur 5px to 0`, delayed 50 ms after the geometry starts; exiting view `opacity 1 to 0, blur 4px`, scaled to fit the new size: `scale 0.7, y -7.5` when the Island shrinks (timer to ring, timer to idle), `scale 1.4, y 7.5` when it grows (ring to timer), `scale 0.9, scaleX 0.9` when going to idle so content is pulled inward before the pill narrows. Values were hand-tuned per transition because a real Island has a finite set of states. Apple itself uses wait-mode between two rich states and only a plain grow when coming from idle; Emil chose the crossfade because it looks better. [Dynamic Island: Morph effect]
- Text swaps inside the Island: numbers enter from `y 12px, blur 2px, opacity 0`, leave to `y -12px`, spring bounce 0.35; use tabular numerals so digits do not jitter. The "Ring" label exits toward the right, so its transform-origin is set to the right. [Dynamic Island: Timer view, Ring view]

### Shape morphs and clip-path
- During a layout (size) animation keep corner radius in absolute points so the library can un-distort it; rem/relative values distort. Scaling a container scales its radius correctly, which is a reason to prefer scale over width/height. [Dynamic Island: Ring view, Transforms]
- clip-path `inset()` animations are GPU-composited and cause no layout shift: image reveal `inset(0 0 100% 0)` to `inset(0)` over 1 s ease-in-out-quart; tab highlight by duplicating the row and clipping with `inset(0 R% 0 L% round 17px)` so text color and pill move as one; hold-to-delete fill is a linear wipe. [Clip Path]
- Percent translations (`translateY(100%)`) move an element by its own size, so enter/exit stays correct when height varies (Sonner, Vaul). [Transforms]
- Shared-element morphs (button becomes popover, thumbnails thrown into the trash) beat swapping components; think of the interface as one evolving space where any element can turn into another. [Feedback popover, Animations of the future]

### Interruptibility and retargeting
- Anything that can be re-triggered before it finishes must be interruptible: menus opened/closed rapidly, toasts added quickly, hover in/out. Springs and CSS transitions retarget smoothly; CSS keyframe animations restart or jump. [Spring animations, Transitions, Train your judgement]
- Gesture values should follow the finger directly (no spring) and only spring on release; momentum after release is what makes a flick feel physical. [Hooks and animations, How do I code animations]
- Radix suspends unmount while the exit animation plays; in SwiftUI the equivalent is letting `.transition` own the removal. [Framer Motion Basics]

### Spatial awareness and origin
- Popovers scale from their trigger, not from their center: set the transform origin at the trigger. [Practical Tips, Transforms, Train your judgement]
- Exit direction mirrors entry direction; navigation direction matches the mental model; a dialog's entrance should read as coming from the thing that opened it. [Train your judgement]
- Sonner enters and leaves in the same direction so swipe-to-dismiss feels consistent with how it arrived. [Timing and purpose]

### Hover and tap
- `scale 1.05` on hover is almost always too much; 1 to 2% is enough. [Train your judgement]
- A hover that moves the element must move a child, not the hover target, or the pointer leaves the hit area and the state flickers. [Practical Tips]
- Disable hover effects on touch input; keep hit targets at least 44 pt. [Practical Tips, Transitions]
- Press feedback scale 0.97; a 0.9 press feels heavy. [Train your judgement]

### When not to animate
- Frequency is the deciding factor. Raycast opens hundreds of times a day and has no open animation; that is the optimal experience for a daily-driver tool. Keyboard-initiated actions (arrow-key selection) are never animated; a delayed highlight feels disconnected from the key press. [Timing and purpose, Practical Tips]
- A hover effect used dozens of times a day gets no animation, or the shortest possible one; even 200 ms on a frequently hovered list feels sluggish. [What makes an animation feel right]
- Delight is for rarely used moments (a feedback form you open once a week); used daily it becomes friction. An animation feels right when it is obvious why it exists. [Timing and purpose]
- Products should feel fast; marketing pages may be slower and more expressive, and intro animations play once per session. Brand feel is set by pace: Vercel very fast or instant, Stripe slow and premium, Sonner slightly slow and `ease` for elegance. [Timing and purpose, The big little details]
- Use your own product daily to find the animations that annoy you; ship, then keep replaying for a few days before calling it done. [Practical Tips, The big little details]

### Reduce motion
- Ship two variants of every animation. Under reduced motion: no autoplaying loops, animate only opacity / color / background, never transform or layout movement. Reduced does not mean none; opacity fades keep the UI understandable. Loops can be paused on a chosen frame with a negative delay. Motion's `MotionConfig reducedMotion="user"` limits animation to opacity and background color app-wide. [Accessibility, Navigation menu: Closing thoughts]

### Performance
- 60 fps means a 16.7 ms frame budget. Animate only transform and opacity (composite step); width/height/padding/margin/top/left force layout every frame. clip-path and transform are GPU-accelerated. Add `will-change: transform` to stop the 1 px CPU/GPU hand-off shift. Blur is expensive; keep it small. Changing an inherited variable on a parent re-styles every child (Vaul drag lag past about 20 items). [Performance, Practical Tips, Clip Path]

### Taste and process
- Record the animation and scrub it frame by frame; recreate great work until you can name why it works; step away for a day before shipping. [Taste, Practical Tips, Family Drawer: The analysis]
- Prototype in a live interface, expose the knobs (sliders bound to values), test with worst-case content, share early. [Prototyping interfaces]
- The course's review checklist rejects: ease-in on UI, transitions past 300 ms, wrong transform-origin, animation on something done a hundred times a day. [skills page]
- A motion brief per component should state: what animates on enter and exit, the transform origin, easing and duration, what happens when interrupted mid-flight, the reduced-motion variant, or the verdict that it should not animate at all. [skills page]

## Translation table: CSS / Framer Motion to SwiftUI

| Web | SwiftUI |
|---|---|
| `transition: transform 200ms cubic-bezier(x1,y1,x2,y2)` | `.animation(.timingCurve(x1, y1, x2, y2, duration: 0.2), value: state)` |
| The same curve as a reusable value | `UnitCurve.bezier(startControlPoint: .init(x: x1, y: y1), endControlPoint: .init(x: x2, y: y2))` (Fovea's `Tokens.Motion.curve` is ease-out-quint) |
| CSS `ease-out` (0, 0, 0.58, 1) | `.easeOut(duration:)`; identical weak curve, which the course says is not strong enough. Use ease-out-quart `.timingCurve(0.165, 0.84, 0.44, 1, duration:)` or ease-out-quint `.timingCurve(0.23, 1, 0.32, 1, duration:)` instead |
| CSS `ease` (0.25, 0.1, 0.25, 1) | `.timingCurve(0.25, 0.1, 0.25, 1, duration:)` for hover colour changes |
| CSS `ease-in-out` (0.42, 0, 0.58, 1) | `.easeInOut(duration:)`; prefer ease-in-out-cubic `.timingCurve(0.645, 0.045, 0.355, 1, duration:)` for on-screen moves |
| `linear` | `.linear(duration:)` |
| Framer `{ type: "spring", duration: D, bounce: B }` | `.spring(duration: D, bounce: B)` 1:1. Motion adopted Apple's duration + bounce model, so the numbers transfer directly. Presets `[SwiftUI API]`: `.smooth` = bounce 0, `.snappy` = bounce 0.15, `.bouncy` = bounce 0.3, default duration 0.5 s |
| Framer `{ type: "spring", bounce: B }` with no duration | `.spring(duration: 0.8, bounce: B)` (Motion's default duration when only bounce is set `[Motion docs]`), then shorten to taste |
| `.spring(response:dampingFraction:)` vs `(duration:bounce:)` | For bounce >= 0: `dampingFraction = 1 - bounce`, `response ~= duration` `[Apple Spring model]`. Fovea today: open = response 0.42 / damping 0.8 = duration 0.42 bounce 0.2; close = 0.45 / 1.0 = bounce 0; hover = 0.3 / 0.9 = bounce 0.1; convert = `.snappy(duration: 0.4)` = bounce 0.15 |
| Framer `{ type: "spring", stiffness: k, damping: c, mass: m }` | `.interpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: 0)`, or convert: `response = 2 * pi * sqrt(m / k)`, `dampingFraction = c / (2 * sqrt(k * m))`. Course examples: cursor follow (0.1, 71, 16) -> response 0.24 s, dampingFraction 3.0 (overdamped, gentle lag); ticker (mass 1, 185, 25) -> response 0.46 s, dampingFraction 0.92; demo (0.75, 100, 10) -> response 0.54 s, dampingFraction 0.58 (visibly bouncy) |
| Framer `initial / animate / exit` with opacity + blur + scale | one `AnyTransition.modifier(active:identity:)`, see below |
| `AnimatePresence mode="popLayout"` (crossfade) | `.id(key)` on the content plus `.transition(...)`; SwiftUI keeps both views during the swap by default |
| `AnimatePresence mode="wait"` (sequential) | `.transition(.asymmetric(insertion: t.animation(anim.delay(exitDuration)), removal: t.animation(exitAnim)))`, or drive it with `PhaseAnimator` |
| `layout` / `layoutId` shared-layout | `matchedGeometryEffect(id:in:)` inside a `Namespace`; `.animation(spring, value: frames)` for size changes |
| Framer keyframes `rotate: [0, 20, -15, 12.5, -10, 10, -7.5, 7.5, -5, 5, 0]` | `.keyframeAnimator(initialValue:trigger:)` with `LinearKeyframe` / `SpringKeyframe` steps |
| Stagger `delay: i * 0.03` or `animation-delay: calc(30ms * var(--index))` | `.animation(anim.delay(Double(i) * 0.03), value:)` or `withAnimation(anim.delay(Double(i) * 0.03))` |
| `transform-origin: top left` / `--transform-origin` | `.scaleEffect(s, anchor: .topLeading)`; `.transition(.scale(scale: 0.96, anchor: .top))` |
| `@media (prefers-reduced-motion: reduce)` | `@Environment(\.accessibilityReduceMotion)`; swap to `.opacity` transitions and a 0.1 s fade or `nil` |
| `will-change: transform` | `.drawingGroup()` / `.compositingGroup()` where a layer is worth it; not needed for plain transform + opacity |
| `useMotionValue` tracking a drag 1:1 | `@GestureState` / drag translation applied without animation; spring only on `.onEnded` |
| Tooltip delay + skip-delay window | Task-based dwell timers (Fovea already has `exitGrace`, `layoutGrace`, `shelfGrace`) |

Single-modifier enter/exit transition (the course's opacity + blur + scale recipe):

```swift
struct FadeBlurScale: ViewModifier {
    var opacity: Double
    var blur: CGFloat
    var scale: CGFloat
    var anchor: UnitPoint = .center
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(scale, anchor: anchor)
    }
}

extension AnyTransition {
    /// Enter: 0.94 -> 1 with 4 pt blur; exit: 1 -> 0.94 with 4 pt blur.
    static func fadeBlurScale(enterScale: CGFloat = 0.94, exitScale: CGFloat = 0.94,
                              blur: CGFloat = 4, anchor: UnitPoint = .top) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: FadeBlurScale(opacity: 0, blur: blur, scale: enterScale, anchor: anchor),
                                 identity: FadeBlurScale(opacity: 1, blur: 0, scale: 1, anchor: anchor)),
            removal: .modifier(active: FadeBlurScale(opacity: 0, blur: blur, scale: exitScale, anchor: anchor),
                               identity: FadeBlurScale(opacity: 1, blur: 0, scale: 1, anchor: anchor)))
    }
}
```

## Recommended Tokens.Motion values for Fovea

Fovea is a daily-driver surface opened many times a day, so the course's frequency rule outranks its Dynamic Island playfulness: fast, ease-out, near-zero bounce, exits shorter than entries, and no animation at all on keyboard-driven selection. The one place the course explicitly endorses elasticity is the Island geometry itself, and only with a small value.

Island geometry (`Tokens.Motion.Spring`):
- `open`: `.spring(duration: 0.38, bounce: 0.15)` (today 0.42 / bounce 0.2). A small bounce is justified by the course's Dynamic Island brief ("deliberate elasticity", "living organism"), but the course's own values (0.3 to 0.5) are for a phone demo without a duration cap; the bounce rule says keep it very small, and the 300 ms guideline plus "bigger elements move slower" put a big notch surface at 0.35 to 0.4 s. [Dynamic Island: The Design, Spring animations, Timing and purpose]
- `close`: `.spring(duration: 0.30, bounce: 0)` (today 0.45 / bounce 0). Press-to-close gets no bounce; exits are shorter than entries. [Spring animations, Train your judgement]
- `hover` (grow under the pointer): `.spring(duration: 0.26, bounce: 0.05)` (today 0.3 / 0.9 damping = bounce 0.1). Hover is re-targeted constantly, so it must stay a spring for interruptibility, but a daily hover wants almost no overshoot. [Spring animations, Train your judgement]
- `convert` (referent stack expand): `.spring(duration: 0.32, bounce: 0.1)` (today `.snappy(duration: 0.4)` = bounce 0.15). Smaller element, so it may keep slightly more bounce than the full open, per "smaller views need more bounce to register, larger ones less". [Dynamic Island: Morph effect]
- Rule for any new geometry spring: bounce scales inversely with the size of the change, never above 0.2 on macOS; all springs have `duration` set explicitly so nothing inherits an 0.8 s default. [Dynamic Island: Morph effect, Motion docs]

Island content hand-off (`IslandSurface.content` transition, today `.opacity + .scale(0.96, anchor: .top)`):
- Enter: opacity 0 to 1, blur 4 pt to 0, scale 0.94 to 1 anchored `.top`; start 50 ms after the geometry spring so the shape leads and the content follows. `.spring(duration: 0.25, bounce: 0)` or `.timingCurve(0.165, 0.84, 0.44, 1, duration: 0.2)`. [Dynamic Island: Morph effect, Trash interaction, Practical Tips]
- Exit: opacity 1 to 0, blur 4 pt, 0.15 s; scale toward 0.9 when the island is shrinking and toward 1.08 when it is growing (the course used 0.7 / 1.4 for a much larger relative size jump). [Dynamic Island: Morph effect, Train your judgement]
- Numbers and short labels that change in place (timer, counters): `y 8 pt -> 0` with 2 pt blur, tabular numerals, `.spring(duration: 0.3, bounce: 0.1)`; do not animate text that changes on every keystroke (`phaseKey` already keeps those stable). [Dynamic Island: Timer view, Timing and purpose]
- Never start a view from scale 0; 0.9 to 0.96 is the range. [Practical Tips]

Press and hover (`Tokens.Motion.Kind`):
- `press`: scale 0.97, 0.12 to 0.15 s ease-out-quart (`.timingCurve(0.165, 0.84, 0.44, 1, duration: 0.12)`). Today 0.12 s ease-out-quint is on target. [Easing Blueprint, Practical Tips]
- `hover` colour / background changes: 0.10 to 0.12 s with the CSS `ease` curve `.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.12)` instead of a strong ease-out; and for the rows hovered most (agent list, chat selector) no animation at all. [Easing Blueprint, Transitions, Train your judgement]
- Hover lift or scale on cards: at most 1 to 2%, and move a child layer, not the hit target. [Train your judgement, Practical Tips]
- Keyboard selection highlight (arrow keys in lists): `nil` animation, always. [Timing and purpose, Practical Tips]

Popover, dropdown, select, sheet:
- `popover`: 0.16 s enter ease-out-quart, scale 0.96 to 1 + opacity, anchor at the trigger edge (`.top` when it hangs below the island, `.topLeading` / `.topTrailing` for corner-anchored menus); exit 0.12 s opacity + scale 0.98. [Practical Tips, Train your judgement, Framer Motion Basics]
- `select` 0.18 s and `accordion` 0.20 s: keep; accordion should be a measured-height animation with ease-out, no bounce. [Train your judgement, Multi-step component]
- `sheet` 0.22 s: keep; if a sheet ever slides from an edge use `(0.32, 0.72, 0, 1)` at 0.35 to 0.45 s, which is the iOS-sheet feel the course borrowed for Vaul. [Timing and purpose]
- `detailOpen` 0.20 s / `detailClose` 0.17 s with `(0.22, 1, 0.36, 1)`: keep; exit already shorter than entry and starts from `detailZoomScale` 0.96, inside the 0.85 to 0.95+ rule. [Train your judgement, Practical Tips]
- Tooltips: 0.125 s ease-out, scale 0.97; first tooltip after a dwell, subsequent tooltips within a short window instant with no animation. [Practical Tips]

Choreography:
- Staggered list entrances (referent shelf, agent list): 30 ms per item, cap the stagger at about 6 items (later items appear with the last delay) so the tail never exceeds 300 ms; one entrance per container, never parent + children. [The big little details, Train your judgement, course demo CSS]
- Layered timing inside the island: geometry first, content 50 ms later, secondary details (badges, waveform) 80 to 120 ms later; on a user click the primary response has zero delay. [Dynamic Island: Morph effect, Hero illustration: Click animation]

Dwell and grace (existing tokens, all kept):
- `exitGrace` 100 ms and `shelfGrace` 120 ms: consistent with the course's "hover intent" logic (pointer may wander briefly without collapsing). `layoutGrace` 600 ms after a resize is the right idea (ignore hover exits caused by the surface moving under a still pointer). [Practical Tips (tooltip delay logic), Train your judgement (interruptions)]
- Add `hoverIntent` ~ 100 to 150 ms before a pointer-driven expansion starts, and a `reopenWindow` ~ 300 ms during which re-entering skips the intent delay. The course gives the principle (delay the first tooltip, skip the delay for the next); the millisecond values here are Fovea's choice, aligned with Radix's skip-delay behaviour, not course numbers. [Practical Tips]

Reduced motion (existing behaviour, kept):
- Springs become 0.12 s opacity fades, movement transitions become `.opacity`, `breathePeriod` loop and waveform stop; this matches the course's "only opacity and colour, no autoplaying loops, reduced is not none". [Accessibility]

Curve tokens to add next to `Tokens.Motion.curve`:
- `curveOut` = ease-out-quart `(0.165, 0.84, 0.44, 1)` for enter/exit tweens; `curveOutStrong` = ease-out-quint `(0.23, 1, 0.32, 1)` (current `curve`) for the fastest snaps; `curveMove` = ease-in-out-cubic `(0.645, 0.045, 0.355, 1)` for on-screen repositioning; `curveHover` = `(0.25, 0.1, 0.25, 1)` for colour. [Easing Blueprint, easing-curves]
