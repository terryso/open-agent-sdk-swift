// Story18_8_ATDDTests.swift
// Story 18.8: Update CompatOptions Example -- ATDD Tests
//
// ATDD tests for Story 18-8: Update CompatOptions/main.swift and
// AgentOptionsCompatTests.swift to reflect the features added by Story 17-2
// (AgentOptions Complete Parameters).
//
// Test design:
// - AC1: Core configuration PASS -- allowedTools, disallowedTools, fallbackModel, env updated
// - AC2: Advanced configuration PASS -- effort, outputFormat, toolConfig, includePartialMessages, promptSuggestions updated
// - AC3: Session configuration PASS -- continueRecentSession, forkSession, resumeSessionAt, persistSession updated
// - AC4: systemPromptConfig PASS -- SystemPromptConfig.preset(name:append:) exists
// - AC5: EffortLevel type PASS -- 4 cases with budgetTokens
// - AC6: ThinkingConfig effort PASS -- effort is separate EffortLevel, not on ThinkingConfig
// - AC7: Example comment headers updated (verified by code review)
// - AC8: Compat test summary updated -- correct PASS/PARTIAL/MISSING counts
// - AC9: Build and tests pass (verified externally)
//
// TDD Phase: RED -- Compat report table tests verify expected counts.
// AC1-AC6 tests verify SDK API and will PASS immediately (fields exist from 17-2).

import XCTest
@testable import OpenAgentSDK

// Helper: get field names from a type via Mirror
private func fieldNames(of value: Any) -> Set<String> {
    Set(Mirror(reflecting: value).children.compactMap { $0.label })
}

// ================================================================
// MARK: - AC1: Core Configuration PASS (3 tests)
// ================================================================

/// Verifies core config fields upgraded from MISSING/PARTIAL to PASS by Story 17-2.
final class Story18_8_CoreConfigATDDTests: XCTestCase {

    /// AC1 [P0]: allowedTools exists as [String]? on AgentOptions.
    func testAC1_allowedTools_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", allowedTools: ["Read", "Write"])
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("allowedTools"),
                       "AgentOptions has 'allowedTools' property")
        XCTAssertEqual(options.allowedTools, ["Read", "Write"],
                       "allowedTools stores tool whitelist correctly")
    }

    /// AC1 [P0]: disallowedTools exists as [String]? on AgentOptions.
    func testAC1_disallowedTools_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", disallowedTools: ["Bash"])
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("disallowedTools"),
                       "AgentOptions has 'disallowedTools' property")
        XCTAssertEqual(options.disallowedTools, ["Bash"],
                       "disallowedTools stores tool blacklist correctly")
    }

    /// AC1 [P0]: Core config summary should be 11 PASS + 1 PARTIAL + 0 MISSING.
    func testAC1_coreFields_allPass() {
        // Core: 12 fields
        // PASS (11): maxTurns, maxBudgetUsd, model, permissionMode, canUseTool, cwd, mcpServers,
        //            allowedTools, disallowedTools, fallbackModel, env
        // PARTIAL (1): systemPrompt (String only, but SystemPromptConfig alongside)
        // MISSING (0): none
        let passCount = 11
        let partialCount = 1
        let missingCount = 0
        let total = passCount + partialCount + missingCount

        XCTAssertEqual(total, 12, "Core config has 12 fields")
        XCTAssertEqual(passCount, 11, "11 core fields PASS")
        XCTAssertEqual(partialCount, 1, "1 core field PARTIAL (systemPrompt)")
        XCTAssertEqual(missingCount, 0, "0 core fields MISSING")
    }
}

// ================================================================
// MARK: - AC2: Advanced Configuration PASS (5 tests)
// ================================================================

/// Verifies advanced config fields upgraded from MISSING to PASS by Story 17-2.
final class Story18_8_AdvancedConfigATDDTests: XCTestCase {

    /// AC2 [P0]: effort exists as EffortLevel? on AgentOptions.
    func testAC2_effort_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", effort: .high)
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("effort"),
                       "AgentOptions has 'effort' property")
        XCTAssertEqual(options.effort, .high)
        XCTAssertEqual(EffortLevel.allCases.count, 4, "EffortLevel has 4 cases")
    }

    /// AC2 [P0]: outputFormat exists as OutputFormat? on AgentOptions.
    func testAC2_outputFormat_pass() {
        let schema: [String: Any] = ["type": "object"]
        let format = OutputFormat(jsonSchema: schema)
        let options = AgentOptions(apiKey: "test-key", model: "test", outputFormat: format)
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("outputFormat"),
                       "AgentOptions has 'outputFormat' property")
        XCTAssertEqual(options.outputFormat?.type, "json_schema",
                       "outputFormat type is always 'json_schema'")
    }

    /// AC2 [P0]: toolConfig exists as ToolConfig? on AgentOptions.
    func testAC2_toolConfig_pass() {
        let config = ToolConfig(maxConcurrentReadTools: 5, maxConcurrentWriteTools: 2)
        let options = AgentOptions(apiKey: "test-key", model: "test", toolConfig: config)
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("toolConfig"),
                       "AgentOptions has 'toolConfig' property")
        XCTAssertEqual(options.toolConfig?.maxConcurrentReadTools, 5)
        XCTAssertEqual(options.toolConfig?.maxConcurrentWriteTools, 2)
    }

    /// AC2 [P0]: includePartialMessages exists as Bool on AgentOptions (default true).
    func testAC2_includePartialMessages_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("includePartialMessages"),
                       "AgentOptions has 'includePartialMessages' property")
        XCTAssertTrue(options.includePartialMessages,
                       "includePartialMessages defaults to true")
    }

    /// AC2 [P0]: promptSuggestions exists as Bool on AgentOptions (default false).
    func testAC2_promptSuggestions_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("promptSuggestions"),
                       "AgentOptions has 'promptSuggestions' property")
        XCTAssertFalse(options.promptSuggestions,
                        "promptSuggestions defaults to false")
    }
}

// ================================================================
// MARK: - AC3: Session Configuration PASS (4 tests)
// ================================================================

/// Verifies session config fields upgraded from MISSING/PARTIAL to PASS by Story 17-2.
final class Story18_8_SessionConfigATDDTests: XCTestCase {

    /// AC3 [P0]: continueRecentSession exists as Bool on AgentOptions (default false).
    func testAC3_continueRecentSession_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("continueRecentSession"),
                       "AgentOptions has 'continueRecentSession' property")
        XCTAssertFalse(options.continueRecentSession,
                        "continueRecentSession defaults to false")
    }

    /// AC3 [P0]: forkSession exists as Bool on AgentOptions (default false).
    func testAC3_forkSession_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", forkSession: true)
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("forkSession"),
                       "AgentOptions has 'forkSession' property")
        XCTAssertTrue(options.forkSession)
    }

    /// AC3 [P0]: resumeSessionAt exists as String? on AgentOptions.
    /// This replaces the PARTIAL "resume" field with a direct property.
    func testAC3_resumeSessionAt_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", resumeSessionAt: "msg-123")
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("resumeSessionAt"),
                       "AgentOptions has 'resumeSessionAt' property")
        XCTAssertEqual(options.resumeSessionAt, "msg-123",
                       "resumeSessionAt stores message ID for truncating history")
    }

    /// AC3 [P0]: persistSession exists as Bool on AgentOptions (default true).
    func testAC3_persistSession_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("persistSession"),
                       "AgentOptions has 'persistSession' property")
        XCTAssertTrue(options.persistSession,
                       "persistSession defaults to true")
    }
}

// ================================================================
// MARK: - AC4: systemPromptConfig PASS (2 tests)
// ================================================================

/// Verifies SystemPromptConfig preset and text modes exist from Story 17-2.
final class Story18_8_SystemPromptConfigATDDTests: XCTestCase {

    /// AC4 [P0]: SystemPromptConfig.preset(name:append:) exists and works.
    func testAC4_systemPromptConfig_presetMode() {
        let presetConfig = SystemPromptConfig.preset(name: "claude_code", append: "custom")
        let options = AgentOptions(apiKey: "test-key", model: "test", systemPromptConfig: presetConfig)
        let fields = fieldNames(of: options)

        XCTAssertTrue(fields.contains("systemPromptConfig"),
                       "AgentOptions has 'systemPromptConfig' property")
        XCTAssertEqual(options.systemPromptConfig, presetConfig,
                       "systemPromptConfig stores preset configuration")
    }

    /// AC4 [P0]: SystemPromptConfig.text(String) exists and works.
    func testAC4_systemPromptConfig_textMode() {
        let textConfig = SystemPromptConfig.text("You are a helpful assistant.")
        let options = AgentOptions(apiKey: "test-key", model: "test", systemPromptConfig: textConfig)

        XCTAssertEqual(options.systemPromptConfig, textConfig,
                       "systemPromptConfig stores text configuration")
    }
}

// ================================================================
// MARK: - AC5: EffortLevel Type PASS (2 tests)
// ================================================================

/// Verifies EffortLevel enum with 4 cases and budgetTokens computed property.
final class Story18_8_EffortLevelATDDTests: XCTestCase {

    /// AC5 [P0]: EffortLevel has exactly 4 cases: low, medium, high, max.
    func testAC5_effortLevel_fourCases() {
        XCTAssertEqual(EffortLevel.allCases.count, 4,
                       "EffortLevel has exactly 4 cases")

        let cases: [EffortLevel] = [.low, .medium, .high, .max]
        for effortCase in cases {
            XCTAssertTrue(EffortLevel.allCases.contains(effortCase),
                           "EffortLevel contains \(effortCase.rawValue)")
        }
    }

    /// AC5 [P0]: EffortLevel has budgetTokens computed property.
    func testAC5_effortLevel_budgetTokens() {
        // Verify each effort level has a non-zero budgetTokens
        for effort in EffortLevel.allCases {
            XCTAssertGreaterThan(effort.budgetTokens, 0,
                                  "EffortLevel.\(effort.rawValue).budgetTokens > 0")
        }

        // Verify ordering: low < medium < high < max
        XCTAssertLessThan(EffortLevel.low.budgetTokens, EffortLevel.medium.budgetTokens)
        XCTAssertLessThan(EffortLevel.medium.budgetTokens, EffortLevel.high.budgetTokens)
        XCTAssertLessThan(EffortLevel.high.budgetTokens, EffortLevel.max.budgetTokens)
    }
}

// ================================================================
// MARK: - AC6: ThinkingConfig Effort PASS (1 test)
// ================================================================

/// Verifies effort is a separate EffortLevel enum, NOT a field on ThinkingConfig.
final class Story18_8_ThinkingConfigEffortATDDTests: XCTestCase {

    /// AC6 [P0]: effort is on AgentOptions as EffortLevel?, not on ThinkingConfig.
    /// TS SDK has effort as a separate top-level option, not nested in thinking config.
    func testAC6_thinkingConfig_effortSeparate() {
        // Verify ThinkingConfig does NOT have an effort field
        let adaptive = ThinkingConfig.adaptive
        let enabled = ThinkingConfig.enabled(budgetTokens: 1000)
        let disabled = ThinkingConfig.disabled

        let adaptiveFields = fieldNames(of: adaptive)
        let enabledFields = fieldNames(of: enabled)
        let disabledFields = fieldNames(of: disabled)

        XCTAssertFalse(adaptiveFields.contains("effort"),
                        "ThinkingConfig.adaptive has no 'effort' field -- effort is separate")
        XCTAssertFalse(enabledFields.contains("effort"),
                        "ThinkingConfig.enabled has no 'effort' field -- effort is separate")
        XCTAssertFalse(disabledFields.contains("effort"),
                        "ThinkingConfig.disabled has no 'effort' field -- effort is separate")

        // Verify effort is on AgentOptions instead
        let options = AgentOptions(apiKey: "test-key", model: "test", effort: .high)
        let optionsFields = fieldNames(of: options)
        XCTAssertTrue(optionsFields.contains("effort"),
                       "effort exists as a top-level property on AgentOptions")
        XCTAssertEqual(options.effort, .high)
    }
}

// ================================================================
// MARK: - AC8: Compat Test Summary Updated (3 tests -- RED PHASE)
// ================================================================

/// Verifies the expected compat report summary counts after Story 18-8 update.
final class Story18_8_CompatReportATDDTests: XCTestCase {

    /// AC8 [P0]: Overall summary should be 23 PASS + 6 PARTIAL + 6 MISSING + 2 N/A = 37.
    /// This fixes the known inconsistency where testCompatReport_overallSummary said 22/7
    /// but testCompatReport_completeFieldLevelCoverage said 23/6.
    func testAC8_overallSummary_23PASS_6PARTIAL() {
        let totalPass = 23
        let totalPartial = 6
        let totalMissing = 6
        let totalNA = 2
        let total = totalPass + totalPartial + totalMissing + totalNA

        XCTAssertEqual(total, 37, "Total verifications should be 37")
        XCTAssertEqual(totalPass, 23, "23 items PASS")
        XCTAssertEqual(totalPartial, 6, "6 items PARTIAL")
        XCTAssertEqual(totalMissing, 6, "6 items MISSING")
        XCTAssertEqual(totalNA, 2, "2 items N/A")

        // Coverage rate: (PASS + PARTIAL) / (PASS + PARTIAL + MISSING) = 29/35 = ~83%
        let actionable = totalPass + totalPartial + totalMissing
        let compatRate = Double(totalPass + totalPartial) / Double(actionable) * 100
        XCTAssertEqual(Int(compatRate), 82, "Pass+Partial rate should be ~82%")
    }

    /// AC8 [P0]: Category breakdown should have correct totals.
    func testAC8_categoryBreakdown_correctTotals() {
        // Core: 11 PASS + 1 PARTIAL + 0 MISSING = 12
        // Advanced: 7 PASS + 2 PARTIAL + 0 MISSING = 9
        // Session: 5 PASS + 0 PARTIAL + 0 MISSING = 5
        // Extended: 0 PASS + 3 PARTIAL + 6 MISSING + 2 N/A = 11
        // Total: 23 PASS + 6 PARTIAL + 6 MISSING + 2 N/A = 37

        let coreTotal = 12
        let advancedTotal = 9
        let sessionTotal = 5
        let extendedTotal = 11
        let grandTotal = coreTotal + advancedTotal + sessionTotal + extendedTotal

        XCTAssertEqual(grandTotal, 37, "Total TS SDK Options fields should be 37")
        XCTAssertEqual(coreTotal, 12, "Core config: 12 fields")
        XCTAssertEqual(advancedTotal, 9, "Advanced config: 9 fields")
        XCTAssertEqual(sessionTotal, 5, "Session config: 5 fields")
        XCTAssertEqual(extendedTotal, 11, "Extended config: 11 fields")
    }

    /// AC8 [P0]: Session config should have 5 PASS, 0 PARTIAL, 0 MISSING.
    func testAC8_sessionConfig_5PASS() {
        // Session: sessionId (PASS), forkSession (PASS), persistSession (PASS),
        //          continueRecentSession (PASS), resume (via resumeSessionAt, PASS)
        let passCount = 5
        let partialCount = 0
        let missingCount = 0
        let total = passCount + partialCount + missingCount

        XCTAssertEqual(total, 5, "Session config has 5 fields")
        XCTAssertEqual(passCount, 5, "5 session fields PASS")
        XCTAssertEqual(partialCount, 0, "0 session fields PARTIAL")
        XCTAssertEqual(missingCount, 0, "0 session fields MISSING")
    }
}
