import XCTest
@testable import OpenAgentSDK

// MARK: - TaskTypes Tests

/// ATDD RED PHASE: Tests for Story 4.1 -- Type Definitions (AC6).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `TaskTypes.swift` is created in `Sources/OpenAgentSDK/Types/`
///   - `TaskStatus` enum is defined with all required cases
///   - `Task` struct is defined with all required fields
///   - `AgentMessage` struct is defined with all required fields
///   - `AgentMessageType` enum is defined with all required cases
/// TDD Phase: RED (feature not implemented yet)
final class TaskTypesTests: XCTestCase {

    // MARK: - AC6: TaskStatus enum

    /// AC6 [P0]: TaskStatus enum has all required cases and is CaseIterable.
    func testTaskStatus_isCaseIterable() {
        // Given: the TaskStatus enum
        // Then: it has exactly 5 cases
        XCTAssertEqual(TaskStatus.allCases.count, 5)

        // And: all required cases exist
        let expectedRawValues: Set<String> = ["pending", "inProgress", "completed", "failed", "cancelled"]
        let actualRawValues = Set(TaskStatus.allCases.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues)
    }

    // MARK: - AC6: Task struct

    /// AC6 [P0]: Task struct has all required fields.
    func testTask_hasRequiredFields() {
        // Given: a Task instance
        let task = Task(
            id: "task_1",
            subject: "Test task",
            description: "A test",
            status: .pending,
            owner: "agent-1",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        // Then: all required fields are accessible
        XCTAssertEqual(task.id, "task_1")
        XCTAssertEqual(task.subject, "Test task")
        XCTAssertEqual(task.description, "A test")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.owner, "agent-1")
        XCTAssertEqual(task.createdAt, "2026-01-01T00:00:00Z")
        XCTAssertEqual(task.updatedAt, "2026-01-01T00:00:00Z")
    }

    /// AC6 [P0]: Task conforms to Sendable.
    func testTask_implementsSendable() {
        // Given: a Task instance
        let task = Task(
            id: "task_1",
            subject: "Sendable test",
            status: .pending,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        // Then: Task can be used in a Sendable context (compiles)
        // This test verifies Sendable conformance at compile time
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(task)
    }

    // MARK: - AC6: AgentMessage struct

    /// AC6 [P0]: AgentMessage struct has all required fields.
    func testAgentMessage_hasRequiredFields() {
        // Given: an AgentMessage instance
        let message = AgentMessage(
            from: "agent-1",
            to: "agent-2",
            content: "Hello",
            timestamp: "2026-01-01T00:00:00Z",
            type: .text
        )

        // Then: all required fields are accessible
        XCTAssertEqual(message.from, "agent-1")
        XCTAssertEqual(message.to, "agent-2")
        XCTAssertEqual(message.content, "Hello")
        XCTAssertEqual(message.timestamp, "2026-01-01T00:00:00Z")
        XCTAssertEqual(message.type, .text)
    }

    // MARK: - AC6: AgentMessageType enum

    /// AC6 [P0]: AgentMessageType enum has all required cases.
    func testAgentMessageType_hasAllCases() {
        // Given: the AgentMessageType enum
        // Then: all required cases exist and compile
        let text = AgentMessageType.text
        let shutdownRequest = AgentMessageType.shutdownRequest
        let shutdownResponse = AgentMessageType.shutdownResponse
        let planApprovalResponse = AgentMessageType.planApprovalResponse

        // And: raw values match expected strings
        XCTAssertEqual(text.rawValue, "text")
        XCTAssertEqual(shutdownRequest.rawValue, "shutdownRequest")
        XCTAssertEqual(shutdownResponse.rawValue, "shutdownResponse")
        XCTAssertEqual(planApprovalResponse.rawValue, "planApprovalResponse")
    }
}
