---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-05'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-5-auto-conversation-compaction.md'
  - 'Sources/OpenAgentSDK/Utils/Tokens.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/API/AnthropicClient.swift'
  - 'Tests/OpenAgentSDKTests/Utils/TokensTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/StreamTests.swift'
---

# ATDD Checklist: Story 2.5 - Auto Conversation Compaction

## TDD Red Phase (Current)

**Status:** FAILING tests generated -- all tests assert EXPECTED behavior.

- Unit Tests: 14 tests (CompactTests.swift)
- Integration Tests: 4 tests (CompactIntegrationTests.swift)
- Total: 18 tests

## Acceptance Criteria Coverage

### AC1: Auto-Compact Trigger (Blocking Path)
- [x] P0: `testShouldAutoCompact_ReturnsTrue_WhenTokensExceedThreshold` -- shouldAutoCompact returns true when tokens >= threshold
- [x] P0: `testShouldAutoCompact_ReturnsFalse_WhenTokensBelowThreshold` -- shouldAutoCompact returns false when tokens < threshold
- [x] P0: `testShouldAutoCompact_ReturnsFalse_WhenConsecutiveFailuresAtLimit` -- shouldAutoCompact returns false when consecutiveFailures >= 3
- [x] P1: `testEstimateMessagesTokens_CalculatesCorrectTotal` -- estimateMessagesTokens with string content
- [x] P1: `testEstimateMessagesTokens_HandlesBlockContent` -- estimateMessagesTokens with block content array
- [x] P1: `testEstimateMessagesTokens_ReturnsZeroForEmptyArray` -- estimateMessagesTokens with empty messages
- [x] P1: `testGetAutoCompactThreshold_EqualsContextWindowMinusBuffer` -- getAutoCompactThreshold calculation
- [x] P0: `testPrompt_TriggersCompaction_WhenTokensExceedThreshold` -- prompt() integration test

### AC2: Auto-Compact Trigger (Streaming Path)
- [x] P0: `testStream_TriggersCompaction_WhenTokensExceedThreshold` -- stream() triggers compaction before next API call

### AC3: Post-Compaction Conversation Structure
- [x] P0: `testCompactConversation_ReturnsTwoMessages_OnSuccess` -- compacted messages contain user summary + assistant confirmation
- [x] P0: `testCompactConversation_SummaryContainsExpectedPrefix` -- user message contains "[Previous conversation summary]"
- [x] P0: `testStream_EmitsCompactBoundaryEvent_AfterCompaction` -- stream() emits .system(.compactBoundary)

### AC4: Compaction Failure Tolerance
- [x] P0: `testCompactConversation_PreservesOriginalMessages_OnFailure` -- original messages preserved when LLM call fails
- [x] P0: `testCompactConversation_IncrementsConsecutiveFailures_OnFailure` -- consecutiveFailures increments on failure
- [x] P0: `testShouldAutoCompact_StopsAfterThreeConsecutiveFailures` -- compaction stops after 3 failures
- [x] P0: `testCompactConversation_ResetsConsecutiveFailures_OnSuccess` -- consecutiveFailures resets to 0 on success

### AC5: Summary Quality
- [x] P1: `testCompactConversation_CallsLLMWithCorrectSystemPrompt` -- verifies LLM is called with summarizer system prompt
- [x] P1: `testCompactConversation_StateTracking_AccurateAcrossCalls` -- state tracks compacted flag and turnCounter correctly

## Test Strategy

| Level | Tests | Scope |
|-------|-------|-------|
| Unit | 14 | Pure function tests for Compact.swift functions |
| Integration | 4 | Agent loop integration (prompt/stream paths) |

## Implementation Prerequisites

These tests will FAIL until:
1. `Utils/Compact.swift` is created with `AutoCompactState`, `createAutoCompactState()`, `estimateMessagesTokens()`, `getAutoCompactThreshold()`, `shouldAutoCompact()`, `compactConversation()`
2. `Agent.prompt()` is updated to check `shouldAutoCompact` before API call
3. `Agent.stream()` is updated to check `shouldAutoCompact` before eventStream fetch and emit `.system(.compactBoundary)`

## Next Steps (TDD Green Phase)

After implementing the feature:
1. Run tests: `swift test`
2. Verify all tests PASS (green phase)
3. If any tests fail, fix implementation or test as needed
4. Commit passing tests

## Test Files

| File | Location |
|------|----------|
| CompactTests.swift | Tests/OpenAgentSDKTests/Utils/CompactTests.swift |
| CompactIntegrationTests.swift | Tests/OpenAgentSDKTests/Core/CompactIntegrationTests.swift |

## Execution Mode

Sequential (Swift XCTest backend project -- no browser-based testing needed)
