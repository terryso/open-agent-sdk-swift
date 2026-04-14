import Foundation

// MARK: - Thread-safe State

/// Thread-safe state for shell hook process execution.
///
/// Uses `@unchecked Sendable` because all mutable state is accessed sequentially:
/// the timeout fires on a global dispatch queue, and the termination handler fires
/// on an arbitrary dispatch queue, but only one of them sets `resumed`.
private final class ShellHookExecutionState: @unchecked Sendable {
    /// Whether the timeout has already fired.
    var timeoutFired = false

    /// Guards against double-resume of the continuation.
    var resumed = false
}

// MARK: - ShellHookExecutor

/// Executes shell command hooks via Foundation `Process`.
///
/// Uses `/bin/bash -c` to execute commands, passing `HookInput` as JSON
/// through stdin and reading `HookOutput` JSON from stdout.
/// Matches the TypeScript SDK's `executeShellHook` behavior.
///
/// Key behaviors (aligned with TS SDK):
/// - Input data is passed via stdin pipe (never concatenated in command string -- NFR7)
/// - Inherits current process environment plus HOOK_* variables
/// - Non-JSON stdout is wrapped as `HookOutput(message: stdout)`
/// - Empty stdout returns nil
/// - Non-zero exit code returns nil
/// - Timeout terminates process and returns nil (doesn't block other hooks)
public enum ShellHookExecutor {

    /// Execute a shell command hook.
    ///
    /// - Parameters:
    ///   - command: The shell command to execute via `/bin/bash -c`.
    ///   - input: The hook input data to pass as JSON via stdin.
    ///   - timeoutMs: Timeout in milliseconds (default 30,000).
    /// - Returns: A `HookOutput` parsed from stdout JSON, or nil on failure/timeout.
    public static func execute(
        command: String,
        input: HookInput,
        timeoutMs: Int = 30_000
    ) async -> HookOutput? {
        // Clamp timeout to at least 1ms to prevent instant termination
        // (matches BashTool.swift's max(1, ...) pattern)
        let timeoutMs = max(1, timeoutMs)

        return await withCheckedContinuation { continuation in
            let accumulator = ShellHookExecutionState()
            let process = Process()
            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = FileHandle.nullDevice

            // Set environment variables: inherit current + add HOOK_* vars
            var env = ProcessInfo.processInfo.environment
            env["HOOK_EVENT"] = input.event.rawValue
            env["HOOK_TOOL_NAME"] = input.toolName ?? ""
            env["HOOK_SESSION_ID"] = input.sessionId ?? ""
            env["HOOK_CWD"] = input.cwd ?? ""
            process.environment = env

            // Write HookInput as JSON to stdin via JSONSerialization
            // (cannot use JSONEncoder because HookInput contains Any? fields)
            var inputDict: [String: Any] = [
                "event": input.event.rawValue
            ]
            if let toolName = input.toolName { inputDict["toolName"] = toolName }
            if let sessionId = input.sessionId { inputDict["sessionId"] = sessionId }
            if let cwd = input.cwd { inputDict["cwd"] = cwd }
            if let toolUseId = input.toolUseId { inputDict["toolUseId"] = toolUseId }
            if let error = input.error { inputDict["error"] = error }
            if let toolInput = input.toolInput { inputDict["toolInput"] = toolInput }
            if let toolOutput = input.toolOutput { inputDict["toolOutput"] = toolOutput }

            if let jsonData = try? JSONSerialization.data(withJSONObject: inputDict) {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: jsonData)
            }
            try? stdinPipe.fileHandleForWriting.close()

            // Timeout: terminate process if it exceeds the limit
            DispatchQueue.global().asyncAfter(
                deadline: .now() + .milliseconds(timeoutMs)
            ) { [weak process] in
                if let process = process, process.isRunning {
                    accumulator.timeoutFired = true
                    process.terminate()
                }
            }

            // Termination handler: read and process output
            process.terminationHandler = { _ in
                guard !accumulator.resumed else { return }
                accumulator.resumed = true

                // Timeout: return nil
                if accumulator.timeoutFired {
                    continuation.resume(returning: nil)
                    return
                }

                // Non-zero exit code: return nil
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                // Read all stdout after process has terminated
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stdoutString = String(data: stdoutData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // Empty stdout: return nil
                guard !stdoutString.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Try JSON parse → HookOutput
                if let data = stdoutString.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let output = parseHookOutput(from: jsonObject)
                    continuation.resume(returning: output)
                } else {
                    // Non-JSON → wrap as message
                    continuation.resume(returning: HookOutput(message: stdoutString))
                }
            }

            do {
                try process.run()
                // Close our copy of stdout write end so readDataToEndOfFile()
                // gets EOF when the process terminates
                try? stdoutPipe.fileHandleForWriting.close()
            } catch {
                guard !accumulator.resumed else { return }
                accumulator.resumed = true
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - JSON Parsing

    /// Parses a JSON dictionary into a `HookOutput`.
    ///
    /// Handles all fields: message, permissionUpdate, block, notification.
    /// Missing fields use defaults (nil for optionals, false for block).
    private static func parseHookOutput(from dict: [String: Any]) -> HookOutput {
        let message = dict["message"] as? String

        var permissionUpdate: PermissionUpdate?
        if let permDict = dict["permissionUpdate"] as? [String: Any],
           let tool = permDict["tool"] as? String,
           let behaviorStr = permDict["behavior"] as? String,
           let behavior = PermissionBehavior(rawValue: behaviorStr) {
            permissionUpdate = PermissionUpdate(tool: tool, behavior: behavior)
        }

        let block = dict["block"] as? Bool ?? false

        var notification: HookNotification?
        if let notifDict = dict["notification"] as? [String: Any],
           let title = notifDict["title"] as? String,
           let body = notifDict["body"] as? String {
            let levelStr = notifDict["level"] as? String ?? "info"
            notification = HookNotification(title: title, body: body, level: HookNotificationLevel(levelStr))
        }

        return HookOutput(
            message: message,
            permissionUpdate: permissionUpdate,
            block: block,
            notification: notification
        )
    }
}
