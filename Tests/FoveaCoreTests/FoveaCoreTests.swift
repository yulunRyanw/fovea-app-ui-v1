import XCTest
import ImageIO
@testable import FoveaCore

final class CaptureAnchorsTests: XCTestCase {
    func testExtractsProperNounsIdentifiersAndLongWords() {
        XCTAssertEqual(CaptureAnchors.extract(from: "Make the Prisma schema match users.py please"),
                       ["Prisma", "schema", "match", "users.py"])
    }

    func testStopsAtFiveAndSkipsStopWords() {
        let anchors = CaptureAnchors.extract(from: "Please compare these designs against the Linear roadmap, then update tokens.swift and Figma")
        XCTAssertEqual(anchors.count, 5)
        XCTAssertFalse(anchors.contains("these"))
    }

    func testEmptyTranscript() {
        XCTAssertEqual(CaptureAnchors.extract(from: ""), [])
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
        s.interfaceLanguage = "ja"
        s.screenshotRetentionDays = nil
        try await store.save(s, changed: "interfaceLanguage")
        XCTAssertEqual(store.load(), s)
    }

    func testDecodesMissingKeysWithDefaults() throws {
        let data = #"{"interfaceLanguage":"de"}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertEqual(s.interfaceLanguage, "de")
        XCTAssertEqual(s.launchAtLogin, UserSettings.default.launchAtLogin)
    }

    /// Settings written in the feed era carry `accentColor`, `theme` and `feedFonts`.
    /// Those blobs must still load, with the unknown keys ignored, not throw.
    func testFeedEraBlobStillLoads() throws {
        let data = #"{"accentColor":"cobalt","theme":"roast","feedFonts":["fraunces"],"launchAtLogin":false}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertFalse(s.launchAtLogin)
        XCTAssertEqual(s.interfaceLanguage, UserSettings.default.interfaceLanguage)
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
        XCTAssertEqual(SettingsRoute.parse("settings/account/app"), SettingsRoute(.app))
        XCTAssertEqual(SettingsRoute.parse("plan/billing"), SettingsRoute(.billing))
        XCTAssertNil(SettingsRoute.parse("settings/general"))
        XCTAssertEqual(AppRoute.parse("settings/connectors/cursor"), .connectorDetail("cursor"))
        XCTAssertEqual(AppRoute.parse("settings/connectors/available"), .settings(SettingsRoute(.available)))
        XCTAssertEqual(AppRoute.parse("captures/cap-navbar"), .captureDetail("cap-navbar"))
    }

    func testNavigationIsExact() {
        // The seven categories in the spec, and no eighth.
        XCTAssertEqual(SettingsCategory.allCases.map(\.title),
                       ["Account", "Eye Tracking", "Voice & Capture", "Dictionary",
                        "Shortcuts", "Connectors", "Usage & Plan"])
        XCTAssertEqual(SettingsCategory.plan.children.map(\.title), ["Usage", "Plan", "Billing"])
        XCTAssertEqual(SettingsCategory.account.children.map(\.title), ["Profile", "App", "Data"])
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
