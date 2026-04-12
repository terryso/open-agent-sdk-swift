---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/13-3-session-memory-compression-layer.md'
  - 'Sources/OpenAgentSDK/Utils/Compact.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Utils/Tokens.swift'
  - 'Tests/OpenAgentSDKTests/Utils/CompactTests.swift'
---

# ATDD Checklist - Epic 13, Story 3: Session Memory Compression Layer

**Date:** 2026-04-12
**Author:** Nick (TEA Agent)
**Primary Test Level:** Unit (Swift backend project)

---

## Story Summary

Implement a Session Memory layer that maintains cross-query key context within an Agent's process lifetime. After auto-compact completes, key decisions, preferences, and constraints are extracted and stored in a bounded FIFO queue (4,000 tokens). This memory is injected into subsequent queries' system prompts via a `<session-memory>` XML block.

**As a** developer
**I want** the Agent to maintain cross-query key context via session memory
**So that** subsequent queries don't need to re-analyze already-known information

---

## Acceptance Criteria

1. **AC1:** Session Memory injected into system prompt -- `<session-memory>` XML block appears after prior query's auto-compact completes (FR67)
2. **AC2:** Three-layer compression -- micro-compact (Epic 2, Story 2.6, unchanged)
3. **AC3:** Three-layer compression -- auto-compact (Epic 2, Story 2.5, extended for extraction)
4. **AC4:** Session Memory extraction -- FIFO queue bounded to 4,000 tokens, in-process only, NFR30: FIFO prune in <10ms
5. **AC5:** Token estimation -- language-aware (ASCII: 1 token ~ 4 chars, CJK: 1 token ~ 1.5 chars)
6. **AC6:** Extraction mechanism -- LLM call after auto-compact for long summaries; direct store for short (<200 chars)

---

## Failing Tests Created (RED Phase)

### Unit Tests - TokenEstimator (14 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/TokenEstimatorTests.swift` (~165 lines)

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testEstimate_PureASCII_ReturnsCorrectTokenCount | AC5 | P0 | RED | `cannot find 'TokenEstimator' in scope` |
| 2 | testEstimate_EmptyString_ReturnsZero | AC5 | P0 | RED | `cannot find 'TokenEstimator' in scope` |
| 3 | testEstimate_SingleASCIIChar_ReturnsZero | AC5 | P1 | RED | `cannot find 'TokenEstimator' in scope` |
| 4 | testEstimate_FourASCIIChars_ReturnsOne | AC5 | P1 | RED | `cannot find 'TokenEstimator' in scope` |
| 5 | testEstimate_LongASCII_ReturnsCorrectCount | AC5 | P0 | RED | `cannot find 'TokenEstimator' in scope` |
| 6 | testEstimate_PureCJK_ReturnsCorrectTokenCount | AC5 | P0 | RED | `cannot find 'TokenEstimator' in scope` |
| 7 | testEstimate_SingleCJKChar_ReturnsApproximatelyOnePointFive | AC5 | P0 | RED | `cannot find 'TokenEstimator' in scope` |
| 8 | testEstimate_LongCJK_ReturnsCorrectCount | AC5 | P1 | RED | `cannot find 'TokenEstimator' in scope` |
| 9 | testEstimate_MixedASCIIAndCJK_SegmentsAndSums | AC5 | P0 | RED | `cannot find 'TokenEstimator' in scope` |
| 10 | testEstimate_MultipleSegments_SumsCorrectly | AC5 | P1 | RED | `cannot find 'TokenEstimator' in scope` |
| 11 | testEstimate_NumbersTreatedAsASCII | AC5 | P1 | RED | `cannot find 'TokenEstimator' in scope` |
| 12 | testEstimate_HangulCharacters_EstimatedAsCJK | AC5 | P2 | RED | `cannot find 'TokenEstimator' in scope` |
| 13 | testEstimate_WhitespaceOnly_TreatedAsASCII | AC5 | P2 | RED | `cannot find 'TokenEstimator' in scope` |
| 14 | testEstimate_Emoji_ReturnsPositiveTokens | AC5 | P2 | RED | `cannot find 'TokenEstimator' in scope` |

### Unit Tests - SessionMemory (23 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/SessionMemoryTests.swift` (~540 lines)

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testSessionMemoryEntry_CanBeCreatedWithRequiredFields | AC4 | P0 | RED | `cannot find 'SessionMemoryEntry' in scope` |
| 2 | testSessionMemoryEntry_SupportsAllCategoryTypes | AC4 | P0 | RED | `cannot find 'SessionMemoryEntry' in scope` |
| 3 | testSessionMemory_StartsEmpty | AC4 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 4 | testSessionMemory_AppendAddsEntry | AC4 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 5 | testSessionMemory_AppendMultipleEntries | AC4 | P1 | RED | `cannot find 'SessionMemory' in scope` |
| 6 | testFormatForPrompt_ProducesSessionMemoryXMLBlock | AC1 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 7 | testFormatForPrompt_EntryShowsCategorySummaryContext | AC1 | P1 | RED | `cannot find 'SessionMemory' in scope` |
| 8 | testFormatForPrompt_EmptyMemory_ReturnsNil | AC1 | P1 | RED | `cannot find 'SessionMemory' in scope` |
| 9 | testFIFOPruning_RemovesOldestEntriesWhenOverBudget | AC4 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 10 | testFIFOPruning_DefaultBudget_Is4000Tokens | AC4 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 11 | testFIFOPruning_PreservesNewestEntries | AC4 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 12 | testFIFOPruning_CompletesWithin10ms | AC4/NFR30 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 13 | testTokenCount_UsesLanguageAwareEstimation | AC5 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 14 | testBuildSystemPrompt_IncludesSessionMemoryBlock | AC1 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 15 | testBuildSystemPrompt_NoSessionMemory_WhenEmpty | AC1 | P1 | RED | Compiles but no session-memory expected |
| 16 | testExtractSessionMemory_ShortSummary_StoredDirectly | AC6 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 17 | testExtractSessionMemory_LongSummary_RequiresLLMExtraction | AC6 | P1 | RED | Compiles (tests JSON parsing logic) |
| 18 | testExtractedEntries_AppendedToSessionMemory | AC6 | P0 | RED | `cannot find 'SessionMemory' in scope` |
| 19 | testCompactConversation_AcceptsSessionMemoryParameter | AC6 | P0 | RED | `extra argument 'sessionMemory' in call` |
| 20 | testCompactConversation_WithoutSessionMemory_StillWorks | AC6 | P1 | RED | Compiles (existing signature) |
| 21 | testSessionMemory_IsThreadSafe | AC4 | P2 | RED | `cannot find 'SessionMemory' in scope` |
| 22 | testSessionMemory_CustomMaxTokens | AC4 | P1 | RED | `cannot find 'SessionMemory' in scope` |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). Test levels:
- **Unit tests** for `TokenEstimator` (pure function, no dependencies)
- **Unit tests** for `SessionMemory` (class with FIFO queue, thread safety)
- **Unit tests** for `compactConversation` integration (Mock URL protocol pattern from CompactTests)
- **No E2E tests** (no UI component, no browser)

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 23 | Core ACs: type existence, FIFO pruning, token estimation, extraction, system prompt injection |
| P1 | 10 | Supporting: edge cases, custom budgets, backward compatibility |
| P2 | 4 | Nice-to-have: thread safety, non-standard character sets |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Session Memory injection) | 4 | Unit (formatForPrompt + buildSystemPrompt) |
| AC4 (FIFO + budget + perf) | 10 | Unit (queue behavior + NFR30 timing) |
| AC5 (Token estimation) | 15 | Unit (TokenEstimator + SessionMemory tokenCount) |
| AC6 (Extraction mechanism) | 5 | Unit (direct store + LLM extraction + compactConversation) |
| Backward compat | 2 | Unit (compactConversation without sessionMemory) |

---

## Implementation Checklist

### Task 1: Create TokenEstimator (AC: #5)

**File:** `Sources/OpenAgentSDK/Utils/TokenEstimator.swift` (NEW)

**Tests this makes pass:**
- All 14 TokenEstimatorTests

**Implementation steps:**
- [ ] Create `enum TokenEstimator` namespace (no instances, pure static)
- [ ] Implement `public static func estimate(_ text: String) -> Int`
- [ ] ASCII chars: `utf8.count / 4`
- [ ] CJK chars (Unicode range `\u{4E00}`...`\u{9FFF}`): count * 1.5, rounded
- [ ] Mixed text: segment by character category, estimate each, sum

### Task 2: Create SessionMemoryEntry and SessionMemory (AC: #1, #4, #5)

**File:** `Sources/OpenAgentSDK/Utils/SessionMemory.swift` (NEW)

**Tests this makes pass:**
- testSessionMemoryEntry_CanBeCreatedWithRequiredFields
- testSessionMemoryEntry_SupportsAllCategoryTypes
- testSessionMemory_StartsEmpty
- testSessionMemory_AppendAddsEntry
- testSessionMemory_AppendMultipleEntries
- testFormatForPrompt_ProducesSessionMemoryXMLBlock
- testFormatForPrompt_EntryShowsCategorySummaryContext
- testFormatForPrompt_EmptyMemory_ReturnsNil
- testFIFOPruning_RemovesOldestEntriesWhenOverBudget
- testFIFOPruning_DefaultBudget_Is4000Tokens
- testFIFOPruning_PreservesNewestEntries
- testFIFOPruning_CompletesWithin10ms
- testTokenCount_UsesLanguageAwareEstimation
- testSessionMemory_IsThreadSafe
- testSessionMemory_CustomMaxTokens

**Implementation steps:**
- [ ] Define `SessionMemoryEntry` struct (category, summary, context, timestamp) -- Sendable
- [ ] Define `SessionMemory` final class with `NSLock` for thread safety
- [ ] Internal `[SessionMemoryEntry]` array as FIFO queue
- [ ] `init(maxTokens: Int = 4000)` with configurable budget
- [ ] `append(_ entry:)` -- add entry, then prune if over budget
- [ ] `formatForPrompt() -> String?` -- XML block or nil when empty
- [ ] `tokenCount() -> Int` -- uses `TokenEstimator.estimate()`
- [ ] FIFO pruning: while tokenCount > maxTokens, remove from head

### Task 3: Integrate SessionMemory into Agent (AC: #1)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift` (MODIFY)

**Tests this makes pass:**
- testBuildSystemPrompt_IncludesSessionMemoryBlock
- testBuildSystemPrompt_NoSessionMemory_WhenEmpty

**Implementation steps:**
- [ ] Add `private let sessionMemory = SessionMemory()` property to Agent
- [ ] In `buildSystemPrompt()`, after `<project-instructions>`, append `sessionMemory.formatForPrompt()` if non-nil
- [ ] Verify both `prompt()` and `stream()` pass `sessionMemory` to `compactConversation()`

### Task 4: Modify compactConversation for Session Memory extraction (AC: #3, #6)

**File:** `Sources/OpenAgentSDK/Utils/Compact.swift` (MODIFY)

**Tests this makes pass:**
- testCompactConversation_AcceptsSessionMemoryParameter
- testCompactConversation_WithoutSessionMemory_StillWorks
- testExtractSessionMemory_ShortSummary_StoredDirectly
- testExtractSessionMemory_LongSummary_RequiresLLMExtraction
- testExtractedEntries_AppendedToSessionMemory

**Implementation steps:**
- [ ] Add `sessionMemory: SessionMemory? = nil` parameter to `compactConversation()`
- [ ] After successful compaction (summary non-empty):
  - If summary.count < 200: create single `SessionMemoryEntry` and append
  - If summary.count >= 200: call `extractSessionMemory()` with LLM
- [ ] Implement `extractSessionMemory()` function:
  - Build extraction prompt requesting JSON array
  - Parse response with `JSONSerialization` (not Codable, per project convention)
  - Create `SessionMemoryEntry` for each extracted item
  - Append to `sessionMemory`
- [ ] Update `Agent.swift` call sites in both `prompt()` and `stream()` to pass `sessionMemory`

### Task 5: Verify compilation and full test suite

- [ ] `swift build` compiles without errors
- [ ] `swift test` -- all tests pass (including 2435+ existing tests)
- [ ] No regressions in existing CompactTests, AgentLoopTests, StreamTests

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter TokenEstimatorTests
swift test --filter SessionMemoryTests

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 37 tests written across 2 test files, all failing due to compilation errors
- Tests cover all 6 acceptance criteria
- Tests follow Given-When-Then format with descriptive test names
- Test isolation via fresh SessionMemory instances per test
- Mock URL protocol pattern reused from CompactTests for compactConversation tests

**Verification:**
- Build fails with: `cannot find 'TokenEstimator' in scope` (14 errors)
- Build fails with: `cannot find 'SessionMemory' in scope` (17 errors)
- Build fails with: `cannot find 'SessionMemoryEntry' in scope` (17 errors)
- Build fails with: `extra argument 'sessionMemory' in call` (1 error)
- All ~49 compilation errors are due to missing implementation, not test bugs
- Zero non-test-file compilation errors (rest of project compiles cleanly)

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (TokenEstimator.swift) -- pure function, no dependencies, makes 14 tests pass
2. **Then Task 2** (SessionMemory.swift) -- depends on TokenEstimator, makes 15 tests pass
3. **Then Task 3** (Agent.swift) -- add sessionMemory property and buildSystemPrompt() injection, makes 2 tests pass
4. **Then Task 4** (Compact.swift) -- add sessionMemory param and extraction logic, makes 5 tests pass
5. **Finally Task 5** -- verify full suite passes

**Key Principles:**
- One type/file at a time (fix compilation, then fix assertions)
- Minimal implementation (don't over-engineer)
- Run tests frequently (immediate feedback)
- Remember: update BOTH `prompt()` and `stream()` call sites in Agent.swift

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Verify all 2435+ tests pass
2. Review code quality (readability, maintainability)
3. Ensure consistency with existing patterns (CompactTests mock patterns, NSLock usage in SkillRegistry)
4. Verify no import violations
5. Check logger integration points (pre-placed for Epic 14)

---

## Key Risks and Assumptions

1. **Risk: TokenEstimator accuracy** -- Character-based heuristics are approximate. Tests use exact values which may need tolerance adjustments.
2. **Assumption: FIFO pruning via array head removal** -- `removeFirst()` on Array is O(n). For 4,000 tokens of entries, this should still be well within 10ms. If not, switch to `UnsafeMutablePointer` circular buffer.
3. **Assumption: JSONSerialization for LLM extraction** -- Per project convention, Codable is avoided for LLM response parsing. JSONSerialization must handle malformed JSON gracefully.
4. **Risk: Both prompt() and stream() must be updated** -- Previous stories repeatedly noted this as a common oversight. CompactConversation is called in both methods.
5. **Assumption: SessionMemory is per-Agent instance** -- Not shared across agents, not persisted to disk. Lifetime matches the Agent instance.

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**
```
error: cannot find 'TokenEstimator' in scope (14 occurrences)
error: cannot find 'SessionMemory' in scope (17 occurrences)
error: cannot find 'SessionMemoryEntry' in scope (17 occurrences)
error: extra argument 'sessionMemory' in call (1 occurrence)
```

**Summary:**
- Total tests: 37
- Passing: 0 (expected -- compilation failures)
- Failing: 37 (expected -- types and methods not yet implemented)
- Non-test errors: 0 (project compiles cleanly)
- Status: RED phase verified

---

**Generated by BMad TEA Agent** - 2026-04-12
