# Story 17.7: Session Management Enhancement

Status: done

## Story

As an SDK developer,
I want to wire the 4 deferred AgentOptions session fields (`continueRecentSession`, `forkSession`, `resumeSessionAt`, `persistSession`) into the Agent runtime,
so that developers can fully control session lifecycle (continue, fork, resume-at, and ephemeral sessions) in Swift.

## Acceptance Criteria

1. **AC1: continueRecentSession wiring** -- When `AgentOptions.continueRecentSession` is `true` and `sessionStore` is set (but `sessionId` is nil or empty), the Agent resolves the most recent session from `SessionStore.list()`, sets the resolved ID as the active session, and restores its history. If no sessions exist, proceed as a new session (no error).

2. **AC2: forkSession wiring** -- When `AgentOptions.forkSession` is `true` and `sessionStore` + `sessionId` are configured, the Agent calls `SessionStore.fork(sourceSessionId:)` to create a copy with a new auto-generated ID before restoring history. The original session remains untouched. The forked session ID becomes the active session for subsequent save operations.

3. **AC3: resumeSessionAt wiring** -- When `AgentOptions.resumeSessionAt` is set to a message UUID and `sessionStore` + `sessionId` are configured, the Agent loads the session, finds the message with matching UUID (in the raw dict, checking `["uuid"]` or `["id"]` keys), and truncates history to that point before appending the new user message. If the UUID is not found, fall back to loading the full history (no error, match TS SDK behavior of "resume from most recent").

4. **AC4: persistSession wiring** -- Already partially wired in Story 17-2 (save paths in Agent.swift already check `options.persistSession`). Verify both `prompt()` and `stream()` code paths gate session save on `persistSession == true`. Ensure the default `true` preserves existing behavior.

5. **AC5: Build and test** -- `swift build` zero errors zero warnings, 4034+ existing tests pass with zero regression.

## Tasks / Subtasks

- [x] Task 1: Wire continueRecentSession in Agent.swift (AC: #1)
  - [x] In `promptImpl()`, before session restore block (~line 358): if `options.continueRecentSession && options.sessionStore != nil && (options.sessionId == nil || options.sessionId!.isEmpty)`, call `sessionStore.list()`, take first result (most recent), set `sessionId` to that ID
  - [x] In `stream()` closure, same logic in the session restore section (~line 921)
  - [x] Handle empty list gracefully: if `list()` returns empty, proceed with new session
  - [x] Add DocC comment documenting the behavior

- [x] Task 2: Wire forkSession in Agent.swift (AC: #2)
  - [x] In `promptImpl()`, after `continueRecentSession` resolution but before session restore: if `options.forkSession && options.sessionStore != nil && options.sessionId != nil`, call `sessionStore.fork(sourceSessionId: sessionId)`, get new ID, set active session ID to forked ID
  - [x] In `stream()` closure, same logic
  - [x] Handle fork returning nil (source doesn't exist): proceed as new session
  - [x] Add DocC comment documenting the behavior

- [x] Task 3: Wire resumeSessionAt in Agent.swift (AC: #3)
  - [x] In `promptImpl()`, after session restore but before appending new user message: if `options.resumeSessionAt != nil && messages.count > 0`, search messages for matching UUID (check `["uuid"]`, `["id"]` keys), truncate to that index
  - [x] In `stream()` closure, same logic
  - [x] Handle UUID not found: keep full history (no truncation, no error)
  - [x] Add DocC comment documenting the behavior

- [x] Task 4: Verify persistSession wiring (AC: #4)
  - [x] Confirm `promptImpl()` save path (~line 531, ~line 754) checks `options.persistSession`
  - [x] Confirm `stream()` save path (~line 1534) checks `capturedPersistSession`
  - [x] Confirm error-path save (~line 531) also checks `persistSession`
  - [x] No code changes needed unless gaps found; document verification

- [x] Task 5: Update compat tests (AC: #5)
  - [x] Update `testAgentOptions_continue_gap()` to assert PASS (field exists, now also wired)
  - [x] Update `testCompatReport_restoreOptionsCoverage()` to reflect 4 MISSING -> PASS/RESOLVED
  - [x] Update `testCompatReport_overallSummary()` totals
  - [x] Add new unit tests for continueRecentSession, forkSession, resumeSessionAt runtime behavior

- [x] Task 6: Add unit tests for session wiring (AC: #5)
  - [x] Test continueRecentSession with no existing sessions -> new session behavior
  - [x] Test continueRecentSession with existing sessions -> restores most recent
  - [x] Test continueRecentSession with explicit sessionId -> sessionId wins (no-op)
  - [x] Test forkSession with valid session -> forked copy used
  - [x] Test forkSession with non-existent session -> graceful fallback
  - [x] Test resumeSessionAt with valid UUID -> truncation
  - [x] Test resumeSessionAt with invalid UUID -> full history kept
  - [x] Test persistSession=false -> no save after query
  - [x] Test combination: continueRecentSession + forkSession -> fork the continued session

- [x] Task 7: Validation (AC: #5)
  - [x] `swift build` zero errors zero warnings
  - [x] All 4034+ existing tests pass with zero regression
  - [x] New unit tests pass
  - [x] Run full test suite and report total count

## Dev Notes

### Position in Epic and Project

- **Epic 17** (TypeScript SDK Feature Alignment), seventh story
- **Prerequisites:** Story 17-1 (SDKMessage types), 17-2 (AgentOptions with 4 deferred session fields declared)
- **This is a production code story** -- modifies Agent.swift runtime logic
- **Focus:** Wire 4 deferred AgentOptions fields from Story 17-2 into Agent runtime behavior
- **Origin:** Memory note "Epic 17 deferred runtime wiring fields" identifies these 4 fields as deferred from 17-2

### Critical Gap Analysis

The 4 fields were **declared** in Story 17-2 but have **no runtime effect**:

| # | Field | Current Status | Required Action |
|---|---|---|---|
| 1 | `continueRecentSession: Bool` | Declared, defaults false, never read | Add logic: resolve most recent session from list() |
| 2 | `forkSession: Bool` | Declared, defaults false, never read | Add logic: fork session before restore |
| 3 | `resumeSessionAt: String?` | Declared, defaults nil, never read | Add logic: truncate history at UUID |
| 4 | `persistSession: Bool` | Declared, defaults true, **partially wired** | Verify all 3 save paths check it |

### persistSession Current Wiring Status

From Agent.swift analysis:
- **prompt() success path** (line 754): `if let sessionStore = options.sessionStore, let sessionId = options.sessionId, options.persistSession` -- WIRED
- **prompt() error path** (line 531): `if let sessionStore = options.sessionStore, let sessionId = options.sessionId, options.persistSession` -- WIRED
- **stream() save path** (line 1534): `if let sessionStore = capturedSessionStore, let sessionId = capturedSessionId, capturedPersistSession` -- WIRED

persistSession is already fully wired. Task 4 is verification-only, no code changes expected.

### Current Source Code Structure

**File: `Sources/OpenAgentSDK/Core/Agent.swift`**

```
promptImpl() flow (~line 345-370):
  1. sessionStart hook
  2. assembleFullToolPool() (MCP)
  3. Session restore:
     - if sessionStore + sessionId: load(sessionId:) -> messages
     - else: buildMessages(prompt:)
  4. Agent loop...

stream() closure flow (~line 920-930):
  1. Session restore:
     - if capturedSessionStore + capturedSessionId: load(sessionId:) -> messages
     - else: use decodedMessages
  2. sessionStart hook
  3. Agent loop...
```

**Injection points for new logic:**

For `continueRecentSession`:
- **promptImpl()**: Before line 360 session restore block. If `continueRecentSession && sessionStore != nil && sessionId == nil`, call `await sessionStore.list()`, take `.first?.id`, set as sessionId.
- **stream()**: Before line 922 session restore block. Same logic using `capturedSessionStore` / `capturedSessionId`.

For `forkSession`:
- **promptImpl()**: After continueRecentSession resolution but before session restore. If `forkSession && sessionStore != nil && sessionId != nil`, call `await sessionStore.fork(sourceSessionId: sessionId!)`, set sessionId to returned fork ID.
- **stream()**: Same timing, using captured variables.

For `resumeSessionAt`:
- **promptImpl()**: After session restore (after line 362) but before appending new user message (line 367). If `resumeSessionAt != nil`, search `messages` for matching UUID, truncate.
- **stream()**: After line 924 session restore, before line 929 append.

### Key Design Decisions

1. **Execution order:** continueRecentSession -> forkSession -> session restore -> resumeSessionAt -> append user message. This allows combining options: e.g., `continueRecentSession=true` + `forkSession=true` means "find most recent session, fork it, and continue in the fork."

2. **continueRecentSession without sessionId:** This is the primary use case. User sets `continueRecentSession=true` + `sessionStore` but no `sessionId`. Agent resolves the most recent session automatically. If `sessionId` IS also set, `continueRecentSession` is a no-op (the explicit sessionId takes precedence).

3. **forkSession creates new session ID:** The fork operation generates a new UUID. The original `sessionId` is preserved on disk. The forked ID becomes the active session for the rest of the query (including auto-save).

4. **resumeSessionAt message UUID matching:** Messages in `[[String: Any]]` format may have different key names. Search for `"uuid"`, `"id"`, `"message_id"` keys. If none found in any message, keep full history. This is defensive -- in practice, messages typically don't have UUIDs in the current format, so the fallback (full history) is the expected behavior.

5. **All new logic is additive:** No existing code paths change. The new blocks are guarded by field checks and only execute when the option is explicitly set to a non-default value.

6. **SessionStore has no new methods needed:** `list()` already returns sessions sorted by updatedAt descending. `fork()` already exists with auto-ID generation. `load()` returns all messages. No SessionStore changes required.

### Architecture Compliance

- **Core/ is the orchestrator:** All session wiring belongs in `Sources/OpenAgentSDK/Core/Agent.swift`
- **Module boundary:** Agent.swift imports from Types/ (AgentOptions), Stores/ (SessionStore). No new imports needed.
- **Sendable compliance:** No new types created. Session operations use existing actor-isolated SessionStore.
- **No Apple-proprietary frameworks:** All code uses Foundation and Swift Concurrency only.
- **Error handling:** Use `try?` for session operations (consistent with existing pattern at lines 361, 539). Failures are graceful fallbacks, not thrown errors.
- **Avoid naming type `Task`:** Per CLAUDE.md, never name a Swift type `Task`.

### File Locations

```
Sources/OpenAgentSDK/Core/Agent.swift                              # MODIFY -- add session wiring logic in promptImpl() and stream()
Tests/OpenAgentSDKTests/Core/AgentSessionWiringTests.swift         # POSSIBLE NEW -- unit tests for session wiring behavior
Tests/OpenAgentSDKTests/Compat/SessionManagementCompatTests.swift  # MODIFY -- update MISSING assertions to PASS/RESOLVED
```

### Source Files to Reference

- `Sources/OpenAgentSDK/Core/Agent.swift` -- promptImpl() session restore (line 358-370), stream() session restore (line 921-930), session save paths (lines 531, 754, 1534) (PRIMARY modification target)
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions.continueRecentSession (line 331), forkSession (line 336), resumeSessionAt (line 340), persistSession (line 345)
- `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- list() (line 242), fork() (line 198), load() (line 104)
- `Sources/OpenAgentSDK/Types/SessionTypes.swift` -- SessionMetadata, SessionData
- `Tests/OpenAgentSDKTests/Compat/SessionManagementCompatTests.swift` -- 4 MISSING assertions to update
- `_bmad-output/implementation-artifacts/16-6-session-management-compat.md` -- Detailed gap analysis
- `_bmad-output/implementation-artifacts/17-6-subagent-system-enhancement.md` -- Previous story patterns

### Previous Story Intelligence

**From Story 17-6 (Subagent System Enhancement):**
- Pattern: extend existing types/protocol, add new overload with default params for backward compat
- 4034 tests passing after 17-6 completion
- Compat tests updated from MISSING to PASS assertions

**From Story 17-2 (AgentOptions Enhancement):**
- Declared 14 new AgentOptions fields including the 4 deferred session fields
- Runtime wiring done for 7 fields, deferred 5 (including these 4 + toolConfig + promptSuggestions)
- Memory note created: "Epic 17 deferred runtime wiring fields"
- Pattern: use captured local variables in stream() closure for Sendable compliance

**From Story 16-6 (Session Management Compat):**
- Documented 4 MISSING session restore options: continue, forkSession, resumeSessionAt, persistSession
- SessionStore already has list(), fork(), load() -- all methods needed for wiring
- Compat tests assert MISSING for these 4 options -- need updating

### Anti-Patterns to Avoid

- Do NOT modify SessionStore.swift -- it already has all needed methods (list, fork, load)
- Do NOT add new AgentOptions fields -- they already exist from Story 17-2
- Do NOT change existing session restore behavior when new options are at default values
- Do NOT throw errors from session wiring -- use graceful fallback (try? and nil checks)
- Do NOT import Stores/ from Types/ -- violates module boundary
- Do NOT use force-unwrap (`!`) -- use guard let / if let
- Do NOT make session wiring synchronous -- SessionStore is an actor, use `await`
- Do NOT forget to update both promptImpl() AND stream() code paths
- Do NOT forget to capture new variables for stream() Sendable compliance
- Do NOT create mock-based E2E tests -- per CLAUDE.md, E2E tests use real environment

### Implementation Strategy

1. **Start with continueRecentSession:** Simplest -- call list(), take first, set sessionId. Add to both promptImpl() and stream().
2. **Add forkSession:** After continue resolution, call fork() to create copy. Add to both paths.
3. **Add resumeSessionAt:** After session restore, search and truncate messages. Add to both paths.
4. **Verify persistSession:** Audit all save paths. No changes expected.
5. **Update compat tests:** Change 4 MISSING assertions to PASS/RESOLVED.
6. **Write unit tests:** Use real SessionStore with temp directory (per CLAUDE.md testing rules).
7. **Build and verify:** `swift build` + full test suite.

### Testing Requirements

- **Existing tests must pass:** 4034+ tests (as of 17-6), zero regression
- **New tests needed:**
  - Unit test: continueRecentSession=true with no sessions -> empty history, no error
  - Unit test: continueRecentSession=true with existing sessions -> restores most recent
  - Unit test: continueRecentSession=true with explicit sessionId -> sessionId wins (no-op)
  - Unit test: forkSession=true with valid session -> forked copy created, original unchanged
  - Unit test: forkSession=true with non-existent session -> graceful fallback
  - Unit test: resumeSessionAt with matching UUID -> history truncated
  - Unit test: resumeSessionAt with non-matching UUID -> full history kept
  - Unit test: persistSession=false -> no save after query
  - Unit test: combined continueRecentSession + forkSession -> fork then continue
- **Compat test updates:** 4 tests change from asserting MISSING to PASS/RESOLVED
- **No E2E tests with mocks:** Per CLAUDE.md, E2E tests use real environment
- After implementation, run full test suite and report total count

### Project Structure Notes

- All changes in `Sources/OpenAgentSDK/Core/Agent.swift` -- no new files in production code
- Test file may be new or may extend existing `Tests/OpenAgentSDKTests/Core/` files
- No new types needed -- wiring uses existing SessionStore methods and AgentOptions fields
- No Package.swift changes needed

### References

- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L358-370] -- promptImpl() session restore block (PRIMARY modification target)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L921-930] -- stream() session restore block
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L531] -- promptImpl() error-path save with persistSession check
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L754] -- promptImpl() success-path save with persistSession check
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L1534] -- stream() save with persistSession check
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L328-345] -- 4 deferred session fields
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift#L198-237] -- fork() method
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift#L242-264] -- list() method (sorted by updatedAt desc)
- [Source: Tests/OpenAgentSDKTests/Compat/SessionManagementCompatTests.swift#L591-601] -- continue MISSING assertion
- [Source: Tests/OpenAgentSDKTests/Compat/SessionManagementCompatTests.swift#L988-1002] -- restore options compat report
- [Source: _bmad-output/implementation-artifacts/16-6-session-management-compat.md] -- Detailed gap analysis
- [Source: _bmad-output/implementation-artifacts/17-6-subagent-system-enhancement.md] -- Previous story

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented session lifecycle wiring in both promptImpl() and stream() code paths
- continueRecentSession: resolves most recent session via sessionStore.list() when no explicit sessionId
- forkSession: forks resolved session via sessionStore.fork() before restore, forked ID becomes active
- resumeSessionAt: truncates message history at matching UUID (checks "uuid" and "id" keys) after restore
- persistSession: verified all 3 save paths already wired -- no code changes needed
- Save paths updated to use resolvedSessionId (from wiring) instead of options.sessionId
- Compat tests updated: 4 MISSING options now RESOLVED (continueRecentSession, forkSession, resumeSessionAt, persistSession)
- All 21 ATDD tests pass (existing from story creation)
- All 4055 tests pass with zero regressions (21 new tests added since story 17-6)
- swift build: zero errors

### File List

- Sources/OpenAgentSDK/Core/Agent.swift (MODIFIED -- session lifecycle wiring in promptImpl() and stream())
- Tests/OpenAgentSDKTests/Compat/SessionManagementCompatTests.swift (MODIFIED -- updated compat assertions)
- Tests/OpenAgentSDKTests/Core/SessionManagementWiringATDDTests.swift (EXISTING -- 21 ATDD tests, all passing)
- _bmad-output/implementation-artifacts/sprint-status.yaml (MODIFIED -- status updated)
- _bmad-output/implementation-artifacts/17-7-session-management-enhancement.md (MODIFIED -- tasks marked complete)

### Change Log

- 2026-04-17: Story 17-7 implementation complete -- wired 4 deferred session fields (continueRecentSession, forkSession, resumeSessionAt, persistSession) into Agent runtime. All 4055 tests pass.

### Review Findings

- [x] [Review][Patch] Force-unwrap on `resolvedSessionId!.isEmpty` replaced with `resolvedSessionId?.isEmpty == true` [Sources/OpenAgentSDK/Core/Agent.swift:365, 965] -- fixed
- [x] [Review][Defer] Dev Notes mention `message_id` key but code only checks `uuid`/`id` [Sources/OpenAgentSDK/Core/Agent.swift:392-393] -- deferred, pre-existing (AC only requires `uuid`/`id`, Dev Notes inconsistency)
