---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-10'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/10-2-custom-system-prompt-example.md'
  - 'Tests/OpenAgentSDKTests/Documentation/CustomSystemPromptExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/MultiToolExampleComplianceTests.swift'
  - 'Examples/BasicAgent/main.swift'
  - 'Examples/MultiToolExample/main.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
---

# ATDD Checklist - Epic 10, Story 10-2: CustomSystemPromptExample

**Date:** 2026-04-10
**Author:** TEA Agent
**Primary Test Level:** Unit (Compliance/Static Analysis)

---

## Story Summary

Create a CustomSystemPromptExample that demonstrates how to create a specialized Agent using a custom `systemPrompt`. The example uses the blocking `agent.prompt()` API and displays the complete QueryResult fields, showcasing pure conversational AI with no tool registration.

**As a** Swift developer
**I want** an example showing custom system prompt Agent creation
**So that** I understand how to specialize Agent behavior for specific roles

---

## Acceptance Criteria

1. **AC1:** CustomSystemPromptExample compiles and runs without errors/warnings
2. **AC2:** Uses blocking API (`agent.prompt()`) not streaming
3. **AC3:** Agent reply style matches the specialized system prompt role
4. **AC4:** Displays all QueryResult fields (text, numTurns, usage, durationMs, totalCostUsd, status)
5. **AC5:** Package.swift executableTarget configured correctly
6. **AC6:** Uses actual public API signatures (no hypothetical or outdated APIs)
7. **AC7:** Clear comments, no exposed API keys, no force unwraps

---

## Failing Tests Created (RED Phase)

### Compliance Tests (28 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/CustomSystemPromptExampleComplianceTests.swift` (447 lines)

#### AC5: Package.swift Configuration (3 tests)

- **Test:** `testPackageSwiftContainsCustomSystemPromptExampleTarget`
  - **Status:** RED - Package.swift does not yet contain CustomSystemPromptExample
  - **Verifies:** AC5 - executableTarget name exists in Package.swift

- **Test:** `testCustomSystemPromptExampleTargetDependsOnOpenAgentSDK`
  - **Status:** RED - Target not found in Package.swift
  - **Verifies:** AC5 - target has OpenAgentSDK dependency

- **Test:** `testCustomSystemPromptExampleTargetSpecifiesCorrectPath`
  - **Status:** RED - Target not found in Package.swift
  - **Verifies:** AC5 - target specifies path "Examples/CustomSystemPromptExample"

#### AC1: File Existence and Imports (6 tests)

- **Test:** `testCustomSystemPromptExampleDirectoryExists`
  - **Status:** RED - Directory does not exist
  - **Verifies:** AC1 - Examples/CustomSystemPromptExample/ exists

- **Test:** `testCustomSystemPromptExampleMainSwiftExists`
  - **Status:** RED - File does not exist
  - **Verifies:** AC1 - main.swift file exists

- **Test:** `testCustomSystemPromptExampleImportsOpenAgentSDK`
  - **Status:** RED - File not readable (does not exist)
  - **Verifies:** AC1, AC6 - imports OpenAgentSDK

- **Test:** `testCustomSystemPromptExampleImportsFoundation`
  - **Status:** RED - File not readable
  - **Verifies:** AC1, AC6 - imports Foundation for ProcessInfo

- **Test:** `testCustomSystemPromptExampleUsesCreateAgent`
  - **Status:** RED - File not readable
  - **Verifies:** AC1, AC6 - uses createAgent() factory function

- **Test:** `testCustomSystemPromptExampleUsesBypassPermissions`
  - **Status:** RED - File not readable
  - **Verifies:** AC1 - sets .bypassPermissions permissionMode

#### AC2: Blocking API (2 tests)

- **Test:** `testCustomSystemPromptExampleUsesBlockingPromptAPI`
  - **Status:** RED - File not readable
  - **Verifies:** AC2 - uses agent.prompt() not agent.stream()

- **Test:** `testCustomSystemPromptExampleDoesNotUseStreamingAPI`
  - **Status:** RED - File not readable
  - **Verifies:** AC2 - does NOT use agent.stream()

#### AC3: Specialized System Prompt (3 tests)

- **Test:** `testCustomSystemPromptExampleDefinesSpecializedSystemPrompt`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - defines a systemPrompt with a specialized role

- **Test:** `testCustomSystemPromptExampleSystemPromptGuidesFormat`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - system prompt guides response format/structure

- **Test:** `testCustomSystemPromptExampleDoesNotRegisterTools`
  - **Status:** RED - File not readable
  - **Verifies:** AC3 - no tools registered (pure conversation example)

#### AC4: Complete QueryResult Fields (6 tests)

- **Test:** `testCustomSystemPromptExampleDisplaysResponseText`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - displays result.text

- **Test:** `testCustomSystemPromptExampleDisplaysStatus`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - displays result.status

- **Test:** `testCustomSystemPromptExampleDisplaysNumTurns`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - displays result.numTurns

- **Test:** `testCustomSystemPromptExampleDisplaysDurationMs`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - displays result.durationMs

- **Test:** `testCustomSystemPromptExampleDisplaysTokenUsage`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - displays result.usage.inputTokens and outputTokens

- **Test:** `testCustomSystemPromptExampleDisplaysCost`
  - **Status:** RED - File not readable
  - **Verifies:** AC4 - displays result.totalCostUsd

#### AC6: Actual Public API (3 tests)

- **Test:** `testCustomSystemPromptExampleAgentOptionsUsesRealParameterNames`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - AgentOptions uses real parameter names

- **Test:** `testCustomSystemPromptExampleQueryResultMatchesSourceType`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - QueryResult property access matches source type

- **Test:** `testCustomSystemPromptExampleUsesAwaitForPrompt`
  - **Status:** RED - File not readable
  - **Verifies:** AC6 - uses `await agent.prompt()` (correct async API)

#### AC7: Comments and Security (5 tests)

- **Test:** `testCustomSystemPromptExampleHasTopLevelDescriptionComment`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - file starts with descriptive comment block

- **Test:** `testCustomSystemPromptExampleHasMultipleInlineComments`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - has more than 3 inline comments

- **Test:** `testCustomSystemPromptExampleDoesNotExposeRealAPIKeys`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - no real API keys exposed

- **Test:** `testCustomSystemPromptExampleUsesPlaceholderOrEnvVarForAPIKey`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - uses sk-... placeholder or ProcessInfo env var

- **Test:** `testCustomSystemPromptExampleDoesNotUseForceUnwrap`
  - **Status:** RED - File not readable
  - **Verifies:** AC7 - no try! force-try

---

## Implementation Checklist

### Test: Package.swift Target (3 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/CustomSystemPromptExampleComplianceTests.swift`

**Tasks to make these tests pass:**

- [ ] Add `.executableTarget(name: "CustomSystemPromptExample", dependencies: ["OpenAgentSDK"], path: "Examples/CustomSystemPromptExample")` to Package.swift targets array
- [ ] Verify target depends on OpenAgentSDK
- [ ] Verify path is "Examples/CustomSystemPromptExample"
- [ ] Run: `swift build` to confirm compilation

**Estimated Effort:** 0.25 hours

---

### Test: Example File Creation (25 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/CustomSystemPromptExampleComplianceTests.swift`

**Tasks to make these tests pass:**

- [ ] Create directory `Examples/CustomSystemPromptExample/`
- [ ] Create `Examples/CustomSystemPromptExample/main.swift`
- [ ] Add file-level comment block describing purpose
- [ ] Import Foundation and OpenAgentSDK
- [ ] Read API key from environment variable or use "sk-..." placeholder
- [ ] Create Agent with `createAgent(options:)` using `AgentOptions`:
  - apiKey, model ("claude-sonnet-4-6")
  - systemPrompt: specialized role (e.g., code review expert) with format guidance
  - maxTurns: 5
  - permissionMode: .bypassPermissions
  - Do NOT pass tools parameter (defaults to nil)
- [ ] Use `await agent.prompt()` for blocking query (NOT `agent.stream()`)
- [ ] Output all QueryResult fields: text, status, numTurns, durationMs, usage.inputTokens, usage.outputTokens, totalCostUsd
- [ ] Add inline comments for key steps (more than 3)
- [ ] Do NOT use `try!` force-try
- [ ] Do NOT use real API keys
- [ ] Run: `swift build` to confirm compilation
- [ ] Run: `swift test --filter CustomSystemPromptExampleComplianceTests`

**Estimated Effort:** 1 hour

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter CustomSystemPromptExampleComplianceTests

# Run full test suite (verify no regressions)
swift test

# Build only (verify compilation)
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All 28 tests written and failing
- Failure reason: Examples/CustomSystemPromptExample/main.swift does not exist and Package.swift lacks the target
- Implementation checklist created
- No test quality issues (follows established pattern from MultiToolExampleComplianceTests)

**Verification:**

```
Executed 28 tests, with 31 failures (0 unexpected) in 0.575 seconds
```

All tests fail due to missing implementation, not test bugs.

---

### GREEN Phase (DEV Team - Next Steps)

1. Add executableTarget to Package.swift
2. Create Examples/CustomSystemPromptExample/main.swift
3. Run `swift build` to verify compilation
4. Run `swift test --filter CustomSystemPromptExampleComplianceTests` to verify all 28 pass
5. Run full suite to verify no regressions

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter CustomSystemPromptExampleComplianceTests`

**Results:**

```
Executed 28 tests, with 31 failures (0 unexpected) in 0.575 (0.579) seconds
```

**Summary:**

- Total tests: 28
- Passing: 0 (expected)
- Failing: 28 (31 failure assertions) (expected)
- Status: RED phase verified

### Full Suite Regression Check

**Command:** `swift test`

**Results:**

```
Executed 1883 tests, with 4 tests skipped and 31 failures (0 unexpected)
```

- The 31 failures are all from CustomSystemPromptExampleComplianceTests (RED phase, expected)
- Zero unexpected failures -- no regressions introduced
- 4 skipped tests are pre-existing

---

## Notes

- This is a Swift backend project; ATDD tests are compliance/static-analysis tests (XCTest) that verify file existence, content patterns, and API signature correctness
- Tests follow the exact pattern established in MultiToolExampleComplianceTests.swift (Story 10-1)
- Story explicitly states no unit tests needed; these compliance tests serve as compilation/API-correctness gate
- Key difference from Story 10-1: this example uses blocking `agent.prompt()` API (not streaming) and does NOT register tools

---

**Generated by BMad TEA Agent** - 2026-04-10
