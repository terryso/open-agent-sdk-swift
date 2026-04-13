---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/15-7-multi-turn-example.md'
  - 'Sources/OpenAgentSDK/Stores/SessionStore.swift'
  - 'Sources/OpenAgentSDK/Types/SessionTypes.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/ContextInjectionExampleComplianceTests.swift'
---

# ATDD Checklist - Epic 15, Story 7: MultiTurnExample

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit / Static Analysis (Swift backend project, example compliance tests)

---

## Story Summary

Create a runnable MultiTurnExample program that demonstrates multi-turn conversation using SessionStore + sessionId for cross-prompt context retention. Shows that the Agent "remembers" what was said earlier across multiple prompt() calls, then demonstrates streaming multi-turn, message history inspection, and session cleanup. This is an example/documentation story, not a new feature.

**As a** developer
**I want** a runnable example demonstrating multi-turn conversation with an Agent
**So that** I can understand how to maintain context across multiple prompt calls

---

## Acceptance Criteria

1. **AC1:** Example compiles and runs -- directory exists with main.swift, no build errors
2. **AC2:** Multi-turn with SessionStore -- demonstrates creating SessionStore, Agent with sessionStore+sessionId, multiple prompt() calls
3. **AC3:** Cross-turn context retention -- first prompt tells Agent a fact, second prompt asks about it, asserts response contains the fact
4. **AC4:** Message history inspection -- loads session via sessionStore.load(sessionId:), prints messageCount and metadata (model, createdAt, updatedAt)
5. **AC5:** Streaming multi-turn -- uses agent.stream() for third turn, collects SDKMessage events, streaming maintains session context
6. **AC6:** Session cleanup -- deletes session via sessionStore.delete(sessionId:), verifies cleanup
7. **AC7:** Package.swift updated with MultiTurnExample executableTarget following existing pattern

---

## Failing Tests Created (RED Phase)

### Compliance Tests - MultiTurnExampleComplianceTests (35 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/MultiTurnExampleComplianceTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testPackageSwiftContainsMultiTurnExampleTarget | AC7 | P0 | RED | Package.swift missing MultiTurnExample target |
| 2 | testMultiTurnExampleTargetDependsOnOpenAgentSDK | AC7 | P0 | RED | Package.swift missing dependency |
| 3 | testMultiTurnExampleTargetSpecifiesCorrectPath | AC7 | P0 | RED | Package.swift missing path |
| 4 | testMultiTurnExampleDirectoryExists | AC1 | P0 | RED | Examples/MultiTurnExample/ does not exist |
| 5 | testMultiTurnExampleMainSwiftExists | AC1 | P0 | RED | main.swift does not exist |
| 6 | testMultiTurnExampleImportsOpenAgentSDK | AC1 | P0 | RED | File not found |
| 7 | testMultiTurnExampleImportsFoundation | AC1 | P0 | RED | File not found |
| 8 | testMultiTurnExampleHasTopLevelDescriptionComment | AC1 | P1 | RED | File not found |
| 9 | testMultiTurnExampleHasMultipleInlineComments | AC1 | P1 | RED | File not found |
| 10 | testMultiTurnExampleHasMarkSections | AC1 | P1 | RED | File not found |
| 11 | testMultiTurnExampleDoesNotUseForceUnwrap | AC1 | P0 | RED | File not found |
| 12 | testMultiTurnExampleDoesNotExposeRealAPIKeys | AC1 | P0 | RED | File not found |
| 13 | testMultiTurnExampleUsesLoadDotEnvPattern | AC1 | P1 | RED | File not found |
| 14 | testMultiTurnExampleUsesGetEnvPattern | AC1 | P1 | RED | File not found |
| 15 | testMultiTurnExampleUsesAssertions | AC1 | P0 | RED | File not found |
| 16 | testMultiTurnExampleCreatesSessionStore | AC2 | P0 | RED | File not found |
| 17 | testMultiTurnExampleCreatesAgentWithSessionStoreAndSessionId | AC2 | P0 | RED | File not found |
| 18 | testMultiTurnExampleExecutesMultiplePrompts | AC2 | P0 | RED | File not found |
| 19 | testMultiTurnExampleDemonstratesCrossTurnContext | AC3 | P0 | RED | File not found |
| 20 | testMultiTurnExampleAssertsContextRetention | AC3 | P0 | RED | File not found |
| 21 | testMultiTurnExampleUsesBypassPermissions | AC3 | P0 | RED | File not found |
| 22 | testMultiTurnExampleUsesCreateAgent | AC3 | P0 | RED | File not found |
| 23 | testMultiTurnExampleUsesAwait | AC3 | P0 | RED | File not found |
| 24 | testMultiTurnExampleLoadsSessionData | AC4 | P0 | RED | File not found |
| 25 | testMultiTurnExampleAccessesMessageCount | AC4 | P0 | RED | File not found |
| 26 | testMultiTurnExamplePrintsMetadata | AC4 | P0 | RED | File not found |
| 27 | testMultiTurnExampleAssertsMessageCountGreaterThanZero | AC4 | P0 | RED | File not found |
| 28 | testMultiTurnExampleUsesStream | AC5 | P0 | RED | File not found |
| 29 | testMultiTurnExampleCollectsSDKMessageEvents | AC5 | P0 | RED | File not found |
| 30 | testMultiTurnExampleAssertsStreamingResponseNonEmpty | AC5 | P0 | RED | File not found |
| 31 | testMultiTurnExampleDeletesSession | AC6 | P0 | RED | File not found |
| 32 | testMultiTurnExampleAssertsDeletionSucceeded | AC6 | P0 | RED | File not found |
| 33 | testMultiTurnExampleVerifiesSessionNoLongerExists | AC6 | P0 | RED | File not found |
| 34 | testMultiTurnExampleHasFourParts | AC1 | P1 | RED | File not found |
| 35 | testMultiTurnExampleUsesSpecificSessionId | AC2 | P0 | RED | File not found |

**Note:** 35 test methods produce 36 assertion failures because one test (testMultiTurnExampleCreatesAgentWithSessionStoreAndSessionId) contains two assertions.

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). The MultiTurnExample is a documentation/example artifact, not a runtime feature. Test levels:
- **Compliance / static analysis tests** for all ACs -- verify file existence, code content, API usage patterns
- **No E2E tests** (no real LLM calls needed; compliance tests only check source code)
- **No unit tests for new logic** (no new SDK types introduced in this story)

### Approach

1. Tests verify that `Examples/MultiTurnExample/main.swift` exists and contains correct content
2. Content-based assertions check for specific API names (SessionStore, sessionStore, sessionId, .prompt(), .stream(), SDKMessage, .load(sessionId:), .delete(sessionId:), messageCount, model, createdAt, updatedAt)
3. Package.swift assertions verify executableTarget configuration
4. Code quality checks (no force unwrap, no hardcoded API keys, comments, MARK sections)
5. Pattern matching ensures example demonstrates all 4 parts (Multi-turn, History, Streaming, Cleanup)
6. Tests follow the same compliance-test pattern as ContextInjectionExampleComplianceTests

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 30 | Core ACs: file existence, API usage, key demonstrations |
| P1 | 5 | Supporting: comments, MARK sections, conventions, loadDotEnv/getEnv |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Directory/file existence, compiles) | 13 | Compliance (file exists, imports, comments, quality, assertions, 4 parts) |
| AC2 (Multi-turn with SessionStore) | 4 | Compliance (SessionStore init, sessionStore+sessionId, multiple prompts, specific sessionId) |
| AC3 (Cross-turn context retention) | 5 | Compliance (cross-turn context, assert context retention, bypassPermissions, createAgent, await) |
| AC4 (Message history inspection) | 4 | Compliance (load session, messageCount, metadata fields, message count assert) |
| AC5 (Streaming multi-turn) | 3 | Compliance (stream(), SDKMessage events, assert non-empty) |
| AC6 (Session cleanup) | 3 | Compliance (delete session, assert deletion, verify nil after delete) |
| AC7 (Package.swift target) | 3 | Compliance (target, dependency, path) |

---

## Implementation Checklist

### Task 1: Add MultiTurnExample executableTarget to Package.swift (AC: #7)

**File:** `Package.swift` (MODIFY)

**Tests this makes pass:**
- testPackageSwiftContainsMultiTurnExampleTarget
- testMultiTurnExampleTargetDependsOnOpenAgentSDK
- testMultiTurnExampleTargetSpecifiesCorrectPath

**Implementation steps:**
- [ ] Add `.executableTarget(name: "MultiTurnExample", dependencies: ["OpenAgentSDK"], path: "Examples/MultiTurnExample")` to targets array after ContextInjectionExample

### Task 2: Create Examples/MultiTurnExample/main.swift (AC: #1-#6)

**File:** `Examples/MultiTurnExample/main.swift` (NEW)

**Tests this makes pass:** All 35 compliance tests

**Implementation steps:**
- [ ] Create directory `Examples/MultiTurnExample/`
- [ ] Create `main.swift` with Chinese + English header comment block
- [ ] Part 1: Multi-turn with SessionStore
  - [ ] Create `SessionStore()` instance
  - [ ] Create Agent with `sessionStore` and `sessionId: "multi-turn-demo"` via `createAgent()`
  - [ ] Set `permissionMode: .bypassPermissions`
  - [ ] Turn 1: Tell the Agent a fact (e.g., "Remember that my name is Nick")
  - [ ] Print first result text
  - [ ] Turn 2: Ask about the fact from Turn 1 (e.g., "What is my name?")
  - [ ] Assert second response contains "Nick"
  - [ ] Print second result text
  - [ ] Use `assert()` for context retention validation
- [ ] Part 2: Message History Inspection
  - [ ] Call `sessionStore.load(sessionId: "multi-turn-demo")` to get `SessionData`
  - [ ] Print `metadata.messageCount`
  - [ ] Print `metadata.model`, `metadata.createdAt`, `metadata.updatedAt`
  - [ ] Assert `messageCount > 0`
- [ ] Part 3: Streaming Multi-turn
  - [ ] Use `agent.stream()` for a third prompt
  - [ ] Collect `SDKMessage` events and print final text
  - [ ] Assert streaming response is non-empty
- [ ] Part 4: Session Cleanup
  - [ ] Call `sessionStore.delete(sessionId: "multi-turn-demo")`
  - [ ] Assert deletion returned `true`
  - [ ] Verify session no longer exists via `sessionStore.load()` returning `nil`
- [ ] Use `loadDotEnv()` and `getEnv()` patterns for API key
- [ ] Add MARK section comments for each part
- [ ] Add inline comments explaining each concept
- [ ] Ensure no force unwraps
- [ ] Ensure no real API keys hardcoded

### Task 3: Verify build and full test suite

- [ ] `swift build` compiles with no errors (including MultiTurnExample target)
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter "MultiTurnExampleComplianceTests"

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 35 compliance tests written in 1 test file, all failing because the example file does not exist yet
- Tests cover all 7 acceptance criteria
- Tests use same helper pattern as ContextInjectionExampleComplianceTests (projectRoot, fileContent)
- Tests verify both structural (file exists, Package.swift) and content (API usage, patterns)

**Verification:**
- Tests do NOT pass (MultiTurnExample directory doesn't exist -- expected for RED phase)
- Failures are clean: "Examples/MultiTurnExample/ directory should exist"
- No crashes or unexpected behavior
- 35 tests produce 36 assertion failures (one test has 2 assertions)

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (Package.swift update) -- makes 3 tests pass
2. **Then Task 2** (Create MultiTurnExample/main.swift) -- makes remaining 32 tests pass
3. **Finally Task 3** -- verify full suite passes

**Key Principles:**
- Follow the ContextInjectionExample and ModelSwitchingExample patterns for structure
- SessionStore is an actor -- all methods require `await`
- Use `try await` for `save`, `load`, `delete` on SessionStore
- The same Agent can be used for all 3 turns (prompt, prompt, stream)
- SessionStore auto-saves after prompt/stream, auto-loads before next prompt/stream
- Use `nonisolated(unsafe)` let bindings when capturing in Task closures (Swift 6 concurrency)
- Use `assert()` for key validations to support compliance test verification
- Use `"multi-turn-demo"` as the sessionId (test checks for this exact string)
- Keep prompts short and simple to minimize cost/latency

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency with existing examples)
3. Ensure the example runs correctly: `swift run MultiTurnExample`
4. Verify the example gracefully handles missing API key

---

## Key Risks and Assumptions

1. **Assumption: SessionStore, SessionData, SessionMetadata are stable and public** -- Epic 7 is complete with all APIs available.
2. **Assumption: Agent auto-saves/restores sessions** -- Agent's prompt() and stream() methods automatically handle session persistence.
3. **Assumption: Same Agent instance works for multiple turns** -- The story says calling prompt() multiple times on the same Agent is the simplest pattern.
4. **Risk: API key availability** -- All 3 turns require API calls. The example should use the loadDotEnv/getEnv fallback pattern.
5. **Risk: Streaming SDKMessage event type** -- Need to verify the exact type name for SDKMessage in the stream API.
6. **Assumption: Cross-turn context works reliably** -- The LLM should respond with "Nick" when asked "what is my name?" after being told. Using assert() for this check.
7. **Risk: SessionStore default directory** -- SessionStore() creates sessions in a default directory. Cleanup via delete() is important.

---

**Generated by BMad TEA Agent** - 2026-04-13
