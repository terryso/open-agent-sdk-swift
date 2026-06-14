---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-14'
storyId: '29.6'
storyKey: 29-6-diagnostics-deferred-subagent-fields
storyFile: _bmad-output/implementation-artifacts/29-6-diagnostics-deferred-subagent-fields.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-29-6-diagnostics-deferred-subagent-fields.md
generatedTestFiles:
  - Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift
  - Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/29-6-diagnostics-deferred-subagent-fields.md
  - _bmad-output/project-context.md
  - _bmad/tea/config.yaml
detectedStack: backend
generationMode: ai-generation
redPhaseMode: compile-time
---

# ATDD Checklist: Story 29.6 — Diagnostics for Deferred Subagent Fields

## Story Summary

Story 29.6 of Epic 29 (Claude Code Skill/Subagent Compatibility) introduces runtime
diagnostics for subagent fields accepted by schema but not fully wired at runtime
(`run_in_background`, `resume`, `isolation`, `team_name`, `skills`, unresolved MCP
server `.reference`s). The story adds:

- `SubAgentFieldDiagnostics` struct + `SubAgentFieldDiagnosticReason` enum in `Types/AgentTypes.swift`
- `SubAgentResult.fieldDiagnostics: [SubAgentFieldDiagnostics]?` field (default `nil`, backward compatible)
- `DefaultSubAgentSpawner.collectFieldDiagnostics(...)` private helper + propagation through `executeAgent` / `mapQueryResultToSubAgentResult`
- `createSubAgentLauncherTool` rendering branch (diagnostics block between `result.text` and `[Tools used: ...]`)

Out of scope: real background/resume/isolation/team/skills/reference runtime semantics
(deferred to later stories per epic plan). This story only surfaces diagnostics.

## TDD Red Phase (Generated)

Red-phase test scaffolds were generated before implementation. Tests asserted
EXPECTED behavior and originally failed at compile-time until the implementation
types existed (Swift/XCTest adaptation of the JS `test.skip()` red-phase pattern;
there is no `test.skip()` in XCTest, so the equivalent is "test references missing
symbols").

- Unit tests (Core): **13 new tests** added to `DefaultSubAgentSpawnerTests.swift`
- Unit tests (Tools/Advanced): **5 new tests** + 1 mock helper added to `AgentToolTests.swift`
- Total new red-phase tests: **18**
- All tests reference `SubAgentFieldDiagnostics`, `SubAgentFieldDiagnosticReason`,
  or the `fieldDiagnostics:` parameter that does not exist yet in source

### Red Phase Verification

Before implementation, `swift build --target OpenAgentSDKTests` failed with errors like:

```
error: cannot find 'SubAgentFieldDiagnostics' in scope
error: cannot infer contextual base in reference to member 'backgroundExecutionNotImplemented'
error: cannot infer contextual base in reference to member 'resumeNotImplemented'
```

The `OpenAgentSDK` target itself compiles — only the test target fails on the
missing symbols. This is the intended TDD red state.

## Acceptance Criteria Coverage

| AC  | Description                                                          | Test Coverage                                                                                             |
|-----|----------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| AC1 | `SubAgentFieldDiagnostics` type exists in `Types/AgentTypes.swift`   | Compile-time red: every test using the type. `SubAgentFieldDiagnosticReason` cases exercised by `.reason` assertions. |
| AC2 | `SubAgentResult.fieldDiagnostics` field (default nil)                | `testMapQueryResultToSubAgentResult_propagatesDiagnostics`, `testMapQueryResultToSubAgentResult_backwardCompat_defaultsToNilDiagnostics`, `testAgentTool_noDiagnostics_outputUnchanged` |
| AC3 | spawner collects run_in_background diagnostic (truthy only)          | `testSpawn_runInBackgroundTrue_emitsDiagnostic`, `testSpawn_runInBackgroundFalse_noBackgroundDiagnostic`, `testSpawn_resumeSet_emitsDiagnostic`, `testSpawn_isolationSet_emitsDiagnostic`, `testSpawn_teamNameSet_emitsDiagnostic` |
| AC4 | MCP `.reference` diagnostic; inline excluded; duplicates per-ref     | `testSpawn_mcpReference_emitsDiagnostic`, `testSpawn_mcpInline_noReferenceDiagnostic`, `testSpawn_duplicateMcpReference_emitsPerReferenceDiagnostic` |
| AC5 | Multiple deferred fields emitted in deterministic order              | `testSpawn_multipleDeferredFields_allEmittedInOrder`                                                      |
| AC6 | AgentTool renders diagnostics block (after text, before [Tools used])| `testAgentTool_outputIncludesDiagnosticsBlock`, `testTaskTool_outputIncludesDiagnosticsBlock`, `testAgentTool_noDiagnosticsNoToolCalls_bareOutput`, `testAgentTool_multipleDiagnostics_renderedInOrder` |
| AC7 | skills rawValue is comma-joined, order preserved                     | `testSpawn_skillsSet_emitsDiagnosticWithCommaJoinedValue`                                                 |
| AC8 | No deferred fields => `fieldDiagnostics == nil`                      | `testSpawn_noDeferredFields_diagnosticsIsNil`                                                             |
| AC9 | Backward compat (init signature unchanged, nil diagnostics)          | `testMapQueryResultToSubAgentResult_backwardCompat_defaultsToNilDiagnostics`, `testAgentTool_noDiagnostics_outputUnchanged`, all 13+ pre-existing `AgentToolTests` and 29.5 `DefaultSubAgentSpawnerTests` regression guards |
| AC10| Build + full regression (DEV phase)                                 | N/A (runtime gate; verified post-implementation by `swift test`)                                          |

## Red-Phase Test Scaffolds Created

### `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`

Added `// MARK: - Story 29.6: Deferred Field Diagnostics Collection` section
(appended after the Story 29.5 helper). New tests:

1. `testSpawn_runInBackgroundTrue_emitsDiagnostic` — AC3 [P0]
2. `testSpawn_runInBackgroundFalse_noBackgroundDiagnostic` — AC3 [P1]
3. `testSpawn_resumeSet_emitsDiagnostic` — AC3 sibling [P0]
4. `testSpawn_isolationSet_emitsDiagnostic` — AC3 sibling [P0]
5. `testSpawn_teamNameSet_emitsDiagnostic` — AC3 sibling [P0]
6. `testSpawn_skillsSet_emitsDiagnosticWithCommaJoinedValue` — AC7 [P0]
7. `testSpawn_mcpReference_emitsDiagnostic` — AC4 [P0]
8. `testSpawn_mcpInline_noReferenceDiagnostic` — AC4 [P0]
9. `testSpawn_duplicateMcpReference_emitsPerReferenceDiagnostic` — AC4 [P1]
10. `testSpawn_multipleDeferredFields_allEmittedInOrder` — AC5 [P0]
11. `testSpawn_noDeferredFields_diagnosticsIsNil` — AC8 [P0]
12. `testMapQueryResultToSubAgentResult_propagatesDiagnostics` — AC2 [P0]
13. `testMapQueryResultToSubAgentResult_backwardCompat_defaultsToNilDiagnostics` — AC9 [P0]

### `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`

Added `MockSubAgentSpawner.makeWithDiagnostics(...)` static helper (default
parameters keep existing init call sites unchanged) and a
`// MARK: - Story 29.6: Deferred Field Diagnostics Rendering` section. New tests:

14. `testAgentTool_outputIncludesDiagnosticsBlock` — AC6 [P0]
15. `testTaskTool_outputIncludesDiagnosticsBlock` — AC6 [P0]
16. `testAgentTool_noDiagnostics_outputUnchanged` — AC6/AC9 [P0]
17. `testAgentTool_noDiagnosticsNoToolCalls_bareOutput` — AC6 [P1]
18. `testAgentTool_multipleDiagnostics_renderedInOrder` — AC6 [P1]

## Mock Requirements

All tests mock external I/O per project rule #27 (no real network/LLM/shell):

- `DefaultSubAgentSpawnerTests`: reuses the existing `SpawnerMockURLProtocol` returning
  a canned 401 response. Diagnostics are collected BEFORE the LLM call, so the 401
  error response does not affect diagnostic assertions.
- `AgentToolTests`: uses `MockSubAgentSpawner` returning a pre-configured `SubAgentResult`
  with the desired `fieldDiagnostics`. No real spawner or LLM involved.
- `testMapQueryResultToSubAgentResult_*`: drives the `internal static` mapping directly
  with hand-built `QueryResult` — no LLM round-trip.

## Required data-testid Attributes

N/A — backend Swift project, no UI selectors.

## Implementation Checklist (for DEV team — GREEN phase)

Each scaffolded test maps to concrete implementation work from the story's Task list:

| Test                                                       | Implementation Task (story)                                  |
|------------------------------------------------------------|--------------------------------------------------------------|
| `testMapQueryResultToSubAgentResult_propagatesDiagnostics` | Task 2.4 — extend `mapQueryResultToSubAgentResult` signature |
| `testMapQueryResultToSubAgentResult_backwardCompat_*`      | Task 2.4 — default `fieldDiagnostics: nil`                   |
| `testSpawn_runInBackgroundTrue_emitsDiagnostic`            | Task 2.1, 2.2, 2.3, 2.5 — `collectFieldDiagnostics` + threading |
| `testSpawn_resumeSet_emitsDiagnostic`                      | Task 2.1 — resume branch                                     |
| `testSpawn_isolationSet_emitsDiagnostic`                   | Task 2.1 — isolation branch                                  |
| `testSpawn_teamNameSet_emitsDiagnostic`                    | Task 2.1 — team_name branch                                  |
| `testSpawn_skillsSet_emitsDiagnosticWithCommaJoinedValue`  | Task 2.1 — skills branch (comma-join)                        |
| `testSpawn_mcpReference_emitsDiagnostic`                   | Task 2.1 — `.reference` pattern match                        |
| `testSpawn_mcpInline_noReferenceDiagnostic`                | Task 2.1 — `.inline` excluded                                |
| `testSpawn_duplicateMcpReference_*`                        | Task 2.1 — no dedup                                          |
| `testSpawn_multipleDeferredFields_allEmittedInOrder`       | Task 1.3 / 2.1 — fixed append order                          |
| `testSpawn_noDeferredFields_diagnosticsIsNil`              | Task 2.5 — empty array -> nil                                |
| `testSpawn_runInBackgroundFalse_noBackgroundDiagnostic`    | Task 2.1 — truthy check (`runInBackground == true`)          |
| `testAgentTool_outputIncludesDiagnosticsBlock`             | Task 3.1 — rendering branch                                  |
| `testTaskTool_outputIncludesDiagnosticsBlock`              | Task 3.1 — shared factory renders for both Agent and Task    |
| `testAgentTool_noDiagnostics_outputUnchanged`              | Task 3.1 — `if let diags, !diags.isEmpty` guard              |
| `testAgentTool_noDiagnosticsNoToolCalls_bareOutput`        | Task 3.1 — same guard                                        |
| `testAgentTool_multipleDiagnostics_renderedInOrder`        | Task 3.1 — map + join in order                               |

### Implementation Order (recommended)

1. **Task 1** — Add `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` to
   `Types/AgentTypes.swift`, add `fieldDiagnostics` field + default-param init to
   `SubAgentResult`, add `shortHumanReadableText` extension. This unlocks compile
   for most tests (they'll then run and fail at runtime until Task 2/3 land).
2. **Task 2** — Implement `collectFieldDiagnostics` + thread through `executeAgent` /
   `mapQueryResultToSubAgentResult`. This turns the `DefaultSubAgentSpawnerTests`
   tests green.
3. **Task 3** — Add the rendering branch in `createSubAgentLauncherTool`. This turns
   the `AgentToolTests` tests green.
4. **Task 4** — Verify `SubAgentSpawner` protocol signatures unchanged (AC9).
5. **Task 6** — `swift build` + `swift test`; record new total test count
   (baseline: 5769 tests passing from Story 29.5).

## Red-Green-Refactor Workflow

- **RED (complete)**: 18 new tests were scaffolded. They originally failed at
  compile-time because `SubAgentFieldDiagnostics`, `SubAgentFieldDiagnosticReason`,
  and the `fieldDiagnostics:` parameter did not exist in source yet.
- **GREEN (DEV phase)**: Implement Tasks 1 → 2 → 3 above. After Task 1 the tests
  should compile; after Task 2 + 3 they should pass. Run `swift test` after each task.
- **REFACTOR (DEV phase)**: After all green, review for cleanup. The story's
  Dev Notes already specifies the `nil` vs `[]` semantic decision (AC8) and the
  `fieldDiagnostics` / `filterDiagnostics` boundary with 29.5.

## Execution Commands

```bash
# Build everything (tests + sources)
swift build

# Run only the 29.6-related test classes
swift test --filter DefaultSubAgentSpawnerTests
swift test --filter AgentToolTests

# Run the full suite (post-implementation gate, project rule)
swift test
```

## Knowledge Base References Applied

- **Project rule #23**: XCTest only, test dir mirrors source — tests placed under
  `Tests/OpenAgentSDKTests/Core/` and `Tests/OpenAgentSDKTests/Tools/Advanced/`.
- **Project rule #27**: No real I/O — `SpawnerMockURLProtocol` and `MockSubAgentSpawner`
  used; `mapQueryResultToSubAgentResult` driven directly.
- **Project rule #40**: No force-unwrap — `try XCTUnwrap` used for diagnostic
  presence assertions; `if let`/optional chaining elsewhere.
- **Project rule #46**: Array (ordered) used for diagnostics, never Set.
- **Project rule #56**: Reused existing test files (`DefaultSubAgentSpawnerTests`,
  `AgentToolTests`) rather than creating new ones; reused `MockSubAgentSpawner`
  with a default-parameter factory.
- **Story 29.5 retrospective**: "新增字段有默认值" migration pattern reused —
  `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil` on both the `SubAgentResult`
  init and `mapQueryResultToSubAgentResult` to keep existing call sites compiling.

## Next Steps for DEV Team

1. Read the story file (`_bmad-output/implementation-artifacts/29-6-diagnostics-deferred-subagent-fields.md`).
2. Implement Task 1 (types in `AgentTypes.swift`). Confirm `swift build` succeeds.
3. Implement Task 2 (collect + propagate). Run `swift test --filter DefaultSubAgentSpawnerTests`.
4. Implement Task 3 (rendering). Run `swift test --filter AgentToolTests`.
5. Run `swift test` (full suite, project rule). Record new total count.
6. Story 29.7 will add E2E tests and DocC documentation.
