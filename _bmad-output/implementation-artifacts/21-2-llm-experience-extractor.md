# Story 21.2: LLMExperienceExtractor — LLM 驱动的经验提取器

Status: done

## Story

As an SDK developer,
I want an LLM-based implementation of the ExperienceExtractor protocol that extracts experience signals from agent conversations,
so that the SDK can automatically learn from conversations without requiring developers to write custom extraction logic.

## Acceptance Criteria

1. **AC1: `LLMExperienceExtractor` struct** — Given `LLMExperienceExtractor`, when defined in `Utils/`, it is a `public struct` that is `Sendable` and conforms to `ExperienceExtractor`. It holds a `LLMClient` and an `extractionModel` string (default `"claude-haiku-4-5-20251001"`). It does NOT use actor isolation — it delegates to the injected `LLMClient` which handles its own concurrency.

2. **AC2: `extract(from:config:)` implementation** — Given a non-empty array of `[SDKMessage]`, when `extract()` is called, it: (a) serializes messages to a prompt-friendly text representation, (b) calls `LLMClient.sendMessage()` with the extraction system prompt, (c) parses the LLM response JSON into `[ExperienceSignal]`, (d) filters signals below `config.minSignalConfidence` and those matching `config.antiPatternKeywords`, (e) returns an `ExtractionResult` with `skippedCount` reflecting filtered-out candidates.

3. **AC3: Extraction system prompt** — Given the extraction system prompt, when built, it instructs the LLM to return a JSON array of experience objects. Each object has fields: `domain` (string), `content` (string), `kind` (one of: "affordance", "avoid", "observation"), `confidence` (0-1). The prompt includes the anti-pattern guidance from Hermes: "If a tool failed because of setup state, capture the FIX — never 'this tool does not work' as a standalone constraint." The prompt uses `maxTokens: 2048` and `temperature: 0.3`.

4. **AC4: Message serialization** — Given `[SDKMessage]`, when serialized for the extraction prompt, the implementation extracts text content from `.assistant`, `.userMessage`, and `.toolResult` cases only. System messages, tool use requests, progress events, and hook events are excluded. The serialization produces a compact text format: `[assistant] text`, `[user] text`, `[tool_result] content`. Messages exceeding 2000 characters are truncated with a "... [truncated]" suffix.

5. **AC5: JSON parsing resilience** — Given the LLM response, when parsed, the implementation handles: (a) response wrapped in markdown code fences (```json ... ```), (b) empty response body (returns empty result with 0 signals), (c) malformed JSON (logs warning and returns empty result), (d) individual signal parse failures (skips invalid signals, increments skipped count). Uses `JSONSerialization` for raw parsing, NOT Codable (LLM boundary rule).

6. **AC6: Error handling** — Given an LLM call failure, when `sendMessage()` throws, the `extract()` method throws `SDKError.apiError` with the underlying error details. The extractor does NOT silently swallow errors — callers (like the ReviewHook in 21.3) need to know when extraction fails.

7. **AC7: Unit tests** — All new code tested: `LLMExperienceExtractor` initialization, message serialization logic, JSON parsing (valid, wrapped in fences, empty, malformed), anti-pattern filtering, confidence threshold filtering, ExtractionResult construction. A mock `LLMClient` returns fixed responses for deterministic testing. The mock does NOT make real network calls.

8. **AC8: Build and test pass** — `swift build` with zero errors and zero warnings. All existing tests pass with zero regression.

## Tasks / Subtasks

- [x] Task 1: Define `LLMExperienceExtractor` struct (AC: #1)
  - [x] Create `Sources/OpenAgentSDK/Utils/LLMExperienceExtractor.swift`
  - [x] `public struct LLMExperienceExtractor: ExperienceExtractor, Sendable`
  - [x] Stored properties: `client: LLMClient`, `extractionModel: String` (default `"claude-haiku-4-5-20251001"`)
  - [x] Public init with default model

- [x] Task 2: Implement message serialization (AC: #4)
  - [x] Private method `serializeMessages(_:) -> String`
  - [x] Extract text from `.assistant(AssistantData)`, `.userMessage(UserMessageData)`, `.toolResult(ToolResultData)`
  - [x] Format: `[assistant] text`, `[user] text`, `[tool_result] content`
  - [x] Truncate at 2000 chars with "... [truncated]" suffix

- [x] Task 3: Build extraction system prompt (AC: #3)
  - [x] Private method `buildSystemPrompt(config:) -> String`
  - [x] Instruct LLM to return JSON array with domain/content/kind/confidence fields
  - [x] Include anti-pattern guidance from Hermes
  - [x] Include domain filter when `config.domain` is non-nil

- [x] Task 4: Implement JSON response parsing (AC: #5)
  - [x] Private method `parseExtractionResponse(_:) -> [RawSignal]`
  - [x] Strip markdown code fences if present
  - [x] Use `JSONSerialization` (NOT Codable — LLM boundary)
  - [x] Handle empty/malformed responses gracefully

- [x] Task 5: Implement `extract(from:config:)` (AC: #2, #6)
  - [x] Serialize messages to text
  - [x] Call `client.sendMessage()` with extraction prompt
  - [x] Parse response into raw signals
  - [x] Filter by confidence threshold and anti-pattern keywords
  - [x] Build and return `ExtractionResult`

- [x] Task 6: Unit tests (AC: #7)
  - [x] Create `Tests/OpenAgentSDKTests/Utils/LLMExperienceExtractorTests.swift`
  - [x] Create mock `MockLLMClient: LLMClient` that returns canned responses
  - [x] Test message serialization (excludes system/toolUse/progress messages, truncates long content)
  - [x] Test JSON parsing (valid response, code-fenced response, empty response, malformed JSON)
  - [x] Test anti-pattern filtering (signals with anti-pattern keywords are skipped)
  - [x] Test confidence threshold filtering
  - [x] Test full extraction pipeline with mock client
  - [x] Test error propagation (mock client throws, extractor re-throws)

- [x] Task 7: Verify build and tests (AC: #8)
  - [x] `swift build` — 0 errors, 0 warnings
  - [x] Run full test suite — 0 failures

## Dev Notes

### Architecture Compliance

- **`LLMExperienceExtractor` goes in `Utils/`**: This follows the pattern of `MemoryContextProvider` and `MemoryLifecycleService` — stateless computation services that depend on `Types/` abstractions. The extractor depends on `LLMClient` (protocol from `API/`) which is valid per the `Utils/` dependency rule: "Utils/ → no outbound dependency (leaf-node, Compact exception can temporarily call API/AnthropicClient)".
- **No actor needed**: `LLMExperienceExtractor` is a `struct`. The `LLMClient` protocol's `sendMessage()` is `nonisolated async throws`, so the extractor doesn't need actor isolation. The client (e.g., `AnthropicClient`) manages its own concurrency as an actor.
- **No Apple-proprietary frameworks**: Foundation only (`JSONSerialization`, `String` operations).
- **LLM boundary uses `[String: Any]`**: The extraction request and response parsing use raw JSON dictionaries, NOT Codable. This follows the project convention: "LLM 端：`[String: Any]` 原始 JSON 字典（API 请求/响应、工具 inputSchema）".
- **Module boundary**: `Utils/` may import `API/` (LLMClient protocol). `Utils/` may NOT import `Core/` or `Tools/`.

### Key Design Decisions

1. **Use Haiku as default extraction model**: The `extractionModel` defaults to `"claude-haiku-4-5-20251001"` following the Hermes pattern of using a cheaper auxiliary model for background review. This keeps extraction costs low (~$0.001 per session). Developers can override via init.

2. **Non-streaming API call only**: Extraction uses `sendMessage()` (non-streaming), NOT `streamMessage()`. The result is a single JSON response. Streaming adds complexity without benefit here.

3. **Message serialization excludes non-essential cases**: Only `.assistant`, `.userMessage`, and `.toolResult` carry conversation content worth analyzing. `.system`, `.toolUse` (tool invocation request), `.hookStarted`, `.hookProgress`, `.hookResponse`, `.taskStarted`, `.taskProgress`, `.authStatus`, `.filesPersisted`, `.localCommandOutput`, `.promptSuggestion`, `.toolUseSummary` are metadata events that don't contain extractable experience.

4. **Anti-pattern filtering is post-extraction**: The LLM may still produce signals that match anti-patterns. We filter AFTER parsing, not before sending to the LLM. This is simpler and more robust — the prompt tells the LLM what to avoid, but we enforce it programmatically too.

5. **Error propagation, not swallowing**: If the LLM call fails, the extractor throws. The caller (ReviewHook in 21.3) decides whether to retry, log, or ignore. This keeps the extractor as a pure function of messages → signals.

6. **2000 char truncation per message**: Long tool outputs (e.g., file contents) can blow up the extraction prompt. Truncating individual messages keeps the total prompt size manageable while preserving the conversation structure.

### Integration Points

- **`ExperienceExtractor` protocol** (`Types/ExperienceTypes.swift`): `LLMExperienceExtractor` conforms to this protocol. The `extract(from:config:)` signature is fixed — no new parameters.
- **`LLMClient` protocol** (`API/LLMClient.swift`): The extractor takes a `LLMClient` (protocol, not concrete type). This means it works with `AnthropicClient`, `OpenAIClient`, or any custom implementation. It also makes testing trivial — inject a mock.
- **`ExtractionConfig`** (`Types/ExperienceTypes.swift`): The `antiPatternKeywords`, `minSignalConfidence`, `maxSignalsPerExtraction`, and `domain` fields are all used during extraction and filtering.
- **`ExperienceSignal.create()`** (`Types/ExperienceTypes.swift`): Used to construct signals from parsed LLM output. The `source` is always `.conversation`.
- **`ExtractionResult`** (`Types/ExperienceTypes.swift`): The return type wrapping signals with metadata.
- **`SDKMessage`** (`Types/SDKMessage.swift`): Input type. The extractor reads `.assistant`, `.userMessage`, `.toolResult` subtypes.

### File Structure

```
Sources/OpenAgentSDK/Utils/
  LLMExperienceExtractor.swift     # LLMExperienceExtractor struct (NEW)

Tests/OpenAgentSDKTests/Utils/
  LLMExperienceExtractorTests.swift  # Unit tests (NEW)
```

### Modified Files

None — this story is purely additive.

### Previous Story Learnings (Story 21.1)

- Story 21.1 defined the types but did NOT re-export them from `OpenAgentSDK.swift`. This story should also NOT modify `OpenAgentSDK.swift` — re-exports can be handled in a separate alignment story.
- Build baseline: verify current test count matches `swift test` output before and after.
- `nonisolated(unsafe)` for simple flags when actor isolation isn't needed.
- Swift 6.1 strict concurrency: closures need explicit capture lists.
- Pure computation structs are preferred when no mutable state is needed.
- Test counts in completion notes must match actual test count.
- `Codable` for SDK-internal structured data, raw `[String: Any]` only for LLM API communication boundary.

### Testing Strategy

- **Mock `LLMClient`**: Create a `MockLLMClient` struct conforming to `LLMClient`. Its `sendMessage()` returns a canned `[String: Any]` dictionary mimicking the Anthropic API response format (`content: [{type: "text", text: "..."}]`). Its `streamMessage()` can throw — not needed for extraction tests.
- **No real network calls**: All tests use `MockLLMClient`. Zero I/O.
- **JSON parsing edge cases**: Test with valid JSON, JSON wrapped in markdown fences, empty string, malformed JSON, JSON with extra fields (should be ignored), JSON with missing fields (should skip that signal).
- **Serialization tests**: Verify that system messages, tool use requests, and other metadata events are excluded. Verify truncation at 2000 chars.
- **Filtering tests**: Verify that signals with `confidence < 0.4` are skipped, signals matching anti-pattern keywords are skipped, and `skippedCount` reflects all filtered signals.

### Hermes Reference Implementation Notes

The Hermes `background_review.py` implementation:
- Lines 1-40: Trigger conditions and interval control
- Lines 34-37: `_MEMORY_THREAT_PATTERNS` — prompt injection detection (handled in Story 21.4, not this story)
- Lines 45-145: `_COMBINED_REVIEW_PROMPT` — the combined review prompt for memory and skill extraction
- Lines 121-144: Anti-pattern list (already captured in `ExtractionConfig.defaultAntiPatternKeywords`)

Key Hermes patterns to replicate:
- **"Be ACTIVE"**: The prompt should encourage capturing genuine learnings, not just summarizing what happened
- **"Nothing to save"**: If the conversation contains no extractable experience, return empty — don't force signals
- **Two-signal focus**: Hermes focuses on user identity signals (persona, preferences) and user expectation signals (work style, behavior)
- **Anti-pattern guidance**: "If a tool failed because of setup state, capture the FIX — never 'this tool does not work' as a standalone constraint"

### References

- [Source: docs/epics.md#Epic 21 Story 21.2 — LLMExperienceExtractor]
- [Source: _bmad-output/project-context.md — Architecture rules, LLM boundary convention, module boundaries]
- [Source: _bmad-output/implementation-artifacts/21-1-experience-extractor-protocol-signal-model.md — Protocol and types defined]
- [Source: Sources/OpenAgentSDK/Types/ExperienceTypes.swift — ExperienceExtractor protocol, ExtractionConfig, ExtractionResult, ExperienceSignal]
- [Source: Sources/OpenAgentSDK/API/LLMClient.swift — LLMClient protocol with sendMessage()]
- [Source: Sources/OpenAgentSDK/API/AnthropicClient.swift — Concrete LLMClient implementation (reference for response format)]
- [Source: Sources/OpenAgentSDK/Utils/MemoryContextProvider.swift — Pattern for Utils/ struct depending on Types/]
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift — SDKMessage enum with all 18 cases and associated data]
- [Reference: Hermes agent/background_review.py — Combined review prompt, anti-pattern guidance, extraction logic]

## Dev Agent Record

### Agent Model Used
Claude (GLM-5.1)

### Debug Log References
- MockLLMClient required `@unchecked Sendable` shared state via `SharedMockState` class to work around Swift 6 strict concurrency in test parameter capture
- `SystemData.Subtype.init` case conflicts with Swift metatype `.init` — used `.status` instead in tests

### Completion Notes List
- Implemented LLMExperienceExtractor as a Sendable struct conforming to ExperienceExtractor protocol
- Message serialization extracts only .assistant, .userMessage, .toolResult cases, formatted as [role] text
- Truncation at 2000 chars with "... [truncated]" suffix per message
- System prompt includes anti-pattern guidance from Hermes, domain filtering support
- JSON parsing uses JSONSerialization (not Codable), strips markdown code fences, handles empty/malformed responses
- Post-extraction filtering: confidence threshold, anti-pattern keywords, max signals limit
- Error propagation: LLM failures throw SDKError.apiError (not swallowed)
- 20 unit tests covering all acceptance criteria
- 12 E2E tests with real LLM API calls (skipped when no API key)
- Full test suite: 5035 tests passing, 0 failures, 26 skipped

### File List
- Sources/OpenAgentSDK/Utils/LLMExperienceExtractor.swift (NEW)
- Tests/OpenAgentSDKTests/Utils/LLMExperienceExtractorTests.swift (NEW)
- Tests/OpenAgentSDKTests/Utils/LLMExperienceExtractorE2ETests.swift (NEW)

## Change Log

- 2026-05-22: Story 21.2 created — LLMExperienceExtractor implementation with LLM-driven signal extraction from conversations.
- 2026-05-22: Story 21.2 implementation complete — all 7 tasks done, 20 tests added, 5023 total tests passing.
- 2026-05-22: Senior Developer Review (AI) — 5 issues found (2 HIGH, 3 MEDIUM), all auto-fixed. Fixes: (1) added malformed JSON warning logging via Logger.shared.warn, (2) parse failure count now included in skippedCount (AC5d compliance), (3) added .taskProgress/.toolProgress to exclusion test, (4) updated File List with E2E test file, (5) corrected test count to 5035. 5035 tests passing, 0 failures.

## Senior Developer Review (AI)

**Reviewer:** Nick (via Claude)
**Date:** 2026-05-22
**Outcome:** Approved (after auto-fixes)

### Findings (all fixed)

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | HIGH | AC5c violation: `parseExtractionResponse` silently returns `[]` for malformed JSON without logging | Added `Logger.shared.warn("LLMExperienceExtractor", "malformed_json_response", ...)` |
| 2 | HIGH | AC5d violation: individual signal parse failures not counted in `skippedCount` | Changed return type to `ParsedExtraction` struct, parse failures now increment `skipped` |
| 3 | MEDIUM | E2E test file not in story File List | Added `LLMExperienceExtractorE2ETests.swift` to File List |
| 4 | MEDIUM | Missing `.taskProgress` and `.toolProgress` in exclusion test | Added both cases to `testSerializeExcludesNonEssentialMessageTypes` |
| 5 | MEDIUM | Completion Notes test count wrong (5023 vs 5035) | Updated to 5035, added E2E test count note |

### Verification
- `swift build`: 0 errors, 0 warnings
- `swift test`: 5035 tests, 26 skipped, 0 failures
