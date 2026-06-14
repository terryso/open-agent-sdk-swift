---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
lastStep: step-04-generate-tests
lastSaved: '2026-06-14'
storyId: '29.3'
storyKey: 29-3-direct-skill-package-context
storyFile: _bmad-output/implementation-artifacts/29-3-direct-skill-package-context.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-29-3-direct-skill-package-context.md
generatedTestFiles:
  - Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift
  - Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/29-3-direct-skill-package-context.md
  - _bmad-output/project-context.md
---

# ATDD Red-Phase Checklist — Story 29.3: Direct Skill Package Context

- **Story ID:** 29-3
- **Epic:** 29 (Claude Code Skill/Subagent Compatibility)
- **Phase:** RED (TDD red-green-refactor)
- **Mode:** yolo (auto-approval)
- **Date:** 2026-06-14
- **Test Files:**
  - `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift` (extended)
  - `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift` (extended)
- **Story Spec:** `_bmad-output/implementation-artifacts/29-3-direct-skill-package-context.md`

## Stack Detection

- **Detected stack:** backend (Swift Package Manager, XCTest, no browser testing layer)
- **Generation mode:** AI generation (no recording mode for backend)
- **Execution mode:** sequential (Swift backend; no subagent/agent-team dispatch)

## Acceptance Criteria → Test Mapping

| AC | Description | Test Name | Suite | Priority | Red? |
|----|-------------|-----------|-------|----------|------|
| AC1 | Filesystem skill prompt contains the **absolute** baseDir | `testExecuteSkillStream_promptContainsAbsoluteBaseDir_whenFilesystemSkill` | Stream | P0 | YES — `XCTAssertTrue failed - Expected prompt to contain absolute baseDir` |
| AC1 | Filesystem skill prompt lists supporting files in **relative** form (NOT expanded to absolute) | `testExecuteSkillStream_promptContainsRelativeSupportingFiles` | Stream | P0 | YES — `XCTAssertTrue failed - Expected prompt to list supporting file as relative path` |
| AC2 | Prompt must NOT inline supporting file contents (progressive disclosure) | `testExecuteSkillStream_promptDoesNotContainSupportingFileContents` | Stream | P1 | NO (intentional guard rail — passes today because current source never inlines content; locks against future regression) |
| AC2 | Prompt shape ordering: `promptTemplate` → `Skill package context:` → `User request:` | `testExecuteSkillStream_promptShape_followsEpicSpec` | Stream | P0 | YES — `'Skill package context:' marker not found` |
| AC3 | Programmatic skill keeps legacy prompt shape exactly (regression guard) | `testExecuteSkillStream_promptUnchanged_whenProgrammaticSkill` | Stream | P0 | NO (intentional guard rail — passes today because current source emits legacy shape for skills without baseDir/supportingFiles; locks against future regression) |
| AC3/AC5 | Programmatic skill with no args omits `User request:` line | `testExecuteSkillStream_promptUnchanged_whenProgrammaticSkillNoArgs` | Stream | P1 | NO (intentional guard rail — passes today; current behavior already correct) |
| AC4 | Skill with only `baseDir` (no supportingFiles) emits `baseDir:` line, omits `supportingFiles:` | `testExecuteSkillStream_promptHasPackageContext_whenOnlyBaseDir` | Stream | P1 | YES — `Prompt must contain 'Skill package context:' block when baseDir is set` |
| AC4 | Skill with only `supportingFiles` (`baseDir == nil`) emits supportingFiles section and flags missing baseDir | `testExecuteSkillStream_promptHasPackageContext_whenOnlySupportingFiles` | Stream | P1 | YES — `Prompt must contain 'Skill package context:' block when supportingFiles non-empty` |
| AC1 | (Non-stream path) Filesystem skill prompt contains absolute baseDir + relative supportingFiles | `testExecuteSkill_promptContainsAbsoluteBaseDir_whenFilesystemSkill` | Non-stream | P0 | YES — `Expected prompt to contain absolute baseDir` |
| AC3 | (Non-stream path) Programmatic skill keeps legacy prompt shape (regression guard) | `testExecuteSkill_promptUnchanged_whenProgrammaticSkill` | Non-stream | P0 | NO (intentional guard rail — passes today; locks against future regression) |
| AC2 | (Non-stream path) Prompt shape ordering follows epic spec | `testExecuteSkill_promptShape_followsEpicSpec` | Non-stream | P0 | YES — `'Skill package context:' marker not found` |

### Coverage Summary

- **8 RED tests** (fail today, will pass after implementation): cover AC1, AC2 (positive shape), AC4 (both edge cases) — 5 stream + 2 non-stream + 1 stream AC2 shape
- **3 guard-rail tests** (pass today by design): cover AC2 (negative — no content inline), AC3 (backward compat for both stream and non-stream)
- **AC5** ("User request:" behavior) is exercised implicitly inside every test that passes `args`; the dedicated no-args test (`testExecuteSkillStream_promptUnchanged_whenProgrammaticSkillNoArgs`) confirms the absent-args path
- **AC6** (build + full regression) is a dev-story concern, not an ATDD scaffold; it will be validated by `bmad-dev-story` at green phase

## Red-Phase Verification (executed)

- `swift build --target OpenAgentSDK` → SUCCESS (SDK source unchanged — confirms no feature yet)
- `swift build --build-tests` → SUCCESS (all 11 new test methods compile; mock URL protocol extensions compile)
- `swift test --filter ExecuteSkillStreamTests` →
  - **Existing 6 tests:** all PASS (no regression)
  - **New 8 tests:** 6 FAIL (red), 2 PASS (guard rails)
- `swift test --filter ExecuteSkillTests` →
  - **Existing 7 tests:** all PASS (no regression)
  - **New 3 tests:** 2 FAIL (red), 1 PASS (guard rail)
- Aggregate: 11 new tests, 8 red / 3 green (guard rails)

### Why 3 tests intentionally pass today

These are **defensive guard rails**, not premature green:

1. **`testExecuteSkillStream_promptDoesNotContainSupportingFileContents`** — asserts a unique-token is ABSENT from the prompt. Today no implementation inlines content, so this trivially passes. After implementation, it locks the progressive-disclosure contract so a future regression cannot silently leak file contents.
2. **`testExecuteSkillStream_promptUnchanged_whenProgrammaticSkill`** (stream) and **`testExecuteSkill_promptUnchanged_whenProgrammaticSkill`** (non-stream) — assert that programmatic skills (`baseDir == nil && supportingFiles == []`) still emit the exact legacy prompt shape. Today this is current behavior; after implementation it locks AC3 backward-compat so the new helper cannot accidentally mutate the legacy branch.

All 3 must remain green after the GREEN phase. They are written to fail loudly on regression, not to satisfy a passing-test quota.

## Observation Strategy

`resolveSkillForExecution` is `private`, so the only observable side effect is the request body sent to `https://api.anthropic.com/v1/messages`. The story spec (Task 4.4) mandates extending `SkillStreamMockURLProtocol` with `lastRequestBody: Data?`, captured via the existing `readRequestBodyFromStream(_:)` helper from `MockURLProtocolHelpers.swift`. Implemented verbatim.

For the non-stream path (`ExecuteSkillTests.swift`), the file previously had no request-capturing mock. Per story Task 4.3 the dev-story direction permits either reusing `SkillStreamMockURLProtocol` or adding a parallel mock. We added a focused `SkillRequestRecordingURLProtocol` in the same file (mirrors the stream mock's recording pattern; returns a minimal non-streaming Anthropic JSON response). This is preferred over routing the non-stream test through a stream mock, because the two paths use different request shapes (stream vs non-stream) and the mock must return a matching response to let `executeSkill` complete without throwing.

**Note on JSON escaping:** the legacy-prompt assertions match the JSON-escaped form (`\\n\\n---\\n`) rather than literal newlines, because `AnthropicClient` serializes the message via JSON. This is documented inline in each affected test.

## Conventions Followed

- **XCTest only** (project-context.md rule #23)
- **Test location mirrors source** (rule #24): both files are in `Tests/OpenAgentSDKTests/Tools/Advanced/`, alongside the existing skill-execution tests
- **Mock-based, no real network I/O** (rule #27): all 11 tests inject an `AnthropicClient` whose `urlSession` is wired to a `URLProtocol` subclass via `makeMockURLSession(protocolClass:)`
- **No new file created** (story Task 4.5): extended existing files only
- **Reused `readRequestBodyFromStream`** + `makeMockURLSession` (rule #56 — do not duplicate mock infra)
- **No `Task` Swift type introduced** (rule #15)
- **No force-unwrap on captured body** (rule #40): every test uses `guard let body = ... else { XCTFail(...); return }`
- **E2E deferred** to Story 29.7 (rule #29) — no E2E scaffolds generated here
- **Single-action tests**: each test exercises exactly one `executeSkill` / `executeSkillStream` invocation and asserts one prompt characteristic

## Decisions

- **Mock reuse:** Extended `SkillStreamMockURLProtocol` per story Task 4.4 (added `nonisolated(unsafe) static var lastRequestBody`, recorded in `startLoading()`, cleared in `reset()`). Added a parallel `SkillRequestRecordingURLProtocol` for the non-stream path because (a) the existing non-stream tests had no request-capturing mock at all, and (b) the non-stream path requires a different mock response shape (`application/json` non-streaming message, not `text/event-stream`). Both mocks reuse `readRequestBodyFromStream` and `makeMockURLSession`.
- **Helper extraction in tests:** Added `driveExecuteSkillAndCaptureBody(skill:args:)` in `ExecuteSkillTests` to collapse the repeated registry + client + agent + execute + capture boilerplate across the 3 non-stream tests. Keeps each test focused on assertions.
- **AC2 negative guard rail:** `testExecuteSkillStream_promptDoesNotContainSupportingFileContents` does not require a real file on disk — it simply asserts a sentinel token (never written anywhere) is absent. This satisfies the progressive-disclosure contract without violating rule #27 (no real I/O).
- **JSON escaping in legacy assertions:** Legacy-shape substring assertions use `\\n\\n---\\n` (escaped) rather than literal `\n\n---\n`, because the captured body is the JSON payload, not a raw prompt string. Documented inline to prevent confusion.

## Files Modified

- `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift`
  - Extended `SkillStreamMockURLProtocol` with `lastRequestBody: Data?` (captured in `startLoading`, cleared in `reset`)
  - Added `// MARK: - Story 29.3: Direct Skill Package Context` section with 8 new test methods (5 RED + 2 guard rails + 1 no-args guard rail)
- `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift`
  - Added `// MARK: - Story 29.3: Direct Skill Package Context` section with 3 new test methods (2 RED + 1 guard rail)
  - Added `private func driveExecuteSkillAndCaptureBody(...)` test helper
  - Added new `SkillRequestRecordingURLProtocol` mock URL protocol (mirrors the stream mock's recording pattern; serves a minimal non-streaming Anthropic response)

## Next Steps

- Hand off to **bmad-dev-story** to implement the GREEN phase:
  1. Extract `private func buildSkillExecutionPrompt(skill: Skill, args: String?) -> String` in `Sources/OpenAgentSDK/Core/Agent.swift` (Story Task 1)
  2. Insert the compact `Skill package context:` block when `baseDir != nil` or `!supportingFiles.isEmpty` (Story Task 2)
  3. Keep the legacy branch byte-identical for programmatic skills (Story Task 3)
  4. Verify all 8 currently-red tests go green; verify the 3 guard rails stay green; run full `swift test` suite and report total count
- After GREEN, run `bmad-testarch-trace` for the traceability matrix.
