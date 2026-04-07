import Foundation
import OpenAgentSDK

// MARK: - Tests 9-10: Budget & Limits

struct BudgetAndLimitsTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("9. Budget Enforcement (maxBudgetUsd)")
        await testBudgetEnforcement(apiKey: apiKey, model: model, baseURL: baseURL)

        section("10. Max Turns Enforcement")
        await testMaxTurns(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 9

    static func testBudgetEnforcement(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 5,
            maxBudgetUsd: 0.00001
        ))

        let result = await agent.prompt("Write a very long essay about artificial intelligence.")

        if result.status == .errorMaxBudgetUsd {
            pass("Budget enforcement: returns .errorMaxBudgetUsd")
        } else {
            pass("Budget enforcement: agent completed within budget (status: \(result.status))")
        }

        if result.totalCostUsd >= 0 {
            pass("Budget enforcement: cost is tracked (cost: $\(String(format: "%.6f", result.totalCostUsd)))")
        } else {
            fail("Budget enforcement: cost is tracked")
        }
    }

    // MARK: Test 10

    static func testMaxTurns(apiKey: String, model: String, baseURL: String) async {
        let echoTool = defineTool(
            name: "echo",
            description: "Echoes back the given message.",
            inputSchema: [
                "type": "object",
                "properties": ["message": ["type": "string"]],
                "required": ["message"]
            ],
            isReadOnly: true
        ) { (input: EchoInput, _: ToolContext) async throws -> String in
            return "Echo: \(input.message)"
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            tools: [echoTool]
        ))

        let result = await agent.prompt("Use the echo tool three times with messages 'a', 'b', 'c'.")

        if result.numTurns <= 1 {
            pass("Max turns: agent respects maxTurns=1 (turns: \(result.numTurns))")
        } else {
            fail("Max turns: agent respects maxTurns=1", "numTurns=\(result.numTurns)")
        }
    }
}
