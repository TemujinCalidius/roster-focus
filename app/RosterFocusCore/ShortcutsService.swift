import Foundation

/// Thin wrapper over `/usr/bin/shortcuts`. Mirrors the Python `run_shortcut`
/// fail-loud behavior so a mistyped name can never look like success.
public struct ShortcutsService {
    private let binary = "/usr/bin/shortcuts"
    public init() {}

    /// Names of all shortcuts, or nil if the CLI couldn't be run.
    public func list() -> Set<String>? {
        guard let res = run(args: ["list"]), res.exit == 0 else { return nil }
        return Self.parseList(res.stdout)
    }

    /// Run a shortcut by name. True on success. Verifies the name exists first
    /// (the CLI exits 0 even for a missing shortcut) and treats error output as failure.
    @discardableResult
    public func runShortcut(_ name: String) -> Bool {
        if let known = list(), !known.contains(name) {
            warn("shortcut '\(name)' not found in Shortcuts.app")
            return false
        }
        guard let res = run(args: ["run", name]) else {
            warn("could not launch the shortcuts CLI")
            return false
        }
        let err = res.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if res.exit != 0 || err.contains("Error") || err.contains("Couldn't find") {
            warn("shortcut '\(name)' failed: \(err.isEmpty ? "exit \(res.exit)" : err)")
            return false
        }
        return true
    }

    /// Parse `shortcuts list` output: one trimmed, non-empty name per line.
    public static func parseList(_ output: String) -> Set<String> {
        Set(output.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    // MARK: - private

    private struct Result { let exit: Int32; let stdout: String; let stderr: String }

    private func run(args: [String]) -> Result? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do { try proc.run() } catch { return nil }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return Result(exit: proc.terminationStatus,
                      stdout: String(data: outData, encoding: .utf8) ?? "",
                      stderr: String(data: errData, encoding: .utf8) ?? "")
    }

    private func warn(_ msg: String) {
        FileHandle.standardError.write(Data("[rosterfocus] \(msg)\n".utf8))
    }
}
