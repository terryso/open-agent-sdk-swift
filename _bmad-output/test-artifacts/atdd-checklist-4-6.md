---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-07'
inputDocuments:
  - _bmad-output/implementation-artifacts/4-6-team-tools-create-delete.md
  - Sources/OpenAgentSDK/Types/TaskTypes.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Stores/TeamStore.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift
  - Sources/OpenAgentSDK/Tools/Advanced/TaskCreateTool.swift
  - Tests/OpenAgentSDKTests/Tools/Advanced/TaskToolsTests.swift
---

# ATDD Checklist: Story 4-6 -- Team Tools (Create/Delete)

## TDD Red Phase (Current)

- [x] Failing tests generated
- Unit Tests: 1 file, 24 tests (will not compile until factory functions exist)

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, XCTest)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)
- **Execution Mode:** sequential

## Acceptance Criteria Coverage

| AC # | Description | Test Coverage | Priority |
|------|-------------|---------------|----------|
| AC1  | TeamCreate tool factory + behavior | 6 tests (factory, schema, readOnly, name-only, with-members, input-decode) | P0 |
| AC2  | TeamDelete tool factory + behavior | 5 tests (factory, schema, readOnly, delete-success, delete-not-found, delete-already-disbanded) | P0 |
| AC3  | ToolContext dependency injection (teamStore) | 3 tests (has-teamStore, defaults-nil, backward-compat, all-fields) | P0 |
| AC4  | Module boundary compliance | 1 test (no-direct-store-imports) | P0 |
| AC5  | Error handling (nil teamStore, never throws) | 5 tests (nil-store for both tools, malformed input for both, never-throws) | P0 |
| AC6  | inputSchema matches TS SDK | 2 tests (TeamCreate schema, TeamDelete schema) | P0 |
| AC7  | isReadOnly = false for both tools | 2 tests | P0 |
| AC8  | AgentOptions/Agent.swift unmodified | Covered by AC3 (ToolContext already has teamStore) | P0 |

## Test Inventory

### File: `Tests/OpenAgentSDKTests/Tools/Advanced/TeamToolsTests.swift`

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | testCreateTeamCreateTool_returnsToolProtocol | AC1 | P0 | Factory returns valid ToolProtocol with name "TeamCreate" |
| 2 | testCreateTeamCreateTool_hasValidInputSchema | AC6 | P0 | inputSchema matches TS SDK (name, members, task_description, required) |
| 3 | testCreateTeamCreateTool_isNotReadOnly | AC7 | P0 | isReadOnly is false |
| 4 | testTeamCreate_nameOnly_returnsSuccess | AC1 | P0 | Create team with only required name field |
| 5 | testTeamCreate_withMembers_returnsSuccess | AC1 | P0 | Create team with name + members array |
| 6 | testTeamCreate_defaultMembersEmpty | AC1 | P0 | Omitting members defaults to empty array |
| 7 | testTeamCreate_inputDecodable | AC6 | P0 | JSON input correctly decodes all fields |
| 8 | testCreateTeamDeleteTool_returnsToolProtocol | AC2 | P0 | Factory returns valid ToolProtocol with name "TeamDelete" |
| 9 | testCreateTeamDeleteTool_hasValidInputSchema | AC6 | P0 | inputSchema matches TS SDK (id, required) |
| 10 | testCreateTeamDeleteTool_isNotReadOnly | AC7 | P0 | isReadOnly is false |
| 11 | testTeamDelete_existingTeam_returnsSuccess | AC2 | P0 | Delete an existing active team succeeds |
| 12 | testTeamDelete_nonexistentTeam_returnsError | AC2 | P0 | Delete non-existent team returns isError=true |
| 13 | testTeamDelete_alreadyDisbanded_returnsError | AC2 | P0 | Delete already-disbanded team returns isError=true |
| 14 | testTeamCreate_nilTeamStore_returnsError | AC5 | P0 | Create with nil teamStore returns error |
| 15 | testTeamDelete_nilTeamStore_returnsError | AC5 | P0 | Delete with nil teamStore returns error |
| 16 | testTeamCreate_neverThrows_malformedInput | AC5 | P0 | Malformed input never throws |
| 17 | testTeamDelete_neverThrows_malformedInput | AC5 | P0 | Malformed input never throws |
| 18 | testToolContext_hasTeamStoreField | AC3 | P0 | ToolContext can be created with teamStore |
| 19 | testToolContext_teamStoreDefaultsToNil | AC3 | P0 | ToolContext teamStore defaults to nil |
| 20 | testToolContext_withAllFields | AC3 | P0 | ToolContext works with all fields populated |
| 21 | testTeamTools_moduleBoundary_noDirectStoreImports | AC4 | P0 | Factory functions work through ToolContext injection |
| 22 | testTeamCreate_verifyTeamInStore | AC1 | P1 | After create, team is retrievable from store |
| 23 | testTeamDelete_verifyTeamRemovedFromStore | AC2 | P1 | After delete, team is gone from store |
| 24 | testIntegration_createThenDelete | Integration | P1 | Create a team then delete it |

## Why Tests Will Fail (TDD Red Phase)

All 24 tests reference two factory functions that do not exist yet:

1. **`createTeamCreateTool()`** -- Not defined anywhere in the codebase yet
2. **`createTeamDeleteTool()`** -- Not defined anywhere in the codebase yet

The tests will fail at **compile time** with "Cannot find 'createTeamCreateTool' in scope" and
"Cannot find 'createTeamDeleteTool' in scope". This is intentional -- TDD red phase.

Once the factory functions are implemented in:
- `Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift`
- `Sources/OpenAgentSDK/Tools/Advanced/TeamDeleteTool.swift`

the tests will compile and should pass (green phase).

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Create `Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift` with `createTeamCreateTool()` factory
2. Create `Sources/OpenAgentSDK/Tools/Advanced/TeamDeleteTool.swift` with `createTeamDeleteTool()` factory
3. Update `Sources/OpenAgentSDK/OpenAgentSDK.swift` with re-export comments
4. Run `swift test --filter TeamToolsTests` -- verify all 24 tests PASS
5. Commit passing tests

## Implementation Guidance

### Factory functions to implement:

- `createTeamCreateTool() -> ToolProtocol` in `Tools/Advanced/TeamCreateTool.swift`
  - Private `TeamCreateInput: Codable` with name (required), members (optional [String]), task_description (optional String)
  - Uses `defineTool` with `ToolExecuteResult` return overload
  - Gets teamStore from `context.teamStore`, returns error if nil
  - Converts `[String]` to `[TeamMember]` with default role `.member`
  - Calls `teamStore.create(name:members:leaderId:)`
  - `isReadOnly: false`

- `createTeamDeleteTool() -> ToolProtocol` in `Tools/Advanced/TeamDeleteTool.swift`
  - Private `TeamDeleteInput: Codable` with id (required)
  - Uses `defineTool` with `ToolExecuteResult` return overload
  - Gets teamStore from `context.teamStore`, returns error if nil
  - Calls `teamStore.delete(id:)` with try await
  - Catches `TeamStoreError.teamNotFound` and `TeamStoreError.teamAlreadyDisbanded`
  - `isReadOnly: false`

### Files to modify (comments only):

- `Sources/OpenAgentSDK/OpenAgentSDK.swift` -- add re-export comments for TeamCreate/TeamDelete

### Files NOT to modify:

- `ToolTypes.swift` -- teamStore already exists
- `AgentTypes.swift` -- teamStore already exists
- `Agent.swift` -- teamStore already injected
