import Foundation

/// Streaming message union type for agent communication.
///
/// `SDKMessage` is the primary event type yielded by ``Agent/stream(_:)``. Each case
/// represents a different stage or event in the agent's processing loop. Use a `switch`
/// statement to handle the events you care about:
///
/// ```swift
/// for await message in agent.stream("Hello") {
///     switch message {
///     case .partialMessage(let data):
///         print(data.text, terminator: "")
///     case .result(let data):
///         print("\nDone: \(data.status)")
///     default:
///         break
///     }
/// }
/// ```
public enum SDKMessage: Sendable {
    /// An assistant response with text, model info, and stop reason.
    case assistant(AssistantData)
    /// A tool invocation request from the LLM.
    case toolUse(ToolUseData)
    /// A tool execution result being fed back to the LLM.
    case toolResult(ToolResultData)
    /// The final result of the agent query.
    case result(ResultData)
    /// A partial text chunk during streaming.
    case partialMessage(PartialData)
    /// A system-level event (init, compact boundary, status, etc.).
    case system(SystemData)
    /// A user message event.
    case userMessage(UserMessageData)
    /// A tool progress event during tool execution.
    case toolProgress(ToolProgressData)
    /// A hook started event when a hook begins execution.
    case hookStarted(HookStartedData)
    /// A hook progress event with stdout/stderr output.
    case hookProgress(HookProgressData)
    /// A hook response event with the final hook result.
    case hookResponse(HookResponseData)
    /// A task started event when a sub-agent task begins.
    case taskStarted(TaskStartedData)
    /// A task progress event with usage information.
    case taskProgress(TaskProgressData)
    /// An authentication status event.
    case authStatus(AuthStatusData)
    /// A files persisted event listing file paths written.
    case filesPersisted(FilesPersistedData)
    /// A local command output event from sandboxed execution.
    case localCommandOutput(LocalCommandOutputData)
    /// A prompt suggestion event with recommended follow-up prompts.
    case promptSuggestion(PromptSuggestionData)
    /// A tool use summary event with aggregated tool usage statistics.
    case toolUseSummary(ToolUseSummaryData)

    // MARK: - Convenience Computed Properties

    /// Text content, available for all variants.
    public var text: String {
        switch self {
        case .assistant(let data): return data.text
        case .toolUse(let data): return data.toolName
        case .result(let data): return data.text
        case .partialMessage(let data): return data.text
        case .toolResult(let data): return data.content
        case .system(let data): return data.message
        case .userMessage(let data): return data.message
        case .toolProgress(let data): return data.toolName
        case .hookStarted(let data): return data.hookName
        case .hookProgress(let data): return data.hookName
        case .hookResponse(let data): return data.hookName
        case .taskStarted(let data): return data.description
        case .taskProgress(let data): return data.taskId
        case .authStatus(let data): return data.message
        case .filesPersisted(let data): return data.filePaths.joined(separator: ", ")
        case .localCommandOutput(let data): return data.output
        case .promptSuggestion(let data): return data.suggestions.joined(separator: ", ")
        case .toolUseSummary(let data): return "Used \(data.toolUseCount) tools"
        }
    }

    /// Model name, available only for `.assistant`.
    public var model: String? {
        guard case .assistant(let data) = self else { return nil }
        return data.model
    }

    /// Stop reason, available only for `.assistant`.
    public var stopReason: String? {
        guard case .assistant(let data) = self else { return nil }
        return data.stopReason
    }

    /// Tool use ID, available only for `.toolResult`.
    public var toolUseId: String? {
        guard case .toolResult(let data) = self else { return nil }
        return data.toolUseId
    }

    /// Content string, available only for `.toolResult`.
    public var content: String? {
        guard case .toolResult(let data) = self else { return nil }
        return data.content
    }

    /// Whether the tool result is an error, available only for `.toolResult`.
    public var isError: Bool? {
        guard case .toolResult(let data) = self else { return nil }
        return data.isError
    }

    /// Number of turns, available only for `.result`.
    public var numTurns: Int? {
        guard case .result(let data) = self else { return nil }
        return data.numTurns
    }

    /// Duration in milliseconds, available only for `.result`.
    public var durationMs: Int? {
        guard case .result(let data) = self else { return nil }
        return data.durationMs
    }

    /// System message, available only for `.system`.
    public var message: String? {
        guard case .system(let data) = self else { return nil }
        return data.message
    }

    // MARK: - Associated Data Types

    /// Data for an assistant response message.
    public struct AssistantData: Sendable, Equatable {
        /// The text content of the assistant's response.
        public let text: String
        /// The model identifier used for this response.
        public let model: String
        /// The reason the response stopped (e.g., "end_turn", "tool_use", "max_tokens").
        public let stopReason: String
        /// Unique identifier for this message.
        public let uuid: String?
        /// Session identifier this message belongs to.
        public let sessionId: String?
        /// Parent tool use ID if this message was generated within a tool call context.
        public let parentToolUseId: String?
        /// Error information if the assistant encountered an error.
        public let error: AssistantError?

        /// Creates assistant data with all fields.
        ///
        /// - Parameters:
        ///   - text: The text content of the response.
        ///   - model: The model identifier.
        ///   - stopReason: The reason the response stopped.
        ///   - uuid: Unique message identifier. Defaults to `nil`.
        ///   - sessionId: Session identifier. Defaults to `nil`.
        ///   - parentToolUseId: Parent tool use ID. Defaults to `nil`.
        ///   - error: Error information. Defaults to `nil`.
        public init(text: String, model: String, stopReason: String, uuid: String? = nil, sessionId: String? = nil, parentToolUseId: String? = nil, error: AssistantError? = nil) {
            self.text = text
            self.model = model
            self.stopReason = stopReason
            self.uuid = uuid
            self.sessionId = sessionId
            self.parentToolUseId = parentToolUseId
            self.error = error
        }
    }

    /// Error subtypes for assistant messages, matching the TS SDK error categories.
    public enum AssistantError: String, Sendable, Equatable {
        /// Authentication with the API failed.
        case authenticationFailed
        /// A billing-related error occurred.
        case billingError
        /// The request was rate-limited.
        case rateLimit
        /// The request was invalid.
        case invalidRequest
        /// A server-side error occurred.
        case serverError
        /// The maximum output token limit was reached.
        case maxOutputTokens
        /// An unknown error occurred.
        case unknown
    }

    /// Data for a tool invocation message.
    public struct ToolUseData: Sendable, Equatable {
        /// The name of the tool being invoked.
        public let toolName: String
        /// A unique identifier for this tool use instance.
        public let toolUseId: String
        /// The raw JSON input for the tool call.
        public let input: String

        public init(toolName: String, toolUseId: String, input: String) {
            self.toolName = toolName
            self.toolUseId = toolUseId
            self.input = input
        }
    }

    /// Data for a tool result message.
    public struct ToolResultData: Sendable, Equatable {
        /// The tool use ID this result corresponds to.
        public let toolUseId: String
        /// The content returned by the tool.
        public let content: String
        /// Whether the tool execution resulted in an error.
        public let isError: Bool

        public init(toolUseId: String, content: String, isError: Bool) {
            self.toolUseId = toolUseId
            self.content = content
            self.isError = isError
        }
    }

    /// Final result data from an agent query.
    public struct ResultData: Sendable, Equatable {
        /// The result subtype indicating how the query terminated.
        public enum Subtype: String, Sendable, Equatable {
            /// The query completed successfully.
            case success
            /// The agent loop exceeded the configured maxTurns limit.
            case errorMaxTurns
            /// An API error occurred during execution.
            case errorDuringExecution
            /// The accumulated cost exceeded the configured budget limit.
            case errorMaxBudgetUsd
            /// The query was cancelled by the user.
            case cancelled
            /// Structured output generation exceeded the maximum retry limit.
            case errorMaxStructuredOutputRetries
        }

        /// How the query terminated.
        public let subtype: Subtype
        /// The accumulated response text.
        public let text: String
        /// Token usage for the query, if available.
        public let usage: TokenUsage?
        /// Number of agent loop turns completed.
        public let numTurns: Int
        /// Total query duration in milliseconds.
        public let durationMs: Int
        /// Total cost in USD for this query.
        public let totalCostUsd: Double
        /// Per-model cost breakdown for this query.
        public let costBreakdown: [CostBreakdownEntry]
        /// Structured output from the query, if available (JSON-compatible).
        public let structuredOutput: SendableStructuredOutput?
        /// Permission denials encountered during the query.
        public let permissionDenials: [SDKPermissionDenial]?
        /// Per-model token usage entries for this query (distinct from costBreakdown).
        public let modelUsage: [ModelUsageEntry]?

        /// Creates result data with the original fields.
        ///
        /// - Parameters:
        ///   - subtype: How the query terminated.
        ///   - text: The accumulated response text.
        ///   - usage: Token usage for the query.
        ///   - numTurns: Number of agent loop turns completed.
        ///   - durationMs: Total query duration in milliseconds.
        ///   - totalCostUsd: Total cost in USD. Defaults to `0.0`.
        ///   - costBreakdown: Per-model cost breakdown. Defaults to `[]`.
        ///   - structuredOutput: Structured output (JSON-compatible). Defaults to `nil`.
        ///   - permissionDenials: Permission denials. Defaults to `nil`.
        ///   - modelUsage: Per-model usage entries. Defaults to `nil`.
        public init(subtype: Subtype, text: String, usage: TokenUsage?, numTurns: Int, durationMs: Int, totalCostUsd: Double = 0.0, costBreakdown: [CostBreakdownEntry] = [], structuredOutput: SendableStructuredOutput? = nil, permissionDenials: [SDKPermissionDenial]? = nil, modelUsage: [ModelUsageEntry]? = nil) {
            self.subtype = subtype
            self.text = text
            self.usage = usage
            self.numTurns = numTurns
            self.durationMs = durationMs
            self.totalCostUsd = totalCostUsd
            self.costBreakdown = costBreakdown
            self.structuredOutput = structuredOutput
            self.permissionDenials = permissionDenials
            self.modelUsage = modelUsage
        }

        public static func == (lhs: ResultData, rhs: ResultData) -> Bool {
            return lhs.subtype == rhs.subtype
                && lhs.text == rhs.text
                && lhs.usage == rhs.usage
                && lhs.numTurns == rhs.numTurns
                && lhs.durationMs == rhs.durationMs
                && lhs.totalCostUsd == rhs.totalCostUsd
                && lhs.costBreakdown == rhs.costBreakdown
                && lhs.structuredOutput == rhs.structuredOutput
                && lhs.permissionDenials == rhs.permissionDenials
                && lhs.modelUsage == rhs.modelUsage
        }
    }

    /// Partial text data during streaming.
    public struct PartialData: Sendable, Equatable {
        /// The text chunk received in this partial update.
        public let text: String
        /// Parent tool use ID if this partial message was generated within a tool call context.
        public let parentToolUseId: String?
        /// Unique identifier for this message.
        public let uuid: String?
        /// Session identifier this message belongs to.
        public let sessionId: String?

        /// Creates partial data with optional metadata fields.
        ///
        /// - Parameters:
        ///   - text: The text chunk.
        ///   - parentToolUseId: Parent tool use ID. Defaults to `nil`.
        ///   - uuid: Unique message identifier. Defaults to `nil`.
        ///   - sessionId: Session identifier. Defaults to `nil`.
        public init(text: String, parentToolUseId: String? = nil, uuid: String? = nil, sessionId: String? = nil) {
            self.text = text
            self.parentToolUseId = parentToolUseId
            self.uuid = uuid
            self.sessionId = sessionId
        }
    }

    /// System-level event data.
    public struct SystemData: Sendable, Equatable {
        /// The type of system event.
        public enum Subtype: String, Sendable, Equatable {
            /// Session initialization.
            case `init`
            /// Conversation compaction boundary.
            case compactBoundary
            /// Status update.
            case status
            /// Task notification.
            case taskNotification
            /// Rate limit event.
            case rateLimit
            /// A task has started.
            case taskStarted
            /// A task has made progress.
            case taskProgress
            /// A hook has started execution.
            case hookStarted
            /// A hook has produced intermediate output.
            case hookProgress
            /// A hook has completed with a response.
            case hookResponse
            /// Files have been persisted to disk.
            case filesPersisted
            /// Output from a local command execution.
            case localCommandOutput
        }

        /// The system event subtype.
        public let subtype: Subtype
        /// A human-readable message describing the event.
        public let message: String
        /// Session identifier, available during init events.
        public let sessionId: String?
        /// Tools available in this session, available during init events.
        public let tools: [ToolInfo]?
        /// Model identifier, available during init events.
        public let model: String?
        /// Permission mode for the session, available during init events.
        public let permissionMode: String?
        /// MCP servers configured for this session, available during init events.
        public let mcpServers: [McpServerInfo]?
        /// Current working directory, available during init events.
        public let cwd: String?

        /// Creates system data with optional init-specific fields.
        ///
        /// - Parameters:
        ///   - subtype: The system event subtype.
        ///   - message: A human-readable message.
        ///   - sessionId: Session identifier. Defaults to `nil`.
        ///   - tools: Available tools. Defaults to `nil`.
        ///   - model: Model identifier. Defaults to `nil`.
        ///   - permissionMode: Permission mode. Defaults to `nil`.
        ///   - mcpServers: MCP servers. Defaults to `nil`.
        ///   - cwd: Working directory. Defaults to `nil`.
        public init(subtype: Subtype, message: String, sessionId: String? = nil, tools: [ToolInfo]? = nil, model: String? = nil, permissionMode: String? = nil, mcpServers: [McpServerInfo]? = nil, cwd: String? = nil) {
            self.subtype = subtype
            self.message = message
            self.sessionId = sessionId
            self.tools = tools
            self.model = model
            self.permissionMode = permissionMode
            self.mcpServers = mcpServers
            self.cwd = cwd
        }
    }

    // MARK: - New Message Data Types (Story 17-1)

    /// Data for a user message event.
    public struct UserMessageData: Sendable, Equatable {
        /// Unique identifier for this message.
        public let uuid: String?
        /// Session identifier this message belongs to.
        public let sessionId: String?
        /// The user's message text.
        public let message: String
        /// Parent tool use ID if this message was generated within a tool call context.
        public let parentToolUseId: String?
        /// Whether this message was synthetically generated (e.g., by a tool).
        public let isSynthetic: Bool?
        /// The tool use result that triggered this message, if applicable.
        public let toolUseResult: String?

        /// Creates user message data.
        ///
        /// - Parameters:
        ///   - uuid: Unique message identifier. Defaults to `nil`.
        ///   - sessionId: Session identifier. Defaults to `nil`.
        ///   - message: The user's message text.
        ///   - parentToolUseId: Parent tool use ID. Defaults to `nil`.
        ///   - isSynthetic: Whether this message is synthetic. Defaults to `nil`.
        ///   - toolUseResult: Tool use result. Defaults to `nil`.
        public init(uuid: String? = nil, sessionId: String? = nil, message: String, parentToolUseId: String? = nil, isSynthetic: Bool? = nil, toolUseResult: String? = nil) {
            self.uuid = uuid
            self.sessionId = sessionId
            self.message = message
            self.parentToolUseId = parentToolUseId
            self.isSynthetic = isSynthetic
            self.toolUseResult = toolUseResult
        }
    }

    /// Data for a tool progress event during tool execution.
    public struct ToolProgressData: Sendable, Equatable {
        /// The tool use ID for the tool execution in progress.
        public let toolUseId: String
        /// The name of the tool being executed.
        public let toolName: String
        /// Parent tool use ID if this progress event is nested within another tool call.
        public let parentToolUseId: String?
        /// Elapsed time in seconds since the tool execution started.
        public let elapsedTimeSeconds: Double?

        /// Creates tool progress data.
        ///
        /// - Parameters:
        ///   - toolUseId: The tool use ID.
        ///   - toolName: The tool name.
        ///   - parentToolUseId: Parent tool use ID. Defaults to `nil`.
        ///   - elapsedTimeSeconds: Elapsed time. Defaults to `nil`.
        public init(toolUseId: String, toolName: String, parentToolUseId: String? = nil, elapsedTimeSeconds: Double? = nil) {
            self.toolUseId = toolUseId
            self.toolName = toolName
            self.parentToolUseId = parentToolUseId
            self.elapsedTimeSeconds = elapsedTimeSeconds
        }
    }

    /// Data for a hook started event.
    public struct HookStartedData: Sendable, Equatable {
        /// Unique identifier for this hook execution.
        public let hookId: String
        /// The name of the hook that started.
        public let hookName: String
        /// The event that triggered the hook (e.g., "PreToolUse", "PostToolUse").
        public let hookEvent: String

        /// Creates hook started data.
        public init(hookId: String, hookName: String, hookEvent: String) {
            self.hookId = hookId
            self.hookName = hookName
            self.hookEvent = hookEvent
        }
    }

    /// Data for a hook progress event with stdout/stderr output.
    public struct HookProgressData: Sendable, Equatable {
        /// Unique identifier for this hook execution.
        public let hookId: String
        /// The name of the hook producing output.
        public let hookName: String
        /// The event that triggered the hook.
        public let hookEvent: String
        /// Standard output from the hook process.
        public let stdout: String?
        /// Standard error from the hook process.
        public let stderr: String?

        /// Creates hook progress data.
        public init(hookId: String, hookName: String, hookEvent: String, stdout: String? = nil, stderr: String? = nil) {
            self.hookId = hookId
            self.hookName = hookName
            self.hookEvent = hookEvent
            self.stdout = stdout
            self.stderr = stderr
        }
    }

    /// Data for a hook response event with the final hook result.
    public struct HookResponseData: Sendable, Equatable {
        /// Unique identifier for this hook execution.
        public let hookId: String
        /// The name of the hook that completed.
        public let hookName: String
        /// The event that triggered the hook.
        public let hookEvent: String
        /// The output from the hook.
        public let output: String?
        /// The exit code of the hook process.
        public let exitCode: Int?
        /// The outcome of the hook execution (e.g., "success", "error").
        public let outcome: String?

        /// Creates hook response data.
        public init(hookId: String, hookName: String, hookEvent: String, output: String? = nil, exitCode: Int? = nil, outcome: String? = nil) {
            self.hookId = hookId
            self.hookName = hookName
            self.hookEvent = hookEvent
            self.output = output
            self.exitCode = exitCode
            self.outcome = outcome
        }
    }

    /// Data for a task started event.
    public struct TaskStartedData: Sendable, Equatable {
        /// Unique identifier for the task.
        public let taskId: String
        /// The type of task (e.g., "subagent").
        public let taskType: String
        /// A human-readable description of the task.
        public let description: String

        /// Creates task started data.
        public init(taskId: String, taskType: String, description: String) {
            self.taskId = taskId
            self.taskType = taskType
            self.description = description
        }
    }

    /// Data for a task progress event with usage information.
    public struct TaskProgressData: Sendable, Equatable {
        /// Unique identifier for the task.
        public let taskId: String
        /// The type of task.
        public let taskType: String
        /// Token usage for the task so far.
        public let usage: TokenUsage?

        /// Creates task progress data.
        public init(taskId: String, taskType: String, usage: TokenUsage? = nil) {
            self.taskId = taskId
            self.taskType = taskType
            self.usage = usage
        }
    }

    /// Data for an authentication status event.
    public struct AuthStatusData: Sendable, Equatable {
        /// The authentication status (e.g., "authenticated", "expired").
        public let status: String
        /// A human-readable message about the authentication status.
        public let message: String

        /// Creates auth status data.
        public init(status: String, message: String) {
            self.status = status
            self.message = message
        }
    }

    /// Data for a files persisted event.
    public struct FilesPersistedData: Sendable, Equatable {
        /// The file paths that were persisted.
        public let filePaths: [String]

        /// Creates files persisted data.
        public init(filePaths: [String]) {
            self.filePaths = filePaths
        }
    }

    /// Data for a local command output event.
    public struct LocalCommandOutputData: Sendable, Equatable {
        /// The output from the local command.
        public let output: String
        /// The command that was executed.
        public let command: String

        /// Creates local command output data.
        public init(output: String, command: String) {
            self.output = output
            self.command = command
        }
    }

    /// Data for a prompt suggestion event.
    public struct PromptSuggestionData: Sendable, Equatable {
        /// The suggested follow-up prompts.
        public let suggestions: [String]

        /// Creates prompt suggestion data.
        public init(suggestions: [String]) {
            self.suggestions = suggestions
        }
    }

    /// Data for a tool use summary event.
    public struct ToolUseSummaryData: Sendable, Equatable {
        /// The total number of tool uses during the query.
        public let toolUseCount: Int
        /// The names of tools used.
        public let tools: [String]

        /// Creates tool use summary data.
        public init(toolUseCount: Int, tools: [String]) {
            self.toolUseCount = toolUseCount
            self.tools = tools
        }
    }

    // MARK: - Supporting Types

    /// A type-erased Sendable wrapper for JSON-compatible structured output.
    ///
    /// Used by ``ResultData/structuredOutput`` to hold arbitrary JSON-compatible values
    /// while maintaining Sendable conformance. The value is expected to be a JSON-compatible
    /// type (String, Int, Double, Bool, Array, Dictionary) but this is not enforced at compile time.
    public struct SendableStructuredOutput: @unchecked Sendable, Equatable {
        /// The underlying JSON-compatible value.
        public let value: Any?

        /// Creates a SendableStructuredOutput wrapping the given value.
        ///
        /// - Parameter value: A JSON-compatible value (String, Int, Double, Bool, Array, Dictionary).
        public init(_ value: Any?) {
            self.value = value
        }

        public static func == (lhs: SendableStructuredOutput, rhs: SendableStructuredOutput) -> Bool {
            switch (lhs.value, rhs.value) {
            case (nil, nil): return true
            case (nil, _), (_, nil): return false
            case let (l as String, r as String): return l == r
            case let (l as Int, r as Int): return l == r
            case let (l as Double, r as Double): return l == r
            case let (l as Bool, r as Bool): return l == r
            case let (l as [Any], r as [Any]): return NSArray(array: l).isEqual(to: r)
            case let (l as [String: Any], r as [String: Any]): return NSDictionary(dictionary: l).isEqual(to: r)
            default: return false
            }
        }
    }

    /// A permission denial record for a tool that was denied execution.
    public struct SDKPermissionDenial: Sendable, Equatable {
        /// The name of the tool that was denied.
        public let toolName: String
        /// The tool use ID of the denied tool call.
        public let toolUseId: String
        /// The input that was passed to the tool.
        public let toolInput: String

        /// Creates a permission denial record.
        public init(toolName: String, toolUseId: String, toolInput: String) {
            self.toolName = toolName
            self.toolUseId = toolUseId
            self.toolInput = toolInput
        }
    }

    /// A per-model token usage entry, distinct from cost breakdown.
    public struct ModelUsageEntry: Sendable, Equatable {
        /// The model identifier.
        public let model: String
        /// Number of input tokens used by this model.
        public let inputTokens: Int
        /// Number of output tokens used by this model.
        public let outputTokens: Int

        /// Creates a model usage entry.
        public init(model: String, inputTokens: Int, outputTokens: Int) {
            self.model = model
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
        }
    }

    /// Tool metadata available during session init events.
    public struct ToolInfo: Sendable, Equatable {
        /// The name of the tool.
        public let name: String
        /// A description of what the tool does.
        public let description: String

        /// Creates tool info.
        public init(name: String, description: String) {
            self.name = name
            self.description = description
        }
    }

    /// MCP server metadata available during session init events.
    public struct McpServerInfo: Sendable, Equatable {
        /// The name of the MCP server.
        public let name: String
        /// The command used to start the MCP server.
        public let command: String

        /// Creates MCP server info.
        public init(name: String, command: String) {
            self.name = name
            self.command = command
        }
    }
}
