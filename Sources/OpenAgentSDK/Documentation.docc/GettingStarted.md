# Getting Started with OpenAgentSDK

Get up and running with your first AI agent in Swift in under 15 minutes.

## Overview

OpenAgentSDK is a native Swift SDK for building AI agent applications. It provides a type-safe, actor-based API for creating agents, registering tools, streaming responses, and managing multi-agent coordination.

This guide walks you through adding the SDK to your project, configuring your API key, creating an agent, registering tools, and processing prompts.

## Add the SDK to Your Project

Add OpenAgentSDK as a Swift Package Manager dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/open-agent-sdk-swift.git", from: "0.1.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["OpenAgentSDK"]
)
```

## Configure Your API Key

The SDK reads your Anthropic API key from the `CODEANY_API_KEY` environment variable:

```bash
export CODEANY_API_KEY="sk-..."
```

Alternatively, pass it programmatically:

```swift
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(apiKey: "sk-..."))
```

## Create an Agent and Send a Prompt

```swift
import OpenAgentSDK

// Create an agent (uses environment variable for API key)
let agent = createAgent()

// Send a prompt and get the result
let result = await agent.prompt("What is the capital of France?")
print(result.text)       // "The capital of France is Paris."
print(result.numTurns)   // 1
print(result.status)     // .success
```

## Stream Responses

Use ``Agent/stream(_:)`` to receive responses as they are generated:

```swift
for await message in agent.stream("Explain photosynthesis") {
    switch message {
    case .partialMessage(let data):
        // Each chunk of text as it arrives
        print(data.text, terminator: "")
    case .result(let data):
        // Final result with usage stats
        print("\n---")
        print("Completed in \(data.durationMs)ms")
        print("Tokens: \(data.usage?.totalTokens ?? 0)")
    default:
        break
    }
}
```

## Register Custom Tools

Tools let your agent take actions. Define a tool with the `defineTool()` factory function using a `Codable` input type:

```swift
struct WeatherInput: Codable {
    let city: String
}

let weatherTool = defineTool(
    name: "GetWeather",
    description: "Get the current weather for a city",
    inputSchema: [
        "type": "object",
        "properties": [
            "city": ["type": "string", "description": "City name"]
        ],
        "required": ["city"]
    ],
    isReadOnly: true
) { (input: WeatherInput, context: ToolContext) -> String in
    // Your weather API call here
    return "The weather in \(input.city) is sunny, 22°C."
}

let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    tools: [weatherTool]
))

let result = await agent.prompt("What is the weather in Tokyo?")
```

## Use Built-in Tools

The SDK provides built-in tools organized into tiers. Get all core tools with ``getAllBaseTools(tier:)``:

```swift
let coreTools = getAllBaseTools(tier: .core)
// Includes: Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch

let specialistTools = getAllBaseTools(tier: .specialist)
// Includes: Worktree, Plan, Cron, Todo, LSP, Config, MCP Resources

let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    tools: coreTools + specialistTools
))
```

## Configure Permissions

Control which tools the agent can use with ``PermissionMode`` and custom policies:

```swift
// Use a permission mode
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    permissionMode: .plan  // Only allows read-only tools
))

// Or define a custom policy
let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])
agent.setCanUseTool(canUseTool(policy: policy))
```

## Next Steps

- <doc:ToolSystem> — Learn about the tool system in detail
- <doc:MultiAgent> — Coordinate multiple agents
- <doc:MCPSessionHooks> — Connect external services via MCP and manage sessions
