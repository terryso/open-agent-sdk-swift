---
title: 'Deferred Work: Thread Safety & Quality Fixes'
type: 'refactor'
created: '2026-04-15'
status: 'done'
baseline_commit: '3607cd3'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Four deferred work items pose thread-safety risks or test coverage gaps: (1) `MODEL_PRICING` global dictionary has unsynchronized mutations via `registerModel`/`unregisterModel`, (2) `Agent.options` is read/written concurrently when `setPermissionMode`/`setCanUseTool` are called during streaming, (3) two MCP tool schema constants use `nonisolated(unsafe)` unnecessarily, (4) SessionStore E2E tests lack concurrent-save and delete coverage.

**Appro:** Add `NSLock` protection for `MODEL_PRICING` mutations and `Agent.options` permission fields, remove `nonisolated(unsafe)` from private schema constants, add E2E tests for concurrent saves and delete. Also mark 2 already-resolved items as FIXED in deferred-work.md.

## Boundaries & Constraints

**Always:** Backward-compatible public API — `registerModel`, `unregisterModel`, `setPermissionMode`, `setCanUseTool` signatures unchanged. Use `NSLock` (not actors) to keep functions synchronous. Run full test suite and report total count.

**Ask First:** Any change beyond the 4 items listed.

**Never:** Refactor `ToolInputSchema` typealias, change `Agent` to an actor, add new public API surface.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Concurrent registerModel | Two threads register different models simultaneously | Both models present in MODEL_PRICING after both return | N/A |
| setPermissionMode during stream | Stream loop executing tools, setPermissionMode called from another context | Stream picks up new mode on next tool execution | N/A |
| Schema constant read | Multiple threads read schema simultaneously | Same value returned, no crash | N/A |
| Delete nonexistent session | Session ID not on disk | Returns false, no crash | N/A |
| Concurrent saves | Two tasks save same session ID simultaneously | Last-write-wins, no crash/corruption | N/A |

</frozen-after-approval>

## Code Map

- `Sources/OpenAgentSDK/Types/ModelInfo.swift` -- `MODEL_PRICING` global var (line 43), `registerModel()` (line 62), `unregisterModel()` (line 71)
- `Sources/OpenAgentSDK/Core/Agent.swift` -- `var options` (line 50), `setPermissionMode()` (line 146), `setCanUseTool()` (line 157), stream reads at lines 1276-1277
- `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` -- `nonisolated(unsafe) let listMcpResourcesSchema` (line 13)
- `Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift` -- `nonisolated(unsafe) let readMcpResourceSchema` (line 5)
- `Sources/E2ETest/SessionStoreE2ETests.swift` -- Existing 3 tests (round-trip, permissions, auto-creation), needs concurrent + delete tests
- `_bmad-output/implementation-artifacts/deferred-work.md` -- Mark 2 resolved items as FIXED

## Tasks & Acceptance

**Execution:**
- [x] `Sources/OpenAgentSDK/Types/ModelInfo.swift` -- Add private `NSLock`, wrap `registerModel()` and `unregisterModel()` bodies in `lock.withLock { }`, add lock-protected read helper if needed -- Prevents data race on concurrent model registration
- [x] `Sources/OpenAgentSDK/Core/Agent.swift` -- Add private `NSLock` for permission fields, protect `setPermissionMode()` and `setCanUseTool()` writes, snapshot permission values under lock in stream path -- Prevents data race when dynamically changing permissions during streaming
- [x] `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` + `ReadMcpResourceTool.swift` -- Attempted removal of `nonisolated(unsafe)`, but compiler requires it because `ToolInputSchema` (`[String: Any]`) is not `Sendable`. Constants are immutable so annotation is safe. Updated deferred-work.md to clarify.
- [x] `Sources/E2ETest/SessionStoreE2ETests.swift` -- Add `testConcurrentSaves()` and `testDeleteSession()` E2E tests -- Covers deferred E2E gaps for concurrent writes and deletion
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- Marked SessionMetadata timestamps, Hook execute() logging, MODEL_PRICING race, Agent options race, and E2E coverage as FIXED
- [x] `Tests/OpenAgentSDKTests/Types/ModelInfoTests.swift` -- Add thread-safety test for concurrent `registerModel` calls -- Validates the lock fix

**Acceptance Criteria:**
- Given concurrent calls to `registerModel`/`unregisterModel`, when run from multiple threads, then no crash or data corruption occurs
- Given `setPermissionMode` called during active streaming, when stream reads `self.options`, then it reads a consistent snapshot (no partial write)
- Given `swift build` succeeds with all `nonisolated(unsafe)` removed from MCP tool schemas
- Given new E2E tests pass alongside existing tests, when full suite runs, then total count reported

## Spec Change Log

## Design Notes

**MODEL_PRICING lock pattern:**
```swift
private let _pricingLock = NSLock()

public func registerModel(_ modelId: String, pricing: ModelPricing) {
    _pricingLock.withLock {
        MODEL_PRICING[modelId] = pricing
    }
}
```

**Agent options lock pattern (targeted, not full `options` lockdown):**
```swift
private let _permissionLock = NSLock()

public func setPermissionMode(_ mode: PermissionMode) {
    _permissionLock.withLock {
        options.permissionMode = mode
        options.canUseTool = nil
    }
}

// In stream path, read under lock:
let (pm, cb) = _permissionLock.withLock { (self.options.permissionMode, self.options.canUseTool) }
```

## Verification

**Commands:**
- `swift build` -- expected: clean compilation, zero errors
- `swift test` -- expected: all tests pass, report total count

## Suggested Review Order

**Thread-safety: MODEL_PRICING lock**

- NSLock with name for deadlock diagnosis, wraps all mutations
  [`ModelInfo.swift:54`](../../Sources/OpenAgentSDK/Types/ModelInfo.swift#L54)

- registerModel() now lock-protected — prevents concurrent-write crashes
  [`ModelInfo.swift:68`](../../Sources/OpenAgentSDK/Types/ModelInfo.swift#L68)

- unregisterModel() lock-protected for consistency
  [`ModelInfo.swift:79`](../../Sources/OpenAgentSDK/Types/ModelInfo.swift#L79)

**Thread-safety: Agent permission lock**

- NSLock with name, protects permissionMode and canUseTool fields
  [`Agent.swift:53`](../../Sources/OpenAgentSDK/Core/Agent.swift#L53)

- setPermissionMode() writes under lock
  [`Agent.swift:153`](../../Sources/OpenAgentSDK/Core/Agent.swift#L153)

- setCanUseTool() writes under lock
  [`Agent.swift:166`](../../Sources/OpenAgentSDK/Core/Agent.swift#L166)

- Stream path: single lock acquisition reads both fields atomically (consistent snapshot)
  [`Agent.swift:1272`](../../Sources/OpenAgentSDK/Core/Agent.swift#L1272)

**E2E tests: SessionStore concurrent saves & delete**

- Concurrent saves with data integrity verification (content is "Save 1" or "Save 2")
  [`SessionStoreE2ETests.swift:175`](../../Sources/E2ETest/SessionStoreE2ETests.swift#L175)

- Delete existing + nonexistent session coverage
  [`SessionStoreE2ETests.swift:218`](../../Sources/E2ETest/SessionStoreE2ETests.swift#L218)

**Unit test: concurrent registerModel**

- 100 concurrent registrations via DispatchGroup, verifies all land and cleanup restores count
  [`ModelInfoTests.swift:131`](../../Tests/OpenAgentSDKTests/Types/ModelInfoTests.swift#L131)

**Documentation: deferred-work.md updates**

- 5 items marked FIXED (SessionMetadata, Hook logging, MODEL_PRICING race, Agent options race, E2E coverage), 2 new deferred items from review
  [`deferred-work.md`](../../_bmad-output/implementation-artifacts/deferred-work.md)
