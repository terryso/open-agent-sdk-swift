# Story 17.2: AgentOptions 完整参数

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 的 `AgentOptions` 中缺失的 TS SDK Options 字段，
以便开发者迁移时不需要妥协功能。

## Acceptance Criteria

1. **AC1: 核心配置补全** -- AgentOptions 新增: `fallbackModel: String?`, `env: [String: String]?`, `allowedTools: [String]?`, `disallowedTools: [String]?`.

2. **AC2: 高级配置补全** -- AgentOptions 新增: `effort: EffortLevel?` (low/medium/high/max), `outputFormat: OutputFormat?` (json_schema), `toolConfig: ToolConfig?`, `includePartialMessages: Bool` (默认 true), `promptSuggestions: Bool` (默认 false).

3. **AC3: 会话配置补全** -- AgentOptions 新增: `continueRecentSession: Bool`, `forkSession: Bool`, `resumeSessionAt: String?`, `persistSession: Bool` (默认 true).

4. **AC4: EffortLevel 枚举** -- 新增 `EffortLevel` 枚举: `.low`, `.medium`, `.high`, `.max`.

5. **AC5: OutputFormat 类型** -- 新增 `OutputFormat` 结构: `{ type: "json_schema", jsonSchema: [String: Any] }`.

6. **AC6: ToolConfig 类型** -- 新增 `ToolConfig` 结构用于工具行为配置.

7. **AC7: systemPrompt preset 支持** -- systemPrompt 支持 `SystemPromptConfig.preset(name:append:)` 模式.

8. **AC8: 构建和测试** -- `swift build` 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: 核心配置字段 (AC: #1)
  - [ ] 添加 fallbackModel: String?
  - [ ] 添加 env: [String: String]?
  - [ ] 添加 allowedTools: [String]?
  - [ ] 添加 disallowedTools: [String]?
  - [ ] 在 Agent loop 中实现 fallbackModel 切换逻辑
  - [ ] 在 Agent loop 中实现工具白名单/黑名单过滤

- [ ] Task 2: 高级配置字段 (AC: #2, #4, #5, #6)
  - [ ] 创建 EffortLevel 枚举
  - [ ] 创建 OutputFormat 结构
  - [ ] 创建 ToolConfig 结构
  - [ ] 添加 effort, outputFormat, toolConfig, includePartialMessages, promptSuggestions 字段
  - [ ] effort 与 ThinkingConfig 联动逻辑

- [ ] Task 3: 会话配置字段 (AC: #3)
  - [ ] 添加 continueRecentSession, forkSession, resumeSessionAt, persistSession 字段
  - [ ] 在 session restore 逻辑中集成这些字段

- [ ] Task 4: systemPrompt preset (AC: #7)
  - [ ] 创建 SystemPromptConfig 类型 (支持 .text(String) 和 .preset(name:append:))
  - [ ] 更新 AgentOptions.systemPrompt 类型以支持两种模式

- [ ] Task 5: 验证构建和测试 (AC: #8)

## Dev Notes

### 关键源文件

- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions 结构
- `Sources/OpenAgentSDK/Core/Agent.swift` -- 使用 AgentOptions 的主循环
- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- ThinkingConfig 已存在

### Epic 16 缺口数据来源

- Story 16-8: 14 个 MISSING 字段详细映射
- Story 16-11: effort 级别和 fallbackModel 行为

### 实现策略

- 所有新增字段均为 optional 或有默认值，确保向后兼容
- fallbackModel 切换逻辑：主模型返回 API 错误时，自动使用 fallbackModel 重试
- allowedTools/disallowedTools 在工具注册阶段过滤，disallowedTools 优先级最高
- effort 级别映射到 API 请求的 thinking.budget_tokens 参数

### References

- [Story 16-8 兼容性报告](_bmad-output/implementation-artifacts/16-8-agent-options-compat.md)
- [Story 16-11 兼容性报告](_bmad-output/implementation-artifacts/16-11-thinking-model-compat.md)
