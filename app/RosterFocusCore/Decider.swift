import Foundation

/// Minimal view of a calendar event, so the decision logic can be unit-tested
/// without EventKit. Times are seconds since 1970.
public protocol EventLike {
    var title: String { get }
    var start: TimeInterval { get }
    var end: TimeInterval { get }
}

/// Pure port of the Python `decide()` / `rule_active()`. No I/O — fully testable.
public enum Decider {
    /// First rule (in list order) with an active event wins. Returns ("", nil) if none.
    public static func decide(rules: [Rule],
                              eventsByCalendar: [String: [EventLike]],
                              now: TimeInterval) -> (focus: String, rule: Rule?) {
        for rule in rules where ruleActive(rule, eventsByCalendar: eventsByCalendar, now: now) {
            return (rule.focus, rule)
        }
        return ("", nil)
    }

    /// True if an event in the rule's calendar (matching its keyword) overlaps `now`,
    /// extended by lead/trail. Boundaries inclusive, matching the Python `<= now <=`.
    public static func ruleActive(_ rule: Rule,
                                  eventsByCalendar: [String: [EventLike]],
                                  now: TimeInterval) -> Bool {
        let events = eventsByCalendar[rule.calendar] ?? []
        let kw = rule.normalizedKeyword
        for ev in events {
            if !kw.isEmpty && !ev.title.lowercased().contains(kw) { continue }
            let s = ev.start - Double(rule.leadMinutes) * 60
            let e = ev.end + Double(rule.trailMinutes) * 60
            if s <= now && now <= e { return true }
        }
        return false
    }
}
