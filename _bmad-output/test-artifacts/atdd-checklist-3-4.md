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
  - _bmad-output/implementation-artifacts/3-4-core-file-tools-read-write-edit.md
  - _bmad-output/planning-artifacts/english/epics.md
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/ToolRegistry.swift
---

# ATDD Checklist: Story 3.4 — Core File Tools (Read, Write, Edit)

## TDD Red Phase (Current)

**Phase:** RED — All tests assert expected behavior and will FAIL until implementation is complete.

- **Stack detected:** backend (Swift SPM, XCTest)
- **Generation mode:** AI generation (backend project, no browser recording needed)
- **Execution mode:** sequential

## Test Files Generated

| # | File | Tests | Level | TDD Phase |
|---|------|-------|-------|-----------|
| 1 | `Tests/OpenAgentSDKTests/Tools/Core/FileReadToolTests.swift` | 12 | Unit | RED |
| 2 | `Tests/OpenAgentSDKTests/Tools/Core/FileWriteToolTests.swift` | 8 | Unit | RED |
| 3 | `Tests/OpenAgentSDKTests/Tools/Core/FileEditToolTests.swift` | 9 | Unit | RED |
| 4 | `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift` | 5 | Integration | RED |
| | **Total** | **34** | | |

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Names | Test Level |
|----|-------------|----------|------------|------------|
| AC1 | Read tool reads file content with line numbers | P0 | `testReadFile_returnsContentWithLineNumbers` | Unit |
| AC2 | Read handles directories | P0 | `testReadFile_directory_returnsError` | Unit |
| AC2 | Read handles image files | P1 | `testReadFile_imageFile_returnsDescription`, `testReadFile_jpgFile_returnsDescription` | Unit |
| AC3 | Read supports pagination (offset/limit) | P0 | `testReadFile_withOffsetAndLimit_returnsPartialContent` | Unit |
| AC3 | Read default limit is 2000 | P1 | `testReadFile_defaultLimit_2000` | Unit |
| AC4 | Write creates new files | P0 | `testWriteFile_createsNewFile` | Unit |
| AC4 | Write overwrites existing files | P0 | `testWriteFile_overwritesExistingFile` | Unit |
| AC4 | Write creates parent directories | P0 | `testWriteFile_createsParentDirectories` | Unit |
| AC5 | Edit replaces unique string | P0 | `testEditFile_replacesUniqueString`, `testEditFile_preservesSurroundingContent` | Unit |
| AC6 | Edit old_string not found returns error | P0 | `testEditFile_oldStringNotFound_returnsError` | Unit |
| AC6 | Edit multiple occurrences returns error | P0 | `testEditFile_multipleOccurrences_returnsError` | Unit |
| AC6 | Edit non-existent file returns error | P0 | `testEditFile_nonExistentFile_returnsError` | Unit |
| AC7 | POSIX path resolution (relative paths) | P0 | `testReadFile_relativePath_resolvesAgainstCwd`, `testWriteFile_relativePath_resolvesAgainstCwd`, `testEditFile_relativePath_resolvesAgainstCwd` | Unit |
| AC7 | Path with .. resolves correctly | P1 | `testReadFile_pathWithDotDot_resolvesCorrectly` | Unit |
| AC8 | Tools registered in core tier | P0 | `testGetAllBaseTools_coreTier_includesFileTools` | Integration |
| AC8 | Tools have correct schemas | P0 | `testGetAllBaseTools_coreTier_toolsHaveCorrectSchema` | Integration |
| AC8 | Read isReadOnly=true, Write/Edit isReadOnly=false | P0 | `testGetAllBaseTools_coreTier_readOnlyProperty` | Integration |
| AC8 | Tools convert to API format | P1 | `testGetAllBaseTools_coreTier_toApiToolsFormat` | Integration |

## Edge Cases and Error Scenarios

| Scenario | Test | Risk |
|----------|------|------|
| Non-existent file (Read) | `testReadFile_nonExistentFile_returnsError` | P0 |
| Directory path (Read) | `testReadFile_directory_returnsError` | P0 |
| Image/binary file (Read) | `testReadFile_imageFile_returnsDescription`, `testReadFile_jpgFile_returnsDescription` | P1 |
| Non-existent file (Edit) | `testEditFile_nonExistentFile_returnsError` | P0 |
| Multiple matches (Edit) | `testEditFile_multipleOccurrences_returnsError` | P0 |
| Invalid/unwritable path (Write) | `testWriteFile_invalidPath_returnsError` | P1 |
| Path with .. (Read) | `testReadFile_pathWithDotDot_resolvesCorrectly` | P1 |

## Test Strategy

- **Unit tests** for each tool's core behavior (Read, Write, Edit)
- **Integration tests** for ToolRegistry registration and schema validation
- All tests use temporary directories (`NSTemporaryDirectory`) with unique UUIDs
- Tests are self-contained and do not depend on external state
- Error paths verified via `ToolResult.isError` flag checks

## Implementation Endpoints

The following Swift source files need to be created/modified:

1. **Create** `Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift` — `createReadTool() -> ToolProtocol`
2. **Create** `Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift` — `createWriteTool() -> ToolProtocol`
3. **Create** `Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift` — `createEditTool() -> ToolProtocol`
4. **Modify** `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` — Update `getAllBaseTools(tier:)` to return file tools for `.core` tier

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify all tests PASS
3. If tests fail:
   - Fix implementation (feature bug), OR
   - Fix test (test bug)
4. Commit passing tests alongside implementation
