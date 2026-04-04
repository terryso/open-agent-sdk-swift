# Story 2.6: 工具结果微压缩

Status: done

## Story

作为开发者，我希望 Agent 自动压缩大型工具结果，以便单个工具输出不会消耗过多上下文。

## Acceptance Criteria

1. **AC1: 微压缩触发** — 给定返回超过 50,000 字符结果的工具执行，当结果被添加到对话中，则结果被自动微压缩为保留关键信息的摘要（FR10），且压缩后的结果被清楚地标记为已截断。

2. **AC2: 阈值以下不压缩** — 给定 50,000 字符以下的工具结果，当结果被添加到对话中，则不执行微压缩，包含完整结果。

3. **AC3: 压缩标记** — 给定已微压缩的工具结果，则结果包含标记：`[微压缩] 原始长度: X, 压缩后长度: Y`。

4. **AC4: 压缩失败容错** — 给定微压缩 LLM 调用失败，当压缩尝试失败，则保留原始工具结果不变（不截断、不丢失），Agent 继续正常执行。

5. **AC5: 压缩质量** — 微压缩摘要保留工具结果的关键信息：文件路径、错误消息、结构化数据的键名和摘要值。摘要不应丢失关键的错误诊断信息。

## Tasks / Subtasks

- [ ] Task 1: 实现微压缩核心函数 (AC: #1, #2, #3, #5)
  - [ ] 在 `Utils/Compact.swift` 添加 `MICRO_COMPACT_THRESHOLD` 常量（50,000 字符）
  - [ ] 实现 `shouldMicroCompact(content:) -> Bool` 检查函数
  - [ ] 实现 `microCompact(client:model:content:) async -> String` 核心函数
  - [ ] 实现 `buildMicroCompactPrompt(_:)` 私有辅助函数
  - [ ] 压缩失败时返回原始内容，并记录 consecutiveFailures

- [ ] Task 2: 集成到 Agent 智能循环 (AC: #1, #2, #4)
  - [ ] 在 `prompt()` 方法中，在工具结果添加到 messages 前检查并微压缩
  - [ ] 在 `stream()` 方法中，在工具结果添加到 messages 前检查并微压缩
  - [ ] 流式路径：微压缩完成时 yield `.system(.status)` 事件通知消费者

- [ ] Task 3: 单元测试 (AC: #1-#5)
  - [ ] 测试 `shouldMicroCompact` 阈值边界（49999、50000、50001 字符）
  - [ ] 测试微压缩成功路径：大内容被压缩并包含标记
  - [ ] 测试微压缩失败路径：LLM 错误时保留原始内容
  - [ ] 测试阈值以下不触发压缩
  - [ ] 测试连续失败计数器

- [ ] Task 4: 集成测试 (AC: #1, #2, #4)
  - [ ] 测试 prompt() 路径的端到端微压缩流程
  - [ ] 测试 stream() 路径的端到端微压缩流程
  - [ ] 测试微压缩与自动压缩（Story 2.5）的协调

## Dev Notes

### 核心设计决策

**本 story 范围：**
- 实现工具结果的微压缩（FR10）— 对超过 50,000 字符的工具结果进行摘要压缩
- 微压缩发生在工具结果即将被添加到 messages 数组之前
- 与 Story 2.5 的自动压缩是互补关系：微压缩处理单个大型内容块，自动压缩处理整个对话上下文

**与 Story 2.5 的关系：**
- 微压缩在内容进入 messages 前执行（前置过滤）
- 自动压缩在整个对话接近上下文限制时执行（后置兜底）
- 微压缩减少单个大块对上下文的消耗，降低自动压缩的触发频率
- 两者都使用 `withRetry` 包装 LLM 调用
- 两者都不计入用户 `totalCostUsd`（内部操作成本）

### 已有基础设施（直接复用）

| 类型 | 位置 | 说明 |
|------|------|------|
| `withRetry()` | `Utils/Retry.swift:93` | 包装微压缩 LLM 调用，复用重试机制 |
| `AnthropicClient.sendMessage()` | `API/AnthropicClient.swift` | 微压缩 LLM 调用使用阻塞路径 |
| `SDKMessage.system(.status)` | `Types/SDKMessage.swift:135` | 微压缩完成通知事件类型 |
| `estimateMessagesTokens()` | `Utils/Compact.swift:21` | 已有的 token 估算函数 |
| `MICRO_COMPACT_THRESHOLD` | 新增常量 | 50,000 字符阈值（与 TS SDK 一致） |

### 实现位置

**新增代码到 `Utils/Compact.swift`：**
```
// 新增常量
let MICRO_COMPACT_THRESHOLD = 50_000  // 字符

// 新增函数
func shouldMicroCompact(content: String) -> Bool
func microCompact(client:model:content:) async -> String
private func buildMicroCompactPrompt(_ content: String) -> String
```

**修改 `Core/Agent.swift`：**
- 注意：当前 Agent.swift 没有工具执行逻辑（属于 Epic 3）
- 微压缩的集成点是在工具结果被添加到 messages 数组之前
- 由于当前循环不处理 tool_use/tool_result，本 story 需要添加工具结果处理的占位集成点
- 具体来说：当 LLM 响应包含 `tool_use` block 时，模拟工具执行结果经过微压缩处理
- **重要**：本 story 只实现微压缩基础设施和占位集成，完整工具执行在 Epic 3 实现

### 反模式警告

- **不要**将微压缩 LLM 调用的成本计入 `totalCostUsd` — 这是内部操作
- **不要**在压缩失败时截断或丢失原始内容 — 必须保留完整原始结果
- **不要**对 `isError: true` 的工具结果进行微压缩 — 错误结果需要完整保留
- **不要**使用 Codable 序列化微压缩请求 — 使用 raw `[String: Any]` 字典（项目规则 #41）
- **不要**修改 `AnthropicClient` — 使用现有 `sendMessage()` 方法
- **不要**在 `Utils/` 创建子目录 — 必须是扁平结构
- **不要**让微压缩阻塞 Agent 循环过久 — 使用与自动压缩相同的 maxTokens=8192 限制
- **不要**重复压缩已压缩内容 — 检查标记前缀 `[微压缩]`

### 微压缩提示词设计

```
You are a content summarizer for tool results. Compress the following tool output while preserving:
1. File paths and names
2. Error messages and stack traces (in full)
3. Key-value pairs (keys in full, values summarized if >200 chars)
4. Structure and formatting cues (headers, lists, indentation levels)
5. Any numeric data or metrics
6. The first and last 200 characters of any code blocks

Remove:
- Verbose logging output (keep first/last lines)
- Redundant file content listings
- Whitespace and padding
- Repeated patterns (note the count and show one example)

Output the compressed version directly.
```

### TypeScript SDK 参考

```typescript
// TS SDK: utils/compact.ts
export const MICRO_COMPACT_THRESHOLD = 50_000; // characters

export function shouldMicroCompact(content: string): boolean {
  return content.length > MICRO_COMPACT_THRESHOLD;
}

export async function microCompact(
  provider: LLMProvider,
  model: string,
  content: string,
): Promise<string> {
  try {
    const prompt = buildMicroCompactPrompt(content);
    const response = await provider.createMessage({
      model,
      maxTokens: 8192,
      system: 'You are a content summarizer...',
      messages: [{ role: 'user', content: prompt }],
    });
    const summary = response.content
      .filter(b => b.type === 'text')
      .map(b => b.text)
      .join('\n');
    return `[微压缩] 原始长度: ${content.length}, 压缩后长度: ${summary.length}\n\n${summary}`;
  } catch {
    return content; // 失败时保留原始内容
  }
}
```

### 前一 Story 关键经验（Story 2.5）

1. **压缩检查必须在 API 调用之前** — 微压缩也应在工具结果进入 messages 前执行
2. **`compactState` 是局部变量** — 微压缩状态也可以是局部的，不需要 Sendable 担忧
3. **流式路径需要 emit 事件** — 微压缩完成时 emit `.system(.status)` 通知消费者
4. **`withRetry` 需要在闭包外捕获值** — 微压缩调用也需要 `retryClient`、`retryModel` 等模式
5. **MockURLProtocol 测试模式** — 继续使用此模式模拟 LLM 响应

### 文件结构

```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift ✎                    — 添加微压缩集成点
├── Utils/
│   └── Compact.swift ✎                  — 添加微压缩函数

Tests/OpenAgentSDKTests/
└── Utils/
    └── CompactTests.swift ✎             — 添加微压缩测试用例
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.6]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD9]
- [Source: Sources/OpenAgentSDK/Utils/Compact.swift] — 已有自动压缩实现
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift:131] — SystemData 类型
- [Source: _bmad-output/implementation-artifacts/2-5-auto-conversation-compaction.md] — 前一 story 经验

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
