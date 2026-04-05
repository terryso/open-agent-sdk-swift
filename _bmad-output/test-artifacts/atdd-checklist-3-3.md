---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-05'
inputDocuments:
  - _bmad-output/implementation-artifacts/3-3-tool-executor-concurrent-serial.md
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/SDKMessage.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Tools/ToolRegistry.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift
  - Tests/OpenAgentSDKTests/Tools/ToolBuilderTests.swift
---

# ATDD Checklist: Story 3.3 -- Tool Executor with Concurrent/Serial Dispatch

## TDD Red Phase (Current)

**Status:** RED -- All tests will FAIL until `ToolExecutor.swift` is implemented and `Agent.swift` is modified.

## Stack Detection

- **Detected Stack:** Backend (Swift Package Manager, no frontend dependencies)
- **Test Framework:** XCTest (Swift native)
- **Test Levels:** Unit + Integration

## Generation Mode

- **Mode:** AI Generation (backend project, no browser recording needed)

---

## Acceptance Criteria Coverage

### AC1: Read-only tools execute concurrently

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testReadOnlyToolsExecuteConcurrently` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testReadOnlyToolsReturnNonErrorResults` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testMaxConcurrencyCappedAt10` | ToolExecutorTests.swift | P1 | Unit | RED |

**Coverage:** Full -- verifies TaskGroup concurrency, result collection, and 10-tool cap.

### AC2: Mutation tools execute serially

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testMutationToolsExecuteSerially` | ToolExecutorTests.swift | P0 | Unit | RED |

**Coverage:** Full -- verifies strict sequential ordering via execution log.

### AC3: Tool execution errors don't crash

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testToolErrorCapturedAsToolResult` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testMixedSuccessAndErrorTools` | ToolExecutorTests.swift | P1 | Unit | RED |

**Coverage:** Full -- verifies isError=true capture and continuation.

### AC4: tool_use block parsing

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testExtractToolUseBlocksFromContent` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testExtractToolUseBlocksNoToolUseReturnsEmpty` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testExtractToolUseBlocksMultipleBlocks` | ToolExecutorTests.swift | P1 | Unit | RED |
| `testExtractToolUseBlocksEmptyContent` | ToolExecutorTests.swift | P1 | Unit | RED |

**Coverage:** Full -- verifies extraction from API response content blocks.

### AC5: tool_result message feedback

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testBuildToolResultMessageCorrectFormat` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testBuildToolResultMessageIncludesIsError` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testBuildToolResultMessageSuccessNoIsError` | ToolExecutorTests.swift | P1 | Unit | RED |
| `testPrompt_ToolResultMessageSentAsUserMessage` | ToolExecutorIntegrationTests.swift | P0 | Integration | RED |

**Coverage:** Full -- verifies message format, is_error field, and integration with agent loop.

### AC6: Unknown tool error handling

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testUnknownToolReturnsError` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testEmptyToolsReturnsUnknownToolError` | ToolExecutorTests.swift | P1 | Unit | RED |
| `testPrompt_UnknownTool_ReturnsErrorButContinues` | ToolExecutorIntegrationTests.swift | P0 | Integration | RED |

**Coverage:** Full -- verifies unknown tool returns error and agent loop continues.

### AC7: Smart loop tool_use round integration

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testPrompt_ToolUseExecuted_ResultsFedBack` | ToolExecutorIntegrationTests.swift | P0 | Integration | RED |
| `testPrompt_ToolUseDoesNotIncrementMaxTokensRecovery` | ToolExecutorIntegrationTests.swift | P0 | Integration | RED |
| `testStream_ToolUse_EventsYielded` | ToolExecutorIntegrationTests.swift | P1 | Integration | RED |

**Coverage:** Full -- verifies loop continuation, maxTokensRecovery reset, and stream events.

### AC8: Micro-compaction integration

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testPrompt_LargeToolResultTriggersMicroCompaction` | ToolExecutorIntegrationTests.swift | P1 | Integration | RED |

**Coverage:** Partial -- verifies large results don't crash; full micro-compaction verification requires LLM mock for compact call (addressed during green phase).

---

## Test Partition Coverage

### Partition Logic (supporting AC1+AC2)

| Test | File | Priority | Level | Status |
|------|------|----------|-------|--------|
| `testPartitionToolsReadOnlyAndMutations` | ToolExecutorTests.swift | P0 | Unit | RED |
| `testPartitionToolsAllReadOnly` | ToolExecutorTests.swift | P1 | Unit | RED |
| `testPartitionToolsAllMutations` | ToolExecutorTests.swift | P1 | Unit | RED |
| `testMixedConcurrentAndSerialExecution` | ToolExecutorTests.swift | P0 | Unit | RED |

---

## Test Priority Summary

| Priority | Count | Tests |
|----------|-------|-------|
| P0 | 15 | Critical path: concurrent execution, serial ordering, error capture, parsing, message format, unknown tool, loop integration |
| P1 | 8 | Edge cases: max concurrency cap, mixed errors, empty content, micro-compaction, stream events |
| P2 | 0 | (none needed for this story) |
| P3 | 0 | (none needed for this story) |
| **Total** | **23** | |

---

## Generated Files

### Test Files

1. `Tests/OpenAgentSDKTests/Core/ToolExecutorTests.swift` -- Unit tests (19 tests)
   - ToolExecutorConcurrentTests (AC1)
   - ToolExecutorSerialTests (AC2)
   - ToolExecutorErrorHandlingTests (AC3)
   - ToolExecutorParsingTests (AC4)
   - ToolExecutorResultMessageTests (AC5)
   - ToolExecutorUnknownToolTests (AC6)
   - ToolExecutorPartitionTests (partition logic)
   - ToolExecutorConcurrencyCapTests (AC1 extended)
   - ToolExecutorMixedScenarioTests (mixed scenario)

2. `Tests/OpenAgentSDKTests/Core/ToolExecutorIntegrationTests.swift` -- Integration tests (6 tests)
   - ToolExecutorIntegrationTests (AC4+5+6+7+8)

### Mock Tools (defined in test files)

- `MockReadOnlyTool` -- Configurable delay, result, completion order tracking
- `MockMutationTool` -- Configurable delay, result, execution log tracking
- `MockThrowingTool` -- Always returns isError=true
- `MockIntegrationReadOnlyTool` -- Simple read-only tool for integration tests

---

## Types Expected from Implementation

The tests reference the following types that `ToolExecutor.swift` must provide:

```swift
/// Internal type representing a tool_use block from the LLM response.
struct ToolUseBlock {
    let id: String       // tool_use_id from LLM
    let name: String     // tool name
    let input: Any       // raw JSON input
}

/// Stateless tool executor namespace.
enum ToolExecutor {
    static func extractToolUseBlocks(from content: [[String: Any]]) -> [ToolUseBlock]
    static func partitionTools(blocks: [ToolUseBlock], tools: [ToolProtocol]) -> (readOnly: [(block: ToolUseBlock, tool: ToolProtocol)], mutations: [(block: ToolUseBlock, tool: ToolProtocol)])
    static func executeTools(toolUseBlocks: [ToolUseBlock], tools: [ToolProtocol], context: ToolContext) async -> [ToolResult]
    static func buildToolResultMessage(from results: [ToolResult]) -> [String: Any]
}
```

---

## Next Steps (TDD Green Phase)

After implementing `ToolExecutor.swift`:

1. Create `Sources/OpenAgentSDK/Core/ToolExecutor.swift`
   - Implement `ToolUseBlock` struct
   - Implement `ToolExecutor.extractToolUseBlocks(from:)`
   - Implement `ToolExecutor.partitionTools(blocks:tools:)`
   - Implement `ToolExecutor.executeTools(toolUseBlocks:tools:context:)`
   - Implement `ToolExecutor.buildToolResultMessage(from:)`

2. Modify `Sources/OpenAgentSDK/Core/Agent.swift`
   - Add tool_use detection in `prompt()` loop (between content extraction and stop_reason check)
   - Add tool_use detection in `stream()` loop (after messageStop)
   - Call `ToolExecutor.executeTools()` when tool_use blocks detected
   - Append assistant message with tool_use content
   - Append tool_result user message
   - Reset `maxTokensRecoveryAttempts` on tool_use
   - Call `processToolResult()` on each result before appending

3. Run tests: `swift test --filter ToolExecutor`
4. Verify all tests PASS (green phase)
5. Commit passing tests

---

## Risks and Assumptions

1. **XCTest not available in current environment** -- Tests cannot be executed locally without Xcode installed (requires full Xcode, not just Command Line Tools). CI should handle test execution.
2. **TaskGroup max concurrency** -- Swift's TaskGroup doesn't natively support `maxConcurrency` parameter. Implementation must manually batch tasks if strict 10-cap is needed.
3. **Stream tool_use handling** -- Stream path integration test is simplified; full SSE tool_use parsing may require additional green-phase refinement.
4. **Micro-compaction mock** -- AC8 test verifies non-crash on large results but cannot fully verify compression without mocking the LLM compact call.
5. **ToolUseBlock type** -- Defined in tests as expected interface; implementation may use internal typealias or nested type.
