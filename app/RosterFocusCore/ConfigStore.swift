import Foundation

/// Reads/writes the SAME files the Python CLI uses, so the app and CLI interoperate:
///   config: ~/.config/roster-focus/config.json   (override: $ROSTERFOCUS_CONFIG)
///   state:  ~/.config/roster-focus/state.json     (override: $ROSTERFOCUS_STATE)
public enum ConfigStore {
    static var baseDir: URL {
        URL(fileURLWithPath: ("~/.config/roster-focus" as NSString).expandingTildeInPath,
            isDirectory: true)
    }

    public static var configURL: URL {
        if let p = ProcessInfo.processInfo.environment["ROSTERFOCUS_CONFIG"], !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        return baseDir.appendingPathComponent("config.json")
    }

    public static var stateURL: URL {
        if let p = ProcessInfo.processInfo.environment["ROSTERFOCUS_STATE"], !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        return baseDir.appendingPathComponent("state.json")
    }

    public static func load() throws -> Config {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public static func loadOrEmpty() -> Config {
        (try? load()) ?? Config(rules: [])
    }

    /// Atomic write. Note: any `_comment` annotations a user added by hand are not
    /// preserved (the CLI doesn't need them).
    public static func save(_ config: Config) throws {
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(config)
        try data.write(to: configURL, options: .atomic)
    }
}
