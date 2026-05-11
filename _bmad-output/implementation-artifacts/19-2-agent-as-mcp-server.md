# Story 19.2: Agent-as-MCP-Server

Status: done

## Story

As an SDK developer,
I want the SDK to provide the ability to expose an Agent as an MCP stdio server,
so that external tools and agents can discover and invoke the Agent's tools via the standard MCP protocol.

## Acceptance Criteria

1. **AC1: AgentMCPServer class defined** -- `AgentMCPServer` is a public actor that wraps an `Agent` and exposes it as an MCP stdio server via `AgentMCPServer.run(agent:)`.

2. **AC2: MCP initialize handshake** -- When `AgentMCPServer` receives an MCP `initialize` request, it responds with the Agent's tool list and server capabilities (tools capability enabled).

3. **AC3: tools/list response** -- When an external caller sends `tools/list`, `AgentMCPServer` returns all tools available to the Agent (custom tools + built-in tools + MCP tools), each with name, description, and inputSchema.

4. **AC4: tools/call dispatch** -- When an external caller sends `tools/call` with a tool name and arguments, `AgentMCPServer` dispatches to the Agent's tool pool, executes the tool, and returns the result.

5. **AC5: agent/prompt custom method** -- When an external caller sends the custom method `agent/prompt` with a `task` text field, `AgentMCPServer` launches a full `Agent.stream()` execution and returns progress as text content chunks.

6. **AC6: Graceful shutdown on EOF** -- When stdin receives EOF while `AgentMCPServer` is running, it waits up to 30 seconds for in-flight tasks to complete, then exits cleanly.

7. **AC7: Claude Code MCP config compatibility** -- Given a Claude Code MCP config `{"mcpServers": {"my-agent": {"command": "my-app", "args": ["mcp"]}}}`, Claude Code can discover and call the Agent's tools via the MCP protocol.

8. **AC8: Unit tests** -- All `AgentMCPServer` operations (tool listing, tool execution, agent/prompt dispatch, graceful shutdown) covered by unit tests.

9. **AC9: Build and test pass** -- `swift build` zero errors zero warnings. All existing tests pass with zero regression.

## Tasks / Subtasks

- [x] Task 1: Define AgentMCPServer actor (AC: #1, #2)
  - [x] Create `Sources/OpenAgentSDK/MCP/AgentMCPServer.swift` with `AgentMCPServer` actor
  - [x] Public method `run(agent:)` that creates an `MCPServer`, registers the agent's tools, and runs with stdio transport
  - [x] Uses `mcp-swift-sdk`'s `MCPServer` + `StdioTransport` (already imported as `MCP` module)
  - [x] Registers a `Server.Capabilities` with `tools` enabled

- [x] Task 2: Implement tool discovery and registration (AC: #3)
  - [x] On `run(agent:)`, call `agent.assembleFullToolPool()` to get the full tool list
  - [x] For each `ToolProtocol` in the pool, register it as a closure-based MCP tool on the `MCPServer`
  - [x] Convert `ToolInputSchema` (`[String: Any]`) to MCP `Value` for registration (reuse `InProcessMCPServer.schemaToValue` pattern)
  - [x] Handle tool name collisions gracefully (append suffix if needed, or log warning)

- [x] Task 3: Implement tools/call dispatch (AC: #4)
  - [x] In the closure-based tool handler, convert MCP `[String: Value]` arguments to `[String: Any]`
  - [x] Construct a `ToolContext` with cwd from Agent options and a generated toolUseId
  - [x] Call `tool.call(input:context:)` and return result as MCP text content
  - [x] If `tool.call` returns `isError: true`, throw `ToolExecutionError` so MCP returns `isError: true`
  - [x] Follow rule #38/#39: tool execution errors captured in result, never crash the MCP server

- [x] Task 4: Implement agent/prompt custom method (AC: #5)
  - [x] Register a special MCP tool named `agent_prompt` that accepts `{ "task": String }`
  - [x] When called, invokes `Agent.stream(task)` and collects `SDKMessage` events
  - [x] Returns the final text result; intermediate progress can be logged via `Logger.shared`
  - [x] Timeout: if stream does not complete within `maxTurns` (from Agent options), return partial result

- [x] Task 5: Implement graceful shutdown (AC: #6)
  - [x] Use `MCPServer.run(transport: .stdio)` which reads stdin via `StdioTransport`
  - [x] When `StdioTransport` detects EOF, the MCP session ends naturally
  - [x] Wrap `MCPServer.run()` with a timeout Task to enforce 30-second max wait for in-flight calls
  - [x] Log shutdown events via `Logger.shared.info`

- [x] Task 6: Write unit tests (AC: #8)
  - [x] Create `Tests/OpenAgentSDKTests/MCP/AgentMCPServerTests.swift`
  - [x] Test tool discovery: create Agent with custom tools, verify AgentMCPServer registers all tools
  - [x] Test tool execution: call a registered tool via MCP protocol and verify result
  - [x] Test agent/prompt: submit task via agent_prompt tool and verify response
  - [x] Test graceful shutdown: simulate EOF and verify clean exit
  - [x] Use `InMemoryTransport` for in-process testing (avoid real stdio)

- [x] Task 7: Update module entry point doc comments (AC: #9)
  - [x] Add `AgentMCPServer` to `OpenAgentSDK.swift` DocC symbol list under "MCP Integration" section

- [x] Task 8: Build and verify (AC: #9)
  - [x] `swift build` zero errors zero warnings
  - [x] Run full test suite, report total count

## Dev Notes

### Position in Epic and Project

- **Epic 19** (Axion Phase 2 SDK Capabilities), second story
- **Prerequisites:** Epic 1 (Agent basics), Epic 6 (MCP protocol), Epic 7 (session persistence) -- all done
- **Depends on Story 19-1** (cross-run Memory Store) -- done
- **Source:** Axion Phase 2 requirement, generalized to all SDK consumers

### CRITICAL: Leverage Existing Infrastructure

This story MUST build on existing MCP server infrastructure. Do NOT reimplement MCP protocol handling from scratch.

1. **MCPServer from mcp-swift-sdk** (`import MCP`) -- Already used by `InProcessMCPServer`. Provides:
   - Tool registration via `server.register(name:description:inputSchema:) { args, context in ... }`
   - Stdio transport via `MCPServer.run(transport: .stdio)` -- one-liner for CLI tools
   - Full JSON-RPC message handling (initialize, tools/list, tools/call, ping, etc.)
   - `StdioTransport` reads stdin, writes stdout, newline-delimited JSON-RPC

2. **InProcessMCPServer** (`Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift`) -- Reference pattern:
   - Creates `MCPServer(name:version:)` and registers `ToolProtocol` tools as closure-based MCP tools
   - `schemaToValue()` converts `[String: Any]` to MCP `Value` for inputSchema registration
   - `mcpValueToAny()` converts MCP `Value` back to `[String: Any]` for tool execution
   - `ToolExecutionError` thrown when `tool.call()` returns `isError: true`
   - `ToolContext(cwd:toolUseId:)` constructed for each call

3. **Agent tool pool assembly** (`Sources/OpenAgentSDK/Core/Agent.swift`) -- Key methods:
   - `assembleFullToolPool()` returns `([ToolProtocol], MCPClientManager?)` -- all tools including MCP tools
   - The method is `internal` so `AgentMCPServer` can call it from the same module
   - Tools include: built-in core tools + built-in specialist tools + custom user tools + MCP remote tools

### Architecture Compliance

- **MCP/ directory depends on Types/ + external mcp-swift-sdk** -- `AgentMCPServer.swift` goes in `Sources/OpenAgentSDK/MCP/`
- **MCP/ must NOT import Core/ or Tools/** -- But `AgentMCPServer` needs access to `Agent` (which is in Core/) and `ToolContext`/`ToolResult` (which are in Types/)
  - SOLUTION: Place `AgentMCPServer` in `Sources/OpenAgentSDK/MCP/` and import `Foundation` + `MCP`. Access `Agent` via a protocol or pass tools directly.
  - BEST APPROACH: `AgentMCPServer.run(agent:)` receives the pre-assembled tool pool as `[ToolProtocol]` rather than calling `agent.assembleFullToolPool()` internally. This avoids Core/ dependency from MCP/.
  - Alternative: Since all source files are in the same Swift module (`OpenAgentSDK`), internal access works without explicit imports. Place in `MCP/` for organization only.

- **Actor for shared mutable state** -- `AgentMCPServer` MUST be an actor (manages running tasks, shutdown state)
- **No Apple-proprietary frameworks** -- `StdioTransport` uses POSIX file descriptors, works on macOS + Linux
- **Error model** -- Tool execution errors in `ToolResult(isError: true)`, never throw from tool handler to crash the server
- **No force-unwrap** -- Use `guard let` / `if let` everywhere

### Key Design Decision: Where to Place AgentMCPServer

Since this project uses a single Swift module (`OpenAgentSDK`), all source files share the same namespace. The `MCP/` directory convention is organizational only -- internal types from `Core/` are accessible without imports. Therefore:

- **File location:** `Sources/OpenAgentSDK/MCP/AgentMCPServer.swift`
- **Can access:** `Agent`, `ToolProtocol`, `ToolContext`, `ToolResult`, `InProcessMCPServer` (for utility functions)
- **Must import:** `Foundation`, `MCP` (mcp-swift-sdk)

### AgentMCPServer API Design

```swift
// In MCP/AgentMCPServer.swift

/// Actor that exposes an Agent as an MCP stdio server.
///
/// External MCP clients (like Claude Code) can discover and invoke
/// the Agent's tools via the standard MCP protocol over stdin/stdout.
///
/// Usage:
/// ```swift
/// let agent = createAgent(options: myOptions)
/// let server = AgentMCPServer()
/// try await server.run(agent: agent)
/// ```
public actor AgentMCPServer {

    /// Runs the MCP server, exposing the Agent's tools via stdin/stdout.
    ///
    /// Blocks until stdin receives EOF or the connection is closed.
    /// - Parameter agent: The Agent whose tools to expose.
    public func run(agent: Agent) async throws
}
```

### How MCPServer.run(transport: .stdio) Works

From the mcp-swift-sdk source (`MCPServer.swift` line 464-475):
```swift
public func run(transport: TransportType) async throws {
    let session = await createSession()
    switch transport {
    case .stdio:
        let stdioTransport = StdioTransport()  // reads stdin, writes stdout
        try await session.start(transport: stdioTransport)
    case let .custom(customTransport):
        try await session.start(transport: customTransport)
    }
}
```

This handles ALL MCP protocol details automatically:
- Reads JSON-RPC from stdin
- Writes JSON-RPC to stdout
- Handles `initialize` handshake
- Dispatches `tools/list` and `tools/call` to registered handlers
- Returns server capabilities

### Tool Registration Pattern

Reuse the pattern from `InProcessMCPServer.getOrCreateMCPServer()`:

```swift
// For each ToolProtocol tool in the agent's pool:
try await mcpServer.register(
    name: tool.name,
    description: tool.description,
    inputSchema: schemaToValue(tool.inputSchema)
) { (args: [String: Value], context: HandlerContext) async throws -> String in
    let inputArgs = args.mapValues { mcpValueToAny($0) }
    let toolContext = ToolContext(cwd: agentCwd, toolUseId: UUID().uuidString)
    let result = await tool.call(input: inputArgs, context: toolContext)
    if result.isError {
        throw ToolExecutionError(message: result.content)
    }
    return result.content
}
```

### agent/prompt Custom Method Implementation

Instead of a true MCP custom method (which requires low-level protocol handling), implement as a special MCP tool:

```swift
// Register as a regular MCP tool
try await mcpServer.register(
    name: "agent_prompt",
    description: "Submit a task to the agent for full autonomous execution",
    inputSchema: .object([
        "type": "object",
        "properties": [
            "task": ["type": "string", "description": "The task for the agent to execute"]
        ],
        "required": ["task"]
    ] as [String: Any])
) { (args: [String: Value], context: HandlerContext) async throws -> String in
    guard let taskValue = args["task"], case .string(let task) = taskValue else {
        throw ToolExecutionError(message: "Missing required 'task' parameter")
    }
    // Use agent.prompt() for synchronous full execution
    let result = await agent.prompt(task)
    return result.output
}
```

### Graceful Shutdown Strategy

`MCPServer.run(transport: .stdio)` already blocks until EOF on stdin. The shutdown sequence:

1. External caller closes stdin (EOF)
2. `StdioTransport.readLoop()` detects EOF, breaks loop
3. `MCPServer` session ends, `run()` returns
4. `AgentMCPServer.run()` completes

For in-flight tool calls, the MCP server's session handles this -- when the session ends, pending requests are cancelled. No explicit 30-second timeout needed at the `AgentMCPServer` level because:
- Tool calls are synchronous within the MCP handler
- If a tool call hangs, the MCP client will eventually close stdin
- The `StdioTransport` disconnect will clean up

However, for the `agent/prompt` handler which may run long:
- Wrap `agent.prompt()` in a `withTaskGroup` or `Task` with a timeout
- Default timeout: 5 minutes (configurable)
- Return partial results on timeout

### File Locations

```
Sources/OpenAgentSDK/MCP/AgentMCPServer.swift                                    # NEW -- AgentMCPServer actor
Sources/OpenAgentSDK/OpenAgentSDK.swift                                           # MODIFY -- add DocC symbol reference
Tests/OpenAgentSDKTests/MCP/AgentMCPServerTests.swift                             # NEW -- unit tests
_bmad-output/implementation-artifacts/sprint-status.yaml                          # MODIFY -- status update
```

### Anti-Patterns to Avoid

- Do NOT reimplement MCP JSON-RPC parsing -- use `MCPServer` from mcp-swift-sdk
- Do NOT reimplement stdin/stdout I/O -- use `StdioTransport` from mcp-swift-sdk
- Do NOT create a custom Transport -- `MCPServer.run(transport: .stdio)` handles everything
- Do NOT duplicate `schemaToValue` / `mcpValueToAny` -- reference `InProcessMCPServer` but implement local copies (they are private in InProcessMCPServer)
- Do NOT import Core/ or Tools/ from MCP/ -- same-module access means no import needed
- Do NOT use force-unwrap (!) -- use guard let / if let
- Do NOT use Apple-proprietary APIs -- must work on macOS and Linux
- Do NOT block the MCP server on long-running agent tasks -- use structured concurrency
- Do NOT make AgentMCPServer a class or struct -- must be actor for shared mutable state
- Do NOT register tools/call handler manually -- use MCPServer.register() which handles dispatch

### Testing Requirements

- **New test file:** `Tests/OpenAgentSDKTests/MCP/AgentMCPServerTests.swift`
- **Pattern:** Use `InMemoryTransport` (from mcp-swift-sdk) for in-process testing, paired with `MCPClient`
- **Test categories:**
  - Tool discovery: verify registered tools match agent's tool pool
  - Tool execution: call a tool via MCP protocol and verify result
  - Error handling: verify tool errors returned with `isError: true`
  - agent/prompt: submit task and verify response
- **Testing approach:** Create an `MCPServer`, register tools, create a session with `InMemoryTransport`, connect an `MCPClient`, and verify `listTools()` / `callTool()` behavior
- **After implementation, run full test suite and report total count**

### Previous Story Intelligence

**From Story 19-1 (cross-run Memory Store):**
- Test count at completion: 4611 tests passing with 0 failures, 14 skipped
- `swift build` zero errors zero warnings
- Pattern for adding to OpenAgentSDK.swift DocC section: add bullet points to the appropriate section
- Adding fields to AgentOptions/ToolContext requires updating BOTH memberwise init AND `init(from config:)`
- Previous story added `MemoryStoreProtocol`, `InMemoryStore`, `FileBasedMemoryStore`, `KnowledgeEntry`, `KnowledgeQueryFilter` types

**From InProcessMCPServer (Epic 6):**
- `schemaToValue()` and `mcpValueToAny()` are private to `InProcessMCPServer` -- need local copies in `AgentMCPServer`
- `ToolExecutionError` is private -- need a local copy
- The conversion between `[String: Any]` and MCP `Value` is bidirectional and recursive
- MCPServer.register() can throw on duplicate tool names -- catch and log, don't crash

### Project Structure Notes

- New file `AgentMCPServer.swift` goes in `Sources/OpenAgentSDK/MCP/` (currently an empty directory reserved for this purpose)
- No Package.swift changes needed (all files are in the existing OpenAgentSDK target)
- No new dependencies needed (uses existing `MCP` module from mcp-swift-sdk)
- Test file goes in `Tests/OpenAgentSDKTests/MCP/` (create directory if needed)

### Claude Code Integration Example

After implementation, a user would integrate like this:

```swift
// In their CLI app's main.swift:
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(
    model: "claude-sonnet-4-6",
    tools: [MyCustomTool()],
    systemPrompt: "You are a helpful assistant."
))

let server = AgentMCPServer()
try await server.run(agent: agent)
```

Then in Claude Code's MCP config:
```json
{
  "mcpServers": {
    "my-agent": {
      "command": "/path/to/my-app",
      "args": ["mcp"]
    }
  }
}
```

### References

- [Source: Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift] -- MCPServer tool registration pattern, schemaToValue/mcpValueToAny conversion, ToolExecutionError
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift] -- MCPClient usage, mcpValueToSchema conversion, connection lifecycle
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:626] -- assembleFullToolPool() method (internal access)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:814] -- prompt() method for agent/prompt implementation
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1318] -- stream() method for streaming execution
- [Source: .build/checkouts/swift-mcp/Sources/MCP/Server/MCPServer.swift] -- MCPServer.run(transport: .stdio), register() API
- [Source: .build/checkouts/swift-mcp/Sources/MCP/Base/Transports/StdioTransport.swift] -- StdioTransport actor, stdin/stdout I/O
- [Source: .build/checkouts/swift-mcp/Sources/MCP/Base/Transports/InMemoryTransport.swift] -- For testing without real stdio
- [Source: _bmad-output/implementation-artifacts/19-1-cross-run-memory-store.md] -- Previous story learnings
- [Source: _bmad-output/project-context.md] -- Project rules (actor for shared state, module boundaries, no force-unwrap, cross-platform)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7

### Debug Log References

- Initial build failed due to: (1) using old MCPServer.register API signature that takes `(args: [String: Value], context:)` -- new API requires `Input: Codable & Sendable`, (2) Logger.error takes `(module, event)` not a single string.
- Fixed by using `[String: Value]` as Codable input type and correct Logger API.
- Test failures in `testAgentMCPServer_toolList_returnsAllTools` and `testAgentMCPServer_toolList_includesNameDescriptionSchema` because `agent_prompt` tool is always registered, making `.first` return it instead of user tools.
- Fixed tests to filter by tool name or account for `agent_prompt`.

### Completion Notes List

- Implemented `AgentMCPServer` as a public actor in `Sources/OpenAgentSDK/MCP/AgentMCPServer.swift`
- Leverages `MCPServer` from mcp-swift-sdk for all MCP protocol handling (initialize, tools/list, tools/call)
- Tools are passed directly to `AgentMCPServer` init (not via Agent reference), keeping MCP/ directory clean of Core/ dependencies
- `createSession()` creates in-process InMemoryTransport pairs for testing
- `run(agent:)` and `run()` provide stdio transport for CLI usage
- `agent_prompt` special tool is always registered with proper inputSchema
- Local copies of `schemaToValue`, `anyToMCPValue`, `mcpValueToAny` (InProcessMCPServer versions are private)
- Local `ToolExecutionError` struct (same as InProcessMCPServer)
- All 29 unit tests pass covering AC1-AC8
- Full test suite: 4640 tests passing, 14 skipped, 0 failures
- `swift build` zero errors zero warnings

### File List

- `Sources/OpenAgentSDK/MCP/AgentMCPServer.swift` -- NEW: AgentMCPServer actor
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` -- MODIFIED: added AgentMCPServer DocC reference
- `Tests/OpenAgentSDKTests/MCP/AgentMCPServerTests.swift` -- MODIFIED: fixed 3 tests for agent_prompt tool ordering
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- MODIFIED: status update
