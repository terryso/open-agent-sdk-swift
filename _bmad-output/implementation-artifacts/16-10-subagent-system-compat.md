# Story 16.10: Subagent System Compatibility Verification / Subagent 系统兼容性验证

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 subagent 系统完全覆盖 TypeScript SDK 的 AgentDefinition 和 Agent 工具用法，
以便所有多 Agent 编排模式都能在 Swift 中使用。

As an SDK developer,
I want to verify that Swift SDK's subagent system fully covers TypeScript SDK's AgentDefinition and Agent tool usage,
so that all multi-agent orchestration patterns are usable in Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatSubagents/` directory and `CompatSubagents` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: AgentDefinition field completeness verification** -- Check Swift SDK's `AgentDefinition` against TS SDK's `AgentDefinition` for all fields:
   - `description: String` (required in TS, optional in Swift -- note the difference)
   - `tools: [String]?` -- allowed tool list
   - `disallowedTools: [String]?` -- denied tool list
   - `prompt: String` (required in TS, maps to Swift `systemPrompt`)
   - `model: String?` -- model override (support for sonnet/opus/haiku/inherit values)
   - `mcpServers: Array<string | { name: string; tools?: string[] }>` -- MCP server spec
   - `skills: [String]?` -- preloaded skill names
   - `maxTurns: Int?` -- max turns
   - `criticalSystemReminder_EXPERIMENTAL: String?` -- experimental reminder
   Missing fields recorded as gaps.

3. **AC3: AgentMcpServerSpec verification** -- Verify subagent MCP configuration supports two modes: string reference to parent server name, and inline config record (mapping to McpServerConfig).

4. **AC4: Agent tool input type verification** -- Check Swift SDK's AgentTool input contains all TS SDK `AgentInput` fields:
   - `description: String`, `prompt: String`, `subagent_type: String`
   - `model: String?` (sonnet/opus/haiku)
   - `resume: String?`
   - `run_in_background: Bool?`
   - `max_turns: Int?` (maps to Swift `maxTurns`)
   - `name: String?`
   - `team_name: String?`
   - `mode: PermissionMode?`
   - `isolation: "worktree"?`
   Missing fields recorded as gaps.

5. **AC5: Agent tool output type verification** -- Check Swift SDK supports TS SDK `AgentOutput` three status discriminations:
   - `status: "completed"` (with agentId, content, totalToolUseCount, totalDurationMs, totalTokens, usage, prompt)
   - `status: "async_launched"` (with agentId, description, prompt, outputFile, canReadOutputFile?)
   - `status: "sub_agent_entered"` (with description, message)
   Missing statuses recorded as gaps.

6. **AC6: Subagent hook event verification** -- Verify Swift SDK supports SubagentStart and SubagentStop hook events, and HookInput contains subagent-relevant fields (agent_id, agent_type, agent_transcript_path, last_assistant_message).

7. **AC7: Multi-subagent orchestration demonstration** -- Demonstrate programmatic definition of multiple subagents with different tool sets and models, orchestrated through a parent Agent.

8. **AC8: Compatibility report output** -- Output compatibility status for all AgentDefinition, AgentInput, AgentOutput, SubagentHook types with standard `[PASS]` / `[MISSING]` / `[PARTIAL]` / `[N/A]` format.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatSubagents/main.swift`
  - [x] Add `CompatSubagents` executable target to `Package.swift`
  - [x] Verify `swift build --target CompatSubagents` passes with zero errors and zero warnings

- [x] Task 2: AgentDefinition field verification (AC: #2, #3)
  - [x] Enumerate all Swift `AgentDefinition` fields via reflection/manual inspection
  - [x] Compare with TS SDK `AgentDefinition` fields (description, tools, disallowedTools, prompt, model, mcpServers, skills, maxTurns, criticalSystemReminder_EXPERIMENTAL)
  - [x] Verify `model` supports sonnet/opus/haiku/inherit as values
  - [x] Check for `mcpServers` field (Swift `AgentDefinition` does NOT have this)
  - [x] Check for `disallowedTools` field (Swift `AgentDefinition` does NOT have this)
  - [x] Check for `skills` field (Swift `AgentDefinition` does NOT have this)
  - [x] Check for `criticalSystemReminder_EXPERIMENTAL` (Swift `AgentDefinition` does NOT have this)
  - [x] Check for `name` field (Swift has it, TS does not)
  - [x] Record per-field status

- [x] Task 3: AgentTool input/output verification (AC: #4, #5)
  - [x] Verify `AgentToolInput` struct fields (prompt, description, subagent_type, model, name, maxTurns)
  - [x] Check for missing fields: resume, run_in_background, team_name, mode, isolation
  - [x] Verify `SubAgentResult` output (text, toolCalls, isError)
  - [x] Check for missing output states: completed vs async_launched vs sub_agent_entered
  - [x] Check for missing output fields: agentId, totalToolUseCount, totalDurationMs, totalTokens, usage
  - [x] Record per-field status

- [x] Task 4: SubAgentSpawner protocol verification
  - [x] Verify `SubAgentSpawner` protocol signature: `spawn(prompt:model:systemPrompt:allowedTools:maxTurns:)`
  - [x] Compare with TS SDK agent-tool's engine creation parameters
  - [x] Check for missing spawn parameters: disallowedTools, mcpServers, skills, runInBackground
  - [x] Verify `DefaultSubAgentSpawner` implementation in Core/
  - [x] Record per-parameter status

- [x] Task 5: Subagent hook event verification (AC: #6)
  - [x] Verify `HookEvent.subagentStart` exists in Swift
  - [x] Verify `HookEvent.subagentStop` exists in Swift
  - [x] Check `HookInput` struct for subagent-specific fields (agent_id, agent_type, transcript_path, last_assistant_message)
  - [x] Register hook handlers and verify event data when subagent runs
  - [x] Record per-field status

- [x] Task 6: Builtin agent definitions verification
  - [x] Verify Swift has Explore builtin agent (matches TS SDK)
  - [x] Verify Swift has Plan builtin agent (matches TS SDK)
  - [x] Check `registerAgents()` equivalent for custom agent registration
  - [x] Record per-item status

- [x] Task 7: Multi-subagent orchestration demo (AC: #7)
  - [x] Define 2-3 custom `AgentDefinition` instances with different configs
  - [x] Demonstrate agent with restricted tool set
  - [x] Demonstrate agent with independent model override
  - [x] Demonstrate result aggregation from subagent back to parent

- [x] Task 8: Generate compatibility report (AC: #8)

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), tenth story
- **Prerequisites:** Stories 16-1 through 16-9 are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report
- **Focus:** This story verifies the **subagent system surface area** of the SDK, including AgentDefinition fields, AgentTool input/output types, SubAgentSpawner protocol, SubagentStart/Stop hooks, and built-in agent definitions.

### Critical API Mapping: TS SDK Subagent Types vs Swift SDK

Based on analysis of `Sources/OpenAgentSDK/Types/AgentTypes.swift`, `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift`, `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`, `Sources/OpenAgentSDK/Types/HookTypes.swift`, and `Sources/OpenAgentSDK/Types/ToolTypes.swift`:

**AgentDefinition field comparison:**
| TS SDK Field | Swift Equivalent | Expected Status |
|---|---|---|
| `description: string` (required) | `AgentDefinition.description: String?` (optional) | PARTIAL (TS required, Swift optional) |
| `prompt: string` (required) | `AgentDefinition.systemPrompt: String?` | PASS (different name, same purpose) |
| `tools?: string[]` | `AgentDefinition.tools: [String]?` | PASS |
| `disallowedTools?: string[]` | No equivalent | MISSING |
| `model?: 'sonnet'\|'opus'\|'haiku'\|'inherit'\|string` | `AgentDefinition.model: String?` | PARTIAL (Swift accepts any string, no enum constraint) |
| `mcpServers?: Array<string\|{ name, tools? }>` | No equivalent | MISSING |
| `skills?: string[]` | No equivalent | MISSING |
| `maxTurns?: number` | `AgentDefinition.maxTurns: Int?` | PASS |
| `criticalSystemReminder_EXPERIMENTAL?: string` | No equivalent | MISSING |
| (Swift-only) `name: String` | TS SDK has no `name` field | N/A (Swift addition) |

**AgentToolInput field comparison:**
| TS SDK Field | Swift Equivalent | Expected Status |
|---|---|---|
| `prompt: string` (required) | `AgentToolInput.prompt: String` | PASS |
| `description: string` (required) | `AgentToolInput.description: String` | PASS |
| `subagent_type?: string` | `AgentToolInput.subagent_type: String?` | PASS |
| `model?: string` | `AgentToolInput.model: String?` | PASS |
| `name?: string` | `AgentToolInput.name: String?` | PASS |
| `maxTurns?: number` | `AgentToolInput.maxTurns: Int?` | PASS (different casing from TS `max_turns`) |
| `run_in_background?: boolean` | No equivalent | MISSING |
| `resume?: string` | No equivalent | MISSING |
| `team_name?: string` | No equivalent | MISSING |
| `mode?: PermissionMode` | No equivalent | MISSING |
| `isolation?: "worktree"` | No equivalent | MISSING |

**AgentTool output (SubAgentResult) comparison:**
| TS SDK Output | Swift Equivalent | Expected Status |
|---|---|---|
| Simple text output | `SubAgentResult.text: String` | PASS |
| `toolCalls: string[]` | `SubAgentResult.toolCalls: [String]` | PASS |
| `isError: boolean` | `SubAgentResult.isError: Bool` | PASS |
| `status: "completed"` discrimination | No status field | MISSING |
| `status: "async_launched"` discrimination | No status field | MISSING |
| `status: "sub_agent_entered"` discrimination | No status field | MISSING |
| `agentId` in output | No equivalent | MISSING |
| `totalToolUseCount` | No equivalent | MISSING |
| `totalDurationMs` | No equivalent | MISSING |
| `totalTokens` | No equivalent | MISSING |
| `usage` object | No equivalent | MISSING |
| `outputFile` (async_launched) | No equivalent | MISSING |
| `canReadOutputFile` (async_launched) | No equivalent | MISSING |

**SubAgentSpawner protocol comparison:**
| TS SDK (engine creation) | Swift SubAgentSpawner | Expected Status |
|---|---|---|
| `prompt: string` | `spawn(prompt:)` | PASS |
| `model?: string` | `spawn(model:)` | PASS |
| `systemPrompt?: string` | `spawn(systemPrompt:)` | PASS |
| `tools` (filtered tool list) | `spawn(allowedTools:)` | PASS |
| `maxTurns?: number` | `spawn(maxTurns:)` | PASS |
| `disallowedTools` filtering | No equivalent | MISSING |
| `mcpServers` configuration | No equivalent | MISSING |
| `skills` configuration | No equivalent | MISSING |
| `run_in_background` support | No equivalent | MISSING |

**Subagent hook events:**
| TS SDK Event | Swift Equivalent | Expected Status |
|---|---|---|
| `SubagentStart` | `HookEvent.subagentStart` | PASS |
| `SubagentStop` | `HookEvent.subagentStop` | PASS |
| `SubagentStartHookInput` fields | `HookInput` (generic, no subagent-specific fields) | PARTIAL |
| `SubagentStopHookInput` fields | `HookInput` (generic, no subagent-specific fields) | PARTIAL |

**Builtin agents:**
| TS SDK Agent | Swift Equivalent | Expected Status |
|---|---|---|
| `Explore` agent | `BUILTIN_AGENTS["Explore"]` | PASS |
| `Plan` agent | `BUILTIN_AGENTS["Plan"]` | PASS |
| `registerAgents()` function | No public equivalent | MISSING |

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** SubAgentSpawner is a protocol; DefaultSubAgentSpawner is a class with `@unchecked Sendable`.
- **Naming conventions:** PascalCase for types, camelCase for variables.
- **Testing standards:** This is an example, not a test. Follow project example patterns.

### Patterns to Follow (from Stories 16-1 through 16-9)

- Use `loadDotEnv()` / `getEnv()` for API key loading
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example scaffold
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Add `CompatSubagents` executable target to Package.swift following established pattern
- Use `swift build --target CompatSubagents` for fast build verification

### File Locations

```
Examples/CompatSubagents/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatSubagents executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentDefinition (name, description, model, systemPrompt, tools, maxTurns), SubAgentResult (text, toolCalls, isError), SubAgentSpawner protocol
- `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` -- AgentToolInput (private struct: prompt, description, subagent_type, model, name, maxTurns), agentToolSchema, BUILTIN_AGENTS (Explore, Plan), createAgentTool() factory
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` -- DefaultSubAgentSpawner (filters AgentTool from sub-tools, resolves model/maxTurns, creates child Agent)
- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- HookEvent.subagentStart / .subagentStop, HookInput struct, HookOutput struct
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolContext.agentSpawner field
- `Examples/CompatPermissions/main.swift` -- Latest reference for established compat example pattern
- `Examples/CompatOptions/main.swift` -- Another reference for CompatEntry/record() pattern
- `Examples/SubagentExample/main.swift` -- Existing subagent demo (shows usage pattern)

### Previous Story Intelligence (16-1 through 16-9)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Story 16-3 verified message types and found many gaps (12 of 20 TS types have no Swift equivalent)
- Story 16-4 verified hook system: 15/18 events PASS, 3 MISSING; significant field-level gaps in HookInput/Output
- Story 16-5 verified MCP integration: 4/5 config types covered, 3/4 runtime ops MISSING, tool namespace PASS
- Story 16-6 verified session management: 2/5 TS functions PASS, 3 PARTIAL, 4/6 session options MISSING
- Story 16-7 verified query methods: 3 PASS (interrupt/switchModel/setPermissionMode), 1 PARTIAL, 16 MISSING, 1 N/A
- Story 16-8 verified agent options: ~14 PASS, ~12 PARTIAL, ~14 MISSING, ~2 N/A across all categories
- Story 16-9 verified permission system: PermissionMode all 6 PASS, CanUseToolFn many fields MISSING, PermissionPolicy types are Swift-only additions
- Known pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `nonisolated(unsafe)` for mutable globals
- Full test suite was 3563 tests passing at time of 16-9 completion (14 skipped, 0 failures)

### Key Differences from Story 16-9

Story 16-9 verified the **permission system surface area** (PermissionMode, CanUseTool, PermissionUpdate, policy types). Story 16-10 focuses on the **subagent/orchestration system** -- AgentDefinition fields, AgentTool I/O schema, SubAgentSpawner protocol, built-in agent definitions, and SubagentStart/Stop hooks. While 16-4 already verified hook events exist, this story digs into subagent-specific hook data fields.

### Expected Gap Summary (Pre-verification)

Based on code analysis, the expected report will show approximately:
- **~12 PASS:** AgentDefinition (description, tools, prompt/systemPrompt, model, maxTurns, name), AgentToolInput (prompt, description, subagent_type, model, name, maxTurns), SubAgentResult (text, toolCalls, isError), HookEvent (.subagentStart, .subagentStop), Builtin agents (Explore, Plan)
- **~4 PARTIAL:** AgentDefinition.model (no enum constraint), HookInput for subagent events (generic, no subagent-specific fields), AgentDefinition.description (optional vs required), prompt/systemPrompt name difference
- **~20 MISSING:** AgentDefinition fields (disallowedTools, mcpServers, skills, criticalSystemReminder_EXPERIMENTAL), AgentToolInput fields (resume, run_in_background, team_name, mode, isolation), Agent output states (completed/async_launched/sub_agent_entered and their sub-fields: agentId, totalToolUseCount, totalDurationMs, totalTokens, usage, outputFile, canReadOutputFile), SubAgentSpawner params (disallowedTools, mcpServers, skills, run_in_background), registerAgents() public API

### Project Structure Notes

- Alignment with unified project structure: example goes in `Examples/CompatSubagents/`
- Detected variance: none -- follows established compat example pattern from stories 16-1 through 16-9

### References

- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentDefinition, SubAgentResult, SubAgentSpawner protocol
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift] -- AgentToolInput (private struct), agentToolSchema, BUILTIN_AGENTS, createAgentTool()
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift] -- DefaultSubAgentSpawner concrete implementation
- [Source: Sources/OpenAgentSDK/Types/HookTypes.swift] -- HookEvent.subagentStart/.subagentStop, HookInput, HookOutput
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] -- ToolContext.agentSpawner
- [Source: _bmad-output/planning-artifacts/epics.md#Story16.10] -- Story 16.10 definition
- [Source: _bmad-output/implementation-artifacts/16-9-permission-system-compat.md] -- Previous story with permission system findings
- [Source: _bmad-output/implementation-artifacts/16-4-hook-system-compat.md] -- Hook system compat (SubagentStart/Stop events verified there)
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/types.ts#L266-L276] -- TS SDK AgentDefinition interface
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/agent-tool.ts] -- TS SDK AgentTool implementation

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Build: `swift build --target CompatSubagents` -- passed with zero errors and zero warnings
- Test suite: 3603 tests passing, 14 skipped, 0 failures (no regressions)

### Completion Notes List

- Implemented all 8 tasks in a single execution pass
- Created `Examples/CompatSubagents/main.swift` following the established CompatEntry/record() pattern from stories 16-1 through 16-9
- Added `CompatSubagents` executable target to `Package.swift`
- Verified AgentDefinition has 6 fields (name, description, model, systemPrompt, tools, maxTurns), missing 4 TS fields (disallowedTools, mcpServers, skills, criticalSystemReminder_EXPERIMENTAL)
- Verified AgentToolInput has 6 fields (prompt, description, subagent_type, model, name, maxTurns), missing 5 TS fields (resume, run_in_background, team_name, mode, isolation)
- Verified SubAgentResult has 3 fields (text, toolCalls, isError), missing all TS status discriminations and output metadata fields
- Verified SubAgentSpawner protocol has 5 spawn parameters, missing 4 TS parameters (disallowedTools, mcpServers, skills, runInBackground)
- Verified HookEvent.subagentStart and .subagentStop exist; HookInput is generic (no subagent-specific fields)
- Verified BUILTIN_AGENTS has Explore and Plan; no public registerAgents() API
- Demonstrated multi-subagent orchestration with 3 AgentDefinition instances (restricted tools, model override, inherited config)
- Generated full compatibility report with PASS/PARTIAL/MISSING/N/A format across all categories
- Fixed one compilation issue: HookRegistry.register() requires `await` due to actor isolation and uses `definition:` label not `hook:`

### Change Log

- 2026-04-16: Story 16-10 implementation complete. Added CompatSubagents example for subagent system compatibility verification.

### File List

- `Examples/CompatSubagents/main.swift` -- NEW
- `Package.swift` -- MODIFIED (added CompatSubagents executable target)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- MODIFIED (status updated)
- `_bmad-output/implementation-artifacts/16-10-subagent-system-compat.md` -- MODIFIED (tasks marked complete, Dev Agent Record updated)
