---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-04'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-1-async-stream-response.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/API/APIModels.swift'
  - 'Sources/OpenAgentSDK/API/AnthropicClient.swift'
  - 'Sources/OpenAgentSDK/API/Streaming.swift'
  - 'Sources/OpenAgentSDK/Types/TokenUsage.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/API/StreamingTests.swift'
---

# ATDD Checklist - Epic 2, Story 2.1: AsyncStream Streaming Response

**Date:** 2026-04-04
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Integration (Agent + Mock AnthropicClient via MockURLProtocol)
**Detected Stack:** backend (Swift Package, XCTest)

---

## Story Summary

Implement streaming response via AsyncStream<SDKMessage> on the Agent class, allowing developers to consume LLM responses as real-time typed events (partialMessage, assistant, result) instead of a single blocking QueryResult.

**As a** developer using the OpenAgentSDK
**I want** to consume Agent responses as a real-time event stream via `agent.stream("prompt")`
**So that** I can display progressive results in my application UI

---

## Acceptance Criteria

1. **AC1: AsyncStream<SDKMessage> Return** -- `agent.stream("text")` returns `AsyncStream<SDKMessage>` immediately; SDKMessage events are yielded as they arrive from the LLM
2. **AC2: Typed Event Stream** -- Stream emits typed events: text deltas (partialMessage), tool use start (assistant), tool results (toolResult), usage updates, and completion (result); developers can pattern-match with `case let`
3. **AC3: Error Events** -- On API error, an error event is emitted on the stream and the stream terminates gracefully
4. **AC4: end_turn Termination** -- When LLM returns stop_reason="end_turn", a `.result(subtype: .success)` event is emitted and the stream terminates
5. **AC5: maxTurns Limit** -- With maxTurns=2, when the agent reaches 2 turns, a `.result(subtype: .errorMaxTurns)` event is emitted and the stream terminates
6. **AC6: Usage Statistics** -- The final `.result` event contains accumulated `usage`, `numTurns`, and `durationMs`
7. **AC7: stream/prompt API Consistency** -- `stream()` and `prompt()` have the same parameter signature (only `text: String`), differing only in return type

---

## Test Strategy

**Stack:** Backend (Swift) -- XCTest framework with MockURLProtocol

**Test Levels:**
- **Integration** (primary): Agent.stream() + Mock AnthropicClient (via MockURLProtocol) -- validates full event mapping pipeline
- **Unit** (supplementary): API signature validation -- verifies public API consistency

**Execution Mode:** Sequential (single agent, backend-only project)

---

## Generation Mode

**Mode:** AI Generation
**Reason:** Backend Swift project with XCTest. No browser UI. Acceptance criteria are clear with well-defined SSE event sequences. All scenarios are API-level integration tests with mock network responses.

---

## Failing Tests Created (RED Phase)

### Integration Tests (14 tests)

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift` (~500 lines)

- **Test:** `testStreamReturnsAsyncStreamOfSDKMessage`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC1 -- stream() returns AsyncStream<SDKMessage>
  - **Priority:** P0

- **Test:** `testStreamYieldsPartialMessageEvents`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC2 -- content_block_delta maps to .partialMessage
  - **Priority:** P0

- **Test:** `testStreamYieldsAssistantEventOnMessageStop`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC2 -- message_stop maps to .assistant with accumulated text, model, stopReason
  - **Priority:** P0

- **Test:** `testStreamYieldsResultEventOnEndTurn`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC4 -- end_turn produces .result(subtype: .success)
  - **Priority:** P0

- **Test:** `testStreamTerminatesOnEndTurn`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC4 -- stream finishes after end_turn result
  - **Priority:** P0

- **Test:** `testStreamYieldsErrorResultOnHTTPError`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC3 -- HTTP 500 produces .result(subtype: .errorDuringExecution)
  - **Priority:** P0

- **Test:** `testStreamYieldsErrorResultOnSSEErrorEvent`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC3 -- SSE error event produces .result(subtype: .errorDuringExecution)
  - **Priority:** P0

- **Test:** `testStreamGracefullyTerminatesOnError`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC3 -- stream finishes after error result event
  - **Priority:** P0

- **Test:** `testStreamMaxTurnsLimitEmitsErrorMaxTurns`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC5 -- maxTurns=2 reached produces .result(subtype: .errorMaxTurns)
  - **Priority:** P0

- **Test:** `testStreamResultContainsAccumulatedUsage`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC6 -- result event has correct inputTokens/outputTokens accumulation
  - **Priority:** P0

- **Test:** `testStreamResultContainsNumTurns`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC6 -- result event has correct numTurns
  - **Priority:** P1

- **Test:** `testStreamResultContainsDurationMs`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC6 -- result event has non-negative durationMs
  - **Priority:** P1

- **Test:** `testStreamAndPromptHaveMatchingParameterSignatures`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC7 -- both methods accept only `text: String`
  - **Priority:** P1

- **Test:** `testStreamWithEmptyStringReturnsStream`
  - **Status:** RED - `Agent` does not have a `stream()` method yet
  - **Verifies:** AC1 edge case -- empty string prompt does not crash
  - **Priority:** P2

---

## Mock Requirements

### Anthropic Streaming API Mock

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Success Response (SSE text/event-stream):**

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":10}}

event: message_stop
data: {"type":"message_stop"}
```

**Failure Response (HTTP 500):**

```json
{
  "error": {
    "type": "api_error",
    "message": "Internal server error"
  }
}
```

**Notes:** Uses `StreamMockURLProtocol` (same pattern as `AgentLoopMockURLProtocol` in AgentLoopTests.swift). SSE response body is plain text with `event:` and `data:` lines separated by blank lines.

---

## Implementation Checklist

### Test: testStreamReturnsAsyncStreamOfSDKMessage

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Add `public func stream(_ text: String) -> AsyncStream<SDKMessage>` to Agent class
- [ ] Use `AsyncStream<SDKMessage>` continuation builder pattern
- [ ] Inside the stream, call `client.streamMessage()` to get SSE event stream
- [ ] Iterate over SSE events and yield SDKMessage values
- [ ] Call `continuation.finish()` to close the stream
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 2 hours

---

### Test: testStreamYieldsPartialMessageEvents

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Handle `content_block_delta` SSE event in stream() method
- [ ] Extract `delta["text"]` from the event
- [ ] Yield `.partialMessage(PartialData(text: deltaText))` via continuation
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours (part of core stream() implementation)

---

### Test: testStreamYieldsAssistantEventOnMessageStop

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Accumulate text from all `content_block_delta` events
- [ ] Track `model` from `message_start` event
- [ ] Track `stopReason` from `message_delta` event
- [ ] On `message_stop` event, yield `.assistant(AssistantData(...))` with accumulated values
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours (part of core stream() implementation)

---

### Test: testStreamYieldsResultEventOnEndTurn

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] After `message_stop`, check `stopReason == "end_turn"` to break the turn loop
- [ ] After the turn loop ends, yield `.result(ResultData(subtype: .success, ...))`
- [ ] Include accumulated usage, turnCount, and durationMs
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testStreamTerminatesOnEndTurn

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Ensure `continuation.finish()` is called after yielding the final `.result` event
- [ ] Verify stream iteration ends (for-in loop completes)
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testStreamYieldsErrorResultOnHTTPError

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Wrap `client.streamMessage()` call in do/catch
- [ ] On API connection error, yield `.result(subtype: .errorDuringExecution, ...)`
- [ ] Call `continuation.finish()` after error result
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testStreamYieldsErrorResultOnSSEErrorEvent

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Handle `SSEEvent.error` case in the SSE event iteration
- [ ] Yield `.result(subtype: .errorDuringExecution, ...)` on error event
- [ ] Call `continuation.finish()` and return from the Task
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testStreamGracefullyTerminatesOnError

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Verify stream iteration completes after error (no hang)
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testStreamMaxTurnsLimitEmitsErrorMaxTurns

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Implement `while turnCount < maxTurns` loop in stream() (same as prompt())
- [ ] When loop exits due to maxTurns, yield `.result(subtype: .errorMaxTurns, ...)`
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testStreamResultContainsAccumulatedUsage

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Accumulate TokenUsage from `message_delta` events using `totalUsage = totalUsage + turnUsage`
- [ ] Include totalUsage in the final `.result` event
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testStreamAndPromptHaveMatchingParameterSignatures

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Ensure `stream()` accepts only `(_ text: String)` and returns `AsyncStream<SDKMessage>`
- [ ] Ensure `prompt()` accepts only `(_ text: String)` and returns `QueryResult`
- [ ] Compile-time check passes
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.1 hours

---

### Test: testStreamWithEmptyStringReturnsStream

**File:** `Tests/OpenAgentSDKTests/Core/StreamTests.swift`

**Tasks to make this test pass:**

- [ ] Handle empty string prompt in stream() (no crash, produces events)
- [ ] Run test: `swift test --filter StreamTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.1 hours

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter StreamTests

# Run specific test class
swift test --filter StreamAsyncStreamTests
swift test --filter StreamErrorEventTests
swift test --filter StreamMaxTurnsTests
swift test --filter StreamUsageStatsTests
swift test --filter StreamAPISignatureTests

# Run full test suite
swift test

# Build without running
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- [x] All tests written and failing (Agent.stream() does not exist)
- [x] Mock requirements documented
- [x] Implementation checklist created
- [x] SSE event sequences documented

**Verification:**

- All tests will fail to compile because `Agent` has no `stream()` method
- Failure is clear: "value of type 'Agent' has no member 'stream'"
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1.1:** Add `stream()` method stub to Agent.swift
2. **Implement SSE event processing** inside the stream continuation
3. **Handle all event types:** message_start, content_block_delta, message_delta, message_stop, error
4. **Implement turn loop** with maxTurns limit
5. **Run tests** after each implementation step
6. **Move to next test** until all pass

**Key Principles:**

- One test at a time (start with AC1 basic stream return)
- Minimal implementation (follow story dev notes skeleton code)
- Run tests frequently (immediate feedback)
- Use implementation checklist as roadmap

---

### REFACTOR Phase (After All Tests Pass)

1. Verify all tests pass (green phase complete)
2. Extract `computeDurationMs()` helper if duplicated with prompt()
3. Review error handling completeness
4. Ensure tests still pass after each refactor
5. No force unwraps, no Codable for SSE events

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter StreamTests`

**Expected Results:**

```
Compile error: value of type 'Agent' has no member 'stream'
```

**Summary:**

- Total tests: 14
- Passing: 0 (expected)
- Failing: 14 (expected -- compile error, method does not exist)
- Status: RED phase verified

---

## Notes

- Swift concurrency: `stream()` returns `AsyncStream<SDKMessage>` (not async), uses `Task {}` inside continuation for async work
- `continuation.finish()` MUST be called in all code paths (error, success, maxTurns) to prevent consumer hangs
- The `StreamMockURLProtocol` uses the same pattern as `AgentLoopMockURLProtocol` but registers SSE-format responses
- Sequential mock responses support multi-turn testing (same pattern as `sequentialResponses` in AgentLoopTests)
- No tool execution in this story -- no toolResult events will be produced
- The AnthropicClient.streamMessage() already exists and returns `AsyncThrowingStream<SSEEvent, Error>`

---

**Generated by BMad TEA Agent** - 2026-04-04
