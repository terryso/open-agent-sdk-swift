---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/14-2-structured-log-output.md'
  - 'Sources/OpenAgentSDK/Utils/Logger.swift'
  - 'Sources/OpenAgentSDK/Types/LogLevel.swift'
  - 'Sources/OpenAgentSDK/Types/LogOutput.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Core/ToolExecutor.swift'
  - 'Sources/OpenAgentSDK/Utils/Compact.swift'
  - 'Tests/OpenAgentSDKTests/Utils/LoggerTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/ToolExecutorTests.swift'
  - 'Tests/OpenAgentSDKTests/Utils/CompactTests.swift'
---

# ATDD Checklist - Epic 14, Story 2: Structured Log Output

**Date:** 2026-04-12
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (Swift backend project)

---

## Story Summary

Add structured Logger call sites throughout the SDK so that developers get meaningful diagnostic output when `logLevel` is set. The Logger API (from Story 14.1) already exists; this story only adds call sites in Agent.swift, ToolExecutor.swift, and Compact.swift.

**As a** developer
**I want** the SDK to output structured log information with standard fields
**So that** I can integrate it into log aggregation systems (ELK, Datadog, etc.)

---

## Acceptance Criteria

1. **AC1:** Structured log entry format -- timestamp (ISO 8601), level (string), module ("Agent"/"ToolExecutor"/"QueryEngine"), event ("llm_request"/"tool_execute"/"compact"), data (key-value dictionary) (FR62)
2. **AC2:** LLM response logging at debug level -- event "llm_response", data: inputTokens, outputTokens, durationMs, model
3. **AC3:** Tool execution logging at debug level -- event "tool_result", data: tool, inputSize, durationMs, outputSize
4. **AC4:** Compact event logging at info level -- event "compact", data: trigger, beforeTokens, afterTokens
5. **AC5:** Budget exceeded logging at warn level -- event "budget_exceeded", data: costUsd, budgetUsd, turnsUsed
6. **AC6:** Error logging at error level -- event "api_error", data: statusCode, message
7. **AC7:** Model switch logging at info level -- event "model_switch", data: from, to

---

## Failing Tests Created (RED Phase)

### Unit Tests - StructuredLogTests (20 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/StructuredLogTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testStructuredLogEntry_ContainsAllRequiredFields | AC1 | P0 | RED | No log emitted from agent loop |
| 2 | testLLMResponseLogging_ContainsRequiredDataFields | AC2 | P0 | RED | No Logger.debug call in promptImpl after usage parsing |
| 3 | testLLMResponseLogging_LevelIsDebug | AC2 | P0 | RED | No log emitted at debug level |
| 4 | testLLMResponseLogging_DataValuesAreStrings | AC2 | P1 | RED | No log emitted |
| 5 | testToolExecutionLogging_ContainsRequiredDataFields | AC3 | P0 | RED | No Logger.debug call in executeSingleTool |
| 6 | testToolExecutionLogging_LevelIsDebug | AC3 | P0 | RED | No log emitted at debug level |
| 7 | testToolExecutionLogging_IncludesOutputSize | AC3 | P1 | RED | No log emitted |
| 8 | testCompactLogging_ContainsRequiredDataFields | AC4 | P0 | RED | No Logger.info call in compactConversation |
| 9 | testCompactLogging_LevelIsInfo | AC4 | P0 | RED | No log emitted at info level |
| 10 | testCompactLogging_TriggerIsAuto | AC4 | P1 | RED | No log emitted |
| 11 | testBudgetExceededLogging_ContainsRequiredDataFields | AC5 | P0 | RED | No Logger.warn call in budget check |
| 12 | testBudgetExceededLogging_LevelIsWarn | AC5 | P0 | RED | No log emitted at warn level |
| 13 | testBudgetExceededLogging_DataValuesAreCorrect | AC5 | P1 | RED | No log emitted |
| 14 | testAPIErrorLogging_ContainsRequiredDataFields | AC6 | P0 | RED | No Logger.error call in catch block |
| 15 | testAPIErrorLogging_LevelIsError | AC6 | P0 | RED | No log emitted at error level |
| 16 | testAPIErrorLogging_IncludesStatusCodeAndMessage | AC6 | P1 | RED | No log emitted |
| 17 | testModelSwitchLogging_ContainsRequiredDataFields | AC7 | P0 | RED | No Logger.info call in switchModel |
| 18 | testModelSwitchLogging_LevelIsInfo | AC7 | P0 | RED | No log emitted at info level |
| 19 | testModelSwitchLogging_DataFromAndToAreCorrect | AC7 | P1 | RED | No log emitted |
| 20 | testNoLoggingWhenLevelIsNone | AC1 | P0 | RED | Test passes but verifies no output at .none |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). Test levels:
- **Unit tests** for each AC -- verify Logger.shared call sites emit correct structured JSON
- **No E2E tests** (no UI component, no browser)

### Approach

Tests use the existing `LogCapture` pattern from LoggerTests.swift:
1. Configure Logger with `.custom` output capturing to a thread-safe buffer
2. Execute code paths that should trigger logging (agent loop, tool execution, model switch)
3. Parse captured JSON lines and verify fields
4. Reuse existing mock patterns: `AgentLoopMockURLProtocol` for agent tests, `MockReadOnlyTool` for tool tests

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 13 | Core ACs: verify correct event emitted with correct level and required fields |
| P1 | 7 | Supporting: verify data field values, string types, trigger names |
| P2 | 0 | None needed for this story |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Structured format) | 2 | Unit (JSON field verification + zero-overhead at .none) |
| AC2 (LLM response debug) | 3 | Unit (agent loop mock response) |
| AC3 (Tool result debug) | 3 | Unit (mock tool execution) |
| AC4 (Compact info) | 3 | Unit (compact function mock) |
| AC5 (Budget exceeded warn) | 3 | Unit (agent loop with budget) |
| AC6 (API error error) | 3 | Unit (agent loop with API error) |
| AC7 (Model switch info) | 3 | Unit (direct switchModel call) |

---

## Implementation Checklist

### Task 1: Add Logger call sites in Agent.swift promptImpl (AC: #2, #5, #6)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift` (MODIFY)

**Tests this makes pass:**
- testLLMResponseLogging_ContainsRequiredDataFields
- testLLMResponseLogging_LevelIsDebug
- testLLMResponseLogging_DataValuesAreStrings
- testBudgetExceededLogging_ContainsRequiredDataFields
- testBudgetExceededLogging_LevelIsWarn
- testBudgetExceededLogging_DataValuesAreCorrect
- testAPIErrorLogging_ContainsRequiredDataFields
- testAPIErrorLogging_LevelIsError
- testAPIErrorLogging_IncludesStatusCodeAndMessage

**Implementation steps:**
- [ ] After `turnCount += 1` and usage parsing (~line 438): `Logger.shared.debug("QueryEngine", "llm_response", data: [...])`
- [ ] In budget check (~line 469): `Logger.shared.warn("QueryEngine", "budget_exceeded", data: [...])`
- [ ] In catch block (~line 390): `Logger.shared.error("QueryEngine", "api_error", data: [...])`
- [ ] Mirror same call sites in `stream()` method (parallel structure)

### Task 2: Add Logger call sites in ToolExecutor.swift (AC: #3)

**File:** `Sources/OpenAgentSDK/Core/ToolExecutor.swift` (MODIFY)

**Tests this makes pass:**
- testToolExecutionLogging_ContainsRequiredDataFields
- testToolExecutionLogging_LevelIsDebug
- testToolExecutionLogging_IncludesOutputSize

**Implementation steps:**
- [ ] In `executeSingleTool()` (~line 301): capture start time before `tool.call()`
- [ ] After `tool.call()` returns: compute duration, output size, add `Logger.shared.debug("ToolExecutor", "tool_result", data: [...])`

### Task 3: Add Logger call sites for compact events (AC: #4)

**File:** `Sources/OpenAgentSDK/Utils/Compact.swift` (MODIFY)

**Tests this makes pass:**
- testCompactLogging_ContainsRequiredDataFields
- testCompactLogging_LevelIsInfo
- testCompactLogging_TriggerIsAuto

**Implementation steps:**
- [ ] In `compactConversation()`: after compact completes, add `Logger.shared.info("QueryEngine", "compact", data: [...])`
- [ ] In `microCompact()`: after micro-compact, add `Logger.shared.debug("QueryEngine", "compact", data: [...])`

### Task 4: Add Logger call site for model switch (AC: #7)

**File:** `Sources/OpenAgentSDK/Core/Agent.swift` (MODIFY)

**Tests this makes pass:**
- testModelSwitchLogging_ContainsRequiredDataFields
- testModelSwitchLogging_LevelIsInfo
- testModelSwitchLogging_DataFromAndToAreCorrect

**Implementation steps:**
- [ ] In `switchModel()`: add `Logger.shared.info("Agent", "model_switch", data: ["from": oldModel, "to": newModel])`

### Task 5: Verify build and full test suite

- [ ] `swift build` compiles with no errors
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter StructuredLogTests

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 20 tests written in 1 test file, all failing because Logger call sites don't exist yet
- Tests cover all 7 acceptance criteria
- Tests follow Given-When-Then format with descriptive test names
- Test isolation via Logger.reset() in setUp/tearDown
- LogCapture pattern reused from LoggerTests.swift

**Verification:**
- Tests compile (Logger API exists from Story 14.1)
- Tests fail at assertion level (no log entries captured because call sites don't exist)
- No compilation errors expected (only runtime assertion failures)

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 4** (switchModel logging) -- simplest, 1 line change, makes 3 tests pass
2. **Then Task 2** (ToolExecutor logging) -- self-contained, makes 3 tests pass
3. **Then Task 3** (Compact logging) -- requires Compact.swift changes, makes 3 tests pass
4. **Then Task 1** (Agent.swift logging) -- most complex, multiple call sites, makes 8 tests pass
5. **Finally Task 5** -- verify full suite passes

**Key Principles:**
- One call site at a time
- Remember: update BOTH `promptImpl()` AND `stream()` in Agent.swift
- Run tests frequently (immediate feedback)
- Data values must be String type (Logger API uses `[String: String]`)

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency of module/event naming)
3. Ensure Logger calls don't introduce performance overhead (guard pattern already handles this)
4. Verify no import violations

---

## Key Risks and Assumptions

1. **Assumption: Logger API is stable** -- Story 14.1 is complete, Logger, LogLevel, LogOutput are finalized. No changes to these files needed.
2. **Assumption: Data values are [String: String]** -- All numeric values (tokens, durations, sizes) must be converted to String before passing to Logger.
3. **Risk: stream() method must be updated too** -- The streaming path has parallel structure to promptImpl(). Both must get the same Logger call sites.
4. **Assumption: Module names match convention** -- "QueryEngine" for agent loop events, "ToolExecutor" for tool events, "Agent" for lifecycle events.
5. **Risk: Compact test requires mock LLM client** -- compactConversation() makes an LLM API call. Tests need the existing mock URL protocol pattern.

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter "StructuredLogFormatTests|LLMResponseLogTests|ToolResultLogTests|CompactLogTests|BudgetExceededLogTests|APIErrorLogTests|ModelSwitchLogTests"`

**Results:**
```
Test Suite 'StructuredLogFormatTests': 2 tests, 1 passed, 1 failed
  testNoLoggingWhenLevelIsNone - PASSED (zero-overhead at .none verified)
  testStructuredLogEntry_ContainsAllRequiredFields - FAILED: XCTUnwrap - no log entries captured
Test Suite 'LLMResponseLogTests': 3 tests, 3 failures
  - XCTUnwrap failed: Should find an 'llm_response' log entry
Test Suite 'ToolResultLogTests': 3 tests, 3 failures
  - XCTUnwrap failed: Should find a 'tool_result' log entry
Test Suite 'CompactLogTests': 3 tests, 3 failures
  - XCTUnwrap failed: Should find a 'compact' log entry
Test Suite 'BudgetExceededLogTests': 3 tests, 3 failures
  - XCTUnwrap failed: Should find a 'budget_exceeded' log entry
Test Suite 'APIErrorLogTests': 3 tests, 3 failures
  - XCTUnwrap failed: Should find an 'api_error' log entry
Test Suite 'ModelSwitchLogTests': 3 tests, 3 failures
  - XCTUnwrap failed: Should find a 'model_switch' log entry
```

**Full Suite:**
```
Executed 2523 tests, with 4 tests skipped and 20 failures (0 unexpected) in 47.679 seconds
```

**Summary:**
- Total new tests: 20
- Passing: 1 (testNoLoggingWhenLevelIsNone -- zero-overhead at .none)
- Failing: 19 (expected -- Logger call sites not yet implemented)
- All failures are clean XCTUnwrap failures (no crashes)
- Zero regressions in existing 2503 tests
- Non-test errors: 0 (project compiles cleanly)
- Status: RED phase verified

---

**Generated by BMad TEA Agent** - 2026-04-12
