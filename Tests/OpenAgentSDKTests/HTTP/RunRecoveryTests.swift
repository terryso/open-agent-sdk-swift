import XCTest
@testable import OpenAgentSDK

final class RunRecoveryTests: TempDirTestCase {

    private var persistence: RunPersistenceService!

    override func setUp() {
        super.setUp()
        persistence = RunPersistenceService(baseDirectory: tempDir)
    }

    // MARK: - Running → Failed

    func testRunningRunsMarkedFailed() async throws {
        let run = TrackedRun(runId: "running-1", status: .running, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "running-1")
        XCTAssertEqual(recovered?.status, .failed)
        XCTAssertEqual(recovered?.error, "server interrupted")
    }

    // MARK: - Queued → Failed

    func testQueuedRunsMarkedFailed() async throws {
        let run = TrackedRun(runId: "queued-1", status: .queued, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "queued-1")
        XCTAssertEqual(recovered?.status, .failed)
    }

    // MARK: - Completed → Preserved

    func testCompletedRunsPreserved() async throws {
        let run = TrackedRun(runId: "completed-1", status: .completed, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "completed-1")
        XCTAssertEqual(recovered?.status, .completed)
        XCTAssertNil(recovered?.error)
    }

    // MARK: - Failed → Preserved

    func testFailedRunsPreserved() async throws {
        let run = TrackedRun(runId: "failed-1", status: .failed, task: "test", createdAt: "2026-01-01T00:00:00Z", error: "original error")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "failed-1")
        XCTAssertEqual(recovered?.status, .failed)
        XCTAssertEqual(recovered?.error, "original error")
    }

    // MARK: - Cancelled → Preserved

    func testCancelledRunsPreserved() async throws {
        let run = TrackedRun(runId: "cancelled-1", status: .cancelled, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "cancelled-1")
        XCTAssertEqual(recovered?.status, .cancelled)
    }

    // MARK: - Intervention Needed → Preserved

    func testInterventionNeededRunsPreserved() async throws {
        let run = TrackedRun(runId: "intervention-1", status: .interventionNeeded, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "intervention-1")
        XCTAssertEqual(recovered?.status, .interventionNeeded)
    }

    // MARK: - Empty Directory

    func testRecoveryWithNoPersistedRuns() async {
        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let runs = await tracker.listRuns()
        XCTAssertTrue(runs.isEmpty)
    }

    // MARK: - Events Restored to Replay Buffer

    func testEventsRestoredToReplayBuffer() async throws {
        let run = TrackedRun(runId: "events-1", status: .completed, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let event = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))
        try persistence.persistEvent(runId: "events-1", event: event)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let buffer = await broadcaster.getReplayBuffer(runId: "events-1")
        XCTAssertEqual(buffer.count, 1)
    }

    // MARK: - Mixed Status Recovery

    func testMixedStatusRecovery() async throws {
        // Persist runs with different statuses
        let running = TrackedRun(runId: "mixed-running", status: .running, task: "t1", createdAt: "2026-01-01T00:00:00Z")
        let completed = TrackedRun(runId: "mixed-completed", status: .completed, task: "t2", createdAt: "2026-01-01T00:00:00Z")
        let intervention = TrackedRun(runId: "mixed-intervention", status: .interventionNeeded, task: "t3", createdAt: "2026-01-01T00:00:00Z")
        let failed = TrackedRun(runId: "mixed-failed", status: .failed, task: "t4", createdAt: "2026-01-01T00:00:00Z")

        try persistence.persistRecord(running)
        try persistence.persistRecord(completed)
        try persistence.persistRecord(intervention)
        try persistence.persistRecord(failed)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        // Running → failed
        let recoveredRunning = await tracker.getRun(runId: "mixed-running")
        XCTAssertEqual(recoveredRunning?.status, .failed)
        XCTAssertEqual(recoveredRunning?.error, "server interrupted")

        // Completed → preserved
        let recoveredCompleted = await tracker.getRun(runId: "mixed-completed")
        XCTAssertEqual(recoveredCompleted?.status, .completed)

        // Intervention → preserved
        let recoveredIntervention = await tracker.getRun(runId: "mixed-intervention")
        XCTAssertEqual(recoveredIntervention?.status, .interventionNeeded)

        // Failed → preserved
        let recoveredFailed = await tracker.getRun(runId: "mixed-failed")
        XCTAssertEqual(recoveredFailed?.status, .failed)
    }

    func testRunningRunGetsServerInterruptedError() async throws {
        let run = TrackedRun(runId: "interrupted-run", status: .running, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let recovered = await tracker.getRun(runId: "interrupted-run")
        XCTAssertEqual(recovered?.error, "server interrupted")
        XCTAssertNotNil(recovered?.updatedAt)
    }

    func testMultipleEventsRestoredForSingleRun() async throws {
        let run = TrackedRun(runId: "multi-events", status: .completed, task: "test", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        try persistence.persistEvent(runId: "multi-events", event: .stepStarted(StepStartedData(stepIndex: 0, tool: "Bash")))
        try persistence.persistEvent(runId: "multi-events", event: .stepCompleted(StepCompletedData(stepIndex: 0, tool: "Bash", success: true)))
        try persistence.persistEvent(runId: "multi-events", event: .runCompleted(RunCompletedData(runId: "multi-events", finalStatus: "completed", totalSteps: 1)))

        let tracker = RunTracker()
        let broadcaster = EventBroadcaster()
        await RunRecoveryService.recover(from: tracker, persistenceService: persistence, eventBroadcaster: broadcaster)

        let buffer = await broadcaster.getReplayBuffer(runId: "multi-events")
        XCTAssertEqual(buffer.count, 3)
    }
}
