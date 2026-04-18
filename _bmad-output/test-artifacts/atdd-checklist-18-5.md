---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-18'
inputDocuments:
  - '_bmad-output/implementation-artifacts/18-5-update-compat-mcp.md'
  - 'Examples/CompatMCP/main.swift'
  - 'Tests/OpenAgentSDKTests/Compat/MCPIntegrationCompatTests.swift'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
  - 'Sources/OpenAgentSDK/Types/MCPTypes.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
---

# ATDD Checklist: Story 18-5 (Update CompatMCP Example)

## Stack Detection

- **detected_stack**: backend (Swift Package Manager, XCTest)
- **test_framework**: XCTest
- **generation_mode**: AI Generation (backend project, no browser testing needed)

## TDD Red Phase (Current)

- 20 ATDD tests generated in `Tests/OpenAgentSDKTests/Compat/Story18_5_ATDDTests.swift`
- All tests PASS immediately because the underlying SDK types exist from Story 17-8
- The tests verify that the CompatMCP example's report tables SHOULD reflect the updated status

## Acceptance Criteria Coverage

### AC1: McpClaudeAIProxyServerConfig PASS (4 tests)
- [x] `testMcpClaudeAIProxyConfig_canConstruct` -- verifies url + id fields
- [x] `testMcpServerConfig_hasClaudeAIProxyCase` -- verifies .claudeAIProxy enum case
- [x] `testMcpClaudeAIProxyConfig_isDistinctFromOtherCases` -- verifies case uniqueness
- [x] `testMcpServerConfig_hasFiveCases` -- verifies 5 total McpServerConfig cases

### AC2: 4 Runtime Management Operations PASS (4 tests)
- [x] `testAgent_mcpServerStatus_returnsCorrectType` -- Agent public API
- [x] `testMCPClientManager_reconnect_exists` -- reconnect(name:)
- [x] `testMCPClientManager_toggle_exists` -- toggle(name:enabled:)
- [x] `testMCPClientManager_setServers_exists` -- setServers(_:)

### AC3: McpServerStatusEnum 5 Values PASS (3 tests)
- [x] `testMcpServerStatusEnum_hasFiveCases` -- exactly 5 cases
- [x] `testMcpServerStatusEnum_allFiveValuesMatchTS` -- rawValue matching
- [x] `testMcpServerStatusEnum_isCaseIterable` -- CaseIterable completeness

### AC4: McpServerStatus Fields PASS (5 tests)
- [x] `testMcpServerStatus_hasFiveFields` -- name, status, serverInfo, error, tools
- [x] `testMcpServerInfo_hasNameAndVersion` -- serverInfo sub-fields
- [x] `testMcpServerStatus_errorField_holdsErrorMessages` -- error field
- [x] `testMcpServerStatus_toolsIsStringArray` -- tools: [String]
- [x] `testMCPManagedConnection_stillHasThreeFields` -- internal type unchanged

### AC5: Build and Tests Pass
- [ ] `swift build` zero errors zero warnings (verified by test run)
- [ ] Full test suite passes with zero regression

### Compat Report Verification (4 tests)
- [x] `testCompatReport_ConfigMapping_4PASS_1PARTIAL_0MISSING` -- AC1 report
- [x] `testCompatReport_OperationMapping_4PASS_0MISSING` -- AC2 report
- [x] `testCompatReport_StatusMapping_5PASS_0MISSING` -- AC3 report
- [x] `testCompatReport_McpServerStatusFields_5PASS_2MISSING` -- AC4 report

## Test Priority Distribution

- P0: 20 tests (all tests are critical acceptance criteria verification)

## Test Levels

- Unit: 20 tests (all SDK API verification + compat report count verification)

## Expected Compat Report State (After Story 18-5 Implementation)

| Table | PASS | PARTIAL | MISSING | Total |
|-------|------|---------|---------|-------|
| ConfigMapping | 4 | 1 | 0 | 5 |
| OperationMapping | 4 | 0 | 0 | 4 |
| StatusMapping | 5 | 0 | 0 | 5 |
| McpServerStatus Fields | 5 | 0 | 2 | 7 |

## Next Steps (TDD Green Phase)

After implementing Story 18-5 (updating CompatMCP example main.swift):

1. Update `Examples/CompatMCP/main.swift`:
   - AC1: Change 3 MISSING entries to PASS for McpClaudeAIProxyConfig
   - AC2: Change 1 PARTIAL + 3 MISSING to PASS for runtime operations
   - AC3: Change 1 PARTIAL + 3 MISSING to PASS for status values
   - AC4: Add McpServerStatus verification; change 2 MISSING + 2 PARTIAL to PASS
   - Update all report tables (ConfigMapping, StatusMapping, OperationMapping)
2. Run full test suite, report total count
3. Verify MCPIntegrationCompatTests compat report counts are correct
