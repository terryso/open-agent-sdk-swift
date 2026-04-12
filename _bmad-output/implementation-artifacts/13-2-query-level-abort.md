# Story 13.2: Query 级别中断（Abort）

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望可以中断正在执行的 Agent 查询，
以便长时间运行的任务可以被用户主动取消。

## Acceptance Criteria

1. **AC1: Task.cancel() 中断查询** -- 给定 Agent 正在执行查询（使用 `Task { agent.stream(...) }`），当开发者取消该 Task（`task.cancel()`），则当前 LLM HTTP 请求被取消，工具执行收到 `CancellationError` 并停止，返回 `QueryResult` 包含 `isCancelled: true`、已完成轮次的结果和部分文本（FR60）。

2. **AC2: FileWriteTool 中断回滚** -- 给定 FileWriteTool 正在写入文件时收到取消信号，当中断到达，则如果文件是新创建的，删除该文件（回滚），如果文件是覆盖写入的，保留原始文件不变（写入到临时文件，未 rename），返回的 `QueryResult.toolResults` 包含已成功完成的工具结果。

3. **AC3: FileEditTool 中断回滚** -- 给定 FileEditTool 正在编辑文件时收到取消信号，当中断到达，则编辑前已备份原始文件内容（内存或临时文件），中断时恢复原始内容，如果备份时尚未开始写入，无需恢复（文件未被修改）。

4. **AC4: AsyncStream 中断事件** -- 给定流式响应（`AsyncStream<SDKMessage>`）被中断，当取消信号到达，则 AsyncStream 发出最后一个 `SDKMessage.cancelled` 事件（或包含 cancelled 状态的 result 事件），AsyncStream 正常 finish（消费者不收到错误）。

## Tasks / Subtasks

- [x] Task 1: 添加 QueryResult.isCancelled 字段和 SDKMessage cancelled/subtype (AC: #1, #4)
  - [x] 在 `QueryResult` 中添加 `isCancelled: Bool` 字段（默认 false）
  - [x] 在 `SDKMessage.ResultData.Subtype` 中添加 `.cancelled` case
  - [x] 在 `QueryStatus` 枚举中添加 `.cancelled` case
  - [x] 更新 `QueryResult.init()` 和 `SDKMessage.ResultData.init()` 签名

- [x] Task 2: 实现 Agent.interrupt() 方法 (AC: #1)
  - [x] 在 `Agent` 类中添加 `public func interrupt()` 方法
  - [x] 在 Agent 内部维护 `_interrupted: Bool` 标志和 `_cancelStreamTask` / `_cancelCurrentQuery` 闭包
  - [x] `interrupt()` 设置标志并调用闭包取消内部 Task
  - [x] 使用 `_interrupted` 标志和 `Task.isCancelled` 双重检查模式供工具检查

- [x] Task 3: 修改 prompt() 方法支持取消检测 (AC: #1)
  - [x] 在 prompt() 的 while 循环顶部检查 `Task.isCancelled || _interrupted`
  - [x] 捕获错误（含 CancellationError/URLError.cancelled）并返回带有 `isCancelled: true` 的 `QueryResult`
  - [x] 保留已完成的轮次结果和部分文本

- [x] Task 4: 修改 stream() 方法支持取消检测 (AC: #1, #4)
  - [x] stream() 已有 `task.cancel()` 在 `onTermination` 中 -- 验证其工作正常
  - [x] 在 while 循环顶部和 SSE 事件处理循环中添加 `Task.isCancelled` 检查
  - [x] 取消时 yield `.result` 消息（subtype: `.cancelled`），然后 `continuation.finish()`
  - [x] 确保 MCP cleanup 仍然执行（defer 块已覆盖）

- [x] Task 5: 修改 ToolExecutor 支持取消传播 (AC: #1, #2, #3)
  - [x] 不修改 ToolContext -- Swift 协作取消通过 `Task.isCancelled` 全局可用
  - [x] 在 `ToolExecutor.executeTools()` 入口添加 `Task.isCancelled` 检查
  - [x] 在 `executeReadOnlyConcurrent` 和 `executeMutationsSerial` 之间添加取消检查
  - [x] 在 `executeMutationsSerial` 的串行循环中每步检查取消

- [x] Task 6: 修改 FileWriteTool 支持原子写入和回滚 (AC: #2)
  - [x] 在写入前检查 `Task.isCancelled`，如果已取消则跳过写入
  - [x] `atomically: true` 保证原子性 -- 取消发生在 write 前则无文件，发生在 write 中则原始文件不受影响

- [x] Task 7: 修改 FileEditTool 支持备份恢复 (AC: #3)
  - [x] 在编辑前将原始文件内容保存到 `originalContent` 内存变量
  - [x] 在替换前和写回前检查 `Task.isCancelled`
  - [x] 如果取消在写回前到达，文件未被修改无需恢复

- [x] Task 8: 编写单元测试 (AC: #1, #2, #3, #4)
  - [x] 创建 `Tests/OpenAgentSDKTests/Core/AbortTests.swift`
  - [x] 测试 AC1：3 个测试覆盖 Task.cancel()、完成轮次保留、Agent.interrupt()
  - [x] 测试 AC2：3 个测试覆盖新文件未创建、覆盖保留原始、工具结果保留
  - [x] 测试 AC3：2 个测试覆盖编辑恢复、写前取消文件不变
  - [x] 测试 AC4：3 个测试覆盖取消结果事件、流正常结束、部分文本保留
  - [x] 额外 5 个类型测试覆盖 QueryStatus.cancelled、QueryResult.isCancelled、ResultData.Subtype.cancelled

- [x] Task 9: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过 -- 2435 tests, 4 skipped, 0 failures

## Dev Notes

### 本 Story 的定位

- **Epic 13**（会话生命周期管理）的第二个 Story
- **核心目标：** 实现查询级别中断，让开发者可以主动取消长时间运行的 Agent 查询
- **前置依赖：** Epic 1-12 全部完成，特别是 Epic 1（Agent 创建与配置）、Epic 2（流式响应）、Epic 3（工具系统）
- **Story 13.1 已完成：** Agent.model 已改为 `public private(set) var`，CostBreakdownEntry 已定义
- **FR 覆盖：** FR60（开发者可以中断正在执行的 Agent 查询，获得已生成的部分结果）
- **用户场景：** Agent 执行了 5 分钟还在跑，开发者中断后仍能看到前 3 轮的工具调用结果

### 关键设计决策

**1. 使用 Swift 协作取消模型（Cooperative Cancellation）：**

Swift 并发使用协作式取消 -- `Task.cancel()` 设置取消标志，子任务通过 `Task.isCancelled` 或 `try Task.checkCancellation()` 检查。这与 TypeScript SDK 的 `AbortController` / `AbortSignal` 模式不同。

**Swift 取消传播路径：**
```
task.cancel()
  -> Task.isCancelled = true（在整个子任务树中）
  -> URLSession data task 收到 cancel（URLSession 自动响应 Task 取消）
  -> ToolExecutor 中的 TaskGroup 子任务自动继承取消状态
  -> 工具闭包中通过 Task.isCancelled 检查
```

**2. Agent.interrupt() 方法 vs 直接 Task.cancel()：**

TypeScript SDK 提供 `agent.interrupt()` 方法，内部调用 `this.abortCtrl?.abort()`。

Swift 方案：
- **推荐方案：** 同时提供 `Agent.interrupt()` 便利方法和支持直接 `Task.cancel()`
- `Agent.interrupt()` 内部存储对当前查询 Task 的引用，调用 `_currentQueryTask?.cancel()`
- 直接使用 `Task { ... }` 包装 `agent.stream()` 或 `agent.prompt()` 的用户也可以直接 `task.cancel()`
- 两种方式都有效，因为 Swift 的取消是协作式的

**3. 取消时的结果收集：**

取消时需要：
- 收集已完成轮次的文本和工具结果
- 设置 `isCancelled: true`（QueryResult）或 `subtype: .cancelled`（SDKMessage.ResultData）
- 对于 prompt()：返回带有取消状态的 QueryResult
- 对于 stream()：yield 最后的 cancelled result 事件，然后 finish continuation

**4. stream() 的现有 onTermination：**

Agent.stream() 已经在 `continuation.onTermination` 中调用 `task.cancel()`（第 1171-1173 行）。这意味着当消费者停止迭代 AsyncStream 时，内部 Task 已经会被取消。但开发者可能需要在 Task 仍活跃时主动中断。

### TypeScript SDK 参考映射

| Swift 功能 | TypeScript 对应 | 文件 |
|---|---|---|
| `Agent.interrupt()` | `agent.interrupt()` | `src/agent.ts:407-409` |
| `Task.isCancelled` 检查 | `this.config.abortSignal?.aborted` | `src/engine.ts:239` |
| `Task.cancel()` | `this.abortCtrl?.abort()` | `src/agent.ts:408` |
| `ToolContext` 中无显式 signal | `context.abortSignal` | `src/types.ts:193` |

**TypeScript SDK interrupt() 实现：**
```typescript
async interrupt(): Promise<void> {
    this.abortCtrl?.abort()
}
```

**TypeScript SDK engine loop 中 abort 检查：**
```typescript
while (turnsRemaining > 0) {
    if (this.config.abortSignal?.aborted) break
    // ... loop body
}
```

**TypeScript SDK 使用 AbortController + AbortSignal：**
- `query()` 方法创建 `AbortController`，存储在 `this.abortCtrl`
- `engine.ts` 配置中传递 `abortSignal`
- 工具（如 Bash）通过 `context.abortSignal.addEventListener('abort', ...)` 响应
- Swift 中不需要这种模式 -- Swift 的 Task 取消自动传播到子任务和 URLSession

### 已有代码分析

**Agent.swift（核心修改文件）：**

1. `stream()` 方法（第 581-1175 行）：
   - 第 640 行：内部创建 `_Concurrency.Task { ... }`
   - 第 1171-1173 行：`continuation.onTermination = { @Sendable _ in task.cancel() }`
   - 需要在 while 循环中（第 719 行）添加 `Task.isCancelled` 检查
   - 需要在 SSE 事件循环中（第 786 行 `for try await event in eventStream`）添加取消检查
   - 取消时需要 yield cancelled result 然后 finish

2. `prompt()` 方法（第 254-520 行）：
   - while 循环在第 299 行：`while turnCount < maxTurns`
   - 需要在循环顶部添加 `guard !Task.isCancelled else { ... }` 或 `try Task.checkCancellation()`
   - 取消时构建带有 isCancelled=true 的 QueryResult 返回

3. Agent 属性需要添加：
   - `private var _currentQueryTask: Task<Void, Never>?` -- 跟踪当前查询任务

**ToolExecutor.swift（需修改）：**
- `executeTools()`（第 181 行）：添加取消检查
- `executeMutationsSerial()`（第 264 行）：每步检查 `Task.isCancelled`
- `executeReadOnlyConcurrent()`（第 219 行）：TaskGroup 子任务自动继承取消，但主循环需要检查
- **不需要修改 ToolContext** -- Swift 协作取消通过 `Task.isCancelled` 全局可用，不需要传参

**FileWriteTool.swift（需修改）：**
- 当前使用 `input.content.write(toFile:atomically:encoding:)`（第 67-70 行）
- `atomically: true` 已经先写入临时文件再 rename，提供了原子性保障
- 但需要额外的取消检查逻辑：
  - 在写入前检查 `Task.isCancelled`
  - 如果取消发生在 `write(toFile:atomically:)` 调用前，直接返回错误结果
  - 如果取消发生在写入中，`atomically: true` 保证原始文件不受影响（因为 rename 未完成）

**FileEditTool.swift（需修改）：**
- 当前流程：读取文件 -> 检查匹配 -> 替换内容 -> 写回文件
- 需要在替换后、写回前备份原始内容
- 取消时恢复备份（如果写回尚未完成或已被取消中断）

**SDKMessage.swift（需修改）：**
- `ResultData.Subtype`（第 150 行）：添加 `.cancelled` case
- `ResultData.init()`：可能需要更新以支持 cancelled 状态

**AgentTypes.swift（需修改）：**
- `QueryResult`（第 269 行）：添加 `isCancelled: Bool` 字段
- `QueryStatus`（第 231 行）：添加 `.cancelled` case

**ErrorTypes.swift（不需修改）：**
- `SDKError.abortError`（第 38 行）已存在 -- 但这个用于错误路径，不是取消的正常路径
- 取消使用正常的 QueryResult 返回（isCancelled=true），而不是抛出错误

### 取消时的行为设计

**prompt() 取消流程：**
```
1. 开发者调用 task.cancel()
2. prompt() while 循环顶部检查 Task.isCancelled -> true
3. 构建 QueryResult:
   - text: 已完成的轮次累积文本
   - usage: 到目前为止的 token 使用量
   - numTurns: 已完成轮次数
   - status: .cancelled
   - isCancelled: true
   - costBreakdown: 到目前为止的成本明细
4. 返回 QueryResult
```

**stream() 取消流程：**
```
1. 开发者调用 task.cancel() 或 consumer 停止迭代
2. stream() while 循环顶部检查 Task.isCancelled -> true
   OR SSE 事件循环中 for try await 抛出 CancellationError
3. yield .result(ResultData(subtype: .cancelled, ...))
4. 执行 MCP cleanup（defer 块）
5. continuation.finish()
```

**工具取消流程：**
```
1. Task.isCancelled 在 ToolExecutor 中检查
2. 如果在工具调度前检测到取消 -> 跳过未开始的工具，返回已完成的工具结果
3. 如果工具正在执行中 -> FileWriteTool/FileEditTool 的原子性保障保护文件完整性
4. FileWriteTool: atomically: true 保证不会产生半写文件
5. FileEditTool: 备份+恢复机制保护原始文件
```

### FileWriteTool 原子写入分析

**现有代码（第 66-77 行）：**
```swift
// Write file atomically
do {
    try input.content.write(
        toFile: resolvedPath,
        atomically: true,
        encoding: .utf8
    )
}
```

`String.write(toFile:atomically:encoding:)` with `atomically: true` 的行为：
- 先写入临时文件（同一目录下）
- 写入成功后 rename 到目标路径
- 如果写入中途失败（包括取消），临时文件被删除，原始文件不受影响

**AC2 的回滚需求已部分满足：**
- "如果文件是新创建的，删除该文件" -- `atomically: true` 下，如果 rename 未完成，新文件不存在
- "如果文件是覆盖写入的，保留原始文件不变" -- `atomically: true` 保证这一点
- **额外需要做的：** 在调用 write 之前检查 `Task.isCancelled`，如果已取消则跳过写入

**需要注意：** `write(toFile:atomically:)` 不接受 cancellation -- 它是一个同步调用。但因为它在 `async` 闭包中执行，所以 Task 取消不会中断正在进行的 write 调用。write 要么完成（atomically），要么不被调用。

### FileEditTool 备份恢复设计

**当前流程（FileEditTool.swift 第 50-106 行）：**
1. 读取文件内容
2. 检查 old_string 唯一性
3. 替换字符串
4. 写回文件

**修改后的流程：**
1. 读取文件内容 -> **同时保存备份到内存变量 `originalContent`**
2. 检查 old_string 唯一性
3. 检查 `Task.isCancelled` -> 如果已取消，返回取消结果
4. 替换字符串
5. 检查 `Task.isCancelled` -> 如果已取消，无需恢复（尚未写回）
6. 写回文件
7. 如果写回过程中被取消（不太可能，因为是同步操作），恢复 `originalContent`

### 模块边界

**本 Story 涉及文件：**
```
Sources/OpenAgentSDK/
├── Core/
│   ├── Agent.swift              # 修改：+ interrupt(), + _currentQueryTask, prompt()/stream() 中添加取消检测
│   └── ToolExecutor.swift       # 修改：executeTools() 中添加取消检查
├── Types/
│   ├── AgentTypes.swift         # 修改：QueryResult + isCancelled, QueryStatus + .cancelled
│   ├── SDKMessage.swift         # 修改：ResultData.Subtype + .cancelled
│   └── ToolTypes.swift          # 可能修改：ToolContext（如果需要传递取消状态，但当前评估不需要）
├── Tools/
│   └── Core/
│       ├── FileWriteTool.swift  # 修改：写入前检查 Task.isCancelled
│       └── FileEditTool.swift   # 修改：备份+恢复机制
└── ...

Tests/OpenAgentSDKTests/
├── Core/
│   ├── AbortTests.swift         # 新建：中断测试
│   └── ...
└── ...
```

### Logger 集成约定

为 Epic 14 Logger 预留调用点：
- **预留位置：**
  - 查询中断：`Logger.shared.info("Query interrupted", data: ["turnsCompleted": turnCount, "durationMs": elapsed])`
  - 工具取消：`Logger.shared.debug("Tool execution cancelled", data: ["tool": toolName])`
  - 文件回滚：`Logger.shared.info("File write cancelled, rollback", data: ["path": filePath])`
- **预实现方案：** `Logger.shared` 当前为空实现（no-op），不引入编译错误

### 反模式警告

- **不要**使用 `AbortController` / `AbortSignal` 模式 -- Swift 使用协作式取消（`Task.isCancelled` / `Task.checkCancellation()`），不需要额外的 signal 传递机制
- **不要**在 `ToolContext` 中添加 `abortSignal` 字段 -- `Task.isCancelled` 是全局可用的，不需要通过 context 传递
- **不要**在 prompt() 中通过 `throw CancellationError` 处理取消 -- 捕获后返回 QueryResult（isCancelled=true）是更友好的 API
- **不要**在工具执行中 `throw` 取消错误 -- 工具应该返回 ToolResult（isError=true），由 ToolExecutor 统一处理
- **不要**修改 `ToolProtocol` 的 `call` 方法签名 -- 取消通过 `Task.isCancelled` 检查，不改变协议
- **不要**在 `atomically: true` 的 write 之外额外创建临时文件 -- `String.write(toFile:atomically:)` 已经处理了原子性
- **不要**忘记同时更新 `prompt()` 和 `stream()` 两个方法 -- 前序 Story 反复强调这是常见遗漏点
- **不要**在 Agent 类上使用 `@MainActor` 或其他 actor 隔离 -- Agent 是普通 class，不是 actor
- **不要**在取消路径上执行耗时操作 -- 取消应该快速完成，不要尝试额外的 LLM 调用
- **不要**忘记 MCP cleanup -- stream() 中的 defer 块已覆盖 MCP 连接清理
- **不要**在 `QueryStatus` 和 `ResultData.Subtype` 中使用不同的命名 -- 保持一致（都用 `.cancelled`）

### 测试策略

**AC1 测试（Task.cancel() 中断查询）：**
- 在 Task 中启动 `agent.prompt()`（使用 MockLLMClient 模拟长时间响应）
- 调用 `task.cancel()`
- 验证返回的 QueryResult.isCancelled == true
- 验证 result.status == .cancelled
- 验证 result.numTurns 反映已完成轮次
- 验证 result.text 包含部分文本

**AC2 测试（FileWriteTool 中断回滚）：**
- 创建一个新文件路径（文件不存在）
- 配置 MockLLMClient 返回 tool_use 调用 Write 工具
- 在工具执行前取消 Task
- 验证新文件不存在（未被创建）
- 对已存在文件进行覆盖写入时取消
- 验证原始文件内容未改变

**AC3 测试（FileEditTool 中断回滚）：**
- 创建一个已有内容的文件
- 配置 MockLLMClient 返回 tool_use 调用 Edit 工具
- 在编辑执行前取消 Task
- 验证文件内容与编辑前相同

**AC4 测试（AsyncStream 中断事件）：**
- 启动 `agent.stream()` 返回的 AsyncStream
- 在消费几个事件后取消 Task
- 验证最后一个事件是 `.result` 且 `subtype == .cancelled`
- 验证 stream 正常结束（不抛出错误）

**MockLLMClient 配置技巧：**
- 使用延迟响应模拟长时间运行（让取消在正确时机到达）
- 已有 `AgentLoopTests` 使用 MockLLMClient 的模式可参考

### 前序 Story 学习要点

**Story 13.1（运行时动态模型切换）完成情况：**
- 完整测试套件：2419 tests passing, 4 skipped, 0 failures
- **关键教训：** Agent.swift 中修改必须同时检查 `prompt()` 和 `stream()` 两个方法
- `Agent.model` 已改为 `public private(set) var`，`Agent.options` 是 `var`
- `SDKError.invalidConfiguration(String)` case 已添加到 ErrorTypes.swift
- `CostBreakdownEntry` 已定义在 AgentTypes.swift

**Story 12.4（项目文档发现）完成情况：**
- **关键教训：** 修改 Agent 核心属性时需要同时检查 prompt() 和 stream() 两个方法

**Story 12.2（缓存集成）完成情况：**
- **关键教训：** Agent.swift 中新增参数时，必须同时更新 `prompt()` 和 `stream()` 两个方法的所有调用点

**关键代码模式：**
- `stream()` 使用 captured 变量模式满足 Sendable 约束 -- 新增的取消检查需要在 Task 内部（非 @Sendable 闭包边界外）
- `stream()` 第 640 行创建 `_Concurrency.Task { ... }`，第 1171 行 `task.cancel()` 在 onTermination 中
- `prompt()` 直接在方法体内运行，无额外 Task 包装 -- 取消通过调用者的 Task 传播
- `ToolExecutor` 是无状态的 `enum` 命名空间，所有方法都是 `static`
- 工具使用 `defineTool()` 闭包，闭包内可以直接访问 `Task.isCancelled`

### Project Structure Notes

- 测试文件放在 `Tests/OpenAgentSDKTests/Core/AbortTests.swift`
- 不需要创建新的源文件（所有修改在现有文件上）
- `FileWriteTool` 和 `FileEditTool` 的修改最小化 -- 添加取消检查，不改变整体结构
- Agent.swift 是核心修改文件，三个方法（interrupt、prompt、stream）都需要更新

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 13.2] -- 验收标准（4 个 AC：Task.cancel 中断、FileWrite 回滚、FileEdit 回滚、AsyncStream 中断事件）
- [Source: _bmad-output/planning-artifacts/epics.md#FR60] -- 查询中断功能需求
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 13 会话生命周期管理] -- Epic 级别上下文
- [Source: _bmad-output/implementation-artifacts/13-1-runtime-dynamic-model-switching.md] -- 前序 Story 完成记录
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L581] -- stream() 方法（需添加取消检测）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L254] -- prompt() 方法（需添加取消检测）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L1171-1173] -- onTermination 中已有的 task.cancel()
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L719] -- stream() while 循环（添加取消检查点）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L299] -- prompt() while 循环（添加取消检查点）
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift#L181] -- executeTools()（添加取消检查）
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift#L264] -- executeMutationsSerial()（每步检查取消）
- [Source: Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift#L66-77] -- 原子写入（atomically: true）
- [Source: Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift#L50-106] -- 编辑流程（需添加备份+恢复）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L269] -- QueryResult（添加 isCancelled 字段）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L231] -- QueryStatus（添加 .cancelled case）
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift#L148-179] -- ResultData.Subtype（添加 .cancelled case）
- [Source: Sources/OpenAgentSDK/Types/ErrorTypes.swift#L38] -- SDKError.abortError（已有，但不用于正常取消路径）
- [Source: open-agent-sdk-typescript/src/agent.ts#L407-409] -- TypeScript SDK interrupt() 参考
- [Source: open-agent-sdk-typescript/src/engine.ts#L239] -- TypeScript SDK engine loop abort 检查
- [Source: _bmad-output/planning-artifacts/architecture.md#AD1] -- 并发模型决策（Actor + 结构化并发）
- [Source: _bmad-output/planning-artifacts/architecture.md#AD2] -- 流式模型决策（AsyncStream<SDKMessage>）

## Dev Agent Record

### Agent Model Used

Claude Opus 4 (claude-opus-4-6)

### Debug Log References

N/A

### Completion Notes List

1. Used Swift cooperative cancellation model (`Task.isCancelled`) instead of AbortController/AbortSignal pattern -- no changes to ToolContext needed.
2. `Agent.interrupt()` uses dual mechanism: `_interrupted` flag for loop-level checks + `_cancelStreamTask`/`_cancelCurrentQuery` closures for immediate Task cancellation.
3. URLSession throws `URLError.cancelled` (not `CancellationError`) when a request is cancelled via Task cancellation -- error catch path checks both error types.
4. `FileWriteTool` and `FileEditTool` use `atomically: true` writes which provide inherent safety -- cancellation checks are placed before the write call to prevent unnecessary disk I/O.
5. `ToolExecutor.executeTools()` has three cancellation checkpoints: entry, between read-only and mutation batches, and inside serial mutation loop.
6. Stream cancellation detection covers three locations: while loop top, inside SSE event loop (`for try await`), and after SSE stream ends.
7. All 16 Abort tests use `AbortMockURLProtocol` (custom URLProtocol subclass) for network interception with configurable delays.
8. Fixed test isolation issue: changed `testPromptCancellationPreservesCompletedTurns` and `testFileWriteAbort_ToolResultsContainCompletedResults` to use `mockResponses` instead of `sequentialResponses` to avoid cross-test static state interference.

### File List

**Modified:**
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- Added `QueryStatus.cancelled`, `QueryResult.isCancelled` field
- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- Added `ResultData.Subtype.cancelled`
- `Sources/OpenAgentSDK/Core/Agent.swift` -- Added `interrupt()`, `_interrupted` flag, cancel closures; cancellation detection in `prompt()` and `stream()`
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` -- Added `Task.isCancelled` checks in `executeTools()`, `executeMutationsSerial()`
- `Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift` -- Added pre-write cancellation check
- `Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift` -- Added pre-replacement and pre-write cancellation checks

**Created:**
- `Tests/OpenAgentSDKTests/Core/AbortTests.swift` -- 16 unit tests across 5 test classes covering all 4 ACs
