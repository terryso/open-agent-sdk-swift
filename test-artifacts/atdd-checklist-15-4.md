---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/15-4-model-switching-example.md'
  - 'Tests/OpenAgentSDKTests/Documentation/ModelSwitchingExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift'
  - 'Examples/LoggerExample/main.swift'
  - 'Package.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
---

# ATDD Checklist - Epic 15, Story 15.4: ModelSwitchingExample

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Compliance (XCTest with static file analysis)
**Detected Stack:** backend (Swift Package, XCTest)

---

## Story Summary

Create a runnable example demonstrating runtime dynamic model switching via `Agent.switchModel()` and per-model cost breakdown via `QueryResult.costBreakdown`.

**As a** developer
**I want** a runnable example demonstrating runtime dynamic model switching
**So that** I can understand how to select the most appropriate model for each task within a single session (FR59)

---

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Directory `Examples/ModelSwitchingExample/` with `main.swift` and executable target in Package.swift; `swift build` succeeds with no errors/warnings.
2. **AC2: Default model query** -- Creates an Agent with default model (e.g., `claude-sonnet-4-6`) and executes a first query using `agent.prompt()`.
3. **AC3: Model switching** -- Calls `agent.switchModel("claude-opus-4-6")` between queries, then executes a second query with the new model.
4. **AC4: Cost breakdown** -- After switching models, displays per-model token counts and costs from `CostBreakdownEntry` entries.
5. **AC5: Error handling for empty model** -- Demonstrates `agent.switchModel("")` in a `try/catch` block catching `SDKError.invalidConfiguration`.
6. **AC6: Package.swift updated** -- Follows the same pattern as existing examples (LoggerExample, SkillsExample).

---

## Test Strategy

### Test Levels

| Level | Use | Count |
|-------|-----|-------|
| Compliance (Static Analysis) | File existence, code structure, API usage verification | 34 |
| **Total** | | **34** |

### Mode Selection

- **Generation Mode:** AI Generation (acceptance criteria are clear, standard example story)
- **Detected Stack:** backend (Swift Package Manager project with XCTest)

### Priority Assignment

| Priority | Tests | Rationale |
|----------|-------|-----------|
| P0 | 22 | Core acceptance criteria: file/package existence, model switching, prompt calls, cost breakdown, error handling |
| P1 | 12 | Code quality: comments, MARK sections, no force unwrap, no real API keys, proper patterns |

---

## Acceptance Criteria Coverage Matrix

### AC1: Example compiles and runs (8 tests)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 1 | `testModelSwitchingExampleDirectoryExists` | P0 | `Examples/ModelSwitchingExample/` directory exists |
| 2 | `testModelSwitchingExampleMainSwiftExists` | P0 | `main.swift` file exists in directory |
| 3 | `testModelSwitchingExampleImportsOpenAgentSDK` | P0 | `import OpenAgentSDK` present |
| 4 | `testModelSwitchingExampleImportsFoundation` | P0 | `import Foundation` present |
| 5 | `testModelSwitchingExampleHasTopLevelDescriptionComment` | P1 | File starts with descriptive comment |
| 6 | `testModelSwitchingExampleHasMultipleInlineComments` | P1 | Multiple educational comments (>5) |
| 7 | `testModelSwitchingExampleHasMarkSections` | P1 | At least 2 MARK: sections |
| 8 | `testModelSwitchingExampleUsesAssertions` | P1 | Uses `assert()` for compliance |

### AC2: Default model query (5 tests)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 9 | `testModelSwitchingExampleCreatesAgentWithDefaultModel` | P0 | Uses `createAgent()` |
| 10 | `testModelSwitchingExampleReferencesClaudeSonnet` | P0 | References `claude-sonnet-4-6` |
| 11 | `testModelSwitchingExampleUsesPromptAPI` | P0 | Uses `agent.prompt()` |
| 12 | `testModelSwitchingExampleExecutesFirstQuery` | P0 | Has `await` and captures result |
| 13 | `testModelSwitchingExampleUsesBypassPermissions` | P0 | Uses `.bypassPermissions` |

### AC3: Model switching (4 tests)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 14 | `testModelSwitchingExampleCallsSwitchModel` | P0 | Calls `switchModel()` |
| 15 | `testModelSwitchingExampleSwitchesToOpus` | P0 | Switches to `claude-opus-4-6` |
| 16 | `testModelSwitchingExampleExecutesSecondQuery` | P0 | At least 2 `.prompt()` calls |
| 17 | `testModelSwitchingExampleVerifiesModelAfterSwitch` | P0 | Inspects `agent.model` |

### AC4: Cost breakdown (4 tests)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 18 | `testModelSwitchingExampleReferencesCostBreakdown` | P0 | References `costBreakdown` |
| 19 | `testModelSwitchingExampleDemonstratesPerModelCostEntries` | P0 | Iterates entries or uses `CostBreakdownEntry` |
| 20 | `testModelSwitchingExampleDisplaysTokenCounts` | P0 | Shows `inputTokens` and `outputTokens` |
| 21 | `testModelSwitchingExampleDisplaysCostUsd` | P0 | Shows `costUsd` or `totalCostUsd` |
| 22 | `testModelSwitchingExamplePrintsUsageInfo` | P1 | Prints usage/token information |

### AC5: Error handling for empty model (4 tests)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 23 | `testModelSwitchingExampleDemonstratesEmptyModelError` | P0 | Calls `switchModel("")` |
| 24 | `testModelSwitchingExampleUsesTryCatch` | P0 | Uses `do { } catch` block |
| 25 | `testModelSwitchingExampleCatchesSDKError` | P0 | Catches `SDKError` |
| 26 | `testModelSwitchingExampleCatchesInvalidConfiguration` | P0 | Catches `.invalidConfiguration` |
| 27 | `testModelSwitchingExampleVerifiesModelUnchangedAfterError` | P0 | `agent.model` referenced >= 2 times |

### AC6: Package.swift updated (3 tests)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 28 | `testPackageSwiftContainsModelSwitchingExampleTarget` | P0 | Target name in Package.swift |
| 29 | `testModelSwitchingExampleTargetDependsOnOpenAgentSDK` | P0 | Dependency on OpenAgentSDK |
| 30 | `testModelSwitchingExampleTargetSpecifiesCorrectPath` | P0 | Path is `Examples/ModelSwitchingExample` |

### Code Quality (4 tests, cross-cutting)

| # | Test Method | Priority | What It Verifies |
|---|-------------|----------|------------------|
| 31 | `testModelSwitchingExampleDoesNotUseForceUnwrap` | P1 | No `try!` |
| 32 | `testModelSwitchingExampleDoesNotExposeRealAPIKeys` | P1 | No real API keys |
| 33 | `testModelSwitchingExampleUsesLoadDotEnvPattern` | P1 | Uses `loadDotEnv()` |
| 34 | `testModelSwitchingExampleUsesGetEnvPattern` | P1 | Uses `getEnv()` |

---

## TDD Green Phase Status

**Current State: GREEN** -- All 34 tests PASS. Implementation complete:
- `Examples/ModelSwitchingExample/main.swift` created
- `Package.swift` updated with `ModelSwitchingExample` executable target
- Build verified: no errors, no warnings

**Test Run Results:**
```
Executed 34 tests, with 0 failures (0 unexpected) in 0.011 seconds
```

---

## Test File

| File | Type | Tests |
|------|------|-------|
| `Tests/OpenAgentSDKTests/Documentation/ModelSwitchingExampleComplianceTests.swift` | Compliance (static analysis) | 34 |

---

## Implementation Guidance

### Feature files to create:

1. **`Examples/ModelSwitchingExample/main.swift`** -- New example file
2. **`Package.swift`** -- Add `.executableTarget(name: "ModelSwitchingExample", dependencies: ["OpenAgentSDK"], path: "Examples/ModelSwitchingExample")`

### Key API surface to demonstrate:

- `Agent.switchModel(_ model: String) throws` -- synchronous model switching
- `Agent.model` -- read-only property for current model
- `agent.prompt(_ text: String) async -> QueryResult` -- blocking prompt API
- `QueryResult.costBreakdown: [CostBreakdownEntry]` -- per-model cost entries
- `CostBreakdownEntry(model:inputTokens:outputTokens:costUsd:)` -- cost entry struct
- `SDKError.invalidConfiguration(String)` -- thrown on empty model name

### Example structure (2 parts):

- **Part 1:** Model Switching and Cost Tracking
  - Create Agent with `claude-sonnet-4-6`
  - Execute simple query, print result + cost breakdown
  - `switchModel("claude-opus-4-6")`, print `agent.model`
  - Execute reasoning query, print result + cost breakdown
  - Compare costs between models

- **Part 2:** Error Handling
  - `try agent.switchModel("")` in do/catch
  - Catch `SDKError.invalidConfiguration`
  - Verify `agent.model` unchanged

---

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Create `Examples/ModelSwitchingExample/main.swift` following the pattern from LoggerExample
2. Update `Package.swift` with the new executable target
3. Run `swift build` to verify compilation
4. Run compliance tests: `swift test --filter ModelSwitchingExampleCompliance`
5. Verify all 34 tests PASS (green phase)
6. Commit passing tests and implementation
