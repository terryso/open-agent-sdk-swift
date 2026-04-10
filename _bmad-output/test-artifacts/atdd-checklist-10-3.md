---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-10'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/10-3-prompt-api-example.md'
  - 'Tests/OpenAgentSDKTests/Documentation/PromptAPIExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/CustomSystemPromptExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/MultiToolExampleComplianceTests.swift'
  - 'Examples/BasicAgent/main.swift'
  - 'Examples/MultiToolExample/main.swift'
  - 'Examples/CustomSystemPromptExample/main.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
---

# ATDD Checklist - Epic 10, Story 10-3: PromptAPIExample

**Date:** 2026-04-10
**Author:** TEA Agent
**Primary Test Level:** Unit (Compliance/Static Analysis)

---

## Story Summary

Create a PromptAPIExample that demonstrates the blocking `agent.prompt()` API with core tools registered. The example uses `getAllBaseTools(tier: .core)` to register 10 core tools, sends a single blocking query, and displays the complete QueryResult fields including response text, status, turns, duration, token usage, and cost.

**As a** Swift developer
**I want** an example showing the blocking prompt API with tool-equipped Agent
**So that** I understand how to get a complete final result from an Agent that may autonomously execute tools in a single call

---

## Acceptance Criteria

1. **AC1:** PromptAPIExample compiles and runs without errors/warnings
2. **AC2:** Uses blocking API (`agent.prompt()`) not streaming
3. **AC3:** Displays all QueryResult fields (text, status, numTurns, usage, durationMs, totalCostUsd)
4. **AC4:** Registers core tools via `getAllBaseTools(tier: .core)` and shows Agent tool execution results
5. **AC5:** Package.swift executableTarget configured correctly
6. **AC6:** Uses actual public API signatures (no hypothetical or outdated APIs)
7. **AC7:** Clear comments, no exposed API keys, no force unwraps

---

## Failing Tests Created (RED Phase)

### Compliance Tests (29 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/PromptAPIExampleComplianceTests.swift` (440 lines)

#### AC5: Package.swift Configuration (3 tests)

- **Test:** `testPackageSwiftContainsPromptAPIExampleTarget`
  - **Status:** RED - Package.swift does not yet contain PromptAPIExample
  - **Verifies:** AC5 - executableTarget name exists in Package.swift

- **Test:** `testPromptAPIExampleTargetDependsOnOpenAgentSDK`
  - **Status:** RED - Target not found in Package.swift
  - **Verifies:** AC5 - target has OpenAgentSDK dependency

- **Test:** `testPromptAPIExampleTargetSpecifiesCorrectPath`
  - **Status:** RED - Target not found in Package.swift
  - **Verifies:** AC5 - target specifies path "Examples/PromptAPIExample"

#### AC1: File Existence and Imports (6 tests)

- **Test:** `testPromptAPIExampleDirectoryExists`
  - **Status:** RED - Directory does not exist
  - **Verifies:** AC1 - Examples/PromptAPIExample/ exists

- **Test:** `testPromptAPIExampleMainSwiftExists`
  - **Status:** RED - File does not exist
  - **Verifies:** AC1 - main.swift file exists

- **Test:** `testPromptAPIExampleImportsOpenAgentSDK`
  - **Status:** RED - File not readable (does not exist)
  - **Verifies:** AC1, AC6 - imports OpenAgentSDK

- **Test:** `testPromptAPIExampleImportsFoundation`
  - **Status:** RED - File not readable
  - **Verifies:** AC1, AC6 - imports Foundation for ProcessInfo

- **Test:** `testPromptAPIExampleUsesCreateAgent`
  - **Status:** RED - File not readable
  - **Verifies:** AC1, AC6 - uses createAgent() factory function

- **Test:** `testPromptAPIExampleUsesBypassPermissions`
  - **Status:** RED - File not readable
  - **Verifies:** AC1 - sets .bypassPermissions permissionMode

#### AC2: Blocking API (2 tests)

- **Test:** `testPromptAPIExampleUsesBlockingPromptAPI`
  - **Status:** RED - File not readable
  - **Verifies:** AC2 - uses agent.prompt() not agent.stream()

- **Test:** `testPromptAPIExampleDoesNotUseStreamingAPI`
  - **Status:** RED - File not readable
  - **Verifies:** AC2 - does NOT use agent.stream()

#### AC3: Complete QueryResult Fields (6 tests)

- **Test:** `testPromptAPIExampleDisplaysResponseText`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - displays result.text

- **Test:** `testPromptAPIExampleDisplaysStatus`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - displays result.status

- **Test:** `testPromptAPIExampleDisplaysNumTurns`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - displays result.numTurns

- **Test:** `testPromptAPIExampleDisplaysDurationMs`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - displays result.durationMs

- **Test:** `testPromptAPIExampleDisplaysTokenUsage`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - displays result.usage.inputTokens and outputTokens

- **Test:** `testPromptAPIExampleDisplaysCost`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - displays result.totalCostUsd

#### AC4: Core Tools Registration (3 tests)

- **Test:** `testPromptAPIExampleRegistersCoreTools`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - uses getAllBaseTools(tier: .core) to register 10 core tools

- **Test:** `testPromptAPIExamplePassesToolsToAgentOptions`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - passes tools: parameter in AgentOptions (not defaulting to nil)

- **Test:** `testPromptAPIExampleDefinesSystemPrompt`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - defines a systemPrompt in AgentOptions to guide tool usage

#### AC6: Actual Public API (4 tests)

- **Test:** `testPromptAPIExampleAgentOptionsUsesRealParameterNames`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - AgentOptions uses at least 4 real parameter names

- **Test:** `testPromptAPIExampleQueryResultMatchesSourceType`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - QueryResult property access matches source type

- **Test:** `testPromptAPIExampleUsesAwaitForPrompt`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - uses `await agent.prompt()` (correct async API)

- **Test:** `testPromptAPIExampleUsesCreateAgentWithOptions`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - uses createAgent(options: AgentOptions(...))

#### AC7: Comments and Security (5 tests)

- **Test:** `testPromptAPIExampleHasTopLevelDescriptionComment`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - file starts with descriptive comment block

- **Test:** `testPromptAPIExampleHasMultipleInlineComments`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - has more than 3 inline comments

- **Test:** `testPromptAPIExampleDoesNotExposeRealAPIKeys`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - no real API keys exposed

- **Test:** `testPromptAPIExampleUsesPlaceholderOrEnvVarForAPIKey`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - uses sk-... placeholder or ProcessInfo env var

- **Test:** `testPromptAPIExampleDoesNotUseForceUnwrap`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - no try! force-try

---

## Implementation Checklist

### Test: Package.swift Target (3 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/PromptAPIExampleComplianceTests.swift`

**Tasks to make these tests pass:**

- [ ] Add `.executableTarget(name: "PromptAPIExample", dependencies: ["OpenAgentSDK"], path: "Examples/PromptAPIExample")` to Package.swift targets array
- [ ] Verify target depends on OpenAgentSDK
- [ ] Verify path is "Examples/PromptAPIExample"
- [ ] Run: `swift build` to confirm compilation

**Estimated Effort:** 0.25 hours

---

### Test: Example File Creation (26 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/PromptAPIExampleComplianceTests.swift`

**Tasks to make these tests pass:**

- [ ] Create directory `Examples/PromptAPIExample/`
- [ ] Create `Examples/PromptAPIExample/main.swift`
- [ ] Add file-level comment block describing purpose (blocking prompt API with core tools)
- [ ] Import Foundation and OpenAgentSDK
- [ ] Read API key from environment variable or use "sk-..." placeholder
- [ ] Create Agent with `createAgent(options:)` using `AgentOptions`:
  - apiKey (from env var or placeholder)
  - model: "claude-sonnet-4-6"
  - systemPrompt: concise system prompt guiding tool usage
  - maxTurns: 10
  - permissionMode: .bypassPermissions
  - tools: `getAllBaseTools(tier: .core)` -- register 10 core tools
- [ ] Use `await agent.prompt()` for blocking query (NOT `agent.stream()`)
- [ ] Output all QueryResult fields:
  - `result.text` -- complete response text
  - `result.status` -- QueryStatus enum value
  - `result.numTurns` -- number of turns
  - `result.durationMs` -- duration in milliseconds (and optionally in seconds)
  - `result.usage.inputTokens` / `result.usage.outputTokens` -- token usage
  - `result.totalCostUsd` -- estimated cost
- [ ] Add inline comments for key steps (more than 3)
- [ ] Do NOT use `try!` force-try
- [ ] Do NOT use real API keys
- [ ] Run: `swift build` to confirm compilation
- [ ] Run: `swift test --filter PromptAPIExampleComplianceTests`

**Estimated Effort:** 1 hour

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter PromptAPIExampleComplianceTests

# Run full test suite (verify no regressions)
swift test

# Build only (verify compilation)
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All 29 tests written and failing
- Failure reason: Examples/PromptAPIExample/main.swift does not exist and Package.swift lacks the target
- Implementation checklist created
- No test quality issues (follows established pattern from MultiToolExample and CustomSystemPromptExample compliance tests)

**Verification:**

```
Executed 29 tests, with 32 failures (0 unexpected) in 0.621 seconds
```

All tests fail due to missing implementation, not test bugs.

---

### GREEN Phase (DEV Team - Next Steps)

1. Add executableTarget to Package.swift
2. Create Examples/PromptAPIExample/main.swift
3. Run `swift build` to verify compilation
4. Run `swift test --filter PromptAPIExampleComplianceTests` to verify all 29 pass
5. Run full suite to verify no regressions

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter PromptAPIExampleComplianceTests`

**Results:**

```
Executed 29 tests, with 32 failures (0 unexpected) in 0.621 (0.624) seconds
```

**Summary:**

- Total tests: 29
- Passing: 0 (expected)
- Failing: 29 (32 failure assertions) (expected)
- Status: RED phase verified

### Full Suite Regression Check

**Command:** `swift test`

**Results:**

```
Executed 1912 tests, with 4 tests skipped and 32 failures (0 unexpected) in 20.213 seconds
```

- The 32 failures are all from PromptAPIExampleComplianceTests (RED phase, expected)
- Zero unexpected failures -- no regressions introduced
- 4 skipped tests are pre-existing

---

## Notes

- This is a Swift backend project; ATDD tests are compliance/static-analysis tests (XCTest) that verify file existence, content patterns, and API signature correctness
- Tests follow the exact pattern established in MultiToolExampleComplianceTests.swift (Story 10-1) and CustomSystemPromptExampleComplianceTests.swift (Story 10-2)
- Story explicitly states no unit tests needed; these compliance tests serve as compilation/API-correctness gate
- Key difference from Story 10-2 (CustomSystemPromptExample): this example registers core tools via `getAllBaseTools(tier: .core)` and demonstrates Agent tool execution results, while still using the blocking `agent.prompt()` API
- Key difference from BasicAgent (Epic 9): BasicAgent is a simple blocking call with no tools; PromptAPIExample adds core tool registration to show how Agent autonomously executes tools and returns the final result
- Key difference from MultiToolExample (Story 10-1): MultiToolExample uses streaming API (`agent.stream()`); PromptAPIExample uses blocking API (`agent.prompt()`) for simpler "one-call complete result" pattern

---

**Generated by BMad TEA Agent** - 2026-04-10
