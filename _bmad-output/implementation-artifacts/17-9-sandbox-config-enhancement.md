# Story 17.9: Sandbox Config Enhancement

Status: done

## Story

As an SDK developer,
I want to add the missing SandboxNetworkConfig type and 5 missing SandboxSettings fields to the Swift SDK,
so that all security controls from the TypeScript SDK are available in Swift.

## Acceptance Criteria

1. **AC1: SandboxNetworkConfig type** -- Add `SandboxNetworkConfig` struct with 7 fields: `allowedDomains: [String]`, `allowManagedDomainsOnly: Bool`, `allowLocalBinding: Bool`, `allowUnixSockets: Bool`, `allowAllUnixSockets: Bool`, `httpProxyPort: Int?`, `socksProxyPort: Int?`. Struct is `Sendable`, `Equatable`, with DocC comments.

2. **AC2: SandboxSettings.network field** -- Add `network: SandboxNetworkConfig?` field to `SandboxSettings`, initialized to `nil` by default.

3. **AC3: autoAllowBashIfSandboxed field** -- Add `autoAllowBashIfSandboxed: Bool` field to `SandboxSettings`. When `true` and sandbox is active, BashTool skips the `canUseTool` authorization check and auto-executes (command still runs in sandbox environment).

4. **AC4: allowUnsandboxedCommands field** -- Add `allowUnsandboxedCommands: Bool` field to `SandboxSettings`. When `true`, model may request unsandboxed execution. (Field is stored; actual runtime escape hatch behavior is additive for future use.)

5. **AC5: ignoreViolations field** -- Add `ignoreViolations: [String: [String]]?` field to `SandboxSettings`. Supports category-based violation suppression (e.g., `{ "file": ["/tmp/*"], "network": ["localhost"] }`).

6. **AC6: enableWeakerNestedSandbox field** -- Add `enableWeakerNestedSandbox: Bool` field to `SandboxSettings`. Controls whether nested sandbox environments can use weaker restrictions.

7. **AC7: ripgrep field** -- Add `RipgrepConfig` struct with `command: String` and `args: [String]?` fields. Add `ripgrep: RipgrepConfig?` field to `SandboxSettings`. Both types are `Sendable`, `Equatable`.

8. **AC8: SandboxSettings init update** -- Update `SandboxSettings.init()` to accept all new fields with backward-compatible defaults (all optional, defaulting to `nil`/`false`). Existing call sites remain unbroken.

9. **AC9: autoAllowBashIfSandboxed behavior** -- When `SandboxSettings` has `autoAllowBashIfSandboxed = true` and `ToolContext.sandbox` is non-nil, BashTool bypasses the `canUseTool` permission check and executes directly. Command still passes through `SandboxChecker.checkCommand()`.

10. **AC10: Build and test** -- `swift build` zero errors zero warnings, all existing tests pass with zero regression.

## Tasks / Subtasks

- [x] Task 1: Add SandboxNetworkConfig type (AC: #1)
  - [x] Create `SandboxNetworkConfig` struct in `Sources/OpenAgentSDK/Types/SandboxSettings.swift` (append after `SandboxSettings`)
  - [x] Fields: `allowedDomains: [String]`, `allowManagedDomainsOnly: Bool`, `allowLocalBinding: Bool`, `allowUnixSockets: Bool`, `allowAllUnixSockets: Bool`, `httpProxyPort: Int?`, `socksProxyPort: Int?`
  - [x] All fields have default values (empty arrays, `false`, `nil`)
  - [x] Struct conforms to `Sendable`, `Equatable`
  - [x] Add DocC documentation

- [x] Task 2: Add RipgrepConfig type (AC: #7)
  - [x] Create `RipgrepConfig` struct in `Sources/OpenAgentSDK/Types/SandboxSettings.swift`
  - [x] Fields: `command: String`, `args: [String]?` (default `nil`)
  - [x] Struct conforms to `Sendable`, `Equatable`
  - [x] Add DocC documentation

- [x] Task 3: Add 5 new fields to SandboxSettings (AC: #2-#6, #8)
  - [x] Add `autoAllowBashIfSandboxed: Bool` (default `false`)
  - [x] Add `allowUnsandboxedCommands: Bool` (default `false`)
  - [x] Add `ignoreViolations: [String: [String]]?` (default `nil`)
  - [x] Add `enableWeakerNestedSandbox: Bool` (default `false`)
  - [x] Add `network: SandboxNetworkConfig?` (default `nil`)
  - [x] Add `ripgrep: RipgrepConfig?` (default `nil`)
  - [x] Update `init()` with new parameters (all with defaults, backward-compatible)
  - [x] Update `description` computed property to include new fields
  - [x] Verify existing call sites compile without changes (all new params have defaults)

- [x] Task 4: Wire autoAllowBashIfSandboxed into BashTool (AC: #9)
  - [x] In `Sources/OpenAgentSDK/Core/ToolExecutor.swift`, add autoAllowBashIfSandboxed bypass logic
  - [x] Add logic: if `context.sandbox?.autoAllowBashIfSandboxed == true` and tool is Bash, skip `canUseTool` check
  - [x] Verify `SandboxChecker.checkCommand()` still enforces command restrictions
  - [x] Preserve existing behavior when field is `false` (default)

- [x] Task 5: Update SandboxSettings tests (AC: #10)
  - [x] Update `Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift` to verify new fields
  - [x] Add tests for SandboxNetworkConfig construction with all 7 fields
  - [x] Add tests for RipgrepConfig construction
  - [x] Add tests for SandboxSettings with new fields (autoAllowBashIfSandboxed, etc.)
  - [x] Verify field count includes new fields

- [x] Task 6: Update CompatSandbox example (AC: #10)
  - [x] Update `Examples/CompatSandbox/main.swift` to reflect PASS status for resolved fields
  - [x] Update SandboxNetworkConfig entries from MISSING to PASS (7 fields)
  - [x] Update autoAllowBashIfSandboxed from MISSING to PASS
  - [x] Update allowUnsandboxedCommands from MISSING to PASS
  - [x] Update ignoreViolations from MISSING to PASS
  - [x] Update enableWeakerNestedSandbox from PARTIAL to PASS
  - [x] Update ripgrep from MISSING to PASS
  - [x] Verify report summary reflects improvements

- [x] Task 7: Validation (AC: #10)
  - [x] `swift build` zero errors zero warnings
  - [x] All existing tests pass with zero regression
  - [x] Run full test suite and report total count

## Dev Notes

### Position in Epic and Project

- **Epic 17** (TypeScript SDK Feature Alignment), ninth story
- **Prerequisites:** Stories 17-1 through 17-8 are done
- **This is a production code story** -- modifies SandboxSettings, adds SandboxNetworkConfig and RipgrepConfig, wires autoAllowBashIfSandboxed into BashTool
- **Focus:** Fill sandbox configuration gaps identified by Story 16-12 compatibility verification
- **Origin:** Story 16-12 compat report documented 18 MISSING items across sandbox config
- **FR mapping:** FR19 (SandboxNetworkConfig 7 fields), FR20 (5 missing SandboxSettings fields)

### Critical Gap Analysis from Story 16-12

**Missing type:**
| # | TS SDK Type | Swift Equivalent | Gap |
|---|---|---|---|
| 1 | SandboxNetworkConfig (7 fields) | NONE | Entire type missing |

**Missing SandboxSettings fields (5):**
| # | TS SDK Field | Swift Equivalent | Gap |
|---|---|---|---|
| 1 | autoAllowBashIfSandboxed?: boolean | NONE | Bash auto-approve when sandboxed |
| 2 | allowUnsandboxedCommands?: boolean | NONE | Runtime sandbox escape |
| 3 | ignoreViolations?: Record<string, string[]> | NONE | Category-based violation suppression |
| 4 | enableWeakerNestedSandbox?: boolean | allowNestedSandbox (PARTIAL) | Different semantics |
| 5 | ripgrep?: { command, args? } | NONE | Custom ripgrep config |

**SandboxNetworkConfig fields (all 7 MISSING):**
| TS Field | Type |
|---|---|
| allowedDomains | string[] |
| allowManagedDomainsOnly | boolean |
| allowLocalBinding | boolean |
| allowUnixSockets | boolean |
| allowAllUnixSockets | boolean |
| httpProxyPort | number (optional) |
| socksProxyPort | number (optional) |

### Current Source Code Structure

**File: `Sources/OpenAgentSDK/Types/SandboxSettings.swift`**

Current `SandboxSettings` struct has 6 fields:
```swift
public struct SandboxSettings: Sendable, Equatable, CustomStringConvertible {
    public var allowedReadPaths: [String]
    public var allowedWritePaths: [String]
    public var deniedPaths: [String]
    public var deniedCommands: [String]
    public var allowedCommands: [String]?
    public var allowNestedSandbox: Bool
}
```

Need to add 6 new fields:
```swift
    public var autoAllowBashIfSandboxed: Bool       // NEW
    public var allowUnsandboxedCommands: Bool        // NEW
    public var ignoreViolations: [String: [String]]? // NEW
    public var enableWeakerNestedSandbox: Bool       // NEW
    public var network: SandboxNetworkConfig?        // NEW
    public var ripgrep: RipgrepConfig?               // NEW
```

New types needed (add to same file):
```swift
public struct SandboxNetworkConfig: Sendable, Equatable {
    public var allowedDomains: [String]
    public var allowManagedDomainsOnly: Bool
    public var allowLocalBinding: Bool
    public var allowUnixSockets: Bool
    public var allowAllUnixSockets: Bool
    public var httpProxyPort: Int?
    public var socksProxyPort: Int?
}

public struct RipgrepConfig: Sendable, Equatable {
    public var command: String
    public var args: [String]?
}
```

**File: `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`**

BashTool sandbox enforcement at line ~143:
```swift
if let sandbox = context.sandbox {
    try SandboxChecker.checkCommand(input.command, settings: sandbox)
}
```

For autoAllowBashIfSandboxed, the canUseTool check is done at the Agent loop level before dispatching to tools. When `autoAllowBashIfSandboxed = true`, signal that bash commands should auto-approve through the permission system. Check how canUseTool is integrated into the agent loop to understand the right wiring point.

### Key Design Decisions

1. **SandboxNetworkConfig as struct with defaults:** All 7 fields have default values matching TS SDK behavior (empty arrays, `false`, `nil`). This allows partial configuration. Network filtering is declarative -- actual OS-level network filtering requires OS sandbox support not in scope for this story.

2. **SandboxSettings field additions are backward-compatible:** All new fields have default values in the initializer. Existing `SandboxSettings()` calls and partial initializers compile without changes.

3. **autoAllowBashIfSandboxed behavior:** When enabled, bash commands bypass the permission callback but still go through SandboxChecker enforcement. This means the command is still restricted by allowed/denied commands and paths, but no human-in-the-loop approval is needed.

4. **enableWeakerNestedSandbox vs allowNestedSandbox:** Keep both fields. `allowNestedSandbox` (existing) controls whether nested sandbox is allowed at all. `enableWeakerNestedSandbox` (new) controls whether the nested sandbox can have weaker restrictions. Different semantics.

5. **allowUnsandboxedCommands is declarative:** The field is added to SandboxSettings for API surface alignment. Full runtime escape-hatch behavior (dangerouslyDisableSandbox on BashInput) is out of scope for this story -- the field stores the configuration intent.

6. **ignoreViolations is stored but not enforced:** The field stores violation ignore rules for API compatibility. Actual enforcement integration into SandboxChecker is a separate concern and not required for this story.

### Architecture Compliance

- **Types/ module:** New types (SandboxNetworkConfig, RipgrepConfig) and field additions belong in `Sources/OpenAgentSDK/Types/SandboxSettings.swift`
- **Tools/Core/ module:** BashTool behavior change in `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`
- **Sendable compliance:** All new types must be `Sendable`. Use `Sendable` structs only.
- **No Apple-proprietary frameworks:** Foundation only.
- **Avoid naming type `Task`:** Per CLAUDE.md.
- **No new source files needed:** Extend existing `SandboxSettings.swift`. Add new types in the same file.
- **No Package.swift changes needed:** No new targets.

### File Locations

```
Sources/OpenAgentSDK/Types/SandboxSettings.swift                     # MODIFY -- add 6 fields to SandboxSettings, add SandboxNetworkConfig struct, add RipgrepConfig struct
Sources/OpenAgentSDK/Core/ToolExecutor.swift                          # MODIFY -- wire autoAllowBashIfSandboxed behavior
Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift             # MODIFY -- add tests for new fields and types
Examples/CompatSandbox/main.swift                                    # MODIFY -- update MISSING entries to PASS
_bmad-output/implementation-artifacts/sprint-status.yaml             # MODIFY -- status update
_bmad-output/implementation-artifacts/17-9-sandbox-config-enhancement.md  # MODIFY -- tasks marked complete
```

### Source Files to Reference

- `Sources/OpenAgentSDK/Types/SandboxSettings.swift` -- SandboxSettings struct with 6 fields (PRIMARY modification target)
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- BashInput struct, sandbox check at line 143 (MODIFY for autoAllowBashIfSandboxed)
- `Sources/OpenAgentSDK/Utils/SandboxChecker.swift` -- SandboxChecker enforcement logic (reference, no changes expected)
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolContext.sandbox field (reference)
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions.sandbox field at line 286 (reference)
- `Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift` -- Existing sandbox settings tests (extend with new tests)
- `Examples/CompatSandbox/main.swift` -- Compat example with 18 MISSING entries to update
- `_bmad-output/implementation-artifacts/16-12-sandbox-config-compat.md` -- Detailed gap analysis
- `_bmad-output/implementation-artifacts/17-8-mcp-integration-enhancement.md` -- Previous story patterns

### Previous Story Intelligence

**From Story 17-8 (MCP Integration Enhancement):**
- `swift build` succeeds with zero errors
- XCTest unavailable in CI (no Xcode.app); `swift build` used for compilation verification
- Pattern: add new types, extend existing structs, update compat tests from MISSING to PASS
- Compat test updates: change gap assertions to positive assertions

**From Story 17-7 through 17-1:**
- All follow same pattern: extend types, wire into runtime, update compat assertions
- Agent.swift modification pattern: add logic in both promptImpl() and stream() code paths
- 4055+ tests passing as of story 17-8

**From Story 16-12 (Sandbox Config Compat Verification):**
- Documented all sandbox gaps: SandboxNetworkConfig (7 MISSING), 5 MISSING SandboxSettings fields
- `SandboxSettings` has 6 fields currently
- `BashTool` sandbox check at line 143 is simple: `if let sandbox = context.sandbox { try SandboxChecker.checkCommand(...) }`
- CompatSandbox example reports: 14 PASS, 7 PARTIAL, 18 MISSING
- Full test suite: 3650 tests passing at time of 16-12 (now higher after stories 17-1 through 17-8)

### Anti-Patterns to Avoid

- Do NOT remove `allowNestedSandbox` -- it has different semantics from `enableWeakerNestedSandbox`. Keep both.
- Do NOT change existing `SandboxSettings.init()` parameter order -- add new parameters at the end with defaults.
- Do NOT break existing `SandboxSettings()` no-argument initialization -- all new fields must have defaults.
- Do NOT use force-unwrap (`!`) -- use guard let / if let.
- Do NOT modify `SandboxChecker` enforcement logic unless adding ignoreViolations support (optional for this story).
- Do NOT create mock-based E2E tests -- per CLAUDE.md.
- Do NOT add `dangerouslyDisableSandbox` to `BashInput` in this story -- that is out of scope.
- Do NOT forget to update `SandboxSettings.description` to include new fields.

### Implementation Strategy

1. **Start with types:** Add `SandboxNetworkConfig` and `RipgrepConfig` structs to `SandboxSettings.swift`. This is purely additive.
2. **Add fields to SandboxSettings:** Add 6 new fields with defaults to SandboxSettings. Update init() and description.
3. **Wire autoAllowBashIfSandboxed:** In BashTool, add conditional bypass of canUseTool check when field is true.
4. **Update tests:** Extend SandboxSettingsTests with new field tests.
5. **Update CompatSandbox:** Change MISSING/PARTIAL entries to PASS for resolved items.
6. **Build and verify:** `swift build` + full test suite.

### Testing Requirements

- **Existing tests must pass:** 4055+ tests (as of 17-8), zero regression
- **New unit tests needed:**
  - SandboxNetworkConfig construction with all 7 fields
  - SandboxNetworkConfig default values
  - RipgrepConfig construction with command and args
  - RipgrepConfig default args (nil)
  - SandboxSettings with autoAllowBashIfSandboxed = true
  - SandboxSettings with ignoreViolations dictionary
  - SandboxSettings with network config
  - SandboxSettings with ripgrep config
  - SandboxSettings field count (12 fields: 6 existing + 6 new)
  - SandboxSettings backward compatibility (no-arg init still works)
- **CompatSandbox example update:** Change MISSING/PARTIAL entries to PASS
- **No E2E tests with mocks:** Per CLAUDE.md
- After implementation, run full test suite and report total count

### Project Structure Notes

- New types added to `Sources/OpenAgentSDK/Types/SandboxSettings.swift` (same file as existing SandboxSettings)
- No new source files needed
- No Package.swift changes needed
- BashTool modification in `Sources/OpenAgentSDK/Tools/Core/`

### References

- [Source: Sources/OpenAgentSDK/Types/SandboxSettings.swift] -- SandboxSettings struct (6 fields to become 12)
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift#L143] -- sandbox check in BashTool
- [Source: Sources/OpenAgentSDK/Utils/SandboxChecker.swift] -- SandboxChecker enforcement
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] -- ToolContext.sandbox field
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L286] -- AgentOptions.sandbox field
- [Source: Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift] -- Existing sandbox tests
- [Source: Examples/CompatSandbox/main.swift] -- Compat example (18 MISSING entries)
- [Source: _bmad-output/implementation-artifacts/16-12-sandbox-config-compat.md] -- Detailed gap analysis
- [Source: _bmad-output/implementation-artifacts/17-8-mcp-integration-enhancement.md] -- Previous story
- [Source: _bmad-output/planning-artifacts/epics.md#Story17.9] -- Story 17.9 definition

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented SandboxNetworkConfig struct with 7 fields, all with safe defaults, Sendable+Equatable conformance, and DocC documentation.
- Implemented RipgrepConfig struct with command and args fields, Sendable+Equatable conformance, and DocC documentation.
- Added 6 new fields to SandboxSettings: autoAllowBashIfSandboxed, allowUnsandboxedCommands, ignoreViolations, enableWeakerNestedSandbox, network, ripgrep. All with backward-compatible defaults.
- Updated SandboxSettings.init() with 6 new parameters after existing 6, all with default values. Existing call sites unbroken.
- Updated SandboxSettings.description to include all new fields when set.
- Wired autoAllowBashIfSandboxed behavior in ToolExecutor.swift: when true and tool is Bash and sandbox is non-nil, skips canUseTool permission check. SandboxChecker.checkCommand() still enforced inside BashTool.
- Fixed argument ordering issues in ATDD test file (autoAllowBashIfSandboxed must come after deniedCommands in Swift named parameter calls).
- Added 10 new unit tests to SandboxSettingsTests.swift covering all new types and fields.
- Updated CompatSandbox example: 7 SandboxNetworkConfig entries MISSING->PASS, 5 SandboxSettings entries MISSING/PARTIAL->PASS, 4 ignoreViolations entries MISSING->PASS, autoAllowBashIfSandboxed behavior MISSING->PASS.
- swift build: zero errors, zero warnings.
- Full test suite: 4142 tests passing, 0 failures, 14 skipped (pre-existing).

### File List

- `Sources/OpenAgentSDK/Types/SandboxSettings.swift` -- MODIFIED: Added SandboxNetworkConfig struct (7 fields), RipgrepConfig struct (2 fields), 6 new fields to SandboxSettings, updated init() and description
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` -- MODIFIED: Added autoAllowBashIfSandboxed bypass logic in permission check section
- `Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift` -- MODIFIED: Added 10 new unit tests for new types and fields
- `Tests/OpenAgentSDKTests/Utils/SandboxConfigEnhancementATDDTests.swift` -- MODIFIED: Fixed argument ordering in 4 test methods
- `Examples/CompatSandbox/main.swift` -- MODIFIED: Updated 20+ compat entries from MISSING/PARTIAL to PASS
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- MODIFIED: Updated story status to review
- `_bmad-output/implementation-artifacts/17-9-sandbox-config-enhancement.md` -- MODIFIED: Updated tasks to complete, added completion notes
