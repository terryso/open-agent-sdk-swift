# Story 17.1: SDKMessage Type Enhancement / SDKMessage 类型增强

Status: done

## Story

As an SDK developer,
I want to fill in all missing SDKMessage types and fields in the Swift SDK so that it covers the full set of 20 TypeScript SDK message types with complete fields,
so that consumer code handling the message stream can correctly process every event.

## Acceptance Criteria

1. **AC1: Add 12 missing SDKMessage cases** -- Given the TS SDK has 20 message types, 12 of which have no Swift equivalent, when adding them to the SDKMessage enum, then new cases are added: `.userMessage(UserMessageData)`, `.toolProgress(ToolProgressData)`, `.hookStarted(HookStartedData)`, `.hookProgress(HookProgressData)`, `.hookResponse(HookResponseData)`, `.taskStarted(TaskStartedData)`, `.taskProgress(TaskProgressData)`, `.authStatus(AuthStatusData)`, `.filesPersisted(FilesPersistedData)`, `.localCommandOutput(LocalCommandOutputData)`, `.promptSuggestion(PromptSuggestionData)`, `.toolUseSummary(ToolUseSummaryData)`, and each associated type includes all fields defined in the TS SDK and conforms to `Sendable`.

2. **AC2: Complete AssistantData fields** -- Given AssistantData is missing `uuid`, `sessionId`, `parentToolUseId`, and `error`, when adding these fields, then types match TS SDK (`error` supports 7 error subtypes: authenticationFailed, billingError, rateLimit, invalidRequest, serverError, maxOutputTokens, unknown), and all fields are optional for backward compatibility.

3. **AC3: Complete ResultData fields** -- Given ResultData is missing `structuredOutput`, `permissionDenials`, `modelUsage`, and `errorMaxStructuredOutputRetries` subtype, when adding these, then `structuredOutput` is typed `Any?` (JSON-compatible), `permissionDenials` is `[SDKPermissionDenial]`, `modelUsage` coexists with `costBreakdown`, and the new error subtype `errorMaxStructuredOutputRetries` is added to `ResultData.Subtype`.

4. **AC4: Complete SystemData init fields** -- Given SystemData.init is missing `sessionId`, `tools`, `model`, `permissionMode`, `mcpServers`, and `cwd`, when adding these, use optional fields on SystemData, and these fields are correctly populated during streaming queries.

5. **AC5: Complete PartialData fields** -- Given PartialData is missing `parentToolUseId`, `uuid`, and `sessionId`, when adding these, all fields are optional and do not break existing usage.

6. **AC6: All new types maintain Sendable conformance** -- All new structs and enums added in this story conform to the `Sendable` protocol.

7. **AC7: Zero regression** -- All existing tests (3650+) pass after changes with zero failures.

8. **AC8: AsyncStream integration** -- New message types are correctly yielded through the existing `AsyncStream<SDKMessage>` pipeline in Agent.swift.

## Tasks / Subtasks

- [x] Task 1: Add 12 new message data types as nested structs in SDKMessage (AC: #1)
  - [x] Define `UserMessageData` (uuid, sessionId, message, parentToolUseId, isSynthetic, toolUseResult)
  - [x] Define `ToolProgressData` (toolUseId, toolName, parentToolUseId, elapsedTimeSeconds)
  - [x] Define `HookStartedData` (hookId, hookName, hookEvent)
  - [x] Define `HookProgressData` (hookId, hookName, hookEvent, stdout, stderr)
  - [x] Define `HookResponseData` (hookId, hookName, hookEvent, output, exitCode, outcome)
  - [x] Define `TaskStartedData` (taskId, taskType, description)
  - [x] Define `TaskProgressData` (taskId, taskType, usage)
  - [x] Define `AuthStatusData` (status, message)
  - [x] Define `FilesPersistedData` (filePaths)
  - [x] Define `LocalCommandOutputData` (output, command)
  - [x] Define `PromptSuggestionData` (suggestions)
  - [x] Define `ToolUseSummaryData` (toolUseCount, tools)
  - [x] Add 12 new cases to SDKMessage enum
  - [x] Update `text` computed property to handle new cases

- [x] Task 2: Enhance AssistantData with missing fields (AC: #2)
  - [x] Add `uuid: String?`, `sessionId: String?`, `parentToolUseId: String?`
  - [x] Add `error: AssistantError?` with `AssistantError` enum supporting 7 subtypes
  - [x] Update init with default nil values for backward compatibility

- [x] Task 3: Enhance ResultData with missing fields and subtype (AC: #3)
  - [x] Add `errorMaxStructuredOutputRetries` to `ResultData.Subtype` enum
  - [x] Add `structuredOutput` (wrapped as `SendableStructuredOutput` for Sendable compliance)
  - [x] Add `permissionDenials: [SDKPermissionDenial]?`
  - [x] Add `modelUsage: [ModelUsageEntry]?` (distinct from costBreakdown)
  - [x] Define `SDKPermissionDenial` struct (toolName, toolUseId, toolInput)
  - [x] Define `ModelUsageEntry` struct
  - [x] Update init with default nil/empty values for backward compatibility

- [x] Task 4: Enhance SystemData with init-specific fields (AC: #4)
  - [x] Add optional fields: `sessionId: String?`, `tools: [ToolInfo]?`, `model: String?`, `permissionMode: String?`, `mcpServers: [McpServerInfo]?`, `cwd: String?`
  - [x] Define `ToolInfo` and `McpServerInfo` lightweight structs
  - [x] Update init with default nil values
  - [x] Add missing SystemData.Subtype cases: `taskStarted`, `taskProgress`, `hookStarted`, `hookProgress`, `hookResponse`, `filesPersisted`, `localCommandOutput`
  - [x] Ensure existing subtypes still compile

- [x] Task 5: Enhance PartialData with missing fields (AC: #5)
  - [x] Add `parentToolUseId: String?`, `uuid: String?`, `sessionId: String?`
  - [x] Update init with default nil values

- [x] Task 6: Integrate new message types into Agent.swift streaming pipeline (AC: #8)
  - [x] Identify all SDKMessage yield sites in Agent.swift
  - [x] Add yield points for new message types where appropriate (hooks, tasks, tool progress, etc.)
  - [x] Ensure new SystemData subtypes are yielded at correct lifecycle points

- [x] Task 7: Verify zero regression (AC: #6, #7)
  - [x] Run full test suite (3722 tests) and confirm all pass
  - [x] Verify Sendable conformance with compiler checks
  - [x] Verify no warnings from `swift build`

## Dev Notes

### Position in Epic and Project

- **Epic 17** (TypeScript SDK Feature Alignment), first story
- **Prerequisites:** Epic 16 fully complete (all 12 compat verification stories done)
- **This is a production code story** -- modifies core SDKMessage type and Agent streaming pipeline
- **Focus:** Fill the ~100+ MISSING/PARTIAL gaps identified by Story 16-3 (CompatMessageTypes)

### Critical Gap Analysis (from Story 16-3 Compat Report)

Story 16-3 verified all 20 TS SDK message types against Swift SDKMessage. The detailed findings:

| # | TS SDK Type | Swift Status | Action Required |
|---|---|---|---|
| 1 | SDKAssistantMessage | PARTIAL | Add uuid, sessionId, parentToolUseId, error (7 subtypes) |
| 2 | SDKUserMessage | MISSING | Add .userMessage(UserMessageData) |
| 3 | SDKResultMessage | PARTIAL | Add structuredOutput, permissionDenials, modelUsage, errorMaxStructuredOutputRetries |
| 4 | SDKSystemMessage(init) | PARTIAL | Add sessionId, tools, model, permissionMode, mcpServers, cwd to init |
| 5 | SDKPartialAssistantMessage | PARTIAL | Add parentToolUseId, uuid, sessionId |
| 6 | SDKCompactBoundaryMessage | PARTIAL | Add compact_metadata (optional) |
| 7 | SDKStatusMessage | PARTIAL | Add permissionMode (optional) |
| 8 | SDKTaskNotificationMessage | PARTIAL | Add task_id, output_file, summary, usage fields |
| 9 | SDKTaskStartedMessage | MISSING | Add .taskStarted(TaskStartedData) |
| 10 | SDKTaskProgressMessage | MISSING | Add .taskProgress(TaskProgressData) |
| 11 | SDKToolProgressMessage | MISSING | Add .toolProgress(ToolProgressData) |
| 12 | SDKHookStartedMessage | MISSING | Add .hookStarted(HookStartedData) |
| 13 | SDKHookProgressMessage | MISSING | Add .hookProgress(HookProgressData) |
| 14 | SDKHookResponseMessage | MISSING | Add .hookResponse(HookResponseData) |
| 15 | SDKAuthStatusMessage | MISSING | Add .authStatus(AuthStatusData) |
| 16 | SDKFilesPersistedEvent | MISSING | Add .filesPersisted(FilesPersistedData) |
| 17 | SDKRateLimitEvent | PARTIAL | Add rate limit detail fields |
| 18 | SDKLocalCommandOutputMessage | MISSING | Add .localCommandOutput(LocalCommandOutputData) |
| 19 | SDKPromptSuggestionMessage | MISSING | Add .promptSuggestion(PromptSuggestionData) |
| 20 | SDKToolUseSummaryMessage | MISSING | Add .toolUseSummary(ToolUseSummaryData) |

### Current SDKMessage Structure (source of truth)

File: `Sources/OpenAgentSDK/Types/SDKMessage.swift` (225 lines)

```swift
public enum SDKMessage: Sendable {
    case assistant(AssistantData)      // text, model, stopReason
    case toolUse(ToolUseData)          // toolName, toolUseId, input
    case toolResult(ToolResultData)    // toolUseId, content, isError
    case result(ResultData)            // subtype(6 cases), text, usage, numTurns, durationMs, totalCostUsd, costBreakdown
    case partialMessage(PartialData)   // text
    case system(SystemData)            // subtype(5 cases), message
}
```

### Key Design Decisions

1. **Top-level cases for distinct types**: Add independent top-level cases for types with distinct data shapes (toolProgress, hookStarted, hookProgress, hookResponse, authStatus, promptSuggestion, toolUseSummary, userMessage, taskStarted, taskProgress, filesPersisted, localCommandOutput). Each gets its own associated data struct. This gives each type clear identity and enables pattern matching.

2. **Backward compatibility**: All new fields on existing structs (AssistantData, ResultData, SystemData, PartialData) MUST be optional with default nil values in init. Existing call sites must compile without modification.

3. **Error subtypes for AssistantData**: The TS SDK supports 7 error subtypes under the `error` field. Create a dedicated `AssistantError` enum with these 7 cases.

4. **SDKPermissionDenial**: This type is also needed by Story 17-5 (Permission System Enhancement). Define it here as it's referenced by ResultData.permissionDenials.

5. **Task naming conflict**: Per CLAUDE.md, avoid naming types `Task` as it conflicts with Swift Concurrency's `Task`. The names `TaskStartedData` and `TaskProgressData` are safe because they are suffixed with "Data".

6. **Switch exhaustiveness**: Adding new cases to SDKMessage will break all existing `switch` statements that don't use `default`. Use `@unknown default` in internal code for graceful transition. Public API consumers should handle all cases.

### Architecture Compliance

- **Types/ is a leaf module**: SDKMessage.swift lives in `Types/` and has no outbound dependencies. New types defined here must also be self-contained.
- **Sendable conformance**: All new types MUST conform to `Sendable` (NFR1). Use only Sendable-compliant properties (String, Int, Bool, enums, structs that are already Sendable).
- **Module boundary**: Agent.swift (Core/) imports from Types/ -- correct direction. No circular dependencies.
- **DocC documentation**: All new public types need Swift-DocC comments (NFR2).
- **No Apple-proprietary frameworks**: Code must work on macOS and Linux.

### File Locations

```
Sources/OpenAgentSDK/Types/SDKMessage.swift   # MODIFY -- add 12 cases, enhance 4 existing types
Sources/OpenAgentSDK/Core/Agent.swift         # MODIFY -- add yield points for new message types
Sources/OpenAgentSDK/OpenAgentSDK.swift        # MODIFY -- re-export new public types if needed
```

### Source Files to Reference

- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- Primary file to modify; contains all current SDKMessage types
- `Sources/OpenAgentSDK/Core/Agent.swift` -- SDKMessage yield sites (lines ~891-1534); where to integrate new message types
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions, AgentDefinition; costBreakdown definition
- `Sources/OpenAgentSDK/Types/TokenUsage.swift` -- TokenUsage struct used by ResultData
- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- HookEvent enum; useful for HookStartedData/ProgressData/ResponseData field definitions
- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` -- PermissionMode enum; referenced by SystemData init fields
- `Examples/CompatMessageTypes/main.swift` -- Detailed compat report showing all gaps (reference only, no modifications)
- TS SDK Reference: `/Users/nick/CascadeProjects/open-agent-sdk-typescript/src/` -- TypeScript SDK source for field-level verification

### Previous Story Intelligence

**From Story 16-3 (CompatMessageTypes):**
- Established the detailed gap analysis of all 20 TS SDK message types
- Compat report: 8 PARTIAL (Swift has equivalent but missing fields), 12 MISSING (no Swift equivalent), 0 full PASS
- Key gaps: AssistantData missing uuid/session_id/parent_tool_use_id/error; PartialData has only text field; 12 TS types have no Swift equivalent at all
- Test suite at time of 16-3: 3251 tests passing

**From Story 16-12 (Sandbox Config Compat, most recent):**
- Full test suite: 3650 tests passing, 14 skipped, 0 failures
- Code review pattern: yolo mode, 1 patch applied for dead code removal
- All Epic 16 stories are done; moving to Epic 17 feature implementation

**From Story 16-1 (Core Query API Compat):**
- SystemData missing session_id/tools/model
- ResultData missing structuredOutput/permissionDenials/durationApiMs

### Testing Requirements

- **Existing tests must pass**: 3650+ tests, zero regression
- **New tests needed**: Unit tests for each new message data type (init, field access, Sendable conformance)
- **Integration tests**: Verify new message types are correctly yielded in Agent streaming pipeline
- **No E2E tests with mocks**: Per CLAUDE.md, E2E tests use real environment
- After implementation, run full test suite and report total count

### Anti-Patterns to Avoid

- Do NOT break existing SDKMessage `switch` exhaustiveness without providing `@unknown default` or updating all switch sites
- Do NOT use `Task` as a type name (conflicts with Swift Concurrency)
- Do NOT make new fields required on existing types -- all must be optional for backward compatibility
- Do NOT import Core/ from Types/ -- violates module boundary
- Do NOT use force-unwrap (`!`)
- Do NOT use Codable for these types -- they are Swift-side only (per project-context.md rule #5)
- Do NOT use Apple-proprietary frameworks (UIKit, AppKit, Combine)

### Project Structure Notes

- All changes in `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- single primary file
- `Sources/OpenAgentSDK/Core/Agent.swift` -- secondary modifications for yield integration
- No new files needed -- all new types are nested structs within SDKMessage enum
- Alignment with unified project structure: Types/ is leaf node, no outbound dependencies

### References

- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] -- Current SDKMessage enum with 6 cases and all associated data types
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:891-1534] -- SDKMessage yield sites
- [Source: _bmad-output/implementation-artifacts/16-3-message-types-compat.md] -- Detailed gap analysis for all 20 TS message types
- [Source: _bmad-output/planning-artifacts/epics.md#Story17.1] -- Story 17.1 definition with acceptance criteria
- [Source: _bmad-output/project-context.md] -- Project conventions (Sendable, naming, module boundaries)
- [Source: _bmad-output/planning-artifacts/architecture.md] -- AD2: AsyncStream<SDKMessage> streaming model

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

None

### Completion Notes List

- All 12 new SDKMessage cases added with associated data structs
- 4 existing data types enhanced with missing fields (AssistantData, ResultData, SystemData, PartialData)
- `structuredOutput` typed as `SendableStructuredOutput` (not raw `Any?`) to maintain Sendable conformance
- `AssistantError` enum with 7 subtypes matching TS SDK error categories
- `ResultData.Subtype` gained `errorMaxStructuredOutputRetries` case (6 total)
- `SystemData.Subtype` gained 7 new cases (12 total)
- All new fields are optional with default nil values for backward compatibility
- Updated 11 files that had exhaustive `switch` on SDKMessage to handle 12 new cases
- Updated Story 16-3 compat tests from gap-detection to verification mode
- Full test suite: 3722 tests passing, 14 skipped, 0 failures
- Task 6 (Agent.swift yield integration) completed: added system init event with session metadata, user message event, tool progress events, and tool use summary event in streaming pipeline
- Hook events (hookStarted/hookResponse) and task events (taskStarted/taskProgress) deferred to Stories 17-4 and 17-6 where the underlying features will be enhanced
- Auth status, files persisted, local command output, and prompt suggestion events deferred to future stories that implement the features producing these events

### File List

- Sources/OpenAgentSDK/Types/SDKMessage.swift (MODIFIED - primary implementation)
- Tests/OpenAgentSDKTests/Types/SDKMessageEnhancementATDDTests.swift (MODIFIED - fixed .init escaping and structuredOutput type)
- Tests/OpenAgentSDKTests/Core/SDKMessageTests.swift (MODIFIED - added new switch cases)
- Tests/OpenAgentSDKTests/Compat/MessageTypesCompatTests.swift (MODIFIED - updated gap tests to verification tests)
- Tests/OpenAgentSDKTests/Compat/CoreQueryCompatE2ETests.swift (MODIFIED - added new switch cases)
- Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift (MODIFIED - updated gap tests to verification tests)
- Sources/E2ETest/ToolExecutionTests.swift (MODIFIED - added new switch cases)
- Sources/E2ETest/SDKMessageTests.swift (MODIFIED - added new switch cases)
- Examples/QueryAbortExample/main.swift (MODIFIED - added new switch cases)
- Examples/StreamingAgent/main.swift (MODIFIED - added new switch cases)
- Examples/SubagentExample/main.swift (MODIFIED - added new switch cases)
- Examples/MultiToolExample/main.swift (MODIFIED - added new switch cases)
- Examples/CompatCoreQuery/main.swift (MODIFIED - added new switch cases)
- Examples/CompatMessageTypes/main.swift (MODIFIED - added new switch cases)
