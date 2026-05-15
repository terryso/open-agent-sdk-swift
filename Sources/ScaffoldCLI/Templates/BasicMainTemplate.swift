import Foundation

extension TemplateGenerator {

    var basicMainSwift: String {
        """
        import Foundation
        import OpenAgentSDK

        // MARK: - Load Configuration

        let dotEnv = loadDotEnv()
        let apiKey = getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? { fatalError("Please set ANTHROPIC_API_KEY in .env or environment variable") }()

        // MARK: - Load System Prompt

        let systemPrompt = loadSystemPrompt()

        // MARK: - Register Custom Tools
        //
        // createExampleTools() returns tools using three defineTool() patterns:
        //   1. Codable Input + String return (helloTool)
        //   2. Codable Input + ToolExecuteResult return (greetingTool, calculatorTool)
        //   3. No-Input convenience (systemInfoTool)
        //   4. Raw Dictionary Input (configTool)
        //
        // All tools conform to ToolProtocol — register them via AgentOptions.tools.
        // assembleToolPool() merges: baseTools → customTools → mcpTools (latter overrides).

        let tools = createExampleTools()

        // MARK: - (Optional) Register Hooks
        //
        // Hooks intercept lifecycle events (preToolUse, postToolUse, etc.).
        // See Tools/SafetyHooks.swift for a complete example.
        //
        // let registry = HookRegistry()
        // await registry.register(.preToolUse, definition: HookDefinition(
        //     matcher: "click|type_text",
        //     handler: { input in
        //         return HookOutput(decision: .approve)
        //     }
        // ))

        // MARK: - Create Agent

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: "claude-sonnet-4-6",
            systemPrompt: systemPrompt,
            tools: tools,
            permissionMode: .bypassPermissions
            // Uncomment to add hooks:
            // hookRegistry: registry
        ))

        print("Agent \\(agent) created with \\(tools.count) custom tool(s).")
        print()

        // MARK: - Run

        let result = await agent.prompt("Say hello to the world")

        print("Response: \\(result.text)")
        print()
        print("--- Statistics ---")
        print("  Status: \\(result.status)")
        print("  Turns: \\(result.numTurns)")
        print("  Duration: \\(result.durationMs)ms")
        print("  Cost: $\\(String(format: "%.6f", result.totalCostUsd))")

        // MARK: - Helpers

        /// Load system prompt from Prompts/system.md.
        /// Falls back to a default prompt if the file is not found.
        func loadSystemPrompt() -> String {
            let promptPath = "Prompts/system.md"
            if let content = try? String(contentsOfFile: promptPath, encoding: .utf8), !content.isEmpty {
                return content
            }
            return "You are a helpful AI assistant with access to custom tools."
        }
        """
    }

    var mcpIntegrationMainSwift: String {
        """
        import Foundation
        import OpenAgentSDK

        // MARK: - Load Configuration

        let dotEnv = loadDotEnv()
        let apiKey = getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? { fatalError("Please set ANTHROPIC_API_KEY in .env or environment variable") }()

        // MARK: - Load System Prompt

        let systemPrompt = loadSystemPrompt()

        // MARK: - Register Custom Tools

        let tools = createExampleTools()

        // MARK: - Configure MCP Servers
        //
        // MCP servers provide additional tools discovered at runtime.
        // Tools from MCP servers are namespaced as: mcp__{serverName}__{toolName}
        //
        // Example: Use Axion's desktop automation tools (20+ tools)
        // After installing Axion (https://github.com/terryso/axion), its tools
        // become available: launch_app, click, type_text, screenshot, etc.
        //
        // To use your own custom Helper App instead:
        //   1. Build a Swift executable using mcp-swift-sdk's @Tool macro
        //   2. Reference it via McpStdioConfig(command: "/path/to/your-helper")

        let mcpServers: [String: McpServerConfig] = [
            // Axion desktop automation — 20+ tools (launch_app, click, type_text, etc.)
            "axion-helper": .stdio(McpStdioConfig(command: "axion mcp")),

            // Example: Your custom Helper App
            // "my-helper": .stdio(McpStdioConfig(command: "/path/to/my-helper"))
        ]

        // MARK: - (Optional) Register Hooks

        // let registry = HookRegistry()
        // await registry.register(.preToolUse, definition: HookDefinition(
        //     matcher: "mcp__axion-helper__click|mcp__axion-helper__type_text",
        //     handler: { input in
        //         print("Axion tool call: \\(input.toolName ?? "unknown")")
        //         return nil  // nil = allow
        //     }
        // ))

        // MARK: - Create Agent

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: "claude-sonnet-4-6",
            systemPrompt: systemPrompt,
            tools: tools,
            mcpServers: mcpServers,
            permissionMode: .bypassPermissions
            // hookRegistry: registry
        ))

        print("Agent \\(agent) created with \\(tools.count) custom tool(s) + \\(mcpServers.count) MCP server(s).")
        print()

        // MARK: - Run

        let result = await agent.prompt("Say hello to the world")

        print("Response: \\(result.text)")
        print()
        print("--- Statistics ---")
        print("  Status: \\(result.status)")
        print("  Turns: \\(result.numTurns)")
        print("  Duration: \\(result.durationMs)ms")
        print("  Cost: $\\(String(format: "%.6f", result.totalCostUsd))")

        // MARK: - Helpers

        func loadSystemPrompt() -> String {
            let promptPath = "Prompts/system.md"
            if let content = try? String(contentsOfFile: promptPath, encoding: .utf8), !content.isEmpty {
                return content
            }
            return "You are a helpful AI assistant with access to custom tools and Axion desktop automation."
        }
        """
    }
}
