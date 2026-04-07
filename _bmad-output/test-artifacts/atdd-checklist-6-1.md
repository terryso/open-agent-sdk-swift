---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-08'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/6-1-mcp-client-manager-stdio.md'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift'
  - 'Sources/OpenAgentSDK/Tools/ToolRegistry.swift'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ErrorTypes.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
---

# ATDD Checklist - Epic 6, Story 1: MCP Client Manager & Stdio Transport

**Date:** 2026-04-08
**Author:** Nick
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want to connect external MCP servers via stdio transport, so my Agent can use tools provided by external processes.

**As a** SDK developer
**I want** MCPClientManager actor with stdio transport support
**So that** agents can launch external MCP server processes, discover tools, and execute them through the stdio JSON-RPC transport

---

## Acceptance Criteria

1. **AC1: MCPClientManager Actor Creation** -- MCPClientManager actor initializes with `disconnected` state, empty connections dictionary (FR19).
2. **AC2: Stdio Transport Connection** -- `connect(name:config:)` launches external process via `Process`, completes MCPClient handshake, returns connection info (FR19).
3. **AC3: Process Lifecycle Management** -- Startup, crash recovery (no crash, mark error), and graceful shutdown (NFR19).
4. **AC4: Connection State Tracking** -- `connections` returns `[String: MCPManagedConnection]` with name, status, and tools (FR19).
5. **AC5: Tool Discovery** -- Auto `listTools()` after connect, tools wrapped as `mcp__{serverName}__{toolName}` (FR19, rule #10).
6. **AC6: MCP Tool Execution** -- `call()` dispatches via MCPClient, errors captured as `is_error: true` ToolResult (NFR17).
7. **AC7: Agent Integration** -- `AgentOptions.mcpServers` auto-connects via MCPClientManager, tools merged via `assembleToolPool()` (FR22).
8. **AC8: Multi-server Management** -- Independent servers, independent processes, independent lifecycle.
9. **AC9: Connection Failure Handling** -- Non-existent command marks `error`, no crash, empty tools (NFR19).
10. **AC10: Full Shutdown** -- `shutdown()` closes all MCPClients, terminates all child processes.
11. **AC11: Module Boundary** -- `Tools/MCP/` only imports Foundation, Types/, MCP (rules #7, #61).
12. **AC12: Cross-platform** -- `Process` on macOS, POSIX on Linux (NFR11, rule #36).
13. **AC13: API Key Security** -- CODEANY_API_KEY not leaked to child process (NFR6).
14. **AC14: Unit Test Coverage** -- Tests in `Tests/OpenAgentSDKTests/MCP/` covering init, namespace, state, multi-connection, shutdown, errors.
15. **AC15: E2E Test Coverage** -- E2E tests in `Sources/E2ETest/` covering MCPClientManager creation, connection status, tool listing.

---

## Failing Tests Created (RED Phase)

### Unit Tests -- MCPClientManagerTests (47 tests)

**File:** `Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift`

#### MCPConnectionStatus Types (3 tests)

- **Test:** testMCPConnectionStatus_hasAllCases
  - **Status:** RED - MCPConnectionStatus type not yet defined
  - **Verifies:** AC1 -- enum has connected, disconnected, error cases

- **Test:** testMCPConnectionStatus_isEquatable
  - **Status:** RED - MCPConnectionStatus type not yet defined
  - **Verifies:** AC1 -- conforms to Equatable

- **Test:** testMCPConnectionStatus_isSendable
  - **Status:** RED - MCPConnectionStatus type not yet defined
  - **Verifies:** AC1 -- conforms to Sendable

#### MCPManagedConnection Types (5 tests)

- **Test:** testMCPManagedConnection_creationWithEmptyTools
  - **Status:** RED - MCPManagedConnection type not yet defined
  - **Verifies:** AC1, AC4 -- can be created with name, status, empty tools

- **Test:** testMCPManagedConnection_creationWithConnectedStatus
  - **Status:** RED - MCPManagedConnection type not yet defined
  - **Verifies:** AC1 -- can be created with connected status

- **Test:** testMCPManagedConnection_isSendable
  - **Status:** RED - MCPManagedConnection type not yet defined
  - **Verifies:** AC1 -- conforms to Sendable

- **Test:** testMCPManagedConnection_holdsToolList
  - **Status:** RED - MCPManagedConnection, MCPToolDefinition types not yet defined
  - **Verifies:** AC4 -- holds tool list with correct namespace

- **Test:** testMCPManagedConnection_errorStatus_emptyTools
  - **Status:** RED - MCPManagedConnection type not yet defined
  - **Verifies:** AC4, AC9 -- error status with empty tools

#### MCPClientManager Initialization (2 tests)

- **Test:** testMCPClientManager_init_withEmptyConfig_hasNoConnections
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC1 -- initializes with empty connections

- **Test:** testMCPClientManager_isActor
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC1 -- is an actor (thread-safe)

#### MCPToolDefinition Namespace & Schema (8 tests)

- **Test:** testMCPToolDefinition_name_usesMcpNamespace
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- name follows mcp__{server}__{tool} pattern (rule #10)

- **Test:** testMCPToolDefinition_name_differentServerAndTool
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- namespace with different server/tool names

- **Test:** testMCPToolDefinition_schema_isPassedThrough
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- inputSchema is preserved

- **Test:** testMCPToolDefinition_description_isPassedThrough
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- description is preserved

- **Test:** testMCPToolDefinition_isReadOnly_returnsFalse
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- isReadOnly is false (matches TS SDK)

- **Test:** testMCPToolDefinition_call_withNilClient_returnsError
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC6 -- nil client returns error ToolResult

- **Test:** testMCPToolDefinition_call_neverThrows_malformedInput
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC6 -- never throws, always returns ToolResult

- **Test:** testMCPToolDefinition_conformsToToolProtocol
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- conforms to ToolProtocol

#### MCPToolDefinition Namespace Edge Cases (2 tests)

- **Test:** testMCPToolDefinition_name_hyphenatedServerName
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- hyphenated server name in namespace

- **Test:** testMCPToolDefinition_name_underscoredToolName
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC5 -- underscored tool name in namespace

#### MCPStdioTransport (3 tests)

- **Test:** testMCPStdioTransport_exists
  - **Status:** RED - MCPStdioTransport type not yet defined
  - **Verifies:** AC2 -- type exists as actor

- **Test:** testMCPStdioTransport_creationWithConfig
  - **Status:** RED - MCPStdioTransport type not yet defined
  - **Verifies:** AC2 -- can be created with McpStdioConfig

- **Test:** testMCPStdioTransport_creationWithEnv
  - **Status:** RED - MCPStdioTransport type not yet defined
  - **Verifies:** AC2 -- can be created with env vars

#### MCPClientManager Connection Management (7 tests)

- **Test:** testMCPClientManager_getConnections_returnsDictionary
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC4 -- getConnections returns [String: MCPManagedConnection]

- **Test:** testMCPClientManager_connectAll_withEmptyServers_hasNoConnections
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC8 -- connectAll with empty dict does nothing

- **Test:** testMCPClientManager_connect_invalidCommand_marksError
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC9 -- invalid command marks connection as error

- **Test:** testMCPClientManager_connect_failure_doesNotCrash
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC9 -- failure does not crash the manager

- **Test:** testMCPClientManager_connect_emptyCommand_marksError
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC9 -- empty command handled gracefully

- **Test:** testMCPClientManager_connect_specialCharsInName
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC9 -- special characters in server name

- **Test:** testMCPClientManager_multipleFailedConnections
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC8 -- multiple failed connections coexist

#### Shutdown & Cleanup (5 tests)

- **Test:** testMCPClientManager_shutdown_withNoConnections
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC10 -- shutdown with no connections succeeds

- **Test:** testMCPClientManager_shutdown_clearsConnections
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC10 -- shutdown clears all connections

- **Test:** testMCPClientManager_shutdown_afterMultipleFailures
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC10 -- shutdown after multiple failures cleans up

- **Test:** testMCPClientManager_disconnect_nonExistent_doesNotCrash
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC10 -- disconnect non-existent does not crash

- **Test:** testMCPClientManager_disconnect_oneServer_doesNotAffectOther
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC8 -- disconnect one server does not affect others

#### getMCPTools (2 tests)

- **Test:** testMCPClientManager_getMCPTools_withNoConnections_returnsEmpty
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC5 -- empty tools with no connections

- **Test:** testMCPClientManager_getMCPTools_withFailedConnection_returnsEmpty
  - **Status:** RED - MCPClientManager type not yet defined
  - **Verifies:** AC5 -- failed connections contribute no tools

#### API Key Security (2 tests)

- **Test:** testMCPStdioTransport_doesNotLeakApiKeyByDefault
  - **Status:** RED - MCPStdioTransport type not yet defined
  - **Verifies:** AC13 -- CODEANY_API_KEY not leaked to child process

- **Test:** testMCPStdioTransport_passesExplicitEnvVars
  - **Status:** RED - MCPStdioTransport type not yet defined
  - **Verifies:** AC13 -- explicit env vars are passed

#### Module Boundary (1 test)

- **Test:** testMCPToolDefinition_worksWithOnlyTypesDependencies
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC11 -- only uses Types/ dependencies

#### Agent Integration (3 tests)

- **Test:** testAgentOptions_mcpServers_defaultIsNil
  - **Status:** GREEN (existing code) - mcpServers defaults to nil
  - **Verifies:** AC7 -- mcpServers defaults to nil

- **Test:** testAgentOptions_mcpServers_canBeSetWithStdio
  - **Status:** GREEN (existing code) - McpServerConfig.stdio works
  - **Verifies:** AC7 -- mcpServers can be set with stdio config

- **Test:** testAgentOptions_mcpServers_canHoldMultipleServers
  - **Status:** GREEN (existing code) - multiple servers work
  - **Verifies:** AC7 -- multiple servers supported

#### assembleToolPool Integration (2 tests)

- **Test:** testAssembleToolPool_mergesMCPTools
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC7 -- MCP tools merge with base tools via assembleToolPool

- **Test:** testAssembleToolPool_mcpToolsDeduplicate
  - **Status:** RED - MCPToolDefinition type not yet defined
  - **Verifies:** AC7 -- MCP tools are deduplicated

#### SDKError Integration (2 tests)

- **Test:** testSDKError_mcpConnectionError_exists
  - **Status:** GREEN (existing code) - mcpConnectionError already defined
  - **Verifies:** AC9 -- SDKError.mcpConnectionError exists

- **Test:** testSDKError_mcpConnectionError_hasDescription
  - **Status:** GREEN (existing code) - error description works
  - **Verifies:** AC9 -- mcpConnectionError has proper description

#### McpServerConfig & McpStdioConfig (4 tests)

- **Test:** testMcpStdioConfig_commandOnly
  - **Status:** GREEN (existing code) - McpStdioConfig exists
  - **Verifies:** AC2 -- McpStdioConfig with command only

- **Test:** testMcpStdioConfig_allParameters
  - **Status:** GREEN (existing code) - all parameters work
  - **Verifies:** AC2 -- McpStdioConfig with all parameters

- **Test:** testMcpServerConfig_stdioCase
  - **Status:** GREEN (existing code) - .stdio case exists
  - **Verifies:** AC2 -- McpServerConfig.stdio wraps McpStdioConfig

- **Test:** testMcpServerConfig_isEquatable
  - **Status:** GREEN (existing code) - Equatable conformance
  - **Verifies:** AC2 -- McpServerConfig is Equatable

#### Cross-platform (1 test)

- **Test:** testMCPStdioTransport_usesFoundationProcess
  - **Status:** RED - MCPStdioTransport type not yet defined
  - **Verifies:** AC12 -- uses Foundation Process (cross-platform)

#### MCPToolDefinition call() with mock client (3 tests)

- **Test:** testMCPToolDefinition_call_success_returnsToolResult
  - **Status:** RED - MCPToolDefinition, MCPClientProtocol not yet defined
  - **Verifies:** AC6 -- successful call returns non-error ToolResult

- **Test:** testMCPToolDefinition_call_clientError_returnsErrorToolResult
  - **Status:** RED - MCPToolDefinition, MCPClientProtocol not yet defined
  - **Verifies:** AC6 -- client error returns error ToolResult

- **Test:** testMCPToolDefinition_call_preservesToolUseId
  - **Status:** RED - MCPToolDefinition, MCPClientProtocol not yet defined
  - **Verifies:** AC6 -- toolUseId is preserved in result

---

## Implementation Checklist

### Task 1: Define MCPConnectionStatus and MCPManagedConnection (AC: #1, #4)

**File:** `Sources/OpenAgentSDK/Types/MCPTypes.swift` (new file)

**Tasks to make type existence tests pass:**

- [ ] Define `MCPConnectionStatus` enum with cases: `connected`, `disconnected`, `error`
- [ ] Conform `MCPConnectionStatus` to `Equatable`, `Sendable`
- [ ] Define `MCPManagedConnection` struct with `name: String`, `status: MCPConnectionStatus`, `tools: [ToolProtocol]`
- [ ] Conform `MCPManagedConnection` to `Sendable`
- [ ] Run tests: `swift test --filter MCPClientManagerTests/testMCPConnectionStatus` and `testMCPManagedConnection`

### Task 2: Implement MCPStdioTransport (AC: #2, #3, #12, #13)

**File:** `Sources/OpenAgentSDK/Tools/MCP/MCPStdioTransport.swift` (new file)

**Tasks to make MCPStdioTransport tests pass:**

- [ ] Implement `MCPStdioTransport` actor in `Tools/MCP/`
- [ ] Accept `McpStdioConfig` (command, args, env) in init
- [ ] Use Foundation `Process` to launch child process with stdin/stdout Pipe
- [ ] Implement `getChildEnvironment()` method that returns child process environment (for API key tests)
- [ ] Filter out `CODEANY_API_KEY` from child environment unless explicitly in config.env
- [ ] Pass explicitly configured env vars
- [ ] Only import Foundation and MCP (mcp-swift-sdk)
- [ ] Run tests: `swift test --filter MCPClientManagerTests/testMCPStdioTransport`

### Task 3: Implement MCPToolDefinition wrapper (AC: #5, #6, #11)

**File:** `Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift` (new file)

**Tasks to make MCPToolDefinition tests pass:**

- [ ] Define `MCPClientProtocol` protocol (or use mcp-swift-sdk's protocol)
- [ ] Implement `MCPToolDefinition` struct conforming to `ToolProtocol, Sendable`
- [ ] `name` returns `mcp__{serverName}__{mcpToolName}` namespace
- [ ] `inputSchema` passes through MCP server's schema
- [ ] `isReadOnly` returns false (matches TS SDK)
- [ ] `call()` delegates to `mcpClient.callTool()`, captures errors as `ToolResult(isError: true)`
- [ ] Handle nil mcpClient gracefully
- [ ] Only import Foundation and Types/
- [ ] Run tests: `swift test --filter MCPClientManagerTests/testMCPToolDefinition`

### Task 4: Implement MCPClientManager actor (AC: #1, #2, #4, #8, #9, #10)

**File:** `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` (new file)

**Tasks to make MCPClientManager tests pass:**

- [ ] Implement `MCPClientManager` actor
- [ ] `init()` -- empty connections
- [ ] `connect(name:config:)` -- launch process, create MCPClient, handshake, discover tools
- [ ] `connectAll(servers:)` -- batch connect
- [ ] `disconnect(name:)` -- close single connection
- [ ] `shutdown()` -- close all connections, terminate all processes
- [ ] `getConnections()` -- return [String: MCPManagedConnection]
- [ ] `getMCPTools()` -- return [ToolProtocol] from all connected servers
- [ ] Handle connection failures gracefully (error status, no crash)
- [ ] Only import Foundation, Types/, MCP
- [ ] Run tests: `swift test --filter MCPClientManagerTests/testMCPClientManager`

### Task 5: Integrate into Agent (AC: #7)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tasks to make agent integration work:**

- [ ] Check `options.mcpServers` before tool execution
- [ ] Create MCPClientManager lazily if mcpServers is non-nil
- [ ] Call `connectAll()` to connect all servers
- [ ] Get MCP tools via `getMCPTools()` and merge via `assembleToolPool()`
- [ ] Call `shutdown()` at end of query to clean up

### Task 6: Update module entry (AC: #11)

**File:** `Sources/OpenAgentSDK/OpenAgentSDK.swift`

- [ ] Add documentation references for MCPClientManager, MCPToolDefinition, MCPStdioTransport

### Task 7: Compile verification

- [ ] Run `swift build` to confirm compilation passes
- [ ] Verify `Tools/MCP/` files only import Foundation, Types/, MCP
- [ ] Run `swift test --filter MCPClientManagerTests` to verify all tests pass (GREEN phase)

### Task 8: E2E tests (AC: #15)

**Files:** `Sources/E2ETest/`

- [ ] Add MCPClientManager E2E section covering creation, connection status, tool listing
- [ ] Use lightweight echo MCP server or mock

---

## Running Tests

```bash
# Run all failing tests for this story (will fail until implementation)
swift test --filter MCPClientManagerTests

# Build only (verify compilation)
swift build

# Build tests (verify RED phase failures)
swift build --build-tests
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and designed to fail
- Test file follows established patterns (McpResourceToolTests, ToolRegistryTests)
- Implementation checklist created with task-to-test mapping
- 47 total tests covering 15 acceptance criteria (AC1-AC15)
- Mock MCPClientProtocol and MockMCPClient included for testing
- MCPTestError enum for mock error scenarios

**Verification:**

- Tests fail due to missing types (MCPConnectionStatus, MCPManagedConnection, MCPToolDefinition, MCPStdioTransport, MCPClientManager, MCPClientProtocol)
- Failure messages are clear: "cannot find type in scope" or "use of unresolved identifier"
- Tests fail due to missing implementation, not test bugs
- Build confirmed: `swift build --build-tests` produces expected RED phase errors

---

### GREEN Phase (DEV Team - Next Steps)

1. **Start with Task 1** (types) -- makes MCPConnectionStatus, MCPManagedConnection tests pass
2. **Task 2** (MCPStdioTransport) -- makes transport tests pass
3. **Task 3** (MCPToolDefinition) -- makes namespace, schema, call tests pass
4. **Task 4** (MCPClientManager) -- makes manager init, connect, disconnect, shutdown tests pass
5. **Tasks 5-6** (Agent integration + docs) -- makes integration tests pass
6. **Task 7** (compile verification) -- all tests pass
7. **Task 8** (E2E) -- covers AC15

---

## Acceptance Criteria Coverage Matrix

| AC | Description | Test Methods |
|----|-------------|-------------|
| AC1 | MCPClientManager Actor Creation | testMCPConnectionStatus_hasAllCases, testMCPConnectionStatus_isEquatable, testMCPConnectionStatus_isSendable, testMCPManagedConnection_creationWithEmptyTools, testMCPManagedConnection_creationWithConnectedStatus, testMCPManagedConnection_isSendable, testMCPClientManager_init_withEmptyConfig_hasNoConnections, testMCPClientManager_isActor |
| AC2 | Stdio Transport Connection | testMCPStdioTransport_exists, testMCPStdioTransport_creationWithConfig, testMCPStdioTransport_creationWithEnv, testMcpStdioConfig_commandOnly, testMcpStdioConfig_allParameters, testMcpServerConfig_stdioCase, testMcpServerConfig_isEquatable |
| AC3 | Process Lifecycle | (covered by AC9 error handling and AC10 shutdown tests) |
| AC4 | Connection State Tracking | testMCPClientManager_getConnections_returnsDictionary, testMCPManagedConnection_holdsToolList, testMCPManagedConnection_errorStatus_emptyTools |
| AC5 | Tool Discovery | testMCPToolDefinition_name_usesMcpNamespace, testMCPToolDefinition_name_differentServerAndTool, testMCPToolDefinition_schema_isPassedThrough, testMCPToolDefinition_description_isPassedThrough, testMCPToolDefinition_isReadOnly_returnsFalse, testMCPToolDefinition_conformsToToolProtocol, testMCPToolDefinition_name_hyphenatedServerName, testMCPToolDefinition_name_underscoredToolName, testMCPClientManager_getMCPTools_withNoConnections_returnsEmpty, testMCPClientManager_getMCPTools_withFailedConnection_returnsEmpty |
| AC6 | MCP Tool Execution | testMCPToolDefinition_call_withNilClient_returnsError, testMCPToolDefinition_call_neverThrows_malformedInput, testMCPToolDefinition_call_success_returnsToolResult, testMCPToolDefinition_call_clientError_returnsErrorToolResult, testMCPToolDefinition_call_preservesToolUseId |
| AC7 | Agent Integration | testAgentOptions_mcpServers_defaultIsNil, testAgentOptions_mcpServers_canBeSetWithStdio, testAgentOptions_mcpServers_canHoldMultipleServers, testAssembleToolPool_mergesMCPTools, testAssembleToolPool_mcpToolsDeduplicate |
| AC8 | Multi-server Management | testMCPClientManager_connectAll_withEmptyServers_hasNoConnections, testMCPClientManager_multipleFailedConnections, testMCPClientManager_disconnect_oneServer_doesNotAffectOther |
| AC9 | Connection Failure Handling | testMCPClientManager_connect_invalidCommand_marksError, testMCPClientManager_connect_failure_doesNotCrash, testMCPClientManager_connect_emptyCommand_marksError, testMCPClientManager_connect_specialCharsInName, testSDKError_mcpConnectionError_exists, testSDKError_mcpConnectionError_hasDescription |
| AC10 | Full Shutdown | testMCPClientManager_shutdown_withNoConnections, testMCPClientManager_shutdown_clearsConnections, testMCPClientManager_shutdown_afterMultipleFailures, testMCPClientManager_disconnect_nonExistent_doesNotCrash |
| AC11 | Module Boundary | testMCPToolDefinition_worksWithOnlyTypesDependencies |
| AC12 | Cross-platform | testMCPStdioTransport_usesFoundationProcess |
| AC13 | API Key Security | testMCPStdioTransport_doesNotLeakApiKeyByDefault, testMCPStdioTransport_passesExplicitEnvVars |
| AC14 | Unit Test Coverage | (this document IS the coverage) |
| AC15 | E2E Test Coverage | (created in GREEN phase in Sources/E2ETest/) |

---

## Notes

- MCPClientManager is an actor (thread-safe, manages shared mutable connection state)
- MCPToolDefinition uses `mcp__{serverName}__{toolName}` namespace (architecture rule #10)
- MCPToolDefinition.call() captures ALL errors as ToolResult(isError: true), never throws (rule #38/#39)
- MCPStdioTransport uses Foundation Process for cross-platform support (rule #43)
- MCPClientProtocol abstraction allows mocking for unit tests
- nonisolated(unsafe) may be needed for schema dictionary constants (lesson from Story 5-7)
- Story 6-1 is the foundation for Epic 6 -- stories 6-2, 6-3, 6-4 depend on this
- Tests use `@testable import OpenAgentSDK` to access internal types
- MockMCPClient, MCPClientProtocol, MCPTestError defined in test file for isolation

---

**Generated by BMad TEA Agent** - 2026-04-08
