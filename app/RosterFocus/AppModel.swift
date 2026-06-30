import SwiftUI
import EventKit
import RosterFocusCore

/// Single source of UI truth; owns the Scheduler and exposes everything the menu
/// and wizard need. Lives for the app's lifetime.
@MainActor
final class AppModel: ObservableObject {
    @Published var enabled: Bool
    @Published var currentFocus: String = FocusStateFile.read()
    @Published var lastAction: String = ""
    @Published var lastError: String?
    @Published var calendarAuthorized: Bool = false
    @Published var calendars: [String] = []
    @Published var availableShortcuts: [String] = []
    @Published var rules: [Rule] = []
    @Published var rulesDirty: Bool = false
    @Published var loginItemEnabled: Bool = LoginItem.isEnabled

    private var savedSnapshot: [Rule] = []
    private let eventKit = EventKitService()
    private let shortcuts = ShortcutsService()
    private lazy var scheduler = Scheduler(eventKit: eventKit, shortcuts: shortcuts)
    private let enabledKey = "RosterFocusEnabled"

    init() {
        enabled = UserDefaults.standard.bool(forKey: enabledKey)
        scheduler.onStatus = { [weak self] s in
            self?.currentFocus = s.currentFocus
            self?.lastAction = s.lastAction
            self?.lastError = s.lastError
        }
        refreshAuthorization()
        loadRules()
        if enabled { scheduler.start() }
    }

    // MARK: Calendar access
    func refreshAuthorization() {
        calendarAuthorized = eventKit.authorizationStatus() == .fullAccess
        if calendarAuthorized { refreshCalendars() }
    }

    func requestCalendarAccess() async {
        let ok = await eventKit.requestAccess()
        calendarAuthorized = ok
        if ok { refreshCalendars() }
    }

    func refreshCalendars() { calendars = eventKit.allCalendarTitles() }

    func refreshShortcuts() {
        Task { availableShortcuts = (await shortcuts.list()).map { $0.sorted() } ?? [] }
    }

    func refreshLoginItem() { loginItemEnabled = LoginItem.isEnabled }

    func refreshCurrentFocus() { currentFocus = FocusStateFile.read() }

    // MARK: Rules
    func loadRules() {
        rules = ConfigStore.loadOrEmpty().rules
        savedSnapshot = rules
        rulesDirty = false
    }

    func saveRules() {
        do {
            try ConfigStore.save(Config(rules: rules))
            savedSnapshot = rules
            rulesDirty = false
            lastError = nil
            lastAction = "Rules saved"
        } catch {
            lastError = "Could not save rules: \(error.localizedDescription)"
        }
    }

    /// Recompute the unsaved-changes flag (call on any edit to model.rules).
    func markRulesChanged() { rulesDirty = (rules != savedSnapshot) }

    func addRule() {
        rules.append(Rule(calendar: calendars.first ?? "Work",
                          focus: "Work",
                          onShortcut: "Work Focus On",
                          offShortcut: "Work Focus Off"))
        markRulesChanged()
    }

    func removeRule(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        markRulesChanged()
    }

    // MARK: Run control
    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: enabledKey)
        if on { scheduler.start() } else { scheduler.stop() }
    }

    /// Evaluate now. Saves unsaved rule edits first so "Check Now" tests what's on screen.
    func checkNow() {
        if rulesDirty { saveRules() }
        Task { await scheduler.tick() }
    }

    // MARK: Login item
    func setLoginItem(_ on: Bool) {
        _ = on ? LoginItem.register() : LoginItem.unregister()
        loginItemEnabled = LoginItem.isEnabled
    }
}
