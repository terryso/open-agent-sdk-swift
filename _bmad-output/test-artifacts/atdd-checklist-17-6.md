---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-17'
storyId: '17-6'
storyTitle: 'Subagent System Enhancement'
tddPhase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-6-subagent-system-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift'
  - 'Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
  - 'Sources/OpenAgentSDK/Types/PermissionTypes.swift'
  - 'Tests/OpenAgentSDKTests/Types/AgentTypesTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift'
---

# ATDD Checklist: Story 17-6 Subagent System Enhancement

## Preflight Summary

- **Story:** 17-6 Subagent System Enhancement
- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Mode:** AI Generation (backend, no browser)
- **TDD Phase:** RED (failing tests before implementation)

## Acceptance Criteria -> Test Mapping

### AC1: AgentDefinition field completion (4 new fields)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 1.1 | AgentDefinition has disallowedTools field (defaults nil) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.2 | AgentDefinition has mcpServers field (defaults nil) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.3 | AgentDefinition has skills field (defaults nil) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.4 | AgentDefinition has criticalSystemReminderExperimental field (defaults nil) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.5 | AgentDefinition init with all new fields set | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.6 | AgentDefinition backward compat: existing init compiles | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.7 | AgentDefinition with disallowedTools populated | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.8 | AgentDefinition with mcpServers populated with AgentMcpServerSpec | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.9 | AgentDefinition with skills populated | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 1.10 | AgentDefinition with criticalSystemReminderExperimental populated | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC2: AgentToolInput field completion (5 new fields)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 2.1 | AgentToolInput JSON decodes runInBackground field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.2 | AgentToolInput JSON decodes isolation field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.3 | AgentToolInput JSON decodes team_name -> teamName field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.4 | AgentToolInput JSON decodes mode field (string) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.5 | AgentToolInput JSON decodes resume field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.6 | AgentToolInput defaults all new fields to nil | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.7 | agentToolSchema includes runInBackground property | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.8 | agentToolSchema includes isolation property | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.9 | agentToolSchema includes team_name property | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.10 | agentToolSchema includes mode property | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.11 | agentToolSchema includes resume property | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.12 | AgentTool passes new fields to spawner (runInBackground) | Integration | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.13 | AgentTool passes new fields to spawner (isolation) | Integration | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 2.14 | AgentTool passes mode string as PermissionMode to spawner | Integration | P1 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC3: AgentOutput three-state discrimination

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 3.1 | AgentOutput enum has .completed case | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.2 | AgentOutput enum has .asyncLaunched case | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.3 | AgentOutput enum has .subAgentEntered case | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.4 | AgentOutput.completed carries AgentCompletedOutput | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.5 | AgentOutput.asyncLaunched carries AsyncLaunchedOutput | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.6 | AgentOutput.subAgentEntered carries SubAgentEnteredOutput | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.7 | AgentOutput conforms to Sendable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 3.8 | AgentOutput conforms to Equatable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC3: AgentCompletedOutput struct

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 4.1 | AgentCompletedOutput has agentId field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.2 | AgentCompletedOutput has content field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.3 | AgentCompletedOutput has totalToolUseCount field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.4 | AgentCompletedOutput has totalDurationMs field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.5 | AgentCompletedOutput has totalTokens field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.6 | AgentCompletedOutput has usage field (TokenUsage?) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.7 | AgentCompletedOutput has prompt field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.8 | AgentCompletedOutput conforms to Sendable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.9 | AgentCompletedOutput conforms to Equatable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 4.10 | AgentCompletedOutput init with all fields | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC3: AsyncLaunchedOutput struct

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 5.1 | AsyncLaunchedOutput has agentId field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.2 | AsyncLaunchedOutput has description field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.3 | AsyncLaunchedOutput has prompt field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.4 | AsyncLaunchedOutput has outputFile field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.5 | AsyncLaunchedOutput has canReadOutputFile field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.6 | AsyncLaunchedOutput conforms to Sendable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.7 | AsyncLaunchedOutput conforms to Equatable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 5.8 | AsyncLaunchedOutput init with all fields | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC3: SubAgentEnteredOutput struct

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 6.1 | SubAgentEnteredOutput has description field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 6.2 | SubAgentEnteredOutput has message field | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 6.3 | SubAgentEnteredOutput conforms to Sendable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 6.4 | SubAgentEnteredOutput conforms to Equatable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 6.5 | SubAgentEnteredOutput init with all fields | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC4: AgentMcpServerSpec type

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 7.1 | AgentMcpServerSpec has .reference(String) case | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 7.2 | AgentMcpServerSpec has .inline(McpServerConfig) case | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 7.3 | AgentMcpServerSpec conforms to Sendable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 7.4 | AgentMcpServerSpec conforms to Equatable | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 7.5 | AgentMcpServerSpec.reference equality by string | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 7.6 | AgentMcpServerSpec.inline equality by config | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |
| 7.7 | AgentMcpServerSpec.reference and .inline are not equal | Unit | P1 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC5: SubAgentSpawner protocol extension (new spawn overload)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 8.1 | SubAgentSpawner has new spawn overload with extra params | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.2 | Protocol extension default delegates to original spawn | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.3 | New spawn overload accepts disallowedTools | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.4 | New spawn overload accepts mcpServers | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.5 | New spawn overload accepts skills | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.6 | New spawn overload accepts runInBackground | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.7 | New spawn overload accepts isolation | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.8 | New spawn overload accepts name | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.9 | New spawn overload accepts teamName | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.10 | New spawn overload accepts mode (PermissionMode?) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.11 | Existing SubAgentSpawner conformers compile (backward compat) | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.12 | MockSubAgentSpawner updated for new spawn overload | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |
| 8.13 | DefaultSubAgentSpawner implements new overload | Unit | P0 | SubagentSystemEnhancementATDDTests.swift | RED |

### AC6: Build and test

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 9.1 | swift build zero errors zero warnings | Build | P0 | (CLI verification) | PENDING |
| 9.2 | 3977+ existing tests pass | Regression | P0 | (CLI verification) | PENDING |

## Test File Summary

| File | Tests | Classes |
|---|---|---|
| SubagentSystemEnhancementATDDTests.swift | 68 | 8 |
| **Total** | **68** | **8** |

## TDD Red Phase Status

- All tests assert EXPECTED behavior
- All tests will FAIL until feature is implemented
- This is INTENTIONAL (TDD red phase)

## Notes

- AgentMcpServerSpec is a new enum in AgentTypes.swift referencing existing McpServerConfig
- AgentOutput is a new enum (separate from existing SubAgentResult, which remains unchanged)
- AgentDefinition gains 4 new optional fields (all default nil)
- AgentToolInput gains 5 new Codable fields (runInBackground, isolation, teamName, mode, resume)
- SubAgentSpawner gets a new spawn overload via protocol extension (backward compatible)
- DefaultSubAgentSpawner must implement the new overload with disallowedTools filtering
- MockSubAgentSpawner in AgentToolTests must be updated for the new spawn overload
- All new types must conform to Sendable + Equatable
- No E2E tests: pure backend unit tests per project conventions
