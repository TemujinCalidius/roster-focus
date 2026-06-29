import XCTest
@testable import RosterFocusCore

private struct TestEvent: EventLike {
    let title: String
    let start: TimeInterval
    let end: TimeInterval
}

final class DeciderTests: XCTestCase {
    let now: TimeInterval = 1_000_000

    private func active(_ title: String, from: TimeInterval, to: TimeInterval) -> TestEvent {
        TestEvent(title: title, start: now + from, end: now + to)
    }

    private let rules: [Rule] = [
        Rule(calendar: "On-Call", focus: "DND", onShortcut: "DND On", offShortcut: "DND Off"),
        Rule(calendar: "Work", keyword: "night", focus: "Sleep",
             onShortcut: "Sleep On", offShortcut: "Sleep Off"),
        Rule(calendar: "Work", focus: "Work",
             onShortcut: "Work On", offShortcut: "Work Off", leadMinutes: 5),
    ]

    private func pick(_ events: [String: [EventLike]]) -> String {
        Decider.decide(rules: rules, eventsByCalendar: events, now: now).focus
    }

    func testGenericWorkShift() {
        XCTAssertEqual(pick(["Work": [active("Day shift", from: -3600, to: 3600)]]), "Work")
    }

    func testPriorityOnCallWins() {
        let e: [String: [EventLike]] = [
            "On-Call": [active("oncall", from: -10, to: 10)],
            "Work": [active("Day", from: -10, to: 10)],
        ]
        XCTAssertEqual(pick(e), "DND")
    }

    func testKeywordRuleBeatsGenericWhenListedFirst() {
        // "night" rule is listed before the generic Work rule, so a night shift → Sleep.
        XCTAssertEqual(pick(["Work": [active("Night shift", from: -10, to: 10)]]), "Sleep")
    }

    func testKeywordNonMatchFallsThroughToGeneric() {
        XCTAssertEqual(pick(["Work": [active("Day shift", from: -10, to: 10)]]), "Work")
    }

    func testKeywordIsCaseInsensitiveSubstring() {
        XCTAssertEqual(pick(["Work": [active("Overnight NIGHT cover", from: -10, to: 10)]]), "Sleep")
    }

    func testNothingActive() {
        XCTAssertEqual(pick(["Work": [active("future", from: 3600, to: 7200)]]), "")
    }

    func testLeadMinutesActivatesEarly() {
        // Work rule has lead 5m; event starts in 3 min → already active.
        XCTAssertEqual(pick(["Work": [active("Day", from: 180, to: 3600)]]), "Work")
    }

    func testBeyondLeadNotYetActive() {
        // Event starts in 10 min, lead only 5m → not active.
        XCTAssertEqual(pick(["Work": [active("Day", from: 600, to: 3600)]]), "")
    }

    func testTrailKeepsActiveAfterEnd() {
        let r = [Rule(calendar: "Work", focus: "Work",
                      onShortcut: "On", offShortcut: "Off", trailMinutes: 10)]
        // Event ended 5 min ago; trail 10m → still active.
        let e: [String: [EventLike]] = ["Work": [TestEvent(title: "x", start: now - 3600, end: now - 300)]]
        XCTAssertEqual(Decider.decide(rules: r, eventsByCalendar: e, now: now).focus, "Work")
    }

    func testBoundaryInclusive() {
        // now exactly equals event end → still active (inclusive).
        let r = [Rule(calendar: "Work", focus: "Work", onShortcut: "On", offShortcut: "Off")]
        let e: [String: [EventLike]] = ["Work": [TestEvent(title: "x", start: now - 100, end: now)]]
        XCTAssertEqual(Decider.decide(rules: r, eventsByCalendar: e, now: now).focus, "Work")
    }
}
