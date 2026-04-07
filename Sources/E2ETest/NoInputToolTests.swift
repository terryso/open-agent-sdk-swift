import Foundation
import OpenAgentSDK

// MARK: - Test 22: No-Input Tool

struct NoInputToolTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("22. No-Input Tool (defineTool without Codable)")
        await testNoInputTool(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    static func testNoInputTool(apiKey: String, model: String, baseURL: String) async {
        let clockTool = defineTool(
            name: "get_time",
            description: "Returns the current date and time.",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { (_: ToolContext) async throws -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return "Current time: \(formatter.string(from: Date()))"
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            tools: [clockTool]
        ))

        let result = await agent.prompt("What time is it? Use the get_time tool.")

        if result.status == .success {
            pass("No-input tool: agent returns success")
        } else {
            fail("No-input tool: agent returns success", "got \(result.status)")
        }
    }
}
