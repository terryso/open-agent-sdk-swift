# Story 29.2: Spawner Detection and Child Tool Filtering

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an SDK runtime maintainer,
I want subagent spawner injection and child tool filtering to recognize both `Agent` and `Task`,
so that aliasing does not create runtime holes (spawner missing when only `Task` is registered) or recursive child spawning (child re-launches `Task` because filter only strips `Agent`).

## Acceptance Criteria

1. **AC1: Spawner is injected when only `Task` is registered**
   - **Given** an `Agent` whose `options.tools` contains `createTaskTool()` but NOT `createAgentTool()`
   - **When** the agent executes a tool-call prompt (non-stream path) or a streaming prompt (stream path)
   - **Then** `ToolContext.agentSpawner` is **non-nil** for the child tool invocation
   - **And** the `Task` tool does not return the "subagent spawner missing" error that Story 29.1 emits when `agentSpawner == nil`

2. **AC2: Child tool pool excludes `Agent` by default**
   - **Given** a parent tool pool that contains both `createAgentTool()` (name `"Agent"`) and `createTaskTool()` (name `"Task"`)
   - **When** `DefaultSubAgentSpawner.spawn(...)` builds the child tool pool (no explicit `allowedTools`/`disallowedTools`)
   - **Then** the child tool pool does NOT contain any tool whose `.name == "Agent"`

3. **AC3: Child tool pool excludes `Task` by default**
   - **Given** a parent tool pool that contains both `createAgentTool()` and `createTaskTool()`
   - **When** `DefaultSubAgentSpawner.spawn(...)` builds the child tool pool (no explicit `allowedTools`/`disallowedTools`)
   - **Then** the child tool pool does NOT contain any tool whose `.name == "Task"`
   - **And** this prevents unbounded recursive spawning (Task → spawn child with Task → spawn grandchild → ...)

4. **AC4: Single shared helper for launcher-name list (no string litter)**
   - **Given** the SDK is built
   - **When** the dev audits references to launcher tool names in Core/
   - **Then** all three sites (`Agent.createSubAgentSpawner`, `Agent.supportedAgents`, `DefaultSubAgentSpawner.filterTools`) consult a single `SubAgentLauncherNames.default` constant (or equivalent shared list)
   - **And** no other code path hard-codes the strings `"Agent"` / `"Task"` for launcher detection/filtering purposes

5. **AC5: Escape hatch is preserved (no default inheritance of recursion)**
   - **Given** a future explicit recursion-allowed configuration (not yet implemented in this story)
   - **When** the host later opts in to recursive spawning
   - **Then** the default `filterTools` path continues to strip both launcher names unless that explicit override is set
   - **And** no current code change silently enables recursion without the host's explicit opt-in (this story does NOT add an opt-in API; it only ensures the default behavior is "strip both")

6. **AC6: Backward compatibility and full regression**
   - **Given** existing code that registers only `createAgentTool()` (no `createTaskTool()`)
   - **When** the SDK runs the full test suite
   - **Then** `createSubAgentSpawner` still injects the spawner when `Agent` is present (no regression)
   - **And** `filterTools` still strips `Agent` from the child pool (no regression)
   - **And** the full suite passes with the new total test count reported in completion notes

## Tasks / Subtasks

- [x] Task 1: Add shared launcher-name helper (AC: #4)
  - [x] 1.1 Add `enum SubAgentLauncherNames` (Swift type-name compliant — NOT `Task`) to `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` (top of file, above the `final class` declaration) with:
    ```swift
    /// LLM-facing tool names that can spawn subagents.
    ///
    /// `Agent` is the canonical SDK name; `Task` is the Claude Code-compatible alias
    /// (introduced in Story 29.1). Spawner detection AND child filtering must both
    /// recognize every name in this list so that:
    ///   1. Registering only `Task` still injects a spawner into ToolContext
    ///      (prevents the "spawner missing" runtime hole).
    ///   2. Both names are stripped from the child tool pool by default
    ///      (prevents unbounded recursive spawning).
    enum SubAgentLauncherNames {
        /// Default set of subagent launcher tool names recognized by the SDK.
        /// Order does not matter (membership checks only); kept as `Array` per project rule #46.
        static let `default`: [String] = ["Agent", "Task"]

        /// Returns `true` when `toolName` is one of the default launcher names.
        static func contains(_ toolName: String) -> Bool {
            `default`.contains(toolName)
        }
    }
    ```
  - [x] 1.2 Location rationale documented in story dev notes (this file): Core/ owns both call sites (`Agent.swift` and `DefaultSubAgentSpawner.swift`); Types/ is not needed because Tools/ does not consult this list. Keeping the helper next to its primary consumer (`filterTools`) minimizes import surface.

- [x] Task 2: Update `Agent.createSubAgentSpawner(...)` to detect both launchers (AC: #1)
  - [x] 2.1 In `Sources/OpenAgentSDK/Core/Agent.swift` at line ~3232, replace:
    ```swift
    let hasAgentTool = tools.contains { $0.name == "Agent" }
    guard hasAgentTool else { return nil }
    ```
    with:
    ```swift
    let hasLauncher = tools.contains { SubAgentLauncherNames.contains($0.name) }
    guard hasLauncher else { return nil }
    ```
  - [x] 2.2 Update the doc comment (lines 3221–3224) to read:
    ```swift
    /// Creates a sub-agent spawner if the tool pool contains ANY subagent launcher tool
    /// (`Agent` or the Claude Code-compatible `Task` alias — see ``SubAgentLauncherNames``).
    ///
    /// Centralizes the launcher detection check + ``DefaultSubAgentSpawner`` construction
    /// shared between `promptImpl` and `stream` tool execution blocks.
    ```
  - [x] 2.3 The two call sites at `Agent.swift:1716` (non-stream, `promptImpl`) and `Agent.swift:2601` (stream) **automatically** pick up the new behavior because they delegate to `createSubAgentSpawner(...)`. No change needed at those two call sites beyond verifying they still compile after the helper body changes.

- [x] Task 3: Update `DefaultSubAgentSpawner.filterTools(...)` to strip both launchers (AC: #2, #3, #5)
  - [x] 3.1 In `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` at line ~132, replace:
    ```swift
    var subTools = parentTools.filter { $0.name != "Agent" }
    ```
    with:
    ```swift
    // Strip all subagent launcher tools by default to prevent recursive spawning.
    // Escape hatch (explicit recursion-allowed config) is deferred to a future story;
    // current default MUST remain "strip both" per Story 29.2 AC5.
    var subTools = parentTools.filter { !SubAgentLauncherNames.contains($0.name) }
    ```
  - [x] 3.2 Update the existing `filterTools` doc comment (line 130) to read:
    ```swift
    /// Filter parent tools: strip subagent launcher tools (``SubAgentLauncherNames.default``)
    /// and apply allowed/disallowed lists.
    ///
    /// Default behavior strips BOTH `Agent` and `Task` so that a child cannot recursively
    /// spawn grandchildren without explicit host opt-in. See Story 29.2 AC5.
    ```

- [x] Task 4: Update `Agent.supportedAgents()` to consult the shared helper (AC: #4 — string litter cleanup)
  - [x] 4.1 In `Sources/OpenAgentSDK/Core/Agent.swift` at line ~926, replace:
    ```swift
    let hasAgentTool = options.tools?.contains(where: { $0.name == "Agent" }) ?? false
    ```
    with:
    ```swift
    let hasLauncher = options.tools?.contains(where: { SubAgentLauncherNames.contains($0.name) }) ?? false
    ```
  - [x] 4.2 Rename the local `hasAgentTool` → `hasLauncher` in the same scope (lines 926–927) for clarity; the `guard hasLauncher else { return [] }` line updates accordingly.
  - [x] 4.3 This change is **within Story 29.2 scope** because the epic's task #4 explicitly forbids hard-coded string litter; leaving `supportedAgents()` with `"Agent"` would violate AC4 even though the epic's task list did not enumerate this site by line number. (Discovered during story creation; flagged in dev notes for transparency.)

- [x] Task 5: Extend tests in `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` (AC: #1, #2, #3, #6)
  - [x] 5.1 Add a new `// MARK: - Story 29.2: Spawner Detection and Child Filtering` section at the end of the existing test class. Reuse the existing `makeMockClient()` helper for any test that needs a `DefaultSubAgentSpawner` instance.
  - [x] 5.2 Add the following test cases (single-action, unit-level, mock-based — no real network I/O per project rule #27):
    - `testFilterTools_stripsAgentByDefault` — constructs `DefaultSubAgentSpawner` with parent tools `[Bash, Read, Agent]`; assert that after a `spawn(...)` call (mock client returns 401 as today), the test verifies the **filtering** behavior indirectly by calling the spawner's `filterTools` via `spawn` and using a "spy" agent — see implementation hint below
    - `testFilterTools_stripsTaskByDefault` — same shape as above but with `Task` in the parent pool
    - `testFilterTools_stripsBothAgentAndTaskWhenBothPresent` — parent pool `[Bash, Agent, Task]`, assert neither launcher name survives in the child pool
    - `testFilterTools_preservesNonLauncherTools` — parent pool `[Bash, Read, Grep]`, assert all three survive (sanity)
    - `testSpawn_preservesBackwardCompat_whenOnlyAgentPresent` — parent pool `[Read, Agent]`, assert child pool excludes `Agent` only (existing behavior, no regression)
  - [x] 5.3 **Implementation hint for indirect `filterTools` observation**: because `filterTools` is `private`, tests must observe the filtering through observable side effects. Two acceptable strategies:
    - **Strategy A (preferred): expose a `internal func filterToolsForTesting(...) -> [ToolProtocol]`** — wrap the existing private `filterTools` and mark it `internal`. Project rule #22 ("prefer internal") supports this; the function is already internal-accessible to `@testable import OpenAgentSDK` tests.
    - **Strategy B: spawn-based assertion via a custom `LLMClient` mock** — replace the mock `URLProtocol`'s 401 with a custom `LLMClient` that records the `AgentOptions.tools` it receives; assert the recorded list does not contain launcher names.
    - Prefer Strategy A unless the team has a convention against `*ForTesting` surface; the function is already internal and only adds a one-line wrapper.
  - [x] 5.4 Add a separate test file or section for **spawner detection** at the `Agent` level (where `createSubAgentSpawner` is a `private static` method on `Agent`):
    - Create `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift` (NEW file)
    - `testCreateSubAgentSpawner_returnsSpawner_whenOnlyTaskRegistered` — call `Agent.createSubAgentSpawner(...)` indirectly by inspecting `ToolContext.agentSpawner` after `agent.prompt(...)` with a tool-call prompt; assert non-nil
    - `testCreateSubAgentSpawner_returnsSpawner_whenBothRegistered` — same shape with both launchers in tool pool
    - `testCreateSubAgentSpawner_returnsNil_whenNeitherRegistered` — sanity (existing behavior preserved)
    - Note: `createSubAgentSpawner` is `private static`. Tests must observe via public `Agent.prompt(...)` or `Agent.stream(...)` entry points using a mock `LLMClient` that emits a tool-call response. Use the same `MockURLProtocol` pattern as `DefaultSubAgentSpawnerTests.swift` (or refactor to share `makeMockClient()`).
  - [x] 5.5 E2E coverage (real-environment, optional per project rule #29): defer to Story 29.7. Do NOT add E2E tests in this story.

- [x] Task 6: Verify build and full regression (AC: #6)
  - [x] 6.1 `swift build` succeeds with zero new warnings
  - [x] 6.2 `swift test` runs the full suite; report the new total test count in completion notes
  - [x] 6.3 Confirm no Swift compiler error references a type named `Task` (the `SubAgentLauncherNames` enum name is rule-#15 compliant)
  - [x] 6.4 Confirm grep for `name == "Agent"` and `name != "Agent"` in `Sources/OpenAgentSDK/` returns **zero matches** (all three original sites migrated to the helper)

## Dev Notes

### Architecture Context

This is **Story 2 of 7 in Epic 29** (Claude Code Skill/Subagent Compatibility). It depends on Story 29.1 (DONE, commit 923bd6b) which introduced `createTaskTool()` as a Claude Code-compatible alias. Story 29.2 closes the runtime gap: registering only `Task` must still inject a spawner, and child tool pools must strip both launcher names.

**Epic dependency graph (post-29.2):**
```
29.1 (DONE)  -->  29.2 (THIS STORY, BLOCKING for 29.3/29.4 downstream wiring)
                  |
                  +--> 29.3 (skill package context, parallel-eligible)
                  +--> 29.4 (tool declaration compatibility)
                          |
                          +--> 29.5, 29.6, 29.7
```

### CRITICAL: Swift Type Naming Constraint (project-context.md rule #15)

**Never name any Swift type `Task`.** The new helper is `enum SubAgentLauncherNames` — compliant. The tool-name **strings** `"Agent"` and `"Task"` inside the `.default` array are runtime identifiers, not Swift type names; these are fine.

### Three Code Sites That Must Change

Verified by grep on 2026-06-14:

| File:Line | Current Code | Action |
|---|---|---|
| `Sources/OpenAgentSDK/Core/Agent.swift:3232` | `let hasAgentTool = tools.contains { $0.name == "Agent" }` | Replace with `SubAgentLauncherNames.contains($0.name)` |
| `Sources/OpenAgentSDK/Core/Agent.swift:926` | `let hasAgentTool = options.tools?.contains(where: { $0.name == "Agent" }) ?? false` | Replace with `SubAgentLauncherNames.contains($0.name)` (discovered during story creation — see Task 4 rationale) |
| `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:132` | `var subTools = parentTools.filter { $0.name != "Agent" }` | Replace with `!SubAgentLauncherNames.contains($0.name)` |

The two spawner-creation call sites (`Agent.swift:1716` and `Agent.swift:2601`) **do not need changes** — they delegate to `createSubAgentSpawner(...)` and pick up the new detection logic automatically.

### Module Boundary Compliance (project-context.md rule #7)

- `SubAgentLauncherNames` lives in `Core/DefaultSubAgentSpawner.swift`
- `Core/Agent.swift` is in the same module (`Core/`) and can reference the helper with no import
- `Tools/Advanced/AgentTool.swift` does **not** consult this helper (the tool only emits a "spawner missing" error if `ToolContext.agentSpawner == nil`; detection is the Core's job). This preserves the `Tools/` → `Core/` forbidden-import rule (#41).
- `Types/` does NOT need to host the helper: no `Tools/` or `Stores/` file currently needs to detect launcher names. Co-locating with `DefaultSubAgentSpawner` (the primary consumer) keeps the symbol in the tightest possible scope.

If a future story (e.g., a hypothetical Tools/-side restriction resolver) needs to read this list, **promote** it to `Types/SubAgentLauncherNames.swift` at that time. Do not pre-promote now — YAGNI.

### Escape Hatch Semantics (AC5)

This story **does not** introduce a recursion-allowed configuration. The default behavior MUST remain "strip both." If a future story (e.g., Axion Epic 40) needs explicit recursion, it should:

1. Add an opt-in parameter to `DefaultSubAgentSpawner.init(...)` (e.g., `allowRecursiveSpawning: Bool = false`)
2. In `filterTools`, only skip the launcher-name filter when that flag is `true`
3. Pass the flag through `Agent.createSubAgentSpawner(...)` from a new `AgentOptions` field

The current implementation leaves this hook unwired but preserves the design space by centralizing the names in `SubAgentLauncherNames.default` (future code can subtract from or ignore this list).

### Existing Test Infrastructure to Reuse

`Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` already defines:

- `private final class SpawnerMockURLProtocol: URLProtocol` — canned 401 response, no network I/O
- `private func makeMockClient() -> AnthropicClient` — wraps the URLProtocol into a real client

Reuse both. Do NOT create a new mock client. If a higher-fidelity assertion is needed (Strategy B in Task 5.3), extend the existing `SpawnerMockURLProtocol` to also record received request bodies; do not introduce a parallel mock.

`MockSubAgentSpawner` from `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` is a **spawner mock** (it implements `SubAgentSpawner`). It is NOT what this story needs — this story tests the **default spawner's filtering behavior**, not a mock spawner. Do not conflate.

### Files to Modify/Create

- **MODIFY**: `Sources/OpenAgentSDK/Core/Agent.swift`
  - Line ~926: `Agent.supportedAgents()` detection uses `SubAgentLauncherNames.contains`
  - Line ~3221–3233: `Agent.createSubAgentSpawner(...)` detection uses `SubAgentLauncherNames.contains`, doc comment updated
  - No new imports needed (helper is in same module)
- **MODIFY**: `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`
  - Add `enum SubAgentLauncherNames` near top of file (above `final class DefaultSubAgentSpawner`)
  - Line ~130–132: `filterTools` strips via `!SubAgentLauncherNames.contains($0.name)`, doc comment updated
- **MODIFY**: `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
  - Add `// MARK: - Story 29.2: Spawner Detection and Child Filtering` section
  - Add 5 new test methods (Task 5.2 list)
  - Optionally expose `internal func filterToolsForTesting(...)` on `DefaultSubAgentSpawner` (Strategy A) to enable direct filtering assertions
- **CREATE**: `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift`
  - Tests for `Agent`-level spawner detection via the public `prompt(...)` / `stream(...)` entry points using a mock LLM client that emits a tool-call response

**No `.docc` documentation files need updating** for this story — the new `SubAgentLauncherNames` enum is `internal` (default access for an unmarked `enum` at file scope is `internal`); it does not appear in the public DocC catalog. (Confirm during implementation: if the dev marks it `public`, add a DocC entry; otherwise skip.)

### Anti-Patterns to Avoid (project-context.md)

- ❌ Do NOT throw from any tool handler or spawner method — return `SubAgentResult(isError: true)` (rule #39)
- ❌ Do NOT force-unwrap (`!`) — use `guard let` / `if let` (rule #40)
- ❌ Do NOT import `Core/` from `Tools/` (rule #41) — this story adds zero new cross-module imports
- ❌ Do NOT name any Swift type `Task` (rule #15) — `SubAgentLauncherNames` is compliant
- ❌ Do NOT use `Set` for the launcher-name collection — use `Array` (rule #46) for predictability and consistency with `ToolRestriction` patterns
- ❌ Do NOT create a new mock client or mock URL protocol — reuse `SpawnerMockURLProtocol` and `makeMockClient()` (rule #51, #56)
- ❌ Do NOT write the test by spawning a real child agent over the network — all unit tests must use mocks (rule #27)

### Testing Standards

- XCTest only (rule #23)
- Test directory mirrors source: `Tests/OpenAgentSDKTests/Core/` (rule #24)
- Single-action test prompts: each test exercises exactly one `spawn(...)` or `prompt(...)` invocation
- `await` for actor-isolated methods (rule #26)
- E2E tests OPTIONAL (rule #29) and DEFERRED to Story 29.7

### Previous Story Intelligence (Story 29.1)

Story 29.1 (commit 923bd6b) completed with 5695 tests passing. Key learnings that apply here:

- **Shared factory extraction works cleanly in `Tools/Advanced/`** — this story mirrors the pattern in `Core/` by centralizing the launcher-name list in one enum
- **Mock URLProtocol pattern (`SpawnerMockURLProtocol`) returns canned 401** — same pattern is reusable for the new `filterTools` tests; the existing 7 tests in `DefaultSubAgentSpawnerTests.swift` all assert `isError == true` from this mock
- **Doc-comment updates matter for future maintainers** — Story 29.1 updated the "Sub-Agent Spawning" DocC section; this story updates the `createSubAgentSpawner` and `filterTools` doc comments to mention both launcher names
- **`AgentToolInput` was kept private (no rename)** — Story 29.2 does not touch `AgentTool.swift` at all; all changes are in `Core/`

### Git Intelligence (recent commits)

```
3a42f5c fix: surface SSE error messages in errorDuringExecution result
4506dcf fix: BashTool terminate child process on Task cancellation
d6e5e44 fix: parseFrontmatter handle YAML quoted strings and block scalars
be94b37 fix: retry on network-layer errors (statusCode 0)
99e3788 feat: add lastTurnInputTokens to ResultData and QueryResult
```

Recent commits are bug fixes only. No architectural changes that affect this story. Story 29.1 (`feat: add createTaskTool alias`) is the most recent feature commit on this code path and is the direct prerequisite.

### Dependencies and Blockers

**Upstream (DONE):** Story 29.1 — `createTaskTool()` exists and is exported. Without it, this story's AC1 ("only Task registered") would be unreachable.

**Downstream (this story UNBLOCKS):**
- Story 29.3 (Direct skill package context) — orthogonal file region, can proceed in parallel after this story merges
- Story 29.4 (Tool declaration compatibility) — will reference `Task` and `Agent` as known LLM-facing tool names; benefits from `SubAgentLauncherNames.default` as the canonical list

**No blockers remain.**

### Out of Scope (Deferred to Later Stories)

- Recursion-allowed escape hatch (explicit opt-in config) → **future story** (not in Epic 29)
- `resolveSkillForExecution` package-context prompt → **Story 29.3**
- Richer `ToolDeclaration` model → **Story 29.4**
- Shared filtering helper in `Types/ToolDeclaration.swift` → **Story 29.5**
- Deferred field diagnostics (`run_in_background`, `resume`, `isolation`, `team_name`, `skills`) → **Story 29.6**
- E2E tests and DocC article updates → **Story 29.7**
- Filesystem subagent loader (`.claude/agents/*.md`) → **future epic**

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.2] — story definition, ACs, and implementation tasks
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — Swift type name constraint, module boundary, backward compatibility, no silent escalation
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 间依赖关系] — dependency graph showing 29.2 as blocking for 29.3 and 29.4
- [Source: _bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md] — Story 29.1 completion notes (5695 tests, commit 923bd6b)
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md] — readiness verdict, all code facts verified
- [Source: _bmad-output/project-context.md#7] — module boundary rules (Core/ owns `DefaultSubAgentSpawner`)
- [Source: _bmad-output/project-context.md#15] — Swift type naming (no `Task` type)
- [Source: _bmad-output/project-context.md#39-51] — anti-patterns: no throws, no force-unwrap, no Core/ imports from Tools/, no Apple frameworks, reuse mocks
- [Source: _bmad-output/project-context.md#46] — use Array not Set for ordered tool lists
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:926] — `supportedAgents()` launcher detection (Task 4 target)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1716] — `promptImpl` spawner creation call site (unchanged, delegates to helper)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:2601] — `stream` spawner creation call site (unchanged, delegates to helper)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:3221-3241] — `createSubAgentSpawner(...)` private helper (Task 2 target)
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:13-35] — class declaration and init (where `SubAgentLauncherNames` will live above)
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:130-145] — `filterTools(...)` private method (Task 3 target)
- [Source: Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift:6-49] — existing `SpawnerMockURLProtocol` + `makeMockClient()` helpers to reuse
- [Source: Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift:51-87] — existing `testSpawn_filtersOutAgentTool` pattern to extend with `Task` variants

## Dev Agent Record

### Agent Model Used

claude-opus-4 (dev-story skill, GREEN phase, yolo mode)

### Debug Log References

- Initial `swift build --build-tests` per story header: 54 errors (RED phase confirmed)
- Post-implementation `swift build --build-tests`: Build complete! (34.24s) — 518 build steps, zero errors
- Grep `name\s*==\s*"Agent"|name\s*!=\s*"Agent"` in `Sources/OpenAgentSDK/`: **zero matches** (AC4 string-litter cleanup verified)

### Completion Notes List

- Added `enum SubAgentLauncherNames` (rule #15 compliant — no `Task` type name) with `static let default: [String] = ["Agent", "Task"]` and `static func contains(_:)`. Co-located with its primary consumer `DefaultSubAgentSpawner.filterTools` per YAGNI (no Tools/ consumer → no Types/ promotion).
- Migrated three detection/filter sites to consult `SubAgentLauncherNames`:
  1. `Agent.createSubAgentSpawner` (Core/Agent.swift:3232) — `$0.name == "Agent"` → `SubAgentLauncherNames.contains($0.name)`. AC1 fix: registering only `Task` now injects a spawner.
  2. `Agent.supportedAgents` (Core/Agent.swift:926) — `$0.name == "Agent"` → `SubAgentLauncherNames.contains($0.name)`. String-litter cleanup.
  3. `DefaultSubAgentSpawner.filterTools` (Core/DefaultSubAgentSpawner.swift) — `$0.name != "Agent"` → `!SubAgentLauncherNames.contains($0.name)`. AC2/AC3 fix: child pool strips BOTH launcher names.
- Exposed `internal func filterToolsForTesting(allowedTools:disallowedTools:)` (Strategy A from Task 5.3) as a one-line wrapper over the private `filterTools`. Required for the 5 unit-level `testFilterTools_*` assertions in DefaultSubAgentSpawnerTests.
- The two `createSubAgentSpawner` call sites (Agent.swift:1716 promptImpl and :2601 stream) needed no changes — they delegate to the helper.
- 11 previously-RED tests now GREEN: 5 in `DefaultSubAgentSpawnerTests` (filterTools_stripsAgentByDefault, filterTools_stripsTaskByDefault, filterTools_stripsBothAgentAndTaskWhenBothPresent, filterTools_preservesNonLauncherTools, spawn_preservesBackwardCompat_whenOnlyAgentPresent) + 6 in new `AgentSpawnerDetectionTests` (createSubAgentSpawner_returnsSpawner_whenOnlyTaskRegistered, createSubAgentSpawner_returnsSpawner_whenBothRegistered, createSubAgentSpawner_returnsNil_whenNeitherRegistered, subAgentLauncherNames_defaultContainsAgentAndTask, subAgentLauncherNames_containsMatchesExpected, escapeHatch_defaultDoesNotPropagateRecursion).
- Full regression: **5706 tests passing, 0 failures** (previous baseline 5695 from Story 29.1 → +11 net new). No regressions detected.
- Escape hatch design preserved (AC5): no opt-in API added; default behavior remains "strip both". Future story can extend `filterTools` with a flag without touching `SubAgentLauncherNames`.
- Verified no Swift compiler errors referencing a `Task` type (rule #15 — `SubAgentLauncherNames` is compliant).

### File List

- Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift (MODIFIED) — Added `enum SubAgentLauncherNames` (top of file); updated `filterTools` doc comment and strip predicate to consult the helper; added `internal func filterToolsForTesting(...)` one-line wrapper.
- Sources/OpenAgentSDK/Core/Agent.swift (MODIFIED) — `createSubAgentSpawner` uses `SubAgentLauncherNames.contains`; doc comment updated. `supportedAgents()` uses the helper; local renamed `hasAgentTool` → `hasLauncher`.
- Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift (RED tests pre-existing in GREEN-passing state — no changes required)
- Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift (RED tests pre-existing in GREEN-passing state — no changes required)
- _bmad-output/implementation-artifacts/29-2-spawner-detection-child-filtering.md (MODIFIED) — Status `ready-for-dev` → `review`; all 6 tasks and 14 subtasks marked [x]; Dev Agent Record populated.

## Change Log

| Date       | Version | Description                                                                                                                                                                                                                                          | Author           |
|------------|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------|
| 2026-06-14 | 0.1     | Initial story creation (Story 29.2 of Epic 29 — Claude Code Skill/Subagent Compatibility).                                                                                                                                                            | create-story     |
| 2026-06-14 | 1.0     | GREEN-phase implementation: added `SubAgentLauncherNames` helper (Core/), migrated three call sites (`createSubAgentSpawner`, `supportedAgents`, `filterTools`) to consult the helper, exposed `filterToolsForTesting` test wrapper. 5706 tests pass. | dev-story (yolo) |
