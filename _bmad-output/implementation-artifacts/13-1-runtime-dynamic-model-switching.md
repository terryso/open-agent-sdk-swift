# Story 13.1: 运行时动态模型切换

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望在 Agent 会话中动态切换 LLM 模型，
以便我可以根据任务需要选择最合适的模型。

## Acceptance Criteria

1. **AC1: 基本模型切换** -- 给定使用 "claude-sonnet-4-6" 模型创建的 Agent，当开发者调用 `agent.switchModel("claude-opus-4-6")`，则方法返回 `Void`，无错误，且后续 `agent.stream(...)` 发送的 API 请求中 `model` 字段为 "claude-opus-4-6"（FR59）。

2. **AC2: 多模型成本拆分** -- 给定模型从 "claude-sonnet-4-6" 切换到 "claude-opus-4-6"，当查询完成后检查 `result.usage`，则 `result.usage.costBreakdown` 包含两个条目：sonnet 的 token 计数和 opus 的 token 计数，且总成本 = sonnet 成本 + opus 成本。

3. **AC3: 空模型名称拒绝** -- 给定开发者调用 `agent.switchModel("")`（空字符串），当方法执行，则抛出 `SDKError.invalidConfiguration("Model name cannot be empty")`，且 Agent 当前模型不变，会话不中断。

4. **AC4: 未知模型名称允许** -- 给定开发者调用 `agent.switchModel("some-new-model-name")`（非空但非预知模型），当方法执行，则方法成功返回（不使用白名单验证，允许未来新模型名称），且如果 API 返回 404 错误，错误在下次查询时正常报告。

## Tasks / Subtasks

- [x] Task 1: 实现 Agent.switchModel() 方法 (AC: #1, #3, #4)
  - [x] 在 `Agent` 类中添加 `public func switchModel(_ model: String) throws` 方法
  - [x] 验证 model 非空：空字符串时抛出 `SDKError.invalidConfiguration("Model name cannot be empty")`
  - [x] 更新 `self.model`（从 `let` 改为可变存储）和 `self.options.model`
  - [x] 不使用白名单验证，允许任意非空字符串
  - [x] 重置 `buildSystemPrompt()` 的缓存（如果存在缓存机制需要刷新）

- [x] Task 2: 实现多模型成本拆分 -- CostBreakdown 类型 (AC: #2)
  - [x] 在 `TokenUsage` 或新类型中定义 `CostBreakdownEntry`（包含 model: String, inputTokens: Int, outputTokens: Int, costUsd: Double）
  - [x] 在 `QueryResult` 中添加 `costBreakdown: [CostBreakdownEntry]` 字段（默认空数组）
  - [x] 在 `SDKMessage.ResultData` 中添加 `costBreakdown` 字段（流式场景也需要）
  - [x] 在 Agent 的 `prompt()` 和 `stream()` 中跟踪每模型成本（使用 `[String: CostBreakdownEntry]` 字典按模型聚合）

- [x] Task 3: 修改 Agent.model 从 let 改为可变存储 (AC: #1)
  - [x] 将 `Agent.model` 从 `public let model: String` 改为 `public private(set) var model: String`（保持外部只读，内部可变）
  - [x] 更新所有依赖 `model` 为 immutable 的代码路径（特别是 `stream()` 中 `capturedModel` 的捕获方式）

- [x] Task 4: 处理 stream() 中的模型动态切换 (AC: #1)
  - [x] 在 `stream()` 方法中，确保 LLM API 调用使用的是 `self.model` 而非预先捕获的常量
  - [x] 评估 `stream()` 中 captured 变量模式对动态模型切换的影响
  - [x] 确保在流式循环中每轮 API 调用前读取最新的 `self.model`

- [x] Task 5: 编写单元测试 (AC: #1, #2, #3, #4)
  - [x] 在 `Tests/OpenAgentSDKTests/Core/` 下创建 `ModelSwitchingTests.swift`
  - [x] 测试 AC1：创建 Agent，调用 switchModel，验证 model 属性变更，验证 API 请求中的 model 字段
  - [x] 测试 AC2：在两次 API 调用之间切换模型，验证 costBreakdown 包含两个模型的条目
  - [x] 测试 AC3：调用 switchModel("")，验证抛出正确错误且 model 不变
  - [x] 测试 AC4：调用 switchModel("unknown-model-xyz")，验证成功且 model 更新

- [x] Task 6: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- **Epic 13**（会话生命周期管理）的第一个 Story
- **核心目标：** 实现运行时动态模型切换，让开发者在同一会话中根据任务复杂度选择不同模型
- **前置依赖：** Epic 1-12 全部完成，特别是 Epic 1（Agent 创建与配置）和 Epic 2（流式响应与成本追踪）
- **FR 覆盖：** FR59（开发者可以在 Agent 会话中动态切换 LLM 模型）
- **用户场景：** 简单问答用快速模型节省成本，复杂推理切换到强力模型，无需重启会话

### 关键设计决策

**switchModel() 作为 Agent 实例方法：**
- 与 TypeScript SDK 的 `agent.setModel()` 对齐
- 同一 pattern 已有先例：`Agent.setPermissionMode()` 和 `Agent.setCanUseTool()` 已经使用类似模式修改 `options` 字段
- 需要将 `Agent.model` 从 `let` 改为 `private(set) var`

**成本拆分（CostBreakdown）：**
- 新增 `CostBreakdownEntry` 结构体记录每模型成本
- 在 `prompt()` 和 `stream()` 循环中按模型名聚合成本
- 现有 `estimateCost(model:usage:)` 已经支持按模型名查定价，无需修改

**stream() 方法中的挑战：**
- `stream()` 使用 captured 变量模式（`let capturedModel = model`）在闭包外捕获值
- 如果在 stream() 执行期间调用 switchModel()，captured 值不会更新
- 解决方案：stream() 内部应使用 `self.model`（通过在循环中重新读取），而非依赖一次性 captured 值
- 注意：并发安全性需评估 -- switchModel() 在 stream() 执行期间被调用的情况

**不使用白名单验证：**
- AC4 明确要求不使用白名单，允许任意非空模型名称
- 错误延迟到 API 调用时报告（404 等）
- 这与 TypeScript SDK 的 `setModel()` 行为一致

### TypeScript SDK 参考映射

| Swift 功能 | TypeScript 对应 | 文件 |
|---|---|---|
| `Agent.switchModel()` | `agent.setModel(model)` | `src/agent.ts:414-419` |
| `Agent.model` (可变) | `this.modelId` | `src/agent.ts:416` |
| `self.options.model` 更新 | `this.cfg.model = model` | `src/agent.ts:417` |
| CostBreakdown | 无直接对应（TS SDK 无此功能） | -- |

**TypeScript SDK setModel() 实现：**
```typescript
async setModel(model?: string): Promise<void> {
    if (model) {
      this.modelId = model
      this.cfg.model = model
    }
}
```
- TS SDK 实现非常简洁：只更新 `modelId` 和 `cfg.model`
- Swift 版本增加空字符串验证（TS SDK 通过 `if (model)` 隐式跳过空值）
- Swift 版本增加 costBreakdown（TS SDK 没有的新功能）

### 已有代码分析

**Agent.swift（需修改）：**
- `public let model: String`（第 22 行）：需改为 `public private(set) var model: String`
- `self.model = options.model`（第 62 行）：初始化赋值，无需修改（var 支持）
- `prompt()` 方法：使用 `self.model` 直接访问（第 276 行等），改为 var 后仍有效
- `stream()` 方法：使用 `let capturedModel = model`（第 539 行）一次性捕获
  - 关键问题：stream() 中 API 调用使用 capturedModel 而非 self.model
  - 在流式循环的每轮中重新读取 model 是必要的
  - 需要评估 Sendable 约束 -- `self` 是 `class`（非 Sendable），在 `@Sendable` 闭包中直接访问需要 care
  - 当前 stream() 中大量使用 captured 变量模式正是因为 Sendable 要求
  - **建议方案：** 在 while 循环内部（Task 内部，非 @Sendable 闭包边界外）重新读取，使用一个 `var currentModel = capturedModel`，每次循环迭代时检查是否有更新

**AgentTypes.swift（需修改）：**
- `QueryResult`（第 246 行）：添加 `costBreakdown: [CostBreakdownEntry]` 字段
- 需要定义 `CostBreakdownEntry` struct（可放在 `Types/` 下独立文件或嵌入 `TokenUsage.swift`）

**SDKMessage.swift（需修改）：**
- `ResultData`（第 148 行）：添加 `costBreakdown` 字段
- `ResultData.init()` 需要更新

**Utils/Tokens.swift（不需修改）：**
- `estimateCost(model:usage:)` 已支持按模型查定价，无需改动

### Agent.model 可变性分析

**当前使用 model 的位置：**

1. `Agent.init()` -- 赋值（第 62 行）
2. `Agent.model` 公共属性 -- 只读暴露（第 22 行）
3. `Agent.prompt()` -- 多处直接使用 `self.model`（第 276、296、325 行等）
4. `Agent.stream()` -- 通过 `let capturedModel = model` 捕获（第 539 行），然后在循环中使用 capturedModel
5. `Agent.description` / `debugDescription` -- 只读
6. `buildSystemPrompt()` -- 间接（不直接使用 model）

**prompt() 中的 model 使用：**
- 第 276 行：`shouldAutoCompact(messages: messages, model: model, ...)` -- 每轮调用
- 第 278 行：`compactConversation(client: client, model: model, ...)` -- 每轮调用
- 第 296 行：`let retryModel = self.model` -- 每轮 API 调用前捕获
- 第 301 行：`retryClient.sendMessage(model: retryModel, ...)` -- API 调用
- 第 361 行：`estimateCost(model: model, usage: turnUsage)` -- 成本计算

prompt() 中每轮循环都会重新读取 `self.model`（通过 `let retryModel = self.model` 在循环内），因此改为 var 后 switchModel() 在循环间隙被调用会生效。

**stream() 中的 model 使用：**
- 第 539 行：`let capturedModel = model` -- **循环外一次性捕获**
- 第 672 行：`shouldAutoCompact(messages: messages, model: capturedModel, ...)` -- 使用 captured 值
- 第 675 行：`compactConversation(client: capturedClient, model: capturedModel, ...)` -- 使用 captured 值
- 第 691 行：`let retryModel = capturedModel` -- 使用 captured 值
- 第 729 行：`var currentModel = capturedModel` -- 在 SSE 事件处理中跟踪
- 第 748 行：`estimateCost(model: currentModel, ...)` -- 使用 currentModel

**stream() 的改造方案：**
stream() 由于 AsyncStream 闭包和 Sendable 约束，不能直接在 @Sendable 闭包内访问 `self.model`。建议：
1. 保留 `let capturedModel = model` 作为初始值
2. 在 while 循环内部引入 `var activeModel = capturedModel`（在 Task 内部，无 Sendable 约束）
3. 每轮循环开始时检查：`activeModel = capturedModel`（由于 capturedModel 是 let，不会变）
4. **关键限制：** stream() 期间调用 switchModel() 的效果在**下一次 stream() 调用**时生效，当前流不更新
5. 这与实际使用场景一致：开发者不会在 stream() 执行中间调用 switchModel()

**简化方案（推荐）：**
- stream() 中保持 captured 变量模式不变（符合 Sendable 约束）
- switchModel() 的影响在**下一次 prompt()/stream() 调用**时生效
- 这是合理的语义：一个流式查询使用一个一致的模型
- prompt() 中每轮 API 调用前重新读取 self.model，所以 prompt() 内的 switchModel() 调用会在下一轮生效

### CostBreakdown 设计

```swift
/// Per-model cost entry for cost breakdown tracking.
public struct CostBreakdownEntry: Sendable, Equatable {
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let costUsd: Double
}
```

**聚合方式：**
- 在 prompt()/stream() 中维护 `var costByModel: [String: CostBreakdownEntry] = [:]`
- 每次 API 调用后，按当前模型名聚合到字典中
- 循环结束后将字典值转为数组赋给 `QueryResult.costBreakdown`

**集成点：**
- `QueryResult.costBreakdown` -- 阻塞式 API 结果
- `SDKMessage.ResultData.costBreakdown` -- 流式 API 结果
- 两者共享 `CostBreakdownEntry` 类型

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Core/Agent.swift` -- **修改**：switchModel() 方法、model 改为 var、prompt()/stream() 中添加 costByModel 跟踪
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- **修改**：QueryResult 添加 costBreakdown 字段、定义 CostBreakdownEntry
- `Sources/OpenAgentSDK/Types/SDKMessage.swift` -- **修改**：ResultData 添加 costBreakdown 字段
- `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift` -- **新建**：模型切换测试

```
Sources/OpenAgentSDK/
├── Core/
│   └── Agent.swift                     # 修改：+ switchModel(), model 改 var, costByModel 跟踪
├── Types/
│   ├── AgentTypes.swift                # 修改：QueryResult + costBreakdown, + CostBreakdownEntry
│   ├── SDKMessage.swift                # 修改：ResultData + costBreakdown
│   └── ...
└── ...

Tests/OpenAgentSDKTests/
├── Core/
│   ├── ModelSwitchingTests.swift       # 新建：模型切换测试
│   └── ...
└── ...
```

### Logger 集成约定

为 Epic 14 Logger 预留调用点：
- **预留位置：**
  - 模型切换成功：`Logger.shared.info("Model switched", data: ["from": oldModel, "to": newModel])`
  - 空模型名称拒绝：`Logger.shared.warn("Model switch rejected: empty name")`
- **预实现方案：** `Logger.shared` 当前为空实现（no-op），不引入编译错误

### 反模式警告

- **不要**使用白名单验证模型名称 -- AC4 明确要求允许任意非空字符串
- **不要**在 stream() 期间尝试动态更新模型 -- 保持 captured 变量模式，switchModel() 在下一次 prompt()/stream() 时生效
- **不要**将 `Agent.model` 改为完全公开的 `var` -- 使用 `public private(set) var` 保持外部只读
- **不要**在 prompt() 中一次性捕获 model -- 每轮循环前重新读取 `self.model`（当前已通过循环内 `let retryModel = self.model` 实现，改为 var 后自动支持动态更新）
- **不要**忘记同时更新 `self.options.model` -- 与 TypeScript SDK 一致，两个位置都需要更新
- **不要**在 `Utils/` 中创建新文件 -- CostBreakdownEntry 放在 `Types/AgentTypes.swift` 中（与其他 result 类型一起）
- **不要**破坏现有 cost 计算 -- `estimateCost(model:usage:)` 已经按模型名查定价，costBreakdown 是增量功能
- **不要**在工具执行中使用 `Core/` 导入 -- 模块边界不变

### 测试策略

**AC1 测试（基本模型切换）：**
- 创建 Agent（model: "claude-sonnet-4-6"）
- 调用 `agent.switchModel("claude-opus-4-6")`
- 验证 `agent.model == "claude-opus-4-6"`
- 使用 mock client 验证 API 请求中 model 字段已更新
- 注意：现有 AgentLoopTests 使用 MockLLMClient，可直接参考

**AC2 测试（多模型成本拆分）：**
- 创建 Agent（model: "claude-sonnet-4-6"）
- 配置 MockLLMClient 返回 end_turn 响应
- 执行第一次 prompt，切换模型，执行第二次 prompt（或使用多轮 prompt 中切换）
- 验证 `result.costBreakdown` 包含两个模型的条目
- 验证总成本 = 各模型成本之和
- 注意：如果在一个 prompt() 调用中间无法切换模型（循环内 self.model 重新读取），可以在两个 prompt() 调用之间切换

**AC3 测试（空模型名称拒绝）：**
- 创建有效 Agent
- 调用 `try agent.switchModel("")`
- 验证抛出 `SDKError.invalidConfiguration` 且 message 包含 "empty"
- 验证 `agent.model` 不变（仍为原始模型）

**AC4 测试（未知模型名称允许）：**
- 创建 Agent
- 调用 `try agent.switchModel("future-model-v99")`
- 验证成功返回、无错误
- 验证 `agent.model == "future-model-v99"`
- 验证后续 API 调用使用新模型名

### 前序 Story 学习要点

**Story 12.4 完成情况：**
- 完整测试套件：2396 tests passing, 4 skipped, 0 failures
- buildSystemPrompt() 修改同时影响 prompt() 和 stream()
- **关键教训：** 修改 Agent 核心属性时需要同时检查 prompt() 和 stream() 两个方法

**Story 12.2 完成情况：**
- **关键教训：** Agent.swift 中新增参数时，必须同时更新 `prompt()` 和 `stream()` 两个方法的所有调用点

**Story 11.2 完成情况：**
- `modelOverride` 在技能执行期间覆盖模型名称
- 技能执行完毕后恢复原始模型
- **与本 Story 的交互：** switchModel() 修改的是 Agent 的基础模型，技能的 modelOverride 是临时覆盖
- switchModel() 后执行带 modelOverride 的技能，技能结束后应恢复到 switchModel() 设置的模型

**关键代码模式：**
- Agent 已有动态配置先例：`setPermissionMode()` 和 `setCanUseTool()` 修改 `options` 字段
- prompt() 在循环内通过 `let retryModel = self.model` 每轮重新读取 -- 改为 var 后自动支持动态模型
- stream() 使用 captured 变量模式 -- 不支持执行中动态更新（但这是合理的设计限制）
- `SDKError.invalidConfiguration` 是已有错误 case，可直接用于空模型名验证

### Project Structure Notes

- 不需要创建新文件（CostBreakdownEntry 定义在 AgentTypes.swift 中）
- Agent.swift 是核心修改文件，model 属性和 prompt()/stream() 方法都需要更新
- 测试文件放在 `Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 13.1] -- 验收标准（4 个 AC：基本切换、成本拆分、空名称拒绝、未知模型允许）
- [Source: _bmad-output/planning-artifacts/epics.md#FR59] -- 运行时模型切换功能需求
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 13 会话生命周期管理] -- Epic 级别上下文
- [Source: _bmad-output/implementation-artifacts/12-4-project-document-discovery.md] -- 前序 Story 完成记录
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L22] -- 当前 model 属性（let，需改为 var）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L109] -- setPermissionMode() 先例（动态修改 options 的模式）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L539] -- stream() captured 变量模式
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L296] -- prompt() 循环内 model 读取
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L246] -- QueryResult 定义（添加 costBreakdown）
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift#L148] -- ResultData 定义（添加 costBreakdown）
- [Source: Sources/OpenAgentSDK/Types/ModelInfo.swift] -- MODEL_PRICING 字典
- [Source: Sources/OpenAgentSDK/Utils/Tokens.swift#L34] -- estimateCost() 已支持按模型名查定价
- [Source: open-agent-sdk-typescript/src/agent.ts#L414-419] -- TypeScript SDK setModel() 参考
- [Source: _bmad-output/planning-artifacts/architecture.md#AD3] -- API 客户端架构决策
- [Source: _bmad-output/planning-artifacts/architecture.md#AD9] -- 配置基于结构体决策

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented `Agent.switchModel(_:)` method with empty/whitespace validation via `SDKError.invalidConfiguration`
- Changed `Agent.model` from `let` to `public private(set) var` for internal mutability while preserving external read-only access
- Defined `CostBreakdownEntry` struct with model, inputTokens, outputTokens, costUsd fields (Sendable, Equatable)
- Added `costBreakdown` field to both `QueryResult` and `SDKMessage.ResultData` with empty array default
- Added per-model cost tracking via `costByModel: [String: CostBreakdownEntry]` dictionary in both `prompt()` and `stream()` methods
- `stream()` retains captured variable pattern for Sendable compliance; switchModel() takes effect on the next prompt()/stream() call
- `prompt()` re-reads `self.model` each loop iteration via `let retryModel = self.model`, so switchModel() between turns works naturally
- Added `SDKError.invalidConfiguration(String)` case to ErrorTypes.swift for empty model name rejection
- All 4 acceptance criteria (AC1-AC4) satisfied with 20 tests in ModelSwitchingTests.swift
- Full test suite: 2419 tests passing, 4 skipped, 0 failures

### File List

- Sources/OpenAgentSDK/Types/ErrorTypes.swift -- Modified: added `SDKError.invalidConfiguration(String)` case
- Sources/OpenAgentSDK/Types/AgentTypes.swift -- Modified: added `CostBreakdownEntry` struct, `costBreakdown` field on `QueryResult`
- Sources/OpenAgentSDK/Types/SDKMessage.swift -- Modified: added `costBreakdown` field on `ResultData`
- Sources/OpenAgentSDK/Core/Agent.swift -- Modified: `model` changed to `public private(set) var`, added `switchModel()` method, added costByModel tracking in `prompt()` and `stream()`
- Tests/OpenAgentSDKTests/Core/ModelSwitchingTests.swift -- Pre-existing ATDD tests (unchanged, all now passing)

### Review Findings

- [x] [Review][Patch] switchModel stores untrimmed value instead of trimmed value [Sources/OpenAgentSDK/Core/Agent.swift:144] -- FIXED: changed `self.model = model` to `self.model = trimmed` so whitespace-padded model names are normalized before storage.

### Change Log

- 2026-04-12: Story 13.1 implementation complete -- Runtime Dynamic Model Switching (AC1-AC4 satisfied, 2419 tests passing)
- 2026-04-12: Code review passed (1 patch fixed, 0 decision-needed, 4 dismissed). Status: done.
