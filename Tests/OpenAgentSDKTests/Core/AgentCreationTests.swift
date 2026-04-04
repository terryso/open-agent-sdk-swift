import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: createAgent Factory Function

/// ATDD RED PHASE: Tests for Story 1.4 — Agent Creation and Configuration.
/// All tests assert EXPECTED behavior. They will FAIL until Agent.swift is implemented.
/// TDD Phase: RED (feature not implemented yet)
final class AgentCreationFactoryTests: XCTestCase {

    // MARK: - AC1: createAgent with valid AgentOptions returns configured Agent

    /// AC1: Given valid AgentOptions with system prompt, model, and maxTurns,
    /// when createAgent(options:) is called, then an Agent instance is returned (FR1).
    func testCreateAgentWithValidOptionsReturnsAgent() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-opus-4",
            systemPrompt: "You are a helpful assistant.",
            maxTurns: 5
        )

        let agent = createAgent(options: options)

        XCTAssertNotNil(agent, "createAgent should return a non-nil Agent instance")
    }

    /// AC1: Agent returned by createAgent has the specified model.
    func testCreateAgentHasSpecifiedModel() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-opus-4",
            systemPrompt: "Custom prompt"
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.model, "claude-opus-4",
                       "Agent model should match the specified model")
    }

    /// AC1: Agent returned by createAgent has the specified system prompt.
    func testCreateAgentHasSpecifiedSystemPrompt() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are a code reviewer."
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.systemPrompt, "You are a code reviewer.",
                       "Agent systemPrompt should match the specified system prompt")
    }

    /// AC1: Agent returned by createAgent has the specified maxTurns.
    func testCreateAgentHasSpecifiedMaxTurns() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-sonnet-4-6",
            maxTurns: 25
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.maxTurns, 25,
                       "Agent maxTurns should match the specified maxTurns")
    }

    /// AC1: Agent returned by createAgent has the specified maxTokens.
    func testCreateAgentHasSpecifiedMaxTokens() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-sonnet-4-6",
            maxTokens: 8192
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.maxTokens, 8192,
                       "Agent maxTokens should match the specified maxTokens")
    }
}

// MARK: - AC2: Default Values Applied

/// AC2: When an Agent is created with default options, default values are applied.
final class AgentCreationDefaultsTests: XCTestCase {

    /// AC2: Default model is "claude-sonnet-4-6".
    func testDefaultModelIsClaudeSonnet() async throws {
        let agent = createAgent(options: AgentOptions(apiKey: "sk-test"))

        XCTAssertEqual(agent.model, "claude-sonnet-4-6",
                       "Default model should be claude-sonnet-4-6")
    }

    /// AC2: Default maxTurns is 10.
    func testDefaultMaxTurns() async throws {
        let agent = createAgent(options: AgentOptions(apiKey: "sk-test"))

        XCTAssertEqual(agent.maxTurns, 10,
                       "Default maxTurns should be 10")
    }

    /// AC2: Default maxTokens is 16384.
    func testDefaultMaxTokens() async throws {
        let agent = createAgent(options: AgentOptions(apiKey: "sk-test"))

        XCTAssertEqual(agent.maxTokens, 16384,
                       "Default maxTokens should be 16384")
    }

    /// AC2: Default systemPrompt is nil when not provided.
    func testDefaultSystemPromptIsNil() async throws {
        let agent = createAgent(options: AgentOptions(apiKey: "sk-test"))

        XCTAssertNil(agent.systemPrompt,
                     "Default systemPrompt should be nil")
    }
}

// MARK: - AC3: System Prompt Integration

/// AC3: When an Agent has a custom system prompt, it is available for API request construction.
final class AgentSystemPromptTests: XCTestCase {

    /// AC3: Agent stores the system prompt and exposes it as a read-only property.
    func testAgentStoresCustomSystemPrompt() async throws {
        let customPrompt = "You are an expert Swift developer. Follow clean code principles."
        let options = AgentOptions(
            apiKey: "sk-test-key",
            systemPrompt: customPrompt
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.systemPrompt, customPrompt,
                       "Agent should store and expose the custom system prompt")
    }

    /// AC3: Agent with nil system prompt exposes nil.
    func testAgentWithNilSystemPrompt() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            systemPrompt: nil
        )

        let agent = createAgent(options: options)

        XCTAssertNil(agent.systemPrompt,
                     "Agent with nil systemPrompt should expose nil")
    }

    /// AC3: Agent with empty string system prompt stores empty string.
    func testAgentWithEmptySystemPrompt() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            systemPrompt: ""
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.systemPrompt, "",
                       "Agent should store empty string system prompt as-is")
    }
}

// MARK: - AC4: AnthropicClient Integration

/// AC4: When AgentOptions includes an apiKey, Agent creates an internal AnthropicClient
/// using that apiKey and optional baseURL (AD3, FR41).
final class AgentAnthropicClientTests: XCTestCase {

    /// AC4: Agent can be created with an API key — AnthropicClient initialized internally.
    func testAgentCreatedWithAPIKey() async throws {
        let options = AgentOptions(
            apiKey: "sk-ant-test-key-12345",
            model: "claude-sonnet-4-6"
        )

        let agent = createAgent(options: options)

        XCTAssertNotNil(agent, "Agent should be created with API key")
    }

    /// AC4: Agent can be created with a custom baseURL for AnthropicClient (FR41).
    func testAgentCreatedWithCustomBaseURL() async throws {
        let options = AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-sonnet-4-6",
            baseURL: "https://my-proxy.example.com"
        )

        let agent = createAgent(options: options)

        XCTAssertNotNil(agent, "Agent should be created with custom baseURL")
    }

    /// AC4: Agent can be created without an API key (deferred to later prompt/stream call).
    func testAgentCreatedWithoutAPIKey() async throws {
        let options = AgentOptions(
            apiKey: nil,
            model: "claude-sonnet-4-6"
        )

        let agent = createAgent(options: options)

        XCTAssertNotNil(agent, "Agent should be creatable without API key (deferred)")
    }
}

// MARK: - AC5: SDKConfiguration Merge

/// AC5: When using SDKConfiguration.resolved(), AgentOptions gets merged values
/// and Agent uses them correctly (FR39 + FR40 merge scenario).
final class AgentSDKConfigMergeTests: XCTestCase {

    /// AC5: createAgent with nil options uses SDKConfiguration.resolved() defaults.
    func testCreateAgentWithNilOptionsUsesResolvedConfig() async throws {
        // Set env vars to verify they flow through
        setenv("CODEANY_API_KEY", "sk-env-merge-key", 1)
        setenv("CODEANY_MODEL", "claude-haiku-4", 1)
        defer {
            unsetenv("CODEANY_API_KEY")
            unsetenv("CODEANY_MODEL")
        }

        let agent = createAgent(options: nil)

        XCTAssertEqual(agent.model, "claude-haiku-4",
                       "Agent model should come from env var when options is nil")
    }

    /// AC5: Explicit AgentOptions override SDKConfiguration values.
    func testExplicitOptionsOverrideConfig() async throws {
        setenv("CODEANY_MODEL", "claude-haiku-4", 1)
        defer { unsetenv("CODEANY_MODEL") }

        let options = AgentOptions(
            apiKey: "sk-explicit-key",
            model: "claude-opus-4"
        )

        let agent = createAgent(options: options)

        XCTAssertEqual(agent.model, "claude-opus-4",
                       "Explicit model should override env var")
    }

    /// AC5: AgentOptions created from SDKConfiguration carries config values into Agent.
    func testAgentFromSDKConfigurationCarriesValues() async throws {
        let config = SDKConfiguration(
            apiKey: "sk-config-key",
            model: "claude-opus-4",
            maxTurns: 20,
            maxTokens: 4096
        )

        let options = AgentOptions(from: config)
        let agent = createAgent(options: options)

        XCTAssertEqual(agent.model, "claude-opus-4",
                       "Agent model should match SDKConfiguration model")
        XCTAssertEqual(agent.maxTurns, 20,
                       "Agent maxTurns should match SDKConfiguration maxTurns")
        XCTAssertEqual(agent.maxTokens, 4096,
                       "Agent maxTokens should match SDKConfiguration maxTokens")
    }
}

// MARK: - AC6: Agent Public API

/// AC6: Agent exposes model and systemPrompt as read-only properties.
/// API key is NOT directly accessible (NFR6).
final class AgentPublicAPITests: XCTestCase {

    /// AC6: Agent exposes a read-only model property.
    func testAgentExposesReadOnlyModelProperty() async throws {
        let options = AgentOptions(apiKey: "sk-test", model: "claude-opus-4")
        let agent = createAgent(options: options)

        XCTAssertEqual(agent.model, "claude-opus-4",
                       "Agent should expose model as read-only property")
    }

    /// AC6: Agent exposes a read-only systemPrompt property.
    func testAgentExposesReadOnlySystemPromptProperty() async throws {
        let options = AgentOptions(
            apiKey: "sk-test",
            systemPrompt: "Test prompt"
        )
        let agent = createAgent(options: options)

        XCTAssertEqual(agent.systemPrompt, "Test prompt",
                       "Agent should expose systemPrompt as read-only property")
    }

    /// AC6: API key is not directly accessible on Agent (NFR6).
    /// This test verifies the Agent type does not expose apiKey as a public property.
    func testAgentDoesNotExposeAPIKeyDirectly() async throws {
        let secretKey = "sk-ant-super-secret-99999"
        let options = AgentOptions(apiKey: secretKey, model: "claude-sonnet-4-6")
        let agent = createAgent(options: options)

        // Agent should not have a public apiKey property.
        // We verify indirectly: the agent exists, but there is no `agent.apiKey`.
        // This is a compile-time check — if Agent exposed apiKey publicly,
        // this test file would compile and we would add an explicit assertion.
        XCTAssertNotNil(agent, "Agent should be created")

        // Mirror the agent to check for leaked properties
        let mirror = Mirror(reflecting: agent)
        let propertyNames = mirror.children.map { $0.label ?? "" }

        // Public properties should include model and systemPrompt
        XCTAssertTrue(propertyNames.contains("model"),
                      "Agent should expose 'model' property")
        XCTAssertTrue(propertyNames.contains("systemPrompt"),
                      "Agent should expose 'systemPrompt' property")

        // apiKey should NOT be in public properties
        XCTAssertFalse(propertyNames.contains("apiKey"),
                       "Agent must NOT expose apiKey as a public property (NFR6)")
    }

    /// AC6: Agent description/debugDescription do not leak the API key.
    func testAgentDescriptionDoesNotLeakAPIKey() async throws {
        let secretKey = "sk-ant-secret-abcdef123456"
        let options = AgentOptions(apiKey: secretKey, model: "claude-sonnet-4-6")
        let agent = createAgent(options: options)

        let description = agent.description
        XCTAssertFalse(description.contains(secretKey),
                       "Agent description must not contain API key. Got: \(description)")
        XCTAssertFalse(description.contains("sk-ant-secret"),
                       "Agent description must not contain API key prefix. Got: \(description)")
    }

    /// AC6: Agent class is not an actor — it holds immutable configuration.
    func testAgentIsClassNotActor() async throws {
        let options = AgentOptions(apiKey: "sk-test")
        let agent = createAgent(options: options)

        // Agent should be a class (reference type), not an actor or struct
        let agentType = type(of: agent)
        let typeName = String(describing: agentType)

        XCTAssertTrue(typeName.contains("Agent"),
                      "Type name should contain 'Agent'. Got: \(typeName)")
        // Agent is a class, not an actor — verify it is a reference type
        let agent2 = agent
        XCTAssertTrue(agent === agent2,
                       "Agent should be a reference type (class), not a value type (struct)")
    }
}
