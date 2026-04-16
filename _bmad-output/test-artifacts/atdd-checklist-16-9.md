---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-16'
story_id: '16-9'
inputDocuments:
  - _bmad-output/implementation-artifacts/16-9-permission-system-compat.md
  - Sources/OpenAgentSDK/Types/PermissionTypes.swift
  - Sources/OpenAgentSDK/Types/HookTypes.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Core/ToolExecutor.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Examples/CompatOptions/main.swift
---

# ATDD Checklist - Story 16-9: Permission System Compatibility Verification

## Stack Detection
- **Detected Stack:** backend (Swift project, Package.swift, no frontend manifests)
- **Test Framework:** Swift Package Manager (swift build / swift test)
- **Test Type:** Compatibility verification example (not unit tests)

## Generation Mode
- **Mode:** AI Generation (backend project, acceptance criteria clear, standard scenarios)

## Test Strategy

### AC Mapping to Test Scenarios

| AC | Description | Test Level | Priority | Scenario |
|---|---|---|---|---|
| AC1 | Build compilation | Build | P0 | `swift build --target CompatPermissions` succeeds with 0 errors |
| AC2 | 6 PermissionMode behavior | Unit (example) | P0 | Verify all 6 modes in PermissionMode.allCases; verify shouldBlockTool behavior |
| AC3 | CanUseTool callback verification | Unit (example) | P0 | Verify CanUseToolFn signature, CanUseToolResult fields, missing TS params |
| AC4 | PermissionUpdate operations | Unit (example) | P0 | Verify PermissionUpdate struct, PermissionBehavior enum, missing TS operations |
| AC5 | disallowedTools priority | Unit (example) | P0 | Verify denylist > allowlist in CompositePolicy |
| AC6 | allowDangerouslySkipPermissions | Unit (example) | P1 | Verify bypassPermissions requires explicit mode setting |
| AC7 | PermissionDenial structure | Unit (example) | P1 | Verify SDKError.permissionDenied, missing SDKPermissionDenial type |
| AC8 | Compatibility report output | Integration (example) | P0 | Standard PASS/MISSING/PARTIAL/N/A report format |

### TDD Red Phase Status
- Story 16-9 is a **pure verification example** (no new production code)
- The "test" is the example binary itself: `swift build --target CompatPermissions`
- All ACs verified at compile time and runtime within the example
- Red phase = example fails to compile if expected API surface is missing

## Acceptance Test Checklist

### AC1: Build Compilation
- [ ] CompatPermissions directory exists
- [ ] CompatPermissions target in Package.swift
- [ ] `swift build --target CompatPermissions` passes with zero errors, zero warnings

### AC2: 6 PermissionMode Behavior Verification
- [ ] PermissionMode.allCases contains exactly 6 cases
- [ ] .default: blocks non-readonly tools
- [ ] .acceptEdits: allows Write/Edit, blocks other mutations
- [ ] .bypassPermissions: allows all tools
- [ ] .plan: blocks all non-readonly tools
- [ ] .dontAsk: denies non-readonly tools outright
- [ ] .auto: behaves like .bypassPermissions (allows all)
- [ ] Read-only tools always allowed in all modes

### AC3: CanUseTool Callback Verification
- [ ] CanUseToolFn type signature verified: @Sendable (ToolProtocol, Any, ToolContext) async -> CanUseToolResult?
- [ ] CanUseToolResult.behavior supports .allow
- [ ] CanUseToolResult.behavior supports .deny
- [ ] CanUseToolResult.updatedInput present (Any?)
- [ ] CanUseToolResult.message present (String?)
- [ ] Missing TS params documented: signal, suggestions, blockedPath, decisionReason, agentID
- [ ] Missing result fields documented: updatedPermissions, interrupt, toolUseID

### AC4: PermissionUpdate Type Verification
- [ ] PermissionUpdate struct exists with tool + behavior fields
- [ ] PermissionBehavior.allow exists
- [ ] PermissionBehavior.deny exists
- [ ] PermissionBehavior.ask MISSING (documented)
- [ ] 6 TS operation types (addRules/replaceRules/removeRules/setMode/addDirectories/removeDirectories) checked
- [ ] PermissionUpdateDestination MISSING (documented)

### AC5: disallowedTools Priority
- [ ] CompositePolicy short-circuits on deny
- [ ] ToolNameDenylistPolicy deny takes priority over ToolNameAllowlistPolicy allow
- [ ] Denylist priority works even when allowlist contains the same tool

### AC6: allowDangerouslySkipPermissions
- [ ] bypassPermissions mode requires explicit setting
- [ ] No accidental bypass possible

### AC7: PermissionDenial Structure
- [ ] SDKError.permissionDenied exists with tool + reason params
- [ ] Missing SDKPermissionDenial type documented
- [ ] Missing permission_denials field on SDKResultMessage documented

### AC8: Compatibility Report Output
- [ ] Report uses standard [PASS] / [MISSING] / [PARTIAL] / [N/A] format
- [ ] All permission types covered in report
- [ ] Summary statistics (PASS/PARTIAL/MISSING/NA counts)
- [ ] Pass+Partial rate calculated

## Test Files Created

1. `Examples/CompatPermissions/main.swift` -- Permission system compatibility verification example
2. `Package.swift` (modified) -- Added CompatPermissions executable target

## Coverage Summary (Expected)

- ~6 PASS: PermissionMode (6 cases), PermissionBehavior (allow/deny), CanUseToolResult.behavior, setPermissionMode
- ~3 PARTIAL: PermissionUpdate (simplified), CanUseToolFn params (missing several), setMode only
- ~15 MISSING: CanUseToolFn TS params (5), CanUseToolResult TS fields (3), PermissionBehavior.ask, PermissionUpdate operations (5), PermissionUpdateDestination (5 values), SDKPermissionDenial
- ~5 Swift-only: PermissionPolicy, ToolNameAllowlistPolicy, ToolNameDenylistPolicy, ReadOnlyPolicy, CompositePolicy
