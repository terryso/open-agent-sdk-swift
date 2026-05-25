import Foundation

// MARK: - AgentEvent

/// Protocol for all runtime events emitted by the agent system.
///
/// Every event carries a unique identifier and the moment it was created.
/// Concrete event types use struct composition with ``BaseAgentEvent`` rather
/// than class inheritance, preserving value semantics and `Sendable` safety.
public protocol AgentEvent: Sendable, Codable {
    /// Unique identifier for this event instance.
    var id: String { get }
    /// Wall-clock time when this event was created.
    var timestamp: Date { get }
}

// MARK: - BaseAgentEvent

/// Default implementation of ``AgentEvent`` providing auto-generated `id` and `timestamp`.
///
/// Concrete event types compose this as a stored property rather than subclassing:
/// ```swift
/// struct MyEvent: AgentEvent {
///     let base: BaseAgentEvent
///     var id: String { base.id }
///     var timestamp: Date { base.timestamp }
///     // ... domain-specific fields
/// }
/// ```
public struct BaseAgentEvent: AgentEvent, Codable, Equatable {
    public let id: String
    public let timestamp: Date

    public init(id: String = UUID().uuidString, timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}

// MARK: - AgentEventCategory

/// High-level classification of runtime event types.
///
/// Used by the EventBus for type-filtered subscriptions and structured logging.
public enum AgentEventCategory: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case session
    case agent
    case tool
    case llm
    case memory
    case subAgent
}

// MARK: - Session Events

/// Status of a session at the time of closure.
public enum SessionFinalStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case completed
    case failed
    case interrupted
}

/// Emitted when a new session is created.
public struct SessionCreatedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let task: String
    public let model: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case task, model
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, task: String, model: String) {
        self.base = base
        self.sessionId = sessionId
        self.task = task
        self.model = model
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        task = try c.decode(String.self, forKey: .task)
        model = try c.decode(String.self, forKey: .model)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(task, forKey: .task)
        try c.encode(model, forKey: .model)
    }
}

/// Emitted when a session is restored from a SessionStore.
public struct SessionRestoredEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let messageCount: Int
    public let originalCreatedAt: Date

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case messageCount = "message_count"
        case originalCreatedAt = "original_created_at"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, messageCount: Int, originalCreatedAt: Date) {
        self.base = base
        self.sessionId = sessionId
        self.messageCount = messageCount
        self.originalCreatedAt = originalCreatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        messageCount = try c.decode(Int.self, forKey: .messageCount)
        originalCreatedAt = try c.decode(Date.self, forKey: .originalCreatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(messageCount, forKey: .messageCount)
        try c.encode(originalCreatedAt, forKey: .originalCreatedAt)
    }
}

/// Emitted when a session is closed (agent execution ends).
public struct SessionClosedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let finalStatus: SessionFinalStatus

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case finalStatus = "final_status"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, finalStatus: SessionFinalStatus) {
        self.base = base
        self.sessionId = sessionId
        self.finalStatus = finalStatus
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        finalStatus = try c.decode(SessionFinalStatus.self, forKey: .finalStatus)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(finalStatus, forKey: .finalStatus)
    }
}

/// Emitted when a session is auto-saved during the agent loop.
public struct SessionAutoSavedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let messageCount: Int

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case messageCount = "message_count"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, messageCount: Int) {
        self.base = base
        self.sessionId = sessionId
        self.messageCount = messageCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        messageCount = try c.decode(Int.self, forKey: .messageCount)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(messageCount, forKey: .messageCount)
    }
}

// MARK: - Agent Events

/// Emitted when an agent starts executing.
public struct AgentStartedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let task: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case task
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, task: String) {
        self.base = base
        self.sessionId = sessionId
        self.task = task
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        task = try c.decode(String.self, forKey: .task)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(task, forKey: .task)
    }
}

/// Emitted when an agent completes execution successfully.
public struct AgentCompletedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let totalSteps: Int
    public let durationMs: Int
    public let resultText: String?

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case totalSteps = "total_steps"
        case durationMs = "duration_ms"
        case resultText = "result_text"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, totalSteps: Int, durationMs: Int, resultText: String?) {
        self.base = base
        self.sessionId = sessionId
        self.totalSteps = totalSteps
        self.durationMs = durationMs
        self.resultText = resultText
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        totalSteps = try c.decode(Int.self, forKey: .totalSteps)
        durationMs = try c.decode(Int.self, forKey: .durationMs)
        resultText = try c.decodeIfPresent(String.self, forKey: .resultText)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(totalSteps, forKey: .totalSteps)
        try c.encode(durationMs, forKey: .durationMs)
        try c.encodeIfPresent(resultText, forKey: .resultText)
    }
}

/// Emitted when an agent fails during execution.
public struct AgentFailedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let error: String
    public let stepsCompleted: Int

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, error
        case sessionId = "session_id"
        case stepsCompleted = "steps_completed"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, error: String, stepsCompleted: Int) {
        self.base = base
        self.sessionId = sessionId
        self.error = error
        self.stepsCompleted = stepsCompleted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        error = try c.decode(String.self, forKey: .error)
        stepsCompleted = try c.decode(Int.self, forKey: .stepsCompleted)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(error, forKey: .error)
        try c.encode(stepsCompleted, forKey: .stepsCompleted)
    }
}

/// Emitted when an agent is interrupted during execution.
public struct AgentInterruptedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let stepsCompleted: Int

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case stepsCompleted = "steps_completed"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, stepsCompleted: Int) {
        self.base = base
        self.sessionId = sessionId
        self.stepsCompleted = stepsCompleted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        stepsCompleted = try c.decode(Int.self, forKey: .stepsCompleted)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(stepsCompleted, forKey: .stepsCompleted)
    }
}

/// Emitted when an agent resumes from an interrupted state.
public struct AgentResumedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let resumeContext: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case resumeContext = "resume_context"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, resumeContext: String) {
        self.base = base
        self.sessionId = sessionId
        self.resumeContext = resumeContext
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        resumeContext = try c.decode(String.self, forKey: .resumeContext)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(resumeContext, forKey: .resumeContext)
    }
}

// MARK: - Tool Events

/// Emitted when a tool starts executing.
public struct ToolStartedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let toolName: String
    public let toolUseId: String
    public let input: String?

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case toolName = "tool_name"
        case toolUseId = "tool_use_id"
        case input
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, toolName: String, toolUseId: String, input: String?) {
        self.base = base
        self.sessionId = sessionId
        self.toolName = toolName
        self.toolUseId = toolUseId
        self.input = input
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        toolName = try c.decode(String.self, forKey: .toolName)
        toolUseId = try c.decode(String.self, forKey: .toolUseId)
        input = try c.decodeIfPresent(String.self, forKey: .input)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(toolName, forKey: .toolName)
        try c.encode(toolUseId, forKey: .toolUseId)
        try c.encodeIfPresent(input, forKey: .input)
    }
}

/// Emitted when a tool produces streaming output.
public struct ToolStreamingEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let toolUseId: String
    public let chunk: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case toolUseId = "tool_use_id"
        case chunk
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, toolUseId: String, chunk: String) {
        self.base = base
        self.sessionId = sessionId
        self.toolUseId = toolUseId
        self.chunk = chunk
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        toolUseId = try c.decode(String.self, forKey: .toolUseId)
        chunk = try c.decode(String.self, forKey: .chunk)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(toolUseId, forKey: .toolUseId)
        try c.encode(chunk, forKey: .chunk)
    }
}

/// Emitted when a tool completes execution.
public struct ToolCompletedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let toolUseId: String
    public let toolName: String
    public let durationMs: Int
    public let isError: Bool

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case toolUseId = "tool_use_id"
        case toolName = "tool_name"
        case durationMs = "duration_ms"
        case isError = "is_error"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, toolUseId: String, toolName: String, durationMs: Int, isError: Bool) {
        self.base = base
        self.sessionId = sessionId
        self.toolUseId = toolUseId
        self.toolName = toolName
        self.durationMs = durationMs
        self.isError = isError
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        toolUseId = try c.decode(String.self, forKey: .toolUseId)
        toolName = try c.decode(String.self, forKey: .toolName)
        durationMs = try c.decode(Int.self, forKey: .durationMs)
        isError = try c.decode(Bool.self, forKey: .isError)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(toolUseId, forKey: .toolUseId)
        try c.encode(toolName, forKey: .toolName)
        try c.encode(durationMs, forKey: .durationMs)
        try c.encode(isError, forKey: .isError)
    }
}

/// Emitted when a tool execution fails.
public struct ToolFailedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let toolUseId: String
    public let toolName: String
    public let error: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, error
        case sessionId = "session_id"
        case toolUseId = "tool_use_id"
        case toolName = "tool_name"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, toolUseId: String, toolName: String, error: String) {
        self.base = base
        self.sessionId = sessionId
        self.toolUseId = toolUseId
        self.toolName = toolName
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        toolUseId = try c.decode(String.self, forKey: .toolUseId)
        toolName = try c.decode(String.self, forKey: .toolName)
        error = try c.decode(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(toolUseId, forKey: .toolUseId)
        try c.encode(toolName, forKey: .toolName)
        try c.encode(error, forKey: .error)
    }
}

// MARK: - LLM Events

/// Emitted when an LLM API request starts.
public struct LLMRequestStartedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let model: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case model
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, model: String) {
        self.base = base
        self.sessionId = sessionId
        self.model = model
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        model = try c.decode(String.self, forKey: .model)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(model, forKey: .model)
    }
}

/// Emitted when an LLM response is received.
public struct LLMResponseReceivedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let model: String
    public let durationMs: Int

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case model
        case durationMs = "duration_ms"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, model: String, durationMs: Int) {
        self.base = base
        self.sessionId = sessionId
        self.model = model
        self.durationMs = durationMs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        model = try c.decode(String.self, forKey: .model)
        durationMs = try c.decode(Int.self, forKey: .durationMs)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(model, forKey: .model)
        try c.encode(durationMs, forKey: .durationMs)
    }
}

/// Emitted when token/cost data is available for an LLM call.
public struct LLMCostEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let estimatedCostUsd: Double

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case estimatedCostUsd = "estimated_cost_usd"
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, model: String, inputTokens: Int, outputTokens: Int, cacheCreationInputTokens: Int?, cacheReadInputTokens: Int?, estimatedCostUsd: Double) {
        self.base = base
        self.sessionId = sessionId
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.estimatedCostUsd = estimatedCostUsd
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        model = try c.decode(String.self, forKey: .model)
        inputTokens = try c.decode(Int.self, forKey: .inputTokens)
        outputTokens = try c.decode(Int.self, forKey: .outputTokens)
        cacheCreationInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens)
        cacheReadInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens)
        estimatedCostUsd = try c.decode(Double.self, forKey: .estimatedCostUsd)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(model, forKey: .model)
        try c.encode(inputTokens, forKey: .inputTokens)
        try c.encode(outputTokens, forKey: .outputTokens)
        try c.encodeIfPresent(cacheCreationInputTokens, forKey: .cacheCreationInputTokens)
        try c.encodeIfPresent(cacheReadInputTokens, forKey: .cacheReadInputTokens)
        try c.encode(estimatedCostUsd, forKey: .estimatedCostUsd)
    }
}
