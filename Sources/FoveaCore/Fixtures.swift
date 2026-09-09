import Foundation

/// Realistic local fixtures. Dates are relative to `now` so the feed always has a
/// Today and a Yesterday group. Ids are stable strings so fingerprints are deterministic.
public enum Fixtures {

    public static let claudeCode = AppRef(id: "claude-code", name: "Claude Code", symbol: "terminal")
    public static let cursor = AppRef(id: "cursor", name: "Cursor", symbol: "cursorarrow")
    public static let codex = AppRef(id: "codex", name: "Codex", symbol: "chevron.left.forwardslash.chevron.right")
    public static let figma = AppRef(id: "figma", name: "Figma", symbol: "pencil.and.outline")
    public static let safari = AppRef(id: "safari", name: "Safari", symbol: "safari")
    public static let xcode = AppRef(id: "xcode", name: "Xcode", symbol: "hammer")
    public static let terminal = AppRef(id: "terminal", name: "Terminal", symbol: "apple.terminal")
    public static let preview = AppRef(id: "preview", name: "Preview", symbol: "doc.richtext")
    public static let notion = AppRef(id: "notion", name: "Notion", symbol: "note.text")
    public static let linear = AppRef(id: "linear", name: "Linear", symbol: "line.3.horizontal.decrease")
    public static let photos = AppRef(id: "photos", name: "Photos", symbol: "photo")

    public static func captures(now: Date = Date(), calendar: Calendar = .current) -> [Capture] {
        (baseCaptures(now: now, calendar: calendar) + textCaptures(now: now, calendar: calendar)).map(decorate)
    }

    /// Tags, Chat names and extra referents for the detail card, keyed by capture id. The
    /// hero referent stays first so the feed layout does not change.
    private static func decorate(_ capture: Capture) -> Capture {
        var c = capture
        if let meta = detailMeta[c.id] {
            c.tags = meta.tags
            c.chatName = meta.chat
        }
        if let extra = extraReferents[c.id] { c.referents += extra }
        return c
    }

    private static let detailMeta: [String: (tags: [String], chat: String)] = [
        "cap-navbar": (["Product Design", "Engineering"], "Fovea"),
        "cap-figma": (["Product Design", "Settings"], "Settings shell"),
        "cap-prisma": (["Engineering", "Schema"], "Schema"),
        "cap-mountain": (["Marketing", "Landing page"], "Landing page"),
        "cap-code": (["Engineering", "Bug"], "users.py"),
        "cap-rewrite": (["Writing"], "Copy edits"),
        "cap-spec": (["Product Design", "Onboarding", "Research"], "Onboarding"),
        "cap-tweet": (["Marketing", "Launch"], "Launch"),
        "cap-building": (["Marketing", "Gallery"], "Gallery"),
        "cap-equation": (["Research"], "Fovea"),
        "cap-error": (["Engineering", "Bug"], "Fovea"),
        "cap-terminal": (["Engineering", "Release"], "Release"),
        "cap-update": (["Product Design", "Navigation"], "Fovea"),
        "cap-chart": (["Research", "Training"], "Training"),
        "cap-meeting": (["Planning"], "Fovea"),
        "cap-linear": (["Planning", "Today"], "Dictionary polish"),
        "cap-compare": (["Product Design"], "Fovea"),
        "cap-coast": (["Marketing", "App Store"], "App Store"),
        "cap-research": (["Research", "Competitors"], "Research"),
        "cap-whiteboard": (["Planning"], "Fovea"),
        "cap-forest": (["Product Design", "Onboarding"], "Onboarding"),
        "cap-lion": (["Accessibility"], "Fovea"),
        "cap-desk": (["Marketing", "Video", "Mood"], "Demo video"),
    ]

    private static let extraReferents: [String: [Referent]] = [
        "cap-figma": [
            Referent(id: "ref-figma-home", kind: .screenshot, aspect: 1180.0 / 800.0,
                     resource: "Screens/fovea-home.png", filename: "Fovea — Home.png",
                     sourceApp: "Fovea", sourceWindowTitle: "Home"),
        ],
        "cap-mountain": [
            Referent(id: "ref-mountain-desk", kind: .image, aspect: 1200.0 / 800.0,
                     resource: "Photos/desk.jpg", filename: "desk.jpg", sourceApp: "Photos"),
            Referent(id: "ref-mountain-coast", kind: .image, aspect: 1200.0 / 800.0,
                     resource: "Photos/coast.jpg", filename: "coast.jpg", sourceApp: "Photos"),
        ],
        "cap-desk": [
            Referent(id: "ref-desk-mountain", kind: .image, aspect: 1200.0 / 800.0,
                     resource: "Photos/mountain.jpg", filename: "mountain.jpg", sourceApp: "Photos"),
            Referent(id: "ref-desk-coast", kind: .image, aspect: 1200.0 / 800.0,
                     resource: "Photos/coast.jpg", filename: "coast.jpg", sourceApp: "Photos"),
            Referent(id: "ref-desk-forest", kind: .image, aspect: 1200.0 / 800.0,
                     resource: "Photos/forest.jpg", filename: "forest.jpg", sourceApp: "Photos"),
            Referent(id: "ref-desk-building", kind: .image, aspect: 900.0 / 1200.0,
                     resource: "Photos/building.jpg", filename: "building.jpg", sourceApp: "Photos"),
            Referent(id: "ref-desk-lion", kind: .image, aspect: 1200.0 / 900.0,
                     resource: "Photos/lion.jpg", filename: "lion.jpg", sourceApp: "Photos"),
        ],
    ]

    private static func baseCaptures(now: Date, calendar: Calendar) -> [Capture] {
        func at(daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        let codeSnippet = """
        def process_user(user):
            if user is None:
                return None
            return user.name
        """
        let terminalOutput = """
        > npm run build
        ✓ Compiled successfully
        ✓ Linting and checking...
        ✓ Generated 12 pages

        Done in 8.4s
        """
        let lossPoints: [ChartPoint] = stride(from: 0, through: 40_000, by: 1_000).map { step in
            let x = Double(step)
            let y = 0.0015 + 0.98 * exp(-x / 2600) + 0.02 * exp(-x / 15000)
            return ChartPoint(x: x, y: y)
        }

        return [
            // Today
            Capture(id: "cap-navbar", intent: .voiceOnly, createdAt: at(daysAgo: 0, 10, 24),
                    transcript: "The navbar needs a bit more padding on the left and the hover state should match the sidebar links.",
                    semanticAnchors: ["navbar", "padding", "hover state"],
                    sourceApp: safari, destinationApp: claudeCode),
            Capture(id: "cap-figma", intent: .voiceWithAttachment, createdAt: at(daysAgo: 0, 9, 41),
                    transcript: "Use this layout as the reference for the settings shell, keep the sidebar quiet.",
                    semanticAnchors: ["layout", "settings shell", "sidebar"],
                    referents: [Referent(id: "ref-figma", kind: .screenshot, aspect: 1180.0 / 800.0,
                                         resource: "Screens/fovea-settings.png", filename: "Fovea — Settings.png",
                                         sourceApp: "Fovea", sourceWindowTitle: "Settings")],
                    sourceApp: figma, destinationApp: cursor),
            Capture(id: "cap-prisma", intent: .voiceOnly, createdAt: at(daysAgo: 0, 9, 12),
                    transcript: "Take this table and generate the matching Prisma schema for the database.",
                    semanticAnchors: ["prisma", "schema", "database"],
                    sourceApp: notion, destinationApp: cursor),
            Capture(id: "cap-mountain", intent: .voiceWithAttachment, createdAt: at(daysAgo: 0, 8, 54),
                    transcript: "Use this as the hero image on the landing page.",
                    semanticAnchors: ["hero image", "landing page"],
                    referents: [Referent(id: "ref-mountain", kind: .image, aspect: 1200.0 / 800.0,
                                         resource: "Photos/mountain.jpg", filename: "mountain.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: claudeCode),
            Capture(id: "cap-code", intent: .voiceWithAttachment, createdAt: at(daysAgo: 0, 8, 20),
                    transcript: "This function should raise instead of returning None.",
                    semanticAnchors: ["process_user", "raise", "None"],
                    referents: [Referent(id: "ref-code", kind: .code, aspect: 1.55,
                                         filename: "users.py", text: codeSnippet,
                                         sourceApp: "Xcode", sourceWindowTitle: "users.py")],
                    sourceApp: xcode, destinationApp: claudeCode),
            Capture(id: "cap-rewrite", intent: .voiceOnly, createdAt: at(daysAgo: 0, 8, 16),
                    transcript: "Rewrite the second paragraph so it's under 80 words.",
                    semanticAnchors: ["rewrite", "paragraph", "under 80 words"],
                    sourceApp: safari, destinationApp: codex),
            Capture(id: "cap-spec", intent: .voiceWithAttachment, createdAt: at(daysAgo: 0, 7, 46),
                    transcript: "Pull the user personas from this spec into the onboarding doc.",
                    semanticAnchors: ["user personas", "onboarding"],
                    referents: [Referent(id: "ref-spec", kind: .document, aspect: 1.5,
                                         filename: "Design_Spec_v2.pdf",
                                         text: "1. Overview\n2. Goals\n3. User Personas",
                                         title: "Product Design Specification",
                                         sourceApp: "Preview", sourceWindowTitle: "Design_Spec_v2.pdf")],
                    sourceApp: preview, destinationApp: claudeCode),
            Capture(id: "cap-tweet", intent: .voiceOnly, createdAt: at(daysAgo: 0, 7, 32),
                    transcript: "Draft a tweet for the launch announcement, keep it to two lines.",
                    semanticAnchors: ["tweet", "launch", "announcement"],
                    sourceApp: safari, destinationApp: codex),
            Capture(id: "cap-building", intent: .voiceWithAttachment, createdAt: at(daysAgo: 0, 7, 21),
                    transcript: "Match the color grading of this photo in the gallery thumbnails.",
                    semanticAnchors: ["color grading", "gallery"],
                    referents: [Referent(id: "ref-building", kind: .image, aspect: 900.0 / 1200.0,
                                         resource: "Photos/building.jpg", filename: "building.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: cursor),

            // Yesterday
            Capture(id: "cap-equation", intent: .voiceWithAttachment, createdAt: at(daysAgo: 1, 22, 14),
                    transcript: "Explain each term of this equation in one line.",
                    semanticAnchors: ["equation", "Maxwell"],
                    referents: [Referent(id: "ref-equation", kind: .equation, aspect: 1.75,
                                         text: "∇ × B⃗ = μ₀J⃗ + μ₀ε₀ ∂E⃗/∂t",
                                         sourceApp: "Safari", sourceWindowTitle: "Ampère–Maxwell law")],
                    sourceApp: safari, destinationApp: claudeCode),
            Capture(id: "cap-error", intent: .voiceOnly, createdAt: at(daysAgo: 1, 21, 3),
                    transcript: "This error comes from the function here, add a nil check before the cast.",
                    semanticAnchors: ["error", "nil check", "function", "cast"],
                    sourceApp: terminal, destinationApp: claudeCode, deliveryStatus: .failed),
            Capture(id: "cap-terminal", intent: .voiceWithAttachment, createdAt: at(daysAgo: 1, 20, 47),
                    transcript: "The build is green now, write the changelog entry.",
                    semanticAnchors: ["build", "changelog"],
                    referents: [Referent(id: "ref-terminal", kind: .terminal, aspect: 1.5,
                                         filename: "zsh — fovea", text: terminalOutput,
                                         sourceApp: "Terminal", sourceWindowTitle: "zsh — fovea")],
                    sourceApp: terminal, destinationApp: codex),
            Capture(id: "cap-update", intent: .quickAnswer, createdAt: at(daysAgo: 1, 19, 21),
                    transcript: "Update the layout so it's more compact.",
                    semanticAnchors: ["update", "layout", "more compact"],
                    sourceApp: figma, destinationApp: nil,
                    question: "How do I make this layout more compact without dropping the section labels?",
                    answer: "Reduce the vertical gap between groups from 24 to 16 points, move section labels into the first row of each group, and drop the per-row explanatory text where the label is self-evident."),
            Capture(id: "cap-chart", intent: .voiceWithAttachment, createdAt: at(daysAgo: 1, 18, 58),
                    transcript: "Loss plateaus after 20k steps, try a lower learning rate.",
                    semanticAnchors: ["training loss", "learning rate"],
                    referents: [Referent(id: "ref-chart", kind: .chart, aspect: 1.55,
                                         title: "Training Loss", chartPoints: lossPoints,
                                         sourceApp: "Safari", sourceWindowTitle: "Weights & Biases")],
                    sourceApp: safari, destinationApp: claudeCode),

            // Older
            Capture(id: "cap-meeting", intent: .voiceOnly, createdAt: at(daysAgo: 12, 11, 2),
                    transcript: "Turn my meeting notes into action items and a follow up email.",
                    semanticAnchors: ["meeting", "notes", "action items", "follow up"],
                    sourceApp: notion, destinationApp: claudeCode),
            Capture(id: "cap-linear", intent: .voiceWithAttachment, createdAt: at(daysAgo: 12, 10, 21),
                    transcript: "Order today's list by priority and move the docs task to tomorrow.",
                    semanticAnchors: ["today", "priority", "docs task"],
                    referents: [Referent(id: "ref-linear", kind: .screenshot, aspect: 1180.0 / 800.0,
                                         resource: "Screens/fovea-home.png", filename: "Fovea — Home.png",
                                         sourceApp: "Fovea", sourceWindowTitle: "Home")],
                    sourceApp: linear, destinationApp: cursor),
            Capture(id: "cap-compare", intent: .voiceOnly, createdAt: at(daysAgo: 12, 9, 37),
                    transcript: "Compare these two designs and tell me which one reads faster.",
                    semanticAnchors: ["compare", "these two", "designs"],
                    sourceApp: figma, destinationApp: claudeCode),
            Capture(id: "cap-coast", intent: .voiceWithAttachment, createdAt: at(daysAgo: 12, 8, 14),
                    transcript: "Crop this to a square for the app store screenshot.",
                    semanticAnchors: ["crop", "square", "app store"],
                    referents: [Referent(id: "ref-coast", kind: .image, aspect: 1200.0 / 800.0,
                                         resource: "Photos/coast.jpg", filename: "coast.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: cursor),
            Capture(id: "cap-research", intent: .voiceOnly, createdAt: at(daysAgo: 12, 6, 28),
                    transcript: "Research the competitors and give me the key takeaways.",
                    semanticAnchors: ["research", "competitors", "key takeaways"],
                    sourceApp: safari, destinationApp: codex),

            Capture(id: "cap-whiteboard", intent: .voiceWithAttachment, createdAt: at(daysAgo: 15, 16, 5),
                    transcript: "Transcribe the whiteboard into a bullet list.",
                    semanticAnchors: ["whiteboard", "bullet list"],
                    referents: [Referent(id: "ref-whiteboard", kind: .image, aspect: 4.0 / 3.0,
                                         resource: "Photos/whiteboard.jpg", filename: "IMG_4821.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: claudeCode),
            Capture(id: "cap-forest", intent: .voiceWithAttachment, createdAt: at(daysAgo: 15, 15, 40),
                    transcript: "Pick a palette from this photo for the onboarding screens.",
                    semanticAnchors: ["palette", "onboarding"],
                    referents: [Referent(id: "ref-forest", kind: .image, aspect: 1200.0 / 800.0,
                                         resource: "Photos/forest.jpg", filename: "forest.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: cursor),
            Capture(id: "cap-lion", intent: .voiceWithAttachment, createdAt: at(daysAgo: 15, 14, 12),
                    transcript: "Describe this image for the alt text.",
                    semanticAnchors: ["alt text", "image"],
                    referents: [Referent(id: "ref-lion", kind: .image, aspect: 1200.0 / 900.0,
                                         resource: "Photos/lion.jpg", filename: "lion.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: claudeCode),
            Capture(id: "cap-desk", intent: .voiceWithAttachment, createdAt: at(daysAgo: 15, 9, 3),
                    transcript: "Use this mood for the café scene in the demo video.",
                    semanticAnchors: ["mood", "café", "demo video"],
                    referents: [Referent(id: "ref-desk", kind: .image, aspect: 1200.0 / 800.0,
                                         resource: "Photos/desk.jpg", filename: "desk.jpg",
                                         sourceApp: "Photos")],
                    sourceApp: photos, destinationApp: codex),
        ]
    }

    /// Text-only captures (and two Quick Answers) so the feed is mostly words, the way a
    /// week of real use looks. Spread over the same days as the media captures plus two more.
    private static func textCaptures(now: Date, calendar: Calendar) -> [Capture] {
        func at(daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }
        func voice(_ id: String, _ d: Int, _ h: Int, _ m: Int, _ transcript: String, _ anchors: [String],
                   from source: AppRef, to destination: AppRef, tags: [String], chat: String,
                   status: DeliveryStatus = .delivered) -> Capture {
            Capture(id: id, intent: .voiceOnly, createdAt: at(daysAgo: d, h, m), transcript: transcript,
                    semanticAnchors: anchors, sourceApp: source, destinationApp: destination,
                    deliveryStatus: status, tags: tags, chatName: chat)
        }
        return [
            // Today
            voice("cap-empty-state", 0, 11, 6,
                  "Make sure the empty state explains what Fovea can see, and add a subtle shortcut hint below it.",
                  ["empty state", "shortcut hint"], from: xcode, to: claudeCode, tags: ["Product Design", "Onboarding"], chat: "Fovea"),
            voice("cap-toast", 0, 10, 52,
                  "The delivery toast should stay for three seconds, not five, and it should slide up from the bottom edge instead of fading in place.",
                  ["toast", "three seconds", "slide up"], from: xcode, to: claudeCode, tags: ["Product Design", "Motion"], chat: "Fovea"),
            voice("cap-retry-copy", 0, 10, 8,
                  "Change the retry copy so it says what failed. Delivery failed is not enough, tell them which agent did not answer.",
                  ["retry copy", "which agent"], from: safari, to: cursor, tags: ["Writing", "Errors"], chat: "Copy edits"),
            voice("cap-sidebar-focus", 0, 9, 27,
                  "Tab order in the settings sidebar skips the second child under Voice and Capture, check the focusable modifiers there.",
                  ["tab order", "sidebar", "focusable"], from: xcode, to: claudeCode, tags: ["Engineering", "Accessibility"], chat: "Settings shell"),
            voice("cap-search-debounce", 0, 8, 41,
                  "Search filters on every keystroke and stutters on long lists, debounce it by about a hundred and fifty milliseconds and keep the first result stable.",
                  ["search", "debounce", "stutters"], from: xcode, to: codex, tags: ["Engineering", "Performance"], chat: "Fovea"),
            voice("cap-import-photos", 0, 8, 3,
                  "Write a script that pulls six free photos with known aspect ratios so the feed fixtures stop depending on my desktop.",
                  ["script", "photos", "fixtures"], from: terminal, to: codex, tags: ["Engineering", "Fixtures"], chat: "Release"),
            voice("cap-quiet-week", 0, 7, 55,
                  "Draft a short note to the team about what shipped this week, keep it to five bullets and no adjectives.",
                  ["note", "team", "five bullets"], from: notion, to: claudeCode, tags: ["Writing", "Planning"], chat: "Fovea"),
            voice("cap-standup", 0, 7, 12,
                  "Turn yesterday's standup into three follow up tasks and assign the connector one to me.",
                  ["standup", "follow up", "connector"], from: notion, to: cursor, tags: ["Planning"], chat: "Dictionary polish"),
            // Yesterday
            voice("cap-hover-timing", 1, 21, 40,
                  "Hover reveals feel late. Cut the delay to zero on enter and keep a hundred milliseconds of grace on exit.",
                  ["hover", "delay", "grace"], from: xcode, to: claudeCode, tags: ["Product Design", "Motion"], chat: "Fovea"),
            voice("cap-permissions", 1, 20, 19,
                  "If microphone access is denied, show one line and a button to the exact privacy pane, do not show the waveform at all.",
                  ["microphone", "privacy pane", "waveform"], from: safari, to: claudeCode, tags: ["Product Design", "Permissions"], chat: "Fovea"),
            voice("cap-alt-wording", 1, 19, 46,
                  "Rewrite the alt text for the three landing images so they describe what is in them, not how they feel.",
                  ["alt text", "landing images"], from: safari, to: codex, tags: ["Writing", "Accessibility"], chat: "Landing page"),
            Capture(id: "cap-qa-tokens", intent: .quickAnswer, createdAt: at(daysAgo: 1, 18, 33),
                    transcript: "Why keep colors in a tokens file?",
                    semanticAnchors: ["tokens", "colors"], sourceApp: xcode,
                    question: "Why should every color live in one tokens file instead of the views?",
                    answer: "Because the palette drifts otherwise. Once a color is typed into a view it gets copied, tweaked and forgotten; two weeks later the same gray exists in nine shades. One file makes the palette reviewable, lets you retheme in a single change, and keeps light and dark variants next to each other.",
                    tags: ["Engineering", "Design system"], chatName: "Fovea"),
            voice("cap-changelog-tone", 1, 17, 58,
                  "The changelog reads like a commit log. Rewrite the top three entries as sentences a user would care about.",
                  ["changelog", "sentences", "user"], from: notion, to: claudeCode, tags: ["Writing", "Release"], chat: "Release"),
            voice("cap-menu-order", 1, 16, 22,
                  "Reorder the Island menu so the states follow the actual flow: listening, transcribing, review, then the quick answers.",
                  ["Island menu", "order", "flow"], from: xcode, to: cursor, tags: ["Product Design"], chat: "Fovea", status: .failed),
            // Two days ago
            voice("cap-onboarding-steps", 2, 15, 30,
                  "Onboarding has five steps and nobody finishes it. Merge permissions into one screen and drop the tour entirely.",
                  ["onboarding", "five steps", "permissions"], from: figma, to: claudeCode, tags: ["Product Design", "Onboarding"], chat: "Onboarding"),
            voice("cap-log-noise", 2, 14, 4,
                  "The console prints a warning for every hover event. Find where that log line lives and remove it before the build.",
                  ["console", "warning", "hover event"], from: terminal, to: codex, tags: ["Engineering", "Bug"], chat: "Release"),
            voice("cap-pricing-copy", 2, 12, 47,
                  "Explain the Pro plan in one sentence under the price, something like six hundred captures a month, no per agent fees.",
                  ["Pro plan", "one sentence", "captures a month"], from: safari, to: claudeCode, tags: ["Writing", "Marketing"], chat: "Landing page"),
            voice("cap-keyboard-map", 2, 11, 15,
                  "List every keyboard shortcut the window supports and check that none of them collide with system ones.",
                  ["keyboard shortcut", "collide", "system"], from: xcode, to: cursor, tags: ["Engineering", "Accessibility"], chat: "Settings shell"),
            voice("cap-interview-notes", 2, 9, 38,
                  "Summarize the three user interviews from Tuesday into what surprised us and what we already knew.",
                  ["user interviews", "surprised", "already knew"], from: notion, to: claudeCode, tags: ["Research"], chat: "Research"),
            // Five days ago
            voice("cap-icon-weights", 5, 16, 51,
                  "All the sidebar icons should be the same optical weight. The eye icon is heavier than the rest, swap it for the outlined variant.",
                  ["sidebar icons", "optical weight", "eye icon"], from: figma, to: cursor, tags: ["Product Design"], chat: "Settings shell"),
            voice("cap-flaky-test", 5, 15, 9,
                  "The store test fails one time in twenty because it reuses the same user defaults suite, give each test its own suite name.",
                  ["store test", "flaky", "user defaults"], from: terminal, to: codex, tags: ["Engineering", "Tests"], chat: "Release"),
            Capture(id: "cap-qa-notch", intent: .quickAnswer, createdAt: at(daysAgo: 5, 13, 26),
                    transcript: "How wide is the notch in points?",
                    semanticAnchors: ["notch", "points"], sourceApp: xcode,
                    question: "How wide is the MacBook notch in points, and can I read it at runtime?",
                    answer: "It depends on the model and the scaled resolution, roughly 180 to 200 points. Read it at runtime from the screen: the notch width is the screen width minus the two auxiliary top areas, and its height is the top safe-area inset. Never hardcode it.",
                    tags: ["Engineering", "Island"], chatName: "Fovea"),
            voice("cap-demo-script", 5, 10, 44,
                  "Write a ninety second demo script that starts with a capture, shows the review step once, and ends on the quick answer.",
                  ["demo script", "ninety seconds", "quick answer"], from: notion, to: claudeCode, tags: ["Marketing", "Video"], chat: "Demo video"),
            // Older
            voice("cap-analytics-list", 12, 12, 16,
                  "Draft the analytics event list for the Island, no transcript content in any event, just names and when they fire.",
                  ["analytics", "event list", "Island"], from: notion, to: claudeCode, tags: ["Engineering", "Planning"], chat: "Fovea"),
            voice("cap-color-names", 12, 9, 2,
                  "Rename the accent colors after real things, cobalt and sage read better than blue one and green two.",
                  ["accent colors", "rename", "cobalt"], from: figma, to: cursor, tags: ["Product Design", "Design system"], chat: "Settings shell"),
            voice("cap-license-check", 12, 7, 49,
                  "Check the licenses of the two notch libraries we are borrowing from and note which files need the copyright header kept.",
                  ["licenses", "notch libraries", "copyright"], from: safari, to: codex, tags: ["Engineering", "Legal"], chat: "Release"),
            voice("cap-quiet-motion", 15, 17, 20,
                  "Everything that enters should ease out and nothing should bounce. Go through the motion tokens and remove every spring that is not on the Island.",
                  ["ease out", "bounce", "motion tokens"], from: xcode, to: claudeCode, tags: ["Product Design", "Motion"], chat: "Fovea"),
            voice("cap-readme", 15, 12, 33,
                  "Rewrite the readme so the first three lines tell a designer how to run it and try one capture.",
                  ["readme", "designer", "run it"], from: terminal, to: codex, tags: ["Writing"], chat: "Release"),
        ]
    }

    public static func dictionary(now: Date = Date()) -> [DictionaryTerm] {
        let words: [(String, [String], Int)] = [
            ("Fovea", ["Fovia", "Phovea"], 42), ("VoiceFlow", ["Voice flow"], 38), ("Supabase", ["Super base"], 30),
            ("Claude", ["Cloud", "Clod"], 29), ("Linear", [], 25), ("Yulun", ["You Lun", "Yulin"], 24),
            ("Codex", ["Code X"], 20), ("Cursor", [], 18), ("Prisma", ["Prism a"], 16), ("Tailwind", [], 15),
            ("shadcn", ["shad CN"], 14), ("Xcode", ["X code"], 13), ("SwiftUI", ["Swift UI"], 12),
            ("Zustand", [], 11), ("Vercel", ["Versel"], 11), ("Postgres", [], 10), ("Notion", [], 9),
            ("Figma", [], 9), ("Raycast", ["Ray cast"], 8), ("Obsidian", [], 8), ("Anthropic", [], 7),
            ("Kowalski", ["Kovalski"], 6), ("Lucide", ["Lucid"], 6), ("Ampère", ["Ampere"], 5),
            ("navbar", ["nav bar"], 5), ("useEffect", ["use effect"], 5), ("Ryan", [], 4), ("MCP", ["M C P"], 4),
            ("Base UI", [], 4), ("Playwright", [], 3), ("pnpm", ["P N P M"], 3), ("Vite", ["Veet"], 3),
            ("Radix", [], 2), ("Dia", [], 2), ("Arc", [], 2), ("Sonoma", [], 1), ("Sequoia", [], 1), ("Mythos", [], 1),
        ]
        return words.enumerated().map { i, w in
            DictionaryTerm(id: "term-\(i)", preferredSpelling: w.0, aliases: w.1,
                           source: i % 3 == 0 ? .correction : .manual,
                           createdAt: now.addingTimeInterval(-Double(i) * 86_400 * 1.7),
                           useCount: w.2)
        }
    }

    public static let connectors: [Connector] = [
        Connector(id: "claude-code", name: "Claude Code", symbol: "terminal", status: .connected,
                  permissions: ["Send captures", "Read session state", "Open conversation"],
                  detail: "Session · fovea/app-ui-v1"),
        Connector(id: "cursor", name: "Cursor", symbol: "cursorarrow", status: .connected,
                  permissions: ["Send captures", "Open conversation"],
                  granted: ["Send captures"], detail: "Workspace · fovea"),
        Connector(id: "codex", name: "Codex", symbol: "chevron.left.forwardslash.chevron.right", status: .available,
                  permissions: ["Send captures", "Read session state"]),
        Connector(id: "chatgpt", name: "ChatGPT", symbol: "bubble.left.and.text.bubble.right", status: .available,
                  permissions: ["Send captures", "Open conversation"]),
        Connector(id: "raycast", name: "Raycast", symbol: "command", status: .available,
                  permissions: ["Send captures"]),
    ]

    public static func usage(now: Date = Date(), calendar: Calendar = .current) -> UsageSummary {
        let reset = calendar.date(byAdding: .day, value: 11, to: calendar.startOfDay(for: now))!
        return UsageSummary(used: 312, limit: 600, unitLabel: "captures", resetsAt: reset)
    }

    public static let plan = PlanInfo(name: "Pro", price: "$12", cadence: "per month")

    public static func billing(now: Date = Date(), calendar: Calendar = .current) -> [BillingEntry] {
        (0..<3).map { i in
            let date = calendar.date(byAdding: .month, value: -i, to: now)!
            return BillingEntry(id: "inv-\(i)", date: date, amount: "$12.00", description: "Fovea Pro · monthly")
        }
    }

    public static let audioInputs: [AudioInput] = [
        AudioInput(id: "default", name: "System Default (MacBook Pro Microphone)", isSystemDefault: true),
        AudioInput(id: "macbook", name: "MacBook Pro Microphone"),
        AudioInput(id: "airpods", name: "AirPods Pro"),
        AudioInput(id: "yeti", name: "Blue Yeti"),
    ]

    /// Simulated permission state for the prototype. Accessibility is missing so the
    /// Eye Tracking page shows the inline recovery affordance.
    public static let permissions: [SystemPermission: Bool] = [
        .microphone: true, .screenRecording: true, .accessibility: false, .eyeTracking: true,
    ]

    // MARK: - Island

    public static let chatGPT = AppRef(id: "chatgpt", name: "ChatGPT", symbol: "bubble.left.and.text.bubble.right")

    /// What the simulated transcriber "hears".
    public static let transcriptScript =
        "Make sure the empty state explains what Fovea can see, and add a subtle shortcut hint below it."

    /// Referents captured with the demo session: enough to wrap onto a second row.
    public static let reviewReferents: [Referent] = [
        Referent(id: "isl-settings", kind: .screenshot, aspect: 1180.0 / 800.0,
                 resource: "Screens/fovea-settings.png", filename: "Fovea — Settings.png",
                 sourceApp: "Fovea", sourceWindowTitle: "Settings"),
        Referent(id: "isl-home", kind: .screenshot, aspect: 1180.0 / 800.0,
                 resource: "Screens/fovea-home.png", filename: "Fovea — Home.png",
                 sourceApp: "Fovea", sourceWindowTitle: "Home"),
        Referent(id: "isl-mountain", kind: .image, aspect: 1.5, resource: "Photos/mountain.jpg",
                 filename: "mountain.jpg", sourceApp: "Photos"),
        Referent(id: "isl-desk", kind: .image, aspect: 1.5, resource: "Photos/desk.jpg",
                 filename: "desk.jpg", sourceApp: "Photos"),
        Referent(id: "isl-coast", kind: .image, aspect: 1.5, resource: "Photos/coast.jpg",
                 filename: "coast.jpg", sourceApp: "Photos"),
        Referent(id: "isl-forest", kind: .image, aspect: 1.5, resource: "Photos/forest.jpg",
                 filename: "forest.jpg", sourceApp: "Photos"),
        Referent(id: "isl-building", kind: .image, aspect: 1.5, resource: "Photos/building.jpg",
                 filename: "building.jpg", sourceApp: "Photos"),
        Referent(id: "isl-lion", kind: .image, aspect: 1.5, resource: "Photos/lion.jpg",
                 filename: "lion.jpg", sourceApp: "Photos"),
    ]

    // MARK: Chats

    public static let folderFovea = ContextFolder(name: "fovea", path: "~/Documents/fovea")
    public static let folderFuturo = ContextFolder(name: "Futuro", path: "~/Desktop/things/Futuro")
    public static let folderNewProject = ContextFolder(name: "New project", path: "~/Documents/New project")

    /// Folders a new Chat can start in; more than fit, so the list scrolls.
    public static let contextFolders: [ContextFolder] = [
        folderFovea,
        folderFuturo,
        folderNewProject,
        ContextFolder(name: "ai image gen", path: "~/Projects/ai image gen"),
        ContextFolder(name: "landing page", path: "~/Projects/landing page"),
        ContextFolder(name: "app-ui-v1", path: "~/Desktop/things/fovea/app-ui-v1"),
        ContextFolder(name: "Dictionary", path: "~/Projects/dictionary"),
        ContextFolder(name: "Marketing site", path: "~/Projects/marketing"),
    ]

    /// Destinations a new Chat can start in. Claude Code is the recommendation.
    public static let destinationChoices: [DestinationChoice] = [
        DestinationChoice(app: claudeCode, isRecommended: true),
        DestinationChoice(app: codex),
        DestinationChoice(app: cursor),
    ]

    /// Every Chat the catalog knows, most recent first. The first ten are within a day.
    public static func chatCatalog(now: Date = Date()) -> [ChatRoute] {
        func chat(_ id: String, _ name: String, _ app: AppRef, minutes: Double, in folder: ContextFolder) -> ChatRoute {
            ChatRoute(id: id, kind: .recent, destination: app, chatName: name,
                      lastActiveAt: now.addingTimeInterval(-minutes * 60), context: folder)
        }
        return [
            chat("chat-settings", "app-ui-v1 settings", claudeCode, minutes: 12, in: folderFovea),
            chat("chat-dictionary", "Dictionary polish", cursor, minutes: 38, in: folderFovea),
            chat("chat-launch-copy", "Launch copy review", chatGPT, minutes: 2 * 60, in: folderFuturo),
            chat("chat-permissions", "Capture permissions", claudeCode, minutes: 5 * 60, in: folderFovea),
            chat("chat-agent-routing", "Agent routing", codex, minutes: 9 * 60, in: folderFovea),
            chat("chat-qa-layout", "Quick Answer layout", claudeCode, minutes: 11 * 60, in: folderFovea),
            chat("chat-onboarding", "Onboarding polish", cursor, minutes: 14 * 60, in: folderFovea),
            chat("chat-model-routing", "Model routing", chatGPT, minutes: 17 * 60, in: folderFuturo),
            chat("chat-capture-flow", "Capture flow", chatGPT, minutes: 20 * 60, in: folderFovea),
            chat("chat-marketing", "Marketing review", cursor, minutes: 23 * 60, in: folderFuturo),
            // Older, so search finds more than the recent grid shows.
            chat("chat-routing-benchmarks", "Model routing benchmarks", codex, minutes: 27 * 60, in: folderFuturo),
            chat("chat-routing-tests", "Routing intent tests", codex, minutes: 3 * 24 * 60, in: folderNewProject),
        ]
    }

    /// What searching "routing" in Codex finds, in order.
    public static func chatSearchResults(now: Date = Date()) -> [ChatRoute] {
        chatCatalog(now: now).filter { $0.destination == codex && $0.chatName.lowercased().contains("routing") }
    }

    public static var chatRouteMenu: ChatRouteMenu { chatRouteMenu(now: Date()) }

    public static func chatRouteMenu(now: Date) -> ChatRouteMenu {
        ChatRouteMenu(
            recommended: ChatRoute(id: "chat-fovea", kind: .recommended, destination: claudeCode, chatName: "Fovea",
                                   lastActiveAt: nil, context: folderFovea),
            original: nil,
            recent: chatCatalog(now: now),
            new: ChatRoute.newChat(in: claudeCode),
            destinations: destinationChoices)
    }

    /// Four tasks, one per state, so the list shows its full vocabulary.
    public static func agentTasks(now: Date = Date()) -> [AgentTask] {
        [
            AgentTask(id: "task-onboarding", title: "Redesign onboarding empty state", state: .working,
                      destination: claudeCode, chatName: "Fovea", activity: "Editing the empty state view",
                      updatedAt: now.addingTimeInterval(-40), captureId: "cap-navbar"),
            AgentTask(id: "task-sidebar", title: "Settings sidebar spacing", state: .needsYou,
                      destination: cursor, chatName: "Dictionary polish", activity: "Choose a spacing option",
                      updatedAt: now.addingTimeInterval(-190), captureId: "cap-figma"),
            AgentTask(id: "task-prisma", title: "Prisma schema from table", state: .complete,
                      destination: codex, chatName: "Schema", activity: "Ready to review",
                      updatedAt: now.addingTimeInterval(-600), captureId: "cap-prisma"),
            AgentTask(id: "task-nil-check", title: "Nil check before the cast", state: .failed,
                      destination: claudeCode, chatName: "Fovea", activity: "Build failed · 2 errors",
                      updatedAt: now.addingTimeInterval(-3_400), captureId: "cap-error"),
        ]
    }

    /// Extra tasks for the overflow/scroll variant (seven in all against five visible).
    public static func moreAgentTasks(now: Date = Date()) -> [AgentTask] {
        [
            AgentTask(id: "task-changelog", title: "Changelog entry for the build", state: .working,
                      destination: codex, chatName: "Release", activity: "Running tests",
                      updatedAt: now.addingTimeInterval(-900)),
            AgentTask(id: "task-alt-text", title: "Alt text for the lion image", state: .complete,
                      destination: claudeCode, chatName: "Fovea", activity: "Ready to review",
                      updatedAt: now.addingTimeInterval(-1_500)),
            AgentTask(id: "task-launch", title: "Launch copy review", state: .working,
                      destination: chatGPT, chatName: "Launch copy review", activity: "Drafting the hero copy",
                      updatedAt: now.addingTimeInterval(-2_100)),
        ]
    }

    /// The task Send just created, for the list-after-send scenario.
    public static func sentTask(now: Date = Date()) -> AgentTask {
        AgentTask(id: "task-sent", title: "Make sure the empty state explains", state: .working,
                  destination: claudeCode, chatName: "Fovea", activity: "Reading the request",
                  updatedAt: now, captureId: "cap-task-sent")
    }

    public static let quickAnswerQuestion = "What does retention mean in this context?"
    public static let quickAnswerShort =
        "Retention is the percentage of users who continue using a product over time. Here, it shows whether the redesigned onboarding helps new users return after their first session."
    public static let quickAnswerFollowUp = "How is it usually measured?"
    public static let quickAnswerFollowUpAnswer =
        "Pick a cohort by signup week, then count how many are still active on day 1, day 7 and day 30. Report each as a share of the original cohort so cohorts of different sizes compare cleanly."
    /// Earlier turns of a long session, so the bookmark rail has questions to index.
    public static let quickAnswerMoreTurns: [QuickAnswerTurn] = [
        QuickAnswerTurn(question: "Which cohort should we start with?",
                        answer: "The signup week after the onboarding change ships, against the week before it. Two cohorts show a direction; four make it credible."),
        QuickAnswerTurn(question: "Is 40% at day 7 realistic for us?",
                        answer: "For a tool people open daily, yes. The current build sits near 31%, so the redesign needs to move about nine points, which is a lot for one change."),
        QuickAnswerTurn(question: "What would make the number look better than it is?",
                        answer: "Counting all users instead of signup cohorts, or counting an open as active. Fix the definition before the redesign ships so both periods compare."),
    ]
    public static let quickAnswerLong = """
        Retention is the share of users who keep coming back after they first try a product. It is the single clearest signal that something is worth using, because it strips out the effect of marketing and novelty.

        In this plan it appears next to weekly active users and conversion, and it is the metric the onboarding redesign is meant to move. A better first session should show up as a higher share of users returning in week two.

        How to read it:
        • Day-1 retention says whether the first session made sense.
        • Day-7 retention says whether the product found a place in the week.
        • Day-30 retention says whether it became a habit.

        A common target for a productivity tool is 40% at day 7 and 25% at day 30, measured on signup cohorts rather than on all users, so that growth does not flatter the number.

        If you only track one of these, track day 7. It responds to onboarding changes within a couple of weeks and is stable enough to compare across cohorts.
        """
}
