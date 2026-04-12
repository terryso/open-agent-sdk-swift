---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/13-1-runtime-dynamic-model-switching.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Types/ErrorTypes.swift'
  - 'Sources/OpenAgentSDK/Types/TokenUsage.swift'
  - 'Sources/OpenAgentSDK/Types/ModelInfo.swift'
  - 'Sources/OpenAgentSDK/Utils/Tokens.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/CostTrackingTests.swift'
---

# ATDD Checklist - Epic 13, Story 13.1: Runtime Dynamic Model Switching

**Date:** 2026-04-12
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Integration (Agent + Mock AnthropicClient via MockURLProtocol)
**Detected Stack:** backend (Swift Package, XCTest)

---

## Story Summary

Implement runtime dynamic model switching on the Agent class, allowing developers to switch LLM models mid-session. Includes per-model cost breakdown tracking and validation of model name (reject empty, allow unknown).

**As a** developer using the OpenAgentSDK
**I want** to dynamically switch LLM models during an Agent session
**So that** I can choose the most appropriate model for each task without restarting the session

---

## Acceptance Criteria

1. **AC1: Basic Model Switching** -- Given an Agent with "claude-sonnet-4-6", when developer calls `agent.switchModel("claude-opus-4-6")`, method returns Void without error, and subsequent `agent.stream(...)` / `agent.prompt(...)` sends API requests with `model` = "claude-opus-4-6" (FR59).
2. **AC2: Multi-Model Cost Breakdown** -- Given model switched from sonnet to opus, when query completes, `result.costBreakdown` contains per-model token counts and costs, total = sum of per-model costs.
3. **AC3: Empty Model Name Rejection** -- Given developer calls `agent.switchModel("")`, method throws `SDKError.invalidConfiguration("Model name cannot be empty")`, model unchanged, session not interrupted.
4. **AC4: Unknown Model Name Allowed** -- Given developer calls `agent.switchModel("some-new-model-name")`, method succeeds (no whitelist), if API returns 404, error reported normally on next query.

---

## Test Strategy

**Stack:** Backend (Swift) -- XCTest framework with MockURLProtocol

**Test Levels:**
- **Integration** (primary): Agent.switchModel() + Agent.prompt() with Mock AnthropicClient -- validates full model switching pipeline including API request body inspection
- **Unit** (supplementary): Type existence tests for CostBreakdownEntry, SDKError.invalidConfiguration, QueryResult.costBreakdown, ResultData.costBreakdown

**Execution Mode:** Sequential (single agent, backend-only project)

---

## Generation Mode

**Mode:** AI Generation
**Reason:** Backend Swift project with XCTest. No browser UI. Acceptance criteria are clear with well-defined behaviors. All scenarios are API-level integration tests with mock network responses.

---

## Failing Tests Created (RED Phase)

### Integration Tests (20 tests)

**File:** `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

#### AC1: Basic Model Switching (4 tests)

- **Test:** `testSwitchModel_UpdatesAgentModelProperty`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC1 -- switchModel updates agent.model property
  - **Priority:** P0

- **Test:** `testSwitchModel_SubsequentPromptUsesNewModel`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC1 -- subsequent prompt() sends API request with new model
  - **Priority:** P0

- **Test:** `testSwitchModel_UpdatesInternalOptionsModel`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC1 -- switchModel updates internal options.model
  - **Priority:** P1

- **Test:** `testSDKError_InvalidConfiguration_Exists`
  - **Status:** RED - `SDKError` has no member `invalidConfiguration`
  - **Verifies:** AC3 prerequisite -- error case exists
  - **Priority:** P0

#### AC2: Multi-Model Cost Breakdown (7 tests)

- **Test:** `testCostBreakdown_ContainsEntriesAfterModelSwitch`
  - **Status:** RED - `QueryResult` has no member `costBreakdown`
  - **Verifies:** AC2 -- costBreakdown contains entries after model switch
  - **Priority:** P0

- **Test:** `testCostBreakdownEntry_HasCorrectFields`
  - **Status:** RED - `CostBreakdownEntry` not found in scope
  - **Verifies:** AC2 -- CostBreakdownEntry has model, inputTokens, outputTokens, costUsd
  - **Priority:** P0

- **Test:** `testCostBreakdownEntry_IsEquatable`
  - **Status:** RED - `CostBreakdownEntry` not found in scope
  - **Verifies:** AC2 -- CostBreakdownEntry conforms to Equatable
  - **Priority:** P1

- **Test:** `testCostBreakdown_SingleModelCostMatchesTotal`
  - **Status:** RED - `QueryResult` has no member `costBreakdown`
  - **Verifies:** AC2 -- single model cost matches totalCostUsd
  - **Priority:** P1

- **Test:** `testCostBreakdown_DefaultsToEmptyArray`
  - **Status:** RED - `QueryResult` has no member `costBreakdown`
  - **Verifies:** AC2 -- costBreakdown defaults to empty array
  - **Priority:** P2

- **Test:** `testQueryResult_AcceptsCostBreakdown`
  - **Status:** RED - extra argument `costBreakdown` in call
  - **Verifies:** AC2 -- QueryResult init accepts costBreakdown
  - **Priority:** P0

- **Test:** `testResultData_AcceptsCostBreakdown`
  - **Status:** RED - `SDKMessage.ResultData` has no member `costBreakdown`
  - **Verifies:** AC2 -- ResultData init accepts costBreakdown (streaming)
  - **Priority:** P0

#### AC3: Empty Model Name Rejection (4 tests)

- **Test:** `testSwitchModel_EmptyString_ThrowsInvalidConfiguration`
  - **Status:** RED - `Agent` has no member `switchModel`, `SDKError` has no member `invalidConfiguration`
  - **Verifies:** AC3 -- empty string throws correct error
  - **Priority:** P0

- **Test:** `testSwitchModel_EmptyString_DoesNotChangeModel`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC3 -- model unchanged after rejection
  - **Priority:** P0

- **Test:** `testSwitchModel_WhitespaceOnly_ThrowsInvalidConfiguration`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC3 -- whitespace-only also rejected
  - **Priority:** P1

- **Test:** `testSDKError_InvalidConfiguration_IsEquatable`
  - **Status:** RED - `SDKError` has no member `invalidConfiguration`
  - **Verifies:** AC3 -- error is equatable for test comparison
  - **Priority:** P1

#### AC4: Unknown Model Name Allowed (4 tests)

- **Test:** `testSwitchModel_UnknownModel_Succeeds`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC4 -- unknown model name accepted
  - **Priority:** P0

- **Test:** `testSwitchModel_UnknownModel_ApiRequestUsesUnknownModel`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC4 -- API request uses unknown model (no whitelist)
  - **Priority:** P0

- **Test:** `testSwitchModel_SwitchBackToKnownModel`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC4 -- can switch back to known model
  - **Priority:** P1

- **Test:** `testSwitchModel_MultipleSwitches`
  - **Status:** RED - `Agent` has no member `switchModel`
  - **Verifies:** AC4 -- multiple rapid switches all applied
  - **Priority:** P1

#### Type Existence Tests (3 tests)

- **Test:** `testCostBreakdownEntry_CanBeInitialized`
  - **Status:** RED - `CostBreakdownEntry` not found in scope
  - **Verifies:** Type exists with correct init signature
  - **Priority:** P0

- **Test:** `testCostBreakdownEntry_IsSendable`
  - **Status:** RED - `CostBreakdownEntry` not found in scope
  - **Verifies:** Conforms to Sendable (Swift concurrency)
  - **Priority:** P0

- **Test:** `testResultData_CostBreakdown_DefaultsToEmpty`
  - **Status:** RED - `SDKMessage.ResultData` has no member `costBreakdown`
  - **Verifies:** Default value is empty array
  - **Priority:** P1

---

## Compilation Error Categories (TDD Red Phase Verified)

| Error Category | Count | Missing Feature |
|---|---|---|
| `Agent` has no member `switchModel` | 10+ | Agent.switchModel() method |
| `CostBreakdownEntry` not found | 16 | CostBreakdownEntry struct |
| `SDKError` has no member `invalidConfiguration` | 6 | SDKError.invalidConfiguration case |
| `QueryResult` has no member `costBreakdown` | 6 | QueryResult.costBreakdown field |
| Extra argument `costBreakdown` in call | 3 | QueryResult/ResultData init update |
| `ResultData` has no member `costBreakdown` | 1 | ResultData.costBreakdown field |

---

## Mock Requirements

### Anthropic API Mock

Uses existing `AgentLoopMockURLProtocol` from `AgentLoopTests.swift` (same mock URL protocol pattern).

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Success Response (non-streaming):**

```json
{
  "id": "msg_loop_001",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "Response text"}],
  "model": "claude-opus-4-6",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 50, "output_tokens": 100}
}
```

**Notes:** Tests use `AgentLoopMockURLProtocol.lastRequest` to inspect the outbound API request body and verify the `model` field matches the switched model.

---

## Implementation Checklist

### Test: testSwitchModel_UpdatesAgentModelProperty

**File:** `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

**Tasks to make this test pass:**

- [ ] Add `public func switchModel(_ model: String) throws` to Agent class
- [ ] Change `Agent.model` from `public let` to `public private(set) var`
- [ ] Validate model is non-empty: throw `SDKError.invalidConfiguration` if empty
- [ ] Update `self.model = model` and `self.options.model = model`
- [ ] Run test: `swift test --filter ModelSwitchBasicTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testSwitchModel_SubsequentPromptUsesNewModel

**File:** `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

**Tasks to make this test pass:**

- [ ] Ensure `prompt()` reads `self.model` in the API call (already reads via `let retryModel = self.model` in loop)
- [ ] Since model is now `var`, the captured value reflects the latest switchModel() call
- [ ] Run test: `swift test --filter ModelSwitchBasicTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours (follows from previous task)

---

### Test: testCostBreakdown_ContainsEntriesAfterModelSwitch

**File:** `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

**Tasks to make this test pass:**

- [ ] Define `CostBreakdownEntry` struct in `Types/AgentTypes.swift`
- [ ] Add `costBreakdown: [CostBreakdownEntry]` field to `QueryResult`
- [ ] Add `costBreakdown: [CostBreakdownEntry]` field to `SDKMessage.ResultData`
- [ ] In `Agent.prompt()`, track per-model costs using `var costByModel: [String: CostBreakdownEntry]`
- [ ] After each API call, aggregate tokens and cost by current model name
- [ ] Assign `costBreakdown` to QueryResult before returning
- [ ] Run test: `swift test --filter ModelSwitchCostBreakdownTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 1.5 hours

---

### Test: testSwitchModel_EmptyString_ThrowsInvalidConfiguration

**File:** `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

**Tasks to make this test pass:**

- [ ] Add `case invalidConfiguration(String)` to `SDKError` enum in `ErrorTypes.swift`
- [ ] Update `errorDescription` computed property for the new case
- [ ] Update `message` computed property for the new case
- [ ] In `switchModel()`, check for empty/whitespace string and throw the error
- [ ] Run test: `swift test --filter ModelSwitchEmptyNameTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testSwitchModel_UnknownModel_Succeeds

**File:** `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

**Tasks to make this test pass:**

- [ ] Ensure `switchModel()` does NOT validate against a whitelist
- [ ] Accept any non-empty string as a valid model name
- [ ] Run test: `swift test --filter ModelSwitchUnknownModelTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.1 hours (already covered by basic switchModel implementation)

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter ModelSwitchingTests

# Run specific test classes
swift test --filter ModelSwitchBasicTests
swift test --filter ModelSwitchCostBreakdownTests
swift test --filter ModelSwitchEmptyNameTests
swift test --filter ModelSwitchUnknownModelTests
swift test --filter SDKErrorInvalidConfigurationTests
swift test --filter CostBreakdownEntryTypeTests
swift test --filter QueryResultCostBreakdownTests
swift test --filter ResultDataCostBreakdownTests

# Run full test suite
swift test

# Build without running
swift build
swift build --build-tests
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- [x] All tests written and failing (compile errors)
- [x] Mock requirements documented
- [x] Implementation checklist created
- [x] Error categories documented

**Verification:**

- All tests fail to compile due to missing:
  - `Agent.switchModel()` method
  - `CostBreakdownEntry` type
  - `SDKError.invalidConfiguration` case
  - `QueryResult.costBreakdown` field
  - `SDKMessage.ResultData.costBreakdown` field
- Failure is clear: compilation errors pointing to missing features
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Task 1:** Add `SDKError.invalidConfiguration(String)` case to `ErrorTypes.swift`
2. **Task 2:** Define `CostBreakdownEntry` struct in `AgentTypes.swift`
3. **Task 3:** Add `costBreakdown` fields to `QueryResult` and `ResultData`
4. **Task 4:** Change `Agent.model` from `let` to `public private(set) var`
5. **Task 5:** Implement `Agent.switchModel()` method with empty string validation
6. **Task 6:** Add costByModel tracking to `Agent.prompt()` loop
7. **Task 7:** Run tests after each step
8. **Task 8:** Verify all 20 tests pass

**Key Principles:**

- One task at a time (start with type definitions)
- Minimal implementation
- Run tests frequently (immediate feedback)
- Use implementation checklist as roadmap

---

### REFACTOR Phase (After All Tests Pass)

1. Verify all tests pass (green phase complete)
2. Consider adding costByModel tracking to `stream()` method (for streaming cost breakdown)
3. Review error handling completeness
4. Ensure tests still pass after each refactor
5. Run full test suite to verify no regressions

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift build --build-tests`

**Expected Results:**

```
Compile errors:
- value of type 'Agent' has no member 'switchModel'
- cannot find 'CostBreakdownEntry' in scope
- type 'SDKError' has no member 'invalidConfiguration'
- value of type 'QueryResult' has no member 'costBreakdown'
- extra argument 'costBreakdown' in call
- value of type 'SDKMessage.ResultData' has no member 'costBreakdown'
```

**Summary:**

- Total tests: 20 (across 8 test classes)
- Passing: 0 (expected)
- Failing: 20 (expected -- compile errors, features not implemented)
- Status: RED phase verified

---

## Notes

- Tests follow existing pattern from `AgentLoopTests.swift` and `CostTrackingTests.swift` (MockURLProtocol-based integration tests)
- `switchModel()` is synchronous (not async) -- matches TypeScript SDK's `setModel()` and existing `setPermissionMode()` pattern
- `CostBreakdownEntry` is a value type (struct) that is Sendable and Equatable for safe concurrency
- stream() tests are not included in this ATDD because stream() uses captured variables -- switchModel() takes effect on the NEXT stream() call, not mid-stream (this is documented as acceptable behavior in the story dev notes)
- The whitespace-only string test (AC3) is an edge case beyond the story's explicit AC -- it validates robustness of the empty string check
- No tool execution in this story -- no tool-related test scenarios needed

---

**Generated by BMad TEA Agent** - 2026-04-12
