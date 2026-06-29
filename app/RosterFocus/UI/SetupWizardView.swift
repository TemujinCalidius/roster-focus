import SwiftUI
import RosterFocusCore

struct SetupWizardView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var step = 0

    private let titles = ["Calendar Access", "Create a Focus", "Add Shortcuts", "Rules", "Enable"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { content.padding(20) }
            Divider()
            footer
        }
        .onAppear {
            step = 0
            model.refreshAuthorization()
            model.refreshShortcuts()
            model.refreshLoginItem()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            ForEach(titles.indices, id: \.self) { i in
                Text("\(i + 1). \(titles[i])")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(i == step ? Color.accentColor.opacity(0.2) : Color.clear))
                    .foregroundStyle(i == step ? Color.accentColor : .secondary)
            }
        }
        .padding(10)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: calendarStep
        case 1: focusStep
        case 2: shortcutsStep
        case 3: RulesEditorView(model: model).frame(minHeight: 300)
        default: enableStep
        }
    }

    private var footer: some View {
        HStack {
            Button("Back") { step -= 1 }.disabled(step == 0)
            Spacer()
            Text("Step \(step + 1) of \(titles.count)").font(.caption).foregroundStyle(.secondary)
            Spacer()
            if step < titles.count - 1 {
                Button("Next") { step += 1 }.keyboardShortcut(.defaultAction)
            } else {
                Button("Done") { dismissWindow(id: "setup") }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }

    // MARK: Steps

    private var calendarStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Calendar access", systemImage: "calendar")
                .font(.title3).bold()
            Text("RosterFocus reads your shift calendar to decide which Focus to turn on. "
                 + "Grant Calendar access so it can see your events.")
            if model.calendarAuthorized {
                Label("Calendar access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Calendars it can see: \(model.calendars.isEmpty ? "—" : model.calendars.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Grant Calendar Access") {
                    Task { await model.requestCalendarAccess() }
                }
                Text("If no prompt appears, this Mac may already have decided — open System Settings › "
                     + "Privacy & Security › Calendars and enable RosterFocus.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Create the Focus you want to drive", systemImage: "moon.circle")
                .font(.title3).bold()
            Text("macOS doesn't let any app create a Focus — you make it once yourself. "
                 + "In System Settings › Focus, add the Focus you want (the built-in **Work** "
                 + "Focus works best). Remember its exact name for the rules step.")
            Button("Open Focus Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private var shortcutsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add the Focus Shortcuts", systemImage: "square.stack.3d.up")
                .font(.title3).bold()
            Text("A Shortcut is the only thing that can actually flip a Focus. For the built-in "
                 + "**Work** Focus you can import the ready-made pair below. For any other Focus, "
                 + "build a matching On/Off pair in Shortcuts.app.")
            HStack {
                Button("Import “Work Focus On”") { openBundledShortcut("Work Focus On") }
                Button("Import “Work Focus Off”") { openBundledShortcut("Work Focus Off") }
            }
            Text("After importing, open each in Shortcuts.app and confirm the Set Focus action shows "
                 + "your Focus (re-pick it if it's blank — that happens with a custom Focus).")
                .font(.caption).foregroundStyle(.secondary)
            Button("Refresh shortcut list") { model.refreshShortcuts() }
            Text(model.availableShortcuts.isEmpty
                 ? "No shortcuts detected yet."
                 : "Detected: \(model.availableShortcuts.joined(separator: ", "))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var enableStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enable RosterFocus", systemImage: "power.circle")
                .font(.title3).bold()
            Toggle("Run automatically (check every 60s)", isOn: Binding(
                get: { model.enabled }, set: { model.setEnabled($0) }))
            Toggle("Launch at login", isOn: Binding(
                get: { model.loginItemEnabled }, set: { model.setLoginItem($0) }))
            Button("Check Now") { model.checkNow() }
            if !model.lastAction.isEmpty {
                Text(model.lastAction).font(.caption).foregroundStyle(.secondary)
            }
            Text("You can close this window — RosterFocus keeps running in the menu bar.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func openBundledShortcut(_ name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "shortcut") {
            NSWorkspace.shared.open(url)
        }
    }
}
