---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-09'
inputDocuments:
  - _bmad-output/implementation-artifacts/8-1-hook-event-types-registry.md
  - Sources/OpenAgentSDK/Types/HookTypes.swift
  - Tests/OpenAgentSDKTests/Types/HookTypesTests.swift
  - Tests/OpenAgentSDKTests/Stores/SessionStoreTests.swift
  - Sources/E2ETest/SessionStoreE2ETests.swift
  - Sources/E2ETest/TestHarness.swift
---

# ATDD Checklist: Story 8-1 -- HookRegistry Actor & Function Hook Execution

## TDD Red Phase (Current)

**All tests will FAIL until `HookRegistry` is implemented.** Tests reference types and methods that do not yet exist (`HookRegistry` actor, `HookDefinition.handler` closure), so they will not compile. This is intentional -- TDD red phase.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | HookRegistry Actor basic structure | P0 | Unit | `testInit_createsHookRegistryActor` |
| AC2 | Register single hook | P0 | Unit | `testRegister_singleHook_stored`, `testHookEvent_has21Cases`, `testRegister_multipleEvents_independent`, `testRegister_all21Events_canBeRegistered` |
| AC3 | PreToolUse hook execution | P0 | Unit | `testExecute_singleHook_returnsOutput`, `testExecute_noHooks_returnsEmptyArray`, `testExecute_preToolUse_canBlock` |
| AC4 | Batch register from config | P0 | Unit | `testRegisterFromConfig_validEventsRegistered`, `testRegisterFromConfig_invalidEventsSkipped`, `testRegisterFromConfig_appendsToExisting` |
| AC5 | Multiple hooks in order | P0 | Unit | `testExecute_multipleHooks_executedInOrder` |
| AC6 | Matcher filtering | P0 | Unit | `testExecute_matcherFilters`, `testExecute_nilMatcher_matchesAll`, `testExecute_matcherRegex_patternMatches`, `testExecute_matcherWithNilToolName_skipsFilteredHook` |
| AC7 | Hook timeout | P0 | Unit | `testExecute_timeout_returnsEmptyForTimedOutHook` |
| AC8 | hasHooks query | P0 | Unit | `testHasHooks_returnsCorrectly` |
| AC9 | clear all hooks | P0 | Unit | `testClear_removesAllHooks` |
| AC10 | Handler closure support | P0 | Unit | `testExecute_handlerReceivesCorrectInput`, `testExecute_handlerFailure_doesNotAffectOtherHooks` |
| AC11 | Thread safety | P0 | Unit | `testConcurrentRegisterExecute_threadSafe` |
| AC12 | Unit test coverage | -- | Unit | All 18 unit tests in `HookRegistryTests.swift` |
| AC13 | E2E test coverage | -- | E2E | `testRegisterAndTrigger_verifyOutput`, `testMultipleHooks_executeInOrder` |

## Test Summary

- **Total Tests:** 20 (18 unit + 2 E2E)
- **Unit Tests:** 18 (all in `Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift`)
- **E2E Tests:** 2 (all in `Sources/E2ETest/HookRegistryE2ETests.swift`)
- **All tests will FAIL until feature is implemented** (compilation failure -- types don't exist)

## Unit Test Plan (Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testInit_createsHookRegistryActor` | AC1 | P0 | HookRegistry can be instantiated as an actor |
| 2 | `testRegister_singleHook_stored` | AC2 | P0 | register() stores a hook on a lifecycle event |
| 3 | `testHookEvent_has21Cases` | AC2 | P0 | HookEvent has exactly 21 cases (CaseIterable) |
| 4 | `testRegister_multipleEvents_independent` | AC2 | P0 | register() on different events are independent |
| 5 | `testRegisterFromConfig_validEventsRegistered` | AC4 | P0 | registerFromConfig() registers hooks for valid event names |
| 6 | `testRegisterFromConfig_invalidEventsSkipped` | AC4 | P0 | registerFromConfig() silently skips invalid event names |
| 7 | `testExecute_singleHook_returnsOutput` | AC3 | P0 | execute() calls registered handler and returns output |
| 8 | `testExecute_noHooks_returnsEmptyArray` | AC3 | P0 | execute() returns empty array when no hooks registered |
| 9 | `testExecute_preToolUse_canBlock` | AC3 | P0 | execute() returns block=true from PreToolUse hook |
| 10 | `testExecute_multipleHooks_executedInOrder` | AC5 | P0 | Multiple hooks on same event execute in registration order |
| 11 | `testExecute_matcherFilters` | AC6 | P0 | Hook with matcher filters by toolName |
| 12 | `testExecute_nilMatcher_matchesAll` | AC6 | P0 | Hook with nil matcher matches all tools |
| 13 | `testExecute_matcherRegex_patternMatches` | AC6 | P1 | Hook with regex matcher matches pattern |
| 14 | `testExecute_timeout_returnsEmptyForTimedOutHook` | AC7 | P0 | Hook exceeding timeout returns empty, doesn't block others |
| 15 | `testExecute_handlerFailure_doesNotAffectOtherHooks` | AC10 | P0 | Handler failure does not affect other hooks |
| 16 | `testHasHooks_returnsCorrectly` | AC8 | P0 | hasHooks() returns false before registration, true after |
| 17 | `testClear_removesAllHooks` | AC9 | P0 | clear() removes all hooks from all events |
| 18 | `testConcurrentRegisterExecute_threadSafe` | AC11 | P0 | Concurrent register and execute are thread-safe |
| 19 | `testExecute_handlerReceivesCorrectInput` | AC10 | P0 | Handler receives HookInput with correct event and toolName |
| 20 | `testRegister_all21Events_canBeRegistered` | AC2 | P1 | All 21 HookEvent cases can be registered and queried |
| 21 | `testRegisterFromConfig_appendsToExisting` | AC4 | P1 | registerFromConfig() appends to existing hooks, not replaces |
| 22 | `testExecute_matcherWithNilToolName_skipsFilteredHook` | AC6 | P1 | Matcher skipped when input has nil toolName |

## E2E Test Plan (Sources/E2ETest/HookRegistryE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testRegisterAndTrigger_verifyOutput` | AC2,AC3 | P0 | Register hook, trigger event, verify handler called with correct output |
| 2 | `testMultipleHooks_executeInOrder` | AC5 | P0 | Register multiple hooks, trigger event, verify execution order |

## Implementation Guidance

### Types to Create/Modify

1. **`Sources/OpenAgentSDK/Hooks/HookRegistry.swift`** -- `actor HookRegistry`
   - `public init()`
   - `public func register(_ event: HookEvent, definition: HookDefinition)`
   - `public func registerFromConfig(_ config: [String: [HookDefinition]])`
   - `public func execute(_ event: HookEvent, input: HookInput) async -> [HookOutput]`
   - `public func hasHooks(_ event: HookEvent) -> Bool`
   - `public func clear()`
   - `private var hooks: [HookEvent: [HookDefinition]] = [:]`
   - `private enum HookExecutionError: Error { case timeout }`

2. **`Sources/OpenAgentSDK/Types/HookTypes.swift`** -- Modify `HookDefinition`
   - Add `handler: (@Sendable (HookInput) async -> HookOutput?)?` field
   - Update `init` to accept handler parameter with default `nil`
   - Use `@unchecked Sendable` conformance (consistent with existing pattern)

### Existing Types to Use (DO NOT MODIFY core logic)

- `HookEvent` (Types/HookTypes.swift) -- 21-case enum, already CaseIterable
- `HookInput` (Types/HookTypes.swift) -- event, toolName, toolInput, etc.
- `HookOutput` (Types/HookTypes.swift) -- message, permissionUpdate, block, notification
- `PermissionUpdate` (Types/HookTypes.swift) -- already defined
- `HookNotification` (Types/HookTypes.swift) -- already defined

### Key Implementation Details

- Actor isolation ensures thread safety (no locks needed)
- Matcher uses Swift Regex: `try Regex(matcher)` + `toolName.contains(regex)`
- Timeout uses `withThrowingTaskGroup` with race between handler and `Task.sleep`
- Invalid regex in matcher: skip the hook (don't crash)
- Handler failure: catch and continue to next hook
- `registerFromConfig`: use `HookEvent(rawValue:)` to parse event names, skip nil results
- Default timeout: 30000ms (30 seconds) when `def.timeout` is nil

### Module Boundaries

- Hooks/ may import Types/ (HookEvent, HookInput, HookOutput, HookDefinition)
- Hooks/ must NOT import Core/ or Tools/
- HookRegistry.swift must be `public actor`

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test --filter HookRegistryTests` to verify unit tests pass
3. Run `swift run E2ETest` to verify E2E tests pass
4. Verify HookRegistry does NOT import Core/ (module boundary rule)
5. Run full test suite to verify no regressions
6. Commit passing tests
