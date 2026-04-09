# OpenAgentSDK

OpenAgentSDK is a native Swift SDK for building AI agent applications powered by the Anthropic API.

## Overview

OpenAgentSDK provides a comprehensive, type-safe Swift API for creating AI agents that can process prompts, execute tools, manage multi-agent coordination, persist sessions, and integrate with external services via the Model Context Protocol (MCP).

### Core Concepts

- **Agent** — The central type that processes prompts via the Anthropic API. Create one with ``createAgent(options:)`` and send prompts with ``Agent/prompt(_:)`` or ``Agent/stream(_:)``.
- **Tools** — Define custom tools with ``defineTool(name:description:inputSchema:isReadOnly:execute:)-(_,_,_,_,(Input,ToolContext)->String)`` that conform to ``ToolProtocol``. The SDK provides built-in tools for file I/O, search, shell execution, and more.
- **Sessions** — Persist and restore agent conversations with ``SessionStore``, supporting save, load, fork, and metadata management.
- **Multi-Agent** — Coordinate multiple agents with ``TeamStore``, ``TaskStore``, ``MailboxStore``, and ``AgentRegistry``. Agents can spawn sub-agents, exchange messages, and manage shared tasks.
- **Hooks** — Intercept lifecycle events with ``HookRegistry`` using function callbacks or shell commands.
- **MCP** — Connect to external tool servers via the Model Context Protocol using ``MCPClientManager``, supporting stdio, HTTP, and SSE transports.

### Quick Start

```swift
import OpenAgentSDK

// Create an agent with your API key
let agent = createAgent(options: AgentOptions(apiKey: "sk-..."))

// Send a prompt and get the result
let result = await agent.prompt("Explain quantum computing in one paragraph")
print(result.text)
```

### Streaming

```swift
// Stream responses as they arrive
for await message in agent.stream("Write a haiku about Swift") {
    switch message {
    case .partialMessage(let data):
        print(data.text, terminator: "")
    case .result(let data):
        print("\nDone in \(data.durationMs)ms")
    default:
        break
    }
}
```

## Topics

### Getting Started

- <doc:GettingStarted>

### Core Types

- ``Agent``
- ``createAgent(options:)``
- ``AgentOptions``
- ``SDKConfiguration``
- ``QueryResult``
- ``QueryStatus``
- ``SDKMessage``
- ``SDKError``

### Tool System

- <doc:ToolSystem>
- ``ToolProtocol``
- ``defineTool(name:description:inputSchema:isReadOnly:execute:)-(_,_,_,_,(Input,ToolContext)->String)``
- ``ToolExecuteResult``
- ``ToolResult``
- ``ToolContext``
- ``ToolTier``
- ``ToolInputSchema``

### Multi-Agent Orchestration

- <doc:MultiAgent>
- ``TaskStore``
- ``MailboxStore``
- ``TeamStore``
- ``AgentRegistry``
- ``SubAgentSpawner``
- ``SubAgentResult``
- ``AgentDefinition``

### MCP, Sessions & Hooks

- <doc:MCPSessionHooks>
- ``MCPClientManager``
- ``InProcessMCPServer``
- ``SessionStore``
- ``HookRegistry``
- ``PermissionMode``
- ``PermissionPolicy``

### Configuration

- ``TokenUsage``
- ``ThinkingConfig``
- ``ModelInfo``
- ``MODEL_PRICING``
- ``LLMProvider``
