---
title: 'Deferred Core Type Improvements'
type: 'refactor'
created: '2026-04-15'
status: 'done'
baseline_commit: '1a5e43c'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Five deferred work items in core types reduce type safety, maintainability, and debuggability: String-typed timestamps in SessionMetadata, duplicate MCP transport config structs, hardcoded MODEL_PRICING dictionary, missing HookOutput Equatable conformance, and silent error swallowing in HookRegistry.

**Approach:** Make targeted, backward-compatible improvements to each: convert timestamps to `Date`, unify the two MCP config structs into one with type aliases for compat, add a `registerModel()` function for MODEL_PRICING, add `Equatable` to HookOutput, and add error logging in HookRegistry's catch block.

## Boundaries & Constraints

**Always:** Maintain backward compatibility — public API signatures must not break existing consumers. Use type aliases where structs are merged. Keep all existing tests passing.

**Ask First:** None anticipated.

**Never:** Do not change the serialization format on disk (ISO 8601 strings in JSON). Do not add new dependencies. Do not touch MCP connection wiring (Epic 6 scope).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| SessionMetadata with Date fields | `Date()` values for createdAt/updatedAt | Serialized as ISO 8601 strings; deserialized back to `Date` | Malformed date string → `nil` metadata, logged warning |
| McpTransportConfig used as McpSseConfig | Code references `McpSseConfig` | Type alias resolves to `McpTransportConfig`, compiles and works identically | N/A |
| registerModel for unknown model | `registerModel("my-model", pricing: ...)` | MODEL_PRICING updated; subsequent `estimateCost` finds it | N/A |
| registerModel overwriting existing | Same key as built-in | Overwrites silently (user choice takes precedence) | N/A |
| HookOutput equality comparison | Two HookOutput instances with same fields | `==` returns `true` | N/A |
| Hook execution failure | Hook throws error | Error logged via `Logger.shared.error()`, execution continues | N/A |

</frozen-after-approval>

## Code Map

- `Sources/OpenAgentSDK/Types/SessionTypes.swift` -- SessionMetadata struct with String timestamps
- `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- Serializes/deserializes SessionMetadata, owns dateFormatter
- `Sources/OpenAgentSDK/Types/MCPConfig.swift` -- McpSseConfig, McpHttpConfig, McpServerConfig enum
- `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` -- Consumes McpServerConfig for connections
- `Sources/OpenAgentSDK/Types/ModelInfo.swift` -- MODEL_PRICING dictionary and ModelPricing struct
- `Sources/OpenAgentSDK/Utils/Tokens.swift` -- estimateCost() reads MODEL_PRICING
- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- HookOutput struct (line 102), HookNotification, PermissionUpdate
- `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` -- execute() catch block (line 122)
- `Tests/OpenAgentSDKTests/` -- Existing tests for all affected types

## Tasks & Acceptance

**Execution:**
- [x] `Sources/OpenAgentSDK/Types/SessionTypes.swift` -- Change `createdAt: String` and `updatedAt: String` to `Date` type; update init and Equatable conformance
- [x] `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- Update serialization (Date→String) and deserialization (String→Date with error logging); remove local dateFormatter if SessionTypes now owns it
- [x] `Sources/OpenAgentSDK/Types/MCPConfig.swift` -- Create `McpTransportConfig` struct with url+headers; replace McpSseConfig and McpHttpConfig with type aliases to McpTransportConfig
- [x] `Sources/OpenAgentSDK/Types/ModelInfo.swift` -- Change MODEL_PRICING from `let` to `var`; add `public func registerModel(_:pricing:)` and `public func unregisterModel(_:)` functions
- [x] `Sources/OpenAgentSDK/Types/HookTypes.swift` -- Add `Equatable` conformance to HookOutput struct declaration
- [x] `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` -- Add `Logger.shared.error()` call in execute() catch block; import Logger if needed
- [x] `Tests/OpenAgentSDKTests/` -- Update any tests broken by SessionMetadata Date change; add tests for registerModel/unregisterModel; add test for HookOutput equality; verify all existing tests pass

**Acceptance Criteria:**
- Given SessionMetadata with Date fields, when serialized to JSON and deserialized, then timestamps round-trip correctly
- Given code referencing McpSseConfig or McpHttpConfig, when compiled, then it works via type alias without changes
- Given a model not in MODEL_PRICING, when registerModel is called, then estimateCost returns the registered pricing
- Given two HookOutput instances with identical fields, when compared with ==, then result is true
- Given a hook that throws, when execute() runs, then error is logged and execution continues
- Given the full test suite, when run, then all tests pass

## Spec Change Log

## Design Notes

**SessionMetadata Date migration:** The on-disk format stays ISO 8601 strings. The `Date` type is only in-memory. SessionStore handles conversion at serialization boundaries. The existing `ISO8601DateFormatter` with `.withInternetDateTime, .withFractionalSeconds` is reused.

**MCP Config type aliases:** `public typealias McpSseConfig = McpTransportConfig` and `public typealias McpHttpConfig = McpTransportConfig` preserve source compatibility. The enum cases `.sse(McpSseConfig)` and `.http(McpHttpConfig)` remain unchanged.

**MODEL_PRICING mutability:** The dictionary becomes `var` with a public registration API. Thread safety is not a concern — MODEL_PRICING is typically configured at startup before any concurrent access.

## Verification

**Commands:**
- `swift build` -- expected: clean compilation, zero errors
- `swift test` -- expected: all tests pass (verify total count matches baseline)

## Suggested Review Order

**SessionMetadata Date migration**

- Entry point: timestamps changed from String to Date
  [`SessionTypes.swift:14`](../../Sources/OpenAgentSDK/Types/SessionTypes.swift#L14)

- Deserialization with split guard for missing vs malformed dates
  [`SessionStore.swift:127`](../../Sources/OpenAgentSDK/Stores/SessionStore.swift#L127)

- Serialization unchanged — Date→String via existing dateFormatter
  [`SessionStore.swift:40`](../../Sources/OpenAgentSDK/Stores/SessionStore.swift#L40)

**MCP transport config consolidation**

- New unified struct replacing two identical structs
  [`MCPConfig.swift:37`](../../Sources/OpenAgentSDK/Types/MCPConfig.swift#L37)

- Type aliases for backward compatibility
  [`MCPConfig.swift:55`](../../Sources/OpenAgentSDK/Types/MCPConfig.swift#L55)

- Consolidated connect() with streaming parameter
  [`MCPClientManager.swift:136`](../../Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift#L136)

- Enum dispatch passes explicit streaming flag
  [`MCPClientManager.swift:236`](../../Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift#L236)

**MODEL_PRICING registration API**

- Mutable pricing table with registerModel/unregisterModel
  [`ModelInfo.swift:43`](../../Sources/OpenAgentSDK/Types/ModelInfo.swift#L43)

**HookOutput Equatable + HookRegistry logging**

- Equatable conformance added (compiler-synthesized from all-Equatable fields)
  [`HookTypes.swift:102`](../../Sources/OpenAgentSDK/Types/HookTypes.swift#L102)

- Error logging in previously silent catch block
  [`HookRegistry.swift:124`](../../Sources/OpenAgentSDK/Hooks/HookRegistry.swift#L124)

**Tests**

- SessionMetadata tests updated for Date type
  [`SessionTypesTests.swift:8`](../../Tests/OpenAgentSDKTests/Types/SessionTypesTests.swift#L8)

- New registerModel/unregisterModel tests
  [`ModelInfoTests.swift:95`](../../Tests/OpenAgentSDKTests/Types/ModelInfoTests.swift#L95)

- New HookOutput equality tests
  [`HookTypesTests.swift:107`](../../Tests/OpenAgentSDKTests/Types/HookTypesTests.swift#L107)
