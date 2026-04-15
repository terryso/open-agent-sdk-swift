# Story 16.11: Thinking & Model 配置兼容性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 ThinkingConfig 和模型配置与 TypeScript SDK 完全兼容，
以便开发者可以精确控制 LLM 的推理行为。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatThinkingModel/` 目录和 `CompatThinkingModel` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: ThinkingConfig 三种模式验证** -- 逐一测试 Swift SDK 的 ThinkingConfig，验证与 TS SDK 完全一致：
   - `.adaptive` — 模型自动决定推理深度（Opus 4.6+ 默认）
   - `.enabled(budgetTokens: N)` — 固定推理 token 预算
   - `.disabled` — 禁用扩展推理
   且三种模式都正确传递到 API 请求。

3. **AC3: effort 级别验证** -- 检查 Swift SDK 是否支持 TS SDK 的 effort 参数（`low | medium | high | max`），验证 effort 与 ThinkingConfig 的正确联动。如果不支持，记录缺口。

4. **AC4: ModelInfo 类型验证** -- 检查 Swift SDK 的 ModelInfo 是否包含 TS SDK 的所有字段：value、displayName、description、supportsEffort、supportedEffortLevels、supportsAdaptiveThinking、supportsFastMode。

5. **AC5: ModelUsage 类型验证** -- 检查 Swift SDK 的 token 使用量追踪是否包含 TS SDK `ModelUsage` 的所有字段：inputTokens、outputTokens、cacheReadInputTokens、cacheCreationInputTokens、webSearchRequests、costUSD、contextWindow、maxOutputTokens。

6. **AC6: fallbackModel 行为验证** -- 检查 Swift SDK 是否支持 `fallbackModel` 选项。如果主模型失败，是否自动切换到备用模型。如果不支持，记录缺口。

7. **AC7: 运行时模型切换验证** -- 使用 `agent.switchModel()` 在查询间切换模型，验证：
   - 切换后后续查询使用新模型
   - costBreakdown 包含两个模型的独立计数
   - 空字符串模型名抛出错误

8. **AC8: 缓存 Token 追踪验证** -- 验证 Swift SDK 的 TokenUsage 包含 cacheCreationInputTokens 和 cacheReadInputTokens 字段，并在使用 prompt caching 时正确更新。

9. **AC9: 兼容性报告输出** -- 对 ThinkingConfig、effort、ModelInfo、ModelUsage、fallbackModel 输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: ThinkingConfig 三种模式测试 (AC: #2)
  - [ ] adaptive 模式查询
  - [ ] enabled(budgetTokens:) 模式查询
  - [ ] disabled 模式查询
- [ ] Task 3: effort 级别和联动测试 (AC: #3)
  - [ ] 检查 effort 参数支持
  - [ ] 测试 effort + thinking 联动
- [ ] Task 4: ModelInfo/ModelUsage 类型检查 (AC: #4, #5, #8)
  - [ ] 检查 ModelInfo 字段完整性
  - [ ] 检查 TokenUsage/ModelUsage 字段
  - [ ] 验证缓存 token 追踪
- [ ] Task 5: fallbackModel 和模型切换测试 (AC: #6, #7)
  - [ ] 检查 fallbackModel 支持
  - [ ] 测试 switchModel 行为
  - [ ] 验证 costBreakdown
- [ ] Task 6: 生成兼容性报告 (AC: #9)

## Dev Notes

### 参考文档

- [TypeScript SDK] ThinkingConfig、ModelInfo、ModelUsage、effort、fallbackModel
- [Source] Sources/OpenAgentSDK/Types/ThinkingConfig.swift — ThinkingConfig enum
- [Source] Sources/OpenAgentSDK/Types/TokenUsage.swift — TokenUsage struct
- [Source] Sources/OpenAgentSDK/Types/ModelInfo.swift — ModelInfo struct
- [Source] Sources/OpenAgentSDK/Core/Agent.swift — switchModel 方法
