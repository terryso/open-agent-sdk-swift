# Story 16.12: Sandbox Configuration Compatibility Verification / Sandbox 配置兼容性验证

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 Sandbox 配置完全覆盖 TypeScript SDK 的所有沙盒选项，
以便所有安全控制都能在 Swift 中使用。

As an SDK developer,
I want to verify that Swift SDK's Sandbox configuration fully covers all sandbox options from the TypeScript SDK,
so that all security controls are usable in Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatSandbox/` directory and `CompatSandbox` executable target in `Package.swift`, `swift build --target CompatSandbox` compiles with zero errors and zero warnings.

2. **AC2: SandboxSettings complete field verification** -- Check Swift SDK's SandboxSettings contains all TS SDK top-level fields:
   - `enabled: Bool` -- enable sandbox
   - `autoAllowBashIfSandboxed: Bool` -- auto-approve Bash in sandbox
   - `excludedCommands: [String]` -- commands that always bypass sandbox
   - `allowUnsandboxedCommands: Bool` -- allow model to request unsandboxed execution
   - `network: SandboxNetworkConfig?` -- network configuration
   - `filesystem: SandboxFilesystemConfig?` -- filesystem configuration
   - `ignoreViolations: [String: [String]]?` -- violation ignore rules
   - `enableWeakerNestedSandbox: Bool` -- nested sandbox weakening
   - `ripgrep: { command, args? }?` -- custom ripgrep configuration

3. **AC3: SandboxNetworkConfig verification** -- Check Swift SDK for network sandbox config equivalent type containing TS SDK fields: allowedDomains, allowManagedDomainsOnly, allowLocalBinding, allowUnixSockets, allowAllUnixSockets, httpProxyPort, socksProxyPort. If not implemented, mark as v2.0 candidate.

4. **AC4: SandboxFilesystemConfig verification** -- Check Swift SDK's filesystem sandbox config contains TS SDK fields: allowWrite (allowed write paths), denyWrite (denied write paths), denyRead (denied read paths).

5. **AC5: autoAllowBashIfSandboxed behavior verification** -- Set `sandbox.enabled = true` + `autoAllowBashIfSandboxed = true`, verify BashTool auto-executes without additional authorization.

6. **AC6: excludedCommands vs allowUnsandboxedCommands verification** -- Verify distinction: excludedCommands is a static list (model has no control), allowUnsandboxedCommands allows model at runtime to request unsandboxed execution via dangerouslyDisableSandbox (falls back to canUseTool).

7. **AC7: dangerouslyDisableSandbox fallback verification** -- Verify BashTool's `dangerouslyDisableSandbox` input field, when enabled falls back to canUseTool callback. Verify canUseTool callback can recognize this request and implement custom authorization.

8. **AC8: ignoreViolations pattern verification** -- Verify violation ignore rules match by category (e.g., `{ "file": ["/tmp/*"], "network": ["localhost"] }`).

9. **AC9: Compatibility report output** -- Output compatibility status for all SandboxSettings fields and network/filesystem sub-configurations with standard `[PASS]` / `[MISSING]` / `[PARTIAL]` / `[N/A]` format.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatSandbox/main.swift`
  - [x] Add `CompatSandbox` executable target to `Package.swift`
  - [x] Verify `swift build --target CompatSandbox` passes with zero errors and zero warnings

- [x] Task 2: SandboxSettings field comparison (AC: #2)
  - [x] Compare each TS SDK SandboxSettings field against Swift SandboxSettings
  - [x] Record field-level status (PASS/MISSING/PARTIAL/N/A)
  - [x] Document Swift's alternative approach (blocklist/allowlist model)

- [x] Task 3: Network and filesystem config check (AC: #3, #4)
  - [x] Check for SandboxNetworkConfig equivalent -- mark MISSING if absent
  - [x] Check SandboxSettings filesystem fields vs SandboxFilesystemConfig
  - [x] Map Swift's allowedReadPaths/allowedWritePaths/deniedPaths to TS filesystem config

- [x] Task 4: Behavior verification (AC: #5, #6, #7, #8)
  - [x] Test autoAllowBashIfSandboxed equivalent (MISSING -- no such field)
  - [x] Test excludedCommands list (Swift: deniedCommands as partial equivalent)
  - [x] Test dangerouslyDisableSandbox + canUseTool fallback (MISSING)
  - [x] Test ignoreViolations (MISSING)

- [x] Task 5: Generate compatibility report (AC: #9)

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), twelfth and final story
- **Prerequisites:** Stories 16-1 through 16-11 are done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report
- **Focus:** This story verifies the **sandbox configuration surface area** -- SandboxSettings struct, network/filesystem sub-configs, behavior patterns (autoAllow, excludedCommands, dangerouslyDisableSandbox), and ignoreViolations.

### Critical API Mapping: TS SDK Sandbox Types vs Swift SDK

Based on analysis of `Sources/OpenAgentSDK/Types/SandboxSettings.swift`, `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`, `Sources/OpenAgentSDK/Utils/SandboxChecker.swift`, `Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift`, `Sources/OpenAgentSDK/Types/ToolTypes.swift`:

**IMPORTANT: The Swift SDK has a fundamentally different sandbox architecture from the TS SDK.** The TS SDK uses an `enabled` boolean toggle plus granular behavior flags, while Swift uses a blocklist/allowlist model with path and command restrictions. Many TS SDK sandbox fields have no Swift equivalent.

**SandboxSettings top-level field comparison:**
| TS SDK Field | Swift Equivalent | Expected Status |
|---|---|---|
| `enabled?: boolean` | No equivalent (sandbox is active when `AgentOptions.sandbox` is non-nil) | PARTIAL (implicit enable) |
| `autoAllowBashIfSandboxed?: boolean` | No equivalent | MISSING |
| `excludedCommands?: string[]` | `SandboxSettings.deniedCommands: [String]` (similar concept, different name) | PARTIAL (denied vs excluded semantics differ) |
| `allowUnsandboxedCommands?: boolean` | No equivalent | MISSING |
| `network?: SandboxNetworkConfig` | No equivalent type | MISSING (v2.0 candidate) |
| `filesystem?: SandboxFilesystemConfig` | Partially covered by allowedReadPaths/allowedWritePaths/deniedPaths | PARTIAL |
| `ignoreViolations?: Record<string, string[]>` | No equivalent | MISSING |
| `enableWeakerNestedSandbox?: boolean` | `SandboxSettings.allowNestedSandbox: Bool` (different default and semantics) | PARTIAL |
| `ripgrep?: { command, args? }` | No equivalent | MISSING |

**SandboxNetworkConfig comparison:**
| TS SDK Field | Swift Equivalent | Expected Status |
|---|---|---|
| `allowedDomains?: string[]` | No equivalent | MISSING |
| `allowManagedDomainsOnly?: boolean` | No equivalent | MISSING |
| `allowLocalBinding?: boolean` | No equivalent | MISSING |
| `allowUnixSockets?: boolean` | No equivalent | MISSING |
| `allowAllUnixSockets?: boolean` | No equivalent | MISSING |
| `httpProxyPort?: number` | No equivalent | MISSING |
| `socksProxyPort?: number` | No equivalent | MISSING |

**SandboxFilesystemConfig comparison:**
| TS SDK Field | Swift Equivalent | Expected Status |
|---|---|---|
| `allowWrite?: string[]` | `SandboxSettings.allowedWritePaths: [String]` | PASS (different name) |
| `denyWrite?: string[]` | `SandboxSettings.deniedPaths: [String]` (applies to both read+write) | PARTIAL (no write-specific deny) |
| `denyRead?: string[]` | `SandboxSettings.deniedPaths: [String]` (applies to both read+write) | PARTIAL (no read-specific deny) |

**BashTool integration comparison:**
| TS SDK Behavior | Swift Equivalent | Expected Status |
|---|---|---|
| `dangerouslyDisableSandbox` input field on BashInput | No equivalent (BashInput only has command, timeout, description) | MISSING |
| Falls back to `canUseTool` when dangerouslyDisableSandbox=true | No equivalent behavior | MISSING |
| `autoAllowBashIfSandboxed` bypasses canUseTool for bash | No equivalent | MISSING |

**Swift-unique fields (no TS equivalent):**
| Swift Field | TS Equivalent | Notes |
|---|---|---|
| `SandboxSettings.allowedReadPaths: [String]` | Partially in SandboxFilesystemConfig | Swift splits read/write paths explicitly |
| `SandboxSettings.allowedWritePaths: [String]` | Partially in SandboxFilesystemConfig | Swift splits read/write paths explicitly |
| `SandboxSettings.allowedCommands: [String]?` | No direct equivalent | Swift's allowlist mode for commands |
| `SandboxChecker` utility | No direct equivalent (enforcement is internal) | Swift has a dedicated enforcement checker |
| `SandboxPathNormalizer` utility | No direct equivalent | Swift has path normalization for sandbox |

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Naming conventions:** PascalCase for types, camelCase for variables.
- **Testing standards:** This is an example, not a test. Follow project example patterns.

### Patterns to Follow (from Stories 16-1 through 16-11)

- Use `loadDotEnv()` / `getEnv()` for API key loading
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example scaffold
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern for report generation
- Use `nonisolated(unsafe)` for mutable global report state
- Add `CompatSandbox` executable target to Package.swift following established pattern
- Use `swift build --target CompatSandbox` for fast build verification

### File Locations

```
Examples/CompatSandbox/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatSandbox executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Types/SandboxSettings.swift` -- SandboxSettings struct (allowedReadPaths, allowedWritePaths, deniedPaths, deniedCommands, allowedCommands, allowNestedSandbox)
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- BashInput struct (command, timeout, description -- NO dangerouslyDisableSandbox), sandbox check at line 92
- `Sources/OpenAgentSDK/Utils/SandboxChecker.swift` -- SandboxChecker with isPathAllowed, checkCommand, checkShellMetacharacters
- `Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift` -- Path normalization utility
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolContext with sandbox: SandboxSettings? field
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions.sandbox field (line 135)
- `Sources/OpenAgentSDK/Types/SDKConfiguration.swift` -- SDKConfiguration.sandbox field
- `Examples/SandboxExample/main.swift` -- Existing sandbox example for reference
- `Examples/CompatPermissions/main.swift` -- Latest reference for established compat example pattern (CompatEntry/record())
- `Examples/CompatThinkingModel/main.swift` -- Previous story's example for pattern reference

### Expected Gap Summary (Pre-verification)

Based on code analysis, the expected report will show approximately:
- **~5 PASS:** allowedWritePaths (mapped from allowWrite), allowNestedSandbox (mapped from enableWeakerNestedSandbox), SandboxSettings existence, SandboxChecker enforcement, BashTool sandbox integration
- **~5 PARTIAL:** enabled (implicit vs explicit), excludedCommands (deniedCommands similar but different), filesystem config (split across 3 fields, no separate type), enableWeakerNestedSandbox (allowNestedSandbox has different semantics), denyWrite/denyRead (merged into deniedPaths)
- **~15 MISSING:** autoAllowBashIfSandboxed, allowUnsandboxedCommands, SandboxNetworkConfig (7 fields), ignoreViolations, ripgrep config, dangerouslyDisableSandbox (BashTool input), canUseTool fallback for unsandbox requests

### Previous Story Intelligence (16-1 through 16-11)

- Story 16-1 established the `CompatEntry` / `record()` pattern for compatibility reports
- Story 16-2 extended the pattern for tool system verification
- Story 16-3 verified message types and found many gaps (12 of 20 TS types have no Swift equivalent)
- Story 16-4 verified hook system: 15/18 events PASS, 3 MISSING; significant field-level gaps in HookInput/Output
- Story 16-5 verified MCP integration: 4/5 config types covered, 3/4 runtime ops MISSING, tool namespace PASS
- Story 16-6 verified session management: 2/5 TS functions PASS, 3 PARTIAL, 4/6 session options MISSING
- Story 16-7 verified query methods: 3 PASS (interrupt/switchModel/setPermissionMode), 1 PARTIAL, 16 MISSING, 1 N/A
- Story 16-8 verified agent options: ~14 PASS, ~12 PARTIAL, ~14 MISSING, ~2 N/A across all categories
- Story 16-9 verified permission system: PermissionMode all 6 PASS, CanUseToolFn many fields MISSING, PermissionPolicy types are Swift-only additions
- Story 16-10 verified subagent system: ~12 PASS, ~4 PARTIAL, ~20 MISSING
- Story 16-11 verified thinking/model config: 24 PASS, 3 PARTIAL, 10 MISSING
- Known pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Use `nonisolated(unsafe)` for mutable globals
- Full test suite was 3650 tests passing at time of 16-11 completion (14 skipped, 0 failures)

### Project Structure Notes

- Alignment with unified project structure: example goes in `Examples/CompatSandbox/`
- Detected variance: none -- follows established compat example pattern from stories 16-1 through 16-11

### References

- [Source: Sources/OpenAgentSDK/Types/SandboxSettings.swift] -- SandboxSettings struct with 6 fields
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] -- BashInput (no dangerouslyDisableSandbox), sandbox check
- [Source: Sources/OpenAgentSDK/Utils/SandboxChecker.swift] -- Command/path enforcement logic
- [Source: Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift] -- Path normalization
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] -- ToolContext.sandbox field
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentOptions.sandbox field
- [Source: Sources/OpenAgentSDK/Types/SDKConfiguration.swift] -- SDKConfiguration.sandbox field
- [Source: Examples/SandboxExample/main.swift] -- Existing sandbox example for reference
- [Source: Examples/CompatPermissions/main.swift] -- Latest compat example pattern
- [Source: _bmad-output/planning-artifacts/epics.md#Story16.12] -- Story 16.12 definition
- [Source: _bmad-output/implementation-artifacts/16-11-thinking-model-compat.md] -- Previous story findings

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Task 1: CompatSandbox example directory and scaffold already created. Package.swift already has CompatSandbox target. Build passes with zero errors and zero warnings.
- Task 2: SandboxSettings field comparison complete. 6 Swift fields verified via Mirror reflection. 9 TS SDK top-level fields mapped: 0 PASS (direct), 4 PARTIAL (enabled implicit, excludedCommands->deniedCommands, filesystem split fields, enableWeakerNestedSandbox->allowNestedSandbox), 5 MISSING (autoAllowBashIfSandboxed, allowUnsandboxedCommands, network, ignoreViolations, ripgrep).
- Task 3: SandboxNetworkConfig -- all 7 fields MISSING (v2.0 candidate). SandboxFilesystemConfig -- 1 PASS (allowWrite->allowedWritePaths), 2 PARTIAL (denyWrite/denyRead merged into deniedPaths). Swift has unique allowedReadPaths field.
- Task 4: Behavior verification complete. autoAllowBashIfSandboxed MISSING, excludedCommands PARTIAL (deniedCommands with opposite semantics), dangerouslyDisableSandbox MISSING, canUseTool exists but NOT integrated with sandbox escape, ignoreViolations MISSING. Blocklist/allowlist enforcement PASS via SandboxChecker.
- Task 5: Full compatibility report generated with deduplicated entries, summary stats, and missing items list.
- Overall: 14 PASS, 7 PARTIAL, 18 MISSING across all sandbox configuration categories.
- Full test suite: 3650 tests passing, 14 skipped, 0 failures.

### File List

- `Examples/CompatSandbox/main.swift` -- NEW: Sandbox configuration compatibility verification example
- `Package.swift` -- MODIFIED: CompatSandbox executable target added (pre-existing)

### Change Log

- 2026-04-16: Story 16-12 implementation complete. CompatSandbox example verifies all sandbox configuration fields against TS SDK. Status set to review.
- 2026-04-16: Code review (adversarial, yolo mode). 1 patch applied (removed 62 lines dead code: unused FieldMapping struct and 5 mapping arrays). 2 dismissed. 0 decision-needed. All 3650 tests passing.

### Review Findings

- [x] [Review][Patch] Dead code: FieldMapping struct and 5 mapping arrays (~62 lines) constructed but never used in report output [Examples/CompatSandbox/main.swift:354-415] -- FIXED
- [x] [Review][Dismiss] Report table alignment for long notes -- cosmetic, no action needed
- [x] [Review][Dismiss] settingsFields reflection variable -- serves valid field-count verification purpose, not dead code
