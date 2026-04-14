import XCTest
@testable import OpenAgentSDK

final class SessionTypesTests: XCTestCase {

    // MARK: - SessionMetadata

    func testSessionMetadata_creation() {
        let created = Date(timeIntervalSince1970: 1735689600) // 2025-01-01T00:00:00Z
        let updated = Date(timeIntervalSince1970: 1735693200) // 2025-01-01T01:00:00Z
        let meta = SessionMetadata(
            id: "sess_1",
            cwd: "/home/user",
            model: "claude-sonnet-4-6",
            createdAt: created,
            updatedAt: updated,
            messageCount: 5,
            summary: "A test session"
        )
        XCTAssertEqual(meta.id, "sess_1")
        XCTAssertEqual(meta.cwd, "/home/user")
        XCTAssertEqual(meta.model, "claude-sonnet-4-6")
        XCTAssertEqual(meta.createdAt, created)
        XCTAssertEqual(meta.updatedAt, updated)
        XCTAssertEqual(meta.messageCount, 5)
        XCTAssertEqual(meta.summary, "A test session")
    }

    func testSessionMetadata_summaryDefaultsNil() {
        let now = Date()
        let meta = SessionMetadata(
            id: "sess_2",
            cwd: "/tmp",
            model: "claude-haiku-4-5",
            createdAt: now,
            updatedAt: now,
            messageCount: 0
        )
        XCTAssertNil(meta.summary)
    }

    func testSessionMetadata_equality() {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        let a = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "model",
            createdAt: t1, updatedAt: t2,
            messageCount: 3, summary: "sum"
        )
        let b = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "model",
            createdAt: t1, updatedAt: t2,
            messageCount: 3, summary: "sum"
        )
        XCTAssertEqual(a, b)
    }

    func testSessionMetadata_inequality() {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        let a = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "model",
            createdAt: t1, updatedAt: t2,
            messageCount: 3
        )
        let b = SessionMetadata(
            id: "s2", cwd: "/tmp", model: "model",
            createdAt: t1, updatedAt: t2,
            messageCount: 3
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - SessionData

    func testSessionData_creation() {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        let meta = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "m",
            createdAt: t1, updatedAt: t2,
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
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        let meta = SessionMetadata(
            id: "s1", cwd: "/tmp", model: "m",
            createdAt: t1, updatedAt: t2,
            messageCount: 0
        )
        let data = SessionData(metadata: meta, messages: [])
        XCTAssertTrue(data.messages.isEmpty)
    }
}
