# Story 16.2: Tool System Compatibility Verification

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an SDK developer,
I want to verify the Swift SDK's tool definition and execution is fully compatible with the TypeScript SDK's tool system,
so that all TypeScript SDK tool usage patterns can be implemented in Swift.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/CompatToolSystem/` directory and `CompatToolSystem` executable target in Package.swift, `swift build` compiles with zero errors and zero warnings.

2. **AC2: defineTool equivalence** -- Given TS SDK's `tool(name, description, inputSchema, handler, { annotations })`, Swift SDK's `defineTool()` supports equivalent parameters: name, description, inputSchema (JSON Schema dict), execution closure. Verify all four `defineTool` overloads: Codable Input + String return, Codable Input + ToolExecuteResult return, No-Input convenience, Raw Dictionary Input.

3. **AC3: ToolAnnotations compatibility** -- Verify whether Swift SDK has an equivalent to TS SDK's `ToolAnnotations` with fields: `readOnlyHint` (Swift: `isReadOnly`), `destructiveHint`, `idempotentHint`, `openWorldHint`. If missing, record as compatibility gap with recommended addition.

4. **AC4: ToolResult structure compatibility** -- Verify Swift SDK's `ToolResult` vs TS SDK's `CallToolResult`: TS has `content` array (text/image resource types), Swift has `content: String`. Document the structural difference and whether typed content arrays are supported.

5. **AC5: Built-in tool input schema validation** -- Check Swift SDK built-in tool inputSchemas against TS SDK `ToolInputSchemas` field names and types for at least: BashInput (`command`, `timeout`; TS also has `description`, `run_in_background`), FileReadInput (`file_path`, `offset`, `limit`), FileEditInput (`file_path`, `old_string`, `new_string`, `replace_all`), GlobInput (`pattern`, `path`), GrepInput (`pattern`, `path`, `glob`, `output_mode`, `-i`, `head_limit`, `-C`, `-A`, `-B`).

6. **AC6: Built-in tool output structure validation** -- Check Swift SDK tool output vs TS SDK `ToolOutputSchemas`: ReadOutput type discrimination (text/image/pdf/notebook), EditOutput (structuredPatch info), BashOutput (stdout/stderr separation, backgroundTaskId). Note: Swift tools return `String` content, not structured output objects.

7. **AC7: InProcessMCPServer equivalence** -- Verify Swift SDK's `InProcessMCPServer(name:version:tools:cwd:)` matches TS SDK's `createSdkMcpServer({ name, version, tools })` pattern. Verify `createSession()`, `getTools()`, and `asConfig()` methods.

8. **AC8: Compatibility report output** -- Example outputs a standardized compatibility report listing `[PASS]` / `[MISSING]` / `[N/A]` status for each verification point, with field-level mapping table.

## Tasks / Subtasks

- [x] Task 1: Create example directory and scaffold (AC: #1)
  - [x] Create `Examples/CompatToolSystem/main.swift`
  - [x] Add `CompatToolSystem` executable target to `Package.swift`
  - [x] Verify `swift build` passes with no errors/warnings

- [x] Task 2: Custom tool definition verification (AC: #2)
  - [x] Use `defineTool()` Codable overload to create a custom tool with JSON Schema input
  - [x] Use `defineTool()` No-Input overload for a parameterless tool
  - [x] Use `defineTool()` Raw Dictionary overload for dynamic input
  - [x] Use `defineTool()` ToolExecuteResult overload for explicit error signaling
  - [x] Verify each overload compiles and creates a valid `ToolProtocol`

- [x] Task 3: ToolAnnotations / isReadOnly gap analysis (AC: #3)
  - [x] Check if `ToolAnnotations` type exists in Swift SDK (grep for it)
  - [x] Verify `ToolProtocol.isReadOnly` property as equivalent to `readOnlyHint`
  - [x] Document missing: `destructiveHint`, `idempotentHint`, `openWorldHint`
  - [x] Record recommended additions for future implementation

- [x] Task 4: ToolResult structure comparison (AC: #4)
  - [x] Inspect `ToolResult` struct (ToolTypes.swift): `toolUseId`, `content: String`, `isError`
  - [x] Compare against TS SDK `CallToolResult`: `content: Array<TextBlock | ImageBlock>`, `isError`
  - [x] Document: Swift uses flat `String` content, TS uses typed content array
  - [x] Note: `ToolExecuteResult` mirrors this with `content: String` + `isError: Bool`

- [x] Task 5: Built-in tool input schema validation (AC: #5)
  - [x] Get each built-in tool's inputSchema from `getAllBaseTools(tier: .core)`
  - [x] Compare BashInput fields against TS SDK: `command` (PASS), `timeout` (PASS), `description` (MISSING), `run_in_background` (MISSING)
  - [x] Compare FileReadInput: `file_path` (PASS), `offset` (PASS), `limit` (PASS)
  - [x] Compare FileEditInput: `file_path` (PASS), `old_string` (PASS), `new_string` (PASS), `replace_all` (PASS)
  - [x] Compare GlobInput: `pattern` (PASS), `path` (PASS)
  - [x] Compare GrepInput: `pattern` (PASS), `path` (PASS), `glob` (PASS), `output_mode` (PASS), `-i` (PASS), `head_limit` (PASS), `-C` (PASS), `-A` (PASS), `-B` (PASS)
  - [x] Compare FileWriteInput: `file_path` (PASS), `content` (PASS)

- [x] Task 6: Built-in tool output structure validation (AC: #6)
  - [x] Execute Read tool and check output: cat-n formatted text (no typed content discrimination)
  - [x] Execute Edit tool and check output: success/failure message (no structuredPatch)
  - [x] Execute Bash tool and check output: stdout+stderr combined (not separated)
  - [x] Document: Swift tools return flat String, not typed output objects like TS SDK

- [x] Task 7: InProcessMCPServer equivalence (AC: #7)
  - [x] Create `InProcessMCPServer(name: "test", version: "1.0", tools: [customTool])`
  - [x] Call `server.getTools()` and verify tools are accessible
  - [x] Call `server.asConfig()` and verify it returns `McpServerConfig.sdk`
  - [x] Compare against TS SDK `createSdkMcpServer({ name, version, tools })` pattern

- [x] Task 8: Generate compatibility report (AC: #8)
  - [x] Output standardized report with PASS/MISSING/N/A per field
  - [x] Include summary: pass count, missing count, pass rate
  - [x] Include recommended actions for MISSING items

## Dev Notes

### Position in Epic and Project

- **Epic 16** (TypeScript SDK Compatibility Verification), second story
- **Prerequisites:** Epic 1-3 (Agent creation, streaming, tool system) are complete; Story 16-1 done
- **This is a pure verification example story** -- no new production code, only example creation and compatibility report

### Critical API Mapping Table

| TypeScript SDK | Swift SDK | Source File | Gap? |
|---|---|---|---|
| `tool(name, desc, schema, handler, { annotations })` | `defineTool(name:description:inputSchema:execute:)` | `Tools/ToolBuilder.swift:27` | No annotations param |
| `ToolAnnotations { readOnlyHint, destructiveHint, idempotentHint, openWorldHint }` | `ToolProtocol.isReadOnly: Bool` only | `Types/ToolTypes.swift:11` | MISSING 3 fields |
| `CallToolResult { content: Array, isError }` | `ToolResult { toolUseId, content: String, isError }` | `Types/ToolTypes.swift:17` | Content is String not array |
| `createSdkMcpServer({ name, version, tools })` | `InProcessMCPServer(name:version:tools:cwd:)` | `Tools/MCP/InProcessMCPServer.swift:46` | cwd extra param (OK) |
| 20 ToolInputSchemas | 10 core tool inputSchemas | `Tools/Core/*.swift` | See Task 5 |
| 18 ToolOutputSchemas | Flat String output | All tools return `String` | Structured output missing |

### Known Gaps to Investigate

1. **ToolAnnotations missing** -- Swift SDK has NO `ToolAnnotations` type. The `ToolProtocol.isReadOnly` property is the only annotation equivalent. Missing: `destructiveHint`, `idempotentHint`, `openWorldHint`. TS SDK uses these for permission gating. Record as `[MISSING]` with recommendation to add `ToolAnnotations` struct.

2. **ToolResult.content is String, not typed array** -- TS SDK's `CallToolResult.content` is an array of `TextBlock | ImageBlock | ResourceBlock`. Swift's `ToolResult.content` is a flat `String`. This means Swift tools cannot return structured multi-part content (text + image). Record as `[MISSING]` with recommendation to add typed content support.

3. **BashInput missing fields** -- TS SDK Bash tool has `description` and `run_in_background` fields. Swift `BashInput` now has `command`, `timeout`, and `description`. Only `run_in_background` remains `[MISSING]`.

4. **No structured output** -- TS SDK tools return typed output objects (ReadOutput with type discrimination, EditOutput with structuredPatch, BashOutput with separated stdout/stderr). Swift tools all return flat `String`. Record as architectural difference.

5. **Tool registration pattern** -- TS SDK's `tool()` returns a tool definition that can be passed to `createSdkMcpServer()`. Swift's `defineTool()` returns `ToolProtocol` which can be passed to `InProcessMCPServer`. This pattern IS compatible.

### Architecture Compliance

- **Module boundaries:** Example code imports only `OpenAgentSDK` (public API). No internal imports.
- **Actor patterns:** `InProcessMCPServer` is an actor -- use `await` for all method calls.
- **ToolProtocol:** Protocol requires `name`, `description`, `inputSchema`, `isReadOnly`, and `call(input:context:)`.
- **JSON/Codable boundary:** `defineTool()` handles JSON-to-Codable bridging automatically.
- **Naming conventions:** PascalCase for types, camelCase for variables.
- **Testing standards:** This is an example, not a test. Follow project example patterns.

### Patterns to Follow

- Use `loadDotEnv()` / `getEnv()` for API key loading (see `Examples/CompatCoreQuery/main.swift`)
- Use `createAgent(options:)` factory function
- Use `permissionMode: .bypassPermissions` to simplify example (no interactive prompts)
- Add bilingual (EN + Chinese) comment header
- Use `CompatEntry` struct and `record()` function pattern from CompatCoreQuery for report generation
- Use `nonisolated(unsafe)` for mutable global report state

### File Locations

```
Examples/CompatToolSystem/
  main.swift                     # NEW - compatibility verification example
Package.swift                    # MODIFY - add CompatToolSystem executable target
```

### Source Files to Reference (read-only, no modifications)

- `Sources/OpenAgentSDK/Tools/ToolBuilder.swift` -- defineTool() factory functions (4 overloads)
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolProtocol, ToolResult, ToolExecuteResult, ToolContext
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` -- getAllBaseTools(), toApiTool(), assembleToolPool()
- `Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift` -- InProcessMCPServer actor
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- BashInput (command, timeout)
- `Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift` -- FileReadInput (file_path, offset, limit)
- `Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift` -- FileEditInput (file_path, old_string, new_string, replace_all)
- `Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift` -- FileWriteInput (file_path, content)
- `Sources/OpenAgentSDK/Tools/Core/GlobTool.swift` -- GlobInput (pattern, path)
- `Sources/OpenAgentSDK/Tools/Core/GrepTool.swift` -- GrepInput (pattern, path, glob, output_mode, -i, head_limit, -C, -A, -B)
- `Examples/CompatCoreQuery/main.swift` -- Reference pattern for compat report generation

### Previous Story Intelligence (16-1)

- Story 16-1 completed successfully with all ACs satisfied
- CompatCoreQuery example established the `CompatEntry` / `record()` pattern for reports
- Known gaps from 16-1: SystemData missing session_id/tools/model; errors/structuredOutput/permissionDenials/durationApiMs missing from ResultData
- Full test suite was 3403 tests passing at time of 16-1 completion
- Example pattern: bilingual comments, `loadDotEnv()`, `createAgent()`, `permissionMode: .bypassPermissions`
- Package.swift already has `CompatCoreQuery` target -- add `CompatToolSystem` following the same pattern

### Git Intelligence

Recent commits show Epic 16 work started with 16-1 implementation. The `feat: add Epic 16 TS SDK compat layer` commit added all story specs and the CompatCoreQuery example. Build and test patterns are established.

### References

- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] -- defineTool() with 4 overloads
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] -- ToolProtocol, ToolResult, ToolExecuteResult
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] -- getAllBaseTools(), assembleToolPool()
- [Source: Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift] -- InProcessMCPServer actor
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] -- BashInput schema
- [Source: Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift] -- FileReadInput schema
- [Source: Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift] -- FileEditInput schema
- [Source: _bmad-output/planning-artifacts/epics.md#Epic16] -- Story 16.2 definition and compatibility matrix
- [Source: _bmad-output/implementation-artifacts/16-1-core-query-api-compat.md] -- Previous story patterns and learnings
- [TS SDK Reference] tool(), createSdkMcpServer(), ToolInputSchemas, ToolOutputSchemas, ToolAnnotations

## Dev Agent Record

### Agent Model Used

Claude (claude-sonnet-4-6)

### Debug Log References

- swift build --target CompatToolSystem: 0 errors, 0 warnings
- swift test --filter CompatToolSystemTests: 36/36 tests passing
- swift test (full suite): 3183 tests, 0 failures, 14 skipped

### Completion Notes List

- Task 1: Created `Examples/CompatToolSystem/main.swift` and added executable target to Package.swift. Build passes with zero errors and zero warnings.
- Task 2: All four `defineTool()` overloads verified in example: Codable+String, Codable+ToolExecuteResult, No-Input convenience, Raw Dictionary. Each creates a valid `ToolProtocol` and executes correctly.
- Task 3: Confirmed `ToolAnnotations` type does not exist in Swift SDK. `ToolProtocol.isReadOnly` is the sole equivalent to TS `readOnlyHint`. Missing: `destructiveHint`, `idempotentHint`, `openWorldHint`. Documented as compatibility gaps.
- Task 4: `ToolResult` has `toolUseId: String`, `content: String`, `isError: Bool`. Documented: content is flat String vs TS typed content array. `ToolExecuteResult` mirrors with `content: String` + `isError: Bool`.
- Task 5: All core tool input schemas validated. BashInput: command+timeout+description PASS, run_in_background MISSING. FileReadInput: all 3 fields PASS. FileEditInput: all 4 fields PASS. FileWriteInput: both fields PASS. GlobInput: both fields PASS. GrepInput: all 9 fields PASS. Core tool count: 10.
- Task 6: Read output is cat-n formatted String (not typed). Edit output is success message String (no structuredPatch). Bash output combines stdout+stderr (no separation). All documented as architectural differences.
- Task 7: InProcessMCPServer matches createSdkMcpServer pattern. getTools(), asConfig(), createSession() all verified working.
- Task 8: Compatibility report generated with PASS/MISSING/N/A per field, summary counts, pass rate, and recommended actions.
- Fixed SourceKit warnings: removed always-true `as? [String: Any]` casts in both example and test file helpers.
- Fixed SourceKit error at line 226: replaced unused `struct Input: Codable { let placeholder: String? }` with no-input `defineTool` overload that doesn't need a Codable struct.

### Change Log

- 2026-04-15: Implemented all 8 tasks. Created CompatToolSystem example, fixed test file SourceKit warnings/errors, all 36 ATDD tests passing.

### File List

- Examples/CompatToolSystem/main.swift (NEW)
- Package.swift (MODIFIED - added CompatToolSystem executable target)
- Tests/OpenAgentSDKTests/Compat/CompatToolSystemTests.swift (MODIFIED - fixed always-true cast warnings and unused Codable struct)
