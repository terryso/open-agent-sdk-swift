# Story 16.7: Query 对象方法兼容性验证 / Query Object Methods Compatibility Verification

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 提供与 TypeScript SDK Query 对象等价的所有运行时控制方法，
以便开发者可以在查询过程中动态控制 Agent 行为。

As an SDK developer,
I want to verify that Swift SDK provides equivalent runtime control methods for the TypeScript SDK Query object,
so that developers can dynamically control Agent behavior during queries.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatQueryMethods/` directory and `CompatQueryMethods` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: 16 Query methods逐一验证** -- For each TS SDK Query object method, check Swift SDK for equivalent implementation and output compatibility matrix:

   | # | TS Query Method | Swift Equivalent | Status |
   |---|---|---|---|
   | 1 | `interrupt()` | `agent.interrupt()` | Need verify |
   | 2 | `rewindFiles(msgId, { dryRun? })` | ? | Need verify |
   | 3 | `setPermissionMode(mode)` | `agent.setPermissionMode()` | Need verify |
   | 4 | `setModel(model?)` | `agent.switchModel()` | Need verify |
   | 5 | `initializationResult()` | ? | Need verify |
   | 6 | `supportedCommands()` | ? | Need verify |
   | 7 | `supportedModels()` | ? | Need verify |
   | 8 | `supportedAgents()` | ? | Need verify |
   | 9 | `mcpServerStatus()` | ? | Need verify |
   | 10 | `reconnectMcpServer(name)` | ? | Need verify |
   | 11 | `toggleMcpServer(name, enabled)` | ? | Need verify |
   | 12 | `setMcpServers(servers)` | ? | Need verify |
   | 13 | `streamInput(stream)` | ? | Need verify |
   | 14 | `stopTask(taskId)` | ? | Need verify |
   | 15 | `close()` | ? | Need verify |
   | 16 | `setMaxThinkingTokens(n)` | ? | Need verify (added from TS source) |

3. **AC3: Existing method functional verification** -- For methods already in Swift SDK (interrupt, switchModel, setPermissionMode), verify behavior matches TS SDK. Test that `interrupt()` stops a running query, `switchModel()` changes model for next request, `setPermissionMode()` takes effect immediately.

4. **AC4: initializationResult equivalent verification** -- Check if Swift SDK has equivalent method returning data matching TS SDK `SDKControlInitializeResponse` fields: commands (SlashCommand[]), agents (AgentInfo[]), output_style, available_output_styles, models (ModelInfo[]), account (AccountInfo), fast_mode_state. Record missing fields.

5. **AC5: MCP management methods verification** -- Check if Swift SDK has methods equivalent to mcpServerStatus/reconnectMcpServer/toggleMcpServer/setMcpServers. Verify input/output structure matches TS SDK if present.

6. **AC6: streamInput equivalent verification** -- Check if Swift SDK supports multi-turn streaming input (AsyncIterable input mode). If not supported, record as gap.

7. **AC7: stopTask equivalent verification** -- Check if Swift SDK supports stopping background tasks by ID. If not supported, record as gap.

8. **AC8: Additional TS methods from source** -- Verify these additional TS SDK Agent methods found in source code:
   - `getMessages()` -- retrieve conversation messages
   - `clear()` -- reset conversation history
   - `setMaxThinkingTokens(n | null)` -- set thinking budget
   - `getSessionId()` -- get session ID
   - `getApiType()` -- get current API type

9. **AC9: Compatibility report output** -- Output compatibility status for all methods with standard format.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatQueryMethods/main.swift`
  - [x] Add `CompatQueryMethods` executable target to `Package.swift`
  - [x] Verify `swift build --target CompatQueryMethods` passes with zero errors and zero warnings

- [x] Task 2: Existing method functional verification (AC: #3)
  - [x] Test `agent.interrupt()` -- verify it stops a running stream query
  - [x] Test `agent.switchModel()` -- verify model changes for subsequent calls
  - [x] Test `agent.setPermissionMode()` -- verify permission changes take effect
  - [x] Test `agent.setCanUseTool()` -- verify custom callback works
  - [x] Record per-method behavior match/mismatch

- [x] Task 3: Missing methods discovery (AC: #2, #4, #5, #6, #7, #8)
  - [x] Check for `rewindFiles` / file checkpointing in Swift SDK
  - [x] Check for `initializationResult` / `supportedCommands` / `supportedModels` / `supportedAgents`
  - [x] Check for MCP management methods (mcpServerStatus, reconnectMcpServer, toggleMcpServer, setMcpServers)
  - [x] Check for `streamInput` (AsyncIterable prompt)
  - [x] Check for `stopTask` (stop background task by ID)
  - [x] Check for `close` / cleanup method
  - [x] Check for `setMaxThinkingTokens` equivalent
  - [x] Check for `getMessages` / `clear` / `getSessionId` / `getApiType`
  - [x] Record all findings per-method

- [x] Task 4: Generate compatibility report (AC: #9)

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), seventh story
- **Prerequisites:** Stories 16-1 through 16-6 are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report

### Critical API Mapping: TS SDK Agent Methods vs Swift SDK Agent Methods

Based on analysis of `Sources/OpenAgentSDK/Core/Agent.swift` and `Sources/OpenAgentSDK/Types/AgentTypes.swift`:

**TS SDK Agent class methods (from `open-agent-sdk-typescript/src/agent.ts`):**

| # | TS SDK Method | Swift Agent Method | Status | Gap Details |
|---|---|---|---|---|
| 1 | `interrupt()` | `Agent.interrupt()` | PASS | Both cancel running query. TS uses AbortController.abort(), Swift sets _interrupted flag + cancels _streamTask |
| 2 | `setModel(model?)` | `Agent.switchModel(_ model: String) throws` | PASS | Both change model for next request. Swift throws on empty string; TS silently ignores nil |
| 3 | `setPermissionMode(mode)` | `Agent.setPermissionMode(_ mode: PermissionMode)` | PASS | Both update mode immediately. Swift also clears canUseTool callback |
| 4 | `getMessages()` | No public equivalent | MISSING | Swift Agent has no public getMessages(). Messages are internal. Could expose `public var messages: [SDKMessage]` |
| 5 | `clear()` | No public equivalent | MISSING | Swift Agent has no clear() method. Would need to reset internal message history |
| 6 | `setMaxThinkingTokens(n \| null)` | No direct equivalent | MISSING | Swift has `AgentOptions.thinking` but no runtime method to change it. Need `setThinkingConfig(_ config: ThinkingConfig?)` |
| 7 | `getSessionId()` | No public equivalent | MISSING | Swift Agent has no session ID getter. sessionId is in AgentOptions, not a property on Agent |
| 8 | `getApiType()` | No public equivalent | N/A | TS returns "anthropic"/"openai". Swift uses `LLMProvider` enum but no public getter |
| 9 | `stopTask(taskId)` | No direct equivalent | MISSING | Swift has TaskStore but no `Agent.stopTask()`. TaskStop tool exists but not a direct Agent method |
| 10 | `close()` | No public equivalent | MISSING | Swift has no close() method. TS persists session + closes MCP connections. Swift does neither on cleanup |

**TS SDK Query methods from documentation (NOT in local TS source, from Claude Code SDK docs):**

| # | TS SDK Method | Swift Equivalent | Status | Gap Details |
|---|---|---|---|---|
| 11 | `rewindFiles(msgId, { dryRun? })` | No equivalent | MISSING | Requires enableFileCheckpointing. Swift has no file checkpointing system |
| 12 | `initializationResult()` | No equivalent | MISSING | No `SDKControlInitializeResponse` type. Would return commands, agents, models, account info |
| 13 | `supportedCommands()` | No equivalent | MISSING | No SlashCommand type. SDK does not define slash commands |
| 14 | `supportedModels()` | `MODEL_PRICING` keys (partial) | PARTIAL | Swift has `MODEL_PRICING` dictionary keys but no method returning `ModelInfo[]` with all fields |
| 15 | `supportedAgents()` | No equivalent | MISSING | No AgentInfo type. Sub-agents defined via AgentDefinition, not queried |
| 16 | `mcpServerStatus()` | No equivalent | MISSING | MCPClientManager is internal. No public method to query status |
| 17 | `reconnectMcpServer(name)` | No equivalent | MISSING | MCPClientManager is internal. No public reconnect method |
| 18 | `toggleMcpServer(name, enabled)` | No equivalent | MISSING | No toggle mechanism |
| 19 | `setMcpServers(servers)` | No equivalent | MISSING | mcpServers set at creation only via AgentOptions. No runtime replacement |
| 20 | `streamInput(stream)` | No equivalent | MISSING | Swift prompt() and stream() only accept String, not AsyncSequence. No multi-turn streaming input |

**Summary:** 3 PASS (interrupt, setModel, setPermissionMode), 1 PARTIAL (supportedModels via MODEL_PRICING keys), 16 MISSING, 1 N/A.

### ModelInfo vs TS SDK ModelInfo Field Verification

**Swift `ModelInfo` fields:**

| TS SDK ModelInfo Field | Swift ModelInfo Field | Status |
|---|---|---|
| value | value: String | PASS |
| displayName | displayName: String | PASS |
| description | description: String | PASS |
| supportsEffort | supportsEffort: Bool | PASS |
| supportedEffortLevels | **MISSING** | MISSING |
| supportsAdaptiveThinking | **MISSING** | MISSING |
| supportsFastMode | **MISSING** | MISSING |

**Summary:** 4 PASS, 3 MISSING fields.

### SDKControlInitializeResponse (from TS SDK docs)

This type does NOT exist in Swift SDK. Fields expected:
- commands: SlashCommand[] -- MISSING (no SlashCommand type)
- agents: AgentInfo[] -- MISSING (no AgentInfo type)
- output_style: string -- MISSING
- available_output_styles: string[] -- MISSING
- models: ModelInfo[] -- PARTIAL (ModelInfo exists but incomplete)
- account: AccountInfo -- MISSING (no AccountInfo type)
- fast_mode_state -- MISSING

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** Agent is a class (not actor), uses NSLock for permission-related mutations. Access with appropriate synchronization.
- **Naming conventions:** PascalCase for types, camelCase for variables.
- **Testing standards:** This is an example, not a test. Follow project example patterns.

### Patterns to Follow (from Stories 16-1 through 16-6)

- Use `loadDotEnv()` / `getEnv()` for API key loading (see `Examples/CompatCoreQuery/main.swift`)
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern from CompatCoreQuery for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Package.swift already has CompatCoreQuery, CompatToolSystem, CompatMessageTypes, CompatHooks, CompatMCP, CompatSessions targets -- add `CompatQueryMethods` following the same pattern
- Use `swift build --target CompatQueryMethods` for fast build verification

### File Locations

```
Examples/CompatQueryMethods/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatQueryMethods executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Core/Agent.swift` -- Agent class public methods (interrupt, switchModel, setPermissionMode, setCanUseTool, prompt, stream)
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions, QueryResult, AgentDefinition
- `Sources/OpenAgentSDK/Types/ModelInfo.swift` -- ModelInfo struct, MODEL_PRICING dictionary
- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` -- PermissionMode enum, CanUseToolFn
- `Sources/OpenAgentSDK/Types/ThinkingConfig.swift` -- ThinkingConfig enum
- `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` -- MCPClientManager actor (internal)
- `Sources/OpenAgentSDK/Stores/TaskStore.swift` -- TaskStore actor (for stopTask gap analysis)
- `Examples/CompatCoreQuery/main.swift` -- Reference pattern for CompatEntry/record() report generation
- `Examples/CompatMCP/main.swift` -- Latest reference for established compat example pattern

### Previous Story Intelligence (16-1 through 16-6)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Story 16-3 verified message types and found many gaps (12 of 20 TS types have no Swift equivalent)
- Story 16-4 verified hook system: 15/18 events PASS, 3 MISSING; significant field-level gaps in HookInput/Output
- Story 16-5 verified MCP integration: 4/5 config types covered, 3/4 runtime ops MISSING, tool namespace PASS
- Story 16-6 verified session management: 2/5 TS functions PASS, 3 PARTIAL, 4/6 session options MISSING
- Known pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `nonisolated(unsafe)` for mutable globals
- Full test suite was 3402 tests passing at time of 16-5 completion (14 skipped, 0 failures)
- Story 16-1 AC5 already verified multi-turn (same Agent) context retention works correctly

### Git Intelligence

Recent commits show Epic 16 progressing sequentially: 16-1 (core query), 16-2 (tool system), 16-3 (message types), 16-4 (hooks), 16-5 (MCP), 16-6 (sessions). The CompatEntry/record() pattern is established and consistent across all six examples. All examples follow the same scaffold pattern.

### Key Differences from Story 16-1

Story 16-1 verified the core query API (prompt/stream usage, SDKMessage types, QueryResult fields). Story 16-7 is different -- it verifies **runtime control methods** on the Query/Agent object. These are the methods developers call *during* or *between* queries to control behavior: interrupting, switching models, managing MCP servers, getting metadata. While 16-1 tested "can you make a query and get results," 16-7 tests "can you control the agent while it runs."

### Expected Gap Summary (Pre-verification)

Based on code analysis, the expected report will show:
- **3 PASS:** interrupt(), switchModel(), setPermissionMode()
- **1 PARTIAL:** supportedModels() (MODEL_PRICING keys exist but no ModelInfo[] method)
- **16 MISSING:** rewindFiles, initializationResult, supportedCommands, supportedAgents, mcpServerStatus, reconnectMcpServer, toggleMcpServer, setMcpServers, streamInput, stopTask, close, getMessages, clear, setMaxThinkingTokens, getSessionId
- **1 N/A:** getApiType (LLMProvider exists but no getter method)

### References

- [Source: Sources/OpenAgentSDK/Core/Agent.swift] -- Agent class with interrupt(), switchModel(), setPermissionMode(), setCanUseTool()
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentOptions, QueryResult, AgentDefinition
- [Source: Sources/OpenAgentSDK/Types/ModelInfo.swift] -- ModelInfo struct with 4 of 7 TS fields
- [Source: Sources/OpenAgentSDK/Types/PermissionTypes.swift] -- PermissionMode enum (6 cases)
- [Source: Sources/OpenAgentSDK/Types/ThinkingConfig.swift] -- ThinkingConfig enum (adaptive/enabled/disabled)
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift] -- MCPClientManager actor (connect, connectAll, getMCPTools -- no status/reconnect/toggle/setMcpServers)
- [Source: _bmad-output/planning-artifacts/epics.md#Epic16-Story7] -- Story 16.7 definition
- [Source: _bmad-output/implementation-artifacts/16-6-session-management-compat.md] -- Previous story with established report pattern
- [Source: _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md] -- Original CompatEntry/record() pattern
- [TS SDK Source] open-agent-sdk-typescript/src/agent.ts -- Agent class methods (interrupt, setModel, setPermissionMode, setMaxThinkingTokens, getSessionId, getApiType, stopTask, close, getMessages, clear)
- [TS SDK Docs] Query object, SDKControlInitializeResponse

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Created CompatQueryMethods example following established CompatEntry/record() pattern from Stories 16-1 through 16-6
- Build passes with zero errors: `swift build --target CompatQueryMethods`
- Full test suite: 3510 tests pass (14 skipped, 0 failures) -- no regressions
- AC2: Verified all 16 TS SDK Query methods -- 3 PASS, 1 PARTIAL, 12 MISSING
- AC3: Verified existing method functionality (interrupt, switchModel, setPermissionMode, setCanUseTool)
- AC4: initializationResult equivalent not found; ModelInfo has 4 of 7 TS fields
- AC5: All 4 MCP management methods MISSING from public API
- AC6: streamInput (AsyncIterable) not supported -- prompt/stream accept String only
- AC7: TaskStore.delete() is partial stopTask equivalent; no Agent.stopTask()
- AC8: 4 additional TS methods MISSING, 1 N/A; ThinkingConfig verified with 3 cases
- AC9: Compatibility report outputs 4 tables: query methods, agent methods, ModelInfo fields, overall summary

### File List

- `Examples/CompatQueryMethods/main.swift` -- NEW: Compatibility verification example
- `Package.swift` -- MODIFIED: Added CompatQueryMethods executable target

### Change Log

- 2026-04-16: Story 16-7 implementation complete. Created CompatQueryMethods example verifying 28 TS SDK Query/Agent methods and ModelInfo fields against Swift SDK.
