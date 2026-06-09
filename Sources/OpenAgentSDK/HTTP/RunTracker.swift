import Foundation

// MARK: - RunTrackerError

/// Errors thrown by RunTracker for invalid state transitions.
public enum RunTrackerError: Error, Equatable {
    case runNotFound(runId: String)
    case invalidTransition(from: APIRunStatus, to: APIRunStatus)
}

// MARK: - RunTracker

/// Actor-based run lifecycle state machine.
/// Tracks runs from submission through completion with validated state transitions.
public actor RunTracker {

    // MARK: - Properties

    private var runs: [String: TrackedRun] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Run Lifecycle

    /// Submit a new run and return the created TrackedRun.
    public func submitRun(task: String) -> TrackedRun {
        let runId = generateRunId()
        let now = makeISO8601DateFormatter().string(from: Date())

        let run = TrackedRun(
            runId: runId,
            status: .queued,
            task: task,
            createdAt: now
        )
        runs[runId] = run
        return run
    }

    /// Transition a run from `queued` to `running`.
    public func startRun(runId: String) throws {
        try transitionRun(runId: runId, from: .queued, to: .running) { _ in }
    }

    /// Transition a run from `running` to `completed`.
    public func completeRun(runId: String, resultText: String?, totalSteps: Int, durationMs: Int?) throws {
        try transitionRun(runId: runId, from: .running, to: .completed) { run in
            run.resultText = resultText
            run.totalSteps = totalSteps
            run.durationMs = durationMs
        }
    }

    /// Transition a run from `running` to `failed`.
    public func failRun(runId: String, error: String) throws {
        try transitionRun(runId: runId, from: .running, to: .failed) { run in
            run.error = error
        }
    }

    /// Transition a run from `running` to `cancelled`.
    public func cancelRun(runId: String) throws {
        try transitionRun(runId: runId, from: .running, to: .cancelled) { _ in }
    }

    /// Flexible update for run fields, used by runHandler callbacks.
    /// Only updates fields that are non-nil. Does not validate state transitions.
    public func updateRun(
        runId: String,
        status: APIRunStatus? = nil,
        totalSteps: Int? = nil,
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
        guard runs[runId] != nil else { return }
        if let status { runs[runId]?.status = status }
        if let totalSteps { runs[runId]?.totalSteps = totalSteps }
        if let durationMs { runs[runId]?.durationMs = durationMs }
        if let resultText { runs[runId]?.resultText = resultText }
        if let error { runs[runId]?.error = error }
        if let steps { runs[runId]?.steps = steps }
        if let startedAt { runs[runId]?.startedAt = startedAt }
        if let endedAt { runs[runId]?.endedAt = endedAt }
        if let exitCode { runs[runId]?.exitCode = exitCode }
        if let result { runs[runId]?.result = result }
        if let intervention { runs[runId]?.intervention = intervention }
        if let costTelemetry { runs[runId]?.costTelemetry = costTelemetry }
        runs[runId]?.updatedAt = currentTimestamp()
    }

    // MARK: - Query

    /// Retrieve a run by its ID.
    public func getRun(runId: String) -> TrackedRun? {
        runs[runId]
    }

    /// List all tracked runs, sorted by creation time (newest first).
    public func listRuns(limit: Int? = nil) -> [TrackedRun] {
        let sorted = runs.values.sorted { $0.createdAt > $1.createdAt }
        if let limit { return Array(sorted.prefix(limit)) }
        return sorted
    }

    // MARK: - Recovery

    /// Restore a persisted run into memory. Called during server startup recovery.
    public func restoreRun(_ run: TrackedRun) {
        runs[run.runId] = run
    }

    // MARK: - Private Helpers

    /// Validates a state transition and applies it with a timestamp update.
    /// Callers pass a closure to set transition-specific fields on the run.
    private func transitionRun(
        runId: String,
        from expectedStatus: APIRunStatus,
        to newStatus: APIRunStatus,
        _ configure: (inout TrackedRun) -> Void
    ) throws {
        guard var run = runs[runId] else {
            throw RunTrackerError.runNotFound(runId: runId)
        }
        guard run.status == expectedStatus else {
            throw RunTrackerError.invalidTransition(from: run.status, to: newStatus)
        }
        run.status = newStatus
        run.updatedAt = currentTimestamp()
        configure(&run)
        runs[runId] = run
    }

    private func generateRunId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let datePart = formatter.string(from: Date())
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let randomPart = String((0..<6).map { _ in chars.randomElement()! })
        return "\(datePart)-\(randomPart)"
    }

    private func currentTimestamp() -> String {
        return makeISO8601DateFormatter().string(from: Date())
    }
}
