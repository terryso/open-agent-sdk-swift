# Story 16.10: Subagent 系统兼容性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 subagent 系统完全覆盖 TypeScript SDK 的 AgentDefinition 和 Agent 工具用法，
以便所有多 Agent 编排模式都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatSubagents/` 目录和 `CompatSubagents` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: AgentDefinition 字段完整性验证** -- 检查 Swift SDK 的 AgentDefinition 是否包含 TS SDK 的所有字段：
   - `description: String`（必需）
   - `tools: [String]?` — 允许的工具列表
   - `disallowedTools: [String]?` — 禁止的工具列表
   - `prompt: String`（必需）— 系统提示词
   - `model: String?` — 模型覆盖（支持 sonnet/opus/haiku/inherit）
   - `mcpServers: AgentMcpServerSpec?` — MCP 服务器配置
   - `skills: [String]?` — 预加载技能
   - `maxTurns: Int?` — 最大轮次
   - `criticalSystemReminder_EXPERIMENTAL: String?` — 实验性提醒
   缺失字段记录为缺口。

3. **AC3: AgentMcpServerSpec 验证** -- 验证 subagent 的 MCP 配置支持两种模式：字符串引用父级服务器名和内联配置记录（映射到 McpServerConfig）。

4. **AC4: Agent 工具输入类型验证** -- 检查 Swift SDK 的 AgentTool 输入是否包含 TS SDK `AgentInput` 的所有字段：
   - `description: String`、`prompt: String`、`subagent_type: String`
   - `model: String?`（sonnet/opus/haiku）
   - `resume: String?`
   - `run_in_background: Bool?`
   - `max_turns: Int?`
   - `name: String?`
   - `team_name: String?`
   - `mode: PermissionMode?`
   - `isolation: "worktree"?`
   缺失字段记录为缺口。

5. **AC5: Agent 工具输出类型验证** -- 检查 Swift SDK 是否支持 TS SDK `AgentOutput` 的三种状态鉴别：
   - `status: "completed"`（含 agentId、content、totalToolUseCount、totalDurationMs、totalTokens、usage、prompt）
   - `status: "async_launched"`（含 agentId、description、prompt、outputFile、canReadOutputFile?）
   - `status: "sub_agent_entered"`（含 description、message）
   缺失状态记录为缺口。

6. **AC6: Subagent Hook 事件验证** -- 验证 Swift SDK 支持 SubagentStart 和 SubagentStop hook 事件，且 HookInput 包含 agent_id、agent_type、agent_transcript_path、last_assistant_message 字段。

7. **AC7: 多 subagent 协作验证** -- 演示编程式定义多个 subagent，每个有不同的工具集和模型，通过主 Agent 调度执行。

8. **AC8: 兼容性报告输出** -- 对 AgentDefinition、AgentInput、AgentOutput、SubagentHooks 输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: AgentDefinition 字段检查 (AC: #2, #3)
  - [ ] 对比 TS SDK AgentDefinition 的每个字段
  - [ ] 检查 model 的 4 个值支持
  - [ ] 检查 mcpServers 两种模式
- [ ] Task 3: Agent 工具 I/O 检查 (AC: #4, #5)
  - [ ] 检查 AgentTool 输入字段
  - [ ] 检查输出三种状态
  - [ ] 记录缺失字段和状态
- [ ] Task 4: Subagent Hook 验证 (AC: #6)
  - [ ] 注册 SubagentStart/Stop hook
  - [ ] 执行 subagent 验证 hook 触发
- [ ] Task 5: 多 subagent 协作演示 (AC: #7)
  - [ ] 定义 2-3 个不同配置的 subagent
  - [ ] 主 Agent 调度执行
- [ ] Task 6: 生成兼容性报告 (AC: #8)

## Dev Notes

### 参考文档

- [TypeScript SDK] AgentDefinition、AgentMcpServerSpec、AgentInput、AgentOutput、SubagentStartHookInput、SubagentStopHookInput
- [Source] Sources/OpenAgentSDK/Core/SubAgentSpawner.swift — SubAgentSpawner 协议
- [Source] Sources/OpenAgentSDK/Types/SubAgentTypes.swift — AgentDefinition、SubAgentResult
- [Source] Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift — AgentTool 实现
