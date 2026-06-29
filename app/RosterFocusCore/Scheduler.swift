import Foundation

/// Runs the decide→toggle loop on a timer. Pure orchestration; the same algorithm
/// as the Python `main()`: act only on change, fail-loud (don't persist on failure),
/// fail-safe (do nothing if no configured calendar is readable).
@MainActor
public final class Scheduler {
    public struct Status {
        public var currentFocus: String
        public var lastAction: String
        public var lastError: String?
    }

    private let eventKit: EventKitService
    private let shortcuts: ShortcutsService
    private let interval: TimeInterval
    private var timer: Timer?

    /// Called after each tick that changes anything (or fails), for the UI to observe.
    public var onStatus: ((Status) -> Void)?

    public init(eventKit: EventKitService = EventKitService(),
                shortcuts: ShortcutsService = ShortcutsService(),
                interval: TimeInterval = 60) {
        self.eventKit = eventKit
        self.shortcuts = shortcuts
        self.interval = interval
    }

    public var isRunning: Bool { timer != nil }

    public func start() {
        stop()
        tick()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// One evaluation. Safe to call manually (e.g. a "Check now" menu item).
    public func tick() {
        let rules = ConfigStore.loadOrEmpty().rules
        guard !rules.isEmpty else { return }

        let names = Set(rules.map { $0.calendar })
        guard let eventsByCal = eventKit.eventsByCalendar(names: names) else {
            return  // fail-safe: can't read any configured calendar → do nothing
        }

        let now = Date().timeIntervalSince1970
        let (desired, desiredRule) = Decider.decide(rules: rules, eventsByCalendar: eventsByCal, now: now)
        let current = FocusStateFile.read()
        guard current != desired else { return }   // act only on change

        let prevRule = rules.first { $0.focus == current }
        let ok: Bool
        if let dr = desiredRule {
            if let pr = prevRule { _ = shortcuts.runShortcut(pr.offShortcut) }  // best-effort
            ok = shortcuts.runShortcut(dr.onShortcut)                            // must succeed
        } else if let pr = prevRule {
            ok = shortcuts.runShortcut(pr.offShortcut)                           // turning off
        } else {
            ok = true
        }

        guard ok else {
            // Fail-loud: don't record the change, so the next tick retries.
            onStatus?(Status(currentFocus: current,
                             lastAction: "focus change failed — will retry",
                             lastError: "a Shortcut failed to run"))
            return
        }

        try? FocusStateFile.write(desired)
        let label = desired.isEmpty ? "none" : desired
        onStatus?(Status(currentFocus: desired, lastAction: "focus → \(label)", lastError: nil))
    }
}
