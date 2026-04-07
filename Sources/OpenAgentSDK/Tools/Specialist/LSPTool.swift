import Foundation

// MARK: - Input

/// Input type for the LSP tool.
///
/// Field names match the TS SDK's LSP tool schema.
private struct LSPInput: Codable {
    let operation: String      // Required
    let file_path: String?     // Optional
    let line: Int?             // Optional (0-based)
    let character: Int?        // Optional (0-based)
    let query: String?         // Optional
}

// MARK: - Schema

private nonisolated(unsafe) let lspSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "operation": [
            "type": "string",
            "enum": [
                "goToDefinition",
                "findReferences",
                "hover",
                "documentSymbol",
                "workspaceSymbol",
                "goToImplementation",
                "prepareCallHierarchy",
                "incomingCalls",
                "outgoingCalls"
            ],
            "description": "LSP operation to perform"
        ] as [String: Any],
        "file_path": [
            "type": "string",
            "description": "File path for the operation"
        ] as [String: Any],
        "line": [
            "type": "number",
            "description": "Line number (0-based)"
        ] as [String: Any],
        "character": [
            "type": "number",
            "description": "Character position (0-based)"
        ] as [String: Any],
        "query": [
            "type": "string",
            "description": "Symbol name (for workspace symbol search)"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["operation"]
]

// MARK: - Symbol Extraction Helper

/// Extracts the word at the given cursor position in a file.
///
/// Uses `\b\w+\b` regex to find all words on the specified line,
/// then returns the word whose range contains the character position.
///
/// - Parameters:
///   - filePath: Absolute path to the file.
///   - line: 0-based line number.
///   - character: 0-based character offset within the line.
/// - Returns: The symbol string at the position, or `nil` if not found.
private func getSymbolAtPosition(
    filePath: String,
    line: Int,
    character: Int
) -> String? {
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        return nil
    }
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    guard line >= 0, line < lines.count else { return nil }
    let lineText = String(lines[line])

    let regex = try? NSRegularExpression(pattern: "\\b\\w+\\b")
    let range = NSRange(lineText.startIndex..., in: lineText)
    guard let matches = regex?.matches(in: lineText, range: range) else { return nil }

    for match in matches {
        guard let matchRange = Range(match.range, in: lineText) else { continue }
        let matchStart = lineText.distance(from: lineText.startIndex, to: matchRange.lowerBound)
        let matchEnd = lineText.distance(from: lineText.startIndex, to: matchRange.upperBound)
        if matchStart <= character && matchEnd >= character {
            return String(lineText[matchRange])
        }
    }
    return nil
}

// MARK: - Thread-safe data accumulator for grep process

/// Thread-safe accumulator for capturing grep process output and timeout state.
///
/// Uses `@unchecked Sendable` because all mutable state is accessed sequentially:
/// Pipe readability handlers and the termination handler all fire on the run loop's
/// dispatch queue, avoiding data races.
private final class GrepOutputAccumulator: @unchecked Sendable {
    var stdoutData = Data()

    /// Whether the timeout has already fired.
    var timeoutFired = false

    /// Guards against double-resume of the continuation.
    var resumed = false
}

// MARK: - Grep Execution Helper

/// Executes a grep command via Foundation's Process class.
///
/// Uses `/usr/bin/env` as the executable for cross-platform compatibility.
/// Captures stdout; stderr is discarded. Has a configurable timeout (default 10 seconds).
///
/// - Parameters:
///   - arguments: Command arguments (e.g., `["grep", "-rn", "pattern", "/path"]`).
///   - cwd: Working directory for the process.
///   - timeout: Maximum execution time in seconds (default 10.0).
/// - Returns: The trimmed stdout output, or `nil` if execution failed or timed out.
private func runGrep(
    arguments: [String],
    cwd: String,
    timeout: TimeInterval = 10.0
) async -> String? {
    return await withCheckedContinuation { continuation in
        let accumulator = GrepOutputAccumulator()
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handler in
            accumulator.stdoutData.append(handler.availableData)
        }

        // Timeout handler
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak process] in
            if let process = process, process.isRunning {
                accumulator.timeoutFired = true
                process.terminate()
            }
        }

        process.terminationHandler = { _ in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil

            // Read any remaining data
            accumulator.stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())

            let output = String(data: accumulator.stdoutData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !accumulator.resumed else { return }
            accumulator.resumed = true

            if accumulator.timeoutFired {
                continuation.resume(returning: nil)
            } else {
                // Return output for both exit code 0 (matches found) and 1 (no matches).
                // An empty/nil output indicates no matches.
                continuation.resume(returning: output)
            }
        }

        do {
            try process.run()
        } catch {
            guard !accumulator.resumed else { return }
            accumulator.resumed = true
            continuation.resume(returning: nil)
        }
    }
}

// MARK: - Factory Function

/// Creates the LSP tool for code intelligence operations.
///
/// The LSP tool provides grep-based fallback implementations for common
/// Language Server Protocol operations. It is completely stateless and
/// read-only -- no Actor store, ToolContext modifications, or AgentOptions
/// changes are required.
///
/// **Supported operations:**
/// - `goToDefinition` / `goToImplementation`: Extracts symbol at cursor, searches for definitions via grep.
/// - `findReferences`: Extracts symbol at cursor, searches for all references (max 50 lines).
/// - `hover`: Returns a hint that a running language server is needed.
/// - `documentSymbol`: Searches for declarations in a file.
/// - `workspaceSymbol`: Searches the workspace for matching symbols (max 30 lines).
/// - `prepareCallHierarchy` / `incomingCalls` / `outgoingCalls`: Returns language server hint.
///
/// **Architecture:** This tool uses only `ToolContext.cwd` for directory resolution.
/// It does not import Core/, Stores/, or any other modules beyond Foundation.
///
/// - Returns: A ``ToolProtocol`` instance for the LSP tool.
public func createLSPTool() -> ToolProtocol {
    return defineTool(
        name: "LSP",
        description: "Language Server Protocol operations for code intelligence. Supports go-to-definition, find-references, hover, and symbol lookup.",
        inputSchema: lspSchema,
        isReadOnly: true
    ) { (input: LSPInput, context: ToolContext) async throws -> ToolExecuteResult in
        let cwd = context.cwd

        switch input.operation {
        case "goToDefinition", "goToImplementation":
                guard let filePath = input.file_path else {
                    return ToolExecuteResult(
                        content: "Error: file_path is required for goToDefinition.",
                        isError: true
                    )
                }
                guard let line = input.line else {
                    return ToolExecuteResult(
                        content: "Error: line is required for goToDefinition.",
                        isError: true
                    )
                }
                let character = input.character ?? 0

                guard let symbol = getSymbolAtPosition(
                    filePath: filePath,
                    line: line,
                    character: character
                ) else {
                    return ToolExecuteResult(
                        content: "No definition found for symbol at position",
                        isError: false
                    )
                }

                // Search for definition patterns: function/class/struct/enum/protocol/typealias/let/var/export
                let pattern = "(func|class|struct|enum|protocol|typealias|let|var|export)\\s+\(symbol)"
                let results = await runGrep(
                    arguments: ["grep", "-rn", "-E", pattern, cwd],
                    cwd: cwd
                )

                if let output = results, !output.isEmpty {
                    return ToolExecuteResult(content: output, isError: false)
                } else {
                    return ToolExecuteResult(
                        content: "No definition found for \"\(symbol)\"",
                        isError: false
                    )
                }

            case "findReferences":
                guard let filePath = input.file_path else {
                    return ToolExecuteResult(
                        content: "Error: file_path is required for findReferences.",
                        isError: true
                    )
                }
                guard let line = input.line else {
                    return ToolExecuteResult(
                        content: "Error: line is required for findReferences.",
                        isError: true
                    )
                }
                let character = input.character ?? 0

                guard let symbol = getSymbolAtPosition(
                    filePath: filePath,
                    line: line,
                    character: character
                ) else {
                    return ToolExecuteResult(
                        content: "No references found for symbol at position",
                        isError: false
                    )
                }

                let results = await runGrep(
                    arguments: ["grep", "-rn", symbol, cwd],
                    cwd: cwd
                )

                if let output = results, !output.isEmpty {
                    // Limit to 50 lines (consistent with TS SDK)
                    let lines = output.components(separatedBy: "\n")
                    let limited = Array(lines.prefix(50)).joined(separator: "\n")
                    return ToolExecuteResult(content: limited, isError: false)
                } else {
                    return ToolExecuteResult(
                        content: "No references found for \"\(symbol)\"",
                        isError: false
                    )
                }

            case "hover":
                return ToolExecuteResult(
                    content: "Hover requires a running language server. Consider using the Read tool to view file contents instead.",
                    isError: false
                )

            case "documentSymbol":
                guard let filePath = input.file_path else {
                    return ToolExecuteResult(
                        content: "Error: file_path is required for documentSymbol.",
                        isError: true
                    )
                }

                // Search for declaration patterns in the file
                let pattern = "(func |class |struct |enum |protocol |typealias |let |var |const |interface |type )"
                let results = await runGrep(
                    arguments: ["grep", "-n", "-E", pattern, filePath],
                    cwd: cwd
                )

                if let output = results, !output.isEmpty {
                    return ToolExecuteResult(content: output, isError: false)
                } else {
                    return ToolExecuteResult(
                        content: "No symbols found",
                        isError: false
                    )
                }

            case "workspaceSymbol":
                guard let query = input.query, !query.isEmpty else {
                    return ToolExecuteResult(
                        content: "Error: query is required for workspaceSymbol.",
                        isError: true
                    )
                }

                let results = await runGrep(
                    arguments: ["grep", "-rn", "-E", query, cwd],
                    cwd: cwd
                )

                if let output = results, !output.isEmpty {
                    // Limit to 30 lines (consistent with TS SDK)
                    let lines = output.components(separatedBy: "\n")
                    let limited = Array(lines.prefix(30)).joined(separator: "\n")
                    return ToolExecuteResult(content: limited, isError: false)
                } else {
                    return ToolExecuteResult(
                        content: "No symbols found for \"\(query)\"",
                        isError: false
                    )
                }

        default:
            return ToolExecuteResult(
                content: "LSP operation \"\(input.operation)\" requires a running language server.",
                isError: false
            )
        }
    }
}
