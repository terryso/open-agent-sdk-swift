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
