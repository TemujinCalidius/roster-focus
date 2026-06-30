import Foundation

/// Thin async wrapper over `/usr/bin/shortcuts`. Mirrors the Python `run_shortcut`
/// fail-loud behavior so a mistyped name can never look like success.
///
/// All subprocess work runs off the main actor (callers `await`), and both output
/// pipes are drained concurrently to avoid a classic two-pipe deadlock.
public struct ShortcutsService: Sendable {
    private let binary = "/usr/bin/shortcuts"
    public init() {}

    /// Names of all shortcuts, or nil if the CLI couldn't be run.
    public func list() async -> Set<String>? {
        guard let res = await run(args: ["list"]), res.exit == 0 else { return nil }
        return Self.parseList(res.stdout)
    }

    /// Run a shortcut by name. True on success. Verifies the name exists first
    /// (the CLI exits 0 even for a missing shortcut) and treats error output as failure.
    /// Pass `known` (from a single `list()` per tick) to avoid re-spawning `shortcuts list`.
    @discardableResult
    public func runShortcut(_ name: String, known: Set<String>? = nil) async -> Bool {
        let names: Set<String>?
        if let known { names = known } else { names = await list() }
        if let names, !names.contains(name) {
            warn("shortcut '\(name)' not found in Shortcuts.app")
            return false
        }
        guard let res = await run(args: ["run", name]) else {
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

    /// Parse `shortcuts list`: one trimmed, non-empty name per line. Splits on any
    /// newline (LF/CRLF/CR) and trims newlines, matching Python's `line.strip()`.
    public static func parseList(_ output: String) -> Set<String> {
        Set(output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
    }

    // MARK: - private

    private struct Result: Sendable { let exit: Int32; let stdout: String; let stderr: String }

    private func run(args: [String]) async -> Result? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do { try proc.run() } catch { return nil }

        // Drain both pipes concurrently — reading one to EOF before the other can
        // deadlock if the child fills the second pipe's buffer.
        async let out = Self.readToEnd(outPipe.fileHandleForReading)
        async let err = Self.readToEnd(errPipe.fileHandleForReading)
        let outData = await out
        let errData = await err
        proc.waitUntilExit()   // both pipes at EOF ⇒ child already exited; returns promptly
        return Result(exit: proc.terminationStatus,
                      stdout: String(decoding: outData, as: UTF8.self),
                      stderr: String(decoding: errData, as: UTF8.self))
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }

    private func warn(_ msg: String) {
        FileHandle.standardError.write(Data("[rosterfocus] \(msg)\n".utf8))
    }
}
