import Foundation

/// The last-applied Focus, persisted as {"focus": "<label or "">"} — identical shape
/// to the Python CLI's state.json, so they share state and never fight.
public enum FocusStateFile {
    /// Only the `focus` field matters; any other keys are ignored (tolerant, like the
    /// Python `read_state` which only does `.get("focus", "")`).
    private struct StateDTO: Decodable { let focus: String? }

    public static func read() -> String {
        guard let data = try? Data(contentsOf: ConfigStore.stateURL),
              let dto = try? JSONDecoder().decode(StateDTO.self, from: data)
        else { return "" }
        return dto.focus ?? ""
    }

    public static func write(_ focus: String) throws {
        try FileManager.default.createDirectory(at: ConfigStore.baseDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(["focus": focus])
        try data.write(to: ConfigStore.stateURL, options: .atomic)
    }
}
