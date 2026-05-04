import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import OpenAgentSDK

// MARK: - AC3: Streaming SSE Response

final class StreamingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// Helper to build a complete SSE response body from individual events.
    func buildSSEResponse(events: [(event: String, data: String)]) -> Data {
        var body = ""
        for evt in events {
            body += "event: \(evt.event)\n"
            body += "data: \(evt.data)\n\n"
        }
        return Data(body.utf8)
    }

    /// AC3: streamMessage returns an AsyncThrowingStream that yields SSEEvent values.
    func testStreamMessageReturnsAsyncThrowingStream() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "message_delta", data: """
                {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var collectedEvents: [SSEEvent] = []
        for try await event in stream {
            collectedEvents.append(event)
        }

        XCTAssertFalse(collectedEvents.isEmpty, "Should receive at least one SSE event")
    }

    /// AC3: text_delta events are parsed incrementally.
    func testTextDeltaParsedIncrementally() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello "}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"World"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var textDeltas: [[String: Any]] = []
        for try await event in stream {
            if case .contentBlockDelta(_, let delta) = event {
                if delta["type"] as? String == "text_delta" {
                    textDeltas.append(delta)
                }
            }
        }

        XCTAssertEqual(textDeltas.count, 2, "Should receive exactly 2 text_delta events")
        XCTAssertEqual(textDeltas[0]["text"] as? String, "Hello ")
        XCTAssertEqual(textDeltas[1]["text"] as? String, "World")
    }

    /// AC3: input_json_delta events are parsed for tool input streaming.
    func testInputJSONDeltaParsedForToolInput() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01","name":"get_weather","input":{}}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"location\\":\\"SF\\"}"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Weather in SF?"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var jsonDeltas: [[String: Any]] = []
        for try await event in stream {
            if case .contentBlockDelta(_, let delta) = event {
                if delta["type"] as? String == "input_json_delta" {
                    jsonDeltas.append(delta)
                }
            }
        }

        XCTAssertEqual(jsonDeltas.count, 1)
        let partialJSON = jsonDeltas[0]["partial_json"] as? String
        XCTAssertNotNil(partialJSON)

        // Verify the partial JSON can be parsed
        let jsonData = Data(partialJSON!.utf8)
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertEqual(parsed?["location"] as? String, "SF")
    }

    /// AC3: thinking_delta events are parsed incrementally.
    func testThinkingDeltaParsed() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me think..."}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"EqQBCg..."}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Think"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var thinkingDeltas: [[String: Any]] = []
        var signatureDeltas: [[String: Any]] = []
        for try await event in stream {
            if case .contentBlockDelta(_, let delta) = event {
                if delta["type"] as? String == "thinking_delta" {
                    thinkingDeltas.append(delta)
                } else if delta["type"] as? String == "signature_delta" {
                    signatureDeltas.append(delta)
                }
            }
        }

        XCTAssertEqual(thinkingDeltas.count, 1, "Should receive 1 thinking_delta")
        XCTAssertEqual(thinkingDeltas[0]["thinking"] as? String, "Let me think...")

        XCTAssertEqual(signatureDeltas.count, 1, "Should receive 1 signature_delta")
        XCTAssertEqual(signatureDeltas[0]["signature"] as? String, "EqQBCg...")
    }

    /// AC3: Complete SSE event sequence with message_start, content blocks, and message_stop.
    func testCompleteSSEEventSequence() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_full","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
            (event: "ping", data: """
                {"type":"ping"}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01","name":"get_weather","input":{}}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"location\\":\\"SF\\"}"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":1}
                """),
            (event: "message_delta", data: """
                {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":89}}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Weather in SF?"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var collectedEvents: [SSEEvent] = []
        for try await event in stream {
            collectedEvents.append(event)
        }

        // Verify the full event sequence
        XCTAssertTrue(collectedEvents.count >= 6, "Should receive at least 6 events, got \(collectedEvents.count)")

        // First event should be messageStart
        if case .messageStart(let message) = collectedEvents.first {
            XCTAssertEqual(message["id"] as? String, "msg_full")
        } else {
            XCTFail("First event should be messageStart")
        }

        // Last event should be messageStop
        if case .messageStop = collectedEvents.last {
            // pass
        } else {
            XCTFail("Last event should be messageStop")
        }
    }

    /// AC3: ping events are handled without error.
    func testPingEventHandled() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "ping", data: """
                {"type":"ping"}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"pong"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "ping"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var hasPing = false
        for try await event in stream {
            if case .ping = event {
                hasPing = true
            }
        }

        XCTAssertTrue(hasPing, "Should receive a ping event")
    }

    /// AC3: error events in the SSE stream are handled.
    func testSSEErrorEventHandled() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "error", data: """
                {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var hasError = false
        for try await event in stream {
            if case .error(let data) = event {
                hasError = true
                let errorType = data["error"] as? [String: Any]
                XCTAssertEqual(errorType?["type"] as? String, "overloaded_error")
            }
        }

        XCTAssertTrue(hasError, "Should receive an error event from stream")
    }

    /// AC3: Stream request body includes stream: true.
    func testStreamRequestBodySetsStreamTrue() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        // Register a minimal SSE response
        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        let bodyData = request?.httpBody
        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]
        XCTAssertEqual(body?["stream"] as? Bool, true, "stream should be true for streamMessage")
    }

    /// AC3: Stream request includes required headers.
    func testStreamRequestIncludesCorrectHeaders() async throws {
        let sut = makeSUT(apiKey: "sk-test-key-xyz")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        XCTAssertEqual(request?.value(forHTTPHeaderField: "x-api-key"), "sk-test-key-xyz")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "content-type"), "application/json")
    }

    /// AC3: messageDelta event contains stop_reason and usage.
    func testMessageDeltaContainsStopReasonAndUsage() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Done"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "message_delta", data: """
                {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var messageDeltaFound = false
        for try await event in stream {
            if case .messageDelta(let delta, let usage) = event {
                messageDeltaFound = true
                XCTAssertEqual(delta["stop_reason"] as? String, "end_turn")
                XCTAssertEqual(usage["output_tokens"] as? Int, 15)
            }
        }

        XCTAssertTrue(messageDeltaFound, "Should receive a messageDelta event")
    }

    /// AC3: contentBlockStart and contentBlockStop events have correct indices.
    func testContentBlockEventsHaveCorrectIndices() async throws {
        let sut = makeSUT(apiKey: "sk-test-key")

        let sseEvents = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"First"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":0}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01","name":"calc","input":{}}}
                """),
            (event: "content_block_delta", data: """
                {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{}"}}
                """),
            (event: "content_block_stop", data: """
                {"type":"content_block_stop","index":1}
                """),
            (event: "message_stop", data: """
                {"type":"message_stop"}
                """),
        ]

        let responseBody = buildSSEResponse(events: sseEvents)

        MockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Test"]
        ]

        let stream = try await sut.streamMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        var blockStarts: [(index: Int, type: String)] = []
        var blockStops: [Int] = []

        for try await event in stream {
            switch event {
            case .contentBlockStart(let index, let contentBlock):
                blockStarts.append((index: index, type: contentBlock["type"] as? String ?? ""))
            case .contentBlockStop(let index):
                blockStops.append(index)
            default:
                break
            }
        }

        XCTAssertEqual(blockStarts.count, 2, "Should have 2 content_block_start events")
        XCTAssertEqual(blockStarts[0].index, 0)
        XCTAssertEqual(blockStarts[0].type, "text")
        XCTAssertEqual(blockStarts[1].index, 1)
        XCTAssertEqual(blockStarts[1].type, "tool_use")

        XCTAssertEqual(blockStops, [0, 1], "Should have block stops at indices 0 and 1")
    }
}

// MARK: - SSEEvent Enum Tests

final class SSEEventTests: XCTestCase {

    /// Verify SSEEvent.messageStart carries the message dictionary.
    func testMessageStartCase() {
        let message: [String: Any] = ["id": "msg_123", "type": "message", "role": "assistant"]
        let event = SSEEvent.messageStart(message: message)

        if case .messageStart(let msg) = event {
            XCTAssertEqual(msg["id"] as? String, "msg_123")
        } else {
            XCTFail("Expected messageStart case")
        }
    }

    /// Verify SSEEvent.contentBlockStart carries index and content block.
    func testContentBlockStartCase() {
        let block: [String: Any] = ["type": "text", "text": ""]
        let event = SSEEvent.contentBlockStart(index: 0, contentBlock: block)

        if case .contentBlockStart(let idx, let cb) = event {
            XCTAssertEqual(idx, 0)
            XCTAssertEqual(cb["type"] as? String, "text")
        } else {
            XCTFail("Expected contentBlockStart case")
        }
    }

    /// Verify SSEEvent.contentBlockDelta carries index and delta.
    func testContentBlockDeltaCase() {
        let delta: [String: Any] = ["type": "text_delta", "text": "Hello"]
        let event = SSEEvent.contentBlockDelta(index: 0, delta: delta)

        if case .contentBlockDelta(let idx, let d) = event {
            XCTAssertEqual(idx, 0)
            XCTAssertEqual(d["type"] as? String, "text_delta")
            XCTAssertEqual(d["text"] as? String, "Hello")
        } else {
            XCTFail("Expected contentBlockDelta case")
        }
    }

    /// Verify SSEEvent.contentBlockStop carries index.
    func testContentBlockStopCase() {
        let event = SSEEvent.contentBlockStop(index: 2)

        if case .contentBlockStop(let idx) = event {
            XCTAssertEqual(idx, 2)
        } else {
            XCTFail("Expected contentBlockStop case")
        }
    }

    /// Verify SSEEvent.messageDelta carries delta and usage.
    func testMessageDeltaCase() {
        let delta: [String: Any] = ["stop_reason": "end_turn"]
        let usage: [String: Any] = ["output_tokens": 50]
        let event = SSEEvent.messageDelta(delta: delta, usage: usage)

        if case .messageDelta(let d, let u) = event {
            XCTAssertEqual(d["stop_reason"] as? String, "end_turn")
            XCTAssertEqual(u["output_tokens"] as? Int, 50)
        } else {
            XCTFail("Expected messageDelta case")
        }
    }

    /// Verify SSEEvent.messageStop case.
    func testMessageStopCase() {
        let event = SSEEvent.messageStop

        if case .messageStop = event {
            // pass
        } else {
            XCTFail("Expected messageStop case")
        }
    }

    /// Verify SSEEvent.ping case.
    func testPingCase() {
        let event = SSEEvent.ping

        if case .ping = event {
            // pass
        } else {
            XCTFail("Expected ping case")
        }
    }

    /// Verify SSEEvent.error case carries error data.
    func testErrorCase() {
        let data: [String: Any] = ["type": "error", "error": ["message": "Overloaded"]]
        let event = SSEEvent.error(data: data)

        if case .error(let d) = event {
            let error = d["error"] as? [String: Any]
            XCTAssertEqual(error?["message"] as? String, "Overloaded")
        } else {
            XCTFail("Expected error case")
        }
    }

    /// Verify SSEEvent conforms to Sendable for safe concurrency.
    func testSSEEventIsSendable() {
        // Compile-time check: SSEEvent conforms to Sendable via @unchecked Sendable.
        let event: SSEEvent = .ping
        // Force the value to cross a concurrency boundary to verify Sendable conformance.
        _Concurrency.Task { @Sendable in
            _ = event
        }
        XCTAssertNotNil(event)
    }
}
