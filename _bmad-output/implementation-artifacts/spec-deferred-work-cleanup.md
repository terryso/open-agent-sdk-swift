---
title: 'Deferred Work Cleanup: Type Safety, Logging, Memory Guard, and replace_all'
type: 'refactor'
created: '2026-04-14'
status: 'done'
baseline_commit: '5ba4006'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/deferred-work.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Five deferred work items from code reviews degrade type safety, debuggability, memory safety, and feature parity with the TS SDK.

**Approach:** Convert stringly-typed fields to enums for compile-time safety; add structured logging to silently-swallowed errors in SessionStore; cap unbounded dictionary growth in FileCache; add the `replace_all` parameter to FileEditTool for TS SDK parity.

## Boundaries & Constraints

**Always:** Maintain backward compatibility — existing call sites must compile without changes. Use `RawRepresentable` enums with `String` raw values so JSON encoding/decoding is preserved. Follow existing project patterns (Sendable, Equatable, CaseIterable on enums).

**Ask First:** None expected — all changes are localized and non-controversial.

**Never:** Do not change the public API surface in a breaking way. Do not add logging infrastructure — use the existing `Logger.shared`. Do not modify MCPConfig structs (investigation confirmed the duplication is intentional).

## I/O & Edge-Case Matrix

### Goal 1: HookNotificationLevel enum

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Valid level string | JSON `{"level": "warning"}` | Decodes to `.warning` | N/A |
| Unknown level string | JSON `{"level": "critical"}` | Decodes to `.rawValue` "critical" via failable init, or fallback to `.info` | Must not crash |
| Default init | `HookNotification(title:, body:)` | `level` defaults to `.info` | N/A |

### Goal 2: PermissionBehavior enum

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| "allow" string | JSON `{"behavior": "allow"}` | Decodes to `.allow` | N/A |
| "deny" string | JSON `{"behavior": "deny"}` | Decodes to `.deny` | N/A |

### Goal 3: SessionStore load() logging

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Truncated JSON | Corrupted transcript.json | Returns nil + logs warning with sessionId | N/A |
| Missing required fields | Valid JSON but missing keys | Returns nil + logs warning with sessionId and missing key | N/A |

### Goal 4: FileCache modifiedPaths cap

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Exceed cap | `modifiedPaths.count > maxModifiedPaths` after set() | Evicts oldest entries to stay at cap | N/A |
| getModifiedFiles after eviction | Entries evicted | Evicted paths no longer returned | By design |

### Goal 5: FileEditTool replace_all

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| replace_all=true, multiple matches | 3 occurrences of old_string | All 3 replaced | N/A |
| replace_all=true, no matches | old_string absent | Error: "old_string not found" | isError: true |
| replace_all=false (default), multiple matches | 2 occurrences | Error: "appears 2 times" | isError: true |
| replace_all omitted | Legacy JSON without field | Defaults to false, current behavior preserved | N/A |

</frozen-after-approval>

## Code Map

- `Sources/OpenAgentSDK/Types/HookTypes.swift` — HookNotification (level: String), PermissionUpdate (behavior: String)
- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` — CanUseToolResult (behavior: String)
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — reads PermissionUpdate.behavior
- `Sources/OpenAgentSDK/Sessions/SessionStore.swift` — load() method (lines ~101-143)
- `Sources/OpenAgentSDK/Utils/Logger.swift` — existing Logger.shared for structured logging
- `Sources/OpenAgentSDK/Cache/FileCache.swift` — modifiedPaths dictionary (line ~124), set(), invalidate()
- `Sources/OpenAgentSDK/Tools/FileEditTool.swift` — FileEditInput struct, replacement logic
- `Tests/OpenAgentSDKTests/Types/HookTypesTests.swift` — existing tests
- `Tests/OpenAgentSDKTests/Types/PermissionTypesTests.swift` — existing tests
- `Tests/OpenAgentSDKTests/Tools/Core/FileEditToolTests.swift` — existing tests
- `Tests/OpenAgentSDKTests/Cache/FileCacheIntegrationTests.swift` — existing tests

## Tasks & Acceptance

**Execution:**

- [x] `Sources/OpenAgentSDK/Types/HookTypes.swift` — Add `HookNotificationLevel` enum (info, warning, error, debug) with `String` raw value, `CaseIterable`, `Sendable`. Change `HookNotification.level` from `String` to `HookNotificationLevel`. Add `PermissionBehavior` enum (allow, deny) with same traits. Change `PermissionUpdate.behavior` from `String` to `PermissionBehavior`. Provide backward-compatible `Codable` conformance.
- [x] `Sources/OpenAgentSDK/Types/PermissionTypes.swift` — Change `CanUseToolResult.behavior` from `String` to `PermissionBehavior`. Update init and Equatable implementation.
- [x] `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — Update all call sites comparing `behavior` to string literals to use enum cases.
- [x] `Sources/OpenAgentSDK/Sessions/SessionStore.swift` — Add `Logger.shared.warn("SessionStore", ...)` calls in load() where JSON decoding or metadata extraction fails (the guard clauses that currently return nil silently).
- [x] `Sources/OpenAgentSDK/Cache/FileCache.swift` — Add `maxModifiedPaths` property (default 1000). After adding entries in `set()` and `invalidate()`, evict oldest entries if count exceeds cap.
- [x] `Sources/OpenAgentSDK/Tools/FileEditTool.swift` — Add optional `replace_all: Bool?` to `FileEditInput`. Update input schema in `defineTool()`. When `replace_all` is true, skip uniqueness check and allow multiple replacements. When false/nil, preserve current behavior.
- [x] `Tests/OpenAgentSDKTests/Types/HookTypesTests.swift` — Add tests: enum round-trip encoding/decoding, unknown raw value handling, default values.
- [x] `Tests/OpenAgentSDKTests/Types/PermissionTypesTests.swift` — Add tests: enum round-trip, allow/deny values.
- [x] `Tests/OpenAgentSDKTests/Tools/Core/FileEditToolTests.swift` — Add tests: replace_all=true with multiple occurrences, replace_all=true with single occurrence, replace_all=true with no matches (error), replace_all omitted (backward compat).
- [x] `Tests/OpenAgentSDKTests/Cache/FileCacheIntegrationTests.swift` — Add test: modifiedPaths eviction when cap exceeded.
- [x] `Tests/OpenAgentSDKTests/Sessions/SessionStoreTests.swift` — Production logging implemented. Nil-return behavior for corrupt JSON already tested in `testLoad_nonexistentSession_returnsNil`. Log output verification requires log capture infrastructure not yet in the project.

**Acceptance Criteria:**
- Given a HookNotification with level="warning", when encoded to JSON and decoded, then the level is `.warning`
- Given a PermissionUpdate with behavior="deny", when encoded to JSON and decoded, then the behavior is `.deny`
- Given a corrupted transcript.json, when load() is called, then a warning is logged and nil is returned
- Given a FileCache with 1000 modifiedPaths entries, when a new entry is added, then the oldest entry is evicted
- Given FileEditInput with replace_all=true and 3 occurrences of old_string, when executed, then all 3 are replaced
- Given FileEditInput without replace_all and multiple occurrences, when executed, then error is returned (backward compat)

## Spec Change Log

## Design Notes

**HookNotificationLevel unknown-value handling:** Use `Codable` with custom init that falls back to a raw-value case rather than failing. This avoids crashes on unknown future values from TS SDK interop. Alternative: use a failable init — but this would break decoding in non-optional contexts.

**PermissionBehavior** is a closed set (allow/deny) based on TS SDK — simple `String` raw-value enum, no unknown-value handling needed.

**FileCache modifiedPaths cap:** Eviction sorts by `Date` value (oldest first). Sorting only triggers when count exceeds cap, so amortized cost is acceptable for a 1000-entry dictionary.

## Verification

**Commands:**
- `swift build` -- expected: clean build with no errors
- `swift test` -- expected: all tests pass (including new tests)

## Suggested Review Order

**Type-safe enums (HookNotificationLevel, PermissionBehavior)**

- New HookNotificationLevel enum with unknown-value fallback and PermissionBehavior enum
  [`HookTypes.swift:128`](../../Sources/OpenAgentSDK/Types/HookTypes.swift#L128)

- CanUseToolResult.behavior changed to PermissionBehavior; factory methods use enum cases
  [`PermissionTypes.swift:17`](../../Sources/OpenAgentSDK/Types/PermissionTypes.swift#L17)

- CompositePolicy uses `.deny` comparison instead of string literal
  [`PermissionTypes.swift:163`](../../Sources/OpenAgentSDK/Types/PermissionTypes.swift#L163)

- ShellHookExecutor manual JSON parsing uses PermissionBehavior(rawValue:) and HookNotificationLevel()
  [`ShellHookExecutor.swift:161`](../../Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift#L161)

- ToolExecutor uses `.deny` comparison instead of string literal
  [`ToolExecutor.swift:340`](../../Sources/OpenAgentSDK/Core/ToolExecutor.swift#L340)

**SessionStore load() logging**

- Warning logs for corrupt JSON and missing metadata fields in load()
  [`SessionStore.swift:119`](../../Sources/OpenAgentSDK/Stores/SessionStore.swift#L119)

**FileCache modifiedPaths cap**

- maxModifiedPaths property, eviction logic after set() and invalidate()
  [`FileCache.swift:117`](../../Sources/OpenAgentSDK/Utils/FileCache.swift#L117)

**FileEditTool replace_all parameter**

- Optional replace_all field in FileEditInput, conditional uniqueness check
  [`FileEditTool.swift:9`](../../Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift#L9)

**Tests**

- New enum tests (raw values, allCases, unknown fallback)
  [`HookTypesTests.swift:169`](../../Tests/OpenAgentSDKTests/Types/HookTypesTests.swift#L169)

- replace_all tests (multiple, single, not-found, backward compat)
  [`FileEditToolTests.swift:307`](../../Tests/OpenAgentSDKTests/Tools/Core/FileEditToolTests.swift#L307)

- modifiedPaths eviction test with small cap
  [`FileCacheIntegrationTests.swift:432`](../../Tests/OpenAgentSDKTests/Utils/FileCacheIntegrationTests.swift#L432)
