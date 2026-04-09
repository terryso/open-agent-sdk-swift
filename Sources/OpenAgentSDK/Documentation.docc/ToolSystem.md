# Tool System

Learn how to define, register, and execute tools in OpenAgentSDK.

## Overview

Tools are the primary way agents interact with the outside world. Every tool conforms to ``ToolProtocol``, which defines a name, description, input schema, and execution closure. The SDK provides a rich set of built-in tools and a flexible factory function for creating custom tools.

## Tool Protocol

All tools conform to ``ToolProtocol``, which requires four properties and one method:

```swift
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }
    var isReadOnly: Bool { get }
    func call(input: Any, context: ToolContext) async -> ToolResult
}
```

- **`name`** — A unique identifier for the tool. Used by the LLM to select the tool.
- **`description`** — A human-readable description that helps the LLM understand when to use the tool.
- **`inputSchema`** — A JSON Schema dictionary (``ToolInputSchema``) describing the tool's expected input format.
- **`isReadOnly`** — Whether the tool only reads data without side effects. Read-only tools may be allowed under restrictive permission modes.
- **`call(input:context:)`** — The execution method. Receives raw input and a ``ToolContext``, returns a ``ToolResult``. **Never throws** — errors are captured in the result.

## Creating Custom Tools with defineTool()

Use the `defineTool()` factory function to create tools with type-safe Codable input decoding:

### Codable Input Tool

The most common pattern bridges raw JSON to a Swift `Codable` type:

```swift
struct SearchInput: Codable {
    let query: String
    let limit: Int?
}

let searchTool = defineTool(
    name: "Search",
    description: "Search the knowledge base",
    inputSchema: [
        "type": "object",
        "properties": [
            "query": ["type": "string"],
            "limit": ["type": "integer"]
        ],
        "required": ["query"]
    ]
) { (input: SearchInput, context: ToolContext) -> String in
    // `input` is already decoded from JSON
    return "Found 3 results for '\(input.query)'"
}
```

### Structured Result Tool

When you need to explicitly signal success or error, return ``ToolExecuteResult``:

```swift
let writeFileTool = defineTool(
    name: "WriteFile",
    description: "Write content to a file",
    inputSchema: [
        "type": "object",
        "properties": [
            "path": ["type": "string"],
            "content": ["type": "string"]
        ],
        "required": ["path", "content"]
    ]
) { (input: FileInput, context: ToolContext) -> ToolExecuteResult in
    do {
        try writeContent(input.content, to: input.path)
        return ToolExecuteResult(content: "File written successfully", isError: false)
    } catch {
        return ToolExecuteResult(content: "Error: \(error)", isError: true)
    }
}
```

### No-Input Tool

For tools that don't need structured input:

```swift
let healthTool = defineTool(
    name: "HealthCheck",
    description: "Check system health",
    inputSchema: ["type": "object", "properties": [:]]
) { (context: ToolContext) -> String in
    return "System is healthy"
}
```

### Raw Dictionary Input Tool

For tools with dynamic input types (e.g., a `value` field that can be any JSON type):

```swift
let configTool = defineTool(
    name: "Config",
    description: "Get or set configuration values",
    inputSchema: [
        "type": "object",
        "properties": [
            "key": ["type": "string"],
            "value": ["description": "Any JSON value"]
        ],
        "required": ["key"]
    ]
) { (input: [String: Any], context: ToolContext) -> ToolExecuteResult in
    guard let key = input["key"] as? String else {
        return ToolExecuteResult(content: "Missing 'key'", isError: true)
    }
    // Handle value of any type
    if let value = input["value"] {
        config[key] = value
        return ToolExecuteResult(content: "Set \(key)", isError: false)
    }
    return ToolExecuteResult(content: "\(key) = \(config[key] ?? "nil")", isError: false)
}
```

## Tool Tiers

Built-in tools are organized into three tiers via ``ToolTier``:

| Tier | Description | Tools |
|------|-------------|-------|
| ``ToolTier/core`` | Essential tools | Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch |
| ``ToolTier/advanced`` | Specialized tools | (reserved for future use) |
| ``ToolTier/specialist`` | Domain-specific tools | Worktree, Plan, Cron, Todo, LSP, Config, RemoteTrigger, MCP Resources |

Retrieve tools for a tier with ``getAllBaseTools(tier:)``:

```swift
let coreTools = getAllBaseTools(tier: .core)
```

## Tool Pool Assembly

``assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)`` merges tools from multiple sources with deduplication:

```swift
let pool = assembleToolPool(
    baseTools: getAllBaseTools(tier: .core),
    customTools: [myTool1, myTool2],
    mcpTools: mcpTools,
    allowed: ["Read", "Write", "MyTool"],
    disallowed: ["Bash"]
)
```

When tools share the same name, later sources override earlier ones (custom overrides base, MCP overrides custom/base).

## Tool Context

``ToolContext`` provides execution context including:

- `cwd` — Current working directory
- `toolUseId` — Unique ID for this tool invocation
- `agentSpawner` — Sub-agent spawner (when AgentTool is available)
- `mailboxStore`, `teamStore`, `taskStore` — Multi-agent stores
- `hookRegistry` — Lifecycle hooks
- `permissionMode`, `canUseTool` — Permission enforcement

## Tool Execution Results

``ToolResult`` captures the outcome of a tool call:

```swift
public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String
    public let content: String
    public let isError: Bool
}
```

The agent loop handles tool results automatically — errors are reported to the LLM so it can adjust its approach.

## Converting Tools to API Format

``toApiTool(_:)`` and ``toApiTools(_:)`` convert ``ToolProtocol`` instances to the dictionary format expected by the Anthropic API:

```swift
let apiTools = toApiTools(myTools)
// [["name": "MyTool", "description": "...", "input_schema": [...]], ...]
```
