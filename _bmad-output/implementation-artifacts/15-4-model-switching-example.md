# Story 15.4: ModelSwitchingExample

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a runnable example demonstrating runtime dynamic model switching,
so that I can understand how to select the most appropriate model for each task within a single session (FR59).

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/ModelSwitchingExample/` directory with a `main.swift` file and corresponding `ModelSwitchingExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: Default model query** -- Given the example code, when reading the code, it creates an Agent with a default model (e.g., `claude-sonnet-4-6`) and executes a first query using `agent.prompt()`.

3. **AC3: Model switching** -- Given the example code, when reading the code, it calls `agent.switchModel("claude-opus-4-6")` between queries, then executes a second query that uses the new model.

4. **AC4: Cost breakdown** -- Given the model has been switched from sonnet to opus, when the second query completes and the code inspects `result.costBreakdown`, then the example displays per-model token counts and costs from `CostBreakdownEntry` entries.

5. **AC5: Error handling for empty model** -- Given the example code, when reading the code, it demonstrates calling `agent.switchModel("")` inside a `try/catch` block and shows that `SDKError.invalidConfiguration` is thrown.

6. **AC6: Package.swift updated** -- Given the Package.swift file, when adding the `ModelSwitchingExample` executable target, it follows the exact same pattern as existing examples (e.g., `LoggerExample`, `SkillsExample`).

## Tasks / Subtasks

- [x] Task 1: Create example directory and file (AC: #1, #6)
  - [x] Create `Examples/ModelSwitchingExample/main.swift`
  - [x] Add `.executableTarget(name: "ModelSwitchingExample", dependencies: ["OpenAgentSDK"], path: "Examples/ModelSwitchingExample")` to Package.swift

- [x] Task 2: Write Part 1 -- Model Switching Demo (AC: #2, #3, #4)
  - [x] Create Agent with default model (claude-sonnet-4-6)
  - [x] Execute first query via `agent.prompt()` (simple question for fast/cheap model)
  - [x] Print first query result text and token usage
  - [x] Call `agent.switchModel("claude-opus-4-6")` to switch to opus
  - [x] Execute second query via `agent.prompt()` (reasoning-heavy question)
  - [x] Print second query result text and token usage
  - [x] Print `result.costBreakdown` showing per-model entries with inputTokens, outputTokens, costUsd

- [x] Task 3: Write Part 2 -- Error Handling (AC: #5)
  - [x] Demonstrate `try agent.switchModel("")` in a do/catch block
  - [x] Catch `SDKError.invalidConfiguration` and print the error message
  - [x] Verify Agent's current model is unchanged after the failed switch

- [x] Task 4: Verify build (AC: #1)
  - [x] `swift build` compiles with no errors/warnings
  - [x] Manual smoke-test of `swift run ModelSwitchingExample`

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), fourth story
- **Core goal:** Create a runnable example demonstrating runtime model switching (`Agent.switchModel()`) and cost breakdown (`QueryResult.costBreakdown`)
- **Prerequisites:** Epic 13 Story 13.1 (runtime dynamic model switching) is DONE -- `switchModel()` and `CostBreakdownEntry` exist
- **FR coverage:** FR59 (example/illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface (from Epic 13 implementation)

The following public API is already implemented and available for the example:

```swift
// Sources/OpenAgentSDK/Core/Agent.swift
public class Agent {
    /// Current model identifier (read-only externally, mutated by switchModel)
    public private(set) var model: String

    /// Switch to a different LLM model for subsequent queries
    /// - Throws: SDKError.invalidConfiguration if model name is empty/whitespace
    public func switchModel(_ model: String) throws

    /// Blocking prompt API -- returns QueryResult
    public func prompt(_ text: String) async -> QueryResult
}

// Sources/OpenAgentSDK/Types/AgentTypes.swift
public struct QueryResult: Sendable {
    public let text: String
    public let usage: TokenUsage        // total aggregated usage
    public let numTurns: Int
    public let durationMs: Int
    public let messages: [SDKMessage]
    public let status: QueryStatus
    public let totalCostUsd: Double
    public let costBreakdown: [CostBreakdownEntry]  // per-model cost entries
    public let isCancelled: Bool
}

public struct CostBreakdownEntry: Sendable, Equatable {
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let costUsd: Double
}

// Sources/OpenAgentSDK/Types/TokenUsage.swift
public struct TokenUsage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public var totalTokens: Int { get }
}

// Sources/OpenAgentSDK/Types/SDKError.swift (relevant case)
public enum SDKError: Error {
    case invalidConfiguration(String)
}
```

### Example Pattern to Follow

Follow the exact same patterns as existing examples (SkillsExample, SandboxExample, LoggerExample):

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

1. **switchModel() is synchronous** -- It does NOT require `await` or `try` unless validation fails. The method is `throws` (not `async throws`). Use `try` for the call, but no `await`.

2. **costBreakdown is per-query** -- Each `QueryResult` contains its own `costBreakdown` with entries for each model used **during that query**. Since each `prompt()` call is a separate query, the cost breakdown for a single query with one model will have exactly one entry. To show multiple model entries in one breakdown, the model must be switched mid-stream or mid-prompt execution.

3. **Simple two-query approach** -- The simplest demo is:
   - Query 1 with sonnet -> shows single-model cost breakdown
   - `switchModel("claude-opus-4-6")`
   - Query 2 with opus -> shows single-model cost breakdown for opus
   - Compare the two results side by side

4. **Error handling pattern** -- `switchModel("")` throws `SDKError.invalidConfiguration("Model name cannot be empty")`. Catch it with:
   ```swift
   do {
       try agent.switchModel("")
   } catch let error as SDKError {
       if case .invalidConfiguration(let msg) = error {
           print("Caught expected error: \(msg)")
       }
   }
   ```

5. **agent.model is verifiable** -- After `switchModel()`, `agent.model` reflects the new model name. After a failed switch (empty string), `agent.model` should still be the previous model.

6. **Model name format** -- Use the actual model identifiers: `"claude-sonnet-4-6"` and `"claude-opus-4-6"`. These are the default model names in the SDK.

### Example Structure (2 Parts)

```
Part 1: Model Switching and Cost Tracking
  - Create Agent with claude-sonnet-4-6
  - Execute simple query (e.g., "What is 2+3?")
  - Print result.text, usage, and costBreakdown
  - Switch to claude-opus-4-6 via try agent.switchModel()
  - Print agent.model to confirm switch
  - Execute reasoning query (e.g., "Explain the difference between structs and classes in Swift")
  - Print result.text, usage, and costBreakdown
  - Compare costs between models

Part 2: Error Handling
  - Try agent.switchModel("") -- should throw
  - Catch SDKError.invalidConfiguration
  - Verify agent.model unchanged
```

### File Locations

```
Examples/ModelSwitchingExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add ModelSwitchingExample executable target
```

### Package.swift Change

Add after the `LoggerExample` target:

```swift
.executableTarget(
    name: "ModelSwitchingExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/ModelSwitchingExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run ModelSwitchingExample` should output model switching demos
- **No new unit tests needed** -- this is an example, not production code
- The example itself serves as an integration test of the switchModel/costBreakdown API surface
- Note: Running the example requires a valid API key with access to both claude-sonnet-4-6 and claude-opus-4-6

### Previous Story Intelligence (Story 15.3: LoggerExample)

- **Pattern confirmed:** Chinese + English header comment block, MARK sections, `loadDotEnv()`/`getEnv()` for API key, `createAgent` with `permissionMode: .bypassPermissions`
- **File structure:** Single `main.swift` file in `Examples/<Name>/` directory
- **Package.swift pattern:** `.executableTarget(name: "...", dependencies: ["OpenAgentSDK"], path: "Examples/...")`
- **Build verified:** `swift build` compiles with no errors/warnings
- **LogBuffer pattern:** Used `final class LogBuffer: @unchecked Sendable` with NSLock for thread-safe capture in @Sendable closures -- reuse this pattern if needed
- **Design decision from 15-3:** Used `AgentOptions` directly instead of `SDKConfiguration` for agent creation -- simpler and more direct

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.4] -- Full acceptance criteria for ModelSwitchingExample
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 13 Story 13.1] -- Runtime dynamic model switching design
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#switchModel] -- `switchModel(_:)` method implementation
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#prompt] -- `prompt(_:)` blocking API
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#CostBreakdownEntry] -- Per-model cost entry type
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#QueryResult] -- Query result with costBreakdown field
- [Source: Sources/OpenAgentSDK/Types/TokenUsage.swift] -- Token usage tracking
- [Source: Examples/LoggerExample/main.swift] -- Pattern: Chinese+English header, MARK sections, 2-part structure
- [Source: Examples/SkillsExample/main.swift] -- Pattern: agent creation, query stats
- [Source: Package.swift] -- Existing executable target definitions to follow

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- swift build: compiled successfully with no errors/warnings (4.99s)
- swift test: all 2808 tests passed, 0 failures, 4 skipped

### Completion Notes List

- Created ModelSwitchingExample with 2 parts following existing example patterns (LoggerExample, SkillsExample)
- Part 1: Agent creation with default model, first query with sonnet, switchModel to opus, second query, cost breakdown display for both queries, cost comparison
- Part 2: Error handling for switchModel("") with SDKError.invalidConfiguration catch, model unchanged verification
- Used Chinese + English header comment block, MARK sections, loadDotEnv()/getEnv() helpers, createAgent with permissionMode: .bypassPermissions
- Used assert() statements for key validations to support compliance testing
- Added .executableTarget to Package.swift following exact same pattern as LoggerExample
- Build verified: no errors, no warnings
- Full test suite: 2808 tests passing, no regressions

### File List

- Examples/ModelSwitchingExample/main.swift (NEW)
- Package.swift (MODIFIED: added ModelSwitchingExample executable target)

### Review Findings

- [x] [Review][Patch] Stale TDD RED PHASE comment in compliance tests [Tests/OpenAgentSDKTests/Documentation/ModelSwitchingExampleComplianceTests.swift:5] -- FIXED: updated to reflect green phase
- [x] [Review][Patch] Bare top-level `try` on switchModel lacks graceful error context [Examples/ModelSwitchingExample/main.swift:79] -- FIXED: wrapped in do/catch with descriptive error message
