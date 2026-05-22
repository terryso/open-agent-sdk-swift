# Story 22.4: SkillCurator — Automatic Skill Curation Service

Status: done

## Story

As an SDK developer,
I want an automatic curation service that periodically evaluates the skill library during agent idle time — merging overlapping skills, archiving stale ones, and patching low-quality prompts — so that the skill library stays healthy without manual intervention.

## Acceptance Criteria

1. **AC1: `CuratorState` struct** — Given `CuratorState`, when defined in `Types/SkillEvolutionTypes.swift`, it is a `public struct` that is `Sendable`, `Codable`, `Equatable`. Fields: `lastRunAt` (Date?, default nil), `paused` (Bool, default false), `runCount` (Int, default 0), `lastRunDurationMs` (Int?, default nil), `lastErrors` ([String], default []). Methods: `static func defaultState() -> CuratorState` returns a fresh state with all defaults.

2. **AC2: `SkillCuratorConfig` struct** — Given `SkillCuratorConfig`, when defined in `Types/SkillEvolutionTypes.swift`, it is a `public struct` that is `Sendable`, `Codable`, `Equatable`. Fields: `intervalHours` (Double, default 168.0 — 7 days), `minIdleHours` (Double, default 2.0), `staleAfterDays` (Int, default 30), `archiveAfterDays` (Int, default 90), `dryRun` (Bool, default false), `enabled` (Bool, default true). Validation: `intervalHours > 0`, `minIdleHours >= 0`, `archiveAfterDays > staleAfterDays > 0`. Invalid configs `preconditionFailure`.

3. **AC3: `CuratorRunResult` struct** — Given `CuratorRunResult`, when defined in `Types/SkillEvolutionTypes.swift`, it is a `public struct` that is `Sendable`, `Codable`, `Equatable`. Fields: `transitionsApplied` ([SkillLifecycleTransition]), `skillsEvaluated` (Int), `skillsSkipped` (Int — pinned/bundled), `errors` ([String]), `durationMs` (Int), `dryRun` (Bool), `ranAt` (Date).

4. **AC4: `SkillCuratorStore` actor** — Given `SkillCuratorStore`, when defined in `Stores/SkillCuratorStore.swift`, it is a `public actor` that persists `CuratorState` to a JSON file at `~/.open-agent-sdk/skills/.curator-state.json`. Methods: `func loadState() -> CuratorState`, `func saveState(_ state: CuratorState) throws`, `func getSkillsDir() -> String`. Uses the same atomic write pattern as `SkillUsageStore` (write to temp file, then `FileManager.moveItem`). Configurable `skillsDir` parameter (default `~/.open-agent-sdk/skills/`). Depends only on `Types/`.

5. **AC5: `SkillCurator` struct** — Given `SkillCurator`, when defined in `Utils/SkillCurator.swift`, it is a `public struct` that is `Sendable`. It takes a `SkillUsageStore`, a `SkillCuratorStore`, and optional `SkillCuratorConfig`. Methods: (a) `func shouldRun(state: CuratorState) -> Bool` — returns true if config.enabled, not paused, and either `lastRunAt == nil` or time since last run >= intervalHours; (b) `func run() async throws -> CuratorRunResult` — executes one curation pass; (c) `func pause() async throws`, (d) `func resume() async throws` — toggle the paused flag in state.

6. **AC6: Curation pass logic** — Given `run()` is called, the curator: (a) Loads current state from `SkillCuratorStore`; (b) Checks `shouldRun` — if false, returns empty result with `dryRun: true`; (c) Gets all usage data from `SkillUsageStore`; (d) For each tracked skill where `provenance == .agentCreated` and `pinned == false`, evaluates lifecycle transitions using `SkillUsageTracker`; (e) Skills with `provenance == .bundled` or `.userDefined` or `.hubInstalled` are skipped and counted in `skillsSkipped`; (f) Skills that are `pinned` are skipped and counted in `skillsSkipped`; (g) For each transition found, if `config.dryRun == false`, applies the transition via `SkillUsageStore.setUsage`; (h) Updates `CuratorState` with `lastRunAt`, incremented `runCount`, `lastRunDurationMs`, and any errors; (i) Persists state via `SkillCuratorStore.saveState`; (j) Returns `CuratorRunResult` with all collected data.

7. **AC7: Safety boundary** — The curator NEVER modifies skills with `provenance != .agentCreated`. It NEVER deletes skills (retirement changes usage state only). Pinned skills are always skipped. The `dryRun` config flag prevents any state mutation when true — transitions are computed but not applied.

8. **AC8: Module boundary compliance** — `SkillCuratorStore` lives in `Stores/` and depends only on `Types/`. `SkillCurator` lives in `Utils/` and depends on `Types/` (for data models), `Stores/` (for `SkillUsageStore` and `SkillCuratorStore`), and `Utils/SkillUsageTracker` (for lifecycle evaluation). Neither imports `Core/` or `Tools/`.

9. **AC9: Unit tests** — All new code tested: `CuratorState` defaults and Codable round-trip; `SkillCuratorConfig` defaults, custom init, validation (precondition failures for invalid values); `CuratorRunResult` construction; `SkillCuratorStore` actor tests (initial state, save/load round-trip, persistence across store instances); `SkillCurator.shouldRun` logic (enabled/paused/interval checks); `SkillCurator.run` — full curation pass with agent-created skills transitioning, bundled skills skipped, pinned skills skipped, dryRun mode preventing mutations, pause/resume toggling, error collection. Store tests use temp directories (no real I/O — create isolated temp dir, use it, clean up).

10. **AC10: Build and test pass** — `swift build` with zero errors. All existing tests pass with zero regression.

## Tasks / Subtasks

- [x] Task 1: Define `CuratorState`, `SkillCuratorConfig`, and `CuratorRunResult` types (AC: #1, #2, #3)
  - [x] Add `CuratorState` to `Sources/OpenAgentSDK/Types/SkillEvolutionTypes.swift`
  - [x] Add `SkillCuratorConfig` with validation to same file
  - [x] Add `CuratorRunResult` to same file

- [x] Task 2: Create `SkillCuratorStore` actor (AC: #4)
  - [x] Create `Sources/OpenAgentSDK/Stores/SkillCuratorStore.swift`
  - [x] Implement actor with JSON state persistence and atomic writes
  - [x] Methods: loadState, saveState, getSkillsDir
  - [x] Configurable `skillsDir` parameter with default `~/.open-agent-sdk/skills/`

- [x] Task 3: Create `SkillCurator` struct (AC: #5, #6, #7)
  - [x] Create `Sources/OpenAgentSDK/Utils/SkillCurator.swift`
  - [x] Implement shouldRun, run, pause, resume methods
  - [x] Curation pass: iterate agentCreated skills, evaluate via SkillUsageTracker, apply transitions
  - [x] Safety: skip bundled/userDefined/hubInstalled, skip pinned, honor dryRun

- [x] Task 4: Unit tests for types (AC: #9)
  - [x] Add tests to `Tests/OpenAgentSDKTests/Types/SkillEvolutionTypesTests.swift`
  - [x] Test CuratorState defaults and Codable round-trip
  - [x] Test SkillCuratorConfig defaults, custom init, validation failures
  - [x] Test CuratorRunResult construction

- [x] Task 5: Unit tests for SkillCuratorStore (AC: #9)
  - [x] Create `Tests/OpenAgentSDKTests/Stores/SkillCuratorStoreTests.swift`
  - [x] Test initial state, save/load round-trip, persistence across instances
  - [x] Use temp directories for all tests

- [x] Task 6: Unit tests for SkillCurator (AC: #9)
  - [x] Create `Tests/OpenAgentSDKTests/Utils/SkillCuratorTests.swift`
  - [x] Test shouldRun logic (enabled, paused, interval)
  - [x] Test full curation pass (agentCreated skills transition, others skip)
  - [x] Test dryRun mode (transitions computed but not applied)
  - [x] Test pause/resume
  - [x] Test error collection

- [x] Task 7: Verify build and tests (AC: #10)
  - [x] `swift build` — 0 errors
  - [x] Full test suite — 0 failures

## Dev Notes

### Architecture Compliance

- **New types go in `Types/SkillEvolutionTypes.swift`**: `CuratorState`, `SkillCuratorConfig`, `CuratorRunResult` are all data models with no outbound dependencies beyond existing Types. Same location as all other skill evolution types.
- **`SkillCuratorStore` goes in `Stores/`**: Follows the `SkillUsageStore`, `FactStore` pattern. Actor-isolated, JSON file persistence, depends only on `Types/`. No dependency on `Core/` or `Tools/`.
- **`SkillCurator` goes in `Utils/`**: Follows the `SkillUsageTracker`, `LLMSkillEvolver`, `MemoryLifecycleService` pattern. Stateless computation struct that delegates I/O to injected stores. Depends on `Types/`, `Stores/`, and `Utils/SkillUsageTracker`.
- **No Apple-proprietary frameworks**: Foundation only (FileManager, Date, JSONEncoder/Decoder).
- **Actor for shared mutable state**: `SkillCuratorStore` is an actor (manages file I/O). `SkillCurator` is a struct (no mutable state).
- **Stores/ never imports Core/**: Strict module boundary maintained.

### Key Design Decisions

1. **Curator is a struct, not an actor**: Like `SkillUsageTracker` and `LLMSkillEvolver`, the curator has no mutable state — it reads from stores, computes curation actions, and delegates writes to the injected stores. The caller (typically a background task) is responsible for scheduling.

2. **State persistence uses same pattern as SkillUsageStore**: The `SkillCuratorStore` actor persists `CuratorState` to `~/.open-agent-sdk/skills/.curator-state.json` using atomic writes. This follows the exact same pattern as `SkillUsageStore` writing to `.usage.json`.

3. **Safety boundary mirrors Hermes curator**: Only `agentCreated` skills are eligible for automatic curation. `bundled`, `userDefined`, and `hubInstalled` skills are never modified. Pinned skills are always skipped. The curator never deletes skills — retirement only changes usage state.

4. **Reuses SkillUsageTracker for lifecycle evaluation**: The curator does NOT re-implement lifecycle evaluation. It delegates to `SkillUsageTracker.checkLifecycle(skillName:)` and `SkillUsageTracker.checkAllLifecycles()` to compute transitions, then applies them.

5. **dryRun prevents all mutations**: When `config.dryRun == true`, transitions are computed and reported in the result, but no `SkillUsageStore.setUsage` calls are made and no `CuratorState` is persisted.

6. **Interval check is time-based**: `shouldRun` compares `Date()` against `state.lastRunAt + config.intervalHours`. This allows the caller to check whether a run is due without actually running.

7. **Error collection is non-fatal**: If individual transition applications fail (e.g., file I/O error on a specific skill), the error is appended to `CuratorRunResult.errors` and the curation continues. Only store-level failures (unable to load/save state) are thrown.

### Integration Points with Existing SDK

- **`Types/SkillEvolutionTypes.swift`**: Extend with `CuratorState`, `SkillCuratorConfig`, `CuratorRunResult`. These types are consumed by both `SkillCuratorStore` and `SkillCurator`.
- **`Stores/SkillUsageStore.swift`**: Used by `SkillCurator` to read usage data and apply lifecycle transitions. The curator calls `allUsage()`, `getUsage()`, and `setUsage()`.
- **`Utils/SkillUsageTracker.swift`**: Used by `SkillCurator` to evaluate lifecycle transitions. The curator calls `checkAllLifecycles()` to get candidate transitions, then applies only those for `agentCreated` + non-pinned skills.
- **`Stores/FactStore.swift`**: Pattern reference for actor-based JSON persistence with atomic writes.

### File Structure

```
Sources/OpenAgentSDK/Types/
  SkillEvolutionTypes.swift          # ADD: CuratorState, SkillCuratorConfig,
                                      #      CuratorRunResult

Sources/OpenAgentSDK/Stores/
  SkillCuratorStore.swift            # NEW: Actor for curator state persistence

Sources/OpenAgentSDK/Utils/
  SkillCurator.swift                 # NEW: Curation pass orchestration

Tests/OpenAgentSDKTests/Types/
  SkillEvolutionTypesTests.swift     # ADD: Tests for new types

Tests/OpenAgentSDKTests/Stores/
  SkillCuratorStoreTests.swift       # NEW: Store tests with temp directories

Tests/OpenAgentSDKTests/Utils/
  SkillCuratorTests.swift            # NEW: Curator logic tests
```

### Curator State File Format

```json
{
  "lastRunAt": "2026-05-23T10:30:00Z",
  "paused": false,
  "runCount": 5,
  "lastRunDurationMs": 142,
  "lastErrors": []
}
```

### Hermes Reference Mapping

```
Hermes curator.py           →  SDK Component
──────────────────────────────────────────────────
_default_state()            →  CuratorState.defaultState()
load_state() / save_state() →  SkillCuratorStore.loadState() / saveState()
is_enabled()                →  SkillCuratorConfig.enabled
get_interval_hours()        →  SkillCuratorConfig.intervalHours (168.0)
get_min_idle_hours()        →  SkillCuratorConfig.minIdleHours (2.0)
get_stale_after_days()      →  SkillCuratorConfig.staleAfterDays (30)
get_archive_after_days()    →  SkillCuratorConfig.archiveAfterDays (90)
should_run_now()            →  SkillCurator.shouldRun(state:)
(Invariant: agent_created)  →  provenance == .agentCreated check
(Invariant: no auto-delete) →  Curator only transitions, never deletes
(Invariant: pinned skip)    →  data.pinned check
```

### Previous Story Learnings (Stories 22.1, 22.2, 22.3)

- **Build baseline**: 5671 tests passing. Any regression check must match this baseline.
- **`nonisolated(unsafe)`** for simple flags when actor isolation isn't needed.
- **Swift 6.1 strict concurrency**: closures need explicit capture lists.
- **`Codable` for SDK-internal structured data**, raw `[String: Any]` only for LLM API communication boundary.
- **Pure computation structs preferred** when no mutable state is needed.
- **Test counts in completion notes must match actual** — use `swift test 2>&1 | grep -c "passed"` before writing completion notes.
- **Atomic file writes**: `SkillUsageStore` pattern — write to temp, `removeItem` existing, then `FileManager.moveItem`. Must remove existing file first since `moveItem` fails when destination exists.
- **Actor tests use `await`** for all actor-isolated methods.
- **Store tests with temp directories**: Create a unique temp dir for each test, pass as `skillsDir`, clean up in `tearDown` or `defer` block.
- **JSON encoder pattern**: `.iso8601` date strategy, `.prettyPrinted` + `.sortedKeys` output formatting.
- **`SharedMockState` pattern**: `final class SharedMockState: @unchecked Sendable` with `NSLock` for test state capture.
- **Confidence clamping** — always clamp to 0-1 range in factory methods.
- **precondition for config validation** — use `precondition()` not `assert()` to catch invalid configs in release builds too.

### Testing Strategy

- **Unit tests only**: Mock all external dependencies. `SkillCuratorStore` tests use temp directories (not real SDK paths). `SkillCurator` tests use real `SkillUsageStore` and `SkillCuratorStore` instances with temp dirs.
- **Store tests**: Test actor methods via `await`. Test persistence by writing, creating new store instance with same dir, reading back.
- **Curator tests**: Inject stores with temp dirs, populate usage data via `SkillUsageStore`, run curation, verify transitions applied or skipped.
- **Edge cases**: Empty store, all skills bundled (nothing to curate), all skills pinned, dryRun mode, disabled config, paused state, interval not reached.

### References

- [Source: docs/epics.md — Epic 22, Story 22.4 definition with Hermes curator.py references]
- [Source: Sources/OpenAgentSDK/Types/SkillEvolutionTypes.swift — CuratorState, SkillCuratorConfig, CuratorRunResult]
- [Source: Sources/OpenAgentSDK/Stores/SkillUsageStore.swift — Pattern: Actor with JSON persistence, atomic writes]
- [Source: Sources/OpenAgentSDK/Utils/SkillUsageTracker.swift — Lifecycle evaluation delegated to curator]
- [Source: _bmad-output/implementation-artifacts/22-3-skill-usage-tracker-lifecycle.md — Previous story, defines SkillUsageData, SkillUsageStore, SkillUsageTracker]
- [Source: _bmad-output/implementation-artifacts/22-2-llm-skill-evolver.md — Utils/ struct pattern, LLMClient dependency]
- [Source: _bmad-output/project-context.md — Architecture rules, module boundaries, actor conventions]

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.1)

### Debug Log References

### Completion Notes List

- Implemented `CuratorState`, `SkillCuratorConfig`, `CuratorRunResult` in `SkillEvolutionTypes.swift` — all Sendable, Codable, Equatable with validation via `precondition()`.
- Created `SkillCuratorStore` actor following `SkillUsageStore` pattern — atomic JSON writes, configurable skillsDir, in-memory cache with disk persistence.
- Created `SkillCurator` struct — delegates lifecycle evaluation to `SkillUsageTracker`, applies transitions only for `agentCreated` + non-pinned skills, honors dryRun, persists state after run.
- Added 12 type tests (CuratorState defaults/Codable, SkillCuratorConfig defaults/custom/Codable, CuratorRunResult defaults/custom/Codable), 7 store tests, and 20 curator tests.
- All 5,240 tests pass with 0 failures, 42 skipped.

### File List

- `Sources/OpenAgentSDK/Types/SkillEvolutionTypes.swift` — Added CuratorState, SkillCuratorConfig, CuratorRunResult types
- `Sources/OpenAgentSDK/Stores/SkillCuratorStore.swift` — New: Actor for curator state persistence
- `Sources/OpenAgentSDK/Utils/SkillCurator.swift` — New: Curation pass orchestration struct
- `Tests/OpenAgentSDKTests/Types/SkillEvolutionTypesTests.swift` — Added type tests
- `Tests/OpenAgentSDKTests/Stores/SkillCuratorStoreTests.swift` — New: Store tests
- `Tests/OpenAgentSDKTests/Utils/SkillCuratorTests.swift` — New: Curator logic tests
- `Sources/E2ETest/SkillCuratorE2ETests.swift` — New: E2E tests for SkillCurator and SkillCuratorStore
- `Sources/E2ETest/main.swift` — Added SkillCuratorE2ETests.run() call

### Change Log

- 2026-05-23: Story 22.4 complete — SkillCurator automatic curation service with types, store, curator, and full test coverage.
- 2026-05-23: Senior Developer Review (AI) — Fixed HIGH: no-op transition application now updates `lastManagedAt`. Fixed MEDIUM: incorrect test count in completion notes, added missing E2E files to File List. Noted: Logger dependency in SkillCuratorStore (inherited pattern from SkillUsageStore). All 5240+ tests pass.
