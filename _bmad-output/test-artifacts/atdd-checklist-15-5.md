---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/15-5-query-abort-example.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Examples/ModelSwitchingExample/main.swift'
  - 'Examples/LoggerExample/main.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/ModelSwitchingExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/LoggerExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/ExamplesComplianceTests.swift'
---

# ATDD Checklist - Epic 15, Story 5: QueryAbortExample

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit / Static Analysis (Swift backend project, example compliance tests)

---

## Story Summary

Create a runnable QueryAbortExample program that demonstrates how to interrupt a running Agent query. The example should show Task.cancel() cancellation, Agent.interrupt() cancellation, partial results handling, and stream cancellation with SDKMessage subtype checking. This is an example/documentation story, not a new feature.

**As a** developer
**I want** a runnable example demonstrating how to interrupt a running Agent query
**So that** I can understand how to implement user cancellation for long-running tasks (FR60)

---

## Acceptance Criteria

1. **AC1:** Example compiles and runs -- directory exists with main.swift, no build errors
2. **AC2:** Task.cancel() cancellation -- launches query inside Task, calls task.cancel(), shows isCancelled == true
3. **AC3:** Agent.interrupt() cancellation -- launches query inside Task, calls agent.interrupt(), shows isCancelled == true
4. **AC4:** Partial results handling -- inspects result.text, result.numTurns, result.usage after cancellation
5. **AC5:** Stream cancellation -- uses agent.stream() with cancellation, shows .result(subtype: .cancelled)
6. **AC6:** Package.swift updated with QueryAbortExample executableTarget following existing pattern

---

## Failing Tests Created (RED Phase)

### Compliance Tests - QueryAbortExampleComplianceTests (36 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/QueryAbortExampleComplianceTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testPackageSwiftContainsQueryAbortExampleTarget | AC6 | P0 | RED | Package.swift missing QueryAbortExample target |
| 2 | testQueryAbortExampleTargetDependsOnOpenAgentSDK | AC6 | P0 | RED | Package.swift missing dependency |
| 3 | testQueryAbortExampleTargetSpecifiesCorrectPath | AC6 | P0 | RED | Package.swift missing path |
| 4 | testQueryAbortExampleDirectoryExists | AC1 | P0 | RED | Examples/QueryAbortExample/ does not exist |
| 5 | testQueryAbortExampleMainSwiftExists | AC1 | P0 | RED | Examples/QueryAbortExample/main.swift does not exist |
| 6 | testQueryAbortExampleImportsOpenAgentSDK | AC1 | P0 | RED | File not found |
| 7 | testQueryAbortExampleImportsFoundation | AC1 | P0 | RED | File not found |
| 8 | testQueryAbortExampleHasTopLevelDescriptionComment | AC1 | P1 | RED | File not found |
| 9 | testQueryAbortExampleHasMultipleInlineComments | AC1 | P1 | RED | File not found |
| 10 | testQueryAbortExampleHasMarkSections | AC1 | P1 | RED | File not found |
| 11 | testQueryAbortExampleDoesNotUseForceUnwrap | AC1 | P0 | RED | File not found |
| 12 | testQueryAbortExampleDoesNotExposeRealAPIKeys | AC1 | P0 | RED | File not found |
| 13 | testQueryAbortExampleUsesLoadDotEnvPattern | AC1 | P1 | RED | File not found |
| 14 | testQueryAbortExampleUsesGetEnvPattern | AC1 | P1 | RED | File not found |
| 15 | testQueryAbortExampleUsesBypassPermissions | AC1 | P0 | RED | File not found |
| 16 | testQueryAbortExampleUsesCreateAgent | AC1 | P0 | RED | File not found |
| 17 | testQueryAbortExampleUsesTaskBlock | AC2 | P0 | RED | File not found |
| 18 | testQueryAbortExampleCallsTaskCancel | AC2 | P0 | RED | File not found |
| 19 | testQueryAbortExampleUsesTaskSleep | AC2 | P0 | RED | File not found |
| 20 | testQueryAbortExampleChecksIsCancelled | AC2 | P0 | RED | File not found |
| 21 | testQueryAbortExampleUsesPromptAPI | AC2 | P0 | RED | File not found |
| 22 | testQueryAbortExampleUsesAwait | AC2 | P0 | RED | File not found |
| 23 | testQueryAbortExampleCallsAgentInterrupt | AC3 | P0 | RED | File not found |
| 24 | testQueryAbortExampleDemonstratesSecondCancellationMechanism | AC3 | P0 | RED | File not found |
| 25 | testQueryAbortExampleInspectsPartialText | AC4 | P0 | RED | File not found |
| 26 | testQueryAbortExampleInspectsNumTurns | AC4 | P0 | RED | File not found |
| 27 | testQueryAbortExampleInspectsUsage | AC4 | P0 | RED | File not found |
| 28 | testQueryAbortExampleUsesStreamAPI | AC5 | P0 | RED | File not found |
| 29 | testQueryAbortExampleIteratesAsyncStream | AC5 | P0 | RED | File not found |
| 30 | testQueryAbortExampleHandlesSDKMessageResult | AC5 | P0 | RED | File not found |
| 31 | testQueryAbortExampleChecksCancelledSubtype | AC5 | P0 | RED | File not found |
| 32 | testQueryAbortExampleHasThreeParts | AC1 | P1 | RED | File not found |
| 33 | testQueryAbortExampleUsesAssertions | AC1 | P0 | RED | File not found |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). The QueryAbortExample is a documentation/example artifact, not a runtime feature. Test levels:
- **Compliance / static analysis tests** for all ACs -- verify file existence, code content, API usage patterns
- **No E2E tests** (no real LLM calls needed; compliance tests only check source code)
- **No unit tests for new logic** (no new SDK types introduced in this story)

### Approach

1. Tests verify that `Examples/QueryAbortExample/main.swift` exists and contains correct content
2. Content-based assertions check for specific API names (Task, .cancel(), .interrupt(), isCancelled, .stream, .result, .cancelled)
3. Package.swift assertions verify executableTarget configuration
4. Code quality checks (no force unwrap, no hardcoded API keys, comments, MARK sections)
5. Pattern matching ensures example demonstrates both cancellation mechanisms and stream cancellation
6. Tests follow the same compliance-test pattern as ModelSwitchingExampleComplianceTests

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 28 | Core ACs: file existence, API usage, key demonstrations |
| P1 | 5 | Supporting: comments, MARK sections, conventions |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Directory/file existence, compiles) | 16 | Compliance (file exists, imports, comments, quality, assertions, 3 parts) |
| AC2 (Task.cancel() cancellation) | 6 | Compliance (Task block, .cancel(), sleep, isCancelled, prompt, await) |
| AC3 (Agent.interrupt() cancellation) | 2 | Compliance (interrupt(), both mechanisms) |
| AC4 (Partial results handling) | 3 | Compliance (text, numTurns, usage) |
| AC5 (Stream cancellation) | 4 | Compliance (stream API, AsyncStream, .result, .cancelled) |
| AC6 (Package.swift target) | 3 | Compliance (target, dependency, path) |

---

## Implementation Checklist

### Task 1: Add QueryAbortExample executableTarget to Package.swift (AC: #6)

**File:** `Package.swift` (MODIFY)

**Tests this makes pass:**
- testPackageSwiftContainsQueryAbortExampleTarget
- testQueryAbortExampleTargetDependsOnOpenAgentSDK
- testQueryAbortExampleTargetSpecifiesCorrectPath

**Implementation steps:**
- [ ] Add `.executableTarget(name: "QueryAbortExample", dependencies: ["OpenAgentSDK"], path: "Examples/QueryAbortExample")` to targets array after ModelSwitchingExample

### Task 2: Create Examples/QueryAbortExample/main.swift (AC: #1-#5)

**File:** `Examples/QueryAbortExample/main.swift` (NEW)

**Tests this makes pass:** All 33 compliance tests

**Implementation steps:**
- [ ] Create directory `Examples/QueryAbortExample/`
- [ ] Create `main.swift` with Chinese + English header comment block
- [ ] Part 1: Task.cancel() Cancellation Demo
  - [ ] Create Agent with `loadDotEnv()`/`getEnv()` and `permissionMode: .bypassPermissions`
  - [ ] Launch query inside `Task { agent.prompt("complex analysis...") }`
  - [ ] Use `Task.sleep(for: .milliseconds(500))` then call `task.cancel()`
  - [ ] Await result, check `result.isCancelled == true`
  - [ ] Print partial result: `result.text`, `result.numTurns`, `result.usage`
  - [ ] `assert(result.isCancelled)`
- [ ] Part 2: Agent.interrupt() Cancellation Demo
  - [ ] Create a second Agent instance
  - [ ] Launch query inside `Task { agent.prompt(...) }`
  - [ ] Use `Task.sleep(for:)` then call `agent.interrupt()`
  - [ ] Await result, check `result.isCancelled == true`
  - [ ] Print partial result details
  - [ ] `assert(result.isCancelled)`
- [ ] Part 3: Stream Cancellation Demo
  - [ ] Create a third Agent instance
  - [ ] Launch `agent.stream(...)` inside Task
  - [ ] Iterate over `AsyncStream<SDKMessage>` with `for await`
  - [ ] After receiving a few events, call `task.cancel()`
  - [ ] Handle `.result` case with `subtype == .cancelled`
  - [ ] Show stream finishes normally (no error)
- [ ] Use `loadDotEnv()` and `getEnv()` patterns for API key
- [ ] Add MARK section comments for each part
- [ ] Add inline comments explaining each concept
- [ ] Ensure no force unwraps
- [ ] Use `assert()` for key validations

### Task 3: Verify build and full test suite

- [ ] `swift build` compiles with no errors (including QueryAbortExample target)
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter "QueryAbortExampleComplianceTests"

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 33 compliance tests written in 1 test file, all failing because the example file does not exist yet
- Tests cover all 6 acceptance criteria
- Tests use same helper pattern as ModelSwitchingExampleComplianceTests (projectRoot, fileContent)
- Tests verify both structural (file exists, Package.swift) and content (API usage, patterns)

**Verification:**
- Tests do NOT pass (QueryAbortExample directory doesn't exist -- expected for RED phase)
- Failures are clean: "Examples/QueryAbortExample/ directory should exist"
- No crashes or unexpected behavior

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (Package.swift update) -- makes 3 tests pass
2. **Then Task 2** (Create QueryAbortExample/main.swift) -- makes remaining 30 tests pass
3. **Finally Task 3** -- verify full suite passes

**Key Principles:**
- Follow the ModelSwitchingExample and LoggerExample patterns for structure
- Agent.interrupt(), QueryResult.isCancelled, and SDKMessage.ResultData.Subtype.cancelled all exist from Story 13.2
- Demonstrate both cancellation mechanisms (Task.cancel() and Agent.interrupt())
- Use Task.sleep for timing to ensure query is still running when cancelled
- prompt() returns normally on cancellation (does NOT throw) -- result.isCancelled == true
- Stream yields .result(subtype: .cancelled) and finishes normally
- Print partial results after cancellation (text, numTurns, usage)
- Use LogBuffer pattern from LoggerExample for stream event capture in @Sendable closures
- Use assert() for key validations to support compliance test verification

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency with existing examples)
3. Ensure the example runs correctly: `swift run QueryAbortExample`
4. Verify the example gracefully handles missing API key

---

## Key Risks and Assumptions

1. **Assumption: Agent.interrupt() and isCancelled are stable and public** -- Story 13.2 is complete with all APIs available.
2. **Assumption: prompt() does NOT throw on cancellation** -- Returns QueryResult with isCancelled == true. The example should NOT use try/catch for cancellation.
3. **Assumption: stream() yields .result(subtype: .cancelled)** -- AsyncStream finishes normally after yielding this event, no error thrown.
4. **Risk: Timing of cancellation** -- Task.sleep delay must be long enough for query to start but short enough for it to still be running. Using .milliseconds(500) should work for most cases.
5. **Assumption: loadDotEnv() and getEnv() helpers are available** -- Shared helpers in the Examples directory.
6. **Risk: Three agents needed** -- Story specifies 3 separate agent instances (one per part). Each needs its own API key loading.

---

**Generated by BMad TEA Agent** - 2026-04-13
