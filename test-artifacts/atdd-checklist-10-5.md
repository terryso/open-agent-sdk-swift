---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-10'
inputDocuments:
  - _bmad-output/implementation-artifacts/10-5-permissions-example.md
  - Tests/OpenAgentSDKTests/Documentation/PermissionsExampleComplianceTests.swift
  - Tests/OpenAgentSDKTests/Documentation/SubagentExampleComplianceTests.swift
  - Tests/OpenAgentSDKTests/Documentation/PromptAPIExampleComplianceTests.swift
  - Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift
---

# ATDD Checklist: Story 10-5 PermissionsExample

## Story Summary

**Story 10.5:** PermissionsExample - Permission control example demonstrating ToolNameAllowlistPolicy, ReadOnlyPolicy, and bypassPermissions comparison.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, XCTest framework)
- **Test Framework:** XCTest (Swift built-in)
- **Generation Mode:** AI Generation (backend, no browser recording needed)

## Test Strategy

### Test Level: Compliance/Documentation Tests (Unit-level file inspection)

These tests verify the PermissionsExample source code file exists, compiles, and uses the correct public API signatures. They follow the same pattern as SubagentExampleComplianceTests, PromptAPIExampleComplianceTests, and other documentation compliance tests in the project.

### Priority Assignment

| Priority | Test Category | Count |
|----------|---------------|-------|
| P0 | Package.swift target configuration | 3 |
| P0 | File/directory existence | 2 |
| P0 | ToolNameAllowlistPolicy usage (AC2) | 4 |
| P0 | ReadOnlyPolicy usage (AC3) | 3 |
| P0 | bypassPermissions comparison (AC4) | 3 |
| P0 | Blocking API and QueryResult (AC1) | 5 |
| P0 | Real public API signatures (AC6) | 4 |
| P0 | Comments and no exposed keys (AC7) | 5 |
| P1 | Code structure (MARK sections) | 1 |
| **Total** | | **34** |

## Acceptance Criteria to Test Mapping

### AC1: PermissionsExample Compiles and Runs

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleDirectoryExists | P0 | FAIL (red) |
| testPermissionsExampleMainSwiftExists | P0 | FAIL (red) |
| testPermissionsExampleImportsOpenAgentSDK | P0 | FAIL (red) |
| testPermissionsExampleImportsFoundation | P0 | FAIL (red) |
| testPermissionsExampleUsesCreateAgent | P0 | FAIL (red) |
| testPermissionsExampleUsesBlockingPromptAPI | P0 | FAIL (red) |
| testPermissionsExampleDisplaysQueryResultProperties | P0 | FAIL (red) |
| testPermissionsExampleUsesCoreTools | P0 | FAIL (red) |
| testPermissionsExamplePassesToolsToAgentOptions | P0 | FAIL (red) |
| testPermissionsExampleUsesCreateAgentWithOptions | P0 | FAIL (red) |

### AC2: ToolNameAllowlistPolicy Restricts Tool Access

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleUsesToolNameAllowlistPolicy | P0 | FAIL (red) |
| testPermissionsExampleAllowlistSpecifiesReadGlobGrep | P0 | FAIL (red) |
| testPermissionsExampleUsesCanUseToolPolicyBridge | P0 | FAIL (red) |
| testPermissionsExamplePassesCanUseToolToAgentOptions | P0 | FAIL (red) |

### AC3: ReadOnlyPolicy Restricts to Read-Only Operations

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleUsesReadOnlyPolicy | P0 | FAIL (red) |
| testPermissionsExampleReadOnlyPolicyBridgedViaCanUseTool | P0 | FAIL (red) |
| testPermissionsExampleShowsMultipleAgentsWithDifferentPolicies | P0 | FAIL (red) |

### AC4: bypassPermissions Mode Comparison

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleUsesBypassPermissions | P0 | FAIL (red) |
| testPermissionsExampleBypassAgentDoesNotSetCanUseTool | P0 | FAIL (red) |
| testPermissionsExampleOutputsComparisonSummary | P0 | FAIL (red) |

### AC5: Package.swift executableTarget Configured

| Test | Priority | Status |
|------|----------|--------|
| testPackageSwiftContainsPermissionsExampleTarget | P0 | FAIL (red) |
| testPermissionsExampleTargetDependsOnOpenAgentSDK | P0 | FAIL (red) |
| testPermissionsExampleTargetSpecifiesCorrectPath | P0 | FAIL (red) |

### AC6: Uses Actual Public API Signatures

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleAgentOptionsUsesRealParameterNames | P0 | FAIL (red) |
| testPermissionsExampleQueryResultMatchesSourceType | P0 | FAIL (red) |
| testPermissionsExampleUsesToolNameAllowlistPolicyRealAPI | P0 | FAIL (red) |
| testPermissionsExampleUsesCanUseToolPolicyBridgeFunction | P0 | FAIL (red) |
| testPermissionsExampleUsesAwaitForPrompt | P0 | FAIL (red) |

### AC7: Clear Comments and No Exposed Keys

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleHasTopLevelDescriptionComment | P0 | FAIL (red) |
| testPermissionsExampleHasMultipleInlineComments | P0 | FAIL (red) |
| testPermissionsExampleDoesNotExposeRealAPIKeys | P0 | FAIL (red) |
| testPermissionsExampleUsesPlaceholderOrEnvVarForAPIKey | P0 | FAIL (red) |
| testPermissionsExampleDoesNotUseForceUnwrap | P0 | FAIL (red) |

### Code Structure

| Test | Priority | Status |
|------|----------|--------|
| testPermissionsExampleHasMarkSectionsForThreeParts | P1 | FAIL (red) |

## TDD Red Phase Verification

- **Total tests generated:** 34
- **All tests FAILING (expected):** Yes (37 failures from 34 tests, some multi-assert)
- **Unexpected failures:** 0
- **Existing test regressions:** 0 (1983 total tests, only new 34 fail)
- **Tests skipped:** 4 (pre-existing)

## Test File

- `Tests/OpenAgentSDKTests/Documentation/PermissionsExampleComplianceTests.swift`

## Negative/Edge Cases Covered

1. **Bypass agent must NOT have canUseTool** - ensures the comparison agent is truly unrestricted
2. **No force unwrap** - prevents `try!` usage in example code
3. **No real API keys** - prevents key leakage in example code
4. **Multiple agents required** - ensures at least 2 agents with different policies are created
