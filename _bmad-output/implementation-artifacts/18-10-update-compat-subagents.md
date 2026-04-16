# Story 18.10: 更新 CompatSubagents 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatSubagents/` 使其反映 Epic 17 填补后的兼容性状态，
以便子代理系统兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: AgentDefinition 字段 PASS** -- mcpServers/skills/criticalSystemReminderExperimental 标记为 `[PASS]`.
2. **AC2: AgentInput 字段 PASS** -- runInBackground/isolation/name/teamName/mode 标记为 `[PASS]`.
3. **AC3: AgentOutput 三态 PASS** -- completed/asyncLaunched/subAgentEntered 标记为 `[PASS]`.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 AgentDefinition 验证 (AC: #1)
  - [ ] 测试 mcpServers 两种模式 (string 引用和 inline)
  - [ ] 测试 skills 列表
  - [ ] 测试 criticalSystemReminderExperimental

- [ ] Task 2: 更新 AgentInput 验证 (AC: #2)
  - [ ] 测试 runInBackground 后台执行
  - [ ] 测试 isolation="worktree"
  - [ ] 测试 name/teamName/mode

- [ ] Task 3: 更新 AgentOutput 验证 (AC: #3)
  - [ ] 测试 completed 状态字段
  - [ ] 测试 asyncLaunched 状态字段
  - [ ] 测试 subAgentEntered 状态字段

- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-6 (子代理系统增强)

### 关键源文件
- `Examples/CompatSubagents/main.swift` — 需要更新的示例

### References
- [Story 16-10 兼容性报告](_bmad-output/implementation-artifacts/16-10-subagent-system-compat.md)
- [Story 17-6](_bmad-output/implementation-artifacts/17-6-subagent-system-enhancement.md)
