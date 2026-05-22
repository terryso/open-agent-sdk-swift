import Foundation
import Hummingbird

// MARK: - APIRunStatus

/// Run status exposed via the HTTP API.
public enum APIRunStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case queued
    case running
    case completed
    case failed
    case cancelled
    case interventionNeeded = "intervention_needed"
    case userTakeover = "user_takeover"
    case resuming
}

// MARK: - CreateRunRequest

/// Request body for `POST /v1/runs`.
public struct CreateRunRequest: Codable, Equatable, Sendable {
    public let task: String
    public let maxSteps: Int?
    public let maxBatches: Int?
    public let allowForeground: Bool?

    enum CodingKeys: String, CodingKey {
        case task
        case maxSteps = "max_steps"
        case maxBatches = "max_batches"
        case allowForeground = "allow_foreground"
    }

    public init(task: String, maxSteps: Int? = nil, maxBatches: Int? = nil, allowForeground: Bool? = nil) {
        self.task = task
        self.maxSteps = maxSteps
        self.maxBatches = maxBatches
        self.allowForeground = allowForeground
    }
}

// MARK: - RunResponse

/// Response body for `POST /v1/runs` and `GET /v1/runs/{id}`.
public struct RunResponse: Codable, Equatable, Sendable, ResponseEncodable {
    public let runId: String
    public let status: APIRunStatus
    public let task: String
    public let createdAt: String
    public let updatedAt: String?
    public let totalSteps: Int?
    public let durationMs: Int?
    public let ok: Bool?
    public let error: String?
    public let steps: [StepSummary]?
    public let startedAt: String?
    public let endedAt: String?
    public let exitCode: Int?
    public let result: RunResult?
    public let intervention: InterventionData?
    public let costTelemetry: TokenUsage?
    public let schemaVersion: Int?

    enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case status
        case task
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case totalSteps = "total_steps"
        case durationMs = "duration_ms"
        case ok
        case error
        case steps
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case exitCode = "exit_code"
        case result
        case intervention
        case costTelemetry = "cost_telemetry"
        case schemaVersion = "schema_version"
    }

    public init(
        runId: String,
        status: APIRunStatus,
        task: String,
        createdAt: String,
        updatedAt: String? = nil,
        totalSteps: Int? = nil,
        durationMs: Int? = nil,
        ok: Bool? = nil,
        error: String? = nil,
        steps: [StepSummary]? = nil,
        startedAt: String? = nil,
        endedAt: String? = nil,
        exitCode: Int? = nil,
        result: RunResult? = nil,
        intervention: InterventionData? = nil,
        costTelemetry: TokenUsage? = nil,
        schemaVersion: Int? = nil
    ) {
        self.runId = runId
        self.status = status
        self.task = task
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalSteps = totalSteps
        self.durationMs = durationMs
        self.ok = ok
        self.error = error
        self.steps = steps
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exitCode = exitCode
        self.result = result
        self.intervention = intervention
        self.costTelemetry = costTelemetry
        self.schemaVersion = schemaVersion
    }
}

// MARK: - HealthResponse

/// Response body for `GET /v1/health`.
public struct HealthResponse: Codable, Equatable, Sendable, ResponseEncodable {
    public let status: String
    public let version: String

    public init(status: String = "ok", version: String = "1.0.0") {
        self.status = status
        self.version = version
    }
}

// MARK: - APIErrorResponse

/// Standard error response format for all API errors.
public struct APIErrorResponse: Codable, Equatable, Sendable, ResponseEncodable {
    public let error: String
    public let message: String

    public init(error: String, message: String) {
        self.error = error
        self.message = message
    }
}

// MARK: - SSE Event Data Types

/// Data payload for a `step_started` SSE event.
public struct StepStartedData: Codable, Equatable, Sendable {
    public let stepIndex: Int
    public let tool: String

    enum CodingKeys: String, CodingKey {
        case stepIndex = "step_index"
        case tool
    }

    public init(stepIndex: Int, tool: String) {
        self.stepIndex = stepIndex
        self.tool = tool
    }
}

/// Data payload for a `step_completed` SSE event.
public struct StepCompletedData: Codable, Equatable, Sendable {
    public let stepIndex: Int
    public let tool: String
    public let success: Bool
    public let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case stepIndex = "step_index"
        case tool
        case success
        case durationMs = "duration_ms"
    }

    public init(stepIndex: Int, tool: String, success: Bool, durationMs: Int? = nil) {
        self.stepIndex = stepIndex
        self.tool = tool
        self.success = success
        self.durationMs = durationMs
    }
}

/// Data payload for a `run_completed` SSE event.
public struct RunCompletedData: Codable, Equatable, Sendable {
    public let runId: String
    public let finalStatus: String
    public let totalSteps: Int
    public let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case finalStatus = "final_status"
        case totalSteps = "total_steps"
        case durationMs = "duration_ms"
    }

    public init(runId: String, finalStatus: String, totalSteps: Int, durationMs: Int? = nil) {
        self.runId = runId
        self.finalStatus = finalStatus
        self.totalSteps = totalSteps
        self.durationMs = durationMs
    }
}

// MARK: - AgentSSEEvent

/// SSE event types emitted during agent execution via the HTTP API.
/// Named `AgentSSEEvent` to avoid conflict with the existing `SSEEvent` in the API layer.
public enum AgentSSEEvent: Equatable, Sendable {
    case stepStarted(StepStartedData)
    case stepCompleted(StepCompletedData)
    case runCompleted(RunCompletedData)

    /// The SSE event type name string.
    public var eventType: String {
        switch self {
        case .stepStarted: return "step_started"
        case .stepCompleted: return "step_completed"
        case .runCompleted: return "run_completed"
        }
    }

    /// Encode this event as an SSE-formatted text string.
    public func encodeToSSE(sequenceId: Int) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data: Data
        switch self {
        case .stepStarted(let d): data = try encoder.encode(d)
        case .stepCompleted(let d): data = try encoder.encode(d)
        case .runCompleted(let d): data = try encoder.encode(d)
        }

        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        return "event: \(eventType)\ndata: \(jsonString)\nid: \(sequenceId)\n\n"
    }
}

// MARK: - PersistedSSEEvent

/// Codable wrapper for persisting SSEEvent to JSONL.
struct PersistedSSEEvent: Codable, Equatable, Sendable {
    let eventType: String
    let stepStarted: StepStartedData?
    let stepCompleted: StepCompletedData?
    let runCompleted: RunCompletedData?

    init(from event: AgentSSEEvent) {
        self.eventType = event.eventType
        switch event {
        case .stepStarted(let data):
            self.stepStarted = data
            self.stepCompleted = nil
            self.runCompleted = nil
        case .stepCompleted(let data):
            self.stepStarted = nil
            self.stepCompleted = data
            self.runCompleted = nil
        case .runCompleted(let data):
            self.stepStarted = nil
            self.stepCompleted = nil
            self.runCompleted = data
        }
    }

    func toSSEEvent() -> AgentSSEEvent? {
        switch eventType {
        case "step_started":
            guard let data = stepStarted else { return nil }
            return .stepStarted(data)
        case "step_completed":
            guard let data = stepCompleted else { return nil }
            return .stepCompleted(data)
        case "run_completed":
            guard let data = runCompleted else { return nil }
            return .runCompleted(data)
        default:
            return nil
        }
    }
}

// MARK: - StepSummary

/// Summary of a single executed step within a run.
public struct StepSummary: Codable, Equatable, Sendable {
    public let index: Int
    public let tool: String
    public let purpose: String
    public let success: Bool

    public init(index: Int, tool: String, purpose: String, success: Bool) {
        self.index = index
        self.tool = tool
        self.purpose = purpose
        self.success = success
    }
}

// MARK: - RunResult

/// Structured result payload for a completed run.
public struct RunResult: Codable, Equatable, Sendable {
    public let kind: String
    public let title: String
    public let body: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case body
        case createdAt = "created_at"
    }

    public init(kind: String, title: String, body: String, createdAt: String) {
        self.kind = kind
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

// MARK: - InterventionData

/// Intervention payload when a run enters a paused/takeover state.
public struct InterventionData: Codable, Equatable, Sendable {
    public let reason: String
    public let availableActions: [String]
    public let blockingIssue: String

    enum CodingKeys: String, CodingKey {
        case reason
        case availableActions = "available_actions"
        case blockingIssue = "blocking_issue"
    }

    public init(reason: String, availableActions: [String], blockingIssue: String) {
        self.reason = reason
        self.availableActions = availableActions
        self.blockingIssue = blockingIssue
    }
}

// MARK: - TrackedRun

/// Internal representation of a tracked run, stored in RunTracker.
public struct TrackedRun: Codable, Equatable, Sendable {
    public let runId: String
    public var status: APIRunStatus
    public let task: String
    public let createdAt: String
    public var updatedAt: String?
    public var totalSteps: Int
    public var durationMs: Int?
    public var resultText: String?
    public var error: String?
    public var steps: [StepSummary]?
    public var startedAt: String?
    public var endedAt: String?
    public var exitCode: Int?
    public var result: RunResult?
    public var intervention: InterventionData?
    public var costTelemetry: TokenUsage?

    public init(
        runId: String,
        status: APIRunStatus,
        task: String,
        createdAt: String,
        updatedAt: String? = nil,
        totalSteps: Int = 0,
        durationMs: Int? = nil,
        resultText: String? = nil,
        error: String? = nil,
        steps: [StepSummary]? = nil,
        startedAt: String? = nil,
        endedAt: String? = nil,
        exitCode: Int? = nil,
        result: RunResult? = nil,
        intervention: InterventionData? = nil,
        costTelemetry: TokenUsage? = nil
    ) {
        self.runId = runId
        self.status = status
        self.task = task
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalSteps = totalSteps
        self.durationMs = durationMs
        self.resultText = resultText
        self.error = error
        self.steps = steps
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exitCode = exitCode
        self.result = result
        self.intervention = intervention
        self.costTelemetry = costTelemetry
    }

    public func toResponse() -> RunResponse {
        RunResponse(
            runId: runId,
            status: status,
            task: task,
            createdAt: createdAt,
            updatedAt: updatedAt,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            durationMs: durationMs,
            ok: status == .completed,
            error: error,
            steps: steps,
            startedAt: startedAt,
            endedAt: endedAt,
            exitCode: exitCode,
            result: result,
            intervention: intervention,
            costTelemetry: costTelemetry,
            schemaVersion: 1
        )
    }
}
