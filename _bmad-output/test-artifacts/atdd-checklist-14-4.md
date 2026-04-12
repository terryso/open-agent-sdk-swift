---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-13'
storyId: '14-4'
inputDocuments:
  - '_bmad-output/implementation-artifacts/14-4-filesystem-sandbox-enforcement.md'
  - 'Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/GlobTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/GrepTool.swift'
  - 'Sources/OpenAgentSDK/Utils/SandboxChecker.swift'
  - 'Sources/OpenAgentSDK/Types/SandboxSettings.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/ToolBuilder.swift'
---

# ATDD Checklist — Story 14.4: Filesystem Sandbox Enforcement

## Stack Detection
- **Detected Stack**: backend (Swift Package Manager, XCTest)
- **Generation Mode**: AI generation (backend, no browser recording)

## Test Strategy

All tests are **unit level** (direct tool invocation with real filesystem, no mocks, no LLM).

### Priority Legend
- **P0**: Must-have for acceptance (maps directly to AC)
- **P1**: Important edge case or quality check

## Acceptance Criteria → Test Mapping

### AC1: FileReadTool enforces read-path sandbox
| # | Test | Priority | Status |
|---|------|----------|--------|
| 1 | `testFileReadTool_allowedPath_succeeds` | P0 | PASS |
| 2 | `testFileReadTool_deniedPath_returnsPermissionDenied` | P0 | FAIL (RED) |
| 3 | `testFileReadTool_etcPasswd_deniedWhenProjectOnlyAllowed` | P0 | FAIL (RED) |

### AC2: FileWriteTool enforces write-path sandbox
| # | Test | Priority | Status |
|---|------|----------|--------|
| 4 | `testFileWriteTool_emptyWritePaths_deniesWrite` | P0 | FAIL (RED) |
| 5 | `testFileWriteTool_allowedWritePath_succeeds` | P0 | PASS |

### AC3: FileEditTool enforces write-path sandbox
| # | Test | Priority | Status |
|---|------|----------|--------|
| 6 | `testFileEditTool_allowedPath_succeeds` | P0 | PASS |
| 7 | `testFileEditTool_deniedWritePath_returnsPermissionDenied` | P0 | FAIL (RED) |

### AC4: GlobTool enforces read-path sandbox on search directory
| # | Test | Priority | Status |
|---|------|----------|--------|
| 8 | `testGlobTool_allowedSearchDir_succeeds` | P0 | PASS |
| 9 | `testGlobTool_deniedSearchDir_returnsPermissionDenied` | P0 | FAIL (RED) |

### AC5: GrepTool enforces read-path sandbox on search directory
| # | Test | Priority | Status |
|---|------|----------|--------|
| 10 | `testGrepTool_allowedSearchDir_succeeds` | P0 | PASS |
| 11 | `testGrepTool_deniedSearchDir_returnsPermissionDenied` | P0 | FAIL (RED) |

### AC6: Symlink escape prevention
| # | Test | Priority | Status |
|---|------|----------|--------|
| 12 | `testSymlinkEscape_readThroughSymlinkOutsideSandbox_denied` | P0 | FAIL (RED) |

### AC7: Path traversal prevention
| # | Test | Priority | Status |
|---|------|----------|--------|
| 13 | `testPathTraversal_dotDotEscapesSandbox_denied` | P0 | PASS |

### AC8: No sandbox = no restrictions
| # | Test | Priority | Status |
|---|------|----------|--------|
| 14 | `testNoSandbox_readTool_worksNormally` | P0 | PASS |
| 15 | `testNoSandbox_writeTool_worksNormally` | P0 | PASS |
| 16 | `testNoSandbox_editTool_worksNormally` | P0 | PASS |
| 17 | `testNoSandbox_globTool_worksNormally` | P0 | PASS |
| 18 | `testNoSandbox_grepTool_worksNormally` | P0 | PASS |

### AC9: Sandbox check happens BEFORE tool execution
| # | Test | Priority | Status |
|---|------|----------|--------|
| 19 | `testSandboxCheckBeforeIO_writeDenied_noFileCreated` | P0 | FAIL (RED) |
| 20 | `testSandboxCheckBeforeIO_editDenied_fileUnmodified` | P0 | FAIL (RED) |

### AC10: deniedPaths takes precedence
| # | Test | Priority | Status |
|---|------|----------|--------|
| 21 | `testDeniedPathsOverridesAllowedPaths_readDenied` | P0 | FAIL (RED) |
| 22 | `testDeniedPathsDoesNotBlockUnrelatedPaths_readAllowed` | P0 | PASS |

### Edge Cases
| # | Test | Priority | Status |
|---|------|----------|--------|
| 23 | `testEmptySandboxSettings_noRestrictions` | P1 | PASS |
| 24 | `testTrailingSlashInAllowedPaths_matchesCorrectly` | P1 | PASS |
| 25 | `testGlobTool_defaultCwd_withSandbox` | P1 | PASS |
| 26 | `testGrepTool_defaultCwd_withSandbox` | P1 | PASS |

## Summary

- **Total tests**: 26 (across 10 test classes)
- **FAIL (RED)**: 10 — These require sandbox enforcement code in the 5 file tools
- **PASS**: 16 — These test scenarios that already work (no sandbox, allowed paths, empty settings)
- **TDD Phase**: RED — Tests correctly fail because sandbox checks are not yet implemented in the file tools
- **Test file**: `Tests/OpenAgentSDKTests/Tools/FilesystemSandboxTests.swift`

## Test Classes

1. `FileReadToolSandboxTests` — AC1 (3 tests)
2. `FileWriteToolSandboxTests` — AC2 (2 tests)
3. `FileEditToolSandboxTests` — AC3 (2 tests)
4. `GlobToolSandboxTests` — AC4 (2 tests)
5. `GrepToolSandboxTests` — AC5 (2 tests)
6. `SymlinkEscapeSandboxTests` — AC6 (1 test)
7. `PathTraversalSandboxTests` — AC7 (1 test)
8. `NoSandboxBackwardCompatTests` — AC8 (5 tests)
9. `SandboxCheckTimingTests` — AC9 (2 tests)
10. `DeniedPathsPrecedenceTests` — AC10 (2 tests)
11. `SandboxEdgeCaseTests` — Edge cases (4 tests)
