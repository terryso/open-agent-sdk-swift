# Story 2.3: 预算强制执行

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望设置每次 Agent 调用的最大美元预算，
以便失控的 Agent 循环不会耗尽我的 API 额度。

## Acceptance Criteria

1. **AC1: 配置预算后超限停止（阻塞路径）** — 给定配置了 `maxBudgetUsd=0.50` 的 Agent，当执行期间累积成本超过 $0.50，则智能循环立即停止（FR8），且返回带有成本摘要和使用轮次的优雅错误结果（NFR16），且应用不会崩溃

2. **AC2: 配置预算后超限停止（流式路径）** — 给定配置了 `maxBudgetUsd=0.50` 的 Agent，当流式执行期间累积成本超过 $0.50，则流发出 `.errorMaxBudgetUsd` 结果事件后终止，包含成本摘要和使用轮次，且流不会崩溃

3. **AC3: 未配置预算时无检查** — 给定未配置预算限制的 Agent（`maxBudgetUsd: nil`），当 Agent 执行，则追踪成本但不执行预算检查，行为与 Story 2.2 完全一致

4. **AC4: 阻塞路径返回正确状态** — 给定预算超限的阻塞式调用，当开发者检查 `QueryResult`，则 `status == .errorMaxBudgetUsd`，且 `totalCostUsd` 反映超限时的累积成本，且 `numTurns` 反映已执行轮次

5. **AC5: 流式路径返回正确子类型** — 给定预算超限的流式调用，当开发者检查最终 `.result` 事件，则 `subtype == .errorMaxBudgetUsd`，且 `totalCostUsd` 反映超限时的累积成本，且 `numTurns` 反映已执行轮次

6. **AC6: 预算检查时机正确** — 给定正在执行的 Agent，当每轮 API 调用完成后累积成本，则在下一次循环迭代开始前检查预算，且已累积的文本结果被保留在返回值中

## Tasks / Subtasks

- [x] Task 1: 添加 `QueryStatus.errorMaxBudgetUsd` 枚举值 (AC: #1, #4)
  - [x] 1.1: 在 `QueryStatus` 枚举中添加 `case errorMaxBudgetUsd`
  - [x] 1.2: 确认 `SDKMessage.ResultData.Subtype.errorMaxBudgetUsd` 已存在（无需修改）

- [x] Task 2: 在 `Agent.prompt()` 中添加预算检查 (AC: #1, #3, #4, #6)
  - [x] 2.1: 在成本累积之后（`totalCostUsd += estimateCost(...)` 之后）添加预算检查：`if let budget = options.maxBudgetUsd, totalCostUsd > budget { ... }`
  - [x] 2.2: 预算超限时设置 `status = .errorMaxBudgetUsd` 并 `break` 跳出循环
  - [x] 2.3: 确保 `QueryResult` 返回超限时的 `totalCostUsd`、`numTurns`、`text`（部分结果）

- [x] Task 3: 在 `Agent.stream()` 中添加预算检查 (AC: #2, #3, #5, #6)
  - [x] 3.1: 在闭包前捕获 `options.maxBudgetUsd`：`let capturedMaxBudgetUsd = options.maxBudgetUsd`
  - [x] 3.2: 在 `messageDelta` 处理的成本累积之后，检查预算：`if let budget = capturedMaxBudgetUsd, totalCostUsd > budget { ... }`
  - [x] 3.3: 预算超限时 yield `.result(SDKMessage.ResultData(subtype: .errorMaxBudgetUsd, ...))` 并 `return`
  - [x] 3.4: 在 `messageStop` 之后（turnCount 递增后）也检查预算（双重保障）
  - [x] 3.5: 确保流式路径返回超限时的 `totalCostUsd`、`numTurns`、`text`（部分结果）

- [x] Task 4: 编写预算强制执行测试 (AC: #1-#6)
  - [x] 4.1: 测试 AC1 — 阻塞路径预算超限立即停止并返回正确状态
  - [x] 4.2: 测试 AC2 — 流式路径预算超限立即停止并返回正确子类型
  - [x] 4.3: 测试 AC3 — 未配置预算时正常执行不中断
  - [x] 4.4: 测试 AC4 — 阻塞路径返回 totalCostUsd 和 numTurns 正确
  - [x] 4.5: 测试 AC5 — 流式路径返回 totalCostUsd 和 numTurns 正确
  - [x] 4.6: 测试 AC6 — 预算检查在成本累积后、下一轮前执行

- [x] Task 5: 更新现有测试以适配新增枚举值 (AC: #1, #4)
  - [x] 5.1: 检查并更新所有 `switch` 或模式匹配 `QueryStatus` 的测试代码
  - [x] 5.2: 确认现有测试不受预算检查影响（默认 `maxBudgetUsd: nil`）

## Dev Notes

### 核心设计决策

**本 story 的范围限制：**
- **仅实现预算检查和循环中断**（FR8）
- **不实现重试逻辑**（NFR15，Story 2.4 的范围）
- **不实现 max_tokens 恢复**（FR5，Story 2.4 的范围）
- **不实现自动压缩**（FR9，Story 2.5 的范围）
- **不修改 `estimateCost()` 或 `MODEL_PRICING`**（Story 2.2 已完成）

**关键洞察：** Story 2.2 已经在 `prompt()` 和 `stream()` 中追踪了 `totalCostUsd`。本 story 只需要在每次成本累积后添加预算比较和循环中断逻辑。

### 已有基础设施（无需修改，直接使用）

以下类型和字段已在之前 story 中实现，本 story 直接使用：

| 类型 | 位置 | 说明 |
|------|------|------|
| `AgentOptions.maxBudgetUsd: Double?` | `Types/AgentTypes.swift:11` | 预算配置，默认 `nil`（无限制） |
| `SDKError.budgetExceeded(cost:turnsUsed:)` | `Types/ErrorTypes.swift:7` | 预算超限错误类型 |
| `SDKMessage.ResultData.Subtype.errorMaxBudgetUsd` | `Types/SDKMessage.swift:103` | 流式结果子类型 |
| `estimateCost(model:usage:)` | `Utils/Tokens.swift` | 成本计算函数 |
| `totalCostUsd` 追踪 | `Core/Agent.swift` | 两个方法中已累积 |

### 需要新增的类型

**`QueryStatus` 需要新增枚举值：**

```swift
// Types/AgentTypes.swift — QueryStatus
public enum QueryStatus: String, Sendable, Equatable {
    case success
    case errorMaxTurns
    case errorDuringExecution
    case errorMaxBudgetUsd  // ← 新增
}
```

### 预算检查集成点

**prompt() 中的集成点（第 158 行之后）：**

```swift
// 现有代码（Story 2.2 已实现）:
if let usage = response["usage"] as? [String: Any] {
    let turnUsage = TokenUsage(
        inputTokens: usage["input_tokens"] as? Int ?? 0,
        outputTokens: usage["output_tokens"] as? Int ?? 0
    )
    totalUsage = totalUsage + turnUsage
    totalCostUsd += estimateCost(model: model, usage: turnUsage)
}

// ↓↓↓ 新增预算检查 ↓↓↓
if let budget = options.maxBudgetUsd, totalCostUsd > budget {
    status = .errorMaxBudgetUsd
    break
}
```

**stream() 中的集成点（messageDelta 处理，第 297 行之后）：**

```swift
// 现有代码（Story 2.2 已实现）:
case .messageDelta(let delta, let usage):
    currentStopReason = delta["stop_reason"] as? String ?? ""
    let turnUsage = TokenUsage(
        inputTokens: usage["input_tokens"] as? Int ?? 0,
        outputTokens: usage["output_tokens"] as? Int ?? 0
    )
    totalUsage = totalUsage + turnUsage
    totalCostUsd += estimateCost(model: currentModel, usage: turnUsage)
    // ↓↓↓ 新增预算检查 ↓↓↓
    if let budget = capturedMaxBudgetUsd, totalCostUsd > budget {
        // yield result with .errorMaxBudgetUsd and return
    }
```

**stream() 中还需要在 messageStop 后检查（第 305 行之后）：**

```swift
case .messageStop:
    turnCount += 1
    continuation.yield(.assistant(...))
    messages.append(...)
    // ↓↓↓ 新增：轮结束后检查预算（双重保障） ↓↓↓
    if let budget = capturedMaxBudgetUsd, totalCostUsd > budget {
        // yield result with .errorMaxBudgetUsd and return
    }
```

### stream() 的 Swift 6 并发处理

`options.maxBudgetUsd` 是 `AgentOptions` 的属性，需要在 `AsyncStream` 闭包前捕获：

```swift
// 在 stream() 方法中，与其他 captured* 值一起捕获
let capturedMaxBudgetUsd = options.maxBudgetUsd
```

这是一个简单的 `Double?` 值（值类型），直接捕获即可，无需序列化。

### 反模式警告

- **禁止**在预算超限时抛出异常或 crash — 必须返回优雅的部分结果（NFR16）
- **禁止**在未配置预算时执行任何检查 — `maxBudgetUsd: nil` 表示无限制
- **禁止**修改 `estimateCost()` 或 `MODEL_PRICING` — Story 2.2 的范围
- **禁止**使用 `>=` 比较预算 — 使用 `>`（累积成本**超过**预算时触发）
- **禁止**在 `messageStart` 中检查预算 — input token 成本可能低于预算，应等完整轮次结束后再检查
- **禁止**将预算检查放在 API 调用之前 — 应在每次 API 调用返回并累积成本后检查
- **禁止**丢失部分结果 — 预算超限时已收集的 `text`、`totalUsage` 必须包含在返回值中
- **禁止**使用 force-unwrap (`!`) — 使用 `guard let` / `if let` / `??`

### TypeScript SDK 参考实现

```typescript
// TS SDK: engine.ts — QueryEngine 中的预算检查

// 每次 API 岸应后累积成本并检查
this.totalCost += estimateCost(this.config.model, response.usage)

// 预算检查 — 在每次 API 调用后
if (this.config.maxBudgetUsd !== undefined && this.totalCost > this.config.maxBudgetUsd) {
    // 中断循环，返回 error_max_budget_usd 结果
    return {
        status: "error_max_budget_usd",
        text: lastAssistantText,
        total_cost_usd: this.totalCost,
        turns_used: turnCount,
        usage: this.totalUsage,
    }
}
```

### 与后续 Story 的关系

- **Story 2.4**（LLM API 重试与 max_tokens 恢复）将使用与本 story 相同的循环中断模式，并添加重试逻辑
- **Story 2.5**（对话自动压缩）将在预算检查前可能触发压缩以节省 token
- **Story 3.3**（工具执行器）可能增加工具执行的 token 成本

### 测试策略

**使用 MockURLProtocol 模拟 API 响应：**

需要模拟多轮 API 调用，其中累积成本逐步增长直到超过预算限制。关键测试场景：

1. **单轮超限**：设置极低预算（$0.001），第一轮即超限
2. **多轮累积超限**：设置中等预算，第 2-3 轮超限
3. **刚好不超限**：累积成本略低于预算，正常完成
4. **无预算限制**：`maxBudgetUsd: nil`，多轮正常执行
5. **流式超限**：在 `messageDelta` 事件中累积成本触发超限

### Project Structure Notes

本 story 修改的文件：
```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift ✎                    — 在 prompt() 和 stream() 中添加预算检查（修改）
├── Types/
│   └── AgentTypes.swift ✎              — QueryStatus 添加 errorMaxBudgetUsd 枚举值（修改）

Tests/OpenAgentSDKTests/
└── Core/
    └── BudgetEnforcementTests.swift ★   — 预算强制执行测试（新建）
```

**无需修改的文件：**
- `Types/SDKMessage.swift` — `ResultData.Subtype.errorMaxBudgetUsd` 已存在
- `Types/ErrorTypes.swift` — `SDKError.budgetExceeded` 已存在
- `Types/AgentTypes.swift` 中的 `AgentOptions` — `maxBudgetUsd` 字段已存在
- `Utils/Tokens.swift` — `estimateCost()` 已存在

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#AD11] — 预算跟踪与循环中断
- [Source: _bmad-output/planning-artifacts/architecture.md#ErrorModel] — budgetExceeded 错误类型
- [Source: _bmad-output/planning-artifacts/prd.md#FR8] — 开发者可以设置最大预算（美元）
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 预算超限条件产生优雅错误结果
- [Source: _bmad-output/planning-artifacts/epics.md#Story-2.3] — Story 定义和验收标准
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L158] — prompt() 中成本累积的精确位置
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L297] — stream() 中 messageDelta 成本累积的精确位置
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L72] — QueryStatus 枚举（需添加 .errorMaxBudgetUsd）
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift#L103] — ResultData.Subtype.errorMaxBudgetUsd（已存在）
- [Source: Sources/OpenAgentSDK/Types/ErrorTypes.swift#L7] — SDKError.budgetExceeded（已存在）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L11] — AgentOptions.maxBudgetUsd（已存在）
- [Source: _bmad-output/implementation-artifacts/2-2-token-usage-cost-tracking.md] — Story 2.2 完成记录和 dev notes

### Previous Story Intelligence (Story 2.2)

**已建立的代码模式：**
1. `prompt()` 和 `stream()` 都使用 `totalCostUsd += estimateCost(model:usage:)` 模式累积成本
2. `stream()` 中成本在两个地方累积：`messageStart`（input tokens）和 `messageDelta`（output tokens）
3. `stream()` 需要捕获值跨越 AsyncStream 闭包边界（Swift 6 Sendable）
4. 错误路径使用 `yieldStreamError` 静态方法统一处理
5. `computeDurationMs` 是 `private static func`
6. 测试使用 MockURLProtocol 模拟 API 响应

**Story 2.2 遇到的问题和解决方案：**
- CI 初始失败：流式路径中 `message_start` 的 `input_tokens` 成本未计算。修复在 `1ec6e26` 中提交
- 成本计算在 `message_start` 和 `message_delta` 两个事件中分别进行（input 和 output tokens）
- 所有 242 个测试通过

**对本 story 的影响：**
- 预算检查应放在 `messageDelta` 的成本累积之后（因为那时有完整的轮次成本信息）
- 同时在 `messageStop` 后也需要检查（作为完整轮结束的确认点）
- 需要正确处理 `messageStart` 的成本累积可能触发预算超限的边界情况

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
