import Foundation
import OpenAgentSDK

// MARK: - Tests 13-14: Token & Cost Tracking

struct TrackingTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("13. Token Usage Tracking")
        await testTokenUsageTracking(apiKey: apiKey, model: model, baseURL: baseURL)

        section("14. Cost Estimation")
        await testCostEstimation(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 13

    static func testTokenUsageTracking(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1
        ))

        let result = await agent.prompt("Say 'test'.")

        if result.usage.inputTokens > 0 {
            pass("Token tracking: inputTokens > 0 (\(result.usage.inputTokens))")
        } else {
            fail("Token tracking: inputTokens > 0")
        }

        if result.usage.outputTokens > 0 {
            pass("Token tracking: outputTokens > 0 (\(result.usage.outputTokens))")
        } else {
            fail("Token tracking: outputTokens > 0")
        }
    }

    // MARK: Test 14

    static func testCostEstimation(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1
        ))

        let result = await agent.prompt("Say 'cost test'.")

        if result.totalCostUsd > 0 {
            pass("Cost estimation: totalCostUsd > 0 ($\(String(format: "%.6f", result.totalCostUsd)))")
        } else {
            fail("Cost estimation: totalCostUsd > 0")
        }
    }
}
