import Foundation

extension TemplateGenerator {

    var readmeContent: String {
        """
        # \(projectName)

        An AI Agent built with [OpenAgentSDK](https://github.com/terryso/open-agent-sdk-swift).

        ## Quick Start (5 minutes)

        ```bash
        # 1. Set up your API key
        cp .env.example .env
        # Edit .env and add your Anthropic API key

        # 2. Build the project
        swift build

        # 3. Run the agent
        swift run \(projectName)
        ```

        ## Project Structure

        ```
        \(projectName)/
        ├── Package.swift                    # SPM manifest — OpenAgentSDK dependency
        ├── .env.example                     # API key configuration template
        ├── README.md                        # This file
        ├── Sources/
        │   └── \(projectName)/              # Main program (executable target)
        │       ├── main.swift               # Agent entry point — create + run
        │       ├── Tools/                   # Custom tools directory
        │       │   └── HelloWorldTool.swift # Example tools using defineTool()
        │       ├── Hooks/                   # Safety hooks directory
        │       │   └── SafetyHooks.swift    # Hook registration examples
        │       └── Config/                  # Configuration
        │           └── EnvLoader.swift      # .env loading documentation
        ├── Prompts/
        │   └── system.md                    # System prompt template
        └── Tests/
            └── \(projectName)Tests/         # Unit tests
        ```

        ## Tool Development Guide

        The SDK provides `defineTool()` with four patterns for different use cases:

        | Pattern | Input Type | Return Type | When to Use |
        |---------|-----------|-------------|-------------|
        | Codable + String | `Codable` struct | `String` | Most common — type-safe input, simple result |
        | Codable + Result | `Codable` struct | `ToolExecuteResult` | Need explicit success/failure control |
        | No-Input | None (no struct) | `String` | Simple tools (health check, info) |
        | Raw Dictionary | `[String: Any]` | `ToolExecuteResult` | Dynamic/arbitrary input types |

        ### Pattern 1: Codable Input + String Return (Recommended)

        ```swift
        struct MyInput: Codable {
            let query: String
            let limit: Int?
        }

        let myTool = defineTool(
            name: "my_tool",
            description: "What this tool does",
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Search query"],
                    "limit": ["type": "integer", "description": "Max results"]
                ],
                "required": ["query"]
            ],
            isReadOnly: true
        ) { (input: MyInput, context: ToolContext) -> String in
            return "Result for: \\(input.query)"
        }
        ```

        ### Pattern 2: Codable Input + ToolExecuteResult

        Use when you need explicit error reporting:

        ```swift
        let calcTool = defineTool(
            name: "calculator",
            description: "Perform arithmetic",
            inputSchema: [/* ... */]
        ) { (input: CalcInput, context: ToolContext) -> ToolExecuteResult in
            guard input.b != 0 else {
                return ToolExecuteResult(content: "Division by zero", isError: true)
            }
            return ToolExecuteResult(content: "\\(input.a / input.b)", isError: false)
        }
        ```

        ### Pattern 3: No-Input (Simple Tools)

        ```swift
        let infoTool = defineTool(
            name: "system_info",
            description: "Get system info",
            inputSchema: ["type": "object", "properties": [:] as [String: Any]]
        ) { (context: ToolContext) -> String in
            return "Working directory: \\(context.cwd)"
        }
        ```

        ### Pattern 4: Raw Dictionary Input

        ```swift
        let configTool = defineTool(
            name: "get_config",
            description: "Read config value",
            inputSchema: [/* ... */]
        ) { (input: [String: Any], context: ToolContext) -> ToolExecuteResult in
            guard let key = input["key"] as? String else {
                return ToolExecuteResult(content: "Missing key", isError: true)
            }
            return ToolExecuteResult(content: "Value for \\(key)", isError: false)
        }
        ```

        **Important:** The `inputSchema` field names and types must match your Codable struct properties.

        ## Tool Pool Assembly

        When the agent starts, `assembleToolPool()` merges tools in this order:

        1. **Base tools** — SDK built-in tools (file read/write, search, etc.)
        2. **Custom tools** — Your tools from `AgentOptions.tools`
        3. **MCP tools** — Tools discovered from MCP servers

        If tools have the same name, **later sources override earlier ones**. This means your custom
        tool can replace a base tool with the same name.

        You can control which tools are available using `allowedTools` and `disallowedTools` arrays in
        `AgentOptions`.

        ## Hooks: Safety Policies

        Hooks intercept agent lifecycle events to enforce policies, add auditing, or modify behavior.

        See `Sources/\(projectName)/Hooks/SafetyHooks.swift` for a complete example.

        ### Registering a Hook

        ```swift
        let registry = HookRegistry()

        // Pre-tool hook: runs before each tool execution
        await registry.register(.preToolUse, definition: HookDefinition(
            matcher: "click|type_text",  // Regex matching tool names (nil = all tools)
            handler: { input in
                // Return nil to allow, or HookOutput to block/modify
                return HookOutput(decision: .block, message: "Operation blocked")
            }
        ))

        // Pass registry to agent
        let agent = createAgent(options: AgentOptions(
            // ... other options
            hookRegistry: registry
        ))
        ```

        ### Available Hook Events

        | Event | When |
        |-------|------|
        | `preToolUse` | Before a tool executes |
        | `postToolUse` | After a tool succeeds |
        | `postToolUseFailure` | After a tool fails |
        | `sessionStart` / `sessionEnd` | Agent session lifecycle |
        | `permissionRequest` | When permission check occurs |

        ### Batch Registration

        ```swift
        await registry.registerFromConfig([
            "preToolUse": [hookDef1, hookDef2],
            "postToolUse": [hookDef3]
        ])
        ```

        ## MCP Server Integration

        MCP (Model Context Protocol) servers provide additional tools discovered at runtime.

        ### Using Axion's Desktop Automation

        If you have [Axion](https://github.com/terryso/axion) installed, you can use its 20+ desktop
        operation tools (launch_app, click, type_text, screenshot, etc.):

        ```swift
        let mcpServers: [String: McpServerConfig] = [
            "axion-helper": .stdio(McpStdioConfig(command: "axion mcp"))
        ]

        let agent = createAgent(options: AgentOptions(
            // ... other options
            mcpServers: mcpServers
        ))
        ```

        Axion tools are namespaced as `mcp__axion-helper__{tool_name}` (e.g. `mcp__axion-helper__click`).

        ### Using a Custom Helper App

        You can build your own Helper App that follows the AxionHelper pattern:

        1. Create a Swift executable using `mcp-swift-sdk`'s `@Tool` macro
        2. Define tools as `@Tool struct` with `@Parameter` properties
        3. Communicate via stdio JSON-RPC (no network port needed)

        ```swift
        let mcpServers: [String: McpServerConfig] = [
            "my-helper": .stdio(McpStdioConfig(command: "/path/to/my-helper"))
        ]
        ```

        #### Custom Helper App Architecture

        Reference the [AxionHelper architecture](https://github.com/terryso/axion/tree/master/Sources/AxionHelper):

        ```
        MyHelper/
        ├── Package.swift              # Depends on mcp-swift-sdk
        ├── Sources/
        │   └── MyHelper/
        │       ├── main.swift         # MCPServer.run() entry point
        │       └── Tools/
        │           └── MyTool.swift   # @Tool struct definitions
        ```

        Minimal `main.swift`:

        ```swift
        import MCP

        @main
        struct MyHelper {
            static func main() async throws {
                let server = MCPServer(name: "my-helper", version: "1.0.0")
                // Register @Tool structs here
                try await server.run(transport: StdioTransport())
            }
        }
        ```

        Minimal `Package.swift`:

        ```swift
        // swift-tools-version: 6.1
        import PackageDescription

        let package = Package(
            name: "MyHelper",
            platforms: [.macOS(.v14)],
            targets: [
                .executableTarget(name: "MyHelper", dependencies: [
                    .product(name: "MCP", package: "mcp-swift-sdk")
                ])
            ],
            dependencies: [
                .package(url: "https://github.com/anthropics/mcp-swift-sdk", from: "0.1.0")
            ]
        )
        ```

        ## Permission Modes

        Control how tools are authorized:

        | Mode | Behavior |
        |------|----------|
        | `.bypassPermissions` | All tools execute without prompting (development only) |
        | `.default` | Prompts user for dangerous operations |
        | `.acceptEdits` | Auto-accept file edits, prompt for other operations |
        | `.auto` | Auto-approve all tool calls |
        | `.dontAsk` | Skip permission prompts, use stored decisions |
        | `.plan` | Read-only — no tool execution, planning only |

        ### Custom Permission Callback

        ```swift
        let agent = createAgent(options: AgentOptions(
            // ... other options
            permissionMode: .default,
            canUseTool: { tool, input, context in
                // Return CanUseToolResult to allow/deny, or nil to defer
                if tool.name == "delete_file" {
                    return .deny("Delete operations not allowed")
                }
                return .allow()
            }
        ))
        ```

        ## Configuring System Prompt

        Edit `Prompts/system.md` to customize your agent's behavior:

        - Add or remove available tools
        - Modify behavior guidelines
        - Add domain-specific instructions

        ## Running and Debugging

        ```bash
        # Run with default configuration
        swift run \(projectName)

        # Build in release mode (faster startup)
        swift build -c release
        .build/release/\(projectName)

        # Run tests
        swift test
        ```

        ## Environment Variables

        | Variable | Required | Description |
        |----------|----------|-------------|
        | `ANTHROPIC_API_KEY` | Yes | Your Anthropic API key |
        | `MODEL` | No | Override default model (default: `claude-sonnet-4-6`) |

        ## SDK Reference

        - **SDK Documentation**: [open-agent-sdk-swift](https://github.com/terryso/open-agent-sdk-swift)
        - **SDK Boundary Doc**: See Axion's [docs/sdk-boundary.md](https://github.com/terryso/axion/blob/master/docs/sdk-boundary.md) for a detailed breakdown of SDK vs application layer
        - **Axion Reference**: [Axion](https://github.com/terryso/axion) — flagship reference implementation

        ### Core SDK APIs Used

        | API | Purpose |
        |-----|---------|
        | `createAgent(options:)` | Create an Agent instance |
        | `AgentOptions` | Configure agent parameters (apiKey, model, systemPrompt, tools, mcpServers, hookRegistry) |
        | `defineTool()` | Define custom tools (4 overloads for different input/return types) |
        | `ToolExecuteResult` | Explicit success/failure return for tools |
        | `HookRegistry` | Register lifecycle hooks for safety/auditing |
        | `HookDefinition` | Define hook with matcher regex and handler closure |
        | `HookOutput` | Hook decision (approve/block) with optional message |
        | `McpStdioConfig` | Configure MCP server via stdio transport |
        | `assembleToolPool()` | Merge base + custom + MCP tools with deduplication |
        | `loadDotEnv()` / `getEnv()` | Environment variable loading |
        | `agent.prompt()` | Run a single prompt and get response |
        | `agent.stream()` | Stream agent responses in real-time |

        ## License

        Add your license here.
        """
    }
}
