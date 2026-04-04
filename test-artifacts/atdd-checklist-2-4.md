---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-05'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-4-llm-api-retry-max-tokens-recovery.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/ErrorTypes.swift'
  - 'Sources/OpenAgentSDK/API/AnthropicClient.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/BudgetEnforcementTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/StreamTests.swift'
---

# ATDD Checklist: Story 2.4 — LLM API Retry & max_tokens Recovery

## Stack Detection
- **Detected Stack:** `backend` (Swift Package Manager, XCTest, no frontend/browser indicators)
- **Generation Mode:** AI Generation (backend project, no browser recording needed)

## Test Strategy

### Test Levels
| Level | Usage |
|-------|-------|
| Unit | RetryConfig, isRetryableError, getRetryDelay, withRetry pure functions |
| Integration | Agent.prompt() and Agent.stream() with retry and max_tokens recovery via MockURLProtocol |

### Priority Definitions
| Priority | Meaning |
|----------|---------|
| P0 | Must-pass for story acceptance — blocks merge |
| P1 | Important — should pass before story is considered complete |
| P2 | Edge case / defensive — nice to have |

## Acceptance Criteria to Test Mapping

### AC1: Transient Error Auto-Retry (Blocking Path) [P0]
- **Test Level:** Integration (Agent.prompt() via MockURLProtocol)
- **Scenarios:**
  1. HTTP 503 x2 then success on 3rd attempt — prompt() returns success result
  2. HTTP 429 x4 (exceeds 3 retries) — prompt() returns errorDuringExecution
  3. HTTP 500 then success — verifies single retry works
- **Files:** `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift`

### AC2: Transient Error Auto-Retry (Streaming Path) [P0]
- **Test Level:** Integration (Agent.stream() via StreamMockURLProtocol)
- **Scenarios:**
  1. HTTP 503 x2 then success on 3rd attempt — stream yields success result
  2. HTTP 429 x4 (exceeds 3 retries) — stream yields errorDuringExecution result
- **Files:** `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift`

### AC3: max_tokens Continuation Recovery (Blocking Path) [P0]
- **Test Level:** Integration (Agent.prompt() via MockURLProtocol)
- **Scenarios:**
  1. max_tokens x2 then end_turn — prompt() returns success with accumulated text
  2. max_tokens x4 (exceeds 3 recovery limit) — prompt() returns success with partial text (NOT errorDuringExecution)
  3. Continuation prompt text is "Please continue from where you left off." (not "continue")
- **Files:** `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift`

### AC4: max_tokens Continuation Recovery (Streaming Path) [P0]
- **Test Level:** Integration (Agent.stream() via StreamMockURLProtocol)
- **Scenarios:**
  1. max_tokens x2 then end_turn — stream yields success with accumulated text
  2. max_tokens x4 (exceeds 3 recovery limit) — stream yields success result with partial text
- **Files:** `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift`

### AC5: Non-Transient Errors Not Retried [P0]
- **Test Level:** Integration (both paths via MockURLProtocol)
- **Scenarios:**
  1. HTTP 401 (blocking) — returns error immediately, no retry (1 request total)
  2. HTTP 403 (blocking) — returns error immediately, no retry (1 request total)
  3. HTTP 400 (streaming) — returns error immediately, no retry (1 request total)
- **Files:** `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift`

### AC6: API Key Security [P1]
- **Test Level:** Unit (verify error message sanitization)
- **Scenarios:**
  1. Error messages in retry exhaustion do not contain API key
  2. Error messages from non-transient errors do not contain API key
- **Files:** `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift`

## Unit Tests for Retry Utilities

### RetryConfig Defaults [P1]
- **Test Level:** Unit
- **Scenarios:**
  1. RetryConfig.default has maxRetries=3
  2. RetryConfig.default has retryableStatusCodes=[429,500,502,503,529]
  3. Custom RetryConfig values are respected

### isRetryableError [P0]
- **Test Level:** Unit
- **Scenarios:**
  1. SDKError.apiError(statusCode: 429) — retryable
  2. SDKError.apiError(statusCode: 500) — retryable
  3. SDKError.apiError(statusCode: 502) — retryable
  4. SDKError.apiError(statusCode: 503) — retryable
  5. SDKError.apiError(statusCode: 529) — retryable
  6. SDKError.apiError(statusCode: 400) — NOT retryable
  7. SDKError.apiError(statusCode: 401) — NOT retryable
  8. SDKError.apiError(statusCode: 403) — NOT retryable
  9. Non-SDKError — NOT retryable

### getRetryDelay [P1]
- **Test Level:** Unit
- **Scenarios:**
  1. Exponential backoff: attempt 0 > attempt 1 > attempt 2
  2. Delay does not exceed maxDelayMs
  3. Custom config values are respected

### withRetry [P0]
- **Test Level:** Unit
- **Scenarios:**
  1. Success on first attempt — returns immediately
  2. Retryable error x2 then success — returns result after retries
  3. Non-retryable error — throws immediately without retry
  4. All retries exhausted — throws last error
- **Files:** `Tests/OpenAgentSDKTests/Utils/RetryTests.swift`

## TDD Red Phase Confirmation
- All tests assert EXPECTED behavior that does NOT exist yet
- Tests will FAIL until:
  - `Utils/Retry.swift` is created with RetryConfig, isRetryableError, getRetryDelay, withRetry
  - `Agent.prompt()` wraps client.sendMessage() in withRetry
  - `Agent.stream()` wraps capturedClient.streamMessage() in withRetry
  - max_tokens recovery counter (max 3) is added to both prompt() and stream()
  - Continuation prompt text changes from "continue" to "Please continue from where you left off."

## Test Files

| File | Purpose | AC Coverage |
|------|---------|-------------|
| `Tests/OpenAgentSDKTests/Utils/RetryTests.swift` | RetryConfig, isRetryableError, getRetryDelay, withRetry unit tests | AC1, AC2, AC5 |
| `Tests/OpenAgentSDKTests/Core/RetryAndRecoveryTests.swift` | Integration tests for retry + max_tokens recovery in prompt() and stream() | AC1-AC6 |

## Summary Statistics
- **Total Test Cases:** 28
- **P0 (must-pass):** 18
- **P1 (important):** 10
- **P2 (edge case):** 0
- **Test Files:** 2 new files
