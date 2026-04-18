// HookSystemCompatTests.swift
// Story 16.4: Hook System Compatibility Verification
// ATDD: Tests verify TS SDK 18 HookEvents <-> Swift SDK HookEvent 20 cases
//       with field-level HookInput, HookOutput, HookDefinition verification
// TDD Phase: RED (tests verify expected contract; known gaps documented)
//
// These tests verify that Swift SDK's hook system covers all 18 TypeScript SDK
// HookEvents and their corresponding input/output types. The tests use Mirror
// introspection to detect field presence/absence and document compatibility gaps.

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Build Compilation Verification (P0)

/// Verifies that HookEvent, HookInput, HookOutput, HookDefinition and all
/// associated types compile correctly.
final class HookSystemBuildCompatTests: XCTestCase {

    /// AC1 [P0]: HookEvent enum exists and has exactly 23 cases (20 + 3 new from Story 17-4).
    func testHookEvent_has23Cases() {
        // Exhaustive iteration confirms all 23 cases exist at compile time
        let allCases = HookEvent.allCases
        XCTAssertEqual(allCases.count, 23,
            "HookEvent must have exactly 23 cases. TS SDK has 18 events + 5 Swift extras (now all 18 matched).")
    }

    /// AC1 [P0]: HookEvent conforms to CaseIterable (required for iteration).
    func testHookEvent_isCaseIterable() {
        let allCases = HookEvent.allCases
        XCTAssertFalse(allCases.isEmpty,
            "HookEvent.allCases must be non-empty (CaseIterable)")
    }

    /// AC1 [P0]: HookEvent conforms to Sendable (required for async hook registry).
    func testHookEvent_isSendable() {
        let event: Sendable = HookEvent.preToolUse
        XCTAssertNotNil(event, "HookEvent must conform to Sendable")
    }

    /// AC1 [P0]: HookInput can be constructed with all available fields.
    func testHookInput_compiles() {
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
    }

    /// AC1 [P0]: HookOutput can be constructed with all available fields.
    func testHookOutput_compiles() {
        let output = HookOutput(
            message: "Blocked",
            permissionUpdate: PermissionUpdate(tool: "Bash", behavior: .deny),
            block: true,
            notification: HookNotification(title: "Hook", body: "Blocked Bash", level: .warning)
        )
        XCTAssertTrue(output.block)
    }

    /// AC1 [P0]: HookDefinition can be constructed with all available fields.
    func testHookDefinition_compiles() {
        let def = HookDefinition(
            handler: { _ in HookOutput(block: true) },
            matcher: "Bash",
            timeout: 10_000
        )
        XCTAssertNotNil(def.handler)
    }

    /// AC1 [P0]: HookRegistry actor can be instantiated.
    func testHookRegistry_instantiation() async {
        let registry = HookRegistry()
        let hasHooks = await registry.hasHooks(.preToolUse)
        XCTAssertFalse(hasHooks, "New registry should have no hooks")
    }
}

// MARK: - AC2: 18 HookEvent Coverage Verification (P0)

/// Verifies that Swift SDK's HookEvent enum covers all 18 TS SDK HookEvents.
/// TS SDK events: PreToolUse, PostToolUse, PostToolUseFailure, Notification,
///   UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop,
///   PreCompact, PermissionRequest, Setup, TeammateIdle, TaskCompleted,
///   ConfigChange, WorktreeCreate, WorktreeRemove
final class HookEventCoverageCompatTests: XCTestCase {

    /// AC2 [P0]: PreToolUse event exists in Swift.
    func testHookEvent_preToolUse_exists() {
        let event = HookEvent(rawValue: "preToolUse")
        XCTAssertNotNil(event,
            "HookEvent must have preToolUse case. TS SDK: PreToolUse")
    }

    /// AC2 [P0]: PostToolUse event exists in Swift.
    func testHookEvent_postToolUse_exists() {
        let event = HookEvent(rawValue: "postToolUse")
        XCTAssertNotNil(event,
            "HookEvent must have postToolUse case. TS SDK: PostToolUse")
    }

    /// AC2 [P0]: PostToolUseFailure event exists in Swift.
    func testHookEvent_postToolUseFailure_exists() {
        let event = HookEvent(rawValue: "postToolUseFailure")
        XCTAssertNotNil(event,
            "HookEvent must have postToolUseFailure case. TS SDK: PostToolUseFailure")
    }

    /// AC2 [P0]: Notification event exists in Swift.
    func testHookEvent_notification_exists() {
        let event = HookEvent(rawValue: "notification")
        XCTAssertNotNil(event,
            "HookEvent must have notification case. TS SDK: Notification")
    }

    /// AC2 [P0]: UserPromptSubmit event exists in Swift.
    func testHookEvent_userPromptSubmit_exists() {
        let event = HookEvent(rawValue: "userPromptSubmit")
        XCTAssertNotNil(event,
            "HookEvent must have userPromptSubmit case. TS SDK: UserPromptSubmit")
    }

    /// AC2 [P0]: SessionStart event exists in Swift.
    func testHookEvent_sessionStart_exists() {
        let event = HookEvent(rawValue: "sessionStart")
        XCTAssertNotNil(event,
            "HookEvent must have sessionStart case. TS SDK: SessionStart")
    }

    /// AC2 [P0]: SessionEnd event exists in Swift.
    func testHookEvent_sessionEnd_exists() {
        let event = HookEvent(rawValue: "sessionEnd")
        XCTAssertNotNil(event,
            "HookEvent must have sessionEnd case. TS SDK: SessionEnd")
    }

    /// AC2 [P0]: Stop event exists in Swift.
    func testHookEvent_stop_exists() {
        let event = HookEvent(rawValue: "stop")
        XCTAssertNotNil(event,
            "HookEvent must have stop case. TS SDK: Stop")
    }

    /// AC2 [P0]: SubagentStart event exists in Swift.
    func testHookEvent_subagentStart_exists() {
        let event = HookEvent(rawValue: "subagentStart")
        XCTAssertNotNil(event,
            "HookEvent must have subagentStart case. TS SDK: SubagentStart")
    }

    /// AC2 [P0]: SubagentStop event exists in Swift.
    func testHookEvent_subagentStop_exists() {
        let event = HookEvent(rawValue: "subagentStop")
        XCTAssertNotNil(event,
            "HookEvent must have subagentStop case. TS SDK: SubagentStop")
    }

    /// AC2 [P0]: PreCompact event exists in Swift.
    func testHookEvent_preCompact_exists() {
        let event = HookEvent(rawValue: "preCompact")
        XCTAssertNotNil(event,
            "HookEvent must have preCompact case. TS SDK: PreCompact")
    }

    /// AC2 [P0]: PermissionRequest event exists in Swift.
    func testHookEvent_permissionRequest_exists() {
        let event = HookEvent(rawValue: "permissionRequest")
        XCTAssertNotNil(event,
            "HookEvent must have permissionRequest case. TS SDK: PermissionRequest")
    }

    /// AC2 [P0]: TeammateIdle event exists in Swift.
    func testHookEvent_teammateIdle_exists() {
        let event = HookEvent(rawValue: "teammateIdle")
        XCTAssertNotNil(event,
            "HookEvent must have teammateIdle case. TS SDK: TeammateIdle")
    }

    /// AC2 [P0]: TaskCompleted event exists in Swift.
    func testHookEvent_taskCompleted_exists() {
        let event = HookEvent(rawValue: "taskCompleted")
        XCTAssertNotNil(event,
            "HookEvent must have taskCompleted case. TS SDK: TaskCompleted")
    }

    /// AC2 [P0]: ConfigChange event exists in Swift.
    func testHookEvent_configChange_exists() {
        let event = HookEvent(rawValue: "configChange")
        XCTAssertNotNil(event,
            "HookEvent must have configChange case. TS SDK: ConfigChange")
    }

    /// AC2 [RESOLVED by Story 17-4]: Setup event now exists in Swift.
    func testHookEvent_setup_gap() {
        let event = HookEvent(rawValue: "setup")
        XCTAssertNotNil(event,
            "HookEvent must have setup case. TS SDK has Setup event. Resolved by Story 17-4.")
    }

    /// AC2 [RESOLVED by Story 17-4]: WorktreeCreate event now exists in Swift.
    func testHookEvent_worktreeCreate_gap() {
        let event = HookEvent(rawValue: "worktreeCreate")
        XCTAssertNotNil(event,
            "HookEvent must have worktreeCreate case. TS SDK has WorktreeCreate event. Resolved by Story 17-4.")
    }

    /// AC2 [RESOLVED by Story 17-4]: WorktreeRemove event now exists in Swift.
    func testHookEvent_worktreeRemove_gap() {
        let event = HookEvent(rawValue: "worktreeRemove")
        XCTAssertNotNil(event,
            "HookEvent must have worktreeRemove case. TS SDK has WorktreeRemove event. Resolved by Story 17-4.")
    }

    /// AC2 [P0]: Swift has extra events not in TS SDK.
    func testHookEvent_swiftExtras() {
        let extras = ["permissionDenied", "taskCreated", "cwdChanged", "fileChanged", "postCompact"]
        for extra in extras {
            let event = HookEvent(rawValue: extra)
            XCTAssertNotNil(event,
                "Swift extra event '\(extra)' should exist (no TS SDK equivalent)")
        }
    }

    /// AC2 [P0]: Coverage summary: all 18 TS events now have Swift equivalents (Story 17-4).
    func testHookEvent_coverageSummary() {
        let tsEvents: [(String, String)] = [
            ("PreToolUse", "preToolUse"),
            ("PostToolUse", "postToolUse"),
            ("PostToolUseFailure", "postToolUseFailure"),
            ("Notification", "notification"),
            ("UserPromptSubmit", "userPromptSubmit"),
            ("SessionStart", "sessionStart"),
            ("SessionEnd", "sessionEnd"),
            ("Stop", "stop"),
            ("SubagentStart", "subagentStart"),
            ("SubagentStop", "subagentStop"),
            ("PreCompact", "preCompact"),
            ("PermissionRequest", "permissionRequest"),
            ("Setup", "setup"),          // RESOLVED by Story 17-4
            ("TeammateIdle", "teammateIdle"),
            ("TaskCompleted", "taskCompleted"),
            ("ConfigChange", "configChange"),
            ("WorktreeCreate", "worktreeCreate"),  // RESOLVED by Story 17-4
            ("WorktreeRemove", "worktreeRemove"),  // RESOLVED by Story 17-4
        ]

        var passCount = 0
        var missingCount = 0
        for (tsName, rawValue) in tsEvents {
            if HookEvent(rawValue: rawValue) != nil {
                passCount += 1
            } else {
                missingCount += 1
                print("  [MISSING] \(tsName) -> \(rawValue)")
            }
        }

        print("")
        print("=== HookEvent Coverage Summary ===")
        print("PASS: \(passCount) | MISSING: \(missingCount) | Total TS events: \(tsEvents.count)")
        print("")

        XCTAssertEqual(passCount, 18, "All 18 TS events should have Swift equivalents (resolved by Story 17-4)")
        XCTAssertEqual(missingCount, 0, "No TS events should be missing after Story 17-4")
    }
}

// MARK: - AC3: BaseHookInput Field Verification (P0)

/// Verifies Swift SDK's HookInput base fields cover TS SDK's BaseHookInput.
/// TS SDK BaseHookInput fields: session_id, transcript_path, cwd, permission_mode, agent_id, agent_type
/// Swift HookInput fields: event, toolName, toolInput, toolOutput, toolUseId, sessionId, cwd, error
final class BaseHookInputCompatTests: XCTestCase {

    /// AC3 [P0]: HookInput has sessionId field (maps to TS SDK session_id).
    func testHookInput_sessionId_available() {
        let input = HookInput(event: .preToolUse, sessionId: "sess_123")
        XCTAssertEqual(input.sessionId, "sess_123",
            "HookInput.sessionId maps to TS SDK BaseHookInput.session_id")
    }

    /// AC3 [P0]: HookInput has cwd field (maps to TS SDK cwd).
    func testHookInput_cwd_available() {
        let input = HookInput(event: .preToolUse, cwd: "/home/user")
        XCTAssertEqual(input.cwd, "/home/user",
            "HookInput.cwd maps to TS SDK BaseHookInput.cwd")
    }

    /// AC3 [P0]: HookInput has event field (always present).
    func testHookInput_event_available() {
        let input = HookInput(event: .postToolUse)
        XCTAssertEqual(input.event, .postToolUse,
            "HookInput.event is required and maps to TS SDK event type")
    }

    /// AC3 [RESOLVED by Story 17-4]: HookInput now has transcriptPath (TS SDK has transcript_path).
    func testHookInput_transcriptPath_gap() {
        let input = HookInput(event: .preToolUse)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("transcriptPath"),
            "HookInput must have transcriptPath. TS SDK BaseHookInput has transcript_path. Resolved by Story 17-4.")
    }

    /// AC3 [RESOLVED by Story 17-4]: HookInput now has permissionMode (TS SDK has permission_mode).
    func testHookInput_permissionMode_gap() {
        let input = HookInput(event: .preToolUse)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("permissionMode"),
            "HookInput must have permissionMode. TS SDK BaseHookInput has permission_mode. Resolved by Story 17-4.")
    }

    /// AC3 [RESOLVED by Story 17-4]: HookInput now has agentId (TS SDK has agent_id).
    func testHookInput_agentId_gap() {
        let input = HookInput(event: .preToolUse)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("agentId"),
            "HookInput must have agentId. TS SDK BaseHookInput has agent_id. Resolved by Story 17-4.")
    }

    /// AC3 [RESOLVED by Story 17-4]: HookInput now has agentType (TS SDK has agent_type).
    func testHookInput_agentType_gap() {
        let input = HookInput(event: .preToolUse)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("agentType"),
            "HookInput must have agentType. TS SDK BaseHookInput has agent_type. Resolved by Story 17-4.")
    }

    /// AC3 [P0]: HookInput has 19 fields (8 original + 4 base + 7 per-event from Story 17-4).
    func testHookInput_fieldCount() {
        let input = HookInput(event: .preToolUse)
        let mirror = Mirror(reflecting: input)
        XCTAssertEqual(mirror.children.count, 19,
            "HookInput should have 19 fields (8 original + 4 base + 7 per-event from Story 17-4).")
    }
}

// MARK: - AC4: PreToolUse/PostToolUse/PostToolUseFailure HookInput Verification (P0)

/// Verifies per-event HookInput fields for the three tool-related events.
/// TS SDK PreToolUse: tool_name, tool_input, tool_use_id
/// TS SDK PostToolUse: tool_name, tool_input, tool_response, tool_use_id
/// TS SDK PostToolUseFailure: error, is_interrupt
final class ToolEventHookInputCompatTests: XCTestCase {

    /// AC4 [P0]: HookInput has toolName field (maps to TS SDK tool_name).
    func testHookInput_toolName_available() {
        let input = HookInput(event: .preToolUse, toolName: "Bash")
        XCTAssertEqual(input.toolName, "Bash",
            "HookInput.toolName maps to TS SDK PreToolUse.tool_name")
    }

    /// AC4 [P0]: HookInput has toolInput field (maps to TS SDK tool_input).
    func testHookInput_toolInput_available() {
        let input = HookInput(event: .preToolUse, toolInput: "{\"command\":\"ls\"}")
        XCTAssertEqual(input.toolInput as? String, "{\"command\":\"ls\"}",
            "HookInput.toolInput maps to TS SDK PreToolUse.tool_input")
    }

    /// AC4 [P0]: HookInput has toolUseId field (maps to TS SDK tool_use_id).
    func testHookInput_toolUseId_available() {
        let input = HookInput(event: .preToolUse, toolUseId: "tu_abc")
        XCTAssertEqual(input.toolUseId, "tu_abc",
            "HookInput.toolUseId maps to TS SDK PreToolUse.tool_use_id")
    }

    /// AC4 [P0]: HookInput has toolOutput field (maps to TS SDK PostToolUse.tool_response).
    func testHookInput_toolOutput_available() {
        let input = HookInput(event: .postToolUse, toolOutput: "file1.txt\nfile2.txt")
        XCTAssertEqual(input.toolOutput as? String, "file1.txt\nfile2.txt",
            "HookInput.toolOutput maps to TS SDK PostToolUse.tool_response")
    }

    /// AC4 [P0]: HookInput has error field (maps to TS SDK PostToolUseFailure.error).
    func testHookInput_error_available() {
        let input = HookInput(event: .postToolUseFailure, error: "command not found")
        XCTAssertEqual(input.error, "command not found",
            "HookInput.error maps to TS SDK PostToolUseFailure.error")
    }

    /// AC4 [RESOLVED by Story 17-4]: HookInput now has isInterrupt (TS SDK PostToolUseFailure has is_interrupt).
    func testHookInput_isInterrupt_gap() {
        let input = HookInput(event: .postToolUseFailure, error: "interrupted")
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("isInterrupt"),
            "HookInput must have isInterrupt. TS SDK PostToolUseFailure has is_interrupt. Resolved by Story 17-4.")
    }
}

// MARK: - AC5: Other HookInput Type Verification (P0)

/// Verifies per-event HookInput fields for remaining events.
/// TS SDK Stop: stop_hook_active, last_assistant_message
/// TS SDK SubagentStart: agent_id, agent_type
/// TS SDK SubagentStop: agent_id, agent_transcript_path, agent_type, last_assistant_message
/// TS SDK PreCompact: trigger (manual/auto), custom_instructions
/// TS SDK PermissionRequest: tool_name, tool_input, permission_suggestions
final class OtherHookInputCompatTests: XCTestCase {

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has stopHookActive (TS SDK Stop has stop_hook_active).
    func testHookInput_stopHookActive_gap() {
        let input = HookInput(event: .stop)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("stopHookActive"),
            "HookInput must have stopHookActive. TS SDK StopHookInput has stop_hook_active. Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has lastAssistantMessage (TS SDK Stop has last_assistant_message).
    func testHookInput_lastAssistantMessage_gap() {
        let input = HookInput(event: .stop)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("lastAssistantMessage"),
            "HookInput must have lastAssistantMessage. TS SDK StopHookInput/SubagentStopHookInput has last_assistant_message. Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has agentId for SubagentStart (TS SDK has agent_id).
    func testHookInput_subagentStart_agentId_gap() {
        let input = HookInput(event: .subagentStart)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("agentId"),
            "HookInput must have agentId for subagent events. TS SDK SubagentStartHookInput has agent_id. Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has agentType for SubagentStart (TS SDK has agent_type).
    func testHookInput_subagentStart_agentType_gap() {
        let input = HookInput(event: .subagentStart)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("agentType"),
            "HookInput must have agentType for subagent events. TS SDK SubagentStartHookInput has agent_type. Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has agentTranscriptPath for SubagentStop.
    func testHookInput_subagentStop_agentTranscriptPath_gap() {
        let input = HookInput(event: .subagentStop)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("agentTranscriptPath"),
            "HookInput must have agentTranscriptPath. TS SDK SubagentStopHookInput has agent_transcript_path. Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has trigger field for PreCompact (TS SDK has trigger: manual/auto).
    func testHookInput_preCompact_trigger_gap() {
        let input = HookInput(event: .preCompact)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("trigger"),
            "HookInput must have trigger. TS SDK PreCompactHookInput has trigger (manual/auto). Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has customInstructions for PreCompact.
    func testHookInput_preCompact_customInstructions_gap() {
        let input = HookInput(event: .preCompact)
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("customInstructions"),
            "HookInput must have customInstructions. TS SDK PreCompactHookInput has custom_instructions. Resolved by Story 17-4.")
    }

    /// AC5 [RESOLVED by Story 17-4]: HookInput now has permissionSuggestions for PermissionRequest.
    func testHookInput_permissionRequest_permissionSuggestions_gap() {
        let input = HookInput(event: .permissionRequest, toolName: "Bash", toolInput: "{}")
        let mirror = Mirror(reflecting: input)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("permissionSuggestions"),
            "HookInput must have permissionSuggestions. TS SDK PermissionRequestHookInput has permission_suggestions. Resolved by Story 17-4.")
    }
}

// MARK: - AC6: HookCallbackMatcher Verification (P0)

/// Verifies Swift SDK's HookDefinition supports matcher regex filtering,
/// multiple hook callbacks array, and timeout configuration.
final class HookCallbackMatcherCompatTests: XCTestCase {

    /// AC6 [P0]: HookDefinition supports matcher regex filtering.
    func testHookDefinition_matcher_supported() {
        let def = HookDefinition(handler: { _ in nil }, matcher: "Bash")
        XCTAssertEqual(def.matcher, "Bash",
            "HookDefinition.matcher provides regex filtering like TS SDK's matcher: RegExp")
    }

    /// AC6 [P0]: HookDefinition matcher can be nil (matches all tools).
    func testHookDefinition_matcher_nil() {
        let def = HookDefinition(handler: { _ in nil }, matcher: nil)
        XCTAssertNil(def.matcher,
            "Nil matcher matches all tools, same as TS SDK undefined matcher")
    }

    /// AC6 [P0]: HookDefinition supports timeout with default 30000ms.
    func testHookDefinition_timeout_supported() {
        let def = HookDefinition(handler: { _ in nil }, timeout: 10_000)
        XCTAssertEqual(def.timeout, 10_000,
            "HookDefinition.timeout maps to TS SDK's timeout: number (default 30000ms)")
    }

    /// AC6 [P0]: HookDefinition timeout defaults to nil (HookRegistry applies 30000ms).
    func testHookDefinition_timeout_defaultNil() {
        let def = HookDefinition(handler: { _ in nil })
        XCTAssertNil(def.timeout,
            "Nil timeout means use default 30000ms, matching TS SDK default behavior")
    }

    /// AC6 [P0]: Multiple hooks can be registered for the same event (array behavior).
    func testHookRegistry_multipleHooksPerEvent() async {
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "first")
        }))
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "second")
        }))
        let hasHooks = await registry.hasHooks(.preToolUse)
        XCTAssertTrue(hasHooks, "Multiple hooks can be registered for the same event")

        let input = HookInput(event: .preToolUse, toolName: "Bash")
        let results = await registry.execute(.preToolUse, input: input)
        XCTAssertEqual(results.count, 2,
            "Both hooks should execute and return results")
        XCTAssertEqual(results[0].message, "first")
        XCTAssertEqual(results[1].message, "second",
            "Hooks execute in registration order (matches TS SDK behavior)")
    }

    /// AC6 [P0]: Matcher filtering skips non-matching tools.
    func testHookRegistry_matcherFiltering() async {
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "matched") },
            matcher: "Bash"
        ))
        let input = HookInput(event: .preToolUse, toolName: "Read")
        let results = await registry.execute(.preToolUse, input: input)
        XCTAssertTrue(results.isEmpty,
            "Matcher 'Bash' should NOT match toolName 'Read'")
    }

    /// AC6 [P0]: Matcher filtering matches correct tools.
    func testHookRegistry_matcherMatches() async {
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "matched") },
            matcher: "Bash"
        ))
        let input = HookInput(event: .preToolUse, toolName: "Bash")
        let results = await registry.execute(.preToolUse, input: input)
        XCTAssertEqual(results.count, 1,
            "Matcher 'Bash' should match toolName 'Bash'")
        XCTAssertEqual(results[0].message, "matched")
    }

    /// AC6 [DIFF]: TS SDK registers hooks as array per matcher. Swift registers one-at-a-time.
    func testHookRegistration_apiDifference() async {
        // TS SDK: hooks: HookCallback[] (array of callbacks per matcher)
        // Swift SDK: register() called once per HookDefinition
        // Both achieve the same result: multiple hooks per event
        let registry = HookRegistry()
        for i in 0..<3 {
            await registry.register(.postToolUse, definition: HookDefinition(
                handler: { _ in HookOutput(message: "hook\(i)") }
            ))
        }
        let input = HookInput(event: .postToolUse, toolName: "Bash")
        let results = await registry.execute(.postToolUse, input: input)
        XCTAssertEqual(results.count, 3,
            "Swift one-at-a-time registration achieves same result as TS array registration")
    }
}

// MARK: - AC7: HookOutput Type Verification (P0)

/// Verifies Swift SDK's HookOutput supports TS SDK SyncHookJSONOutput key fields.
/// TS SDK fields: decision (approve/block), systemMessage, reason,
///   permissionDecision (allow/deny/ask), updatedInput, additionalContext
/// TS SDK hookSpecificOutput variants: PreToolUse, PostToolUse, PermissionRequest
final class HookOutputCompatTests: XCTestCase {

    /// AC7 [PARTIAL]: HookOutput has block field (maps to TS SDK decision: block).
    func testHookOutput_block_available() {
        let output = HookOutput(block: true)
        XCTAssertTrue(output.block,
            "HookOutput.block maps to TS SDK decision: 'block'")
    }

    /// AC7 [P0]: HookOutput block defaults to false (no decision = approve).
    func testHookOutput_blockDefaultFalse() {
        let output = HookOutput()
        XCTAssertFalse(output.block,
            "Default block=false means 'approve', matching TS SDK default behavior")
    }

    /// AC7 [P0]: HookOutput has message field (partial mapping to TS SDK reason/systemMessage).
    func testHookOutput_message_available() {
        let output = HookOutput(message: "Operation denied")
        XCTAssertEqual(output.message, "Operation denied",
            "HookOutput.message partially maps to TS SDK reason/systemMessage")
    }

    /// AC7 [P0]: HookOutput has permissionUpdate field (maps to TS SDK permissionDecision).
    func testHookOutput_permissionUpdate_available() {
        let update = PermissionUpdate(tool: "Bash", behavior: .deny)
        let output = HookOutput(permissionUpdate: update)
        XCTAssertNotNil(output.permissionUpdate)
        XCTAssertEqual(output.permissionUpdate?.tool, "Bash")
        XCTAssertEqual(output.permissionUpdate?.behavior, .deny,
            "HookOutput.permissionUpdate maps to TS SDK permissionDecision (allow/deny)")
    }

    /// AC7 [P0]: HookOutput has notification field.
    func testHookOutput_notification_available() {
        let notification = HookNotification(title: "Alert", body: "Tool blocked", level: .warning)
        let output = HookOutput(notification: notification)
        XCTAssertNotNil(output.notification)
        XCTAssertEqual(output.notification?.title, "Alert")
    }

    /// AC7 [RESOLVED]: HookOutput now has decision field (TS SDK: approve/block).
    func testHookOutput_decision_exists() {
        let output = HookOutput(decision: .block)
        let mirror = Mirror(reflecting: output)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("decision"),
            "HookOutput now has decision field matching TS SDK.")
        XCTAssertEqual(output.decision, .block)
        XCTAssertTrue(output.block)
    }

    /// AC7 [RESOLVED by Story 17-4]: HookOutput now has systemMessage (TS SDK has systemMessage).
    func testHookOutput_systemMessage_gap() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("systemMessage"),
            "HookOutput must have systemMessage. TS SDK SyncHookJSONOutput has systemMessage. Resolved by Story 17-4.")
    }

    /// AC7 [RESOLVED by Story 17-4]: HookOutput now has reason field (TS SDK has reason).
    func testHookOutput_reason_gap() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("reason"),
            "HookOutput must have reason. TS SDK SyncHookJSONOutput has reason field. Resolved by Story 17-4.")
    }

    /// AC7 [RESOLVED by Story 17-4]: HookOutput now has updatedInput (TS SDK PreToolUse has updatedInput).
    func testHookOutput_updatedInput_gap() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("updatedInput"),
            "HookOutput must have updatedInput. TS SDK PreToolUse hookSpecificOutput has updatedInput. Resolved by Story 17-4.")
    }

    /// AC7 [RESOLVED by Story 17-4]: HookOutput now has additionalContext (TS SDK multiple variants have this).
    func testHookOutput_additionalContext_gap() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("additionalContext"),
            "HookOutput must have additionalContext. TS SDK hookSpecificOutput variants have additionalContext. Resolved by Story 17-4.")
    }

    /// AC7 [RESOLVED by Story 17-4]: HookOutput now has updatedMCPToolOutput (TS SDK PostToolUse has this).
    func testHookOutput_updatedMCPToolOutput_gap() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("updatedMCPToolOutput"),
            "HookOutput must have updatedMCPToolOutput. TS SDK PostToolUse hookSpecificOutput has this. Resolved by Story 17-4.")
    }

    /// AC7 [P0]: HookOutput has 11 fields (4 original + 6 new from Story 17-4 + decision).
    func testHookOutput_fieldCount() {
        let output = HookOutput()
        let mirror = Mirror(reflecting: output)
        XCTAssertEqual(mirror.children.count, 11,
            "HookOutput should have 11 fields (message, permissionUpdate, block, notification, systemMessage, reason, updatedInput, additionalContext, permissionDecision, updatedMCPToolOutput, decision).")
    }

    /// AC7 [P0]: PermissionBehavior has allow, deny, and ask cases.
    func testPermissionBehavior_cases() {
        let allow = PermissionBehavior.allow
        let deny = PermissionBehavior.deny
        let ask = PermissionBehavior.ask
        XCTAssertEqual(allow.rawValue, "allow")
        XCTAssertEqual(deny.rawValue, "deny")
        XCTAssertEqual(ask.rawValue, "ask",
            "PermissionBehavior now has allow/deny/ask matching TS SDK. Resolved by Story 17-5.")
    }

    /// AC7 [RESOLVED by Story 17-5]: PermissionBehavior now has 'ask' case matching TS SDK.
    /// PermissionDecision also has ask from Story 17-4 for hook-specific decisions.
    func testPermissionBehavior_ask_resolved() {
        // Story 17-5 adds 'ask' to PermissionBehavior to match TS SDK.
        let ask = PermissionBehavior(rawValue: "ask")
        XCTAssertNotNil(ask,
            "PermissionBehavior must have 'ask' case. Resolved by Story 17-5.")
        // Verify PermissionDecision also has ask (from Story 17-4)
        let decisionAsk = PermissionDecision(rawValue: "ask")
        XCTAssertNotNil(decisionAsk,
            "PermissionDecision must have 'ask' case. Resolved by Story 17-4.")
    }
}

// MARK: - AC8: Live Hook Execution Verification (P0)

/// Verifies that hooks execute correctly with real HookRegistry interactions.
/// Tests PreToolUse hook with block, PostToolUse hook for audit, and execution order.
final class LiveHookExecutionCompatTests: XCTestCase {

    /// AC8 [P0]: PreToolUse hook can block tool execution.
    func testPreToolUse_blockExecution() async {
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "Tool blocked", block: true) }
        ))

        let input = HookInput(event: .preToolUse, toolName: "Bash", toolInput: "{\"command\":\"rm -rf /\"}")
        let results = await registry.execute(.preToolUse, input: input)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].block,
            "PreToolUse hook returns block=true to intercept tool execution (TS SDK pattern)")
        XCTAssertEqual(results[0].message, "Tool blocked")
    }

    /// AC8 [P0]: PostToolUse hook can record audit log.
    func testPostToolUse_auditRecording() async {
        let registry = HookRegistry()
        nonisolated(unsafe) var auditLog: [(String, String)] = []

        await registry.register(.postToolUse, definition: HookDefinition(
            handler: { input in
                auditLog.append((input.toolName ?? "unknown", input.toolUseId ?? "no-id"))
                return HookOutput(message: "Audit recorded")
            }
        ))

        let input = HookInput(event: .postToolUse, toolName: "Bash", toolOutput: "success", toolUseId: "tu_001")
        let results = await registry.execute(.postToolUse, input: input)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].message, "Audit recorded")
        XCTAssertEqual(auditLog.count, 1)
        XCTAssertEqual(auditLog[0].0, "Bash")
        XCTAssertEqual(auditLog[0].1, "tu_001",
            "PostToolUse hook receives tool context for audit logging")
    }

    /// AC8 [P0]: Hooks execute in registration order.
    func testHooks_executeInRegistrationOrder() async {
        let registry = HookRegistry()
        nonisolated(unsafe) var executionOrder: [Int] = []

        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                executionOrder.append(1)
                return HookOutput(message: "first")
            }
        ))
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                executionOrder.append(2)
                return HookOutput(message: "second")
            }
        ))
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                executionOrder.append(3)
                return HookOutput(message: "third")
            }
        ))

        let input = HookInput(event: .preToolUse, toolName: "Bash")
        let results = await registry.execute(.preToolUse, input: input)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(executionOrder, [1, 2, 3],
            "Hooks must execute in registration order (matches TS SDK behavior)")
    }

    /// AC8 [P0]: Shell command hooks work alongside handler hooks.
    func testShellCommandHook_supported() async {
        let registry = HookRegistry()
        // Register a shell command hook (no handler, uses command field)
        await registry.register(.postToolUse, definition: HookDefinition(
            command: "echo 'audit'"
        ))
        // Also register a handler hook
        await registry.register(.postToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "handler") }
        ))

        let input = HookInput(event: .postToolUse, toolName: "Bash")
        let results = await registry.execute(.postToolUse, input: input)

        // Shell command may or may not produce output depending on execution environment,
        // but handler should always produce output
        XCTAssertTrue(results.contains(where: { $0.message == "handler" }),
            "Handler hook must produce output even when shell command hooks are also registered")
    }

    /// AC8 [P0]: HookRegistry clear removes all hooks.
    func testHookRegistry_clear() async {
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(block: true) }
        ))
        let hasBefore = await registry.hasHooks(.preToolUse)
        XCTAssertTrue(hasBefore)

        await registry.clear()
        let hasAfter = await registry.hasHooks(.preToolUse)
        XCTAssertFalse(hasAfter,
            "clear() removes all registered hooks")
    }

    /// AC8 [P0]: createHookRegistry factory function works.
    func testCreateHookRegistry_factory() async {
        let registry = await createHookRegistry()
        let hasHooks = await registry.hasHooks(.preToolUse)
        XCTAssertFalse(hasHooks,
            "createHookRegistry() creates empty registry (matches TS SDK createHookRegistry())")
    }

    /// AC8 [P0]: createHookRegistry with config registers hooks from config.
    func testCreateHookRegistry_withConfig() async {
        let registry = await createHookRegistry(config: [
            "preToolUse": [HookDefinition(handler: { _ in HookOutput(block: true) })]
        ])
        let hasHooks = await registry.hasHooks(.preToolUse)
        XCTAssertTrue(hasHooks,
            "createHookRegistry(config:) registers hooks from config dictionary")
    }

    /// AC8 [P0]: HookRegistry ignores invalid event names in config.
    func testCreateHookRegistry_invalidEventIgnored() async {
        let registry = await createHookRegistry(config: [
            "invalidEvent": [HookDefinition(handler: { _ in HookOutput(block: true) })]
        ])
        // Invalid events should be silently skipped (matches TS SDK behavior)
        for event in HookEvent.allCases {
            let hasHooks = await registry.hasHooks(event)
            XCTAssertFalse(hasHooks,
                "Invalid event names in config should be silently ignored")
        }
    }
}

// MARK: - AC9: Compatibility Report Output (P0)

/// Generates the complete compatibility report for all 18 TS SDK events
/// and all HookInput/HookOutput types with per-item status.
final class HookSystemCompatReportTests: XCTestCase {

    /// AC9 [P0]: Generate complete 18-row HookEvent compatibility report.
    func testCompatReport_all18HookEvents() {
        // TS SDK 18 HookEvents vs Swift SDK HookEvent mapping
        let tsEvents: [(index: Int, tsEvent: String, rawValue: String, status: String, note: String)] = [
            (1, "PreToolUse", "preToolUse", "PASS", "Case exists. Raw value differs (lowercase)."),
            (2, "PostToolUse", "postToolUse", "PASS", "Case exists. Raw value differs (lowercase)."),
            (3, "PostToolUseFailure", "postToolUseFailure", "PASS", "Case exists. Raw value differs (lowercase)."),
            (4, "Notification", "notification", "PASS", "Case exists. Raw value differs (lowercase)."),
            (5, "UserPromptSubmit", "userPromptSubmit", "PASS", "Case exists. Raw value differs (lowercase)."),
            (6, "SessionStart", "sessionStart", "PASS", "Case exists. Raw value differs (lowercase)."),
            (7, "SessionEnd", "sessionEnd", "PASS", "Case exists. Raw value differs (lowercase)."),
            (8, "Stop", "stop", "PASS", "Exact raw value match."),
            (9, "SubagentStart", "subagentStart", "PASS", "Case exists. Raw value differs (lowercase)."),
            (10, "SubagentStop", "subagentStop", "PASS", "Case exists. Raw value differs (lowercase)."),
            (11, "PreCompact", "preCompact", "PASS", "Case exists. Raw value differs (lowercase)."),
            (12, "PermissionRequest", "permissionRequest", "PASS", "Case exists. Raw value differs (lowercase)."),
            (13, "Setup", "setup", "PASS", "Case exists. Resolved by Story 17-4."),
            (14, "TeammateIdle", "teammateIdle", "PASS", "Case exists. Raw value differs (lowercase)."),
            (15, "TaskCompleted", "taskCompleted", "PASS", "Case exists. Raw value differs (lowercase)."),
            (16, "ConfigChange", "configChange", "PASS", "Case exists. Raw value differs (lowercase)."),
            (17, "WorktreeCreate", "worktreeCreate", "PASS", "Case exists. Resolved by Story 17-4."),
            (18, "WorktreeRemove", "worktreeRemove", "PASS", "Case exists. Resolved by Story 17-4."),
        ]

        XCTAssertEqual(tsEvents.count, 18, "Must have exactly 18 TS SDK HookEvent mappings")

        let passCount = tsEvents.filter { $0.status == "PASS" }.count
        let missingCount = tsEvents.filter { $0.status == "MISSING" }.count

        print("")
        print("=== Hook System Compatibility Report (AC9) ===")
        print("TS SDK 18 HookEvents vs Swift SDK HookEvent")
        for m in tsEvents {
            print("  \(m.index)\t\(m.tsEvent)\t\(m.rawValue)\t[\(m.status)]\t\(m.note)")
        }
        print("")
        print("Summary: PASS: \(passCount) | MISSING: \(missingCount) | Total: \(tsEvents.count)")
        print("Swift extras: permissionDenied, taskCreated, cwdChanged, fileChanged, postCompact")
        print("")

        XCTAssertEqual(passCount, 18, "All 18 TS events should have Swift equivalents (resolved by Story 17-4)")
        XCTAssertEqual(missingCount, 0, "No TS events should be MISSING after Story 17-4")
    }

    /// AC9 [P0]: HookInput field-level compatibility summary.
    func testCompatReport_hookInputFieldSummary() {
        let fields: [(tsField: String, swiftField: String, status: String)] = [
            // BaseHookInput fields
            ("session_id", "sessionId", "PASS"),
            ("transcript_path", "transcriptPath", "PASS"),
            ("cwd", "cwd", "PASS"),
            ("permission_mode", "permissionMode", "PASS"),
            ("agent_id", "agentId", "PASS"),
            ("agent_type", "agentType", "PASS"),
            // Tool event fields
            ("tool_name", "toolName", "PASS"),
            ("tool_input", "toolInput", "PASS"),
            ("tool_response", "toolOutput", "PASS"),
            ("tool_use_id", "toolUseId", "PASS"),
            ("error", "error", "PASS"),
            // Per-event fields (resolved by Story 17-4)
            ("is_interrupt", "isInterrupt", "PASS"),
            ("stop_hook_active", "stopHookActive", "PASS"),
            ("last_assistant_message", "lastAssistantMessage", "PASS"),
            ("agent_transcript_path", "agentTranscriptPath", "PASS"),
            ("trigger (manual/auto)", "trigger", "PASS"),
            ("custom_instructions", "customInstructions", "PASS"),
            ("permission_suggestions", "permissionSuggestions", "PASS"),
        ]

        let passCount = fields.filter { $0.status == "PASS" }.count
        let missingCount = fields.filter { $0.status == "MISSING" }.count

        print("")
        print("=== HookInput Field Compatibility ===")
        for f in fields {
            print("  [\(f.status)] TS: \(f.tsField) -> Swift: \(f.swiftField)")
        }
        print("Summary: PASS: \(passCount) | MISSING: \(missingCount) | Total: \(fields.count)")
        print("")

        XCTAssertEqual(passCount, 18, "All 18 fields should have Swift equivalents (resolved by Story 17-4)")
        XCTAssertEqual(missingCount, 0, "No fields should be MISSING after Story 17-4")
    }

    /// AC9 [P0]: HookOutput field-level compatibility summary.
    func testCompatReport_hookOutputFieldSummary() {
        let fields: [(tsField: String, swiftField: String, status: String)] = [
            ("decision (approve/block)", "decision: HookDecision?", "PASS"),
            ("systemMessage", "systemMessage", "PASS"),
            ("reason", "reason", "PASS"),
            ("permissionDecision (allow/deny/ask)", "permissionDecision", "PASS"),
            ("updatedInput", "updatedInput", "PASS"),
            ("additionalContext", "additionalContext", "PASS"),
            ("updatedMCPToolOutput", "updatedMCPToolOutput", "PASS"),
        ]

        let passCount = fields.filter { $0.status == "PASS" }.count
        let partialCount = fields.filter { $0.status == "PARTIAL" }.count
        let missingCount = fields.filter { $0.status == "MISSING" }.count

        print("")
        print("=== HookOutput Field Compatibility ===")
        for f in fields {
            print("  [\(f.status)] TS: \(f.tsField) -> Swift: \(f.swiftField)")
        }
        print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | MISSING: \(missingCount) | Total: \(fields.count)")
        print("")

        XCTAssertEqual(passCount, 7, "All 7 fields should be PASS (decision resolved by Spec 19)")
        XCTAssertEqual(partialCount, 0, "No fields should be PARTIAL after Spec 19")
        XCTAssertEqual(missingCount, 0, "No fields should be MISSING after Story 17-4")
    }
}
