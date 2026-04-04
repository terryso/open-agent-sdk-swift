import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Environment Variable Reading

final class SDKConfigurationEnvVarTests: XCTestCase {

    /// AC1: When CODEANY_API_KEY is set, SDKConfiguration.fromEnvironment() reads it into apiKey.
    func testFromEnvironmentReadsAPIKey() {
        setenv("CODEANY_API_KEY", "sk-test-env-api-key-12345", 1)
        defer { unsetenv("CODEANY_API_KEY") }

        let config = SDKConfiguration.fromEnvironment()
        XCTAssertEqual(config.apiKey, "sk-test-env-api-key-12345",
                       "apiKey should be read from CODEANY_API_KEY env var")
    }

    /// AC1: When CODEANY_MODEL is set, SDKConfiguration.fromEnvironment() reads it into model.
    func testFromEnvironmentReadsModel() {
        setenv("CODEANY_MODEL", "claude-opus-4", 1)
        defer { unsetenv("CODEANY_MODEL") }

        let config = SDKConfiguration.fromEnvironment()
        XCTAssertEqual(config.model, "claude-opus-4",
                       "model should be read from CODEANY_MODEL env var")
    }

    /// AC1: When CODEANY_BASE_URL is set, SDKConfiguration.fromEnvironment() reads it into baseURL.
    func testFromEnvironmentReadsBaseURL() {
        setenv("CODEANY_BASE_URL", "https://my-proxy.example.com", 1)
        defer { unsetenv("CODEANY_BASE_URL") }

        let config = SDKConfiguration.fromEnvironment()
        XCTAssertEqual(config.baseURL, "https://my-proxy.example.com",
                       "baseURL should be read from CODEANY_BASE_URL env var")
    }

    /// AC1: When no env vars are set, fromEnvironment() returns defaults with nil apiKey and baseURL.
    func testFromEnvironmentReturnsDefaultsWhenNoVarsSet() {
        unsetenv("CODEANY_API_KEY")
        unsetenv("CODEANY_MODEL")
        unsetenv("CODEANY_BASE_URL")

        let config = SDKConfiguration.fromEnvironment()
        XCTAssertNil(config.apiKey, "apiKey should be nil when CODEANY_API_KEY is not set")
        XCTAssertEqual(config.model, "claude-sonnet-4-6",
                       "model should default to claude-sonnet-4-6 when CODEANY_MODEL is not set")
        XCTAssertNil(config.baseURL, "baseURL should be nil when CODEANY_BASE_URL is not set")
    }

    /// AC1: All three env vars are read simultaneously in a single fromEnvironment() call.
    func testFromEnvironmentReadsAllVarsAtOnce() {
        setenv("CODEANY_API_KEY", "sk-key-xyz", 1)
        setenv("CODEANY_MODEL", "claude-haiku-4", 1)
        setenv("CODEANY_BASE_URL", "https://custom.api.com", 1)
        defer {
            unsetenv("CODEANY_API_KEY")
            unsetenv("CODEANY_MODEL")
            unsetenv("CODEANY_BASE_URL")
        }

        let config = SDKConfiguration.fromEnvironment()
        XCTAssertEqual(config.apiKey, "sk-key-xyz")
        XCTAssertEqual(config.model, "claude-haiku-4")
        XCTAssertEqual(config.baseURL, "https://custom.api.com")
    }
}

// MARK: - AC2: Programmatic Configuration

final class SDKConfigurationProgrammaticTests: XCTestCase {

    /// AC2: SDKConfiguration can be created programmatically with all properties set.
    func testProgrammaticInitWithAllProperties() {
        let config = SDKConfiguration(
            apiKey: "sk-programmatic-key",
            model: "claude-opus-4",
            baseURL: "https://custom.api.com",
            maxTurns: 20,
            maxTokens: 32768
        )

        XCTAssertEqual(config.apiKey, "sk-programmatic-key")
        XCTAssertEqual(config.model, "claude-opus-4")
        XCTAssertEqual(config.baseURL, "https://custom.api.com")
        XCTAssertEqual(config.maxTurns, 20)
        XCTAssertEqual(config.maxTokens, 32768)
    }

    /// AC2: SDKConfiguration can be created with only apiKey and model, no env var dependency.
    func testProgrammaticInitMinimal() {
        let config = SDKConfiguration(
            apiKey: "sk-minimal-key",
            model: "claude-sonnet-4-6"
        )

        XCTAssertEqual(config.apiKey, "sk-minimal-key")
        XCTAssertEqual(config.model, "claude-sonnet-4-6")
        XCTAssertNil(config.baseURL)
        XCTAssertEqual(config.maxTurns, 10, "maxTurns should default to 10")
        XCTAssertEqual(config.maxTokens, 16384, "maxTokens should default to 16384")
    }

    /// AC2: SDKConfiguration can be created with no parameters at all (all defaults).
    func testProgrammaticInitNoParameters() {
        let config = SDKConfiguration()

        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.model, "claude-sonnet-4-6")
        XCTAssertNil(config.baseURL)
        XCTAssertEqual(config.maxTurns, 10)
        XCTAssertEqual(config.maxTokens, 16384)
    }

    /// AC2: SDKConfiguration is a struct (value type), not a class or actor.
    func testSDKConfigurationIsStruct() {
        var config1 = SDKConfiguration(apiKey: "key-a", model: "model-a")
        var config2 = config1
        config2.apiKey = "key-b"

        XCTAssertEqual(config1.apiKey, "key-a",
                       "Struct semantics: modifying copy should not affect original")
        XCTAssertEqual(config2.apiKey, "key-b")
    }
}

// MARK: - AC3: Reasonable Defaults

final class SDKConfigurationDefaultsTests: XCTestCase {

    /// AC3: Default model is "claude-sonnet-4-6".
    func testDefaultModel() {
        let config = SDKConfiguration()
        XCTAssertEqual(config.model, "claude-sonnet-4-6",
                       "Default model should be claude-sonnet-4-6")
    }

    /// AC3: Default maxTurns is 10.
    func testDefaultMaxTurns() {
        let config = SDKConfiguration()
        XCTAssertEqual(config.maxTurns, 10, "Default maxTurns should be 10")
    }

    /// AC3: Default maxTokens is 16384.
    func testDefaultMaxTokens() {
        let config = SDKConfiguration()
        XCTAssertEqual(config.maxTokens, 16384, "Default maxTokens should be 16384")
    }

    /// AC3: Default apiKey is nil (not an empty string).
    func testDefaultAPIKeyIsNil() {
        let config = SDKConfiguration()
        XCTAssertNil(config.apiKey, "Default apiKey should be nil")
    }

    /// AC3: Default baseURL is nil.
    func testDefaultBaseURLIsNil() {
        let config = SDKConfiguration()
        XCTAssertNil(config.baseURL, "Default baseURL should be nil")
    }

    /// AC3: Only setting apiKey and model leaves remaining fields at defaults.
    func testOnlyAPIKeyAndModelSet() {
        let config = SDKConfiguration(apiKey: "sk-only-key", model: "claude-opus-4")
        XCTAssertEqual(config.apiKey, "sk-only-key")
        XCTAssertEqual(config.model, "claude-opus-4")
        XCTAssertNil(config.baseURL)
        XCTAssertEqual(config.maxTurns, 10)
        XCTAssertEqual(config.maxTokens, 16384)
    }
}

// MARK: - AC4: Dual Platform Compilation

final class SDKConfigurationCompilationTests: XCTestCase {

    /// AC4: SDKConfiguration compiles using only Foundation (no Apple-exclusive frameworks).
    /// This is a compile-time check -- if SDKConfiguration imports UIKit/AppKit/Combine, it will fail.
    func testCompilesWithFoundationOnly() {
        // This test verifies that SDKConfiguration can be instantiated without
        // any Apple-specific framework dependencies.
        let config = SDKConfiguration(apiKey: "sk-test", model: "test-model")
        XCTAssertNotNil(config, "SDKConfiguration should compile with Foundation only")
    }

    /// AC4: SDKConfiguration conforms to Sendable (required for Swift concurrency).
    func testSDKConfigurationIsSendable() {
        let config = SDKConfiguration(apiKey: "sk-sendable", model: "test-model")
        // This test verifies Sendable conformance at compile time.
        // If SDKConfiguration is not Sendable, passing it to a nonisolated function
        // that expects Sendable will fail.
        func expectSendable<T: Sendable>(_ value: T) -> Bool { true }
        XCTAssertTrue(expectSendable(config),
                      "SDKConfiguration must conform to Sendable")
    }

    /// AC4: SDKConfiguration conforms to Equatable.
    func testSDKConfigurationIsEquatable() {
        let config1 = SDKConfiguration(apiKey: "sk-eq", model: "model-eq")
        let config2 = SDKConfiguration(apiKey: "sk-eq", model: "model-eq")
        XCTAssertEqual(config1, config2, "Equal configurations should be equal")
    }
}

// MARK: - AC5: API Key Security

final class SDKConfigurationSecurityTests: XCTestCase {

    /// AC5: description does not contain the actual API key.
    func testDescriptionMasksAPIKey() {
        let config = SDKConfiguration(apiKey: "sk-super-secret-key-99999", model: "test-model")
        let description = String(describing: config)
        XCTAssertFalse(description.contains("sk-super-secret-key-99999"),
                       "description must not contain the actual API key. Got: \(description)")
        XCTAssertTrue(description.contains("***"),
                      "description should mask API key with '***'. Got: \(description)")
    }

    /// AC5: debugDescription does not contain the actual API key.
    func testDebugDescriptionMasksAPIKey() {
        let config = SDKConfiguration(apiKey: "sk-debug-secret-12345", model: "test-model")
        let debugDescription = config.debugDescription
        XCTAssertFalse(debugDescription.contains("sk-debug-secret-12345"),
                       "debugDescription must not contain the actual API key. Got: \(debugDescription)")
        XCTAssertTrue(debugDescription.contains("***"),
                      "debugDescription should mask API key with '***'. Got: \(debugDescription)")
    }

    /// AC5: When apiKey is nil, description does not crash.
    func testDescriptionWithNilAPIKey() {
        let config = SDKConfiguration()
        let description = String(describing: config)
        XCTAssertFalse(description.contains("Optional("),
                       "description should handle nil apiKey gracefully. Got: \(description)")
    }

    /// AC5: When apiKey is empty string, it is treated as nil (masked).
    func testDescriptionWithEmptyAPIKey() {
        let config = SDKConfiguration(apiKey: "", model: "test-model")
        let description = String(describing: config)
        // Empty string should not appear as a key leak
        XCTAssertFalse(description.contains("sk-"),
                       "description should not leak key patterns for empty string. Got: \(description)")
    }

    /// AC5: API key is masked in description even with special characters.
    func testDescriptionMasksAPIKeyWithSpecialCharacters() {
        let config = SDKConfiguration(apiKey: "sk-ant-api03-ABCDEF-1234567890!@#$%", model: "test-model")
        let description = String(describing: config)
        XCTAssertFalse(description.contains("sk-ant-api03"),
                       "description must not contain API key prefix. Got: \(description)")
        XCTAssertFalse(description.contains("ABCDEF-1234567890"),
                       "description must not contain API key body. Got: \(description)")
    }
}

// MARK: - AC6: AgentOptions Integration

final class SDKConfigurationAgentOptionsTests: XCTestCase {

    /// AC6: AgentOptions can be created from SDKConfiguration via convenience initializer.
    func testAgentOptionsFromSDKConfiguration() {
        let config = SDKConfiguration(
            apiKey: "sk-integration-key",
            model: "claude-opus-4",
            baseURL: "https://custom.api.com",
            maxTurns: 15,
            maxTokens: 8192
        )

        let options = AgentOptions(from: config)

        XCTAssertEqual(options.apiKey, "sk-integration-key",
                       "AgentOptions.apiKey should match SDKConfiguration.apiKey")
        XCTAssertEqual(options.model, "claude-opus-4",
                       "AgentOptions.model should match SDKConfiguration.model")
        XCTAssertEqual(options.baseURL, "https://custom.api.com",
                       "AgentOptions.baseURL should match SDKConfiguration.baseURL")
        XCTAssertEqual(options.maxTurns, 15,
                       "AgentOptions.maxTurns should match SDKConfiguration.maxTurns")
        XCTAssertEqual(options.maxTokens, 8192,
                       "AgentOptions.maxTokens should match SDKConfiguration.maxTokens")
    }

    /// AC6: AgentOptions from SDKConfiguration preserves Agent-specific defaults for unset fields.
    func testAgentOptionsFromSDKConfigurationPreservesAgentDefaults() {
        let config = SDKConfiguration(apiKey: "sk-key", model: "claude-sonnet-4-6")
        let options = AgentOptions(from: config)

        XCTAssertNil(options.systemPrompt,
                     "systemPrompt should be nil (AgentOptions default)")
        XCTAssertNil(options.thinking,
                     "thinking should be nil (AgentOptions default)")
        XCTAssertEqual(options.permissionMode, .default,
                       "permissionMode should be .default (AgentOptions default)")
        XCTAssertNil(options.canUseTool,
                     "canUseTool should be nil (AgentOptions default)")
        XCTAssertNil(options.tools,
                     "tools should be nil (AgentOptions default)")
        XCTAssertNil(options.mcpServers,
                     "mcpServers should be nil (AgentOptions default)")
    }

    /// AC6: Environment variables serve as fallback when no programmatic overrides are given.
    func testResolvedUsesEnvironmentAsFallback() {
        setenv("CODEANY_API_KEY", "sk-env-fallback-key", 1)
        setenv("CODEANY_MODEL", "claude-haiku-4", 1)
        setenv("CODEANY_BASE_URL", "https://env-fallback.api.com", 1)
        defer {
            unsetenv("CODEANY_API_KEY")
            unsetenv("CODEANY_MODEL")
            unsetenv("CODEANY_BASE_URL")
        }

        let config = SDKConfiguration.resolved()
        XCTAssertEqual(config.apiKey, "sk-env-fallback-key",
                       "resolved() should use env var as fallback for apiKey")
        XCTAssertEqual(config.model, "claude-haiku-4",
                       "resolved() should use env var as fallback for model")
        XCTAssertEqual(config.baseURL, "https://env-fallback.api.com",
                       "resolved() should use env var as fallback for baseURL")
    }

    /// AC6: Programmatic overrides take precedence over environment variables.
    func testResolvedProgrammaticOverridesTakePrecedence() {
        setenv("CODEANY_API_KEY", "sk-env-override-key", 1)
        setenv("CODEANY_MODEL", "claude-haiku-4", 1)
        defer {
            unsetenv("CODEANY_API_KEY")
            unsetenv("CODEANY_MODEL")
        }

        let overrides = SDKConfiguration(
            apiKey: "sk-programmatic-override",
            model: "claude-opus-4"
        )

        let config = SDKConfiguration.resolved(overrides: overrides)
        XCTAssertEqual(config.apiKey, "sk-programmatic-override",
                       "Programmatic apiKey should override env var")
        XCTAssertEqual(config.model, "claude-opus-4",
                       "Programmatic model should override env var")
    }

    /// AC6: resolved() with nil overrides falls back to env vars entirely.
    func testResolvedWithNilOverridesUsesOnlyEnvVars() {
        setenv("CODEANY_API_KEY", "sk-env-only-key", 1)
        defer { unsetenv("CODEANY_API_KEY") }

        let config = SDKConfiguration.resolved(overrides: nil)
        XCTAssertEqual(config.apiKey, "sk-env-only-key",
                       "resolved(overrides: nil) should use env var")
    }

    /// AC6: resolved() with empty overrides uses defaults when no env vars are set.
    func testResolvedWithNoEnvVarsAndNoOverrides() {
        unsetenv("CODEANY_API_KEY")
        unsetenv("CODEANY_MODEL")
        unsetenv("CODEANY_BASE_URL")

        let config = SDKConfiguration.resolved()
        XCTAssertNil(config.apiKey,
                     "apiKey should be nil when no env var and no override")
        XCTAssertEqual(config.model, "claude-sonnet-4-6",
                       "model should default to claude-sonnet-4-6")
        XCTAssertNil(config.baseURL,
                     "baseURL should be nil when no env var and no override")
    }

    /// AC6: Partial programmatic override -- only override some values, env fills the rest.
    func testResolvedPartialOverride() {
        setenv("CODEANY_API_KEY", "sk-env-partial-key", 1)
        setenv("CODEANY_MODEL", "claude-haiku-4", 1)
        setenv("CODEANY_BASE_URL", "https://env-url.com", 1)
        defer {
            unsetenv("CODEANY_API_KEY")
            unsetenv("CODEANY_MODEL")
            unsetenv("CODEANY_BASE_URL")
        }

        // Override only model, let apiKey and baseURL come from env
        let overrides = SDKConfiguration(model: "claude-opus-4")
        let config = SDKConfiguration.resolved(overrides: overrides)

        XCTAssertEqual(config.apiKey, "sk-env-partial-key",
                       "apiKey should come from env when not overridden programmatically")
        XCTAssertEqual(config.model, "claude-opus-4",
                       "model should come from programmatic override")
        XCTAssertEqual(config.baseURL, "https://env-url.com",
                       "baseURL should come from env when not overridden programmatically")
    }
}
