import Foundation

/// The last-applied Focus, persisted as {"focus": "<label or "">"} — identical shape
/// to the Python CLI's state.json, so they share state and never fight.
public enum FocusStateFile {
    public static func read() -> String {
        guard let data = try? Data(contentsOf: ConfigStore.stateURL),
              let obj = try? JSONDecoder().decode([String: String].self, from: data)
        else { return "" }
        return obj["focus"] ?? ""
    }

    public static func write(_ focus: String) throws {
        try FileManager.default.createDirectory(at: ConfigStore.baseDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(["focus": focus])
        try data.write(to: ConfigStore.stateURL, options: .atomic)
    }
}
