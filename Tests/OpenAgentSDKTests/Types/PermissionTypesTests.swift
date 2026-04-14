import XCTest
@testable import OpenAgentSDK

final class PermissionTypesTests: XCTestCase {

    // MARK: - PermissionMode CaseIterable

    func testPermissionMode_allCases() {
        XCTAssertEqual(PermissionMode.allCases.count, 6)
        XCTAssertTrue(PermissionMode.allCases.contains(.default))
        XCTAssertTrue(PermissionMode.allCases.contains(.acceptEdits))
        XCTAssertTrue(PermissionMode.allCases.contains(.bypassPermissions))
        XCTAssertTrue(PermissionMode.allCases.contains(.plan))
        XCTAssertTrue(PermissionMode.allCases.contains(.dontAsk))
        XCTAssertTrue(PermissionMode.allCases.contains(.auto))
    }

    func testPermissionMode_rawValues() {
        XCTAssertEqual(PermissionMode.default.rawValue, "default")
        XCTAssertEqual(PermissionMode.acceptEdits.rawValue, "acceptEdits")
        XCTAssertEqual(PermissionMode.bypassPermissions.rawValue, "bypassPermissions")
        XCTAssertEqual(PermissionMode.plan.rawValue, "plan")
        XCTAssertEqual(PermissionMode.dontAsk.rawValue, "dontAsk")
        XCTAssertEqual(PermissionMode.auto.rawValue, "auto")
    }

    func testPermissionMode_initFromRawValue() {
        XCTAssertEqual(PermissionMode(rawValue: "default"), .default)
        XCTAssertEqual(PermissionMode(rawValue: "acceptEdits"), .acceptEdits)
        XCTAssertEqual(PermissionMode(rawValue: "bypassPermissions"), .bypassPermissions)
        XCTAssertEqual(PermissionMode(rawValue: "plan"), .plan)
        XCTAssertEqual(PermissionMode(rawValue: "dontAsk"), .dontAsk)
        XCTAssertEqual(PermissionMode(rawValue: "auto"), .auto)
        XCTAssertNil(PermissionMode(rawValue: "unknown"))
    }

    // MARK: - CanUseToolResult

    func testCanUseToolResult_basicCreation() {
        let result = CanUseToolResult(behavior: .allow)
        XCTAssertEqual(result.behavior, .allow)
        XCTAssertNil(result.updatedInput)
        XCTAssertNil(result.message)
    }

    func testCanUseToolResult_withMessage() {
        let result = CanUseToolResult(behavior: .deny, message: "Not allowed")
        XCTAssertEqual(result.behavior, .deny)
        XCTAssertEqual(result.message, "Not allowed")
    }

    func testCanUseToolResult_withUpdatedInput() {
        let result = CanUseToolResult(behavior: .allow, updatedInput: ["key": "value"])
        XCTAssertEqual(result.behavior, .allow)
        XCTAssertNotNil(result.updatedInput)
    }

    func testCanUseToolResult_equality_sameBehaviorAndMessage() {
        let a = CanUseToolResult(behavior: .allow, message: "ok")
        let b = CanUseToolResult(behavior: .allow, message: "ok")
        XCTAssertEqual(a, b)
    }

    func testCanUseToolResult_equality_ignoresUpdatedInput() {
        // Equality comparison excludes updatedInput per documentation
        let a = CanUseToolResult(behavior: .allow, updatedInput: ["a": 1])
        let b = CanUseToolResult(behavior: .allow, updatedInput: ["b": 2])
        XCTAssertEqual(a, b)
    }

    func testCanUseToolResult_inequality_differentBehavior() {
        let a = CanUseToolResult(behavior: .allow)
        let b = CanUseToolResult(behavior: .deny)
        XCTAssertNotEqual(a, b)
    }

    func testCanUseToolResult_inequality_differentMessage() {
        let a = CanUseToolResult(behavior: .allow, message: "yes")
        let b = CanUseToolResult(behavior: .allow, message: "no")
        XCTAssertNotEqual(a, b)
    }
}
