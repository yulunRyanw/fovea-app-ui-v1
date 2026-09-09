import XCTest
import ImageIO
@testable import FoveaCore

final class SemanticFingerprintTests: XCTestCase {
    func testSameIdSameComposition() {
        let a = SemanticFingerprint.make(captureId: "cap-navbar", anchors: ["navbar", "padding", "hover state"])
        let b = SemanticFingerprint.make(captureId: "cap-navbar", anchors: ["navbar", "padding", "hover state"])
        XCTAssertEqual(a, b)
    }

    func testDifferentIdsVary() {
        let ids = ["cap-navbar", "cap-prisma", "cap-rewrite", "cap-error", "cap-update", "cap-meeting"]
        let comps = ids.map { SemanticFingerprint.make(captureId: $0, anchors: ["one", "two", "three"]) }
        XCTAssertGreaterThan(Set(comps).count, 1)
    }

    /// The emphasis rule is now positional-free, so assert the invariants that must
    /// hold for every composition rather than "index 0 is the loud one".
    func testEmphasisInvariants() {
        let ids = ["cap-error", "cap-navbar", "cap-prisma", "cap-rewrite", "cap-update",
                   "cap-meeting", "cap-toast", "cap-script", "cap-tokens", "cap-standup"]
        for id in ids {
            for words in [["error"],
                          ["error", "nil check"],
                          ["error", "nil check", "function"],
                          ["error", "nil check", "function", "cast"],
                          ["error", "nil check", "function", "cast", "retry"]] {
                let f = SemanticFingerprint.make(captureId: id, anchors: words)
                let primaries = f.anchors.filter(\.isPrimary)
                let quiet = f.anchors.filter { !$0.isPrimary }

                XCTAssertEqual(f.anchors.filter { $0.emphasis == .lead }.count, 1, "\(id) \(words.count)")
                XCTAssertTrue((1...2).contains(primaries.count), "\(id) \(words.count)")
                // A second highlight only on cards with room for it.
                if words.count < 4 { XCTAssertEqual(primaries.count, 1, "\(id) \(words.count)") }

                for a in f.anchors {
                    XCTAssertGreaterThanOrEqual(a.size, SemanticFingerprint.minSize)
                    XCTAssertLessThanOrEqual(a.size, SemanticFingerprint.maxSize)
                }
                for p in primaries { XCTAssertGreaterThanOrEqual(p.size, 22, "\(id) \(words.count)") }
                // Every quiet word stays smaller than every highlight.
                for q in quiet {
                    XCTAssertLessThanOrEqual(q.size, 19, "\(id) \(words.count)")
                    for p in primaries { XCTAssertLessThan(q.size, p.size, "\(id) \(words.count)") }
                }
                // The two highlights never sit adjacent.
                if primaries.count == 2 {
                    let idx = f.anchors.enumerated().filter { $0.element.isPrimary }.map(\.offset)
                    XCTAssertGreaterThanOrEqual(abs(idx[0] - idx[1]), 2, "\(id) \(words.count)")
                }
                XCTAssertTrue((1.05...1.36).contains(f.aspect))
            }
        }
    }

    /// The lead is drawn from the first three words, so across many ids it must
    /// actually land somewhere other than index 0 — otherwise the rule is inert.
    func testLeadIsNotAlwaysTheFirstWord() {
        let leads = (0..<80).map { i -> Int in
            let f = SemanticFingerprint.make(captureId: "cap-\(i)", anchors: ["one", "two", "three", "four"])
            return f.anchors.firstIndex { $0.emphasis == .lead } ?? -1
        }
        XCTAssertGreaterThan(Set(leads).count, 1, "the lead never moves off its default position")
        XCTAssertTrue(leads.allSatisfy { (0...2).contains($0) }, "lead escaped the first three words")
    }

    func testFallsBackToTranscriptAnchors() {
        let f = SemanticFingerprint.make(captureId: "x", anchors: [], transcript: "Make the Prisma schema match users.py please")
        XCTAssertEqual(f.anchors.map(\.text), ["Prisma", "schema", "match", "users.py"])
    }
}

final class JustifiedRowsTests: XCTestCase {
    let items = Fixtures.captures().map { c in
        JustifiedRows.Item(id: c.id, aspect: c.heroReferent?.aspect
                           ?? SemanticFingerprint.make(captureId: c.id, anchors: c.semanticAnchors).aspect)
    }

    func testRowsFillWidthAndRespectCap() {
        for (width, cap) in [(CGFloat(940), 4), (CGFloat(760), 3)] {
            let rows = JustifiedRows.layout(items, width: width, targetHeight: 150, spacing: 20, maxPerRow: cap)
            XCTAssertFalse(rows.isEmpty)
            for row in rows {
                XCTAssertLessThanOrEqual(row.items.count, cap)
                let total = row.items.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(row.items.count - 1) * 20
                if row.justified { XCTAssertEqual(total, width, accuracy: 1) }
                else { XCTAssertLessThanOrEqual(total, width + 1) }
            }
        }
    }

    func testPreservesOrder() {
        let rows = JustifiedRows.layout(items, width: 940, targetHeight: 150, spacing: 20, maxPerRow: 4)
        XCTAssertEqual(rows.flatMap { $0.items.map(\.id) }, items.map(\.id))
    }

    func testFixedPerRow() {
        for n in 2...6 {
            let rows = JustifiedRows.layout(items, width: 940, targetHeight: 130, spacing: 22, maxPerRow: 5, fixedPerRow: n)
            XCTAssertEqual(rows.count, Int((Double(items.count) / Double(n)).rounded(.up)))
            for (i, row) in rows.enumerated() {
                let total = row.items.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(row.items.count - 1) * 22
                if i < rows.count - 1 || items.count % n == 0 {
                    XCTAssertEqual(row.items.count, n)
                    XCTAssertTrue(row.justified)
                    XCTAssertEqual(total, 940, accuracy: 1)
                } else {
                    XCTAssertEqual(row.items.count, items.count % n)
                    XCTAssertLessThanOrEqual(total, 941)
                }
            }
            XCTAssertEqual(rows.flatMap { $0.items.map(\.id) }, items.map(\.id))
        }
    }

    func testEmptyAndZeroWidth() {
        XCTAssertTrue(JustifiedRows.layout([], width: 900, targetHeight: 150, spacing: 20, maxPerRow: 4).isEmpty)
        XCTAssertTrue(JustifiedRows.layout(items, width: 0, targetHeight: 150, spacing: 20, maxPerRow: 4).isEmpty)
    }
}

final class CaptureSearchTests: XCTestCase {
    let captures = Fixtures.captures()

    func testEmptyQueryReturnsAll() {
        XCTAssertEqual(CaptureSearch.filter(captures, query: "  ").count, captures.count)
    }

    func testMatchesAnchorsFilenamesAndAnswers() {
        XCTAssertEqual(CaptureSearch.filter(captures, query: "PRISMA").map(\.id), ["cap-prisma"])
        XCTAssertEqual(CaptureSearch.filter(captures, query: "design_spec").map(\.id), ["cap-spec"])
        XCTAssertTrue(CaptureSearch.filter(captures, query: "section labels").map(\.id).contains("cap-update"))
        XCTAssertTrue(CaptureSearch.filter(captures, query: "ampere").map(\.id).contains("cap-equation"))
    }

    func testNoResults() {
        XCTAssertTrue(CaptureSearch.filter(captures, query: "zzzz-nothing").isEmpty)
    }
}

final class DateGroupingTests: XCTestCase {
    func testTodayYesterdayOlder() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = cal.date(from: DateComponents(year: 2024, month: 10, day: 28, hour: 12))!
        let groups = DateGrouping.groups(Fixtures.captures(now: now, calendar: cal), now: now, calendar: cal)
        XCTAssertEqual(groups.map(\.title), ["Today", "Yesterday", "Oct 26, 2024", "Oct 23, 2024", "Oct 16, 2024", "Oct 13, 2024"])
        XCTAssertEqual(groups[0].subtitle, "Oct 28, 2024")
        XCTAssertNil(groups[2].subtitle)
        // Newest first within a day.
        XCTAssertEqual(groups[0].captures.first?.id, "cap-empty-state")
        XCTAssertEqual(DateGrouping.timeLabel(groups[0].captures[0].createdAt, calendar: cal), "11:06 AM")
        for group in groups {
            XCTAssertEqual(group.captures.map(\.createdAt), group.captures.map(\.createdAt).sorted(by: >))
        }
    }
}

final class ShortcutTests: XCTestCase {
    func testDefaultsDoNotConflict() {
        XCTAssertTrue(ShortcutConflicts.detect(ShortcutBindings.defaults.bindings).isEmpty)
    }

    func testDefaultsAreOnTheFunctionKey() {
        let b = ShortcutBindings.defaults.bindings
        XCTAssertEqual(b[.voiceFlow], .functionKey())
        XCTAssertEqual(b[.quickAnswer], .functionKey([.control]))
        XCTAssertTrue(b[.voiceFlow]!.isFunctionKey)
        XCTAssertFalse(KeyBinding(modifiers: [.option], keyCode: 49, keyLabel: "Space").isFunctionKey)
    }

    func testConflictDetected() {
        var b = ShortcutBindings.defaults.bindings
        b[.quickAnswer] = .functionKey()
        let c = ShortcutConflicts.detect(b)
        XCTAssertEqual(c[.quickAnswer], .voiceFlow)
        XCTAssertEqual(c[.voiceFlow], .quickAnswer)
        XCTAssertEqual(ShortcutConflicts.conflict(for: .quickAnswer, candidate: b[.quickAnswer]!, in: ShortcutBindings.defaults.bindings), .voiceFlow)
    }

    func testGlyphOrder() {
        let k = KeyBinding(modifiers: [.command, .shift, .option, .control], keyCode: 0, keyLabel: "A")
        XCTAssertEqual(k.displayGlyphs, ["⌃", "⌥", "⇧", "⌘", "A"])
        XCTAssertEqual(KeyBinding(modifiers: [.option], keyCode: 49, keyLabel: "Space").displayString, "⌥ Space")
        // fn leads its chord, as in the macOS menu bar.
        XCTAssertEqual(ShortcutBindings.defaults.bindings[.voiceFlow]?.displayString, "fn")
        XCTAssertEqual(ShortcutBindings.defaults.bindings[.quickAnswer]?.displayString, "fn ⌃")
    }
}

final class StoreTests: XCTestCase {
    func testUserDefaultsRoundTrip() async throws {
        let suite = "fovea-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsStore<UserSettings>(defaults: defaults, key: "settings")
        XCTAssertNil(store.load())
        var s = UserSettings.default
        s.theme = .canyon
        s.screenshotRetentionDays = nil
        try await store.save(s, changed: "theme")
        XCTAssertEqual(store.load(), s)
    }

    func testDecodesMissingKeysWithDefaults() throws {
        let data = #"{"theme":"roast"}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertEqual(s.theme, .roast)
        XCTAssertEqual(s.launchAtLogin, UserSettings.default.launchAtLogin)
    }

    /// Settings written before the palette change carry `accentColor` with a value
    /// no theme answers to. That blob must still load, not throw.
    func testLegacyAccentColorBlobFallsBackToDefaultTheme() throws {
        let data = #"{"accentColor":"cobalt","launchAtLogin":false}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertEqual(s.theme, .paper)
        XCTAssertFalse(s.launchAtLogin)
    }

    /// And a present-but-unrecognized theme name must not take the decode down either.
    func testUnknownThemeNameFallsBack() throws {
        let data = #"{"theme":"chartreuse"}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertEqual(s.theme, .paper)
    }

    func testFlakyStoreFailsOnceThenSucceeds() async throws {
        let inner = InMemoryStore<UserSettings>()
        let flaky = FlakyStore(wrapping: inner, failingKey: "automaticUpdates")
        do {
            try await flaky.save(.default, changed: "automaticUpdates")
            XCTFail("expected failure")
        } catch {}
        try await flaky.save(.default, changed: "launchAtLogin")
        try await flaky.save(.default, changed: "automaticUpdates")
        XCTAssertEqual(inner.saveCount, 2)
    }
}

final class RouteTests: XCTestCase {
    func testSettingsRouteParsing() {
        XCTAssertEqual(SettingsRoute.parse("settings/dictionary"), SettingsRoute(.learnedWords))
        XCTAssertEqual(SettingsRoute.parse("settings/account/appearance"), SettingsRoute(.appearance))
        XCTAssertEqual(SettingsRoute.parse("plan/billing"), SettingsRoute(.billing))
        XCTAssertNil(SettingsRoute.parse("settings/general"))
        XCTAssertEqual(AppRoute.parse("settings/connectors/cursor"), .connectorDetail("cursor"))
        XCTAssertEqual(AppRoute.parse("settings/connectors/available"), .settings(SettingsRoute(.available)))
        XCTAssertEqual(AppRoute.parse("captures/cap-navbar"), .captureDetail("cap-navbar"))
    }

    func testNavigationIsExact() {
        XCTAssertEqual(SettingsCategory.allCases.map(\.title),
                       ["Account", "Typography", "Eye Tracking", "Voice & Capture", "Dictionary",
                        "Shortcuts", "Connectors", "Usage & Plan"])
        XCTAssertEqual(SettingsCategory.plan.children.map(\.title), ["Usage", "Plan", "Billing"])
        XCTAssertEqual(SettingsCategory.typography.children.map(\.title),
                       ["Highlighted Words", "Everything Else"])
    }

    func testSidebarGroupsCoverEveryCategoryOnce() {
        let listed = SettingsSidebarGroup.allCases.flatMap(\.categories)
        XCTAssertEqual(listed.count, SettingsCategory.allCases.count)
        XCTAssertEqual(Set(listed), Set(SettingsCategory.allCases))
        XCTAssertEqual(SettingsSidebarGroup.allCases.map(\.title), ["Personal", "Capture", "Integrations"])
    }
}

final class FixtureAssetTests: XCTestCase {
    func testBundledImageAspectRatiosMatchFixtures() throws {
        for c in Fixtures.captures() {
            for r in c.referents where r.kind == .image || r.kind == .screenshot {
                guard let path = r.resource else { continue }
                guard let url = FoveaResources.url(path) else {
                    // Missing media is a deliberate fixture state (broken preview) and
                    // screenshots are generated by the app; only photos must exist.
                    XCTAssertTrue(path.hasPrefix("Screens/") || path == "Photos/whiteboard.jpg", "missing \(path)")
                    continue
                }
                let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
                let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
                let w = try XCTUnwrap(props[kCGImagePropertyPixelWidth] as? Double)
                let h = try XCTUnwrap(props[kCGImagePropertyPixelHeight] as? Double)
                XCTAssertEqual(Double(r.aspect), w / h, accuracy: 0.01, path)
            }
        }
    }

    func testFixtureShape() {
        let caps = Fixtures.captures()
        XCTAssertEqual(Set(caps.map(\.id)).count, caps.count)
        XCTAssertTrue(caps.contains { $0.deliveryStatus == .failed })
        XCTAssertTrue(caps.contains { $0.intent == .quickAnswer && $0.answer != nil })
        XCTAssertEqual(Fixtures.dictionary().count, 38)
        XCTAssertEqual(Fixtures.connectors.filter { $0.status == .connected }.count, 2)
        XCTAssertEqual(Fixtures.connectors.filter { $0.status == .available }.count, 3)
        XCTAssertEqual(Fixtures.usage().percent, 52)
    }
}

final class RelativeTimeTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    /// Tue Sep 8 2026, 13:37 PT.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 13, minute: 37))!
    }

    func testShort() {
        let cal = calendar
        func short(minutes: Double) -> String {
            RelativeTime.short(from: now.addingTimeInterval(-minutes * 60), to: now, calendar: cal)
        }
        XCTAssertEqual(short(minutes: 0.5), "now")
        XCTAssertEqual(short(minutes: 12), "12m")
        XCTAssertEqual(short(minutes: 38), "38m")
        XCTAssertEqual(short(minutes: 59), "59m")
        XCTAssertEqual(short(minutes: 60), "1h")
        XCTAssertEqual(short(minutes: 23 * 60), "23h")
        XCTAssertEqual(short(minutes: 27 * 60), "yesterday")
        XCTAssertEqual(short(minutes: 3 * 24 * 60), "Sep 5")
        XCTAssertEqual(short(minutes: 400 * 24 * 60), "Aug 4, 2025")
    }

    func testActivity() {
        let cal = calendar
        XCTAssertEqual(RelativeTime.activity(from: now.addingTimeInterval(-9 * 3600), to: now, calendar: cal), "Active 9h ago")
        XCTAssertEqual(RelativeTime.activity(from: now.addingTimeInterval(-30), to: now, calendar: cal), "Active just now")
        XCTAssertEqual(RelativeTime.activity(from: now.addingTimeInterval(-27 * 3600), to: now, calendar: cal), "yesterday")
        XCTAssertEqual(RelativeTime.activity(from: now.addingTimeInterval(-3 * 86_400), to: now, calendar: cal), "Sep 5")
    }
}

final class FeedFontTests: XCTestCase {
    func testEveryFontHasADistinctFileAndFamily() {
        XCTAssertEqual(Set(FeedFont.allCases.map(\.file)).count, FeedFont.allCases.count)
        XCTAssertEqual(Set(FeedFont.allCases.map(\.family)).count, FeedFont.allCases.count)
    }

    /// Every declared file has to actually be in the resource bundle, or the app
    /// silently renders the system font everywhere.
    func testEveryFontFileIsBundled() {
        for font in FeedFont.allCases {
            XCTAssertNotNil(FoveaResources.url("Fonts/\(font.file)"),
                            "missing bundled font file for \(font.displayName): \(font.file)")
        }
    }

    func testLicenceShipsForEveryFont() {
        // OFL 1.1 requires the notice to travel with the redistributed font.
        let dir = FoveaResources.url("Fonts/")
        XCTAssertNotNil(dir)
        let licences = (try? FileManager.default.contentsOfDirectory(atPath: dir!.path))?
            .filter { $0.hasPrefix("OFL-") } ?? []
        XCTAssertEqual(licences.count, FeedFont.allCases.count)
    }

    func testPoolFallsBackRatherThanReturningNothing() {
        XCTAssertEqual(FeedFont.pool([], role: .display),
                       FeedFont.allCases.filter { $0.role == .display })
        // Only text faces enabled: the display pool borrows them instead of emptying.
        let textOnly: [FeedFont] = [.dmSans, .karla]
        XCTAssertEqual(FeedFont.pool(textOnly, role: .display), textOnly)
        XCTAssertEqual(FeedFont.pool(textOnly, role: .text), textOnly)
    }

    func testFontPickIsDeterministicAndSpreads() {
        let display = FeedFont.allCases.filter { $0.role == .display }
        let text = FeedFont.allCases.filter { $0.role == .text }
        let a = SemanticFingerprint.fontPick(captureId: "cap-navbar", display: display, text: text)
        let b = SemanticFingerprint.fontPick(captureId: "cap-navbar", display: display, text: text)
        XCTAssertEqual(a.display, b.display)
        XCTAssertEqual(a.text, b.text)

        let picks = (0..<120).compactMap {
            SemanticFingerprint.fontPick(captureId: "cap-\($0)", display: display, text: text).display
        }
        XCTAssertEqual(Set(picks).count, display.count, "some display faces never get picked")
    }

    func testSingleWeightFacesAreFlagged() {
        XCTAssertTrue(FeedFont.instrumentSerif.isSingleWeight)
        XCTAssertTrue(FeedFont.specialGothic.isSingleWeight)
        XCTAssertFalse(FeedFont.fraunces.isSingleWeight)
    }

    func testSettingsRoundTripFontSelection() throws {
        var s = UserSettings.default
        s.feedFonts = [.fraunces, .dmSans]
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(UserSettings.self, from: data).feedFonts,
                       [.fraunces, .dmSans])
    }

    /// A blob naming a face that no longer exists must not take the decode down.
    func testUnknownFontIdFallsBack() throws {
        let data = #"{"feedFonts":["fraunces","comic-sans"]}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertEqual(s.feedFonts, UserSettings.default.feedFonts)
    }
}
