---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-04'
inputDocuments:
  - _bmad-output/implementation-artifacts/1-2-custom-anthropic-api-client.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
---

# ATDD Checklist -- Story 1.2: Custom Anthropic API Client

## Step 1: Preflight & Context

- **Stack:** backend (Swift 6.2.4, XCTest)
- **Story:** 1-2-custom-anthropic-api-client.md
- **Acceptance Criteria:** 8 ACs (AC1-AC8)
- **Test Framework:** XCTest (Swift built-in, configured via Package.swift)
- **Dev Environment:** Swift 6.2.4 on macOS arm64
- **Knowledge Loaded:** test-quality, test-levels-framework, test-priorities-matrix (from prior ATDD run)

## Step 2: Generation Mode

- **Mode:** AI Generation (sequential)
- **Reason:** Backend Swift project -- no browser recording needed
- **Source:** Story acceptance criteria + architecture documentation + Anthropic API docs embedded in story

## Step 3: Test Strategy

### AC to Scenario Mapping

| AC | Description | Scenarios | Level | Priority |
|---|---|---|---|---|
| AC1 | Basic message creation (non-streaming) | 7 scenarios: response structure, content blocks, usage, actor type, API key security, headers, request body | Unit + Integration | P0 |
| AC2 | Custom Base URL | 2 scenarios: custom URL used, default URL fallback | Unit | P0 |
| AC3 | Streaming SSE response | 11 scenarios: AsyncThrowingStream, text_delta, input_json_delta, thinking_delta, signature_delta, full sequence, ping, error events, stream:true body, headers, messageDelta, content block indices | Unit + Integration | P0 |
| AC4 | Tools request | 2 scenarios: tool_use response parsing, tools serialization in request body | Unit | P0 |
| AC5 | System prompt | 2 scenarios: system as top-level param, absent when nil | Unit | P0 |
| AC6 | Thinking configuration | 3 scenarios: enabled config, disabled config, thinking blocks in response | Unit | P1 |
| AC7 | Error response handling | 6 scenarios: 401, 429, 500, 503, API key exposure check, sequential errors | Unit | P0 |
| AC8 | Dual platform compilation | 1 scenario: Foundation-only import check | Integration (build) | P1 |

## Step 4: Test Generation (RED PHASE)

### Files Generated

| File | AC Coverage | Priority | Tests |
|---|---|---|---|
| `Tests/OpenAgentSDKTests/API/AnthropicClientTests.swift` | AC1, AC2, AC4, AC5, AC6, AC7, AC8 | P0/P1 | 26 |
| `Tests/OpenAgentSDKTests/API/StreamingTests.swift` | AC3 | P0 | 11 + 9 (SSEEvent enum) |
| **Total** | | | **46** |

### Test Breakdown by AC

**AC1 (7 tests):** testSendMessageReturnsCompleteResponse, testSendMessageResponseContainsContentBlocks, testSendMessageResponseContainsUsage, testAnthropicClientIsActor, testAPIKeyNotExposedInErrorMessage, testSendMessageIncludesCorrectHeaders, testSendMessageRequestBodyStructure

**AC2 (2 tests):** testCustomBaseURLUsedInRequests, testDefaultBaseURLIsAnthropicAPI

**AC3 (11 streaming tests):** testStreamMessageReturnsAsyncThrowingStream, testTextDeltaParsedIncrementally, testInputJSONDeltaParsedForToolInput, testThinkingDeltaParsed, testCompleteSSEEventSequence, testPingEventHandled, testSSEErrorEventHandled, testStreamRequestBodySetsStreamTrue, testStreamRequestIncludesCorrectHeaders, testMessageDeltaContainsStopReasonAndUsage, testContentBlockEventsHaveCorrectIndices

**AC3 (9 SSEEvent enum tests):** testMessageStartCase, testContentBlockStartCase, testContentBlockDeltaCase, testContentBlockStopCase, testMessageDeltaCase, testMessageStopCase, testPingCase, testErrorCase, testSSEEventIsSendable

**AC4 (2 tests):** testToolsRequestParsesToolUseResponse, testToolsSerializedInRequestBody

**AC5 (2 tests):** testSystemPromptSentAsTopLevelParameter, testNoSystemKeyWhenSystemPromptIsNil

**AC6 (3 tests):** testThinkingConfigSerializedInRequestBody, testThinkingDisabledSerializedInRequestBody, testThinkingBlocksParsedInResponse

**AC7 (6 tests):** testAuthenticationError401, testRateLimitError429, testInternalServerError500, testServiceUnavailableError503, testErrorDoesNotContainAPIKey, testMultipleErrorsHandledIndependently

**AC8 (1 test):** testAPIImportsOnlyFoundation

### TDD Status: RED

All 46 tests reference types that do not exist yet:
- `AnthropicClient` -- actor with `sendMessage` and `streamMessage` methods
- `SSEEvent` -- enum with 8 cases (messageStart, contentBlockStart, contentBlockDelta, contentBlockStop, messageDelta, messageStop, ping, error)
- `MockURLProtocol` -- custom URLProtocol subclass for network interception

These types will be created during Story 1.2 implementation. The tests will not compile until then.

### Test Infrastructure

- **MockURLProtocol:** Custom URLProtocol subclass registered in test files for intercepting network requests without real HTTP calls
- **Helper extensions:** XCTestCase extensions for SUT creation, mock response registration, JSON serialization, and response builders

## Step 5: Validation

- [x] Prerequisites satisfied (Swift 6.2.4, XCTest, Story 1.2 with clear ACs)
- [x] Test files created in correct directory structure (Tests/OpenAgentSDKTests/API/)
- [x] Checklist covers all 8 acceptance criteria (AC1-AC8)
- [x] All tests fail before implementation (compile errors due to missing types)
- [x] Temp artifacts stored in `_bmad-output/test-artifacts/`
- [x] No orphaned browser processes (N/A -- backend)
- [x] API key security verified by dedicated tests (AC1/NFR6, AC7/NFR6)

### Risks & Assumptions

- AnthropicClient init signature may differ -- tests assume `init(apiKey:baseURL:urlSession:)` accepting custom URLSession for mocking
- SSE parsing uses URLSession bytes delegate -- MockURLProtocol may not perfectly simulate streaming; real streaming tests may need URLProtocol subclass refinement
- AC8 (dual platform) is primarily validated by `swift build` on both platforms, not just unit tests
- SSEEvent is expected to be `Sendable` for safe concurrency with AsyncThrowingStream
- `[String: Any]` dictionary-based API (no Codable) must be respected in implementation
- Actor isolation requires `await` on all method calls -- tests use async/await correctly

### Next Steps

1. Implement Story 1.2 to make tests pass (TDD green phase)
2. Create `Sources/OpenAgentSDK/API/AnthropicClient.swift` (actor)
3. Create `Sources/OpenAgentSDK/API/APIModels.swift` (request/response helpers)
4. Create `Sources/OpenAgentSDK/API/Streaming.swift` (SSE parser + SSEEvent enum)
5. Run `swift test` to verify all 46 tests pass
6. Refactor if needed (TDD refactor phase)
