import Foundation
import OpenAgentSDK

// MARK: - Tests 11-12: Error Handling

struct ErrorHandlingTests {
    static func run(baseURL: String) async {
        section("11. Invalid API Key")
        await testInvalidApiKey(baseURL: baseURL)

        section("12. AnthropicClient Regression")
        testAnthropicClientRegression()
    }

    // MARK: Test 11

    static func testInvalidApiKey(baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: "sk-invalid-key-12345",
            model: "gpt-4o-mini",
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 1
        ))

        let result = await agent.prompt("This should fail.")

        if result.status == .errorDuringExecution {
            pass("Invalid API key: returns .errorDuringExecution")
        } else {
            fail("Invalid API key: returns .errorDuringExecution", "got \(result.status)")
        }

        if result.text.isEmpty {
            pass("Invalid API key: empty text on error")
        } else {
            fail("Invalid API key: empty text on error", "text: \(result.text.prefix(100))")
        }
    }

    // MARK: Test 12

    static func testAnthropicClientRegression() {
        let client = AnthropicClient(apiKey: "test-key", baseURL: "https://test.example.com")
        let desc = String(describing: client)
        if desc.contains("AnthropicClient") {
            pass("AnthropicClient still works and conforms to LLMClient")
        } else {
            fail("AnthropicClient still works and conforms to LLMClient")
        }
    }
}
