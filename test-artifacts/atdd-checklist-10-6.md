---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-10'
inputDocuments:
  - _bmad-output/implementation-artifacts/10-6-advanced-mcp-example.md
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/MCPConfig.swift
  - Examples/MCPIntegration/main.swift
  - Tests/OpenAgentSDKTests/Documentation/PermissionsExampleComplianceTests.swift
  - Package.swift
---

# ATDD Checklist: Story 10-6 AdvancedMCPExample

## Story Summary

**Story 10.6:** AdvancedMCPExample - Advanced MCP tool example demonstrating InProcessMCPServer, defineTool() with Codable inputs, MCP namespace tool invocation, and tool error handling.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, XCTest framework)
- **Test Framework:** XCTest (Swift built-in)
- **Generation Mode:** AI Generation (backend, no browser recording needed)

## Test Strategy

### Test Level: Compliance/Documentation Tests (Unit-level file inspection)

These tests verify the AdvancedMCPExample source code file exists, compiles, and uses the correct public API signatures. They follow the same pattern as PermissionsExampleComplianceTests, SubagentExampleComplianceTests, and other documentation compliance tests in the project.

### Priority Assignment

| Priority | Test Category | Count |
|----------|---------------|-------|
| P0 | Package.swift target configuration | 4 |
| P0 | File/directory existence | 3 |
| P0 | defineTool() with Codable input (AC2) | 5 |
| P0 | InProcessMCPServer wrapping (AC3) | 5 |
| P0 | Agent mcpServers configuration (AC4) | 6 |
| P0 | Tool error handling (AC5) | 3 |
| P0 | Real public API signatures (AC7) | 5 |
| P0 | Comments and no exposed keys (AC8) | 5 |
| P1 | Code structure (MARK sections) | 1 |
| **Total** | | **37 tests (39 test methods)** |

## Acceptance Criteria to Test Mapping

### AC1: AdvancedMCPExample Compiles and Runs

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleDirectoryExists | P0 | FAIL (red) |
| testAdvancedMCPExampleMainSwiftExists | P0 | FAIL (red) |
| testAdvancedMCPExampleImportsOpenAgentSDK | P0 | FAIL (red) |
| testAdvancedMCPExampleImportsFoundation | P0 | FAIL (red) |
| testAdvancedMCPExampleImportsMCP | P0 | FAIL (red) |

### AC2: Demonstrates defineTool() Creating Custom Tools with Codable Input

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleUsesDefineTool | P0 | FAIL (red) |
| testAdvancedMCPExampleDefinesAtLeastTwoCustomTools | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesCodableInputStructs | P0 | FAIL (red) |
| testAdvancedMCPExampleDefinesToolWithJSONSchema | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesToolExecuteResultVariant | P0 | FAIL (red) |

### AC3: Demonstrates InProcessMCPServer Wrapping Tools

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleUsesInProcessMCPServer | P0 | FAIL (red) |
| testAdvancedMCPExampleServerNameDoesNotContainDoubleUnderscore | P0 | FAIL (red) |
| testAdvancedMCPExamplePassesToolsToInProcessMCPServer | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesAsConfig | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesAwaitForAsConfig | P0 | FAIL (red) |

### AC4: Agent Connects via mcpServers Configuration

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleUsesAgentOptionsWithMcpServers | P0 | FAIL (red) |
| testAdvancedMCPExampleMcpServersUsesSDKConfig | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesBypassPermissions | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesCreateAgent | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesAgentPrompt | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesAwaitForPrompt | P0 | FAIL (red) |

### AC5: Demonstrates Tool Error Handling

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleHasErrorHandlingTool | P0 | FAIL (red) |
| testAdvancedMCPExampleCreatesToolExecuteResultWithError | P0 | FAIL (red) |
| testAdvancedMCPExampleDemonstratesErrorHandling | P0 | FAIL (red) |

### AC6: Package.swift executableTarget Configured

| Test | Priority | Status |
|------|----------|--------|
| testPackageSwiftContainsAdvancedMCPExampleTarget | P0 | FAIL (red) |
| testAdvancedMCPExampleTargetDependsOnOpenAgentSDK | P0 | FAIL (red) |
| testAdvancedMCPExampleTargetDependsOnMCPProduct | P0 | FAIL (red) |
| testAdvancedMCPExampleTargetSpecifiesCorrectPath | P0 | FAIL (red) |

### AC7: Uses Actual Public API Signatures

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleAgentOptionsUsesRealParameterNames | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesCreateAgentWithOptions | P0 | FAIL (red) |
| testAdvancedMCPExampleQueryResultMatchesSourceType | P0 | FAIL (red) |
| testAdvancedMCPExampleDefineToolSignatureMatchesSource | P0 | FAIL (red) |
| testAdvancedMCPExampleInProcessMCPServerInitMatchesSource | P0 | FAIL (red) |

### AC8: Clear Comments and No Exposed Keys

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleHasTopLevelDescriptionComment | P0 | FAIL (red) |
| testAdvancedMCPExampleHasMultipleInlineComments | P0 | FAIL (red) |
| testAdvancedMCPExampleDoesNotExposeRealAPIKeys | P0 | FAIL (red) |
| testAdvancedMCPExampleUsesPlaceholderOrEnvVarForAPIKey | P0 | FAIL (red) |
| testAdvancedMCPExampleDoesNotUseForceUnwrap | P0 | FAIL (red) |

### Code Structure

| Test | Priority | Status |
|------|----------|--------|
| testAdvancedMCPExampleHasMarkSectionsForParts | P1 | FAIL (red) |

## TDD Red Phase Verification

- **Total tests generated:** 39
- **Total failures:** 43 (some tests have multiple assertions)
- **All tests FAILING (expected):** Yes
- **Unexpected failures:** 0
- **Existing test regressions:** 0 (2022 total tests, only new 39 fail, 4 skipped pre-existing)
- **Test file:** `Tests/OpenAgentSDKTests/Documentation/AdvancedMCPExampleComplianceTests.swift`

## Negative/Edge Cases Covered

1. **Server name must not contain "__"** - ensures InProcessMCPServer name avoids precondition crash
2. **No force unwrap** - prevents `try!` usage in example code
3. **No real API keys** - prevents key leakage in example code
4. **MCP product dependency required** - ensures Package.swift includes MCP dependency like MCPIntegration
5. **await required for actor methods** - verifies asConfig() is called with await since InProcessMCPServer is an actor
6. **At least 2 custom tools required** - ensures meaningful multi-tool demonstration
7. **ToolExecuteResult variant must be used** - verifies at least one tool uses the error-capable variant
