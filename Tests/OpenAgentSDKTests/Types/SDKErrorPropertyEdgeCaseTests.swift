import XCTest
@testable import OpenAgentSDK

/// Tests SDKError computed properties return nil for wrong error cases,
/// and validates errorDescription format for all cases.
final class SDKErrorPropertyEdgeCaseTests: XCTestCase {

    // MARK: - statusCode returns nil for non-apiError

    func testStatusCode_nilOnToolExecutionError() {
        let error = SDKError.toolExecutionError(toolName: "Bash", message: "fail")
        XCTAssertNil(error.statusCode)
    }

    func testStatusCode_nilOnBudgetExceeded() {
        let error = SDKError.budgetExceeded(cost: 1.0, turnsUsed: 5)
        XCTAssertNil(error.statusCode)
    }

    func testStatusCode_nilOnMaxTurnsExceeded() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 10)
        XCTAssertNil(error.statusCode)
    }

    func testStatusCode_nilOnSessionError() {
        let error = SDKError.sessionError(message: "expired")
        XCTAssertNil(error.statusCode)
    }

    func testStatusCode_nilOnMCPConnectionError() {
        let error = SDKError.mcpConnectionError(serverName: "srv", message: "fail")
        XCTAssertNil(error.statusCode)
    }

    func testStatusCode_nilOnPermissionDenied() {
        let error = SDKError.permissionDenied(tool: "Write", reason: "blocked")
        XCTAssertNil(error.statusCode)
    }

    func testStatusCode_nilOnAbortError() {
        let error = SDKError.abortError
        XCTAssertNil(error.statusCode)
    }

    // MARK: - toolName returns nil for non-toolExecutionError

    func testToolName_nilOnAPIError() {
        let error = SDKError.apiError(statusCode: 500, message: "fail")
        XCTAssertNil(error.toolName)
    }

    func testToolName_nilOnAbortError() {
        let error = SDKError.abortError
        XCTAssertNil(error.toolName)
    }

    // MARK: - cost returns nil for non-budgetExceeded

    func testCost_nilOnAPIError() {
        let error = SDKError.apiError(statusCode: 500, message: "fail")
        XCTAssertNil(error.cost)
    }

    func testCost_nilOnMaxTurnsExceeded() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 10)
        XCTAssertNil(error.cost)
    }

    // MARK: - turnsUsed returns nil for wrong cases

    func testTurnsUsed_nilOnAPIError() {
        let error = SDKError.apiError(statusCode: 500, message: "fail")
        XCTAssertNil(error.turnsUsed)
    }

    func testTurnsUsed_nilOnSessionError() {
        let error = SDKError.sessionError(message: "fail")
        XCTAssertNil(error.turnsUsed)
    }

    func testTurnsUsed_onBudgetExceeded() {
        let error = SDKError.budgetExceeded(cost: 2.5, turnsUsed: 7)
        XCTAssertEqual(error.turnsUsed, 7)
    }

    func testTurnsUsed_onMaxTurnsExceeded() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 15)
        XCTAssertEqual(error.turnsUsed, 15)
    }

    // MARK: - serverName returns nil for non-mcpConnectionError

    func testServerName_nilOnAPIError() {
        let error = SDKError.apiError(statusCode: 500, message: "fail")
        XCTAssertNil(error.serverName)
    }

    // MARK: - tool returns nil for non-permissionDenied

    func testTool_nilOnAPIError() {
        let error = SDKError.apiError(statusCode: 500, message: "fail")
        XCTAssertNil(error.tool)
    }

    // MARK: - reason returns nil for non-permissionDenied

    func testReason_nilOnAPIError() {
        let error = SDKError.apiError(statusCode: 500, message: "fail")
        XCTAssertNil(error.reason)
    }

    // MARK: - message property for all cases

    func testMessage_budgetExceeded() {
        let error = SDKError.budgetExceeded(cost: 1.0, turnsUsed: 5)
        XCTAssertEqual(error.message, "Budget exceeded")
    }

    func testMessage_maxTurnsExceeded() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 10)
        XCTAssertEqual(error.message, "Max turns exceeded")
    }

    func testMessage_abortError() {
        let error = SDKError.abortError
        XCTAssertEqual(error.message, "Aborted")
    }

    func testMessage_permissionDenied() {
        let error = SDKError.permissionDenied(tool: "Bash", reason: "User said no")
        XCTAssertEqual(error.message, "User said no")
    }

    // MARK: - errorDescription format

    func testErrorDescription_apiError_format() {
        let error = SDKError.apiError(statusCode: 429, message: "Rate limited")
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("429") ?? false)
        XCTAssertTrue(desc?.contains("Rate limited") ?? false)
    }

    func testErrorDescription_toolExecution_format() {
        let error = SDKError.toolExecutionError(toolName: "Read", message: "Not found")
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("Read") ?? false)
        XCTAssertTrue(desc?.contains("Not found") ?? false)
    }

    func testErrorDescription_budgetExceeded_format() {
        let error = SDKError.budgetExceeded(cost: 3.14159, turnsUsed: 12)
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("3.1416") ?? false)
        XCTAssertTrue(desc?.contains("12") ?? false)
    }

    func testErrorDescription_maxTurns_format() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 20)
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("20") ?? false)
    }

    func testErrorDescription_session_format() {
        let error = SDKError.sessionError(message: "Corrupted data")
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("Corrupted data") ?? false)
    }

    func testErrorDescription_mcpConnection_format() {
        let error = SDKError.mcpConnectionError(serverName: "weather-api", message: "Timeout")
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("weather-api") ?? false)
        XCTAssertTrue(desc?.contains("Timeout") ?? false)
    }

    func testErrorDescription_permissionDenied_format() {
        let error = SDKError.permissionDenied(tool: "Write", reason: "Read-only mode")
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("Write") ?? false)
        XCTAssertTrue(desc?.contains("Read-only mode") ?? false)
    }

    func testErrorDescription_abort_format() {
        let error = SDKError.abortError
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertEqual(desc, "Operation aborted")
    }
}
