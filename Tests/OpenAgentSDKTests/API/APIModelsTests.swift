import XCTest
@testable import OpenAgentSDK

final class APIModelsTests: XCTestCase {

    // MARK: - buildRequestBody

    func testBuildRequestBody_requiredFieldsOnly() {
        let body = buildRequestBody(
            model: "claude-sonnet-4-6",
            messages: [["role": "user", "content": "hello"]],
            maxTokens: 1024,
            stream: false
        )
        XCTAssertEqual(body["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(body["max_tokens"] as? Int, 1024)
        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertNotNil(body["messages"])
        XCTAssertNil(body["system"])
        XCTAssertNil(body["tools"])
        XCTAssertNil(body["tool_choice"])
        XCTAssertNil(body["thinking"])
        XCTAssertNil(body["temperature"])
    }

    func testBuildRequestBody_withSystem() {
        let body = buildRequestBody(
            model: "m",
            messages: [],
            maxTokens: 100,
            stream: true,
            system: "You are helpful."
        )
        XCTAssertEqual(body["system"] as? String, "You are helpful.")
    }

    func testBuildRequestBody_withTools() {
        let tools: [[String: Any]] = [["name": "bash", "description": "Run cmd"]]
        let body = buildRequestBody(
            model: "m",
            messages: [],
            maxTokens: 100,
            stream: false,
            tools: tools
        )
        XCTAssertNotNil(body["tools"])
    }

    func testBuildRequestBody_withToolChoice() {
        let body = buildRequestBody(
            model: "m",
            messages: [],
            maxTokens: 100,
            stream: false,
            toolChoice: ["type": "auto"]
        )
        XCTAssertNotNil(body["tool_choice"])
    }

    func testBuildRequestBody_withThinking() {
        let body = buildRequestBody(
            model: "m",
            messages: [],
            maxTokens: 100,
            stream: false,
            thinking: ["type": "enabled", "budget_tokens": 10000]
        )
        XCTAssertNotNil(body["thinking"])
    }

    func testBuildRequestBody_withTemperature() {
        let body = buildRequestBody(
            model: "m",
            messages: [],
            maxTokens: 100,
            stream: false,
            temperature: 0.7
        )
        XCTAssertEqual(body["temperature"] as? Double, 0.7)
    }

    func testBuildRequestBody_allFields() {
        let body = buildRequestBody(
            model: "claude-opus-4-6",
            messages: [["role": "user", "content": "test"]],
            maxTokens: 4096,
            stream: true,
            system: "system prompt",
            tools: [["name": "tool1"]],
            toolChoice: ["type": "auto"],
            thinking: ["type": "enabled", "budget_tokens": 5000],
            temperature: 0.5
        )
        XCTAssertEqual(body.count, 9)
    }

    // MARK: - parseResponse

    func testParseResponse_validJSON() throws {
        let json = """
        {"id": "msg_1", "type": "message", "content": "hello"}
        """.data(using: .utf8)!
        let result = try parseResponse(data: json)
        XCTAssertEqual(result["id"] as? String, "msg_1")
        XCTAssertEqual(result["type"] as? String, "message")
    }

    func testParseResponse_nestedJSON() throws {
        let json = """
        {"usage": {"input_tokens": 100, "output_tokens": 50}}
        """.data(using: .utf8)!
        let result = try parseResponse(data: json)
        let usage = result["usage"] as? [String: Any]
        XCTAssertEqual(usage?["input_tokens"] as? Int, 100)
    }

    func testParseResponse_invalidJSONThrows() {
        let invalidData = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try parseResponse(data: invalidData))
    }

    func testParseResponse_nonDictJSONThrows() {
        let arrayData = "[1,2,3]".data(using: .utf8)!
        XCTAssertThrowsError(try parseResponse(data: arrayData))
    }

    // MARK: - SSEEvent

    func testSSEEvent_messageStart() {
        let event = SSEEvent.messageStart(message: ["id": "msg_1"])
        if case .messageStart(let msg) = event {
            XCTAssertEqual(msg["id"] as? String, "msg_1")
        } else {
            XCTFail("Expected .messageStart")
        }
    }

    func testSSEEvent_contentBlockStart() {
        let event = SSEEvent.contentBlockStart(index: 0, contentBlock: ["type": "text"])
        if case .contentBlockStart(let idx, let block) = event {
            XCTAssertEqual(idx, 0)
            XCTAssertEqual(block["type"] as? String, "text")
        } else {
            XCTFail("Expected .contentBlockStart")
        }
    }

    func testSSEEvent_contentBlockDelta() {
        let event = SSEEvent.contentBlockDelta(index: 1, delta: ["type": "text_delta", "text": "hi"])
        if case .contentBlockDelta(let idx, _) = event {
            XCTAssertEqual(idx, 1)
        } else {
            XCTFail("Expected .contentBlockDelta")
        }
    }

    func testSSEEvent_contentBlockStop() {
        let event = SSEEvent.contentBlockStop(index: 2)
        if case .contentBlockStop(let idx) = event {
            XCTAssertEqual(idx, 2)
        } else {
            XCTFail("Expected .contentBlockStop")
        }
    }

    func testSSEEvent_messageDelta() {
        let event = SSEEvent.messageDelta(delta: ["stop_reason": "end_turn"], usage: ["output_tokens": 10])
        if case .messageDelta(let delta, let usage) = event {
            XCTAssertEqual(delta["stop_reason"] as? String, "end_turn")
            XCTAssertEqual(usage["output_tokens"] as? Int, 10)
        } else {
            XCTFail("Expected .messageDelta")
        }
    }

    func testSSEEvent_messageStop() {
        let event = SSEEvent.messageStop
        if case .messageStop = event {
            // success
        } else {
            XCTFail("Expected .messageStop")
        }
    }

    func testSSEEvent_ping() {
        let event = SSEEvent.ping
        if case .ping = event {
            // success
        } else {
            XCTFail("Expected .ping")
        }
    }

    func testSSEEvent_error() {
        let event = SSEEvent.error(data: ["message": "rate limited"])
        if case .error(let data) = event {
            XCTAssertEqual(data["message"] as? String, "rate limited")
        } else {
            XCTFail("Expected .error")
        }
    }
}
