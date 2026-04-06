import Foundation

// MARK: - Question Handler (module-level state)

/// Internal question handler storage.
/// Set by the agent when it has an interactive user connection.
/// Uses `nonisolated(unsafe)` because access is serialized by the tool execution
/// lifecycle (handler set before agent loop, cleared after).
nonisolated(unsafe) private var _questionHandler: (@Sendable (String, [String]?) async throws -> String)?

/// Sets the question handler for the AskUser tool.
///
/// Called by the agent when it has an interactive user connection.
/// The handler receives the question text and optional list of choices,
/// and returns the user's response string.
///
/// - Parameter handler: A closure that takes a question string and optional
///   choices array, returning the user's answer.
public func setQuestionHandler(
    _ handler: @Sendable @escaping (String, [String]?) async throws -> String
) {
    _questionHandler = handler
}

/// Clears the question handler for the AskUser tool.
///
/// Called when the agent disconnects from an interactive session,
/// putting the AskUser tool into non-interactive mode.
public func clearQuestionHandler() {
    _questionHandler = nil
}

// MARK: - Input

/// Input type for the AskUser tool.
private struct AskUserInput: Codable {
    let question: String
    let options: [String]?
}

// MARK: - Factory

/// Creates the AskUser tool for asking the user questions during execution.
///
/// The AskUser tool allows an agent to request input from the user during
/// execution. Key behaviors:
///
/// - **Interactive mode**: When a question handler is set (via `setQuestionHandler`),
///   the tool calls the handler and returns the user's response.
/// - **Non-interactive mode**: When no handler is set, returns an informational
///   message indicating no user is available, and the agent should use best judgment.
/// - **Error handling**: If the handler throws (e.g., user declines), returns
///   `isError: true` with the error description.
///
/// - Returns: A `ToolProtocol` instance for the AskUser tool.
public func createAskUserTool() -> ToolProtocol {
    return defineTool(
        name: "AskUser",
        description:
            "Ask the user a question and wait for their response. " +
            "Use when you need clarification or input from the user during execution.",
        inputSchema: [
            "type": "object",
            "properties": [
                "question": [
                    "type": "string",
                    "description": "The question to ask the user"
                ],
                "options": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Optional list of choices for the user"
                ]
            ],
            "required": ["question"]
        ],
        isReadOnly: true
    ) { (input: AskUserInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let handler = _questionHandler else {
            // Non-interactive mode: no user available
            var msg = "[Non-interactive mode] Question: \(input.question)"
            if let options = input.options {
                msg += "\nOptions: \(options.joined(separator: ", "))"
            }
            msg += "\n\nNo user available to answer. Proceeding with best judgment."
            return ToolExecuteResult(content: msg, isError: false)
        }

        do {
            let answer = try await handler(input.question, input.options)
            return ToolExecuteResult(content: answer, isError: false)
        } catch {
            return ToolExecuteResult(
                content: "User declined to answer: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
