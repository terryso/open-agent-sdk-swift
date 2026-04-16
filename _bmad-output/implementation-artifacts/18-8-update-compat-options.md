# Story 18.8: 更新 CompatOptions 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatOptions/` 使其反映 Epic 17 填补后的兼容性状态，
以便 Agent Options 兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: 核心配置 PASS** -- fallbackModel/env/allowedTools/disallowedTools 标记为 `[PASS]`.
2. **AC2: 高级配置 PASS** -- effort/outputFormat/toolConfig/includePartialMessages/promptSuggestions 标记为 `[PASS]`.
3. **AC3: 会话配置 PASS** -- continueRecentSession/forkSession/resumeSessionAt/persistSession 标记为 `[PASS]`.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新核心配置验证 (AC: #1)
  - [ ] 测试 fallbackModel 设置和切换行为
  - [ ] 测试 env 注入
  - [ ] 测试 allowedTools/disallowedTools 过滤

- [ ] Task 2: 更新高级配置验证 (AC: #2)
  - [ ] 测试 EffortLevel 4 个值
  - [ ] 测试 OutputFormat json_schema
  - [ ] 测试 includePartialMessages/promptSuggestions 开关

- [ ] Task 3: 更新会话配置验证 (AC: #3)
- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-2 (AgentOptions 完整参数)

### 关键源文件
- `Examples/CompatOptions/main.swift` — 需要更新的示例

### References
- [Story 16-8 兼容性报告](_bmad-output/implementation-artifacts/16-8-agent-options-compat.md)
- [Story 17-2](_bmad-output/implementation-artifacts/17-2-agent-options-enhancement.md)
