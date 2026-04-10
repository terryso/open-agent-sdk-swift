# Examples Tutorial

[中文版](./README_CN.md)

Complete runnable examples demonstrating Open Agent SDK features. Each example is a standalone Swift executable you can run with a single command.

## Prerequisites

- **Swift 6.1+** and **macOS 13+**
- **API Key** — set one of the following environment variables:

```bash
# Option 1: OpenAI-compatible API (GLM, Ollama, OpenRouter, etc.) — default
export CODEANY_API_KEY=your-key
export CODEANY_BASE_URL=https://open.bigmodel.cn/api/coding/paas/v4
export CODEANY_MODEL=glm-5.1

# Option 2: Anthropic API (Claude models)
export ANTHROPIC_API_KEY=sk-ant-...
```

> **Tip:** Add the `export` lines to your `~/.zshrc` or `~/.bashrc` so they persist across sessions. Or copy `.env` from the project root and adjust the values.

## Quick Start

```bash
# 1. Clone and enter the project
git clone https://github.com/terryso/open-agent-sdk-swift.git
cd open-agent-sdk-swift

# 2. Build the project (first time only — resolves all dependencies)
swift build

# 3. Run your first example
swift run BasicAgent
```

That's it! The agent will send a prompt to the LLM and print the response.

## All Examples

### 1. BasicAgent — Agent Creation & Simple Query

The simplest example. Creates an agent, sends a blocking prompt, and prints the response with usage stats.

```bash
swift run BasicAgent
```

**What you'll learn:**
- Creating an agent with `createAgent(options:)`
- Blocking query with `agent.prompt()`
- Reading `QueryResult` fields (text, status, turns, cost, tokens)
- Using Anthropic vs OpenAI-compatible providers

**Key code:**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant.",
    permissionMode: .bypassPermissions
))
let result = await agent.prompt("Explain what an AI agent is in one paragraph.")
```

---

### 2. StreamingAgent — Real-Time Streaming Responses

Shows how to consume agent responses in real-time using `AsyncStream<SDKMessage>`.

```bash
swift run StreamingAgent
```

**What you'll learn:**
- Streaming with `agent.stream()`
- Event types: `partialMessage`, `toolUse`, `toolResult`, `result`, `system`
- Budget tracking with `maxBudgetUsd`

**Key code:**
```swift
for await message in agent.stream("Write a haiku about programming.") {
    switch message {
    case .partialMessage(let data): print(data.text, terminator: "")
    case .result(let data): print("Done: \(data.numTurns) turns, $\(data.totalCostUsd)")
    default: break
    }
}
```

---

### 3. CustomTools — Defining Custom Tools

Demonstrates `defineTool()` with Codable input types, String vs `ToolExecuteResult` returns, and permission control.

```bash
swift run CustomTools
```

**What you'll learn:**
- Creating tools with `defineTool()` and Codable input structs
- JSON Schema definitions for tool parameters
- String return vs `ToolExecuteResult` (success/error) return types
- Read-only tools with `isReadOnly: true`
- Three permission control approaches: closure, Policy, and mode

**Key code:**
```swift
struct WeatherInput: Codable { let city: String }

let weatherTool = defineTool(
    name: "get_weather",
    description: "Get the current weather for a city",
    inputSchema: [...]
) { (input: WeatherInput, context: ToolContext) -> String in
    return "Weather in \(input.city): 22C, sunny"
}
```

---

### 4. CustomSystemPromptExample — Specialized Agent Roles

Shows how to customize agent behavior through system prompts. Creates a "code review expert" agent.

```bash
swift run CustomSystemPromptExample
```

**What you'll learn:**
- Using `systemPrompt` to define agent persona and output format
- How system prompts shape response style and structure
- Running a domain-specific agent (code reviewer)

---

### 5. PromptAPIExample — Blocking API with Built-in Tools

Demonstrates `agent.prompt()` with all 10 core tools registered. The agent autonomously executes tools and returns the final result.

```bash
swift run PromptAPIExample
```

**What you'll learn:**
- Using `getAllBaseTools(tier: .core)` to register all core tools
- Blocking API where the agent uses tools autonomously
- Handling `QueryResult` status and error cases

**Key code:**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    tools: getAllBaseTools(tier: .core)
))
let result = await agent.prompt("Analyze the project structure...")
```

---

### 6. MultiToolExample — Multi-Tool Orchestration (Streaming)

Shows an agent autonomously coordinating multiple tools (Glob, Bash, Read) using the streaming API.

```bash
swift run MultiToolExample
```

**What you'll learn:**
- Streaming with `agent.stream()` while tools execute
- Real-time event handling for tool calls and results
- Agent-driven multi-step task orchestration

---

### 7. SubagentExample — Agent Delegation

Demonstrates the main agent delegating tasks to sub-agents via the `Agent` tool.

```bash
swift run SubagentExample
```

**What you'll learn:**
- Creating a coordinator agent with `createAgentTool()`
- How the main agent spawns Explore-type sub-agents
- Sub-agents use a restricted tool set (Read, Glob, Grep, Bash)
- Results flow back from sub-agent to main agent

**Key code:**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    tools: getAllBaseTools(tier: .core) + [createAgentTool()]
))
```

---

### 8. PermissionsExample — Permission Policy Comparison

Runs three agents side-by-side, each with a different permission policy, to demonstrate access control.

```bash
swift run PermissionsExample
```

**What you'll learn:**
- `ToolNameAllowlistPolicy` — allow only specific tool names
- `ReadOnlyPolicy` — allow only `isReadOnly == true` tools
- `bypassPermissions` — unrestricted access (for comparison)
- Bridging policies to callbacks with `canUseTool(policy:)`

---

### 9. MCPIntegration — MCP Server Basics

Introduces MCP (Model Context Protocol) integration with `InProcessMCPServer` and stdio configurations.

```bash
swift run MCPIntegration
```

**What you'll learn:**
- Creating an `InProcessMCPServer` with custom tools
- MCP tool namespacing (`mcp__{serverName}__{toolName}`)
- Using `asConfig()` to generate SDK configuration
- Stdio MCP server configuration for external tool servers

**Key code:**
```swift
let server = InProcessMCPServer(name: "my-tools", version: "1.0.0", tools: [echoTool], cwd: "/tmp")
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    mcpServers: ["my-tools": await server.asConfig()]
))
```

---

### 10. AdvancedMCPExample — Multi-Tool MCP with Error Handling

Advanced MCP example with multiple tools and error handling patterns.

```bash
swift run AdvancedMCPExample
```

**What you'll learn:**
- Registering multiple tools in a single MCP server
- Error handling with `ToolExecuteResult(isError: true)`
- Running multiple queries with the same MCP agent
- Namespace verification (`mcp__utility__get_weather`, etc.)

---

### 11. SessionsAndHooks — Session Persistence & Lifecycle Hooks

Demonstrates session persistence (save/resume conversations) and hook registry for lifecycle events.

```bash
swift run SessionsAndHooks
```

**What you'll learn:**
- `SessionStore` for saving/loading/forking sessions
- `HookRegistry` for pre/post tool execution hooks
- `sessionStart`/`sessionEnd` lifecycle hooks
- Session resume across processes using `sessionId`

**Key code:**
```swift
let sessionStore = SessionStore()
let hookRegistry = HookRegistry()
await hookRegistry.register(.preToolUse, definition: HookDefinition(
    matcher: "Bash",
    handler: { input in return HookOutput(message: "Blocked", block: true) }
))
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    sessionStore: sessionStore,
    sessionId: "my-session",
    hookRegistry: hookRegistry
))
```

## Example Dependencies

| Example             | Requires MCP dependency | Extra setup              |
| ------------------- | ---------------------- | ------------------------ |
| BasicAgent          | No                     | None                     |
| StreamingAgent      | No                     | None                     |
| CustomTools         | No                     | None                     |
| CustomSystemPrompt  | No                     | None                     |
| PromptAPIExample    | No                     | None                     |
| MultiToolExample    | No                     | None                     |
| SubagentExample     | No                     | None                     |
| PermissionsExample  | No                     | None                     |
| MCPIntegration      | Yes (`import MCP`)     | None                     |
| AdvancedMCPExample  | Yes (`import MCP`)     | None                     |
| SessionsAndHooks    | No                     | None                     |

All examples are defined as executable targets in `Package.swift` — no additional configuration needed.

## Recommended Learning Path

```
BasicAgent → StreamingAgent → CustomTools → CustomSystemPromptExample
    → PromptAPIExample → MultiToolExample → SubagentExample
    → PermissionsExample → MCPIntegration → AdvancedMCPExample
    → SessionsAndHooks
```

1. **Start here:** BasicAgent, StreamingAgent — understand the core prompt/stream APIs
2. **Add tools:** CustomTools, CustomSystemPromptExample — learn tool definition and prompt customization
3. **Use built-in tools:** PromptAPIExample, MultiToolExample — see agents autonomously use tools
4. **Multi-agent:** SubagentExample — delegate tasks to sub-agents
5. **Security:** PermissionsExample — control what tools agents can use
6. **MCP integration:** MCPIntegration, AdvancedMCPExample — connect external tool servers
7. **Persistence:** SessionsAndHooks — save sessions and hook into lifecycle events

## Troubleshooting

### Build errors

```bash
# Clean and rebuild
swift package clean
swift build
```

### "No such module 'OpenAgentSDK'"

Make sure you're running from the project root directory where `Package.swift` is located.

### API key errors

Check that your environment variable is set:

```bash
echo $ANTHROPIC_API_KEY   # should print your key
# or
echo $CODEANY_API_KEY
```

### Running in Xcode

```bash
open Package.swift
```

Then select any example target from the scheme selector and press Cmd+R to run.

### Using with GLM / other OpenAI-compatible providers

The examples default to `ANTHROPIC_API_KEY`, but you can modify them to use any OpenAI-compatible provider:

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["CODEANY_API_KEY"] ?? "your-key",
    model: "glm-5.1",
    baseURL: "https://open.bigmodel.cn/api/coding/paas/v4",
    provider: .openai,
    permissionMode: .bypassPermissions
))
```
