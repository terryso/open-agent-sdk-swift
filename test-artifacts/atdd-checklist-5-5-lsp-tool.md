---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-07'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-5-lsp-tool.md'
  - 'Sources/OpenAgentSDK/Tools/ToolBuilder.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/GrepTool.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/CronToolsTests.swift'
---

# ATDD Checklist - Epic 5, Story 5.5: LSP Tool

**Date:** 2026-04-07
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest with async tool execution via `await`)
**Detected Stack:** backend (Swift Package, XCTest)

---

## Story Summary

Implement LSP tool for code intelligence operations (go-to-definition, find-references, hover, symbol lookup) using grep-based fallback when no language server is running. The tool is stateless and read-only -- it does not require an Actor store, ToolContext modifications, or AgentOptions changes.

**As a** developer using the OpenAgentSDK
**I want** my Agent to interact with LSP-like code intelligence features
**So that** it can get definition locations, references, and symbol information

---

## Acceptance Criteria

1. **AC1: LSP Tool Registration** -- Given LSP tool is registered, when LLM lists available tools, then sees a tool named "LSP" with description "Language Server Protocol operations for code intelligence" supporting operations: goToDefinition, findReferences, hover, documentSymbol, workspaceSymbol, goToImplementation, prepareCallHierarchy, incomingCalls, outgoingCalls (FR18).
2. **AC2: goToDefinition Operation** -- Given LSP tool and valid file_path + line + character, when LLM requests goToDefinition, then extracts symbol at cursor position, uses grep to search for definition, returns matches or "No definition found for {symbol}" (FR18).
3. **AC3: findReferences Operation** -- Given LSP tool and valid file_path + line + character, when LLM requests findReferences, then extracts symbol at cursor position, uses grep to search for all references (max 50 lines), returns matches or "No references found for {symbol}" (FR18).
4. **AC4: hover Operation** -- Given LSP tool, when LLM requests hover, then returns a hint message explaining a running language server is needed, suggesting to use the Read tool instead (FR18).
5. **AC5: documentSymbol Operation** -- Given LSP tool and valid file_path, when LLM requests documentSymbol, then uses grep to search for function, class, interface, type, const declarations in the file, returns matching symbols or "No symbols found" (FR18).
6. **AC6: workspaceSymbol Operation** -- Given LSP tool and valid query, when LLM requests workspaceSymbol, then uses grep to search the workspace for matching symbols (max 30 lines), returns matches or "No symbols found for {query}" (FR18).
7. **AC7: Unknown Operation Error** -- Given LSP tool and an unknown operation value (e.g., prepareCallHierarchy, incomingCalls, outgoingCalls), when LLM requests that operation, then returns hint "LSP operation {operation} requires a running language server." (FR18).
8. **AC8: Parameter Missing Error** -- Given LSP tool, when LLM requests an operation requiring file_path + line but parameters are missing, then returns is_error=true ToolResult indicating required parameters. workspaceSymbol missing query also returns an error.
9. **AC9: isReadOnly Classification** -- Given LSP tool, when checking isReadOnly property, then returns true (all operations are read-only queries that don't modify any state).
10. **AC10: inputSchema Matches TS SDK** -- Given TS SDK's LSP tool schema (lsp-tool.ts), when checking Swift side inputSchema, then field names, types, and required list match. operation (string, required, enum), file_path (string, optional), line (number, optional), character (number, optional), query (string, optional).
11. **AC11: Module Boundary Compliance** -- Given LSPTool in Tools/Specialist/, when checking import statements, then only imports Foundation and Types/, never imports Core/, Stores/, or other modules (architecture rules #7, #40).
12. **AC12: Error Handling Doesn't Break Loop** -- Given an exception occurs during LSP tool execution (e.g., Process execution failure, file not found), when error is caught, then returns is_error=true ToolResult, doesn't interrupt the Agent's intelligence loop (architecture rule #38).
13. **AC13: Cross-platform Process Execution** -- Given LSP tool uses Process to execute grep commands, when running on macOS and Linux, then uses Foundation's Process class (consistent with BashTool cross-platform pattern, rule #43).
14. **AC14: Symbol Extraction Helper** -- Given valid file path, line number, and character position, when calling getSymbolAtPosition helper function, then extracts the word at cursor position from file content (using \b\w+\b regex), returns symbol string or nil.
15. **AC15: Working Directory Uses cwd** -- Given LSP tool obtains working directory via ToolContext.cwd, when executing grep searches, then uses cwd as the base directory for search scope (consistent with TS SDK using context.cwd).
16. **AC16: No Actor Store Needed** -- Given LSP tool is a stateless read-only query tool, when implementing, then no new Actor store class is needed, no ToolContext or AgentOptions modifications required.
17. **AC17: ToolContext.cwd Dependency** -- Given LSP tool obtains current working directory via context.cwd, when tool executes, then uses cwd as the starting directory for grep searches and file path resolution.

---

## Test Strategy

**Stack:** Backend (Swift) -- XCTest framework

**Test Levels:**
- **Unit** (primary): LSPTool factory function, input schema, isReadOnly, operation behaviors
- **Helper function validation** (supplementary): getSymbolAtPosition, runGrep Process execution

**Execution Mode:** Sequential (single agent, backend-only project, yolo mode)

---

## Generation Mode

**Mode:** AI Generation
**Reason:** Backend Swift project with XCTest. No browser UI. Acceptance criteria are clear with well-defined tool operation patterns. All scenarios are unit tests for a stateless tool.

---

## Failing Tests Created (RED Phase)

### LSPTool Tests (35 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

#### AC1: LSP Tool Registration
- **Test:** `testCreateLSPTool_returnsToolProtocol`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC1 -- factory returns ToolProtocol with name "LSP"
  - **Priority:** P0

- **Test:** `testCreateLSPTool_descriptionMentionsCodeIntelligence`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC1 -- description mentions "Language Server Protocol" or "code intelligence"
  - **Priority:** P0

#### AC9: isReadOnly Classification
- **Test:** `testCreateLSPTool_isReadOnly_returnsTrue`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC9 -- isReadOnly is true
  - **Priority:** P0

#### AC10: inputSchema Matches TS SDK
- **Test:** `testCreateLSPTool_inputSchema_hasCorrectType`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- schema type is "object"
  - **Priority:** P0

- **Test:** `testCreateLSPTool_inputSchema_operationIsRequired`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- operation is in required array
  - **Priority:** P0

- **Test:** `testCreateLSPTool_inputSchema_operationEnum_hasAllNineValues`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- operation enum contains all 9 values
  - **Priority:** P0

- **Test:** `testCreateLSPTool_inputSchema_hasOptionalFilePath`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- file_path is string, optional
  - **Priority:** P0

- **Test:** `testCreateLSPTool_inputSchema_hasOptionalLine`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- line is number, optional
  - **Priority:** P0

- **Test:** `testCreateLSPTool_inputSchema_hasOptionalCharacter`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- character is number, optional
  - **Priority:** P0

- **Test:** `testCreateLSPTool_inputSchema_hasOptionalQuery`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC10 -- query is string, optional
  - **Priority:** P0

#### AC2: goToDefinition Operation
- **Test:** `testGoToDefinition_missingFilePath_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- file_path missing returns is_error=true
  - **Priority:** P0

- **Test:** `testGoToDefinition_missingLine_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- line missing returns is_error=true
  - **Priority:** P0

- **Test:** `testGoToDefinition_withSymbolAtPosition_returnsGrepResults`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC2 -- extracts symbol, runs grep, returns results
  - **Priority:** P0

- **Test:** `testGoToDefinition_noSymbolAtPosition_returnsNotFound`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC2 -- no symbol found returns appropriate message
  - **Priority:** P1

#### AC2/AC10: goToImplementation (same logic as goToDefinition)
- **Test:** `testGoToImplementation_missingFilePath_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- file_path missing returns is_error=true
  - **Priority:** P0

- **Test:** `testGoToImplementation_withSymbol_returnsGrepResults`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC2 -- extracts symbol, runs grep, returns results
  - **Priority:** P0

#### AC3: findReferences Operation
- **Test:** `testFindReferences_missingFilePath_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- file_path missing returns is_error=true
  - **Priority:** P0

- **Test:** `testFindReferences_missingLine_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- line missing returns is_error=true
  - **Priority:** P0

- **Test:** `testFindReferences_withSymbol_returnsReferences`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC3 -- extracts symbol, runs grep, returns references
  - **Priority:** P0

- **Test:** `testFindReferences_noSymbol_returnsNoReferences`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC3 -- no symbol found returns "No references found"
  - **Priority:** P1

#### AC4: hover Operation
- **Test:** `testHover_returnsHintMessage`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC4 -- returns hint about language server
  - **Priority:** P0

- **Test:** `testHover_doesNotRequireParameters`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC4 -- hover works without any parameters
  - **Priority:** P0

#### AC5: documentSymbol Operation
- **Test:** `testDocumentSymbol_missingFilePath_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- file_path missing returns is_error=true
  - **Priority:** P0

- **Test:** `testDocumentSymbol_withFilePath_returnsSymbols`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC5 -- returns symbol declarations from file
  - **Priority:** P0

- **Test:** `testDocumentSymbol_noSymbols_returnsNoSymbolsFound`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC5 -- no symbols found returns appropriate message
  - **Priority:** P1

#### AC6: workspaceSymbol Operation
- **Test:** `testWorkspaceSymbol_missingQuery_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC8 -- query missing returns is_error=true
  - **Priority:** P0

- **Test:** `testWorkspaceSymbol_withQuery_returnsResults`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC6 -- returns matching symbols from workspace
  - **Priority:** P0

- **Test:** `testWorkspaceSymbol_noMatches_returnsNoSymbolsFound`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC6 -- no matches returns "No symbols found for {query}"
  - **Priority:** P1

#### AC7: Unknown Operation Error
- **Test:** `testUnknownOperation_prepareCallHierarchy_returnsLanguageServerHint`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC7 -- prepareCallHierarchy returns language server hint
  - **Priority:** P0

- **Test:** `testUnknownOperation_incomingCalls_returnsLanguageServerHint`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC7 -- incomingCalls returns language server hint
  - **Priority:** P0

- **Test:** `testUnknownOperation_outgoingCalls_returnsLanguageServerHint`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC7 -- outgoingCalls returns language server hint
  - **Priority:** P0

- **Test:** `testUnknownOperation_completelyUnknown_returnsLanguageServerHint`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC7 -- unknown operation name returns language server hint
  - **Priority:** P0

#### AC12: Error Handling
- **Test:** `testLSPTool_neverThrows_malformedInput`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC12 -- tool never throws, always returns ToolResult
  - **Priority:** P0

- **Test:** `testLSPTool_nonExistentFile_returnsError`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC12 -- non-existent file returns is_error=true
  - **Priority:** P0

#### AC16: No Actor Store Needed
- **Test:** `testLSPTool_doesNotRequireStoreInContext`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC16 -- tool works with basic ToolContext (no store)
  - **Priority:** P0

#### AC15/AC17: Working Directory Uses cwd
- **Test:** `testLSPTool_usesCwdFromContext`
  - **Status:** RED - `createLSPTool()` does not exist yet
  - **Verifies:** AC15, AC17 -- tool uses context.cwd as search base
  - **Priority:** P0

---

## Implementation Checklist

### Test: testCreateLSPTool_returnsToolProtocol through testCreateLSPTool_isReadOnly_returnsTrue

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Create `Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift`
- [ ] Define `private struct LSPInput: Codable` with operation, file_path, line, character, query fields
- [ ] Define `private nonisolated(unsafe) let lspSchema: ToolInputSchema` with correct schema
- [ ] Implement `public func createLSPTool() -> ToolProtocol` using `defineTool`
- [ ] Set name: "LSP", description mentions code intelligence, isReadOnly: true
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testCreateLSPTool_inputSchema_* (schema validation tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Ensure lspSchema matches TS SDK schema exactly
- [ ] operation: string, required, enum with 9 values
- [ ] file_path: string, optional
- [ ] line: number, optional
- [ ] character: number, optional
- [ ] query: string, optional
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testGoToDefinition_* and testGoToImplementation_* (AC2)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement `getSymbolAtPosition(filePath:line:character:)` helper
- [ ] Implement goToDefinition/goToImplementation case in tool call handler
- [ ] Validate file_path and line are present, return error if missing
- [ ] Extract symbol at position, run grep for definition keywords
- [ ] Return results or "No definition found for {symbol}"
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 1 hour

---

### Test: testFindReferences_* (AC3)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement findReferences case in tool call handler
- [ ] Validate file_path and line, extract symbol
- [ ] Run grep for references (max 50 lines)
- [ ] Return results or "No references found for {symbol}"
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testHover_* (AC4)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement hover case -- return hint message
- [ ] No parameters required
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.1 hours

---

### Test: testDocumentSymbol_* (AC5)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement documentSymbol case
- [ ] Validate file_path, return error if missing
- [ ] Run grep for declarations in the specified file
- [ ] Return results or "No symbols found"
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testWorkspaceSymbol_* (AC6)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement workspaceSymbol case
- [ ] Validate query, return error if missing
- [ ] Run grep in workspace for matching symbols (max 30 lines)
- [ ] Return results or "No symbols found for {query}"
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: testUnknownOperation_* (AC7)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Implement default case in switch for unknown operations
- [ ] Return "LSP operation \"{operation}\" requires a running language server."
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.1 hours

---

### Test: testLSPTool_neverThrows_malformedInput (AC12)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`

**Tasks to make these tests pass:**

- [ ] Ensure outer do/catch wraps all operation logic
- [ ] Catch returns ToolExecuteResult with isError: true
- [ ] Run tests: `swift test --filter LSPToolTests`
- [ ] Tests pass (green phase)

**Estimated Effort:** 0.25 hours

---

### Module Boundary (AC11)

- [ ] Verify `LSPTool.swift` only imports Foundation
- [ ] Verify `LSPTool.swift` does not import Core/ or Stores/
- [ ] Update `OpenAgentSDK.swift` with `createLSPTool` documentation reference

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter LSPToolTests

# Run full test suite
swift test

# Build without running
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- [x] All tests written and failing (createLSPTool does not exist)
- [x] No mock requirements needed (tool operates on real files via Process/grep)
- [x] Implementation checklist created
- [x] Test patterns follow existing Specialist tool conventions (CronToolsTests)

**Verification:**

- All tests will fail to compile because `createLSPTool()` does not exist
- Failure is clear: "cannot find 'createLSPTool' in scope" etc.
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1:** Create LSPTool.swift with LSPInput struct, lspSchema, and createLSPTool() factory
2. **Implement symbol extraction** -- getSymbolAtPosition helper function
3. **Implement Process execution** -- runGrep helper function (reference BashTool)
4. **Implement each operation** -- goToDefinition, findReferences, hover, documentSymbol, workspaceSymbol, default
5. **Update OpenAgentSDK.swift** with createLSPTool documentation reference
6. **Run tests** after each implementation step
7. **Verify module boundaries** (no Core/ or Stores/ imports)

**Key Principles:**

- One operation at a time (start with schema/factory, then hover, then grep-based operations)
- Minimal implementation (follow story dev notes skeleton code)
- Run tests frequently (immediate feedback)
- Use implementation checklist as roadmap
- Reference GrepTool for file reading patterns and BashTool for Process execution

---

### REFACTOR Phase (After All Tests Pass)

1. Verify all tests pass (green phase complete)
2. Check that Tools/Specialist/LSPTool.swift only imports Foundation
3. Review error handling completeness
4. Ensure tests still pass after each refactor
5. No force unwraps, no unnecessary dependencies

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter LSPToolTests`

**Expected Results:**

```
error: cannot find 'createLSPTool' in scope
```

**Summary:**

- Total new tests: 35
  - LSPToolTests: 35 tests
- Passing: 0 (expected)
- Failing: 35 (expected -- compile error, factory function does not exist)
- Status: RED phase verified

---

## Notes

- LSPTool is stateless: no Actor store, no ToolContext modifications, no AgentOptions changes
- Tool uses Process to execute grep commands (cross-platform via /usr/bin/env)
- Tests create temporary files for file-based operations (documentSymbol, goToDefinition)
- getSymbolAtPosition uses \b\w+\b regex to extract word at cursor position
- runGrep has 10-second timeout (consistent with TS SDK)
- Test naming: `test{MethodName}_{scenario}_{expectedBehavior}`
- No real network calls -- pure unit tests against tool operations
- isReadOnly: true for all operations (consistent with TS SDK)
- Test patterns mirror CronToolsTests and existing Specialist tool tests

---

**Generated by BMad TEA Agent** - 2026-04-07
