---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-05'
inputDocuments:
  - _bmad-output/implementation-artifacts/3-5-core-search-tools-glob-grep.md
  - _bmad-output/planning-artifacts/english/epics.md
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/ToolRegistry.swift
  - Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift
  - Tests/OpenAgentSDKTests/Tools/Core/FileReadToolTests.swift
  - Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift
---

# ATDD Checklist: Story 3.5 -- Core Search Tools (Glob, Grep)

## TDD Red Phase (Current)

**Phase:** RED -- All tests assert expected behavior and will FAIL until implementation is complete.

- **Stack detected:** backend (Swift SPM, XCTest)
- **Generation mode:** AI generation (backend project, no browser recording needed)
- **Execution mode:** sequential

## Test Files Generated

| # | File | Tests | Level | TDD Phase |
|---|------|-------|-------|-----------|
| 1 | `Tests/OpenAgentSDKTests/Tools/Core/GlobToolTests.swift` | 10 | Unit | RED |
| 2 | `Tests/OpenAgentSDKTests/Tools/Core/GrepToolTests.swift` | 14 | Unit | RED |
| 3 | `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift` | +3 (updated) | Integration | RED |
| | **Total** | **27** | | |

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Names | Test Level |
|----|-------------|----------|------------|------------|
| AC1 | Glob matches files by pattern | P0 | `testGlob_matchesFilesByPattern` | Unit |
| AC2 | Glob supports custom search directory | P0 | `testGlob_withCustomPath_searchesInSpecifiedDir` | Unit |
| AC3 | Glob empty results return descriptive message | P0 | `testGlob_noMatches_returnsDescriptiveMessage` | Unit |
| AC4 | Grep searches file content with regex | P0 | `testGrep_searchesFileContent` | Unit |
| AC5 | Grep supports output modes | P0 | `testGrep_outputMode_filesWithMatches`, `testGrep_outputMode_content`, `testGrep_outputMode_count` | Unit |
| AC6 | Grep supports glob/type filters and path | P0 | `testGrep_globFilter`, `testGrep_typeFilter`, `testGrep_withCustomPath_searchesInSpecifiedDir` | Unit |
| AC7 | Glob/Grep registered in core tier | P0 | `testGetAllBaseTools_coreTier_includesGlobAndGrep`, `testGetAllBaseTools_coreTier_globGrepAreReadOnly` | Integration |
| AC8 | POSIX path resolution | P0 | `testGlob_relativePath_resolvesAgainstCwd`, `testGrep_relativePath_resolvesAgainstCwd` | Unit |

## Edge Cases and Error Scenarios

| Scenario | Test | Risk |
|----------|------|------|
| Non-existent directory (Glob) | `testGlob_nonExistentDirectory_returnsError` | P0 |
| Result limit 500 (Glob) | `testGlob_resultLimit_max500` | P1 |
| Nested directory patterns (Glob) | `testGlob_matchesNestedDirectories` | P0 |
| Sorting by modification time (Glob) | `testGlob_resultsSortedByModificationTime` | P1 |
| Case-insensitive search (Grep) | `testGrep_caseInsensitive` | P1 |
| Head limit truncation (Grep) | `testGrep_headLimit` | P1 |
| No matches (Grep) | `testGrep_noMatches_returnsDescriptiveMessage` | P0 |
| Invalid regex pattern (Grep) | `testGrep_invalidRegex_returnsError` | P0 |
| Context lines (Grep) | `testGrep_contextLines` | P1 |
| Binary file skip (Grep) | `testGrep_skipsBinaryFiles` | P1 |
| Hidden directory skip (Glob/Grep) | `testGlob_skipsHiddenDirectories`, `testGrep_skipsHiddenDirectories` | P1 |
| Glob schema has required fields | `testGlobTool_hasPatternInRequiredSchema` | P0 |
| Grep schema has required fields | `testGrepTool_hasPatternInRequiredSchema` | P0 |

## Test Strategy

- **Unit tests** for each tool's core behavior (Glob, Grep)
- **Integration tests** for ToolRegistry registration, schema validation, and isReadOnly properties
- All tests use temporary directories (`NSTemporaryDirectory`) with unique UUIDs
- Tests are self-contained and do not depend on external state
- Error paths verified via `ToolResult.isError` flag checks
- Pattern matching tested with realistic file hierarchies (nested dirs, multiple extensions)
- Pure Foundation implementation assumed (no external process calls)

## Implementation Endpoints

The following Swift source files need to be created/modified:

1. **Create** `Sources/OpenAgentSDK/Tools/Core/GlobTool.swift` -- `createGlobTool() -> ToolProtocol`
2. **Create** `Sources/OpenAgentSDK/Tools/Core/GrepTool.swift` -- `createGrepTool() -> ToolProtocol`
3. **Modify** `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` -- Update `getAllBaseTools(tier:)` to include `createGlobTool()` and `createGrepTool()` for `.core` tier

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify all tests PASS
3. If tests fail:
   - Fix implementation (feature bug), OR
   - Fix test (test bug)
4. Commit passing tests alongside implementation
