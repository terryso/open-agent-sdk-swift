# Story 8.4: 权限模式

Status: done

## Story

作为开发者，
我希望设置六种权限模式之一来控制工具执行，
以便我可以限制 Agent 允许执行的操作。

## Acceptance Criteria

1. **AC1: PermissionMode 枚举到行为映射** — 给定 `PermissionMode` 枚举（已存在 6 个 case），当 `ToolExecutor.executeSingleTool()` 被调用时，则根据 `AgentOptions.permissionMode` 值决定是否拦截工具执行（FR32）。

2. **AC2: bypassPermissions 模式** — 给定 `permissionMode = .bypassPermissions` 的 Agent，当 LLM 请求任何工具，则工具直接执行，无需权限检查（FR32）。

3. **AC3: default 模式** — 给定 `permissionMode = .default` 的 Agent，当请求变更工具（`isReadOnly == false`，如 Write、Edit、Bash），则权限系统拦截执行并返回需要授权的提示（FR34、NFR8）。只读工具直接执行无需拦截。

4. **AC4: acceptEdits 模式** — 给定 `permissionMode = .acceptEdits` 的 Agent，当请求文件编辑工具（Write、Edit），则自动允许执行。其他变更工具（如 Bash）仍然拦截。

5. **AC5: plan 模式** — 给定 `permissionMode = .plan` 的 Agent，当请求任何变更工具，则所有变更操作被拦截（计划模式下只允许只读操作）。

6. **AC6: dontAsk 模式** — 给定 `permissionMode = .dontAsk` 的 Agent，当请求任何工具，则自动拒绝所有变更工具，无需提示用户。

7. **AC7: auto 模式** — 给定 `permissionMode = .auto` 的 Agent，当请求任何工具，则自动允许所有工具执行（与 bypassPermissions 行为相同）。

8. **AC8: canUseTool 回调优先** — 给定同时设置了 `permissionMode` 和 `canUseTool` 闭包的 Agent，当 LLM 请求工具，则先执行 `canUseTool` 回调；若回调返回非 nil 结果，使用回调结果；若返回 nil，回退到 `permissionMode` 的行为（FR33、NFR9）。

9. **AC9: canUseTool deny 行为** — 给定 `canUseTool` 回调返回 `CanUseToolResult(behavior: "deny")`，当 LLM 请求被拒绝的工具，则工具不执行，向 Agent 返回权限拒绝错误消息。

10. **AC10: canUseTool allow + updatedInput** — 给定 `canUseTool` 回调返回 `CanUseToolResult(behavior: "allow", updatedInput: ...)`，当 LLM 请求工具，则使用修改后的输入执行工具（FR33）。

11. **AC11: ToolContext 携带权限信息** — 给定 `ToolContext`，当权限检查执行时，则 `ToolContext` 可访问 `permissionMode` 和 `canUseTool`（通过 `AgentOptions` 注入），供工具自身进行额外的权限验证（NFR9）。

12. **AC12: 单元测试覆盖** — 给定 `Tests/OpenAgentSDKTests/Core/` 目录，则包含 `PermissionModeTests.swift`（或在现有 ToolExecutorTests.swift 中扩展），至少覆盖：六种模式的拦截行为、canUseTool 回调优先级、deny 返回错误消息、allow+updatedInput 传递、只读工具在所有模式下均不拦截。

13. **AC13: E2E 测试覆盖** — 给定 `Sources/E2ETest/` 目录，则包含 `PermissionModeE2ETests.swift`，至少覆盖：bypassPermissions 模式下工具直接执行、default 模式下变更工具被拦截、canUseTool 回调 deny 和 allow 路径。

## Tasks / Subtasks

- [x] Task 1: 定义权限检查逻辑 (AC: #1-#7)
  - [x] 在 `Core/ToolExecutor.swift` 的 `executeSingleTool()` 方法中添加权限检查
  - [x] 实现 `shouldBlockTool(permissionMode:tool:)` 辅助函数
  - [x] 实现 bypassPermissions: 全部放行
  - [x] 实现 default: 变更工具拦截，只读放行
  - [x] 实现 acceptEdits: Write/Edit 放行，其他变更拦截
  - [x] 实现 plan: 所有变更拦截
  - [x] 实现 dontAsk: 所有变更拒绝
  - [x] 实现 auto: 全部放行

- [x] Task 2: 集成 canUseTool 回调 (AC: #8-#11)
  - [x] 在 `ToolContext` 中添加 `permissionMode` 和 `canUseTool` 字段
  - [x] 在 `Core/Agent.swift` 中构造 `ToolContext` 时注入权限字段
  - [x] 修改 `ToolExecutor.executeSingleTool()` 先调用 canUseTool，再回退到 permissionMode
  - [x] 处理 canUseTool 的 allow/deny/updatedInput 行为

- [x] Task 3: 单元测试 (AC: #12)
  - [x] 创建/扩展 `Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift`
  - [x] 测试 shouldBlockTool 六种模式行为
  - [x] 测试 canUseTool 回调优先级
  - [x] 测试 deny 返回错误消息
  - [x] 测试 allow+updatedInput 传递
  - [x] 测试只读工具不拦截

- [x] Task 4: E2E 测试 (AC: #13)
  - [x] 创建 `Sources/E2ETest/PermissionModeE2ETests.swift`
  - [x] E2E 测试：bypassPermissions 模式下工具直接执行
  - [x] E2E 测试：default 模式下变更工具被拦截
  - [x] E2E 测试：canUseTool 回调 deny 和 allow
  - [x] 更新 `Sources/E2ETest/main.swift` 添加新 Section

- [x] Task 5: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证所有现有测试仍通过
  - [x] 运行完整测试套件并报告总数

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 8（钩子系统与权限控制）的第四个 story
- **在 ToolExecutor.executeSingleTool() 中添加基于 PermissionMode 的工具执行拦截**
- **关键目标：** 开发者可以通过 `AgentOptions.permissionMode` 控制哪些工具允许自动执行，哪些需要授权（FR32、FR34）
- **前置依赖：** Story 8-1（HookRegistry 和类型系统）和 Story 8-2（函数钩子集成到 Agent 循环）和 Story 8-3（Shell 钩子执行）
- **本 story 与 8-5 的关系：** 8-4 实现六种权限模式 + canUseTool 回调集成；8-5 将实现更高级的自定义授权回调场景（如交互式用户提示）

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `PermissionMode` | `Types/PermissionTypes.swift` | 6 个 case 的枚举，已完成 |
| `CanUseToolResult` | `Types/PermissionTypes.swift` | 包含 behavior, updatedInput, message，已完成 |
| `CanUseToolFn` | `Types/PermissionTypes.swift` | `(ToolProtocol, Any, ToolContext) async -> CanUseToolResult?`，已完成 |
| `AgentOptions.permissionMode` | `Types/AgentTypes.swift` | 默认 `.default`，已完成 |
| `AgentOptions.canUseTool` | `Types/AgentTypes.swift` | 可选闭包，已完成 |
| `ToolProtocol.isReadOnly` | `Types/ToolTypes.swift` | 只读标记，已完成 |
| `ToolExecutor` | `Core/ToolExecutor.swift` | 无状态枚举命名空间，已完成 |
| `ToolContext` | `Types/ToolTypes.swift` | 工具执行上下文，已完成 |

### TypeScript SDK 参考（关键）

TypeScript SDK 的 `executeSingleTool` 权限检查（`engine.ts` 第 429-483 行）：

```typescript
// Check permissions
if (this.config.canUseTool) {
  try {
    const permission = await this.config.canUseTool(tool, block.input)
    if (permission.behavior === 'deny') {
      return {
        type: 'tool_result',
        tool_use_id: block.id,
        content: permission.message || `Permission denied for tool "${block.name}"`,
        is_error: true,
        tool_name: block.name,
      }
    }
    if (permission.updatedInput !== undefined) {
      block = { ...block, input: permission.updatedInput as Record<string, unknown> }
    }
  } catch (err: any) {
    return {
      type: 'tool_result',
      tool_use_id: block.id,
      content: `Permission check error: ${err.message}`,
      is_error: true,
      tool_name: block.name,
    }
  }
}
```

**TypeScript SDK 的 `CanUseToolResult`（types.ts 第 205-209 行）：**
```typescript
export type CanUseToolResult = {
  behavior: 'allow' | 'deny'
  updatedInput?: unknown
  message?: string
}
```

**TypeScript SDK 的 `CanUseToolFn`（types.ts 第 211-214 行）：**
```typescript
export type CanUseToolFn = (
  tool: ToolDefinition,
  input: unknown,
) => Promise<CanUseToolResult>
```

**TypeScript SDK 权限模式（types.ts 第 197-203 行）：**
```typescript
export type PermissionMode =
  | 'default'
  | 'acceptEdits'
  | 'bypassPermissions'
  | 'plan'
  | 'dontAsk'
  | 'auto'
```

**关键行为差异（Swift vs TS）：**
1. TS SDK 中 `canUseTool` 回调签名是 `(tool, input)` — 2 个参数
2. Swift SDK 中 `CanUseToolFn` 签名是 `(ToolProtocol, Any, ToolContext) async -> CanUseToolResult?` — 3 个参数（多了 ToolContext）
3. TS SDK 的 engine 在 `executeSingleTool` 中使用 `this.config.canUseTool` — 实例方法访问
4. Swift SDK 的 `ToolExecutor` 是无状态枚举 — 需要通过 `ToolContext` 传递权限信息
5. TS SDK 没有在 engine 中直接实现六种模式的行为 — 只使用 `canUseTool` 回调。模式行为通常由宿主应用实现（如 CLI 工具中的 canUseTool 工厂函数）。**Swift SDK 需要在 ToolExecutor 中实现模式逻辑**，因为 SDK 是库，没有宿主应用。

### 六种权限模式的行为规范

| 模式 | 只读工具 | Write/Edit | Bash | 其他变更工具 |
|------|----------|------------|------|-------------|
| `.default` | 放行 | 拦截 | 拦截 | 拦截 |
| `.acceptEdits` | 放行 | 放行 | 拦截 | 拦截 |
| `.bypassPermissions` | 放行 | 放行 | 放行 | 放行 |
| `.plan` | 放行 | 拦截 | 拦截 | 拦截 |
| `.dontAsk` | 放行 | 拒绝 | 拒绝 | 拒绝 |
| `.auto` | 放行 | 放行 | 放行 | 放行 |

**拦截 vs 拒绝：**
- **拦截（block）**：返回 `isError: true` 的 ToolResult，内容为 "Permission required for tool X in Y mode"
- **拒绝（deny）**：返回 `isError: true` 的 ToolResult，内容为 "Tool X denied by permission mode"

**acceptEdits 的文件编辑工具识别：**
- 通过工具名称匹配：`tool.name == "Write" || tool.name == "Edit"`

### 需要创建/修改的文件

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Core/ToolExecutor.swift` | **修改** | executeSingleTool() 添加权限检查 |
| `Types/ToolTypes.swift` | **修改** | ToolContext 添加 permissionMode 和 canUseTool 字段 |
| `Core/Agent.swift` | **修改** | 构造 ToolContext 时注入权限字段（prompt 和 stream 两处） |

新测试文件：
| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift` | **新建** | 单元测试 |
| `Sources/E2ETest/PermissionModeE2ETests.swift` | **新建** | E2E 测试 |
| `Sources/E2ETest/main.swift` | **修改** | 添加新 Section |

### 不修改的文件

- `Types/PermissionTypes.swift` — 无需修改，PermissionMode、CanUseToolResult、CanUseToolFn 已在 1-1 完成
- `Types/AgentTypes.swift` — 无需修改，permissionMode 和 canUseTool 属性已存在
- `Hooks/HookRegistry.swift` — 无需修改，钩子触发逻辑已在 8-2 完成
- `Hooks/ShellHookExecutor.swift` — 无需修改

### 关键实现细节

**1. ToolContext 扩展**

在 `Types/ToolTypes.swift` 的 `ToolContext` 中添加两个可选字段：

```swift
public struct ToolContext: Sendable {
    // ... 现有字段 ...
    /// Optional permission mode controlling tool execution behavior.
    /// Injected by Core/ from AgentOptions.permissionMode.
    public let permissionMode: PermissionMode?
    /// Optional permission check callback for custom authorization.
    /// Injected by Core/ from AgentOptions.canUseTool.
    public let canUseTool: CanUseToolFn?

    public init(
        // ... 现有参数 ...
        permissionMode: PermissionMode? = nil,
        canUseTool: CanUseToolFn? = nil
    ) {
        // ...
        self.permissionMode = permissionMode
        self.canUseTool = canUseTool
    }

    public func withToolUseId(_ id: String) -> ToolContext {
        ToolContext(
            // ... 现有字段 ...
            permissionMode: permissionMode,
            canUseTool: canUseTool
        )
    }
}
```

**注意：** `ToolContext` 位于 `Types/`（叶节点模块），而 `PermissionMode` 和 `CanUseToolFn` 也在 `Types/PermissionTypes.swift` 中。所以 `ToolTypes.swift` 可以直接引用同模块类型，不违反模块边界。

**2. ToolExecutor.executeSingleTool() 权限检查**

在 `Core/ToolExecutor.swift` 的 `executeSingleTool()` 中，在 PreToolUse 钩子之后、工具执行之前添加权限检查：

```swift
static func executeSingleTool(
    block: ToolUseBlock,
    tool: ToolProtocol?,
    context: ToolContext
) async -> ToolResult {
    // Unknown tool handling (现有)
    guard let tool = tool else { ... }

    // PreToolUse hook (现有, Story 8-2)
    if let hookRegistry = context.hookRegistry { ... }

    // === 新增：权限检查 ===
    // Step 1: 尝试 canUseTool 回调
    if let canUseTool = context.canUseTool {
        do {
            if let result = await canUseTool(tool, block.input, context) {
                if result.behavior == "deny" {
                    return ToolResult(
                        toolUseId: block.id,
                        content: result.message ?? "Permission denied for tool \"\(block.name)\"",
                        isError: true
                    )
                }
                // allow — 可能带有 updatedInput
                // 使用 result.updatedInput 替换原始 input 执行工具
                let effectiveInput = result.updatedInput ?? block.input
                let execResult = await tool.call(input: effectiveInput, context: context)
                // PostToolUse hook (现有逻辑)
                // ...
                return ToolResult(toolUseId: block.id, content: execResult.content, isError: execResult.isError)
            }
            // canUseTool 返回 nil → 回退到 permissionMode
        } catch {
            return ToolResult(
                toolUseId: block.id,
                content: "Permission check error: \(error)",
                isError: true
            )
        }
    }

    // Step 2: 基于 permissionMode 的默认行为
    if let mode = context.permissionMode {
        let decision = shouldBlockTool(permissionMode: mode, tool: tool)
        switch decision {
        case .allow:
            break // 继续执行
        case .block(let message):
            return ToolResult(
                toolUseId: block.id,
                content: message,
                isError: true
            )
        case .deny(let message):
            return ToolResult(
                toolUseId: block.id,
                content: message,
                isError: true
            )
        }
    }

    // Execute tool (现有逻辑)
    let result = await tool.call(input: block.input, context: context)
    // PostToolUse hook (现有)
    // ...
}
```

**3. shouldBlockTool 辅助函数**

在 `ToolExecutor` 枚举中添加：

```swift
/// Permission decision for tool execution.
enum PermissionDecision: Sendable {
    case allow
    case block(String)   // 拦截 — 需要授权提示
    case deny(String)    // 拒绝 — 直接拒绝
}

/// Determines whether a tool should be blocked based on the permission mode.
///
/// - Parameters:
///   - permissionMode: The active permission mode.
///   - tool: The tool being checked.
/// - Returns: A permission decision.
static func shouldBlockTool(permissionMode: PermissionMode, tool: ToolProtocol) -> PermissionDecision {
    // 只读工具在所有模式下都放行
    if tool.isReadOnly { return .allow }

    switch permissionMode {
    case .bypassPermissions, .auto:
        return .allow
    case .default:
        return .block("Permission required for tool \"\(tool.name)\" in default mode")
    case .acceptEdits:
        // Write/Edit 放行，其他变更拦截
        if tool.name == "Write" || tool.name == "Edit" {
            return .allow
        }
        return .block("Permission required for tool \"\(tool.name)\" in acceptEdits mode")
    case .plan:
        return .block("Tool \"\(tool.name)\" blocked in plan mode (read-only)")
    case .dontAsk:
        return .deny("Tool \"\(tool.name)\" denied in dontAsk mode")
    }
}
```

**4. Agent.swift 修改**

在 `prompt()` 和 `stream()` 中构造 `ToolContext` 时注入权限字段：

```swift
// prompt() 中（约第 338-352 行）
let toolResults = await ToolExecutor.executeTools(
    toolUseBlocks: toolUseBlocks,
    tools: registeredTools,
    context: ToolContext(
        cwd: options.cwd ?? "",
        agentSpawner: spawner,
        mailboxStore: options.mailboxStore,
        teamStore: options.teamStore,
        senderName: options.agentName,
        taskStore: options.taskStore,
        worktreeStore: options.worktreeStore,
        planStore: options.planStore,
        cronStore: options.cronStore,
        todoStore: options.todoStore,
        hookRegistry: options.hookRegistry,
        permissionMode: options.permissionMode,     // 新增
        canUseTool: options.canUseTool               // 新增
    )
)

// stream() 中（约第 861-877 行）— 同样添加两个字段
```

**5. 权限检查与钩子的关系**

PreToolUse 钩子在权限检查**之前**执行。这意味着：
1. 如果 PreToolUse 钩子返回 `block: true` → 工具被阻止，不再执行权限检查
2. 如果 PreToolUse 钩子未阻止 → 继续权限检查
3. 权限检查通过 → 执行工具
4. PostToolUse 钩子照常触发

这个顺序是正确的，因为：
- 钩子系统是开发者注册的事件处理器（Story 8-1/8-2/8-3）
- 权限模式是 SDK 内置的安全层
- 钩子优先级高于权限（开发者可以在钩子中覆盖权限决策）

### 前序 Story 的经验教训（必须遵循）

来自 Story 8-1、8-2、8-3 的 Dev Notes 和 Completion Notes：

1. **Actor 方法外部调用需要 `await`** — HookRegistry 的所有公共方法都是 actor 隔离的
2. **`_Concurrency.Task.sleep` 而非 `Task.sleep`** — 项目有自定义 Task 类型冲突
3. **`@unchecked Sendable` 模式** — CanUseToolResult 使用此模式
4. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
5. **E2E 测试** — 使用真实环境（不使用 mock）
6. **不使用 Apple 专属框架** — Foundation 和 Regex 在 macOS 和 Linux 均可用
7. **force-unwrap 禁止** — 使用 guard let / if let
8. **错误不传播** — 钩子失败静默处理，权限拒绝以 ToolResult(isError:true) 返回
9. **ToolExecutor 是无状态 enum** — 所有方法为 static，状态通过参数传递
10. **整数溢出** — 使用 `UInt64(clamping:)` 防止溢出
11. **canUseTool 回调是 `async`** — 需要使用 `await` 调用
12. **ToolContext.withToolUseId** 需要保留所有字段 — 添加新字段时记得更新此方法

### 反模式警告

- **不要**修改 `Types/PermissionTypes.swift` — 所有类型定义已完成
- **不要**修改 `Types/AgentTypes.swift` — permissionMode 和 canUseTool 属性已存在
- **不要**在 Types/ 中导入 Core/ — 违反模块边界
- **不要**在 ToolExecutor 中存储状态 — 它是无状态的 enum
- **不要**让权限拒绝传播为异常 — 必须返回 ToolResult(isError: true)
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台
- **不要**使用 `Task.sleep` — 使用 `_Concurrency.Task.sleep`
- **不要**在 acceptEdits 模式中仅通过 `isReadOnly` 判断 — Write/Edit 的 `isReadOnly` 为 false，需要通过工具名称特殊处理
- **不要**在 canUseTool 回调抛出异常时让 Agent 崩溃 — 捕获异常返回错误 ToolResult
- **不要**忘记更新 `withToolUseId` 方法 — 新增 permissionMode 和 canUseTool 字段后必须包含

### 模块边界

```
Types/ToolTypes.swift              → 修改：ToolContext 添加 permissionMode, canUseTool
Core/ToolExecutor.swift             → 修改：executeSingleTool() 添加权限检查
Core/Agent.swift                    → 修改：ToolContext 构造注入权限字段
```

新测试文件：
```
Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift   (新建)
Sources/E2ETest/PermissionModeE2ETests.swift               (新建)
Sources/E2ETest/main.swift                                  (修改：添加新 Section)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 8-1 (已完成) | 依赖 — 使用其 HookEvent、HookInput、HookOutput 类型 |
| 8-2 (已完成) | 依赖 — PreToolUse 钩子已在 ToolExecutor.executeSingleTool() 中集成，权限检查在钩子之后 |
| 8-3 (已完成) | 依赖 — Shell 钩子执行已在 HookRegistry 中集成 |
| 8-5 (后续) | 后续 — 自定义授权回调的高级场景，如交互式用户提示 |
| 1-1 (已完成) | 使用 — PermissionMode、CanUseToolResult、CanUseToolFn 类型 |

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift）：**

- `testShouldBlockTool_bypassPermissions_allowsAll` — 变更工具在 bypassPermissions 下放行
- `testShouldBlockTool_auto_allowsAll` — 变更工具在 auto 下放行
- `testShouldBlockTool_default_blocksMutationTools` — 变更工具在 default 下拦截
- `testShouldBlockTool_default_allowsReadOnlyTools` — 只读工具在 default 下放行
- `testShouldBlockTool_acceptEdits_allowsWriteEdit` — Write/Edit 在 acceptEdits 下放行
- `testShouldBlockTool_acceptEdits_blocksBash` — Bash 在 acceptEdits 下拦截
- `testShouldBlockTool_plan_blocksAllMutations` — 所有变更在 plan 下拦截
- `testShouldBlockTool_dontAsk_deniesAllMutations` — 所有变更在 dontAsk 下拒绝
- `testExecuteSingleTool_canUseToolDeny_returnsError` — canUseTool 返回 deny
- `testExecuteSingleTool_canUseToolAllow_executesTool` — canUseTool 返回 allow
- `testExecuteSingleTool_canUseToolUpdatedInput_usesModifiedInput` — canUseTool 修改输入
- `testExecuteSingleTool_canUseToolReturnsNil_fallsBackToPermissionMode` — canUseTool 返回 nil 回退到模式
- `testExecuteSingleTool_canUseToolThrows_returnsError` — canUseTool 抛出异常
- `testExecuteSingleTool_noCanUseToolNoPermissionMode_executesTool` — 无权限配置时直接执行

**E2E 测试（Sources/E2ETest/PermissionModeE2ETests.swift）：**
- 使用真实的 LLM 调用验证权限模式
- bypassPermissions 模式下 LLM 驱动的工具调用成功执行
- default 模式下 LLM 驱动的变更工具被拦截
- canUseTool 回调 deny 路径
- canUseTool 回调 allow 路径

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.4 权限模式]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD8 权限模型 — 枚举 + 回调拦截器]
- [Source: _bmad-output/planning-artifacts/prd.md#FR32 六种权限模式]
- [Source: _bmad-output/planning-artifacts/prd.md#FR33 自定义 canUseTool 回调]
- [Source: _bmad-output/planning-artifacts/prd.md#FR34 基于权限的工具访问控制]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR8 权限系统在执行前强制执行]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR9 自定义 canUseTool 回调接收完整工具上下文]
- [Source: _bmad-output/implementation-artifacts/8-3-shell-hook-execution.md] — Story 8-3 完成记录
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/engine.ts:429-483] — TS SDK 权限检查
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/types.ts:194-214] — TS SDK 权限类型
- [Source: Sources/OpenAgentSDK/Types/PermissionTypes.swift] — 已有的 PermissionMode, CanUseToolResult, CanUseToolFn
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift:217-276] — executeSingleTool() 当前实现
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift:42-120] — ToolContext 当前实现

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Types/ToolTypes.swift` — ToolContext 添加 permissionMode 和 canUseTool
- **修改** `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — executeSingleTool() 添加权限检查逻辑
- **修改** `Sources/OpenAgentSDK/Core/Agent.swift` — ToolContext 构造注入权限字段
- **新建** `Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift` — 单元测试
- **新建** `Sources/E2ETest/PermissionModeE2ETests.swift` — E2E 测试
- **修改** `Sources/E2ETest/main.swift` — 添加新 Section 41
- **不修改** `Types/PermissionTypes.swift`、`Types/AgentTypes.swift`、`Hooks/` 目录下任何文件
- 完全对齐架构文档的目录结构和模块边界（Types/ 是叶节点，Core/ 依赖 Types/）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Task 1: Added `PermissionDecision` enum (allow/block/deny) and `shouldBlockTool(permissionMode:tool:)` static method to `ToolExecutor`. Implements all 6 permission modes: bypassPermissions and auto allow all; default blocks mutations; acceptEdits allows Write/Edit, blocks others; plan blocks all mutations; dontAsk denies all mutations. Read-only tools always pass.
- Task 2: Added `permissionMode: PermissionMode?` and `canUseTool: CanUseToolFn?` fields to `ToolContext` (with defaults = nil). Updated `withToolUseId()` to preserve them. Injected both fields from `AgentOptions` in `Agent.prompt()` and `Agent.stream()`. Added permission check in `executeSingleTool()` between PreToolUse hook and tool execution: canUseTool callback takes priority, falls back to permissionMode on nil return.
- Task 3: Unit tests (15 total) already existed from ATDD red phase -- all now pass. Covers: 8 shouldBlockTool tests for all 6 modes, 7 executeSingleTool integration tests for canUseTool deny/allow/updatedInput/nil fallback/no-config, plus ToolContext field preservation test.
- Task 4: E2E tests (4 total) already existed from ATDD red phase. `main.swift` already had Section 41 added.
- Task 5: `swift build` succeeds. Full test suite: all 1539 tests pass, 0 failures, 4 skipped (pre-existing).

### File List

- `Sources/OpenAgentSDK/Types/ToolTypes.swift` — Modified: Added `permissionMode` and `canUseTool` fields to ToolContext, updated init and withToolUseId
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — Modified: Added PermissionDecision enum, shouldBlockTool() method, permission check logic in executeSingleTool()
- `Sources/OpenAgentSDK/Core/Agent.swift` — Modified: Injected permissionMode and canUseTool into ToolContext construction in prompt() and stream()
- `Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift` — Pre-existing (ATDD): 15 unit tests, now passing
- `Sources/E2ETest/PermissionModeE2ETests.swift` — Pre-existing (ATDD): 4 E2E tests
- `Sources/E2ETest/main.swift` — Pre-existing: Section 41 already added

### Review Findings

- [x] [Review][Patch] Duplicated PostToolUse hook logic [ToolExecutor.swift:309-321] — Fixed: extracted firePostToolHook() helper, both call sites now use it.
- [x] [Review][Patch] Tautological E2E assertion in default mode test [PermissionModeE2ETests.swift:93] — Fixed: removed `result.status == .success` from OR condition.
- [x] [Review][Defer] acceptEdits magic string matching [ToolExecutor.swift:80] — deferred, pre-existing design decision consistent with TypeScript SDK
- [x] [Review][Defer] Non-deterministic E2E test reliability [PermissionModeE2ETests.swift:41c] — deferred, inherent limitation of LLM-driven E2E tests

### Change Log

- 2026-04-09: Implemented permission mode enforcement — ToolContext extended, shouldBlockTool added, executeSingleTool permission checks integrated, Agent injection complete. All 1539 tests pass.
