# Story 18.7: 更新 CompatQueryMethods 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatQueryMethods/` 使其反映 Epic 17 填补后的兼容性状态，
以便查询方法兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: 9 个新查询方法 PASS** -- rewindFiles/streamInput/stopTask/close/initializationResult/supportedModels/supportedAgents/setMaxThinkingTokens 标记为 `[PASS]`.
2. **AC2: 方法功能验证** -- 示例中实际调用新方法并验证返回值.
3. **AC3: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 16 个查询方法映射表 (AC: #1)
  - [ ] rewindFiles -> agent.rewindFiles()
  - [ ] streamInput -> agent.streamInput()
  - [ ] stopTask -> agent.stopTask()
  - [ ] close -> agent.close()
  - [ ] initializationResult -> agent.initializationResult()
  - [ ] supportedModels -> agent.supportedModels()
  - [ ] supportedAgents -> agent.supportedAgents()
  - [ ] setMaxThinkingTokens -> agent.setMaxThinkingTokens()
- [ ] Task 2: 更新实际方法调用验证 (AC: #2)
- [ ] Task 3: 验证构建 (AC: #3)

## Dev Notes

### 依赖
- Story 17-10 (查询方法增强)

### 关键源文件
- `Examples/CompatQueryMethods/main.swift` — 需要更新的示例

### References
- [Story 16-7 兼容性报告](_bmad-output/implementation-artifacts/16-7-query-methods-compat.md)
- [Story 17-10](_bmad-output/implementation-artifacts/17-10-query-methods-enhancement.md)
