---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-map-criteria', 'step-04-analyze-gaps', 'step-05-gate-decision']
lastStep: 'step-05-gate-decision'
lastSaved: '2026-04-16'
storyId: '16-12'
---

# Traceability Report: Story 16-12 -- Sandbox Configuration Compatibility Verification

## Gate Decision: PASS

**Rationale:** P0 coverage is 100% (all 9 acceptance criteria have full test coverage via the CompatSandbox executable example), overall coverage is 100% (all 9 AC are covered by story tasks and verification code), and there are no P1 requirements (all are P0). This is a pure verification/example story with no new production code -- the example verifies existing API surface area and documents compatibility gaps between Swift and TypeScript SDK sandbox configuration. The CompatSandbox example builds with zero errors/warnings and the full test suite (3650 tests) shows no regressions.

---

## Coverage Summary

- **Total Acceptance Criteria:** 9
- **Fully Covered (Tests):** 7 (AC2, AC3, AC4, AC5, AC6, AC7, AC8)
- **Covered by Story Tasks:** 2 (AC1: build verification, AC9: compat report)
- **Overall Test Coverage:** 100%
- **P0 Coverage:** 100%

### Test Execution Results

- **Example Build:** `swift build --target CompatSandbox` -- zero errors, zero warnings
- **Example Run:** `swift run CompatSandbox` -- 43 compatibility entries output correctly
- **Full Test Suite:** 3650 tests passing, 14 skipped, 0 failures

---

## Traceability Matrix

### AC-to-Test Mapping

| AC | Description | Priority | Test Coverage | Verification Method | Status |
|----|-------------|----------|---------------|---------------------|--------|
| AC1 | Example compiles and runs | P0 | Story task (build verification) | `swift build --target CompatSandbox` succeeds | PASS |
| AC2 | SandboxSettings complete field verification | P0 | FULL | Mirror reflection + field-by-field comparison (9 TS fields mapped, 6 Swift fields verified) | PASS |
| AC3 | SandboxNetworkConfig verification | P0 | FULL | Type existence check + 7 field checks (all MISSING, v2.0 candidate) | PASS |
| AC4 | SandboxFilesystemConfig verification | P0 | FULL | Field mapping: allowWrite/denyWrite/denyRead against Swift allowedWritePaths/deniedPaths | PASS |
| AC5 | autoAllowBashIfSandboxed behavior verification | P0 | FULL | MISSING confirmed + sandbox propagation via AgentOptions/ToolContext verified | PASS |
| AC6 | excludedCommands vs allowUnsandboxedCommands | P0 | FULL | Static list comparison + SandboxChecker.isCommandAllowed runtime enforcement test | PASS |
| AC7 | dangerouslyDisableSandbox fallback verification | P0 | FULL | BashInput field check + canUseTool integration check + BashTool enforcement verified | PASS |
| AC8 | ignoreViolations pattern verification | P0 | FULL | 4 pattern checks (type, file, network, command -- all MISSING) | PASS |
| AC9 | Compatibility report output | P0 | FULL | Full field-level report with 43 entries, PASS/PARTIAL/MISSING/N/A format | PASS |

### Test Level Classification

| Test Level | Count | Description |
|------------|-------|-------------|
| Unit (Example) | 43 compat entries | All verification in `Examples/CompatSandbox/main.swift` |
| Integration | 0 | N/A (compatibility verification story) |
| E2E | 0 | N/A (compatibility verification story) |

---

## Field-Level Compatibility Matrix (43 Items)

### SandboxSettings Top-Level Fields (9 items)

| # | TS SDK Field | Swift Equivalent | Status | Note |
|---|---|---|---|---|
| 1 | SandboxSettings.enabled | AgentOptions.sandbox != nil (implicit enable) | PARTIAL | TS uses explicit enabled boolean; Swift enables when sandbox property is non-nil |
| 2 | SandboxSettings.autoAllowBashIfSandboxed | NO EQUIVALENT | MISSING | TS auto-approves Bash when sandboxed |
| 3 | SandboxSettings.excludedCommands | SandboxSettings.deniedCommands: [String] | PARTIAL | Similar concept, opposite semantics (bypass vs block) |
| 4 | SandboxSettings.allowUnsandboxedCommands | NO EQUIVALENT | MISSING | TS allows runtime unsandboxed execution requests |
| 5 | SandboxSettings.network | NO EQUIVALENT TYPE | MISSING | Entire SandboxNetworkConfig absent (v2.0 candidate) |
| 6 | SandboxSettings.filesystem | {allowedReadPaths, allowedWritePaths, deniedPaths} | PARTIAL | Split across flat fields, no dedicated type |
| 7 | SandboxSettings.ignoreViolations | NO EQUIVALENT | MISSING | No violation ignore system |
| 8 | SandboxSettings.enableWeakerNestedSandbox | SandboxSettings.allowNestedSandbox: Bool | PARTIAL | Different semantics (weaker vs allow) |
| 9 | SandboxSettings.ripgrep | NO EQUIVALENT | MISSING | No custom ripgrep configuration |

### SandboxNetworkConfig Fields (8 items)

| # | TS SDK Field | Swift Equivalent | Status |
|---|---|---|---|
| 10 | SandboxNetworkConfig type | NO EQUIVALENT TYPE | MISSING |
| 11 | allowedDomains: string[] | NO EQUIVALENT | MISSING |
| 12 | allowManagedDomainsOnly: boolean | NO EQUIVALENT | MISSING |
| 13 | allowLocalBinding: boolean | NO EQUIVALENT | MISSING |
| 14 | allowUnixSockets: boolean | NO EQUIVALENT | MISSING |
| 15 | allowAllUnixSockets: boolean | NO EQUIVALENT | MISSING |
| 16 | httpProxyPort: number | NO EQUIVALENT | MISSING |
| 17 | socksProxyPort: number | NO EQUIVALENT | MISSING |

### SandboxFilesystemConfig Fields (4 items)

| # | TS SDK Field | Swift Equivalent | Status | Note |
|---|---|---|---|---|
| 18 | allowWrite: string[] | SandboxSettings.allowedWritePaths: [String] | PASS | Direct mapping |
| 19 | denyWrite: string[] | SandboxSettings.deniedPaths: [String] | PARTIAL | Merged with denyRead into single deniedPaths |
| 20 | denyRead: string[] | SandboxSettings.deniedPaths: [String] | PARTIAL | Merged with denyWrite into single deniedPaths |
| 21 | Swift-unique: allowedReadPaths | SandboxSettings.allowedReadPaths: [String] | PASS | Swift has explicit read allowlist |

### Behavior Verification (7 items)

| # | TS SDK Behavior | Swift Equivalent | Status | Note |
|---|---|---|---|---|
| 22 | autoAllowBashIfSandboxed behavior | NO EQUIVALENT | MISSING | No auto-approve for sandboxed Bash |
| 23 | AgentOptions.sandbox propagation | AgentOptions.sandbox: SandboxSettings? | PASS | Sandbox propagates to agent |
| 24 | ToolContext.sandbox propagation | ToolContext.sandbox: SandboxSettings? | PASS | Sandbox reaches tool context |
| 25 | excludedCommands (static list) | SandboxSettings.deniedCommands | PARTIAL | Opposite semantics |
| 26 | deniedCommands enforcement | SandboxChecker.isCommandAllowed | PASS | Blocklist enforcement works |
| 27 | allowedCommands (allowlist mode) | SandboxSettings.allowedCommands: [String]? | PASS | Allowlist mode works (Swift-unique) |
| 28 | allowUnsandboxedCommands (runtime) | NO EQUIVALENT | MISSING | No runtime sandbox escape hatch |

### dangerouslyDisableSandbox Fallback (4 items)

| # | TS SDK Behavior | Swift Equivalent | Status | Note |
|---|---|---|---|---|
| 29 | BashInput.dangerouslyDisableSandbox | NO EQUIVALENT | MISSING | BashInput only has command, timeout, description |
| 30 | dangerouslyDisableSandbox -> canUseTool fallback | NO EQUIVALENT | MISSING | No sandbox escape fallback mechanism |
| 31 | canUseTool callback exists | AgentOptions.canUseTool: CanUseToolFn? | PASS | Callback exists but NOT integrated with sandbox escape |
| 32 | BashTool sandbox enforcement | BashTool -> SandboxChecker.checkCommand | PASS | Enforced, no bypass (more secure but less flexible) |

### ignoreViolations Patterns (4 items)

| # | TS SDK Pattern | Swift Equivalent | Status |
|---|---|---|---|
| 33 | ignoreViolations type | NO EQUIVALENT | MISSING |
| 34 | ignoreViolations.file pattern | NO EQUIVALENT | MISSING |
| 35 | ignoreViolations.network pattern | NO EQUIVALENT | MISSING |
| 36 | ignoreViolations.command pattern | NO EQUIVALENT | MISSING |

### Swift-Unique Fields (7 items)

| # | Swift Field | TS Equivalent | Status | Note |
|---|---|---|---|---|
| 37 | allowedReadPaths: [String] | Partially in SandboxFilesystemConfig | PASS | Explicit read path allowlist |
| 38 | allowedWritePaths: [String] | Mapped from allowWrite | PASS | Verified via reflection |
| 39 | deniedPaths: [String] | Mapped from denyWrite+denyRead | PASS | Combined read/write denial |
| 40 | deniedCommands: [String] | Similar to excludedCommands | PASS | Blocklist enforcement |
| 41 | allowedCommands: [String]? | No direct equivalent | PASS | Allowlist mode (Swift-unique) |
| 42 | allowNestedSandbox: Bool | enableWeakerNestedSandbox | PASS | Verified via reflection |
| 43 | SandboxSettings field count | 6 fields via Mirror reflection | PASS | All 6 fields confirmed |

---

## Category-Level Summary

| Category | PASS | PARTIAL | MISSING | Total | Coverage |
|----------|------|---------|---------|-------|----------|
| SandboxSettings Top-Level | 0 | 4 | 5 | 9 | 44% |
| SandboxNetworkConfig | 0 | 0 | 8 | 8 | 0% |
| SandboxFilesystemConfig | 2 | 2 | 0 | 4 | 100% |
| Behavior Verification | 4 | 1 | 2 | 7 | 71% |
| dangerouslyDisableSandbox | 2 | 0 | 2 | 4 | 50% |
| ignoreViolations | 0 | 0 | 4 | 4 | 0% |
| Swift-Unique Fields | 7 | 0 | 0 | 7 | 100% |
| **Total** | **15** | **7** | **21** | **43** | **51%** |

**Pass+Partial Rate: 51.2%** (22 of 43 TS SDK sandbox configuration fields have PASS or PARTIAL coverage in Swift SDK)

---

## Gap Analysis

### Coverage Gaps (21 MISSING items)

These gaps represent TS SDK sandbox features with NO Swift equivalent. They are documented and tracked but do NOT represent test coverage failures -- the tests correctly identify these as expected gaps in the Swift SDK's API surface.

#### Critical Missing Items (v2.0 Candidates)

1. **SandboxNetworkConfig (entire type, 8 items)** -- No network sandbox configuration exists in Swift SDK. All 7 network fields (allowedDomains, allowManagedDomainsOnly, allowLocalBinding, allowUnixSockets, allowAllUnixSockets, httpProxyPort, socksProxyPort) and the type itself are MISSING. This is the largest single gap and a v2.0 candidate.

2. **autoAllowBashIfSandboxed** -- TS SDK auto-approves Bash execution when sandbox is enabled. Swift has no equivalent behavior, requiring explicit permission for every Bash call even when sandboxed.

3. **allowUnsandboxedCommands** -- TS allows model to request unsandboxed execution at runtime. Swift has no runtime sandbox escape hatch.

4. **dangerouslyDisableSandbox (2 items)** -- TS BashInput has a boolean field to request unsandboxed execution, with fallback to canUseTool callback. Swift has neither the field nor the fallback mechanism.

5. **ignoreViolations (4 items)** -- Entire violation ignore system is MISSING. TS supports category-based violation suppression patterns (file, network, command). Swift has no equivalent.

6. **ripgrep configuration** -- TS has custom ripgrep configuration (command, args). Swift has no equivalent.

### PARTIAL Coverage (7 items)

1. **enabled** -- Swift implicitly enables sandbox when AgentOptions.sandbox is non-nil, vs TS explicit boolean toggle.
2. **excludedCommands** -- Swift's deniedCommands is a blocklist (blocks listed commands), while TS's excludedCommands bypasses the sandbox for listed commands (opposite semantics).
3. **filesystem** -- Split across 3 flat fields instead of a dedicated SandboxFilesystemConfig type.
4. **enableWeakerNestedSandbox** -- Swift's allowNestedSandbox has different default and semantics.
5. **denyWrite** -- Merged into deniedPaths (applies to both read+write, no write-specific deny).
6. **denyRead** -- Merged into deniedPaths (applies to both read+write, no read-specific deny).
7. **excludedCommands (static list)** -- Same as item 2, different semantics (deny vs bypass).

---

## Risk Assessment

| Risk | Probability | Impact | Score | Action |
|------|-------------|--------|-------|--------|
| No SandboxNetworkConfig (entire type missing) | 2 (possible future request) | 3 (significant -- no network sandbox controls) | 6 | MONITOR |
| No autoAllowBashIfSandboxed | 2 (possible future request) | 2 (degraded -- requires manual Bash approval) | 4 | DOCUMENT |
| No dangerouslyDisableSandbox fallback | 2 (possible future request) | 2 (degraded -- no runtime escape hatch) | 4 | DOCUMENT |
| No ignoreViolations system | 1 (unlikely near-term) | 2 (degraded -- no fine-grained violation control) | 2 | DOCUMENT |
| No ripgrep configuration | 1 (unlikely near-term) | 1 (minor -- niche feature) | 1 | DOCUMENT |
| deniedCommands opposite semantics | 1 (unlikely -- documented behavior) | 1 (minor -- just different naming) | 1 | DOCUMENT |

**Note on MONITOR item (SandboxNetworkConfig, risk score 6):** This is the largest gap in the sandbox configuration surface. Network-level sandboxing provides important security controls for restricting outbound connections. However, Swift's sandbox architecture is fundamentally different (blocklist/allowlist model for paths and commands, no network-level controls). Implementing network sandbox config would require significant new infrastructure and is appropriately tracked as a v2.0 candidate.

---

## Gate Decision Details

### Gate Criteria Check

| Criterion | Required | Actual | Status |
|-----------|----------|--------|--------|
| P0 Coverage | 100% | 100% | MET |
| Overall Coverage | >= 80% | 100% | MET |
| Build Verification | Zero errors/warnings | Zero errors/warnings | MET |
| No Regressions | Full suite passing | 3650 tests, 0 failures | MET |

### Decision: PASS

All acceptance criteria are fully covered by verification code and story tasks. The compatibility report correctly identifies 15 PASS, 7 PARTIAL, and 21 MISSING fields across the sandbox configuration's 43-field API surface. The 51.2% Pass+Partial rate accurately reflects the current state of Swift SDK sandbox feature parity with the TS SDK. All gaps are documented and tracked as expected findings for a compatibility verification story.

**Special consideration:** The Swift SDK uses a fundamentally different sandbox architecture (blocklist/allowlist model) from the TS SDK (enabled toggle plus granular behavior flags). Many TS SDK sandbox features (network config, violation ignore, auto-approve behaviors) have no Swift equivalent by design. The MISSING items represent architectural differences, not implementation bugs.

---

## Recommendations

1. **Implement SandboxNetworkConfig** -- The largest gap (8 MISSING items). Network sandboxing controls are important for security-sensitive deployments. Track as v2.0 candidate.
2. **Add autoAllowBashIfSandboxed equivalent** -- Reduces friction for sandboxed environments by auto-approving safe Bash calls. Consider as a future enhancement.
3. **Add dangerouslyDisableSandbox with canUseTool fallback** -- Provides runtime flexibility for escaping sandbox when authorized. Requires BashInput modification and canUseTool integration.
4. **Add ignoreViolations system** -- Fine-grained violation suppression by category. Useful for gradual sandbox adoption.
5. **Consider separate denyRead/denyWrite** -- Currently merged into deniedPaths. Separate deny lists provide more granular control matching the TS SDK model.
6. **Add ripgrep configuration** -- Custom ripgrep binary and arguments for sandbox-aware file search. Lower priority.

---

## Artifacts

- Example file: `Examples/CompatSandbox/main.swift` (43 compat entries)
- Package.swift: CompatSandbox executable target added
- Story file: `_bmad-output/implementation-artifacts/16-12-sandbox-config-compat.md`
- ATDD checklist: `_bmad-output/test-artifacts/atdd-checklist-16-12.md`
