# Deferred Work

## Deferred from: code review of 1-1-spm-package-core-types (2026-04-04)

- **SessionMetadata 使用 String 时间戳** — createdAt/updatedAt 为 String 类型无格式约束，未来改为 Date 或添加格式文档 [SessionTypes.swift:4-30]
- **McpSseConfig/McpHttpConfig 结构完全相同** — 两者均为 url+headers，按 MCP 协议传输类型区分，未来可考虑合并 [MCPConfig.swift:24-43]
- **HookNotification.level / PermissionUpdate.behavior 为字符串类型** — 应使用 enum 提供类型安全，匹配 TS SDK 模式但可改进 [HookTypes.swift, PermissionTypes.swift]
- **ThinkingConfig.enabled 无 budgetTokens 验证** — 零或负值会传给 API，在使用点添加验证 [ThinkingConfig.swift:6]
- **HookDefinition 所有字段可选** — 全 nil 实例无语义，匹配 TS SDK 模式 [HookTypes.swift]
- **MODEL_PRICING 字典对新模型返回 nil** — 新模型发布需更新 SDK，可改为可注册模式 [ModelInfo.swift:30-39]
- **AgentOptions.baseURL 无 URL 验证** — 无效 URL 静默通过，在使用点添加验证 [AgentTypes.swift]

## Deferred from: code review of 3-4-core-file-tools-read-write-edit (2026-04-05)

- **Edit tool missing old_string == new_string guard** — TS SDK rejects identical strings, Swift tool silently succeeds with no-op. Not in story AC, defensive enhancement for future [FileEditTool.swift]
- **Edit tool missing replace_all parameter** — TS SDK supports replacing all occurrences via boolean flag. Not in story AC, future story enhancement [FileEditTool.swift]
- **NFR2 performance test not verified** — No test confirms <1MB file reads complete in 500ms. Requires performance test infrastructure not available locally [FileReadTool.swift]

## Deferred from: code review of 4-1-task-store-mailbox-store (2026-04-06)

- **Task struct name collision with Swift Concurrency's Task** — `Task` struct collides with `_Concurrency.Task`. Already mitigated with `_Concurrency.Task` qualification in existing code, but remains a latent naming risk for future code. Pre-existing design decision documented in Dev Notes [TaskTypes.swift:17]

## Deferred from: code review of 5-7-mcp-resource-tools (2026-04-07)

- **mcpConnections thread safety (latent risk)** — `nonisolated(unsafe) var mcpConnections` is genuinely mutable shared state. Acceptable for single-agent but would clobber with concurrent multi-agent. Design choice matching TS SDK pattern [ListMcpResourcesTool.swift:8]
- **AC5: missing tool count hint in listing-not-supported** — TS SDK shows `({tools.length} tools available)` but Swift MCPConnectionInfo lacks tools field. Deferred to Epic 6 when real MCP connections exist [ListMcpResourcesTool.swift:79-91]

## Deferred from: code review of 7-1-session-store-json-persistence (2026-04-08)

- **load() silently swallows JSON corruption** — If transcript.json is truncated or corrupted, load() returns nil with no diagnostic. Matches TypeScript SDK `catch { return null }` behavior. Future enhancement: add optional logging [SessionStore.swift:101-143]
- **E2E tests missing concurrent/delete coverage** — AC10 minimum coverage met (round-trip, permissions, auto-creation). Missing E2E tests for concurrent saves and delete. Future enhancement [SessionStoreE2ETests.swift]

## Deferred from: code review of 8-1-hook-event-types-registry (2026-04-09)

- **Silent error swallowing in execute() catch block** — All hook errors (including timeout) are silently caught with no logging. Matches TS SDK `console.error` pattern but Swift has no logging infrastructure. Future enhancement when logging is added [HookRegistry.swift:122-125]
- **HookOutput lacks Equatable conformance** — Cannot perform full structural equality assertions in tests. Low priority since all fields are individually Equatable [HookTypes.swift:62]

## Deferred from: code review of 8-5-custom-authorization-callback (2026-04-09)

- **Stream path ignores dynamic permission changes** — stream() captures permissionMode and canUseTool at stream creation time. Calling setPermissionMode()/setCanUseTool() during an active stream has no effect. This is pre-existing behavior of the stream architecture, not introduced by this story. Future enhancement: re-read options at each tool execution in stream path [Agent.swift:506-507]

## Deferred from: code review of 10-3-prompt-api-example (2026-04-10)

- **No safety warning about destructive tools with bypassPermissions** — PromptAPIExample registers Write/Edit/Bash tools with bypassPermissions. All examples in the project follow this pattern. Pre-existing design choice, not introduced by this story
