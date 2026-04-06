import Foundation

// MARK: - Input

/// Input type for the Bash tool.
private struct BashInput: Codable {
    let command: String
    let timeout: Int?
}

// MARK: - Constants

private enum BashConstants {
    static let defaultTimeoutMs = 120_000
    static let maxTimeoutMs = 600_000
    static let truncationThreshold = 100_000
    static let truncationHead = 50_000
    static let truncationTail = 50_000
}

// MARK: - Thread-safe data accumulator

/// Thread-safe accumulator for capturing process output data and timeout state.
///
/// Uses `@unchecked Sendable` because all mutable state is accessed sequentially:
/// Pipe readability handlers and the termination handler all fire on the run loop's
/// dispatch queue, avoiding data races.
private final class ProcessOutputAccumulator: @unchecked Sendable {
    var stdoutData = Data()
    var stderrData = Data()

    /// Whether the timeout has already fired. Set by the timeout handler
    /// and read by the termination handler to determine if timeout caused termination.
    var timeoutFired = false

    /// Guards against double-resume of the continuation in edge cases where
    /// the termination handler and catch block could both fire.
    var resumed = false
}

// MARK: - Factory

/// Creates the Bash tool for executing shell commands.
///
/// The Bash tool executes commands via `/bin/bash -c` and captures stdout, stderr,
/// and exit code information. Key behaviors:
///
/// - **Timeout**: Default 120 seconds, configurable up to 600 seconds.
///   Processes exceeding the timeout are terminated.
/// - **Output truncation**: Output exceeding 100,000 characters is truncated to
///   the first 50,000 + "...(truncated)..." + last 50,000 characters.
/// - **Exit codes**: Non-zero exit codes are appended to the output but do NOT
///   set `isError: true` (exit codes are normal command output).
/// - **Working directory**: Uses `ToolContext.cwd` as the process working directory.
/// - **Cross-platform**: Uses Foundation's `Process` class (works on macOS and Linux).
///
/// - Returns: A `ToolProtocol` instance for the Bash tool.
public func createBashTool() -> ToolProtocol {
    return defineTool(
        name: "Bash",
        description:
            "Execute a bash command and return its output. " +
            "Use for running shell commands, scripts, and system operations. " +
            "Supports configurable timeout (default 120s, max 600s).",
        inputSchema: [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The bash command to execute"
                ],
                "timeout": [
                    "type": "integer",
                    "description": "Optional timeout in milliseconds (max 600000, default 120000)"
                ]
            ],
            "required": ["command"]
        ],
        isReadOnly: false
    ) { (input: BashInput, context: ToolContext) async throws -> ToolExecuteResult in
        let timeoutMs = max(1, min(
            input.timeout ?? BashConstants.defaultTimeoutMs,
            BashConstants.maxTimeoutMs
        ))

        return await executeBashProcess(
            command: input.command,
            cwd: context.cwd,
            timeoutMs: timeoutMs
        )
    }
}

// MARK: - Process Execution

/// Executes a bash command via `Process` with timeout and output capture.
///
/// Uses `withCheckedContinuation` to bridge the callback-based `Process` API
/// to Swift's async/await concurrency model.
///
/// - Parameters:
///   - command: The shell command to execute.
///   - cwd: The working directory for the process.
///   - timeoutMs: Timeout in milliseconds.
/// - Returns: A `ToolExecuteResult` with captured output or error information.
private func executeBashProcess(
    command: String,
    cwd: String,
    timeoutMs: Int
) async -> ToolExecuteResult {
    return await withCheckedContinuation { continuation in
        let accumulator = ProcessOutputAccumulator()
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handler in
            accumulator.stdoutData.append(handler.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handler in
            accumulator.stderrData.append(handler.availableData)
        }

        // Timeout: terminate process if it exceeds the limit.
        // Captures process weakly to avoid retain cycles.
        // Uses accumulator.timeoutFired (thread-safe via @unchecked Sendable)
        // instead of DispatchWorkItem.isCancelled to avoid capturing a non-Sendable type.
        DispatchQueue.global().asyncAfter(
            deadline: .now() + .milliseconds(timeoutMs)
        ) { [weak process] in
            if let process = process, process.isRunning {
                accumulator.timeoutFired = true
                process.terminate()
            }
        }

        process.terminationHandler = { _ in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            // Read any remaining data
            accumulator.stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            accumulator.stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

            let stdout = String(data: accumulator.stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: accumulator.stderrData, encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus

            var output = ""

            if accumulator.timeoutFired {
                // Timeout was the cause of termination
                output = "Command timed out after \(timeoutMs)ms."
                if !stdout.isEmpty {
                    output += "\n--- stdout so far ---\n" + stdout
                }
                if !stderr.isEmpty {
                    output += "\n--- stderr so far ---\n" + stderr
                }
                let truncated = truncateOutput(output)
                guard !accumulator.resumed else { return }
                accumulator.resumed = true
                continuation.resume(returning: ToolExecuteResult(content: truncated, isError: true))
                return
            }

            // Normal completion
            if !stdout.isEmpty { output += stdout }
            if !stderr.isEmpty {
                output += (output.isEmpty ? "" : "\n") + stderr
            }
            if exitCode != 0 {
                output += "\nExit code: \(exitCode)"
            }

            // Truncate if needed
            let truncated = truncateOutput(output)
            guard !accumulator.resumed else { return }
            accumulator.resumed = true
            continuation.resume(returning: ToolExecuteResult(content: truncated, isError: false))
        }

        do {
            try process.run()
        } catch {
            guard !accumulator.resumed else { return }
            accumulator.resumed = true
            continuation.resume(returning: ToolExecuteResult(
                content: "Error starting process: \(error.localizedDescription)",
                isError: true
            ))
        }
    }
}

// MARK: - Output Truncation

/// Truncates output exceeding 100,000 characters to first 50,000 + marker + last 50,000.
///
/// Uses `String.Index` for efficient truncation on large strings,
/// avoiding the O(n) cost of `String.count` on multi-byte content.
private func truncateOutput(_ output: String) -> String {
    // Fast path: use utf16 count as a quick upper-bound check
    guard output.utf16.count > BashConstants.truncationThreshold else {
        return output
    }

    // Precise check using String index
    guard let headEnd = output.index(
        output.startIndex,
        offsetBy: BashConstants.truncationHead,
        limitedBy: output.endIndex
    ),
        let tailStart = output.index(
            output.endIndex,
            offsetBy: -BashConstants.truncationTail,
            limitedBy: output.startIndex
        ),
        headEnd < tailStart
    else {
        return output
    }

    let head = String(output[output.startIndex..<headEnd])
    let tail = String(output[tailStart..<output.endIndex])
    return head + "\n...(truncated)...\n" + tail
}
