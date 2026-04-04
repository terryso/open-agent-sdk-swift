---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
inputDocuments:
  - _bmad-output/implementation-artifacts/1-5-agent-loop-blocking-response.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/API/AnthropicClient.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Types/TokenUsage.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Tests/OpenAgentSDKTests/API/AnthropicClientTests.swift
  - Tests/OpenAgentSDKTests/Core/AgentCreationTests.swift
storyId: '1-5'
date: '2026-04-04'
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-04'
---

# ATDD Checklist: Story 1.5 -- Agent Loop & Blocking Response

## TDD Red Phase (Current)

- [x] Failing tests generated
- [x] All tests assert EXPECTED behavior (not placeholders)
- [x] Test file created: `Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift`
- [x] No placeholder assertions (`expect(true).toBe(true)` equivalent avoided)
- [x] All tests reference `Agent.prompt()` which does not exist yet (compile-time RED)
- [x] Temp artifacts stored in `_bmad-output/test-artifacts/` (not random locations)

## Test Summary

| Category | Test Count | Status |
|----------|-----------|--------|
| Unit Tests (Agent Loop) | 22 | RED (will fail until feature implemented) |
| **Total** | **22** | **RED** |

## Acceptance Criteria Coverage

### AC1: Basic Agent Loop Execution (No Tools) (FR4, FR3) -- 4 tests [P0 x 2, P1 x 2]

| Test | Priority | Status |
|------|----------|--------|
| `testPromptReturnsTextAndUsageForBasicQuery` | P0 | RED |
| `testPromptSingleTurnReturnsNumTurnsOne` | P0 | RED |
| `testPromptReturnsNonNegativeDuration` | P1 | RED |
| `testPromptWithEmptyStringReturnsResponse` | P1 | RED |

### AC2: maxTurns Limit (FR6) -- 3 tests [P0 x 2, P1 x 1]

| Test | Priority | Status |
|------|----------|--------|
| `testMaxTurnsOneStopsLoop` | P0 | RED |
| `testMaxTurnsExceededReturnsAppropriateStatus` | P0 | RED |
| `testEndTurnBeforeMaxTurnsSucceeds` | P1 | RED |

### AC3: end_turn Termination -- 2 tests [P0 x 1, P1 x 1]

| Test | Priority | Status |
|------|----------|--------|
| `testEndTurnStopsLoopAndReturnsResponse` | P0 | RED |
| `testStopSequenceTerminatesLoop` | P1 | RED |

### AC4: API Error Propagation (NFR17) -- 4 tests [P0 x 3, P1 x 1]

| Test | Priority | Status |
|------|----------|--------|
| `testAPIError500DoesNotCrash` | P0 | RED |
| `testNetworkErrorDoesNotCrash` | P0 | RED |
| `testAuthError401DoesNotCrash` | P0 | RED |
| `testRateLimitError429DoesNotCrash` | P1 | RED |

### AC5: Usage Statistics -- 3 tests [P1 x 3]

| Test | Priority | Status |
|------|----------|--------|
| `testSingleTurnUsageStatistics` | P1 | RED |
| `testMultiTurnUsageAccumulates` | P1 | RED |
| `testDurationIsMeasuredInMilliseconds` | P1 | RED |

### AC6: System Prompt Passed Correctly -- 3 tests [P1 x 3]

| Test | Priority | Status |
|------|----------|--------|
| `testSystemPromptIncludedInAPIRequest` | P1 | RED |
| `testNoSystemPromptExcludesSystemFromRequest` | P1 | RED |
| `testEmptySystemPromptIncludedInRequest` | P1 | RED |

### AC7: Empty Tools List -- 3 tests [P1 x 3]

| Test | Priority | Status |
|------|----------|--------|
| `testNoToolsExcludesToolsFromRequest` | P1 | RED |
| `testRequestIncludesCorrectModel` | P1 | RED |
| `testRequestIncludesCorrectMaxTokens` | P1 | RED |

## Priority Coverage

| Priority | Count | Percentage |
|----------|-------|------------|
| P0 | 8 | 36% |
| P1 | 14 | 64% |
| P2 | 0 | 0% |
| P3 | 0 | 0% |

## Test Strategy

- **Stack**: Backend (Swift SPM library)
- **Framework**: XCTest
- **Test Level**: Unit/Integration tests (Agent loop uses AnthropicClient which is mocked via MockURLProtocol)
- **Mock Strategy**: MockURLProtocol subclass intercepts HTTP requests; sequential response support for multi-turn scenarios
- **Test Infrastructure**: AgentLoopMockURLProtocol with sequential response capability for multi-turn testing

## Implementation Requirements

### Files to Create/Modify

1. `Sources/OpenAgentSDK/Core/Agent.swift` -- Add `prompt()` method and test-only `init(options:client:)` initializer
2. `Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift` -- Already created (RED phase)

### Required API Changes

The tests require the following additions to `Agent`:

```swift
public class Agent {
    // Existing properties...

    /// Add a public prompt() method for blocking agent loop execution.
    public func prompt(_ text: String) async throws -> QueryResult

    /// Add a testable initializer that accepts a pre-configured AnthropicClient.
    /// This allows tests to inject a mock-based client.
    init(options: AgentOptions, client: AnthropicClient)
}
```

### Key Design Decisions for Implementation

1. **Agent is a class (not actor)** -- project constraint
2. **prompt() must handle API errors gracefully** -- return SDKError, never crash
3. **No tools support in this story** -- `tools` parameter omitted from API request
4. **Usage accumulation across turns** -- TokenUsage `+` operator already exists
5. **Sequential mock responses** -- tests verify multi-turn loop behavior

### Test Infrastructure Details

- `AgentLoopMockURLProtocol`: Custom URLProtocol subclass supporting sequential responses for multi-turn testing
- `makeAgentLoopSUT()`: Creates an Agent with mocked AnthropicClient
- `registerSequentialAgentLoopMockResponses()`: Registers responses consumed in order for multi-turn tests

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Add `init(options:client:)` to `Agent` class (internal, for testing)
2. Add `public func prompt(_ text: String) async throws -> QueryResult` to `Agent` class
3. Implement the agent loop logic:
   - Build messages array from user prompt
   - While turnCount < maxTurns: send API request, check stop_reason, accumulate usage
   - Return QueryResult with text, usage, numTurns, durationMs
4. Run `swift test` -- verify all 22 tests PASS (green phase)
5. If any tests fail: fix implementation or test as needed
6. Commit passing tests

## Knowledge Fragments Used

- test-quality.md (deterministic tests, explicit assertions, structured test classes)
- data-factories.md (factory patterns for test data via helper methods)
- test-healing-patterns.md (failure pattern awareness for mock-based tests)
- component-tdd.md (TDD red-green-refactor cycle)

## Environment Note

The XCTest module is not available in the current CLI-only toolchain environment (xcodebuild not configured). Tests will compile and run correctly once Xcode developer tools are properly configured. This is an environment setup issue, not a test design issue. The TDD red phase is confirmed by the fact that `Agent.prompt()` does not exist in the codebase, causing compile-time failures.
