# Story 16.3: 消息类型完整性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 `SDKMessage` 包含 TypeScript SDK 的所有 20 种消息子类型及其字段，
以便消费消息流的代码能正确处理所有事件。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatMessageTypes/` 目录和 `CompatMessageTypes` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: SDKAssistantMessage 验证** -- 验证 `.assistant(AssistantData)` 包含 TS SDK `SDKAssistantMessage` 的所有字段：`uuid`、`session_id`、`message`（Anthropic Message 对象）、`parent_tool_use_id`、`error`（支持 authentication_failed/billing_error/rate_limit/invalid_request/server_error/max_output_tokens/unknown）。

3. **AC3: SDKResultMessage 验证** -- 验证 `.result(ResultData)` 支持 TS SDK 的两种子类型：成功（含 result、total_cost_usd、usage、model_usage、num_turns、duration_ms、structured_output、permission_denials）和错误（含 errors 数组和 error_max_turns/error_during_execution/error_max_budget_usd/error_max_structured_output_retries 子类型）。

4. **AC4: SDKSystemMessage 验证** -- 验证 `.system(SystemData)` 支持 TS SDK 的所有子类型：init（含 session_id、tools、model、permissionMode、mcp_servers、cwd）、status（含 status、permissionMode）、compact_boundary（含 compact_metadata）、task_notification（含 task_id、status、output_file、summary、usage）。

5. **AC5: SDKPartialAssistantMessage 验证** -- 验证是否有 `.partialMessage(PartialData)` 等价于 TS SDK 的 `SDKPartialAssistantMessage`（type: "stream_event"，含 event 流事件、parent_tool_use_id、uuid、session_id）。如果不存在，记录缺口。

6. **AC6: 工具进度消息验证** -- 验证是否有 `SDKToolProgressMessage` 等价类型（tool_use_id、tool_name、parent_tool_use_id、elapsed_time_seconds）。如果不存在，记录缺口。

7. **AC7: Hook 相关消息验证** -- 验证是否有 `SDKHookStartedMessage`、`SDKHookProgressMessage`、`SDKHookResponseMessage` 等价类型（hook_id、hook_name、hook_event、stdout/stderr/output、exit_code、outcome）。如果不存在，记录缺口。

8. **AC8: 任务相关消息验证** -- 验证是否有 `SDKTaskStartedMessage`、`SDKTaskProgressMessage`、`SDKTaskNotificationMessage` 等价类型（task_id、task_type、description、usage）。如果不存在，记录缺口。

9. **AC9: 其他消息类型验证** -- 验证是否有 `SDKFilesPersistedEvent`、`SDKRateLimitEvent`、`SDKAuthStatusMessage`、`SDKPromptSuggestionMessage`、`SDKToolUseSummaryMessage`、`SDKLocalCommandOutputMessage` 的等价类型。如果不存在，记录缺口。

10. **AC10: 完整兼容性报告** -- 对 20 种 TS SDK 消息类型逐一输出兼容性状态，包括字段级别的对比。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
  - [ ] 创建 `Examples/CompatMessageTypes/main.swift`
  - [ ] 在 Package.swift 添加 `CompatMessageTypes` 可执行目标

- [ ] Task 2: 遍历 SDKMessage 所有 case (AC: #2, #3, #4)
  - [ ] 执行一个完整查询（含工具调用）
  - [ ] 使用 switch 遍历每个 SDKMessage case
  - [ ] 打印每个 case 的关联值字段

- [ ] Task 3: 验证缺失的消息类型 (AC: #5-#9)
  - [ ] 检查 Swift SDK 是否有 PartialAssistantMessage
  - [ ] 检查 ToolProgress 消息
  - [ ] 检查 Hook 生命周期消息
  - [ ] 检查 Task 生命周期消息
  - [ ] 检查 FilesPersisted/RateLimit/AuthStatus 等消息
  - [ ] 对每种缺失类型记录字段需求

- [ ] Task 4: 生成完整兼容性报告 (AC: #10)
  - [ ] 对 20 种消息类型逐一对比
  - [ ] 输出 PASS/MISSING/PARTIAL 状态

## Dev Notes

### 关键对比矩阵

TS SDK 的 20 种消息类型：
1. `SDKAssistantMessage` → `.assistant(AssistantData)`
2. `SDKUserMessage` → 用户输入事件
3. `SDKResultMessage` → `.result(ResultData)` — 需验证两种子类型
4. `SDKSystemMessage(init)` → `.system(SystemData)` — 需验证所有子类型
5. `SDKPartialAssistantMessage` → `.partialMessage(PartialData)` — 需验证
6. `SDKCompactBoundaryMessage` → 系统消息子类型 — 需验证
7. `SDKStatusMessage` → 系统消息子类型 — 需验证
8. `SDKTaskNotificationMessage` → 系统消息子类型 — 需验证
9. `SDKTaskStartedMessage` → 系统消息子类型 — 需验证
10. `SDKTaskProgressMessage` → 系统消息子类型 — 需验证
11. `SDKToolProgressMessage` → 需验证独立类型
12. `SDKHookStartedMessage` → 系统消息子类型 — 需验证
13. `SDKHookProgressMessage` → 系统消息子类型 — 需验证
14. `SDKHookResponseMessage` → 系统消息子类型 — 需验证
15. `SDKAuthStatusMessage` → 需验证独立类型
16. `SDKFilesPersistedEvent` → 系统消息子类型 — 需验证
17. `SDKRateLimitEvent` → 需验证独立类型
18. `SDKLocalCommandOutputMessage` → 系统消息子类型 — 需验证
19. `SDKPromptSuggestionMessage` → 需验证独立类型
20. `SDKToolUseSummaryMessage` → 需验证独立类型

### 参考文档

- [TypeScript SDK] Message Types 全部小节
- [Source] Sources/OpenAgentSDK/Types/SDKMessage.swift — Swift SDKMessage enum
