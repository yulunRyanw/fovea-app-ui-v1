import XCTest
@testable import FoveaCore

final class DetailCardGeometryTests: XCTestCase {
    let spec = DetailCardGeometry.Spec()

    func testDesignCanvas() {
        let f = DetailCardGeometry.frame(canvas: CGSize(width: 1180, height: 819), topInset: 52, spec: spec)
        XCTAssertEqual(f.width, 732, "62% of the width")
        XCTAssertEqual(f.height, 400, "48% would be 368; the minimum wins")
        XCTAssertEqual(f.midX, 590, accuracy: 1)
        XCTAssertEqual(f.midY, 52 + (819 - 52) / 2, accuracy: 1)
    }

    func testMaximumsOnLargeCanvas() {
        let f = DetailCardGeometry.frame(canvas: CGSize(width: 2000, height: 1600), topInset: 52, spec: spec)
        XCTAssertEqual(f.width, 1120)
        XCTAssertEqual(f.height, 680)
    }

    func testMinimumSizeYieldsToSmallCanvas() {
        let f = DetailCardGeometry.frame(canvas: CGSize(width: 700, height: 500), topInset: 52, spec: spec)
        XCTAssertEqual(f.width, 640, "the minimum, still inside the margins")
        XCTAssertEqual(f.height, 400)
        XCTAssertGreaterThanOrEqual(f.minX, spec.margin)
        XCTAssertLessThanOrEqual(f.maxX, 700 - spec.margin)
    }

    func testZoomAnchor() {
        let card = CGRect(x: 100, y: 100, width: 800, height: 400)
        XCTAssertEqual(DetailCardGeometry.zoomAnchor(origin: nil, card: card), CGPoint(x: 0.5, y: 0.5))
        let anchor = DetailCardGeometry.zoomAnchor(origin: CGRect(x: 0, y: 0, width: 100, height: 100), card: card)
        XCTAssertEqual(anchor, CGPoint(x: 0, y: 0), "clamped to the card")
        let inside = DetailCardGeometry.zoomAnchor(origin: CGRect(x: 480, y: 280, width: 40, height: 40), card: card)
        XCTAssertEqual(inside.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(inside.y, 0.5, accuracy: 0.001)
    }
}

final class DetailMetadataTests: XCTestCase {
    func testDetailLabelFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10, minute: 24))!
        XCTAssertEqual(DateGrouping.detailLabel(date, calendar: calendar), "Sep 7, 2026 · 10:24 AM")
    }

    func testCaptureDecodesWithoutNewKeys() throws {
        let json = """
        {"id":"x","intent":"voice_only","createdAt":0,"semanticAnchors":["a"],"referents":[],"deliveryStatus":"sent"}
        """.data(using: .utf8)!
        let c = try JSONDecoder().decode(Capture.self, from: json)
        XCTAssertEqual(c.tags, [])
        XCTAssertNil(c.chatName)
        XCTAssertEqual(c.deliveryStatus, .sent)
    }

    func testCaptureRoundTripsTags() throws {
        let c = Capture(id: "y", intent: .quickAnswer, createdAt: Date(timeIntervalSince1970: 100),
                        question: "q", answer: "a", tags: ["Product Design", "Navigation"], chatName: "Fovea")
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(Capture.self, from: data)
        XCTAssertEqual(back.tags, ["Product Design", "Navigation"])
        XCTAssertEqual(back.chatName, "Fovea")
    }

    func testFixturesCarryDetailMetadata() {
        let caps = Fixtures.captures()
        XCTAssertTrue(caps.allSatisfy { !$0.tags.isEmpty && $0.chatName != nil })
        XCTAssertEqual(caps.first { $0.id == "cap-desk" }?.referents.count, 6)
        XCTAssertEqual(caps.first { $0.id == "cap-mountain" }?.referents.first?.id, "ref-mountain", "hero stays first")
    }
}
