# Story 2.4: LLM API 重试与 max_tokens 恢复

Status: done

## Story

作为开发者，
我希望 Agent 重试失败的 API 调用并从 max_tokens 响应中恢复，
以便瞬态错误和上下文限制不会终止我的 Agent 会话。

## Acceptance Criteria

1. **AC1: 瞬态错误自动重试（阻塞路径）** — 给定因瞬态错误（HTTP 429、500、502、503、529）失败的 LLM API 调用，当错误被重试机制捕获，则请求以指数退避方式重试，最多 3 次（NFR15），且 SDK 不会崩溃或在错误消息中暴露 API 密钥

2. **AC2: 瞬态错误自动重试（流式路径）** — 给定因瞬态错误失败的流式 API 调用，当错误被重试机制捕获，则以指数退避方式重试最多 3 次，且流不崩溃，重试耗尽后优雅终止并发出错误结果

3. **AC3: max_tokens 续接恢复（阻塞路径）** — 给定 `stop_reason="max_tokens"` 的 LLM 响应，当智能循环处理此响应，则发送续接提示以恢复生成（FR5），且对话从截断处继续，且在返回部分结果前最多重试 3 次

4. **AC4: max_tokens 续接恢复（流式路径）** — 给定 `stop_reason="max_tokens"` 的流式 LLM 响应，当流处理此事件，则添加续接提示继续对话，最多重试 3 次，3 次后正常终止并返回已收集的部分结果

5. **AC5: 非瞬态错误不重试** — 给定因 HTTP 400、401、403 等非瞬态错误失败的 API 调用，当错误发生，则不执行重试，直接返回错误结果

6. **AC6: API 密钥安全** — 给定任何错误场景（重试中或重试耗尽后），当错误消息被记录或返回，则 API 密钥不被暴露

## Tasks / Subtasks

- [ ] Task 1: 创建 `Utils/Retry.swift` 重试工具 (AC: #1, #2, #5)
  - [ ] 1.1: 定义 `RetryConfig` 结构体（maxRetries: 3, baseDelayMs: 2000, maxDelayMs: 30000, retryableStatusCodes: [429, 500, 502, 503, 529]）
  - [ ] 1.2: 实现 `isRetryableError(_ error: Error) -> Bool` 函数 — 检查 SDKError 的 statusCode 是否在 retryableStatusCodes 中
  - [ ] 1.3: 实现 `getRetryDelay(attempt: Int, config: RetryConfig) -> UInt64` 函数 — 指数退避 + 25% 抖动
  - [ ] 1.4: 实现 `withRetry<T>(_:retryConfig:) async throws -> T` 函数 — 泛型重试包装器

- [ ] Task 2: 在 `Agent.prompt()` 中集成重试逻辑 (AC: #1, #3, #5, #6)
  - [ ] 2.1: 将 `client.sendMessage()` 调用包装在 `withRetry` 中
  - [ ] 2.2: 重试耗尽后返回 `.errorDuringExecution` 状态（保持现有行为）
  - [ ] 2.3: 将现有的 `max_tokens` 续接逻辑从简单追加 "continue" 改为带计数器限制的续接（最多 3 次）
  - [ ] 2.4: 确保 API 密钥不在错误消息中暴露（依赖 AnthropicClient 已有的安全处理）

- [ ] Task 3: 在 `Agent.stream()` 中集成重试逻辑 (AC: #2, #4, #5, #6)
  - [ ] 3.1: 将 `capturedClient.streamMessage()` 调用包装在 `withRetry` 中
  - [ ] 3.2: 重试耗尽后使用 `yieldStreamError` 优雅终止
  - [ ] 3.3: 添加 `maxTokensRecoveryCount` 计数器，限制 max_tokens 续接最多 3 次
  - [ ] 3.4: 确保 3 次 max_tokens 恢复后正常结束流（发出 result 事件）

- [ ] Task 4: 编写重试逻辑单元测试 (AC: #1, #2, #5)
  - [ ] 4.1: 测试 AC1 — 阻塞路径瞬态错误重试成功
  - [ ] 4.2: 测试 AC1 — 阻塞路径重试 3 次耗尽后返回错误
  - [ ] 4.3: 测试 AC2 — 流式路径瞬态错误重试成功
  - [ ] 4.4: 测试 AC5 — HTTP 401/403 非瞬态错误不重试直接返回

- [ ] Task 5: 编写 max_tokens 恢复测试 (AC: #3, #4)
  - [ ] 5.1: 测试 AC3 — 阻塞路径 max_tokens 恢复（续接后 end_turn 正常完成）
  - [ ] 5.2: 测试 AC3 — 阻塞路径 max_tokens 连续 3 次后返回部分结果
  - [ ] 5.3: 测试 AC4 — 流式路径 max_tokens 恢复
  - [ ] 5.4: 测试 AC6 — 所有错误场景中 API 密钥不被暴露

## Dev Notes

### 核心设计决策

**本 story 的范围限制：**
- **实现 API 调用重试逻辑**（NFR15）— 指数退避，最多 3 次
- **实现 max_tokens 恢复**（FR5）— 发送续接提示，最多 3 次
- **不实现自动压缩**（FR9，Story 2.5 的范围）
- **不实现微压缩**（FR10，Story 2.6 的范围）
- **不修改预算检查逻辑**（Story 2.3 已完成）

**关键洞察：** `Agent.prompt()` 已有基本的 max_tokens 处理（追加 "continue" 继续循环），但缺少两个关键能力：
1. **API 重试**：当前瞬态错误直接返回 `.errorDuringExecution`，没有重试
2. **max_tokens 恢复计数**：当前 max_tokens 会无限续接直到 maxTurns 耗尽，需要限制为最多 3 次

### 已有基础设施（直接使用）

| 类型 | 位置 | 说明 |
|------|------|------|
| `SDKError.apiError(statusCode:message:)` | `Types/ErrorTypes.swift:5` | API 错误类型，带 statusCode |
| `AnthropicClient.validateHTTPResponse()` | `API/AnthropicClient.swift:191` | 已自动清理 API 密钥（NFR6） |
| `prompt()` 中 `max_tokens` 续接 | `Core/Agent.swift:193` | 已追加 "continue"，需添加计数器 |
| `stream()` 中 `max_tokens` 续接 | `Core/Agent.swift:403` | 已追加 "continue"，需添加计数器 |
| `totalCostUsd` 追踪 | `Core/Agent.swift` | 两个方法中已累积 |
| `yieldStreamError` | `Core/Agent.swift:444` | 流式错误处理统一入口 |

### 需要新增的文件

**`Utils/Retry.swift` — 重试工具模块：**

```swift
// Sources/OpenAgentSDK/Utils/Retry.swift

import Foundation

/// 重试配置
struct RetryConfig: Sendable {
    let maxRetries: Int
    let baseDelayMs: Int
    let maxDelayMs: Int
    let retryableStatusCodes: Set<Int>

    static let `default` = RetryConfig(
        maxRetries: 3,
        baseDelayMs: 2000,
        maxDelayMs: 30000,
        retryableStatusCodes: [429, 500, 502, 503, 529]
    )
}

/// 判断错误是否可重试
func isRetryableError(_ error: Error) -> Bool {
    guard let sdkError = error as? SDKError,
          case .apiError(let statusCode, _) = sdkError else {
        return false
    }
    return RetryConfig.default.retryableStatusCodes.contains(statusCode)
}

/// 计算重试延迟（指数退避 + 抖动）
func getRetryDelay(attempt: Int, config: RetryConfig = .default) -> UInt64 {
    let delay = config.baseDelayMs * (1 << attempt) // 2^attempt
    let jitterMs = Int(Double(delay) * 0.25 * (Double.random(in: -1...1)))
    let totalMs = max(0, min(delay + jitterMs, config.maxDelayMs))
    return UInt64(totalMs * 1_000_000) // 转换为纳秒供 Task.sleep
}

/// 带重试的异步执行
func withRetry<T>(
    _ operation: @Sendable () async throws -> T,
    retryConfig: RetryConfig = .default
) async throws -> T {
    var lastError: Error?
    for attempt in 0...retryConfig.maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error
            if !isRetryableError(error) || attempt == retryConfig.maxRetries {
                throw error
            }
            let delayNs = getRetryDelay(attempt: attempt, config: retryConfig)
            try await Task.sleep(nanoseconds: delayNs)
        }
    }
    throw lastError!
}
```

### 集成点：prompt() 方法

**重试集成（替换现有的 do/catch）：**

当前代码（`Core/Agent.swift` 第 128-147 行）：
```swift
let response: [String: Any]
do {
    response = try await client.sendMessage(
        model: model, messages: messages, maxTokens: maxTokens, system: buildSystemPrompt()
    )
} catch {
    return QueryResult(text: lastAssistantText, usage: totalUsage, ...)
}
```

替换为：
```swift
let response: [String: Any]
do {
    response = try await withRetry {
        try await self.client.sendMessage(
            model: self.model, messages: messages,
            maxTokens: self.maxTokens, system: self.buildSystemPrompt()
        )
    }
} catch {
    return QueryResult(text: lastAssistantText, ..., status: .errorDuringExecution, totalCostUsd: totalCostUsd)
}
```

**max_tokens 恢复计数器（在 while 循环前添加）：**

```swift
var maxTokensRecoveryAttempts = 0
let MAX_TOKENS_RECOVERY = 3

// 在 stop_reason 检查处（第 184-193 行）：
let stopReason = response["stop_reason"] as? String ?? ""

if stopReason == "end_turn" || stopReason == "stop_sequence" {
    break
}

// max_tokens 恢复（带计数限制）
if stopReason == "max_tokens" && maxTokensRecoveryAttempts < MAX_TOKENS_RECOVERY {
    maxTokensRecoveryAttempts += 1
    messages.append(["role": "user", "content": "Please continue from where you left off."])
    continue
} else if stopReason == "max_tokens" {
    // 超过恢复次数，返回部分结果
    break
}
```

### 集成点：stream() 方法

**重试集成（替换 eventStream 获取）：**

当前代码（第 257-273 行）：
```swift
let eventStream: AsyncThrowingStream<SSEEvent, Error>
do {
    eventStream = try await capturedClient.streamMessage(...)
} catch {
    Self.yieldStreamError(...)
    return
}
```

替换为：
```swift
let eventStream: AsyncThrowingStream<SSEEvent, Error>
do {
    eventStream = try await withRetry {
        try await capturedClient.streamMessage(
            model: capturedModel, messages: messages,
            maxTokens: capturedMaxTokens, system: capturedSystemPrompt
        )
    }
} catch {
    Self.yieldStreamError(...)
    return
}
```

**max_tokens 恢复计数器（在 while 循环内、eventStream 处理前添加）：**

```swift
// 在 while 循环开始处添加
var maxTokensRecoveryAttempts = 0
let MAX_TOKENS_RECOVERY = 3

// 在 messageStop 处理之后（第 360 行之后）、终止条件检查处：
if currentStopReason == "end_turn" || currentStopReason == "stop_sequence" {
    break
}

// max_tokens 恢复（带计数限制）
if currentStopReason == "max_tokens" && maxTokensRecoveryAttempts < MAX_TOKENS_RECOVERY {
    maxTokensRecoveryAttempts += 1
    messages.append(["role": "user", "content": "Please continue from where you left off."])
    continue  // 继续外层 while 循环
} else if currentStopReason == "max_tokens" {
    break  // 超过恢复次数，正常终止流
}
```

### 重试逻辑的关键细节

1. **重试仅包装 API 调用**，不包装整个智能循环 — 每次重试只重新发送单次 API 请求
2. **退避公式**：`baseDelayMs * 2^attempt + jitter`（jitter 为 +/-25%）
   - attempt 0: ~2000ms + jitter
   - attempt 1: ~4000ms + jitter
   - attempt 2: ~8000ms + jitter
3. **可重试的状态码**：429（限流）、500（内部错误）、502（网关错误）、503（服务不可用）、529（过载）
4. **不可重试的状态码**：400（请求错误）、401（未授权）、403（禁止）等

### max_tokens 恢复的关键细节

1. **续接提示文本**：从当前的 `"continue"` 改为 `"Please continue from where you left off."`（与 TS SDK 一致）
2. **计数器独立于 turnCount**：`maxTokensRecoveryAttempts` 专门追踪 max_tokens 恢复次数，不影响 turnCount
3. **恢复后继续正常循环**：续接提示添加后，循环继续，LLM 可以继续生成或发出 end_turn
4. **TS SDK 参考实现**：`engine.ts` 第 361-372 行，使用 `MAX_OUTPUT_RECOVERY = 3` 限制

### stream() 的 Swift 并发注意事项

- `withRetry` 内部的 `Task.sleep` 不需要额外处理 — 它在 `Task` 上下文中运行
- 重试耗尽后的错误通过 `yieldStreamError` 处理 — 保持现有模式
- `maxTokensRecoveryAttempts` 是局部变量，不需要 Sendable 关心

### 反模式警告

- **禁止**将整个 while 循环包装在重试中 — 只重试单次 API 调用
- **禁止**重试非瞬态错误（400、401、403）— 这些是客户端错误，重试无意义
- **禁止**在 max_tokens 恢复中无限续接 — 最多 3 次
- **禁止**修改 `AnthropicClient` 的错误处理 — 它已正确清理 API 密钥
- **禁止**将 `RetryConfig` 设为 `public` — 这是内部实现细节（`internal` 可访问性）
- **禁止**使用 `!` force-unwrap — 使用 `guard let` / `if let`
- **禁止**在重试计数器的 `else if` 分支中设置 `status = .errorDuringExecution` — max_tokens 恢复耗尽时应返回 `.success`（已获得部分有效文本）
- **禁止**将 max_tokens 恢复计数器放在 while 循环外面 — 每轮次可能有多个 API 调用，计数器应在 while 级别

### TypeScript SDK 参考实现

```typescript
// TS SDK: utils/retry.ts — 重试配置
export const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 3,
  baseDelayMs: 2000,
  maxDelayMs: 30000,
  retryableStatusCodes: [429, 500, 502, 503, 529],
}

// TS SDK: utils/retry.ts — 带重试执行
export async function withRetry<T>(
  fn: () => Promise<T>,
  config: RetryConfig = DEFAULT_RETRY_CONFIG,
  abortSignal?: AbortSignal,
): Promise<T> {
  let lastError: any
  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      return await fn()
    } catch (err: any) {
      lastError = err
      if (!isRetryableError(err, config)) throw err
      if (attempt === config.maxRetries) throw err
      const delay = getRetryDelay(attempt, config)
      await new Promise((resolve) => setTimeout(resolve, delay))
    }
  }
  throw lastError
}

// TS SDK: engine.ts — max_tokens 恢复
let maxOutputRecoveryAttempts = 0
const MAX_OUTPUT_RECOVERY = 3

// 在响应处理后：
if (
  response.stopReason === 'max_tokens' &&
  maxOutputRecoveryAttempts < MAX_OUTPUT_RECOVERY
) {
  maxOutputRecoveryAttempts++
  this.messages.push({
    role: 'user',
    content: 'Please continue from where you left off.',
  })
  continue
}
```

### 与其他 Story 的关系

- **Story 2.3**（预算强制执行）已实现 — 重试成功后的 API 调用仍受预算检查约束
- **Story 2.5**（对话自动压缩）将在重试前可能触发压缩
- **Story 2.6**（工具结果微压缩）将在工具执行后压缩大型结果
- **Story 3.3**（工具执行器）的工具调用也应用此重试机制

### 测试策略

**使用 MockURLProtocol 模拟 API 错误：**

1. **瞬态错误重试成功**：模拟前 2 次 HTTP 503，第 3 次成功返回
2. **瞬态错误重试耗尽**：模拟连续 4 次 HTTP 429（超过 3 次重试限制）
3. **非瞬态错误不重试**：模拟 HTTP 401，验证立即返回错误无重试
4. **max_tokens 恢复**：模拟 2 次 max_tokens + 1 次 end_turn
5. **max_tokens 恢复耗尽**：模拟 4 次 max_tokens（超过 3 次限制）

**测试文件命名：** `RetryAndRecoveryTests.swift`

**注意：** 重试逻辑的 `Task.sleep` 会导致测试变慢。可以在测试中注入较短的 `RetryConfig`（baseDelayMs: 1, maxDelayMs: 1）来加速。

### Project Structure Notes

本 story 修改/创建的文件：
```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift ✎                    — 在 prompt() 和 stream() 中添加重试和 max_tokens 恢复（修改）
├── Utils/
│   └── Retry.swift ★                     — 重试工具函数（新建）

Tests/OpenAgentSDKTests/
├── Core/
│   └── RetryAndRecoveryTests.swift ★     — 重试和恢复测试（新建）
└── Utils/
    └── RetryTests.swift ★                — RetryConfig 和 withRetry 单元测试（新建）
```

**无需修改的文件：**
- `API/AnthropicClient.swift` — 已有正确的错误处理和 API 密钥清理
- `Types/ErrorTypes.swift` — `SDKError.apiError` 已有 statusCode 关联值
- `Types/AgentTypes.swift` — `QueryStatus` 不需要新增枚举值
- `Types/SDKMessage.swift` — 不需要新增事件类型

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#AD3] — 自定义 AnthropicClient，POST /v1/messages
- [Source: _bmad-output/planning-artifacts/architecture.md#AD10] — 带关联值的类型化错误
- [Source: _bmad-output/planning-artifacts/architecture.md#Utils] — Utils/Retry.swift 在架构中的位置
- [Source: _bmad-output/planning-artifacts/prd.md#FR5] — Agent 从 max_tokens 响应中恢复
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 指数退避重试（最多 3 次）
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] — 仅通过 POST /v1/messages 通信
- [Source: _bmad-output/planning-artifacts/epics.md#Story-2.4] — Story 定义和验收标准
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L128] — prompt() 中 API 调用的 do/catch（需包装 withRetry）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L184] — prompt() 中 stop_reason 检查（需添加计数器）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L257] — stream() 中 eventStream 获取（需包装 withRetry）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L398] — stream() 中终止条件（需添加计数器）
- [Source: Sources/OpenAgentSDK/API/AnthropicClient.swift#L191] — validateHTTPResponse 已清理 API 密钥
- [Source: Sources/OpenAgentSDK/Types/ErrorTypes.swift#L5] — SDKError.apiError(statusCode:message:)
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/utils/retry.ts] — TS SDK 重试参考实现
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/engine.ts#L361] — TS SDK max_tokens 恢复参考

### Previous Story Intelligence (Story 2.3)

**已建立的代码模式：**
1. `prompt()` 和 `stream()` 都使用 `totalCostUsd += estimateCost(model:usage:)` 模式累积成本
2. `stream()` 中成本在两个地方累积：`messageStart`（input tokens）和 `messageDelta`（output tokens）
3. `stream()` 需要捕获值跨越 AsyncStream 闭包边界（Swift 6 Sendable）
4. 错误路径使用 `yieldStreamError` 静态方法统一处理
5. `computeDurationMs` 是 `private static func`
6. 测试使用 MockURLProtocol 模拟 API 响应

**Story 2.3 遇到的问题和解决方案：**
- `messageStart` 中的预算检查需要特别处理 — 重试逻辑也会遇到类似的边界情况
- 浮点数比较需要容差处理 — 预算比较使用 `>` 而非 `>=`
- `turnCount` 的递增位置很重要 — 在 `messageStop` 中递增而非 `messageStart`

**对本 story 的影响：**
- 重试成功后的 API 调用仍需正确累积成本 — 预算检查在重试之后自动生效
- `stream()` 中的重试包装应在 eventStream 获取级别，不在事件循环级别
- max_tokens 恢复不影响预算检查 — 每轮 API 调用的成本正常累积

### Git Intelligence

最近 5 次提交（Epic 2 相关）：
- `84d422f` — 修复预算测试中的 messageStart 检查和浮点边界
- `af304cb` — 实现 Story 2.3 预算强制执行
- `1ec6e26` — 修复流式路径中 message_start 的 input_tokens 成本计算
- `64e9905` — 实现 Story 2.2 token 使用量和成本追踪
- `d9ee242` — 修复流式路径中 input_tokens 提取

**关键模式观察：**
1. 每个功能 story 后都有修复提交 — 开发时注意边界条件
2. 流式路径和阻塞路径经常有微妙差异 — 需要同时测试两条路径
3. 成本累积在 `messageStart` 和 `messageDelta` 两个事件中 — 重试不应干扰此机制

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
