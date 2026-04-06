---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-07'
storyId: '4-3'
detectedStack: 'backend'
generationMode: 'ai-generation'
testFramework: 'XCTest'
---

# ATDD Test Checklist — Story 4.3: Agent Tool (Sub-Agent Spawn)

## Test Strategy

| Level | AC | Priority | File |
|-------|-----|----------|------|
| Unit | #1 createAgentTool returns ToolProtocol | P0 | AgentToolTests.swift |
| Unit | #1 AgentTool has valid inputSchema | P0 | AgentToolTests.swift |
| Unit | #2 Success result returns text | P0 | AgentToolTests.swift |
| Unit | #2 Success includes tool summary | P1 | AgentToolTests.swift |
| Unit | #6 No spawner returns error | P0 | AgentToolTests.swift |
| Unit | #3 Explore agent type | P1 | AgentToolTests.swift |
| Unit | #3 Plan agent type | P1 | AgentToolTests.swift |
| Unit | #5 Custom model overrides default | P1 | AgentToolTests.swift |
| Unit | #9 Error never throws | P0 | AgentToolTests.swift |
| Unit | #4 Tool filtering removes Agent | P0 | DefaultSubAgentSpawnerTests.swift |
| Unit | #4 allowedTools filters correctly | P1 | DefaultSubAgentSpawnerTests.swift |
| Unit | #5 Model inheritance | P0 | DefaultSubAgentSpawnerTests.swift |
| Unit | #5 Model override | P0 | DefaultSubAgentSpawnerTests.swift |
| Unit | #2 API error returns isError | P0 | DefaultSubAgentSpawnerTests.swift |
| Unit | #5 Custom maxTurns | P0 | DefaultSubAgentSpawnerTests.swift |
| Unit | #7 AgentDefinition with tools | P0 | AgentTypesTests.swift |
| Unit | #7 AgentDefinition defaults nil | P0 | AgentTypesTests.swift |
| Unit | #7 AgentDefinition backward compat | P0 | AgentTypesTests.swift |
| Unit | #6 SubAgentResult success | P0 | AgentTypesTests.swift |
| Unit | #6 SubAgentResult error | P0 | AgentTypesTests.swift |
| Unit | #6 SubAgentResult equatable | P1 | AgentTypesTests.swift |
| Unit | #6 ToolContext with agentSpawner | P0 | AgentTypesTests.swift |
| Unit | #6 ToolContext backward compat | P0 | AgentTypesTests.swift |
| Unit | #6 SubAgentSpawner protocol exists | P0 | AgentTypesTests.swift |

## Test Files Generated

1. `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` — 10 tests
2. `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` — 7 tests
3. `Tests/OpenAgentSDKTests/Types/AgentTypesTests.swift` — 10 tests

**Total: 27 tests**

## TDD Status: RED PHASE

All tests assert EXPECTED behavior that does not exist yet. They will FAIL until:
- `AgentDefinition` gains `tools` and `maxTurns` fields
- `SubAgentSpawner` protocol is defined in Types/
- `SubAgentResult` struct is defined in Types/
- `ToolContext` gains `agentSpawner` field
- `createAgentTool()` factory function is implemented in Tools/Advanced/
- `DefaultSubAgentSpawner` class is implemented in Core/
