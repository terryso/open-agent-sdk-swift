# Story 16.1: Core Query API Compatibility Verification

Status: done

## Story

As an SDK developer,
I want to verify the Swift SDK's `query()`-equivalent API is fully compatible with the TypeScript SDK's core usage patterns,
so developers can seamlessly migrate TypeScript code to Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatCoreQuery/` directory and `CompatCoreQuery` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: Basic streaming query equivalence** -- Given the TypeScript SDK pattern `for await (const msg of query({ prompt }))`, Swift SDK's `agent.stream(prompt)` produces an equivalent `AsyncStream<SDKMessage>` event stream. The `.result(ResultData)` case contains `text`, `totalCostUsd`, `usage` (`TokenUsage`), `numTurns`, `durationMs`, `costBreakdown` -- all matching TS SDK's `SDKResultMessage` fields.

3. **AC3: Blocking query equivalence** -- Given the TypeScript SDK pattern of collecting all messages to get a final result, Swift SDK's `agent.prompt()` returns `QueryResult` with `text` (TS: `result`), `status` (TS: `subtype`), `isCancelled` (TS: N/A, Swift addition), `numTurns`, `totalCostUsd`, `usage`, `durationMs`, `costBreakdown` (TS: `model_usage`).

4. **AC4: System init message equivalence** -- Given TS SDK's `SDKSystemMessage` (subtype: "init") with `session_id`, `tools`, `model`, `permissionMode`, `mcp_servers`, Swift SDK's `.system(SystemData)` with `subtype: .init` provides equivalent information. Note: Swift `SystemData` currently has `subtype` and `message` fields -- verify whether `session_id`, `tools`, `model` are included or missing.

5. **AC5: Multi-turn query equivalence** -- Given TS SDK using the same session for multi-turn queries, Swift SDK uses the same `Agent` instance with consecutive `prompt()` or `stream()` calls. The second query references content from the first.

6. **AC6: Query interrupt equivalence** -- Given TS SDK's `AbortController` + `query()` interrupt mechanism, Swift SDK uses `Task.cancel()` or `agent.interrupt()`. The returned `QueryResult` has `isCancelled == true` and contains partial results from completed turns. Streaming returns `.result(ResultData(subtype: .cancelled, ...))`.

7. **AC7: Result message error subtypes** -- Verify Swift SDK `ResultData.Subtype` covers all TS SDK error subtypes: `success`, `error_max_turns` (Swift: `errorMaxTurns`), `error_during_execution` (Swift: `errorDuringExecution`), `error_max_budget_usd` (Swift: `errorMaxBudgetUsd`), plus Swift-only `cancelled`. Verify `errors: [String]` field availability in error results.

8. **AC8: Compatibility report output** -- The example outputs a standardized compatibility report listing `[PASS]` / `[MISSING]` / `[N/A]` status for each verification point.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatCoreQuery/main.swift`
  - [x] Add `CompatCoreQuery` executable target to `Package.swift`
  - [x] Verify `swift build` passes with no errors/warnings

- [x] Task 2: Write basic streaming query verification (AC: #2, #4)
  - [x] Use `agent.stream("Hello, what is 2+2?")` to execute a simple query
  - [x] Iterate all `SDKMessage` cases with `switch`, printing each event's fields
  - [x] Capture `.system(SystemData)` with `subtype == .init`, verify fields (session_id, tools, model)
  - [x] Capture `.result(ResultData)`, verify all fields (text, usage, numTurns, durationMs, totalCostUsd, costBreakdown)
  - [x] Compare field names/structure against TS SDK `SDKResultMessage` table

- [x] Task 3: Write blocking query verification (AC: #3)
  - [x] Use `agent.prompt("What is the capital of France?")` to execute a query
  - [x] Inspect `QueryResult` fields against TS SDK `SDKResultMessage` mapping
  - [x] Verify `costBreakdown: [CostBreakdownEntry]` provides per-model usage (maps to TS `model_usage`)
  - [x] Verify `TokenUsage` includes `cacheCreationInputTokens` and `cacheReadInputTokens` (maps to TS cache fields)

- [x] Task 4: Write multi-turn query verification (AC: #5)
  - [x] Turn 1: Tell the agent "My name is Nick and my favorite color is blue"
  - [x] Turn 2: Ask "What is my name and favorite color?"
  - [x] Verify the agent remembers context from turn 1

- [x] Task 5: Write query interrupt verification (AC: #6)
  - [x] Launch a longer query inside `Task { agent.stream("Count from 1 to 100, explaining each number") }`
  - [x] After a brief delay, call `task.cancel()` or `agent.interrupt()`
  - [x] Verify `ResultData.subtype == .cancelled` in the stream result
  - [x] Verify `QueryResult.isCancelled == true` if using prompt()

- [x] Task 6: Write error subtype verification (AC: #7)
  - [x] Set `maxTurns=1` to trigger `errorMaxTurns` subtype
  - [x] Set `maxBudgetUsd=0.001` to trigger `errorMaxBudgetUsd` subtype
  - [x] Verify each error subtype matches TS SDK equivalents
  - [x] Check for `errors: [String]` field or equivalent error details

- [x] Task 7: Generate compatibility report (AC: #8)
  - [x] Output standardized compatibility report with PASS/MISSING/N/A per field
  - [x] Include field-by-field mapping table in output

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), first story
- **Prerequisites:** Epic 1-2 (Agent creation, streaming, agentic loop) are complete
- **FR Coverage:** FR1-FR4 (verification only, no new production code)
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report

### Critical API Mapping Table

The following table maps every TypeScript SDK core query field to its Swift SDK equivalent, verified against actual source code:

| TypeScript SDK | Swift SDK | Source File | Verification |
|---|---|---|---|
| `query({ prompt })` streaming | `agent.stream(prompt) -> AsyncStream<SDKMessage>` | `Sources/OpenAgentSDK/Core/Agent.swift:715` | AC2 |
| `query({ prompt })` blocking | `agent.prompt(prompt) -> QueryResult` | `Sources/OpenAgentSDK/Core/Agent.swift:327` | AC3 |
| `SDKResultMessage.subtype: "success"` | `ResultData.Subtype.success` | `Sources/OpenAgentSDK/Types/SDKMessage.swift:151` | AC7 |
| `SDKResultMessage.subtype: "error_max_turns"` | `ResultData.Subtype.errorMaxTurns` | `Sources/OpenAgentSDK/Types/SDKMessage.swift:154` | AC7 |
| `SDKResultMessage.subtype: "error_during_execution"` | `ResultData.Subtype.errorDuringExecution` | `Sources/OpenAgentSDK/Types/SDKMessage.swift:156` | AC7 |
| `SDKResultMessage.subtype: "error_max_budget_usd"` | `ResultData.Subtype.errorMaxBudgetUsd` | `Sources/OpenAgentSDK/Types/SDKMessage.swift:158` | AC7 |
| `SDKResultMessage.result` | `QueryResult.text` / `ResultData.text` | `AgentTypes.swift:359` / `SDKMessage.swift:166` | AC3 |
| `SDKResultMessage.total_cost_usd` | `QueryResult.totalCostUsd` / `ResultData.totalCostUsd` | `AgentTypes.swift:371` / `SDKMessage.swift:174` | AC3 |
| `SDKResultMessage.usage` | `QueryResult.usage` (`TokenUsage`) | `AgentTypes.swift:360` / `TokenUsage.swift:15` | AC3 |
| `SDKResultMessage.model_usage` | `QueryResult.costBreakdown` (`[CostBreakdownEntry]`) | `AgentTypes.swift:373` / `AgentTypes.swift:335` | AC3 |
| `SDKResultMessage.num_turns` | `QueryResult.numTurns` / `ResultData.numTurns` | `AgentTypes.swift:363` / `SDKMessage.swift:170` | AC3 |
| `SDKResultMessage.duration_ms` | `QueryResult.durationMs` / `ResultData.durationMs` | `AgentTypes.swift:365` / `SDKMessage.swift:172` | AC3 |
| `SDKResultMessage.stop_reason` | `AssistantData.stopReason` | `SDKMessage.swift:106` | AC2 |
| `SDKSystemMessage.session_id` | `SystemData.message` (may be missing) | `SDKMessage.swift:200` | AC4 |
| `AbortController.abort()` | `Task.cancel()` / `agent.interrupt()` | `Agent.swift:213` | AC6 |
| `for await (msg of query())` | `for await msg in agent.stream()` | `Agent.swift:715` | AC2 |
| `TokenUsage.cache_read_input_tokens` | `TokenUsage.cacheReadInputTokens` | `TokenUsage.swift:23` | AC3 |
| `TokenUsage.cache_creation_input_tokens` | `TokenUsage.cacheCreationInputTokens` | `TokenUsage.swift:21` | AC3 |

### Known Gaps to Investigate

1. **SystemData completeness** -- `SystemData` (SDKMessage.swift:200) currently has `subtype` and `message` only. TS SDK's `SDKSystemMessage(init)` includes `session_id`, `tools`, `model`, `permissionMode`, `mcp_servers`. If these are missing from Swift's `SystemData`, record as `[MISSING]`.

2. **Streaming input prompt** -- TS SDK supports `prompt: string | AsyncIterable<SDKUserMessage>`. Swift SDK's `agent.stream()` and `agent.prompt()` accept `String` only. If `AsyncIterable` input is needed, record as `[MISSING]` with note to add `streamInput()` in future.

3. **Result errors field** -- TS SDK's error subtypes include `errors: [String]`. Check if Swift `ResultData` or `QueryResult` exposes error details. If not, record as `[MISSING]`.

4. **`structuredOutput`** -- TS SDK's `SDKResultMessage` includes `structuredOutput` field. Check if Swift has equivalent. If not, record as `[MISSING]`.

5. **`permissionDenials`** -- TS SDK's `SDKResultMessage` includes `permissionDenials` field. Check if Swift has equivalent. If not, record as `[MISSING]`.

6. **`durationApiMs`** -- TS SDK's `SDKResultMessage` includes `durationApiMs`. Swift has `durationMs` only. Record whether `durationApiMs` is separate or merged.

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** `Agent` is `@unchecked Sendable` class. Use `await` for async methods. No direct actor access needed.
- **JSON/Codable boundary:** Example uses only public Swift types (`QueryResult`, `SDKMessage`, `TokenUsage`). No raw JSON handling.
- **Naming conventions:** Follow PascalCase for types, camelCase for variables. No violations.
- **Testing standards:** This is an example, not a test. But follow the project's example patterns from `Examples/` directory.

### Patterns to Follow

- Use `loadDotEnv()` / `getEnv()` for API key loading (see existing examples)
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example (no interactive prompts)
- Add bilingual (EN + Chinese) comment header
- Follow existing example structure from `Examples/BasicAgent/main.swift`, `Examples/MultiTurnExample/`, etc.

### File Locations

```
Examples/CompatCoreQuery/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatCoreQuery executable target
```

### Project Structure Notes

- Follows the unified `Examples/` directory convention
- Executable target naming: `CompatCoreQuery` (matches Epic 16 naming pattern `16-1-core-query-api-compat`)
- Source files to reference (read-only, no modifications):
  - `Sources/OpenAgentSDK/Core/Agent.swift` -- Agent class with prompt(), stream(), switchModel(), interrupt()
  - `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- SDKMessage enum + all associated data types
  - `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- QueryResult, QueryStatus, CostBreakdownEntry, AgentOptions
  - `Sources/OpenAgentSDK/Types/TokenUsage.swift` -- TokenUsage struct with cache token fields

### References

- [Source: Sources/OpenAgentSDK/Core/Agent.swift] -- prompt(), stream(), interrupt(), switchModel()
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] -- SDKMessage enum, ResultData, SystemData, AssistantData
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- QueryResult, QueryStatus, CostBreakdownEntry
- [Source: Sources/OpenAgentSDK/Types/TokenUsage.swift] -- TokenUsage with cache fields
- [Source: _bmad-output/planning-artifacts/epics.md#Epic16] -- Story 16.1 definition and compatibility matrix
- [Source: _bmad-output/planning-artifacts/architecture.md#AD2] -- AsyncStream<SDKMessage> streaming model
- [TS SDK Reference] query() function, SDKResultMessage, SDKSystemMessage types

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered. Build and tests all pass cleanly.

### Completion Notes List

- Task 1: Created `Examples/CompatCoreQuery/main.swift` with full compatibility verification covering all 8 ACs. Added executable target to `Package.swift`. Build passes with zero errors and zero warnings.
- Task 2: Streaming query verification iterates all SDKMessage cases via switch. Captures ResultData, AssistantData, and SystemData. Verifies text, usage, numTurns, durationMs, totalCostUsd, costBreakdown fields.
- Task 3: Blocking query verification tests agent.prompt() and inspects QueryResult fields including costBreakdown and TokenUsage cache fields.
- Task 4: Multi-turn verification uses same Agent instance with consecutive prompt() calls to test context retention.
- Task 5: Query interrupt verification uses Task.cancel() after 3-second delay during a long-running stream query.
- Task 6: Error subtype verification tests all ResultData.Subtype enum cases at compile time. Runtime tests for errorMaxTurns (maxTurns=1) and errorMaxBudgetUsd (maxBudgetUsd=0.0001).
- Task 7: Compatibility report generated with PASS/MISSING/N/A status for each TS SDK field. Report includes deduplication, pass rate calculation, and missing field summary.
- Known Gaps (7 MISSING fields): session_id, tools, model on SystemData; errors, structuredOutput, permissionDenials, durationApiMs. Also documented: AsyncIterable input support missing.
- Full test suite: 3403 tests passing, 0 failures.

### Change Log

- 2026-04-15: Story implementation complete. Created CompatCoreQuery example with all 7 verification tasks. All acceptance criteria satisfied.

### File List

- Examples/CompatCoreQuery/main.swift (NEW)
- Package.swift (MODIFIED - added CompatCoreQuery executable target)
