---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-05-12'
storyId: '19.2'
storyKey: '19-2-agent-as-mcp-server'
storyFile: '_bmad-output/implementation-artifacts/19-2-agent-as-mcp-server.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-19-2-agent-as-mcp-server.md'
generatedTestFiles:
  - 'Tests/OpenAgentSDKTests/MCP/AgentMCPServerTests.swift'
inputDocuments:
  - '_bmad-output/project-context.md'
  - '_bmad-output/implementation-artifacts/19-2-agent-as-mcp-server.md'
  - 'Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift'
  - 'Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift'
---

# ATDD Checklist: Story 19.2 -- Agent-as-MCP-Server

## TDD Red Phase (Current)

**Status:** RED -- Test scaffolds generated. All tests will fail to compile until `AgentMCPServer` is implemented.

- **Unit Tests:** 24 tests (all will fail to compile -- `AgentMCPServer` type does not exist yet)
- **Execution Mode:** Sequential (backend Swift project, no browser testing needed)
- **Test Framework:** XCTest (Swift built-in)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Coverage | Status |
|----|-------------|----------|---------------|--------|
| AC1 | AgentMCPServer class defined | P0 | `testAgentMCPServer_creation_*` (4 tests) | RED |
| AC2 | MCP initialize handshake | P0 | `testAgentMCPServer_initializeHandshake_*` (2 tests) | RED |
| AC3 | tools/list response | P0 | `testAgentMCPServer_toolList_*` (5 tests) | RED |
| AC4 | tools/call dispatch | P0 | `testAgentMCPServer_toolCall_*` (5 tests) | RED |
| AC5 | agent/prompt custom method | P0 | `testAgentMCPServer_agentPrompt_*` (4 tests) | RED |
| AC6 | Graceful shutdown on EOF | P0 | `testAgentMCPServer_gracefulShutdown_*` (2 tests) | RED |
| AC7 | Claude Code MCP config compat | P0 | `testAgentMCPServer_claudeCodeCompat_*` (1 test) | RED |
| AC8 | Unit tests (module boundary) | P0 | `testAgentMCPServer_respectsModuleBoundary`, `testAgentMCPServer_isPublicActor` | RED |
| AC9 | Build and test pass | P0 | Verified by full test suite run after implementation | N/A |

## Test Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 20 | Critical path -- must pass for story acceptance |
| P1 | 5 | Important but not blocking |
| P2 | 2 | Nice-to-have coverage |
| **Total** | **27** | |

## Generated Files

| File | Type | Test Count |
|------|------|------------|
| `Tests/OpenAgentSDKTests/MCP/AgentMCPServerTests.swift` | Unit Tests | 24 test methods + 2 mock tool classes |

## Test Approach

- **In-process testing:** Uses `InMemoryTransport` (from mcp-swift-sdk) to avoid real stdio I/O
- **Pattern:** Create `AgentMCPServer`, call `createSession()` to get a connected `(Server, InMemoryTransport)` pair, connect an MCP `Client`, then verify protocol behavior via `listTools()` / `callTool()`
- **Mock tools:** `AgentMCPServerMockTool` (configurable result/error) and `AgentMCPServerEchoArgTool` (echoes arguments back for verification)
- **Follows existing pattern:** Mirrors `InProcessMCPServerTests.swift` structure and conventions

## Architecture Notes

- `AgentMCPServer` must be a `public actor` in `Sources/OpenAgentSDK/MCP/`
- Must use `MCPServer` + `InMemoryTransport` from `mcp-swift-sdk`
- Reuses `schemaToValue()` / `mcpValueToAny()` conversion patterns from `InProcessMCPServer`
- No Apple-proprietary frameworks (cross-platform)
- No force-unwrap (`!`) -- use `guard let` / `if let`

## Next Steps (Task-by-Task Activation)

During implementation:

1. Create `Sources/OpenAgentSDK/MCP/AgentMCPServer.swift` with the `AgentMCPServer` actor
2. Tests will start compiling once the type exists
3. Run `swift build` to verify compilation
4. Run `swift test --filter AgentMCPServerTests` to see red test results
5. Implement features task by task:
   - Task 1: Basic actor + `createSession()` (AC1, AC2)
   - Task 2: Tool registration + tools/list (AC3)
   - Task 3: tools/call dispatch (AC4)
   - Task 4: agent/prompt tool (AC5)
   - Task 5: Graceful shutdown (AC6)
6. After each task, re-run tests to verify green progress
7. Run full test suite after all tasks complete
8. Commit passing tests

## Implementation Guidance

### Key Types to Create

```
Sources/OpenAgentSDK/MCP/AgentMCPServer.swift
  - public actor AgentMCPServer
  - init(name:version:tools:)
  - public var name: String
  - public var version: String
  - public func createSession() async throws -> (Server, InMemoryTransport)
```

### Key Patterns to Reuse (from InProcessMCPServer)

- `MCPServer(name:version:)` creation
- `server.register(name:description:inputSchema:)` for tool registration
- `schemaToValue()` / `mcpValueToAny()` for JSON schema conversion
- `ToolExecutionError` for error propagation
- `createSession()` -> `InMemoryTransport.createConnectedPair()` pattern

### No Changes Needed

- Package.swift (same target)
- No new dependencies (uses existing MCP module)
