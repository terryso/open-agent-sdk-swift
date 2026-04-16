// AgentOptionsEnhancementATDDTests.swift
// Story 17.2: AgentOptions Complete Parameters -- ATDD (TDD Red Phase)
//
// These tests verify the EXPECTED behavior after implementation of:
// - AC1: Core configuration fields (fallbackModel, env, allowedTools, disallowedTools)
// - AC2: Advanced configuration fields (effort, outputFormat, toolConfig, includePartialMessages, promptSuggestions)
// - AC3: Session configuration fields (continueRecentSession, forkSession, resumeSessionAt, persistSession)
// - AC4: EffortLevel enum
// - AC5: OutputFormat type
// - AC6: ToolConfig type
// - AC7: SystemPromptConfig preset support
// - AC8: Build and test verification
//
// TDD Phase: RED -- All tests will FAIL until the feature is implemented.
// After implementation, these tests should pass (GREEN phase).

import XCTest
@testable import OpenAgentSDK

// MARK: - AC4: EffortLevel Enum

/// Tests for the new EffortLevel enum with 4 cases: .low, .medium, .high, .max.
final class EffortLevelATDDTests: XCTestCase {

    /// AC4 [P0]: EffortLevel has exactly 4 cases matching TS SDK effort levels.
    func testEffortLevel_allCases() {
        let levels: [EffortLevel] = [.low, .medium, .high, .max]
        XCTAssertEqual(levels.count, 4, "EffortLevel must have exactly 4 cases")
    }

    /// AC4 [P0]: EffortLevel conforms to CaseIterable.
    func testEffortLevel_caseIterable() {
        XCTAssertEqual(EffortLevel.allCases.count, 4)
        XCTAssertTrue(EffortLevel.allCases.contains(.low))
        XCTAssertTrue(EffortLevel.allCases.contains(.medium))
        XCTAssertTrue(EffortLevel.allCases.contains(.high))
        XCTAssertTrue(EffortLevel.allCases.contains(.max))
    }

    /// AC4 [P0]: EffortLevel raw values match expected strings.
    func testEffortLevel_rawValues() {
        XCTAssertEqual(EffortLevel.low.rawValue, "low")
        XCTAssertEqual(EffortLevel.medium.rawValue, "medium")
        XCTAssertEqual(EffortLevel.high.rawValue, "high")
        XCTAssertEqual(EffortLevel.max.rawValue, "max")
    }

    /// AC4 [P0]: EffortLevel conforms to Sendable.
    func testEffortLevel_sendable() {
        let level: EffortLevel = .high
        let _: any Sendable = level
    }

    /// AC4 [P0]: EffortLevel conforms to Equatable.
    func testEffortLevel_equatable() {
        XCTAssertEqual(EffortLevel.low, EffortLevel.low)
        XCTAssertNotEqual(EffortLevel.low, EffortLevel.max)
    }

    /// AC4 [P0]: EffortLevel conforms to String (raw value type).
    func testEffortLevel_stringRawValue() {
        let level = EffortLevel(rawValue: "low")
        XCTAssertEqual(level, .low)
        let invalid = EffortLevel(rawValue: "unknown")
        XCTAssertNil(invalid)
    }

    /// AC4 [P1]: EffortLevel maps to thinking budget tokens.
    func testEffortLevel_budgetTokens() {
        XCTAssertEqual(EffortLevel.low.budgetTokens, 1024)
        XCTAssertEqual(EffortLevel.medium.budgetTokens, 5120)
        XCTAssertEqual(EffortLevel.high.budgetTokens, 10240)
        XCTAssertEqual(EffortLevel.max.budgetTokens, 32768)
    }
}

// MARK: - AC5: OutputFormat Type

/// Tests for the new OutputFormat struct with SendableJSONSchema wrapper.
final class OutputFormatATDDTests: XCTestCase {

    /// AC5 [P0]: OutputFormat can be constructed with type and jsonSchema.
    func testOutputFormat_init() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": ["name": ["type": "string"]]
        ]
        let format = OutputFormat(jsonSchema: schema)
        XCTAssertNotNil(format)
    }

    /// AC5 [P0]: OutputFormat type field is "json_schema".
    func testOutputFormat_typeIsJsonSchema() {
        let schema: [String: Any] = ["type": "object"]
        let format = OutputFormat(jsonSchema: schema)
        XCTAssertEqual(format.type, "json_schema")
    }

    /// AC5 [P0]: OutputFormat stores the jsonSchema dictionary.
    func testOutputFormat_storesJsonSchema() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "age": ["type": "integer"]
            ]
        ]
        let format = OutputFormat(jsonSchema: schema)
        let retrieved = format.jsonSchema
        XCTAssertEqual(retrieved["type"] as? String, "object")
    }

    /// AC5 [P0]: OutputFormat conforms to Sendable.
    func testOutputFormat_sendable() {
        let schema: [String: Any] = ["type": "string"]
        let format = OutputFormat(jsonSchema: schema)
        let _: any Sendable = format
    }

    /// AC5 [P0]: SendableJSONSchema wrapper holds [String: Any].
    func testSendableJSONSchema_init() {
        let schema: [String: Any] = ["key": "value", "count": 42]
        let wrapper = SendableJSONSchema(schema: schema)
        XCTAssertNotNil(wrapper)
        XCTAssertEqual(wrapper.schema["key"] as? String, "value")
        XCTAssertEqual(wrapper.schema["count"] as? Int, 42)
    }

    /// AC5 [P0]: SendableJSONSchema conforms to Sendable.
    func testSendableJSONSchema_sendable() {
        let schema: [String: Any] = ["type": "object"]
        let wrapper = SendableJSONSchema(schema: schema)
        let _: any Sendable = wrapper
    }
}

// MARK: - AC6: ToolConfig Type

/// Tests for the new ToolConfig struct for tool behavior configuration.
final class ToolConfigATDDTests: XCTestCase {

    /// AC6 [P0]: ToolConfig can be constructed with default values (all nil).
    func testToolConfig_initDefaults() {
        let config = ToolConfig()
        XCTAssertNil(config.maxConcurrentReadTools)
        XCTAssertNil(config.maxConcurrentWriteTools)
    }

    /// AC6 [P0]: ToolConfig can be constructed with explicit values.
    func testToolConfig_initExplicit() {
        let config = ToolConfig(
            maxConcurrentReadTools: 5,
            maxConcurrentWriteTools: 2
        )
        XCTAssertEqual(config.maxConcurrentReadTools, 5)
        XCTAssertEqual(config.maxConcurrentWriteTools, 2)
    }

    /// AC6 [P0]: ToolConfig conforms to Sendable.
    func testToolConfig_sendable() {
        let config = ToolConfig(maxConcurrentReadTools: 3)
        let _: any Sendable = config
    }

    /// AC6 [P0]: ToolConfig conforms to Equatable.
    func testToolConfig_equatable() {
        let a = ToolConfig(maxConcurrentReadTools: 5, maxConcurrentWriteTools: 2)
        let b = ToolConfig(maxConcurrentReadTools: 5, maxConcurrentWriteTools: 2)
        let c = ToolConfig(maxConcurrentReadTools: 3)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// AC6 [P1]: ToolConfig supports partial configuration (only read tools).
    func testToolConfig_partialConfig() {
        let config = ToolConfig(maxConcurrentReadTools: 10)
        XCTAssertEqual(config.maxConcurrentReadTools, 10)
        XCTAssertNil(config.maxConcurrentWriteTools)
    }
}

// MARK: - AC7: SystemPromptConfig

/// Tests for the new SystemPromptConfig enum with .text and .preset cases.
final class SystemPromptConfigATDDTests: XCTestCase {

    /// AC7 [P0]: SystemPromptConfig has .text case wrapping a String.
    func testSystemPromptConfig_textCase() {
        let config = SystemPromptConfig.text("You are a helpful assistant.")
        if case let .text(value) = config {
            XCTAssertEqual(value, "You are a helpful assistant.")
        } else {
            XCTFail("Expected .text case")
        }
    }

    /// AC7 [P0]: SystemPromptConfig has .preset case with name and append.
    func testSystemPromptConfig_presetCase() {
        let config = SystemPromptConfig.preset(name: "claude_code", append: "Always be concise.")
        if case let .preset(name, append) = config {
            XCTAssertEqual(name, "claude_code")
            XCTAssertEqual(append, "Always be concise.")
        } else {
            XCTFail("Expected .preset case")
        }
    }

    /// AC7 [P0]: SystemPromptConfig.preset append parameter is optional.
    func testSystemPromptConfig_presetNilAppend() {
        let config = SystemPromptConfig.preset(name: "claude_code", append: nil)
        if case let .preset(name, append) = config {
            XCTAssertEqual(name, "claude_code")
            XCTAssertNil(append)
        } else {
            XCTFail("Expected .preset case")
        }
    }

    /// AC7 [P0]: SystemPromptConfig conforms to Sendable.
    func testSystemPromptConfig_sendable() {
        let textConfig: any Sendable = SystemPromptConfig.text("Hello")
        let presetConfig: any Sendable = SystemPromptConfig.preset(name: "claude_code", append: nil)
        _ = textConfig
        _ = presetConfig
    }

    /// AC7 [P0]: SystemPromptConfig conforms to Equatable.
    func testSystemPromptConfig_equatable() {
        let a = SystemPromptConfig.text("Hello")
        let b = SystemPromptConfig.text("Hello")
        let c = SystemPromptConfig.text("World")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// AC7 [P0]: SystemPromptConfig.preset equality works with name and append.
    func testSystemPromptConfig_presetEquality() {
        let a = SystemPromptConfig.preset(name: "claude_code", append: "extra")
        let b = SystemPromptConfig.preset(name: "claude_code", append: "extra")
        let c = SystemPromptConfig.preset(name: "claude_code", append: nil)
        let d = SystemPromptConfig.preset(name: "other", append: "extra")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
    }
}

// MARK: - AC1: Core Configuration Fields

/// Tests for new core configuration fields on AgentOptions.
final class CoreConfigFieldsATDDTests: XCTestCase {

    /// AC1 [P0]: AgentOptions has fallbackModel field (optional String).
    func testAgentOptions_fallbackModel_set() {
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            fallbackModel: "claude-haiku-4-5"
        )
        XCTAssertEqual(options.fallbackModel, "claude-haiku-4-5")
    }

    /// AC1 [P0]: AgentOptions fallbackModel defaults to nil.
    func testAgentOptions_fallbackModel_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.fallbackModel)
    }

    /// AC1 [P0]: AgentOptions has env field (optional [String: String]).
    func testAgentOptions_env_set() {
        let env: [String: String] = ["HOME": "/custom/home", "PATH": "/usr/bin"]
        let options = AgentOptions(
            apiKey: "sk-test",
            env: env
        )
        XCTAssertEqual(options.env?["HOME"], "/custom/home")
        XCTAssertEqual(options.env?["PATH"], "/usr/bin")
    }

    /// AC1 [P0]: AgentOptions env defaults to nil.
    func testAgentOptions_env_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.env)
    }

    /// AC1 [P0]: AgentOptions has allowedTools field (optional [String]).
    func testAgentOptions_allowedTools_set() {
        let options = AgentOptions(
            apiKey: "sk-test",
            allowedTools: ["Bash", "Read", "Write"]
        )
        XCTAssertEqual(options.allowedTools?.count, 3)
        XCTAssertTrue(options.allowedTools?.contains("Bash") == true)
    }

    /// AC1 [P0]: AgentOptions allowedTools defaults to nil.
    func testAgentOptions_allowedTools_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.allowedTools)
    }

    /// AC1 [P0]: AgentOptions has disallowedTools field (optional [String]).
    func testAgentOptions_disallowedTools_set() {
        let options = AgentOptions(
            apiKey: "sk-test",
            disallowedTools: ["Bash", "Write"]
        )
        XCTAssertEqual(options.disallowedTools?.count, 2)
        XCTAssertTrue(options.disallowedTools?.contains("Bash") == true)
    }

    /// AC1 [P0]: AgentOptions disallowedTools defaults to nil.
    func testAgentOptions_disallowedTools_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.disallowedTools)
    }

    /// AC1 [P0]: Both allowedTools and disallowedTools can be set simultaneously.
    func testAgentOptions_allowedAndDisallowedTools_bothSet() {
        let options = AgentOptions(
            apiKey: "sk-test",
            allowedTools: ["Bash", "Read", "Write", "Grep"],
            disallowedTools: ["Write"]
        )
        XCTAssertEqual(options.allowedTools?.count, 4)
        XCTAssertEqual(options.disallowedTools?.count, 1)
    }

    /// AC1 [P0]: Backward compatibility - existing init without new fields still compiles.
    func testAgentOptions_backwardCompat_existingInit() {
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are helpful",
            maxTurns: 20
        )
        XCTAssertEqual(options.apiKey, "sk-test")
        XCTAssertEqual(options.model, "claude-sonnet-4-6")
        XCTAssertNil(options.fallbackModel)
        XCTAssertNil(options.env)
        XCTAssertNil(options.allowedTools)
        XCTAssertNil(options.disallowedTools)
    }
}

// MARK: - AC2: Advanced Configuration Fields

/// Tests for new advanced configuration fields on AgentOptions.
final class AdvancedConfigFieldsATDDTests: XCTestCase {

    /// AC2 [P0]: AgentOptions has effort field (optional EffortLevel).
    func testAgentOptions_effort_set() {
        let options = AgentOptions(
            apiKey: "sk-test",
            effort: .high
        )
        XCTAssertEqual(options.effort, .high)
    }

    /// AC2 [P0]: AgentOptions effort defaults to nil.
    func testAgentOptions_effort_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.effort)
    }

    /// AC2 [P0]: AgentOptions has outputFormat field (optional OutputFormat).
    func testAgentOptions_outputFormat_set() {
        let schema: [String: Any] = ["type": "object", "properties": ["result": ["type": "string"]]]
        let format = OutputFormat(jsonSchema: schema)
        let options = AgentOptions(
            apiKey: "sk-test",
            outputFormat: format
        )
        XCTAssertNotNil(options.outputFormat)
        XCTAssertEqual(options.outputFormat?.type, "json_schema")
    }

    /// AC2 [P0]: AgentOptions outputFormat defaults to nil.
    func testAgentOptions_outputFormat_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.outputFormat)
    }

    /// AC2 [P0]: AgentOptions has toolConfig field (optional ToolConfig).
    func testAgentOptions_toolConfig_set() {
        let config = ToolConfig(maxConcurrentReadTools: 5, maxConcurrentWriteTools: 2)
        let options = AgentOptions(
            apiKey: "sk-test",
            toolConfig: config
        )
        XCTAssertNotNil(options.toolConfig)
        XCTAssertEqual(options.toolConfig?.maxConcurrentReadTools, 5)
        XCTAssertEqual(options.toolConfig?.maxConcurrentWriteTools, 2)
    }

    /// AC2 [P0]: AgentOptions toolConfig defaults to nil.
    func testAgentOptions_toolConfig_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.toolConfig)
    }

    /// AC2 [P0]: AgentOptions has includePartialMessages field (Bool, default true).
    func testAgentOptions_includePartialMessages_defaultTrue() {
        let options = AgentOptions()
        XCTAssertTrue(options.includePartialMessages, "includePartialMessages should default to true")
    }

    /// AC2 [P0]: AgentOptions includePartialMessages can be set to false.
    func testAgentOptions_includePartialMessages_setFalse() {
        let options = AgentOptions(
            apiKey: "sk-test",
            includePartialMessages: false
        )
        XCTAssertFalse(options.includePartialMessages)
    }

    /// AC2 [P0]: AgentOptions has promptSuggestions field (Bool, default false).
    func testAgentOptions_promptSuggestions_defaultFalse() {
        let options = AgentOptions()
        XCTAssertFalse(options.promptSuggestions, "promptSuggestions should default to false")
    }

    /// AC2 [P0]: AgentOptions promptSuggestions can be set to true.
    func testAgentOptions_promptSuggestions_setTrue() {
        let options = AgentOptions(
            apiKey: "sk-test",
            promptSuggestions: true
        )
        XCTAssertTrue(options.promptSuggestions)
    }
}

// MARK: - AC3: Session Configuration Fields

/// Tests for new session configuration fields on AgentOptions.
final class SessionConfigFieldsATDDTests: XCTestCase {

    /// AC3 [P0]: AgentOptions has continueRecentSession field (Bool, default false).
    func testAgentOptions_continueRecentSession_defaultFalse() {
        let options = AgentOptions()
        XCTAssertFalse(options.continueRecentSession, "continueRecentSession should default to false")
    }

    /// AC3 [P0]: AgentOptions continueRecentSession can be set to true.
    func testAgentOptions_continueRecentSession_setTrue() {
        let options = AgentOptions(
            apiKey: "sk-test",
            continueRecentSession: true
        )
        XCTAssertTrue(options.continueRecentSession)
    }

    /// AC3 [P0]: AgentOptions has forkSession field (Bool, default false).
    func testAgentOptions_forkSession_defaultFalse() {
        let options = AgentOptions()
        XCTAssertFalse(options.forkSession, "forkSession should default to false")
    }

    /// AC3 [P0]: AgentOptions forkSession can be set to true.
    func testAgentOptions_forkSession_setTrue() {
        let options = AgentOptions(
            apiKey: "sk-test",
            forkSession: true
        )
        XCTAssertTrue(options.forkSession)
    }

    /// AC3 [P0]: AgentOptions has resumeSessionAt field (optional String).
    func testAgentOptions_resumeSessionAt_set() {
        let options = AgentOptions(
            apiKey: "sk-test",
            resumeSessionAt: "msg-uuid-001"
        )
        XCTAssertEqual(options.resumeSessionAt, "msg-uuid-001")
    }

    /// AC3 [P0]: AgentOptions resumeSessionAt defaults to nil.
    func testAgentOptions_resumeSessionAt_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.resumeSessionAt)
    }

    /// AC3 [P0]: AgentOptions has persistSession field (Bool, default true).
    func testAgentOptions_persistSession_defaultTrue() {
        let options = AgentOptions()
        XCTAssertTrue(options.persistSession, "persistSession should default to true")
    }

    /// AC3 [P0]: AgentOptions persistSession can be set to false.
    func testAgentOptions_persistSession_setFalse() {
        let options = AgentOptions(
            apiKey: "sk-test",
            persistSession: false
        )
        XCTAssertFalse(options.persistSession)
    }

    /// AC3 [P0]: Session fields integrate with existing sessionStore and sessionId.
    func testAgentOptions_sessionFields_withExistingSessionConfig() {
        let options = AgentOptions(
            apiKey: "sk-test",
            sessionId: "existing-session",
            continueRecentSession: true,
            persistSession: false
        )
        XCTAssertEqual(options.sessionId, "existing-session")
        XCTAssertTrue(options.continueRecentSession)
        XCTAssertFalse(options.persistSession)
    }
}

// MARK: - AC7: systemPromptConfig on AgentOptions

/// Tests for systemPromptConfig field on AgentOptions alongside existing systemPrompt.
final class SystemPromptConfigOnOptionsATDDTests: XCTestCase {

    /// AC7 [P0]: AgentOptions has systemPromptConfig field (optional SystemPromptConfig).
    func testAgentOptions_systemPromptConfig_set() {
        let options = AgentOptions(
            apiKey: "sk-test",
            systemPromptConfig: .preset(name: "claude_code", append: nil)
        )
        XCTAssertNotNil(options.systemPromptConfig)
        if case let .preset(name, _) = options.systemPromptConfig {
            XCTAssertEqual(name, "claude_code")
        } else {
            XCTFail("Expected .preset case")
        }
    }

    /// AC7 [P0]: AgentOptions systemPromptConfig defaults to nil.
    func testAgentOptions_systemPromptConfig_defaultNil() {
        let options = AgentOptions()
        XCTAssertNil(options.systemPromptConfig)
    }

    /// AC7 [P0]: systemPromptConfig coexists with systemPrompt (systemPromptConfig takes priority).
    func testAgentOptions_systemPromptConfig_coexistsWithSystemPrompt() {
        let options = AgentOptions(
            apiKey: "sk-test",
            systemPrompt: "Old prompt",
            systemPromptConfig: .text("New config prompt")
        )
        XCTAssertEqual(options.systemPrompt, "Old prompt")
        XCTAssertNotNil(options.systemPromptConfig)
    }

    /// AC7 [P0]: systemPrompt can still be used alone (backward compatibility).
    func testAgentOptions_systemPrompt_backwardCompat() {
        let options = AgentOptions(
            apiKey: "sk-test",
            systemPrompt: "Just a string prompt"
        )
        XCTAssertEqual(options.systemPrompt, "Just a string prompt")
        XCTAssertNil(options.systemPromptConfig)
    }
}

// MARK: - AC1 & AC7: init(from:) Config-Based Init

/// Tests that the config-based init sets proper defaults for all new fields.
final class ConfigBasedInitATDDTests: XCTestCase {

    /// AC1/AC2/AC3/AC7 [P0]: init(from:) sets all new fields to their defaults.
    func testInitFromConfig_newFieldsDefaultValues() {
        let config = SDKConfiguration(
            apiKey: "config-key",
            model: "claude-sonnet-4-6"
        )
        let options = AgentOptions(from: config)

        // AC1: Core config fields default to nil
        XCTAssertNil(options.fallbackModel)
        XCTAssertNil(options.env)
        XCTAssertNil(options.allowedTools)
        XCTAssertNil(options.disallowedTools)

        // AC2: Advanced config fields default to nil
        XCTAssertNil(options.effort)
        XCTAssertNil(options.outputFormat)
        XCTAssertNil(options.toolConfig)
        XCTAssertTrue(options.includePartialMessages)
        XCTAssertFalse(options.promptSuggestions)

        // AC3: Session config fields have appropriate defaults
        XCTAssertFalse(options.continueRecentSession)
        XCTAssertFalse(options.forkSession)
        XCTAssertNil(options.resumeSessionAt)
        XCTAssertTrue(options.persistSession)

        // AC7: systemPromptConfig defaults to nil
        XCTAssertNil(options.systemPromptConfig)
    }

    /// AC1 [P0]: init(from:) preserves existing config values.
    func testInitFromConfig_preservesExistingFields() {
        let config = SDKConfiguration(
            apiKey: "config-key",
            model: "claude-haiku-4-5",
            maxTurns: 15,
            maxTokens: 8192
        )
        let options = AgentOptions(from: config)
        XCTAssertEqual(options.apiKey, "config-key")
        XCTAssertEqual(options.model, "claude-haiku-4-5")
        XCTAssertEqual(options.maxTurns, 15)
        XCTAssertEqual(options.maxTokens, 8192)
    }
}

// MARK: - AC8: Sendable Conformance for All New Types

/// Verifies that all new types and enhanced AgentOptions conform to Sendable.
final class AgentOptionsSendableATDDTests: XCTestCase {

    /// AC8 [P0]: EffortLevel conforms to Sendable.
    func testEffortLevel_isSendable() {
        let _: any Sendable = EffortLevel.high
    }

    /// AC8 [P0]: OutputFormat conforms to Sendable.
    func testOutputFormat_isSendable() {
        let format = OutputFormat(jsonSchema: ["type": "object"])
        let _: any Sendable = format
    }

    /// AC8 [P0]: SendableJSONSchema conforms to Sendable.
    func testSendableJSONSchema_isSendable() {
        let schema = SendableJSONSchema(schema: ["type": "string"])
        let _: any Sendable = schema
    }

    /// AC8 [P0]: ToolConfig conforms to Sendable.
    func testToolConfig_isSendable() {
        let config = ToolConfig(maxConcurrentReadTools: 5)
        let _: any Sendable = config
    }

    /// AC8 [P0]: SystemPromptConfig conforms to Sendable.
    func testSystemPromptConfig_isSendable() {
        let textConfig: any Sendable = SystemPromptConfig.text("Hello")
        let presetConfig: any Sendable = SystemPromptConfig.preset(name: "claude_code", append: nil)
        _ = textConfig
        _ = presetConfig
    }

    /// AC8 [P0]: AgentOptions with all new fields is still Sendable.
    func testAgentOptions_withNewFields_isSendable() {
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            fallbackModel: "claude-haiku-4-5",
            env: ["KEY": "VALUE"],
            allowedTools: ["Bash"],
            disallowedTools: ["Write"],
            effort: .high,
            includePartialMessages: true,
            promptSuggestions: false,
            continueRecentSession: false,
            forkSession: false,
            persistSession: true,
            systemPromptConfig: .text("Hello")
        )
        let _: any Sendable = options
    }
}

// MARK: - AC8: Backward Compatibility & Zero Regression

/// Verifies that all existing AgentOptions usage patterns still work after enhancement.
final class BackwardCompatATDDTests: XCTestCase {

    /// AC8 [P0]: Default init still works with no parameters.
    func testDefaultInit_noParameters() {
        let options = AgentOptions()
        XCTAssertEqual(options.model, "claude-sonnet-4-6")
        XCTAssertEqual(options.maxTurns, 10)
        XCTAssertEqual(options.maxTokens, 16384)
        XCTAssertEqual(options.provider, .anthropic)
        XCTAssertEqual(options.permissionMode, .default)
    }

    /// AC8 [P0]: Existing parameterized init still works.
    func testExistingParameterizedInit() {
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-opus-4-6",
            baseURL: "http://localhost:8080",
            provider: .openai,
            systemPrompt: "You are helpful",
            maxTurns: 20,
            maxTokens: 4096,
            maxBudgetUsd: 5.0,
            thinking: .enabled(budgetTokens: 10000),
            permissionMode: .auto,
            cwd: "/home/user"
        )
        XCTAssertEqual(options.apiKey, "sk-test")
        XCTAssertEqual(options.model, "claude-opus-4-6")
        XCTAssertEqual(options.baseURL, "http://localhost:8080")
        XCTAssertEqual(options.provider, .openai)
        XCTAssertEqual(options.systemPrompt, "You are helpful")
        XCTAssertEqual(options.maxTurns, 20)
        XCTAssertEqual(options.maxTokens, 4096)
    }

    /// AC8 [P0]: All existing fields remain accessible.
    func testExistingFieldsAccessible() {
        let options = AgentOptions()
        // Verify all original 38 fields are still accessible
        _ = options.apiKey
        _ = options.model
        _ = options.baseURL
        _ = options.provider
        _ = options.systemPrompt
        _ = options.maxTurns
        _ = options.maxTokens
        _ = options.maxBudgetUsd
        _ = options.thinking
        _ = options.permissionMode
        _ = options.canUseTool
        _ = options.cwd
        _ = options.tools
        _ = options.mcpServers
        _ = options.retryConfig
        _ = options.agentName
        _ = options.mailboxStore
        _ = options.teamStore
        _ = options.taskStore
        _ = options.worktreeStore
        _ = options.planStore
        _ = options.cronStore
        _ = options.todoStore
        _ = options.sessionStore
        _ = options.sessionId
        _ = options.hookRegistry
        _ = options.skillRegistry
        _ = options.skillDirectories
        _ = options.skillNames
        _ = options.maxSkillRecursionDepth
        _ = options.fileCacheMaxEntries
        _ = options.fileCacheMaxSizeBytes
        _ = options.fileCacheMaxEntrySizeBytes
        _ = options.gitCacheTTL
        _ = options.projectRoot
        _ = options.logLevel
        _ = options.logOutput
        _ = options.sandbox
    }

    /// AC8 [P0]: Validation still works for existing checks.
    func testValidation_existingChecksStillWork() {
        let validOptions = AgentOptions(apiKey: "sk-test")
        XCTAssertNoThrow(try validOptions.validate())

        let invalidURL = AgentOptions(apiKey: "sk-test", baseURL: "http://[invalid")
        XCTAssertThrowsError(try invalidURL.validate())
    }
}

// MARK: - Integration: All New Fields Together

/// Tests that all new fields can be used simultaneously in a realistic configuration.
final class AllFieldsIntegrationATDDTests: XCTestCase {

    /// Integration [P0]: AgentOptions can be created with all new fields simultaneously.
    func testAllNewFields_together() {
        let schema: [String: Any] = ["type": "object", "properties": ["answer": ["type": "string"]]]
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            fallbackModel: "claude-haiku-4-5",
            env: ["API_ENV": "production"],
            allowedTools: ["Bash", "Read", "Write"],
            disallowedTools: ["Write"],
            effort: .high,
            outputFormat: OutputFormat(jsonSchema: schema),
            toolConfig: ToolConfig(maxConcurrentReadTools: 10, maxConcurrentWriteTools: 3),
            includePartialMessages: false,
            promptSuggestions: true,
            continueRecentSession: false,
            forkSession: true,
            resumeSessionAt: nil,
            persistSession: false,
            systemPromptConfig: .preset(name: "claude_code", append: "Be thorough.")
        )

        // Verify all fields
        XCTAssertEqual(options.fallbackModel, "claude-haiku-4-5")
        XCTAssertEqual(options.env?["API_ENV"], "production")
        XCTAssertEqual(options.allowedTools?.count, 3)
        XCTAssertEqual(options.disallowedTools?.count, 1)
        XCTAssertEqual(options.effort, .high)
        XCTAssertNotNil(options.outputFormat)
        XCTAssertNotNil(options.toolConfig)
        XCTAssertFalse(options.includePartialMessages)
        XCTAssertTrue(options.promptSuggestions)
        XCTAssertFalse(options.continueRecentSession)
        XCTAssertTrue(options.forkSession)
        XCTAssertNil(options.resumeSessionAt)
        XCTAssertFalse(options.persistSession)
        XCTAssertNotNil(options.systemPromptConfig)
    }

    /// Integration [P1]: Mix of old and new fields works correctly.
    func testMixedOldAndNewFields() {
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-opus-4-6",
            systemPrompt: "You are a code assistant.",
            maxTurns: 50,
            thinking: .enabled(budgetTokens: 20000),
            permissionMode: .auto,
            fallbackModel: "claude-sonnet-4-6",
            effort: .max,
            includePartialMessages: true,
            promptSuggestions: true,
            persistSession: true
        )

        XCTAssertEqual(options.model, "claude-opus-4-6")
        XCTAssertEqual(options.maxTurns, 50)
        XCTAssertEqual(options.thinking, .enabled(budgetTokens: 20000))
        XCTAssertEqual(options.fallbackModel, "claude-sonnet-4-6")
        XCTAssertEqual(options.effort, .max)
        XCTAssertTrue(options.includePartialMessages)
        XCTAssertTrue(options.promptSuggestions)
        XCTAssertTrue(options.persistSession)
    }
}
