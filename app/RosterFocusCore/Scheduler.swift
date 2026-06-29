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
    private var ticking = false

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
        Task { @MainActor in await self.tick() }
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// One evaluation. Safe to call manually (e.g. a "Check Now" menu item).
    /// Re-entrancy guarded so a slow tick can't overlap the next.
    public func tick() async {
        guard !ticking else { return }
        ticking = true
        defer { ticking = false }

        // Distinguish "no config yet" (silent) from "config present but invalid" (report).
        let rules: [Rule]
        if FileManager.default.fileExists(atPath: ConfigStore.configURL.path) {
            do {
                rules = try ConfigStore.load().rules
            } catch {
                onStatus?(Status(currentFocus: FocusStateFile.read(),
                                 lastAction: "config error",
                                 lastError: "config.json couldn't be read: \(error.localizedDescription)"))
                return
            }
        } else {
            return
        }
        guard !rules.isEmpty else { return }

        let names = Set(rules.map { $0.calendar })
        guard let eventsByCal = eventKit.eventsByCalendar(names: names) else {
            return  // fail-safe: can't read any configured calendar → do nothing
        }

        let now = Date().timeIntervalSince1970
        let (desired, desiredRule) = Decider.decide(rules: rules, eventsByCalendar: eventsByCal, now: now)
        let current = FocusStateFile.read()
        guard current != desired else { return }   // act only on change

        // Mirror the Python `if current` guard: an empty current means no previous rule.
        let prevRule = current.isEmpty ? nil : rules.first { $0.focus == current }
        let known = await shortcuts.list()         // fetch once per change

        let ok: Bool
        if let dr = desiredRule {
            if let pr = prevRule { _ = await shortcuts.runShortcut(pr.offShortcut, known: known) }  // best-effort
            ok = await shortcuts.runShortcut(dr.onShortcut, known: known)                           // must succeed
        } else if let pr = prevRule {
            ok = await shortcuts.runShortcut(pr.offShortcut, known: known)                          // turning off
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
