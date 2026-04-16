# Story 17.2: AgentOptions Complete Parameters / AgentOptions 完整参数

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an SDK developer,
I want to fill in all missing `AgentOptions` fields from the TypeScript SDK into the Swift SDK,
so that developers migrating from TypeScript don't have to compromise on functionality.

## Acceptance Criteria

1. **AC1: Core configuration fields** -- `AgentOptions` gains: `fallbackModel: String?`, `env: [String: String]?`, `allowedTools: [String]?`, `disallowedTools: [String]?`. All are optional, backward-compatible. `disallowedTools` takes priority over `allowedTools` and `permissionMode` when filtering tools.

2. **AC2: Advanced configuration fields** -- `AgentOptions` gains: `effort: EffortLevel?` (low/medium/high/max), `outputFormat: OutputFormat?` (json_schema), `toolConfig: ToolConfig?`, `includePartialMessages: Bool` (default true), `promptSuggestions: Bool` (default false). `effort` maps to the API request's thinking parameter; `outputFormat` carries a JSON Schema for structured output.

3. **AC3: Session configuration fields** -- `AgentOptions` gains: `continueRecentSession: Bool` (default false), `forkSession: Bool` (default false), `resumeSessionAt: String?`, `persistSession: Bool` (default true). These integrate with existing `sessionStore` and `sessionId` fields.

4. **AC4: EffortLevel enum** -- New `EffortLevel` enum: `.low`, `.medium`, `.high`, `.max`. Conforms to `Sendable`, `Equatable`, `CaseIterable`, `String`. Maps to API-level thinking budget tokens.

5. **AC5: OutputFormat type** -- New `OutputFormat` struct: `{ type: "json_schema", jsonSchema: [String: Any] }`. Conforms to `Sendable`. Use a wrapper approach for `[String: Any]` Sendable compliance (similar to `SendableStructuredOutput` pattern from Story 17-1).

6. **AC6: ToolConfig type** -- New `ToolConfig` struct for tool behavior configuration. Conforms to `Sendable`. Fields: `maxConcurrentReadTools: Int?`, `maxConcurrentWriteTools: Int?`.

7. **AC7: systemPrompt preset support** -- `systemPrompt` supports `SystemPromptConfig.preset(name:append:)` mode via a new `SystemPromptConfig` enum with `.text(String)` and `.preset(name:String, append:String?)` cases. The existing `systemPrompt: String?` property remains for backward compatibility; a new `systemPromptConfig: SystemPromptConfig?` property is added alongside it.

8. **AC8: Build and test** -- `swift build` zero errors zero warnings, 3722+ tests zero regression (1 known flaky timeout test `testDurationIsMeasuredInMilliseconds` is pre-existing and unrelated).

## Tasks / Subtasks

- [ ] Task 1: Core configuration fields (AC: #1)
  - [ ] Add `fallbackModel: String?` to AgentOptions
  - [ ] Add `env: [String: String]?` to AgentOptions
  - [ ] Add `allowedTools: [String]?` to AgentOptions
  - [ ] Add `disallowedTools: [String]?` to AgentOptions
  - [ ] Add parameters to AgentOptions.init() with default nil values
  - [ ] Add parameters to AgentOptions.init(from:) with default nil values
  - [ ] Implement tool whitelist/blacklist filtering in Agent.swift prompt/stream methods (apply after tool pool assembly, before API call)
  - [ ] DisallowedTools priority: if a tool name appears in both lists, it is blocked

- [ ] Task 2: Advanced configuration fields (AC: #2, #4, #5, #6)
  - [ ] Create `EffortLevel` enum in `Types/EffortLevel.swift` (or add to AgentTypes.swift)
  - [ ] Create `OutputFormat` struct with `SendableJSONSchema` wrapper pattern
  - [ ] Create `ToolConfig` struct with optional concurrency fields
  - [ ] Add `effort: EffortLevel?` to AgentOptions
  - [ ] Add `outputFormat: OutputFormat?` to AgentOptions
  - [ ] Add `toolConfig: ToolConfig?` to AgentOptions
  - [ ] Add `includePartialMessages: Bool` (default true) to AgentOptions
  - [ ] Add `promptSuggestions: Bool` (default false) to AgentOptions
  - [ ] Wire effort level to thinking config in Agent loop (effort overrides thinking budget when both set)

- [ ] Task 3: Session configuration fields (AC: #3)
  - [ ] Add `continueRecentSession: Bool` (default false) to AgentOptions
  - [ ] Add `forkSession: Bool` (default false) to AgentOptions
  - [ ] Add `resumeSessionAt: String?` to AgentOptions
  - [ ] Add `persistSession: Bool` (default true) to AgentOptions
  - [ ] Integrate `continueRecentSession` with session restore logic in prompt/stream
  - [ ] Integrate `forkSession` with session fork logic
  - [ ] Integrate `resumeSessionAt` with message history slicing
  - [ ] Integrate `persistSession` with auto-save logic (skip save when false)

- [ ] Task 4: SystemPromptConfig preset (AC: #7)
  - [ ] Create `SystemPromptConfig` enum with `.text(String)` and `.preset(name:String, append:String?)` cases
  - [ ] Add `systemPromptConfig: SystemPromptConfig?` to AgentOptions
  - [ ] Update `buildSystemPrompt()` in Agent.swift to handle SystemPromptConfig
  - [ ] When `systemPromptConfig` is set, it takes priority over `systemPrompt`
  - [ ] Known preset values: `"claude_code"` (standard Code agent prompt)

- [ ] Task 5: Validation and tests (AC: #8)
  - [ ] `swift build` zero errors zero warnings
  - [ ] All 3722+ existing tests pass (zero regression)
  - [ ] Add unit tests for new types (EffortLevel, OutputFormat, ToolConfig, SystemPromptConfig)
  - [ ] Add unit tests for tool filtering logic
  - [ ] Add unit tests for session config field behavior
  - [ ] Update CompatOptions example (Epic 18 scope, not this story)

## Dev Notes

### Position in Epic and Project

- **Epic 17** (TypeScript SDK Feature Alignment), second story
- **Prerequisites:** Story 17-1 (SDKMessage type enhancement) is done
- **This is a production code story** -- modifies AgentOptions, Agent, and adds new types
- **Focus:** Fill the ~14 MISSING/PARTIAL AgentOptions gaps identified by Story 16-8 (CompatOptions)

### Critical Gap Analysis (from Story 16-8 Compat Report)

Story 16-8 verified all TS SDK Options fields against Swift AgentOptions. The detailed findings for fields this story must address:

| # | TS SDK Field | Current Swift Status | Action |
|---|---|---|---|
| 1 | `allowedTools: string[]` | MISSING (ToolNameAllowlistPolicy exists in PermissionTypes but not on AgentOptions) | Add to AgentOptions |
| 2 | `disallowedTools: string[]` | MISSING (ToolNameDenylistPolicy exists but not on AgentOptions) | Add to AgentOptions |
| 3 | `fallbackModel: string` | MISSING | Add to AgentOptions |
| 4 | `env: Record<string, string>` | MISSING | Add to AgentOptions |
| 5 | `effort: 'low' \| 'medium' \| 'high' \| 'max'` | MISSING | Add EffortLevel enum + field |
| 6 | `toolConfig: ToolConfig` | MISSING | Add ToolConfig struct + field |
| 7 | `outputFormat: { type: 'json_schema', schema }` | MISSING | Add OutputFormat struct + field |
| 8 | `includePartialMessages: boolean` | MISSING | Add to AgentOptions |
| 9 | `promptSuggestions: boolean` | MISSING | Add to AgentOptions |
| 10 | `continue: boolean` | MISSING | Add as continueRecentSession |
| 11 | `forkSession: boolean` | PARTIAL (SessionStore has fork, not on AgentOptions) | Add to AgentOptions |
| 12 | `resume: string` | PARTIAL (sessionId exists but no message-level resume) | Add as resumeSessionAt |
| 13 | `persistSession: boolean` | PARTIAL (implicit when sessionStore set) | Add explicit flag |
| 14 | `systemPrompt` preset mode | PARTIAL (String only, no preset) | Add SystemPromptConfig |

### Current AgentOptions Structure

File: `Sources/OpenAgentSDK/Types/AgentTypes.swift` (449 lines)

AgentOptions currently has 38 properties. This story adds ~14 new properties, bringing the total to ~52. All new fields are optional or have default values for backward compatibility.

**Two init methods must be updated:**
1. `public init(...)` -- main init with ~35 parameters, add new parameters with defaults
2. `public init(from config: SDKConfiguration)` -- config-based init, add new fields with nil/false defaults

**Critical init ordering:** New parameters go BEFORE the `sandbox: SandboxSettings? = nil` parameter (currently the last param) to maintain consistency. Actually, since Swift uses labeled arguments, ordering does not matter for callers. Place new parameters at the end of the init signature.

### Key Design Decisions

1. **allowedTools/disallowedTools as direct fields (not policies):** The TS SDK has these as top-level Options fields. While Swift already has `ToolNameAllowlistPolicy`/`ToolNameDenylistPolicy` in PermissionTypes.swift, these are runtime permission policies. The new AgentOptions fields are simpler: they filter the tool pool at query time. Implementation: after `assembleFullToolPool()` in Agent.swift, filter the tool array by name before converting to API tools.

2. **Tool filtering priority:** `disallowedTools` > `allowedTools` > `permissionMode`. If a tool name appears in both allowedTools and disallowedTools, it is blocked. This matches TS SDK behavior.

3. **EffortLevel and ThinkingConfig interaction:** `effort` is an alternative to explicit `ThinkingConfig.enabled(budgetTokens:)`. When `effort` is set, it maps to a budget_tokens value:
   - `.low` -> 1024 tokens
   - `.medium` -> 5120 tokens (default for Sonnet)
   - `.high` -> 10240 tokens
   - `.max` -> 32768 tokens
   When both `effort` and `thinking` are set, `effort` takes priority.

4. **OutputFormat Sendable compliance:** `[String: Any]` is not Sendable. Use the same wrapper pattern as Story 17-1's `SendableStructuredOutput`:
   ```swift
   public struct SendableJSONSchema: Sendable {
       public let schema: [String: Any]
       // Use nonisolated(unsafe) or @unchecked Sendable
   }
   ```

5. **SystemPromptConfig as separate enum, not replacing systemPrompt:** The existing `systemPrompt: String?` property remains unchanged. A new `systemPromptConfig: SystemPromptConfig?` is added alongside it. When both are set, `systemPromptConfig` takes priority. This avoids breaking every existing AgentOptions call site.

6. **Session config fields are declarative options:** `continueRecentSession`, `forkSession`, `resumeSessionAt`, `persistSession` modify the behavior of existing `sessionStore` + `sessionId` logic:
   - `continueRecentSession: true` -> loads most recent session from store (ignores `sessionId`)
   - `forkSession: true` -> creates a new session instead of continuing (with copied history)
   - `resumeSessionAt: "uuid"` -> truncates message history at specified message UUID before continuing
   - `persistSession: false` -> skip auto-save after query (session still loads if sessionId set)

7. **env field for subprocess injection:** The `env` dictionary overrides environment variables for subprocess execution (Bash tool, shell hooks). Implementation: merge into `ProcessInfo.processInfo.environment` when spawning processes in BashTool and ShellHookExecutor.

### Architecture Compliance

- **Types/ is a leaf module:** All new types (EffortLevel, OutputFormat, ToolConfig, SystemPromptConfig) are defined in `Types/` with no outbound dependencies.
- **Sendable conformance:** All new types MUST conform to `Sendable` (NFR1). Use only Sendable-compliant properties.
- **Module boundary:** Agent.swift (Core/) imports from Types/ -- correct direction. No circular dependencies.
- **Backward compatibility:** All new AgentOptions fields are optional or have default values. Existing call sites compile without modification.
- **DocC documentation:** All new public types need Swift-DocC comments (NFR2).
- **No Apple-proprietary frameworks:** Code must work on macOS and Linux.

### File Locations

```
Sources/OpenAgentSDK/Types/AgentTypes.swift         # MODIFY -- add ~14 new fields to AgentOptions
Sources/OpenAgentSDK/Types/EffortLevel.swift        # NEW (or inline in AgentTypes.swift)
Sources/OpenAgentSDK/Core/Agent.swift               # MODIFY -- tool filtering, session config, effort, fallbackModel logic
Sources/OpenAgentSDK/OpenAgentSDK.swift              # MODIFY -- re-export new public types
```

### Source Files to Reference

- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions struct (38 properties), primary file to modify
- `Sources/OpenAgentSDK/Core/Agent.swift` -- Agent class, tool pool assembly (line ~342 `assembleFullToolPool()`), session restore (lines ~345-357, ~835-844), system prompt building
- `Sources/OpenAgentSDK/Types/ThinkingConfig.swift` -- ThinkingConfig enum, effort interaction reference
- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- SendableStructuredOutput pattern for OutputFormat
- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` -- ToolNameAllowlistPolicy, ToolNameDenylistPolicy (related but separate)
- `Sources/OpenAgentSDK/Types/ModelInfo.swift` -- ModelInfo.supportsEffort field
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` -- toApiTools(), tool conversion functions
- `Sources/OpenAgentSDK/Types/SDKConfiguration.swift` -- config-based init reference

### Previous Story Intelligence

**From Story 17-1 (SDKMessage Type Enhancement):**
- Successfully added 12 new SDKMessage cases with associated data structs
- Established `SendableStructuredOutput` wrapper pattern for `[String: Any]` Sendable compliance -- reuse this for OutputFormat
- Updated 11 files that had exhaustive `switch` on SDKMessage
- Full test suite: 3722 tests passing, 14 skipped, 0 failures
- Pattern: all new fields optional with default nil values for backward compatibility
- Pattern: update both `public init(...)` and `init(from config:)` methods

**From Story 16-8 (AgentOptions Compat):**
- Detailed field-by-field compatibility matrix for 37 TS SDK Options fields
- Pre-analysis: ~14 PASS, ~12 PARTIAL, ~14 MISSING, ~2 N/A
- `allowedTools`/`disallowedTools` exist as PermissionPolicies but not as AgentOptions fields
- `systemPrompt` is String only (no preset support)
- `effort`, `toolConfig`, `outputFormat`, `includePartialMessages`, `promptSuggestions` all MISSING
- Session fields `continue`, `forkSession`, `persistSession` all MISSING or PARTIAL

**From Story 16-11 (Thinking Model Compat):**
- `effort` level confirmed MISSING from Swift SDK
- `fallbackModel` confirmed MISSING from AgentOptions
- Agent currently passes `thinking: nil` to API calls even when `options.thinking` is set -- this is a known gap but NOT in scope for this story (runtime wiring is separate from field definition)
- ThinkingConfig has 3 modes (adaptive, enabled, disabled) -- effort maps to budget_tokens

### Testing Requirements

- **Existing tests must pass:** 3722+ tests, zero regression
- **New tests needed:**
  - Unit tests for EffortLevel enum (all 4 cases, CaseIterable, rawValue)
  - Unit tests for OutputFormat struct (init, Sendable conformance)
  - Unit tests for ToolConfig struct (init, defaults)
  - Unit tests for SystemPromptConfig enum (both cases)
  - Unit tests for AgentOptions with all new fields (init with defaults, init with values)
  - Unit tests for tool filtering logic (allowedTools, disallowedTools, priority)
  - Unit tests for session config fields (continueRecentSession, forkSession, persistSession)
- **No E2E tests with mocks:** Per CLAUDE.md, E2E tests use real environment
- After implementation, run full test suite and report total count

### Anti-Patterns to Avoid

- Do NOT make new fields required on AgentOptions -- all must be optional or have default values for backward compatibility
- Do NOT replace `systemPrompt: String?` with `SystemPromptConfig` -- add `systemPromptConfig` alongside it
- Do NOT import Core/ from Types/ -- violates module boundary
- Do NOT use force-unwrap (`!`)
- Do NOT use Apple-proprietary frameworks (UIKit, AppKit, Combine)
- Do NOT use `Task` as a type name (conflicts with Swift Concurrency)
- Do NOT forget to update BOTH init methods (public init and init(from:))
- Do NOT forget to update `validate()` if any new field needs validation (fallbackModel should be non-empty if set, outputFormat schema should be valid JSON)

### Implementation Strategy

1. **Start with types:** Create EffortLevel, OutputFormat (with SendableJSONSchema), ToolConfig, SystemPromptConfig in Types/
2. **Add fields to AgentOptions:** Add all ~14 new properties with defaults to both init methods
3. **Wire tool filtering:** In Agent.swift, after `assembleFullToolPool()`, apply allowedTools/disallowedTools filter
4. **Wire session config:** In Agent.swift session restore blocks, handle continueRecentSession, forkSession, resumeSessionAt, persistSession
5. **Wire effort:** In Agent.swift, map effort level to thinking budget when building API request
6. **Wire systemPromptConfig:** In `buildSystemPrompt()`, handle SystemPromptConfig.preset case
7. **Wire fallbackModel:** In Agent.swift error handling, retry with fallbackModel on model-not-found or overloaded errors
8. **Wire env:** Pass env overrides to ToolContext for BashTool/ShellHookExecutor use
9. **Write tests:** Unit tests for all new types and integration logic
10. **Build and verify:** `swift build` + full test suite

### Project Structure Notes

- New types can go in `Sources/OpenAgentSDK/Types/` as separate files or be added to existing `AgentTypes.swift`
- Prefer separate files for new standalone types (EffortLevel, OutputFormat, ToolConfig, SystemPromptConfig) to keep files focused
- AgentTypes.swift already has AgentOptions, AgentDefinition, QueryResult, SubAgentResult, SubAgentSpawner -- adding 14 more properties is manageable but keep it organized with MARK comments
- Alignment with unified project structure: Types/ is leaf node, no outbound dependencies

### References

- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentOptions struct (38 properties), primary modification target
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:342-357] -- Tool pool assembly and session restore in prompt()
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:835-844] -- Session restore in stream()
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:400-424] -- API call with retry (fallbackModel wiring point)
- [Source: Sources/OpenAgentSDK/Types/ThinkingConfig.swift] -- ThinkingConfig enum for effort interaction
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] -- SendableStructuredOutput pattern
- [Source: _bmad-output/implementation-artifacts/16-8-agent-options-compat.md] -- Detailed gap analysis for all TS Options fields
- [Source: _bmad-output/implementation-artifacts/16-11-thinking-model-compat.md] -- Effort/fallbackModel gap analysis
- [Source: _bmad-output/planning-artifacts/epics.md#Story17.2] -- Story 17.2 definition with acceptance criteria
- [Source: _bmad-output/implementation-artifacts/17-1-sdkmessage-type-enhancement.md] -- Previous story (patterns, SendableStructuredOutput)
- [Source: _bmad-output/project-context.md] -- Project conventions (Sendable, naming, module boundaries)

## Review Findings

### Review [Decision] Session config compat test mismatch -- `continueRecentSession` not checked in `testContinue_missing()`
The compat test `testContinue_missing()` at `Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift:430` still asserts `XCTAssertFalse(fields.contains("continue"))`, checking for the TS field name `continue` (not `continueRecentSession`). Meanwhile, the field-by-field report at line 798 maps `continue` -> `AgentOptions.continueRecentSession` with status `PASS`. The summary at line 482-486 says `missingCount = 1` but the report says `PASS`. This is an internal contradiction: either the test should assert that `continueRecentSession` exists (the field IS there) or the summary counts need updating. Currently the test "passes" because `fields.contains("continue")` is false (the Swift field is named `continueRecentSession`, not `continue`), but this masks the fact that the feature was implemented.

### Review [Patch] No runtime wiring of new fields in Agent.swift [`Sources/OpenAgentSDK/Core/Agent.swift`]
None of the 14 new AgentOptions fields are referenced in Agent.swift. Specifically:
- `buildSystemPrompt()` (line 267) does not handle `systemPromptConfig` -- it only reads `options.systemPrompt`. The story spec (AC7, Dev Note #4) says `systemPromptConfig` should take priority over `systemPrompt`.
- `assembleFullToolPool()` (line 227) does not apply `allowedTools`/`disallowedTools` filtering. The story spec (AC1, Task 1) requires tool whitelist/blacklist filtering after pool assembly.
- The API call at line 413-423 passes `thinking: nil` hardcoded -- it does not read `options.effort` or `options.thinking`. The story spec (AC2, Dev Note #3) says effort maps to budget_tokens.
- No `fallbackModel` retry logic exists. The story spec (Task 4, line 238) requires retry with fallbackModel on model errors.
- No session config wiring (`continueRecentSession`, `forkSession`, `resumeSessionAt`, `persistSession`). The story spec (AC3, Task 3) requires integration with session restore logic.
- No `env` propagation to tool context. The story spec (Dev Note #7) requires env override injection into BashTool/ShellHookExecutor.

This is an incomplete implementation: types and fields are defined but completely disconnected from runtime behavior. The story scope (Tasks 1-4, AC1-AC7) explicitly requires this wiring.

### Review [Patch] Validation not extended for new fields [`Sources/OpenAgentSDK/Types/AgentTypes.swift:571`]
The `validate()` method only checks `baseURL` and `thinking`. The story spec (Anti-Patterns, line 228) states: "Do NOT forget to update `validate()` if any new field needs validation (fallbackModel should be non-empty if set, outputFormat schema should be valid JSON)." Neither `fallbackModel` (should reject empty string) nor `outputFormat` (should validate schema is non-empty dict) are validated.

### Review [Patch] Session config summary counts are internally inconsistent [`Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift:482`]
The comment says "3 PASS + 1 PARTIAL + 1 MISSING" and the code has `missingCount = 1`. But the field-by-field report at line 798 maps `continue` as `PASS` (via `AgentOptions.continueRecentSession`). The summary should be "4 PASS + 1 PARTIAL + 0 MISSING" to be consistent with the report, or the report mapping needs correction.

### Review [Patch] Compat category breakdown comment contradicts summary [`Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift:833`]
Comment at line 833 says "Session: 4 PASS + 1 PARTIAL + 0 MISSING = 5" but the test code at line 482-490 says "3 PASS + 1 PARTIAL + 1 MISSING". These two tests in the same file assert contradictory numbers about the same data.

### Review [Defer] Compat test `testContinue_missing` uses wrong field name [`Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift:430`] -- deferred, pre-existing test design issue
The compat test checks for the exact TS field name `continue` (not `continueRecentSession`). This is a pre-existing design pattern in the compat test suite (checking field-by-field names), but the test asserts "no continue field" when the actual field exists as `continueRecentSession`. Not introduced by this change, but the summary counts should have been updated.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
