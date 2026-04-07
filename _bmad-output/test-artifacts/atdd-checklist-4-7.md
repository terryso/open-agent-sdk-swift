---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-07'
inputDocuments:
  - _bmad-output/implementation-artifacts/4-7-notebook-edit-tool.md
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift
  - Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift
  - Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift
  - Tests/OpenAgentSDKTests/Tools/Advanced/TeamToolsTests.swift
---

# ATDD Checklist: Story 4-7 -- NotebookEdit Tool

## TDD Red Phase (Current)

- [x] Failing tests generated
- [x] Tests compile (test file syntax is valid)
- [x] Tests fail at link time (feature not implemented)
- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] 64 compilation errors -- all referencing `createNotebookEditTool` not in scope

## Test Summary

| Metric | Value |
|--------|-------|
| Total test methods | 30 |
| TDD Phase | RED |
| All expected to fail | Yes |
| Compilation errors | 64 (all `createNotebookEditTool` not in scope) |

## Acceptance Criteria Coverage

| AC | Description | Test Methods | Priority | Status |
|----|-------------|-------------|----------|--------|
| AC1 | NotebookEdit -- replace mode | `testNotebookEdit_replace_source_updatesCell`, `testNotebookEdit_replace_withCellType_updatesType`, `testNotebookEdit_replace_preservesCellType`, `testNotebookEdit_replace_successMessage_format` | P0/P1 | Covered |
| AC2 | NotebookEdit -- insert mode | `testNotebookEdit_insert_codeCell_atHead`, `testNotebookEdit_insert_markdownCell`, `testNotebookEdit_insert_codeCell_hasOutputsAndExecutionCount`, `testNotebookEdit_insert_markdownCell_noOutputsFields`, `testNotebookEdit_insert_atEnd`, `testNotebookEdit_insert_defaultCellTypeIsCode` | P0/P1 | Covered |
| AC3 | NotebookEdit -- delete mode | `testNotebookEdit_delete_middleCell`, `testNotebookEdit_delete_firstCell`, `testNotebookEdit_delete_lastCell`, `testNotebookEdit_delete_onlyCell_leavesEmpty`, `testNotebookEdit_delete_successMessage_format` | P0/P1 | Covered |
| AC4 | Error handling -- invalid file/format | `testNotebookEdit_fileNotFound_returnsError`, `testNotebookEdit_invalidJSON_returnsError`, `testNotebookEdit_missingCellsKey_returnsError`, `testNotebookEdit_cellsNotArray_returnsError`, `testNotebookEdit_neverThrows_malformedInput`, `testNotebookEdit_invalidCommand_returnsError` | P0 | Covered |
| AC5 | Error handling -- out-of-bounds cell | `testNotebookEdit_replace_outOfBounds_returnsError`, `testNotebookEdit_delete_outOfBounds_returnsError`, `testNotebookEdit_replace_emptyNotebook_returnsError` | P0 | Covered |
| AC6 | inputSchema matches TS SDK | `testCreateNotebookEditTool_hasValidInputSchema` | P0 | Covered |
| AC7 | isReadOnly classification | `testCreateNotebookEditTool_isNotReadOnly`, `testNotebookEditTool_isReadOnly_false` | P0 | Covered |
| AC8 | Module boundary compliance | `testNotebookEditTool_moduleBoundary_noStoreRequired` | P1 | Covered |
| AC9 | File path resolution | `testNotebookEdit_relativePath_resolvesAgainstCwd` | P0 | Covered |
| AC10 | Notebook format preservation | `testNotebookEdit_sourceSplit_multiLine`, `testNotebookEdit_output_prettyPrinted` | P0 | Covered |

## Priority Breakdown

| Priority | Count | Tests |
|----------|-------|-------|
| P0 | 24 | Core factory, all three commands, error paths, schema, isReadOnly, path resolution, format |
| P1 | 6 | Preserves cell_type, markdown no outputs fields, boundary, success messages |

## Test File

- `Tests/OpenAgentSDKTests/Tools/Advanced/NotebookEditToolTests.swift`

## Implementation Requirements (for TDD Green Phase)

To make these tests pass, implement:

1. **New file**: `Sources/OpenAgentSDK/Tools/Advanced/NotebookEditTool.swift`
   - Define `NotebookEditInput` Codable struct (file_path, command, cell_number, cell_type?, source?, cell_id?)
   - Define `notebookEditSchema` input schema (nonisolated(unsafe))
   - Implement `createNotebookEditTool()` factory function using `defineTool` with `ToolExecuteResult` return
   - Handle three commands: insert, replace, delete
   - Use `resolvePath()` from FileReadTool for path resolution
   - All errors return `ToolExecuteResult(isError: true)`
   - Source split into `[String]` with trailing `\n` on all but last line
   - Code cells include `outputs: []` and `execution_count: null`
   - Markdown cells omit `outputs` and `execution_count`
   - JSON output uses `.prettyPrinted`

2. **Modify**: `Sources/OpenAgentSDK/OpenAgentSDK.swift`
   - Add re-export comment for `createNotebookEditTool`

## Validation Checklist

- [x] Prerequisites: Story 4-7 approved with clear acceptance criteria
- [x] Test framework: XCTest (Swift Package Manager)
- [x] Stack detected: backend (Swift)
- [x] Test file created: NotebookEditToolTests.swift
- [x] All 10 acceptance criteria have test coverage
- [x] Tests designed to fail before implementation (64 link errors confirmed)
- [x] No placeholder assertions (all tests assert meaningful behavior)
- [x] Test patterns match existing codebase (TeamToolsTests, factory function pattern)
- [x] Temp artifacts stored in _bmad-output/test-artifacts/

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Create `Sources/OpenAgentSDK/Tools/Advanced/NotebookEditTool.swift`
2. Update `Sources/OpenAgentSDK/OpenAgentSDK.swift` with re-export
3. Run `swift build --build-tests` to verify compilation
4. Run `swift test --filter NotebookEditToolTests` to verify all 30 tests pass
5. Commit passing tests
