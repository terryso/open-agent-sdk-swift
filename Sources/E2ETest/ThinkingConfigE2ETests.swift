import Foundation
import OpenAgentSDK

// MARK: - ThinkingConfig E2E Tests

struct ThinkingConfigE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("60. Agent with ThinkingConfig Disabled")
        await testThinkingConfigDisabled(apiKey: apiKey, model: model, baseURL: baseURL)

        section("61. ThinkingConfig Type Validation")
        await testThinkingConfigTypeValidation()
    }

    // MARK: Test 60 - ThinkingConfig Disabled (default behavior)

    static func testThinkingConfigDisabled(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            thinking: .disabled
        ))

        let result = await agent.prompt("What is 2 + 2? Reply with just the number.")

        if result.status == .success {
            pass("ThinkingConfig disabled: agent returns success")
        } else {
            fail("ThinkingConfig disabled: agent returns success", "got \(result.status)")
        }

        let digitsOnly = result.text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digitsOnly.contains("4") {
            pass("ThinkingConfig disabled: correct response")
        } else {
            fail("ThinkingConfig disabled: correct response", "text: \(result.text.prefix(100))")
        }
    }

    // MARK: Test 61 - ThinkingConfig Type Validation

    static func testThinkingConfigTypeValidation() async {
        let adaptive = ThinkingConfig.adaptive
        let enabled = ThinkingConfig.enabled(budgetTokens: 10000)
        let disabled = ThinkingConfig.disabled

        if adaptive != enabled && adaptive != disabled && enabled != disabled {
            pass("ThinkingConfig: all three cases are distinct")
        } else {
            fail("ThinkingConfig: cases should be distinct")
        }

        // Test that AgentOptions accepts thinking config
        let optionsAdaptive = AgentOptions(
            apiKey: "test", model: "test",
            thinking: .adaptive
        )
        let optionsEnabled = AgentOptions(
            apiKey: "test", model: "test",
            thinking: .enabled(budgetTokens: 5000)
        )
        let optionsDisabled = AgentOptions(
            apiKey: "test", model: "test",
            thinking: .disabled
        )

        if optionsAdaptive.thinking == .adaptive
            && optionsEnabled.thinking == .enabled(budgetTokens: 5000)
            && optionsDisabled.thinking == .disabled {
            pass("ThinkingConfig: AgentOptions stores all variants correctly")
        } else {
            fail("ThinkingConfig: AgentOptions should store all variants")
        }
    }
}
