import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.currentFocus.isEmpty ? "Focus: none" : "Focus: \(model.currentFocus)")
            .onAppear {
                // Keep the indicator honest even when the CLI made the last change
                // or the app is disabled (the scheduler isn't running then).
                model.refreshCurrentFocus()
                model.refreshLoginItem()
            }
        if !model.lastAction.isEmpty {
            Text(model.lastAction).font(.caption).foregroundStyle(.secondary)
        }
        if let err = model.lastError {
            Text("⚠︎ \(err)").font(.caption).foregroundStyle(.red)
        }

        Divider()

        Toggle("Enabled", isOn: Binding(
            get: { model.enabled },
            set: { model.setEnabled($0) }
        ))
        Button("Check Now") { model.checkNow() }

        Divider()

        Button("Set Up / Edit Rules…") {
            openWindow(id: "setup")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit RosterFocus") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
