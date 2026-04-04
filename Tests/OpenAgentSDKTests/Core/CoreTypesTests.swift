import XCTest
@testable import OpenAgentSDK

// MARK: - AC2: Core Types Exposed | AC5: PermissionMode | AC6: Default Config

final class CoreTypesTests: XCTestCase {

    // MARK: - AC2: All core types accessible

    func testTokenUsageStruct() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: 10,
            cacheReadInputTokens: 20
        )
        XCTAssertEqual(usage.inputTokens, 100)
        XCTAssertEqual(usage.outputTokens, 50)
        XCTAssertEqual(usage.cacheCreationInputTokens, 10)
        XCTAssertEqual(usage.cacheReadInputTokens, 20)
    }

    func testTokenUsageTotalTokens() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: nil,
            cacheReadInputTokens: nil
        )
        XCTAssertEqual(usage.totalTokens, 150)
    }

    func testTokenUsageAddition() {
        let a = TokenUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil)
        let b = TokenUsage(inputTokens: 200, outputTokens: 30, cacheCreationInputTokens: 5, cacheReadInputTokens: nil)
        let total = a + b
        XCTAssertEqual(total.inputTokens, 300)
        XCTAssertEqual(total.outputTokens, 80)
        XCTAssertEqual(total.cacheCreationInputTokens, 5)
        XCTAssertNil(total.cacheReadInputTokens)
    }

    func testTokenUsageCodableRoundTrip() throws {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 10, cacheReadInputTokens: 20)
        let encoded = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: encoded)
        XCTAssertEqual(decoded.inputTokens, 100)
        XCTAssertEqual(decoded.outputTokens, 50)
        XCTAssertEqual(decoded.cacheCreationInputTokens, 10)
        XCTAssertEqual(decoded.cacheReadInputTokens, 20)
    }

    func testTokenUsageSnakeCaseCodingKeys() throws {
        let json = """
        {"input_tokens": 100, "output_tokens": 50, "cache_creation_input_tokens": 10, "cache_read_input_tokens": 20}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: json)
        XCTAssertEqual(decoded.inputTokens, 100)
        XCTAssertEqual(decoded.outputTokens, 50)
        XCTAssertEqual(decoded.cacheCreationInputTokens, 10)
        XCTAssertEqual(decoded.cacheReadInputTokens, 20)
    }

    func testToolProtocolExists() {
        // Verify ToolProtocol is a protocol that can be conformed to
        // We can't instantiate a protocol directly, so we verify its requirements exist
        // by checking the type is accessible
        let _: Any = ToolResult.self
        let _: Any = ToolContext.self
    }

    func testToolResultStruct() {
        let result = ToolResult(toolUseId: "tu_1", content: "output", isError: false)
        XCTAssertEqual(result.toolUseId, "tu_1")
        XCTAssertEqual(result.content, "output")
        XCTAssertFalse(result.isError)
    }

    func testToolResultIsError() {
        let result = ToolResult(toolUseId: "tu_2", content: "failed", isError: true)
        XCTAssertTrue(result.isError)
    }

    func testToolContextStruct() {
        let context = ToolContext(cwd: "/tmp")
        XCTAssertEqual(context.cwd, "/tmp")
    }

    // MARK: - AC5: PermissionMode enum (6 cases)

    func testPermissionModeDefault() {
        let mode = PermissionMode.default
        XCTAssertEqual(mode, .default)
    }

    func testPermissionModeAcceptEdits() {
        let mode = PermissionMode.acceptEdits
        XCTAssertEqual(mode, .acceptEdits)
    }

    func testPermissionModeBypassPermissions() {
        let mode = PermissionMode.bypassPermissions
        XCTAssertEqual(mode, .bypassPermissions)
    }

    func testPermissionModePlan() {
        let mode = PermissionMode.plan
        XCTAssertEqual(mode, .plan)
    }

    func testPermissionModeDontAsk() {
        let mode = PermissionMode.dontAsk
        XCTAssertEqual(mode, .dontAsk)
    }

    func testPermissionModeAuto() {
        let mode = PermissionMode.auto
        XCTAssertEqual(mode, .auto)
    }

    func testPermissionModeExhaustiveSwitch() {
        let modes: [PermissionMode] = [.default, .acceptEdits, .bypassPermissions, .plan, .dontAsk, .auto]
        for mode in modes {
            switch mode {
            case .default: break
            case .acceptEdits: break
            case .bypassPermissions: break
            case .plan: break
            case .dontAsk: break
            case .auto: break
            }
        }
        XCTAssertEqual(modes.count, 6)
    }

    // MARK: - AC6: Default configuration values

    func testAgentOptionsDefaultModel() {
        let options = AgentOptions()
        XCTAssertEqual(options.model, "claude-sonnet-4-6")
    }

    func testAgentOptionsDefaultMaxTurns() {
        let options = AgentOptions()
        XCTAssertEqual(options.maxTurns, 10)
    }

    func testAgentOptionsDefaultMaxTokens() {
        let options = AgentOptions()
        XCTAssertEqual(options.maxTokens, 16384)
    }

    func testAgentOptionsDefaultApiKeyIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.apiKey)
    }

    func testAgentOptionsDefaultBaseURLIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.baseURL)
    }

    func testAgentOptionsDefaultSystemPromptIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.systemPrompt)
    }

    func testAgentOptionsDefaultMaxBudgetUsdIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.maxBudgetUsd)
    }

    func testAgentOptionsDefaultThinkingIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.thinking)
    }

    func testAgentOptionsDefaultPermissionMode() {
        let options = AgentOptions()
        XCTAssertEqual(options.permissionMode, .default)
    }

    func testAgentOptionsDefaultCanUseToolIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.canUseTool)
    }

    func testAgentOptionsDefaultCwdIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.cwd)
    }

    func testAgentOptionsDefaultToolsIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.tools)
    }

    func testAgentOptionsDefaultMcpServersIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.mcpServers)
    }

    // MARK: - ThinkingConfig

    func testThinkingConfigAdaptive() {
        let config = ThinkingConfig.adaptive
        XCTAssertEqual(config, .adaptive)
    }

    func testThinkingConfigEnabled() {
        let config = ThinkingConfig.enabled(budgetTokens: 10000)
        if case .enabled(let tokens) = config {
            XCTAssertEqual(tokens, 10000)
        } else {
            XCTFail("Expected .enabled case")
        }
    }

    func testThinkingConfigDisabled() {
        let config = ThinkingConfig.disabled
        XCTAssertEqual(config, .disabled)
    }

    // MARK: - QueryResult

    func testQueryResultStruct() {
        let result = QueryResult(
            text: "Response text",
            usage: TokenUsage(inputTokens: 50, outputTokens: 25, cacheCreationInputTokens: nil, cacheReadInputTokens: nil),
            numTurns: 2,
            durationMs: 3000,
            messages: []
        )
        XCTAssertEqual(result.text, "Response text")
        XCTAssertEqual(result.numTurns, 2)
        XCTAssertEqual(result.durationMs, 3000)
    }

    // MARK: - ModelInfo & MODEL_PRICING

    func testModelInfoStruct() {
        let info = ModelInfo(value: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", description: "Test", supportsEffort: true)
        XCTAssertEqual(info.value, "claude-sonnet-4-6")
        XCTAssertEqual(info.displayName, "Claude Sonnet 4.6")
        XCTAssertTrue(info.supportsEffort)
    }

    func testModelPricingContainsKnownModels() {
        XCTAssertTrue(MODEL_PRICING["claude-opus-4-6"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-sonnet-4-6"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-haiku-4-5"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-sonnet-4-5"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-opus-4-5"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-3-5-sonnet"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-3-5-haiku"] != nil)
        XCTAssertTrue(MODEL_PRICING["claude-3-opus"] != nil)
    }

    func testModelPricingValues() {
        let sonnet = MODEL_PRICING["claude-sonnet-4-6"]
        XCTAssertNotNil(sonnet)
        XCTAssertEqual(sonnet?.input, 3.0 / 1_000_000)
        XCTAssertEqual(sonnet?.output, 15.0 / 1_000_000)
    }
}
