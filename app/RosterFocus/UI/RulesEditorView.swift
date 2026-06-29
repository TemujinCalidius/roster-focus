import SwiftUI
import RosterFocusCore

/// A free-text field with a dropdown of discovered options (calendars / shortcuts).
/// Free text means a configured value that isn't currently present still shows/edits.
private struct ComboField: View {
    let placeholder: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $selection).textFieldStyle(.roundedBorder)
            Menu {
                if options.isEmpty {
                    Text("none found")
                } else {
                    ForEach(options, id: \.self) { opt in
                        Button(opt) { selection = opt }
                    }
                }
            } label: { Image(systemName: "chevron.down") }
                .menuStyle(.borderlessButton)
                .fixedSize()
        }
    }
}

private struct RuleRow: View {
    @Binding var rule: Rule
    let calendars: [String]
    let shortcuts: [String]
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ComboField(placeholder: "Calendar", selection: $rule.calendar, options: calendars)
                TextField("Keyword (optional)", text: $rule.keyword).textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
            }
            TextField("Focus name (must match a Focus you created)", text: $rule.focus)
                .textFieldStyle(.roundedBorder)
            HStack {
                ComboField(placeholder: "On shortcut", selection: $rule.onShortcut, options: shortcuts)
                ComboField(placeholder: "Off shortcut", selection: $rule.offShortcut, options: shortcuts)
            }
            HStack {
                Stepper("Lead \(rule.leadMinutes)m", value: $rule.leadMinutes, in: 0...240)
                    .fixedSize()
                Stepper("Trail \(rule.trailMinutes)m", value: $rule.trailMinutes, in: 0...240)
                    .fixedSize()
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

struct RulesEditorView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Rules").font(.headline)
                    Text("Evaluated top to bottom — the first rule with an event happening now wins.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.refreshCalendars(); model.refreshShortcuts() } label: {
                    Label("Refresh lists", systemImage: "arrow.clockwise")
                }
                Button { model.addRule() } label: { Label("Add Rule", systemImage: "plus") }
            }

            if model.rules.isEmpty {
                Text("No rules yet. Add one to map a calendar to a Focus.")
                    .foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                List {
                    ForEach($model.rules) { $rule in
                        RuleRow(rule: $rule,
                                calendars: model.calendars,
                                shortcuts: model.availableShortcuts,
                                onDelete: { model.removeRule(rule) })
                    }
                    .onMove { model.rules.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset)
            }

            HStack {
                Button("Save") { model.saveRules() }.keyboardShortcut("s")
                Button("Reload from disk") { model.loadRules() }
                Spacer()
                Text("Config: ~/.config/roster-focus/config.json")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refreshCalendars(); model.refreshShortcuts() }
    }
}
