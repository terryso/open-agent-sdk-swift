---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-06-14'
storyId: '29.7'
storyKey: '29-7-tests-and-documentation'
storyFile: '_bmad-output/implementation-artifacts/29-7-tests-and-documentation.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-29-7-tests-and-documentation.md'
generatedTestFiles:
  - 'Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/29-7-tests-and-documentation.md'
  - '_bmad-output/project-context.md'
  - '_bmad/tea/config.yaml'
detectedStack: backend
generationMode: ai-generation
executionMode: sequential
redPhaseStatus: not-applicable
---

# ATDD Checklist — Story 29.7: Tests and Documentation

## Story Summary

Epic 29 closing story (Claude Code Skill/Subagent Compatibility). **No runtime code changes.** Consolidates cross-feature integration coverage across the Epic 29 surface and adds the missing DocC + cookbook documentation.

**TDD phase note (per Story Dev Notes line 206):** This is a tests + docs story verifying ALREADY-IMPLEMENTED runtime behavior from Stories 29.1–29.6. **There is no red phase** — integration tests are expected to be green on first run. The 8 new tests below all pass against the current main branch.

---

## Acceptance Criteria → Test Mapping

### AC1: `createTaskTool()` alias shares spawn semantics (spawn→filter→render)

| ID | Test | File | Priority | Status |
|----|------|------|----------|--------|
| AC1.a | `testCreateTaskTool_aliasSharesSpawnCallSemanticsWithAgent` | `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` | P0 | PASS |
| AC1.b | `testCreateTaskTool_spawnerMissingErrorMentionsTask` | `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` | P0 | PASS |

**Coverage:** Proves the `Task` alias and `Agent` tool share the single `createSubAgentLauncherTool` factory (identical `prompt`/`maxTurns`/`model` reach the mock spawner), and that the alias surfaces its own name in the nil-spawner error path.

### AC2: Task-only tool pool triggers spawner injection + dual-launcher stripping

| ID | Test | File | Priority | Status |
|----|------|------|----------|--------|
| AC2.a | `testTaskOnlyToolPool_triggersSpawnerInjection` | `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift` | P0 | PASS |
| AC2.b | `testAgentAndTaskBothPresent_childStripsBothLaunchers` | `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift` | P0 | PASS |

**Coverage:** Task-only pool still injects a spawner (no "spawner missing" error), and a pool with BOTH `Agent` and `Task` strips BOTH from the child pool via `SubAgentLauncherNames.default == ["Agent", "Task"]`.

### AC3: Package context + toolDeclarations coexistence

| ID | Test | File | Priority | Status |
|----|------|------|----------|--------|
| AC3.a | `testFilesystemSkill_withBaseDirAndSupportingFilesAndToolDeclarations_assemblesCompletePrompt` | `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift` | P0 | PASS |

**Coverage:** A filesystem Skill carrying `baseDir` + `supportingFiles` + `toolDeclarations` (MCP namespaced + SDK name) simultaneously still assembles a prompt containing the absolute baseDir, the relative supporting-file path, and the "Skill package context:" marker. Proves 29.3 prompt assembly is not broken by 29.4 declaration parsing.

### AC4: Full declaration spectrum → parse → filter (single test, four types)

| ID | Test | File | Priority | Status |
|----|------|------|----------|--------|
| AC4.a | `testParseAndFilter_allFourDeclarationTypes_preservedAndRouted` | `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` | P0 | PASS |

**Coverage:** One `allowed-tools` fragment (`"WebSearch, mcp__github__list_prs, Bash(git diff:*), UnknownTool"`) exercising all four declaration shapes. `fromToolNames` preserves all four (no collapse to unrestricted), and `filterToolsByDeclarations` routes them: matched tools retained, `UnknownTool` → `unmatchedDeclarations`, `Bash(git diff:*)` → `patternDeclarations`.

### AC5: Dual diagnostic dimension boundary (fields vs. tool-filter)

| ID | Test | File | Priority | Status |
|----|------|------|----------|--------|
| AC5.a | `testSpawn_runInBackgroundAndUnknownAllowedTool_fieldDiagnosticsOnlyContainFields` | `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` | P0 | PASS |
| AC5.b | `testAgentTool_outputWithFieldDiagnostics_doesNotLeakToolFilterInfo` | `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` | P0 | PASS |

**Coverage:** A spawn with `run_in_background: true` AND an unknown `allowedTools` entry surfaces ONLY the `run_in_background` field diagnostic (count == 1, no tool-filter vocabulary leaks). AgentTool output carrying `fieldDiagnostics` renders the field block without any `unmatched`/`pattern declaration` wording. Pins the 29.6 Dev Notes "Boundary with 29.5" contract as a regression test.

### AC6: E2E (real environment) — SKIPPED per epic clause

| ID | Action | Status |
|----|--------|--------|
| AC6 | E2E file NOT created; skip recorded | SKIPPED |

**Decision:** Environment has no `CODEANY_API_KEY` or `ANTHROPIC_API_KEY` set. Per Epic 29 "E2E tests are optional" clause and CLAUDE.md rule ("Do not create mock-based tests for E2E test files"), the E2E is **skipped** rather than written as a mock-based test. To be recorded in Completion Notes: "E2E skipped per epic 29.7 'E2E tests are optional' clause; reason: no API key available in environment."

### AC7: DocC `MultiAgent.md` updates — DEFERRED to dev-story step

| ID | Action | Status |
|----|--------|--------|
| AC7 | DocC documentation edits | PENDING (dev-story step) |

**Note:** Documentation ACs (AC7, AC8) are deliverables of the dev-story step, not the ATDD red-phase step. The ATDD skill scope is test scaffolds only. They are tracked here for completeness; implementation happens in the next pipeline step.

### AC8: Cookbook scenarios 8 + 10 updates — DEFERRED to dev-story step

| ID | Action | Status |
|----|--------|--------|
| AC8 | Cookbook documentation edits | PENDING (dev-story step) |

### AC9: Build + full-suite regression — DEFERRED to dev-story step

| ID | Action | Status |
|----|--------|--------|
| AC9 | `swift build` + `swift test` full-suite pass + total count | PENDING (dev-story step) |

### AC10: DocC build no new warnings — DEFERRED to dev-story step

| ID | Action | Status |
|----|--------|--------|
| AC10 | `swift package generate-documentation` no unresolved-link warnings | PENDING (dev-story step) |

---

## Test Files Modified

All 5 test files were **extended** (not created) per project-context.md rule #56 (reuse shared test infrastructure). Each new section is demarcated with a `// MARK: - Story 29.7:` header:

1. `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` — section `Story 29.7: Epic-End Integration Coverage` (2 tests)
2. `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift` — section `Story 29.7: Task-Only Spawner Detection Integration` (2 tests)
3. `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift` — section `Story 29.7: Package Context Integration` (1 test)
4. `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` — section `Story 29.7: Full Declaration Spectrum Integration` (1 test)
5. `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` — section `Story 29.7: Dual Diagnostics Integration` (2 tests)

**Total new tests: 8** (all PASS against current main — green on first run, no red phase).

No new test files created. No E2E file created (AC6 skipped).

---

## Test Strategy

- **Stack:** backend (Swift / SPM / XCTest). No browser/E2E framework.
- **Level:** Integration-flavored unit tests, mock-driven (project rule #27 — no real I/O in unit tests). All external dependencies mocked: `MockSubAgentSpawner` for spawner, `SkillStreamMockURLProtocol` for LLM HTTP, `SpawnerMockURLProtocol` (401) for spawner client.
- **Priorities:** All P0 — these are epic-closing seam tests pinning the public contract.
- **Red phase:** Not applicable. Per Story 29.7 Dev Notes line 206, this story verifies already-implemented behavior; tests are green from inception.

---

## Execution Report

- **Build:** `swift build` OK, zero new warnings.
- **Test build:** `swift build --build-tests` OK (one pre-existing warning in `ToolBuilderTests.swift:94`, unrelated to this story).
- **New tests run:** 8 passed, 0 failures, 0.336s elapsed.

---

## Notes for Dev-Story Step

1. **AC7/AC8 (documentation):** DocC `MultiAgent.md` and cookbook edits remain to be written. Use double-backtick DocC link syntax (`` `createTaskTool()` ``, `` `SubAgentFieldDiagnostics` ``) — these symbols are already exported in `OpenAgentSDK.swift`.
2. **AC9 (full-suite count):** Baseline is 5787 (Story 29.6 completion). After this story's 8 new tests, expected total is **5795**. Record the actual `swift test` count in Completion Notes as "all NNNN tests passing".
3. **AC10 (DocC warnings):** Run `swift package generate-documentation` to verify no unresolved-link warnings from the new DocC sections. If `DocCBuildTests` exists, it must still pass.
4. **No runtime changes:** Do NOT modify `Sources/OpenAgentSDK/**` runtime code. If an integration test reveals a runtime bug, record it as a dev note and open a follow-up — do not expand this story's scope.
5. **E2E skip record:** Completion Notes must state "E2E skipped per epic 29.7 'E2E tests are optional' clause; reason: no API key in environment." File List must NOT include any E2E file path.
