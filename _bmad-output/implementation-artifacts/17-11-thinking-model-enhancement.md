# Story 17.11: Thinking 和模型配置增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 effort 级别、ModelInfo 字段和 fallbackModel 行为，
以便开发者可以精确控制 LLM 的推理行为。

## Acceptance Criteria

1. **AC1: EffortLevel 枚举** -- 新增 `EffortLevel` 枚举: `.low`, `.medium`, `.high`, `.max`. 与 ThinkingConfig 正确联动 (effort 自动映射到 thinking budget).

2. **AC2: ModelInfo 字段补全** -- ModelInfo 新增: displayName: String?, description: String?, supportsEffort: Bool?, supportedEffortLevels: [EffortLevel]?, supportsAdaptiveThinking: Bool?, supportsFastMode: Bool?.

3. **AC3: fallbackModel 行为** -- 主模型请求失败时自动切换到 fallbackModel. 重试使用相同消息上下文. 切换事件通过 AsyncStream<SDKMessage> 通知.

4. **AC4: effort 与 ThinkingConfig 联动** -- 设置 effort=.low 映射到低 thinking budget, effort=.max 映射到最大 thinking budget. effort 和 explicit ThinkingConfig 同时存在时, explicit 优先.

5. **AC5: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: EffortLevel (AC: #1, #4)
  - [ ] 创建 EffortLevel 枚举
  - [ ] 实现 effort -> thinking budget 映射
  - [ ] effort 和 ThinkingConfig 优先级逻辑

- [ ] Task 2: ModelInfo 字段 (AC: #2)
  - [ ] 在 ModelInfo 中添加 6 个 optional 字段
  - [ ] 更新模型信息获取逻辑

- [ ] Task 3: fallbackModel 行为 (AC: #3)
  - [ ] 在 API 调用失败时检查 fallbackModel
  - [ ] 使用相同上下文重试
  - [ ] 通过 SDKMessage 通知模型切换事件
  - [ ] costBreakdown 中区分主模型和备用模型的使用量

- [ ] Task 4: 验证构建和测试 (AC: #5)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- ThinkingConfig 已存在
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions, ModelInfo (如存在)
- `Sources/OpenAgentSDK/Core/Agent.swift` -- API 调用和模型切换逻辑

### 缺口来源
- Story 16-11: 10 MISSING (effort, ModelInfo fields, fallbackModel behavior)

### 实现策略
- EffortLevel 是 ThinkingConfig 的便捷封装，不替代 ThinkingConfig
- effort 映射规则: .low -> disabled, .medium -> adaptive, .high -> enabled(10000), .max -> enabled(maxTokens)
- fallbackModel 重试不计入额外 turn，但在 usage 中标记模型切换
- ModelInfo 字段可在 Agent 初始化时从配置或硬编码的模型列表获取

### References
- [Story 16-11 兼容性报告](_bmad-output/implementation-artifacts/16-11-thinking-model-compat.md)
