# Story 15.5: QueryAbortExample

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a runnable example demonstrating how to interrupt a running Agent query,
so that I can understand how to implement user cancellation for long-running tasks (FR60).

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/QueryAbortExample/` directory with a `main.swift` file and corresponding `QueryAbortExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: Task.cancel() cancellation** -- Given the example code, when reading the code, it launches an Agent query inside a Swift `Task { }`, calls `task.cancel()` after a short delay, and demonstrates that the returned `QueryResult.isCancelled == true`.

3. **AC3: Agent.interrupt() cancellation** -- Given the example code, when reading the code, it launches an Agent query inside a `Task { }`, calls `agent.interrupt()` after a short delay, and demonstrates that the returned `QueryResult.isCancelled == true`.

4. **AC4: Partial results handling** -- Given the example code, when reading the code, it demonstrates inspecting the partial `QueryResult` after cancellation -- specifically `result.text` (partial text), `result.numTurns` (completed turns), and `result.usage` (tokens used so far).

5. **AC5: Stream cancellation** -- Given the example code, when reading the code, it demonstrates using `agent.stream()` with cancellation, showing how the `AsyncStream<SDKMessage>` yields a `.result` event with `subtype: .cancelled` and then finishes normally (no error thrown to consumer).

6. **AC6: Package.swift updated** -- Given the Package.swift file, when adding the `QueryAbortExample` executable target, it follows the exact same pattern as existing examples (e.g., `ModelSwitchingExample`, `LoggerExample`).

## Tasks / Subtasks

- [x] Task 1: Create example directory and file (AC: #1, #6)
  - [x] Create `Examples/QueryAbortExample/main.swift`
  - [x] Add `.executableTarget(name: "QueryAbortExample", dependencies: ["OpenAgentSDK"], path: "Examples/QueryAbortExample")` to Package.swift

- [x] Task 2: Write Part 1 -- Task.cancel() Cancellation Demo (AC: #2, #4)
  - [x] Create Agent with `loadDotEnv()`/`getEnv()` pattern and `permissionMode: .bypassPermissions`
  - [x] Launch a query inside `Task { agent.prompt("some long prompt...") }`
  - [x] Use `Task.sleep(for:)` then call `task.cancel()`
  - [x] Await the result and inspect `result.isCancelled == true`
  - [x] Print partial result details: `result.text`, `result.numTurns`, `result.usage`
  - [x] Use `assert()` for key validations

- [x] Task 3: Write Part 2 -- Agent.interrupt() Cancellation Demo (AC: #3, #4)
  - [x] Create a second Agent instance
  - [x] Launch a query inside `Task { agent.prompt(...) }`
  - [x] Use `Task.sleep(for:)` then call `agent.interrupt()`
  - [x] Await the result and verify `result.isCancelled == true`
  - [x] Print partial result details
  - [x] Use `assert()` for key validations

- [x] Task 4: Write Part 3 -- Stream Cancellation Demo (AC: #5)
  - [x] Create a third Agent instance
  - [x] Launch `agent.stream(...)` inside a Task
  - [x] Iterate over `AsyncStream<SDKMessage>` events
  - [x] After receiving a few events, call `task.cancel()`
  - [x] Show that stream yields `.result` event with `subtype == .cancelled`
  - [x] Show stream finishes normally (no error)

- [x] Task 5: Verify build (AC: #1)
  - [x] `swift build` compiles with no errors/warnings
  - [x] Manual smoke-test of `swift run QueryAbortExample`

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), fifth story
- **Core goal:** Create a runnable example demonstrating query-level interruption via `Task.cancel()` and `Agent.interrupt()`, plus stream cancellation observation
- **Prerequisites:** Epic 13 Story 13.2 (query-level abort) is DONE -- `Agent.interrupt()`, `QueryResult.isCancelled`, and `SDKMessage.ResultData.Subtype.cancelled` all exist
- **FR coverage:** FR60 (example/illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface (from Epic 13 Story 13.2 implementation)

The following public API is already implemented and available for the example:

```swift
// Sources/OpenAgentSDK/Core/Agent.swift

/// Interrupts the currently executing query.
/// Sets an internal flag and cancels the internal Task reference.
/// Equivalent to calling Task.cancel() on the wrapping task.
/// If no query is currently running, this method does nothing.
public func interrupt()
```

```swift
// Sources/OpenAgentSDK/Types/AgentTypes.swift

public struct QueryResult: Sendable {
    public let text: String
    public let usage: TokenUsage
    public let numTurns: Int
    public let durationMs: Int
    public let messages: [SDKMessage]
    public let status: QueryStatus
    public let totalCostUsd: Double
    public let costBreakdown: [CostBreakdownEntry]
    public let isCancelled: Bool  // true if query was cancelled
}

public enum QueryStatus: String, Sendable, Equatable {
    case success
    case errorMaxTurns
    case errorDuringExecution
    case errorMaxBudgetUsd
    case cancelled  // query was cancelled by user
}
```

```swift
// Sources/OpenAgentSDK/Types/SDKMessage.swift

public enum SDKMessage: Sendable, Equatable {
    case result(ResultData)
    // ...
}

extension SDKMessage {
    public struct ResultData: Sendable, Equatable {
        public enum Subtype: String, Sendable, Equatable {
            case success
            case errorMaxTurns
            case errorDuringExecution
            case errorMaxBudgetUsd
            case cancelled  // query was cancelled
        }
        public let subtype: Subtype
        public let text: String
        public let usage: TokenUsage?
        public let numTurns: Int
        public let durationMs: Int
        public let totalCostUsd: Double
        public let costBreakdown: [CostBreakdownEntry]
    }
}
```

### Example Pattern to Follow

Follow the exact same patterns as existing examples (SkillsExample, SandboxExample, LoggerExample, ModelSwitchingExample):

1. **Header comment** -- Chinese + English header block listing what the example demonstrates
2. **API key loading** -- Use `loadDotEnv()` and `getEnv()` helper pattern:
   ```swift
   let dotEnv = loadDotEnv()
   let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
       ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
       ?? "sk-..."
   let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
   ```
3. **MARK sections** -- Use `// MARK: - Part N: Title` for each section
4. **Agent creation** -- Use `createAgent(options:)` with `permissionMode: .bypassPermissions`
5. **Output formatting** -- Print sections with clear headers, show pass/fail results
6. **Assertions** -- Use `assert()` for key validations so compliance tests can verify

### Important Implementation Details

1. **Two cancellation mechanisms are equivalent** -- `Task.cancel()` and `Agent.interrupt()` both set the cooperative cancellation flag. `interrupt()` additionally sets an internal `_interrupted` flag. Both result in `QueryResult.isCancelled == true`. The example should demonstrate both approaches.

2. **Cancellation is cooperative** -- Swift uses cooperative cancellation, meaning the cancel signal is checked at yield points in the agent loop (top of while loop, during SSE event processing, after tool execution). The cancellation may not be instant.

3. **Use Task.sleep for timing** -- To demonstrate cancellation during a running query, wrap the prompt in a `Task { }`, use `Task.sleep(for: .milliseconds(500))` (or similar short delay), then call `task.cancel()` or `agent.interrupt()`. The delay must be long enough for the query to start but short enough for it to still be running.

4. **prompt() returns QueryResult even when cancelled** -- The `prompt()` method catches `CancellationError` internally and returns a `QueryResult` with `isCancelled: true`. It does NOT throw on cancellation. So the pattern is:
   ```swift
   let task = Task {
       await agent.prompt("complex analysis...")
   }
   Task.sleep(for: .milliseconds(500))
   task.cancel()
   let result = await task.value  // returns normally with isCancelled: true
   ```

5. **Stream yields .result(subtype: .cancelled)** -- When stream is cancelled, it yields a final `.result(ResultData(subtype: .cancelled, ...))` event and then the `AsyncStream` finishes normally (the `for await` loop exits). No error is thrown.

6. **Partial results** -- After cancellation, `result.text` contains whatever text was generated so far, `result.numTurns` shows how many turns completed, and `result.usage` shows tokens used.

### Example Structure (3 Parts)

```
Part 1: Task.cancel() Cancellation
  - Create Agent
  - Launch a query with a complex prompt inside Task { }
  - Sleep briefly, then call task.cancel()
  - Await result, check result.isCancelled
  - Print partial text, numTurns, usage
  - assert(result.isCancelled)

Part 2: Agent.interrupt() Cancellation
  - Create a new Agent
  - Launch a query inside Task { }
  - Sleep briefly, then call agent.interrupt()
  - Await result, check result.isCancelled
  - Print partial text, numTurns, usage
  - assert(result.isCancelled)

Part 3: Stream Cancellation
  - Create a new Agent
  - Launch agent.stream() inside Task { }
  - Iterate over AsyncStream<SDKMessage>
  - After a few events, call task.cancel()
  - Show .result event with subtype == .cancelled
  - Show stream finishes normally
```

### File Locations

```
Examples/QueryAbortExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add QueryAbortExample executable target
```

### Package.swift Change

Add after the `ModelSwitchingExample` target:

```swift
.executableTarget(
    name: "QueryAbortExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/QueryAbortExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run QueryAbortExample` should output cancellation demos (note: requires API key)
- **No new unit tests needed** -- this is an example, not production code
- **Compliance tests** will be auto-generated to verify acceptance criteria via code pattern checks (file existence, import, API usage patterns, assert statements)

### Previous Story Intelligence (Story 15.4: ModelSwitchingExample)

- **Pattern confirmed:** Chinese + English header comment block, MARK sections, `loadDotEnv()`/`getEnv()` for API key, `createAgent` with `permissionMode: .bypassPermissions`
- **File structure:** Single `main.swift` file in `Examples/<Name>/` directory
- **Package.swift pattern:** `.executableTarget(name: "...", dependencies: ["OpenAgentSDK"], path: "Examples/...")`
- **Build verified:** `swift build` compiles with no errors/warnings
- **LogBuffer pattern (from 15-3):** Used `final class LogBuffer: @unchecked Sendable` with NSLock for thread-safe capture in @Sendable closures -- reuse this pattern for stream event capture
- **Design decision from 15-3:** Used `AgentOptions` directly instead of `SDKConfiguration` for agent creation -- simpler and more direct
- **assert() usage:** Use assert() for key validations to support compliance test verification

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.5] -- Full acceptance criteria for QueryAbortExample
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 13 Story 13.2] -- Query-level abort design
- [Source: _bmad-output/implementation-artifacts/13-2-query-level-abort.md] -- Previous story with detailed implementation notes
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#interrupt] -- `interrupt()` method implementation
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#prompt] -- `prompt()` blocking API with cancellation handling
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#stream] -- `stream()` API with cancellation and yieldStreamCancelled
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#QueryResult] -- QueryResult with isCancelled field
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#QueryStatus] -- QueryStatus.cancelled case
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift#ResultData.Subtype] -- Subtype.cancelled case
- [Source: Examples/ModelSwitchingExample/main.swift] -- Pattern: Chinese+English header, MARK sections, 2-part structure
- [Source: Examples/LoggerExample/main.swift] -- Pattern: LogBuffer for stream capture
- [Source: Package.swift] -- Existing executable target definitions to follow

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (via BMAD dev-story workflow)

### Debug Log References

- Initial build failed with Swift 6 strict concurrency errors: `sending 'agent1' risks causing data races` when passing non-Sendable `Agent` instance to `_Concurrency.Task { }` closure
- Fixed by using `nonisolated(unsafe)` let bindings to capture agent references before passing to Task closures, consistent with Swift 6 patterns for example code

### Completion Notes List

- Implemented QueryAbortExample with 3 parts: Task.cancel(), Agent.interrupt(), and stream cancellation
- Directory and Package.swift target already existed; main.swift had implementation with Swift 6 concurrency errors
- Fixed concurrency errors by adding `nonisolated(unsafe)` let bindings for agent references passed to Task closures
- Build compiles with zero errors and zero warnings
- Full test suite passes: 2841 tests, 0 failures, 4 skipped
- Follows exact same patterns as ModelSwitchingExample and LoggerExample (Chinese+English header, MARK sections, loadDotEnv/getEnv, createAgent with bypassPermissions, assert() validations)

### File List

- `Examples/QueryAbortExample/main.swift` -- Modified: Fixed Swift 6 concurrency errors by adding nonisolated(unsafe) bindings for agent references in Task closures
- `Package.swift` -- Already contained the QueryAbortExample executable target (no modification needed)

## Change Log

- 2026-04-13: Story 15-5 implementation complete -- fixed Swift 6 strict concurrency compilation errors in QueryAbortExample, verified build and all 2841 tests pass
