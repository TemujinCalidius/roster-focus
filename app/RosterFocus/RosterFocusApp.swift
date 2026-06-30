import SwiftUI

@main
struct RosterFocusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("RosterFocus", systemImage: "calendar.badge.clock") {
            MenuBarContent(model: model)
        }

        Window("RosterFocus Setup", id: "setup") {
            SetupWizardView(model: model)
                .frame(minWidth: 560, minHeight: 460)
        }
        .windowResizability(.contentSize)
    }
}
