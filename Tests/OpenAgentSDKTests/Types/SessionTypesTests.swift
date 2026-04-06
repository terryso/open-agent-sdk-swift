import XCTest
@testable import OpenAgentSDK

final class SessionTypesTests: XCTestCase {

    // MARK: - SessionMetadata

    func testSessionMetadata_creation() {
        let meta = SessionMetadata(
            id: "sess_1",
            cwd: "/home/user",
            model: "claude-sonnet-4-6",
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T01:00:00Z",
            messageCount: 5,
            summary: "A test session"
        )
        XCTAssertEqual(meta.id, "sess_1")
        XCTAssertEqual(meta.cwd, "/home/user")
        XCTAssertEqual(meta.model, "claude-sonnet-4-6")
        XCTAssertEqual(meta.createdAt, "2025-01-01T00:00:00Z")
        XCTAssertEqual(meta.updatedAt, "2025-01-01T01:00:00Z")
        XCTAssertEqual(meta.messageCount, 5)
        XCTAssertEqual(meta.summary, "A test session")
    }

    func testSessionMetadata_summaryDefaultsNil() {
        let meta = SessionMetadata(
            id: "sess_2",
            cwd: "/tmp",
            model: "claude-haiku-4-5",
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z",
            messageCount: 0
        )
        XCTAssertNil(meta.summary)
    }

    func testSessionMetadata_equality() {
        let a = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "model",
            createdAt: "t1", updatedAt: "t2",
            messageCount: 3, summary: "sum"
        )
        let b = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "model",
            createdAt: "t1", updatedAt: "t2",
            messageCount: 3, summary: "sum"
        )
        XCTAssertEqual(a, b)
    }

    func testSessionMetadata_inequality() {
        let a = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "model",
            createdAt: "t1", updatedAt: "t2",
            messageCount: 3
        )
        let b = SessionMetadata(
            id: "s2", cwd: "/tmp", model: "model",
            createdAt: "t1", updatedAt: "t2",
            messageCount: 3
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - SessionData

    func testSessionData_creation() {
        let meta = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "m",
            createdAt: "t1", updatedAt: "t2",
            messageCount: 1
        )
        let messages: [[String: Any]] = [
            ["role": "user", "content": "hello"],
            ["role": "assistant", "content": "hi"],
        ]
        let data = SessionData(metadata: meta, messages: messages)
        XCTAssertEqual(data.metadata.id, "s1")
        XCTAssertEqual(data.messages.count, 2)
    }

    func testSessionData_emptyMessages() {
        let meta = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "m",
            createdAt: "t1", updatedAt: "t2",
            messageCount: 0
        )
        let data = SessionData(metadata: meta, messages: [])
        XCTAssertTrue(data.messages.isEmpty)
    }
}
