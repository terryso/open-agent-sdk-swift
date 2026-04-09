# Story 8.1: 钩子事件类型与注册表

Status: done

## Story

作为开发者，
我希望在 21 个 Agent 生命周期事件上注册钩子，
以便我可以观察和响应 Agent 行为。

## Acceptance Criteria

1. **AC1: HookRegistry Actor** — 给定 `HookRegistry` actor，当开发者创建实例时，则 actor 管理事件到处理程序的映射 `[HookEvent: [HookDefinition]]`，所有操作通过 Actor 隔离实现线程安全（FR28、FR48）。

2. **AC2: 注册单个钩子** — 给定 `HookRegistry` actor，当开发者在生命周期事件（如 `PostToolUse`）上注册函数钩子，则钩子被存储，在事件触发时将被调用（FR28）。所有 21 个事件可作为类型化枚举 case 使用，支持编译时穷举检查（`CaseIterable`）。

3. **AC3: PreToolUse 钩子执行** — 给定在 `PreToolUse` 上注册的钩子，当 Agent 即将执行工具时，则钩子被调用，传入工具名称和输入，且钩子的返回值可以允许、拒绝或修改执行（通过 `HookOutput.block` 和 `HookOutput.message`）。

4. **AC4: 批量注册从配置** — 给定 `HookConfig`（`[String: [HookDefinition]]`）配置字典，当开发者调用 `registerFromConfig(_:)` 时，则所有有效事件的钩子被注册，无效事件名被静默跳过。

5. **AC5: 按序执行多钩子** — 给定在同一事件上注册的多个钩子，当事件触发时，则所有钩子按注册顺序执行，且每个钩子的输出被收集到结果数组中。

6. **AC6: Matcher 过滤** — 给定带有 `matcher` 正则表达式的钩子定义，当事件触发且 `toolName` 不匹配正则时，则跳过该钩子不执行。`matcher` 为 `nil` 时匹配所有工具。

7. **AC7: 钩子超时** — 给定带有 `timeout`（默认 30 秒）的钩子定义，当钩子执行超过超时时间时，则超时错误被捕获，钩子返回空结果，不影响其他钩子执行（FR31）。

8. **AC8: hasHooks 查询** — 给定 `HookRegistry`，当开发者调用 `hasHooks(_:)` 检查某事件是否有注册钩子时，则返回 `Bool` 表示是否有钩子。

9. **AC9: clear 清除** — 给定已注册钩子的 `HookRegistry`，当开发者调用 `clear()` 时，则所有钩子被移除。

10. **AC10: 函数处理器支持** — 给定 `HookDefinition` 的 `handler` 闭包，当钩子执行时，则闭包接收 `HookInput` 并返回 `HookOutput?`。注意：本 story 仅实现 HookRegistry 的注册和函数处理器执行基础设施；Shell 命令执行（`command` 字段）推迟到 Story 8-3。

11. **AC11: 线程安全** — 给定并发的注册和执行操作，当多个 Agent/任务同时操作 `HookRegistry` 时，则所有操作正确完成，无数据损坏（actor 隔离保证）。

12. **AC12: 单元测试覆盖** — 给定 `Tests/OpenAgentSDKTests/Hooks/` 目录，则包含 `HookRegistryTests.swift`，至少覆盖：注册单个钩子、批量注册、注册到多个事件、PreToolUse 执行与 block 返回、多钩子按序执行、matcher 过滤、超时处理、hasHooks 查询、clear 清除、无效事件名跳过、并发安全。

13. **AC13: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/` 时，则包含 `HookRegistryE2ETests.swift`，至少覆盖：注册钩子并触发事件验证输出、多钩子按序执行验证。

## Tasks / Subtasks

- [x] Task 1: 创建 HookRegistry Actor (AC: #1)
  - [x] 创建 `Sources/OpenAgentSDK/Hooks/` 目录
  - [x] 创建 `Sources/OpenAgentSDK/Hooks/HookRegistry.swift`
  - [x] 实现 `public actor HookRegistry`，内部维护 `private var hooks: [HookEvent: [HookDefinition]] = [:]`

- [x] Task 2: 实现 register() 方法 (AC: #2)
  - [x] 添加 `public func register(_ event: HookEvent, definition: HookDefinition)`
  - [x] 追加到 `hooks[event]` 数组
  - [x] 验证所有 20 个 `HookEvent` case 可用于注册

- [x] Task 3: 实现 registerFromConfig() 方法 (AC: #4)
  - [x] 添加 `public func registerFromConfig(_ config: [String: [HookDefinition]])`
  - [x] 遍历 config 字典，将有效事件名的钩子注册
  - [x] 无效事件名静默跳过（不抛出错误）

- [x] Task 4: 实现 execute() 方法 (AC: #3, #5, #6, #7, #10)
  - [x] 添加 `public func execute(_ event: HookEvent, input: HookInput) async -> [HookOutput]`
  - [x] 获取 `hooks[event]` 定义数组
  - [x] 按 matcher 过滤：如果 `def.matcher` 非空且 `input.toolName` 不匹配，跳过
  - [x] 按序执行每个钩子的 handler 闭包（如果有）
  - [x] 超时处理：使用 `withThrowingTaskGroup` + `_Concurrency.Task.sleep` 机制（默认 30 秒）
  - [x] 收集非 nil 的 `HookOutput` 到结果数组
  - [x] 单个钩子失败不中断其他钩子执行

- [x] Task 5: 实现 hasHooks() 和 clear() (AC: #8, #9)
  - [x] 添加 `public func hasHooks(_ event: HookEvent) -> Bool`
  - [x] 添加 `public func clear()`

- [x] Task 6: 单元测试 (AC: #12)
  - [x] 创建 `Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift`
  - [x] 测试 `testRegister_singleHook_stored`
  - [x] 测试 `testRegister_multipleEvents_independent`
  - [x] 测试 `testRegisterFromConfig_validEventsRegistered`
  - [x] 测试 `testRegisterFromConfig_invalidEventsSkipped`
  - [x] 测试 `testExecute_singleHook_returnsOutput`
  - [x] 测试 `testExecute_multipleHooks_executedInOrder`
  - [x] 测试 `testExecute_preToolUse_canBlock`
  - [x] 测试 `testExecute_matcherFilters`
  - [x] 测试 `testExecute_timeout_returnsEmptyForTimedOutHook`
  - [x] 测试 `testExecute_handlerFailure_doesNotAffectOtherHooks`
  - [x] 测试 `testHasHooks_returnsCorrectly`
  - [x] 测试 `testClear_removesAllHooks`
  - [x] 测试 `testConcurrentRegisterExecute_threadSafe`

- [x] Task 7: E2E 测试 (AC: #13)
  - [x] 创建 `Sources/E2ETest/HookRegistryE2ETests.swift`
  - [x] E2E 测试：注册钩子 → 触发事件 → 验证输出
  - [x] E2E 测试：注册多个钩子 → 触发事件 → 验证按序执行

- [x] Task 8: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证所有现有测试仍通过
  - [x] 更新 `Sources/E2ETest/main.swift` 添加新 Section

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 8（钩子系统与权限控制）的第一个 story
- **HookRegistry Actor 创建与函数钩子执行基础设施** — 定义钩子注册表和执行引擎
- **关键目标：** 开发者可以在 21 个生命周期事件上注册函数钩子并接收执行结果（FR28）
- **范围限制：** Shell 命令执行（`HookDefinition.command` 字段）推迟到 Story 8-3，本 story 仅实现 handler 闭包执行

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `HookEvent` | `Types/HookTypes.swift` | 已定义：21 个 case 的枚举，`Sendable`, `Equatable`, `CaseIterable` |
| `HookInput` | `Types/HookTypes.swift` | 已定义：包含 event, toolName, toolInput, toolOutput, toolUseId, sessionId, cwd, error |
| `HookOutput` | `Types/HookTypes.swift` | 已定义：包含 message, permissionUpdate, block, notification |
| `HookDefinition` | `Types/HookTypes.swift` | 已定义：包含 command, matcher, timeout — **注意缺少 handler 闭包** |
| `PermissionUpdate` | `Types/HookTypes.swift` | 已定义 |
| `HookNotification` | `Types/HookTypes.swift` | 已定义 |

### 关键问题：HookDefinition 需要 handler 闭包

当前 `HookTypes.swift` 中的 `HookDefinition` 不包含 handler 闭包（与 TS SDK 不同）。TS SDK 的 `HookDefinition` 包含：
```typescript
handler?: (input: HookInput) => Promise<HookOutput | void>
```

**必须在 `HookDefinition` 中添加 handler 闭包字段：**
```swift
public struct HookDefinition: @unchecked Sendable {
    public let command: String?
    public let handler: (@Sendable (HookInput) async -> HookOutput?)?  // 新增
    public let matcher: String?
    public let timeout: Int?
}
```

注意使用 `@unchecked Sendable` 因为闭包无法静态验证 Sendable。这与 `HookInput` 和 `HookOutput` 已有的 `@unchecked Sendable` 模式一致。

### TypeScript SDK 参考

TypeScript SDK 的 `hooks.ts` 提供了直接参考：

```typescript
export class HookRegistry {
  private hooks: Map<HookEvent, HookDefinition[]> = new Map()

  registerFromConfig(config: HookConfig): void {
    for (const [event, definitions] of Object.entries(config)) {
      const hookEvent = event as HookEvent
      if (!HOOK_EVENTS.includes(hookEvent)) continue
      const existing = this.hooks.get(hookEvent) || []
      this.hooks.set(hookEvent, [...existing, ...definitions])
    }
  }

  register(event: HookEvent, definition: HookDefinition): void {
    const existing = this.hooks.get(event) || []
    existing.push(definition)
    this.hooks.set(event, existing)
  }

  async execute(event: HookEvent, input: HookInput): Promise<HookOutput[]> {
    const definitions = this.hooks.get(event) || []
    const results: HookOutput[] = []

    for (const def of definitions) {
      // Check matcher for tool-specific hooks
      if (def.matcher && input.toolName) {
        const regex = new RegExp(def.matcher)
        if (!regex.test(input.toolName)) continue
      }

      try {
        let output: HookOutput | void = undefined

        if (def.handler) {
          output = await Promise.race([
            def.handler(input),
            new Promise<void>((_, reject) =>
              setTimeout(() => reject(new Error('Hook timeout')), def.timeout || 30000),
            ),
          ])
        } else if (def.command) {
          // Shell command — 本 story 不实现，Story 8-3 实现
          output = await executeShellHook(def.command, input, def.timeout || 30000)
        }

        if (output) {
          results.push(output)
        }
      } catch (err: any) {
        console.error(`[Hook] ${event} hook failed: ${err.message}`)
      }
    }

    return results
  }

  hasHooks(event: HookEvent): boolean {
    return (this.hooks.get(event)?.length || 0) > 0
  }

  clear(): void {
    this.hooks.clear()
  }
}
```

**TypeScript SDK 钩子执行模式分析：**
1. `register()` — 追加到数组（不是替换）
2. `registerFromConfig()` — 批量注册，跳过无效事件名
3. `execute()` — 按序执行所有匹配的钩子，超时通过 `Promise.race` 实现
4. matcher 通过正则匹配 `toolName`
5. 单个钩子失败不中断执行
6. 钩子错误仅记录日志，不传播

**与 TypeScript 的差异（Swift 增强）：**
- TypeScript 用 class — Swift 用 actor（线程安全）
- TypeScript 用 Map — Swift 用 Dictionary（等效）
- TypeScript 的超时用 `Promise.race` + `setTimeout` — Swift 用 `withThrowingTaskGroup` 或自定义超时
- Swift 需要处理 `@unchecked Sendable` 因为闭包和 `Any?` 值
- Swift 的 `execute` 是 actor 方法，内部调用不需要额外 await

### 关键实现细节

**1. HookDefinition 添加 handler 字段**

```swift
public struct HookDefinition: @unchecked Sendable {
    public let command: String?
    public let handler: (@Sendable (HookInput) async -> HookOutput?)?  // 新增
    public let matcher: String?
    public let timeout: Int?

    public init(
        command: String? = nil,
        handler: (@Sendable (HookInput) async -> HookOutput?)? = nil,  // 新增
        matcher: String? = nil,
        timeout: Int? = nil
    ) {
        self.command = command
        self.handler = handler
        self.matcher = matcher
        self.timeout = timeout
    }
}
```

**2. HookRegistry Actor 实现**

```swift
public actor HookRegistry {
    private var hooks: [HookEvent: [HookDefinition]] = [:]

    public init() {}

    public func register(_ event: HookEvent, definition: HookDefinition) {
        hooks[event, default: []].append(definition)
    }

    public func registerFromConfig(_ config: [String: [HookDefinition]]) {
        for (eventString, definitions) in config {
            guard let event = HookEvent(rawValue: eventString) else { continue }
            hooks[event, default: []].append(contentsOf: definitions)
        }
    }

    public func execute(_ event: HookEvent, input: HookInput) async -> [HookOutput] {
        guard let definitions = hooks[event] else { return [] }
        var results: [HookOutput] = []

        for def in definitions {
            // Matcher filtering
            if let matcher = def.matcher, let toolName = input.toolName {
                do {
                    let regex = try Regex(matcher)
                    if !toolName.contains(regex) { continue }
                } catch {
                    continue  // Invalid regex, skip this hook
                }
            }

            // Execute handler (command execution deferred to Story 8-3)
            guard let handler = def.handler else { continue }

            do {
                let timeoutMs = def.timeout ?? 30_000
                let output = try await withThrowingTaskGroup(of: HookOutput?.self) { group in
                    group.addTask {
                        await handler(input)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                        throw HookExecutionError.timeout
                    }

                    guard let first = try await group.next() else {
                        group.cancelAll()
                        return nil
                    }
                    group.cancelAll()
                    return first
                }
                if let output { results.append(output) }
            } catch {
                // Hook failed — log and continue (matches TS SDK behavior)
                // In Swift, we don't have console.error, so we silently continue
            }
        }

        return results
    }

    public func hasHooks(_ event: HookEvent) -> Bool {
        (hooks[event]?.count ?? 0) > 0
    }

    public func clear() {
        hooks.removeAll()
    }
}
```

**注意：** 上面的超时实现使用 `withThrowingTaskGroup` 模式。也可以考虑更简单的 `Task.sleep` + cancellation 模式。关键是：
- 默认超时 30 秒（`def.timeout ?? 30_000`）
- 超时后取消执行任务
- 超时不影响其他钩子

**3. Matcher 正则匹配**

TS SDK 使用 `new RegExp(def.matcher).test(toolName)`。
Swift 使用 `Regex` 或 `NSRegularExpression`。

推荐使用 Swift 5.7+ 的 `Regex`：
```swift
let regex = try Regex(matcher)
if !toolName.contains(regex) { continue }
```

如果 `Regex` 初始化失败（无效正则），跳过该钩子。

**4. HookExecutionError（私有错误类型）**

在 HookRegistry.swift 内部定义：
```swift
private enum HookExecutionError: Error {
    case timeout
}
```

这是内部实现细节，不需要暴露到 `Types/ErrorTypes.swift`。

**5. registerFromConfig 的事件名映射**

TS SDK 的事件名使用 PascalCase（如 `"PreToolUse"`）。
Swift 的 `HookEvent` 使用 rawValue camelCase（如 `"preToolUse"`）。

因此 `registerFromConfig` 使用 `HookEvent(rawValue:)` 初始化，config 字典的 key 必须是 rawValue 值（camelCase）。这与 Swift 惯例一致。

如果需要支持 PascalCase 映射（匹配 TS SDK），可以添加转换逻辑。但 AC 没有要求，建议保持简单用 rawValue。

**6. HookEvent 的 21 个 case 验证**

当前 `HookTypes.swift` 已定义 21 个 case：
preToolUse, postToolUse, postToolUseFailure, sessionStart, sessionEnd, stop, subagentStart, subagentStop, userPromptSubmit, permissionRequest, permissionDenied, taskCreated, taskCompleted, configChange, cwdChanged, fileChanged, notification, preCompact, postCompact, teammateIdle

与 TS SDK 的 HOOK_EVENTS 列表完全一致。`CaseIterable` 协议已实现，支持编译时穷举检查。

### 前序 Story 的经验教训（必须遵循）

1. **Actor 方法外部调用需要 `await`** — HookRegistry 的所有公共方法都是 actor 隔离的
2. **测试使用临时目录/独立实例** — 每个测试创建独立的 HookRegistry 实例
3. **MARK 注释风格** — 遵循 `// MARK: - Public API` 等格式
4. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
5. **E2E 测试** — 使用真实环境（E2E 规则：不使用 mock）
6. **不使用 Apple 专属框架** — Foundation 和 Regex 在 macOS 和 Linux 均可用
7. **@unchecked Sendable 模式** — 与 HookInput、HookOutput 保持一致
8. **force-unwrap 禁止** — 使用 guard let / if let
9. **错误不传播** — 钩子失败静默处理，不影响智能循环（NFR17 精神）
10. **方法命名保持一致性** — register, execute, hasHooks, clear 与 TS SDK 对齐

### 反模式警告

- **不要**修改 `Core/Agent.swift` 或 `Core/QueryEngine.swift` — HookRegistry 是独立组件，集成到 QueryEngine 在后续 story 中完成
- **不要**修改 `Core/ToolExecutor.swift` — 钩子与工具执行的集成在后续 story 中完成
- **不要**实现 Shell 命令执行（`command` 字段）— 推迟到 Story 8-3
- **不要**在 `execute()` 中使用 force-unwrap (`!`)
- **不要**在 execute 中传播钩子错误 — 匹配 TS SDK 的静默处理模式
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台
- **不要**破坏 HookDefinition 现有的调用方 — handler 参数必须有默认值 nil
- **不要**将 HookRegistry 实现为 class — 必须是 actor（project-context 规则 1）
- **不要**在 Hooks/ 中导入 Core/ — 违反模块边界
- **不要**在 execute 中使用 try? 吞掉 matcher 的无效正则错误 — 应该明确跳过

### 模块边界

```
Types/HookTypes.swift              → 修改：HookDefinition 添加 handler 字段
Hooks/HookRegistry.swift           → 新建：HookRegistry actor
Types/ErrorTypes.swift              → 不修改：HookExecutionError 是内部私有类型
Core/Agent.swift                    → 不修改：集成在后续 story
Core/ToolExecutor.swift             → 不修改：集成在后续 story
```

新测试文件：
```
Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift   (新建)
Sources/E2ETest/HookRegistryE2ETests.swift               (新建)
Sources/E2ETest/main.swift                                (修改：添加新 Section)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 8-2 (后续) | 依赖本 story — 函数钩子注册与执行扩展 |
| 8-3 (后续) | 依赖本 story — Shell 命令钩子执行，使用 `command` 字段 |
| 8-4 (后续) | 并行 — 权限模式，不直接依赖 HookRegistry |
| 8-5 (后续) | 并行 — 自定义授权回调，可能与 PreToolUse 钩子协作 |
| 7-1 到 7-4 (已完成) | 模式参考 — Actor 存储的实现模式 |

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift）：**

每个测试创建独立的 HookRegistry 实例：
- 使用 handler 闭包模拟钩子行为（不需要 mock）
- 使用计数器或数组验证执行顺序
- 使用 expectation 或 async 测试超时行为

**E2E 测试（Sources/E2ETest/HookRegistryE2ETests.swift）：**

- 使用真实的 HookRegistry actor
- 注册真实闭包并验证执行
- 不使用 mock（E2E 规则）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.1 钩子事件类型与注册表]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD7 钩子系统]
- [Source: _bmad-output/planning-artifacts/prd.md#FR28 21 个生命周期事件钩子]
- [Source: _bmad-output/planning-artifacts/prd.md#FR31 可配置超时]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR7 输入清理]
- [Source: _bmad-output/project-context.md#规则 1 Actor 用于共享可变状态]
- [Source: _bmad-output/project-context.md#规则 7 模块边界 — Hooks/ 依赖 Types/]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/hooks.ts#HookRegistry] — TypeScript SDK HookRegistry 完整实现参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/hooks.ts#HOOK_EVENTS] — 21 个事件定义
- [Source: Sources/OpenAgentSDK/Types/HookTypes.swift] — 已有类型定义（HookEvent, HookInput, HookOutput, HookDefinition）
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — Deferred: HookNotification.level 字符串类型（已知限制，不在本 story 解决）

### Project Structure Notes

- **新建** `Sources/OpenAgentSDK/Hooks/` 目录
- **新建** `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` — HookRegistry actor
- **修改** `Sources/OpenAgentSDK/Types/HookTypes.swift` — HookDefinition 添加 handler 闭包字段
- **新建** `Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift` — 单元测试
- **新建** `Sources/E2ETest/HookRegistryE2ETests.swift` — E2E 测试
- **修改** `Sources/E2ETest/main.swift` — 添加新 Section
- **不修改** `Core/Agent.swift` 和 `Core/ToolExecutor.swift` — 集成在后续 story
- 完全对齐架构文档的目录结构和模块边界（Hooks/ 依赖 Types/，不导入 Core/ 或 Tools/）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Fixed `_Concurrency.Task.sleep` usage (project has custom `Task` type conflict)
- Fixed `nil` contextual type in `withThrowingTaskGroup` by using `nil as HookOutput?`
- Fixed Sendable closure capture issues in tests by using actor-based trackers
- Fixed handler failure test to use timeout instead of throw (handler is non-throwing)
- Fixed HookEvent count: 20 cases in TS SDK, not 21 as story stated

### Completion Notes List

- Implemented HookRegistry actor with all required methods: register, registerFromConfig, execute, hasHooks, clear
- Added handler closure field to HookDefinition with @unchecked Sendable pattern
- execute() uses withThrowingTaskGroup for timeout handling with default 30s
- Matcher filtering uses Swift Regex, invalid regex patterns skip the hook
- Handler failures (including timeout) are caught silently, not propagated
- 22 unit tests all passing covering all ACs
- 2 E2E tests all passing
- Full regression suite: 1488 tests, 0 failures, 4 skipped
- Story file had existing E2E test stubs and main.swift reference from ATDD phase

### Change Log

- 2026-04-09: Implemented HookRegistry actor, modified HookDefinition, created unit tests and E2E tests

### File List

- Sources/OpenAgentSDK/Types/HookTypes.swift (modified: added handler closure field to HookDefinition)
- Sources/OpenAgentSDK/Hooks/HookRegistry.swift (new: HookRegistry actor implementation)
- Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift (modified: fixed compilation issues, 22 tests)
- Sources/E2ETest/HookRegistryE2ETests.swift (modified: fixed Sendable capture issues, 2 tests)
- Sources/E2ETest/main.swift (unchanged: already referenced HookRegistryE2ETests from ATDD phase)

### Review Findings

- [x] [Review][Patch] Test name/comment mismatch in testHookEvent_has21Cases [Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift:39] — Fixed: renamed to testHookEvent_has20Cases and updated comment to match actual count.
- [x] [Review][Patch] Integer overflow in timeout nanosecond calculation [Sources/OpenAgentSDK/Hooks/HookRegistry.swift:110] — Fixed: changed `UInt64(timeoutMs) * 1_000_000` to `UInt64(clamping: Int64(timeoutMs) * 1_000_000)` to prevent overflow.
- [x] [Review][Patch] Missing handler assertion in HookTypesTests defaults test [Tests/OpenAgentSDKTests/Types/HookTypesTests.swift:155] — Fixed: added `XCTAssertNil(def.handler)`.
- [x] [Review][Defer] Silent error swallowing with no diagnostic capability [Sources/OpenAgentSDK/Hooks/HookRegistry.swift:122] — deferred, pre-existing design choice matching TS SDK behavior. No logging infrastructure exists in the project.
- [x] [Review][Defer] HookOutput lacks Equatable conformance [Sources/OpenAgentSDK/Types/HookTypes.swift:62] — deferred, pre-existing. Conformance would require PermissionUpdate and HookNotification fields to be Equatable (already are), but block is Bool. Low priority.
