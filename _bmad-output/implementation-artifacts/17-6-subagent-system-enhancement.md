# Story 17.6: 子代理系统增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 子代理系统中缺失的 AgentDefinition 字段、AgentInput 字段和 AgentOutput 三态判定，
以便所有多 Agent 编排模式都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: AgentDefinition 字段补全** -- AgentDefinition 新增: `mcpServers: [AgentMcpServerSpec]?` (支持 string 引用和 inline 配置), `skills: [String]?`, `criticalSystemReminderExperimental: String?`.

2. **AC2: AgentInput 字段补全** -- AgentTool 输入新增: `runInBackground: Bool?`, `isolation: String?` (支持 "worktree"), `name: String?`, `teamName: String?`, `mode: PermissionMode?`.

3. **AC3: AgentOutput 三态** -- 实现 AgentOutput 三种状态: `.completed` (agentId, content, totalToolUseCount, totalDurationMs, totalTokens, usage, prompt), `.asyncLaunched` (agentId, description, prompt, outputFile, canReadOutputFile), `.subAgentEntered` (description, message).

4. **AC4: AgentMcpServerSpec** -- 支持两种模式: string 引用父级服务器名, inline McpServerConfig 配置.

5. **AC5: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: AgentDefinition 字段 (AC: #1, #4)
  - [ ] 创建 AgentMcpServerSpec 类型 (支持 .reference(String) 和 .inline(McpServerConfig))
  - [ ] 在 AgentDefinition 中添加 mcpServers, skills, criticalSystemReminderExperimental
  - [ ] 在 SubAgentSpawner 中集成 mcpServers 配置

- [ ] Task 2: AgentInput 字段 (AC: #2)
  - [ ] 在 AgentTool.Input 中添加 runInBackground, isolation, name, teamName, mode 字段
  - [ ] BashTool 后台执行支持 (与 17-3 协同)
  - [ ] worktree 隔离模式支持

- [ ] Task 3: AgentOutput 三态 (AC: #3)
  - [ ] 创建 AgentOutput 枚举 (completed, asyncLaunched, subAgentEntered)
  - [ ] 创建 CompletedOutput, AsyncLaunchedOutput, SubAgentEnteredOutput 关联值类型
  - [ ] 在 SubAgentSpawner 中构造 AgentOutput
  - [ ] 更新 AgentTool 输出解析

- [ ] Task 4: 验证构建和测试 (AC: #5)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Tools/Core/AgentTool.swift` -- AgentTool, AgentInput, AgentDefinition
- `Sources/OpenAgentSDK/Core/SubAgentSpawner.swift` -- subagent 创建和执行
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions

### 缺口来源
- Story 16-10: ~20 MISSING (disallowedTools, mcpServers, skills, runInBackground, isolation, AgentOutput states)

### 实现策略
- AgentOutput 三态用于区分同步完成、异步启动、子代理进入三种场景
- runInBackground + isolation="worktree" 组合需要与 WorktreeStore 协同
- AgentMcpServerSpec 的 string 引用模式需要在 SubAgentSpawner 中解析父级 MCP 配置

### References
- [Story 16-10 兼容性报告](_bmad-output/implementation-artifacts/16-10-subagent-system-compat.md)
