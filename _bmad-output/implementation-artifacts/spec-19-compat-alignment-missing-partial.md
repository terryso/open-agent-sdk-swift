---
title: 'Align Swift SDK Compat: Resolve All MISSING & PARTIAL Items'
type: 'feature'
created: '2026-04-18'
status: 'done'
baseline_commit: 'ec45cda'
context:
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Types/HookTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SessionTypes.swift'
  - 'Sources/OpenAgentSDK/Stores/SessionStore.swift'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Swift SDK compat reports show 2 MISSING core query fields, 4 PARTIAL message types, 1 PARTIAL hook output field, 3 MISSING session metadata fields, untyped session messages, and 3 PARTIAL session functions. These gaps mean the Swift SDK is not fully aligned with the TypeScript SDK.

**Approach:** Add all missing fields and types to existing Swift structs, create new supporting types where needed (compact metadata, rate limit info, task notification data, session message), update SessionStore signatures with pagination/filter params, and update all compat tests from MISSING/PARTIAL to PASS.

## Boundaries & Constraints

**Always:** Maintain backward compatibility (all new fields optional with defaults). Follow existing naming conventions (camelCase). Update compat tests to expect PASS. Run full test suite after changes.

**Ask First:** None expected — all fields are directly mapped from TS SDK.

**Never:** Do not change existing public API signatures (additive only). Do not add mock-based tests. Do not modify CLAUDE.md.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| ResultData with errors | Error subtype result | errors: ["msg1", "msg2"] populated | nil for success subtype |
| ResultData with durationApiMs | Any query result | Separate API time vs wall-clock time | Defaults to 0 |
| CompactBoundary with metadata | compact_boundary system msg | compactMetadata with trigger/tokens/segment | nil fields for missing optional data |
| Status message with compact fields | status system msg | status, compactResult, compactError populated | status can be nil |
| TaskNotification with all fields | task_notification system msg | taskId, outputFile, summary, usage, etc. | usage is optional |
| RateLimitEvent with info | rate_limit_event msg | rateLimitInfo with status/resetsAt/utilization | All sub-fields optional |
| HookOutput decision | Hook returns decision | decision: .approve or .block | nil means approve (default) |
| Typed SessionMessage | Load session messages | Struct with uuid, sessionId, role, content, parentToolUseId | parentToolUseId is nil |
| SessionMetadata with new fields | Load session metadata | fileSize, firstPrompt, gitBranch available | All optional, nil when absent |
| listSessions with limit | list(limit: 5) | Returns at most 5 sessions | Returns all if limit is nil |
| getSessionMessages with pagination | load(sessionId:, offset: 10, limit: 20) | Returns messages 10..29 | Returns all if no pagination |

</frozen-after-approval>

## Code Map

- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- ResultData, SystemData, and all message types
- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- HookOutput struct
- `Sources/OpenAgentSDK/Types/SessionTypes.swift` -- SessionMetadata, SessionData
- `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- list(), load(), rename(), tag()
- `Tests/OpenAgentSDKTests/Compat/` -- All compat test files needing PASS updates

## Tasks & Acceptance

**Execution:**
- [x] `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- Add `errors: [String]?` and `durationApiMs: Int` to ResultData; add `CompactMetadata`, `RateLimitInfo`, `TaskNotificationInfo` structs; add fields to SystemData for compactBoundary/status/taskNotification/rateLimit subtypes -- Resolve 2 MISSING + 4 PARTIAL core query and message type items
- [x] `Sources/OpenAgentSDK/Types/HookTypes.swift` -- Add `HookDecision` enum and `decision: HookDecision?` to HookOutput -- Resolve 1 PARTIAL hook output item
- [x] `Sources/OpenAgentSDK/Types/SessionTypes.swift` -- Add `fileSize: Int?`, `firstPrompt: String?`, `gitBranch: String?` to SessionMetadata; add `SessionMessage` struct with uuid/sessionId/role/content/parentToolUseId -- Resolve 3 MISSING metadata + 3 MISSING + 2 PARTIAL message items
- [x] `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- Add `limit`, `includeWorktrees` params to list(); add `limit`, `offset` to load(); parse new metadata fields -- Resolve 3 PARTIAL session function items
- [x] `Tests/OpenAgentSDKTests/Compat/` -- Update all compat tests from MISSING/PARTIAL to PASS for the new fields -- Verify all compat items now report PASS
- [x] Run `swift test` -- All 4560 tests pass, 0 failures, 14 skipped

**Acceptance Criteria:**
- Given ResultData, when error subtype, then errors field is non-nil
- Given ResultData, when any query, then durationApiMs is separate from durationMs
- Given SystemData with compactBoundary subtype, then compactMetadata is populated
- Given SystemData with status subtype, then status/compactResult/compactError fields exist
- Given SystemData with taskNotification subtype, then taskId/outputFile/summary/usage exist
- Given SystemData with rateLimit subtype, then rateLimitInfo struct is populated
- Given HookOutput, when decision set, then .approve or .block accessible
- Given SessionMetadata, then fileSize/firstPrompt/gitBranch fields accessible
- Given SessionStore.list(limit: N), then returns at most N sessions
- Given `swift test`, then all tests pass with 0 MISSING in compat reports

## Spec Change Log

## Design Notes

**HookDecision approach:** Add `enum HookDecision: String { case approve, block }` and `decision: HookDecision?` to HookOutput. Keep existing `block: Bool` as a computed convenience property (`block = decision == .block`). Parse from JSON `"decision": "approve"|"block"`. Backward compatible since decision defaults to nil (treated as approve).

**SessionMessage typing:** Create `SessionMessage` struct to replace raw `[String: Any]` dicts in session data. Existing code that accesses messages as dictionaries can migrate incrementally — add a `rawDictionary: [String: Any]` computed property for backward compat during transition.

**SystemData partial subtypes:** Rather than creating separate structs for each system subtype (which would require changing the enum layout), add optional fields directly to SystemData that are nil for irrelevant subtypes. This mirrors the TS SDK's union type approach but stays idiomatic for Swift's single-struct pattern.

## Verification

**Commands:**
- `swift build` -- expected: builds with no errors
- `swift test` -- expected: all tests pass, compat reports show 0 MISSING
