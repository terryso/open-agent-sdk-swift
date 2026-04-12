---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-12'
story_id: '12-3'
story_name: 'Git Status Injection'
tdd_phase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/12-3-git-status-injection.md'
  - 'Sources/OpenAgentSDK/Utils/FileCache.swift'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Tests/OpenAgentSDKTests/Utils/FileCacheTests.swift'
  - 'Tests/OpenAgentSDKTests/Utils/SDKConfigurationTests.swift'
detected_stack: 'backend'
generation_mode: 'AI Generation (backend project, no browser recording)'
---

# ATDD Checklist: Story 12.3 -- Git Status Injection

## TDD Red Phase (Current)

**Status: RED** -- All tests reference unimplemented APIs and will not compile until features are implemented.

### Test Files Created

| File | Tests | Priority Coverage | Status |
|------|-------|-------------------|--------|
| `Tests/OpenAgentSDKTests/Utils/GitContextCollectorTests.swift` | 16 | P0: 8, P1: 6, P2: 2 | RED (compilation errors) |

**Total: 16 failing tests** (all in TDD RED phase)

---

## Acceptance Criteria Coverage

### AC1: Git Context Injected into System Prompt

> Given Agent executing in a Git repo, when query starts (`agent.stream("help me commit")`), the system prompt sent to LLM contains a formatted `<git-context>` block with Branch, Main branch, Git user, Status, and Recent commits.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC1_CollectGitContext_InGitRepo_ReturnsFormattedBlock` | P0 | Full `<git-context>` block with all fields |
| `testAC1_CollectGitContext_ContainsBranch` | P0 | Branch field present and correct |
| `testAC1_CollectGitContext_ContainsMainBranch` | P1 | Main branch detection (main/master) |
| `testAC1_CollectGitContext_ContainsGitUser` | P1 | Git user.name present |
| `testAC1_CollectGitContext_ContainsStatus` | P0 | Status section with modified files |
| `testAC1_CollectGitContext_ContainsRecentCommits` | P0 | Recent commits section |
| `testAC1_BuildSystemPrompt_WithGitContext_AppendsToExistingPrompt` | P0 | Agent.buildSystemPrompt() appends git context |
| `testAC1_BuildSystemPrompt_GitContextOnly_NoSystemPrompt` | P1 | Git context used as system prompt when none set |

### AC2: Non-Git Repository No Error

> Given Agent not in a Git repo (`git rev-parse --git-dir` returns non-zero), when query starts, system prompt has no `<git-context>` block and query executes normally.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC2_CollectGitContext_NotGitRepo_ReturnsNil` | P0 | Returns nil for non-Git directory |
| `testAC2_BuildSystemPrompt_NotGitRepo_ReturnsOriginalPrompt` | P0 | buildSystemPrompt() returns original prompt unchanged |

### AC3: Git Status Truncation

> Given `git status --short` output exceeds 2000 characters, when injecting Git status, truncate to 2000 chars and append truncation message.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC3_StatusExceeds2000Chars_TruncatesWithMessage` | P0 | Truncation at 2000 chars with message |
| `testAC3_StatusUnder2000Chars_NoTruncation` | P1 | No truncation when under limit |

### AC4: Git Status Cache TTL

> Given two consecutive queries within `SDKConfiguration.gitCacheTTL` (default 5s), second query uses cached Git status (Process not called again). If TTL expired, refresh cache. Developer can set `config.gitCacheTTL = 0` to disable caching.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC4_SecondCallWithinTTL_ReturnsCachedResult` | P0 | Cache hit within TTL |
| `testAC4_AfterTTLExpires_RefreshesCache` | P0 | Cache miss after TTL |
| `testAC4_TTLZero_AlwaysRefreshes` | P1 | TTL=0 disables caching |
| `testAC4_DifferentCwd_DifferentCache` | P1 | Different cwd uses different cache |

---

## Compilation Errors (Expected -- TDD Red Phase)

These errors confirm the tests correctly reference unimplemented APIs:

1. `Cannot find 'GitContextCollector' in scope` (16 occurrences)
2. `value of type 'SDKConfiguration' has no member 'gitCacheTTL'` (multiple occurrences)
3. `value of type 'AgentOptions' has no member 'gitCacheTTL'` (multiple occurrences)
4. `value of type 'Agent' has no member 'buildSystemPrompt'` -- may already exist but missing git context integration

---

## Implementation Checklist

### Task 1: Create GitContextCollector utility class (AC: #1, #2, #3, #4)

- [ ] Create `Sources/OpenAgentSDK/Utils/GitContextCollector.swift`
- [ ] Implement `public final class GitContextCollector: @unchecked Sendable`
- [ ] Implement `private func runGitCommand(_ command: String, cwd: String, timeoutMs: Int = 5000) -> String?`
- [ ] Implement `private func detectMainBranch(cwd: String) -> String?`
- [ ] Implement `public func collectGitContext(cwd: String, ttl: TimeInterval) -> String?`
- [ ] Implement cache state: `cachedContext`, `cachedCwd`, `cacheTimestamp`, protected by `NSLock`
- [ ] Implement truncation logic for `git status --short` output > 2000 chars

### Task 2: Add SDKConfiguration and AgentOptions configuration parameters (AC: #4)

- [ ] Add `public var gitCacheTTL: TimeInterval` (default 5.0) to `SDKConfiguration`
- [ ] Update `SDKConfiguration.init()`, `resolved()`, `description`, `debugDescription`
- [ ] Add `public var gitCacheTTL: TimeInterval` (default 5.0) to `AgentOptions`
- [ ] Update `AgentOptions.init()`, `init(from:)`

### Task 3: Modify Agent.buildSystemPrompt() to integrate Git context (AC: #1, #2)

- [ ] Add `private let gitContextCollector = GitContextCollector()` instance property
- [ ] Modify `buildSystemPrompt()` to call `gitContextCollector.collectGitContext(cwd:ttl:)`
- [ ] Append `<git-context>` block to systemPrompt or use as standalone
- [ ] Ensure nil Git context returns original systemPrompt unchanged

---

## Next Steps (TDD Green Phase)

After implementing the features above:

1. Run `swift build --build-tests` to verify compilation
2. Run `swift test` to verify tests pass (green phase)
3. Run full test suite to verify no regressions
4. Commit passing tests
