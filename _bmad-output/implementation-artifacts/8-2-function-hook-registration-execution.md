# Story 8.2: 函数钩子注册与执行

Status: done

## Story

作为开发者，
我希望在生命周期事件上注册异步函数钩子，
以便我可以在 Agent 执行期间运行自定义逻辑。

## Acceptance Criteria

1. **AC1: AgentOptions 添加 hookRegistry** — 给定 `AgentOptions`，当开发者设置 `hookRegistry` 属性时，则 `HookRegistry` 被传递到 Agent 并在 Agent 循环中使用（FR28）。

2. **AC2: SessionStart 钩子执行** — 给定在 `sessionStart` 上注册的函数钩子，当新的 Agent 会话开始（`prompt()` 或 `stream()` 被调用）时，则钩子接收会话上下文并可以执行初始化逻辑。

3. **AC3: 多钩子按序执行** — 给定在同一事件上注册的多个钩子，当事件触发时，则所有钩子按注册顺序执行，且每个钩子接收前一个钩子的输出（如适用）。

4. **AC4: PreToolUse 钩子拦截** — 给定在 `preToolUse` 上注册的钩子，当 Agent 即将执行工具时，则钩子被调用，传入工具名称和输入。若钩子返回 `HookOutput(block: true)`，则工具执行被阻止并返回错误给 LLM。

5. **AC5: PostToolUse 钩子** — 给定在 `postToolUse` 上注册的钩子，当工具成功执行后，则钩子接收工具名称、输入和输出。

6. **AC6: PostToolUseFailure 钩子** — 给定在 `postToolUseFailure` 上注册的钩子，当工具执行失败后（`isError: true`），则钩子接收工具名称、输入和错误信息。

7. **AC7: SessionEnd 钩子执行** — 给定在 `sessionEnd` 上注册的函数钩子，当 Agent 会话结束（`prompt()` 或 `stream()` 完成时），则钩子被调用。

8. **AC8: Stop 钩子执行** — 给定在 `stop` 上注册的函数钩子，当 Agent 循环终止（end_turn、maxTurns、预算超限等）时，则钩子被调用。

9. **AC9: hookRegistry 为 nil 时无副作用** — 给定未设置 `hookRegistry` 的 Agent，当执行 prompt/stream 时，则 Agent 行为与之前完全一致，无额外开销。

10. **AC10: createHookRegistry 便利工厂** — 给定 `createHookRegistry()` 函数，当开发者调用此函数并传入可选的 `HookConfig` 时，则返回配置好的 `HookRegistry` 实例（与 TS SDK 对齐）。

11. **AC11: 单元测试覆盖** — 给定 `Tests/OpenAgentSDKTests/Hooks/` 目录，则包含 `HookIntegrationTests.swift`，至少覆盖：AgentOptions 注入 hookRegistry、createHookRegistry 工厂、各生命周期事件的钩子触发验证、PreToolUse 阻止工具执行、hookRegistry 为 nil 无副作用。

12. **AC12: E2E 测试覆盖** — 给定 `Sources/E2ETest/` 目录，则包含 `HookIntegrationE2ETests.swift`，至少覆盖：通过 AgentOptions 配置钩子并触发 SessionStart/SessionEnd、PreToolUse 阻止工具执行验证。

## Tasks / Subtasks

- [ ] Task 1: AgentOptions 添加 hookRegistry 属性 (AC: #1, #9)
  - [ ] 在 `Types/AgentTypes.swift` 的 `AgentOptions` 中添加 `public var hookRegistry: HookRegistry?` 属性
  - [ ] 在 `init(...)` 中添加 `hookRegistry: HookRegistry? = nil` 参数
  - [ ] 在 `init(from config:)` 中初始化 `hookRegistry = nil`

- [ ] Task 2: ToolContext 添加 hookRegistry 属性 (AC: #4, #5, #6)
  - [ ] 在 `Types/ToolTypes.swift` 的 `ToolContext` 中添加 `public let hookRegistry: HookRegistry?` 属性
  - [ ] 在 `init(...)` 中添加 `hookRegistry: HookRegistry? = nil` 参数
  - [ ] 在 `withToolUseId(...)` 方法中保留 hookRegistry

- [ ] Task 3: 实现 createHookRegistry 便利工厂 (AC: #10)
  - [ ] 在 `Hooks/HookRegistry.swift` 中添加 `public func createHookRegistry(config: [String: [HookDefinition]]? = nil) -> HookRegistry`

- [ ] Task 4: Agent.prompt() 集成钩子 (AC: #2, #7, #8, #9)
  - [ ] 在 `prompt()` 开始时触发 `sessionStart` 钩子（如果 hookRegistry 非 nil）
  - [ ] 在 `prompt()` 正常结束时触发 `sessionEnd` 钩子
  - [ ] 在 `prompt()` 循环终止时触发 `stop` 钩子
  - [ ] 将 `hookRegistry` 传递到 `ToolContext`

- [ ] Task 5: Agent.stream() 集成钩子 (AC: #2, #7, #8, #9)
  - [ ] 在 `stream()` 开始时触发 `sessionStart` 钩子
  - [ ] 在 `stream()` 正常结束时触发 `sessionEnd` 钩子
  - [ ] 在 `stream()` 循环终止时触发 `stop` 钩子
  - [ ] 将 `hookRegistry` 传递到 `ToolContext`

- [ ] Task 6: ToolExecutor 集成 PreToolUse/PostToolUse 钩子 (AC: #4, #5, #6)
  - [ ] 在 `executeSingleTool()` 中实现 `preToolUse` 钩子调用
  - [ ] 若 PreToolUse 返回 `block: true`，返回阻止错误给 LLM
  - [ ] 在工具执行成功后触发 `postToolUse` 钩子
  - [ ] 在工具执行失败后触发 `postToolUseFailure` 钩子
  - [ ] 替换现有的 `// TODO: Epic 8` 注释

- [ ] Task 7: 单元测试 (AC: #11)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift`
  - [ ] 测试 AgentOptions 注入 hookRegistry
  - [ ] 测试 createHookRegistry 工厂函数
  - [ ] 测试 PreToolUse 阻止工具执行
  - [ ] 测试 hookRegistry 为 nil 时无副作用

- [ ] Task 8: E2E 测试 (AC: #12)
  - [ ] 创建 `Sources/E2ETest/HookIntegrationE2ETests.swift`
  - [ ] E2E 测试：配置钩子并触发 SessionStart/SessionEnd
  - [ ] E2E 测试：PreToolUse 阻止工具执行验证

- [ ] Task 9: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证所有现有测试仍通过
  - [ ] 更新 `Sources/E2ETest/main.swift` 添加新 Section

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 8（钩子系统与权限控制）的第二个 story
- **将 Story 8-1 创建的 HookRegistry 集成到 Agent 执行循环中**
- **关键目标：** 函数钩子在 Agent 生命周期中实际被触发和执行（FR28）
- **范围限制：** 仅实现函数钩子（handler 闭包）的集成。Shell 命令钩子（`command` 字段）推迟到 Story 8-3

### 已有的类型和组件（Story 8-1 创建，直接使用）

| 组件 | 位置 | 说明 |
|------|------|------|
| `HookEvent` | `Types/HookTypes.swift` | 20 个 case 的枚举，`Sendable`, `Equatable`, `CaseIterable` |
| `HookInput` | `Types/HookTypes.swift` | 包含 event, toolName, toolInput, toolOutput, toolUseId, sessionId, cwd, error |
| `HookOutput` | `Types/HookTypes.swift` | 包含 message, permissionUpdate, block, notification |
| `HookDefinition` | `Types/HookTypes.swift` | 包含 command, handler 闭包, matcher, timeout |
| `HookRegistry` | `Hooks/HookRegistry.swift` | Actor，提供 register/registerFromConfig/execute/hasHooks/clear |

### 需要修改的文件

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Types/AgentTypes.swift` | **修改** | AgentOptions 添加 `hookRegistry: HookRegistry?` |
| `Types/ToolTypes.swift` | **修改** | ToolContext 添加 `hookRegistry: HookRegistry?` |
| `Hooks/HookRegistry.swift` | **修改** | 添加 `createHookRegistry()` 便利工厂函数 |
| `Core/Agent.swift` | **修改** | prompt() 和 stream() 集成钩子触发点 |
| `Core/ToolExecutor.swift` | **修改** | executeSingleTool() 集成 PreToolUse/PostToolUse/PostToolUseFailure |

### 不修改的文件

- `Types/HookTypes.swift` — 无需修改，所有类型已在 8-1 中定义
- `Hooks/ShellHookExecutor.swift` — 不创建，Story 8-3 实现
- `Core/QueryEngine.swift` — 不存在此文件（Agent.swift 包含所有循环逻辑）

### TypeScript SDK 参考

TypeScript SDK 的 `createHookRegistry` 工厂函数（`hooks.ts` 第 255-261 行）：
```typescript
export function createHookRegistry(config?: HookConfig): HookRegistry {
  const registry = new HookRegistry()
  if (config) {
    registry.registerFromConfig(config)
  }
  return registry
}
```

TypeScript SDK 中 HookRegistry 在 Agent 中的使用方式：TS SDK 的 `AgentOptions` 中有 `hooks` 配置字段（`types.ts` 第 417-420 行），Agent 在工具执行前后调用钩子。

### 关键实现细节

**1. AgentOptions 添加 hookRegistry**

```swift
// 在 AgentOptions 中添加：
public var hookRegistry: HookRegistry?

// init 中添加参数：
hookRegistry: HookRegistry? = nil

// init(from:) 中初始化：
self.hookRegistry = nil
```

**2. ToolContext 添加 hookRegistry**

ToolContext 需要传递 hookRegistry 到 ToolExecutor，以便在 executeSingleTool 中使用。

```swift
// 在 ToolContext 中添加：
public let hookRegistry: HookRegistry?

// init 中添加参数（在 todoStore 之后）：
hookRegistry: HookRegistry? = nil

// withToolUseId 方法中保留 hookRegistry：
func withToolUseId(_ id: String) -> ToolContext {
    ToolContext(
        // ... 所有现有字段 ...
        hookRegistry: hookRegistry
    )
}
```

**3. Agent.prompt() 钩子触发点**

在 `prompt()` 方法中：
```
[a] 函数开始 → 触发 sessionStart
    let hookInput = HookInput(event: .sessionStart, sessionId: nil, cwd: options.cwd)
    await options.hookRegistry?.execute(.sessionStart, input: hookInput)

[b] 循环终止时 → 触发 stop
    let stopInput = HookInput(event: .stop, sessionId: nil, cwd: options.cwd)
    await options.hookRegistry?.execute(.stop, input: stopInput)

[c] 函数返回前 → 触发 sessionEnd
    let endInput = HookInput(event: .sessionEnd, sessionId: nil, cwd: options.cwd)
    await options.hookRegistry?.execute(.sessionEnd, input: endInput)
```

**4. Agent.stream() 钩子触发点**

stream() 的结构更复杂（在 AsyncStream 闭包内的 Task 中执行）。需要：
- 在 Task 开始时触发 sessionStart
- 在循环终止时触发 stop
- 在 continuation.finish() 之前触发 sessionEnd

**重要约束：** stream() 中的所有捕获值必须满足 Sendable。`HookRegistry` 是 actor，本身就是 Sendable，所以可以直接捕获。

**5. ToolExecutor.executeSingleTool() 钩子集成**

这是最关键的修改。在 `executeSingleTool()` 中替换现有的 TODO 注释：

```swift
static func executeSingleTool(
    block: ToolUseBlock,
    tool: ToolProtocol?,
    context: ToolContext
) async -> ToolResult {
    // Unknown tool handling (保持不变)
    guard let tool = tool else {
        return ToolResult(
            toolUseId: block.id,
            content: "Error: Unknown tool \"\(block.name)\"",
            isError: true
        )
    }

    // [新增] PreToolUse hook
    if let hookRegistry = context.hookRegistry {
        let hookInput = HookInput(
            event: .preToolUse,
            toolName: block.name,
            toolInput: block.input,
            toolUseId: block.id,
            cwd: context.cwd
        )
        let hookResults = await hookRegistry.execute(.preToolUse, input: hookInput)
        // 检查是否有钩子阻止了执行
        if hookResults.contains(where: { $0.block }) {
            let blockMessage = hookResults.compactMap { $0.message }.first ?? "Tool execution blocked by hook"
            return ToolResult(
                toolUseId: block.id,
                content: "Error: \(blockMessage)",
                isError: true
            )
        }
    }

    // Execute tool (保持不变)
    let result = await tool.call(input: block.input, context: context)

    // [新增] PostToolUse / PostToolUseFailure hook
    if let hookRegistry = context.hookRegistry {
        let hookEvent: HookEvent = result.isError ? .postToolUseFailure : .postToolUse
        let hookInput = HookInput(
            event: hookEvent,
            toolName: block.name,
            toolInput: block.input,
            toolOutput: result.content,
            toolUseId: block.id,
            cwd: context.cwd,
            error: result.isError ? result.content : nil
        )
        _ = await hookRegistry.execute(hookEvent, input: hookInput)
    }

    return ToolResult(
        toolUseId: block.id,
        content: result.content,
        isError: result.isError
    )
}
```

**6. createHookRegistry 工厂函数**

```swift
/// Create a hook registry with optional configuration.
public func createHookRegistry(config: [String: [HookDefinition]]? = nil) -> HookRegistry {
    let registry = HookRegistry()
    if let config {
        // registerFromConfig 是 actor 方法，需要 await
        // 但由于 registry 是刚创建的，可以安全地调用
        // 注意：因为这是在调用方的上下文中，需要 async
    }
    return registry
}
```

**问题：** `registerFromConfig` 是 actor 方法，需要 `await`。所以 `createHookRegistry` 必须是 `async` 函数。这与 TS SDK 的同步版本不同。

替代方案：让 `createHookRegistry` 为 `async` 函数：
```swift
public func createHookRegistry(config: [String: [HookDefinition]]? = nil) async -> HookRegistry {
    let registry = HookRegistry()
    if let config {
        await registry.registerFromConfig(config)
    }
    return registry
}
```

或者提供一个同步的 `HookRegistry.init(config:)` 便利初始化器（不推荐，因为 actor 初始化器中调用 self 方法不安全）。

推荐使用 `async` 版本，这与 Swift actor 的惯例一致。

### 前序 Story 的经验教训（必须遵循）

来自 Story 8-1 的 Dev Notes 和 Completion Notes：

1. **Actor 方法外部调用需要 `await`** — HookRegistry 的所有公共方法都是 actor 隔离的
2. **`_Concurrency.Task.sleep` 而非 `Task.sleep`** — 项目有自定义 Task 类型冲突
3. **`@unchecked Sendable` 模式** — HookInput、HookOutput、HookDefinition 都使用此模式
4. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
5. **E2E 测试** — 使用真实环境（不使用 mock）
6. **不使用 Apple 专属框架** — Foundation 和 Regex 在 macOS 和 Linux 均可用
7. **force-unwrap 禁止** — 使用 guard let / if let
8. **错误不传播** — 钩子失败静默处理，不影响智能循环（NFR17 精神）
9. **使用 actor 追踪器** — 测试中使用 actor（如 E2ECallTracker、E2EOrderTracker）来追踪闭包调用
10. **整数溢出** — 使用 `UInt64(clamping:)` 防止溢出（来自 8-1 review 修复）
11. **HookEvent 有 20 个 case**（不是 21）— 修正自 8-1 的 debug log
12. **不修改 HookTypes.swift** — 所有类型已在 8-1 完成

### 反模式警告

- **不要**修改 `Types/HookTypes.swift` — 所有类型定义已完成
- **不要**实现 Shell 命令钩子执行（`command` 字段）— 推迟到 Story 8-3
- **不要**在 `executeSingleTool()` 中使用 force-unwrap (`!`)
- **不要**在钩子执行中传播错误到智能循环 — 匹配 TS SDK 的静默处理模式
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台
- **不要**破坏 AgentOptions 现有的调用方 — hookRegistry 参数必须有默认值 nil
- **不要**破坏 ToolContext 现有的调用方 — hookRegistry 参数必须有默认值 nil
- **不要**在 Hooks/ 中导入 Core/ — 违反模块边界
- **不要**在 prompt/stream 中无条件调用钩子 — 必须检查 `hookRegistry != nil`（可选链 `?.`）
- **不要**让钩子执行影响 Agent 的正常流程 — 钩子失败应静默处理
- **不要**忘记在 stream() 中使用 `_Concurrency.Task.sleep` 而非 `Task.sleep`
- **不要**在 `createHookRegistry` 中使用同步调用 — 必须是 `async` 因为 actor 隔离

### 模块边界

```
Types/AgentTypes.swift    → 修改：AgentOptions 添加 hookRegistry
Types/ToolTypes.swift     → 修改：ToolContext 添加 hookRegistry
Hooks/HookRegistry.swift  → 修改：添加 createHookRegistry() 工厂函数
Core/Agent.swift          → 修改：prompt()/stream() 集成钩子
Core/ToolExecutor.swift   → 修改：executeSingleTool() 集成钩子
```

新测试文件：
```
Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift   (新建)
Sources/E2ETest/HookIntegrationE2ETests.swift               (新建)
Sources/E2ETest/main.swift                                  (修改：添加新 Section)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 8-1 (已完成) | 本 story 依赖 8-1 — 使用其 HookRegistry、HookDefinition、HookInput/Output |
| 8-3 (后续) | 依赖本 story — Shell 命令钩子执行使用 `command` 字段，在已集成的框架中添加 |
| 8-4 (后续) | 并行 — 权限模式，可能使用 PreToolUse 钩子基础设施 |
| 8-5 (后续) | 并行 — 自定义授权回调，可能使用 PreToolUse 钩子 |
| 3-3 (已完成) | 修改 — ToolExecutor.executeSingleTool() 添加钩子集成 |

### Agent.swift 修改的精确位置

**prompt() 方法（约第 168 行开始）：**

1. **SessionStart 触发点** — 在 `let startTime = ContinuousClock.now` 之后、`let (mcpTools, mcpManager) = await assembleFullToolPool()` 之前
2. **Stop 触发点** — 在 `if !loopExitedCleanly, turnCount >= maxTurns, status == .success` 判断之后
3. **SessionEnd 触发点** — 在 `return QueryResult(...)` 之前
4. **hookRegistry 传递到 ToolContext** — 在 `ToolContext(cwd:...)` 构造中添加 `hookRegistry: options.hookRegistry`

**stream() 方法（约第 426 行开始）：**

1. **SessionStart 触发点** — 在 `var messages = decodedMessages` 之前（Task 内部）
2. **Stop 触发点** — 在 `let subtype: SDKMessage.ResultData.Subtype` 判断之后
3. **SessionEnd 触发点** — 在 `continuation.finish()` 之前
4. **hookRegistry 捕获** — 在 captured* 值列表中添加 `let capturedHookRegistry = options.hookRegistry`
5. **hookRegistry 传递到 ToolContext** — 在 `ToolContext(cwd:...)` 构造中添加 `hookRegistry: capturedHookRegistry`

### ToolExecutor.swift 修改的精确位置

**executeSingleTool() 方法（约第 217 行开始）：**

当前代码在第 231 行有 `// TODO: Epic 8 — PreToolUse hook insertion point`，在第 239 行有 `// TODO: Epic 8 — PostToolUse / PostToolUseFailure hook insertion point`。替换这些 TODO 注释为实际实现。

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift）：**

每个测试创建独立的 HookRegistry 和必要的 mock/stub：
- `testCreateHookRegistry_withoutConfig_returnsEmptyRegistry`
- `testCreateHookRegistry_withConfig_registersHooks`
- `testAgentOptions_hookRegistry_defaultNil`
- `testAgentOptions_hookRegistry_injectable`
- `testToolContext_hookRegistry_defaultNil`
- `testToolContext_hookRegistry_preservedInWithToolUseId`
- `testPreToolUse_hookBlocksExecution`
- `testPreToolUse_hookAllowsExecution`
- `testPostToolUse_hookReceivesToolOutput`
- `testPostToolUseFailure_hookReceivesError`
- `testHookRegistryNil_noSideEffects`

**E2E 测试（Sources/E2ETest/HookIntegrationE2ETests.swift）：**

- 使用真实的 HookRegistry actor
- 使用 actor 追踪器（类似 E2ECallTracker、E2EOrderTracker）验证钩子被调用
- 不使用 mock（E2E 规则）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.2 函数钩子注册与执行]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD7 钩子系统]
- [Source: _bmad-output/planning-artifacts/prd.md#FR28 21 个生命周期事件钩子]
- [Source: _bmad-output/implementation-artifacts/8-1-hook-event-types-registry.md] — Story 8-1 完成记录
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/hooks.ts#createHookRegistry] — TS SDK 工厂函数
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/types.ts#417] — TS SDK hooks 配置字段
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift:231] — PreToolUse TODO 注释
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift:239] — PostToolUse TODO 注释
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:168] — prompt() 方法
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:426] — stream() 方法
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:10] — AgentOptions 结构体
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift:42] — ToolContext 结构体
- [Source: Sources/OpenAgentSDK/Hooks/HookRegistry.swift] — HookRegistry actor 实现

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Types/AgentTypes.swift` — AgentOptions 添加 hookRegistry
- **修改** `Sources/OpenAgentSDK/Types/ToolTypes.swift` — ToolContext 添加 hookRegistry
- **修改** `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` — 添加 createHookRegistry 工厂函数
- **修改** `Sources/OpenAgentSDK/Core/Agent.swift` — 集成钩子到 prompt()/stream()
- **修改** `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — 集成钩子到 executeSingleTool()
- **新建** `Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift` — 单元测试
- **新建** `Sources/E2ETest/HookIntegrationE2ETests.swift` — E2E 测试
- **修改** `Sources/E2ETest/main.swift` — 添加新 Section
- 完全对齐架构文档的目录结构和模块边界（Hooks/ 依赖 Types/，不导入 Core/ 或 Tools/）

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
