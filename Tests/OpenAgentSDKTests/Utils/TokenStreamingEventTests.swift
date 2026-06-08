import XCTest
@testable import OpenAgentSDK
import _Concurrency

final class TokenStreamingEventTests: XCTestCase {

    private static let testEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let testDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - AC1: AgentOptions.emitTokenStream default is false

    func testAgentOptionsEmitTokenStreamDefaultIsFalse() {
        let options = AgentOptions()
        XCTAssertFalse(options.emitTokenStream)
    }

    func testAgentOptionsEmitTokenStreamExplicitTrue() {
        let options = AgentOptions(emitTokenStream: true)
        XCTAssertTrue(options.emitTokenStream)
    }

    // MARK: - AC2: LLMTokenStreamEvent construction

    func testLLMTokenStreamEventConstruction() {
        let event = LLMTokenStreamEvent(sessionId: "s1", chunk: "Hello")
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
        XCTAssertEqual(event.sessionId, "s1")
        XCTAssertEqual(event.chunk, "Hello")
    }

    func testLLMTokenStreamEventNilSessionId() {
        let event = LLMTokenStreamEvent(sessionId: nil, chunk: "world")
        XCTAssertNil(event.sessionId)
        XCTAssertEqual(event.chunk, "world")
    }

    func testLLMTokenStreamEventEmptyChunk() {
        let event = LLMTokenStreamEvent(sessionId: "s1", chunk: "")
        XCTAssertEqual(event.chunk, "")
    }

    // MARK: - AC2: LLMTokenStreamEvent AgentEvent conformance

    func testLLMTokenStreamEventConformsToAgentEvent() {
        func acceptEvent<T: AgentEvent>(_ event: T) {
            XCTAssertFalse(event.id.isEmpty)
        }
        let event = LLMTokenStreamEvent(sessionId: "s1", chunk: "test")
        acceptEvent(event)
    }

    // MARK: - AC2: LLMTokenStreamEvent Equatable

    func testLLMTokenStreamEventEquatable() {
        let base = BaseAgentEvent(id: "same", timestamp: Date(timeIntervalSince1970: 1000))
        let event1 = LLMTokenStreamEvent(base: base, sessionId: "s1", chunk: "hello")
        let event2 = LLMTokenStreamEvent(base: base, sessionId: "s1", chunk: "hello")
        XCTAssertEqual(event1, event2)
    }

    func testLLMTokenStreamEventNotEqualDifferentChunk() {
        let base = BaseAgentEvent(id: "same", timestamp: Date(timeIntervalSince1970: 1000))
        let event1 = LLMTokenStreamEvent(base: base, sessionId: "s1", chunk: "hello")
        let event2 = LLMTokenStreamEvent(base: base, sessionId: "s1", chunk: "world")
        XCTAssertNotEqual(event1, event2)
    }

    // MARK: - AC2: LLMTokenStreamEvent Codable round-trip

    func testLLMTokenStreamEventCodableRoundTrip() throws {
        let event = LLMTokenStreamEvent(
            base: BaseAgentEvent(id: "test-id", timestamp: Date(timeIntervalSince1970: 1700000000)),
            sessionId: "s1",
            chunk: "Hello, world!"
        )
        let data = try Self.testEncoder.encode(event)

        let decoded = try Self.testDecoder.decode(LLMTokenStreamEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince(event.timestamp), 0, accuracy: 1.0)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
        XCTAssertEqual(decoded.chunk, event.chunk)
    }

    func testLLMTokenStreamEventCodableNilSessionId() throws {
        let event = LLMTokenStreamEvent(
            base: BaseAgentEvent(id: "id2", timestamp: Date(timeIntervalSince1970: 1700000001)),
            sessionId: nil,
            chunk: "data"
        )
        let data = try Self.testEncoder.encode(event)

        let decoded = try Self.testDecoder.decode(LLMTokenStreamEvent.self, from: data)

        XCTAssertNil(decoded.sessionId)
        XCTAssertEqual(decoded.chunk, "data")
    }

    // MARK: - AC6: SSE mapping returns nil for LLMTokenStreamEvent

    func testLLMTokenStreamEventSSEMappingReturnsNil() {
        let event = LLMTokenStreamEvent(sessionId: "s1", chunk: "text")
        XCTAssertNil(AgentEventSSEMapping.map(event))
    }

    func testLLMTokenStreamEventSSEMappingNilSessionId() {
        let event = LLMTokenStreamEvent(sessionId: nil, chunk: "chunk")
        XCTAssertNil(AgentEventSSEMapping.map(event))
    }

    // MARK: - AC3 & AC4: EventBus publish/subscribe for LLMTokenStreamEvent

    func testEventBusPublishesLLMTokenStreamEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        await bus.publish(LLMTokenStreamEvent(sessionId: "s1", chunk: "Hello "))
        await bus.publish(LLMTokenStreamEvent(sessionId: "s1", chunk: "world"))
        await bus.publish(LLMTokenStreamEvent(sessionId: "s1", chunk: "!"))

        let collected = await collectEventsWithTimeout(stream: stream, count: 3)

        XCTAssertEqual(collected.count, 3)
        let tokenEvents = collected.compactMap { $0 as? LLMTokenStreamEvent }
        XCTAssertEqual(tokenEvents.count, 3)
        XCTAssertEqual(tokenEvents[0].chunk, "Hello ")
        XCTAssertEqual(tokenEvents[1].chunk, "world")
        XCTAssertEqual(tokenEvents[2].chunk, "!")
    }

    func testEventBusTypeFilteredSubscribeForLLMTokenStreamEvent() async {
        let bus = EventBus()
        let typedStream = await bus.subscribe(LLMTokenStreamEvent.self)

        // Publish a mix of events
        await bus.publish(AgentStartedEvent(sessionId: "s1", task: "test"))
        await bus.publish(LLMTokenStreamEvent(sessionId: "s1", chunk: "Hello"))
        await bus.publish(AgentCompletedEvent(sessionId: "s1", totalSteps: 1, durationMs: 100, resultText: "done"))
        await bus.publish(LLMTokenStreamEvent(sessionId: "s1", chunk: " world"))

        let collected = await collectTypedEventsWithTimeout(stream: typedStream, count: 2)

        XCTAssertEqual(collected.count, 2)
        XCTAssertEqual(collected[0].chunk, "Hello")
        XCTAssertEqual(collected[1].chunk, " world")
    }

    // MARK: - AC4: emitTokenStream == false → no LLMTokenStreamEvent in mixed stream

    func testNoLLMTokenStreamEventInMixedPublish() async {
        let bus = EventBus()
        let typedStream = await bus.subscribe(LLMTokenStreamEvent.self)

        // Publish only non-token-stream events
        await bus.publish(AgentStartedEvent(sessionId: "s1", task: "test"))
        await bus.publish(AgentCompletedEvent(sessionId: "s1", totalSteps: 1, durationMs: 100, resultText: "done"))

        let collected = await collectTypedEventsWithTimeout(stream: typedStream, count: 1, timeoutNs: 100_000_000)

        XCTAssertEqual(collected.count, 0, "No LLMTokenStreamEvent should be in the typed stream")
    }

    // MARK: - AC5: ToolStreamingEvent not affected by LLMTokenStreamEvent

    func testToolStreamingEventCoexistsWithTokenStreamEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        await bus.publish(LLMTokenStreamEvent(sessionId: "s1", chunk: "text"))
        await bus.publish(ToolStreamingEvent(sessionId: "s1", toolUseId: "tu1", chunk: "output"))

        let collected = await collectEventsWithTimeout(stream: stream, count: 2)

        XCTAssertEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is LLMTokenStreamEvent)
        XCTAssertTrue(collected[1] is ToolStreamingEvent)

        let toolEvent = collected[1] as! ToolStreamingEvent
        XCTAssertEqual(toolEvent.chunk, "output")
    }

    // MARK: - AC4: emitTokenStream == true but eventBus == nil — no crash

    func testEmitTokenStreamTrueWithNilEventBusNoCrash() {
        let options = AgentOptions(eventBus: nil, emitTokenStream: true)
        XCTAssertTrue(options.emitTokenStream)
        XCTAssertNil(options.eventBus)
    }

    // MARK: - Timeout-Protected Collection Helpers

    private static let defaultTimeoutNs: UInt64 = 5_000_000_000

    private func collectEventsWithTimeout(
        stream: AsyncStream<any AgentEvent>,
        count: Int,
        timeoutNs: UInt64 = TokenStreamingEventTests.defaultTimeoutNs
    ) async -> [any AgentEvent] {
        await withTaskGroup(of: [any AgentEvent].self, returning: [any AgentEvent].self) { group in
            group.addTask {
                var events: [any AgentEvent] = []
                for await event in stream {
                    events.append(event)
                    if events.count >= count { break }
                }
                return events
            }
            group.addTask {
                try? await _Concurrency.Task.sleep(nanoseconds: timeoutNs)
                return []
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }
    }

    private func collectTypedEventsWithTimeout<T: AgentEvent>(
        stream: AsyncStream<T>,
        count: Int,
        timeoutNs: UInt64 = TokenStreamingEventTests.defaultTimeoutNs
    ) async -> [T] {
        await withTaskGroup(of: [T].self, returning: [T].self) { group in
            group.addTask {
                var events: [T] = []
                for await event in stream {
                    events.append(event)
                    if events.count >= count { break }
                }
                return events
            }
            group.addTask {
                try? await _Concurrency.Task.sleep(nanoseconds: timeoutNs)
                return []
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }
    }
}
