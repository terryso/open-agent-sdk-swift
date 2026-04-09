# Story 8.5: 自定义授权回调

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望提供高级自定义 canUseTool 授权回调，包括策略构建器和动态权限切换，
以便我可以轻松实现复杂的工具授权逻辑（如工具名称白名单、组合策略、运行时权限切换）而无需为每个场景手写闭包。

## Acceptance Criteria

1. **AC1: PermissionPolicy 协议** — 给定 `PermissionPolicy` 协议，当开发者创建自定义授权策略，则策略可被用作 `canUseTool` 回调（FR33、NFR9）。

2. **AC2: ToolNameAllowlistPolicy** — 给定 `ToolNameAllowlistPolicy`（允许的工具名称集合），当 LLM 请求工具执行，则仅允许名称在集合中的工具执行，其他工具返回 deny。

3. **AC3: ToolNameDenylistPolicy** — 给定 `ToolNameDenylistPolicy`（拒绝的工具名称集合），当 LLM 请求工具执行，则拒绝名称在集合中的工具，其他工具放行。

4. **AC4: ReadOnlyPolicy** — 给定 `ReadOnlyPolicy`，当 LLM 请求任何变更工具（`isReadOnly == false`），则返回 deny；只读工具放行。此策略与 `.plan` 模式类似但通过策略接口实现。

5. **AC5: CompositePolicy（组合策略）** — 给定 `CompositePolicy`（包含多个 `PermissionPolicy`），当 LLM 请求工具，则按顺序评估每个子策略：任何子策略返回 deny 则整体 deny；所有子策略返回 allow 则整体 allow；任何子策略返回 nil 则跳过继续下一个。

6. **AC6: Agent.setPermissionMode() 动态切换** — 给定正在运行的 Agent 会话，当开发者调用 `agent.setPermissionMode(.bypassPermissions)`，则后续的工具执行使用新的权限模式（FR32、FR34）。此方法同时清除当前 `canUseTool` 回调（如果存在），使新的 permissionMode 生效。

7. **AC7: Agent.setCanUseTool() 动态回调更新** — 给定正在运行的 Agent 会话，当开发者调用 `agent.setCanUseTool(myPolicy)`，则后续的工具执行使用新的授权回调。之前通过 `setPermissionMode()` 设置的模式被回调优先级覆盖。

8. **AC8: PermissionPolicyToFn 桥接** — 给定 `PermissionPolicy`，当开发者通过 `canUseTool(policy)` 便利函数转换，则返回 `CanUseToolFn` 闭包，可直接设置到 `AgentOptions.canUseTool` 或通过 `setCanUseTool()` 使用。

9. **AC9: CanUseToolResult 便利工厂方法** — 给定 `CanUseToolResult` 类型，当开发者使用 `CanUseToolResult.allow()`、`.deny(_:)`、`.allowWithInput(_:)` 静态方法，则创建对应的结果实例，无需手写 `behavior` 字符串。

10. **AC10: ToolContext 权限信息扩展** — 给定 `ToolContext`，当策略回调执行时，则 `ToolContext` 可访问 `permissionMode`（通过已有的 `permissionMode` 属性），策略可基于当前模式做条件决策（NFR9）。

11. **AC11: 单元测试覆盖** — 给定 `Tests/OpenAgentSDKTests/Core/` 目录，则包含 `PermissionPolicyTests.swift`，至少覆盖：每个策略类型的 allow/deny 决策、CompositePolicy 组合评估、PermissionPolicyToFn 桥接、CanUseToolResult 便利工厂方法。

12. **AC12: E2E 测试覆盖** — 给定 `Sources/E2ETest/` 目录，则包含 `AuthorizationCallbackE2ETests.swift`，至少覆盖：LLM 驱动的 allowlist 策略执行、LLM 驱动的 denylist 策略拒绝、动态 setPermissionMode 切换。

## Tasks / Subtasks

- [x] Task 1: 定义 PermissionPolicy 协议和基础策略 (AC: #1-#4)
  - [x] 在 `Types/PermissionTypes.swift` 中定义 `PermissionPolicy` 协议
  - [x] 实现 `ToolNameAllowlistPolicy` 结构体
  - [x] 实现 `ToolNameDenylistPolicy` 结构体
  - [x] 实现 `ReadOnlyPolicy` 结构体

- [x] Task 2: 实现 CompositePolicy 和便利桥接 (AC: #5, #8)
  - [x] 实现 `CompositePolicy` 结构体，支持多策略组合
  - [x] 实现 `canUseTool(policy:)` 全局便利函数
  - [x] 实现 CanUseToolResult 便利工厂方法 (AC: #9)

- [x] Task 3: Agent 动态权限切换 (AC: #6, #7)
  - [x] 在 `Core/Agent.swift` 添加 `setPermissionMode(_:)` 公共方法
  - [x] 在 `Core/Agent.swift` 添加 `setCanUseTool(_:)` 公共方法
  - [x] 确保 Agent 的 options 中的变更在下次工具执行时生效

- [x] Task 4: 单元测试 (AC: #11)
  - [x] 创建 `Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift`
  - [x] 测试 ToolNameAllowlistPolicy allow/deny
  - [x] 测试 ToolNameDenylistPolicy allow/deny
  - [x] 测试 ReadOnlyPolicy allow/deny
  - [x] 测试 CompositePolicy 组合评估
  - [x] 测试 canUseTool(policy:) 桥接
  - [x] 测试 CanUseToolResult 便利工厂方法
  - [x] 测试 Agent.setPermissionMode() 动态切换
  - [x] 测试 Agent.setCanUseTool() 动态更新

- [x] Task 5: E2E 测试 (AC: #12)
  - [x] 创建 `Sources/E2ETest/AuthorizationCallbackE2ETests.swift`
  - [x] E2E 测试：allowlist 策略下 LLM 驱动的工具调用
  - [x] E2E 测试：denylist 策略下 LLM 驱动的工具拒绝
  - [x] E2E 测试：动态 setPermissionMode 切换
  - [x] 更新 `Sources/E2ETest/main.swift` 添加新 Section

- [x] Task 6: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证所有现有测试仍通过
  - [x] 运行完整测试套件并报告总数

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 8（钩子系统与权限控制）的第五个 story，也是最后一个 story
- **在 Story 8-4 已实现的 canUseTool 基础设施之上，提供高级开发者体验**
- **关键目标：** 开发者可以使用策略模式（而非手写闭包）实现复杂授权逻辑，并支持运行时动态切换权限配置（FR33、NFR9）
- **前置依赖：** Story 8-1（HookRegistry）、8-2（函数钩子集成）、8-3（Shell 钩子）、8-4（权限模式 + canUseTool 基础集成）

**与 Story 8-4 的关系：**
- 8-4 实现了 `CanUseToolFn` 类型、`ToolContext` 扩展、`executeSingleTool()` 中的权限检查
- 8-5 在此基础上提供策略模式和动态切换 API
- 8-4 是"引擎层"（how canUseTool works），8-5 是"开发者体验层"（how developers use it）

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `PermissionMode` | `Types/PermissionTypes.swift` | 6 个 case 的枚举，已完成 |
| `CanUseToolResult` | `Types/PermissionTypes.swift` | behavior + updatedInput + message，已完成 |
| `CanUseToolFn` | `Types/PermissionTypes.swift` | `(ToolProtocol, Any, ToolContext) async -> CanUseToolResult?`，已完成 |
| `AgentOptions.permissionMode` | `Types/AgentTypes.swift` | 默认 `.default`，`var`（可变） |
| `AgentOptions.canUseTool` | `Types/AgentTypes.swift` | 可选闭包，`var`（可变） |
| `ToolContext.permissionMode` | `Types/ToolTypes.swift` | 只读属性，已完成 |
| `ToolContext.canUseTool` | `Types/ToolTypes.swift` | 只读属性，已完成 |
| `ToolProtocol.isReadOnly` | `Types/ToolTypes.swift` | 只读标记，已完成 |
| `ToolExecutor.shouldBlockTool()` | `Core/ToolExecutor.swift` | 模式→决策映射，已完成 |
| `ToolExecutor.executeSingleTool()` | `Core/ToolExecutor.swift` | 权限检查集成，已完成 |

### TypeScript SDK 参考（关键差异）

**TypeScript SDK 的 `setPermissionMode`（agent.ts 第 338-342 行）：**
```typescript
/**
 * Change the permission mode during a session.
 */
async setPermissionMode(mode: PermissionMode): Promise<void> {
  this.cfg.permissionMode = mode
}
```

**TypeScript SDK 的 canUseTool 构建模式（agent.ts 第 185-195 行）：**
```typescript
const permMode = opts.permissionMode ?? 'bypassPermissions'
const canUseTool: CanUseToolFn = opts.canUseTool ?? (async (_tool, _input) => {
  if (permMode === 'bypassPermissions' || permMode === 'dontAsk' || permMode === 'auto') {
    return { behavior: 'allow' }
  }
  if (permMode === 'acceptEdits') {
    return { behavior: 'allow' }
  }
  return { behavior: 'allow' }
})
```

**TypeScript SDK 的子代理 canUseTool 覆盖（agent-tool.ts 第 112 行）：**
```typescript
canUseTool: async () => ({ behavior: 'allow' }),
```

**关键观察：**
1. TS SDK 的 `setPermissionMode` 是简单的属性赋值 — Swift SDK 的 `AgentOptions` 是 struct，需要通过 Agent 类的方法来修改
2. TS SDK 中 canUseTool 的默认实现总是返回 allow — Swift SDK 在 8-4 中实现了更丰富的模式行为
3. TS SDK 没有策略模式 — 这是 Swift SDK 的增强，提供更好的开发者体验
4. TS SDK 的子代理总是 bypass — Swift SDK 的 AgentTool 已在 8-4 中处理

### PermissionPolicy 协议设计

```swift
/// Protocol for defining custom tool authorization policies.
///
/// A `PermissionPolicy` evaluates whether a tool should be allowed to execute
/// based on the tool, its input, and the execution context. Policies can be
/// composed using `CompositePolicy` for complex authorization scenarios.
///
/// Usage:
/// ```swift
/// let policy = ToolNameAllowlistPolicy(allowed: ["Read", "Glob", "Grep"])
/// agent.setCanUseTool(canUseTool(policy: policy))
/// ```
public protocol PermissionPolicy: Sendable {
    /// Evaluates whether the tool execution should be allowed.
    ///
    /// - Parameters:
    ///   - tool: The tool being evaluated.
    ///   - input: The raw input for the tool call.
    ///   - context: The execution context with permission info.
    /// - Returns: A `CanUseToolResult` with the decision, or `nil` to defer
    ///   to the next policy or the default permission mode behavior.
    func evaluate(
        tool: ToolProtocol,
        input: Any,
        context: ToolContext
    ) async -> CanUseToolResult?
}
```

**设计选择 — 返回 `CanUseToolResult?`（可选）：**
- 返回非 nil = 做出决策（allow 或 deny）
- 返回 nil = "跳过/无意见" — 让下一个策略或 permissionMode 决定
- 这与 `CanUseToolFn` 的返回类型一致，允许策略链式组合

### 具体策略实现

**1. ToolNameAllowlistPolicy**
```swift
public struct ToolNameAllowlistPolicy: PermissionPolicy, Sendable, Equatable {
    public let allowedToolNames: Set<String>

    public init(allowedToolNames: Set<String>) {
        self.allowedToolNames = allowedToolNames
    }

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if allowedToolNames.contains(tool.name) {
            return CanUseToolResult.allow()
        }
        return CanUseToolResult.deny("Tool \"\(tool.name)\" not in allowlist")
    }
}
```

**2. ToolNameDenylistPolicy**
```swift
public struct ToolNameDenylistPolicy: PermissionPolicy, Sendable, Equatable {
    public let deniedToolNames: Set<String>

    public init(deniedToolNames: Set<String>) {
        self.deniedToolNames = deniedToolNames
    }

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if deniedToolNames.contains(tool.name) {
            return CanUseToolResult.deny("Tool \"\(tool.name)\" is denied")
        }
        return .allow()  // 不在黑名单 = 允许
    }
}
```

**3. ReadOnlyPolicy**
```swift
public struct ReadOnlyPolicy: PermissionPolicy, Sendable, Equatable {
    public init() {}

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if tool.isReadOnly {
            return .allow()
        }
        return .deny("Tool \"\(tool.name)\" denied: read-only policy active")
    }
}
```

**4. CompositePolicy**
```swift
public struct CompositePolicy: PermissionPolicy, Sendable {
    public let policies: [PermissionPolicy]

    public init(policies: [PermissionPolicy]) {
        self.policies = policies
    }

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        for policy in policies {
            if let result = await policy.evaluate(tool: tool, input: input, context: context) {
                if result.behavior == "deny" {
                    return result  // 任何 deny → 整体 deny（短路）
                }
                // allow 或带 updatedInput 的 allow → 继续检查其他策略
            }
            // nil → 此策略无意见，继续下一个
        }
        // 所有策略都允许或无意见 → 允许
        return .allow()
    }
}
```

### CanUseToolResult 便利工厂方法

在现有 `CanUseToolResult` 结构体中添加静态工厂方法（向后兼容扩展）：

```swift
extension CanUseToolResult {
    /// Creates an allow result.
    public static func allow() -> CanUseToolResult {
        CanUseToolResult(behavior: "allow")
    }

    /// Creates a deny result with a message.
    public static func deny(_ message: String) -> CanUseToolResult {
        CanUseToolResult(behavior: "deny", message: message)
    }

    /// Creates an allow result with modified input.
    public static func allowWithInput(_ updatedInput: Any) -> CanUseToolResult {
        CanUseToolResult(behavior: "allow", updatedInput: updatedInput)
    }
}
```

### canUseTool(policy:) 便利函数

```swift
/// Creates a `CanUseToolFn` closure from a `PermissionPolicy`.
///
/// This bridge function converts a policy into the callback format expected
/// by `AgentOptions.canUseTool` and `Agent.setCanUseTool()`.
///
/// - Parameter policy: The permission policy to use for authorization decisions.
/// - Returns: A `CanUseToolFn` closure that delegates to the policy's `evaluate()` method.
public func canUseTool(policy: PermissionPolicy) -> CanUseToolFn {
    return { tool, input, context in
        await policy.evaluate(tool: tool, input: input, context: context)
    }
}
```

### Agent 动态权限切换

在 `Core/Agent.swift` 的 `Agent` 类中添加两个公共方法：

```swift
/// Changes the permission mode for subsequent tool executions.
///
/// This also clears any custom `canUseTool` callback, so the new
/// permission mode takes effect immediately.
///
/// - Parameter mode: The new permission mode to use.
public func setPermissionMode(_ mode: PermissionMode) {
    options.permissionMode = mode
    options.canUseTool = nil  // 清除自定义回调，使新模式生效
}

/// Sets a custom authorization callback for subsequent tool executions.
///
/// The callback takes priority over the configured `permissionMode`.
/// To revert to permission-mode-based behavior, call `setPermissionMode()`.
///
/// - Parameter callback: The authorization callback, or nil to clear it.
public func setCanUseTool(_ callback: CanUseToolFn?) {
    options.canUseTool = callback
}
```

**重要设计决策：`setPermissionMode()` 同时清除 `canUseTool`**
- 理由：canUseTool 回调优先于 permissionMode（8-4 的设计）
- 如果不清除，用户调用 `setPermissionMode(.bypassPermissions)` 后 canUseTool 仍然覆盖新模式
- 清除后，新的 permissionMode 可以正确生效
- 如果用户想同时保留 canUseTool 和 permissionMode，应先 `setPermissionMode`，再 `setCanUseTool`

**AgentOptions 必须是 `class` 的 `var` 属性：**
- 检查 `Agent` 类中 `options` 属性是否为 `var`（可变）
- 如果不是，需要将其改为 `var` 或提供其他修改方式
- 注意：`AgentOptions` 是 struct — `options` 属性需要 `var` 声明

### 需要创建/修改的文件

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Types/PermissionTypes.swift` | **修改** | 添加 `PermissionPolicy` 协议、4 个策略实现、`CanUseToolResult` 扩展、`canUseTool(policy:)` 全局函数 |
| `Core/Agent.swift` | **修改** | 添加 `setPermissionMode(_:)` 和 `setCanUseTool(_:)` 方法 |
| `OpenAgentSDK.swift` | **修改** | 确保 `PermissionPolicy` 协议和相关类型被重新导出 |

新测试文件：
| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift` | **新建** | 单元测试 |
| `Sources/E2ETest/AuthorizationCallbackE2ETests.swift` | **新建** | E2E 测试 |
| `Sources/E2ETest/main.swift` | **修改** | 添加新 Section |

### 不修改的文件

- `Core/ToolExecutor.swift` — 无需修改，权限检查逻辑已在 8-4 完成
- `Types/ToolTypes.swift` — 无需修改，ToolContext 已包含 permissionMode 和 canUseTool
- `Types/AgentTypes.swift` — 无需修改，AgentOptions 已有 permissionMode（var）和 canUseTool（var）
- `Hooks/HookRegistry.swift` — 无需修改
- `Hooks/ShellHookExecutor.swift` — 无需修改

### 关键实现细节

**1. PermissionPolicy 和策略类型的位置**

所有策略类型添加到 `Types/PermissionTypes.swift`。理由：
- `PermissionTypes.swift` 已有 `PermissionMode`、`CanUseToolResult`、`CanUseToolFn`
- 策略类型与授权类型紧密相关
- 位于 `Types/` 目录（叶节点），不违反模块边界
- `PermissionPolicy` 协议依赖 `ToolProtocol` 和 `ToolContext` — 都在 `Types/` 中

**2. canUseTool(policy:) 是全局函数**

作为全局函数（而非 PermissionPolicy 的方法），理由：
- 返回类型是 `CanUseToolFn`（typealias）
- 作为桥接函数，放在调用端更自然
- 类似 TypeScript 的工厂模式

**3. CompositePolicy 的短路行为**

- 第一个 deny → 立即返回（短路）
- allow 不短路 — 继续检查其他策略（可能后面的策略会 deny）
- nil 跳过 — 无意见的策略不参与决策
- 全部通过 → allow

**4. Agent 类中 options 属性的 mutability**

需要验证 `Agent` 类中 `options` 属性是 `var`。如果当前是 `let`，需改为 `var`。
由于 `AgentOptions` 是 struct，修改 `options` 的属性（如 `permissionMode`）需要整体赋值能力。

### 前序 Story 的经验教训（必须遵循）

来自 Story 8-1、8-2、8-3、8-4 的 Dev Notes 和 Completion Notes：

1. **Actor 方法外部调用需要 `await`** — HookRegistry 的所有公共方法都是 actor 隔离的
2. **`_Concurrency.Task.sleep` 而非 `Task.sleep`** — 项目有自定义 Task 类型冲突
3. **`@unchecked Sendable` 模式** — CanUseToolResult 使用此模式
4. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
5. **E2E 测试** — 使用真实环境（不使用 mock）
6. **不使用 Apple 专属框架** — Foundation 和 Regex 在 macOS 和 Linux 均可用
7. **force-unwrap 禁止** — 使用 guard let / if let
8. **错误不传播** — 权限拒绝以 ToolResult(isError:true) 返回
9. **ToolExecutor 是无状态 enum** — 所有方法为 static，状态通过参数传递
10. **整数溢出** — 使用 `UInt64(clamping:)` 防止溢出
11. **canUseTool 回调是 `async`** — 需要使用 `await` 调用
12. **ToolContext.withToolUseId** 需要保留所有字段
13. **不要使用 `import Logging`** — 与前序 story 保持一致
14. **不要使用 Apple 专属框架（UIKit, AppKit）** — 必须跨平台
15. **不要使用 `Task.sleep`** — 使用 `_Concurrency.Task.sleep`
16. **不要在 acceptEdits 模式中仅通过 `isReadOnly` 判断** — Write/Edit 需要通过工具名称特殊处理

### 反模式警告

- **不要**修改 `Core/ToolExecutor.swift` — 权限检查逻辑已完整，无需变更
- **不要**修改 `Types/ToolTypes.swift` — ToolContext 已有 permissionMode 和 canUseTool
- **不要**在 PermissionPolicy 中引入 Core/ 依赖 — 策略类型必须留在 Types/
- **不要**让策略 evaluate() 方法抛出异常 — 必须返回 CanUseToolResult?
- **不要**忘记 PermissionPolicy 协议需要 `Sendable` 约束 — 用于并发上下文
- **不要**在 `setPermissionMode()` 中不清除 canUseTool — 会导致新模式被旧回调覆盖
- **不要**使用 behavior 字符串比较之外的方式判断 deny — 与 8-4 保持一致（`result.behavior == "deny"`）
- **不要**在 CompositePolicy 中对 allow 短路 — 必须检查所有策略，因为后续策略可能 deny
- **不要**将 `canUseTool(policy:)` 设为 PermissionProtocol 的方法 — 它是全局桥接函数

### 模块边界

```
Types/PermissionTypes.swift              → 修改：添加 PermissionPolicy、策略实现、CanUseToolResult 扩展、桥接函数
Core/Agent.swift                         → 修改：添加 setPermissionMode() 和 setCanUseTool()
OpenAgentSDK.swift                        → 修改：确保新类型被重新导出
```

新测试文件：
```
Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift   (新建)
Sources/E2ETest/AuthorizationCallbackE2ETests.swift         (新建)
Sources/E2ETest/main.swift                                    (修改：添加新 Section)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 8-1 (已完成) | 依赖 — HookEvent、HookInput、HookOutput 类型 |
| 8-2 (已完成) | 依赖 — PreToolUse 钩子集成 |
| 8-3 (已完成) | 依赖 — Shell 钩子执行 |
| 8-4 (已完成) | 直接依赖 — canUseTool 基础设施（CanUseToolFn、ToolContext 扩展、executeSingleTool 权限检查）。本 story 在 8-4 之上构建开发者体验层 |
| 1-1 (已完成) | 使用 — PermissionMode、CanUseToolResult、CanUseToolFn 类型 |
| 3-1 (已完成) | 使用 — ToolProtocol、ToolResult、ToolContext 类型 |

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift）：**

策略测试：
- `testToolNameAllowlistPolicy_allowedTool_returnsAllow` — 允许的工具放行
- `testToolNameAllowlistPolicy_deniedTool_returnsDeny` — 不在列表的工具拒绝
- `testToolNameAllowlistPolicy_emptySet_deniesAll` — 空集合拒绝所有
- `testToolNameDenylistPolicy_deniedTool_returnsDeny` — 黑名单工具拒绝
- `testToolNameDenylistPolicy_allowedTool_returnsAllow` — 不在列表的工具放行
- `testToolNameDenylistPolicy_emptySet_allowsAll` — 空集合允许所有
- `testReadOnlyPolicy_readOnlyTool_returnsAllow` — 只读工具放行
- `testReadOnlyPolicy_mutationTool_returnsDeny` — 变更工具拒绝

CompositePolicy 测试：
- `testCompositePolicy_allAllow_returnsAllow` — 所有策略允许
- `testCompositePolicy_oneDeny_returnsDeny` — 任何一个拒绝则整体拒绝
- `testCompositePolicy_denyShortCircuits` — deny 短路，不评估后续策略
- `testCompositePolicy_nilSkips` — nil 策略被跳过
- `testCompositePolicy_emptyPolicies_returnsAllow` — 空策略列表允许

桥接和工厂方法测试：
- `testCanUseToolPolicy_bridge_returnsExpectedResults` — 桥接函数正确委托
- `testCanUseToolResult_allow_createsAllowResult` — .allow() 工厂方法
- `testCanUseToolResult_deny_createsDenyResult` — .deny() 工厂方法
- `testCanUseToolResult_allowWithInput_createsResultWithInput` — .allowWithInput() 工厂方法

动态切换测试：
- `testAgent_setPermissionMode_updatesMode` — 切换模式生效
- `testAgent_setPermissionMode_clearsCanUseTool` — 切换模式清除回调
- `testAgent_setCanUseTool_updatesCallback` — 设置新回调

**E2E 测试（Sources/E2ETest/AuthorizationCallbackE2ETests.swift）：**
- 使用真实的 LLM 调用验证策略执行
- allowlist 策略下 LLM 驱动的工具调用只执行允许的工具
- denylist 策略下 LLM 驱动的拒绝行为
- 动态 setPermissionMode 切换后的行为变化

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.5 自定义授权回调]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD8 权限模型 — 枚举 + 回调拦截器]
- [Source: _bmad-output/planning-artifacts/prd.md#FR33 自定义 canUseTool 回调]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR9 自定义 canUseTool 回调接收完整工具上下文]
- [Source: _bmad-output/implementation-artifacts/8-4-permission-modes.md] — Story 8-4 完成记录
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/agent.ts:338-342] — TS SDK setPermissionMode
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/agent.ts:185-195] — TS SDK canUseTool 构建
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/agent-tool.ts:112] — TS SDK 子代理 bypass
- [Source: Sources/OpenAgentSDK/Types/PermissionTypes.swift] — 已有的 PermissionMode, CanUseToolResult, CanUseToolFn
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift:320-372] — executeSingleTool() 权限检查（8-4 已实现）
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift:42-132] — ToolContext 当前实现
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:1-150] — AgentOptions 当前实现

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Types/PermissionTypes.swift` — 添加 PermissionPolicy 协议、4 个策略类型、CanUseToolResult 扩展、canUseTool() 桥接函数
- **修改** `Sources/OpenAgentSDK/Core/Agent.swift` — 添加 setPermissionMode() 和 setCanUseTool()
- **修改** `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 确保新公共类型被重新导出
- **新建** `Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift` — 单元测试
- **新建** `Sources/E2ETest/AuthorizationCallbackE2ETests.swift` — E2E 测试
- **修改** `Sources/E2ETest/main.swift` — 添加新 Section
- **不修改** `Core/ToolExecutor.swift`、`Types/ToolTypes.swift`、`Types/AgentTypes.swift`、`Hooks/` 目录下任何文件
- 完全对齐架构文档的目录结构和模块边界（Types/ 是叶节点，Core/ 依赖 Types/）

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.1)

### Debug Log References

### Completion Notes List

- Implemented PermissionPolicy protocol with async evaluate() returning CanUseToolResult?
- Implemented 4 policy types: ToolNameAllowlistPolicy, ToolNameDenylistPolicy, ReadOnlyPolicy, CompositePolicy
- Added CanUseToolResult factory methods: .allow(), .deny(_:), .allowWithInput(_:)
- Added canUseTool(policy:) global bridge function converting PermissionPolicy to CanUseToolFn
- Added Agent.setPermissionMode(_:) which also clears canUseTool callback (per AC6)
- Added Agent.setCanUseTool(_:) for dynamic callback updates (per AC7)
- Changed Agent.options from `let` to `var` to support dynamic mutation
- All 22 unit tests pass (PermissionPolicyTests)
- Build succeeds with no errors
- Full test suite: 1561 tests pass, 4 skipped, 0 failures

### File List

- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` — Modified: Added PermissionPolicy protocol, 4 policy structs, CanUseToolResult extension with factory methods, canUseTool(policy:) bridge function
- `Sources/OpenAgentSDK/Core/Agent.swift` — Modified: Changed `options` from `let` to `var`, added setPermissionMode(_:) and setCanUseTool(_:) public methods
- `Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift` — Created by ATDD phase (22 unit tests, all passing)
- `Sources/E2ETest/AuthorizationCallbackE2ETests.swift` — Created by ATDD phase (3 E2E tests)
- `Sources/E2ETest/main.swift` — Modified by ATDD phase (added Section 42)

### Change Log

- 2026-04-09: Completed story 8-5 implementation — PermissionPolicy protocol, 4 policy types, factory methods, bridge function, Agent dynamic permission switching. All 22 unit tests pass, full suite 1561 tests pass.

### Review Findings

- [x] [Review][Patch] E2E Test 42c Phase 4 is dead code — setCanUseTool is called after prompt() completes, so the allowAllCallback is never actually exercised during tool execution. Fixed: added second prompt() call and allow callback verification. [Sources/E2ETest/AuthorizationCallbackE2ETests.swift:170-195]
- [x] [Review][Defer] Stream path ignores dynamic permission changes — stream() captures permissionMode and canUseTool at creation time. Calling setPermissionMode()/setCanUseTool() during an active stream has no effect. This is pre-existing behavior of the stream architecture (all options captured upfront), not introduced by this story. [Sources/OpenAgentSDK/Core/Agent.swift:506-507] — deferred, pre-existing
