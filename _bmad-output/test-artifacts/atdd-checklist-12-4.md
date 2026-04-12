---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/12-4-project-document-discovery.md'
  - 'Sources/OpenAgentSDK/Utils/GitContextCollector.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Tests/OpenAgentSDKTests/Utils/GitContextCollectorTests.swift'
---

# ATDD Checklist - Epic 12, Story 4: Project Document Discovery

**Date:** 2026-04-12
**Author:** Nick (TEA Agent)
**Primary Test Level:** Unit (Swift backend project)

---

## Story Summary

The SDK should automatically discover and load project-level instruction files (CLAUDE.md, AGENT.md) and global instruction files (~/.claude/CLAUDE.md), injecting them into the agent's system prompt so the LLM receives project-specific behavioral guidance.

**As a** developer
**I want** the SDK to automatically discover and load project-level instruction files
**So that** the LLM receives project-specific behavioral guidance

---

## Acceptance Criteria

1. **AC1:** CLAUDE.md injected into system prompt as `<project-instructions>` block
2. **AC2:** Global instructions (~/.claude/CLAUDE.md) and project instructions are separated into `<global-instructions>` and `<project-instructions>` blocks
3. **AC3:** CLAUDE.md and AGENT.md merged into single `<project-instructions>` block (CLAUDE.md first)
4. **AC4:** Custom project root via `SDKConfiguration.projectRoot` / `AgentOptions.projectRoot`
5. **AC5:** Large files (>100KB) truncated with truncation comment
6. **AC6:** Non-UTF-8 files gracefully skipped (no crash, log warning)
7. **AC7:** Project root discovery via .git directory traversal from cwd
8. **AC8:** No instruction files -- no error, no extra blocks in system prompt

---

## Failing Tests Created (RED Phase)

### Unit Tests (25 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/ProjectDocumentDiscoveryTests.swift` (~470 lines)

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testAC1_CollectContext_CLAUDEmd_ContainsProjectInstructions | AC1 | P0 | RED | `ProjectDocumentDiscovery` type not found |
| 2 | testAC1_BuildSystemPrompt_WithCLAUDEmd_ContainsProjectInstructionsBlock | AC1 | P0 | RED | `projectRoot` argument not on `AgentOptions` |
| 3 | testAC2_GlobalAndProjectInstructions_Separated | AC2 | P0 | RED | `collectProjectContext(cwd:explicitProjectRoot:homeDirectory:)` not found |
| 4 | testAC2_BuildSystemPrompt_GlobalAndProject_SeparateBlocks | AC2 | P1 | RED | `projectRoot` argument not on `AgentOptions` |
| 5 | testAC3_CLAUDEmdAndAGENTmd_MergedInCorrectOrder | AC3 | P0 | RED | `ProjectDocumentDiscovery` type not found |
| 6 | testAC3_OnlyAGENTmd_LoadsSuccessfully | AC3 | P1 | RED | `ProjectDocumentDiscovery` type not found |
| 7 | testAC4_ExplicitProjectRoot_UsesSpecifiedPath | AC4 | P0 | RED | `collectProjectContext` method not found |
| 8 | testAC4_SDKConfiguration_ProjectRoot_PassedToAgentOptions | AC4 | P1 | RED | `projectRoot` not on `SDKConfiguration` |
| 9 | testAC5_LargeFile_TruncatedTo100KB | AC5 | P0 | RED | `ProjectDocumentDiscovery` type not found |
| 10 | testAC5_TruncationComment_ContainsOriginalSize | AC5 | P1 | RED | `ProjectDocumentDiscovery` type not found |
| 11 | testAC6_NonUTF8File_ReturnsNilWithoutCrash | AC6 | P0 | RED | `ProjectDocumentDiscovery` type not found |
| 12 | testAC7_DiscoverProjectRoot_TraversesUpToGitDir | AC7 | P0 | RED | `collectProjectContext` method not found |
| 13 | testAC7_NoGitDir_UsesCwdAsProjectRoot | AC7 | P1 | RED | `collectProjectContext` method not found |
| 14 | testAC8_NoInstructionFiles_ReturnsNilInstructions | AC8 | P0 | RED | `collectProjectContext(cwd:explicitProjectRoot:homeDirectory:)` not found |
| 15 | testAC8_BuildSystemPrompt_NoInstructionFiles_NoExtraBlocks | AC8 | P1 | RED | `projectRoot` not on `AgentOptions` (no error expected) |
| 16 | testIntegration_BuildSystemPrompt_CorrectConcatenationOrder | Integration | P0 | RED | `ProjectDocumentDiscovery` integration not built |
| 17 | testIntegration_BuildSystemPrompt_NoGit_WithProjectInstructions | Integration | P1 | RED | `buildSystemPrompt()` not yet injects project docs |
| 18 | testCaching_SecondCall_ReturnsCachedResult | Caching | P0 | RED | `ProjectDocumentDiscovery` type not found |
| 19 | testCaching_DifferentCwd_DifferentResult | Caching | P1 | RED | `collectProjectContext` method not found |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM). Test levels:
- **Unit tests** for `ProjectDocumentDiscovery` (pure logic: file reading, path discovery, truncation, encoding)
- **Unit tests** for `Agent.buildSystemPrompt()` integration (system prompt concatenation)
- **No E2E/browser tests** (no UI component)

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 10 | Core ACs: injection, separation, merging, custom root, truncation, encoding, discovery, no-file |
| P1 | 9 | Supporting: block format, order, size info, fallback, pass-through |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (CLAUDE.md injection) | 2 | Unit + Integration |
| AC2 (Global/project separation) | 2 | Unit + Integration |
| AC3 (CLAUDE.md + AGENT.md merge) | 2 | Unit |
| AC4 (Custom project root) | 2 | Unit |
| AC5 (Large file truncation) | 2 | Unit |
| AC6 (Non-UTF-8 handling) | 1 | Unit |
| AC7 (Project root discovery) | 2 | Unit |
| AC8 (No instruction files) | 2 | Unit + Integration |
| Integration (order, no-git) | 2 | Integration |
| Caching | 2 | Unit |

---

## Implementation Checklist

### Task 1: Create ProjectDocumentDiscovery.swift

**File:** `Sources/OpenAgentSDK/Utils/ProjectDocumentDiscovery.swift`

**Tests this makes pass:**
- testAC1_CollectContext_CLAUDEmd_ContainsProjectInstructions
- testAC3_CLAUDEmdAndAGENTmd_MergedInCorrectOrder
- testAC3_OnlyAGENTmd_LoadsSuccessfully
- testAC4_ExplicitProjectRoot_UsesSpecifiedPath
- testAC5_LargeFile_TruncatedTo100KB
- testAC5_TruncationComment_ContainsOriginalSize
- testAC6_NonUTF8File_ReturnsNilWithoutCrash
- testAC7_DiscoverProjectRoot_TraversesUpToGitDir
- testAC7_NoGitDir_UsesCwdAsProjectRoot
- testAC8_NoInstructionFiles_ReturnsNilInstructions
- testCaching_SecondCall_ReturnsCachedResult
- testCaching_DifferentCwd_DifferentResult

**Implementation steps:**
- [ ] Create `public final class ProjectDocumentDiscovery: @unchecked Sendable` with `NSLock`
- [ ] Create `public struct ProjectContextResult: Sendable` with `globalInstructions: String?` and `projectInstructions: String?`
- [ ] Implement `public func collectProjectContext(cwd: String, explicitProjectRoot: String?, homeDirectory: String? = nil) -> ProjectContextResult`
- [ ] Implement `private func discoverProjectRoot(from cwd: String) -> String` (traverse up for .git)
- [ ] Implement `private func readFileContent(at path: String, maxSizeKB: Int = 100) -> String?` (with truncation + encoding handling)
- [ ] Implement `private func normalizePath(_ path: String) -> String` (standardizingPath + resolvingSymlinksInPath)
- [ ] Add caching: `cachedResult`, `cachedCwd` protected by `lock`

### Task 2: Add projectRoot to SDKConfiguration

**File:** `Sources/OpenAgentSDK/Types/SDKConfiguration.swift`

**Tests this makes pass:**
- testAC4_SDKConfiguration_ProjectRoot_PassedToAgentOptions

**Implementation steps:**
- [ ] Add `public var projectRoot: String?` (default nil)
- [ ] Update `init()` with `projectRoot` parameter
- [ ] Update `resolved()` to pass `projectRoot`
- [ ] Update `description` and `debugDescription`

### Task 3: Add projectRoot to AgentOptions

**File:** `Sources/OpenAgentSDK/Types/AgentTypes.swift`

**Tests this makes pass:**
- testAC1_BuildSystemPrompt_WithCLAUDEmd_ContainsProjectInstructionsBlock
- testAC2_BuildSystemPrompt_GlobalAndProject_SeparateBlocks
- testAC8_BuildSystemPrompt_NoInstructionFiles_NoExtraBlocks

**Implementation steps:**
- [ ] Add `public var projectRoot: String?` (default nil)
- [ ] Update `init()` with `projectRoot` parameter
- [ ] Update `init(from:)` to read `projectRoot` from `SDKConfiguration`

### Task 4: Integrate into Agent.buildSystemPrompt()

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tests this makes pass:**
- testIntegration_BuildSystemPrompt_CorrectConcatenationOrder
- testIntegration_BuildSystemPrompt_NoGit_WithProjectInstructions

**Implementation steps:**
- [ ] Add `private let projectDocumentDiscovery = ProjectDocumentDiscovery()` instance
- [ ] Modify `buildSystemPrompt()` to call `collectProjectContext(cwd:explicitProjectRoot:)`
- [ ] Append `<global-instructions>` block if global instructions exist
- [ ] Append `<project-instructions>` block if project instructions exist
- [ ] Order: systemPrompt -> git-context -> global-instructions -> project-instructions

### Task 5: Verify all tests pass

- [ ] `swift build` compiles without errors
- [ ] `swift test` -- all tests pass (including 2377+ existing tests)
- [ ] Check AgentLoopTests for cwd isolation issues

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter ProjectDocumentDiscoveryTests

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- All 19 tests written and failing (compilation errors)
- Tests cover all 8 acceptance criteria
- Tests follow Given-When-Then format
- Test isolation via temporary directories (no real filesystem dependency)

**Verification:**
- Build fails with: `cannot find type 'ProjectDocumentDiscovery' in scope`
- Build fails with: `extra argument 'projectRoot' in call`
- All failures are due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (ProjectDocumentDiscovery.swift) -- makes most tests compilable
2. **Then Task 2+3** (SDKConfiguration + AgentOptions) -- enables `projectRoot` parameter
3. **Then Task 4** (Agent integration) -- makes integration tests pass
4. **Finally Task 5** -- verify full suite passes

**Key Principles:**
- One test at a time (fix compilation, then fix assertions)
- Minimal implementation (don't over-engineer)
- Run tests frequently (immediate feedback)
- Check existing AgentLoopTests for cwd isolation after modifying `buildSystemPrompt()`

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Verify all 2377+ tests pass
2. Review code quality (readability, maintainability)
3. Ensure consistency with GitContextCollector patterns
4. Verify no import violations (Utils/ is leaf module)
5. Check logger integration points

---

## Key Risks and Assumptions

1. **Risk: AgentLoopTests cwd isolation** -- Story 12.3 required fixing AgentLoopTests to use non-Git temp directories. Story 12.4 may similarly need existing tests to use isolated directories.
2. **Assumption: `collectProjectContext` has optional `homeDirectory` parameter** -- This allows tests to override the home directory for global instruction tests without touching the real `~/.claude/CLAUDE.md`.
3. **Assumption: Caching is per-instance** -- `ProjectDocumentDiscovery` caches results per Agent instance, not globally.
4. **Risk: File encoding** -- Non-UTF-8 handling test uses Data directly; verify FileManager behavior on edge cases.

---

## Knowledge Base References Applied

- **GitContextCollector pattern** -- Thread-safe `final class` + `@unchecked Sendable` + `NSLock` + caching (referenced from `Sources/OpenAgentSDK/Utils/GitContextCollector.swift`)
- **Given-When-Then test format** -- Consistent with existing `GitContextCollectorTests.swift` patterns
- **Test isolation** -- Temporary directories with UUID-based names, cleanup in `tearDown()`
- **buildSystemPrompt() integration** -- Concatenation order from story spec

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**
```
error: cannot find type 'ProjectDocumentDiscovery' in scope
error: extra argument 'projectRoot' in call
error: 'nil' requires a contextual type
```

**Summary:**
- Total tests: 19
- Passing: 0 (expected -- compilation failures)
- Failing: 19 (expected -- types and methods not yet implemented)
- Status: RED phase verified

---

**Generated by BMad TEA Agent** - 2026-04-12
