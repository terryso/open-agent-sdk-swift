import XCTest
@testable import OpenAgentSDK

final class RunPersistenceTests: TempDirTestCase {

    private var persistence: RunPersistenceService!

    override func setUp() {
        super.setUp()
        persistence = RunPersistenceService(baseDirectory: tempDir)
    }

    // MARK: - Record Persistence

    func testPersistAndLoadRecord() throws {
        let run = TrackedRun(
            runId: "test-run-001",
            status: .running,
            task: "analyze data",
            createdAt: "2026-01-01T00:00:00Z"
        )
        try persistence.persistRecord(run)

        let loaded = persistence.loadRecord(runId: "test-run-001")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.runId, "test-run-001")
        XCTAssertEqual(loaded?.status, .running)
        XCTAssertEqual(loaded?.task, "analyze data")
    }

    func testPersistRecordAtomically() throws {
        let run = TrackedRun(
            runId: "test-atomic",
            status: .completed,
            task: "test",
            createdAt: "2026-01-01T00:00:00Z"
        )
        try persistence.persistRecord(run)

        // Verify file exists
        let dir = persistence.runDirectory(runId: "test-atomic")
        let path = (dir as NSString).appendingPathComponent("api-output.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    // MARK: - Event Persistence

    func testPersistAndLoadEvents() throws {
        let runId = "test-events-001"
        let event1 = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))
        let event2 = AgentSSEEvent.stepCompleted(StepCompletedData(stepIndex: 0, tool: "Bash", success: true))
        let event3 = AgentSSEEvent.runCompleted(RunCompletedData(runId: runId, finalStatus: "completed", totalSteps: 1))

        try persistence.persistEvent(runId: runId, event: event1)
        try persistence.persistEvent(runId: runId, event: event2)
        try persistence.persistEvent(runId: runId, event: event3)

        let loaded = persistence.loadEvents(runId: runId)
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0], event1)
        XCTAssertEqual(loaded[1], event2)
        XCTAssertEqual(loaded[2], event3)
    }

    func testJSONLAppend() throws {
        let runId = "test-append-001"
        let event1 = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))
        let event2 = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 1, tool: "Read"))

        try persistence.persistEvent(runId: runId, event: event1)
        try persistence.persistEvent(runId: runId, event: event2)

        let loaded = persistence.loadEvents(runId: runId)
        XCTAssertEqual(loaded.count, 2)
    }

    // MARK: - Load All

    func testLoadAllPersistedRuns() throws {
        let run1 = TrackedRun(runId: "run-a", status: .completed, task: "task a", createdAt: "2026-01-01T00:00:00Z")
        let run2 = TrackedRun(runId: "run-b", status: .failed, task: "task b", createdAt: "2026-01-01T00:01:00Z")

        try persistence.persistRecord(run1)
        try persistence.persistRecord(run2)

        let all = persistence.loadAllPersistedRuns()
        XCTAssertEqual(all.count, 2)
    }

    // MARK: - Safe Wrappers

    func testPersistRecordSafelyDoesNotThrow() {
        let run = TrackedRun(runId: "safe-run", status: .queued, task: "safe", createdAt: "2026-01-01T00:00:00Z")
        // Should not throw even with valid path
        persistence.persistRecordSafely(run)
    }

    func testPersistEventSafelyDoesNotThrow() {
        let event = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))
        persistence.persistEventSafely(runId: "safe-event", event: event)
    }

    // MARK: - Load Nonexistent

    func testLoadNonexistentRecordReturnsNil() {
        let loaded = persistence.loadRecord(runId: "nonexistent")
        XCTAssertNil(loaded)
    }

    func testLoadNonexistentEventsReturnsEmpty() {
        let loaded = persistence.loadEvents(runId: "nonexistent")
        XCTAssertTrue(loaded.isEmpty)
    }

    func testLoadAllFromEmptyDirReturnsEmpty() {
        let all = persistence.loadAllPersistedRuns()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Edge Cases

    func testPersistRecordOverwrite() throws {
        let run = TrackedRun(runId: "overwrite-test", status: .queued, task: "original", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(run)

        let updated = TrackedRun(runId: "overwrite-test", status: .completed, task: "updated", createdAt: "2026-01-01T00:00:00Z")
        try persistence.persistRecord(updated)

        let loaded = persistence.loadRecord(runId: "overwrite-test")
        XCTAssertEqual(loaded?.status, .completed)
        XCTAssertEqual(loaded?.task, "updated")
    }

    func testLoadEventsWithEmptyJSONLReturnsEmpty() throws {
        // Create the run directory but with an empty events file
        let dir = persistence.runDirectory(runId: "empty-events")
        let path = (dir as NSString).appendingPathComponent("api-events.jsonl")
        try Data().write(to: URL(fileURLWithPath: path))

        let events = persistence.loadEvents(runId: "empty-events")
        XCTAssertTrue(events.isEmpty)
    }

    func testPersistAllEventTypes() throws {
        let runId = "all-event-types"
        let events: [AgentSSEEvent] = [
            .stepStarted(StepStartedData(stepIndex: 0, tool: "Bash")),
            .stepCompleted(StepCompletedData(stepIndex: 0, tool: "Bash", success: true, durationMs: 100)),
            .runCompleted(RunCompletedData(runId: runId, finalStatus: "completed", totalSteps: 1, durationMs: 500)),
        ]

        for event in events {
            try persistence.persistEvent(runId: runId, event: event)
        }

        let loaded = persistence.loadEvents(runId: runId)
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0], events[0])
        XCTAssertEqual(loaded[1], events[1])
        XCTAssertEqual(loaded[2], events[2])
    }

    func testRunDirectoryCreatesParentDirs() throws {
        let runId = "nested-dir-test"
        let dir = persistence.runDirectory(runId: runId)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir))
    }
}
