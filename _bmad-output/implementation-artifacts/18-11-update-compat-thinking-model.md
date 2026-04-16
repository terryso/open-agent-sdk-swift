# Story 18.11: 更新 CompatThinkingModel 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatThinkingModel/` 使其反映 Epic 17 填补后的兼容性状态，
以便 Thinking/Model 配置兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: EffortLevel PASS** -- low/medium/high/max 4 个级别标记为 `[PASS]`.
2. **AC2: ModelInfo 字段 PASS** -- displayName/description/supportsEffort/supportedEffortLevels/supportsAdaptiveThinking/supportsFastMode 标记为 `[PASS]`.
3. **AC3: fallbackModel PASS** -- fallbackModel 行为标记为 `[PASS]`.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 EffortLevel 验证 (AC: #1)
  - [ ] 测试 4 个 effort 级别
  - [ ] 测试 effort 与 ThinkingConfig 联动

- [ ] Task 2: 更新 ModelInfo 验证 (AC: #2)
  - [ ] 测试新字段的值检查

- [ ] Task 3: 更新 fallbackModel 验证 (AC: #3)
  - [ ] 测试主模型失败后自动切换
  - [ ] 验证切换事件通过 SDKMessage 通知

- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-11 (Thinking 和模型配置增强)

### 关键源文件
- `Examples/CompatThinkingModel/main.swift` — 需要更新的示例

### References
- [Story 16-11 兼容性报告](_bmad-output/implementation-artifacts/16-11-thinking-model-compat.md)
- [Story 17-11](_bmad-output/implementation-artifacts/17-11-thinking-model-enhancement.md)
