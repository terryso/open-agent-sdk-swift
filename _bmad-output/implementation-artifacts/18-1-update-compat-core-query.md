# Story 18.1: Update CompatCoreQuery Example

Status: done

## Story

As an SDK developer,
I want to update `Examples/CompatCoreQuery/main.swift` and its companion tests to reflect the features added by Epic 17,
so that the compatibility report accurately shows the current Swift SDK vs TS SDK alignment.

## Acceptance Criteria

1. **AC1: SystemData fields PASS** -- SystemData.init fields `session_id`, `tools`, `model`, `permissionMode`, `mcpServers`, `cwd` are verified and marked `[PASS]` in both the example report and compat tests. These fields were added by Story 17-1.

2. **AC2: ResultData fields PASS** -- ResultData fields `structuredOutput`, `permissionDenials`, `modelUsage` are verified and marked `[PASS]` in both the example report and compat tests. The `errors: [String]` field remains `[MISSING]`. These fields were added by Story 17-1.

3. **AC3: AgentOptions fields PASS** -- AgentOptions fields `fallbackModel`, `effort`, `allowedTools`, `disallowedTools`, and the `streamInput()` method are verified and marked `[PASS]` where applicable. These were added by Stories 17-2 and 17-10.

4. **AC4: Compat test report updated** -- `CoreQueryCompatTests.swift` compatibility report test (`CompatReportTests`) updates MISSING entries to PASS for all fields closed by Epic 17. Only genuinely missing fields remain as MISSING.

5. **AC5: Build and tests pass** -- `swift build` zero errors zero warnings. All existing tests pass with zero regression.

## Tasks / Subtasks

- [x] Task 1: Update CompatCoreQuery example -- SystemData verification (AC: #1)
  - [x] Replace MISSING record for `session_id` with PASS assertion using `systemData.sessionId`
  - [x] Replace MISSING record for `tools` with PASS assertion using `systemData.tools`
  - [x] Replace MISSING record for `model` with PASS assertion using `systemData.model`
  - [x] Add new PASS records for `permissionMode` and `mcpServers` and `cwd` on SystemData

- [x] Task 2: Update CompatCoreQuery example -- ResultData verification (AC: #2)
  - [x] Replace MISSING record for `structuredOutput` with PASS assertion using `streamedResultData.structuredOutput`
  - [x] Replace MISSING record for `permissionDenials` with PASS assertion using `streamedResultData.permissionDenials`
  - [x] Add new PASS record for `modelUsage` using `streamedResultData.modelUsage`
  - [x] Keep `errors: [String]` as MISSING (genuinely not implemented)
  - [x] Keep `durationApiMs` as MISSING (genuinely not implemented)

- [x] Task 3: Update CompatCoreQuery example -- AgentOptions / streamInput (AC: #3)
  - [x] Replace MISSING record for `AsyncIterable input` with PASS for `agent.streamInput()`
  - [x] Optionally verify `AgentOptions.fallbackModel` and `AgentOptions.effort` fields exist

- [x] Task 4: Update CoreQueryCompatTests.swift (AC: #4)
  - [x] Update `CompatReportTests.testCompatReport_fieldMapping`: change `session_id`, `tools`, `model (on SystemData)`, `structuredOutput`, `permissionDenials` from MISSING to PASS
  - [x] Add PASS entries for `permissionMode` (SystemData), `mcpServers` (SystemData), `cwd` (SystemData), `modelUsage` (ResultData), `streamInput` (Agent)
  - [x] Remove `ErrorResultCompatTests.testErrorResult_errorsField_gap` Mirror introspection test or update it to still confirm `errors` is missing
  - [x] Update pass count assertion to reflect new PASS entries (should be >= 20 now)

- [x] Task 5: Build and test verification (AC: #5)
  - [x] `swift build` zero errors zero warnings
  - [x] Run full test suite, report total count

## Dev Notes

### Position in Epic and Project

- **Epic 18** (Example & Official SDK Full Alignment), first story
- **Prerequisites:** Epic 17 fully complete (all 11 stories done)
- **This is a pure update story** -- no new production code, only updating existing example and compat tests
- **FR mapping:** Verification only (FR1-FR4 coverage validation)
- **Pattern:** Same as Epic 16 compat examples, but updating rather than creating

### CRITICAL: Pre-existing Implementation (Do NOT reinvent)

The following features were **already implemented** by Epic 17 stories. Do NOT recreate them:

1. **SystemData fields** (Story 17-1) -- `sessionId: String?`, `tools: [ToolInfo]?`, `model: String?`, `permissionMode: String?`, `mcpServers: [McpServerInfo]?`, `cwd: String?` all exist on `SDKMessage.SystemData` in `Sources/OpenAgentSDK/Types/SDKMessage.swift:329-396`.

2. **ResultData fields** (Story 17-1) -- `structuredOutput: SendableStructuredOutput?`, `permissionDenials: [SDKPermissionDenial]?`, `modelUsage: [ModelUsageEntry]?` all exist on `SDKMessage.ResultData` in `Sources/OpenAgentSDK/Types/SDKMessage.swift:224-300`.

3. **streamInput()** (Story 17-10) -- `Agent.streamInput(_ input: AsyncStream<String>)` exists in `Sources/OpenAgentSDK/Core/Agent.swift:335`.

4. **AgentOptions fields** (Story 17-2) -- `fallbackModel: String?`, `effort: EffortLevel?`, `allowedTools: [String]?`, `disallowedTools: [String]?` all exist on `AgentOptions`.

5. **Supporting types** (Story 17-1) -- `SendableStructuredOutput`, `SDKPermissionDenial`, `ModelUsageEntry`, `ToolInfo`, `McpServerInfo` all exist in `SDKMessage.swift`.

### What IS Actually New for This Story

1. **Updating CompatCoreQuery example** -- change MISSING entries to PASS where Epic 17 filled the gaps
2. **Updating CoreQueryCompatTests** -- update the compat report test to reflect new PASS entries
3. **Verifying build still passes** after updates

### Current State Analysis -- Gap Mapping

The CompatCoreQuery example currently reports these MISSING entries (from `main.swift` and `CoreQueryCompatTests.swift`):

| TS SDK Field | Current Status | Epic 17 Resolution | New Status |
|---|---|---|---|
| `session_id` (SystemData) | MISSING | Story 17-1 added `sessionId` | **PASS** |
| `tools` (SystemData) | MISSING | Story 17-1 added `tools` | **PASS** |
| `model` (SystemData) | MISSING | Story 17-1 added `model` | **PASS** |
| `permissionMode` (SystemData) | Not tested | Story 17-1 added `permissionMode` | **PASS** (new) |
| `mcpServers` (SystemData) | Not tested | Story 17-1 added `mcpServers` | **PASS** (new) |
| `cwd` (SystemData) | Not tested | Story 17-1 added `cwd` | **PASS** (new) |
| `structuredOutput` (ResultData) | MISSING | Story 17-1 added `structuredOutput` | **PASS** |
| `permissionDenials` (ResultData) | MISSING | Story 17-1 added `permissionDenials` | **PASS** |
| `modelUsage` (ResultData) | Not tested | Story 17-1 added `modelUsage` | **PASS** (new) |
| `errors` (ResultData) | MISSING | Not implemented | **MISSING** |
| `durationApiMs` | MISSING | Not implemented (merged into `durationMs`) | **MISSING** |
| `AsyncIterable input` | MISSING | Story 17-10 added `streamInput()` | **PASS** |

### Key Implementation Details

**SystemData.init is populated by Agent at session start.** When `Agent.stream()` or `Agent.prompt()` begins, it emits a `.system(.init)` message. The Agent populates the new SystemData fields in the init event. Verify this by checking the actual values received in the stream:

```swift
if let systemData = streamedSystemData, systemData.subtype == .`init` {
    // Verify new fields
    let hasSessionId = systemData.sessionId != nil
    record("session_id", swiftField: "SystemData.sessionId", status: hasSessionId ? "PASS" : "MISSING")
    // ... similarly for tools, model, permissionMode, mcpServers, cwd
}
```

**ResultData fields are populated when the agent loop completes.** The `.result` message in a stream carries all ResultData fields. For `structuredOutput` and `permissionDenials`, these are nil unless the query specifically triggers them (e.g., structured output requires output format config, permission denials require non-bypass mode). The example should check that the field EXISTS (type-level check) rather than requiring a non-nil value:

```swift
// Type-level verification: field exists and is accessible
let hasStructuredOutputField = true // ResultData.structuredOutput compiles = field exists
record("structuredOutput", swiftField: "ResultData.structuredOutput (SendableStructuredOutput?)", status: "PASS")
```

**QueryResult (blocking) does NOT have structuredOutput/permissionDenials/modelUsage.** These fields only exist on `ResultData` (streaming). The blocking `QueryResult` struct in `AgentTypes.swift:636-667` has its own fixed field set. Do NOT attempt to verify these fields on `QueryResult`.

### Architecture Compliance

- **No new files needed** -- only modifying existing example and test files
- **No Package.swift changes needed**
- **Module boundaries:** Example imports only `OpenAgentSDK`; tests import `@testable import OpenAgentSDK`
- **No production code changes** -- purely updating verification/example code
- **File naming:** No new files

### File Locations

```
Examples/CompatCoreQuery/main.swift                        # MODIFY -- update MISSING entries to PASS
Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift   # MODIFY -- update compat report test
_bmad-output/implementation-artifacts/sprint-status.yaml    # MODIFY -- status update
_bmad-output/implementation-artifacts/18-1-update-compat-core-query.md  # MODIFY -- tasks marked complete
```

### Source Files to Reference (Read-Only)

- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- SystemData (lines 329-396), ResultData (lines 224-300), supporting types
- `Sources/OpenAgentSDK/Core/Agent.swift` -- streamInput() (line 335), stream(), prompt()
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- QueryResult (lines 636-667), AgentOptions

### Previous Story Intelligence

**From Story 17-11 (Thinking Model Enhancement):**
- 4226 tests passing, 0 failures, 14 skipped (pre-existing)
- Pattern: change MISSING to PASS in compat examples and compat tests
- Updated compat test files need both example AND unit test updates
- `swift build` zero errors zero warnings

**From Story 17-1 (SDKMessage Type Enhancement):**
- Added 12 new message types to SDKMessage enum
- Added SystemData optional fields: sessionId, tools, model, permissionMode, mcpServers, cwd
- Added ResultData optional fields: structuredOutput, permissionDenials, modelUsage
- Added supporting types: SendableStructuredOutput, SDKPermissionDenial, ModelUsageEntry, ToolInfo, McpServerInfo

**From Story 17-10 (Query Methods Enhancement):**
- Added `streamInput()` method to Agent
- Added 9 query control methods including rewindFiles, stopTask, close

**From Story 17-2 (Agent Options Enhancement):**
- Added AgentOptions fields: fallbackModel, effort, allowedTools, disallowedTools

### Anti-Patterns to Avoid

- Do NOT add `structuredOutput`/`permissionDenials`/`modelUsage` to `QueryResult` -- they only belong on `ResultData`
- Do NOT recreate SystemData fields or ResultData fields -- they already exist
- Do NOT create mock-based E2E tests -- per CLAUDE.md
- Do NOT change production source code -- this is an update-only story
- Do NOT use force-unwrap (`!`) on optional fields from SystemData/ResultData -- use `if let` or nil-coalescing
- Do NOT require runtime non-nil values for fields that may legitimately be nil (e.g., `structuredOutput` is nil unless configured)
- Do NOT remove the `errors: [String]` MISSING entry -- it genuinely does not exist yet
- Do NOT remove the `durationApiMs` MISSING entry -- it genuinely does not exist yet

### Implementation Strategy

1. **Update CompatCoreQuery example first** -- modify `main.swift` to change MISSING to PASS
2. **Update CoreQueryCompatTests** -- update `CompatReportTests` to reflect new PASS entries
3. **Verify Mirror introspection test** -- ensure `testErrorResult_errorsField_gap` still correctly confirms `errors` is missing
4. **Build and verify** -- `swift build` + full test suite

### Testing Requirements

- **Existing tests must pass:** 4226+ tests (as of 17-11), zero regression
- **Compat test updates:** Change MISSING assertions to PASS for resolved fields
- **Pass count must increase:** The compat report test has `passCount >= 12` assertion -- update to reflect new pass count (should be >= 20)
- After implementation, run full test suite and report total count

### Project Structure Notes

- No new files needed
- No Package.swift changes needed
- CompatCoreQuery update in Examples/
- CoreQueryCompatTests update in Tests/OpenAgentSDKTests/Compat/

### References

- [Source: Examples/CompatCoreQuery/main.swift] -- Primary modification target
- [Source: Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift] -- Compat test to update
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] -- SystemData, ResultData, supporting types (read-only)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] -- streamInput(), stream(), prompt() (read-only)
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- QueryResult, AgentOptions (read-only)
- [Source: _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md] -- Original gap analysis
- [Source: _bmad-output/implementation-artifacts/17-1-sdkmessage-type-enhancement.md] -- Story 17-1 context
- [Source: _bmad-output/implementation-artifacts/17-2-agent-options-enhancement.md] -- Story 17-2 context
- [Source: _bmad-output/implementation-artifacts/17-10-query-methods-enhancement.md] -- Story 17-10 context
- [Source: _bmad-output/implementation-artifacts/17-11-thinking-model-enhancement.md] -- Previous story patterns
- [Source: _bmad-output/planning-artifacts/epics.md#Story18.1] -- Story 18.1 definition

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.1)

### Debug Log References

### Completion Notes List

- Updated CompatCoreQuery/main.swift: Replaced 3 MISSING SystemData entries (session_id, tools, model) with PASS assertions. Added 3 new PASS entries for permissionMode, mcpServers, cwd. Replaced 2 MISSING ResultData entries (structuredOutput, permissionDenials) with PASS. Added new PASS entries for modelUsage and streamInput. Kept errors and durationApiMs as MISSING.
- Updated CoreQueryCompatTests.swift: Updated CompatReportTests.testCompatReport_fieldMapping with 10 new PASS entries (session_id, tools, model, permissionMode, mcpServers, cwd, structuredOutput, permissionDenials, modelUsage, AsyncIterable input). Updated pass count assertion from >=12 to >=20. Kept errors and durationApiMs as MISSING. Updated file header comment.
- Updated Story18_1_ATDDTests.swift: Updated buildCurrentCompatReport() helper to reflect new PASS entries, making the RED-phase ATDD tests now pass.
- Build: swift build zero errors zero warnings.
- Tests: all 4252 tests passing, 14 skipped, 0 failures.

### File List

- Examples/CompatCoreQuery/main.swift (modified)
- Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift (modified)
- Tests/OpenAgentSDKTests/Compat/Story18_1_ATDDTests.swift (modified)

### Change Log

- 2026-04-18: Story 18-1 implementation complete. Updated compat report entries from MISSING to PASS for all Epic 17 fields. All 4252 tests passing.
