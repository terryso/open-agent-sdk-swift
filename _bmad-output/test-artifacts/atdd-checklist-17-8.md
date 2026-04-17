---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-17'
storyId: '17-8'
storyTitle: 'MCP Integration Enhancement'
tddPhase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-8-mcp-integration-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
  - 'Sources/OpenAgentSDK/Types/MCPTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Tests/OpenAgentSDKTests/Compat/MCPIntegrationCompatTests.swift'
---

# ATDD Checklist: Story 17-8 MCP Integration Enhancement

## Preflight Summary

- **Story:** 17-8 MCP Integration Enhancement
- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Mode:** AI Generation (backend, no browser)
- **TDD Phase:** RED (failing tests before implementation)

## Acceptance Criteria -> Test Mapping

### AC1: McpServerConfig.claudeAIProxy(url:id:) configuration case

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 1.1 | McpClaudeAIProxyConfig has url and id fields | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 1.2 | McpClaudeAIProxyConfig init with url and id | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 1.3 | McpClaudeAIProxyConfig conforms to Sendable | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 1.4 | McpClaudeAIProxyConfig conforms to Equatable | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 1.5 | McpServerConfig has .claudeAIProxy case | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 1.6 | McpServerConfig.claudeAIProxy wraps McpClaudeAIProxyConfig | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 1.7 | McpServerConfig now has exactly 5 cases | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |

### AC2: mcpServerStatus() async method on Agent

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 2.1 | Agent has mcpServerStatus() async method | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 2.2 | mcpServerStatus() returns empty dict when no MCP configured | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 2.3 | mcpServerStatus() returns [String: McpServerStatus] | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |

### AC3: reconnectMcpServer(name:) async throws method on Agent

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 3.1 | Agent has reconnectMcpServer(name:) async throws method | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 3.2 | reconnectMcpServer throws when server not found | Unit | P1 | MCPIntegrationEnhancementATDDTests.swift | RED |

### AC4: toggleMcpServer(name:enabled:) async throws method on Agent

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 4.1 | Agent has toggleMcpServer(name:enabled:) async throws method | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 4.2 | toggleMcpServer throws when server not found | Unit | P1 | MCPIntegrationEnhancementATDDTests.swift | RED |

### AC5: setMcpServers() async throws with McpServerUpdateResult

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 5.1 | Agent has setMcpServers(_:) async throws -> McpServerUpdateResult | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 5.2 | McpServerUpdateResult has added, removed, errors fields | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 5.3 | McpServerUpdateResult conforms to Sendable and Equatable | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 5.4 | setMcpServers with no prior MCP returns all as added | Unit | P1 | MCPIntegrationEnhancementATDDTests.swift | RED |

### AC6: McpServerStatus struct with 5 status values

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 6.1 | McpServerStatusEnum has .connected case | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.2 | McpServerStatusEnum has .failed case | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.3 | McpServerStatusEnum has .needsAuth case | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.4 | McpServerStatusEnum has .pending case | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.5 | McpServerStatusEnum has .disabled case | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.6 | McpServerStatusEnum has exactly 5 cases | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.7 | McpServerStatusEnum conforms to Sendable and Equatable | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.8 | McpServerStatus has name field | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.9 | McpServerStatus has status field (McpServerStatusEnum) | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.10 | McpServerStatus has serverInfo field (optional) | Unit | P1 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.11 | McpServerStatus has error field (optional String) | Unit | P1 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.12 | McpServerStatus has tools field | Unit | P1 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.13 | McpServerStatus conforms to Sendable | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |
| 6.14 | McpServerStatus init with all fields | Unit | P0 | MCPIntegrationEnhancementATDDTests.swift | RED |

## Test File Summary

| File | Tests | Classes |
|---|---|---|
| MCPIntegrationEnhancementATDDTests.swift | 30 | 4 |
| **Total** | **30** | **4** |

## TDD Red Phase Status

- **30 tests FAIL** (RED -- new types and methods not yet implemented)
- All failures are EXPECTED (TDD red phase)
- **4055 baseline tests** (from 17-7 completion)
- **0 regressions** expected in existing tests

### RED Tests (30 failures, all expected)

1. `testMcpClaudeAIProxyConfig_hasUrlAndIdFields` - McpClaudeAIProxyConfig type does not exist
2. `testMcpClaudeAIProxyConfig_initWithUrlAndId` - McpClaudeAIProxyConfig init does not exist
3. `testMcpClaudeAIProxyConfig_conformsToSendable` - McpClaudeAIProxyConfig type does not exist
4. `testMcpClaudeAIProxyConfig_conformsToEquatable` - McpClaudeAIProxyConfig type does not exist
5. `testMcpServerConfig_hasClaudeAIProxyCase` - .claudeAIProxy case does not exist on McpServerConfig
6. `testMcpServerConfig_claudeAIProxy_wrapsConfig` - .claudeAIProxy case does not exist
7. `testMcpServerConfig_hasExactlyFiveCases` - McpServerConfig currently has 4 cases
8. `testAgent_hasMcpServerStatusMethod` - mcpServerStatus() method does not exist on Agent
9. `testAgent_mcpServerStatus_returnsEmptyWhenNoMCP` - mcpServerStatus() method does not exist
10. `testAgent_mcpServerStatus_returnsCorrectType` - mcpServerStatus() method does not exist
11. `testAgent_hasReconnectMcpServerMethod` - reconnectMcpServer(name:) does not exist on Agent
12. `testAgent_reconnectMcpServer_throwsWhenServerNotFound` - reconnectMcpServer(name:) does not exist
13. `testAgent_hasToggleMcpServerMethod` - toggleMcpServer(name:enabled:) does not exist on Agent
14. `testAgent_toggleMcpServer_throwsWhenServerNotFound` - toggleMcpServer(name:enabled:) does not exist
15. `testAgent_hasSetMcpServersMethod` - setMcpServers(_:) does not exist on Agent
16. `testMcpServerUpdateResult_hasAddedRemovedErrorsFields` - McpServerUpdateResult type does not exist
17. `testMcpServerUpdateResult_conformsToSendableAndEquatable` - McpServerUpdateResult type does not exist
18. `testAgent_setMcpServers_returnsAllAdded_whenNoPriorMCP` - setMcpServers does not exist
19. `testMcpServerStatusEnum_hasConnectedCase` - McpServerStatusEnum type does not exist
20. `testMcpServerStatusEnum_hasFailedCase` - McpServerStatusEnum type does not exist
21. `testMcpServerStatusEnum_hasNeedsAuthCase` - McpServerStatusEnum type does not exist
22. `testMcpServerStatusEnum_hasPendingCase` - McpServerStatusEnum type does not exist
23. `testMcpServerStatusEnum_hasDisabledCase` - McpServerStatusEnum type does not exist
24. `testMcpServerStatusEnum_hasExactlyFiveCases` - McpServerStatusEnum type does not exist
25. `testMcpServerStatusEnum_conformsToSendableAndEquatable` - McpServerStatusEnum type does not exist
26. `testMcpServerStatus_hasNameField` - McpServerStatus type does not exist
27. `testMcpServerStatus_hasStatusField` - McpServerStatus type does not exist
28. `testMcpServerStatus_hasServerInfoField` - McpServerStatus type does not exist
29. `testMcpServerStatus_hasErrorField` - McpServerStatus type does not exist
30. `testMcpServerStatus_hasToolsField` - McpServerStatus type does not exist

## Implementation Checklist

### AC1: McpClaudeAIProxyConfig + .claudeAIProxy case (Tests 1.1-1.7)

**File:** `Sources/OpenAgentSDK/Types/MCPConfig.swift`

**Tasks to make these tests pass:**

- [ ] Add `McpClaudeAIProxyConfig` struct with url: String and id: String fields
- [ ] Make McpClaudeAIProxyConfig Sendable and Equatable
- [ ] Add `.claudeAIProxy(McpClaudeAIProxyConfig)` case to McpServerConfig enum
- [ ] Handle `.claudeAIProxy` in MCPClientManager.connectAll() switch
- [ ] Handle `.claudeAIProxy` in Agent.processMcpConfigs() switch
- [ ] Update compat test `testMcpServerConfig_hasExactlyFourCases` to expect 5 cases

### AC2: mcpServerStatus() on Agent (Tests 2.1-2.3)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tasks to make these tests pass:**

- [ ] Store MCPClientManager as instance property on Agent
- [ ] Add `public func mcpServerStatus() async -> [String: McpServerStatus]` to Agent
- [ ] Delegate to MCPClientManager.getStatus() or return empty if manager is nil

### AC3: reconnectMcpServer(name:) on Agent (Tests 3.1-3.2)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tasks to make these tests pass:**

- [ ] Add `public func reconnectMcpServer(name: String) async throws` to Agent
- [ ] Delegate to MCPClientManager.reconnect(name:)
- [ ] Throw appropriate error when manager is nil or server not found

### AC4: toggleMcpServer(name:enabled:) on Agent (Tests 4.1-4.2)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tasks to make these tests pass:**

- [ ] Add `public func toggleMcpServer(name: String, enabled: Bool) async throws` to Agent
- [ ] Delegate to MCPClientManager.toggle(name:enabled:)
- [ ] Throw appropriate error when manager is nil or server not found

### AC5: setMcpServers + McpServerUpdateResult (Tests 5.1-5.4)

**File:** `Sources/OpenAgentSDK/Types/MCPTypes.swift`, `Sources/OpenAgentSDK/Core/Agent.swift`

**Tasks to make these tests pass:**

- [ ] Add `McpServerUpdateResult` struct with added, removed, errors fields
- [ ] Make McpServerUpdateResult Sendable and Equatable
- [ ] Add `public func setMcpServers(_ servers: [String: McpServerConfig]) async throws -> McpServerUpdateResult` to Agent
- [ ] Add `setServers(_:) async -> McpServerUpdateResult` to MCPClientManager

### AC6: McpServerStatusEnum + McpServerStatus (Tests 6.1-6.14)

**File:** `Sources/OpenAgentSDK/Types/MCPTypes.swift`

**Tasks to make these tests pass:**

- [ ] Add `McpServerStatusEnum` enum with 5 cases: connected, failed, needsAuth, pending, disabled
- [ ] Make McpServerStatusEnum Sendable and Equatable
- [ ] Add `McpServerStatus` struct with name, status, serverInfo, error, tools fields
- [ ] Make McpServerStatus Sendable
- [ ] Add `McpServerInfo` struct (name + version) for serverInfo field

### Compat Test Updates (Task 6 in story)

**File:** `Tests/OpenAgentSDKTests/Compat/MCPIntegrationCompatTests.swift`

**Tasks to update gap assertions:**

- [ ] Update `testMcpServerConfig_claudeAiProxy_gap()` to PASS
- [ ] Update `testMcpServerConfig_hasExactlyFourCases()` to expect 5 cases
- [ ] Update `testMcpServerConfig_coverageSummary()` missingCount from 1 to 0
- [ ] Update `testMCPClientManager_reconnectMcpServer_gap()` to PASS
- [ ] Update `testMCPClientManager_toggleMcpServer_gap()` to PASS
- [ ] Update `testMCPClientManager_setMcpServers_gap()` to PASS
- [ ] Update runtime operations coverage summary
- [ ] Update connection status coverage summary

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter MCPIntegrationEnhancementATDD

# Run specific test class
swift test --filter McpClaudeAIProxyConfigATDDTests
swift test --filter McpServerStatusEnumATDDTests
swift test --filter McpServerStatusStructATDDTests
swift test --filter MCPAgentRuntimeATDDTests

# Build only (check compilation)
swift build

# Run full test suite
swift test
```

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**Tests written:** 30 failing tests across 4 test classes
**Files created:** `Tests/OpenAgentSDKTests/Types/MCPIntegrationEnhancementATDDTests.swift`
**Checklist saved:** `_bmad-output/test-artifacts/atdd-checklist-17-8.md`

### GREEN Phase (DEV Team - Next Steps)

1. Start with AC6 types (McpServerStatusEnum, McpServerStatus, McpServerUpdateResult) -- pure types, no wiring
2. Then AC1 (McpClaudeAIProxyConfig + .claudeAIProxy case) -- extend existing enum
3. Then AC2-AC5 (MCPClientManager methods + Agent public API) -- runtime management
4. Update compat tests from GAP to PASS
5. Run full test suite (4055+ baseline + new tests)

### AC7: Build and Test

- [ ] `swift build` zero errors zero warnings
- [ ] All 4055+ existing tests pass
- [ ] All 30 new ATDD tests pass
- [ ] Zero regressions

## Notes

- New types go in MCPTypes.swift and MCPConfig.swift (extend existing files, no new files)
- McpServerStatusEnum is a NEW type, separate from existing MCPConnectionStatus (which keeps its 3 cases)
- Agent must store MCPClientManager as an instance property for the new public methods to work
- All new methods are additive -- no existing code paths change
- Per CLAUDE.md: no mock-based E2E tests
