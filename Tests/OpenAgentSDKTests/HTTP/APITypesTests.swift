import XCTest
@testable import OpenAgentSDK

final class APITypesTests: XCTestCase {

    // MARK: - APIRunStatus

    func testAPIRunStatusAllCases() {
        let allCases = APIRunStatus.allCases
        XCTAssertEqual(allCases.count, 8)
        XCTAssertTrue(allCases.contains(.queued))
        XCTAssertTrue(allCases.contains(.running))
        XCTAssertTrue(allCases.contains(.completed))
        XCTAssertTrue(allCases.contains(.failed))
        XCTAssertTrue(allCases.contains(.cancelled))
        XCTAssertTrue(allCases.contains(.interventionNeeded))
        XCTAssertTrue(allCases.contains(.userTakeover))
        XCTAssertTrue(allCases.contains(.resuming))
    }

    func testAPIRunStatusRawValues() {
        XCTAssertEqual(APIRunStatus.queued.rawValue, "queued")
        XCTAssertEqual(APIRunStatus.running.rawValue, "running")
        XCTAssertEqual(APIRunStatus.completed.rawValue, "completed")
        XCTAssertEqual(APIRunStatus.failed.rawValue, "failed")
        XCTAssertEqual(APIRunStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(APIRunStatus.interventionNeeded.rawValue, "intervention_needed")
        XCTAssertEqual(APIRunStatus.userTakeover.rawValue, "user_takeover")
        XCTAssertEqual(APIRunStatus.resuming.rawValue, "resuming")
    }

    func testAPIRunStatusCodableRoundTrip() throws {
        for status in APIRunStatus.allCases {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(APIRunStatus.self, from: encoded)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - CreateRunRequest

    func testCreateRunRequestCodableRoundTrip() throws {
        let request = CreateRunRequest(task: "analyze data", maxSteps: 10, maxBatches: 3)
        let encoded = try JSONEncoder().encode(request)
        let jsonString = String(data: encoded, encoding: .utf8)!

        // Verify snake_case keys
        XCTAssertTrue(jsonString.contains("\"task\""))
        XCTAssertTrue(jsonString.contains("\"max_steps\""))
        XCTAssertTrue(jsonString.contains("\"max_batches\""))

        let decoded = try JSONDecoder().decode(CreateRunRequest.self, from: encoded)
        XCTAssertEqual(decoded, request)
    }

    func testCreateRunRequestMinimal() throws {
        let request = CreateRunRequest(task: "simple task")
        let encoded = try JSONEncoder().encode(request)
        let jsonString = String(data: encoded, encoding: .utf8)!

        // Optional fields should be absent when nil
        XCTAssertFalse(jsonString.contains("max_steps"))
        XCTAssertFalse(jsonString.contains("max_batches"))

        let decoded = try JSONDecoder().decode(CreateRunRequest.self, from: encoded)
        XCTAssertEqual(decoded.task, "simple task")
        XCTAssertNil(decoded.maxSteps)
        XCTAssertNil(decoded.maxBatches)
    }

    // MARK: - RunResponse

    func testRunResponseCodableRoundTrip() throws {
        let response = RunResponse(
            runId: "run-123",
            status: .completed,
            task: "test task",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:01:00Z"
        )
        let encoded = try JSONEncoder().encode(response)
        let jsonString = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"run_id\""))
        XCTAssertTrue(jsonString.contains("\"created_at\""))
        XCTAssertTrue(jsonString.contains("\"updated_at\""))

        let decoded = try JSONDecoder().decode(RunResponse.self, from: encoded)
        XCTAssertEqual(decoded, response)
    }

    // MARK: - HealthResponse

    func testHealthResponseDefaults() {
        let response = HealthResponse()
        XCTAssertEqual(response.status, "ok")
        XCTAssertEqual(response.version, "1.0.0")
    }

    func testHealthResponseCodableRoundTrip() throws {
        let response = HealthResponse(status: "degraded", version: "2.0.0")
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(HealthResponse.self, from: encoded)
        XCTAssertEqual(decoded, response)
    }

    // MARK: - APIErrorResponse

    func testAPIErrorResponseCodableRoundTrip() throws {
        let error = APIErrorResponse(error: "not_found", message: "Run not found: xyz")
        let encoded = try JSONEncoder().encode(error)
        let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: encoded)
        XCTAssertEqual(decoded, error)
    }

    // MARK: - StepStartedData

    func testStepStartedDataCodingKeys() throws {
        let data = StepStartedData(stepIndex: 2, tool: "Bash")
        let encoded = try JSONEncoder().encode(data)
        let jsonString = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"step_index\""))
        XCTAssertTrue(jsonString.contains("\"tool\""))
    }

    // MARK: - StepCompletedData

    func testStepCompletedDataCodingKeys() throws {
        let data = StepCompletedData(stepIndex: 1, tool: "Read", success: true, durationMs: 500)
        let encoded = try JSONEncoder().encode(data)
        let jsonString = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"step_index\""))
        XCTAssertTrue(jsonString.contains("\"duration_ms\""))
        XCTAssertTrue(jsonString.contains("\"success\""))
    }

    func testStepCompletedDataWithoutDuration() throws {
        let data = StepCompletedData(stepIndex: 0, tool: "Bash", success: false)
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(StepCompletedData.self, from: encoded)
        XCTAssertEqual(decoded, data)
        XCTAssertNil(decoded.durationMs)
    }

    // MARK: - RunCompletedData

    func testRunCompletedDataCodingKeys() throws {
        let data = RunCompletedData(
            runId: "run-abc",
            finalStatus: "completed",
            totalSteps: 5,
            durationMs: 3000
        )
        let encoded = try JSONEncoder().encode(data)
        let jsonString = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"run_id\""))
        XCTAssertTrue(jsonString.contains("\"final_status\""))
        XCTAssertTrue(jsonString.contains("\"total_steps\""))
        XCTAssertTrue(jsonString.contains("\"duration_ms\""))
    }

    // MARK: - AgentSSEEvent.encodeToSSE()

    func testStepStartedSSEEncoding() throws {
        let event = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))
        let sseString = try event.encodeToSSE(sequenceId: 1)

        XCTAssertTrue(sseString.hasPrefix("event: step_started\n"))
        XCTAssertTrue(sseString.contains("data: "))
        XCTAssertTrue(sseString.contains("id: 1\n"))
        XCTAssertTrue(sseString.hasSuffix("\n\n"))
    }

    func testStepCompletedSSEEncoding() throws {
        let event = AgentSSEEvent.stepCompleted(
            StepCompletedData(stepIndex: 2, tool: "Read", success: true)
        )
        let sseString = try event.encodeToSSE(sequenceId: 5)

        XCTAssertTrue(sseString.hasPrefix("event: step_completed\n"))
        XCTAssertTrue(sseString.contains("id: 5\n"))
    }

    func testRunCompletedSSEEncoding() throws {
        let event = AgentSSEEvent.runCompleted(
            RunCompletedData(runId: "run-42", finalStatus: "completed", totalSteps: 3)
        )
        let sseString = try event.encodeToSSE(sequenceId: 10)

        XCTAssertTrue(sseString.hasPrefix("event: run_completed\n"))
        XCTAssertTrue(sseString.contains("id: 10\n"))
    }

    func testSSEEncodingContainsValidJSON() throws {
        let event = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))
        let sseString = try event.encodeToSSE(sequenceId: 1)

        // Extract the data line
        let lines = sseString.components(separatedBy: "\n")
        let dataLine = lines.first { $0.hasPrefix("data: ") }!
        let jsonStr = String(dataLine.dropFirst(6))

        // Should be valid JSON
        let data = jsonStr.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["step_index"] as? Int, 0)
        XCTAssertEqual(dict?["tool"] as? String, "Bash")
    }

    func testSSEEncodingSequenceIdIncrements() throws {
        let event = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: "Bash"))

        let sse1 = try event.encodeToSSE(sequenceId: 1)
        let sse2 = try event.encodeToSSE(sequenceId: 2)

        XCTAssertTrue(sse1.contains("id: 1\n"))
        XCTAssertTrue(sse2.contains("id: 2\n"))
    }

    // MARK: - AgentSSEEvent.eventType

    func testEventTypeNames() {
        let started = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 0, tool: ""))
        XCTAssertEqual(started.eventType, "step_started")

        let completed = AgentSSEEvent.stepCompleted(
            StepCompletedData(stepIndex: 0, tool: "", success: true)
        )
        XCTAssertEqual(completed.eventType, "step_completed")

        let runCompleted = AgentSSEEvent.runCompleted(
            RunCompletedData(runId: "", finalStatus: "", totalSteps: 0)
        )
        XCTAssertEqual(runCompleted.eventType, "run_completed")
    }

    // MARK: - PersistedSSEEvent Round-Trip

    func testPersistedSSEEventStepStartedRoundTrip() throws {
        let original = AgentSSEEvent.stepStarted(StepStartedData(stepIndex: 3, tool: "Bash"))
        let persisted = PersistedSSEEvent(from: original)

        let encoded = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedSSEEvent.self, from: encoded)
        let restored = decoded.toSSEEvent()

        XCTAssertEqual(restored, original)
    }

    func testPersistedSSEEventStepCompletedRoundTrip() throws {
        let original = AgentSSEEvent.stepCompleted(
            StepCompletedData(stepIndex: 1, tool: "Read", success: true, durationMs: 200)
        )
        let persisted = PersistedSSEEvent(from: original)

        let encoded = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedSSEEvent.self, from: encoded)
        let restored = decoded.toSSEEvent()

        XCTAssertEqual(restored, original)
    }

    func testPersistedSSEEventRunCompletedRoundTrip() throws {
        let original = AgentSSEEvent.runCompleted(
            RunCompletedData(runId: "r-1", finalStatus: "completed", totalSteps: 4, durationMs: 1000)
        )
        let persisted = PersistedSSEEvent(from: original)

        let encoded = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedSSEEvent.self, from: encoded)
        let restored = decoded.toSSEEvent()

        XCTAssertEqual(restored, original)
    }

    func testPersistedSSEEventUnknownTypeReturnsNil() throws {
        let json = """
        {"eventType":"unknown_event","stepStarted":null,"stepCompleted":null,"runCompleted":null}
        """
        let data = Data(json.utf8)
        let persisted = try JSONDecoder().decode(PersistedSSEEvent.self, from: data)
        XCTAssertNil(persisted.toSSEEvent())
    }

    // MARK: - TrackedRun.toResponse()

    func testTrackedRunToResponse() {
        let run = TrackedRun(
            runId: "run-999",
            status: .completed,
            task: "my task",
            createdAt: "2026-05-01T00:00:00Z",
            updatedAt: "2026-05-01T00:01:00Z"
        )
        let response = run.toResponse()

        XCTAssertEqual(response.runId, "run-999")
        XCTAssertEqual(response.status, .completed)
        XCTAssertEqual(response.task, "my task")
        XCTAssertEqual(response.createdAt, "2026-05-01T00:00:00Z")
        XCTAssertEqual(response.updatedAt, "2026-05-01T00:01:00Z")
    }

    func testTrackedRunToResponsePreservesStatus() {
        for status in APIRunStatus.allCases {
            let run = TrackedRun(
                runId: "run", status: status, task: "t", createdAt: ""
            )
            let response = run.toResponse()
            XCTAssertEqual(response.status, status)
        }
    }

    // MARK: - TrackedRun Codable

    func testTrackedRunCodableRoundTrip() throws {
        let run = TrackedRun(
            runId: "run-abc",
            status: .running,
            task: "analyze data",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:30Z",
            totalSteps: 5,
            durationMs: 3000,
            resultText: "analysis complete",
            error: nil
        )
        let encoded = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(TrackedRun.self, from: encoded)
        XCTAssertEqual(decoded, run)
    }

    func testTrackedRunWithAllOptionals() throws {
        let run = TrackedRun(
            runId: "run-min",
            status: .queued,
            task: "minimal",
            createdAt: "2026-01-01T00:00:00Z"
        )
        let encoded = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(TrackedRun.self, from: encoded)
        XCTAssertEqual(decoded, run)
        XCTAssertNil(decoded.updatedAt)
        XCTAssertEqual(decoded.totalSteps, 0)
        XCTAssertNil(decoded.durationMs)
        XCTAssertNil(decoded.resultText)
        XCTAssertNil(decoded.error)
    }
}
