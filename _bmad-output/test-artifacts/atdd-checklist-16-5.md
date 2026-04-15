---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-15'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/16-5-mcp-integration-compat.md'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
  - 'Sources/OpenAgentSDK/Types/MCPTypes.swift'
  - 'Sources/OpenAgentSDK/Types/MCPResourceTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Tests/OpenAgentSDKTests/Compat/HookSystemCompatTests.swift'
  - 'Examples/CompatHooks/main.swift'
---

# ATDD Checklist - Epic 16, Story 16-5: MCP Integration Compatibility Verification

**Date:** 2026-04-15
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As an SDK developer, I want to verify that Swift SDK's MCP integration supports all TypeScript SDK server configuration types and runtime management operations, so that all MCP usage patterns can be migrated from TypeScript to Swift.

**Key scope:**
- 5 TS MCP server config types (4 have Swift equivalents, 1 missing)
- 4 MCP runtime management operations (1 partial, 3 missing)
- McpServerStatus type verification (3 vs 5 status values)
- MCP tool namespace verification (PASS)
- MCP resource operations verification (PASS)
- AgentMcpServerSpec verification (MISSING -- no subagent MCP support)
- Compatibility report output

**Out of scope (other stories):**
- Story 16-1: Core Query API compatibility (complete)
- Story 16-2: Tool system compatibility (complete)
- Story 16-3: Message types compatibility (complete)
- Story 16-4: Hook system compatibility (complete)
- Future: Adding missing MCP config types/operations to SDK

---

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- `CompatMCP` executable target in Package.swift, `swift build` passes
2. **AC2: 5 McpServerConfig type verification** -- stdio PASS, sse PASS, http PASS, sdk PARTIAL (concrete vs generic), claudeai-proxy MISSING
3. **AC3: MCP runtime management operations verification** -- getConnections PARTIAL (not on Agent API), reconnectMcpServer MISSING, toggleMcpServer MISSING, setMcpServers MISSING
4. **AC4: McpServerStatus type verification** -- 3 status values vs 5 (connected PASS, failed->error PARTIAL, needs-auth/pending/disabled MISSING); MCPManagedConnection 3 fields vs 7 (name+status+tools present, serverInfo/error/config/scope MISSING)
5. **AC5: MCP tool namespace verification** -- mcp__{serverName}__{toolName} PASS, precondition for __ PASS
6. **AC6: MCP resource operations verification** -- MCPResourceItem 3 fields PASS, ListMcpResources/ReadMcpResource schema PASS, MCPReadResult/MCPContentItem PASS
7. **AC7: AgentMcpServerSpec verification** -- AgentDefinition has no mcpServers field (MISSING: string reference and inline config modes)
8. **AC8: Compatibility report output** -- per-item compatibility status for all types and operations

---

## Failing Tests Created (ATDD Verification)

### Unit Tests -- MCPIntegrationCompatTests (69 tests)

**File:** `Tests/OpenAgentSDKTests/Compat/MCPIntegrationCompatTests.swift`

#### AC2: McpServerConfig Type Verification (20 tests)

- **Test:** `testMcpStdioConfig_hasCommandField` [P0] -- command field matches TS McpStdioServerConfig.command
- **Test:** `testMcpStdioConfig_hasArgsField` [P0] -- args field matches TS McpStdioServerConfig.args
- **Test:** `testMcpStdioConfig_hasEnvField` [P0] -- env field matches TS McpStdioServerConfig.env
- **Test:** `testMcpStdioConfig_defaultsArgsAndEnvToNil` [P0] -- defaults match TS optional args/env
- **Test:** `testMcpServerConfig_hasStdioCase` [P0] -- McpServerConfig.stdio wraps McpStdioConfig
- **Test:** `testMcpSseConfig_hasUrlField` [P0] -- url field matches TS McpSSEServerConfig.url
- **Test:** `testMcpSseConfig_hasHeadersField` [P0] -- headers field matches TS McpSSEServerConfig.headers
- **Test:** `testMcpSseConfig_defaultsHeadersToNil` [P0] -- headers default nil matches TS
- **Test:** `testMcpServerConfig_hasSseCase` [P0] -- McpServerConfig.sse wraps McpSseConfig
- **Test:** `testMcpHttpConfig_hasUrlField` [P0] -- url field matches TS McpHttpServerConfig.url
- **Test:** `testMcpHttpConfig_hasHeadersField` [P0] -- headers field matches TS McpHttpServerConfig.headers
- **Test:** `testMcpHttpConfig_defaultsHeadersToNil` [P0] -- headers default nil matches TS
- **Test:** `testMcpServerConfig_hasHttpCase` [P0] -- McpServerConfig.http wraps McpHttpConfig
- **Test:** `testMcpSdkServerConfig_hasNameField` [P0] -- name field matches TS McpSdkServerConfigWithInstance.name
- **Test:** `testMcpSdkServerConfig_hasServerInstanceField` [P0] -- server (instance) field (PARTIAL: concrete vs generic)
- **Test:** `testMcpSdkServerConfig_hasExtraVersionField` [PARTIAL] -- version is Swift-only field
- **Test:** `testMcpServerConfig_hasSdkCase` [P0] -- McpServerConfig.sdk wraps McpSdkServerConfig
- **Test:** `testMcpServerConfig_claudeAiProxy_gap` [GAP] -- No Swift equivalent for claudeai-proxy
- **Test:** `testMcpServerConfig_hasExactlyFourCases` [P0] -- 4 of 5 TS types have Swift equivalents
- **Test:** `testMcpTransportConfig_sharedBySseAndHttp` [P0] -- Both use McpTransportConfig alias
- **Test:** `testMcpServerConfig_coverageSummary` [P0] -- 3 PASS + 1 PARTIAL + 1 MISSING

#### AC3: MCP Runtime Management Operations Verification (7 tests)

- **Test:** `testMCPClientManager_getConnections_available` [PARTIAL] -- exists but not on Agent API
- **Test:** `testMCPClientManager_reconnectMcpServer_gap` [GAP] -- MISSING from Swift SDK
- **Test:** `testMCPClientManager_toggleMcpServer_gap` [GAP] -- MISSING from Swift SDK
- **Test:** `testMCPClientManager_setMcpServers_gap` [GAP] -- MISSING from Swift SDK
- **Test:** `testMCPClientManager_connect_individualServer` [P0] -- connect(name:config:) works
- **Test:** `testMCPClientManager_connectAll_batchConnection` [P0] -- connectAll(servers:) works
- **Test:** `testMCPClientManager_disconnect_individualServer` [P0] -- disconnect(name:) works
- **Test:** `testMCPClientManager_shutdown_fullCleanup` [P0] -- shutdown() works
- **Test:** `testMCPRuntimeOperations_coverageSummary` [P0] -- 1 PARTIAL + 3 MISSING

#### AC4: McpServerStatus Type Verification (12 tests)

- **Test:** `testMCPConnectionStatus_hasConnected` [P0] -- matches TS "connected"
- **Test:** `testMCPConnectionStatus_hasError_mapsToTSFailed` [P0] -- maps to TS "failed" (different name)
- **Test:** `testMCPConnectionStatus_needsAuth_gap` [GAP] -- TS "needs-auth" MISSING
- **Test:** `testMCPConnectionStatus_pending_gap` [GAP] -- TS "pending" MISSING
- **Test:** `testMCPConnectionStatus_disabled_gap` [GAP] -- TS "disabled" MISSING
- **Test:** `testMCPConnectionStatus_hasDisconnected_swiftExtra` [P0] -- Swift-only "disconnected"
- **Test:** `testMCPConnectionStatus_hasThreeCases` [P0] -- 3 values vs TS 5
- **Test:** `testMCPManagedConnection_hasNameField` [P0] -- name PASS
- **Test:** `testMCPManagedConnection_hasStatusField` [P0] -- status PASS (3 vs 5 values)
- **Test:** `testMCPManagedConnection_hasToolsField` [P0] -- tools PASS (no annotations)
- **Test:** `testMCPManagedConnection_serverInfo_gap` [GAP] -- serverInfo MISSING
- **Test:** `testMCPManagedConnection_errorField_gap` [GAP] -- error MISSING
- **Test:** `testMCPManagedConnection_configField_gap` [GAP] -- config MISSING
- **Test:** `testMCPManagedConnection_scopeField_gap` [GAP] -- scope MISSING
- **Test:** `testMCPManagedConnection_fieldCount` [P0] -- 3 fields vs TS 7

#### AC5: MCP Tool Namespace Verification (5 tests)

- **Test:** `testMCPToolDefinition_usesMcpNamespace` [P0] -- mcp__{server}__{tool} PASS
- **Test:** `testMCPToolDefinition_namespace_hyphenatedServer` [P0] -- hyphenated server name
- **Test:** `testMCPToolDefinition_namespace_underscoredTool` [P0] -- underscored tool name
- **Test:** `testMCPToolDefinition_rejectsDoubleUnderscoreServerName` [P0] -- precondition guard
- **Test:** `testMCPToolDefinition_conformsToToolProtocol` [P0] -- ToolProtocol conformance

#### AC6: MCP Resource Operations Verification (9 tests)

- **Test:** `testMCPResourceItem_hasNameField` [P0] -- name field PASS
- **Test:** `testMCPResourceItem_hasDescriptionField` [P0] -- description field PASS
- **Test:** `testMCPResourceItem_hasUriField` [P0] -- uri field PASS
- **Test:** `testListMcpResources_schema_hasServerField` [P0] -- ListMcpResources schema PASS
- **Test:** `testReadMcpResource_schema_hasServerAndUriFields` [P0] -- ReadMcpResource schema PASS
- **Test:** `testMCPReadResult_hasContentsField` [P0] -- MCPReadResult.contents PASS
- **Test:** `testMCPContentItem_hasTextField` [P0] -- MCPContentItem.text PASS
- **Test:** `testMCPContentItem_hasRawValueField` [P0] -- MCPContentItem.rawValue PASS
- **Test:** `testMCPConnectionInfo_hasRequiredFields` [P0] -- MCPConnectionInfo fields PASS
- **Test:** `testMCPResourceProvider_protocol` [P0] -- MCPResourceProvider listResources/readResource PASS

#### AC7: AgentMcpServerSpec Verification (4 tests)

- **Test:** `testAgentDefinition_noMcpServersProperty` [GAP] -- no mcpServers field
- **Test:** `testAgentDefinition_hasExistingFields` [P0] -- name, description, model, etc.
- **Test:** `testAgentDefinition_cannotReferenceParentMcpServers` [GAP] -- string reference MISSING
- **Test:** `testAgentDefinition_cannotDefineInlineMcpConfigs` [GAP] -- inline config MISSING

#### AC8: Compatibility Report Output (5 tests)

- **Test:** `testCompatReport_configTypeCoverage` [P0] -- 5-row config type table
- **Test:** `testCompatReport_runtimeOperationsCoverage` [P0] -- 4-row runtime operations table
- **Test:** `testCompatReport_connectionStatusCoverage` [P0] -- 5-row status values table
- **Test:** `testCompatReport_managedConnectionFieldCoverage` [P0] -- 7-row field table
- **Test:** `testCompatReport_agentMcpServerSpecCoverage` [P0] -- 2-mode vs 0-mode gap

---

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Build compilation verification | (example story, not testable here) | P0 |
| AC2 | 5 McpServerConfig type verification | 21 tests (16 pass + 1 partial + 1 gap + 3 summary) | P0 |
| AC3 | Runtime management operations verification | 9 tests (4 pass + 1 partial + 3 gap + 1 summary) | P0 |
| AC4 | McpServerStatus type verification | 15 tests (6 pass + 5 gap + 4 field verification) | P0 |
| AC5 | MCP tool namespace verification | 5 tests (all pass) | P0 |
| AC6 | MCP resource operations verification | 10 tests (all pass) | P0 |
| AC7 | AgentMcpServerSpec verification | 4 tests (1 pass + 3 gap) | P0 |
| AC8 | Compatibility report output | 5 tests (all pass) | P0 |

**Total: 69 tests covering all acceptance criteria (AC2-AC8).**

---

## Test Strategy

### Stack Detection
- **Detected:** Backend (Swift Package with XCTest, no frontend/browser testing)
- **Mode:** AI Generation (acceptance criteria are clear, standard API verification scenarios)

### Test Levels
- **Unit Tests (69):** Pure type-level verification tests using Mirror introspection for gap detection, MCPClientManager actor interactions, and schema validation

### Priority Distribution
- **P0 (Critical):** 69 tests -- all tests verify core MCP integration compatibility

---

## TDD Phase Validation

- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] All tests compile and pass against existing SDK APIs (verification story, not new feature)
- [x] Each test has clear Given/When/Then structure
- [x] Tests document compatibility gaps inline with [GAP] markers
- [x] Build verification: `swift build --build-tests` succeeds with zero errors
- [x] Test execution: All 69 tests pass (0 failures)
- [x] Full suite regression: All 3402 tests pass (14 skipped, 0 failures)

---

## Compatibility Gaps Documented

### Missing MCP Config Type (1 of 5 TS types has NO Swift equivalent)

| # | TS SDK Config Type | Status | Recommendation |
|---|-------------------|--------|----------------|
| 5 | McpClaudeAIProxyServerConfig (claudeai-proxy) | MISSING | Add .claudeAiProxy case with url, id fields |

### PARTIAL McpSdkServerConfig Match

| Aspect | TS SDK | Swift SDK | Gap |
|--------|--------|-----------|-----|
| instance type | Generic any tool provider | Concrete InProcessMCPServer actor | Swift requires concrete type |
| version field | Not present | Has version: String | Swift-only extra field |

### Missing MCP Runtime Operations (3 of 4 TS operations MISSING)

| # | TS SDK Operation | Status | Recommendation |
|---|-----------------|--------|----------------|
| 1 | mcpServerStatus() | PARTIAL | getConnections() exists but not on Agent API |
| 2 | reconnectMcpServer(name) | MISSING | Add reconnect(name:) to MCPClientManager |
| 3 | toggleMcpServer(name, enabled) | MISSING | Add toggle(name:enabled:) to MCPClientManager |
| 4 | setMcpServers(servers) | MISSING | Add setMcpServers(servers:) returning added/removed/errors |

### Missing MCPConnectionStatus Values (3 of 5 TS values MISSING)

| TS Status | Swift Equivalent | Status |
|-----------|-----------------|--------|
| connected | .connected | PASS |
| failed | .error | PARTIAL (different name) |
| needs-auth | -- | MISSING |
| pending | -- | MISSING |
| disabled | -- | MISSING |

### Missing MCPManagedConnection Fields (4 of 7 TS fields MISSING)

| TS Field | Swift Equivalent | Status |
|----------|-----------------|--------|
| name | name: String | PASS |
| status | status: MCPConnectionStatus | PARTIAL (3 vs 5 values) |
| tools | tools: [ToolProtocol] | PARTIAL (no annotations access) |
| serverInfo | -- | MISSING |
| error | -- | MISSING |
| config | -- | MISSING |
| scope | -- | MISSING |

### Missing AgentMcpServerSpec (entire feature MISSING)

| TS SDK Mode | Swift Equivalent | Status |
|------------|-----------------|--------|
| String reference to parent server | -- | MISSING |
| Inline config record | -- | MISSING |

### Summary

- **Config Type Coverage:** 3/5 PASS (60%), 1/5 PARTIAL (20%), 1/5 MISSING (20%)
- **Runtime Operations:** 0/4 PASS, 1/4 PARTIAL (25%), 3/4 MISSING (75%)
- **Connection Status:** 1/5 PASS (20%), 1/5 PARTIAL (20%), 3/5 MISSING (60%)
- **ManagedConnection Fields:** 1/7 PASS (14%), 2/7 PARTIAL (29%), 4/7 MISSING (57%)
- **Tool Namespace:** Full match (mcp__server__tool)
- **Resource Operations:** Full match (MCPResourceItem, ListMcpResources, ReadMcpResource)
- **AgentMcpServerSpec:** 0/2 modes (entirely missing)

---

## Implementation Guidance

### Files Created
1. `Tests/OpenAgentSDKTests/Compat/MCPIntegrationCompatTests.swift` -- 69 ATDD tests

### Files to Create (Story Implementation)
1. `Examples/CompatMCP/main.swift` -- Compatibility verification example
2. Update `Package.swift` -- Add CompatMCP executable target

### Key Implementation Notes
- Example should follow CompatCoreQuery/CompatHooks pattern: CompatEntry, record(), bilingual comments
- Use `nonisolated(unsafe)` for mutable global report state
- Use `loadDotEnv()` / `getEnv()` for API key loading
- Use `permissionMode: .bypassPermissions` to simplify example
- MCPClientManager is an actor -- all calls require `await`
- InProcessMCPServer is an actor -- all calls require `await`
- McpSseConfig and McpHttpConfig are typealiases for McpTransportConfig
- MCPToolDefinition has precondition guard against double underscore in server name
- Report should output 6 compatibility tables: config types, runtime ops, status values, managed connection fields, tool namespace, agent spec

---

## Next Steps (Story Implementation)

1. Create `Examples/CompatMCP/main.swift` using the verification patterns tested here
2. Add `CompatMCP` executable target to `Package.swift`
3. Run `swift build` to verify example compiles
4. Run `swift run CompatMCP` to generate compatibility report
5. Verify all 69 ATDD tests still pass after implementation
6. Run full test suite to verify no regressions
