# Story 29.1: `Agent` / `Task` 共享子代理启动器

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Claude Code-compatible SDK consumer,
I want `Task` to behave as an alias of `Agent`,
So that existing workflow skills can spawn subagents without rewriting their prompts.

## Acceptance Criteria

1. **AC1: createTaskTool() returns a ToolProtocol with name "Task"**
   - **Given** the SDK is built
   - **When** `createTaskTool()` is invoked
   - **Then** it returns a `ToolProtocol` whose `.name == "Task"`
   - **And** `.description`, `.isReadOnly`, and `.inputSchema` are equivalent to `createAgentTool()`'s output (modulo the tool name)
   - **And** `createAgentTool()` continues to return a tool named `"Agent"` (no regression of public API)

2. **AC2: Task tool routes through the same execution path as Agent**
   - **Given** the tool pool registers `createTaskTool()` and `ToolContext.agentSpawner` is non-nil
   - **When** the LLM calls `Task(prompt:, description:)` (optionally with `subagent_type`, `model`, `maxTurns`, `run_in_background`, `isolation`, `team_name`, `mode`, `resume`)
   - **Then** the call path is identical to `createAgentTool()`'s execution body
   - **And** the same `BUILTIN_AGENTS` resolution, `PermissionMode` parsing, and `spawner.spawn(...)` invocation are exercised
   - **And** the result is the child agent text plus the `[Tools used: ...]` summary when `result.toolCalls` is non-empty

3. **AC3: Missing spawner produces an equivalent error**
   - **Given** the `Task` tool is registered but `ToolContext.agentSpawner == nil`
   - **When** the tool is called
   - **Then** it returns a `ToolExecuteResult` with `isError: true`
   - **And** the error message mentions that the subagent spawner is missing/not available
   - **And** the error message is identical (except for tool-name token) to the one returned by `Agent` under the same condition

4. **AC4: Public API surface and backward compatibility**
   - **Given** the SDK is built
   - **When** a host imports `OpenAgentSDK`
   - **Then** both `createAgentTool()` and `createTaskTool()` are accessible as public functions
   - **And** the Swift type name used for the tool input is **not** `TaskToolInput` and **not** `Task` — it must be a non-conflicting name (recommended: shared private `AgentToolInput` reused as-is, or `SubAgentLauncherInput` if extracted)
   - **And** all existing tests continue to pass (zero regression)

5. **AC5: Test coverage**
   - **Given** the SDK test suite runs
   - **When** the new `createTaskTool()` tests are executed
   - **Then** they cover: tool name == "Task", schema equivalence with `Agent`, happy-path spawn via mock spawner, spawner-error propagation, missing-spawner error, and built-in `subagent_type` resolution
   - **And** the full suite passes with the new tests included

## Tasks / Subtasks

- [x] Task 1: Refactor shared factory inside `AgentTool.swift` (AC: #1, #2)
  - [x] 1.1 Extract a `private func createSubAgentLauncherTool(name:description:) -> ToolProtocol` helper inside `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` that wraps the existing `defineTool` body
  - [x] 1.2 The helper must accept the tool `name` (`"Agent"` or `"Task"`) and the human-facing `description` as parameters; everything else (schema, input type, execute closure) is shared
  - [x] 1.3 Keep the existing private `AgentToolInput` struct as the shared Codable input type — do **not** introduce a `TaskToolInput` type and do **not** rename `AgentToolInput` to `Task` (Swift Concurrency conflict — see project-context.md rule #15)
  - [x] 1.4 If a more descriptive name is desired for the input type per epic guidance, use `SubAgentLauncherInput` (file-scope rename); this is **optional** for 29.1, leaving it as `AgentToolInput` is also acceptable

- [x] Task 2: Add `createTaskTool()` public factory (AC: #1, #2)
  - [x] 2.1 Inside `AgentTool.swift`, add a new public function:
    ```swift
    /// Creates the Task tool — a Claude Code-compatible alias of ``createAgentTool()``.
    ///
    /// `Task` shares the same schema, execution body, and output format as the `Agent` tool.
    /// Existing Claude Code workflow skills that emit `Task(subagent_type:, description:, prompt:)`
    /// snippets can run unmodified once this tool is registered.
    ///
    /// - Returns: A ``ToolProtocol`` instance for the Task tool.
    public func createTaskTool() -> ToolProtocol {
        return createSubAgentLauncherTool(
            name: "Task",
            description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets."
        )
    }
    ```
  - [x] 2.2 Re-implement `createAgentTool()` as a thin wrapper that calls `createSubAgentLauncherTool(name: "Agent", description: <existing Agent description>)` — preserves backward-compatible public behavior
  - [x] 2.3 The descriptions may differ between `Agent` and `Task` (Task's can mention "Claude Code-compatible alias"), but the schema and execute closure MUST be shared

- [x] Task 3: Export `createTaskTool()` from the module surface (AC: #4)
  - [x] 3.1 Update `Sources/OpenAgentSDK/OpenAgentSDK.swift` DocC comment in the "Sub-Agent Spawning" section to list `createTaskTool()` alongside `createAgentTool()`
  - [x] 3.2 Public functions are auto-exported at module scope — no `@_exported` is needed; only the DocC catalog entry is updated

- [x] Task 4: Add unit tests (AC: #5)
  - [x] 4.1 Extend `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` (reuse the existing `MockSubAgentSpawner` already defined in this file — do **not** create a new mock type)
  - [x] 4.2 Add a focused test section `// MARK: - Task Tool (Story 29.1)` with the following cases:
    - `testCreateTaskTool_returnsToolNamedTask` — verifies `.name == "Task"`, non-empty description, `.isReadOnly == false`
    - `testCreateTaskTool_schemaEquivalentToAgent` — verifies both tools expose the same `properties` keys (`prompt`, `description`, `subagent_type`, `model`, `name`, `maxTurns`, `run_in_background`, `isolation`, `team_name`, `mode`, `resume`) and the same `required` array
    - `testTaskTool_success_returnsTextResult` — registers mock spawner, calls `Task(prompt:, description:)`, asserts success and expected output
    - `testTaskTool_missingSpawner_returnsError` — invokes `Task` with `ToolContext(cwd:, agentSpawner: nil)`, asserts `isError: true` and message contains "spawner"
    - `testTaskTool_exploreType_passesExploreSystemPrompt` — calls `Task(subagent_type: "Explore", ...)`, asserts `mockSpawner.lastCall?.systemPrompt` matches the Explore built-in prompt
    - `testTaskTool_toolCallsSummaryAppended` — asserts that when `SubAgentResult.toolCalls == ["Glob", "Grep"]`, the output ends with `[Tools used: Glob, Grep]`
  - [x] 4.3 Reuse `makeTestToolContext()` from `Tests/OpenAgentSDKTests/GitTestHelpers.swift` only if a richer context is needed; the existing tests in this file use the simpler `ToolContext(cwd:agentSpawner:)` initializer which is fine here (single-action invocation, no fs/git operations)
  - [x] 4.4 Follow single-action test pattern — each test exercises exactly one tool invocation; do **not** test multi-turn LLM flows in these unit tests

- [x] Task 5: Verify build, type system, and full regression (AC: #4, #5)
  - [x] 5.1 `swift build` succeeds with zero warnings introduced by this story
  - [x] 5.2 `swift test` runs the full suite and reports the new total test count in completion notes
  - [x] 5.3 Confirm no Swift compiler error references a type named `Task` (if any appear, the input type was wrongly named — fix by keeping it as `AgentToolInput`)

## Dev Notes

### Architecture Context

This is **Story 1 of 7 in Epic 29** (Claude Code Skill/Subagent Compatibility). It provides the foundational `Task` alias that downstream stories (29.2 spawner detection, 29.3 skill package context, 29.4 tool declarations, 29.5 shared filtering, 29.6 diagnostics, 29.7 tests/docs) will build upon.

**Epic 29 implementation readiness was verified on 2026-06-14** (see `_bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md`). All 7 "current code facts" claims in the epic were validated against source. Epic 29 is one of the best-prepared epics in project history.

### CRITICAL: Swift Type Naming Constraint (project-context.md rule #15)

**Never name any Swift type `Task`.** Swift Concurrency's `Task` symbol would shadow/conflict with it. The tool name **string** `"Task"` is fine (it's a runtime identifier, not a Swift type). Specifically:

- ✅ Allowed: tool whose `.name == "Task"`
- ✅ Allowed: function `createTaskTool()`
- ✅ Allowed: keep the private input type named `AgentToolInput` (no rename needed)
- ✅ Allowed: rename the input type to `SubAgentLauncherInput` (if extraction is desired)
- ❌ Forbidden: a Swift `struct Task`, `enum Task`, `final class TaskToolInput`, `typealias Task = ...`

### CRITICAL: Terminology Disambiguation

PRD FR17 was annotated on 2026-06-14 to clarify that two distinct concepts share the `Task*` prefix:

| Concept | Backing | Tool Names |
|---|---|---|
| **Subagent launcher alias (this story)** | `SubAgentSpawner` (Core/) | `Task` |
| **Task management tools (Epic 4)** | `TaskStore` actor (Stores/) | `TaskCreate`, `TaskList`, `TaskUpdate`, `TaskGet`, `TaskStop`, `TaskOutput` |

No runtime collision: tool-name strings `"Task"` and `"TaskCreate"` are distinct. Do not conflate the two when writing docs.

### Shared Factory Pattern (Refactor Goal)

The current `createAgentTool()` body is ~45 lines including the spawner guard, `BUILTIN_AGENTS` lookup, `PermissionMode` parsing, `spawner.spawn(...)`, and output formatting. This story extracts that body into a private `createSubAgentLauncherTool(name:description:)` helper, then both `createAgentTool()` and `createTaskTool()` become one-line wrappers.

**Two acceptable refactor shapes** (pick whichever fits the existing code structure cleanest):

**Option A — closure-returning helper (minimal change):**
```swift
private func createSubAgentLauncherTool(name: String, description: String) -> ToolProtocol {
    return defineTool(
        name: name,
        description: description,
        inputSchema: agentToolSchema,
        isReadOnly: false
    ) { (input: AgentToolInput, context: ToolContext) async throws -> ToolExecuteResult in
        // ... existing 45-line body unchanged ...
    }
}

public func createAgentTool() -> ToolProtocol {
    return createSubAgentLauncherTool(
        name: "Agent",
        description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets."
    )
}

public func createTaskTool() -> ToolProtocol {
    return createSubAgentLauncherTool(
        name: "Task",
        description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets. Claude Code-compatible alias of the Agent tool."
    )
}
```

**Option B — pre-built execute closure** (slightly more verbose but makes sharing explicit):
same idea, factor the `(input, context) async throws -> ToolExecuteResult` closure into a private `let subAgentLauncherExecute: (...) async throws -> ToolExecuteResult = { ... }` constant, then pass to both `defineTool` calls.

Prefer Option A unless there's a concrete reason for B.

### Module Boundary Compliance

Per project-context.md rule #7 (architecture layering) and rule #41 (anti-pattern: `Tools/` never imports `Core/`):

- `AgentTool.swift` lives in `Tools/Advanced/` and **must not** import `Core/`
- It accesses spawner functionality indirectly through `ToolContext.agentSpawner: (any SubAgentSpawner)?` — the protocol is declared in `Types/`
- This story adds **zero new module imports** — it only refactors within a single file and exports one new public function

### SubAgentSpawner Protocol (already exists — do NOT touch)

`Sources/OpenAgentSDK/Types/ToolTypes.swift:285` defines:
```swift
public let agentSpawner: (any SubAgentSpawner)?
```
The protocol `SubAgentSpawner` is already public in Types/; `createTaskTool()` consumes it via the exact same code path as `createAgentTool()`. No spawner protocol changes are needed in this story.

**Important: Story 29.2 will update `Agent.createSubAgentSpawner(...)` in Core/ to detect `Task` in addition to `Agent`. Story 29.1 does NOT make that change — but if a host registers only `createTaskTool()` (no `createAgentTool()`), the spawner will not be injected until 29.2 is implemented. This is expected. Tests in 29.1 inject the mock spawner directly via `ToolContext(cwd:, agentSpawner:)`.**

### Existing Test Infrastructure to Reuse

`Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` already defines:

- `final class MockSubAgentSpawner: SubAgentSpawner, @unchecked Sendable` — records spawn calls, returns a configurable `SubAgentResult`
- The mock's `lastCall: SpawnCall?` property exposes all 13 parameters for assertion (prompt, model, systemPrompt, allowedTools, maxTurns, disallowedTools, mcpServers, skills, runInBackground, isolation, name, teamName, mode, resume)
- The mock already supports the full `spawn(prompt:model:systemPrompt:allowedTools:maxTurns:disallowedTools:mcpServers:skills:runInBackground:isolation:name:teamName:mode:resume:)` signature

**Do not create a new mock.** Reuse `MockSubAgentSpawner` for all `createTaskTool()` tests.

### Files to Modify/Create

- **UPDATE**: `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift`
  - Extract private `createSubAgentLauncherTool(name:description:)` helper
  - Reimplement `createAgentTool()` as a thin wrapper (preserve existing public signature and behavior)
  - Add public `createTaskTool()` factory
  - Keep private `AgentToolInput` struct unchanged (or optionally rename to `SubAgentLauncherInput`)
  - Keep private `agentToolSchema` constant unchanged (shared between both tools)
  - Keep private `BUILTIN_AGENTS` dictionary unchanged
- **UPDATE**: `Sources/OpenAgentSDK/OpenAgentSDK.swift`
  - Add `createTaskTool()` entry to the "Sub-Agent Spawning" DocC section (documentation comment only — no code change needed, public functions are auto-exported)
- **UPDATE**: `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
  - Add new `// MARK: - Task Tool (Story 29.1)` section with 6 test methods (see Task 4.2)

**No new files are created in this story.** All work is refactor + additive.

### Project Structure Notes

- Tool factories belong in `Tools/Advanced/` per project-context.md rule #35 (Advanced subdirectory holds multi-agent tools)
- This story adds one new public symbol (`createTaskTool()`) without violating module boundaries
- No new types are introduced; existing `AgentToolInput` (or renamed `SubAgentLauncherInput`) remains private to the file
- No `.docc` documentation files need updating for this story (DocC catalog will auto-pick up the new public function from the module-level comment in OpenAgentSDK.swift)

### Anti-Patterns to Avoid (project-context.md)

- ❌ Do **not** throw from the tool handler — return `ToolExecuteResult(isError: true)` (rule #39)
- ❌ Do **not** use force-unwrap (`!`) — use `guard let` / `if let` (rule #40)
- ❌ Do **not** import `Core/` from `Tools/` (rule #41)
- ❌ Do **not** name the input type `Task` (rule #15 — Swift Concurrency conflict)
- ❌ Do **not** create a separate mock type for tests — reuse `MockSubAgentSpawner` (rule #51)
- ❌ Do **not** use `Set` for ordered collections — keep using `Array` (rule #46)

### Testing Standards

- XCTest only (rule #23)
- Test directory mirrors source: `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` (rule #24)
- Use `await` for actor-isolated methods (rule #26)
- Single-action test prompts: each test exercises exactly one `tool.call(...)` invocation; do not chain multiple LLM calls in a single test (this is a unit test, not E2E)
- E2E tests are **optional** per rule #29 and must use the real environment. For Story 29.1 the unit tests above are sufficient; E2E can be added in Story 29.7.

### Previous Story Intelligence (Epic 28 retrospective)

Epic 28 (SSE Bridge + Token Streaming) completed with 6016 tests passing. Key learnings that apply here:

- Stateless mapping helpers (`enum` with static functions) work well in `Utils/` and `Types/` — but this story's helper is a tool factory, which belongs in `Tools/Advanced/`
- The `EventBus` publish pattern (Epic 27) established that Core/ can publish events without Tools/ knowing — same boundary applies here (`AgentTool` is unaware of EventBus; events flow through spawner)
- All recent stories follow the pattern of "extract shared helper, then expose as new public function" — this story mirrors that shape exactly

### Git Intelligence (recent commits)

```
3a42f5c fix: surface SSE error messages in errorDuringExecution result
4506dcf fix: BashTool terminate child process on Task cancellation
d6e5e44 fix: parseFrontmatter handle YAML quoted strings and block scalars
be94b37 fix: retry on network-layer errors (statusCode 0)
99e3788 feat: add lastTurnInputTokens to ResultData and QueryResult
```

Recent commits are all bug fixes and small enhancements. No architectural changes that affect this story. The last major feature commit pattern (`feat: ...`) is the right shape for the dev-story commit that will implement 29.1.

### Dependencies and Blockers

**This story has no upstream dependencies** — it modifies only `AgentTool.swift` (which exists and is stable), `OpenAgentSDK.swift` (DocC comment only), and the existing test file.

**This story unblocks**:
- Story 29.2 (Spawner detection must recognize the `Task` tool name this story introduces)
- Story 29.3 (Direct skill package context — orthogonal but shares the same file region)
- Story 29.4 (Tool declaration compatibility will reference `Task` as a known LLM-facing tool name)

### Out of Scope (Deferred to Later Stories)

- `Agent.createSubAgentSpawner(...)` updating to detect `Task` → **Story 29.2**
- `DefaultSubAgentSpawner.filterTools(...)` removing both `Agent` and `Task` from child pool → **Story 29.2**
- `resolveSkillForExecution` package-context prompt → **Story 29.3**
- Richer `ToolDeclaration` model → **Story 29.4**
- Shared filtering helper in `Types/ToolDeclaration.swift` → **Story 29.5** (location decided 2026-06-14)
- Deferred field diagnostics (`run_in_background`, `resume`, `isolation`, `team_name`, `skills`) → **Story 29.6**
- E2E tests and DocC article updates → **Story 29.7**
- Filesystem subagent loader (`.claude/agents/*.md`) → **future epic**

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.1] — story definition and ACs
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — Swift type name constraint, module boundary, backward compatibility, no silent escalation
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md] — readiness verdict READY_WITH_ACTIONS, all 7 code facts verified
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md#Step 5：跨文档对齐] — traceability matrix mapping FR11/FR17/FR35 → 29.1 → `Tools/Advanced/AgentTool.swift`
- [Source: _bmad-output/project-context.md#15] — tool implementation suffix rule and Swift naming rules
- [Source: _bmad-output/project-context.md#39-51] — anti-patterns: no throws, no force-unwrap, no Core/ imports, no Apple frameworks, reuse mocks
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:31-92] — existing `AgentToolInput` Codable struct (private, to be reused or renamed)
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:96-112] — existing `agentToolSchema` constant (shared between Agent and Task)
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:126-174] — existing `createAgentTool()` body to be extracted into shared helper
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift:285] — `ToolContext.agentSpawner: (any SubAgentSpawner)?` injection point
- [Source: Sources/OpenAgentSDK/OpenAgentSDK.swift:56-83] — DocC "Sub-Agent Spawning" section to extend with `createTaskTool()` entry
- [Source: Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift:8-93] — existing `MockSubAgentSpawner` to reuse
- [Source: _bmad-output/implementation-artifacts/28-1-agent-event-sse-event-mapping.md] — recent story template for reference (stateless helper pattern, file structure, test layout)

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.2 via Claude Code)

### Debug Log References

- `swift build` succeeded in 34.79s with zero warnings introduced by this story.
- `swift test` executed 5695 tests with 0 failures in 31.76s.
- All 6 previously-RED Story 29.1 Task tests now pass (GREEN).
- Existing 13 AgentTool tests continue to pass (no regression).
- No Swift compiler error references a type named `Task`.

### Completion Notes List

- Extracted `private func createSubAgentLauncherTool(name:description:) -> ToolProtocol` helper in `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` using Option A (closure-returning helper). The full ~45-line execution body (spawner guard, BUILTIN_AGENTS lookup, PermissionMode parsing, spawner.spawn, output formatting) is now shared between the `Agent` and `Task` tool variants.
- `createAgentTool()` is now a one-line wrapper delegating to the helper with `name: "Agent"` and the existing Agent description.
- `createTaskTool()` is a new public one-line wrapper delegating to the helper with `name: "Task"` and a Claude Code-compatible-alias description.
- Private input type kept as `AgentToolInput` (no rename) — rule #15 compliance: no Swift type named `Task`.
- Private schema constant renamed from `agentToolSchema` to `subAgentLauncherSchema` to reflect that it is now shared (the rename is local/private; no public-API impact).
- Missing-spawner error message now uses the tool `name` token so `Task` and `Agent` produce equivalent error messages (modulo the name token).
- Added `createTaskTool()` entry to the "Sub-Agent Spawning" DocC section in `Sources/OpenAgentSDK/OpenAgentSDK.swift`.
- Tests already existed in the file (RED phase complete prior to this run); implementation made them GREEN without modifying any test code.
- Total test count after this story: 5695 (was 5688 prior to RED phase adding the 7 Task tests, then +0 new tests in GREEN phase).

### File List

- MODIFIED: `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift`
  - Extracted private `createSubAgentLauncherTool(name:description:)` shared helper
  - Reimplemented `createAgentTool()` as a thin wrapper (backward compatible)
  - Added public `createTaskTool()` factory
  - Renamed private `agentToolSchema` constant to `subAgentLauncherSchema` (shared)
  - Kept private `AgentToolInput` Codable struct unchanged
  - Kept private `BUILTIN_AGENTS` dictionary unchanged
- MODIFIED: `Sources/OpenAgentSDK/OpenAgentSDK.swift`
  - Added `createTaskTool()` entry to "Sub-Agent Spawning" DocC catalog section
- UNCHANGED (RED phase tests already in place): `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
  - All 7 Task-related tests (6 new + 1 backward-compat) now pass against the new implementation

### Change Log

- 2026-06-14: Story 29.1 GREEN phase complete. Extracted shared subagent launcher factory; added `createTaskTool()` public alias. 5695 tests passing, 0 failures.
