import XCTest
@testable import OpenAgentSDK

final class HookTypesTests: XCTestCase {

    // MARK: - HookEvent

    func testHookEvent_allCases() {
        XCTAssertEqual(HookEvent.allCases.count, 20, "HookEvent should have 20 cases")
    }

    func testHookEvent_rawValues() {
        XCTAssertEqual(HookEvent.preToolUse.rawValue, "preToolUse")
        XCTAssertEqual(HookEvent.postToolUse.rawValue, "postToolUse")
        XCTAssertEqual(HookEvent.postToolUseFailure.rawValue, "postToolUseFailure")
        XCTAssertEqual(HookEvent.sessionStart.rawValue, "sessionStart")
        XCTAssertEqual(HookEvent.sessionEnd.rawValue, "sessionEnd")
        XCTAssertEqual(HookEvent.stop.rawValue, "stop")
        XCTAssertEqual(HookEvent.subagentStart.rawValue, "subagentStart")
        XCTAssertEqual(HookEvent.subagentStop.rawValue, "subagentStop")
        XCTAssertEqual(HookEvent.userPromptSubmit.rawValue, "userPromptSubmit")
        XCTAssertEqual(HookEvent.permissionRequest.rawValue, "permissionRequest")
        XCTAssertEqual(HookEvent.permissionDenied.rawValue, "permissionDenied")
        XCTAssertEqual(HookEvent.taskCreated.rawValue, "taskCreated")
        XCTAssertEqual(HookEvent.taskCompleted.rawValue, "taskCompleted")
        XCTAssertEqual(HookEvent.configChange.rawValue, "configChange")
        XCTAssertEqual(HookEvent.cwdChanged.rawValue, "cwdChanged")
        XCTAssertEqual(HookEvent.fileChanged.rawValue, "fileChanged")
        XCTAssertEqual(HookEvent.notification.rawValue, "notification")
        XCTAssertEqual(HookEvent.preCompact.rawValue, "preCompact")
        XCTAssertEqual(HookEvent.postCompact.rawValue, "postCompact")
        XCTAssertEqual(HookEvent.teammateIdle.rawValue, "teammateIdle")
    }

    func testHookEvent_equality() {
        XCTAssertEqual(HookEvent.preToolUse, HookEvent.preToolUse)
        XCTAssertNotEqual(HookEvent.preToolUse, HookEvent.postToolUse)
    }

    // MARK: - HookInput

    func testHookInput_requiredFieldsOnly() {
        let input = HookInput(event: .preToolUse)
        XCTAssertEqual(input.event, .preToolUse)
        XCTAssertNil(input.toolName)
        XCTAssertNil(input.toolInput)
        XCTAssertNil(input.toolOutput)
        XCTAssertNil(input.toolUseId)
        XCTAssertNil(input.sessionId)
        XCTAssertNil(input.cwd)
        XCTAssertNil(input.error)
    }

    func testHookInput_allFields() {
        let input = HookInput(
            event: .postToolUse,
            toolName: "bash",
            toolInput: ["command": "ls"],
            toolOutput: "file.txt",
            toolUseId: "tu_123",
            sessionId: "sess_abc",
            cwd: "/home/user",
            error: nil
        )
        XCTAssertEqual(input.event, .postToolUse)
        XCTAssertEqual(input.toolName, "bash")
        XCTAssertEqual(input.toolUseId, "tu_123")
        XCTAssertEqual(input.sessionId, "sess_abc")
        XCTAssertEqual(input.cwd, "/home/user")
        XCTAssertNil(input.error)
    }

    // MARK: - HookOutput

    func testHookOutput_defaults() {
        let output = HookOutput()
        XCTAssertNil(output.message)
        XCTAssertNil(output.permissionUpdate)
        XCTAssertFalse(output.block)
        XCTAssertNil(output.notification)
    }

    func testHookOutput_withMessage() {
        let output = HookOutput(message: "Blocked")
        XCTAssertEqual(output.message, "Blocked")
    }

    func testHookOutput_withBlock() {
        let output = HookOutput(block: true)
        XCTAssertTrue(output.block)
    }

    func testHookOutput_withPermissionUpdate() {
        let update = PermissionUpdate(tool: "bash", behavior: "deny")
        let output = HookOutput(permissionUpdate: update)
        XCTAssertEqual(output.permissionUpdate?.tool, "bash")
        XCTAssertEqual(output.permissionUpdate?.behavior, "deny")
    }

    func testHookOutput_withNotification() {
        let notification = HookNotification(title: "Title", body: "Body")
        let output = HookOutput(notification: notification)
        XCTAssertEqual(output.notification?.title, "Title")
        XCTAssertEqual(output.notification?.body, "Body")
    }

    // MARK: - PermissionUpdate

    func testPermissionUpdate_creation() {
        let update = PermissionUpdate(tool: "file_write", behavior: "allow")
        XCTAssertEqual(update.tool, "file_write")
        XCTAssertEqual(update.behavior, "allow")
    }

    func testPermissionUpdate_equality() {
        let a = PermissionUpdate(tool: "bash", behavior: "deny")
        let b = PermissionUpdate(tool: "bash", behavior: "deny")
        XCTAssertEqual(a, b)
    }

    func testPermissionUpdate_inequality() {
        let a = PermissionUpdate(tool: "bash", behavior: "deny")
        let b = PermissionUpdate(tool: "bash", behavior: "allow")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - HookNotification

    func testHookNotification_creation() {
        let notification = HookNotification(title: "Alert", body: "Something happened")
        XCTAssertEqual(notification.title, "Alert")
        XCTAssertEqual(notification.body, "Something happened")
        XCTAssertEqual(notification.level, "info")
    }

    func testHookNotification_customLevel() {
        let notification = HookNotification(title: "Error", body: "Failed", level: "error")
        XCTAssertEqual(notification.level, "error")
    }

    func testHookNotification_equality() {
        let a = HookNotification(title: "A", body: "B", level: "info")
        let b = HookNotification(title: "A", body: "B", level: "info")
        XCTAssertEqual(a, b)
    }

    func testHookNotification_inequality() {
        let a = HookNotification(title: "A", body: "B")
        let b = HookNotification(title: "C", body: "D")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - HookDefinition

    func testHookDefinition_defaults() {
        let def = HookDefinition()
        XCTAssertNil(def.command)
        XCTAssertNil(def.matcher)
        XCTAssertNil(def.timeout)
    }

    func testHookDefinition_allFields() {
        let def = HookDefinition(command: "echo", matcher: "bash", timeout: 30)
        XCTAssertEqual(def.command, "echo")
        XCTAssertEqual(def.matcher, "bash")
        XCTAssertEqual(def.timeout, 30)
    }
}
