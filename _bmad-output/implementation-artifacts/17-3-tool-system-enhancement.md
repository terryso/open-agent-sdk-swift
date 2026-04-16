# Story 17.3: Tool System Enhancement / 工具系统增强

Status: review

## Story

As an SDK developer,
I want to fill in the missing `ToolAnnotations`, typed `ToolResult` content array, and `BashInput.run_in_background` in the Swift SDK tool system,
so that the Swift SDK achieves feature parity with the TypeScript SDK tool system.

## Acceptance Criteria

1. **AC1: ToolAnnotations type** -- Given the TS SDK has `ToolAnnotations` with 4 hint fields, when adding `ToolAnnotations` struct to Swift SDK, then it contains `readOnlyHint: Bool`, `destructiveHint: Bool`, `idempotentHint: Bool`, `openWorldHint: Bool`, and `ToolProtocol` gains an optional `annotations: ToolAnnotations?` property, and `defineTool()` supports an `annotations` parameter.

2. **AC2: Typed ToolResult content** -- Given TS SDK's `CallToolResult.content` is a typed array, when extending Swift SDK's `ToolResult.content`, then it supports a `ToolContent` type array (`.text(String)`, `.image(data:mimeType:)`, `.resource(uri:name:)`), and the existing `content: String` property remains backward-compatible via a convenience computed property, and `ToolExecuteResult` syncs with typed content support.

3. **AC3: BashInput.run_in_background** -- Given TS SDK's BashInput has a `run_in_background` field, when adding it to Swift's BashInput, then `runInBackground: Bool?` allows commands to execute in the background, and background execution returns a `backgroundTaskId` for subsequent management.

4. **AC4: Build and test** -- `swift build` zero errors zero warnings, existing test suite passes with zero regression.

## Tasks / Subtasks

- [x] Task 1: ToolAnnotations type (AC: #1)
  - [x] Create `ToolAnnotations` struct in `Types/ToolTypes.swift` with 4 Bool fields (all with default `false` values)
  - [x] Add `annotations: ToolAnnotations?` optional property to `ToolProtocol`
  - [x] Provide a default implementation returning `nil` for `annotations` (protocol extension)
  - [x] Add `annotations` parameter to all `defineTool()` overloads in `Tools/ToolBuilder.swift`
  - [x] Pass `annotations` to Anthropic API `tools` array in `toApiTool()` when non-nil
  - [x] Ensure `ToolAnnotations` conforms to `Sendable` and `Equatable`

- [x] Task 2: Typed ToolResult content (AC: #2)
  - [x] Create `ToolContent` enum with cases: `.text(String)`, `.image(data: Data, mimeType: String)`, `.resource(uri: String, name: String?)`
  - [x] Add `typedContent: [ToolContent]?` optional property to `ToolResult`
  - [x] Add backward-compatible `content` property that derives from `typedContent` when available (concatenates `.text` items), falls back to stored string
  - [x] Add `typedContent: [ToolContent]?` to `ToolExecuteResult`
  - [x] Add `ToolExecuteResult` init that accepts `[ToolContent]`
  - [x] Ensure `ToolContent` conforms to `Sendable` and `Equatable`
  - [x] Keep existing `ToolResult.init(toolUseId:content:isError:)` working (backward compatible)

- [x] Task 3: BashInput.run_in_background (AC: #3)
  - [x] Add `runInBackground: Bool?` to `BashInput` struct in `Tools/Core/BashTool.swift`
  - [x] Add `"run_in_background"` to Bash tool's `inputSchema`
  - [x] When `runInBackground == true`, launch process and return `backgroundTaskId` immediately
  - [x] Implement background task tracking (dictionary of running processes)
  - [x] Return result format: `"Background task started with ID: <taskId>"`
  - [x] Handle cleanup of background processes on agent deallocation

- [x] Task 4: Update API tool serialization (AC: #1, #2)
  - [x] Update `toApiTool()` in `ToolRegistry.swift` to include `annotations` in API tool dict when present
  - [x] Verify typed content round-trips correctly through tool execution pipeline

- [x] Task 5: Validation and tests (AC: #4)
  - [x] `swift build` zero errors zero warnings
  - [x] All existing tests pass with zero regression
  - [x] Unit tests for `ToolAnnotations` (init, default values, Sendable, Equatable)
  - [x] Unit tests for `ToolContent` enum (all 3 cases, Sendable, Equatable)
  - [x] Unit tests for `ToolResult` with typed content (backward compat, convenience property)
  - [x] Unit tests for `defineTool()` with annotations parameter
  - [x] Unit tests for `toApiTool()` including annotations

## Dev Notes

### Position in Epic and Project

- **Epic 17** (TypeScript SDK Feature Alignment), third story
- **Prerequisites:** Story 17-1 (SDKMessage type enhancement) is done, Story 17-2 (AgentOptions) is done
- **This is a production code story** -- modifies ToolProtocol, ToolResult, ToolBuilder, and BashTool
- **Focus:** Fill the 3 tool-system gaps identified by Story 16-2 (CompatToolSystem): ToolAnnotations, typed content, run_in_background

### Critical Gap Analysis (from Story 16-2 Compat Report)

| # | TS SDK Feature | Current Swift Status | Action |
|---|---|---|---|
| 1 | `ToolAnnotations { readOnlyHint, destructiveHint, idempotentHint, openWorldHint }` | MISSING -- only `ToolProtocol.isReadOnly: Bool` exists | Add `ToolAnnotations` struct + protocol property |
| 2 | `CallToolResult.content: Array<TextBlock \| ImageBlock \| ResourceBlock>` | MISSING -- `ToolResult.content: String` (flat) | Add `ToolContent` enum + typed array |
| 3 | `BashInput.run_in_background: boolean` | MISSING | Add `runInBackground: Bool?` to BashInput |

### Current Tool System Structure

**File: `Sources/OpenAgentSDK/Types/ToolTypes.swift`** (209 lines)

```swift
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }
    var isReadOnly: Bool { get }
    func call(input: Any, context: ToolContext) async -> ToolResult
}

public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String
    public let content: String
    public let isError: Bool
}

public struct ToolExecuteResult: Sendable, Equatable {
    public let content: String
    public let isError: Bool
}
```

**File: `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`** -- BashInput is `private struct BashInput: Codable` with `command: String`, `timeout: Int?`, `description: String?`.

**File: `Sources/OpenAgentSDK/Tools/ToolRegistry.swift`** -- `toApiTool()` produces `["name": ..., "description": ..., "input_schema": ...]`. Must add `"annotations"` key when present.

**File: `Sources/OpenAgentSDK/Tools/ToolBuilder.swift`** -- 4 `defineTool()` overloads: Codable+String, Codable+ToolExecuteResult, No-Input, Raw Dictionary. Each must gain `annotations: ToolAnnotations? = nil` parameter. Internal tool structs (`CodableTool`, `StructuredCodableTool`, `NoInputTool`, `RawInputTool`) must store and expose annotations.

### Key Design Decisions

1. **ToolAnnotations as a separate struct, not replacing isReadOnly:** The existing `ToolProtocol.isReadOnly` property remains. `ToolAnnotations` adds the 3 missing hints (`destructiveHint`, `idempotentHint`, `openWorldHint`) plus a `readOnlyHint` that duplicates `isReadOnly` for TS SDK parity. When `annotations` is non-nil, its `readOnlyHint` should be consistent with `isReadOnly`. Default: `ToolAnnotations(readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false)` matching TS SDK defaults where destructiveHint defaults to `true`.

2. **ToolContent as an enum, not protocol:** Use an enum with associated values for the 3 content types. This is simpler than a protocol hierarchy and works well with pattern matching. The `.text` case is the most common; `.image` and `.resource` support multi-modal tool responses.

3. **Backward compatibility for ToolResult.content:** Keep the `content: String` stored property. Add `typedContent: [ToolContent]?` as optional. The existing `init(toolUseId:content:isError:)` remains unchanged. New init: `ToolResult(toolUseId:typedContent:isError:)` for typed content. When `typedContent` is set, `content` returns the concatenation of `.text` items (or the stored string as fallback).

4. **ToolExecuteResult typed content:** Mirror the `ToolResult` pattern -- add `typedContent: [ToolContent]?` and a backward-compatible `content` property.

5. **BashInput.runInBackground:** When `true`, the Bash tool launches the process and immediately returns a `backgroundTaskId` (UUID string). The process runs to completion in the background. This is a simplified version of TS SDK's background execution. Background task tracking uses a module-level dictionary keyed by taskId.

6. **Protocol extension for annotations default:** Add a protocol extension providing `var annotations: ToolAnnotations? { nil }` so existing tool implementations (all 34+ tools) don't need to be modified. Only tools created via `defineTool()` with explicit annotations need the override.

7. **Annotations in API format:** When converting to API tool format in `toApiTool()`, include `"annotations": { "readOnlyHint": ..., "destructiveHint": ..., ... }` only when `annotations` is non-nil. This follows the Anthropic API tool definition format.

### Architecture Compliance

- **Types/ is a leaf module:** ToolTypes.swift lives in `Types/` with no outbound dependencies. ToolAnnotations and ToolContent must also be self-contained in Types/.
- **Sendable conformance:** All new types MUST conform to `Sendable` (NFR1). Use only Sendable-compliant properties.
- **Module boundary:** ToolBuilder.swift (Tools/) imports from Types/ -- correct direction. No circular dependencies.
- **Backward compatibility:** All new properties are optional or have defaults. Existing `defineTool()` call sites must compile without modification.
- **DocC documentation:** All new public types need Swift-DocC comments (NFR2).
- **No Apple-proprietary frameworks:** Code must work on macOS and Linux.

### File Locations

```
Sources/OpenAgentSDK/Types/ToolTypes.swift         # MODIFY -- add ToolAnnotations, ToolContent, update ToolProtocol, ToolResult, ToolExecuteResult
Sources/OpenAgentSDK/Tools/ToolBuilder.swift       # MODIFY -- add annotations parameter to all 4 defineTool() overloads, update internal tool structs
Sources/OpenAgentSDK/Tools/ToolRegistry.swift      # MODIFY -- update toApiTool() to include annotations
Sources/OpenAgentSDK/Tools/Core/BashTool.swift     # MODIFY -- add runInBackground to BashInput, background execution logic
Sources/OpenAgentSDK/OpenAgentSDK.swift            # MODIFY -- re-export new public types in module doc
```

### Source Files to Reference

- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolProtocol, ToolResult, ToolExecuteResult, ToolContext (primary modification target, 209 lines)
- `Sources/OpenAgentSDK/Tools/ToolBuilder.swift` -- defineTool() factory functions (4 overloads, 393 lines), internal CodableTool/StructuredCodableTool/NoInputTool/RawInputTool structs
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` -- toApiTool(), toApiTools(), getAllBaseTools(), assembleToolPool() (166 lines)
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- BashInput struct (private Codable), bash process execution (244 lines)
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` -- tool execution pipeline (verify ToolResult handling)
- `_bmad-output/implementation-artifacts/16-2-tool-system-compat.md` -- Detailed gap analysis from compat verification
- `_bmad-output/planning-artifacts/epics.md#Story17.3` -- Story 17.3 definition with acceptance criteria

### Previous Story Intelligence

**From Story 17-2 (AgentOptions Enhancement):**
- Review finding: 14 new AgentOptions fields declared but runtime wiring in Agent.swift is incomplete. The `allowedTools`/`disallowedTools` fields exist on AgentOptions but are NOT wired to `filterTools()` in the agent loop. The `assembleToolPool()` function already accepts `allowed`/`disallowed` params, but Agent.swift does not pass `options.allowedTools`/`options.disallowedTools` through. This wiring gap is NOT in scope for Story 17-3 (separate concern from tool system types).
- `SendableStructuredOutput` wrapper pattern for `[String: Any]` Sendable compliance established
- Full test suite: 3722 tests passing at time of 17-2 completion
- Pattern: all new fields optional with default nil values for backward compatibility

**From Story 17-1 (SDKMessage Type Enhancement):**
- Added 12 new SDKMessage cases with associated data structs
- Updated 11 files with exhaustive `switch` on SDKMessage
- Established `SendableStructuredOutput` wrapper pattern
- `@unknown default` used for graceful transition in switch statements
- Full test suite: 3722 tests passing, 14 skipped, 0 failures

**From Story 16-2 (Tool System Compat):**
- Confirmed `ToolAnnotations` type does NOT exist in Swift SDK
- Confirmed `ToolProtocol.isReadOnly` is the sole equivalent to TS `readOnlyHint`
- Confirmed `ToolResult.content` is flat `String`, not typed array
- Confirmed `BashInput` missing `run_in_background` field (description field was added since)
- `InProcessMCPServer` matches TS `createSdkMcpServer` pattern (no changes needed)
- All 4 `defineTool()` overloads verified working
- Tool registration pattern (`defineTool()` -> `ToolProtocol` -> `InProcessMCPServer`) IS compatible

### Testing Requirements

- **Existing tests must pass:** 3722+ tests, zero regression
- **New tests needed:**
  - Unit tests for `ToolAnnotations` struct (init, default values, Sendable, Equatable)
  - Unit tests for `ToolContent` enum (all 3 cases, associated values, Sendable, Equatable)
  - Unit tests for `ToolResult` with typed content (backward compat, convenience property)
  - Unit tests for `ToolExecuteResult` with typed content
  - Unit tests for `defineTool()` with annotations parameter (all 4 overloads)
  - Unit tests for `toApiTool()` including annotations in output
  - Unit tests for BashInput with runInBackground field
- **No E2E tests with mocks:** Per CLAUDE.md, E2E tests use real environment
- After implementation, run full test suite and report total count

### Anti-Patterns to Avoid

- Do NOT make `annotations` required on `ToolProtocol` -- it must be optional with a default `nil` implementation (via protocol extension) so existing 34+ tool implementations compile without modification
- Do NOT replace `content: String` on ToolResult -- add `typedContent` alongside it for backward compatibility
- Do NOT import Core/ from Types/ -- violates module boundary
- Do NOT use force-unwrap (`!`)
- Do NOT use `Task` as a type name (conflicts with Swift Concurrency)
- Do NOT use Apple-proprietary frameworks (UIKit, AppKit, Combine)
- Do NOT forget that BashInput is `private` to BashTool.swift -- only modify within that file
- Do NOT break existing `defineTool()` call sites -- new `annotations` parameter must have default `nil`
- Do NOT forget to update the 4 internal tool structs in ToolBuilder.swift (CodableTool, StructuredCodableTool, NoInputTool, RawInputTool) to store and expose annotations

### Implementation Strategy

1. **Start with ToolAnnotations:** Create the struct in ToolTypes.swift with 4 Bool fields, Sendable+Equatable conformance, default values
2. **Add annotations to ToolProtocol:** Add optional property via protocol extension returning nil, so existing tools are unaffected
3. **Add ToolContent enum:** Create in ToolTypes.swift with `.text`, `.image`, `.resource` cases, all Sendable
4. **Enhance ToolResult:** Add `typedContent: [ToolContent]?` and backward-compatible `content` property
5. **Enhance ToolExecuteResult:** Mirror ToolResult pattern
6. **Update defineTool() overloads:** Add `annotations: ToolAnnotations? = nil` param to all 4, update internal tool structs to store and expose annotations
7. **Update toApiTool():** Include `"annotations"` dict when tool has non-nil annotations
8. **Add BashInput.runInBackground:** Add field, schema entry, and background execution path
9. **Write tests:** Unit tests for all new types and behaviors
10. **Build and verify:** `swift build` + full test suite

### Project Structure Notes

- Primary changes in `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolAnnotations and ToolContent are types, not tools, so they belong in Types/
- ToolBuilder.swift modifications are additive (new parameter with default) -- no existing call sites break
- Internal tool structs in ToolBuilder.swift (CodableTool, StructuredCodableTool, NoInputTool, RawInputTool) must gain `annotations` stored property and protocol conformance
- ToolRegistry.swift modification is localized to `toApiTool()` function
- BashTool.swift modification is contained within the file (BashInput is private)
- All new types are leaf-node types in Types/ with no outbound dependencies

### References

- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] -- ToolProtocol, ToolResult, ToolExecuteResult, ToolContext (primary modification target)
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] -- defineTool() factory functions (4 overloads), internal tool structs
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] -- toApiTool(), toApiTools(), getAllBaseTools(), assembleToolPool()
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] -- BashInput struct, bash process execution
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift] -- Tool execution pipeline
- [Source: _bmad-output/implementation-artifacts/16-2-tool-system-compat.md] -- Detailed gap analysis for tool system
- [Source: _bmad-output/planning-artifacts/epics.md#Story17.3] -- Story 17.3 definition with acceptance criteria
- [Source: _bmad-output/implementation-artifacts/17-2-agent-options-enhancement.md] -- Previous story (review findings, deferred wiring)
- [Source: _bmad-output/implementation-artifacts/17-1-sdkmessage-type-enhancement.md] -- Story 17-1 patterns (Sendable compliance)

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- All 3 tool-system gaps from Story 16-2 CompatToolSystem filled: ToolAnnotations, ToolContent typed content, BashInput.run_in_background
- ToolAnnotations struct added with 4 Bool fields matching TS SDK defaults (destructiveHint=true, rest=false)
- ToolContent enum added with .text, .image, .resource cases, all Sendable+Equatable
- ToolResult and ToolExecuteResult gained typedContent: [ToolContent]? with backward-compatible content computed property
- ToolProtocol.annotations added via protocol extension returning nil (existing 34+ tools unaffected)
- All 4 defineTool() overloads gained annotations: ToolAnnotations? = nil parameter
- Internal tool structs (CodableTool, StructuredCodableTool, NoInputTool, RawInputTool) updated to store and expose annotations
- toApiTool() now includes "annotations" dict when tool has non-nil annotations
- BashInput gained runInBackground: Bool? with "run_in_background" in inputSchema
- BackgroundProcessRegistry class provides thread-safe tracking of background processes
- Background execution returns immediately with "Background task started with ID: <taskId>"
- Process cleanup handled via terminationHandler on background processes
- CompatToolSystemTests.testBashTool_InputSchema_HasCommandAndTimeout updated: run_in_background gap resolved (assertNil -> assertNotNil)
- Full test suite: 3847 tests passing, 14 skipped, 0 failures

### Change Log

- 2026-04-16: Story 17-3 implementation complete -- ToolAnnotations, ToolContent, BashInput.runInBackground added

### File List

- Sources/OpenAgentSDK/Types/ToolTypes.swift (MODIFIED -- added ToolAnnotations, ToolContent, updated ToolProtocol, ToolResult, ToolExecuteResult)
- Sources/OpenAgentSDK/Tools/ToolBuilder.swift (MODIFIED -- added annotations parameter to all 4 defineTool() overloads, updated internal tool structs)
- Sources/OpenAgentSDK/Tools/ToolRegistry.swift (MODIFIED -- updated toApiTool() to include annotations)
- Sources/OpenAgentSDK/Tools/Core/BashTool.swift (MODIFIED -- added runInBackground to BashInput, BackgroundProcessRegistry, background execution path)
- Tests/OpenAgentSDKTests/Compat/CompatToolSystemTests.swift (MODIFIED -- updated run_in_background compat test from assertNil to assertNotNil)
