---
title: 'Thread-safe MCP connections + dynamic stream permissions'
type: 'bugfix'
created: '2026-04-14'
status: 'done'
baseline_commit: '31405b8'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/deferred-work.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Two deferred bugs from code reviews: (1) `mcpConnections` is a `nonisolated(unsafe)` file-level global — genuinely mutable shared state that data-races under concurrent multi-agent usage; (2) `stream()` captures `permissionMode`/`canUseTool` once at stream creation, so calling `setPermissionMode()` or `setCanUseTool()` mid-stream has no effect, unlike the `prompt()` path which reads fresh values each turn.

**Approach:** Move MCP connections into `ToolContext` to eliminate global mutable state entirely. In the stream path, read `self.options.permissionMode` and `self.options.canUseTool` at each tool-execution point instead of using captured locals.

## Boundaries & Constraints

**Always:** Maintain backward compatibility — `setMcpConnections()` public API must remain. ToolContext is a value type (`Sendable struct`); adding a field preserves that.

**Ask First:** None expected — all changes are localized and non-controversial.

**Never:** Do not change Agent to an actor. Do not add async overhead to the MCP connection read path. Do not modify other `nonisolated(unsafe)` vars outside the MCP tools scope.

## I/O & Edge-Case Matrix

### Goal 1: MCP connections via ToolContext

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Agent sets MCP connections then calls tool | `setMcpConnections([conn])` then ListMcpResources | Tool sees the connections | N/A |
| No MCP connections set, tool called | `mcpConnections` field is nil | "No MCP servers connected." | N/A |
| ReadMcpResource with server filter | `mcpConnections` has 2 servers, filter matches 1 | Returns correct server's resource | N/A |
| Backward compat: no ToolContext mcpConnections | Old code path without field | Falls back to nil, tools show "No MCP servers connected" | N/A |

### Goal 2: Dynamic permissions in stream

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Change permissionMode mid-stream | `setPermissionMode(.restrictive)` during active stream | Next tool execution uses restrictive mode | N/A |
| Change canUseTool mid-stream | `setCanUseTool(myCallback)` during active stream | Next tool execution invokes myCallback | N/A |
| No mid-stream change | Stream runs without setPermissionMode calls | Same behavior as before (reads from options) | N/A |

</frozen-after-approval>

## Code Map

- `Sources/OpenAgentSDK/Types/ToolTypes.swift` — ToolContext struct (add `mcpConnections` field)
- `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` — global `mcpConnections` var, `setMcpConnections()`, read in ListMcpResources closure
- `Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift` — read `mcpConnections` in ReadMcpResource closure
- `Sources/OpenAgentSDK/Core/Agent.swift` — stream() captures permissionMode/canUseTool (lines ~722-723), creates ToolContext (lines ~1260-1280); prompt() reads fresh (lines ~581-582)
- `Tests/OpenAgentSDKTests/Tools/Specialist/ListMcpResourcesToolTests.swift` — existing tests
- `Tests/OpenAgentSDKTests/Tools/Specialist/ReadMcpResourceToolTests.swift` — existing tests

## Tasks & Acceptance

**Execution:**

- [x] `Sources/OpenAgentSDK/Types/ToolTypes.swift` — Add `public let mcpConnections: [MCPConnectionInfo]?` field to ToolContext, add to init parameters (after `sandbox`, before closing paren). Default value `nil`.
- [x] `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` — Remove `nonisolated(unsafe) var mcpConnections` global. Keep `setMcpConnections()` as a no-op stub for backward compat. Update tool closure to read from `context.mcpConnections ?? []` instead of global.
- [x] `Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift` — Update tool closure to read from `context.mcpConnections ?? []` instead of global.
- [x] `Sources/OpenAgentSDK/Core/Agent.swift` — In ToolContext creation sites (both `prompt()` ~line 581 and `stream()` ~line 1260), pass `mcpConnections: nil`. In stream(), remove `capturedPermissionMode` and `capturedCanUseTool` locals; read `self.options.permissionMode` and `self.options.canUseTool` directly at ToolContext creation point.
- [x] `Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift` — Update tests to pass MCP connections via ToolContext instead of relying on global state. Add test verifying nil mcpConnections returns "No MCP servers connected."

**Acceptance Criteria:**
- Given MCP connections set via ToolContext, when ListMcpResources tool is called, then it lists the connections correctly
- Given no MCP connections in ToolContext (nil), when ListMcpResources tool is called, then it returns "No MCP servers connected."
- Given a mid-stream call to `setPermissionMode(.restrictive)`, when the next tool executes in the stream, then the restrictive mode is applied
- Given a mid-stream call to `setCanUseTool(callback)`, when the next tool executes in the stream, then the callback is invoked
- Given `swift build`, then it compiles with no errors
- Given `swift test`, then all tests pass

## Spec Change Log

## Design Notes

**Why ToolContext instead of actor for MCP connections:** ToolContext is a `Sendable` value type — no synchronization overhead, no async boundary, and each tool execution gets an immutable snapshot. This is strictly better than a lock or actor for read-heavy access patterns where writes happen only during agent setup.

**Why read `self.options` directly in stream instead of capturing:** `Agent` is a reference type (`class`). The stream closure already captures `self` for many other reads (e.g., `sessionMemory`). Reading `self.options.permissionMode` at each tool execution point follows the same pattern and makes dynamic permission changes effective immediately, matching the `prompt()` path behavior.

## Verification

**Commands:**
- `swift build` -- expected: clean build with no errors
- `swift test` -- expected: all tests pass

## Suggested Review Order

**MCP connections: global state eliminated, ToolContext injection**

- New `mcpConnections` field with nil default preserves backward compat
  [`ToolTypes.swift:103`](../../Sources/OpenAgentSDK/Types/ToolTypes.swift#L103)

- Global `nonisolated(unsafe) var` replaced with no-op backward-compat stub
  [`ListMcpResourcesTool.swift:7`](../../Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift#L7)

- Tool closure reads from context instead of global — thread-safe snapshot
  [`ListMcpResourcesTool.swift:52`](../../Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift#L52)

- Same pattern for ReadMcpResource — reads from context
  [`ReadMcpResourceTool.swift:62`](../../Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift#L62)

**Stream path: dynamic permission changes**

- Captured locals replaced with live reads; comment explains trade-off
  [`Agent.swift:724`](../../Sources/OpenAgentSDK/Core/Agent.swift#L724)

- Stream ToolContext reads fresh permissionMode/canUseTool at each turn
  [`Agent.swift:1276`](../../Sources/OpenAgentSDK/Core/Agent.swift#L1276)

**Tests**

- Tests updated to inject via ToolContext; new nil-connections test added
  [`McpResourceToolTests.swift:17`](../../Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift#L17)
