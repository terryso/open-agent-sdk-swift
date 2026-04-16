# Story 16.9: Permission System Integrity Verification / 权限系统完整性验证

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的权限系统完全覆盖 TypeScript SDK 的所有权限类型和操作，
以便所有权限控制模式都能在 Swift 中使用。

As an SDK developer,
I want to verify that Swift SDK's permission system fully covers all permission types and operations from the TypeScript SDK,
so that all permission control modes are usable in Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatPermissions/` directory and `CompatPermissions` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: 6 PermissionMode behavior verification** -- For each of the TS SDK's 6 permission modes, verify Swift SDK behavior is consistent:
   - `default` -- standard authorization flow (read-only tools allowed, write tools blocked)
   - `acceptEdits` -- auto-accept file edits (Write/Edit allowed, other mutations blocked)
   - `bypassPermissions` -- skip all permission checks (all tools allowed)
   - `plan` -- plan mode, no tool execution (read-only allowed via ToolExecutor, non-readonly blocked)
   - `dontAsk` -- no prompt, deny if not pre-approved (non-readonly outright denied)
   - `auto` -- use model classifier to auto-approve or deny (equivalent to bypassPermissions in Swift)

3. **AC3: CanUseTool callback verification** -- Verify Swift SDK's `CanUseToolFn` is compatible with TS SDK's `CanUseTool` signature:
   - Receives: toolName, input, context (with cwd, toolUseId, permissionMode, etc.)
   - Returns: `CanUseToolResult` with `behavior` (allow/deny), optional `updatedInput`, optional `message`
   - TS SDK receives additional params: signal (AbortSignal), suggestions (PermissionUpdate[]), blockedPath, decisionReason, toolUseID, agentID
   - Verify which TS params are present vs missing in Swift

4. **AC4: PermissionUpdate operation type verification** -- Check Swift SDK for TS SDK's 6 PermissionUpdate operations:
   - `addRules` -- add permission rules
   - `replaceRules` -- replace permission rules
   - `removeRules` -- remove permission rules
   - `setMode` -- set permission mode
   - `addDirectories` -- add directories
   - `removeDirectories` -- remove directories
   Each with behavior (allow/deny/ask) and destination (userSettings/projectSettings/localSettings/session/cliArg).

5. **AC5: disallowedTools priority verification** -- Verify disallowedTools has higher priority than allowedTools and permissionMode (including bypassPermissions).

6. **AC6: allowDangerouslySkipPermissions verification** -- Verify bypassPermissions mode requires explicit confirmation (corresponding to TS SDK's allowDangerouslySkipParameters).

7. **AC7: PermissionDenial structure verification** -- Verify Swift SDK has a type equivalent to TS SDK's `SDKPermissionDenial` (tool_name, tool_use_id, tool_input), and returns it correctly in `SDKResultMessage`'s permission_denials field.

8. **AC8: Compatibility report output** -- Output compatibility status for all permission types and operations with standard `[PASS]` / `[MISSING]` / `[PARTIAL]` / `[N/A]` format.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatPermissions/main.swift`
  - [x] Add `CompatPermissions` executable target to `Package.swift`
  - [x] Verify `swift build --target CompatPermissions` passes with zero errors and zero warnings

- [x] Task 2: PermissionMode behavior verification (AC: #2)
  - [x] Enumerate all 6 PermissionMode cases from `PermissionMode.allCases`
  - [x] For each mode, verify ToolExecutor.shouldBlockTool behavior matches TS SDK
  - [x] Verify read-only tools always allowed in all modes
  - [x] Verify .acceptEdits allows Write/Edit but blocks other mutations
  - [x] Verify .plan blocks all non-readonly tools
  - [x] Verify .dontAsk outright denies non-readonly tools
  - [x] Verify .auto behaves like .bypassPermissions in Swift
  - [x] Record per-mode status with gap notes

- [x] Task 3: CanUseTool callback verification (AC: #3)
  - [x] Verify `CanUseToolFn` type signature: `@Sendable (ToolProtocol, Any, ToolContext) async -> CanUseToolResult?`
  - [x] Compare Swift params (tool, input, context) vs TS params (toolName, input, signal, suggestions, blockedPath, decisionReason, toolUseID, agentID)
  - [x] Verify `CanUseToolResult.behavior` supports allow/deny (check if `ask` is missing)
  - [x] Verify `CanUseToolResult.updatedInput` for input modification
  - [x] Verify `CanUseToolResult.message` for deny messages
  - [x] Check for missing TS fields: updatedPermissions, interrupt, toolUseID in result
  - [x] Record per-field status

- [x] Task 4: PermissionUpdate type verification (AC: #4)
  - [x] Check `PermissionUpdate` struct in HookTypes.swift (tool, behavior)
  - [x] Compare with TS SDK's 6 operation types (addRules/replaceRules/removeRules/setMode/addDirectories/removeDirectories)
  - [x] Check `PermissionBehavior` enum (allow/deny -- verify `ask` is missing)
  - [x] Check for `PermissionUpdateDestination` type (userSettings/projectSettings/localSettings/session/cliArg)
  - [x] Check for `PermissionRuleValue` type
  - [x] Record per-type status

- [x] Task 5: Permission policy system verification
  - [x] Verify `PermissionPolicy` protocol and `evaluate()` method
  - [x] Verify `ToolNameAllowlistPolicy` (equivalent to TS allowedTools)
  - [x] Verify `ToolNameDenylistPolicy` (equivalent to TS disallowedTools)
  - [x] Verify `ReadOnlyPolicy`
  - [x] Verify `CompositePolicy` for policy composition
  - [x] Verify `canUseTool(policy:)` bridge function
  - [x] Check denylist > allowlist priority in CompositePolicy
  - [x] Record per-type status

- [x] Task 6: Priority and safety verification (AC: #5, #6, #7)
  - [x] Verify canUseTool callback takes priority over permissionMode in ToolExecutor
  - [x] Verify denylist policy (deny) short-circuits in CompositePolicy
  - [x] Check for allowDangerouslySkipPermissions equivalent in Swift
  - [x] Search for PermissionDenial / permission_denials in Swift types
  - [x] Check SDKError.permissionDenied case
  - [x] Record findings

- [x] Task 7: Generate compatibility report (AC: #8)

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), ninth story
- **Prerequisites:** Stories 16-1 through 16-8 are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report
- **Focus:** This story verifies the **permission system surface area** of the SDK, including PermissionMode behaviors, CanUseTool callback, PermissionUpdate operations, and policy types. It checks whether every TS SDK permission type has a Swift counterpart.

### Critical API Mapping: TS SDK Permission Types vs Swift SDK

Based on analysis of `Sources/OpenAgentSDK/Types/PermissionTypes.swift`, `Sources/OpenAgentSDK/Types/HookTypes.swift`, `Sources/OpenAgentSDK/Core/ToolExecutor.swift`, and `Sources/OpenAgentSDK/Core/Agent.swift`:

**PermissionMode (6 cases) -- PASS expected:**
| TS SDK Mode | Swift Equivalent | Expected Status |
|---|---|---|
| `default` | `PermissionMode.default` | PASS |
| `acceptEdits` | `PermissionMode.acceptEdits` | PASS |
| `bypassPermissions` | `PermissionMode.bypassPermissions` | PASS |
| `plan` | `PermissionMode.plan` | PASS |
| `dontAsk` | `PermissionMode.dontAsk` | PASS |
| `auto` | `PermissionMode.auto` | PASS |

**CanUseToolFn signature comparison:**
| TS SDK Param | Swift Param | Expected Status |
|---|---|---|
| `toolName` (via tool param) | `ToolProtocol` (has `.name`) | PASS |
| `input` | `Any` | PASS |
| `signal` (AbortSignal) | No AbortSignal in Swift callback | MISSING |
| `suggestions` (PermissionUpdate[]) | No suggestions in callback | MISSING |
| `blockedPath` | No blockedPath param | MISSING |
| `decisionReason` | No decisionReason param | MISSING |
| `toolUseID` | Available via `ToolContext.toolUseId` | PARTIAL |
| `agentID` | No agentID param in context | MISSING |

**CanUseToolResult comparison:**
| TS SDK Field | Swift Equivalent | Expected Status |
|---|---|---|
| `behavior: "allow"` | `CanUseToolResult.behavior: .allow` | PASS |
| `behavior: "deny"` | `CanUseToolResult.behavior: .deny` | PASS |
| `updatedInput` | `CanUseToolResult.updatedInput: Any?` | PASS |
| `updatedPermissions` | No equivalent | MISSING |
| `message` (deny) | `CanUseToolResult.message: String?` | PASS |
| `interrupt` (deny) | No equivalent | MISSING |
| `toolUseID` | No equivalent in result | MISSING |

**PermissionUpdate operations:**
| TS SDK Operation | Swift Equivalent | Expected Status |
|---|---|---|
| `addRules` | No equivalent | MISSING |
| `replaceRules` | No equivalent | MISSING |
| `removeRules` | No equivalent | MISSING |
| `setMode` | `Agent.setPermissionMode(_:)` | PARTIAL |
| `addDirectories` | No equivalent | MISSING |
| `removeDirectories` | No equivalent | MISSING |
| (simplified) `PermissionUpdate` | `PermissionUpdate(tool:behavior:)` | PARTIAL |

**PermissionBehavior:**
| TS SDK Value | Swift Equivalent | Expected Status |
|---|---|---|
| `allow` | `PermissionBehavior.allow` | PASS |
| `deny` | `PermissionBehavior.deny` | PASS |
| `ask` | No equivalent | MISSING |

**PermissionUpdateDestination:**
| TS SDK Destination | Swift Equivalent | Expected Status |
|---|---|---|
| `userSettings` | No equivalent | MISSING |
| `projectSettings` | No equivalent | MISSING |
| `localSettings` | No equivalent | MISSING |
| `session` | No equivalent | MISSING |
| `cliArg` | No equivalent | MISSING |

**PermissionPolicy system (Swift-specific, not in TS):**
| Swift Type | Description | Status |
|---|---|---|
| `PermissionPolicy` protocol | Base protocol for authorization policies | Swift-only |
| `ToolNameAllowlistPolicy` | Allow only listed tools | Equivalent to TS allowedTools |
| `ToolNameDenylistPolicy` | Deny listed tools | Equivalent to TS disallowedTools |
| `ReadOnlyPolicy` | Allow only read-only tools | Equivalent to TS plan mode |
| `CompositePolicy` | Compose multiple policies | Swift-only composition pattern |
| `canUseTool(policy:)` | Bridge function | Swift-only convenience |

**ToolExecutor permission flow (implementation in Core/ToolExecutor.swift):**
1. PreToolUse hooks fire first (can block)
2. `canUseTool` callback checked (if set, takes priority over permissionMode)
3. If canUseTool returns nil, falls back to `permissionMode`-based `shouldBlockTool()`
4. `shouldBlockTool()` uses PermissionDecision enum: allow/block/deny

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** Agent is a class with internal NSLock for permission state. PermissionPolicy types are structs.
- **Naming conventions:** PascalCase for types, camelCase for variables.
- **Testing standards:** This is an example, not a test. Follow project example patterns.

### Patterns to Follow (from Stories 16-1 through 16-8)

- Use `loadDotEnv()` / `getEnv()` for API key loading
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example scaffold
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Add `CompatPermissions` executable target to Package.swift following established pattern
- Use `swift build --target CompatPermissions` for fast build verification

### File Locations

```
Examples/CompatPermissions/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatPermissions executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` -- PermissionMode (6 cases), CanUseToolResult, CanUseToolFn, PermissionPolicy protocol, ToolNameAllowlistPolicy, ToolNameDenylistPolicy, ReadOnlyPolicy, CompositePolicy, canUseTool(policy:) bridge
- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- PermissionBehavior (allow/deny), PermissionUpdate (tool, behavior), HookOutput with permissionUpdate field
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolProtocol (name, isReadOnly), ToolContext (with permissionMode, canUseTool fields)
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions (permissionMode, canUseTool properties)
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` -- shouldBlockTool() method, PermissionDecision enum (allow/block/deny), canUseTool priority logic, permissionMode fallback
- `Sources/OpenAgentSDK/Core/Agent.swift` -- setPermissionMode(_:), setCanUseTool(_:), SDKError.permissionDenied
- `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift` -- PermissionBehavior parsing from shell hook output
- `Examples/CompatCoreQuery/main.swift` -- Original CompatEntry/record() pattern
- `Examples/CompatMCP/main.swift` -- Latest reference for established compat example pattern
- `Examples/CompatOptions/main.swift` -- Latest reference for established compat example pattern

### Previous Story Intelligence (16-1 through 16-8)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Story 16-3 verified message types and found many gaps (12 of 20 TS types have no Swift equivalent)
- Story 16-4 verified hook system: 15/18 events PASS, 3 MISSING; significant field-level gaps in HookInput/Output
- Story 16-5 verified MCP integration: 4/5 config types covered, 3/4 runtime ops MISSING, tool namespace PASS
- Story 16-6 verified session management: 2/5 TS functions PASS, 3 PARTIAL, 4/6 session options MISSING
- Story 16-7 verified query methods: 3 PASS (interrupt/switchModel/setPermissionMode), 1 PARTIAL, 16 MISSING, 1 N/A
- Story 16-8 verified agent options: ~14 PASS, ~12 PARTIAL, ~14 MISSING, ~2 N/A across all categories
- Known pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `nonisolated(unsafe)` for mutable globals
- Full test suite was 3563 tests passing at time of 16-8 completion (14 skipped, 0 failures)

### Key Differences from Story 16-8

Story 16-8 verified the **configuration/options surface area** -- all fields on `AgentOptions`/`SDKConfiguration`. Story 16-9 focuses specifically on the **permission system** -- the PermissionMode behaviors, CanUseTool callback signature and result, PermissionUpdate operations, PermissionBehavior, PermissionUpdateDestination, PermissionPolicy types, and the ToolExecutor permission flow. While 16-8 touched on permissionMode/canUseTool as fields, 16-9 does deep verification of the permission system's types, behaviors, and runtime logic.

### Expected Gap Summary (Pre-verification)

Based on code analysis, the expected report will show approximately:
- **~6 PASS:** PermissionMode (all 6 cases), CanUseToolResult.behavior (allow/deny), PermissionBehavior (allow/deny), CanUseToolResult.updatedInput, canUseTool priority, setPermissionMode()
- **~3 PARTIAL:** PermissionUpdate (simplified vs 6 TS operations), CanUseToolFn params (missing signal/suggestions/etc), PermissionUpdateDestination (none exists)
- **~15 MISSING:** CanUseToolFn params (signal, suggestions, blockedPath, decisionReason, agentID), CanUseToolResult fields (updatedPermissions, interrupt, toolUseID), PermissionBehavior.ask, PermissionUpdate operations (addRules/replaceRules/removeRules/addDirectories/removeDirectories), PermissionUpdateDestination (5 values), PermissionDenial/SDKPermissionDenial, allowDangerouslySkipPermissions
- **~5 Swift-only additions:** PermissionPolicy protocol, ToolNameAllowlistPolicy, ToolNameDenylistPolicy, ReadOnlyPolicy, CompositePolicy

### Project Structure Notes

- Alignment with unified project structure: example goes in `Examples/CompatPermissions/`
- Detected variance: none -- follows established compat example pattern from stories 16-1 through 16-8

### References

- [Source: Sources/OpenAgentSDK/Types/PermissionTypes.swift] -- PermissionMode (6 cases), CanUseToolResult, CanUseToolFn, PermissionPolicy, ToolNameAllowlistPolicy, ToolNameDenylistPolicy, ReadOnlyPolicy, CompositePolicy
- [Source: Sources/OpenAgentSDK/Types/HookTypes.swift] -- PermissionBehavior (allow/deny), PermissionUpdate (tool, behavior)
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] -- ToolProtocol, ToolContext (permissionMode, canUseTool)
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentOptions (permissionMode, canUseTool)
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift] -- shouldBlockTool(), PermissionDecision, canUseTool priority logic
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] -- setPermissionMode(_:), setCanUseTool(_:), SDKError.permissionDenied
- [Source: _bmad-output/planning-artifacts/epics.md#Story16.9] -- Story 16.9 definition
- [Source: _bmad-output/implementation-artifacts/16-8-agent-options-compat.md] -- Previous story with options-level permission field findings
- [Source: _bmad-output/implementation-artifacts/16-4-hook-system-compat.md] -- Hook system compat (PermissionUpdate lives in HookTypes)

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- `swift build --target CompatPermissions` passed with zero errors and zero warnings
- Full test suite: 3563 tests passing, 14 skipped, 0 failures

### Completion Notes List

- Task 1: Created `Examples/CompatPermissions/main.swift` with complete permission system compatibility verification. `CompatPermissions` executable target already existed in Package.swift. Build verified clean.
- Task 2: Verified all 6 PermissionMode cases (default, acceptEdits, bypassPermissions, plan, dontAsk, auto) via `PermissionMode.allCases`. All 6 PASS. Also verified `setPermissionMode()` runtime API.
- Task 3: Verified `CanUseToolFn` signature (3 params: ToolProtocol, Any, ToolContext). TS has 8 params -- 2 PASS, 1 PARTIAL (toolUseID via context), 5 MISSING (signal, suggestions, blockedPath, decisionReason, agentID). CanUseToolResult: 4 fields PASS, 4 MISSING (ask behavior, updatedPermissions, interrupt, toolUseID).
- Task 4: Verified PermissionUpdate struct (tool, behavior) -- simplified vs TS 6 operations. PermissionBehavior (allow/deny) -- 2 PASS, 1 MISSING (ask). All 5 PermissionUpdateDestination types MISSING. 5 of 6 PermissionUpdate operations MISSING, 1 PARTIAL (setMode via runtime method).
- Task 5: All 6 Swift PermissionPolicy types verified PASS: PermissionPolicy protocol, ToolNameAllowlistPolicy, ToolNameDenylistPolicy, ReadOnlyPolicy, CompositePolicy, canUseTool(policy:) bridge. Denylist > allowlist priority verified in CompositePolicy.
- Task 6: canUseTool priority over permissionMode verified (code path in ToolExecutor). CompositePolicy deny short-circuit verified. allowDangerouslySkipPermissions PARTIAL (no separate flag, bypassPermissions is explicit). SDKError.permissionDenied exists with toolName and reason. No SDKPermissionDenial type or permission_denials field.
- Task 7: Full compatibility report generated with PASS/PARTIAL/MISSING/N/A format covering all permission system types and operations.

### File List

- `Examples/CompatPermissions/main.swift` -- NEW: Permission system compatibility verification example (607 lines)
- `Package.swift` -- NO CHANGE: CompatPermissions executable target already present
- `_bmad-output/implementation-artifacts/16-9-permission-system-compat.md` -- MODIFIED: Updated tasks, status, and dev agent record

## Change Log

- 2026-04-16: Story 16-9 implementation complete. Created permission system compat verification example covering all 8 ACs. Build clean, 3563 tests passing, 0 regressions.
