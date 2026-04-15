# Story 16.6: 会话管理完整性验证 / Session Management Compatibility Verification

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的会话管理 API 覆盖 TypeScript SDK 的所有会话操作，
以便所有会话相关功能都能在 Swift 中使用。

As an SDK developer,
I want to verify that Swift SDK's session management API covers all TypeScript SDK session operations,
so that all session-related functionality can be used in Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatSessions/` directory and `CompatSessions` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: listSessions equivalent verification** -- Verify Swift SDK has a method equivalent to TS SDK `listSessions({ dir?, limit?, includeWorktrees? })` returning session metadata list (with sessionId, summary, lastModified, fileSize, customTitle, firstPrompt, gitBranch, cwd, tag, createdAt). Missing fields recorded as gaps.

3. **AC3: getSessionMessages equivalent verification** -- Verify Swift SDK has a method equivalent to TS SDK `getSessionMessages(sessionId, { dir?, limit?, offset? })` returning message list (with type: user/assistant, uuid, session_id, message, parent_tool_use_id). Missing parameters or fields recorded as gaps.

4. **AC4: getSessionInfo/renameSession/tagSession verification** -- Verify Swift SDK has methods equivalent to TS SDK's `getSessionInfo(sessionId)` (returns info or nil), `renameSession(sessionId, title)`, `tagSession(sessionId, tag | null)`. Missing methods recorded as gaps.

5. **AC5: Session restore options verification** -- Verify Swift SDK's AgentOptions supports these session options (matching TS SDK Options):
   - `resume: sessionId` -- resume a session
   - `continue: true` -- continue most recent session
   - `forkSession: true` -- fork instead of continue
   - `resumeSessionAt: messageUUID` -- resume at specific message
   - `sessionId: uuid` -- use specified ID
   - `persistSession: false` -- disable persistence
   Missing options recorded as gaps.

6. **AC6: Cross-query context retention verification** -- Using the same Agent instance, execute two rounds of queries; verify the second round can reference content from the first round.

7. **AC7: Compatibility report output** -- Output compatibility status for all session functions and options.

## Tasks / Subtasks

- [ ] Task 1: Create example directory and scaffold (AC: #1)
  - [ ] Create `Examples/CompatSessions/main.swift`
  - [ ] Add `CompatSessions` executable target to `Package.swift`
  - [ ] Verify `swift build --target CompatSessions` passes with zero errors and zero warnings

- [ ] Task 2: Session list and info verification (AC: #2, #3, #4)
  - [ ] Check `SessionStore.list()` vs TS `listSessions({ dir?, limit?, includeWorktrees? })`
  - [ ] Check `SessionStore.load(sessionId:)` vs TS `getSessionMessages(sessionId, { dir?, limit?, offset? })`
  - [ ] Check `SessionStore.rename(sessionId:newTitle:)` vs TS `renameSession(sessionId, title, { dir? })`
  - [ ] Check `SessionStore.tag(sessionId:tag:)` vs TS `tagSession(sessionId, tag | null, { dir? })`
  - [ ] Verify `SessionMetadata` field completeness vs TS `SDKSessionInfo`
  - [ ] Verify `SessionData.messages` element structure vs TS `SessionMessage`
  - [ ] Record per-field status for each type

- [ ] Task 3: Session restore options verification (AC: #5)
  - [ ] Check `AgentOptions.sessionStore` + `AgentOptions.sessionId` vs TS `resume`/`sessionId`
  - [ ] Check for `continue` option (resume most recent session)
  - [ ] Check for `forkSession` option
  - [ ] Check for `resumeSessionAt` option
  - [ ] Check for `persistSession` option
  - [ ] Record missing options

- [ ] Task 4: Cross-query context verification (AC: #6)
  - [ ] Create agent with session persistence enabled
  - [ ] Round 1: tell agent a fact (name/color)
  - [ ] Round 2: ask agent to recall the fact
  - [ ] Verify context is retained

- [ ] Task 5: Generate compatibility report (AC: #7)

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), sixth story
- **Prerequisites:** Stories 16-1 through 16-5 are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report

### Critical API Mapping: TS SDK Session Functions vs Swift SDK SessionStore

Based on analysis of `Sources/OpenAgentSDK/Stores/SessionStore.swift` and `Sources/OpenAgentSDK/Types/SessionTypes.swift`:

**Swift `SessionStore` actor methods:**

| # | TS SDK Function | Swift Equivalent | Status | Gap Details |
|---|---|---|---|---|
| 1 | `listSessions({ dir?, limit?, includeWorktrees? })` | `SessionStore.list()` | PARTIAL | Returns `[SessionMetadata]`. No `limit` param, no `includeWorktrees` param, no `dir` param (uses constructor `sessionsDir`) |
| 2 | `getSessionMessages(sessionId, { dir?, limit?, offset? })` | `SessionStore.load(sessionId:)` | PARTIAL | Returns `SessionData?` with all messages. No pagination (`limit`/`offset`). No `dir` param |
| 3 | `getSessionInfo(sessionId, { dir? })` | `SessionStore.load(sessionId:)` | PARTIAL | Returns full `SessionData`, not just metadata. Must extract `.metadata` for info-only use. No `dir` param |
| 4 | `renameSession(sessionId, title, { dir? })` | `SessionStore.rename(sessionId:newTitle:)` | PASS | Functional equivalent. No `dir` param |
| 5 | `tagSession(sessionId, tag \| null, { dir? })` | `SessionStore.tag(sessionId:tag:)` | PASS | Functional equivalent. `nil` removes tag. No `dir` param |
| 6 | N/A | `SessionStore.save(sessionId:messages:metadata:)` | EXTRA (Swift-only) | No TS equivalent exposed as standalone function |
| 7 | N/A | `SessionStore.delete(sessionId:)` | EXTRA (Swift-only) | No TS equivalent exposed as standalone function |
| 8 | N/A | `SessionStore.fork(sourceSessionId:newSessionId:upToMessageIndex:)` | EXTRA (Swift-only) | TS uses `forkSession: true` option, not a standalone function |

**Summary:** 2 of 5 TS functions have full equivalents (rename, tag). 3 are PARTIAL (list, getSessionMessages, getSessionInfo) due to missing pagination/filtering params. Swift has 3 extra methods not in TS (save, delete, fork as standalone).

### SessionMetadata vs TS SDK SDKSessionInfo Field Verification

**Swift `SessionMetadata` fields:**

| TS SDK SDKSessionInfo Field | Swift SessionMetadata Field | Status |
|---|---|---|
| sessionId | id: String | PASS (different name) |
| summary | summary: String? | PASS |
| lastModified | updatedAt: Date | PASS (different name, uses Date not string) |
| fileSize | **MISSING** | MISSING -- Swift does not expose file size |
| customTitle | summary: String? (shared with `summary`) | PARTIAL -- same field used for title and summary |
| firstPrompt | **MISSING** | MISSING -- Swift does not capture first prompt |
| gitBranch | **MISSING** | MISSING -- Swift does not capture git branch |
| cwd | cwd: String | PASS |
| tag | tag: String? | PASS |
| createdAt | createdAt: Date | PASS (uses Date not string) |
| N/A | model: String | EXTRA (Swift-only) |
| N/A | messageCount: Int | EXTRA (Swift-only) |
| N/A | updatedAt: Date (separate from lastModified) | EXTRA (Swift-only, TS merges into lastModified) |

**Summary:** 5 fields PASS, 4 fields MISSING (fileSize, customTitle as distinct field, firstPrompt, gitBranch), 3 EXTRA Swift-only fields (model, messageCount, separate updatedAt).

### SessionData.messages Element vs TS SDK SessionMessage

**TS SDK `SessionMessage`:** `{ type: "user"|"assistant", uuid, session_id, message, parent_tool_use_id }`

**Swift `SessionData.messages`:** `[[String: Any]]` -- raw dictionaries, not typed structs.

The messages are stored as raw `[String: Any]` dictionaries (the exact API response format). Fields available depend on what was serialized:
- `role` (not `type`) -- "user" or "assistant"
- `content` (not `message`) -- the message content
- No `uuid` field (Swift does not assign UUIDs to individual messages)
- No `session_id` field (session ID is in metadata, not per-message)
- No `parent_tool_use_id` field

**Key gap:** Swift lacks a typed `SessionMessage` struct with the TS SDK's field names. Messages are opaque dictionaries.

### Session Restore Options Gap Analysis

**Swift `AgentOptions` session-related fields:**

| TS SDK Option | Swift AgentOptions Field | Status |
|---|---|---|
| `resume: sessionId` | `sessionStore: SessionStore?` + `sessionId: String?` | PARTIAL -- requires both fields, not a single `resume` option |
| `continue: true` | **MISSING** | MISSING -- no "resume most recent session" convenience option |
| `forkSession: true` | **MISSING** as option | MISSING -- Swift has `SessionStore.fork()` as standalone method, not as an AgentOption |
| `resumeSessionAt: messageUUID` | **MISSING** | MISSING -- no option to resume at specific message |
| `sessionId: uuid` | `sessionId: String?` | PASS -- can set a custom session ID |
| `persistSession: false` | **MISSING** | MISSING -- Swift always persists when sessionStore+sessionId are set; no way to disable persistence per-query |

**Summary:** 1 PASS, 1 PARTIAL, 4 MISSING. Swift's session management is simpler -- it uses `sessionStore` + `sessionId` together for basic restore/persist, but lacks the fine-grained TS SDK options.

### Session Auto-Restore/Auto-Save Behavior in Agent

From `Sources/OpenAgentSDK/Core/Agent.swift` (lines 345-349, 449-457, 671-680):
- When `options.sessionStore` and `options.sessionId` are both set:
  - **Before query:** Agent loads session history via `sessionStore.load(sessionId:)` and injects into message array
  - **After query:** Agent saves updated messages via `sessionStore.save(sessionId:messages:metadata:)`
  - This happens automatically for both `prompt()` and `stream()` paths
- When either is nil, session persistence is disabled

### Cross-Query Context Retention

Swift has two mechanisms for cross-query context:
1. **In-memory (same Agent instance):** Messages array persists in the Agent between `prompt()` calls. No sessionStore needed.
2. **Persisted (different Agent instances):** Use `sessionStore` + `sessionId` to save/restore across process boundaries.

For AC6, the in-memory path (same Agent instance) is the standard multi-turn pattern verified in Story 16-1 (AC5). For session-specific verification, also test the persisted path with `sessionStore`.

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** `SessionStore` is an actor. Use `await` for all method calls.
- **Naming conventions:** PascalCase for types, camelCase for variables.
- **Testing standards:** This is an example, not a test. Follow project example patterns.

### Patterns to Follow (from Stories 16-1 through 16-5)

- Use `loadDotEnv()` / `getEnv()` for API key loading (see `Examples/CompatCoreQuery/main.swift`)
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern from CompatCoreQuery for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Package.swift already has CompatCoreQuery, CompatToolSystem, CompatMessageTypes, CompatHooks, CompatMCP targets -- add `CompatSessions` following the same pattern
- Use `swift build --target CompatSessions` for fast build verification

### File Locations

```
Examples/CompatSessions/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatSessions executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- SessionStore actor (save, load, delete, fork, list, rename, tag)
- `Sources/OpenAgentSDK/Types/SessionTypes.swift` -- SessionMetadata, SessionData, PartialSessionMetadata
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions.sessionStore, AgentOptions.sessionId
- `Sources/OpenAgentSDK/Core/Agent.swift` -- Agent auto-restore (line 345-349) and auto-save (line 449-457, 671-680)
- `Sources/OpenAgentSDK/Utils/SessionMemory.swift` -- SessionMemory for cross-query in-memory context
- `Examples/CompatCoreQuery/main.swift` -- Reference pattern for CompatEntry/record() report generation
- `Examples/CompatMCP/main.swift` -- Latest reference for established compat example pattern

### Previous Story Intelligence (16-1 through 16-5)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Story 16-3 verified message types and found many gaps (12 of 20 TS types have no Swift equivalent)
- Story 16-4 verified hook system: 15/18 events PASS, 3 MISSING; significant field-level gaps in HookInput/Output
- Story 16-5 verified MCP integration: 4/5 config types covered, 3/4 runtime ops MISSING, tool namespace PASS
- Known pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `nonisolated(unsafe)` for mutable globals
- Full test suite was 3402 tests passing at time of 16-5 completion (14 skipped, 0 failures)
- Story 16-1 AC5 already verified multi-turn (same Agent) context retention works correctly

### Git Intelligence

Recent commits show Epic 16 progressing sequentially: 16-1 (core query), 16-2 (tool system), 16-3 (message types), 16-4 (hooks), 16-5 (MCP). The CompatEntry/record() pattern is established and consistent across all five examples. All examples follow the same scaffold pattern.

### References

- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift] -- SessionStore actor with save/load/delete/fork/list/rename/tag
- [Source: Sources/OpenAgentSDK/Types/SessionTypes.swift] -- SessionMetadata, SessionData, PartialSessionMetadata types
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentOptions.sessionStore, AgentOptions.sessionId
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L345-349] -- Session auto-restore before query
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L449-457] -- Session auto-save after streaming query
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L671-680] -- Session auto-save after blocking query
- [Source: Sources/OpenAgentSDK/Utils/SessionMemory.swift] -- SessionMemory for cross-query in-memory context
- [Source: _bmad-output/planning-artifacts/epics.md#Epic16] -- Story 16.6 definition
- [Source: _bmad-output/implementation-artifacts/16-5-mcp-integration-compat.md] -- Previous story with established report pattern
- [Source: _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md] -- Original CompatEntry/record() pattern
- [TS SDK Reference] listSessions(), getSessionMessages(), getSessionInfo(), renameSession(), tagSession(), Options session-related fields

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
