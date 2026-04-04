---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-05'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-6-tool-result-micro-compaction.md'
  - 'Sources/OpenAgentSDK/Utils/Compact.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Utils/Retry.swift'
  - 'Tests/OpenAgentSDKTests/Utils/CompactTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/CompactIntegrationTests.swift'
---

# ATDD Checklist - Epic 2, Story 2.6: Tool-Result Micro-Compaction

**Date:** 2026-04-05
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest) with Integration Tests

---

## Story Summary

The Agent should automatically compress large tool results (>50,000 characters) via LLM-based micro-compaction before adding them to the conversation. This prevents single tool outputs from consuming excessive context, complementing the auto-compaction from Story 2.5.

**As a** developer
**I want** the Agent to automatically micro-compact large tool results
**So that** individual tool outputs do not consume excessive context window space

---

## Acceptance Criteria

1. **AC1: Micro-compact trigger** -- Given a tool result exceeding 50,000 characters, when the result is added to the conversation, it is automatically micro-compacted to a summary preserving key info (FR10), and the compressed result is marked as truncated.
2. **AC2: No compression below threshold** -- Given tool results below 50,000 characters, no micro-compaction is performed; the full result is included.
3. **AC3: Compression marker** -- Given a micro-compacted tool result, the result includes the marker: `[微压缩] 原始长度: X, 压缩后长度: Y`.
4. **AC4: Compression failure tolerance** -- Given a micro-compaction LLM call failure, the original tool result is preserved intact (no truncation, no loss), and the Agent continues normal execution.
5. **AC5: Compression quality** -- The micro-compaction summary preserves key info: file paths, error messages, structured data key names and summary values. The summary should not lose critical error diagnostic info.

---

## Failing Tests Created (RED Phase)

### Unit Tests (11 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/MicroCompactTests.swift` (~350 lines)

- **Test:** `testShouldMicroCompact_ReturnsTrue_AboveThreshold`
  - **Status:** RED - `shouldMicroCompact(content:)` does not exist yet
  - **Verifies:** AC1 -- content > 50,000 triggers micro-compaction

- **Test:** `testShouldMicroCompact_ReturnsFalse_BelowThreshold`
  - **Status:** RED - `shouldMicroCompact(content:)` does not exist yet
  - **Verifies:** AC2 -- content < 50,000 does not trigger

- **Test:** `testShouldMicroCompact_ReturnsFalse_AtExactThreshold`
  - **Status:** RED - `shouldMicroCompact(content:)` does not exist yet
  - **Verifies:** AC2 -- content == 50,000 does not trigger (strict >)

- **Test:** `testShouldMicroCompact_ReturnsFalse_WhenAlreadyCompacted`
  - **Status:** RED - `shouldMicroCompact(content:)` does not exist yet
  - **Verifies:** Anti-pattern -- does not re-compress content starting with `[微压缩]`

- **Test:** `testShouldMicroCompact_ReturnsFalse_ForErrorResults`
  - **Status:** RED - `shouldMicroCompact(content:)` does not exist yet
  - **Verifies:** Anti-pattern -- isError results are not compacted

- **Test:** `testMicroCompact_ReturnsCompressedContent_OnSuccess`
  - **Status:** RED - `microCompact(client:model:content:)` does not exist yet
  - **Verifies:** AC1, AC3 -- compressed content includes marker

- **Test:** `testMicroCompact_MarkerContainsOriginalAndCompressedLength`
  - **Status:** RED - `microCompact(client:model:content:)` does not exist yet
  - **Verifies:** AC3 -- marker format `[微压缩] 原始长度: X, 压缩后长度: Y`

- **Test:** `testMicroCompact_PreservesOriginalContent_OnFailure`
  - **Status:** RED - `microCompact(client:model:content:)` does not exist yet
  - **Verifies:** AC4 -- failure returns original content unchanged

- **Test:** `testMicroCompact_IncludesCorrectSystemPrompt`
  - **Status:** RED - `microCompact(client:model:content:)` does not exist yet
  - **Verifies:** AC5 -- LLM call includes correct summarizer system prompt

- **Test:** `testMicroCompact_UsesMaxTokens8192`
  - **Status:** RED - `microCompact(client:model:content:)` does not exist yet
  - **Verifies:** Implementation constraint -- maxTokens=8192

- **Test:** `testMicroCompact_DoesNotTrackCostInTotalCostUsd`
  - **Status:** RED - `microCompact(client:model:content:)` does not exist yet
  - **Verifies:** Anti-pattern -- micro-compaction cost is not added to user totalCostUsd

### Integration Tests (4 tests)

**File:** `Tests/OpenAgentSDKTests/Core/MicroCompactIntegrationTests.swift` (~300 lines)

- **Test:** `testPrompt_MicroCompactsLargeToolResult_BeforeAddingToMessages`
  - **Status:** RED - micro-compaction integration not yet in Agent.prompt()
  - **Verifies:** AC1 -- prompt() path compresses large tool results

- **Test:** `testPrompt_DoesNotCompactBelowThreshold`
  - **Status:** RED - micro-compaction integration not yet in Agent.prompt()
  - **Verifies:** AC2 -- prompt() path leaves small results intact

- **Test:** `testStream_MicroCompactsLargeToolResult_AndEmitsStatusEvent`
  - **Status:** RED - micro-compaction integration not yet in Agent.stream()
  - **Verifies:** AC1, stream -- stream() path compresses and emits .system(.status)

- **Test:** `testStream_PreservesOriginal_OnCompactFailure`
  - **Status:** RED - micro-compaction integration not yet in Agent.stream()
  - **Verifies:** AC4 -- stream() path preserves original on failure

---

## Mock Requirements

### Micro-Compaction LLM Mock

**Endpoint:** `POST https://api.anthropic.com/v1/messages` (intercepted via URLProtocol)

**Success Response (Compaction Call):**

```json
{
  "id": "msg_micro_compact_001",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "Compressed summary preserving file paths, errors, keys..."}],
  "model": "claude-sonnet-4-6",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {"input_tokens": 1000, "output_tokens": 200}
}
```

**Failure Response:**

```json
{
  "error": {"type": "api_error", "message": "Internal server error"}
}
```

**Notes:** Uses CompactMockURLProtocol pattern from Story 2.5 tests. Sequential responses support main-loop + micro-compact calls in sequence.

---

## Implementation Checklist

### Task Group 1: Core Micro-Compact Functions (AC1, AC2, AC3, AC5)

**File:** `Sources/OpenAgentSDK/Utils/Compact.swift`

**Tasks to make these tests pass:**

- [ ] Add `MICRO_COMPACT_THRESHOLD = 50_000` constant
- [ ] Implement `shouldMicroCompact(content:) -> Bool` -- checks content.length > threshold, rejects already-compacted content (prefix `[微压缩]`), handles isError parameter
- [ ] Implement `microCompact(client:model:content:) async -> String` -- calls LLM with summarizer prompt, wraps withRetry, returns marker + summary on success, original on failure
- [ ] Implement `buildMicroCompactPrompt(_ content: String) -> String` -- private helper with the summarization instructions
- [ ] Run tests: `swift test --filter MicroCompactTests`

**Estimated Effort:** 2 hours

### Task Group 2: Agent Integration (AC1, AC2, AC4)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tasks to make these tests pass:**

- [ ] Add micro-compact check in `prompt()` before tool results are added to messages
- [ ] Add micro-compact check in `stream()` before tool results are added to messages
- [ ] In stream path: yield `.system(.status)` event when micro-compaction completes
- [ ] Run tests: `swift test --filter MicroCompactIntegrationTests`

**Estimated Effort:** 2 hours

### Task Group 3: Coordination with Auto-Compaction (AC1)

- [ ] Verify micro-compact runs BEFORE auto-compact in the agent loop
- [ ] Verify micro-compact reduces auto-compact trigger frequency
- [ ] Run full test suite: `swift test`

**Estimated Effort:** 1 hour

---

## Running Tests

```bash
# Run all micro-compact unit tests
swift test --filter MicroCompactTests

# Run all micro-compact integration tests
swift test --filter MicroCompactIntegrationTests

# Run all tests for this story
swift test --filter "MicroCompact"

# Run full test suite
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and failing
- Mock infrastructure documented (CompactMockURLProtocol reuse)
- Implementation checklist created
- Failure reasons: functions do not exist yet (`shouldMicroCompact`, `microCompact`, `buildMicroCompactPrompt`)

### GREEN Phase (DEV Team - Next Steps)

1. Pick one failing test group (start with Task Group 1: Core Functions)
2. Add `MICRO_COMPACT_THRESHOLD` constant
3. Implement `shouldMicroCompact(content:)`
4. Run: `swift test --filter ShouldMicroCompactTests`
5. Implement `microCompact(client:model:content:)` and `buildMicroCompactPrompt(_:)`
6. Run: `swift test --filter MicroCompactTests`
7. Integrate into Agent (Task Group 2)
8. Run: `swift test --filter MicroCompactIntegrationTests`

### REFACTOR Phase (After All Tests Pass)

1. Review Compact.swift for DRY between auto-compact and micro-compact
2. Ensure no code smells or duplicated prompt-building logic
3. Verify all tests still pass after refactor

---

## Knowledge Base References Applied

- **component-tdd.md** - TDD red-green-refactor cycle patterns
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test, isolation)
- **data-factories.md** - Test data generation patterns (applied as string builders for large content)
- **test-healing-patterns.md** - Resilient test patterns (MockURLProtocol reuse)

---

## Notes

- Micro-compaction is a pre-filter (before messages array) vs auto-compaction which is a post-filter (context window management)
- Both use `withRetry` for LLM calls
- Micro-compaction cost must NOT be added to `totalCostUsd`
- `isError: true` tool results must never be micro-compacted
- Already-compacted content (prefix `[微压缩]`) must not be re-compacted
- Uses same MockURLProtocol pattern established in Story 2.5 CompactTests

---

**Generated by BMad TEA Agent** - 2026-04-05
