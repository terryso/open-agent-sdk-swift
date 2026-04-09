import XCTest
@testable import OpenAgentSDK

/// Unit tests for SSELineParser and SSEEventDispatcher.
final class SSEParserUnitTests: XCTestCase {

    // MARK: - SSELineParser

    func testParse_singleEvent() {
        let text = "event: message_start\ndata: {\"type\":\"message_start\"}\n\n"
        let results = SSELineParser.parse(text: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event, "message_start")
        XCTAssertEqual(results[0].data, "{\"type\":\"message_start\"}")
    }

    func testParse_multipleEvents() {
        let text = "event: message_start\ndata: {\"a\":1}\n\nevent: message_stop\ndata: {\"b\":2}\n\n"
        let results = SSELineParser.parse(text: text)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].event, "message_start")
        XCTAssertEqual(results[1].event, "message_stop")
    }

    func testParse_emptyInput() {
        let results = SSELineParser.parse(text: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testParse_onlyNewlines() {
        let results = SSELineParser.parse(text: "\n\n\n")
        XCTAssertTrue(results.isEmpty)
    }

    func testParse_dataWithoutEvent_defaultsToMessage() {
        let text = "data: {\"hello\":\"world\"}\n\n"
        let results = SSELineParser.parse(text: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event, "message")
        XCTAssertEqual(results[0].data, "{\"hello\":\"world\"}")
    }

    func testParse_eventWithoutData_ignored() {
        let text = "event: ping\n\n"
        let results = SSELineParser.parse(text: text)
        // event without data is not emitted
        XCTAssertTrue(results.isEmpty)
    }

    func testParse_noTrailingBlankLine() {
        let text = "event: ping\ndata: {}"
        let results = SSELineParser.parse(text: text)
        // Should handle last event without trailing newline
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event, "ping")
        XCTAssertEqual(results[0].data, "{}")
    }

    func testParse_whitespaceInEventAndData() {
        let text = "event:  message_start \ndata:  {\"key\":\"val\"} \n\n"
        let results = SSELineParser.parse(text: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event, "message_start")
        XCTAssertEqual(results[0].data, "{\"key\":\"val\"}")
    }

    func testParse_ignoresNonEventLines() {
        let text = "comment: this is a comment\nevent: ping\ndata: {}\n\n"
        let results = SSELineParser.parse(text: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event, "ping")
    }

    func testParse_complexMultiBlock() {
        let text = """
        event: message_start
        data: {"type":"message_start"}

        event: content_block_start
        data: {"type":"content_block_start","index":0}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0}

        event: message_stop
        data: {"type":"message_stop"}

        """
        let results = SSELineParser.parse(text: text)
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results[0].event, "message_start")
        XCTAssertEqual(results[1].event, "content_block_start")
        XCTAssertEqual(results[2].event, "content_block_delta")
        XCTAssertEqual(results[3].event, "message_stop")
    }

    // MARK: - SSEEventDispatcher

    func testDispatch_messageStart() {
        let result = SSEEventDispatcher.dispatch(
            event: "message_start",
            data: """
            {"type":"message_start","message":{"id":"msg_1","type":"message"}}
            """
        )
        XCTAssertNotNil(result)
        if case .messageStart(let msg) = result {
            XCTAssertEqual(msg["id"] as? String, "msg_1")
        } else {
            XCTFail("Expected messageStart")
        }
    }

    func testDispatch_contentBlockStart() {
        let result = SSEEventDispatcher.dispatch(
            event: "content_block_start",
            data: """
            {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
            """
        )
        XCTAssertNotNil(result)
        if case .contentBlockStart(let idx, let block) = result {
            XCTAssertEqual(idx, 0)
            XCTAssertEqual(block["type"] as? String, "text")
        } else {
            XCTFail("Expected contentBlockStart")
        }
    }

    func testDispatch_contentBlockDelta() {
        let result = SSEEventDispatcher.dispatch(
            event: "content_block_delta",
            data: """
            {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Hi"}}
            """
        )
        XCTAssertNotNil(result)
        if case .contentBlockDelta(let idx, let delta) = result {
            XCTAssertEqual(idx, 1)
            XCTAssertEqual(delta["text"] as? String, "Hi")
        } else {
            XCTFail("Expected contentBlockDelta")
        }
    }

    func testDispatch_contentBlockStop() {
        let result = SSEEventDispatcher.dispatch(
            event: "content_block_stop",
            data: """
            {"type":"content_block_stop","index":2}
            """
        )
        XCTAssertNotNil(result)
        if case .contentBlockStop(let idx) = result {
            XCTAssertEqual(idx, 2)
        } else {
            XCTFail("Expected contentBlockStop")
        }
    }

    func testDispatch_messageDelta() {
        let result = SSEEventDispatcher.dispatch(
            event: "message_delta",
            data: """
            {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":50}}
            """
        )
        XCTAssertNotNil(result)
        if case .messageDelta(let delta, let usage) = result {
            XCTAssertEqual(delta["stop_reason"] as? String, "end_turn")
            XCTAssertEqual(usage["output_tokens"] as? Int, 50)
        } else {
            XCTFail("Expected messageDelta")
        }
    }

    func testDispatch_messageStop() {
        let result = SSEEventDispatcher.dispatch(
            event: "message_stop",
            data: """
            {"type":"message_stop"}
            """
        )
        XCTAssertNotNil(result)
        if case .messageStop = result {
            // pass
        } else {
            XCTFail("Expected messageStop")
        }
    }

    func testDispatch_ping() {
        let result = SSEEventDispatcher.dispatch(
            event: "ping",
            data: """
            {"type":"ping"}
            """
        )
        XCTAssertNotNil(result)
        if case .ping = result {
            // pass
        } else {
            XCTFail("Expected ping")
        }
    }

    func testDispatch_error() {
        let result = SSEEventDispatcher.dispatch(
            event: "error",
            data: """
            {"type":"error","error":{"type":"overloaded","message":"Too many requests"}}
            """
        )
        XCTAssertNotNil(result)
        if case .error(let data) = result {
            let err = data["error"] as? [String: Any]
            XCTAssertEqual(err?["type"] as? String, "overloaded")
        } else {
            XCTFail("Expected error")
        }
    }

    func testDispatch_unknownEvent_returnsNil() {
        let result = SSEEventDispatcher.dispatch(
            event: "unknown_event_type",
            data: """
            {"type":"unknown"}
            """
        )
        XCTAssertNil(result)
    }

    func testDispatch_malformedJSON_returnsNil() {
        let result = SSEEventDispatcher.dispatch(
            event: "message_start",
            data: "not valid json"
        )
        XCTAssertNil(result)
    }

    func testDispatch_missingRequiredField_returnsNil() {
        // message_start requires "message" key
        let result = SSEEventDispatcher.dispatch(
            event: "message_start",
            data: """
            {"type":"message_start","no_message_key":true}
            """
        )
        XCTAssertNil(result)
    }

    func testDispatch_contentBlockStart_missingIndex_returnsNil() {
        let result = SSEEventDispatcher.dispatch(
            event: "content_block_start",
            data: """
            {"type":"content_block_start","content_block":{"type":"text"}}
            """
        )
        XCTAssertNil(result, "Missing index should return nil")
    }

    func testDispatch_emptyData_returnsNil() {
        let result = SSEEventDispatcher.dispatch(
            event: "message_start",
            data: ""
        )
        XCTAssertNil(result)
    }
}
