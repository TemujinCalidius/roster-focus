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
    @Published var loginItemEnabled: Bool = LoginItem.isEnabled

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
        availableShortcuts = shortcuts.list().map { $0.sorted() } ?? []
    }

    // MARK: Rules
    func loadRules() { rules = ConfigStore.loadOrEmpty().rules }

    func saveRules() { try? ConfigStore.save(Config(rules: rules)) }

    func addRule() {
        rules.append(Rule(calendar: calendars.first ?? "Work",
                          focus: "Work",
                          onShortcut: "Work Focus On",
                          offShortcut: "Work Focus Off"))
    }

    func removeRule(_ rule: Rule) { rules.removeAll { $0.id == rule.id } }

    // MARK: Run control
    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: enabledKey)
        if on { scheduler.start() } else { scheduler.stop() }
    }

    func checkNow() { scheduler.tick() }

    // MARK: Login item
    func setLoginItem(_ on: Bool) {
        _ = on ? LoginItem.register() : LoginItem.unregister()
        loginItemEnabled = LoginItem.isEnabled
    }
}
