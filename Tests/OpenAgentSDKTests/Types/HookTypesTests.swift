import XCTest
@testable import OpenAgentSDK

final class HookTypesTests: XCTestCase {

    // MARK: - HookEvent

    func testHookEvent_allCases() {
        XCTAssertEqual(HookEvent.allCases.count, 23, "HookEvent should have 23 cases")
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
        let update = PermissionUpdate(tool: "bash", behavior: .deny)
        let output = HookOutput(permissionUpdate: update)
        XCTAssertEqual(output.permissionUpdate?.tool, "bash")
        XCTAssertEqual(output.permissionUpdate?.behavior, .deny)
    }

    func testHookOutput_withNotification() {
        let notification = HookNotification(title: "Title", body: "Body")
        let output = HookOutput(notification: notification)
        XCTAssertEqual(output.notification?.title, "Title")
        XCTAssertEqual(output.notification?.body, "Body")
    }

    func testHookOutput_equality() {
        let a = HookOutput(message: "hi", block: true)
        let b = HookOutput(message: "hi", block: true)
        XCTAssertEqual(a, b)
    }

    func testHookOutput_inequality_message() {
        let a = HookOutput(message: "hi")
        let b = HookOutput(message: "bye")
        XCTAssertNotEqual(a, b)
    }

    func testHookOutput_equality_allFields() {
        let notification = HookNotification(title: "T", body: "B", level: .warning)
        let permUpdate = PermissionUpdate(tool: "bash", behavior: .deny)
        let a = HookOutput(message: "msg", permissionUpdate: permUpdate, block: true, notification: notification)
        let b = HookOutput(message: "msg", permissionUpdate: permUpdate, block: true, notification: notification)
        XCTAssertEqual(a, b)
    }

    // MARK: - PermissionUpdate

    func testPermissionUpdate_creation() {
        let update = PermissionUpdate(tool: "file_write", behavior: .allow)
        XCTAssertEqual(update.tool, "file_write")
        XCTAssertEqual(update.behavior, .allow)
    }

    func testPermissionUpdate_equality() {
        let a = PermissionUpdate(tool: "bash", behavior: .deny)
        let b = PermissionUpdate(tool: "bash", behavior: .deny)
        XCTAssertEqual(a, b)
    }

    func testPermissionUpdate_inequality() {
        let a = PermissionUpdate(tool: "bash", behavior: .deny)
        let b = PermissionUpdate(tool: "bash", behavior: .allow)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - HookNotification

    func testHookNotification_creation() {
        let notification = HookNotification(title: "Alert", body: "Something happened")
        XCTAssertEqual(notification.title, "Alert")
        XCTAssertEqual(notification.body, "Something happened")
        XCTAssertEqual(notification.level, .info)
    }

    func testHookNotification_customLevel() {
        let notification = HookNotification(title: "Error", body: "Failed", level: .error)
        XCTAssertEqual(notification.level, .error)
    }

    func testHookNotification_equality() {
        let a = HookNotification(title: "A", body: "B", level: .info)
        let b = HookNotification(title: "A", body: "B", level: .info)
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
        XCTAssertNil(def.handler)
        XCTAssertNil(def.matcher)
        XCTAssertNil(def.timeout)
    }

    func testHookDefinition_allFields() {
        let def = HookDefinition(command: "echo", matcher: "bash", timeout: 30)
        XCTAssertEqual(def.command, "echo")
        XCTAssertEqual(def.matcher, "bash")
        XCTAssertEqual(def.timeout, 30)
    }

    // MARK: - HookNotificationLevel

    func testHookNotificationLevel_rawValues() {
        XCTAssertEqual(HookNotificationLevel.info.rawValue, "info")
        XCTAssertEqual(HookNotificationLevel.warning.rawValue, "warning")
        XCTAssertEqual(HookNotificationLevel.error.rawValue, "error")
        XCTAssertEqual(HookNotificationLevel.debug.rawValue, "debug")
    }

    func testHookNotificationLevel_allCases() {
        XCTAssertEqual(HookNotificationLevel.allCases.count, 4)
    }

    func testHookNotificationLevel_initFromString_fallsBackToInfo() {
        XCTAssertEqual(HookNotificationLevel("critical"), .info)
        XCTAssertEqual(HookNotificationLevel(""), .info)
        XCTAssertEqual(HookNotificationLevel("info"), .info)
        XCTAssertEqual(HookNotificationLevel("warning"), .warning)
    }

    // MARK: - PermissionBehavior

    func testPermissionBehavior_rawValues() {
        XCTAssertEqual(PermissionBehavior.allow.rawValue, "allow")
        XCTAssertEqual(PermissionBehavior.deny.rawValue, "deny")
        XCTAssertEqual(PermissionBehavior.ask.rawValue, "ask")
    }

    func testPermissionBehavior_allCases() {
        XCTAssertEqual(PermissionBehavior.allCases.count, 3)
    }

    func testPermissionBehavior_initFromRawValue() {
        XCTAssertEqual(PermissionBehavior(rawValue: "allow"), .allow)
        XCTAssertEqual(PermissionBehavior(rawValue: "deny"), .deny)
        XCTAssertEqual(PermissionBehavior(rawValue: "ask"), .ask)
        XCTAssertNil(PermissionBehavior(rawValue: "unknown"))
    }

    // MARK: - Story 17-4: HookEvent New Cases (AC1)

    /// AC1 [P0]: HookEvent.setup case exists with rawValue "setup".
    func testHookEvent_setup_rawValue() {
        let event = HookEvent(rawValue: "setup")
        XCTAssertNotNil(event, "HookEvent must have 'setup' case (TS SDK Setup event)")
        XCTAssertEqual(event?.rawValue, "setup")
    }

    /// AC1 [P0]: HookEvent.worktreeCreate case exists with rawValue "worktreeCreate".
    func testHookEvent_worktreeCreate_rawValue() {
        let event = HookEvent(rawValue: "worktreeCreate")
        XCTAssertNotNil(event, "HookEvent must have 'worktreeCreate' case (TS SDK WorktreeCreate event)")
        XCTAssertEqual(event?.rawValue, "worktreeCreate")
    }

    /// AC1 [P0]: HookEvent.worktreeRemove case exists with rawValue "worktreeRemove".
    func testHookEvent_worktreeRemove_rawValue() {
        let event = HookEvent(rawValue: "worktreeRemove")
        XCTAssertNotNil(event, "HookEvent must have 'worktreeRemove' case (TS SDK WorktreeRemove event)")
        XCTAssertEqual(event?.rawValue, "worktreeRemove")
    }

    /// AC1 [P0]: HookEvent has 23 cases after adding 3 new events.
    func testHookEvent_allCases_count23() {
        XCTAssertEqual(HookEvent.allCases.count, 23,
            "HookEvent should have 23 cases (20 original + setup + worktreeCreate + worktreeRemove)")
    }

    /// AC1 [P0]: New HookEvent cases are included in allCases.
    func testHookEvent_newCases_inAllCases() {
        let rawValues = Set(HookEvent.allCases.map { $0.rawValue })
        XCTAssertTrue(rawValues.contains("setup"),
            "allCases must contain 'setup'")
        XCTAssertTrue(rawValues.contains("worktreeCreate"),
            "allCases must contain 'worktreeCreate'")
        XCTAssertTrue(rawValues.contains("worktreeRemove"),
            "allCases must contain 'worktreeRemove'")
    }

    // MARK: - Story 17-4: HookInput Base Fields (AC2)

    /// AC2 [P0]: HookInput has transcriptPath field with default nil.
    func testHookInput_transcriptPath_defaultNil() {
        let input = HookInput(event: .preToolUse)
        XCTAssertNil(input.transcriptPath,
            "HookInput.transcriptPath should default to nil")
    }

    /// AC2 [P0]: HookInput has permissionMode field with default nil.
    func testHookInput_permissionMode_defaultNil() {
        let input = HookInput(event: .preToolUse)
        XCTAssertNil(input.permissionMode,
            "HookInput.permissionMode should default to nil")
    }

    /// AC2 [P0]: HookInput has agentId field with default nil.
    func testHookInput_agentId_defaultNil() {
        let input = HookInput(event: .preToolUse)
        XCTAssertNil(input.agentId,
            "HookInput.agentId should default to nil")
    }

    /// AC2 [P0]: HookInput has agentType field with default nil.
    func testHookInput_agentType_defaultNil() {
        let input = HookInput(event: .preToolUse)
        XCTAssertNil(input.agentType,
            "HookInput.agentType should default to nil")
    }

    /// AC2 [P0]: HookInput can be constructed with all base fields.
    func testHookInput_allBaseFields() {
        let input = HookInput(
            event: .sessionStart,
            transcriptPath: "/path/to/transcript.jsonl",
            permissionMode: "default",
            agentId: "agent-123",
            agentType: "orchestrator"
        )
        XCTAssertEqual(input.event, .sessionStart)
        XCTAssertEqual(input.transcriptPath, "/path/to/transcript.jsonl")
        XCTAssertEqual(input.permissionMode, "default")
        XCTAssertEqual(input.agentId, "agent-123")
        XCTAssertEqual(input.agentType, "orchestrator")
    }

    /// AC2 [P1]: HookInput backward compatibility - existing init call sites still compile.
    func testHookInput_backwardCompat_existingInit() {
        // This mirrors the exact pattern used in existing call sites
        let input = HookInput(
            event: .preToolUse,
            toolName: "Bash",
            toolInput: "{\"command\":\"ls\"}",
            toolOutput: nil,
            toolUseId: "tu_123",
            sessionId: "sess_abc",
            cwd: "/tmp",
            error: nil
        )
        XCTAssertEqual(input.event, .preToolUse)
        XCTAssertEqual(input.toolName, "Bash")
        XCTAssertNil(input.transcriptPath)
        XCTAssertNil(input.permissionMode)
        XCTAssertNil(input.agentId)
        XCTAssertNil(input.agentType)
    }

    // MARK: - Story 17-4: Per-Event HookInput Fields (AC3)

    /// AC3 [P0]: HookInput has stopHookActive field with default nil.
    func testHookInput_stopHookActive_defaultNil() {
        let input = HookInput(event: .stop)
        XCTAssertNil(input.stopHookActive,
            "HookInput.stopHookActive should default to nil")
    }

    /// AC3 [P0]: HookInput has lastAssistantMessage field with default nil.
    func testHookInput_lastAssistantMessage_defaultNil() {
        let input = HookInput(event: .stop)
        XCTAssertNil(input.lastAssistantMessage,
            "HookInput.lastAssistantMessage should default to nil")
    }

    /// AC3 [P0]: HookInput has trigger field with default nil.
    func testHookInput_trigger_defaultNil() {
        let input = HookInput(event: .preCompact)
        XCTAssertNil(input.trigger,
            "HookInput.trigger should default to nil")
    }

    /// AC3 [P0]: HookInput has customInstructions field with default nil.
    func testHookInput_customInstructions_defaultNil() {
        let input = HookInput(event: .preCompact)
        XCTAssertNil(input.customInstructions,
            "HookInput.customInstructions should default to nil")
    }

    /// AC3 [P0]: HookInput has permissionSuggestions field with default nil.
    func testHookInput_permissionSuggestions_defaultNil() {
        let input = HookInput(event: .permissionRequest)
        XCTAssertNil(input.permissionSuggestions,
            "HookInput.permissionSuggestions should default to nil")
    }

    /// AC3 [P0]: HookInput has isInterrupt field with default nil.
    func testHookInput_isInterrupt_defaultNil() {
        let input = HookInput(event: .postToolUseFailure)
        XCTAssertNil(input.isInterrupt,
            "HookInput.isInterrupt should default to nil")
    }

    /// AC3 [P0]: HookInput has agentTranscriptPath field with default nil.
    func testHookInput_agentTranscriptPath_defaultNil() {
        let input = HookInput(event: .subagentStop)
        XCTAssertNil(input.agentTranscriptPath,
            "HookInput.agentTranscriptPath should default to nil")
    }

    /// AC3 [P0]: HookInput can be constructed with per-event fields populated.
    func testHookInput_perEventFields_stopEvent() {
        let input = HookInput(
            event: .stop,
            stopHookActive: true,
            lastAssistantMessage: "I am done."
        )
        XCTAssertTrue(input.stopHookActive ?? false)
        XCTAssertEqual(input.lastAssistantMessage, "I am done.")
    }

    /// AC3 [P0]: HookInput can be constructed with PreCompact event fields.
    func testHookInput_perEventFields_preCompactEvent() {
        let input = HookInput(
            event: .preCompact,
            trigger: "manual",
            customInstructions: "Focus on key context"
        )
        XCTAssertEqual(input.trigger, "manual")
        XCTAssertEqual(input.customInstructions, "Focus on key context")
    }

    /// AC3 [P0]: HookInput can be constructed with PermissionRequest fields.
    func testHookInput_perEventFields_permissionRequest() {
        let input = HookInput(
            event: .permissionRequest,
            permissionSuggestions: ["Allow Bash for ls", "Deny for rm"]
        )
        XCTAssertEqual(input.permissionSuggestions?.count, 2)
        XCTAssertEqual(input.permissionSuggestions?[0], "Allow Bash for ls")
    }

    /// AC3 [P0]: HookInput can be constructed with SubagentStop fields.
    func testHookInput_perEventFields_subagentStop() {
        let input = HookInput(
            event: .subagentStop,
            lastAssistantMessage: "Sub-agent finished.",
            agentTranscriptPath: "/path/to/agent/transcript.jsonl"
        )
        XCTAssertEqual(input.agentTranscriptPath, "/path/to/agent/transcript.jsonl")
        XCTAssertEqual(input.lastAssistantMessage, "Sub-agent finished.")
    }

    /// AC3 [P0]: HookInput can be constructed with PostToolUseFailure fields.
    func testHookInput_perEventFields_postToolUseFailure() {
        let input = HookInput(
            event: .postToolUseFailure,
            error: "Tool crashed",
            isInterrupt: true
        )
        XCTAssertEqual(input.error, "Tool crashed")
        XCTAssertTrue(input.isInterrupt ?? false)
    }

    // MARK: - Story 17-4: PermissionDecision Enum (AC4)

    /// AC4 [P0]: PermissionDecision has allow, deny, ask cases.
    func testPermissionDecision_hasThreeCases() {
        XCTAssertEqual(PermissionDecision.allCases.count, 3,
            "PermissionDecision must have exactly 3 cases: allow, deny, ask")
    }

    /// AC4 [P0]: PermissionDecision rawValues match expected strings.
    func testPermissionDecision_rawValues() {
        XCTAssertEqual(PermissionDecision.allow.rawValue, "allow")
        XCTAssertEqual(PermissionDecision.deny.rawValue, "deny")
        XCTAssertEqual(PermissionDecision.ask.rawValue, "ask")
    }

    /// AC4 [P0]: PermissionDecision conforms to Equatable.
    func testPermissionDecision_equality() {
        XCTAssertEqual(PermissionDecision.allow, PermissionDecision.allow)
        XCTAssertNotEqual(PermissionDecision.allow, PermissionDecision.deny)
        XCTAssertNotEqual(PermissionDecision.deny, PermissionDecision.ask)
    }

    /// AC4 [P0]: PermissionDecision conforms to Sendable.
    func testPermissionDecision_isSendable() {
        let decision: Sendable = PermissionDecision.allow
        XCTAssertNotNil(decision, "PermissionDecision must conform to Sendable")
    }

    /// AC4 [P0]: PermissionDecision init from rawValue.
    func testPermissionDecision_initFromRawValue() {
        XCTAssertEqual(PermissionDecision(rawValue: "allow"), .allow)
        XCTAssertEqual(PermissionDecision(rawValue: "deny"), .deny)
        XCTAssertEqual(PermissionDecision(rawValue: "ask"), .ask)
        XCTAssertNil(PermissionDecision(rawValue: "unknown"))
    }

    // MARK: - Story 17-4: HookOutput New Fields (AC4)

    /// AC4 [P0]: HookOutput has systemMessage field with default nil.
    func testHookOutput_systemMessage_defaultNil() {
        let output = HookOutput()
        XCTAssertNil(output.systemMessage,
            "HookOutput.systemMessage should default to nil")
    }

    /// AC4 [P0]: HookOutput has reason field with default nil.
    func testHookOutput_reason_defaultNil() {
        let output = HookOutput()
        XCTAssertNil(output.reason,
            "HookOutput.reason should default to nil")
    }

    /// AC4 [P0]: HookOutput has updatedInput field with default nil.
    func testHookOutput_updatedInput_defaultNil() {
        let output = HookOutput()
        XCTAssertNil(output.updatedInput,
            "HookOutput.updatedInput should default to nil")
    }

    /// AC4 [P0]: HookOutput has additionalContext field with default nil.
    func testHookOutput_additionalContext_defaultNil() {
        let output = HookOutput()
        XCTAssertNil(output.additionalContext,
            "HookOutput.additionalContext should default to nil")
    }

    /// AC4 [P0]: HookOutput has permissionDecision field with default nil.
    func testHookOutput_permissionDecision_defaultNil() {
        let output = HookOutput()
        XCTAssertNil(output.permissionDecision,
            "HookOutput.permissionDecision should default to nil")
    }

    /// AC4 [P0]: HookOutput has updatedMCPToolOutput field with default nil.
    func testHookOutput_updatedMCPToolOutput_defaultNil() {
        let output = HookOutput()
        XCTAssertNil(output.updatedMCPToolOutput,
            "HookOutput.updatedMCPToolOutput should default to nil")
    }

    /// AC4 [P0]: HookOutput can be constructed with all new fields.
    func testHookOutput_allNewFields() {
        let output = HookOutput(
            message: "msg",
            permissionUpdate: nil,
            block: false,
            notification: nil,
            systemMessage: "System override",
            reason: "Policy violation",
            updatedInput: ["command": "safe_command"],
            additionalContext: "Extra context here",
            permissionDecision: .deny,
            updatedMCPToolOutput: ["result": "modified"]
        )
        XCTAssertEqual(output.systemMessage, "System override")
        XCTAssertEqual(output.reason, "Policy violation")
        XCTAssertNotNil(output.updatedInput)
        XCTAssertEqual(output.additionalContext, "Extra context here")
        XCTAssertEqual(output.permissionDecision, .deny)
        XCTAssertNotNil(output.updatedMCPToolOutput)
    }

    /// AC4 [P1]: HookOutput backward compatibility - existing 4-arg init compiles.
    func testHookOutput_backwardCompat_existingInit() {
        let output = HookOutput(
            message: "Blocked",
            permissionUpdate: PermissionUpdate(tool: "Bash", behavior: .deny),
            block: true,
            notification: HookNotification(title: "Hook", body: "Blocked Bash", level: .warning)
        )
        XCTAssertEqual(output.message, "Blocked")
        XCTAssertTrue(output.block)
        XCTAssertNil(output.systemMessage)
        XCTAssertNil(output.reason)
        XCTAssertNil(output.updatedInput)
        XCTAssertNil(output.additionalContext)
        XCTAssertNil(output.permissionDecision)
        XCTAssertNil(output.updatedMCPToolOutput)
    }

    /// AC4 [P0]: HookOutput Equatable works with new fields (Equatable fields compared).
    func testHookOutput_equality_withNewFields() {
        let a = HookOutput(
            message: "msg",
            block: true,
            systemMessage: "sys",
            reason: "because",
            additionalContext: "ctx",
            permissionDecision: .allow
        )
        let b = HookOutput(
            message: "msg",
            block: true,
            systemMessage: "sys",
            reason: "because",
            additionalContext: "ctx",
            permissionDecision: .allow
        )
        XCTAssertEqual(a, b, "HookOutput with new fields should be equatable")
    }

    /// AC4 [P0]: HookOutput Equatable detects difference in new fields.
    func testHookOutput_inequality_differentSystemMessage() {
        let a = HookOutput(systemMessage: "sys-a")
        let b = HookOutput(systemMessage: "sys-b")
        XCTAssertNotEqual(a, b, "Different systemMessage should make outputs unequal")
    }

    /// AC4 [P0]: HookOutput Equatable detects difference in permissionDecision.
    func testHookOutput_inequality_differentPermissionDecision() {
        let a = HookOutput(permissionDecision: .allow)
        let b = HookOutput(permissionDecision: .deny)
        XCTAssertNotEqual(a, b, "Different permissionDecision should make outputs unequal")
    }

    /// AC4 [P0]: HookOutput field count is 11 (4 original + 6 new + decision).
    func testHookOutput_fieldCount() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        XCTAssertEqual(mirror.children.count, 11,
            "HookOutput should have 11 fields (message, permissionUpdate, block, notification, systemMessage, reason, updatedInput, additionalContext, permissionDecision, updatedMCPToolOutput, decision)")
    }

    /// AC4 [P0]: HookInput field count is 19 (8 original + 4 base + 7 per-event).
    func testHookInput_fieldCount() {
        let input = HookInput(event: .preToolUse)
        let mirror = Mirror(reflecting: input)
        XCTAssertEqual(mirror.children.count, 19,
            "HookInput should have 19 fields (event + 7 original optionals + 4 base + 7 per-event)")
    }
}
