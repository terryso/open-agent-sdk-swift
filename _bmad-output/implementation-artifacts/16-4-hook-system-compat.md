# Story 16.4: Hook System Compatibility Verification

Status: done

## Story

As an SDK developer,
I want to verify that Swift SDK's Hook system covers all 18 TypeScript SDK HookEvents and their corresponding input/output types,
so that all Hook usage patterns can be migrated from TypeScript to Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatHooks/` directory and `CompatHooks` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: 18 HookEvent coverage verification** -- Check Swift SDK's `HookEvent` enum against TS SDK's 18 events: PreToolUse, PostToolUse, PostToolUseFailure, Notification, UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, PreCompact, PermissionRequest, Setup, TeammateIdle, TaskCompleted, ConfigChange, WorktreeCreate, WorktreeRemove. Missing events recorded as gaps.

3. **AC3: BaseHookInput field verification** -- Verify Swift SDK's `HookInput` base fields cover TS SDK `BaseHookInput`: session_id, transcript_path, cwd, permission_mode, agent_id, agent_type.

4. **AC4: PreToolUse/PostToolUse/PostToolUseFailure HookInput verification** -- Verify PreToolUse HookInput contains tool_name, tool_input, tool_use_id. Verify PostToolUse HookInput contains tool_name, tool_input, tool_response, tool_use_id. Verify PostToolUseFailure HookInput contains error, is_interrupt.

5. **AC5: Other HookInput type verification** -- Verify StopHookInput (stop_hook_active, last_assistant_message), SubagentStartHookInput (agent_id, agent_type), SubagentStopHookInput (agent_id, agent_transcript_path, agent_type, last_assistant_message), PreCompactHookInput (trigger: manual/auto, custom_instructions), PermissionRequestHookInput (tool_name, tool_input, permission_suggestions).

6. **AC6: HookCallbackMatcher verification** -- Verify Swift SDK supports matcher regex filtering, multiple hook callbacks array, and timeout configuration (default 30 seconds).

7. **AC7: HookOutput type verification** -- Verify Swift SDK's `HookOutput` supports TS SDK `SyncHookJSONOutput` key fields: decision (approve/block), systemMessage, reason, permissionDecision (allow/deny/ask), updatedInput, additionalContext. Verify hookSpecificOutput variants: PreToolUse (permissionDecision, updatedInput, additionalContext), PostToolUse (updatedMCPToolOutput, additionalContext), PermissionRequest (decision with allow/deny).

8. **AC8: Live hook execution verification** -- Register PreToolUse hook demonstrating decision: block to intercept tool execution. Register PostToolUse hook demonstrating audit log recording. Verify hooks execute in registration order.

9. **AC9: Compatibility report output** -- For all 18 events and all HookInput/Output types, output per-item compatibility status.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatHooks/main.swift`
  - [x] Add `CompatHooks` executable target to `Package.swift`
  - [x] Verify `swift build` passes with zero errors and zero warnings

- [x] Task 2: HookEvent coverage check (AC: #2)
  - [x] Define TS SDK's 18 event list
  - [x] Iterate `HookEvent.allCases` to find matches
  - [x] Record missing: Setup, WorktreeCreate, WorktreeRemove
  - [x] Document Swift extras: permissionDenied, taskCreated, cwdChanged, fileChanged, postCompact

- [x] Task 3: HookInput field verification (AC: #3, #4, #5)
  - [x] Check HookInput struct fields against BaseHookInput (session_id, transcript_path, cwd, permission_mode, agent_id, agent_type)
  - [x] Check per-event fields: tool_name, tool_input, tool_output, tool_use_id, error
  - [x] Record missing fields: transcript_path, permission_mode, agent_id, agent_type, stop_hook_active, last_assistant_message, trigger, custom_instructions, permission_suggestions, is_interrupt

- [x] Task 4: HookCallbackMatcher and HookOutput verification (AC: #6, #7)
  - [x] Verify HookDefinition.matcher (regex filter) works
  - [x] Verify HookDefinition.timeout (default 30000ms) works
  - [x] Verify HookOutput fields: message, permissionUpdate, block, notification
  - [x] Record missing HookOutput fields vs TS: decision, systemMessage, reason, permissionDecision, updatedInput, additionalContext

- [x] Task 5: Live hook execution demo (AC: #8)
  - [x] Register PreToolUse hook with block: true to intercept tool execution
  - [x] Register PostToolUse hook for audit log
  - [x] Execute query with tool invocation, verify hooks fire in order

- [x] Task 6: Generate compatibility report (AC: #9)

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), fourth story
- **Prerequisites:** Stories 16-1, 16-2, 16-3 are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report

### Critical API Mapping: TS SDK 18 HookEvents vs Swift SDK HookEvent

Based on analysis of `Sources/OpenAgentSDK/Types/HookTypes.swift` (canonical source):

| # | TS SDK Event | Swift Equivalent | Raw Value Match? | Gap |
|---|---|---|---|---|
| 1 | PreToolUse | `preToolUse` | NO (lowercase) | PASS (case exists) |
| 2 | PostToolUse | `postToolUse` | NO (lowercase) | PASS (case exists) |
| 3 | PostToolUseFailure | `postToolUseFailure` | NO (lowercase) | PASS (case exists) |
| 4 | Notification | `notification` | NO (lowercase) | PASS (case exists) |
| 5 | UserPromptSubmit | `userPromptSubmit` | NO (lowercase) | PASS (case exists) |
| 6 | SessionStart | `sessionStart` | NO (lowercase) | PASS (case exists) |
| 7 | SessionEnd | `sessionEnd` | NO (lowercase) | PASS (case exists) |
| 8 | Stop | `stop` | YES | PASS (case exists) |
| 9 | SubagentStart | `subagentStart` | NO (lowercase) | PASS (case exists) |
| 10 | SubagentStop | `subagentStop` | NO (lowercase) | PASS (case exists) |
| 11 | PreCompact | `preCompact` | NO (lowercase) | PASS (case exists) |
| 12 | PermissionRequest | `permissionRequest` | NO (lowercase) | PASS (case exists) |
| 13 | **Setup** | **NO EQUIVALENT** | N/A | MISSING |
| 14 | TeammateIdle | `teammateIdle` | NO (lowercase) | PASS (case exists) |
| 15 | TaskCompleted | `taskCompleted` | NO (lowercase) | PASS (case exists) |
| 16 | ConfigChange | `configChange` | NO (lowercase) | PASS (case exists) |
| 17 | **WorktreeCreate** | **NO EQUIVALENT** | N/A | MISSING |
| 18 | **WorktreeRemove** | **NO EQUIVALENT** | N/A | MISSING |

**Swift extras (no TS equivalent):** `permissionDenied`, `taskCreated`, `cwdChanged`, `fileChanged`, `postCompact`

**Summary:** 15 of 18 TS events have Swift equivalents. 3 events are missing (Setup, WorktreeCreate, WorktreeRemove).

### HookInput Field-Level Gap Analysis

**Swift `HookInput` current fields (from HookTypes.swift:57-93):**
```swift
public struct HookInput: @unchecked Sendable {
    public let event: HookEvent
    public let toolName: String?
    public let toolInput: Any?
    public let toolOutput: Any?
    public let toolUseId: String?
    public let sessionId: String?
    public let cwd: String?
    public let error: String?
}
```

**TS SDK BaseHookInput fields vs Swift:**

| TS Field | Swift Field | Status |
|---|---|---|
| session_id | sessionId | PASS |
| transcript_path | N/A | MISSING |
| cwd | cwd | PASS |
| permission_mode | N/A | MISSING |
| agent_id | N/A | MISSING |
| agent_type | N/A | MISSING |

**TS SDK per-event HookInput fields vs Swift (single generic struct):**

| TS Event | TS Extra Fields | Swift Status |
|---|---|---|
| PreToolUse | tool_name, tool_input, tool_use_id | PASS (toolName, toolInput, toolUseId) |
| PostToolUse | tool_name, tool_input, tool_response, tool_use_id | PASS (toolName, toolInput, toolOutput, toolUseId) |
| PostToolUseFailure | error, is_interrupt | PARTIAL (has error; missing is_interrupt) |
| Stop | stop_hook_active, last_assistant_message | MISSING |
| SubagentStart | agent_id, agent_type | MISSING (not on base struct) |
| SubagentStop | agent_id, agent_transcript_path, agent_type, last_assistant_message | MISSING |
| PreCompact | trigger (manual/auto), custom_instructions | MISSING |
| PermissionRequest | tool_name, tool_input, permission_suggestions | PARTIAL (has toolName, toolInput; missing permission_suggestions) |

**Key difference:** Swift uses a single generic `HookInput` struct for all events. TS SDK uses event-specific input types that extend `BaseHookInput`. Swift's approach means per-event fields are missing.

### HookOutput Field-Level Gap Analysis

**Swift `HookOutput` current fields (from HookTypes.swift:102-123):**
```swift
public struct HookOutput: @unchecked Sendable, Equatable {
    public let message: String?
    public let permissionUpdate: PermissionUpdate?
    public let block: Bool
    public let notification: HookNotification?
}
```

**TS SDK `SyncHookJSONOutput` fields vs Swift:**

| TS Field | Swift Field | Status |
|---|---|---|
| decision (approve/block) | block: Bool | PARTIAL (block only, no approve) |
| systemMessage | N/A | MISSING |
| reason | N/A | MISSING |
| hookSpecificOutput | N/A | MISSING (no variant support) |

**TS SDK hookSpecificOutput variants vs Swift:**

| Variant | TS Fields | Swift Status |
|---|---|---|
| PreToolUse | permissionDecision (allow/deny/ask), updatedInput, additionalContext | MISSING |
| PostToolUse | updatedMCPToolOutput, additionalContext | MISSING |
| PermissionRequest | decision (allow with updatedInput/updatedPermissions, or deny with message/interrupt) | PARTIAL (has permissionUpdate) |
| UserPromptSubmit/SessionStart/Setup/SubagentStart | additionalContext | MISSING |

### HookCallbackMatcher (HookDefinition) Analysis

**Swift `HookDefinition` (from HookTypes.swift:190-211):**
- `matcher: String?` -- regex pattern for tool name filtering (matches TS)
- `handler: (@Sendable (HookInput) async -> HookOutput?)?` -- function handler (matches TS)
- `command: String?` -- shell command handler (Swift equivalent of TS shell hooks)
- `timeout: Int?` -- timeout in ms, default 30000 (matches TS)

**TS SDK `HookCallbackMatcher`:**
- `matcher?: RegExp` -- PASS (Swift has `matcher: String?`)
- `hooks: HookCallback[]` -- DIFFERENT (Swift registers one definition at a time, not arrays)
- `timeout?: number` -- PASS (Swift has `timeout: Int?`)

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** `HookRegistry` is an actor. Use `await` for all method calls.
- **HookDefinition:** Struct with optional handler/command/matcher/timeout.
- **Testing standards:** This is an example, not a test. Follow project example patterns.
- **Naming conventions:** PascalCase for types, camelCase for variables.

### Patterns to Follow (from Stories 16-1, 16-2, 16-3)

- Use `loadDotEnv()` / `getEnv()` for API key loading (see `Examples/CompatCoreQuery/main.swift`)
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern from CompatCoreQuery for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Package.swift already has `CompatCoreQuery`, `CompatToolSystem`, `CompatMessageTypes` targets -- add `CompatHooks` following the same pattern
- Use `swift build --target CompatHooks` for fast build verification

### File Locations

```
Examples/CompatHooks/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatHooks executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- HookEvent enum (20 cases), HookInput struct, HookOutput struct, HookDefinition, PermissionUpdate, HookNotification
- `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` -- HookRegistry actor with register(), execute(), hasHooks(), clear()
- `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift` -- Shell command hook execution
- `Examples/CompatCoreQuery/main.swift` -- Reference pattern for CompatEntry/record() report generation
- `Examples/CompatMessageTypes/main.swift` -- Latest pattern for compatibility reports

### Previous Story Intelligence (16-1, 16-2, 16-3)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Story 16-3 verified message types and found many gaps (12 of 20 TS types have no Swift equivalent)
- Known pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `nonisolated(unsafe)` for mutable globals
- Full test suite was 3251 tests passing at time of 16-3 completion
- Story 16-3 found hook-related message types (hook_started, hook_progress, hook_response) are all MISSING from Swift SDK -- this story verifies the hook system itself
- HookRegistry is an actor -- all calls require `await`

### Git Intelligence

Recent commits show Epic 16 progressing sequentially: 16-1 (core query), 16-2 (tool system), 16-3 (message types). The CompatEntry/record() pattern is established and consistent across all three examples. All examples follow the same scaffold pattern.

### References

- [Source: Sources/OpenAgentSDK/Types/HookTypes.swift] -- HookEvent (20 cases), HookInput (8 fields), HookOutput (4 fields), HookDefinition
- [Source: Sources/OpenAgentSDK/Hooks/HookRegistry.swift] -- HookRegistry actor with sequential execution and matcher filtering
- [Source: Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift] -- Shell hook execution via Foundation Process
- [Source: _bmad-output/planning-artifacts/epics.md#Epic16] -- Story 16.4 definition with 18 TS HookEvents and HookInput types
- [Source: _bmad-output/implementation-artifacts/16-3-message-types-compat.md] -- Previous story with established report pattern
- [Source: _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md] -- CompatEntry/record() pattern origin
- [TS SDK Reference] HookEvent (18 types), HookInput (BaseHookInput + per-event types), HookCallbackMatcher, SyncHookJSONOutput

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

- Initial build: 1 error (argument order in HookOutput init), 3 warnings (unused execute results) -- fixed by reordering arguments and adding `_ =` for discard
- All 6 tasks implemented in single pass following CompatMessageTypes pattern

### Completion Notes List

- Task 1: Created `Examples/CompatHooks/main.swift` with bilingual header, CompatEntry/record() pattern, env loading. Added `CompatHooks` executable target to Package.swift. Build passes with 0 errors, 0 warnings.
- Task 2: Verified all 18 TS HookEvents against Swift HookEvent.allCases (20 cases). 15 PASS, 3 MISSING (Setup, WorktreeCreate, WorktreeRemove). 5 Swift-only extras documented.
- Task 3: HookInput has 8 fields. Base fields: sessionId, cwd PASS; transcript_path, permission_mode, agent_id, agent_type MISSING. Tool fields: toolName, toolInput, toolOutput, toolUseId, error PASS; is_interrupt MISSING. Per-event fields: 8 MISSING (stop_hook_active, last_assistant_message, agent_transcript_path, trigger, custom_instructions, permission_suggestions, etc).
- Task 4: HookDefinition.matcher (regex), timeout (default 30000ms) both verified PASS. HookOutput fields: message, permissionUpdate, block, notification PASS. TS gaps: decision (PARTIAL), systemMessage MISSING, reason PARTIAL, updatedInput MISSING, additionalContext MISSING, updatedMCPToolOutput MISSING. PermissionBehavior missing 'ask'.
- Task 5: Live execution verified: PreToolUse block intercepts dangerous_tool, PostToolUse audit logs tool usage, execution order preserved (sequential registration), clear() empties registry, factory function works, config-based registration works with invalid event ignored.
- Task 6: Full compatibility report generated with 18-row event table, 18-row input field table, 7-row output field table, deduplicated field-level report with pass rate calculation.

### File List

- `Examples/CompatHooks/main.swift` -- NEW: Hook system compatibility verification example (~500 lines)
- `Package.swift` -- MODIFIED: Added CompatHooks executable target
- `Tests/OpenAgentSDKTests/Compat/HookSystemCompatTests.swift` -- EXISTING: 82 ATDD tests (created by test architect, all passing)

### Change Log

- 2026-04-15: Story 16-4 implementation complete. All 6 tasks done. CompatHooks example created. 3333 tests passing (14 skipped, 0 failures).
