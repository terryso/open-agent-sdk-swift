import XCTest
@testable import OpenAgentSDK

// MARK: - AC3: SDKError Complete Error Domain

final class SDKErrorTests: XCTestCase {

    // MARK: - All 8 error cases compile with associated values

    func testAPIErrorCase() {
        let error = SDKError.apiError(statusCode: 401, message: "Unauthorized")
        XCTAssertEqual(error.statusCode, 401)
        XCTAssertEqual(error.message, "Unauthorized")
    }

    func testToolExecutionErrorCase() {
        let error = SDKError.toolExecutionError(toolName: "Bash", message: "Command failed")
        XCTAssertEqual(error.toolName, "Bash")
        XCTAssertEqual(error.message, "Command failed")
    }
    func testBudgetExceededCase() {
        let error = SDKError.budgetExceeded(cost: 1.50, turnsUsed: 8)
        XCTAssertEqual(error.cost, 1.50)
        XCTAssertEqual(error.turnsUsed, 8)
    }

    func testMaxTurnsExceededCase() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 10)
        XCTAssertEqual(error.turnsUsed, 10)
    }

    func testSessionErrorCase() {
        let error = SDKError.sessionError(message: "Session expired")
        XCTAssertEqual(error.message, "Session expired")
    }

    func testMCPConnectionErrorCase() {
        let error = SDKError.mcpConnectionError(serverName: "my-server", message: "Connection refused")
        XCTAssertEqual(error.serverName, "my-server")
        XCTAssertEqual(error.message, "Connection refused")
    }

    func testPermissionDeniedCase() {
        let error = SDKError.permissionDenied(tool: "Write", reason: "User rejected")
        XCTAssertEqual(error.tool, "Write")
        XCTAssertEqual(error.reason, "User rejected")
    }

    func testAbortErrorCase() {
        _ = SDKError.abortError
        // Verify the case exists — no associated values
    }

    // MARK: - LocalizedError conformance

    func testLocalizedErrorAPIError() {
        let error = SDKError.apiError(statusCode: 404, message: "Not found")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(error.errorDescription?.contains("404") ?? false)
    }

    func testLocalizedErrorToolExecution() {
        let error = SDKError.toolExecutionError(toolName: "Read", message: "File not found")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testLocalizedErrorBudgetExceeded() {
        let error = SDKError.budgetExceeded(cost: 5.0, turnsUsed: 12)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testLocalizedErrorMaxTurns() {
        let error = SDKError.maxTurnsExceeded(turnsUsed: 10)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testLocalizedErrorSession() {
        let error = SDKError.sessionError(message: "Corrupted")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testLocalizedErrorMCP() {
        let error = SDKError.mcpConnectionError(serverName: "srv", message: "Timeout")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testLocalizedErrorPermission() {
        let error = SDKError.permissionDenied(tool: "Bash", reason: "Blocked")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testLocalizedErrorAbort() {
        let error = SDKError.abortError
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    // MARK: - Equatable conformance

    func testEqualitySameCase() {
        let a = SDKError.apiError(statusCode: 500, message: "Server error")
        let b = SDKError.apiError(statusCode: 500, message: "Server error")
        XCTAssertEqual(a, b)
    }

    func testInequalityDifferentCase() {
        let a = SDKError.apiError(statusCode: 500, message: "Error")
        let b = SDKError.abortError
        XCTAssertNotEqual(a, b)
    }

    func testInequalityDifferentAssociatedValues() {
        let a = SDKError.apiError(statusCode: 500, message: "Error A")
        let b = SDKError.apiError(statusCode: 503, message: "Error B")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Conforms to Error

    func testConformsToError() {
        let error: Error = SDKError.abortError
        XCTAssertNotNil(error)
    }
}
