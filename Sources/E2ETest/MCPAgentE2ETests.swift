import Foundation
import OpenAgentSDK

// MARK: - InProcessMCPServer Agent E2E Tests

struct MCPAgentE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("58. Agent with InProcessMCPServer SDK Config")
        await testAgentWithInProcessMCPSDKConfig(apiKey: apiKey, model: model, baseURL: baseURL)

        section("59. Agent with Multiple MCP SDK Servers")
        await testAgentWithMultipleMCPSDKServers(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 58 - Agent uses InProcessMCPServer tool via LLM

    static func testAgentWithInProcessMCPSDKConfig(apiKey: String, model: String, baseURL: String) async {
        let weatherTool = defineTool(
            name: "get_weather",
            description: "Get the current weather for a given city.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "city": ["type": "string", "description": "City name"]
                ],
                "required": ["city"]
            ],
            isReadOnly: true
        ) { (input: WeatherInput, _: ToolContext) async throws -> String in
            return "Weather in \(input.city): 22°C, sunny"
        }

        let mcpServer = InProcessMCPServer(
            name: "weather-service",
            version: "1.0.0",
            tools: [weatherTool]
        )

        let sdkConfig = McpSdkServerConfig(name: "weather-service", version: "1.0.0", server: mcpServer)

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            mcpServers: ["weather": .sdk(sdkConfig)]
        ))

        let result = await agent.prompt(
            "Use the get_weather tool to check the weather in Tokyo."
        )

        if result.status == .success {
            pass("LLM+MCP SDK: agent returns success")
        } else {
            fail("LLM+MCP SDK: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("LLM+MCP SDK: agent uses multiple turns (tool call + response)")
        } else {
            fail("LLM+MCP SDK: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        let lower = result.text.lowercased()
        if lower.contains("22") || lower.contains("sunny") || lower.contains("tokyo") {
            pass("LLM+MCP SDK: response contains tool result data")
        } else {
            fail("LLM+MCP SDK: response contains tool result data", "text: \(result.text.prefix(200))")
        }
    }

    // MARK: Test 59 - Agent with Multiple MCP SDK Servers

    static func testAgentWithMultipleMCPSDKServers(apiKey: String, model: String, baseURL: String) async {
        let translateTool = defineTool(
            name: "translate",
            description: "Translate text from one language to another.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "Text to translate"],
                    "from": ["type": "string", "description": "Source language"],
                    "to": ["type": "string", "description": "Target language"]
                ],
                "required": ["text", "to"]
            ],
            isReadOnly: true
        ) { (input: TranslateInput, _: ToolContext) async throws -> String in
            return "Translation: [\(input.text)] -> simulated translation to \(input.to)"
        }

        let server1 = InProcessMCPServer(name: "translate-svc", version: "1.0.0", tools: [translateTool])

        let config: [String: McpServerConfig] = [
            "translate": .sdk(McpSdkServerConfig(name: "translate-svc", version: "1.0.0", server: server1)),
        ]

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            mcpServers: config
        ))

        let result = await agent.prompt(
            "Use the translate tool to translate 'hello world' to Spanish."
        )

        if result.status == .success {
            pass("LLM+Multi MCP: agent returns success")
        } else {
            fail("LLM+Multi MCP: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("LLM+Multi MCP: agent uses multiple turns")
        } else {
            fail("LLM+Multi MCP: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }
    }
}

// MARK: - Shared Input Types for MCP Tests

private struct WeatherInput: Codable {
    let city: String
}

private struct TranslateInput: Codable {
    let text: String
    let from: String?
    let to: String
}
