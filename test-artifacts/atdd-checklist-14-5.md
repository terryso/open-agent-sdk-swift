---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/14-5-sandbox-bash-command-filtering.md'
  - 'Sources/OpenAgentSDK/Utils/SandboxChecker.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/BashTool.swift'
  - 'Sources/OpenAgentSDK/Types/SandboxSettings.swift'
  - 'Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/FilesystemSandboxTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Core/BashToolTests.swift'
---

# ATDD Checklist - Epic 14, Story 14.5: Sandbox Bash Command Filtering

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest with direct SandboxChecker invocation) + Integration (BashTool with sandbox context)
**Detected Stack:** backend (Swift Package, XCTest)

---

## Story Summary

Integrate `SandboxChecker.checkCommand()` into BashTool so that sandbox command restrictions (allowlist/blocklist) are enforced before any shell process is spawned. Add shell metacharacter detection for subshell invocations, command substitutions, and other bypass vectors.

**As a** developer using the OpenAgentSDK
**I want** sandbox command restrictions enforced in the Bash tool
**So that** dangerous commands are intercepted while safe commands execute normally

---

## Acceptance Criteria

1. **AC1: Blocklist mode denies listed commands** -- Given `SandboxSettings(deniedCommands: ["rm", "sudo", "curl"])`, when BashTool receives `rm -rf /tmp/test`, then it returns `SDKError.permissionDenied`.
2. **AC2: Blocklist extracts basename from full path** -- Given `SandboxSettings(deniedCommands: ["rm"])`, when BashTool receives `/usr/bin/rm -rf /tmp/test`, then it extracts basename `rm` and returns `permissionDenied`.
3. **AC3: Allowlist mode permits only listed commands** -- Given `SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])`, when BashTool receives `git status`, then `git` is in the allowlist and the command executes normally.
4. **AC4: Allowlist mode denies unlisted commands** -- Given `SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])`, when BashTool receives `rm -rf /tmp/test`, then `rm` is not in the allowlist and it returns `permissionDenied`.
5. **AC5: Shell metacharacter bypass prevention -- subshell** -- Given blocklist or allowlist config, when BashTool receives `bash -c "rm -rf /tmp"` or `sh -c "rm -rf /tmp"` or `zsh -c "rm -rf /tmp"`, then the inner command is inspected, and if it contains a denied command, returns `permissionDenied`.
6. **AC6: Shell metacharacter bypass prevention -- command substitution** -- Given blocklist config, when BashTool receives `$(rm -rf /tmp)` or `` `rm -rf /tmp` ``, then the substitution content is inspected, and if it contains a denied command, returns `permissionDenied`.
7. **AC7: Shell metacharacter bypass prevention -- escape and quote** -- Given blocklist config with `deniedCommands: ["rm"]`, when BashTool receives `\rm -rf /tmp` or `"rm" -rf /tmp`, then the command name is stripped of leading `\` and surrounding quotes, matched against `rm`, and returns `permissionDenied`.
8. **AC8: Unparseable metacharacters default-deny** -- Given blocklist or allowlist config, when BashTool receives a command with unparseable shell metacharacters, then it returns `permissionDenied`.
9. **AC9: Allowlist takes precedence over blocklist** -- Given both set, allowlist mode is active and `deniedCommands` is ignored.
10. **AC10: No restrictions = no filtering** -- Given `context.sandbox == nil` or empty settings, no command filtering occurs.
11. **AC11: Sandbox check happens BEFORE process execution** -- Given a denied command, no process is spawned.
12. **AC12: Known limitations documented** -- API documentation mentions blocklist is best-effort.

---

## Test Strategy

### Test Levels

| Level | Use | Count |
|-------|-----|-------|
| Unit | SandboxChecker.checkCommand() / isCommandAllowed() direct invocation | 16 |
| Integration | BashTool.call() with ToolContext containing sandbox | 32 |
| **Total** | | **48** |

### Test Files

- **`Tests/OpenAgentSDKTests/Tools/BashSandboxTests.swift`** -- All tests in one file

### Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 35 | Core acceptance criteria, must pass |
| P1 | 13 | Edge cases and completeness |

---

## Test-to-AC Mapping

| Test | AC | Priority | Level | Status |
|------|----|----------|-------|--------|
| `testBlocklist_deniesListedCommand` | AC1 | P0 | Integration | FAILING |
| `testBlocklist_allowsUnlistedCommand` | AC1 | P0 | Integration | FAILING |
| `testBlocklist_extractsBasenameFromPath` | AC2 | P0 | Integration | FAILING |
| `testBlocklist_fullPathWithArgs_denied` | AC2 | P1 | Integration | FAILING |
| `testAllowlist_permitsListedCommand` | AC3 | P0 | Integration | FAILING |
| `testAllowlist_permitsSwiftCommand` | AC3 | P0 | Integration | FAILING |
| `testAllowlist_deniesUnlistedCommand` | AC4 | P0 | Integration | FAILING |
| `testAllowlist_deniesLs` | AC4 | P0 | Integration | FAILING |
| `testSubshell_bashC_deniedCommand` | AC5 | P0 | Integration | FAILING |
| `testSubshell_shC_deniedCommand` | AC5 | P0 | Integration | FAILING |
| `testSubshell_zshC_deniedCommand` | AC5 | P0 | Integration | FAILING |
| `testSubshell_bashC_allowedCommand` | AC5 | P1 | Integration | FAILING |
| `testSubshell_allowlistMode_deniesInnerUnlistedCommand` | AC5 | P0 | Integration | FAILING |
| `testCommandSubstitution_dollarParen_deniedCommand` | AC6 | P0 | Integration | FAILING |
| `testCommandSubstitution_backtick_deniedCommand` | AC6 | P0 | Integration | FAILING |
| `testCommandSubstitution_dollarParen_allowedCommand` | AC6 | P1 | Integration | FAILING |
| `testCommandSubstitution_backtick_sudo_denied` | AC6 | P1 | Integration | FAILING |
| `testEscapeBypass_backslashRM_denied` | AC7 | P0 | Integration | FAILING |
| `testQuoteBypass_doubleQuotedRM_denied` | AC7 | P0 | Integration | FAILING |
| `testQuoteBypass_singleQuotedRM_denied` | AC7 | P1 | Integration | FAILING |
| `testUnparseableMetachar_defaultDeny` | AC8 | P0 | Integration | FAILING |
| `testUnparseableMetachar_allowlistMode_denied` | AC8 | P0 | Integration | FAILING |
| `testAllowlistPrecedence_gitAllowed` | AC9 | P0 | Integration | FAILING |
| `testAllowlistPrecedence_rmDenied` | AC9 | P0 | Integration | FAILING |
| `testAllowlistPrecedence_lsDenied` | AC9 | P0 | Integration | FAILING |
| `testAllowlistPrecedence_swiftAllowed` | AC9 | P0 | Integration | FAILING |
| `testNoSandbox_anyCommandAllowed` | AC10 | P0 | Integration | PASSING |
| `testEmptySandbox_anyCommandAllowed` | AC10 | P0 | Integration | PASSING |
| `testEmptyAllowlist_nothingAllowed` | AC10 | P0 | Integration | FAILING |
| `testSandboxCheckBeforeProcess_denied_noSideEffect` | AC11 | P0 | Integration | FAILING |
| `testSandboxCheckBeforeProcess_allowed_createsSideEffect` | AC11 | P0 | Integration | PASSING |
| `testDocumentation_mentionsBlocklistLimitations` | AC12 | P1 | Unit | PASSING |
| `testCheckCommand_bashC_denied` | AC5 | P0 | Unit | FAILING |
| `testCheckCommand_shC_denied` | AC5 | P0 | Unit | FAILING |
| `testCheckCommand_zshC_denied` | AC5 | P0 | Unit | FAILING |
| `testCheckCommand_dashC_denied` | AC5 | P0 | Unit | FAILING |
| `testCheckCommand_kshC_denied` | AC5 | P0 | Unit | FAILING |
| `testCheckCommand_dollarSubstitution_denied` | AC6 | P0 | Unit | FAILING |
| `testCheckCommand_backtickSubstitution_denied` | AC6 | P0 | Unit | FAILING |
| `testCheckCommand_backslashEscape_denied` | AC7 | P0 | Unit | PASSING |
| `testCheckCommand_doubleQuote_denied` | AC7 | P0 | Unit | PASSING |
| `testCheckCommand_singleQuote_denied` | AC7 | P0 | Unit | PASSING |
| `testCheckCommand_deeplyNested_denied` | AC8 | P0 | Unit | FAILING |
| `testCheckCommand_bashC_allowedInAllowlist_noThrow` | AC5 | P1 | Unit | PASSING |
| `testCheckCommand_noRestrictions_noThrow` | AC10 | P0 | Unit | PASSING |
| `testIsCommandAllowed_bashC_deniedInner_returnsFalse` | AC5 | P0 | Unit | FAILING |
| `testIsCommandAllowed_dollarSubstitution_returnsFalse` | AC6 | P0 | Unit | FAILING |
| `testIsCommandAllowed_backslashEscape_returnsFalse` | AC7 | P0 | Unit | PASSING |

---

## TDD Red Phase Summary

**Total tests:** 48
**Failing (expected):** 34
**Passing (pre-existing features):** 14

### Failing tests confirm these features are NOT implemented:
1. Sandbox check integration in BashTool (no `if let sandbox = context.sandbox { try ... }`)
2. Shell metacharacter detection in SandboxChecker (`bash -c`, `sh -c`, `zsh -c`, `dash -c`, `ksh -c`)
3. Command substitution detection (`$(...)` and backticks)
4. Deeply nested metacharacter default-deny

### Passing tests confirm these features ALREADY work:
1. Backslash stripping via `extractCommandBasename()` (AC7 partial)
2. Quote stripping via `extractCommandBasename()` (AC7 partial)
3. Basename extraction from full paths (AC2 partial -- SandboxChecker level)
4. No-sandbox backward compatibility (AC10)
5. Allowlist precedence logic (AC9 -- SandboxChecker level)
6. Blocklist/allowlist basic matching (AC1/AC3/AC4 -- SandboxChecker level)

---

## Implementation Notes

### What needs to be implemented:

1. **BashTool.swift**: Add sandbox check before `executeBashProcess()`:
   ```swift
   if let sandbox = context.sandbox {
       try SandboxChecker.checkCommand(input.command, settings: sandbox)
   }
   ```

2. **SandboxChecker.swift**: Add shell metacharacter detection:
   - Detect `bash -c`, `sh -c`, `zsh -c`, `dash -c`, `ksh -c` patterns
   - Extract inner command and recursively check
   - Detect `$(...)` and backtick substitution patterns
   - Default-deny for unparseable metacharacters
   - Update `isCommandAllowed()` and `checkCommand()` to call metachar detection

### Integration Pattern (from story):
- Error flow: `try SandboxChecker.checkCommand(...)` throws `SDKError.permissionDenied`
- ToolExecutor catches and converts to `ToolResult(is_error: true)`
- Same pattern as Story 14.4 (filesystem sandbox)

---

## Validation

- [x] All acceptance criteria have corresponding tests
- [x] All tests are designed to fail before implementation (TDD red phase)
- [x] Test file compiles without errors
- [x] Test file follows project conventions (XCTest, @testable import)
- [x] Test helper patterns match existing FilesystemSandboxTests
- [x] Both unit (SandboxChecker direct) and integration (BashTool with context) levels covered
- [x] Negative and edge cases included for high-risk bypass vectors
