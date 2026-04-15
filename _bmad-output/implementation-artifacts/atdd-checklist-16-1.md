---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-15'
inputDocuments:
  - _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md
  - Sources/OpenAgentSDK/Types/SDKMessage.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Types/TokenUsage.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
---

# ATDD Checklist: Story 16.1 -- Core Query API Compatibility Verification

## TDD Red Phase (Current)

All tests assert EXPECTED behavior. Tests are designed to compile but verify type-level compatibility.
Since this is a pure verification story (no new production code), tests validate that existing types
match the TypeScript SDK's API contract.

## Test Stack

- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Module:** `@testable import OpenAgentSDK`
- **Test Directory:** `Tests/OpenAgentSDKTests/Compat/`

## Generation Mode

- **Mode:** AI Generation (backend project, no browser recording needed)
- **Execution:** Sequential

## Acceptance Criteria Coverage

| AC# | Description | Test Level | Priority | Test File |
|-----|-------------|-----------|----------|-----------|
| AC1 | Example compiles and runs | E2E (build verification) | P0 | CoreQueryCompatTests.swift |
| AC2 | Basic streaming query equivalence | Unit (type verification) + Integration | P0 | CoreQueryCompatTests.swift |
| AC3 | Blocking query equivalence | Unit (type verification) + Integration | P0 | CoreQueryCompatTests.swift |
| AC4 | System init message equivalence | Unit (field verification) | P1 | CoreQueryCompatTests.swift |
| AC5 | Multi-turn query equivalence | Integration | P1 | CoreQueryCompatTests.swift |
| AC6 | Query interrupt equivalence | Unit (type verification) + Integration | P1 | CoreQueryCompatTests.swift |
| AC7 | Result message error subtypes | Unit (enum verification) | P0 | CoreQueryCompatTests.swift |
| AC8 | Compatibility report output | Unit (report generation) | P2 | CoreQueryCompatTests.swift |

## Test Files Generated

1. `Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift` -- Unit tests for type-level API compatibility (AC2, AC3, AC4, AC6, AC7)
2. `Tests/OpenAgentSDKTests/Compat/CoreQueryCompatE2ETests.swift` -- E2E integration tests for runtime behavior (AC1, AC2, AC5, AC6, AC8)

## TDD Red Phase Notes

- Unit tests (CoreQueryCompatTests) verify TYPE-LEVEL compatibility: field names, types, enum cases
  exist and match the TS SDK contract. These should PASS against current code since types already exist.
- E2E tests (CoreQueryCompatE2ETests) verify RUNTIME behavior: actual LLM queries produce correct
  event streams and results. These require API key and will be skipped in CI without credentials.
- Known gaps (SystemData missing session_id/tools/model, missing structuredOutput/permissionDenials
  fields) are tested and expected to FAIL, recording [MISSING] status.

## Field Mapping Table (TS SDK -> Swift SDK)

| TS SDK Field | Swift SDK Field | Verified By |
|---|---|---|
| `query({ prompt })` streaming | `agent.stream(prompt) -> AsyncStream<SDKMessage>` | AC2 |
| `query({ prompt })` blocking | `agent.prompt(prompt) -> QueryResult` | AC3 |
| `SDKResultMessage.subtype: "success"` | `ResultData.Subtype.success` | AC7 |
| `SDKResultMessage.subtype: "error_max_turns"` | `ResultData.Subtype.errorMaxTurns` | AC7 |
| `SDKResultMessage.subtype: "error_during_execution"` | `ResultData.Subtype.errorDuringExecution` | AC7 |
| `SDKResultMessage.subtype: "error_max_budget_usd"` | `ResultData.Subtype.errorMaxBudgetUsd` | AC7 |
| `SDKResultMessage.result` | `QueryResult.text` / `ResultData.text` | AC3 |
| `SDKResultMessage.total_cost_usd` | `QueryResult.totalCostUsd` / `ResultData.totalCostUsd` | AC3 |
| `SDKResultMessage.usage` | `QueryResult.usage` (TokenUsage) | AC3 |
| `SDKResultMessage.model_usage` | `QueryResult.costBreakdown` ([CostBreakdownEntry]) | AC3 |
| `SDKResultMessage.num_turns` | `QueryResult.numTurns` / `ResultData.numTurns` | AC3 |
| `SDKResultMessage.duration_ms` | `QueryResult.durationMs` / `ResultData.durationMs` | AC3 |
| `SDKResultMessage.stop_reason` | `AssistantData.stopReason` | AC2 |
| `SDKSystemMessage.session_id` | `SystemData.message` (GAP) | AC4 |
| `AbortController.abort()` | `Task.cancel()` / `agent.interrupt()` | AC6 |
| `TokenUsage.cache_read_input_tokens` | `TokenUsage.cacheReadInputTokens` | AC3 |
| `TokenUsage.cache_creation_input_tokens` | `TokenUsage.cacheCreationInputTokens` | AC3 |

## Known Gaps Under Investigation

1. `SystemData` lacks `session_id`, `tools`, `model`, `permissionMode`, `mcp_servers` fields
2. No `structuredOutput` field on `ResultData` or `QueryResult`
3. No `permissionDenials` field on `ResultData` or `QueryResult`
4. No separate `durationApiMs` field (only `durationMs`)
5. No `errors: [String]` field on error results

## Next Steps (TDD Green Phase)

1. Run unit tests -- verify type-level compatibility tests pass
2. Run E2E tests with API key -- verify runtime behavior
3. For [MISSING] items: decide whether to add fields to Swift SDK or document as intentional divergence
4. Generate compatibility report from test results
