# MCP, Sessions & Hooks

Connect external services via MCP, persist agent conversations, and intercept lifecycle events with hooks.

## Overview

OpenAgentSDK integrates with the Model Context Protocol (MCP) for connecting to external tool servers, provides session persistence for saving and restoring conversations, and includes a hook system for intercepting agent lifecycle events.

## MCP Client Connections

### MCPClientManager

``MCPClientManager`` manages connections to MCP servers. It handles process lifecycle, MCP handshake, and tool discovery:

```swift
let mcpManager = MCPClientManager()

// Connect to a stdio-based MCP server
await mcpManager.connect(name: "filesystem", config: .stdio(McpStdioConfig(
    command: "npx",
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
)))

// Connect to an SSE-based MCP server
await mcpManager.connect(name: "remote", config: .sse(McpSseConfig(
    url: "http://localhost:3000/sse"
)))

// Connect to an HTTP-based MCP server
await mcpManager.connect(name: "api", config: .http(McpHttpConfig(
    url: "http://localhost:4000/mcp",
    headers: ["Authorization": "Bearer token"]
)))

// Get discovered tools
let tools = await mcpManager.getMCPTools()

// Clean up
await mcpManager.shutdown()
```

### Transport Types

MCP supports three transport types configured via ``McpServerConfig``:

| Config | Transport | Use Case |
|--------|-----------|----------|
| ``McpServerConfig/stdio(_:)`` | Standard I/O | Local processes (CLI tools, language servers) |
| ``McpServerConfig/sse(_:)`` | Server-Sent Events | Remote servers with streaming |
| ``McpServerConfig/http(_:)`` | HTTP POST | Remote servers with request/response |

### Automatic Integration with Agent

Configure MCP servers in ``AgentOptions`` and the agent handles connection and tool assembly automatically:

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    mcpServers: [
        "filesystem": .stdio(McpStdioConfig(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
        )),
        "weather": .http(McpHttpConfig(
            url: "http://weather-service:8080/mcp"
        ))
    ]
))
```

MCP tools are namespaced as `mcp__{serverName}__{toolName}` to avoid conflicts with built-in tools.

## In-Process MCP Server

### InProcessMCPServer

``InProcessMCPServer`` exposes SDK tools to external MCP clients without network overhead:

```swift
// Create an in-process server with your tools
let server = InProcessMCPServer(
    name: "my-tools",
    version: "1.0.0",
    tools: [readTool, writeTool, searchTool],
    cwd: "/project"
)

// Use in SDK internal mode (zero overhead)
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    mcpServers: ["my-tools": server.asConfig()]
))

// Or expose to external MCP clients
let (session, transport) = try await server.createSession()
```

## Session Persistence

### SessionStore

``SessionStore`` persists agent conversations to JSON files at `~/.open-agent-sdk/sessions/{sessionId}/transcript.json`:

```swift
let sessionStore = SessionStore()

// Create an agent with session auto-save/restore
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    sessionId: "my-session-001"
))

// The agent automatically restores previous history before the prompt
// and saves updated messages after completion
let result = await agent.prompt("Continue our discussion about Swift")
```

### Session Management

```swift
// List all sessions (sorted by most recently updated)
let sessions = try sessionStore.list()
for session in sessions {
    print("\(session.id): \(session.summary ?? "No title") (\(session.messageCount) messages)")
}

// Rename a session
try sessionStore.rename(sessionId: "my-session-001", newTitle: "Swift Discussion")

// Tag a session
try sessionStore.tag(sessionId: "my-session-001", tag: "important")

// Fork a session (create a copy with optional truncation)
let forkId = try sessionStore.fork(
    sourceSessionId: "my-session-001",
    newSessionId: "fork-001",
    upToMessageIndex: 5  // Copy only first 6 messages
)

// Delete a session
try sessionStore.delete(sessionId: "my-session-001")
```

### Manual Session Operations

```swift
// Save a session manually
try sessionStore.save(
    sessionId: "manual-001",
    messages: conversationMessages,
    metadata: PartialSessionMetadata(
        cwd: "/project",
        model: "claude-sonnet-4-6",
        summary: "My conversation"
    )
)

// Load a session
if let data = try sessionStore.load(sessionId: "manual-001") {
    print("Loaded \(data.messages.count) messages")
    print("Model: \(data.metadata.model)")
}
```

## Hook System

### HookRegistry

``HookRegistry`` manages lifecycle event hooks. Hooks can intercept agent operations, modify behavior, or trigger side effects:

```swift
let registry = HookRegistry()

// Register a function hook
await registry.register(.preToolUse, definition: HookDefinition(
    handler: { input in
        guard let toolName = input.toolName else { return nil }
        if toolName == "Bash" {
            return HookOutput(message: "Bash execution logged", block: false)
        }
        return nil
    }
))

// Register a shell command hook
await registry.register(.postToolUse, definition: HookDefinition(
    command: "notify-send 'Tool executed' 'Tool: $HOOK_TOOL_NAME'",
    matcher: "Bash"  // Only match Bash tool
))
```

### Lifecycle Events

``HookEvent`` defines all hookable lifecycle events:

| Event | Triggered When |
|-------|---------------|
| ``HookEvent/preToolUse`` | Before a tool is executed |
| ``HookEvent/postToolUse`` | After a tool completes successfully |
| ``HookEvent/postToolUseFailure`` | After a tool fails |
| ``HookEvent/sessionStart`` | When an agent session begins |
| ``HookEvent/sessionEnd`` | When an agent session ends |
| ``HookEvent/stop`` | When the agent loop terminates |
| ``HookEvent/subagentStart`` | When a sub-agent is spawned |
| ``HookEvent/subagentStop`` | When a sub-agent completes |
| ``HookEvent/userPromptSubmit`` | When a user prompt is submitted |
| ``HookEvent/permissionRequest`` | When a permission check occurs |
| ``HookEvent/permissionDenied`` | When a permission is denied |

### Shell Hooks

Shell hooks execute external commands with hook input passed as JSON via stdin:

```swift
await registry.register(.preToolUse, definition: HookDefinition(
    command: "python3 /path/to/handler.py",
    timeout: 5000  // 5 second timeout
))
```

The hook receives JSON on stdin with fields like `event`, `toolName`, `toolInput`, etc. It can return JSON with `message`, `block`, `permissionUpdate`, or `notification` fields.

### Hook Output

Hooks can return ``HookOutput`` to influence agent behavior:

- **`message`** — A log or status message
- **`block`** — Set to `true` to block the current operation
- **`permissionUpdate`** — Dynamically change tool permissions
- **`notification`** — Send a notification to the user

## Permission Modes and Policies

### PermissionMode

``PermissionMode`` controls tool execution behavior:

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    permissionMode: .plan  // Only allows read-only tools
))

// Change mode at runtime
agent.setPermissionMode(.bypassPermissions)
```

Available modes: `.default`, `.acceptEdits`, `.bypassPermissions`, `.plan`, `.dontAsk`, `.auto`.

### Custom Authorization Policies

Implement ``PermissionPolicy`` for fine-grained control:

```swift
// Allow only specific tools
let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])

// Deny specific tools
let denyPolicy = ToolNameDenylistPolicy(deniedToolNames: ["Bash", "Write"])

// Allow only read-only tools
let readOnlyPolicy = ReadOnlyPolicy()

// Compose multiple policies
let composite = CompositePolicy(policies: [denyPolicy, readOnlyPolicy])

agent.setCanUseTool(canUseTool(policy: composite))
```
