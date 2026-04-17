import XCTest
@testable import OpenAgentSDK

// MARK: - Story 17-5 ATDD Tests: Permission System Enhancement

/// ATDD RED PHASE: Tests for Story 17-5 Permission System Enhancement.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `PermissionUpdateDestination` enum with 5 cases is added to PermissionTypes.swift
///   - `PermissionBehavior.ask` case is added to HookTypes.swift
///   - `PermissionUpdateOperation` enum with 6 cases is added to PermissionTypes.swift
///   - `PermissionUpdateAction` struct wrapping operation + destination is added to PermissionTypes.swift
///   - `CanUseToolResult` is extended with updatedPermissions, interrupt, toolUseID fields
///   - `ToolContext` is extended with suggestions, blockedPath, decisionReason, agentId fields
///   - ToolContext copy methods (withToolUseId, withSkillContext) include new fields
///   - `SDKPermissionDenial` integration is verified in ToolExecutor
/// TDD Phase: RED (feature not implemented yet)

// MARK: - AC1: PermissionUpdateDestination (5 cases)

final class PermissionUpdateDestinationATDDTests: XCTestCase {

    /// AC1 [P0]: PermissionUpdateDestination type should exist with 5 cases.
    func testPermissionUpdateDestination_hasFiveCases() {
        let allCases = PermissionUpdateDestination.allCases
        XCTAssertEqual(allCases.count, 5,
            "PermissionUpdateDestination must have exactly 5 cases: userSettings, projectSettings, localSettings, session, cliArg")
    }

    /// AC1 [P0]: PermissionUpdateDestination.userSettings rawValue is "userSettings".
    func testPermissionUpdateDestination_userSettings_rawValue() {
        XCTAssertEqual(PermissionUpdateDestination.userSettings.rawValue, "userSettings")
    }

    /// AC1 [P0]: PermissionUpdateDestination.projectSettings rawValue is "projectSettings".
    func testPermissionUpdateDestination_projectSettings_rawValue() {
        XCTAssertEqual(PermissionUpdateDestination.projectSettings.rawValue, "projectSettings")
    }

    /// AC1 [P0]: PermissionUpdateDestination.localSettings rawValue is "localSettings".
    func testPermissionUpdateDestination_localSettings_rawValue() {
        XCTAssertEqual(PermissionUpdateDestination.localSettings.rawValue, "localSettings")
    }

    /// AC1 [P0]: PermissionUpdateDestination.session rawValue is "session".
    func testPermissionUpdateDestination_session_rawValue() {
        XCTAssertEqual(PermissionUpdateDestination.session.rawValue, "session")
    }

    /// AC1 [P0]: PermissionUpdateDestination.cliArg rawValue is "cliArg".
    func testPermissionUpdateDestination_cliArg_rawValue() {
        XCTAssertEqual(PermissionUpdateDestination.cliArg.rawValue, "cliArg")
    }

    /// AC1 [P0]: PermissionUpdateDestination conforms to Sendable.
    func testPermissionUpdateDestination_conformsToSendable() {
        let dest: any Sendable = PermissionUpdateDestination.userSettings
        XCTAssertNotNil(dest)
    }

    /// AC1 [P0]: PermissionUpdateDestination conforms to Equatable.
    func testPermissionUpdateDestination_conformsToEquatable() {
        XCTAssertEqual(PermissionUpdateDestination.userSettings, PermissionUpdateDestination.userSettings)
        XCTAssertNotEqual(PermissionUpdateDestination.userSettings, PermissionUpdateDestination.session)
    }

    /// AC1 [P0]: PermissionUpdateDestination init from rawValue works.
    func testPermissionUpdateDestination_initFromRawValue() {
        XCTAssertEqual(PermissionUpdateDestination(rawValue: "userSettings"), .userSettings)
        XCTAssertEqual(PermissionUpdateDestination(rawValue: "projectSettings"), .projectSettings)
        XCTAssertEqual(PermissionUpdateDestination(rawValue: "localSettings"), .localSettings)
        XCTAssertEqual(PermissionUpdateDestination(rawValue: "session"), .session)
        XCTAssertEqual(PermissionUpdateDestination(rawValue: "cliArg"), .cliArg)
        XCTAssertNil(PermissionUpdateDestination(rawValue: "unknown"))
    }
}

// MARK: - AC1: PermissionUpdateOperation (6 cases)

final class PermissionUpdateOperationATDDTests: XCTestCase {

    /// AC1 [P0]: addRules operation carries rules and behavior.
    func testPermissionUpdateOperation_addRules() {
        let op = PermissionUpdateOperation.addRules(rules: ["Bash:*"], behavior: .allow)
        if case .addRules(let rules, let behavior) = op {
            XCTAssertEqual(rules, ["Bash:*"])
            XCTAssertEqual(behavior, .allow)
        } else {
            XCTFail("Expected .addRules case")
        }
    }

    /// AC1 [P0]: replaceRules operation carries rules and behavior.
    func testPermissionUpdateOperation_replaceRules() {
        let op = PermissionUpdateOperation.replaceRules(rules: ["Read:*"], behavior: .deny)
        if case .replaceRules(let rules, let behavior) = op {
            XCTAssertEqual(rules, ["Read:*"])
            XCTAssertEqual(behavior, .deny)
        } else {
            XCTFail("Expected .replaceRules case")
        }
    }

    /// AC1 [P0]: removeRules operation carries rules only.
    func testPermissionUpdateOperation_removeRules() {
        let op = PermissionUpdateOperation.removeRules(rules: ["Bash:rm *"])
        if case .removeRules(let rules) = op {
            XCTAssertEqual(rules, ["Bash:rm *"])
        } else {
            XCTFail("Expected .removeRules case")
        }
    }

    /// AC1 [P0]: setMode operation carries a PermissionMode.
    func testPermissionUpdateOperation_setMode() {
        let op = PermissionUpdateOperation.setMode(mode: .auto)
        if case .setMode(let mode) = op {
            XCTAssertEqual(mode, .auto)
        } else {
            XCTFail("Expected .setMode case")
        }
    }

    /// AC1 [P0]: addDirectories operation carries directories array.
    func testPermissionUpdateOperation_addDirectories() {
        let op = PermissionUpdateOperation.addDirectories(directories: ["/home/user/project"])
        if case .addDirectories(let dirs) = op {
            XCTAssertEqual(dirs, ["/home/user/project"])
        } else {
            XCTFail("Expected .addDirectories case")
        }
    }

    /// AC1 [P0]: removeDirectories operation carries directories array.
    func testPermissionUpdateOperation_removeDirectories() {
        let op = PermissionUpdateOperation.removeDirectories(directories: ["/tmp"])
        if case .removeDirectories(let dirs) = op {
            XCTAssertEqual(dirs, ["/tmp"])
        } else {
            XCTFail("Expected .removeDirectories case")
        }
    }

    /// AC1 [P0]: PermissionUpdateOperation conforms to Sendable.
    func testPermissionUpdateOperation_conformsToSendable() {
        let ops: [any Sendable] = [
            PermissionUpdateOperation.addRules(rules: [], behavior: .allow),
            PermissionUpdateOperation.replaceRules(rules: [], behavior: .deny),
            PermissionUpdateOperation.removeRules(rules: []),
            PermissionUpdateOperation.setMode(mode: .default),
            PermissionUpdateOperation.addDirectories(directories: []),
            PermissionUpdateOperation.removeDirectories(directories: [])
        ]
        XCTAssertEqual(ops.count, 6)
    }

    /// AC1 [P0]: PermissionUpdateOperation conforms to Equatable.
    func testPermissionUpdateOperation_conformsToEquatable() {
        let a = PermissionUpdateOperation.addRules(rules: ["Bash"], behavior: .allow)
        let b = PermissionUpdateOperation.addRules(rules: ["Bash"], behavior: .allow)
        XCTAssertEqual(a, b)
    }

    /// AC1 [P0]: PermissionUpdateOperation inequality for different cases.
    func testPermissionUpdateOperation_inequality_differentCases() {
        let a = PermissionUpdateOperation.addRules(rules: ["Bash"], behavior: .allow)
        let b = PermissionUpdateOperation.removeRules(rules: ["Bash"])
        XCTAssertNotEqual(a, b)
    }

    /// AC1 [P0]: addRules and replaceRules work with .ask behavior (after AC1 adds ask).
    func testPermissionUpdateOperation_addRules_withAskBehavior() {
        let op = PermissionUpdateOperation.addRules(rules: ["Glob:*"], behavior: .ask)
        if case .addRules(_, let behavior) = op {
            XCTAssertEqual(behavior, .ask,
                "addRules should support .ask behavior after PermissionBehavior.ask is added")
        } else {
            XCTFail("Expected .addRules case")
        }
    }
}

// MARK: - AC1: PermissionUpdateAction (operation + destination wrapper)

final class PermissionUpdateActionATDDTests: XCTestCase {

    /// AC1 [P0]: PermissionUpdateAction wraps operation with optional destination.
    func testPermissionUpdateAction_withDestination() {
        let op = PermissionUpdateOperation.addRules(rules: ["Bash:*"], behavior: .allow)
        let action = PermissionUpdateAction(operation: op, destination: .userSettings)
        XCTAssertEqual(action.destination, .userSettings)
    }

    /// AC1 [P0]: PermissionUpdateAction destination can be nil.
    func testPermissionUpdateAction_nilDestination() {
        let op = PermissionUpdateOperation.setMode(mode: .auto)
        let action = PermissionUpdateAction(operation: op, destination: nil)
        XCTAssertNil(action.destination)
    }

    /// AC1 [P0]: PermissionUpdateAction conforms to Sendable.
    func testPermissionUpdateAction_conformsToSendable() {
        let op = PermissionUpdateOperation.addDirectories(directories: ["/tmp"])
        let action: any Sendable = PermissionUpdateAction(operation: op, destination: .session)
        XCTAssertNotNil(action)
    }

    /// AC1 [P0]: PermissionUpdateAction conforms to Equatable.
    func testPermissionUpdateAction_conformsToEquatable() {
        let op = PermissionUpdateOperation.removeRules(rules: ["Bash"])
        let a = PermissionUpdateAction(operation: op, destination: .localSettings)
        let b = PermissionUpdateAction(operation: op, destination: .localSettings)
        XCTAssertEqual(a, b)
    }

    /// AC1 [P0]: PermissionUpdateAction inequality with different destinations.
    func testPermissionUpdateAction_inequality_differentDestinations() {
        let op = PermissionUpdateOperation.removeDirectories(directories: ["/tmp"])
        let a = PermissionUpdateAction(operation: op, destination: .userSettings)
        let b = PermissionUpdateAction(operation: op, destination: .projectSettings)
        XCTAssertNotEqual(a, b)
    }

    /// AC1 [P0]: PermissionUpdateAction inequality with different operations.
    func testPermissionUpdateAction_inequality_differentOperations() {
        let a = PermissionUpdateAction(
            operation: .addRules(rules: ["Read"], behavior: .allow),
            destination: .session
        )
        let b = PermissionUpdateAction(
            operation: .replaceRules(rules: ["Read"], behavior: .deny),
            destination: .session
        )
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - AC1: PermissionBehavior.ask

final class PermissionBehaviorAskATDDTests: XCTestCase {

    /// AC1 [P0]: PermissionBehavior has an `ask` case.
    func testPermissionBehavior_hasAskCase() {
        let ask = PermissionBehavior(rawValue: "ask")
        XCTAssertNotNil(ask,
            "PermissionBehavior must have an 'ask' case matching TS SDK behavior")
    }

    /// AC1 [P0]: PermissionBehavior.ask rawValue is "ask".
    func testPermissionBehavior_ask_rawValue() {
        XCTAssertEqual(PermissionBehavior.ask.rawValue, "ask")
    }

    /// AC1 [P0]: PermissionBehavior.allCases includes ask (now 3 cases: allow, deny, ask).
    func testPermissionBehavior_allCases_includesAsk() {
        XCTAssertTrue(PermissionBehavior.allCases.contains(.ask),
            "PermissionBehavior.allCases must include .ask")
        XCTAssertEqual(PermissionBehavior.allCases.count, 3,
            "PermissionBehavior should have 3 cases: allow, deny, ask")
    }
}

// MARK: - AC2: CanUseToolResult Extension

final class CanUseToolResultExtensionATDDTests: XCTestCase {

    /// AC2 [P0]: CanUseToolResult has updatedPermissions field with default nil.
    func testCanUseToolResult_hasUpdatedPermissions_defaultNil() {
        let result = CanUseToolResult(behavior: .allow)
        // The new field should default to nil for backward compat
        XCTAssertNil(result.updatedPermissions,
            "updatedPermissions should default to nil for backward compatibility")
    }

    /// AC2 [P0]: CanUseToolResult has interrupt field with default nil.
    func testCanUseToolResult_hasInterrupt_defaultNil() {
        let result = CanUseToolResult(behavior: .deny, message: "blocked")
        XCTAssertNil(result.interrupt,
            "interrupt should default to nil for backward compatibility")
    }

    /// AC2 [P0]: CanUseToolResult has toolUseID field with default nil.
    func testCanUseToolResult_hasToolUseID_defaultNil() {
        let result = CanUseToolResult(behavior: .allow)
        XCTAssertNil(result.toolUseID,
            "toolUseID should default to nil for backward compatibility")
    }

    /// AC2 [P0]: CanUseToolResult can be created with updatedPermissions.
    func testCanUseToolResult_withUpdatedPermissions() {
        let actions = [
            PermissionUpdateAction(
                operation: .addRules(rules: ["Bash:*"], behavior: .allow),
                destination: .session
            )
        ]
        let result = CanUseToolResult(
            behavior: .allow,
            updatedPermissions: actions
        )
        XCTAssertNotNil(result.updatedPermissions)
        XCTAssertEqual(result.updatedPermissions?.count, 1)
    }

    /// AC2 [P0]: CanUseToolResult can be created with interrupt.
    func testCanUseToolResult_withInterrupt() {
        let result = CanUseToolResult(
            behavior: .deny,
            message: "interrupted",
            interrupt: true
        )
        XCTAssertEqual(result.interrupt, true)
    }

    /// AC2 [P0]: CanUseToolResult can be created with toolUseID.
    func testCanUseToolResult_withToolUseID() {
        let result = CanUseToolResult(
            behavior: .allow,
            toolUseID: "tu_12345"
        )
        XCTAssertEqual(result.toolUseID, "tu_12345")
    }

    /// AC2 [P0]: CanUseToolResult backward compatibility - existing init still works.
    func testCanUseToolResult_backwardCompat_existingInit() {
        // Existing call sites should compile without modification
        let result = CanUseToolResult(behavior: .allow)
        XCTAssertEqual(result.behavior, .allow)
        XCTAssertNil(result.message)
        XCTAssertNil(result.updatedInput)
        XCTAssertNil(result.updatedPermissions)
        XCTAssertNil(result.interrupt)
        XCTAssertNil(result.toolUseID)
    }

    /// AC2 [P0]: CanUseToolResult equality still works (excludes non-Equatable fields).
    func testCanUseToolResult_equality_withNewFields() {
        let a = CanUseToolResult(behavior: .allow, toolUseID: "tu_1")
        let b = CanUseToolResult(behavior: .allow, toolUseID: "tu_2")
        // Equality should focus on behavior and message, not toolUseID (which is like updatedInput)
        XCTAssertEqual(a, b,
            "Equality should match existing behavior (behavior + message comparison)")
    }

    /// AC2 [P0]: CanUseToolResult factory methods still work.
    func testCanUseToolResult_factoryMethods_backwardCompat() {
        let allowResult = CanUseToolResult.allow()
        XCTAssertEqual(allowResult.behavior, .allow)

        let denyResult = CanUseToolResult.deny("denied")
        XCTAssertEqual(denyResult.behavior, .deny)
        XCTAssertEqual(denyResult.message, "denied")

        let allowWithInput = CanUseToolResult.allowWithInput(["key": "value"])
        XCTAssertEqual(allowWithInput.behavior, .allow)
    }
}

// MARK: - AC2: ToolContext Extension

final class ToolContextExtensionATDDTests: XCTestCase {

    /// AC2 [P0]: ToolContext has suggestions field with default nil.
    func testToolContext_hasSuggestions_defaultNil() {
        let ctx = ToolContext(cwd: "/tmp")
        XCTAssertNil(ctx.suggestions,
            "suggestions should default to nil for backward compatibility")
    }

    /// AC2 [P0]: ToolContext has blockedPath field with default nil.
    func testToolContext_hasBlockedPath_defaultNil() {
        let ctx = ToolContext(cwd: "/tmp")
        XCTAssertNil(ctx.blockedPath,
            "blockedPath should default to nil for backward compatibility")
    }

    /// AC2 [P0]: ToolContext has decisionReason field with default nil.
    func testToolContext_hasDecisionReason_defaultNil() {
        let ctx = ToolContext(cwd: "/tmp")
        XCTAssertNil(ctx.decisionReason,
            "decisionReason should default to nil for backward compatibility")
    }

    /// AC2 [P0]: ToolContext has agentId field with default nil.
    func testToolContext_hasAgentId_defaultNil() {
        let ctx = ToolContext(cwd: "/tmp")
        XCTAssertNil(ctx.agentId,
            "agentId should default to nil for backward compatibility")
    }

    /// AC2 [P0]: ToolContext can be created with all new fields.
    func testToolContext_initWithNewFields() {
        let suggestions = [
            PermissionUpdateAction(
                operation: .addRules(rules: ["Read:*"], behavior: .allow),
                destination: .projectSettings
            )
        ]
        let ctx = ToolContext(
            cwd: "/home/user/project",
            toolUseId: "tu_001",
            suggestions: suggestions,
            blockedPath: "/etc/secrets",
            decisionReason: "policy violation",
            agentId: "agent-123"
        )
        XCTAssertNotNil(ctx.suggestions)
        XCTAssertEqual(ctx.suggestions?.count, 1)
        XCTAssertEqual(ctx.blockedPath, "/etc/secrets")
        XCTAssertEqual(ctx.decisionReason, "policy violation")
        XCTAssertEqual(ctx.agentId, "agent-123")
    }

    /// AC2 [P0]: ToolContext backward compatibility - existing init still works.
    func testToolContext_backwardCompat_existingInit() {
        let ctx = ToolContext(cwd: "/tmp", toolUseId: "tu_abc")
        XCTAssertEqual(ctx.cwd, "/tmp")
        XCTAssertEqual(ctx.toolUseId, "tu_abc")
        XCTAssertNil(ctx.suggestions)
        XCTAssertNil(ctx.blockedPath)
        XCTAssertNil(ctx.decisionReason)
        XCTAssertNil(ctx.agentId)
    }

    /// AC2 [P0]: withToolUseId preserves all new fields.
    func testToolContext_withToolUseId_preservesNewFields() {
        let suggestions = [
            PermissionUpdateAction(
                operation: .removeRules(rules: ["Bash:rm"]),
                destination: .userSettings
            )
        ]
        let ctx = ToolContext(
            cwd: "/project",
            toolUseId: "old-id",
            suggestions: suggestions,
            blockedPath: "/restricted",
            decisionReason: "security",
            agentId: "agent-x"
        )
        let updated = ctx.withToolUseId("new-id")

        XCTAssertEqual(updated.toolUseId, "new-id")
        XCTAssertEqual(updated.cwd, "/project")
        XCTAssertNotNil(updated.suggestions)
        XCTAssertEqual(updated.suggestions?.count, 1)
        XCTAssertEqual(updated.blockedPath, "/restricted")
        XCTAssertEqual(updated.decisionReason, "security")
        XCTAssertEqual(updated.agentId, "agent-x")
    }

    /// AC2 [P0]: withSkillContext preserves all new fields.
    func testToolContext_withSkillContext_preservesNewFields() {
        let ctx = ToolContext(
            cwd: "/project",
            toolUseId: "tu_abc",
            suggestions: [],
            blockedPath: nil,
            decisionReason: "test",
            agentId: "agent-1"
        )
        let updated = ctx.withSkillContext(depth: 2)

        XCTAssertEqual(updated.skillNestingDepth, 2)
        XCTAssertEqual(updated.suggestions?.count, 0)
        XCTAssertEqual(updated.decisionReason, "test")
        XCTAssertEqual(updated.agentId, "agent-1")
    }

    /// AC2 [P0]: Existing ToolContext call sites compile without modification.
    func testToolContext_existingCallSites_compile() {
        // Minimal init
        let ctx1 = ToolContext(cwd: "/tmp")
        XCTAssertNotNil(ctx1)

        // With stores
        let ctx2 = ToolContext(
            cwd: "/tmp",
            toolUseId: "id",
            mailboxStore: MailboxStore(),
            teamStore: TeamStore(),
            hookRegistry: HookRegistry()
        )
        XCTAssertNotNil(ctx2.hookRegistry)

        // With permission
        let ctx3 = ToolContext(cwd: "/tmp", permissionMode: .auto)
        XCTAssertEqual(ctx3.permissionMode, .auto)
    }
}

// MARK: - AC3: SDKPermissionDenial Integration

final class SDKPermissionDenialIntegrationATDDTests: XCTestCase {

    /// AC3 [P0]: SDKPermissionDenial type exists and is accessible.
    func testSDKPermissionDenial_typeExists() {
        let denial = SDKMessage.SDKPermissionDenial(
            toolName: "Bash",
            toolUseId: "tu_123",
            toolInput: "{\"command\":\"rm -rf /\"}"
        )
        XCTAssertEqual(denial.toolName, "Bash")
        XCTAssertEqual(denial.toolUseId, "tu_123")
        XCTAssertEqual(denial.toolInput as? String, "{\"command\":\"rm -rf /\"}")
    }

    /// AC3 [P0]: SDKPermissionDenial conforms to Sendable.
    func testSDKPermissionDenial_conformsToSendable() {
        let denial: any Sendable = SDKMessage.SDKPermissionDenial(
            toolName: "Read",
            toolUseId: "tu_456",
            toolInput: ""
        )
        XCTAssertNotNil(denial)
    }

    /// AC3 [P0]: SDKPermissionDenial conforms to Equatable.
    func testSDKPermissionDenial_conformsToEquatable() {
        let a = SDKMessage.SDKPermissionDenial(toolName: "Bash", toolUseId: "tu_1", toolInput: "")
        let b = SDKMessage.SDKPermissionDenial(toolName: "Bash", toolUseId: "tu_1", toolInput: "")
        XCTAssertEqual(a, b)
    }

    /// AC3 [P0]: ResultData has permissionDenials field.
    func testResultData_hasPermissionDenialsField() {
        let denial = SDKMessage.SDKPermissionDenial(
            toolName: "Write",
            toolUseId: "tu_789",
            toolInput: "{\"path\":\"/etc/passwd\"}"
        )
        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "test",
            usage: nil,
            numTurns: 1,
            durationMs: 100,
            permissionDenials: [denial]
        )
        XCTAssertNotNil(resultData.permissionDenials)
        XCTAssertEqual(resultData.permissionDenials?.count, 1)
        XCTAssertEqual(resultData.permissionDenials?[0].toolName, "Write")
    }

    /// AC3 [P0]: ResultData permissionDenials defaults to nil.
    func testResultData_permissionDenials_defaultNil() {
        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "test",
            usage: nil,
            numTurns: 1,
            durationMs: 100
        )
        XCTAssertNil(resultData.permissionDenials,
            "permissionDenials should default to nil")
    }
}
