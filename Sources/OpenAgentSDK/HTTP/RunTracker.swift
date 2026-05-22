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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())

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
        guard var run = runs[runId] else {
            throw RunTrackerError.runNotFound(runId: runId)
        }
        guard run.status == .queued else {
            throw RunTrackerError.invalidTransition(from: run.status, to: .running)
        }
        run.status = .running
        run.updatedAt = currentTimestamp()
        runs[runId] = run
    }

    /// Transition a run from `running` to `completed`.
    public func completeRun(runId: String, resultText: String?, totalSteps: Int, durationMs: Int?) throws {
        guard var run = runs[runId] else {
            throw RunTrackerError.runNotFound(runId: runId)
        }
        guard run.status == .running else {
            throw RunTrackerError.invalidTransition(from: run.status, to: .completed)
        }
        run.status = .completed
        run.updatedAt = currentTimestamp()
        run.resultText = resultText
        run.totalSteps = totalSteps
        run.durationMs = durationMs
        runs[runId] = run
    }

    /// Transition a run from `running` to `failed`.
    public func failRun(runId: String, error: String) throws {
        guard var run = runs[runId] else {
            throw RunTrackerError.runNotFound(runId: runId)
        }
        guard run.status == .running else {
            throw RunTrackerError.invalidTransition(from: run.status, to: .failed)
        }
        run.status = .failed
        run.updatedAt = currentTimestamp()
        run.error = error
        runs[runId] = run
    }

    /// Transition a run from `running` to `cancelled`.
    public func cancelRun(runId: String) throws {
        guard var run = runs[runId] else {
            throw RunTrackerError.runNotFound(runId: runId)
        }
        guard run.status == .running else {
            throw RunTrackerError.invalidTransition(from: run.status, to: .cancelled)
        }
        run.status = .cancelled
        run.updatedAt = currentTimestamp()
        runs[runId] = run
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

    private func generateRunId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let datePart = formatter.string(from: Date())
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let randomPart = String((0..<6).map { _ in chars.randomElement()! })
        return "\(datePart)-\(randomPart)"
    }

    private func currentTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
