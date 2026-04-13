---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/15-6-context-injection-example.md'
  - 'Sources/OpenAgentSDK/Utils/FileCache.swift'
  - 'Sources/OpenAgentSDK/Utils/GitContextCollector.swift'
  - 'Sources/OpenAgentSDK/Utils/ProjectDocumentDiscovery.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Examples/QueryAbortExample/main.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/QueryAbortExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/ModelSwitchingExampleComplianceTests.swift'
---

# ATDD Checklist - Epic 15, Story 6: ContextInjectionExample

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit / Static Analysis (Swift backend project, example compliance tests)

---

## Story Summary

Create a runnable ContextInjectionExample program that demonstrates file caching (FileCache), Git context collection (GitContextCollector), and project document discovery (ProjectDocumentDiscovery) -- the three pillars of context injection in the SDK. The example shows both standalone API usage and Agent integration. This is an example/documentation story, not a new feature.

**As a** developer
**I want** a runnable example demonstrating file caching and context injection features
**So that** I can understand how the SDK automatically provides project context to the LLM

---

## Acceptance Criteria

1. **AC1:** Example compiles and runs -- directory exists with main.swift, no build errors
2. **AC2:** FileCache configuration and hit/miss stats -- demonstrates configuring FileCache, set/get, printing stats
3. **AC3:** FileCache invalidation -- demonstrates invalidate(), nil retrieval, eviction stats
4. **AC4:** Git context injection -- demonstrates GitContextCollector.collectGitContext() producing XML block
5. **AC5:** Project document discovery -- demonstrates ProjectDocumentDiscovery.collectProjectContext() with global/project instructions
6. **AC6:** Custom project root -- demonstrates explicitProjectRoot override vs auto-discovery
7. **AC7:** Agent query with context injection -- creates Agent with projectRoot, executes query, system prompt includes context
8. **AC8:** Package.swift updated with ContextInjectionExample executableTarget following existing pattern

---

## Failing Tests Created (RED Phase)

### Compliance Tests - ContextInjectionExampleComplianceTests (40 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/ContextInjectionExampleComplianceTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testPackageSwiftContainsContextInjectionExampleTarget | AC8 | P0 | RED | Package.swift missing ContextInjectionExample target |
| 2 | testContextInjectionExampleTargetDependsOnOpenAgentSDK | AC8 | P0 | RED | Package.swift missing dependency |
| 3 | testContextInjectionExampleTargetSpecifiesCorrectPath | AC8 | P0 | RED | Package.swift missing path |
| 4 | testContextInjectionExampleDirectoryExists | AC1 | P0 | RED | Examples/ContextInjectionExample/ does not exist |
| 5 | testContextInjectionExampleMainSwiftExists | AC1 | P0 | RED | main.swift does not exist |
| 6 | testContextInjectionExampleImportsOpenAgentSDK | AC1 | P0 | RED | File not found |
| 7 | testContextInjectionExampleImportsFoundation | AC1 | P0 | RED | File not found |
| 8 | testContextInjectionExampleHasTopLevelDescriptionComment | AC1 | P1 | RED | File not found |
| 9 | testContextInjectionExampleHasMultipleInlineComments | AC1 | P1 | RED | File not found |
| 10 | testContextInjectionExampleHasMarkSections | AC1 | P1 | RED | File not found |
| 11 | testContextInjectionExampleDoesNotUseForceUnwrap | AC1 | P0 | RED | File not found |
| 12 | testContextInjectionExampleDoesNotExposeRealAPIKeys | AC1 | P0 | RED | File not found |
| 13 | testContextInjectionExampleUsesLoadDotEnvPattern | AC1 | P1 | RED | File not found |
| 14 | testContextInjectionExampleUsesGetEnvPattern | AC1 | P1 | RED | File not found |
| 15 | testContextInjectionExampleUsesAssertions | AC1 | P0 | RED | File not found |
| 16 | testContextInjectionExampleCreatesFileCache | AC2 | P0 | RED | File not found |
| 17 | testContextInjectionExampleConfiguresFileCacheParams | AC2 | P0 | RED | File not found |
| 18 | testContextInjectionExampleUsesCacheSet | AC2 | P0 | RED | File not found |
| 19 | testContextInjectionExampleUsesCacheGet | AC2 | P0 | RED | File not found |
| 20 | testContextInjectionExamplePrintsCacheStats | AC2 | P0 | RED | File not found |
| 21 | testContextInjectionExampleDemonstratesHitAndMiss | AC2 | P0 | RED | File not found |
| 22 | testContextInjectionExampleUsesCacheInvalidate | AC3 | P0 | RED | File not found |
| 23 | testContextInjectionExampleVerifiesNilAfterInvalidation | AC3 | P0 | RED | File not found |
| 24 | testContextInjectionExampleDemonstratesEviction | AC3 | P0 | RED | File not found |
| 25 | testContextInjectionExampleCreatesGitContextCollector | AC4 | P0 | RED | File not found |
| 26 | testContextInjectionExampleCallsCollectGitContext | AC4 | P0 | RED | File not found |
| 27 | testContextInjectionExamplePrintsGitContextBlock | AC4 | P0 | RED | File not found |
| 28 | testContextInjectionExampleUsesTTLParameter | AC4 | P1 | RED | File not found |
| 29 | testContextInjectionExampleCreatesProjectDocumentDiscovery | AC5 | P0 | RED | File not found |
| 30 | testContextInjectionExampleCallsCollectProjectContext | AC5 | P0 | RED | File not found |
| 31 | testContextInjectionExampleAccessesGlobalInstructions | AC5 | P0 | RED | File not found |
| 32 | testContextInjectionExampleAccessesProjectInstructions | AC5 | P0 | RED | File not found |
| 33 | testContextInjectionExampleDemonstratesExplicitProjectRoot | AC6 | P0 | RED | File not found |
| 34 | testContextInjectionExampleDemonstratesAutoDiscovery | AC6 | P0 | RED | File not found |
| 35 | testContextInjectionExampleUsesBypassPermissions | AC7 | P0 | RED | File not found |
| 36 | testContextInjectionExampleUsesCreateAgent | AC7 | P0 | RED | File not found |
| 37 | testContextInjectionExampleSetsProjectRoot | AC7 | P0 | RED | File not found |
| 38 | testContextInjectionExampleExecutesQuery | AC7 | P0 | RED | File not found |
| 39 | testContextInjectionExampleUsesAwait | AC7 | P0 | RED | File not found |
| 40 | testContextInjectionExampleHasFiveParts | AC1 | P1 | RED | File not found |

**Note:** 40 test methods produce 43 assertion failures because some tests contain multiple assertions (e.g., Package.swift tests check content existence before checking specific fields).

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). The ContextInjectionExample is a documentation/example artifact, not a runtime feature. Test levels:
- **Compliance / static analysis tests** for all ACs -- verify file existence, code content, API usage patterns
- **No E2E tests** (no real LLM calls needed; compliance tests only check source code)
- **No unit tests for new logic** (no new SDK types introduced in this story)

### Approach

1. Tests verify that `Examples/ContextInjectionExample/main.swift` exists and contains correct content
2. Content-based assertions check for specific API names (FileCache, cache.set/get/invalidate, GitContextCollector, collectGitContext, ProjectDocumentDiscovery, collectProjectContext, globalInstructions, projectInstructions, explicitProjectRoot, projectRoot)
3. Package.swift assertions verify executableTarget configuration
4. Code quality checks (no force unwrap, no hardcoded API keys, comments, MARK sections)
5. Pattern matching ensures example demonstrates all 5 parts (FileCache Config, FileCache Invalidation, Git Context, Project Discovery, Agent Query)
6. Tests follow the same compliance-test pattern as QueryAbortExampleComplianceTests

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 34 | Core ACs: file existence, API usage, key demonstrations |
| P1 | 6 | Supporting: comments, MARK sections, conventions, TTL parameter |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Directory/file existence, compiles) | 13 | Compliance (file exists, imports, comments, quality, assertions, 5 parts) |
| AC2 (FileCache configuration and stats) | 6 | Compliance (FileCache init, params, set, get, stats, hit/miss) |
| AC3 (FileCache invalidation) | 3 | Compliance (invalidate, nil check, eviction) |
| AC4 (Git context injection) | 4 | Compliance (GitContextCollector, collectGitContext, git-context block, ttl) |
| AC5 (Project document discovery) | 4 | Compliance (ProjectDocumentDiscovery, collectProjectContext, global/project instructions) |
| AC6 (Custom project root) | 2 | Compliance (explicitProjectRoot, nil auto-discovery) |
| AC7 (Agent query with context injection) | 5 | Compliance (bypassPermissions, createAgent, projectRoot, prompt, await) |
| AC8 (Package.swift target) | 3 | Compliance (target, dependency, path) |

---

## Implementation Checklist

### Task 1: Add ContextInjectionExample executableTarget to Package.swift (AC: #8)

**File:** `Package.swift` (MODIFY)

**Tests this makes pass:**
- testPackageSwiftContainsContextInjectionExampleTarget
- testContextInjectionExampleTargetDependsOnOpenAgentSDK
- testContextInjectionExampleTargetSpecifiesCorrectPath

**Implementation steps:**
- [ ] Add `.executableTarget(name: "ContextInjectionExample", dependencies: ["OpenAgentSDK"], path: "Examples/ContextInjectionExample")` to targets array after QueryAbortExample

### Task 2: Create Examples/ContextInjectionExample/main.swift (AC: #1-#7)

**File:** `Examples/ContextInjectionExample/main.swift` (NEW)

**Tests this makes pass:** All 40 compliance tests

**Implementation steps:**
- [ ] Create directory `Examples/ContextInjectionExample/`
- [ ] Create `main.swift` with Chinese + English header comment block
- [ ] Part 1: FileCache Configuration and Stats
  - [ ] Create `FileCache(maxEntries: 3, maxSizeBytes: 1024, maxEntrySizeBytes: 512)`
  - [ ] Store files with `cache.set("path", content: "...")`
  - [ ] Retrieve with `cache.get("path")` to demonstrate hit
  - [ ] Retrieve non-existent key to demonstrate miss
  - [ ] Print `stats` (hitCount, missCount, evictionCount, totalEntries, totalSizeBytes)
  - [ ] Use `assert()` for key validations
- [ ] Part 2: FileCache Invalidation and Eviction
  - [ ] Store entry, verify via `cache.get()`
  - [ ] Call `cache.invalidate()` on the path
  - [ ] Verify `cache.get()` returns nil
  - [ ] Store 4 entries in cache with maxEntries=3 to trigger eviction
  - [ ] Verify evictionCount > 0
  - [ ] Use `assert()` for key validations
- [ ] Part 3: Git Context Collection
  - [ ] Create `GitContextCollector()`
  - [ ] Call `collectGitContext(cwd: FileManager.default.currentDirectoryPath, ttl: 5.0)`
  - [ ] Print raw `<git-context>` block
  - [ ] Assert output contains expected tags (use `if let` / `guard let` for nil safety)
- [ ] Part 4: Project Document Discovery
  - [ ] Create `ProjectDocumentDiscovery()`
  - [ ] Call `collectProjectContext(cwd: ..., explicitProjectRoot: nil)` for auto-discovery
  - [ ] Print `globalInstructions` and `projectInstructions`
  - [ ] Call `collectProjectContext(cwd: ..., explicitProjectRoot: "/some/path")` for custom root
  - [ ] Print results with custom root
  - [ ] Use `assert()` for key validations
- [ ] Part 5: Agent Query with Context Injection
  - [ ] Create Agent with `loadDotEnv()`/`getEnv()` and `permissionMode: .bypassPermissions`
  - [ ] Set `projectRoot` to current project directory
  - [ ] Execute a short query asking about project files
  - [ ] Print result text
  - [ ] Note that system prompt contained context injection
  - [ ] Use `assert()` for key validations
- [ ] Use `loadDotEnv()` and `getEnv()` patterns for API key
- [ ] Add MARK section comments for each part
- [ ] Add inline comments explaining each concept
- [ ] Ensure no force unwraps

### Task 3: Verify build and full test suite

- [ ] `swift build` compiles with no errors (including ContextInjectionExample target)
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter "ContextInjectionExampleComplianceTests"

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 40 compliance tests written in 1 test file, all failing because the example file does not exist yet
- Tests cover all 8 acceptance criteria
- Tests use same helper pattern as QueryAbortExampleComplianceTests (projectRoot, fileContent)
- Tests verify both structural (file exists, Package.swift) and content (API usage, patterns)

**Verification:**
- Tests do NOT pass (ContextInjectionExample directory doesn't exist -- expected for RED phase)
- Failures are clean: "Examples/ContextInjectionExample/ directory should exist"
- No crashes or unexpected behavior

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (Package.swift update) -- makes 3 tests pass
2. **Then Task 2** (Create ContextInjectionExample/main.swift) -- makes remaining 37 tests pass
3. **Finally Task 3** -- verify full suite passes

**Key Principles:**
- Follow the QueryAbortExample and ModelSwitchingExample patterns for structure
- FileCache, GitContextCollector, and ProjectDocumentDiscovery all exist from Epic 12
- Parts 1-4 are LOCAL demos (no API calls needed) -- deterministic and always work
- Only Part 5 (Agent query) requires an API key
- Use `nonisolated(unsafe)` let bindings when capturing in Task closures (Swift 6 concurrency)
- Use `assert()` for key validations to support compliance test verification
- Use `if let` / `guard let` for nil-safety (collectGitContext returns nil outside git repos)
- FileCache is standalone -- can be created without an Agent
- GitContextCollector is standalone -- can be created without an Agent
- ProjectDocumentDiscovery is standalone -- can be created without an Agent

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency with existing examples)
3. Ensure the example runs correctly: `swift run ContextInjectionExample`
4. Verify the example gracefully handles missing API key (Part 5 only)

---

## Key Risks and Assumptions

1. **Assumption: FileCache, GitContextCollector, ProjectDocumentDiscovery are stable and public** -- Epic 12 is complete with all APIs available.
2. **Assumption: Parts 1-4 are deterministic** -- No API calls, all local operations. FileCache, GitContextCollector, and ProjectDocumentDiscovery work without network access.
3. **Assumption: This project IS a git repo** -- collectGitContext() should return non-nil result when using the project's cwd.
4. **Assumption: This project has CLAUDE.md** -- collectProjectContext() should find project instructions.
5. **Risk: Custom project root path** -- AC6 requires demonstrating explicitProjectRoot. Using "/some/path" may or may not exist, so the example should handle both cases gracefully.
6. **Risk: API key availability** -- Part 5 requires an API key. The example should use the loadDotEnv/getEnv fallback pattern like other examples.
7. **Assumption: Agent buildSystemPrompt automatically injects context** -- The Agent's buildSystemPrompt() method includes git-context, global-instructions, and project-instructions blocks. Part 5 demonstrates this integration.

---

**Generated by BMad TEA Agent** - 2026-04-13
