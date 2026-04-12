# Story 13.3: Session Memory 压缩层

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 在长对话中维护跨查询的关键上下文，
以便后续查询不需要重新分析已知信息。

## Acceptance Criteria

1. **AC1: Session Memory 注入到系统提示** -- 给定 Agent 在同一进程中执行了多次查询，当第二次查询开始，则系统提示包含 `<session-memory>` 块，内容为之前查询的关键决策和发现摘要（FR67）。

2. **AC2: 三层压缩 -- micro-compact 触发** -- 给定三层压缩体系，当单个工具结果超过 50,000 字符，则触发 micro-compact（压缩该工具结果）。此层已在 Epic 2 (Story 2.6) 实现，本 Story 不修改。

3. **AC3: 三层压缩 -- auto-compact 触发** -- 给定三层压缩体系，当整个对话 token 数达到上下文窗口的 80%，则触发 auto-compact（压缩整个对话为摘要）。此层已在 Epic 2 (Story 2.5) 实现，本 Story 扩展以提取 Session Memory。

4. **AC4: Session Memory 提取** -- 给定 auto-compact 完成后，当关键决策和用户偏好被提取，则 Session Memory 是进程内的（不跨进程重启持久化，随 Agent 实例生命周期存在），且 Session Memory 总大小不超过 4,000 token，且当 Session Memory 超过 4,000 token 时，采用 FIFO 策略丢弃最早的条目（保留最新的决策）（NFR30: FIFO 剪枝在 10ms 内完成）。

5. **AC5: Token 计数使用语言感知估算** -- 给定 Session Memory 的 token 预算使用 `TokenEstimator.estimate(text:)` 静态方法，当估算 token 数，则对 ASCII 字符使用 1 token ≈ 4 字符，对 CJK 字符使用 1 token ≈ 1.5 字符，混合文本按字符类别分段估算后求和。

6. **AC6: Session Memory 提取机制** -- 给定 auto-compact 完成后，当使用一次 LLM 调用从摘要中提取关键信息，则提取 prompt 要求 LLM 输出固定格式 JSON 数组，每个条目包含 `category`（decision/preference/constraint）、`summary`（一句话摘要）、`context`（相关文件或代码片段），提取结果追加到 SessionMemory 的 FIFO 队列，如果 auto-compact 产生的摘要本身已足够简短（<200 字符），可跳过提取步骤直接将摘要作为单条目存入。

## Tasks / Subtasks

- [x] Task 1: 定义 SessionMemory 类型 (AC: #1, #4, #5)
  - [x] 在 `Sources/OpenAgentSDK/Utils/` 下新建 `SessionMemory.swift`
  - [x] 定义 `SessionMemoryEntry` struct（category: String, summary: String, context: String, timestamp: Date）
  - [x] 定义 `SessionMemory` final class（内部使用 `[SessionMemoryEntry]` 数组作为 FIFO 队列）
  - [x] 实现线程安全（使用 `NSLock` 或内部串行 DispatchQueue，与 SkillRegistry 一致）
  - [x] 实现 `append(_ entry: SessionMemoryEntry)` 方法（追加条目）
  - [x] 实现 `formatForPrompt() -> String?` 方法（格式化为 `<session-memory>` XML 块）
  - [x] 实现 FIFO 剪枝逻辑：添加条目后检查总 token 数，超出 4,000 时从队列头部移除最早条目
  - [x] 实现 `tokenCount() -> Int` 使用 `TokenEstimator.estimate()`

- [x] Task 2: 定义 TokenEstimator 工具 (AC: #5)
  - [x] 在 `Sources/OpenAgentSDK/Utils/` 下新建 `TokenEstimator.swift`
  - [x] 定义 `TokenEstimator` enum 命名空间（无实例，纯 static 方法）
  - [x] 实现 `public static func estimate(_ text: String) -> Int` 方法
  - [x] ASCII 字符：`utf8.count / 4`
  - [x] CJK 字符：Unicode 范围 `\u{4E00}`...`\u{9FFF}` 计数 × 1.5
  - [x] 混合文本：分段估算后求和
  - [x] 编写 `TokenEstimatorTests.swift` 覆盖纯 ASCII、纯 CJK、混合文本

- [x] Task 3: 在 Agent 中集成 SessionMemory 实例 (AC: #1, #4)
  - [x] 在 `Agent` 类中添加 `private let sessionMemory = SessionMemory()` 属性
  - [x] 在 `buildSystemPrompt()` 中追加 `<session-memory>` 块（如果非空）
  - [x] `<session-memory>` 块追加在 `parts` 数组的末尾（在 project-instructions 之后）

- [x] Task 4: 修改 auto-compact 完成后提取 Session Memory (AC: #3, #4, #6)
  - [x] 修改 `compactConversation()` 函数签名，添加 `sessionMemory: SessionMemory?` 参数
  - [x] 在 compact 成功后（summary 非空），调用 `extractSessionMemory()` 提取条目
  - [x] 实现 `extractSessionMemory()` 函数：使用 LLM 调用从 summary 中提取 JSON 数组
  - [x] 如果 summary 长度 < 200 字符，跳过 LLM 调用，直接作为单条目存入
  - [x] 解析 LLM 返回的 JSON 数组为 `[SessionMemoryEntry]`
  - [x] 逐个 `sessionMemory.append()` 追加条目（FIFO 剪枝自动触发）
  - [x] 修改 `Agent.swift` 中 `prompt()` 和 `stream()` 调用 `compactConversation()` 的位置，传入 `sessionMemory`

- [x] Task 5: 编写单元测试 (AC: #1, #4, #5, #6)
  - [x] 创建 `Tests/OpenAgentSDKTests/Utils/SessionMemoryTests.swift`
  - [x] 测试 AC1：多次查询后 session-memory 块出现在系统提示
  - [x] 测试 AC4：FIFO 剪枝（添加条目直到超出 4000 token，验证最早条目被移除）
  - [x] 测试 AC4：FIFO 剪枝在 10ms 内完成
  - [x] 测试 AC5：TokenEstimator 对 ASCII/CJK/混合文本的估算准确性
  - [x] 测试 AC6：auto-compact 后 Session Memory 被提取和追加
  - [x] 测试 AC6：短摘要（<200 字符）跳过 LLM 调用直接存入

- [x] Task 6: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- **Epic 13**（会话生命周期管理）的第三个也是最后一个 Story
- **核心目标：** 在已有的 micro-compact 和 auto-compact 基础上，增加第三层压缩 -- Session Memory，维护跨查询的关键上下文
- **前置依赖：** Epic 2（auto-compact 和 micro-compact 已实现），Epic 12（FileCache 用于压缩差异），Story 13.1 和 13.2 已完成
- **FR 覆盖：** FR67（对话压缩支持三层体系：micro-compact → auto-compact → session memory）
- **用户场景：** Agent 在一次长会话中处理了 20 个文件，session memory 保留关键决策摘要，后续查询不需要重新分析
- **注意：** TypeScript SDK 没有等效的 Session Memory 功能 -- 这是 Swift SDK 的创新设计

### 关键设计决策

**1. SessionMemory 为 final class（非 actor）：**

与 SkillRegistry 一致 -- 注册/追加是一次性操作，查询是只读的。使用 `NSLock` 或内部串行 DispatchQueue 保护并发安全。不使用 actor 避免在 Agent 的同步上下文中产生不必要的 `await` 开销。

**2. 进程内存储（不持久化）：**

Session Memory 随 Agent 实例生命周期存在。不跨进程重启持久化，不写入磁盘。原因：
- Session Memory 是性能优化（减少重复分析），不是持久化需求
- 如果需要跨进程，开发者可使用 SessionStore 保存对话后在新进程中恢复

**3. 4,000 token 预算：**

使用语言感知的字符近似估算。4,000 token 约 16KB ASCII 文本或约 6KB CJK 文本。足够保留 20-30 个关键决策条目，不会显著增加系统提示长度。

**4. FIFO 剪枝策略：**

保留最新决策，丢弃最早条目。与 NFR30 要求一致（剪枝在 10ms 内完成）。实现简单 -- 从数组头部移除元素。

**5. LLM 提取 vs 直接存入：**

auto-compact 后如果摘要 <200 字符（说明对话本身很简短），跳过 LLM 提取调用直接存入。这避免了对短对话产生不必要的 API 开销。

### 三层压缩体系架构

```
Layer 1: micro-compact (Epic 2, Story 2.6)
  ├─ 触发：工具结果 > 50,000 字符
  ├─ 行为：LLM 压缩单个工具结果
  └─ 作用域：单个工具调用

Layer 2: auto-compact (Epic 2, Story 2.5, 本 Story 扩展)
  ├─ 触发：对话 token 达到上下文窗口 80%
  ├─ 行为：LLM 将整个对话压缩为摘要
  ├─ 作用域：整个对话历史
  └─ 新增：完成后提取 Session Memory 条目 [本 Story]

Layer 3: session memory (本 Story)
  ├─ 触发：auto-compact 完成后自动提取
  ├─ 行为：从摘要中提取关键决策/偏好/约束
  ├─ 作用域：跨查询（进程内）
  └─ 注入：每次查询的系统提示中
```

### 已有代码分析

**Compact.swift（需修改）：**

1. `compactConversation()` 函数（第 79-158 行）：
   - 完成后返回 `(compactedMessages, summary, state)`
   - 需要在返回前添加 Session Memory 提取逻辑
   - 需要新增 `sessionMemory` 参数

2. `AutoCompactState` struct（第 4-23 行）：
   - 不需要修改 -- 状态追踪与 Session Memory 无关

**Agent.swift（需修改）：**

1. `buildSystemPrompt()` 方法（第 223-255 行）：
   - 当前组装顺序：systemPrompt -> git-context -> global-instructions -> project-instructions
   - 需要在末尾追加 `<session-memory>` 块

2. `prompt()` 方法中的 auto-compact 调用点：
   - 搜索 `compactConversation(client:` 在 prompt() 中的调用位置
   - 传入 `sessionMemory` 参数

3. `stream()` 方法中的 auto-compact 调用点：
   - 搜索 `compactConversation(client:` 在 stream() 中的调用位置
   - 传入 `sessionMemory` 参数

**注意：** 前序 Story 反复强调 -- Agent.swift 中修改必须同时检查 `prompt()` 和 `stream()` 两个方法！

**Tokens.swift（不需修改）：**
- `estimateCost()` 和 `getContextWindowSize()` 不变
- Token 估算使用新文件 `TokenEstimator.swift`

### TypeScript SDK 参考

TypeScript SDK 没有等效的 Session Memory 功能。这是 Swift SDK 根据 FR67 要求的创新设计。

参考 TypeScript SDK 的 `compact.ts` 中的 `compactConversation()` 模式：
- TypeScript 使用 LLM 调用生成摘要
- Swift 的 Session Memory 提取使用相同的 LLM 调用模式，但从摘要中额外提取结构化数据

### SessionMemory 类型设计

```swift
/// A single entry in the session memory FIFO queue.
struct SessionMemoryEntry: Sendable {
    let category: String   // "decision", "preference", "constraint"
    let summary: String
    let context: String    // related file or code snippet
    let timestamp: Date
}

/// Manages cross-query context retention via a FIFO queue of memory entries.
/// Thread-safe via internal lock. Bounded to 4,000 tokens.
final class SessionMemory {
    private var entries: [SessionMemoryEntry] = []
    private let lock = NSLock()
    private let maxTokens: Int = 4000

    /// Append an entry, triggering FIFO pruning if over budget.
    func append(_ entry: SessionMemoryEntry)

    /// Format entries as XML block for system prompt injection.
    /// Returns nil if no entries exist.
    func formatForPrompt() -> String?

    /// Current estimated token count across all entries.
    func tokenCount() -> Int
}
```

### TokenEstimator 类型设计

```swift
/// Language-aware token estimation for Claude models.
/// Zero external dependencies -- uses character-based heuristics.
enum TokenEstimator {
    /// Estimate token count for text.
    /// ASCII: 1 token ≈ 4 chars. CJK: 1 token ≈ 1.5 chars.
    static func estimate(_ text: String) -> Int
}
```

### 提取 Prompt 设计

```
Analyze the following conversation summary and extract key information as a JSON array.

Each entry must have:
- "category": one of "decision", "preference", "constraint"
- "summary": a one-sentence summary
- "context": related file path or code snippet (if applicable)

Rules:
- Extract ONLY non-obvious, important information
- Ignore generic pleasantries and routine operations
- Maximum 5 entries per extraction
- Each summary must be under 100 characters

Conversation summary:
{summary}
```

### formatForPrompt() 输出格式

```
<session-memory>
- [decision] Decided to use LRU cache for file reads (main.swift)
- [constraint] User requires macOS 13+ compatibility
- [preference] User prefers snake_case for JSON fields
</session-memory>
```

### 模块边界

**本 Story 涉及文件：**
```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift                     # 修改：+ sessionMemory 属性，buildSystemPrompt() 注入，prompt()/stream() 传参
├── Utils/
│   ├── SessionMemory.swift             # 新建：SessionMemory + SessionMemoryEntry
│   ├── TokenEstimator.swift            # 新建：语言感知 token 估算
│   └── Compact.swift                   # 修改：compactConversation() + sessionMemory 参数，extractSessionMemory()
└── ...

Tests/OpenAgentSDKTests/
├── Utils/
│   ├── SessionMemoryTests.swift        # 新建：Session Memory 测试
│   └── TokenEstimatorTests.swift       # 新建：TokenEstimator 测试
└── ...
```

### Logger 集成约定

为 Epic 14 Logger 预留调用点：
- **预留位置：**
  - Session Memory 条目添加：`Logger.shared.debug("Session memory entry added", data: ["category": category, "totalEntries": count])`
  - Session Memory FIFO 剪枝：`Logger.shared.info("Session memory FIFO prune", data: ["prunedCount": pruned, "remainingTokens": tokenCount])`
  - Session Memory 提取：`Logger.shared.debug("Session memory extracted", data: ["entriesExtracted": count, "source": "llm" / "direct"])`
- **预实现方案：** `Logger.shared` 当前为空实现（no-op），不引入编译错误

### 反模式警告

- **不要**将 SessionMemory 设计为 actor -- 使用 final class + NSLock，与 SkillRegistry 模式一致
- **不要**将 Session Memory 持久化到磁盘 -- 它是进程内的，随 Agent 实例生命周期存在
- **不要**在每次查询时都执行 LLM 提取调用 -- 只在 auto-compact 完成后提取
- **不要**忘记同时更新 `prompt()` 和 `stream()` 两个方法 -- 前序 Story 反复强调这是常见遗漏点
- **不要**在 `Utils/` 中创建嵌套子目录 -- 保持扁平结构（project-context 规则 32）
- **不要**使用 `Set` 管理 SessionMemory 条目 -- 使用有序数组保持 FIFO 语义
- **不要**在 prompt/stream 循环中修改 sessionMemory -- 只在 auto-compact 完成后追加
- **不要**让 Session Memory 影响查询延迟 -- formatForPrompt() 是纯字符串拼接，FIFO 剪枝在 10ms 内
- **不要**使用 `Codable` 进行 LLM 提取结果的 JSON 解析 -- 使用 `JSONSerialization`（与现有 Compact.swift 模式一致）
- **不要**在 SessionMemory 中存储敏感信息（API key、密码）-- 只存储决策、偏好、约束
- **不要**在 `buildSystemPrompt()` 中添加 `<session-memory>` 块时破坏已有的 XML 块顺序
- **不要**在 extractSessionMemory 中使用过长的 prompt -- 保持简洁，与 compact prompt 风格一致
- **不要**对 <200 字符的短摘要执行 LLM 提取 -- 直接作为单条目存入节省 API 调用

### 测试策略

**AC1 测试（Session Memory 注入到系统提示）：**
- 创建 Agent，执行第一次查询（触发 auto-compact + 提取）
- 执行第二次查询，验证 `buildSystemPrompt()` 返回的字符串包含 `<session-memory>` 块
- 验证空 Session Memory 时无 `<session-memory>` 块

**AC4 测试（FIFO 剪枝）：**
- 创建 SessionMemory，设置 maxTokens = 100（测试用低阈值）
- 添加条目直到超出 100 token
- 验证最早的条目被移除，最新条目保留
- 验证剪枝操作在 10ms 内完成（使用 `ContinuousClock.now` 测量）

**AC5 测试（TokenEstimator）：**
- 纯 ASCII 文本：验证 ≈ text.utf8.count / 4
- 纯 CJK 文本：验证 ≈ cjkCharCount × 1.5
- 混合文本：验证分段估算后求和

**AC6 测试（提取机制）：**
- 使用 MockLLMClient 模拟 LLM 提取调用
- 验证 auto-compact 后 SessionMemory 有新条目
- 验证 JSON 解析正确性（category/summary/context 字段）
- 验证 <200 字符摘要直接存入（无 LLM 调用）

### 前序 Story 学习要点

**Story 13.2（Query 级别中断）完成情况：**
- 完整测试套件：2435 tests passing, 4 skipped, 0 failures
- **关键教训：** `stream()` 使用 captured 变量模式满足 Sendable 约束
- `QueryStatus.cancelled` 和 `QueryResult.isCancelled` 已添加
- `Agent._interrupted` 标志用于中断检测
- **与本 Story 的交互：** 中断不影响 Session Memory -- Session Memory 只在 auto-compact 成功后更新

**Story 13.1（运行时动态模型切换）完成情况：**
- **关键教训：** Agent.swift 中修改必须同时检查 `prompt()` 和 `stream()` 两个方法
- `Agent.model` 已改为 `public private(set) var`
- `CostBreakdownEntry` 已定义在 AgentTypes.swift
- `SDKError.invalidConfiguration(String)` case 已添加

**Story 12.2（缓存集成）完成情况：**
- **关键教训：** compactConversation() 已接受 `fileCache: FileCache?` 参数
- `AutoCompactState.lastCompactTime` 用于确定哪些文件在压缩后被修改
- **与本 Story 的交互：** `compactConversation()` 签名已有一个可选参数，添加 `sessionMemory` 参数保持一致模式

**关键代码模式：**
- `compactConversation()` 是一个自由函数（非 Agent 方法），位于 `Compact.swift`
- Agent 的 `prompt()` 和 `stream()` 都调用 `compactConversation()`
- `buildSystemPrompt()` 组装系统提示各 XML 块，追加新块只需在 `parts` 数组后添加
- `TokenUsage` 使用 struct，`SessionMemoryEntry` 也使用 struct

### Project Structure Notes

- 新建文件：`Sources/OpenAgentSDK/Utils/SessionMemory.swift` 和 `Sources/OpenAgentSDK/Utils/TokenEstimator.swift`
- 修改文件：`Agent.swift`（sessionMemory 属性 + buildSystemPrompt + prompt/stream 传参）、`Compact.swift`（compactConversation 签名 + 提取逻辑）
- 测试文件：`Tests/OpenAgentSDKTests/Utils/SessionMemoryTests.swift` 和 `Tests/OpenAgentSDKTests/Utils/TokenEstimatorTests.swift`
- Utils/ 保持扁平结构，不创建子目录

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 13.3] -- 验收标准（6 个 AC：session-memory 注入、三层压缩体系、FIFO 剪枝、token 估算、提取机制）
- [Source: _bmad-output/planning-artifacts/epics.md#FR67] -- 跨查询上下文保留功能需求
- [Source: _bmad-output/planning-artifacts/epics.md#NFR30] -- Session Memory FIFO 剪枝在 10ms 内完成
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 13 会话生命周期管理] -- Epic 级别上下文
- [Source: _bmad-output/implementation-artifacts/13-2-query-level-abort.md] -- 前序 Story 完成记录
- [Source: _bmad-output/implementation-artifacts/13-1-runtime-dynamic-model-switching.md] -- 前序 Story 完成记录
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L223-255] -- buildSystemPrompt() 方法
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L280] -- prompt() 方法入口
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L581] -- stream() 方法入口
- [Source: Sources/OpenAgentSDK/Utils/Compact.swift#L79-158] -- compactConversation() 函数
- [Source: Sources/OpenAgentSDK/Utils/Compact.swift#L4-23] -- AutoCompactState struct
- [Source: Sources/OpenAgentSDK/Utils/Tokens.swift#L34-42] -- estimateCost() 模式参考
- [Source: Sources/OpenAgentSDK/Utils/Tokens.swift#L1-17] -- MODEL_CONTEXT_WINDOWS 和 DEFAULT_CONTEXT_WINDOW
- [Source: _bmad-output/planning-artifacts/architecture.md#AD1] -- 并发模型决策
- [Source: _bmad-output/planning-artifacts/architecture.md#AD2] -- 流式模型决策

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- TokenEstimator emoji fix: Initially counted non-CJK characters by scalar count (1 char = 0 tokens). Fixed to count by UTF-8 byte length so 4-byte emoji correctly estimate 1 token.

### Completion Notes List

- Created TokenEstimator enum with language-aware token estimation: ASCII via UTF-8 byte count / 4, CJK via char count * 1.5, other Unicode (emoji, Cyrillic) via UTF-8 byte count / 4
- Created SessionMemory final class with NSLock-based thread safety, FIFO pruning to 4000 token budget, formatForPrompt() XML output, and @unchecked Sendable conformance
- Integrated SessionMemory into Agent: added sessionMemory property, injected `<session-memory>` block in buildSystemPrompt() after project-instructions, passed sessionMemory to compactConversation() in both prompt() and stream()
- Modified compactConversation() to accept optional sessionMemory parameter and extract session memory after successful compaction
- Implemented extractSessionMemory() with dual path: short summaries (<200 chars) stored directly, long summaries extracted via LLM call into structured JSON entries
- Added helper functions: buildSessionMemoryExtractionPrompt(), stripMarkdownFences()
- ATDD tests (pre-existing) all pass: SessionMemoryTests (17 tests), TokenEstimatorTests (10 tests)
- Full test suite: 2471 tests passing, 4 skipped, 0 failures

### File List

New files:
- Sources/OpenAgentSDK/Utils/TokenEstimator.swift
- Sources/OpenAgentSDK/Utils/SessionMemory.swift

Modified files:
- Sources/OpenAgentSDK/Core/Agent.swift
- Sources/OpenAgentSDK/Utils/Compact.swift
