import Foundation
import EventKit

/// Wraps EKEventStore: permission, calendar titles, and a now ±24h event query.
public final class EventKitService {
    private let store = EKEventStore()
    public init() {}

    public func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Triggers the native Calendar prompt (GUI session only). macOS 14+ API.
    public func requestAccess() async -> Bool {
        do { return try await store.requestFullAccessToEvents() }
        catch { return false }
    }

    public func allCalendarTitles() -> [String] {
        Array(Set(store.calendars(for: .event).map { $0.title })).sorted()
    }

    /// Events (as EventLike) grouped by calendar title for the named calendars,
    /// in a now ±24h window. Returns nil if NONE of the named calendars exist
    /// (fail-safe — mirrors the Python tool so we don't blindly turn everything off).
    public func eventsByCalendar(names: Set<String>) -> [String: [EventLike]]? {
        let cals = store.calendars(for: .event).filter { names.contains($0.title) }
        if cals.isEmpty { return nil }

        let now = Date()
        let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-24 * 3600),
                                            end: now.addingTimeInterval(24 * 3600),
                                            calendars: cals)
        var out: [String: [EventLike]] = [:]
        for cal in cals { out[cal.title] = [] }
        for ev in store.events(matching: pred) {
            let title = ev.calendar?.title ?? ""
            out[title, default: []].append(EKEventAdapter(ev))
        }
        return out
    }
}

private struct EKEventAdapter: EventLike {
    let title: String
    let start: TimeInterval
    let end: TimeInterval
    init(_ ev: EKEvent) {
        title = ev.title ?? ""
        start = ev.startDate?.timeIntervalSince1970 ?? 0
        end = ev.endDate?.timeIntervalSince1970 ?? 0
    }
}
