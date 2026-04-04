# Story 2.2: Token 使用量与成本追踪

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望追踪每次 Agent 调用的累积 token 使用量和预估成本，
以便我可以监控和控制我的 API 支出。

## Acceptance Criteria

1. **AC1: 每轮累积 Token 使用量** — 给定正在执行智能循环的 Agent，当每次 LLM API 调用完成，则输入和输出 token 计数在使用量追踪器中累积（FR7），且使用 `MODEL_PRICING` 查找表计算预估成本

2. **AC2: QueryResult 包含成本信息** — 给定完成的 Agent 阻塞式调用，当开发者检查 `QueryResult`，则总输入 token、输出 token 和以美元计的预估成本可用

3. **AC3: SDKMessage.ResultData 包含成本信息** — 给定完成的 Agent 流式调用，当开发者检查最终 `.result` 事件，则 `ResultData` 包含以美元计的预估成本

4. **AC4: 多模型分别计价** — 给定 Agent 依次使用不同模型，当计算成本，则每个模型的定价根据其 token 成本正确应用

5. **AC5: 未知模型默认定价** — 给定 Agent 使用的模型不在 `MODEL_PRICING` 表中，当计算成本，则使用默认定价（等同于 claude-sonnet 定价）而不崩溃

6. **AC6: MODEL_PRICING 与 TS SDK 同步** — 给定 `MODEL_PRICING` 字典，当开发者查看定价条目，则包含 TS SDK 中所有 Anthropic 模型的定价（不含 OpenAI/DeepSeek — 非 Anthropic 模型通过自定义 Base URL 支持）

## Tasks / Subtasks

- [ ] Task 1: 创建 `Utils/Tokens.swift` 工具文件 (AC: #1, #4, #5, #6)
  - [ ] 1.1: 实现 `public func estimateCost(model: String, usage: TokenUsage) -> Double` — 根据 `MODEL_PRICING` 表计算 USD 成本
  - [ ] 1.2: 实现 `public func getContextWindowSize(model: String) -> Int` — 返回模型的上下文窗口大小（Story 2.5 自动压缩将使用此函数）
  - [ ] 1.3: 实现 `public let AUTOCOMPACT_BUFFER_TOKENS: Int = 13_000` 常量（Story 2.5 将使用此常量）
  - [ ] 1.4: 在 `estimateCost()` 中使用模糊匹配（`model.contains(key)`）以匹配带版本后缀的模型名（如 `claude-sonnet-4-6-20250514`）
  - [ ] 1.5: 当模型不匹配任何条目时使用默认定价（`input: 3.0 / 1_000_000, output: 15.0 / 1_000_000`，等同于 claude-sonnet 定价）

- [ ] Task 2: 为 `QueryResult` 添加成本字段 (AC: #2)
  - [ ] 2.1: 在 `QueryResult` struct 中添加 `public let totalCostUsd: Double` 属性
  - [ ] 2.2: 更新 `QueryResult.init()` 以接受 `totalCostUsd` 参数（带默认值 `0.0` 以保持向后兼容）

- [ ] Task 3: 为 `SDKMessage.ResultData` 添加成本字段 (AC: #3)
  - [ ] 3.1: 在 `SDKMessage.ResultData` struct 中添加 `public let totalCostUsd: Double` 属性
  - [ ] 3.2: 更新 `ResultData.init()` 以接受 `totalCostUsd` 参数（带默认值 `0.0` 以保持向后兼容）

- [ ] Task 4: 在 `Agent.prompt()` 中集成成本追踪 (AC: #1, #2, #4)
  - [ ] 4.1: 在 `prompt()` 方法中添加 `var totalCostUsd: Double = 0.0` 变量
  - [ ] 4.2: 在每轮 API 调用完成后，调用 `estimateCost(model:usage:)` 计算本轮成本并累加到 `totalCostUsd`
  - [ ] 4.3: 在返回 `QueryResult` 时传入 `totalCostUsd` 值

- [ ] Task 5: 在 `Agent.stream()` 中集成成本追踪 (AC: #1, #3, #4)
  - [ ] 5.1: 在 `stream()` 方法中添加 `var totalCostUsd: Double = 0.0` 变量
  - [ ] 5.2: 在 `message_start` 事件中提取 `input_tokens` 后，暂不计算成本（需要等 output_tokens）
  - [ ] 5.3: 在 `message_delta` 事件中提取 usage 后，调用 `estimateCost()` 计算本轮成本并累加到 `totalCostUsd`
  - [ ] 5.4: 在最终 yield `.result()` 时传入 `totalCostUsd` 值
  - [ ] 5.5: 在所有错误路径的 `.result()` 中也传入当前累积的 `totalCostUsd` 值

- [ ] Task 6: 编写 `Tests/OpenAgentSDKTests/Utils/TokensTests.swift` (AC: #1-#6)
  - [ ] 6.1: 测试 AC1 — estimateCost() 正确计算已知模型成本
  - [ ] 6.2: 测试 AC4 — 不同模型使用不同定价
  - [ ] 6.3: 测试 AC5 — 未知模型使用默认定价
  - [ ] 6.4: 测试 AC6 — MODEL_PRICING 包含所有 Anthropic 模型条目
  - [ ] 6.5: 测试带版本后缀的模型名模糊匹配
  - [ ] 6.6: 测试 getContextWindowSize() 返回正确值
  - [ ] 6.7: 测试 QueryResult 包含 totalCostUsd 字段
  - [ ] 6.8: 测试 SDKMessage.ResultData 包含 totalCostUsd 字段

- [ ] Task 7: 更新现有测试以适配新增字段 (AC: #2, #3)
  - [ ] 7.1: 更新 `QueryEngineTests.swift` 中所有 `QueryResult` 构造以包含 `totalCostUsd`
  - [ ] 7.2: 更新 `StreamTests.swift` 中所有 `ResultData` 构造以包含 `totalCostUsd`

## Dev Notes

### 核心设计决策

**本 story 的范围限制：**
- **仅实现 token 使用量累积和成本计算**（FR7）
- **不实现预算强制执行**（FR8，Story 2.3 的范围）— `AgentOptions.maxBudgetUsd` 字段已存在但本 story 不使用它
- **不实现自动压缩**（FR9，Story 2.5 的范围）— `getContextWindowSize()` 和 `AUTOCOMPACT_BUFFER_TOKENS` 在本 story 中定义但不在循环中使用
- **不实现 max_tokens 恢复**（FR5，Story 2.4 的范围）
- **不实现重试**（NFR15，Story 2.4 的范围）
- **不修改 `MODEL_PRICING` 表的 Anthropic 条目**（已在 Story 1.1 中定义，只需确认一致）

### 实现策略

**关键洞察：** `prompt()` 和 `stream()` 方法已经在累积 `TokenUsage`（自 Story 1.5 和 2.1）。本 story 只需要：
1. 创建 `estimateCost()` 函数将 `TokenUsage` + 模型名转换为 USD 成本
2. 在两个方法中添加 `totalCostUsd` 累积变量
3. 在 `QueryResult` 和 `ResultData` 中暴露成本值

**成本计算时机：**
- **prompt()**: 在每次 `client.sendMessage()` 返回后，解析 usage 并计算该轮成本
- **stream()**: 在 `message_delta` 事件中收到 output_tokens 后，计算该轮成本
  - 注意：`message_start` 中的 `input_tokens` 已在 Story 2.1 的 commit `d9ee242` 中提取并累积，但尚未用于成本计算

### 已有代码与集成点

**本 story 直接使用的已完成类型：**
- `TokenUsage`（`Types/TokenUsage.swift`）— 已有 `inputTokens`、`outputTokens`、`+` 运算符、`totalTokens` 计算属性
- `MODEL_PRICING`（`Types/ModelInfo.swift`）— 已有 8 个 Anthropic 模型条目，每个包含 `input` 和 `output` 每百万 token 价格
- `ModelPricing`（`Types/ModelInfo.swift`）— 已有 `input: Double` 和 `output: Double` 属性
- `Agent` 类（`Core/Agent.swift`）— 已有 `prompt()` 和 `stream()` 方法，两者都累积 `totalUsage: TokenUsage`
- `QueryResult`（`Types/AgentTypes.swift`）— blocking 响应类型
- `SDKMessage.ResultData`（`Types/SDKMessage.swift`）— streaming 响应结果类型

**需要修改的文件：**
- `Types/AgentTypes.swift` — 添加 `totalCostUsd` 到 `QueryResult`
- `Types/SDKMessage.swift` — 添加 `totalCostUsd` 到 `ResultData`
- `Core/Agent.swift` — 在 `prompt()` 和 `stream()` 中集成成本追踪

**需要新建的文件：**
- `Utils/Tokens.swift` — `estimateCost()`、`getContextWindowSize()`、`AUTOCOMPACT_BUFFER_TOKENS`
- `Tests/OpenAgentSDKTests/Utils/TokensTests.swift` — 成本计算和工具函数测试

### TypeScript SDK 参考实现

```typescript
// TS SDK: utils/tokens.ts

// 模糊匹配策略 — 使用 model.includes(key) 匹配带版本后缀的模型
export function estimateCost(
  model: string,
  usage: { input_tokens: number; output_tokens: number },
): number {
  const pricing = Object.entries(MODEL_PRICING).find(([key]) =>
    model.includes(key),
  )?.[1] ?? { input: 3 / 1_000_000, output: 15 / 1_000_000 }

  return usage.input_tokens * pricing.input + usage.output_tokens * pricing.output
}
```

```typescript
// TS SDK: engine.ts — QueryEngine 中的使用方式

private totalCost = 0

// 每次 API 响应后累积成本
this.totalCost += estimateCost(this.config.model, response.usage)

// 最终结果中包含成本
total_cost_usd: this.totalCost,
cost: this.totalCost,  // deprecated alias
```

**Swift 适配要点：**
- TS SDK 使用 `model.includes(key)` 模糊匹配（对应 Swift `model.contains(key)`）
- TS SDK 的 `estimateCost` 接受 `{ input_tokens, output_tokens }` 对象（对应 Swift `TokenUsage` struct）
- TS SDK 在结果中同时有 `total_cost_usd`（新）和 `cost`（已弃用）— Swift 版本只需 `totalCostUsd`
- TS SDK 有 OpenAI/DeepSeek 模型定价 — Swift 版本仅包含 Anthropic 模型（非 Anthropic 模型通过自定义 Base URL 支持，定价由用户自行管理）

### estimateCost() 实现参考

```swift
// Utils/Tokens.swift

/// Estimate cost in USD from token usage and model name.
///
/// Uses fuzzy matching via `model.contains(key)` to match versioned model names
/// (e.g., "claude-sonnet-4-6-20250514" matches "claude-sonnet-4-6").
/// Falls back to claude-sonnet-equivalent pricing for unknown models.
public func estimateCost(model: String, usage: TokenUsage) -> Double {
    let match = MODEL_PRICING.first { (key, _) in model.contains(key) }
    let pricing = match?.value ?? ModelPricing(
        input: 3.0 / 1_000_000,
        output: 15.0 / 1_000_000
    )
    return Double(usage.inputTokens) * pricing.input
         + Double(usage.outputTokens) * pricing.output
}
```

### prompt() 中的成本追踪集成点

在 `Core/Agent.swift` 的 `prompt()` 方法中，成本追踪的集成点如下：

```swift
// 现有代码（Story 1.5 已实现）:
// 解析 usage from response
if let usage = response["usage"] as? [String: Any] {
    let turnUsage = TokenUsage(
        inputTokens: usage["input_tokens"] as? Int ?? 0,
        outputTokens: usage["output_tokens"] as? Int ?? 0
    )
    totalUsage = totalUsage + turnUsage
}

// 新增：在 usage 累积之后计算本轮成本
totalCostUsd += estimateCost(model: model, usage: turnUsage)

// 现有代码返回 QueryResult:
return QueryResult(
    text: lastAssistantText,
    usage: totalUsage,
    numTurns: turnCount,
    durationMs: Self.computeDurationMs(ContinuousClock.now - startTime),
    messages: [],
    status: status
    // 新增: totalCostUsd: totalCostUsd
)
```

### stream() 中的成本追踪集成点

在 `Core/Agent.swift` 的 `stream()` 方法中，成本追踪的集成点如下：

```swift
// 现有代码（Story 2.1 已实现）— message_delta 事件处理:
case .messageDelta(let delta, let usage):
    currentStopReason = delta["stop_reason"] as? String ?? ""
    let turnUsage = TokenUsage(
        inputTokens: usage["input_tokens"] as? Int ?? 0,
        outputTokens: usage["output_tokens"] as? Int ?? 0
    )
    totalUsage = totalUsage + turnUsage
    // 新增：在该轮结束时计算成本（此时有 input + output tokens）
    // 注意：message_start 中的 input_tokens 已在之前累积到 totalUsage
    // message_delta 提供本轮的增量 output_tokens
    // 需要计算"本轮完整 usage"的成本，而非仅增量的成本
```

**重要设计决策 — 成本计算粒度：**
- TS SDK 在每次 API 响应后用**该轮完整 usage** 调用 `estimateCost()`
- Swift `stream()` 中，`message_start` 的 `input_tokens` 和 `message_delta` 的 `output_tokens` 是**增量值**（分别代表本轮的输入和输出 token）
- 最佳方案：在 `message_delta` 中收到 `output_tokens` 后，组合 `input_tokens`（从 `message_start`）和 `output_tokens`（从 `message_delta`）为完整的本轮 usage，调用 `estimateCost()`
- 更简单方案（推荐）：直接在每轮结束时用**累积的 totalUsage 差值**计算成本，或在 `message_delta` 中用本轮增量 usage 计算成本

**推荐实现（简单方案）：**
在 `stream()` 的 `message_delta` 处理中，将 `input_tokens` 和 `output_tokens` 视为本轮增量：

```swift
case .messageDelta(let delta, let usage):
    currentStopReason = delta["stop_reason"] as? String ?? ""
    let turnInputTokens = usage["input_tokens"] as? Int ?? 0
    let turnOutputTokens = usage["output_tokens"] as? Int ?? 0
    let turnUsage = TokenUsage(
        inputTokens: turnInputTokens,
        outputTokens: turnOutputTokens
    )
    totalUsage = totalUsage + turnUsage
    totalCostUsd += estimateCost(model: currentModel, usage: turnUsage)
```

注意：`message_start` 中提取的 `input_tokens`（Story 2.1 commit `d9ee242`）已累积到 `totalUsage`。需要仔细审查是否会导致重复计算。查看现有代码，`message_start` 中累积的 `input_tokens` 和 `message_delta` 中累积的 `input_tokens` 可能代表同一个值（Anthropic API 在 `message_start` 的 usage 中报告初始 input_tokens，在 `message_delta` 的 usage 中可能不包含重复的 input_tokens）。

**结论：** 需要实际测试 Anthropic API 行为。最安全的做法是只在一个点计算成本——在 `message_delta` 中（因为那时有完整的该轮 token 信息）。`message_start` 中的 `input_tokens` 累积到 `totalUsage` 用于最终报告，成本计算只在 `message_delta` 时进行。

### TokenUsage 与 MODEL_PRICING 的数据流

```
Anthropic API Response
    │
    ├── prompt() 路径:
    │   └── response["usage"] → TokenUsage → totalUsage 累加
    │                                  └── estimateCost(model, turnUsage) → totalCostUsd 累加
    │
    └── stream() 路径:
        ├── message_start → usage.input_tokens → totalUsage 累加
        └── message_delta → usage.output_tokens → totalUsage 累加
                                         └── estimateCost(model, turnUsage) → totalCostUsd 累加

最终输出:
    QueryResult.usage = totalUsage (TokenUsage)
    QueryResult.totalCostUsd = totalCostUsd (Double)
    SDKMessage.ResultData.usage = totalUsage (TokenUsage?)
    SDKMessage.ResultData.totalCostUsd = totalCostUsd (Double)
```

### 反模式警告

- **禁止**在 `estimateCost()` 中使用精确匹配（`model == key`）— Anthropic 模型名包含日期后缀如 `-20250514`，必须使用模糊匹配 `model.contains(key)`
- **禁止**对未知模型返回 0 成本或抛出错误 — 使用默认定价（NFR16: 优雅降级，不崩溃）
- **禁止**将 `estimateCost` 放在 `Types/` 目录 — 它是工具函数，属于 `Utils/Tokens.swift`（架构规则：Utils/ 是叶节点）
- **禁止**使用 force-unwrap (`!`) — 使用 `guard let` / `if let` / `??` 默认值
- **禁止**使用 Codable 解析 API 响应中的 usage — 使用 `[String: Any]` 原始字典（项目上下文规则 #5、#41）
- **禁止**在 `prompt()` 或 `stream()` 中实现预算检查 — Story 2.3 的范围
- **禁止**创建空的或占位文件 — 每个文件必须有完整实现
- **禁止**修改 `MODEL_PRICING` 字典中已有的 Anthropic 条目 — 只需确认与 TS SDK 一致
- **禁止**在 Swift 版本中包含 OpenAI/DeepSeek 模型定价 — 本 SDK 仅支持 Anthropic API
- **禁止**修改 `TokenUsage` struct — 已有 `+` 运算符和所有需要的字段

### 与后续 Story 的关系

- **Story 2.3**（预算执行）将使用 `totalCostUsd` 在每轮结束后检查 `maxBudgetUsd` 限制，超出时中断循环并返回 `.errorMaxBudgetUsd` 结果
- **Story 2.5**（自动压缩）将使用 `getContextWindowSize()` 和 `AUTOCOMPACT_BUFFER_TOKENS` 计算压缩阈值
- **Story 3.3**（工具执行器）可能需要修改 token 累积逻辑以包含工具结果的 token

### 测试策略

**使用纯单元测试验证成本计算逻辑（不需要 MockURLProtocol）：**

```swift
// TokensTests.swift — 纯计算逻辑测试

func testEstimateCost_KnownModel() {
    let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
    let cost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
    // input: 1000 * (3.0 / 1_000_000) = 0.003
    // output: 500 * (15.0 / 1_000_000) = 0.0075
    // total: 0.0105
    XCTAssertEqual(cost, 0.0105, accuracy: 0.0001)
}

func testEstimateCost_UnknownModel_UsesDefault() {
    let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
    let cost = estimateCost(model: "claude-unknown-model", usage: usage)
    // 默认定价等同于 claude-sonnet
    XCTAssertEqual(cost, 0.0105, accuracy: 0.0001)
}

func testEstimateCost_VersionedModelName() {
    let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
    let cost = estimateCost(model: "claude-sonnet-4-6-20250514", usage: usage)
    // 应匹配 "claude-sonnet-4-6" 条目
    XCTAssertEqual(cost, 0.0105, accuracy: 0.0001)
}
```

**使用 MockURLProtocol 验证集成测试（在现有测试中更新）：**

在 `QueryEngineTests.swift` 和 `StreamTests.swift` 中验证 `totalCostUsd` 字段在完整调用流程中被正确填充。

### Project Structure Notes

本 story 创建/修改带标记的部分：
```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift ✎                    — 在 prompt() 和 stream() 中添加成本追踪（修改）
├── Types/
│   ├── AgentTypes.swift ✎              — QueryResult 添加 totalCostUsd 字段（修改）
│   ├── SDKMessage.swift ✎              — ResultData 添加 totalCostUsd 字段（修改）
│   └── ModelInfo.swift                  — 无修改（MODEL_PRICING 已完整）
├── Utils/
│   └── Tokens.swift ★                   — estimateCost()、getContextWindowSize()、AUTOCOMPACT_BUFFER_TOKENS（新建）
└── OpenAgentSDK.swift                   — 无修改

Tests/OpenAgentSDKTests/
├── Core/
│   ├── QueryEngineTests.swift ✎        — 更新 QueryResult 构造（修改）
│   └── StreamTests.swift ✎             — 更新 ResultData 构造（修改）
└── Utils/
    └── TokensTests.swift ★              — 成本计算测试（新建）
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#AD11] — 预算跟踪 — 模型定价查找表
- [Source: _bmad-output/planning-artifacts/architecture.md#Utils] — Utils/Tokens.swift — estimateTokens, estimateCost, MODEL_PRICING, 阈值
- [Source: _bmad-output/planning-artifacts/prd.md#FR7] — Agent 追踪每次调用的累积 token 使用量和预估成本
- [Source: _bmad-output/planning-artifacts/prd.md#FR8] — 开发者可以设置最大预算（Story 2.3 范围）
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 预算超限条件产生优雅错误结果
- [Source: _bmad-output/planning-artifacts/epics.md#Story-2.2] — Story 定义和验收标准
- [Source: _bmad-output/project-context.md#5] — Codable 与原始 JSON 边界
- [Source: _bmad-output/project-context.md#7] — 模块边界严格单向依赖
- [Source: _bmad-output/project-context.md#21] — internal 标记防止意外依赖
- [Source: _bmad-output/implementation-artifacts/2-1-async-stream-response.md] — Story 2.1 完成记录
- [Source: TypeScript SDK /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/utils/tokens.ts#estimateCost] — TS SDK 成本计算参考
- [Source: TypeScript SDK /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/engine.ts] — TS SDK QueryEngine 中的 totalCost 追踪参考
- [Source: Sources/OpenAgentSDK/Types/TokenUsage.swift] — 现有 TokenUsage struct（已支持 + 运算符和 cache token 字段）
- [Source: Sources/OpenAgentSDK/Types/ModelInfo.swift] — 现有 MODEL_PRICING 字典和 ModelPricing struct
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — 现有 prompt() 和 stream() 方法

### Previous Story Intelligence (Story 2.1)

**已建立的代码模式：**
1. `prompt()` 使用 `client.sendMessage()` 非流式 API，`stream()` 使用 `client.streamMessage()` 流式 API
2. 两者都使用 `totalUsage = totalUsage + turnUsage` 模式累积 token 使用量
3. `stream()` 使用 `AsyncStream<SDKMessage>` + `continuation.yield()` + `continuation.finish()` 模式
4. `stream()` 中通过 JSONSerialization 跨越 AsyncStream 闭包边界以满足 Swift 6 Sendable
5. `computeDurationMs` 已提取为 `private static func` 避免在 Task 闭包中捕获 `self`
6. 错误路径使用 `yieldStreamError` 静态方法统一处理

**Story 2.1 的完成记录要点：**
- `stream()` 中 `message_start` 事件提取 `input_tokens` 并累积到 `totalUsage`（commit `d9ee242`）
- `message_delta` 事件提取 `input_tokens` 和 `output_tokens` 并累积
- Swift 6 strict concurrency 要求 `[[String: Any]]` 序列化为 `Data` 跨越闭包边界
- XCTest 在 CLI-only 环境不可用（无 Xcode）— 测试通过 `swift build` 验证
- `computeDurationMs` 是 `private static func`

**需要特别注意的成本追踪集成风险：**
- `message_start` 和 `message_delta` 中都累积了 `input_tokens` — 可能导致重复计算。在添加成本追踪时需要验证 Anthropic API 的实际行为
- 最安全的做法：只在 `message_delta` 处计算该轮成本（因为那时有完整的 input + output 信息）

### Git Intelligence

**最近 5 次提交：**
- `d9ee242 fix: extract input_tokens from message_start event in stream()` — Story 2.1 修复，添加了 message_start 中的 input_tokens 提取
- `16ff89f feat: implement streaming response with AsyncStream (Story 2.1)` — 流式响应实现
- `8bdfffc fix: remove max_tokens break to allow loop continuation for multi-turn queries` — 循环终止逻辑修复
- `b548bcc feat: implement agent loop with blocking response (Story 1.5)` — 阻塞式智能循环
- `1f69c65 docs: add README (EN/CN), LICENSE and BMAD badge` — 文档

**已建立的提交模式：** `feat:` 用于新功能实现，`fix:` 用于修复

### 重要：input_tokens 重复计算问题

查看现有 `stream()` 代码，`input_tokens` 在两个地方被累积：
1. **message_start**（第 268-274 行）：`msgUsage["input_tokens"]` → 累积到 `totalUsage`
2. **message_delta**（第 283-288 行）：`usage["input_tokens"]` → 累积到 `totalUsage`

根据 Anthropic API 文档：
- `message_start` 中的 `usage.input_tokens` 是**该消息的总 input tokens**
- `message_delta` 中的 `usage.output_tokens` 是**该消息的总 output tokens**
- `message_delta` 中的 `usage.input_tokens` 可能不存在或为 0

**这意味着现有的 `totalUsage` 累积可能存在问题（重复计算 input_tokens）。** 本 story 应该：
1. 审查 Anthropic API 文档确认 `message_delta` 中是否包含 `input_tokens`
2. 如果 `message_delta` 不包含 `input_tokens`，则当前代码安全（`?? 0` 会返回 0）
3. 如果 `message_delta` 包含相同的 `input_tokens`，则需要修复重复计算问题

**成本计算策略：** 为避免重复计算，在 `message_delta` 时只计算 output tokens 的成本，在 `message_start` 时计算 input tokens 的成本。或者更简单地：在每轮结束时用差值计算。但最安全的做法是在 `message_delta`（轮结束时）用该轮的完整增量 usage 一次性计算成本。

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
