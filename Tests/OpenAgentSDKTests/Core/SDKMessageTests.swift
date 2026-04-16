import XCTest
@testable import OpenAgentSDK

// MARK: - AC4: SDKMessage Event Types Complete

final class SDKMessageTests: XCTestCase {

    // MARK: - All 5 variants compile with typed associated data

    func testAssistantVariant() {
        let data = SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn")
        let message = SDKMessage.assistant(data)
        XCTAssertEqual(message.text, "Hello")
        XCTAssertEqual(message.model, "claude-sonnet-4-6")
        XCTAssertEqual(message.stopReason, "end_turn")
    }

    func testToolResultVariant() {
        let data = SDKMessage.ToolResultData(toolUseId: "tu_123", content: "result text", isError: false)
        let message = SDKMessage.toolResult(data)
        XCTAssertEqual(message.toolUseId, "tu_123")
        XCTAssertEqual(message.content, "result text")
        XCTAssertEqual(message.isError, false)
    }

    func testResultVariant() {
        let data = SDKMessage.ResultData(subtype: .success, text: "Done", usage: nil, numTurns: 3, durationMs: 1500)
        let message = SDKMessage.result(data)
        if case .result(let d) = message {
            XCTAssertEqual(d.subtype, .success)
        } else {
            XCTFail("Expected .result case")
        }
        XCTAssertEqual(message.text, "Done")
        XCTAssertEqual(message.numTurns, 3)
        XCTAssertEqual(message.durationMs, 1500)
    }

    func testPartialMessageVariant() {
        let data = SDKMessage.PartialData(text: "Hello wo")
        let message = SDKMessage.partialMessage(data)
        XCTAssertEqual(message.text, "Hello wo")
    }

    func testSystemVariant() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "Session started")
        let message = SDKMessage.system(data)
        if case .system(let d) = message {
            XCTAssertEqual(d.subtype, .`init`)
        } else {
            XCTFail("Expected .system case")
        }
        XCTAssertEqual(message.message, "Session started")
    }

    // MARK: - case let pattern matching

    func testPatternMatchingAssistant() {
        let message = SDKMessage.assistant(SDKMessage.AssistantData(text: "Hi", model: "m", stopReason: "end_turn"))
        if case let .assistant(data) = message {
            XCTAssertEqual(data.text, "Hi")
        } else {
            XCTFail("Expected .assistant case")
        }
    }

    func testPatternMatchingToolResult() {
        let message = SDKMessage.toolResult(SDKMessage.ToolResultData(toolUseId: "x", content: "y", isError: true))
        if case let .toolResult(data) = message {
            XCTAssertTrue(data.isError)
        } else {
            XCTFail("Expected .toolResult case")
        }
    }

    func testPatternMatchingResult() {
        let message = SDKMessage.result(SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 0, durationMs: 0))
        if case let .result(data) = message {
            XCTAssertEqual(data.subtype, .success)
            XCTAssertEqual(message.numTurns, 0)
            XCTAssertEqual(message.durationMs, 0)
        } else {
            XCTFail("Expected .result case")
        }
    }

    func testPatternMatchingPartialMessage() {
        let message = SDKMessage.partialMessage(SDKMessage.PartialData(text: "partial"))
        if case let .partialMessage(data) = message {
            XCTAssertEqual(data.text, "partial")
        } else {
            XCTFail("Expected .partialMessage case")
        }
    }

    func testPatternMatchingSystem() {
        let message = SDKMessage.system(SDKMessage.SystemData(subtype: .compactBoundary, message: "m"))
        if case let .system(data) = message {
            XCTAssertEqual(data.subtype, .compactBoundary)
        } else {
            XCTFail("Expected .system case")
        }
    }

    // MARK: - ResultData subtypes

    func testResultDataSubtypeSuccess() {
        let subtype = SDKMessage.ResultData.Subtype.success
        XCTAssertEqual(subtype, .success)
    }

    func testResultDataSubtypeErrorMaxTurns() {
        let subtype = SDKMessage.ResultData.Subtype.errorMaxTurns
        XCTAssertEqual(subtype, .errorMaxTurns)
    }

    func testResultDataSubtypeErrorDuringExecution() {
        let subtype = SDKMessage.ResultData.Subtype.errorDuringExecution
        XCTAssertEqual(subtype, .errorDuringExecution)
    }

    func testResultDataSubtypeErrorMaxBudgetUsd() {
        let subtype = SDKMessage.ResultData.Subtype.errorMaxBudgetUsd
        XCTAssertEqual(subtype, .errorMaxBudgetUsd)
    }

    // MARK: - SystemData subtypes

    func testSystemDataSubtypeInit() {
        let subtype: SDKMessage.SystemData.Subtype = .`init`
        XCTAssertEqual(subtype, .`init`)
    }

    func testSystemDataSubtypeCompactBoundary() {
        let subtype = SDKMessage.SystemData.Subtype.compactBoundary
        XCTAssertEqual(subtype, .compactBoundary)
    }

    func testSystemDataSubtypeStatus() {
        let subtype = SDKMessage.SystemData.Subtype.status
        XCTAssertEqual(subtype, .status)
    }

    func testSystemDataSubtypeTaskNotification() {
        let subtype = SDKMessage.SystemData.Subtype.taskNotification
        XCTAssertEqual(subtype, .taskNotification)
    }

    func testSystemDataSubtypeRateLimit() {
        let subtype = SDKMessage.SystemData.Subtype.rateLimit
        XCTAssertEqual(subtype, .rateLimit)
    }

    // MARK: - Exhaustive switch

    func testExhaustiveSwitch() {
        let messages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(text: "a", model: "m", stopReason: "s")),
            .toolResult(SDKMessage.ToolResultData(toolUseId: "t", content: "c", isError: false)),
            .result(SDKMessage.ResultData(subtype: .success, text: "r", usage: nil, numTurns: 1, durationMs: 100)),
            .partialMessage(SDKMessage.PartialData(text: "p")),
            .system(SDKMessage.SystemData(subtype: .`init`, message: "sys")),
        ]

        for message in messages {
            switch message {
            case .assistant:
                break
            case .toolUse:
                break
            case .toolResult:
                break
            case .result:
                break
            case .partialMessage:
                break
            case .system:
                break
            case .userMessage:
                break
            case .toolProgress:
                break
            case .hookStarted:
                break
            case .hookProgress:
                break
            case .hookResponse:
                break
            case .taskStarted:
                break
            case .taskProgress:
                break
            case .authStatus:
                break
            case .filesPersisted:
                break
            case .localCommandOutput:
                break
            case .promptSuggestion:
                break
            case .toolUseSummary:
                break
            }
        }
    }
}
