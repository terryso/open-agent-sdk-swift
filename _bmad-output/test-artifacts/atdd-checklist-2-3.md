---
stepsCompleted: ['step-01-preflight-and-context']
lastStep: 'step-01-preflight-and-context'
lastSaved: '2026-04-04'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-3-budget-enforcement.md'
  - 'Tests/OpenAgentSDKTests/Core/CostTrackingTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/StreamTests.swift'
---

# ATDD Checklist: Story 2.3 — 预算强制执行

## Acceptance Criteria → Test Mapping

| AC # | Acceptance Criterion | Test Case | Priority | Type |
|------|---------------------|-----------|----------|------|
| AC1 | 阻塞路径预算超限停止 | `testPrompt_BudgetExceeded_StopsLoop` | P0 | Integration |
| AC1 | 预算超限优雅错误结果 | `testPrompt_BudgetExceeded_ReturnsGracefulError` | P0 | Integration |
| AC1 | 预算超限不崩溃 | `testPrompt_BudgetExceeded_DoesNotCrash` | P0 | Integration |
| AC2 | 流式路径预算超限停止 | `testStream_BudgetExceeded_StopsStream` | P0 | Integration |
| AC2 | 流式超限返回 errorMaxBudgetUsd | `testStream_BudgetExceeded_ReturnsCorrectSubtype` | P0 | Integration |
| AC3 | 未配置预算无检查 | `testPrompt_NoBudget_NoCheck` | P0 | Integration |
| AC3 | 未配置预算无检查（流式） | `testStream_NoBudget_NoCheck` | P0 | Integration |
| AC4 | 阻塞路径返回正确状态 | `testPrompt_BudgetExceeded_CorrectStatusAndCost` | P0 | Integration |
| AC5 | 流式路径返回正确子类型 | `testStream_BudgetExceeded_CorrectSubtypeAndCost` | P0 | Integration |
| AC6 | 预算检查时机正确 | `testPrompt_BudgetCheck_AfterCostAccumulation` | P1 | Integration |
| AC6 | 预算检查时机正确（流式） | `testStream_BudgetCheck_AfterCostAccumulation` | P1 | Integration |

## Test Coverage Summary

- **Total tests**: 12
- **P0 (Must pass)**: 10
- **P1 (Should pass)**: 2
- **Paths covered**: blocking (prompt()) + streaming (stream())
- **Edge cases**: no budget (nil), single turn exceed, multi-turn accumulation, exact boundary

## Test File

`Tests/OpenAgentSDKTests/Core/BudgetEnforcementTests.swift`

## Dependencies on Previous Stories

- **Story 2.2**: Uses `estimateCost()`, `totalCostUsd` tracking, `TokenUsage`, `MODEL_PRICING`
- **Story 2.1**: Uses `StreamMockURLProtocol`, `makeSingleTurnSSEBody`, streaming test helpers
- **Story 1.5**: Uses `AgentLoopMockURLProtocol`, `makeAgentLoopResponse`, blocking test helpers
