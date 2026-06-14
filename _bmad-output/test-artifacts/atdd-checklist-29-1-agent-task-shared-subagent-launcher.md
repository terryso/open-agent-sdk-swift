# ATDD Red-Phase Checklist — Story 29.1: Agent / Task Shared Subagent Launcher

- **Story ID:** 29-1
- **Epic:** 29 (Claude Code Skill/Subagent Compatibility)
- **Phase:** RED (TDD red-green-refactor)
- **Mode:** yolo (auto-approval)
- **Date:** 2026-06-14
- **Test File:** `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` (extended)
- **Story Spec:** `_bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md`

## Acceptance Criteria → Test Mapping

| AC | Description | Test Name | Priority | Red? |
|----|-------------|-----------|----------|------|
| AC1 | `createTaskTool()` returns `ToolProtocol` with `.name == "Task"`, non-empty description, `isReadOnly == false` | `testCreateTaskTool_returnsToolNamedTask` | P0 | YES — `cannot find 'createTaskTool'` |
| AC1 | Schema parity with Agent (same `properties` keys + same `required` array) | `testCreateTaskTool_schemaEquivalentToAgent` | P0 | YES — `cannot find 'createTaskTool'` |
| AC2 | Task tool happy path routes through `agentSpawner.spawn(...)` and returns text result | `testTaskTool_success_returnsTextResult` | P0 | YES — `cannot find 'createTaskTool'` |
| AC3 | Missing `agentSpawner` returns `ToolExecuteResult(isError: true)` with spawner mention; parity with Agent error | `testTaskTool_missingSpawner_returnsError` | P0 | YES — `cannot find 'createTaskTool'` |
| AC2 | `subagent_type: "Explore"` resolves via shared `BUILTIN_AGENTS` and passes Explore system prompt | `testTaskTool_exploreType_passesExploreSystemPrompt` | P0 | YES — `cannot find 'createTaskTool'` |
| AC4 | Tool-calls summary `[Tools used: Glob, Grep]` is appended when `toolCalls` is non-empty | `testTaskTool_toolCallsSummaryAppended` | P0 | YES — `cannot find 'createTaskTool'` |
| AC4 | Backward compatibility — `createAgentTool()` still returns name "Agent" and is not read-only | `testCreateAgentTool_stillWorks_noRegression` | P0 | NO (intentional guard rail — passes today, locks against future regression) |

## Red-Phase Verification

- `swift build --target OpenAgentSDK` → SUCCESS (SDK source has no `createTaskTool` symbol yet)
- `swift build --build-tests` → FAILURE on the 6 new Task tests, with errors:
  ```
  error: cannot find 'createTaskTool' in scope
  ```
- All 6 Task tests are blocked from compiling until the dev-story implementation lands. The backward-compat test (`testCreateAgentTool_stillWorks_noRegression`) compiles and passes today as a guard rail.

## Conventions Followed

- **XCTest only** (project-context.md rule #23)
- **Test location mirrors source** (rule #24): `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
- **Single-action test pattern** (CLAUDE.md E2E rule): each test exercises exactly one `tool.call(...)` invocation
- **Reused `MockSubAgentSpawner`** (rule #51) — no new mock type introduced
- **No `Task` Swift type introduced** (rule #15) — only tool-name string `"Task"` and function `createTaskTool()`
- **No throws from tool handler** (rule #39) — assertions verify `isError: true` rather than thrown errors
- **No force-unwrap on spawner guard** (rule #40) — `guard let` pattern is exercised via AC3 test
- **No `Core/` import added** (rule #41) — tests assert behavior through `ToolContext.agentSpawner` only

## Decisions

- **Test file choice:** Use existing `AgentToolTests.swift` (per Story Task 4.1). The story explicitly directs this; all 6 new tests live alongside the Agent tests in a `// MARK: - Task Tool (Story 29.1)` section.
- **Mock reuse:** Reuse `MockSubAgentSpawner` already defined in the same file — no new mock type created.
- **Context construction:** Use `ToolContext(cwd:, agentSpawner:)` initializer (same shape as existing Agent tests). The richer `makeTestToolContext()` from `GitTestHelpers.swift` is not needed — these tests don't exercise filesystem or git paths.

## Files Modified

- `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` — appended 7 test methods in a new `// MARK: - Task Tool (Story 29.1)` section (6 RED + 1 guard rail)

## Next Steps

- Hand off to **bmad-dev-story** to implement the GREEN phase:
  1. Extract private `createSubAgentLauncherTool(name:description:)` helper in `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift`
  2. Reimplement `createAgentTool()` as thin wrapper
  3. Add public `createTaskTool()` factory
  4. Update DocC comment in `OpenAgentSDK.swift` to list `createTaskTool()`
- After GREEN, re-run `swift test --filter AgentToolTests` to confirm all 7 new tests pass.
