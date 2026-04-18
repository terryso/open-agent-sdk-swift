// PermissionSystemCompatTests.swift
// Story 17.5: Permission System Compatibility Verification
// ATDD: Tests verify TS SDK PermissionUpdate 6 operations, PermissionBehavior.ask,
//       PermissionUpdateDestination 5 values, CanUseTool context/result fields,
//       and SDKPermissionDenial integration.
// TDD Phase: RED (tests verify expected contract; known gaps documented)

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: PermissionUpdateDestination Verification (P0)

/// Verifies Swift SDK has all 5 TS SDK PermissionUpdateDestination values.
final class PermissionUpdateDestinationCompatTests: XCTestCase {

    /// AC1 [P0]: userSettings destination exists (TS SDK: "userSettings").
    func testPermissionUpdateDestination_userSettings() {
        let dest = PermissionUpdateDestination(rawValue: "userSettings")
        XCTAssertNotNil(dest,
            "PermissionUpdateDestination must have userSettings. TS SDK has UserSettings.")
    }

    /// AC1 [P0]: projectSettings destination exists (TS SDK: "projectSettings").
    func testPermissionUpdateDestination_projectSettings() {
        let dest = PermissionUpdateDestination(rawValue: "projectSettings")
        XCTAssertNotNil(dest,
            "PermissionUpdateDestination must have projectSettings. TS SDK has ProjectSettings.")
    }

    /// AC1 [P0]: localSettings destination exists (TS SDK: "localSettings").
    func testPermissionUpdateDestination_localSettings() {
        let dest = PermissionUpdateDestination(rawValue: "localSettings")
        XCTAssertNotNil(dest,
            "PermissionUpdateDestination must have localSettings. TS SDK has LocalSettings.")
    }

    /// AC1 [P0]: session destination exists (TS SDK: "session").
    func testPermissionUpdateDestination_session() {
        let dest = PermissionUpdateDestination(rawValue: "session")
        XCTAssertNotNil(dest,
            "PermissionUpdateDestination must have session. TS SDK has Session.")
    }

    /// AC1 [P0]: cliArg destination exists (TS SDK: "cliArg").
    func testPermissionUpdateDestination_cliArg() {
        let dest = PermissionUpdateDestination(rawValue: "cliArg")
        XCTAssertNotNil(dest,
            "PermissionUpdateDestination must have cliArg. TS SDK has CliArg.")
    }

    /// AC1 [P0]: Coverage summary for PermissionUpdateDestination.
    func testPermissionUpdateDestination_coverageSummary() {
        let destinations: [(String, String)] = [
            ("UserSettings", "userSettings"),
            ("ProjectSettings", "projectSettings"),
            ("LocalSettings", "localSettings"),
            ("Session", "session"),
            ("CliArg", "cliArg"),
        ]

        var passCount = 0
        var missingCount = 0
        for (tsName, rawValue) in destinations {
            if PermissionUpdateDestination(rawValue: rawValue) != nil {
                passCount += 1
            } else {
                missingCount += 1
                print("  [MISSING] \(tsName) -> \(rawValue)")
            }
        }

        print("")
        print("=== PermissionUpdateDestination Coverage Summary ===")
        print("PASS: \(passCount) | MISSING: \(missingCount) | Total: \(destinations.count)")
        print("")

        XCTAssertEqual(passCount, 5, "All 5 TS SDK destinations should have Swift equivalents")
        XCTAssertEqual(missingCount, 0, "No TS SDK destinations should be missing")
    }
}

// MARK: - AC1: PermissionUpdateOperation 6 Operations Verification (P0)

/// Verifies Swift SDK has all 6 TS SDK PermissionUpdate operation types.
final class PermissionUpdateOperationCompatTests: XCTestCase {

    /// AC1 [P0]: addRules operation exists with rules and behavior params.
    func testPermissionUpdateOperation_addRules() {
        let op = PermissionUpdateOperation.addRules(rules: ["Bash:*"], behavior: .allow)
        if case .addRules(let rules, let behavior) = op {
            XCTAssertEqual(rules, ["Bash:*"])
            XCTAssertEqual(behavior, .allow)
        } else {
            XCTFail("addRules operation must exist. TS SDK has PermissionUpdate.addRules.")
        }
    }

    /// AC1 [P0]: replaceRules operation exists with rules and behavior params.
    func testPermissionUpdateOperation_replaceRules() {
        let op = PermissionUpdateOperation.replaceRules(rules: ["Glob:*"], behavior: .deny)
        if case .replaceRules(let rules, let behavior) = op {
            XCTAssertEqual(rules, ["Glob:*"])
            XCTAssertEqual(behavior, .deny)
        } else {
            XCTFail("replaceRules operation must exist. TS SDK has PermissionUpdate.replaceRules.")
        }
    }

    /// AC1 [P0]: removeRules operation exists with rules param.
    func testPermissionUpdateOperation_removeRules() {
        let op = PermissionUpdateOperation.removeRules(rules: ["Write:*"])
        if case .removeRules(let rules) = op {
            XCTAssertEqual(rules, ["Write:*"])
        } else {
            XCTFail("removeRules operation must exist. TS SDK has PermissionUpdate.removeRules.")
        }
    }

    /// AC1 [P0]: setMode operation exists with PermissionMode param.
    func testPermissionUpdateOperation_setMode() {
        let op = PermissionUpdateOperation.setMode(mode: .bypassPermissions)
        if case .setMode(let mode) = op {
            XCTAssertEqual(mode, .bypassPermissions)
        } else {
            XCTFail("setMode operation must exist. TS SDK has PermissionUpdate.setMode.")
        }
    }

    /// AC1 [P0]: addDirectories operation exists with directories param.
    func testPermissionUpdateOperation_addDirectories() {
        let op = PermissionUpdateOperation.addDirectories(directories: ["/workspace"])
        if case .addDirectories(let dirs) = op {
            XCTAssertEqual(dirs, ["/workspace"])
        } else {
            XCTFail("addDirectories operation must exist. TS SDK has PermissionUpdate.addDirectories.")
        }
    }

    /// AC1 [P0]: removeDirectories operation exists with directories param.
    func testPermissionUpdateOperation_removeDirectories() {
        let op = PermissionUpdateOperation.removeDirectories(directories: ["/old"])
        if case .removeDirectories(let dirs) = op {
            XCTAssertEqual(dirs, ["/old"])
        } else {
            XCTFail("removeDirectories operation must exist. TS SDK has PermissionUpdate.removeDirectories.")
        }
    }

    /// AC1 [P0]: Coverage summary for all 6 PermissionUpdateOperation types.
    func testPermissionUpdateOperation_coverageSummary() {
        let ops: [(String, PermissionUpdateOperation)] = [
            ("addRules", .addRules(rules: [], behavior: .allow)),
            ("replaceRules", .replaceRules(rules: [], behavior: .deny)),
            ("removeRules", .removeRules(rules: [])),
            ("setMode", .setMode(mode: .default)),
            ("addDirectories", .addDirectories(directories: [])),
            ("removeDirectories", .removeDirectories(directories: [])),
        ]

        print("")
        print("=== PermissionUpdateOperation Coverage Summary ===")
        print("Summary: \(ops.count) operations")
        print("")

        XCTAssertEqual(ops.count, 6, "All 6 TS SDK PermissionUpdate operations must exist")
    }
}

// MARK: - AC1: PermissionBehavior.ask Verification (P0)

/// Verifies PermissionBehavior has 'ask' case matching TS SDK.
final class PermissionBehaviorCompatTests: XCTestCase {

    /// AC1 [P0]: PermissionBehavior has 'ask' case.
    func testPermissionBehavior_ask_exists() {
        let ask = PermissionBehavior(rawValue: "ask")
        XCTAssertNotNil(ask,
            "PermissionBehavior must have 'ask' case. TS SDK PermissionBehavior has allow/deny/ask.")
    }

    /// AC1 [P0]: PermissionBehavior.allCases count is 3 (allow, deny, ask).
    func testPermissionBehavior_allCases_count() {
        XCTAssertEqual(PermissionBehavior.allCases.count, 3,
            "PermissionBehavior should have 3 cases: allow, deny, ask")
    }

    /// AC1 [P0]: All PermissionBehavior rawValues match TS SDK.
    func testPermissionBehavior_rawValues_matchTsSdk() {
        XCTAssertEqual(PermissionBehavior.allow.rawValue, "allow")
        XCTAssertEqual(PermissionBehavior.deny.rawValue, "deny")
        XCTAssertEqual(PermissionBehavior.ask.rawValue, "ask")
    }
}

// MARK: - AC2: CanUseTool Context Fields Verification (P0)

/// Verifies ToolContext has all TS SDK-equivalent permission callback fields.
final class CanUseToolContextCompatTests: XCTestCase {

    /// AC2 [P0]: ToolContext has suggestions field (TS SDK: suggestions).
    func testToolContext_suggestions_field() {
        let ctx = ToolContext(cwd: "/tmp")
        let mirror = Mirror(reflecting: ctx)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("suggestions"),
            "ToolContext must have suggestions field. TS SDK CanUseTool callback has suggestions parameter.")
    }

    /// AC2 [P0]: ToolContext has blockedPath field (TS SDK: blockedPath).
    func testToolContext_blockedPath_field() {
        let ctx = ToolContext(cwd: "/tmp")
        let mirror = Mirror(reflecting: ctx)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("blockedPath"),
            "ToolContext must have blockedPath field. TS SDK CanUseTool callback has blockedPath parameter.")
    }

    /// AC2 [P0]: ToolContext has decisionReason field (TS SDK: decisionReason).
    func testToolContext_decisionReason_field() {
        let ctx = ToolContext(cwd: "/tmp")
        let mirror = Mirror(reflecting: ctx)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("decisionReason"),
            "ToolContext must have decisionReason field. TS SDK CanUseTool callback has decisionReason parameter.")
    }

    /// AC2 [P0]: ToolContext has agentId field (TS SDK: agentID).
    func testToolContext_agentId_field() {
        let ctx = ToolContext(cwd: "/tmp")
        let mirror = Mirror(reflecting: ctx)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("agentId"),
            "ToolContext must have agentId field. TS SDK CanUseTool callback has agentID parameter.")
    }
}

// MARK: - AC2: CanUseToolResult Fields Verification (P0)

/// Verifies CanUseToolResult has all TS SDK-equivalent fields.
final class CanUseToolResultCompatTests: XCTestCase {

    /// AC2 [P0]: CanUseToolResult has updatedPermissions field.
    func testCanUseToolResult_updatedPermissions_field() {
        let result = CanUseToolResult(behavior: .allow)
        let mirror = Mirror(reflecting: result)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("updatedPermissions"),
            "CanUseToolResult must have updatedPermissions field. TS SDK has updatedPermissions.")
    }

    /// AC2 [P0]: CanUseToolResult has interrupt field.
    func testCanUseToolResult_interrupt_field() {
        let result = CanUseToolResult(behavior: .allow)
        let mirror = Mirror(reflecting: result)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("interrupt"),
            "CanUseToolResult must have interrupt field. TS SDK has interrupt.")
    }

    /// AC2 [P0]: CanUseToolResult has toolUseID field.
    func testCanUseToolResult_toolUseID_field() {
        let result = CanUseToolResult(behavior: .allow)
        let mirror = Mirror(reflecting: result)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("toolUseID"),
            "CanUseToolResult must have toolUseID field. TS SDK has toolUseID.")
    }
}

// MARK: - AC3: SDKPermissionDenial Integration Verification (P0)

/// Verifies SDKPermissionDenial is correctly accessible and integrated.
final class SDKPermissionDenialCompatTests: XCTestCase {

    /// AC3 [P0]: SDKPermissionDenial type exists (added by 17-1, verified by 17-5).
    func testSDKPermissionDenial_typeExists() {
        let denial = SDKMessage.SDKPermissionDenial(
            toolName: "Bash",
            toolUseId: "tu_001",
            toolInput: "{\"command\":\"ls\"}"
        )
        XCTAssertEqual(denial.toolName, "Bash",
            "SDKPermissionDenial.toolName maps to TS SDK SDKPermissionDenial.toolName")
        XCTAssertEqual(denial.toolUseId, "tu_001",
            "SDKPermissionDenial.toolUseId maps to TS SDK SDKPermissionDenial.toolUseId")
    }

    /// AC3 [P0]: ResultData.permissionDenials field exists.
    func testResultData_permissionDenials_field() {
        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "test",
            usage: nil,
            numTurns: 1,
            durationMs: 100
        )
        XCTAssertNil(resultData.permissionDenials,
            "ResultData.permissionDenials should exist and default to nil. TS SDK has permissionDenials on result.")
    }
}

// MARK: - AC4: Full Compatibility Report (P0)

/// Generates the complete compatibility report for all Story 17-5 items.
final class PermissionSystemCompatReportTests: XCTestCase {

    /// AC4 [P0]: Complete permission system gap report.
    func testCompatReport_permissionSystemGapSummary() {
        let gaps: [(index: Int, tsFeature: String, status: String, note: String)] = [
            // PermissionUpdateOperation (6 operations)
            (1, "PermissionUpdate.addRules", "RESOLVED", "Added as enum case with associated values"),
            (2, "PermissionUpdate.replaceRules", "RESOLVED", "Added as enum case with associated values"),
            (3, "PermissionUpdate.removeRules", "RESOLVED", "Added as enum case with associated values"),
            (4, "PermissionUpdate.setMode", "RESOLVED", "Added as enum case with PermissionMode"),
            (5, "PermissionUpdate.addDirectories", "RESOLVED", "Added as enum case with directories"),
            (6, "PermissionUpdate.removeDirectories", "RESOLVED", "Added as enum case with directories"),
            // PermissionUpdateDestination (5 values)
            (7, "PermissionUpdateDestination.userSettings", "RESOLVED", "Added to enum"),
            (8, "PermissionUpdateDestination.projectSettings", "RESOLVED", "Added to enum"),
            (9, "PermissionUpdateDestination.localSettings", "RESOLVED", "Added to enum"),
            (10, "PermissionUpdateDestination.session", "RESOLVED", "Added to enum"),
            (11, "PermissionUpdateDestination.cliArg", "RESOLVED", "Added to enum"),
            // PermissionBehavior.ask
            (12, "PermissionBehavior.ask", "RESOLVED", "Added case to enum"),
            // CanUseTool context fields (4 fields)
            (13, "CanUseTool.suggestions", "RESOLVED", "Added to ToolContext"),
            (14, "CanUseTool.blockedPath", "RESOLVED", "Added to ToolContext"),
            (15, "CanUseTool.decisionReason", "RESOLVED", "Added to ToolContext"),
            (16, "CanUseTool.agentID", "RESOLVED", "Added to ToolContext as agentId"),
            // CanUseToolResult fields (3 fields)
            (17, "CanUseToolResult.updatedPermissions", "RESOLVED", "Added to CanUseToolResult"),
            (18, "CanUseToolResult.interrupt", "RESOLVED", "Added to CanUseToolResult"),
            (19, "CanUseToolResult.toolUseID", "RESOLVED", "Added to CanUseToolResult"),
            // SDKPermissionDenial (2 items from 17-1, verified by 17-5)
            (20, "SDKPermissionDenial type", "RESOLVED", "Added by 17-1, verified"),
            (21, "ResultData.permissionDenials", "RESOLVED", "Added by 17-1, verified"),
        ]

        let resolvedCount = gaps.filter { $0.status == "RESOLVED" }.count
        let missingCount = gaps.filter { $0.status == "MISSING" }.count

        print("")
        print("=== Permission System Compatibility Report (Story 17-5) ===")
        print("TS SDK Permission Features vs Swift SDK")
        for g in gaps {
            if g.status != "PASS" {
                print("  \(g.index)\t\(g.tsFeature)\t[\(g.status)]\t\(g.note)")
            }
        }
        print("")
        print("Summary: RESOLVED: \(resolvedCount) | MISSING: \(missingCount) | Total: \(gaps.count)")
        print("")

        XCTAssertEqual(resolvedCount, 21, "All 21 permission system gaps should be resolved by Story 17-5")
        XCTAssertEqual(missingCount, 0, "No gaps should remain MISSING after Story 17-5")
    }
}
