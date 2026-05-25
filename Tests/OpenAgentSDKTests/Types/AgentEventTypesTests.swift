import XCTest
@testable import OpenAgentSDK

final class AgentEventTypesTests: XCTestCase {

    // MARK: - AgentEvent Protocol (AC1)

    func testAgentEventProtocolConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
        let event = BaseAgentEvent()
        acceptEvent(event)
    }

    func testAgentEventProtocolIsSendable() {
        func acceptSendable<T: Sendable>(_ value: T) {
            _ = value
        }
        acceptSendable(BaseAgentEvent())
    }

    // MARK: - BaseAgentEvent (AC2)

    func testBaseAgentEventDefaultId() {
        let event = BaseAgentEvent()
        XCTAssertFalse(event.id.isEmpty)
        // Should be a valid UUID string
        XCTAssertNotNil(UUID(uuidString: event.id))
    }

    func testBaseAgentEventDefaultTimestamp() {
        let before = Date()
        let event = BaseAgentEvent()
        let after = Date()
        XCTAssertGreaterThanOrEqual(event.timestamp, before)
        XCTAssertLessThanOrEqual(event.timestamp, after)
    }

    func testBaseAgentEventUniqueIds() {
        let event1 = BaseAgentEvent()
        let event2 = BaseAgentEvent()
        XCTAssertNotEqual(event1.id, event2.id)
    }

    func testBaseAgentEventCustomInit() {
        let customId = "custom-id-123"
        let customDate = Date(timeIntervalSince1970: 1000000)
        let event = BaseAgentEvent(id: customId, timestamp: customDate)
        XCTAssertEqual(event.id, customId)
        XCTAssertEqual(event.timestamp, customDate)
    }

    // MARK: - BaseAgentEvent Codable (AC4)

    func testBaseAgentEventCodableRoundTrip() throws {
        let event = BaseAgentEvent(id: "test-id", timestamp: Date(timeIntervalSince1970: 1700000000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BaseAgentEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince(event.timestamp), 0, accuracy: 1.0)
    }

    // MARK: - BaseAgentEvent Equatable (AC4)

    func testBaseAgentEventEquatableSameValues() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let event1 = BaseAgentEvent(id: id, timestamp: ts)
        let event2 = BaseAgentEvent(id: id, timestamp: ts)
        XCTAssertEqual(event1, event2)
    }

    func testBaseAgentEventEquatableDifferentIds() {
        let ts = Date(timeIntervalSince1970: 1700000000)
        let event1 = BaseAgentEvent(id: "id-1", timestamp: ts)
        let event2 = BaseAgentEvent(id: "id-2", timestamp: ts)
        XCTAssertNotEqual(event1, event2)
    }

    func testBaseAgentEventEquatableDifferentTimestamps() {
        let event1 = BaseAgentEvent(id: "same", timestamp: Date(timeIntervalSince1970: 1000))
        let event2 = BaseAgentEvent(id: "same", timestamp: Date(timeIntervalSince1970: 2000))
        XCTAssertNotEqual(event1, event2)
    }

    // MARK: - AgentEventCategory (AC3)

    func testAgentEventCategoryAllCases() {
        let allCases = AgentEventCategory.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.session))
        XCTAssertTrue(allCases.contains(.agent))
        XCTAssertTrue(allCases.contains(.tool))
        XCTAssertTrue(allCases.contains(.llm))
        XCTAssertTrue(allCases.contains(.memory))
        XCTAssertTrue(allCases.contains(.subAgent))
    }

    func testAgentEventCategoryRawValues() {
        XCTAssertEqual(AgentEventCategory.session.rawValue, "session")
        XCTAssertEqual(AgentEventCategory.agent.rawValue, "agent")
        XCTAssertEqual(AgentEventCategory.tool.rawValue, "tool")
        XCTAssertEqual(AgentEventCategory.llm.rawValue, "llm")
        XCTAssertEqual(AgentEventCategory.memory.rawValue, "memory")
        XCTAssertEqual(AgentEventCategory.subAgent.rawValue, "subAgent")
    }

    func testAgentEventCategoryCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for category in AgentEventCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(AgentEventCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    func testAgentEventCategoryEquatable() {
        XCTAssertEqual(AgentEventCategory.session, AgentEventCategory.session)
        XCTAssertNotEqual(AgentEventCategory.session, AgentEventCategory.agent)
    }

    func testAgentEventCategorySendable() {
        func acceptSendable<T: Sendable>(_ value: T) {
            _ = value
        }
        acceptSendable(AgentEventCategory.tool)
    }

    // MARK: - Struct value type (AC4)

    func testBaseAgentEventIsValueType() {
        let event1 = BaseAgentEvent(id: "orig", timestamp: Date())
        let event2 = event1
        XCTAssertEqual(event1, event2)
    }

    // MARK: - Composition Pattern (AC1, AC2)

    /// Verifies the intended usage pattern: a custom struct composes BaseAgentEvent
    /// and forwards id/timestamp, rather than inheriting from a base class.
    func testCompositionPatternCustomEvent() {
        struct ToolCallEvent: AgentEvent, Codable {
            let base: BaseAgentEvent
            let toolName: String
            var id: String { base.id }
            var timestamp: Date { base.timestamp }
        }

        let event = ToolCallEvent(
            base: BaseAgentEvent(),
            toolName: "readFile"
        )
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
        XCTAssertEqual(event.toolName, "readFile")
    }

    func testCompositionPatternSendableConformance() {
        struct CustomEvent: AgentEvent, Codable {
            let base: BaseAgentEvent
            var id: String { base.id }
            var timestamp: Date { base.timestamp }
        }
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(CustomEvent(base: BaseAgentEvent()))
    }

    // MARK: - Existential Usage (AC1)

    /// Verifies that `any AgentEvent` works as an existential type —
    /// this is how EventBus will store and dispatch events.
    func testAgentEventExistentialUsage() {
        let events: [any AgentEvent] = [
            BaseAgentEvent(),
            BaseAgentEvent(id: "custom", timestamp: Date())
        ]
        XCTAssertEqual(events.count, 2)
        for event in events {
            XCTAssertFalse(event.id.isEmpty)
        }
    }

    func testAgentEventExistentialTypeErasure() {
        func getEvent() -> any AgentEvent {
            BaseAgentEvent(id: "erased", timestamp: Date(timeIntervalSince1970: 0))
        }
        let event = getEvent()
        XCTAssertEqual(event.id, "erased")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
    }

    // MARK: - JSON Key Structure (AC4)

    /// Verifies encoded JSON uses expected key names "id" and "timestamp".
    /// Epic 28 will rely on these key names for SSE mapping.
    func testBaseAgentEventJsonKeyStructure() throws {
        let event = BaseAgentEvent(id: "json-test", timestamp: Date(timeIntervalSince1970: 1700000000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["id"], "JSON should contain 'id' key")
        XCTAssertNotNil(json["timestamp"], "JSON should contain 'timestamp' key")
        XCTAssertEqual(json["id"] as? String, "json-test")
    }

    func testBaseAgentEventDecodingFromJson() throws {
        let jsonString = """
        {"id":"decoded-id","timestamp":"2023-11-15T00:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(BaseAgentEvent.self, from: data)

        XCTAssertEqual(event.id, "decoded-id")
    }

    // MARK: - Category JSON String Format (AC3)

    /// Verifies each category encodes to its raw string value in JSON.
    func testAgentEventCategoryJsonStringValue() throws {
        let encoder = JSONEncoder()
        for category in AgentEventCategory.allCases {
            let data = try encoder.encode(category)
            let jsonString = String(data: data, encoding: .utf8)!
            // JSONEncoder wraps strings in quotes
            XCTAssertEqual(jsonString, "\"\(category.rawValue)\"")
        }
    }

    // MARK: - Edge Cases

    func testBaseAgentEventEmptyStringId() {
        let event = BaseAgentEvent(id: "", timestamp: Date())
        XCTAssertTrue(event.id.isEmpty)
    }

    func testBaseAgentEventDistantPastTimestamp() {
        let event = BaseAgentEvent(timestamp: Date.distantPast)
        XCTAssertEqual(event.timestamp, Date.distantPast)
    }

    func testBaseAgentEventDistantFutureTimestamp() {
        let event = BaseAgentEvent(timestamp: Date.distantFuture)
        XCTAssertEqual(event.timestamp, Date.distantFuture)
    }

    // MARK: - Concurrent Access (AC4)

    /// Verifies BaseAgentEvent can safely cross actor boundaries.
    func testBaseAgentEventSendableAcrossActor() async {
        let event = BaseAgentEvent(id: "concurrent-test", timestamp: Date())
        let retrieved = await Self.echoActor.send(event)
        XCTAssertEqual(retrieved.id, "concurrent-test")
    }

    /// Verifies AgentEventCategory can safely cross actor boundaries.
    func testAgentEventCategorySendableAcrossActor() async {
        let category = AgentEventCategory.tool
        let retrieved = await Self.echoActor.sendCategory(category)
        XCTAssertEqual(retrieved, .tool)
    }
}

// MARK: - Test Helpers

private extension AgentEventTypesTests {
    actor EchoActor {
        func send(_ event: BaseAgentEvent) -> BaseAgentEvent { event }
        func sendCategory(_ category: AgentEventCategory) -> AgentEventCategory { category }
    }

    static let echoActor = EchoActor()
}

// MARK: - Session Lifecycle Events

extension AgentEventTypesTests {

    // MARK: - SessionFinalStatus (AC3)

    func testSessionFinalStatusAllCases() {
        let allCases = SessionFinalStatus.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.completed))
        XCTAssertTrue(allCases.contains(.failed))
        XCTAssertTrue(allCases.contains(.interrupted))
    }

    func testSessionFinalStatusRawValues() {
        XCTAssertEqual(SessionFinalStatus.completed.rawValue, "completed")
        XCTAssertEqual(SessionFinalStatus.failed.rawValue, "failed")
        XCTAssertEqual(SessionFinalStatus.interrupted.rawValue, "interrupted")
    }

    func testSessionFinalStatusCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in SessionFinalStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(SessionFinalStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    func testSessionFinalStatusSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(SessionFinalStatus.completed)
    }

    // MARK: - SessionCreatedEvent (AC1)

    func testSessionCreatedEventConstruction() {
        let event = SessionCreatedEvent(sessionId: "sess-1", task: "build app", model: "claude-sonnet-4-6")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.task, "build app")
        XCTAssertEqual(event.model, "claude-sonnet-4-6")
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    func testSessionCreatedEventNilSessionId() {
        let event = SessionCreatedEvent(sessionId: nil, task: "hello", model: "gpt-4")
        XCTAssertNil(event.sessionId)
    }

    func testSessionCreatedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
        let event = SessionCreatedEvent(sessionId: "s", task: "t", model: "m")
        acceptEvent(event)
    }

    func testSessionCreatedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(SessionCreatedEvent(sessionId: nil, task: "t", model: "m"))
    }

    func testSessionCreatedEventCodableRoundTrip() throws {
        let event = SessionCreatedEvent(sessionId: "sess-42", task: "write tests", model: "claude-sonnet-4-6")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionCreatedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.task, event.task)
        XCTAssertEqual(decoded.model, event.model)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince(event.timestamp), 0, accuracy: 1.0)
    }

    func testSessionCreatedEventSnakeCaseJsonKeys() throws {
        let event = SessionCreatedEvent(sessionId: "s1", task: "t", model: "m")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"], "JSON should use snake_case 'session_id'")
        XCTAssertNotNil(json["task"])
        XCTAssertNotNil(json["model"])
        XCTAssertNotNil(json["id"])
        XCTAssertNotNil(json["timestamp"])
    }

    func testSessionCreatedEventEquatable() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = SessionCreatedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", task: "t", model: "m")
        let e2 = SessionCreatedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", task: "t", model: "m")
        XCTAssertEqual(e1, e2)
    }

    func testSessionCreatedEventInitWithBase() {
        let event = SessionCreatedEvent(base: BaseAgentEvent(id: "custom", timestamp: Date(timeIntervalSince1970: 0)), sessionId: "s", task: "t", model: "m")
        XCTAssertEqual(event.id, "custom")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
    }

    // MARK: - SessionRestoredEvent (AC2)

    func testSessionRestoredEventConstruction() {
        let createdAt = Date(timeIntervalSince1970: 1700000000)
        let event = SessionRestoredEvent(sessionId: "sess-1", messageCount: 5, originalCreatedAt: createdAt)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.messageCount, 5)
        XCTAssertEqual(event.originalCreatedAt, createdAt)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testSessionRestoredEventNilSessionId() {
        let event = SessionRestoredEvent(sessionId: nil, messageCount: 0, originalCreatedAt: Date())
        XCTAssertNil(event.sessionId)
    }

    func testSessionRestoredEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = SessionRestoredEvent(sessionId: "s", messageCount: 3, originalCreatedAt: Date())
        acceptEvent(event)
    }

    func testSessionRestoredEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(SessionRestoredEvent(sessionId: nil, messageCount: 0, originalCreatedAt: Date()))
    }

    func testSessionRestoredEventCodableRoundTrip() throws {
        let createdAt = Date(timeIntervalSince1970: 1700000000)
        let event = SessionRestoredEvent(sessionId: "sess-1", messageCount: 10, originalCreatedAt: createdAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionRestoredEvent.self, from: data)

        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.messageCount, event.messageCount)
        XCTAssertEqual(decoded.originalCreatedAt.timeIntervalSince(event.originalCreatedAt), 0, accuracy: 1.0)
    }

    func testSessionRestoredEventSnakeCaseJsonKeys() throws {
        let event = SessionRestoredEvent(sessionId: "s", messageCount: 5, originalCreatedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["message_count"])
        XCTAssertNotNil(json["original_created_at"])
    }

    // MARK: - SessionClosedEvent (AC3)

    func testSessionClosedEventConstruction() {
        let event = SessionClosedEvent(sessionId: "sess-1", finalStatus: .completed)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.finalStatus, .completed)
    }

    func testSessionClosedEventAllFinalStatuses() {
        for status in SessionFinalStatus.allCases {
            let event = SessionClosedEvent(sessionId: nil, finalStatus: status)
            XCTAssertEqual(event.finalStatus, status)
        }
    }

    func testSessionClosedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = SessionClosedEvent(sessionId: "s", finalStatus: .failed)
        acceptEvent(event)
    }

    func testSessionClosedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(SessionClosedEvent(sessionId: nil, finalStatus: .interrupted))
    }

    func testSessionClosedEventCodableRoundTrip() throws {
        let event = SessionClosedEvent(sessionId: "sess-1", finalStatus: .failed)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionClosedEvent.self, from: data)

        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.finalStatus, event.finalStatus)
    }

    func testSessionClosedEventSnakeCaseJsonKeys() throws {
        let event = SessionClosedEvent(sessionId: "s", finalStatus: .completed)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["final_status"])
    }

    // MARK: - SessionAutoSavedEvent (AC4)

    func testSessionAutoSavedEventConstruction() {
        let event = SessionAutoSavedEvent(sessionId: "sess-1", messageCount: 12)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.messageCount, 12)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testSessionAutoSavedEventNilSessionId() {
        let event = SessionAutoSavedEvent(sessionId: nil, messageCount: 0)
        XCTAssertNil(event.sessionId)
    }

    func testSessionAutoSavedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = SessionAutoSavedEvent(sessionId: "s", messageCount: 5)
        acceptEvent(event)
    }

    func testSessionAutoSavedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(SessionAutoSavedEvent(sessionId: nil, messageCount: 0))
    }

    func testSessionAutoSavedEventCodableRoundTrip() throws {
        let event = SessionAutoSavedEvent(sessionId: "sess-1", messageCount: 7)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionAutoSavedEvent.self, from: data)

        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.messageCount, event.messageCount)
    }

    func testSessionAutoSavedEventSnakeCaseJsonKeys() throws {
        let event = SessionAutoSavedEvent(sessionId: "s", messageCount: 3)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["message_count"])
    }

    // MARK: - Session Events Existential Usage (AC5)

    func testSessionEventsAsAgentEventExistential() {
        let events: [any AgentEvent] = [
            SessionCreatedEvent(sessionId: "s1", task: "t", model: "m"),
            SessionRestoredEvent(sessionId: "s2", messageCount: 3, originalCreatedAt: Date()),
            SessionClosedEvent(sessionId: "s3", finalStatus: .completed),
            SessionAutoSavedEvent(sessionId: "s4", messageCount: 5)
        ]
        XCTAssertEqual(events.count, 4)
        for event in events {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
    }

    func testSessionEventsSendableAcrossActor() async {
        let event = SessionCreatedEvent(sessionId: "s", task: "t", model: "m")
        let retrieved = await Self.sessionEchoActor.send(event)
        XCTAssertEqual(retrieved.task, "t")
    }

    // MARK: - All Payload Fields Are Immutable (AC5)

    func testSessionCreatedEventImmutablePayload() {
        let event = SessionCreatedEvent(sessionId: "s", task: "t", model: "m")
        // These are `let` properties — compilation proves immutability
        XCTAssertEqual(event.sessionId, "s")
        XCTAssertEqual(event.task, "t")
        XCTAssertEqual(event.model, "m")
    }

    func testSessionClosedEventImmutablePayload() {
        let event = SessionClosedEvent(sessionId: "s", finalStatus: .failed)
        XCTAssertEqual(event.finalStatus, .failed)
    }

    func testSessionRestoredEventImmutablePayload() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let event = SessionRestoredEvent(sessionId: "s", messageCount: 5, originalCreatedAt: date)
        XCTAssertEqual(event.sessionId, "s")
        XCTAssertEqual(event.messageCount, 5)
        XCTAssertEqual(event.originalCreatedAt, date)
    }

    func testSessionAutoSavedEventImmutablePayload() {
        let event = SessionAutoSavedEvent(sessionId: "s", messageCount: 7)
        XCTAssertEqual(event.sessionId, "s")
        XCTAssertEqual(event.messageCount, 7)
    }

    // MARK: - SessionRestoredEvent Equatable (AC2)

    func testSessionRestoredEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let createdAt = Date(timeIntervalSince1970: 1600000000)
        let e1 = SessionRestoredEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 3, originalCreatedAt: createdAt)
        let e2 = SessionRestoredEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 3, originalCreatedAt: createdAt)
        XCTAssertEqual(e1, e2)
    }

    func testSessionRestoredEventNotEqualDifferentMessageCount() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let createdAt = Date(timeIntervalSince1970: 1600000000)
        let e1 = SessionRestoredEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 3, originalCreatedAt: createdAt)
        let e2 = SessionRestoredEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 5, originalCreatedAt: createdAt)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - SessionClosedEvent Equatable (AC3)

    func testSessionClosedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = SessionClosedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", finalStatus: .completed)
        let e2 = SessionClosedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", finalStatus: .completed)
        XCTAssertEqual(e1, e2)
    }

    func testSessionClosedEventNotEqualDifferentStatus() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = SessionClosedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", finalStatus: .completed)
        let e2 = SessionClosedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", finalStatus: .failed)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - SessionAutoSavedEvent Equatable (AC4)

    func testSessionAutoSavedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = SessionAutoSavedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 5)
        let e2 = SessionAutoSavedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 5)
        XCTAssertEqual(e1, e2)
    }

    func testSessionAutoSavedEventNotEqualDifferentCount() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = SessionAutoSavedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 3)
        let e2 = SessionAutoSavedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", messageCount: 7)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - Init with Base (AC5)

    func testSessionRestoredEventInitWithBase() {
        let event = SessionRestoredEvent(
            base: BaseAgentEvent(id: "custom-base", timestamp: Date(timeIntervalSince1970: 0)),
            sessionId: "s", messageCount: 10, originalCreatedAt: Date(timeIntervalSince1970: 999)
        )
        XCTAssertEqual(event.id, "custom-base")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.messageCount, 10)
    }

    func testSessionClosedEventInitWithBase() {
        let event = SessionClosedEvent(
            base: BaseAgentEvent(id: "closed-base", timestamp: Date(timeIntervalSince1970: 42)),
            sessionId: nil, finalStatus: .interrupted
        )
        XCTAssertEqual(event.id, "closed-base")
        XCTAssertEqual(event.finalStatus, .interrupted)
    }

    func testSessionAutoSavedEventInitWithBase() {
        let event = SessionAutoSavedEvent(
            base: BaseAgentEvent(id: "autosave-base", timestamp: Date(timeIntervalSince1970: 100)),
            sessionId: "s", messageCount: 20
        )
        XCTAssertEqual(event.id, "autosave-base")
        XCTAssertEqual(event.messageCount, 20)
    }

    // MARK: - Codable Decode from Raw JSON (AC1-AC4)

    func testSessionCreatedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"raw-id","timestamp":"2024-01-15T12:00:00Z","session_id":"raw-sess","task":"raw task","model":"raw-model"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionCreatedEvent.self, from: data)

        XCTAssertEqual(event.id, "raw-id")
        XCTAssertEqual(event.sessionId, "raw-sess")
        XCTAssertEqual(event.task, "raw task")
        XCTAssertEqual(event.model, "raw-model")
    }

    func testSessionRestoredEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"rest-id","timestamp":"2024-01-15T12:00:00Z","session_id":"rest-sess","message_count":15,"original_created_at":"2023-06-01T00:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionRestoredEvent.self, from: data)

        XCTAssertEqual(event.id, "rest-id")
        XCTAssertEqual(event.messageCount, 15)
        XCTAssertEqual(event.originalCreatedAt, Date(timeIntervalSince1970: 1685577600))
    }

    func testSessionClosedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"close-id","timestamp":"2024-01-15T12:00:00Z","session_id":"close-sess","final_status":"interrupted"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionClosedEvent.self, from: data)

        XCTAssertEqual(event.id, "close-id")
        XCTAssertEqual(event.finalStatus, .interrupted)
    }

    func testSessionAutoSavedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"auto-id","timestamp":"2024-01-15T12:00:00Z","session_id":"auto-sess","message_count":8}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionAutoSavedEvent.self, from: data)

        XCTAssertEqual(event.id, "auto-id")
        XCTAssertEqual(event.messageCount, 8)
    }

    // MARK: - Nil SessionId Codable Decode (AC3, AC4)

    func testSessionClosedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"final_status":"completed"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionClosedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.finalStatus, .completed)
    }

    func testSessionAutoSavedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"message_count":3}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionAutoSavedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.messageCount, 3)
    }

    // MARK: - Codable Error Cases (AC1-AC4)

    func testSessionCreatedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(SessionCreatedEvent.self, from: data))
    }

    func testSessionClosedEventDecodeInvalidFinalStatus() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","final_status":"unknown_status"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(SessionClosedEvent.self, from: data))
    }

    func testSessionFinalStatusDecodeFromInvalidString() {
        let jsonString = "\"not_a_status\""
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(SessionFinalStatus.self, from: data))
    }

    // MARK: - SessionRestoredEvent Codable nil sessionId decode (AC2)

    func testSessionRestoredEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"message_count":0,"original_created_at":"2024-01-01T00:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SessionRestoredEvent.self, from: data)
        XCTAssertNil(event.sessionId)
    }

    // MARK: - Actor Boundary for All Event Types (AC5)

    func testSessionRestoredEventSendableAcrossActor() async {
        let event = SessionRestoredEvent(sessionId: "s", messageCount: 3, originalCreatedAt: Date())
        let retrieved = await Self.sessionRestoredEchoActor.send(event)
        XCTAssertEqual(retrieved.messageCount, 3)
    }

    func testSessionClosedEventSendableAcrossActor() async {
        let event = SessionClosedEvent(sessionId: "s", finalStatus: .failed)
        let retrieved = await Self.sessionClosedEchoActor.send(event)
        XCTAssertEqual(retrieved.finalStatus, .failed)
    }

    func testSessionAutoSavedEventSendableAcrossActor() async {
        let event = SessionAutoSavedEvent(sessionId: "s", messageCount: 42)
        let retrieved = await Self.sessionAutoSavedEchoActor.send(event)
        XCTAssertEqual(retrieved.messageCount, 42)
    }

    // MARK: - Edge Cases

    func testSessionCreatedEventEmptyTask() {
        let event = SessionCreatedEvent(sessionId: "s", task: "", model: "m")
        XCTAssertEqual(event.task, "")
    }

    func testSessionRestoredEventZeroMessageCount() {
        let event = SessionRestoredEvent(sessionId: nil, messageCount: 0, originalCreatedAt: Date())
        XCTAssertEqual(event.messageCount, 0)
    }

    func testSessionAutoSavedEventZeroMessageCount() {
        let event = SessionAutoSavedEvent(sessionId: nil, messageCount: 0)
        XCTAssertEqual(event.messageCount, 0)
    }

    func testSessionCreatedEventEncodedJsonValueTypes() throws {
        let event = SessionCreatedEvent(sessionId: "s1", task: "t", model: "m")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertTrue(json["id"] is String)
        XCTAssertTrue(json["timestamp"] is String)
        XCTAssertTrue(json["session_id"] is String)
        XCTAssertTrue(json["task"] is String)
        XCTAssertTrue(json["model"] is String)
        XCTAssertEqual(json["session_id"] as? String, "s1")
        XCTAssertEqual(json["task"] as? String, "t")
        XCTAssertEqual(json["model"] as? String, "m")
    }

    func testSessionClosedEventEncodedFinalStatusValue() throws {
        let event = SessionClosedEvent(sessionId: "s", finalStatus: .completed)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["final_status"] as? String, "completed")
    }
}

// MARK: - Session Event Test Helpers

private extension AgentEventTypesTests {
    actor SessionEchoActor {
        func send(_ event: SessionCreatedEvent) -> SessionCreatedEvent { event }
    }

    actor SessionRestoredEchoActor {
        func send(_ event: SessionRestoredEvent) -> SessionRestoredEvent { event }
    }

    actor SessionClosedEchoActor {
        func send(_ event: SessionClosedEvent) -> SessionClosedEvent { event }
    }

    actor SessionAutoSavedEchoActor {
        func send(_ event: SessionAutoSavedEvent) -> SessionAutoSavedEvent { event }
    }

    static let sessionEchoActor = SessionEchoActor()
    static let sessionRestoredEchoActor = SessionRestoredEchoActor()
    static let sessionClosedEchoActor = SessionClosedEchoActor()
    static let sessionAutoSavedEchoActor = SessionAutoSavedEchoActor()
}

// MARK: - Agent Lifecycle Events

extension AgentEventTypesTests {

    // MARK: - AgentStartedEvent (AC1)

    func testAgentStartedEventConstruction() {
        let event = AgentStartedEvent(sessionId: "sess-1", task: "build app")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.task, "build app")
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    func testAgentStartedEventNilSessionId() {
        let event = AgentStartedEvent(sessionId: nil, task: "hello")
        XCTAssertNil(event.sessionId)
    }

    func testAgentStartedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
        let event = AgentStartedEvent(sessionId: "s", task: "t")
        acceptEvent(event)
    }

    func testAgentStartedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(AgentStartedEvent(sessionId: nil, task: "t"))
    }

    func testAgentStartedEventCodableRoundTrip() throws {
        let event = AgentStartedEvent(sessionId: "sess-42", task: "write tests")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentStartedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.task, event.task)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince(event.timestamp), 0, accuracy: 1.0)
    }

    func testAgentStartedEventSnakeCaseJsonKeys() throws {
        let event = AgentStartedEvent(sessionId: "s1", task: "t")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"], "JSON should use snake_case 'session_id'")
        XCTAssertNotNil(json["task"])
        XCTAssertNotNil(json["id"])
        XCTAssertNotNil(json["timestamp"])
    }

    func testAgentStartedEventEquatable() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", task: "t")
        let e2 = AgentStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", task: "t")
        XCTAssertEqual(e1, e2)
    }

    func testAgentStartedEventNotEqualDifferentTask() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", task: "task-a")
        let e2 = AgentStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", task: "task-b")
        XCTAssertNotEqual(e1, e2)
    }

    func testAgentStartedEventInitWithBase() {
        let event = AgentStartedEvent(base: BaseAgentEvent(id: "custom", timestamp: Date(timeIntervalSince1970: 0)), sessionId: "s", task: "t")
        XCTAssertEqual(event.id, "custom")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
    }

    // MARK: - AgentCompletedEvent (AC2)

    func testAgentCompletedEventConstruction() {
        let event = AgentCompletedEvent(sessionId: "sess-1", totalSteps: 5, durationMs: 1200, resultText: "done")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.totalSteps, 5)
        XCTAssertEqual(event.durationMs, 1200)
        XCTAssertEqual(event.resultText, "done")
        XCTAssertFalse(event.id.isEmpty)
    }

    func testAgentCompletedEventNilSessionIdAndResultText() {
        let event = AgentCompletedEvent(sessionId: nil, totalSteps: 0, durationMs: 0, resultText: nil)
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.resultText)
    }

    func testAgentCompletedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = AgentCompletedEvent(sessionId: "s", totalSteps: 3, durationMs: 500, resultText: "ok")
        acceptEvent(event)
    }

    func testAgentCompletedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(AgentCompletedEvent(sessionId: nil, totalSteps: 0, durationMs: 0, resultText: nil))
    }

    func testAgentCompletedEventCodableRoundTrip() throws {
        let event = AgentCompletedEvent(sessionId: "sess-1", totalSteps: 10, durationMs: 3500, resultText: "success")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentCompletedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.totalSteps, event.totalSteps)
        XCTAssertEqual(decoded.durationMs, event.durationMs)
        XCTAssertEqual(decoded.resultText, event.resultText)
    }

    func testAgentCompletedEventSnakeCaseJsonKeys() throws {
        let event = AgentCompletedEvent(sessionId: "s1", totalSteps: 3, durationMs: 100, resultText: "r")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["total_steps"])
        XCTAssertNotNil(json["duration_ms"])
        XCTAssertNotNil(json["result_text"])
    }

    func testAgentCompletedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", totalSteps: 3, durationMs: 100, resultText: "r")
        let e2 = AgentCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", totalSteps: 3, durationMs: 100, resultText: "r")
        XCTAssertEqual(e1, e2)
    }

    func testAgentCompletedEventNotEqualDifferentDuration() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", totalSteps: 3, durationMs: 100, resultText: nil)
        let e2 = AgentCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", totalSteps: 3, durationMs: 200, resultText: nil)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - AgentFailedEvent (AC3)

    func testAgentFailedEventConstruction() {
        let event = AgentFailedEvent(sessionId: "sess-1", error: "timeout", stepsCompleted: 3)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.error, "timeout")
        XCTAssertEqual(event.stepsCompleted, 3)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testAgentFailedEventNilSessionId() {
        let event = AgentFailedEvent(sessionId: nil, error: "crash", stepsCompleted: 0)
        XCTAssertNil(event.sessionId)
    }

    func testAgentFailedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = AgentFailedEvent(sessionId: "s", error: "err", stepsCompleted: 2)
        acceptEvent(event)
    }

    func testAgentFailedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(AgentFailedEvent(sessionId: nil, error: "e", stepsCompleted: 0))
    }

    func testAgentFailedEventCodableRoundTrip() throws {
        let event = AgentFailedEvent(sessionId: "sess-1", error: "api failure", stepsCompleted: 7)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentFailedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.error, event.error)
        XCTAssertEqual(decoded.stepsCompleted, event.stepsCompleted)
    }

    func testAgentFailedEventSnakeCaseJsonKeys() throws {
        let event = AgentFailedEvent(sessionId: "s1", error: "e", stepsCompleted: 5)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["error"])
        XCTAssertNotNil(json["steps_completed"])
    }

    func testAgentFailedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", error: "e", stepsCompleted: 3)
        let e2 = AgentFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", error: "e", stepsCompleted: 3)
        XCTAssertEqual(e1, e2)
    }

    func testAgentFailedEventNotEqualDifferentError() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", error: "err-a", stepsCompleted: 3)
        let e2 = AgentFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", error: "err-b", stepsCompleted: 3)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - AgentInterruptedEvent (AC4)

    func testAgentInterruptedEventConstruction() {
        let event = AgentInterruptedEvent(sessionId: "sess-1", stepsCompleted: 4)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.stepsCompleted, 4)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testAgentInterruptedEventNilSessionId() {
        let event = AgentInterruptedEvent(sessionId: nil, stepsCompleted: 0)
        XCTAssertNil(event.sessionId)
    }

    func testAgentInterruptedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = AgentInterruptedEvent(sessionId: "s", stepsCompleted: 2)
        acceptEvent(event)
    }

    func testAgentInterruptedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(AgentInterruptedEvent(sessionId: nil, stepsCompleted: 0))
    }

    func testAgentInterruptedEventCodableRoundTrip() throws {
        let event = AgentInterruptedEvent(sessionId: "sess-1", stepsCompleted: 6)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentInterruptedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.stepsCompleted, event.stepsCompleted)
    }

    func testAgentInterruptedEventSnakeCaseJsonKeys() throws {
        let event = AgentInterruptedEvent(sessionId: "s1", stepsCompleted: 3)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["steps_completed"])
    }

    func testAgentInterruptedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentInterruptedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", stepsCompleted: 3)
        let e2 = AgentInterruptedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", stepsCompleted: 3)
        XCTAssertEqual(e1, e2)
    }

    func testAgentInterruptedEventNotEqualDifferentSteps() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentInterruptedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", stepsCompleted: 3)
        let e2 = AgentInterruptedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", stepsCompleted: 7)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - AgentResumedEvent (AC5)

    func testAgentResumedEventConstruction() {
        let event = AgentResumedEvent(sessionId: "sess-1", resumeContext: "continue from step 3")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.resumeContext, "continue from step 3")
        XCTAssertFalse(event.id.isEmpty)
    }

    func testAgentResumedEventNilSessionId() {
        let event = AgentResumedEvent(sessionId: nil, resumeContext: "retry")
        XCTAssertNil(event.sessionId)
    }

    func testAgentResumedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = AgentResumedEvent(sessionId: "s", resumeContext: "ctx")
        acceptEvent(event)
    }

    func testAgentResumedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(AgentResumedEvent(sessionId: nil, resumeContext: "c"))
    }

    func testAgentResumedEventCodableRoundTrip() throws {
        let event = AgentResumedEvent(sessionId: "sess-1", resumeContext: "pick up where left off")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentResumedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.resumeContext, event.resumeContext)
    }

    func testAgentResumedEventSnakeCaseJsonKeys() throws {
        let event = AgentResumedEvent(sessionId: "s1", resumeContext: "ctx")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["resume_context"])
    }

    func testAgentResumedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentResumedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", resumeContext: "ctx")
        let e2 = AgentResumedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", resumeContext: "ctx")
        XCTAssertEqual(e1, e2)
    }

    func testAgentResumedEventNotEqualDifferentContext() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = AgentResumedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", resumeContext: "a")
        let e2 = AgentResumedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", resumeContext: "b")
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - Agent Events Existential Usage (AC6)

    func testAgentEventsAsAgentEventExistential() {
        let events: [any AgentEvent] = [
            AgentStartedEvent(sessionId: "s1", task: "start"),
            AgentCompletedEvent(sessionId: "s2", totalSteps: 5, durationMs: 1000, resultText: "done"),
            AgentFailedEvent(sessionId: "s3", error: "fail", stepsCompleted: 2),
            AgentInterruptedEvent(sessionId: "s4", stepsCompleted: 3),
            AgentResumedEvent(sessionId: "s5", resumeContext: "resume")
        ]
        XCTAssertEqual(events.count, 5)
        for event in events {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
    }

    // MARK: - All Payload Fields Are Immutable (AC6)

    func testAgentStartedEventImmutablePayload() {
        let event = AgentStartedEvent(sessionId: "s", task: "t")
        XCTAssertEqual(event.sessionId, "s")
        XCTAssertEqual(event.task, "t")
    }

    func testAgentCompletedEventImmutablePayload() {
        let event = AgentCompletedEvent(sessionId: "s", totalSteps: 5, durationMs: 100, resultText: "r")
        XCTAssertEqual(event.totalSteps, 5)
        XCTAssertEqual(event.durationMs, 100)
        XCTAssertEqual(event.resultText, "r")
    }

    func testAgentFailedEventImmutablePayload() {
        let event = AgentFailedEvent(sessionId: "s", error: "e", stepsCompleted: 3)
        XCTAssertEqual(event.error, "e")
        XCTAssertEqual(event.stepsCompleted, 3)
    }

    func testAgentInterruptedEventImmutablePayload() {
        let event = AgentInterruptedEvent(sessionId: "s", stepsCompleted: 7)
        XCTAssertEqual(event.stepsCompleted, 7)
    }

    func testAgentResumedEventImmutablePayload() {
        let event = AgentResumedEvent(sessionId: "s", resumeContext: "ctx")
        XCTAssertEqual(event.resumeContext, "ctx")
    }

    // MARK: - Codable Decode from Raw JSON

    func testAgentStartedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"raw-id","timestamp":"2024-01-15T12:00:00Z","session_id":"raw-sess","task":"raw task"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentStartedEvent.self, from: data)

        XCTAssertEqual(event.id, "raw-id")
        XCTAssertEqual(event.sessionId, "raw-sess")
        XCTAssertEqual(event.task, "raw task")
    }

    func testAgentCompletedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"comp-id","timestamp":"2024-01-15T12:00:00Z","session_id":"comp-sess","total_steps":8,"duration_ms":2500,"result_text":"ok"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentCompletedEvent.self, from: data)

        XCTAssertEqual(event.id, "comp-id")
        XCTAssertEqual(event.totalSteps, 8)
        XCTAssertEqual(event.durationMs, 2500)
        XCTAssertEqual(event.resultText, "ok")
    }

    func testAgentFailedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"fail-id","timestamp":"2024-01-15T12:00:00Z","session_id":"fail-sess","error":"timeout","steps_completed":4}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentFailedEvent.self, from: data)

        XCTAssertEqual(event.id, "fail-id")
        XCTAssertEqual(event.error, "timeout")
        XCTAssertEqual(event.stepsCompleted, 4)
    }

    func testAgentInterruptedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"int-id","timestamp":"2024-01-15T12:00:00Z","session_id":"int-sess","steps_completed":2}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentInterruptedEvent.self, from: data)

        XCTAssertEqual(event.id, "int-id")
        XCTAssertEqual(event.stepsCompleted, 2)
    }

    func testAgentResumedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"res-id","timestamp":"2024-01-15T12:00:00Z","session_id":"res-sess","resume_context":"continue"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentResumedEvent.self, from: data)

        XCTAssertEqual(event.id, "res-id")
        XCTAssertEqual(event.resumeContext, "continue")
    }

    // MARK: - Nil SessionId Codable Decode

    func testAgentStartedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"task":"hello"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentStartedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.task, "hello")
    }

    func testAgentCompletedEventDecodeNilSessionIdAndResultText() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"total_steps":1,"duration_ms":50,"result_text":null}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentCompletedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.resultText)
        XCTAssertEqual(event.totalSteps, 1)
    }

    func testAgentFailedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"error":"err","steps_completed":0}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentFailedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
    }

    func testAgentInterruptedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"steps_completed":5}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentInterruptedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.stepsCompleted, 5)
    }

    func testAgentResumedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"resume_context":"retry"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentResumedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.resumeContext, "retry")
    }

    func testAgentCompletedEventDecodeMissingResultText() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":"s1","total_steps":3,"duration_ms":100}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentCompletedEvent.self, from: data)
        XCTAssertNil(event.resultText)
        XCTAssertEqual(event.totalSteps, 3)
    }

    // MARK: - Codable Error Cases

    func testAgentStartedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(AgentStartedEvent.self, from: data))
    }

    func testAgentCompletedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","total_steps":1}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(AgentCompletedEvent.self, from: data))
    }

    func testAgentFailedEventDecodeMissingErrorField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","steps_completed":1}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(AgentFailedEvent.self, from: data))
    }

    func testAgentInterruptedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","session_id":"s"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(AgentInterruptedEvent.self, from: data))
    }

    func testAgentResumedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","session_id":"s"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(AgentResumedEvent.self, from: data))
    }

    // MARK: - Actor Boundary (AC6)

    func testAgentStartedEventSendableAcrossActor() async {
        let event = AgentStartedEvent(sessionId: "s", task: "t")
        let retrieved = await Self.agentStartedEchoActor.send(event)
        XCTAssertEqual(retrieved.task, "t")
    }

    func testAgentCompletedEventSendableAcrossActor() async {
        let event = AgentCompletedEvent(sessionId: "s", totalSteps: 5, durationMs: 100, resultText: "r")
        let retrieved = await Self.agentCompletedEchoActor.send(event)
        XCTAssertEqual(retrieved.totalSteps, 5)
    }

    func testAgentFailedEventSendableAcrossActor() async {
        let event = AgentFailedEvent(sessionId: "s", error: "err", stepsCompleted: 3)
        let retrieved = await Self.agentFailedEchoActor.send(event)
        XCTAssertEqual(retrieved.error, "err")
    }

    func testAgentInterruptedEventSendableAcrossActor() async {
        let event = AgentInterruptedEvent(sessionId: "s", stepsCompleted: 2)
        let retrieved = await Self.agentInterruptedEchoActor.send(event)
        XCTAssertEqual(retrieved.stepsCompleted, 2)
    }

    func testAgentResumedEventSendableAcrossActor() async {
        let event = AgentResumedEvent(sessionId: "s", resumeContext: "ctx")
        let retrieved = await Self.agentResumedEchoActor.send(event)
        XCTAssertEqual(retrieved.resumeContext, "ctx")
    }
}

// MARK: - Agent Event Test Helpers

private extension AgentEventTypesTests {
    actor AgentStartedEchoActor {
        func send(_ event: AgentStartedEvent) -> AgentStartedEvent { event }
    }

    actor AgentCompletedEchoActor {
        func send(_ event: AgentCompletedEvent) -> AgentCompletedEvent { event }
    }

    actor AgentFailedEchoActor {
        func send(_ event: AgentFailedEvent) -> AgentFailedEvent { event }
    }

    actor AgentInterruptedEchoActor {
        func send(_ event: AgentInterruptedEvent) -> AgentInterruptedEvent { event }
    }

    actor AgentResumedEchoActor {
        func send(_ event: AgentResumedEvent) -> AgentResumedEvent { event }
    }

    static let agentStartedEchoActor = AgentStartedEchoActor()
    static let agentCompletedEchoActor = AgentCompletedEchoActor()
    static let agentFailedEchoActor = AgentFailedEchoActor()
    static let agentInterruptedEchoActor = AgentInterruptedEchoActor()
    static let agentResumedEchoActor = AgentResumedEchoActor()
}

// MARK: - Tool Lifecycle Events

extension AgentEventTypesTests {

    // MARK: - ToolStartedEvent (AC1)

    func testToolStartedEventConstruction() {
        let event = ToolStartedEvent(sessionId: "sess-1", toolName: "BashTool", toolUseId: "tu-1", input: "{\"cmd\":\"ls\"}")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.toolName, "BashTool")
        XCTAssertEqual(event.toolUseId, "tu-1")
        XCTAssertEqual(event.input, "{\"cmd\":\"ls\"}")
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    func testToolStartedEventNilSessionIdAndInput() {
        let event = ToolStartedEvent(sessionId: nil, toolName: "FileReadTool", toolUseId: "tu-2", input: nil)
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.input)
    }

    func testToolStartedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
        let event = ToolStartedEvent(sessionId: "s", toolName: "t", toolUseId: "tu", input: nil)
        acceptEvent(event)
    }

    func testToolStartedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(ToolStartedEvent(sessionId: nil, toolName: "t", toolUseId: "tu", input: nil))
    }

    func testToolStartedEventCodableRoundTrip() throws {
        let event = ToolStartedEvent(sessionId: "sess-42", toolName: "BashTool", toolUseId: "tu-99", input: "{\"cmd\":\"pwd\"}")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ToolStartedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.toolName, event.toolName)
        XCTAssertEqual(decoded.toolUseId, event.toolUseId)
        XCTAssertEqual(decoded.input, event.input)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince(event.timestamp), 0, accuracy: 1.0)
    }

    func testToolStartedEventSnakeCaseJsonKeys() throws {
        let event = ToolStartedEvent(sessionId: "s1", toolName: "BashTool", toolUseId: "tu-1", input: "inp")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"], "JSON should use snake_case 'session_id'")
        XCTAssertNotNil(json["tool_name"])
        XCTAssertNotNil(json["tool_use_id"])
        XCTAssertNotNil(json["input"])
        XCTAssertNotNil(json["id"])
        XCTAssertNotNil(json["timestamp"])
    }

    func testToolStartedEventEquatable() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolName: "t", toolUseId: "tu", input: nil)
        let e2 = ToolStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolName: "t", toolUseId: "tu", input: nil)
        XCTAssertEqual(e1, e2)
    }

    func testToolStartedEventNotEqualDifferentToolName() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolName: "BashTool", toolUseId: "tu", input: nil)
        let e2 = ToolStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolName: "FileTool", toolUseId: "tu", input: nil)
        XCTAssertNotEqual(e1, e2)
    }

    func testToolStartedEventInitWithBase() {
        let event = ToolStartedEvent(base: BaseAgentEvent(id: "custom", timestamp: Date(timeIntervalSince1970: 0)), sessionId: "s", toolName: "t", toolUseId: "tu", input: "i")
        XCTAssertEqual(event.id, "custom")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
    }

    func testToolStartedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"raw-id","timestamp":"2024-01-15T12:00:00Z","session_id":"raw-sess","tool_name":"BashTool","tool_use_id":"tu-1","input":"ls"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ToolStartedEvent.self, from: data)

        XCTAssertEqual(event.id, "raw-id")
        XCTAssertEqual(event.sessionId, "raw-sess")
        XCTAssertEqual(event.toolName, "BashTool")
        XCTAssertEqual(event.toolUseId, "tu-1")
        XCTAssertEqual(event.input, "ls")
    }

    func testToolStartedEventDecodeNilSessionIdAndInput() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"tool_name":"t","tool_use_id":"tu","input":null}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ToolStartedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.input)
    }

    func testToolStartedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(ToolStartedEvent.self, from: data))
    }

    func testToolStartedEventImmutablePayload() {
        let event = ToolStartedEvent(sessionId: "s", toolName: "t", toolUseId: "tu", input: "i")
        XCTAssertEqual(event.toolName, "t")
        XCTAssertEqual(event.toolUseId, "tu")
        XCTAssertEqual(event.input, "i")
    }

    // MARK: - ToolStreamingEvent (AC2)

    func testToolStreamingEventConstruction() {
        let event = ToolStreamingEvent(sessionId: "sess-1", toolUseId: "tu-1", chunk: "partial output")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.toolUseId, "tu-1")
        XCTAssertEqual(event.chunk, "partial output")
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    func testToolStreamingEventNilSessionId() {
        let event = ToolStreamingEvent(sessionId: nil, toolUseId: "tu-2", chunk: "data")
        XCTAssertNil(event.sessionId)
    }

    func testToolStreamingEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = ToolStreamingEvent(sessionId: "s", toolUseId: "tu", chunk: "c")
        acceptEvent(event)
    }

    func testToolStreamingEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(ToolStreamingEvent(sessionId: nil, toolUseId: "tu", chunk: "c"))
    }

    func testToolStreamingEventCodableRoundTrip() throws {
        let event = ToolStreamingEvent(sessionId: "sess-1", toolUseId: "tu-5", chunk: "streaming data")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ToolStreamingEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.toolUseId, event.toolUseId)
        XCTAssertEqual(decoded.chunk, event.chunk)
    }

    func testToolStreamingEventSnakeCaseJsonKeys() throws {
        let event = ToolStreamingEvent(sessionId: "s1", toolUseId: "tu-1", chunk: "c")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["tool_use_id"])
        XCTAssertNotNil(json["chunk"])
    }

    func testToolStreamingEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolStreamingEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", chunk: "c")
        let e2 = ToolStreamingEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", chunk: "c")
        XCTAssertEqual(e1, e2)
    }

    func testToolStreamingEventNotEqualDifferentChunk() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolStreamingEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", chunk: "a")
        let e2 = ToolStreamingEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", chunk: "b")
        XCTAssertNotEqual(e1, e2)
    }

    func testToolStreamingEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"raw-id","timestamp":"2024-01-15T12:00:00Z","session_id":"raw-sess","tool_use_id":"tu-1","chunk":"data"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ToolStreamingEvent.self, from: data)

        XCTAssertEqual(event.id, "raw-id")
        XCTAssertEqual(event.toolUseId, "tu-1")
        XCTAssertEqual(event.chunk, "data")
    }

    func testToolStreamingEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(ToolStreamingEvent.self, from: data))
    }

    func testToolStreamingEventImmutablePayload() {
        let event = ToolStreamingEvent(sessionId: "s", toolUseId: "tu", chunk: "c")
        XCTAssertEqual(event.toolUseId, "tu")
        XCTAssertEqual(event.chunk, "c")
    }

    // MARK: - ToolCompletedEvent (AC3)

    func testToolCompletedEventConstruction() {
        let event = ToolCompletedEvent(sessionId: "sess-1", toolUseId: "tu-1", toolName: "BashTool", durationMs: 500, isError: false)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.toolUseId, "tu-1")
        XCTAssertEqual(event.toolName, "BashTool")
        XCTAssertEqual(event.durationMs, 500)
        XCTAssertEqual(event.isError, false)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testToolCompletedEventNilSessionId() {
        let event = ToolCompletedEvent(sessionId: nil, toolUseId: "tu-2", toolName: "t", durationMs: 0, isError: true)
        XCTAssertNil(event.sessionId)
    }

    func testToolCompletedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = ToolCompletedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 100, isError: false)
        acceptEvent(event)
    }

    func testToolCompletedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(ToolCompletedEvent(sessionId: nil, toolUseId: "tu", toolName: "t", durationMs: 0, isError: false))
    }

    func testToolCompletedEventCodableRoundTrip() throws {
        let event = ToolCompletedEvent(sessionId: "sess-1", toolUseId: "tu-5", toolName: "BashTool", durationMs: 3500, isError: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ToolCompletedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.toolUseId, event.toolUseId)
        XCTAssertEqual(decoded.toolName, event.toolName)
        XCTAssertEqual(decoded.durationMs, event.durationMs)
        XCTAssertEqual(decoded.isError, event.isError)
    }

    func testToolCompletedEventSnakeCaseJsonKeys() throws {
        let event = ToolCompletedEvent(sessionId: "s1", toolUseId: "tu-1", toolName: "BashTool", durationMs: 100, isError: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["tool_use_id"])
        XCTAssertNotNil(json["tool_name"])
        XCTAssertNotNil(json["duration_ms"])
        XCTAssertNotNil(json["is_error"])
    }

    func testToolCompletedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 100, isError: false)
        let e2 = ToolCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 100, isError: false)
        XCTAssertEqual(e1, e2)
    }

    func testToolCompletedEventNotEqualDifferentDuration() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 100, isError: false)
        let e2 = ToolCompletedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 200, isError: false)
        XCTAssertNotEqual(e1, e2)
    }

    func testToolCompletedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"comp-id","timestamp":"2024-01-15T12:00:00Z","session_id":"comp-sess","tool_use_id":"tu-1","tool_name":"BashTool","duration_ms":2500,"is_error":false}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ToolCompletedEvent.self, from: data)

        XCTAssertEqual(event.id, "comp-id")
        XCTAssertEqual(event.toolName, "BashTool")
        XCTAssertEqual(event.durationMs, 2500)
        XCTAssertEqual(event.isError, false)
    }

    func testToolCompletedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"tool_use_id":"tu","tool_name":"t","duration_ms":0,"is_error":true}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ToolCompletedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertTrue(event.isError)
    }

    func testToolCompletedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","tool_use_id":"tu"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(ToolCompletedEvent.self, from: data))
    }

    func testToolCompletedEventImmutablePayload() {
        let event = ToolCompletedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 100, isError: false)
        XCTAssertEqual(event.durationMs, 100)
        XCTAssertEqual(event.isError, false)
    }

    // MARK: - ToolFailedEvent (AC4)

    func testToolFailedEventConstruction() {
        let event = ToolFailedEvent(sessionId: "sess-1", toolUseId: "tu-1", toolName: "BashTool", error: "command not found")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.toolUseId, "tu-1")
        XCTAssertEqual(event.toolName, "BashTool")
        XCTAssertEqual(event.error, "command not found")
        XCTAssertFalse(event.id.isEmpty)
    }

    func testToolFailedEventNilSessionId() {
        let event = ToolFailedEvent(sessionId: nil, toolUseId: "tu-2", toolName: "t", error: "crash")
        XCTAssertNil(event.sessionId)
    }

    func testToolFailedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = ToolFailedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", error: "err")
        acceptEvent(event)
    }

    func testToolFailedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(ToolFailedEvent(sessionId: nil, toolUseId: "tu", toolName: "t", error: "e"))
    }

    func testToolFailedEventCodableRoundTrip() throws {
        let event = ToolFailedEvent(sessionId: "sess-1", toolUseId: "tu-5", toolName: "BashTool", error: "timeout")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ToolFailedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.toolUseId, event.toolUseId)
        XCTAssertEqual(decoded.toolName, event.toolName)
        XCTAssertEqual(decoded.error, event.error)
    }

    func testToolFailedEventSnakeCaseJsonKeys() throws {
        let event = ToolFailedEvent(sessionId: "s1", toolUseId: "tu-1", toolName: "BashTool", error: "err")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["tool_use_id"])
        XCTAssertNotNil(json["tool_name"])
        XCTAssertNotNil(json["error"])
    }

    func testToolFailedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", error: "e")
        let e2 = ToolFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", error: "e")
        XCTAssertEqual(e1, e2)
    }

    func testToolFailedEventNotEqualDifferentError() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = ToolFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", error: "err-a")
        let e2 = ToolFailedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", toolUseId: "tu", toolName: "t", error: "err-b")
        XCTAssertNotEqual(e1, e2)
    }

    func testToolFailedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"fail-id","timestamp":"2024-01-15T12:00:00Z","session_id":"fail-sess","tool_use_id":"tu-1","tool_name":"BashTool","error":"permission denied"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(ToolFailedEvent.self, from: data)

        XCTAssertEqual(event.id, "fail-id")
        XCTAssertEqual(event.toolName, "BashTool")
        XCTAssertEqual(event.error, "permission denied")
    }

    func testToolFailedEventDecodeMissingErrorField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","tool_use_id":"tu","tool_name":"t"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(ToolFailedEvent.self, from: data))
    }

    func testToolFailedEventImmutablePayload() {
        let event = ToolFailedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", error: "e")
        XCTAssertEqual(event.error, "e")
    }

    // MARK: - Tool Events Edge Cases

    func testToolStartedEventEmptyToolName() {
        let event = ToolStartedEvent(sessionId: nil, toolName: "", toolUseId: "tu", input: nil)
        XCTAssertTrue(event.toolName.isEmpty)
    }

    func testToolStartedEventEmptyToolUseId() {
        let event = ToolStartedEvent(sessionId: nil, toolName: "t", toolUseId: "", input: nil)
        XCTAssertTrue(event.toolUseId.isEmpty)
    }

    func testToolStartedEventEmptyInput() {
        let event = ToolStartedEvent(sessionId: "s", toolName: "t", toolUseId: "tu", input: "")
        XCTAssertEqual(event.input, "")
    }

    func testToolStreamingEventEmptyChunk() {
        let event = ToolStreamingEvent(sessionId: nil, toolUseId: "tu", chunk: "")
        XCTAssertTrue(event.chunk.isEmpty)
    }

    func testToolCompletedEventZeroDuration() {
        let event = ToolCompletedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 0, isError: false)
        XCTAssertEqual(event.durationMs, 0)
    }

    func testToolFailedEventEmptyError() {
        let event = ToolFailedEvent(sessionId: nil, toolUseId: "tu", toolName: "t", error: "")
        XCTAssertTrue(event.error.isEmpty)
    }

    // MARK: - Tool Events Existential Usage (AC5)

    func testToolEventsAsAgentEventExistential() {
        let events: [any AgentEvent] = [
            ToolStartedEvent(sessionId: "s1", toolName: "BashTool", toolUseId: "tu-1", input: nil),
            ToolStreamingEvent(sessionId: "s2", toolUseId: "tu-2", chunk: "data"),
            ToolCompletedEvent(sessionId: "s3", toolUseId: "tu-3", toolName: "FileTool", durationMs: 100, isError: false),
            ToolFailedEvent(sessionId: "s4", toolUseId: "tu-4", toolName: "BashTool", error: "fail")
        ]
        XCTAssertEqual(events.count, 4)
        for event in events {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
    }

    // MARK: - Actor Boundary (AC5)

    func testToolStartedEventSendableAcrossActor() async {
        let event = ToolStartedEvent(sessionId: "s", toolName: "BashTool", toolUseId: "tu", input: "i")
        let retrieved = await Self.toolStartedEchoActor.send(event)
        XCTAssertEqual(retrieved.toolName, "BashTool")
    }

    func testToolStreamingEventSendableAcrossActor() async {
        let event = ToolStreamingEvent(sessionId: "s", toolUseId: "tu", chunk: "chunk-data")
        let retrieved = await Self.toolStreamingEchoActor.send(event)
        XCTAssertEqual(retrieved.chunk, "chunk-data")
    }

    func testToolCompletedEventSendableAcrossActor() async {
        let event = ToolCompletedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", durationMs: 500, isError: false)
        let retrieved = await Self.toolCompletedEchoActor.send(event)
        XCTAssertEqual(retrieved.durationMs, 500)
    }

    func testToolFailedEventSendableAcrossActor() async {
        let event = ToolFailedEvent(sessionId: "s", toolUseId: "tu", toolName: "t", error: "err")
        let retrieved = await Self.toolFailedEchoActor.send(event)
        XCTAssertEqual(retrieved.error, "err")
    }
}

// MARK: - Tool Event Test Helpers

private extension AgentEventTypesTests {
    actor ToolStartedEchoActor {
        func send(_ event: ToolStartedEvent) -> ToolStartedEvent { event }
    }

    actor ToolStreamingEchoActor {
        func send(_ event: ToolStreamingEvent) -> ToolStreamingEvent { event }
    }

    actor ToolCompletedEchoActor {
        func send(_ event: ToolCompletedEvent) -> ToolCompletedEvent { event }
    }

    actor ToolFailedEchoActor {
        func send(_ event: ToolFailedEvent) -> ToolFailedEvent { event }
    }

    static let toolStartedEchoActor = ToolStartedEchoActor()
    static let toolStreamingEchoActor = ToolStreamingEchoActor()
    static let toolCompletedEchoActor = ToolCompletedEchoActor()
    static let toolFailedEchoActor = ToolFailedEchoActor()
}

// MARK: - LLM Cost Events

extension AgentEventTypesTests {

    // MARK: - LLMRequestStartedEvent (AC1)

    func testLLMRequestStartedEventConstruction() {
        let event = LLMRequestStartedEvent(sessionId: "sess-1", model: "claude-sonnet-4-6")
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.model, "claude-sonnet-4-6")
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    func testLLMRequestStartedEventNilSessionId() {
        let event = LLMRequestStartedEvent(sessionId: nil, model: "glm-5.1")
        XCTAssertNil(event.sessionId)
    }

    func testLLMRequestStartedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
        let event = LLMRequestStartedEvent(sessionId: "s", model: "m")
        acceptEvent(event)
    }

    func testLLMRequestStartedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(LLMRequestStartedEvent(sessionId: nil, model: "m"))
    }

    func testLLMRequestStartedEventCodableRoundTrip() throws {
        let event = LLMRequestStartedEvent(sessionId: "sess-42", model: "claude-opus-4-7")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LLMRequestStartedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.model, event.model)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince(event.timestamp), 0, accuracy: 1.0)
    }

    func testLLMRequestStartedEventSnakeCaseJsonKeys() throws {
        let event = LLMRequestStartedEvent(sessionId: "s1", model: "m")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"], "JSON should use snake_case 'session_id'")
        XCTAssertNotNil(json["model"])
        XCTAssertNotNil(json["id"])
        XCTAssertNotNil(json["timestamp"])
    }

    func testLLMRequestStartedEventEquatable() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMRequestStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m")
        let e2 = LLMRequestStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m")
        XCTAssertEqual(e1, e2)
    }

    func testLLMRequestStartedEventNotEqualDifferentModel() {
        let id = "same-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMRequestStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "model-a")
        let e2 = LLMRequestStartedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "model-b")
        XCTAssertNotEqual(e1, e2)
    }

    func testLLMRequestStartedEventInitWithBase() {
        let event = LLMRequestStartedEvent(base: BaseAgentEvent(id: "custom", timestamp: Date(timeIntervalSince1970: 0)), sessionId: "s", model: "m")
        XCTAssertEqual(event.id, "custom")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
    }

    func testLLMRequestStartedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"raw-id","timestamp":"2024-01-15T12:00:00Z","session_id":"raw-sess","model":"claude-sonnet-4-6"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMRequestStartedEvent.self, from: data)

        XCTAssertEqual(event.id, "raw-id")
        XCTAssertEqual(event.sessionId, "raw-sess")
        XCTAssertEqual(event.model, "claude-sonnet-4-6")
    }

    func testLLMRequestStartedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(LLMRequestStartedEvent.self, from: data))
    }

    func testLLMRequestStartedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"model":"m"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMRequestStartedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.model, "m")
    }

    func testLLMRequestStartedEventImmutablePayload() {
        let event = LLMRequestStartedEvent(sessionId: "s", model: "m")
        XCTAssertEqual(event.model, "m")
    }

    // MARK: - LLMResponseReceivedEvent (AC2)

    func testLLMResponseReceivedEventConstruction() {
        let event = LLMResponseReceivedEvent(sessionId: "sess-1", model: "claude-sonnet-4-6", durationMs: 3500)
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.model, "claude-sonnet-4-6")
        XCTAssertEqual(event.durationMs, 3500)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testLLMResponseReceivedEventNilSessionId() {
        let event = LLMResponseReceivedEvent(sessionId: nil, model: "m", durationMs: 100)
        XCTAssertNil(event.sessionId)
    }

    func testLLMResponseReceivedEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = LLMResponseReceivedEvent(sessionId: "s", model: "m", durationMs: 500)
        acceptEvent(event)
    }

    func testLLMResponseReceivedEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(LLMResponseReceivedEvent(sessionId: nil, model: "m", durationMs: 0))
    }

    func testLLMResponseReceivedEventCodableRoundTrip() throws {
        let event = LLMResponseReceivedEvent(sessionId: "sess-1", model: "glm-5.1", durationMs: 4200)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LLMResponseReceivedEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.model, event.model)
        XCTAssertEqual(decoded.durationMs, event.durationMs)
    }

    func testLLMResponseReceivedEventSnakeCaseJsonKeys() throws {
        let event = LLMResponseReceivedEvent(sessionId: "s1", model: "m", durationMs: 100)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["model"])
        XCTAssertNotNil(json["duration_ms"])
    }

    func testLLMResponseReceivedEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMResponseReceivedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", durationMs: 100)
        let e2 = LLMResponseReceivedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", durationMs: 100)
        XCTAssertEqual(e1, e2)
    }

    func testLLMResponseReceivedEventNotEqualDifferentDuration() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMResponseReceivedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", durationMs: 100)
        let e2 = LLMResponseReceivedEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", durationMs: 200)
        XCTAssertNotEqual(e1, e2)
    }

    func testLLMResponseReceivedEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"resp-id","timestamp":"2024-01-15T12:00:00Z","session_id":"resp-sess","model":"glm-5.1","duration_ms":2500}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMResponseReceivedEvent.self, from: data)

        XCTAssertEqual(event.id, "resp-id")
        XCTAssertEqual(event.model, "glm-5.1")
        XCTAssertEqual(event.durationMs, 2500)
    }

    func testLLMResponseReceivedEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","model":"m"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(LLMResponseReceivedEvent.self, from: data))
    }

    func testLLMResponseReceivedEventInitWithBase() {
        let event = LLMResponseReceivedEvent(base: BaseAgentEvent(id: "custom", timestamp: Date(timeIntervalSince1970: 0)), sessionId: "s", model: "m", durationMs: 500)
        XCTAssertEqual(event.id, "custom")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.durationMs, 500)
    }

    func testLLMResponseReceivedEventDecodeNilSessionId() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"model":"m","duration_ms":100}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMResponseReceivedEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.model, "m")
        XCTAssertEqual(event.durationMs, 100)
    }

    func testLLMResponseReceivedEventImmutablePayload() {
        let event = LLMResponseReceivedEvent(sessionId: "s", model: "m", durationMs: 100)
        XCTAssertEqual(event.durationMs, 100)
    }

    // MARK: - LLMCostEvent (AC3)

    func testLLMCostEventConstruction() {
        let event = LLMCostEvent(
            sessionId: "sess-1",
            model: "claude-sonnet-4-6",
            inputTokens: 1500,
            outputTokens: 800,
            cacheCreationInputTokens: 200,
            cacheReadInputTokens: 100,
            estimatedCostUsd: 0.034
        )
        XCTAssertEqual(event.sessionId, "sess-1")
        XCTAssertEqual(event.model, "claude-sonnet-4-6")
        XCTAssertEqual(event.inputTokens, 1500)
        XCTAssertEqual(event.outputTokens, 800)
        XCTAssertEqual(event.cacheCreationInputTokens, 200)
        XCTAssertEqual(event.cacheReadInputTokens, 100)
        XCTAssertEqual(event.estimatedCostUsd, 0.034, accuracy: 0.0001)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testLLMCostEventNilSessionIdAndCacheTokens() {
        let event = LLMCostEvent(
            sessionId: nil,
            model: "m",
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: nil,
            cacheReadInputTokens: nil,
            estimatedCostUsd: 0.01
        )
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.cacheCreationInputTokens)
        XCTAssertNil(event.cacheReadInputTokens)
    }

    func testLLMCostEventAgentEventConformance() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = LLMCostEvent(sessionId: "s", model: "m", inputTokens: 1, outputTokens: 1, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.0)
        acceptEvent(event)
    }

    func testLLMCostEventSendable() {
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(LLMCostEvent(sessionId: nil, model: "m", inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.0))
    }

    func testLLMCostEventCodableRoundTrip() throws {
        let event = LLMCostEvent(
            sessionId: "sess-1",
            model: "claude-opus-4-7",
            inputTokens: 5000,
            outputTokens: 2000,
            cacheCreationInputTokens: 1000,
            cacheReadInputTokens: 500,
            estimatedCostUsd: 0.15
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LLMCostEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.model, event.model)
        XCTAssertEqual(decoded.inputTokens, event.inputTokens)
        XCTAssertEqual(decoded.outputTokens, event.outputTokens)
        XCTAssertEqual(decoded.cacheCreationInputTokens, event.cacheCreationInputTokens)
        XCTAssertEqual(decoded.cacheReadInputTokens, event.cacheReadInputTokens)
        XCTAssertEqual(decoded.estimatedCostUsd, event.estimatedCostUsd, accuracy: 0.0001)
    }

    func testLLMCostEventSnakeCaseJsonKeys() throws {
        let event = LLMCostEvent(
            sessionId: "s1",
            model: "m",
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: 10,
            cacheReadInputTokens: 5,
            estimatedCostUsd: 0.01
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["model"])
        XCTAssertNotNil(json["input_tokens"])
        XCTAssertNotNil(json["output_tokens"])
        XCTAssertNotNil(json["cache_creation_input_tokens"])
        XCTAssertNotNil(json["cache_read_input_tokens"])
        XCTAssertNotNil(json["estimated_cost_usd"])
    }

    func testLLMCostEventEquatable() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMCostEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.01)
        let e2 = LLMCostEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.01)
        XCTAssertEqual(e1, e2)
    }

    func testLLMCostEventNotEqualDifferentTokens() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMCostEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.01)
        let e2 = LLMCostEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", inputTokens: 200, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.01)
        XCTAssertNotEqual(e1, e2)
    }

    func testLLMCostEventNotEqualDifferentCost() {
        let id = "eq-id"
        let ts = Date(timeIntervalSince1970: 1700000000)
        let e1 = LLMCostEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.01)
        let e2 = LLMCostEvent(base: BaseAgentEvent(id: id, timestamp: ts), sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.99)
        XCTAssertNotEqual(e1, e2)
    }

    func testLLMCostEventDecodeFromRawJson() throws {
        let jsonString = """
        {"id":"cost-id","timestamp":"2024-01-15T12:00:00Z","session_id":"cost-sess","model":"glm-5.1","input_tokens":3000,"output_tokens":1500,"cache_creation_input_tokens":500,"cache_read_input_tokens":200,"estimated_cost_usd":0.075}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMCostEvent.self, from: data)

        XCTAssertEqual(event.id, "cost-id")
        XCTAssertEqual(event.model, "glm-5.1")
        XCTAssertEqual(event.inputTokens, 3000)
        XCTAssertEqual(event.outputTokens, 1500)
        XCTAssertEqual(event.cacheCreationInputTokens, 500)
        XCTAssertEqual(event.cacheReadInputTokens, 200)
        XCTAssertEqual(event.estimatedCostUsd, 0.075, accuracy: 0.0001)
    }

    func testLLMCostEventDecodeNilCacheTokens() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","session_id":null,"model":"m","input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":null,"cache_read_input_tokens":null,"estimated_cost_usd":0.01}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMCostEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.cacheCreationInputTokens)
        XCTAssertNil(event.cacheReadInputTokens)
    }

    func testLLMCostEventDecodeMissingCacheTokensOmitted() throws {
        let jsonString = """
        {"id":"n","timestamp":"2024-01-15T12:00:00Z","model":"m","input_tokens":100,"output_tokens":50,"estimated_cost_usd":0.01}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LLMCostEvent.self, from: data)
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.cacheCreationInputTokens)
        XCTAssertNil(event.cacheReadInputTokens)
        XCTAssertEqual(event.inputTokens, 100)
    }

    func testLLMCostEventDecodeMissingRequiredField() {
        let jsonString = """
        {"id":"bad","timestamp":"2024-01-15T12:00:00Z","model":"m"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(LLMCostEvent.self, from: data))
    }

    func testLLMCostEventImmutablePayload() {
        let event = LLMCostEvent(sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.01)
        XCTAssertEqual(event.inputTokens, 100)
        XCTAssertEqual(event.outputTokens, 50)
        XCTAssertEqual(event.estimatedCostUsd, 0.01, accuracy: 0.0001)
    }

    // MARK: - LLM Events Existential Usage

    func testLLMEventsAsAgentEventExistential() {
        let events: [any AgentEvent] = [
            LLMRequestStartedEvent(sessionId: "s1", model: "claude-sonnet-4-6"),
            LLMResponseReceivedEvent(sessionId: "s2", model: "glm-5.1", durationMs: 500),
            LLMCostEvent(sessionId: "s3", model: "claude-opus-4-7", inputTokens: 1000, outputTokens: 500, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.05),
        ]
        XCTAssertEqual(events.count, 3)
        for event in events {
            XCTAssertFalse(event.id.isEmpty)
            XCTAssertNotNil(event.timestamp)
        }
    }

    // MARK: - LLM Events Edge Cases

    func testLLMRequestStartedEventEmptyModel() {
        let event = LLMRequestStartedEvent(sessionId: nil, model: "")
        XCTAssertTrue(event.model.isEmpty)
    }

    func testLLMResponseReceivedEventZeroDuration() {
        let event = LLMResponseReceivedEvent(sessionId: nil, model: "m", durationMs: 0)
        XCTAssertEqual(event.durationMs, 0)
    }

    func testLLMCostEventZeroTokens() {
        let event = LLMCostEvent(sessionId: nil, model: "m", inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.0)
        XCTAssertEqual(event.inputTokens, 0)
        XCTAssertEqual(event.outputTokens, 0)
        XCTAssertEqual(event.estimatedCostUsd, 0.0)
    }

    func testLLMCostEventZeroCost() {
        let event = LLMCostEvent(sessionId: "s", model: "m", inputTokens: 500, outputTokens: 200, cacheCreationInputTokens: 100, cacheReadInputTokens: 50, estimatedCostUsd: 0.0)
        XCTAssertEqual(event.estimatedCostUsd, 0.0)
    }

    func testLLMCostEventZeroCacheTokens() {
        let event = LLMCostEvent(sessionId: "s", model: "m", inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 0, cacheReadInputTokens: 0, estimatedCostUsd: 0.01)
        XCTAssertEqual(event.cacheCreationInputTokens, 0)
        XCTAssertEqual(event.cacheReadInputTokens, 0)
    }

    // MARK: - Actor Boundary (Sendable across actors)

    func testLLMRequestStartedEventSendableAcrossActor() async {
        let event = LLMRequestStartedEvent(sessionId: "s", model: "claude-sonnet-4-6")
        let retrieved = await Self.llmRequestStartedEchoActor.send(event)
        XCTAssertEqual(retrieved.model, "claude-sonnet-4-6")
    }

    func testLLMResponseReceivedEventSendableAcrossActor() async {
        let event = LLMResponseReceivedEvent(sessionId: "s", model: "glm-5.1", durationMs: 1200)
        let retrieved = await Self.llmResponseReceivedEchoActor.send(event)
        XCTAssertEqual(retrieved.durationMs, 1200)
    }

    func testLLMCostEventSendableAcrossActor() async {
        let event = LLMCostEvent(sessionId: "s", model: "claude-opus-4-7", inputTokens: 3000, outputTokens: 1500, cacheCreationInputTokens: 500, cacheReadInputTokens: 200, estimatedCostUsd: 0.12)
        let retrieved = await Self.llmCostEchoActor.send(event)
        XCTAssertEqual(retrieved.inputTokens, 3000)
        XCTAssertEqual(retrieved.outputTokens, 1500)
    }
}

// MARK: - LLM Event Test Helpers

private extension AgentEventTypesTests {
    actor LLMRequestStartedEchoActor {
        func send(_ event: LLMRequestStartedEvent) -> LLMRequestStartedEvent { event }
    }

    actor LLMResponseReceivedEchoActor {
        func send(_ event: LLMResponseReceivedEvent) -> LLMResponseReceivedEvent { event }
    }

    actor LLMCostEchoActor {
        func send(_ event: LLMCostEvent) -> LLMCostEvent { event }
    }

    static let llmRequestStartedEchoActor = LLMRequestStartedEchoActor()
    static let llmResponseReceivedEchoActor = LLMResponseReceivedEchoActor()
    static let llmCostEchoActor = LLMCostEchoActor()
}
