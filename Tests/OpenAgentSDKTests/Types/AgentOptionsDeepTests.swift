import XCTest
@testable import OpenAgentSDK

final class AgentOptionsDeepTests: XCTestCase {

    // MARK: - LLMProvider

    func testLLMProvider_anthropic() {
        XCTAssertEqual(LLMProvider.anthropic.rawValue, "anthropic")
    }

    func testLLMProvider_openai() {
        XCTAssertEqual(LLMProvider.openai.rawValue, "openai")
    }

    func testLLMProvider_equality() {
        XCTAssertEqual(LLMProvider.anthropic, LLMProvider.anthropic)
        XCTAssertEqual(LLMProvider.openai, LLMProvider.openai)
        XCTAssertNotEqual(LLMProvider.anthropic, LLMProvider.openai)
    }

    func testLLMProvider_sendable() {
        let provider: LLMProvider = .anthropic
        // Should compile if Sendable
        _ = provider
    }

    func testLLMProvider_fromRawValue() {
        XCTAssertEqual(LLMProvider(rawValue: "anthropic"), .anthropic)
        XCTAssertEqual(LLMProvider(rawValue: "openai"), .openai)
        XCTAssertNil(LLMProvider(rawValue: "other"))
    }

    // MARK: - QueryStatus

    func testQueryStatus_allCases() {
        let statuses: [QueryStatus] = [.success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd]
        XCTAssertEqual(statuses.count, 4)
    }

    func testQueryStatus_rawValues() {
        XCTAssertEqual(QueryStatus.success.rawValue, "success")
        XCTAssertEqual(QueryStatus.errorMaxTurns.rawValue, "errorMaxTurns")
        XCTAssertEqual(QueryStatus.errorDuringExecution.rawValue, "errorDuringExecution")
        XCTAssertEqual(QueryStatus.errorMaxBudgetUsd.rawValue, "errorMaxBudgetUsd")
    }

    func testQueryStatus_equality() {
        XCTAssertEqual(QueryStatus.success, QueryStatus.success)
        XCTAssertNotEqual(QueryStatus.success, QueryStatus.errorMaxTurns)
    }

    func testQueryStatus_sendable() {
        let status: QueryStatus = .success
        _ = status
    }

    // MARK: - QueryResult

    func testQueryResult_init_allFields() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let messages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn"))
        ]
        let result = QueryResult(
            text: "Done",
            usage: usage,
            numTurns: 3,
            durationMs: 1500,
            messages: messages,
            status: .success,
            totalCostUsd: 0.05
        )
        XCTAssertEqual(result.text, "Done")
        XCTAssertEqual(result.usage.inputTokens, 100)
        XCTAssertEqual(result.numTurns, 3)
        XCTAssertEqual(result.durationMs, 1500)
        XCTAssertEqual(result.messages.count, 1)
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.totalCostUsd, 0.05)
    }

    func testQueryResult_init_defaults() {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0)
        let result = QueryResult(
            text: "ok",
            usage: usage,
            numTurns: 1,
            durationMs: 100,
            messages: []
        )
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.totalCostUsd, 0.0)
    }

    func testQueryResult_sendable() {
        let result = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 0,
            durationMs: 0,
            messages: []
        )
        _ = result
    }

    // MARK: - AgentOptions Default Values

    func testAgentOptions_defaultValues() {
        let options = AgentOptions()
        XCTAssertNil(options.apiKey)
        XCTAssertEqual(options.model, "claude-sonnet-4-6")
        XCTAssertNil(options.baseURL)
        XCTAssertEqual(options.provider, .anthropic)
        XCTAssertNil(options.systemPrompt)
        XCTAssertEqual(options.maxTurns, 10)
        XCTAssertEqual(options.maxTokens, 16384)
        XCTAssertNil(options.maxBudgetUsd)
        XCTAssertNil(options.thinking)
        XCTAssertEqual(options.permissionMode, .default)
        XCTAssertNil(options.canUseTool)
        XCTAssertNil(options.cwd)
        XCTAssertNil(options.tools)
        XCTAssertNil(options.mcpServers)
        XCTAssertNil(options.retryConfig)
        XCTAssertNil(options.agentName)
        XCTAssertNil(options.mailboxStore)
        XCTAssertNil(options.teamStore)
        XCTAssertNil(options.taskStore)
        XCTAssertNil(options.worktreeStore)
        XCTAssertNil(options.planStore)
        XCTAssertNil(options.cronStore)
        XCTAssertNil(options.todoStore)
        XCTAssertNil(options.sessionStore)
        XCTAssertNil(options.sessionId)
        XCTAssertNil(options.hookRegistry)
    }

    func testAgentOptions_customValues() {
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
        XCTAssertEqual(options.maxBudgetUsd, 5.0)
        XCTAssertEqual(options.thinking, .enabled(budgetTokens: 10000))
        XCTAssertEqual(options.permissionMode, .auto)
        XCTAssertEqual(options.cwd, "/home/user")
    }

    func testAgentOptions_fromSDKConfiguration() {
        let config = SDKConfiguration(
            apiKey: "config-key",
            model: "claude-haiku-4-5",
            baseURL: "http://custom.api.com",
            maxTurns: 5,
            maxTokens: 8192
        )
        let options = AgentOptions(from: config)

        XCTAssertEqual(options.apiKey, "config-key")
        XCTAssertEqual(options.model, "claude-haiku-4-5")
        XCTAssertEqual(options.maxTurns, 5)
        XCTAssertEqual(options.maxTokens, 8192)
        XCTAssertEqual(options.baseURL, "http://custom.api.com")
        XCTAssertEqual(options.provider, LLMProvider.anthropic)
        XCTAssertNil(options.systemPrompt)
        XCTAssertNil(options.thinking)
        XCTAssertNil(options.maxBudgetUsd)
    }

    // MARK: - AgentDefinition

    func testAgentDefinition_fullInit() {
        let def = AgentDefinition(
            name: "Researcher",
            description: "Research agent",
            model: "claude-sonnet-4-6",
            systemPrompt: "Research thoroughly",
            tools: ["Read", "Grep", "WebSearch"],
            maxTurns: 15
        )
        XCTAssertEqual(def.name, "Researcher")
        XCTAssertEqual(def.description, "Research agent")
        XCTAssertEqual(def.model, "claude-sonnet-4-6")
        XCTAssertEqual(def.systemPrompt, "Research thoroughly")
        XCTAssertEqual(def.tools, ["Read", "Grep", "WebSearch"])
        XCTAssertEqual(def.maxTurns, 15)
    }

    func testAgentDefinition_minimalInit() {
        let def = AgentDefinition(name: "Minimal")
        XCTAssertEqual(def.name, "Minimal")
        XCTAssertNil(def.description)
        XCTAssertNil(def.model)
        XCTAssertNil(def.systemPrompt)
        XCTAssertNil(def.tools)
        XCTAssertNil(def.maxTurns)
    }

    // MARK: - SubAgentResult

    func testSubAgentResult_equality_differentFields() {
        let a = SubAgentResult(text: "Hello", toolCalls: ["A"], isError: false)
        let b = SubAgentResult(text: "Hello", toolCalls: ["A"], isError: true)
        XCTAssertNotEqual(a, b, "Different isError should not be equal")

        let c = SubAgentResult(text: "Hello", toolCalls: ["A", "B"], isError: false)
        XCTAssertNotEqual(a, c, "Different toolCalls should not be equal")

        let d = SubAgentResult(text: "World", toolCalls: ["A"], isError: false)
        XCTAssertNotEqual(a, d, "Different text should not be equal")
    }

    // MARK: - AgentOptions Validation

    func testAgentOptions_validate_invalidBaseURL_throws() {
        let options = AgentOptions(
            apiKey: "sk-test",
            baseURL: "not a url!!"
        )
        XCTAssertThrowsError(try options.validate()) { error in
            guard let sdkError = error as? SDKError,
                  case .invalidConfiguration(let msg) = sdkError else {
                XCTFail("Expected SDKError.invalidConfiguration, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("baseURL"),
                          "Error message should mention baseURL, got: \(msg)")
        }
    }

    func testAgentOptions_validate_validBaseURL_succeeds() {
        let options = AgentOptions(
            apiKey: "sk-test",
            baseURL: "https://api.example.com"
        )
        XCTAssertNoThrow(try options.validate(),
                         "Valid baseURL should not throw")
    }

    func testAgentOptions_validate_nilBaseURL_succeeds() {
        let options = AgentOptions(apiKey: "sk-test")
        XCTAssertNoThrow(try options.validate(),
                         "nil baseURL should not throw")
    }

    func testAgentOptions_validate_invalidThinking_throws() {
        let options = AgentOptions(
            apiKey: "sk-test",
            thinking: .enabled(budgetTokens: 0)
        )
        XCTAssertThrowsError(try options.validate()) { error in
            guard let sdkError = error as? SDKError,
                  case .invalidConfiguration = sdkError else {
                XCTFail("Expected SDKError.invalidConfiguration, got \(error)")
                return
            }
        }
    }

    func testAgentOptions_validate_validThinking_succeeds() {
        let options = AgentOptions(
            apiKey: "sk-test",
            thinking: .enabled(budgetTokens: 10000)
        )
        XCTAssertNoThrow(try options.validate(),
                         "Valid thinking config should not throw")
    }
}
