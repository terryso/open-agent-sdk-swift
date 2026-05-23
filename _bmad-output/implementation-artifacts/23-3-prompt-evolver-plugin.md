# Story 23.3: PromptEvolverPlugin — 进化式 Prompt 优化

Status: done

## Story

As an SDK developer,
I want a prompt evolution plugin that uses LLM-driven analysis to optimize the agent's system prompt across sessions,
so that agents can iteratively improve their instructions based on real-world usage patterns without manual tuning.

## Acceptance Criteria

1. **AC1: `PromptEvolutionStrategy` enum** — Defined in `Types/PromptEvolutionTypes.swift`. `public enum`, `String`, `Codable`, `Sendable`, `Equatable`, `CaseIterable`. Cases: `refine` (improve clarity and effectiveness of existing prompt instructions), `expand` (add new instructions based on observed gaps), `compress` (reduce verbosity while preserving intent), `safety` (add or strengthen safety guardrails).

2. **AC2: `PromptEvolutionConfig` struct** — Defined in `Types/PromptEvolutionTypes.swift`. `public struct`, `Sendable`, `Codable`, `Equatable`. Fields: `strategies` (`[PromptEvolutionStrategy]`, default all cases), `evolutionModel` (String, default `"claude-haiku-4-5-20251001"`), `maxTokens` (Int, default 2048), `temperature` (Double, default 0.3), `minConversationLength` (Int, default 6 — minimum messages before evolution triggers), `maxChangesPerEvolution` (Int, default 5). Validation: `evolutionModel` must be non-empty, `maxTokens` > 0, `temperature` in 0...1, `minConversationLength` >= 2. Invalid values throw via `preconditionFailure`.

3. **AC3: `PromptChange` struct** — Defined in `Types/PromptEvolutionTypes.swift`. `public struct`, `Sendable`, `Codable`, `Equatable`. Fields: `strategy` (PromptEvolutionStrategy), `section` (String — which part of the prompt changed, e.g. "instructions", "guidelines", "safety"), `original` (String — the original text), `modified` (String — the evolved text), `rationale` (String — why this change was made). Represents a single atomic change to the system prompt.

4. **AC4: `PromptEvolutionResult` struct** — Defined in `Types/PromptEvolutionTypes.swift`. `public struct`, `Sendable`, `Equatable`. Fields: `shouldEvolve` (Bool — whether the LLM recommends changes), `evolvedPrompt` (String? — the full evolved system prompt, nil if shouldEvolve is false), `changes` ([PromptChange]), `confidence` (Double, 0...1 — LLM's confidence in the evolution), `evolvedAt` (Date). Factory method: `PromptEvolutionResult.noEvolution()` returns a result with `shouldEvolve=false`, empty changes, and `confidence=0`.

5. **AC5: `PromptEvolverEngine` struct** — Defined in `Utils/PromptEvolverEngine.swift`. `public struct`, `Sendable`. Pure computation engine (no mutable state). Takes an `LLMClient` reference and performs prompt evolution:
   - `func evolve(currentPrompt: String, messages: [SDKMessage], config: PromptEvolutionConfig, client: LLMClient) async throws -> PromptEvolutionResult` — main entry point.
   - Step 1: Check minimum conversation length. If `messages.count < config.minConversationLength`, return `PromptEvolutionResult.noEvolution()`.
   - Step 2: Serialize conversation and build system prompt for the evolution LLM call.
   - Step 3: Call `client.sendMessage()` with the evolution model, requesting structured JSON output.
   - Step 4: Parse the LLM JSON response into a `PromptEvolutionResult`. Handle malformed responses gracefully (return `.noEvolution()`).
   - Step 5: Clamp confidence to 0...1 range. Cap changes to `maxChangesPerEvolution`.
   - Uses `stripCodeFences()` helper (same pattern as `LLMExperienceExtractor` and `LLMSkillEvolver`).

6. **AC6: `PromptEvolverPlugin` actor** — Defined in `Utils/PromptEvolverPlugin.swift`. `public actor`, conforms to `SelfEvolutionPlugin`. Properties:
   - `name`: `"prompt-evolver"` (constant)
   - `supportedPhases`: `{.initialize, .syncTurn, .sessionEnd}`
   - Private `engine: PromptEvolverEngine?` (created during initialize when LLMClient is available)
   - Private `pluginConfig: EvolutionPluginConfig?`
   - Private `currentPrompt: String?` (tracked across turns)
   - Private `accumulatedMessages: [SDKMessage]` (buffered between syncTurn calls)
   - `func initialize(sessionId:)`: parse config, create `PromptEvolverEngine` with `LLMClient` from context (if available via config), reset buffers.
   - `func onPhase(_:context:)`:
     - On `.syncTurn`: buffer messages, track current prompt from context, return `.none`.
     - On `.sessionEnd`: if enough accumulated messages, run evolution via `PromptEvolverEngine`. Return `.systemPromptBlock` with the evolved prompt suggestion formatted for developer review (not auto-applied). If evolution not warranted, return `.none`.
     - On `.initialize`: no-op.
     - All other phases: return `.none`.
   - `func shutdown()`: clear buffers, release engine.

7. **AC7: Plugin config via `EvolutionPluginConfig`** — `PromptEvolverPlugin` reads its config from `EvolutionPluginConfig.config` dictionary. Supported keys: `"evolutionModel"` (string, overrides default model), `"minConversationLength"` (int string, overrides default 6), `"strategies"` (comma-separated strategy names, e.g. "refine,compress"), `"maxChangesPerEvolution"` (int string), `"autoApply"` ("true"/"false", default "false" — if true, evolved prompt is auto-injected; if false, returned as suggestion for developer review). The plugin is instantiated by the host application and registered with `PluginRegistry`.

8. **AC8: Module boundary compliance** — `Types/PromptEvolutionTypes.swift` lives in `Types/` and depends only on other Types. `PromptEvolverEngine` lives in `Utils/` and depends on `Types/` (evolution types, SDKMessage) + `API/LLMClient` (for LLM calls — same pattern as `LLMExperienceExtractor` which is in Utils/ and uses LLMClient). `PromptEvolverPlugin` lives in `Utils/` and depends on `Types/` (plugin types, evolution types) + `API/` (LLMClient). No imports of `Core/` or `Tools/` from any new file.

9. **AC9: Unit tests** — All new code tested:
   - `PromptEvolutionStrategy`: CaseIterable, rawValue round-trip
   - `PromptEvolutionConfig`: valid construction, defaults, Codable round-trip, precondition failure for invalid values
   - `PromptChange`: construction, equality, Codable round-trip
   - `PromptEvolutionResult`: construction, equality, `noEvolution()` factory
   - `PromptEvolverEngine`: evolution with valid LLM response (mock LLMClient), no evolution below min conversation length, malformed JSON handling, confidence clamping, maxChanges cap, empty prompt handling
   - `PromptEvolverPlugin`: name is "prompt-evolver", supportedPhases correct, initialize sets up engine, onPhase(.syncTurn) buffers messages, onPhase(.sessionEnd) triggers evolution, shutdown clears state, config parsing
   - All store/engine tests use mock LLMClient (no real API calls per project convention)

10. **AC10: Build and test pass** — `swift build` with zero errors. Full test suite passes with zero regression.

## Tasks / Subtasks

- [ ] Task 1: Define evolution type models (AC: #1, #2, #3, #4)
  - [ ] Create `Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift`
  - [ ] Add `PromptEvolutionStrategy` enum with four cases
  - [ ] Add `PromptEvolutionConfig` struct with validation
  - [ ] Add `PromptChange` struct
  - [ ] Add `PromptEvolutionResult` struct with `noEvolution()` factory

- [ ] Task 2: Create `PromptEvolverEngine` (AC: #5)
  - [ ] Create `Sources/OpenAgentSDK/Utils/PromptEvolverEngine.swift`
  - [ ] Implement conversation serialization and system prompt builder
  - [ ] Implement LLM call with structured JSON response parsing
  - [ ] Implement confidence clamping and max changes cap
  - [ ] Handle edge cases: short conversations, malformed responses, empty prompt

- [ ] Task 3: Create `PromptEvolverPlugin` (AC: #6, #7)
  - [ ] Create `Sources/OpenAgentSDK/Utils/PromptEvolverPlugin.swift`
  - [ ] Implement `SelfEvolutionPlugin` conformance
  - [ ] Implement `initialize` to set up engine from config
  - [ ] Implement `onPhase(.syncTurn)` for message buffering
  - [ ] Implement `onPhase(.sessionEnd)` for evolution trigger
  - [ ] Implement config parsing from `EvolutionPluginConfig.config`

- [ ] Task 4: Unit tests for evolution types (AC: #9)
  - [ ] Create `Tests/OpenAgentSDKTests/Utils/PromptEvolutionTypesTests.swift`
  - [ ] Test strategy cases and rawValues
  - [ ] Test config valid/invalid construction
  - [ ] Test PromptChange construction/equality/Codable
  - [ ] Test PromptEvolutionResult construction and `noEvolution()` factory

- [ ] Task 5: Unit tests for PromptEvolverEngine (AC: #9)
  - [ ] Create `Tests/OpenAgentSDKTests/Utils/PromptEvolverEngineTests.swift`
  - [ ] Test evolution with valid LLM response (mock LLMClient)
  - [ ] Test no evolution below min conversation length
  - [ ] Test malformed JSON handling
  - [ ] Test confidence clamping, maxChanges cap
  - [ ] Test empty prompt handling

- [ ] Task 6: Unit tests for PromptEvolverPlugin (AC: #9)
  - [ ] Create `Tests/OpenAgentSDKTests/Utils/PromptEvolverPluginTests.swift`
  - [ ] Test plugin name, supportedPhases
  - [ ] Test initialize/shutdown lifecycle
  - [ ] Test onPhase(.syncTurn) buffers messages
  - [ ] Test onPhase(.sessionEnd) triggers evolution
  - [ ] Test config parsing

- [ ] Task 7: Verify build and tests (AC: #10)
  - [ ] `swift build` — 0 errors
  - [ ] Full test suite — 0 failures

## Dev Notes

### Architecture Compliance

- **`Types/PromptEvolutionTypes.swift`**: Evolution data models. Types/ is the leaf dependency — no outbound imports beyond other Types. References `Foundation` only.
- **`Utils/PromptEvolverEngine.swift`**: Pure computation struct in Utils/. Depends on `Types/` (evolution types, SDKMessage) and `API/LLMClient` (for LLM calls). Same pattern as `LLMExperienceExtractor` — a Sendable struct in Utils/ that takes an LLMClient reference.
- **`Utils/PromptEvolverPlugin.swift`**: Plugin implementation in Utils/. Depends on `Types/` (plugin types, evolution types) and `API/` (LLMClient). Conforms to `SelfEvolutionPlugin` protocol from `PluginEvolutionTypes.swift`.
- **No new external dependencies**: Uses existing LLMClient infrastructure. No SQLite or other new packages.
- **No Apple-proprietary frameworks**: Foundation only.

### Key Design Decisions

1. **Evolution happens at `.sessionEnd`, not `.syncTurn`**: Prompt evolution requires a full conversation to analyze patterns. Running it on every syncTurn would be wasteful and produce low-quality suggestions. The syncTurn phase is used only for message buffering. The sessionEnd phase triggers the actual evolution.

2. **`PromptEvolverEngine` is a pure struct (not actor)**: No mutable state — the engine takes an LLMClient and produces a result. Same pattern as `LLMExperienceExtractor` and `LLMSkillEvolver`. Thread safety is handled by the caller (`PromptEvolverPlugin` is an actor).

3. **Evolved prompt is a suggestion, not auto-applied**: By default (`autoApply: false`), the plugin returns the evolved prompt as a `.systemPromptBlock` for developer review. The suggestion is formatted as a diff-like comparison showing original vs. evolved sections. Auto-apply mode (`autoApply: true`) is opt-in and injects the evolved prompt directly.

4. **Four evolution strategies cover distinct optimization goals**:
   - `refine`: Improve clarity and effectiveness of existing instructions (most common)
   - `expand`: Add new instructions based on observed gaps in agent behavior
   - `compress`: Reduce verbosity while preserving intent (for long prompts)
   - `safety`: Add or strengthen safety guardrails based on observed risky patterns

5. **LLMClient injection, not creation**: The plugin receives the LLMClient from the host application (via config or context). It does not create its own API client. This matches the `LLMExperienceExtractor` and `LLMSkillEvolver` patterns where the client is injected.

6. **`PromptChange` tracks atomic modifications**: Each change records the strategy used, the affected section, original text, modified text, and rationale. This provides an audit trail for prompt evolution decisions.

7. **`PromptEvolverPlugin` is an actor**: Conforms to `SelfEvolutionPlugin` which requires `Sendable`. Using `actor` provides natural isolation for the mutable `accumulatedMessages` and `currentPrompt` state. Same pattern as `SessionSearchPlugin`.

### Integration Points with Existing SDK

- **`Types/PluginEvolutionTypes.swift`** (Story 23.1): `SelfEvolutionPlugin` protocol, `PluginResult`, `PluginContext`, `PluginLifecyclePhase`, `EvolutionPluginConfig`. The prompt evolver implements this protocol.
- **`Hooks/PluginRegistry.swift`** (Story 23.1): `PluginRegistry` actor where the prompt evolver will be registered.
- **`API/LLMClient.swift`**: `LLMClient` protocol used for evolution LLM calls. Same pattern as `LLMExperienceExtractor` and `LLMSkillEvolver`.
- **`Utils/LLMExperienceExtractor.swift`**: Pattern reference for LLM call structure, response parsing, `stripCodeFences()`, `extractTextFromResponse()`.
- **`Utils/LLMSkillEvolver.swift`**: Pattern reference for evolution system (signal analysis, JSON response parsing, evolved output construction).
- **`Utils/SessionSearchPlugin.swift`**: Pattern reference for SelfEvolutionPlugin actor implementation with config parsing.

### System Prompt for Evolution LLM Call

The evolution system prompt should instruct the LLM to:
1. Analyze the current system prompt for effectiveness
2. Review the conversation to identify areas where the prompt could be improved
3. Focus on the configured strategies (refine, expand, compress, safety)
4. Return structured JSON with specific changes

Expected LLM response format:
```json
{
  "shouldEvolve": true,
  "evolvedPrompt": "The complete evolved system prompt text",
  "changes": [
    {
      "strategy": "refine",
      "section": "guidelines",
      "original": "original text",
      "modified": "modified text",
      "rationale": "why this change improves the prompt"
    }
  ],
  "confidence": 0.85
}
```

### Hermes Reference Mapping

```
Hermes trajectory.py                 →  SDK Component
──────────────────────────────────────────────────────
prompt_optimizer.optimize()          →  PromptEvolverEngine.evolve()
evolution_strategies (refine,        →  PromptEvolutionStrategy enum
  expand, compress, safety)
evolution_result (prompt, changes,   →  PromptEvolutionResult struct
  confidence)
system_prompt evolution              →  PromptEvolverPlugin.onPhase(.sessionEnd)
prompt_history tracking              →  Future story (not in scope)
```

### Previous Story Learnings (Stories 23.1–23.2)

- **Build baseline**: 5,361 tests passing. Any regression check must match this baseline.
- **`nonisolated(unsafe)`** for simple flags when actor isolation isn't needed.
- **Swift 6.1 strict concurrency**: closures need explicit capture lists. `[String: Any]` dicts need `@unchecked Sendable` wrappers.
- **`Codable` for SDK-internal structured data**, raw `[String: Any]` only for LLM API communication boundary.
- **Pure computation structs preferred** when no mutable state is needed.
- **`precondition()` for config validation** — not `assert()` — catches issues in release builds too.
- **SendableJSONSchema/SendableToolSchemaList pattern**: Wrap `[String: Any]` in `@unchecked Sendable` struct for use in Equatable/Sendable contexts.
- **Actor tests use `await`** for all actor-isolated methods.
- **JSON encoder pattern**: `.iso8601` date strategy, `.prettyPrinted` + `.sortedKeys` output formatting.
- **`SharedMockState` pattern**: `final class SharedMockState: @unchecked Sendable` with `NSLock` for test state capture.
- **Logger dependency**: Use `Logger.shared` for structured logging.
- **Module boundary**: Utils/ can depend on Types/, Stores/, and API/ (for LLMClient). Hooks/ depends on Types/ only.
- **`stripCodeFences()` duplicated**: Still duplicated across `LLMExperienceExtractor` and `LLMSkillEvolver`. This story will add a third copy. Consider extracting to `Utils/StringHelpers.swift` (noted as technical debt TD2 in Epic 22 retrospective).
- **SessionSearchPlugin pattern**: Use `nonisolated let` for constant properties (`name`, `supportedPhases`), parse config in `init`, store optional references as private vars.
- **Config parsing**: Use `config?.config?["keyName"]` pattern for dictionary access from `EvolutionPluginConfig`.

### File Structure

```
Sources/OpenAgentSDK/Types/
  PromptEvolutionTypes.swift          # NEW: PromptEvolutionStrategy, PromptEvolutionConfig,
                                      #       PromptChange, PromptEvolutionResult

Sources/OpenAgentSDK/Utils/
  PromptEvolverEngine.swift           # NEW: Pure computation evolution engine
  PromptEvolverPlugin.swift           # NEW: SelfEvolutionPlugin implementation

Tests/OpenAgentSDKTests/Utils/
  PromptEvolutionTypesTests.swift     # NEW: Type model tests
  PromptEvolverEngineTests.swift      # NEW: Engine tests with mock LLMClient
  PromptEvolverPluginTests.swift      # NEW: Plugin lifecycle tests
```

### References

- [Source: _bmad-output/story-automator/orchestration-22-23-20260522-160622.md — Story 23.3 definition: PromptEvolverPlugin]
- [Source: _bmad-output/implementation-artifacts/epic-22-retro-2026-05-23.md — Epic 23 preview, TD2/TD3/TD4 action items]
- [Source: Sources/OpenAgentSDK/Types/PluginEvolutionTypes.swift — SelfEvolutionPlugin protocol, PluginResult, PluginContext]
- [Source: Sources/OpenAgentSDK/Hooks/PluginRegistry.swift — Plugin registration pattern]
- [Source: Sources/OpenAgentSDK/Utils/LLMExperienceExtractor.swift — LLM call pattern, stripCodeFences, response parsing]
- [Source: Sources/OpenAgentSDK/Utils/LLMSkillEvolver.swift — Evolution system pattern, JSON response parsing]
- [Source: Sources/OpenAgentSDK/Utils/SessionSearchPlugin.swift — Plugin actor pattern, config parsing]
- [Source: Sources/OpenAgentSDK/API/LLMClient.swift — LLMClient protocol for LLM calls]
- [Source: _bmad-output/implementation-artifacts/23-2-session-search-plugin.md — Previous story, plugin patterns]
- [Source: _bmad-output/project-context.md — Architecture rules, module boundaries, actor conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### Review Findings

- [x] [Review][Patch] PromptEvolutionResult.confidence not clamped despite doc comment [Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift:115] — FIXED: Clamped via `min(max(confidence, 0), 1)` in init.
- [x] [Review][Patch] PromptEvolutionConfig.strategies accepts empty array [Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift:39] — FIXED: Added `precondition(!strategies.isEmpty, ...)`.
- [x] [Review][Patch] PromptEvolutionConfig.maxChangesPerEvolution accepts zero/negative [Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift:34] — FIXED: Added `precondition(maxChangesPerEvolution > 0, ...)`.
- [x] [Review][Defer] PromptEvolutionResult lacks Codable conformance [Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift:105] — Not mandated by AC4 (spec only requires Sendable, Equatable). Consistency concern with sibling Result types. Deferred: engine/consumer can handle serialization if needed.
- [x] [Review][Defer] shouldEvolve/evolvedPrompt inconsistent state not prevented [Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift:107-109] — shouldEvolve: false with non-nil evolvedPrompt is contradictory. PromptEvolverEngine (AC5) will be the sole producer and enforce the invariant. Over-validating the struct constrains legitimate use cases.
- [x] [Review][Defer] Date() makes Equatable non-deterministic [Sources/OpenAgentSDK/Types/PromptEvolutionTypes.swift:119,126] — Two structurally identical results created at different times compare as not-equal. Pre-existing SDK pattern (SkillEvolutionResult same issue). Tests handle via field-level comparison.

### File List
