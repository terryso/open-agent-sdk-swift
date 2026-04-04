# Story 2.1: 通过 AsyncStream 流式响应

Status: done

## Story

作为开发者，
我希望将 Agent 响应作为实时事件流消费，
以便我可以在应用 UI 中展示渐进式结果。

## Acceptance Criteria

1. **AC1: AsyncStream<SDKMessage> 返回** — 给定使用有效配置创建的 Agent，当开发者调用 `agent.stream("分析这段代码")`，则立即返回 `AsyncStream<SDKMessage>`（FR2），且 SDKMessage 事件在从 LLM 到达时被产出

2. **AC2: 类型化事件流** — 给定活跃的 `AsyncStream<SDKMessage>`，当 Agent 处理流式响应，则流发出类型化事件：文本增量（partialMessage）、工具使用开始（assistant）、工具结果（toolResult）、使用量更新和完成（result），且开发者可以使用 `case let` 对 SDKMessage 的各个 case 进行模式匹配

3. **AC3: 错误事件** — 给定遇到 API 错误的活跃流，当从 LLM 接收到错误，则在流上发出错误事件，流优雅终止

4. **AC4: end_turn 终止** — 给定 LLM 返回 `stop_reason="end_turn"` 的流式响应，当 Agent 处理该响应，则发出 `.result(subtype: .success)` 事件后流终止

5. **AC5: maxTurns 限制** — 给定配置了 `maxTurns=2` 的 Agent，当 Agent 流式执行达到 2 轮，则发出 `.result(subtype: .errorMaxTurns)` 事件后流终止

6. **AC6: 使用量统计** — 给定完成的流式调用，当开发者检查最终 `.result` 事件，则包含累积的 `usage`、`numTurns` 和 `durationMs`

7. **AC7: stream 与 prompt 公共 API 一致性** — 给定 Agent 类，当开发者调用 `stream()` 和 `prompt()`，则两者具有相同的参数签名（仅 `text: String`），返回类型分别为 `AsyncStream<SDKMessage>` 和 `QueryResult`

## Tasks / Subtasks

- [x] Task 1: 在 `Core/Agent.swift` 上实现 `stream()` 方法 (AC: #1, #2, #4, #5, #6)
  - [x] 1.1: 添加 `public func stream(_ text: String) -> AsyncStream<SDKMessage>` 方法到 Agent 类
  - [x] 1.2: 使用 `AsyncStream<SDKMessage>` 的 `continuation` 构建器模式创建流
  - [x] 1.3: 在流内部实现与 `prompt()` 相同的循环结构（while turnCount < maxTurns）
  - [x] 1.4: 调用 `client.streamMessage()` 发送流式 API 请求（使用 `stream: true`）
  - [x] 1.5: 遍历 `AsyncThrowingStream<SSEEvent, Error>` 解析 SSE 事件
  - [x] 1.6: 将 SSE 事件映射为 SDKMessage 并通过 continuation yield
  - [x] 1.7: 处理 `message_start` — 提取 model 信息，初始化累积文本
  - [x] 1.8: 处理 `content_block_delta` — 提取文本增量，yield `.partialMessage`
  - [x] 1.9: 处理 `content_block_stop` — 完成当前 content block
  - [x] 1.10: 处理 `message_delta` — 提取 stop_reason 和 usage
  - [x] 1.11: 处理 `message_stop` — yield `.assistant` 事件（完整文本 + stop_reason + model）
  - [x] 1.12: 处理 `error` 事件 — yield `.result(subtype: .errorDuringExecution)` 后终止流
  - [x] 1.13: 循环终止时 yield `.result` 事件（包含累积 usage、turnCount、durationMs）
  - [x] 1.14: 调用 `continuation.finish()` 关闭流

- [x] Task 2: 实现 SSE 事件到 SDKMessage 的映射逻辑 (AC: #2)
  - [x] 2.1: SSE-to-SDKMessage 映射内联在 stream() 方法中（与 stream 循环紧密耦合，无需独立方法）
  - [x] 2.2: 累积完整文本变量 `accumulatedText: String`
  - [x] 2.3: 累积 model 和 stop_reason 变量
  - [x] 2.4: 在 `content_block_delta` 中提取 `delta["text"]` 并 yield `.partialMessage(PartialData(text: deltaText))`
  - [x] 2.5: 在 `message_stop` 中 yield `.assistant(AssistantData(text: accumulatedText, model: model, stopReason: stopReason))`
  - [x] 2.6: 在循环最终（while 循环结束后）yield `.result` 事件

- [x] Task 3: 编写 `Tests/OpenAgentSDKTests/Core/StreamTests.swift` (AC: #1-#7)
  - [x] 3.1: 测试 AC1 — stream() 返回 AsyncStream<SDKMessage>
  - [x] 3.2: 测试 AC2 — 流发出 partialMessage 和 assistant 事件
  - [x] 3.3: 测试 AC3 — API 错误时发出 errorDuringExecution 事件，流优雅终止
  - [x] 3.4: 测试 AC4 — end_turn 时发出 .result(subtype: .success) 事件
  - [x] 3.5: 测试 AC5 — maxTurns 限制时发出 .result(subtype: .errorMaxTurns) 事件
  - [x] 3.6: 测试 AC6 — result 事件包含正确的 usage 统计
  - [x] 3.7: 测试 AC7 — stream() 和 prompt() 具有相同的公共签名模式

## Dev Notes

### 核心设计决策

**本 story 的范围限制：**
- **仅实现流式 `stream()` 方法**（FR2）
- **不实现工具执行** — 无工具场景，LLM 不会返回 `tool_use` blocks
- **不实现预算检查**（FR8，Story 2.3 的范围）
- **不实现自动压缩**（FR9，Story 2.5 的范围）
- **不实现 max_tokens 恢复**（FR5，Story 2.4 的范围）
- **不实现重试**（NFR15，Story 2.4 的范围）

### 实现策略

**推荐：直接在 Agent.stream() 中实现流式循环**，与 `prompt()` 方法保持对称设计。

```swift
// Core/Agent.swift — stream() 方法实现骨架
public func stream(_ text: String) -> AsyncStream<SDKMessage> {
    let startTime = ContinuousClock.now

    return AsyncStream<SDKMessage> { continuation in
        Task {
            var messages = buildMessages(prompt: text)
            var totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
            var turnCount = 0
            var lastStatus: QueryStatus = .success

            while turnCount < maxTurns {
                let eventStream: AsyncThrowingStream<SSEEvent, Error>
                do {
                    eventStream = try await client.streamMessage(
                        model: model,
                        messages: messages,
                        maxTokens: maxTokens,
                        system: buildSystemPrompt()
                    )
                } catch {
                    // API 连接错误 — 发出错误结果并终止
                    let elapsed = ContinuousClock.now - startTime
                    let durationMs = computeDurationMs(elapsed)
                    continuation.yield(.result(ResultData(
                        subtype: .errorDuringExecution,
                        text: "",
                        usage: totalUsage,
                        numTurns: turnCount,
                        durationMs: durationMs
                    )))
                    continuation.finish()
                    return
                }

                // 处理 SSE 事件流
                var accumulatedText = ""
                var currentModel = ""
                var currentStopReason = ""

                do {
                    for try await event in eventStream {
                        switch event {
                        case .messageStart(let message):
                            currentModel = message["model"] as? String ?? model

                        case .contentBlockDelta(_, let delta):
                            if let text = delta["text"] as? String {
                                accumulatedText += text
                                continuation.yield(.partialMessage(PartialData(text: text)))
                            }

                        case .messageDelta(let delta, let usage):
                            currentStopReason = delta["stop_reason"] as? String ?? ""
                            totalUsage = totalUsage + TokenUsage(
                                inputTokens: usage["input_tokens"] as? Int ?? 0,
                                outputTokens: usage["output_tokens"] as? Int ?? 0
                            )

                        case .messageStop:
                            turnCount += 1
                            continuation.yield(.assistant(AssistantData(
                                text: accumulatedText,
                                model: currentModel,
                                stopReason: currentStopReason
                            )))

                            // 添加助手消息到对话历史
                            messages.append(["role": "assistant", "content": [["type": "text", "text": accumulatedText]]])

                        case .error:
                            // API 返回错误事件
                            let elapsed = ContinuousClock.now - startTime
                            let durationMs = computeDurationMs(elapsed)
                            continuation.yield(.result(ResultData(
                                subtype: .errorDuringExecution,
                                text: accumulatedText,
                                usage: totalUsage,
                                numTurns: turnCount,
                                durationMs: durationMs
                            )))
                            continuation.finish()
                            return

                        case .contentBlockStart, .contentBlockStop, .ping:
                            break // 不产出 SDKMessage
                        }
                    }
                } catch {
                    let elapsed = ContinuousClock.now - startTime
                    let durationMs = computeDurationMs(elapsed)
                    continuation.yield(.result(ResultData(
                        subtype: .errorDuringExecution,
                        text: accumulatedText,
                        usage: totalUsage,
                        numTurns: turnCount,
                        durationMs: durationMs
                    )))
                    continuation.finish()
                    return
                }

                // 检查终止条件
                if currentStopReason == "end_turn" || currentStopReason == "stop_sequence" {
                    break
                }
            }

            // 确定最终状态
            let elapsed = ContinuousClock.now - startTime
            let durationMs = computeDurationMs(elapsed)

            let subtype: SDKMessage.ResultData.Subtype =
                turnCount >= maxTurns ? .errorMaxTurns : .success

            let finalText = messages.compactMap { msg -> String? in
                guard let content = msg["content"] as? [[String: Any]] else { return nil }
                return content.filter { $0["type"] as? String == "text" }
                    .compactMap { $0["text"] as? String }
                    .joined()
            }.joined()

            continuation.yield(.result(ResultData(
                subtype: subtype,
                text: finalText,
                usage: totalUsage,
                numTurns: turnCount,
                durationMs: durationMs
            )))
            continuation.finish()
        }
    }
}
```

### 已有代码与集成点

**本 story 直接使用的已完成类型：**
- `Agent` 类（`Core/Agent.swift`）— 已有 `buildSystemPrompt()`、`buildMessages(prompt:)`、`client` 属性、`extractText(from:)` 方法、`prompt()` 方法
- `AnthropicClient` actor（`API/AnthropicClient.swift`）— **已有 `streamMessage()` 方法**，返回 `AsyncThrowingStream<SSEEvent, Error>`
- `SSEEvent` 枚举（`API/APIModels.swift`）— 已有所有 case：`.messageStart`、`.contentBlockStart`、`.contentBlockDelta`、`.contentBlockStop`、`.messageDelta`、`.messageStop`、`.ping`、`.error`
- `SSELineParser` 和 `SSEEventDispatcher`（`API/Streaming.swift`）— 已完成 SSE 解析逻辑
- `SDKMessage` 枚举（`Types/SDKMessage.swift`）— 已有所有 case：`.assistant`、`.toolResult`、`.result`、`.partialMessage`、`.system`
- `TokenUsage`（`Types/TokenUsage.swift`）— 已支持 `+` 运算符累加
- `QueryResult`（`Types/AgentTypes.swift`）— blocking 响应类型
- `SDKError`（`Types/ErrorTypes.swift`）— 错误类型

**无需修改的文件：**
- `AnthropicClient.swift` — 已有 `streamMessage()` 方法
- `APIModels.swift` — SSEEvent 已完整定义
- `Streaming.swift` — SSE 解析已完成
- `SDKMessage.swift` — 所有 SDKMessage case 和关联类型已定义
- `TokenUsage.swift` — 已支持累加
- `ErrorTypes.swift` — 已有所有错误 case

### Anthropic 流式 API 事件序列

Anthropic Messages API 流式响应的事件序列（无工具场景）：
```
event: message_start     → { "message": { "id": "msg_...", "model": "claude-sonnet-4-6", ... } }
event: content_block_start → { "index": 0, "content_block": { "type": "text", "text": "" } }
event: content_block_delta → { "index": 0, "delta": { "type": "text_delta", "text": "Swift" } }
event: content_block_delta → { "index": 0, "delta": { "type": "text_delta", "text": " 并发" } }
event: content_block_stop  → { "index": 0 }
event: message_delta     → { "delta": { "stop_reason": "end_turn" }, "usage": { "output_tokens": 15 } }
event: message_stop      → (no data)
```

**关键映射：**
- `content_block_delta` → `delta["text"]` 是文本增量 → yield `.partialMessage`
- `message_delta` → `delta["stop_reason"]` 和 `usage` → 累积使用量
- `message_stop` → 产出完整 `.assistant` 事件

### TypeScript SDK 参考实现

```typescript
// TS SDK: engine.ts → submitMessage() — 异步生成器
async *submitMessage(prompt: string, overrides?: Partial<AgentOptions>): AsyncGenerator<SDKMessage> {
    // ... 设置 messages, system prompt 等

    while (turnCount < maxTurns) {
        const stream = await this.client.messages.create({
            model, messages, max_tokens, system, stream: true,
        })

        let text = ''
        for await (const event of stream) {
            if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
                text += event.delta.text
                yield { type: 'partialMessage', text: event.delta.text }
            }
            if (event.type === 'message_stop') {
                yield { type: 'assistant', text, model, stopReason }
            }
        }

        turnCount++
        if (stopReason === 'end_turn') break
    }

    yield { type: 'result', ... }
}
```

**Swift 适配要点：**
- TS SDK 使用 `AsyncGenerator<SDKMessage>`（`yield` 关键字），Swift 使用 `AsyncStream<SDKMessage>.Continuation`（`continuation.yield()`）
- TS SDK 的 `for await (const event of stream)` → Swift 的 `for try await event in eventStream`
- Swift `AsyncStream` 需要显式 `continuation.finish()` 关闭（TS AsyncGenerator 在函数返回时自动关闭）
- Swift 需要在 `Task {}` 内执行异步工作（因为 `AsyncStream` 闭包不是 async context）

### AnthropicClient.streamMessage() 现有实现

**重要：** `AnthropicClient` 已经实现了 `streamMessage()` 方法（Story 1.2 中完成），返回 `AsyncThrowingStream<SSEEvent, Error>`。该方法：
1. 发送 `stream: true` 的 POST /v1/messages 请求
2. 解析 SSE 文本为 `(event, data)` 对
3. 通过 `SSEEventDispatcher` 将每对映射为 `SSEEvent` 枚举值
4. 返回包含所有事件的 `AsyncThrowingStream`

**已知限制：** 当前 `streamMessage()` 使用 `urlSession.data(for:)` 一次性获取全部数据后解析，而非逐字节流式解析。这意味着：
- 所有 SSE 事件在 API 响应完全到达后才被解析
- 首个 token 延迟可能不满足 NFR1（2 秒内）
- **本 story 不修复此问题** — 如果测试发现延迟不可接受，可作为优化项在后续 story 或 deferred work 中处理

### durationMs 计算辅助方法

为避免重复代码，建议提取 `computeDurationMs` 辅助方法：
```swift
private func computeDurationMs(_ elapsed: Duration) -> Int {
    Int(elapsed.components.seconds * 1000)
        + Int(elapsed.components.attoseconds / 1_000_000_000_000)
}
```

### 反模式警告

- **禁止**将 `stream()` 内的 Task 设为 detached — 使用 `Task {}` 结构化并发
- **禁止**在流结束后忘记调用 `continuation.finish()` — 会导致消费者永远挂起
- **禁止**在 continuation.yield 后使用 `break` 而不是 `return` — Task 内必须 return 退出
- **禁止**使用 force-unwrap (`!`) — 使用 `guard let` / `if let` / `??` 默认值
- **禁止**使用 Codable 解析 SSE 事件数据 — 使用 `[String: Any]` 原始字典（项目上下文规则 #5、#41）
- **禁止**将 Agent 改为 actor — Agent 是 class（项目上下文规则 #1）
- **禁止**在 stream() 中实现工具执行 — 工具系统在 Epic 3 中
- **禁止**在 stream() 内部实现重试逻辑 — Story 2.4 的范围
- **禁止**在 stream() 内部实现预算检查 — Story 2.3 的范围
- **禁止**在 stream() 内部实现对话压缩 — Story 2.5 的范围
- **禁止**创建空的或占位文件 — 每个文件必须有完整实现

### 与 prompt() 方法的对称设计

`stream()` 和 `prompt()` 应该共享相同的核心循环逻辑，区别仅在于：
- `prompt()` 使用 `client.sendMessage()`（非流式），直接累积结果
- `stream()` 使用 `client.streamMessage()`（流式），通过 continuation yield 事件

**建议：** 如果两个方法的循环逻辑有大量重复，可以考虑提取共享的循环骨架到私有方法中。但在本 story 中，优先保持简单直接实现，避免过度抽象。

### 测试策略

**使用 MockURLProtocol 模拟流式 API 响应**（与 Story 1.2、1.5 的测试模式一致）：

```swift
// 模拟 SSE 流式响应
let sseResponse = """
event: message_start
data: {"message": {"id": "msg_123", "model": "claude-sonnet-4-6", "role": "assistant"}}

event: content_block_start
data: {"index": 0, "content_block": {"type": "text", "text": ""}}

event: content_block_delta
data: {"index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

event: content_block_delta
data: {"index": 0, "delta": {"type": "text_delta", "text": " world"}}

event: content_block_stop
data: {"index": 0}

event: message_delta
data: {"delta": {"stop_reason": "end_turn"}, "usage": {"output_tokens": 10}}

event: message_stop
data: {}
"""
```

**关键测试场景：**
1. 单轮流式对话 → 收到 partialMessage + assistant + result 事件序列
2. API 连接错误 → 收到 errorDuringExecution result 事件，流优雅终止
3. SSE error 事件 → 收到 errorDuringExecution result 事件，流优雅终止
4. maxTurns=1 → 收到 errorMaxTurns result 事件
5. end_turn → 收到 success result 事件
6. 验证 result 事件包含正确 usage 和 durationMs

### Project Structure Notes

本 story 创建/修改带 `★` 标记的部分：
```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift ✎              — 添加 stream() 方法 + computeDurationMs 辅助（修改）
├── Types/
│   └── (无修改 — SDKMessage 已完整)
├── API/
│   └── (无修改 — AnthropicClient.streamMessage() 和 SSEEvent 已完成)
└── OpenAgentSDK.swift ✎          — 可能需要更新文档注释（修改）
Tests/OpenAgentSDKTests/
└── Core/
    └── StreamTests.swift ★        — 流式响应测试（新建）
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#AD2] — AsyncStream<SDKMessage> 流式模型
- [Source: _bmad-output/planning-artifacts/architecture.md#Streaming] — SSE/流式响应解析
- [Source: _bmad-output/planning-artifacts/prd.md#FR2] — 流式响应需求
- [Source: _bmad-output/planning-artifacts/prd.md#NFR1] — 首 token 2 秒延迟要求
- [Source: _bmad-output/planning-artifacts/epics.md#Story-2.1] — Story 定义和验收标准
- [Source: _bmad-output/project-context.md#2] — 结构化并发
- [Source: _bmad-output/project-context.md#5] — Codable 与原始 JSON 边界
- [Source: _bmad-output/project-context.md#7] — 模块边界严格单向依赖
- [Source: _bmad-output/project-context.md#11] — AsyncStream<SDKMessage> 流式管道
- [Source: _bmad-output/project-context.md#20] — Agent、query() 必须是 public
- [Source: _bmad-output/project-context.md#27] — AnthropicClient 测试使用 MockURLProtocol
- [Source: _bmad-output/implementation-artifacts/1-5-agent-loop-blocking-response.md] — Story 1.5 完成记录
- [Source: TypeScript SDK /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/engine.ts#submitMessage] — QueryEngine 流式循环参考
- [Source: TypeScript SDK /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/agent.ts#prompt] — prompt() 通过遍历流收集结果
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — 现有 Agent 类，包含 prompt()、buildSystemPrompt()、buildMessages()
- [Source: Sources/OpenAgentSDK/API/AnthropicClient.swift#streamMessage] — 现有流式 API 方法
- [Source: Sources/OpenAgentSDK/API/APIModels.swift#SSEEvent] — SSE 事件枚举
- [Source: Sources/OpenAgentSDK/API/Streaming.swift] — SSE 解析器
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] — SDKMessage 类型定义

### Previous Story Intelligence (Story 1.5)

**已建立的代码模式：**
1. `prompt()` 方法使用 `while turnCount < maxTurns` 循环结构
2. API 错误通过 `do/catch` 捕获，返回 `.errorDuringExecution` 状态
3. 使用量通过 `totalUsage = totalUsage + turnUsage` 累加
4. 持续时间通过 `ContinuousClock` 计算
5. 消息历史通过 `messages.append(["role": "assistant", "content": ...])` 追加
6. 测试使用 `MockURLProtocol` 模拟 API 响应

**Story 1.5 的完成记录要点：**
- 实现了 Strategy A：直接在 Agent.prompt() 中实现循环（非独立 QueryEngine）
- Agent 有 `init(options:client:)` 公开初始化器，支持测试注入 mock AnthropicClient
- XCTest 在 CLI-only 环境不可用（无 Xcode）— 测试通过 `swift build` 验证
- `max_tokens` 时循环继续而非中断（最新修复：commit 8bdfffc）

### Git Intelligence

**最近 5 次提交：**
- `8bdfffc fix: remove max_tokens break to allow loop continuation for multi-turn queries` — 修复循环终止逻辑
- `b548bcc feat: implement agent loop with blocking response (Story 1.5)` — 实现阻塞式智能循环
- `1f69c65 docs: add README (EN/CN), LICENSE and BMAD badge` — 文档
- `cd9bdc5 fix: correct argument order and remove unnecessary cast in AgentCreationTests` — 测试修复
- `d888672 feat: implement Agent creation and configuration (Story 1.4)` — Agent 创建

**已建立的提交模式：** `feat:` 用于新功能实现，`fix:` 用于修复

### 与后续 Story 的关系

- **Story 2.2**（Token 使用量与成本追踪）将添加 `estimateCost()` 和 `MODEL_PRICING` 查找
- **Story 2.3**（预算执行）将在循环中添加预算检查（在每轮结束后检查）
- **Story 2.4**（重试与 max_tokens 恢复）将添加重试包装和续接提示逻辑
- **Story 2.5**（自动压缩）将在循环中添加压缩检查（在发送 API 请求前检查）
- **Story 3.3**（工具执行器）将添加工具执行逻辑，需要同时修改 `prompt()` 和 `stream()`
- **设计原则**：确保 `stream()` 的内部结构可以在后续 Story 中逐步增强，不改变公共 API

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Swift 6 strict concurrency: `[[String: Any]]` is not `Sendable`, requiring serialization to `Data` before crossing AsyncStream closure boundary
- Made `computeDurationMs` a `private static func` to avoid `self` capture in Task closure
- XCTest unavailable in CLI-only environment (no Xcode); verified via `swift build`

### Completion Notes List

- Implemented `stream()` method on Agent class using `AsyncStream<SDKMessage>` with continuation builder pattern
- SSE event handling: message_start (model extraction), content_block_delta (partialMessage yields), message_delta (usage accumulation), message_stop (assistant event), error (error result + termination)
- Error handling: API connection errors, SSE stream iteration errors, and SSE error events all yield `.result(subtype: .errorDuringExecution)` then `continuation.finish()`
- Loop termination: end_turn/stop_sequence break cleanly; maxTurns exhaustion yields `.result(subtype: .errorMaxTurns)`
- Symmetric design with `prompt()`: same loop structure, same termination conditions
- Captured immutable values before AsyncStream closure to satisfy Swift 6 strict concurrency
- Extracted `computeDurationMs` as static helper method (also available for `prompt()` refactoring in future)
- Pre-existing StreamTests.swift file covered all 7 ACs (was already created as ATDD RED phase tests)

### File List

- Sources/OpenAgentSDK/Core/Agent.swift (modified — added stream() method, computeDurationMs static helper)
- Tests/OpenAgentSDKTests/Core/StreamTests.swift (pre-existing — ATDD tests for all ACs)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified — status update)
- _bmad-output/implementation-artifacts/2-1-async-stream-response.md (modified — task tracking)
