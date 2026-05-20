import XCTest
@testable import OpenAgentSDK

final class TraceEventMappingTests: XCTestCase {

    // MARK: - toolUse mapping

    func testToolUseMapping() {
        let msg = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tu_123",
            input: "{\"command\": \"ls\"}"
        ))
        let result = TraceEventMapping.traceEvent(from: msg, stepIndex: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.event, "step_start")
        XCTAssertEqual(result!.payload["tool"] as? String, "Bash")
        XCTAssertEqual(result!.payload["toolUseId"] as? String, "tu_123")
        XCTAssertEqual(result!.payload["index"] as? Int, 0)
    }

    func testToolUseMappingWithoutStepIndex() {
        let msg = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "FileRead",
            toolUseId: "tu_456",
            input: "{}"
        ))
        let result = TraceEventMapping.traceEvent(from: msg)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.event, "step_start")
        XCTAssertNil(result!.payload["index"])
    }

    // MARK: - toolResult mapping

    func testToolResultMapping() {
        let msg = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tu_123",
            content: "file contents",
            isError: false
        ))
        let result = TraceEventMapping.traceEvent(from: msg, stepIndex: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.event, "step_done")
        XCTAssertEqual(result!.payload["success"] as? Bool, true)
        XCTAssertEqual(result!.payload["toolUseId"] as? String, "tu_123")
    }

    func testToolResultErrorMapping() {
        let msg = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tu_789",
            content: "error: file not found",
            isError: true
        ))
        let result = TraceEventMapping.traceEvent(from: msg)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.event, "step_done")
        XCTAssertEqual(result!.payload["success"] as? Bool, false)
    }

    // MARK: - result mapping

    func testResultMapping() {
        let msg = SDKMessage.result(SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 5,
            durationMs: 3000,
            totalCostUsd: 0.05,
            costBreakdown: []
        ))
        let result = TraceEventMapping.traceEvent(from: msg)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.event, "run_done")
        XCTAssertEqual(result!.payload["status"] as? String, "success")
        XCTAssertEqual(result!.payload["totalSteps"] as? Int, 5)
        XCTAssertEqual(result!.payload["durationMs"] as? Int, 3000)
        XCTAssertEqual(result!.payload["totalCostUsd"] as? Double, 0.05)
    }

    // MARK: - Ignored cases

    func testPartialMessageIgnored() {
        let msg = SDKMessage.partialMessage(SDKMessage.PartialData(text: "hello"))
        XCTAssertNil(TraceEventMapping.traceEvent(from: msg))
    }

    func testSystemIgnored() {
        let msg = SDKMessage.system(SDKMessage.SystemData(subtype: .status, message: "compacting"))
        XCTAssertNil(TraceEventMapping.traceEvent(from: msg))
    }

    func testAssistantIgnored() {
        let msg = SDKMessage.assistant(SDKMessage.AssistantData(
            text: "response", model: "claude-sonnet-4-6", stopReason: "end_turn"
        ))
        XCTAssertNil(TraceEventMapping.traceEvent(from: msg))
    }

    func testHookProgressIgnored() {
        let msg = SDKMessage.hookProgress(SDKMessage.HookProgressData(
            hookId: "h1", hookName: "PreToolUse", hookEvent: "PreToolUse", stdout: "output"
        ))
        XCTAssertNil(TraceEventMapping.traceEvent(from: msg))
    }

    func testToolProgressIgnored() {
        let msg = SDKMessage.toolProgress(SDKMessage.ToolProgressData(
            toolUseId: "tu_1", toolName: "Bash"
        ))
        XCTAssertNil(TraceEventMapping.traceEvent(from: msg))
    }
}
