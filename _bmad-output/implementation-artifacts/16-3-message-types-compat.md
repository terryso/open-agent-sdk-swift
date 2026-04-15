# Story 16.3: Message Types Compatibility Verification

Status: done

## Story

As an SDK developer,
I want to verify that Swift SDK's `SDKMessage` covers all 20 TypeScript SDK message subtypes with their fields,
so that consumer code handling the message stream can correctly process every event.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatMessageTypes/` directory and `CompatMessageTypes` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: SDKAssistantMessage verification** -- Verify `.assistant(AssistantData)` covers TS SDK `SDKAssistantMessage` fields: `uuid`, `session_id`, `message` (Anthropic Message object), `parent_tool_use_id`, `error` (supporting authentication_failed/billing_error/rate_limit/invalid_request/server_error/max_output_tokens/unknown). Record gaps.

3. **AC3: SDKResultMessage verification** -- Verify `.result(ResultData)` covers TS SDK success subtype fields (result, total_cost_usd, usage, model_usage, num_turns, duration_ms, structured_output, permission_denials) and error subtype fields (errors array, error_max_turns/error_during_execution/error_max_budget_usd/error_max_structured_output_retries). Record gaps.

4. **AC4: SDKSystemMessage verification** -- Verify `.system(SystemData)` covers all TS SDK subtypes: init (session_id, tools, model, permissionMode, mcp_servers, cwd), status (status, permissionMode), compact_boundary (compact_metadata), task_notification (task_id, status, output_file, summary, usage). Record gaps including missing subtypes: task_started, task_progress, hook_started, hook_progress, hook_response, files_persisted, local_command_output.

5. **AC5: SDKPartialAssistantMessage verification** -- Verify `.partialMessage(PartialData)` covers TS SDK `SDKPartialAssistantMessage` (type: "stream_event", with event stream event, parent_tool_use_id, uuid, session_id). Record gaps.

6. **AC6: Tool progress message verification** -- Verify whether `SDKToolProgressMessage` equivalent exists (tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds). If absent, record gap.

7. **AC7: Hook-related message verification** -- Verify whether `SDKHookStartedMessage`, `SDKHookProgressMessage`, `SDKHookResponseMessage` equivalents exist (hook_id, hook_name, hook_event, stdout/stderr/output, exit_code, outcome). If absent, record gaps.

8. **AC8: Task-related message verification** -- Verify whether `SDKTaskStartedMessage`, `SDKTaskProgressMessage`, `SDKTaskNotificationMessage` equivalents exist (task_id, task_type, description, usage). If absent, record gaps.

9. **AC9: Other message type verification** -- Verify equivalents for `SDKFilesPersistedEvent`, `SDKRateLimitEvent`, `SDKAuthStatusMessage`, `SDKPromptSuggestionMessage`, `SDKToolUseSummaryMessage`, `SDKLocalCommandOutputMessage`. If absent, record gaps.

10. **AC10: Complete compatibility report** -- For all 20 TS SDK message types, output per-type compatibility status with field-level comparison table.

## Tasks / Subtasks

- [ ] Task 1: Create example directory and scaffold (AC: #1)
  - [ ] Create `Examples/CompatMessageTypes/main.swift`
  - [ ] Add `CompatMessageTypes` executable target to `Package.swift`
  - [ ] Verify `swift build` passes with zero errors and zero warnings

- [ ] Task 2: Enumerate all SDKMessage cases statically (AC: #2-#5)
  - [ ] Create exhaustive `switch` on `SDKMessage` enum covering all 6 cases
  - [ ] For `.assistant`: inspect `AssistantData` fields (text, model, stopReason) vs TS (uuid, session_id, message, parent_tool_use_id, error)
  - [ ] For `.result`: inspect `ResultData` fields (subtype, text, usage, numTurns, durationMs, totalCostUsd, costBreakdown) vs TS (result, totalCostUsd, usage, modelUsage, numTurns, durationMs, structuredOutput, permissionDenials)
  - [ ] For `.system`: inspect `SystemData.Subtype` enum (init, compactBoundary, status, taskNotification, rateLimit) vs TS (init, compact_boundary, status, task_notification, task_started, task_progress, hook_started, hook_progress, hook_response, files_persisted, local_command_output)
  - [ ] For `.partialMessage`: inspect `PartialData` fields (text) vs TS (event, parent_tool_use_id, uuid, session_id)
  - [ ] Print field-level PASS/MISSING for each

- [ ] Task 3: Run live query and capture real messages (AC: #2-#4)
  - [ ] Execute a query with tool invocation (e.g., "List files in current directory using glob")
  - [ ] Capture `.system(.init)`, `.partialMessage`, `.assistant`, `.toolUse`, `.toolResult`, `.result` messages
  - [ ] Print actual field values for each captured message
  - [ ] Compare against TS SDK field names

- [ ] Task 4: Verify missing message types (AC: #6-#9)
  - [ ] Check for `SDKToolProgressMessage` equivalent (grep SDKMessage for tool_progress)
  - [ ] Check for Hook lifecycle messages (hook_started, hook_progress, hook_response)
  - [ ] Check for Task lifecycle messages (task_started, task_progress)
  - [ ] Check for AuthStatus, FilesPersisted, RateLimit fields, PromptSuggestion, ToolUseSummary, LocalCommandOutput
  - [ ] For each missing type, record required fields from TS SDK

- [ ] Task 5: Generate complete compatibility report (AC: #10)
  - [ ] Create 20-row comparison table (TS type -> Swift equivalent -> status)
  - [ ] Output PASS/MISSING/PARTIAL per row
  - [ ] Include summary counts: pass, missing, partial, N/A
  - [ ] Include recommended actions for MISSING items

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), third story
- **Prerequisites:** Story 16-1 (core query API compat) and 16-2 (tool system compat) are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report

### Critical API Mapping: TS SDK 20 Message Types vs Swift SDK

Based on analysis of `Sources/OpenAgentSDK/Types/SDKMessage.swift` (the canonical source):

| # | TS SDK Type | TS "type" field | Swift Equivalent | Swift Source | Gap |
|---|---|---|---|---|---|
| 1 | `SDKAssistantMessage` | "assistant" | `.assistant(AssistantData)` | SDKMessage.swift:100 | MISSING: uuid, session_id, parent_tool_use_id, error |
| 2 | `SDKUserMessage` | "user" | **NO EQUIVALENT** | N/A | MISSING: entire type |
| 3 | `SDKResultMessage` | "result" | `.result(ResultData)` | SDKMessage.swift:148 | MISSING: structuredOutput, permissionDenials, modelUsage; PARTIAL: has success + error subtypes |
| 4 | `SDKSystemMessage(init)` | "system"/"init" | `.system(SystemData)` subtype=.init | SDKMessage.swift:200 | MISSING: session_id, tools, model, permissionMode, mcp_servers, cwd |
| 5 | `SDKPartialAssistantMessage` | "stream_event" | `.partialMessage(PartialData)` | SDKMessage.swift:190 | MISSING: parent_tool_use_id, uuid, session_id |
| 6 | `SDKCompactBoundaryMessage` | "system"/"compact_boundary" | `.system(SystemData)` subtype=.compactBoundary | SDKMessage.swift:206 | MISSING: compact_metadata |
| 7 | `SDKStatusMessage` | "system"/"status" | `.system(SystemData)` subtype=.status | SDKMessage.swift:208 | MISSING: permissionMode |
| 8 | `SDKTaskNotificationMessage` | "system"/"task_notification" | `.system(SystemData)` subtype=.taskNotification | SDKMessage.swift:210 | MISSING: task_id, output_file, summary, usage |
| 9 | `SDKTaskStartedMessage` | "system"/"task_started" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 10 | `SDKTaskProgressMessage` | "system"/"task_progress" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 11 | `SDKToolProgressMessage` | "tool_progress" | **NO CASE** | N/A | MISSING: entire type |
| 12 | `SDKHookStartedMessage` | "system"/"hook_started" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 13 | `SDKHookProgressMessage` | "system"/"hook_progress" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 14 | `SDKHookResponseMessage` | "system"/"hook_response" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 15 | `SDKAuthStatusMessage` | "auth_status" | **NO CASE** | N/A | MISSING: entire type |
| 16 | `SDKFilesPersistedEvent` | "system"/"files_persisted" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 17 | `SDKRateLimitEvent` | "rate_limit_event" | `.system(.rateLimit)` | SDKMessage.swift:211 | MISSING: rate limit fields |
| 18 | `SDKLocalCommandOutputMessage` | "system"/"local_command_output" | **NO SUBTYPE** | N/A | MISSING: entire subtype |
| 19 | `SDKPromptSuggestionMessage` | "prompt_suggestion" | **NO CASE** | N/A | MISSING: entire type |
| 20 | `SDKToolUseSummaryMessage` | "tool_use_summary" | **NO CASE** | N/A | MISSING: entire type |

**Summary:** Swift SDK has 6 cases covering ~10 TS types partially. ~10 TS types have NO equivalent at all.

### Swift SDK `SDKMessage` Current Structure (canonical reference)

```swift
// Sources/OpenAgentSDK/Types/SDKMessage.swift
public enum SDKMessage: Sendable {
    case assistant(AssistantData)      // text, model, stopReason
    case toolUse(ToolUseData)          // toolName, toolUseId, input
    case toolResult(ToolResultData)    // toolUseId, content, isError
    case result(ResultData)            // subtype(6 cases), text, usage, numTurns, durationMs, totalCostUsd, costBreakdown
    case partialMessage(PartialData)   // text
    case system(SystemData)            // subtype(5 cases: init, compactBoundary, status, taskNotification, rateLimit), message
}
```

### Key Field-Level Gaps

**AssistantData** (vs TS SDKAssistantMessage):
- Has: text, model, stopReason
- Missing: uuid, session_id, parent_tool_use_id, error (with 7 error subtypes)

**ResultData** (vs TS SDKResultMessage):
- Has: subtype (success, errorMaxTurns, errorDuringExecution, errorMaxBudgetUsd, cancelled), text, usage, numTurns, durationMs, totalCostUsd, costBreakdown
- Missing: structuredOutput, permissionDenials, modelUsage (separate from costBreakdown), errorMaxStructuredOutputRetries (TS SDK error subtype for structured output retry exhaustion)
- Note: costBreakdown is similar to modelUsage but different naming

**SystemData** (vs TS SDKSystemMessage + subtypes):
- Has: subtype (5), message
- Missing for init: session_id, tools, model, permissionMode, mcp_servers, cwd
- Missing subtypes: task_started, task_progress, hook_started, hook_progress, hook_response, files_persisted, local_command_output

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Testing standards:** This is an example, not a test. Follow project example patterns.
- **Naming conventions:** PascalCase for types, camelCase for variables.

### Patterns to Follow (from Story 16-1 and 16-2)

- Use `loadDotEnv()` / `getEnv()` for API key loading (see `Examples/CompatCoreQuery/main.swift`)
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern from CompatCoreQuery for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Package.swift already has `CompatCoreQuery` and `CompatToolSystem` targets -- add `CompatMessageTypes` following the same pattern

### File Locations

```
Examples/CompatMessageTypes/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatMessageTypes executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- SDKMessage enum with all associated types
- `Sources/OpenAgentSDK/Core/Agent.swift` -- where SDKMessage events are yielded (lines 891-1534)
- `Examples/CompatCoreQuery/main.swift` -- Reference pattern for compat report generation
- `Examples/CompatToolSystem/main.swift` -- Reference pattern for tool-level verification

### Previous Story Intelligence (16-1 and 16-2)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Known gaps from 16-1: SystemData missing session_id/tools/model; errors/structuredOutput/permissionDenials/durationApiMs missing from ResultData
- Story 16-2 completion notes: full test suite was 3183 tests passing; `nonisolated(unsafe)` pattern for mutable globals
- Example pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `swift build --target CompatMessageTypes` for fast build verification

### Git Intelligence

Recent commits show Epic 16 work progressing. Story 16-2 just completed with tool system compat verification and BashInput.description fix. The `CompatEntry`/`record()` report pattern is established and should be reused.

### References

- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] -- SDKMessage enum, all associated data types
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:891-1534] -- SDKMessage yield sites
- [Source: _bmad-output/planning-artifacts/epics.md#Epic16] -- Story 16.3 definition with 20 TS message types
- [Source: _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md] -- Previous story patterns and learnings
- [Source: _bmad-output/implementation-artifacts/16-2-tool-system-compat.md] -- Previous story with established report pattern
- [Source: Examples/CompatCoreQuery/main.swift] -- CompatEntry/record() pattern reference
- [TS SDK Reference] SDKMessage union type, all 20 message subtypes with field definitions

## Dev Agent Record

### Agent Model Used

GLM-5.1 (via Claude Code)

### Debug Log References

- `swift build --target CompatMessageTypes` compiled with 0 errors, 0 warnings
- Full test suite: 3251 tests passed, 14 skipped, 0 failures
- All 68 ATDD tests in MessageTypesCompatTests.swift passed across 11 test classes

### Completion Notes List

- Created `Examples/CompatMessageTypes/main.swift` following patterns from 16-1 (CompatCoreQuery) and 16-2 (CompatToolSystem)
- Added `CompatMessageTypes` executable target to `Package.swift`
- Example covers all 20 TS SDK message types with field-level PASS/MISSING/PARTIAL verification
- Live streaming verification tests real SDKMessage instances against TS SDK field names
- Compatibility report: 8 PARTIAL (Swift has equivalent but missing fields), 12 MISSING (no Swift equivalent), 0 full PASS
- Key gaps documented: AssistantData missing uuid/session_id/parent_tool_use_id/error; PartialData has only text field; 12 TS types have no Swift equivalent at all

### Change Log

- 2026-04-15: Story 16-3 development completed. Created CompatMessageTypes example and updated Package.swift.

### File List

- NEW: `Examples/CompatMessageTypes/main.swift` -- Message types compatibility verification example
- MODIFIED: `Package.swift` -- Added `CompatMessageTypes` executable target
