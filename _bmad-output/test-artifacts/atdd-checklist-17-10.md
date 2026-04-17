---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-17'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-10-query-methods-enhancement.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ModelInfo.swift'
  - 'Sources/OpenAgentSDK/Types/ThinkingConfig.swift'
  - 'Sources/OpenAgentSDK/Stores/TaskStore.swift'
  - 'Tests/OpenAgentSDKTests/Compat/QueryMethodsCompatTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/MCPIntegrationEnhancementATDDTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/SubagentSystemEnhancementATDDTests.swift'
story_id: '17-10'
communication_language: 'zh'
detected_stack: 'backend'
generation_mode: 'ai-generation'
---

# ATDD Checklist: Story 17-10 Query Methods Enhancement

## Story Summary

Story 17-10 adds 9 missing query control methods to the Swift SDK Agent class, along with 5 new supporting types. This fills the gaps identified by Story 16-7 compatibility verification.

## Stack Detection

- **Detected stack:** `backend` (Swift Package Manager project, no frontend framework indicators)
- **Test framework:** XCTest (Swift built-in)
- **Test level:** Unit tests for types and Agent methods

## Generation Mode

- **Mode:** AI Generation (backend project, no browser testing needed)

## Test Strategy: Acceptance Criteria to Test Mapping

### AC1: rewindFiles method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | RewindResult struct construction with all fields | Unit | P0 |
| 2 | RewindResult conforms to Sendable | Unit | P0 |
| 3 | RewindResult conforms to Equatable | Unit | P0 |
| 4 | Agent.rewindFiles(to:dryRun:) exists on Agent | Unit | P0 |
| 5 | Agent.rewindFiles with dryRun=true returns preview | Unit | P1 |
| 6 | Agent.rewindFiles with dryRun=false restores files | Unit | P1 |

### AC2: streamInput method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | Agent.streamInput exists and returns AsyncStream<SDKMessage> | Unit | P0 |
| 2 | streamInput with empty input stream completes | Unit | P1 |

### AC3: stopTask method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | Agent.stopTask(taskId:) exists on Agent | Unit | P0 |
| 2 | stopTask throws when no TaskStore configured | Unit | P0 |
| 3 | stopTask throws when task ID not found | Unit | P1 |

### AC4: close method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | Agent.close() exists on Agent | Unit | P0 |
| 2 | close() sets closed flag, subsequent prompt() throws | Unit | P0 |
| 3 | close() with sessionStore persists session | Unit | P1 |
| 4 | close() cleans up MCP connections | Unit | P1 |

### AC5: initializationResult method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | SDKControlInitializeResponse struct construction | Unit | P0 |
| 2 | SDKControlInitializeResponse conforms to Sendable | Unit | P0 |
| 3 | SDKControlInitializeResponse conforms to Equatable | Unit | P0 |
| 4 | Agent.initializationResult() exists and returns SDKControlInitializeResponse | Unit | P0 |
| 5 | SlashCommand struct construction and conformance | Unit | P0 |
| 6 | AccountInfo struct construction and conformance | Unit | P0 |

### AC6: supportedModels method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | Agent.supportedModels() exists and returns [ModelInfo] | Unit | P0 |
| 2 | supportedModels returns entries matching MODEL_PRICING keys | Unit | P0 |

### AC7: supportedAgents method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | AgentInfo struct construction and conformance | Unit | P0 |
| 2 | Agent.supportedAgents() exists and returns [AgentInfo] | Unit | P0 |
| 3 | supportedAgents returns empty array when no agents configured | Unit | P0 |

### AC8: setMaxThinkingTokens method
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | Agent.setMaxThinkingTokens(_:) exists on Agent | Unit | P0 |
| 2 | setMaxThinkingTokens(10000) sets .enabled(budgetTokens: 10000) | Unit | P0 |
| 3 | setMaxThinkingTokens(nil) clears thinking config | Unit | P0 |
| 4 | setMaxThinkingTokens(0) throws SDKError.invalidConfiguration | Unit | P0 |
| 5 | setMaxThinkingTokens(-1) throws SDKError.invalidConfiguration | Unit | P1 |

### AC9: New supporting types
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | RewindResult struct (covered in AC1) | Unit | P0 |
| 2 | SDKControlInitializeResponse struct (covered in AC5) | Unit | P0 |
| 3 | AgentInfo struct (covered in AC7) | Unit | P0 |
| 4 | SlashCommand struct (covered in AC5) | Unit | P0 |
| 5 | AccountInfo struct (covered in AC5) | Unit | P0 |

### AC10: Build and test
| # | Test Scenario | Level | Priority |
|---|---|---|---|
| 1 | swift build zero errors zero warnings | Build | P0 |
| 2 | All existing tests pass with zero regression | Suite | P0 |

## Test File

- **File:** `Tests/OpenAgentSDKTests/Types/QueryMethodsEnhancementATDDTests.swift`
- **Phase:** RED (all tests fail until feature implemented)
- **Total test count:** ~35 tests across 9 XCTestCase classes

## Red Phase Compliance

All tests assert EXPECTED behavior that does not yet exist. They will FAIL until:
- RewindResult struct is added to Types/
- SDKControlInitializeResponse struct is added to Types/
- SlashCommand struct is added to Types/
- AgentInfo struct is added to Types/
- AccountInfo struct is added to Types/
- Agent gains 9 new public methods: rewindFiles, streamInput, stopTask, close, initializationResult, supportedModels, supportedAgents, setMaxThinkingTokens, and a _closed flag
