---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-07'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-6-config-remote-trigger-tools.md'
  - 'Sources/OpenAgentSDK/Tools/ToolBuilder.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift'
  - 'Sources/OpenAgentSDK/Tools/ToolRegistry.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/CronToolsTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift'
---

# ATDD Checklist - Epic 5, Story 5.6: Config Tool & RemoteTrigger Tool

**Date:** 2026-04-07
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest with async tool execution via `await`)
**Detected Stack:** backend (Swift Package, XCTest)

---

## Story Summary

Implement Config tool for managing session-scoped configuration (get/set/list operations with in-memory storage) and RemoteTrigger tool as a pure stub implementation that returns a prompt for all actions. Neither tool requires an Actor store, ToolContext modifications, or AgentOptions changes.

**As a** developer using the OpenAgentSDK
**I want** my Agent to manage SDK configuration and trigger remote operations
**So that** it can adjust settings and interact with external systems

---

## Acceptance Criteria

1. **AC1: ConfigTool Registration** -- Given ConfigTool is registered, when LLM lists available tools, then sees a tool named "Config" with description "Get or set configuration values. Supports session-scoped settings." (FR18).
2. **AC2: Config get Operation** -- Given ConfigTool, when LLM requests get with key, then returns JSON value. If key not found, returns `Config key "{key}" not found` (FR18).
3. **AC3: Config get Missing Key Error** -- Given ConfigTool, when LLM requests get without key, then returns is_error=true with "key required for get".
4. **AC4: Config set Operation** -- Given ConfigTool, when LLM requests set with key and value, then stores value and returns `Config set: {key} = {JSON(value)}` (FR18).
5. **AC5: Config set Missing Key Error** -- Given ConfigTool, when LLM requests set without key, then returns is_error=true with "key required for set".
6. **AC6: Config list Operation** -- Given ConfigTool, when LLM requests list, then returns all config entries as `{key} = {JSON(value)}` per line. If empty, returns "No config values set." (FR18).
7. **AC7: Config Unknown Action Error** -- Given ConfigTool, when LLM requests unknown action, then returns is_error=true with `Unknown action: {action}`.
8. **AC8: ConfigTool isReadOnly** -- Given ConfigTool, when checking isReadOnly, then returns false (set modifies state).
9. **AC9: ConfigTool inputSchema Matches TS SDK** -- action (string, required, enum: get/set/list), key (string, optional), value (optional, any type).
10. **AC10: RemoteTriggerTool Registration** -- Given RemoteTriggerTool is registered, when LLM lists available tools, then sees a tool named "RemoteTrigger" with description mentioning remote triggers (FR18).
11. **AC11: RemoteTrigger Stub Implementation** -- Given RemoteTriggerTool, when LLM requests any action (list/get/create/update/run), then returns stub message about needing remote backend and suggesting CronCreate/CronList/CronDelete (FR18).
12. **AC12: RemoteTriggerTool isReadOnly** -- Given RemoteTriggerTool, when checking isReadOnly, then returns false.
13. **AC13: RemoteTriggerTool inputSchema Matches TS SDK** -- action (string, required, enum: list/get/create/update/run), id (string, optional), name (string, optional), schedule (string, optional), prompt (string, optional).
14. **AC14: Module Boundary Compliance** -- Given both tools in Tools/Specialist/, when checking imports, then only imports Foundation and Types/, never Core/ or Stores/ (architecture rules #7, #40).
15. **AC15: Error Handling Doesn't Break Loop** -- Given exception during tool execution, when error is caught, then returns is_error=true ToolResult without interrupting Agent loop (architecture rule #38).
16. **AC16: ToolRegistry Registration** -- Given both factory functions, when calling `getAllBaseTools(tier: .specialist)`, then array contains both tools.
17. **AC17: OpenAgentSDK.swift Documentation Update** -- Given module entry file, when checking public API docs, then includes createConfigTool and createRemoteTriggerTool references.
18. **AC18: No New Actor Store Needed** -- Given ConfigTool uses in-memory Map, RemoteTriggerTool is stateless stub, when implementing, then no new Actor store, no ToolContext or AgentOptions changes.
19. **AC19: E2E Test Coverage** -- Given story complete, when checking `Sources/E2ETest/`, then includes Config and RemoteTrigger E2E tests.

---

## Test Strategy

**Stack:** Backend (Swift) -- XCTest framework

**Test Levels:**
- **Unit** (primary): ConfigTool and RemoteTriggerTool factory functions, input schemas, isReadOnly, operation behaviors
- **Integration** (supplementary): Full lifecycle workflows (set-get-list)

**Execution Mode:** Sequential (single agent, backend-only project, yolo mode)

---

## Generation Mode

**Mode:** AI Generation
**Reason:** Backend Swift project with XCTest. No browser UI. Acceptance criteria are clear with well-defined tool operation patterns. All scenarios are unit tests for two stateless/stateful tools.

---

## Failing Tests Created (RED Phase)

### ConfigTool Tests (25 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/ConfigToolTests.swift`

#### AC1: ConfigTool Registration
- **Test:** `testCreateConfigTool_returnsToolProtocol`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC1 -- factory returns ToolProtocol with name "Config"
  - **Priority:** P0

- **Test:** `testCreateConfigTool_descriptionMatchesTSSdk`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC1 -- description mentions config and get/set/configuration
  - **Priority:** P0

#### AC8: ConfigTool isReadOnly
- **Test:** `testCreateConfigTool_isReadOnly_returnsFalse`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC8 -- isReadOnly is false
  - **Priority:** P0

#### AC9: inputSchema Matches TS SDK
- **Test:** `testCreateConfigTool_inputSchema_hasCorrectType`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC9 -- schema type is "object"
  - **Priority:** P0

- **Test:** `testCreateConfigTool_inputSchema_actionIsRequired`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC9 -- action is in required array
  - **Priority:** P0

- **Test:** `testCreateConfigTool_inputSchema_actionEnum_hasGetSetList`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC9 -- action enum contains get, set, list
  - **Priority:** P0

- **Test:** `testCreateConfigTool_inputSchema_hasOptionalKey`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC9 -- key is string, optional
  - **Priority:** P0

- **Test:** `testCreateConfigTool_inputSchema_hasOptionalValue`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC9 -- value is optional, no type constraint
  - **Priority:** P0

#### AC3: Config get Missing Key Error
- **Test:** `testConfigGet_missingKey_returnsError`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC3 -- missing key returns is_error=true
  - **Priority:** P0

#### AC2: Config get Operation
- **Test:** `testConfigGet_existingKey_returnsValue`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC2 -- returns stored value
  - **Priority:** P0

- **Test:** `testConfigGet_nonExistentKey_returnsNotFound`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC2 -- non-existent key returns "not found" message
  - **Priority:** P0

#### AC5: Config set Missing Key Error
- **Test:** `testConfigSet_missingKey_returnsError`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC5 -- missing key returns is_error=true
  - **Priority:** P0

#### AC4: Config set Operation
- **Test:** `testConfigSet_withKeyAndValue_returnsConfirmation`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC4 -- stores and returns confirmation
  - **Priority:** P0

- **Test:** `testConfigSet_numericValue_storesCorrectly`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC4 -- stores numeric values correctly
  - **Priority:** P0

- **Test:** `testConfigSet_booleanValue_storesCorrectly`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC4 -- stores boolean values correctly
  - **Priority:** P0

- **Test:** `testConfigSet_overwritesExistingValue`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC4 -- overwrites existing values
  - **Priority:** P1

#### AC6: Config list Operation
- **Test:** `testConfigList_empty_returnsNoValuesMessage`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC6 -- empty list returns "No config values set."
  - **Priority:** P0

- **Test:** `testConfigList_withValues_returnsAllEntries`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC6 -- returns all config entries
  - **Priority:** P0

- **Test:** `testConfigList_format_perLine`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC6 -- format is `key = JSON(value)` per line
  - **Priority:** P0

#### AC7: Config Unknown Action Error
- **Test:** `testConfig_unknownAction_returnsError`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC7 -- unknown action returns is_error=true
  - **Priority:** P0

#### AC15: Error Handling
- **Test:** `testConfigTool_neverThrows_malformedInput`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC15 -- tool never throws, always returns ToolResult
  - **Priority:** P0

#### AC14/AC18: Module Boundary & No Actor Store
- **Test:** `testConfigTool_doesNotRequireStoreInContext`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC14, AC18 -- works with basic ToolContext
  - **Priority:** P0

- **Test:** `testConfigTool_noActorStoreNeeded`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC18 -- bare ToolContext works
  - **Priority:** P0

#### AC16: ToolRegistry Registration
- **Test:** `testToolRegistry_specialistTier_includesConfigTool`
  - **Status:** RED - `createConfigTool()` not registered yet
  - **Verifies:** AC16 -- specialist tier includes Config tool
  - **Priority:** P0

#### Integration
- **Test:** `testIntegration_fullConfigLifecycle`
  - **Status:** RED - `createConfigTool()` does not exist yet
  - **Verifies:** AC2, AC4, AC6 -- set -> get -> list -> overwrite -> get lifecycle
  - **Priority:** P1

---

### RemoteTriggerTool Tests (19 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/RemoteTriggerToolTests.swift`

#### AC10: RemoteTriggerTool Registration
- **Test:** `testCreateRemoteTriggerTool_returnsToolProtocol`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC10 -- factory returns ToolProtocol with name "RemoteTrigger"
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_descriptionMentionsRemoteTriggers`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC10 -- description mentions remote or trigger
  - **Priority:** P0

#### AC12: RemoteTriggerTool isReadOnly
- **Test:** `testCreateRemoteTriggerTool_isReadOnly_returnsFalse`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC12 -- isReadOnly is false
  - **Priority:** P0

#### AC13: inputSchema Matches TS SDK
- **Test:** `testCreateRemoteTriggerTool_inputSchema_hasCorrectType`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- schema type is "object"
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_inputSchema_actionIsRequired`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- action is in required array
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_inputSchema_actionEnum_hasAllFiveValues`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- action enum contains all 5 values
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_inputSchema_hasOptionalId`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- id is string, optional
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_inputSchema_hasOptionalName`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- name is string, optional
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_inputSchema_hasOptionalSchedule`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- schedule is string, optional
  - **Priority:** P0

- **Test:** `testCreateRemoteTriggerTool_inputSchema_hasOptionalPrompt`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC13 -- prompt is string, optional
  - **Priority:** P0

#### AC11: RemoteTrigger Stub Implementation
- **Test:** `testRemoteTrigger_list_returnsStubMessage`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC11 -- list returns stub
  - **Priority:** P0

- **Test:** `testRemoteTrigger_get_returnsStubMessage`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC11 -- get returns stub
  - **Priority:** P0

- **Test:** `testRemoteTrigger_create_returnsStubMessage`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC11 -- create returns stub
  - **Priority:** P0

- **Test:** `testRemoteTrigger_update_returnsStubMessage`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC11 -- update returns stub
  - **Priority:** P0

- **Test:** `testRemoteTrigger_run_returnsStubMessage`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC11 -- run returns stub
  - **Priority:** P0

- **Test:** `testRemoteTrigger_stubMentionsCronAlternatives`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC11 -- stub mentions CronCreate/CronList/CronDelete
  - **Priority:** P0

#### AC15: Error Handling
- **Test:** `testRemoteTriggerTool_neverThrows_malformedInput`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC15 -- tool never throws, always returns ToolResult
  - **Priority:** P0

#### AC14: Module Boundary
- **Test:** `testRemoteTriggerTool_doesNotRequireStoreInContext`
  - **Status:** RED - `createRemoteTriggerTool()` does not exist yet
  - **Verifies:** AC14 -- works with basic ToolContext
  - **Priority:** P0

#### AC16: ToolRegistry Registration
- **Test:** `testToolRegistry_specialistTier_includesRemoteTriggerTool`
  - **Status:** RED - `createRemoteTriggerTool()` not registered yet
  - **Verifies:** AC16 -- specialist tier includes RemoteTrigger tool
  - **Priority:** P0

---

## Implementation Checklist

### ConfigTool Implementation

**File:** `Sources/OpenAgentSDK/Tools/Specialist/ConfigTool.swift`

**Tasks to make these tests pass:**

- [ ] Create `Sources/OpenAgentSDK/Tools/Specialist/ConfigTool.swift`
- [ ] Define `private nonisolated(unsafe) let configSchema: ToolInputSchema` with correct schema (action enum: get/set/list, optional key, optional value)
- [ ] Implement `public func createConfigTool() -> ToolProtocol` using `defineTool` with `(input: Any, context:)` overload
- [ ] Use file-level dictionary for in-memory config storage
- [ ] Implement get: validate key, return value or "not found"
- [ ] Implement set: validate key, store value, return confirmation
- [ ] Implement list: return all entries or "No config values set."
- [ ] Implement default: return "Unknown action: {action}" with isError: true
- [ ] Implement JSON serialization helper for value types
- [ ] Run tests: `swift test --filter ConfigToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 1 hour

---

### RemoteTriggerTool Implementation

**File:** `Sources/OpenAgentSDK/Tools/Specialist/RemoteTriggerTool.swift`

**Tasks to make these tests pass:**

- [ ] Create `Sources/OpenAgentSDK/Tools/Specialist/RemoteTriggerTool.swift`
- [ ] Define `private struct RemoteTriggerInput: Codable` with action, id, name, schedule, prompt
- [ ] Define `private nonisolated(unsafe) let remoteTriggerSchema: ToolInputSchema` with correct schema
- [ ] Implement `public func createRemoteTriggerTool() -> ToolProtocol` using `defineTool`
- [ ] All actions return same stub message with action name embedded
- [ ] Run tests: `swift test --filter RemoteTriggerToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.25 hours

---

### ToolRegistry Update

**File:** `Sources/OpenAgentSDK/Tools/ToolRegistry.swift`

**Tasks:**

- [ ] Add `createConfigTool()` and `createRemoteTriggerTool()` to specialist tier
- [ ] Run tests: `swift test --filter ConfigToolTests` and `swift test --filter RemoteTriggerToolTests`
- [ ] Registry tests pass (green phase)

**Estimated Effort:** 0.1 hours

---

### OpenAgentSDK.swift Documentation

**File:** `Sources/OpenAgentSDK/OpenAgentSDK.swift`

**Tasks:**

- [ ] Add documentation references for createConfigTool and createRemoteTriggerTool

**Estimated Effort:** 0.1 hours

---

## Running Tests

```bash
# Run Config tool tests
swift test --filter ConfigToolTests

# Run RemoteTrigger tool tests
swift test --filter RemoteTriggerToolTests

# Run both
swift test --filter "ConfigToolTests|RemoteTriggerToolTests"

# Run full test suite
swift test

# Build without running
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- [x] All tests written and failing (createConfigTool/createRemoteTriggerTool do not exist)
- [x] No mock requirements needed (Config uses in-memory store, RemoteTrigger is pure stub)
- [x] Implementation checklist created
- [x] Test patterns follow existing Specialist tool conventions (CronToolsTests, LSPToolTests)

**Verification:**

- All tests will fail to compile because `createConfigTool()` and `createRemoteTriggerTool()` do not exist
- Failure is clear: "cannot find 'createConfigTool' in scope" etc.
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with RemoteTriggerTool** -- simplest (pure stub, all actions return same message)
2. **Then implement ConfigTool** -- slightly more complex (in-memory store, 3 operations, JSON serialization)
3. **Update ToolRegistry** -- add both factory functions to specialist tier
4. **Update OpenAgentSDK.swift** -- add documentation references
5. **Run tests** after each implementation step
6. **Verify module boundaries** (no Core/ or Stores/ imports)

**Key Principles:**

- One tool at a time (start with RemoteTrigger since it's simpler)
- Minimal implementation (follow story dev notes skeleton code)
- Run tests frequently (immediate feedback)
- Use implementation checklist as roadmap
- Reference LSPTool for stateless specialist tool patterns
- Reference CronTools for specialist tool file organization

---

### REFACTOR Phase (After All Tests Pass)

1. Verify all tests pass (green phase complete)
2. Check that ConfigTool.swift only imports Foundation
3. Check that RemoteTriggerTool.swift only imports Foundation
4. Review error handling completeness
5. Ensure tests still pass after each refactor
6. No force unwraps, no unnecessary dependencies

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter ConfigToolTests` and `swift test --filter RemoteTriggerToolTests`

**Expected Results:**

```
error: cannot find 'createConfigTool' in scope
error: cannot find 'createRemoteTriggerTool' in scope
```

**Summary:**

- Total new tests: 44
  - ConfigToolTests: 25 tests
  - RemoteTriggerToolTests: 19 tests
- Passing: 0 (expected)
- Failing: 44 (expected -- compile error, factory functions do not exist)
- Status: RED phase verified

---

## Notes

- ConfigTool uses in-memory dictionary storage (session-scoped, no persistence)
- RemoteTriggerTool is a pure stub -- all 5 actions return the same format of message
- Neither tool requires Actor store, ToolContext modifications, or AgentOptions changes
- ConfigTool uses `(input: Any, context:)` overload because value is arbitrary type
- RemoteTriggerTool uses Codable `RemoteTriggerInput` struct
- Test naming: `test{MethodName}_{scenario}_{expectedBehavior}`
- No real network calls -- pure unit tests
- ConfigTool isReadOnly: false (set modifies state)
- RemoteTriggerTool isReadOnly: false (conceptually has write operations)
- Test patterns mirror LSPToolTests and CronToolsTests

---

**Generated by BMad TEA Agent** - 2026-04-07
