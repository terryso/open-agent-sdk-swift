import XCTest
@testable import OpenAgentSDK

/// Deep tests for SDKMessage covering toolUse variant, text property for all variants,
/// Equatable conformance, and edge cases.
final class SDKMessageDeepTests: XCTestCase {

    // MARK: - toolUse Variant (missing from existing tests)

    func testToolUseVariant() {
        let data = SDKMessage.ToolUseData(
            toolName: "get_weather",
            toolUseId: "toolu_123",
            input: "{\"city\":\"SF\"}"
        )
        let message = SDKMessage.toolUse(data)

        XCTAssertEqual(message.text, "get_weather")
        XCTAssertNil(message.model)
        XCTAssertNil(message.stopReason)
        XCTAssertNil(message.toolUseId)
        XCTAssertNil(message.content)
        XCTAssertNil(message.isError)
        XCTAssertNil(message.numTurns)
        XCTAssertNil(message.durationMs)
        XCTAssertNil(message.message)
    }

    func testToolUseData_equality() {
        let a = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id", input: "{}")
        let b = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id", input: "{}")
        XCTAssertEqual(a, b)
    }

    func testToolUseData_inequality_differentToolName() {
        let a = SDKMessage.ToolUseData(toolName: "toolA", toolUseId: "id", input: "{}")
        let b = SDKMessage.ToolUseData(toolName: "toolB", toolUseId: "id", input: "{}")
        XCTAssertNotEqual(a, b)
    }

    func testToolUseData_inequality_differentToolUseId() {
        let a = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id1", input: "{}")
        let b = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id2", input: "{}")
        XCTAssertNotEqual(a, b)
    }

    func testToolUseData_inequality_differentInput() {
        let a = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id", input: "{\"a\":1}")
        let b = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id", input: "{\"b\":2}")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - text Property for All Variants

    func testText_assistant() {
        let msg = SDKMessage.assistant(SDKMessage.AssistantData(text: "Hello", model: "m", stopReason: "s"))
        XCTAssertEqual(msg.text, "Hello")
    }

    func testText_toolUse() {
        let msg = SDKMessage.toolUse(SDKMessage.ToolUseData(toolName: "Bash", toolUseId: "id", input: "{}"))
        XCTAssertEqual(msg.text, "Bash")
    }

    func testText_toolResult() {
        let msg = SDKMessage.toolResult(SDKMessage.ToolResultData(toolUseId: "id", content: "output", isError: false))
        XCTAssertEqual(msg.text, "output")
    }

    func testText_result() {
        let msg = SDKMessage.result(SDKMessage.ResultData(subtype: .success, text: "Done", usage: nil, numTurns: 1, durationMs: 100))
        XCTAssertEqual(msg.text, "Done")
    }

    func testText_partialMessage() {
        let msg = SDKMessage.partialMessage(SDKMessage.PartialData(text: "partial"))
        XCTAssertEqual(msg.text, "partial")
    }

    func testText_system() {
        let msg = SDKMessage.system(SDKMessage.SystemData(subtype: .`init`, message: "started"))
        XCTAssertEqual(msg.text, "started")
    }

    // MARK: - Computed Property Access on Wrong Variant

    func testModel_nilOnNonAssistant() {
        let msg = SDKMessage.toolResult(SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false))
        XCTAssertNil(msg.model)
        XCTAssertNil(msg.stopReason)
    }

    func testContent_nilOnNonToolResult() {
        let msg = SDKMessage.assistant(SDKMessage.AssistantData(text: "hi", model: "m", stopReason: "s"))
        XCTAssertNil(msg.content)
        XCTAssertNil(msg.isError)
        XCTAssertNil(msg.toolUseId)
    }

    func testNumTurns_nilOnNonResult() {
        let msg = SDKMessage.partialMessage(SDKMessage.PartialData(text: "p"))
        XCTAssertNil(msg.numTurns)
        XCTAssertNil(msg.durationMs)
    }

    func testMessage_nilOnNonSystem() {
        let msg = SDKMessage.result(SDKMessage.ResultData(subtype: .success, text: "t", usage: nil, numTurns: 1, durationMs: 100))
        XCTAssertNil(msg.message)
    }

    // MARK: - AssistantData Equatable

    func testAssistantData_equality() {
        let a = SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn")
        let b = SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn")
        XCTAssertEqual(a, b)
    }

    func testAssistantData_inequality_differentText() {
        let a = SDKMessage.AssistantData(text: "Hello", model: "m", stopReason: "s")
        let b = SDKMessage.AssistantData(text: "World", model: "m", stopReason: "s")
        XCTAssertNotEqual(a, b)
    }

    func testAssistantData_inequality_differentModel() {
        let a = SDKMessage.AssistantData(text: "Hello", model: "m1", stopReason: "s")
        let b = SDKMessage.AssistantData(text: "Hello", model: "m2", stopReason: "s")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ToolResultData Equatable

    func testToolResultData_equality() {
        let a = SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false)
        let b = SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false)
        XCTAssertEqual(a, b)
    }

    func testToolResultData_inequality_differentIsError() {
        let a = SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false)
        let b = SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ResultData Subtype & Equatable

    func testResultData_equality() {
        let a = SDKMessage.ResultData(subtype: .success, text: "t", usage: nil, numTurns: 1, durationMs: 100, totalCostUsd: 0.01)
        let b = SDKMessage.ResultData(subtype: .success, text: "t", usage: nil, numTurns: 1, durationMs: 100, totalCostUsd: 0.01)
        XCTAssertEqual(a, b)
    }

    func testResultData_inequality_differentSubtype() {
        let a = SDKMessage.ResultData(subtype: .success, text: "t", usage: nil, numTurns: 1, durationMs: 100)
        let b = SDKMessage.ResultData(subtype: .errorMaxTurns, text: "t", usage: nil, numTurns: 1, durationMs: 100)
        XCTAssertNotEqual(a, b)
    }

    func testResultData_allSubtypes() {
        let subtypes: [SDKMessage.ResultData.Subtype] = [
            .success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd
        ]
        XCTAssertEqual(subtypes.count, 4)

        // Verify all distinct
        for i in 0..<subtypes.count {
            for j in 0..<subtypes.count {
                if i != j {
                    XCTAssertNotEqual(subtypes[i], subtypes[j])
                }
            }
        }
    }

    func testResultData_withUsage() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let data = SDKMessage.ResultData(subtype: .success, text: "t", usage: usage, numTurns: 2, durationMs: 500)
        XCTAssertEqual(data.usage?.inputTokens, 100)
        XCTAssertEqual(data.usage?.outputTokens, 50)
    }

    // MARK: - PartialData Equatable

    func testPartialData_equality() {
        let a = SDKMessage.PartialData(text: "Hello")
        let b = SDKMessage.PartialData(text: "Hello")
        XCTAssertEqual(a, b)
    }

    func testPartialData_inequality() {
        let a = SDKMessage.PartialData(text: "Hello")
        let b = SDKMessage.PartialData(text: "World")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - SystemData Subtypes & Equatable

    func testSystemData_equality() {
        let a = SDKMessage.SystemData(subtype: .`init`, message: "started")
        let b = SDKMessage.SystemData(subtype: .`init`, message: "started")
        XCTAssertEqual(a, b)
    }

    func testSystemData_inequality_differentMessage() {
        let a = SDKMessage.SystemData(subtype: .status, message: "running")
        let b = SDKMessage.SystemData(subtype: .status, message: "stopped")
        XCTAssertNotEqual(a, b)
    }

    func testSystemData_allSubtypes() {
        let subtypes: [SDKMessage.SystemData.Subtype] = [
            .`init`, .compactBoundary, .status, .taskNotification, .rateLimit
        ]
        XCTAssertEqual(subtypes.count, 5)
    }

    func testSystemData_subtypes_rawValues() {
        XCTAssertEqual(SDKMessage.SystemData.Subtype.`init`.rawValue, "init")
        XCTAssertEqual(SDKMessage.SystemData.Subtype.compactBoundary.rawValue, "compactBoundary")
        XCTAssertEqual(SDKMessage.SystemData.Subtype.status.rawValue, "status")
        XCTAssertEqual(SDKMessage.SystemData.Subtype.taskNotification.rawValue, "taskNotification")
        XCTAssertEqual(SDKMessage.SystemData.Subtype.rateLimit.rawValue, "rateLimit")
    }

    // MARK: - Empty String Edge Cases

    func testAssistantData_emptyStrings() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        XCTAssertEqual(data.text, "")
        XCTAssertEqual(data.model, "")
        XCTAssertEqual(data.stopReason, "")
    }

    func testPartialData_emptyText() {
        let data = SDKMessage.PartialData(text: "")
        XCTAssertEqual(data.text, "")
    }

    func testToolUseData_emptyInput() {
        let data = SDKMessage.ToolUseData(toolName: "tool", toolUseId: "id", input: "")
        XCTAssertEqual(data.input, "")
    }
}
