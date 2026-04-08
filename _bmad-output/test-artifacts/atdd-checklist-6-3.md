---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-08'
workflowType: testarch-atdd
inputDocuments:
  - _bmad-output/implementation-artifacts/6-3-in-process-mcp-server.md
  - Sources/OpenAgentSDK/Types/MCPConfig.swift
  - Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift
  - Sources/E2ETest/MCPClientManagerTests.swift
---

# ATDD Checklist - Epic 6, Story 3: In-Process MCP Server

**Date:** 2026-04-08
**Author:** Nick
**Primary Test Level:** Unit (XCTest) + E2E (custom harness)

---

## Story Summary

Story 6.3 adds an in-process MCP server capability that lets developers expose Agent tools as an MCP server, so external MCP clients can use those tools. It also provides an SDK-internal mode where tools are injected directly into the tool pool without MCP protocol overhead.

**As a** developer
**I want** to expose Agent tools as an MCP server
**So that** external MCP clients can use my tools

---

## Acceptance Criteria

1. **AC1:** InProcessMCPServer creation with name, version, tools
2. **AC2:** McpServerConfig.sdk configuration generation
3. **AC3:** Tools exposed as MCP protocol via InMemoryTransport
4. **AC4:** Tool execution dispatch to ToolProtocol.call()
5. **AC5:** Tool namespace (original names, no prefix)
6. **AC6:** Agent integration (SDK internal mode)
7. **AC7:** Session creation and lifecycle
8. **AC8:** Unknown tool handling (isError: true)
9. **AC9:** Module boundary compliance (Foundation, MCP, Types/ only)
10. **AC10:** Unit test coverage verification
11. **AC11:** E2E test coverage
12. **AC12:** Error handling (tool exceptions captured as isError: true)

---

## Test Strategy

**Detected Stack:** Backend (Swift Package Manager, XCTest)

**Test Levels:**
- **Unit Tests (XCTest):** InProcessMCPServer actor, McpSdkServerConfig, McpServerConfig.sdk, tool exposure, execution dispatch, error handling, module boundary
- **E2E Tests (custom harness):** Full MCP session lifecycle via InMemoryTransport, tool listing, tool invocation, AgentOptions integration

**Priority Distribution:**
- P0: Critical path (creation, session, tool list, tool call, unknown tool, error handling, config, agent integration) -- 26 tests
- P1: Important but secondary (independent sessions, empty tools, schema, edge cases, special chars) -- 9 tests

---

## Failing Tests Created (RED Phase)

### Unit Tests (30 tests)

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift` (~530 lines)

- **Test:** `testInProcessMCPServer_creation_withNameVersionTools`
  - **AC:** AC1 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Server creation with name, version, and tools

- **Test:** `testInProcessMCPServer_creation_withEmptyTools`
  - **AC:** AC1 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Server creation with empty tools list

- **Test:** `testInProcessMCPServer_creation_withMultipleTools`
  - **AC:** AC1 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Server creation with multiple tools

- **Test:** `testInProcessMCPServer_isActor`
  - **AC:** AC1 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** InProcessMCPServer is an actor (thread-safe)

- **Test:** `testMcpSdkServerConfig_creation`
  - **AC:** AC2 [P0]
  - **Status:** RED -- `McpSdkServerConfig` type does not exist yet
  - **Verifies:** Config creation with name, version, server reference

- **Test:** `testMcpServerConfig_sdkCase`
  - **AC:** AC2 [P0]
  - **Status:** RED -- `McpServerConfig.sdk` case does not exist yet
  - **Verifies:** McpServerConfig.sdk wraps McpSdkServerConfig

- **Test:** `testMcpServerConfig_sdk_isDistinctFromOtherCases`
  - **AC:** AC2 [P0]
  - **Status:** RED -- `McpServerConfig.sdk` case does not exist yet
  - **Verifies:** sdk case distinct from stdio, sse, http

- **Test:** `testInProcessMCPServer_asConfig_returnsSdkConfig`
  - **AC:** AC2 [P0]
  - **Status:** RED -- `InProcessMCPServer.asConfig()` does not exist yet
  - **Verifies:** asConfig() returns McpServerConfig.sdk

- **Test:** `testInProcessMCPServer_toolList_viaInMemoryTransport`
  - **AC:** AC3 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Tools exposed through MCP protocol via InMemoryTransport

- **Test:** `testInProcessMCPServer_multipleTools_viaInMemoryTransport`
  - **AC:** AC3 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Multiple tools exposed through MCP protocol

- **Test:** `testInProcessMCPServer_toolList_includesInputSchema`
  - **AC:** AC3 [P1]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Exposed tools include inputSchema

- **Test:** `testInProcessMCPServer_toolCall_dispatchesToTool`
  - **AC:** AC4 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Tool call dispatches to ToolProtocol.call()

- **Test:** `testInProcessMCPServer_toolCall_returnsMCPResult`
  - **AC:** AC4 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Tool call result returned through MCP protocol

- **Test:** `testInProcessMCPServer_toolName_noNamespacePrefix`
  - **AC:** AC5 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Tools use original names (no mcp__ prefix) via MCP

- **Test:** `testInProcessMCPServer_getTools_returnsRegisteredTools`
  - **AC:** AC6 [P0]
  - **Status:** RED -- `InProcessMCPServer.getTools()` does not exist yet
  - **Verifies:** getTools() returns all registered tools

- **Test:** `testAgentOptions_mcpServers_acceptsSdkConfig`
  - **AC:** AC6 [P0]
  - **Status:** RED -- `McpServerConfig.sdk` case does not exist yet
  - **Verifies:** AgentOptions.mcpServers accepts sdk config

- **Test:** `testMcpServerConfig_mixedTypes_withSdk`
  - **AC:** AC6 [P0]
  - **Status:** RED -- `McpServerConfig.sdk` case does not exist yet
  - **Verifies:** AgentOptions holds mixed config types including sdk

- **Test:** `testInProcessMCPServer_createSession_returnsPair`
  - **AC:** AC7 [P0]
  - **Status:** RED -- `InProcessMCPServer.createSession()` does not exist yet
  - **Verifies:** createSession returns (Server, InMemoryTransport)

- **Test:** `testInProcessMCPServer_createSession_multipleSessions`
  - **AC:** AC7 [P0]
  - **Status:** RED -- `InProcessMCPServer.createSession()` does not exist yet
  - **Verifies:** Multiple independent sessions can be created

- **Test:** `testInProcessMCPServer_sessions_operateIndependently`
  - **AC:** AC7 [P1]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Each session operates independently

- **Test:** `testInProcessMCPServer_unknownTool_returnsError`
  - **AC:** AC8 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Unknown tool call returns isError: true

- **Test:** `testInProcessMCPServer_unknownTool_doesNotCrashServer`
  - **AC:** AC8 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Unknown tool does not crash the server

- **Test:** `testInProcessMCPServer_respectsModuleBoundary`
  - **AC:** AC9 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** No imports of Core/ or Stores/ (compile-time check)

- **Test:** `testMcpSdkServerConfig_isSendable`
  - **AC:** AC10 [P0]
  - **Status:** RED -- `McpSdkServerConfig` type does not exist yet
  - **Verifies:** McpSdkServerConfig conforms to Sendable

- **Test:** `testInProcessMCPServer_toolExecutionException_returnsError`
  - **AC:** AC12 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Tool exceptions captured as isError: true

- **Test:** `testInProcessMCPServer_toolExecutionException_serverRemainsOperational`
  - **AC:** AC12 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Server remains operational after tool exception

- **Test:** `testInProcessMCPServer_defaultVersion`
  - **AC:** AC1 [P1]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Default version is "1.0.0"

- **Test:** `testInProcessMCPServer_createSession_emptyTools`
  - **AC:** AC7 [P1]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Empty tools server session does not crash

- **Test:** `testInProcessMCPServer_toolWithUnderscoreName`
  - **AC:** AC5 [P1]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Tools with underscore names work correctly

- **Test:** `testMcpSdkServerConfig_specialCharsInName`
  - **AC:** AC2 [P1]
  - **Status:** RED -- `McpSdkServerConfig` type does not exist yet
  - **Verifies:** Special characters in server name handled

- **Test:** `testAssembleToolPool_includesSdkTools`
  - **AC:** AC6 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** assembleToolPool includes SDK server tools

### E2E Tests (19 tests)

**File:** `Sources/E2ETest/MCPClientManagerTests.swift` (added to existing file, ~400 lines added)

- **Test:** `testInProcessMCPServerCreation`
  - **AC:** AC1 [P0]
  - **Status:** RED -- `InProcessMCPServer` type does not exist yet
  - **Verifies:** Server creation with name, version, tools

- **Test:** `testInProcessMCPServerCreationWithMultipleTools`
  - **AC:** AC1 [P0]
  - **Status:** RED
  - **Verifies:** Multiple tools registration

- **Test:** `testMcpSdkServerConfigCreation`
  - **AC:** AC2 [P0]
  - **Status:** RED
  - **Verifies:** McpSdkServerConfig creation

- **Test:** `testMcpServerConfigSdkCase`
  - **AC:** AC2 [P0]
  - **Status:** RED
  - **Verifies:** McpServerConfig.sdk case

- **Test:** `testMcpServerConfigSdkDistinctFromOthers`
  - **AC:** AC2 [P0]
  - **Status:** RED
  - **Verifies:** sdk distinct from stdio/sse/http

- **Test:** `testInProcessMCPServerAsConfig`
  - **AC:** AC2 [P0]
  - **Status:** RED
  - **Verifies:** asConfig() returns .sdk

- **Test:** `testInProcessMCPServerGetTools`
  - **AC:** AC6 [P0]
  - **Status:** RED
  - **Verifies:** getTools() returns registered tools

- **Test:** `testInProcessMCPServerCreateSession`
  - **AC:** AC7 [P0]
  - **Status:** RED
  - **Verifies:** createSession() returns pair

- **Test:** `testInProcessMCPServerMultipleSessions`
  - **AC:** AC7 [P0]
  - **Status:** RED
  - **Verifies:** Multiple sessions created independently

- **Test:** `testInProcessMCPServerEmptyToolsSession`
  - **AC:** AC7 [P1]
  - **Status:** RED
  - **Verifies:** Empty tools session works

- **Test:** `testInProcessMCPServerToolListViaMCP`
  - **AC:** AC3 [P0]
  - **Status:** RED
  - **Verifies:** Tools exposed via MCP protocol

- **Test:** `testInProcessMCPServerToolNamesNoNamespace`
  - **AC:** AC5 [P0]
  - **Status:** RED
  - **Verifies:** Original tool names (no prefix)

- **Test:** `testInProcessMCPServerToolCallDispatchesToTool`
  - **AC:** AC4 [P0]
  - **Status:** RED
  - **Verifies:** Tool call dispatches correctly

- **Test:** `testInProcessMCPServerUnknownToolReturnsError`
  - **AC:** AC8 [P0]
  - **Status:** RED
  - **Verifies:** Unknown tool returns error

- **Test:** `testInProcessMCPServerToolExceptionReturnsError`
  - **AC:** AC12 [P0]
  - **Status:** RED
  - **Verifies:** Exception captured as isError: true

- **Test:** `testInProcessMCPServerResilientAfterException`
  - **AC:** AC12 [P0]
  - **Status:** RED
  - **Verifies:** Server remains operational after exception

- **Test:** `testAgentOptionsAcceptsSdkConfig`
  - **AC:** AC6 [P0]
  - **Status:** RED
  - **Verifies:** AgentOptions accepts sdk config

- **Test:** `testAgentOptionsMixedConfigTypesWithSdk`
  - **AC:** AC6 [P0]
  - **Status:** RED
  - **Verifies:** Mixed config types with sdk

- **Test:** `testInProcessMCPServerRespectsModuleBoundary`
  - **AC:** AC9 [P0]
  - **Status:** RED
  - **Verifies:** Module boundary compliance

---

## Mock Requirements

### MockTool (Unit Tests)

Used by unit tests to provide a controllable `ToolProtocol` implementation.

- Returns configurable `resultContent` and `resultIsError`
- Never throws
- Defined in `InProcessMCPServerTests.swift`

### MockThrowingTool (Unit Tests)

Simulates a tool that encounters an error during execution.

- Returns `ToolResult(isError: true)` with error description
- Never throws (follows rule #38)
- Defined in `InProcessMCPServerTests.swift`

### E2EMockTool (E2E Tests)

Mock tool for E2E harness testing.

- Returns configurable content
- Defined in `Sources/E2ETest/MCPClientManagerTests.swift`

### E2EThrowingMockTool (E2E Tests)

Mock tool that simulates execution failure.

- Returns `ToolResult(isError: true)`
- Defined in `Sources/E2ETest/MCPClientManagerTests.swift`

---

## Implementation Checklist

### Test: AC1 - InProcessMCPServer Creation

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] Create `Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift`
- [ ] Define `InProcessMCPServer` actor with `name`, `version`, `tools` properties
- [ ] Implement `init(name:version:tools:cwd:)` with default version "1.0.0"
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC1 tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: AC2 - McpServerConfig.sdk Configuration

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] Add `McpSdkServerConfig` struct to `Sources/OpenAgentSDK/Types/MCPConfig.swift`
- [ ] Add `.sdk(McpSdkServerConfig)` case to `McpServerConfig` enum
- [ ] Ensure `Sendable` and `Equatable` conformance
- [ ] Implement `InProcessMCPServer.asConfig()` method
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC2 tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: AC3/AC4/AC5 - MCP Protocol Tool Exposure & Execution

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement `createSession()` returning `(Server, InMemoryTransport)`
- [ ] Use mcp-swift-sdk's `MCPServer` for tool registration
- [ ] Convert `ToolProtocol.inputSchema` to MCP `Value` format
- [ ] Register `ListTools` handler
- [ ] Register `CallTool` handler dispatching to `ToolProtocol.call()`
- [ ] Convert `ToolResult` to MCP `CallTool.Result`
- [ ] Ensure tool names have no namespace prefix
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC3/AC4/AC5 tests pass (green phase)

**Estimated Effort:** 2 hours

---

### Test: AC6 - Agent Integration

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] Add `getTools()` method returning `[ToolProtocol]`
- [ ] Ensure `AgentOptions.mcpServers` accepts `.sdk` config type
- [ ] Verify `assembleToolPool` works with SDK tools
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC6 tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: AC7 - Session Lifecycle

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement `createSession()` with proper `MCPServer.createSession()` delegation
- [ ] Ensure multiple sessions are independent
- [ ] Handle empty tools in session
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC7 tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: AC8 - Unknown Tool Handling

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] In `CallTool` handler, check tool exists before dispatching
- [ ] Return MCP error for unknown tool names
- [ ] Ensure server stays operational after unknown tool call
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC8 tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: AC12 - Error Handling

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make these tests pass:**

- [ ] Wrap `ToolProtocol.call()` in try/catch in CallTool handler
- [ ] Capture exceptions as `isError: true` MCP response
- [ ] Ensure server remains operational after tool exception
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] All AC12 tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: AC9 - Module Boundary

**File:** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`

**Tasks to make this test pass:**

- [ ] Ensure `InProcessMCPServer.swift` only imports Foundation, MCP, Types/
- [ ] Do NOT import Core/, Stores/, or other internal modules
- [ ] Verify at compile time (test compiles = boundary respected)
- [ ] Run unit tests: `swift test --filter InProcessMCPServerTests`
- [ ] AC9 test passes (green phase)

**Estimated Effort:** 0.25 hours

---

## Running Tests

```bash
# Run all unit tests for this story
swift test --filter InProcessMCPServerTests

# Run all MCP-related tests
swift test --filter MCP

# Run E2E tests (requires .env setup)
swift run E2ETest

# Build only (check compilation)
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and failing
- Mock tools created (MockTool, MockThrowingTool, E2EMockTool, E2EThrowingMockTool)
- ATDD checklist created
- Implementation checklist created

**Verification:**

- All tests will fail due to missing types (InProcessMCPServer, McpSdkServerConfig, McpServerConfig.sdk)
- Failure messages are clear: "Cannot find 'InProcessMCPServer' in scope" etc.
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. Start with AC1 (InProcessMCPServer creation)
2. Then AC2 (McpServerConfig.sdk)
3. Then AC7 (session creation)
4. Then AC3/AC4/AC5 (MCP protocol tool exposure/execution/namespacing)
5. Then AC8 (unknown tool handling)
6. Then AC12 (error handling)
7. Then AC6 (Agent integration)
8. Then AC9 (module boundary - verify during implementation)

---

### REFACTOR Phase (After All Tests Pass)

1. Verify all tests pass
2. Review code quality (readability, maintainability)
3. Extract schema conversion logic if duplicated
4. Ensure no duplications with MCPClientManager patterns
5. Run all tests after each refactor

---

## Acceptance Criteria Coverage Matrix

| AC | Unit Tests | E2E Tests | Priority |
|----|-----------|-----------|----------|
| AC1 (Creation) | 4 tests | 2 tests | P0 |
| AC2 (Config) | 5 tests | 5 tests | P0 |
| AC3 (Tool Exposure) | 3 tests | 2 tests | P0 |
| AC4 (Tool Execution) | 2 tests | 1 test | P0 |
| AC5 (Namespace) | 1 test | 1 test | P0 |
| AC6 (Agent Integration) | 4 tests | 2 tests | P0 |
| AC7 (Session Lifecycle) | 3 tests | 3 tests | P0 |
| AC8 (Unknown Tool) | 2 tests | 1 test | P0 |
| AC9 (Module Boundary) | 1 test | 1 test | P0 |
| AC10 (Unit Test Coverage) | 1 test | -- | P0 |
| AC11 (E2E Coverage) | -- | (19 E2E tests) | P0 |
| AC12 (Error Handling) | 2 tests | 2 tests | P0 |

**Total:** 30 unit tests + 19 E2E tests = 49 tests

---

## Notes

- All mock tools follow the project convention of returning `ToolResult` (never throwing), consistent with architecture rule #38
- `nonisolated(unsafe)` used for `ToolInputSchema` dictionaries, consistent with Story 6-1 patterns
- Tests use `InMemoryTransport.createConnectedPair()` for realistic MCP protocol testing without network
- Module boundary tests are compile-time checks -- if the file compiles without forbidden imports, the boundary is respected
- The E2E mock tools (`E2EMockTool`, `E2EThrowingMockTool`) are separate from unit test mocks because the E2E target cannot access `@testable import`
- MCPClient and InMemoryTransport types are from mcp-swift-sdk dependency

---

**Generated by BMad TEA Agent** - 2026-04-08
