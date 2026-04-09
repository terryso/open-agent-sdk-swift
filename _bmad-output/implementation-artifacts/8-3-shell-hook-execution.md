# Story 8.3: Shell 钩子执行

Status: done

## Story

作为开发者，
我希望注册带正则匹配器的 Shell 命令钩子，
以便我可以运行外部脚本以响应 Agent 事件。

## Acceptance Criteria

1. **AC1: Shell 钩子执行引擎** — 给定 `ShellHookExecutor`，当 `HookDefinition` 包含 `command` 字段（非 nil）且 `handler` 为 nil 时，则通过 POSIX 进程生成执行 Shell 命令（FR29）。使用 `/bin/bash -c` 执行命令。

2. **AC2: JSON stdin/stdout 协议** — 给定正在执行的 Shell 钩子，当命令启动时，则 `HookInput` 作为 JSON 通过 stdin 传递，命令的 stdout 输出作为 JSON 解析为 `HookOutput`（FR30）。若 stdout 不是有效 JSON，将其视为 `HookOutput(message: stdout)`。

3. **AC3: 环境变量传递** — 给定正在执行的 Shell 钩子，当进程启动时，则继承当前进程环境变量，并额外设置 `HOOK_EVENT`、`HOOK_TOOL_NAME`、`HOOK_SESSION_ID`、`HOOK_CWD` 环境变量（匹配 TS SDK 模式）。

4. **AC4: Shell 钩子超时** — 给定带有超时设置（默认 30 秒）的 Shell 钩子，当命令执行超过超时时间，则进程被终止并返回空结果（不阻塞其他钩子）（FR31）。

5. **AC5: 非零退出码处理** — 给定正在执行的 Shell 钩子，当命令以非零退出码结束，则返回 nil（空结果），匹配 TS SDK 行为。

6. **AC6: 输入清理防命令注入** — 给定包含特殊字符的 Shell 钩子输入，当 JSON 数据通过 stdin 传递时，则输入不拼接在命令字符串中，而是通过管道传递，防止命令注入（NFR7）。

7. **AC7: HookRegistry.execute() 集成** — 给定 `HookRegistry.execute()` 方法，当遇到 `command` 字段非 nil 且 `handler` 为 nil 的 `HookDefinition` 时，则使用 `ShellHookExecutor` 执行 Shell 命令，而非跳过。

8. **AC8: Shell 钩子与函数钩子共存在同一事件** — 给定在同一事件上同时注册了函数钩子（handler）和 Shell 钩子（command）的 `HookDefinition`，当事件触发时，则两类钩子按注册顺序交错执行。

9. **AC9: 跨平台支持** — 给定 Shell 钩子执行，当在 macOS 和 Linux 上运行时，则使用 Foundation 的 `Process` 类执行命令，不使用 Apple 专属框架。

10. **AC10: 单元测试覆盖** — 给定 `Tests/OpenAgentSDKTests/Hooks/` 目录，则包含 `ShellHookExecutorTests.swift`，至少覆盖：Shell 命令执行并返回 JSON 输出、非 JSON 输出处理为 message、超时终止进程、非零退出码返回 nil、环境变量传递验证、空 stdout 返回 nil。

11. **AC11: E2E 测试覆盖** — 给定 `Sources/E2ETest/` 目录，则包含 `ShellHookExecutionE2ETests.swift`，至少覆盖：注册 Shell 钩子并触发事件验证输出、Shell 钩子与函数钩子按序执行。

12. **AC12: command 字段的 matcher 过滤** — 给定带有 `matcher` 正则表达式的 Shell 钩子定义，当事件触发且 `toolName` 不匹配正则时，则跳过该 Shell 钩子（与函数钩子 matcher 行为一致）。

## Tasks / Subtasks

- [x] Task 1: 创建 ShellHookExecutor (AC: #1, #2, #3, #4, #5, #6, #9)
  - [x] 创建 `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift`
  - [x] 实现 `struct ShellHookExecutor` (或 `enum ShellHookExecutor` 作为命名空间)
  - [x] 实现 `static func execute(command: String, input: HookInput, timeoutMs: Int) async -> HookOutput?`
  - [x] 使用 Foundation `Process` 执行 `/bin/bash -c`
  - [x] 通过 stdin 管道发送 JSON 编码的 HookInput
  - [x] 通过 stdout 管道读取输出
  - [x] 解析 JSON 输出为 HookOutput，非 JSON 降级为 message
  - [x] 设置环境变量 HOOK_EVENT、HOOK_TOOL_NAME、HOOK_SESSION_ID、HOOK_CWD
  - [x] 实现超时终止机制（与 BashTool 类似模式）

- [x] Task 2: 修改 HookRegistry.execute() 集成 Shell 执行 (AC: #7, #8, #12)
  - [x] 修改 `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` 的 `execute()` 方法
  - [x] 替换现有的 `// command execution deferred to Story 8-3` 注释
  - [x] 在 handler 为 nil 时检查 command 字段
  - [x] 若 command 非 nil，调用 `ShellHookExecutor.execute()`
  - [x] handler 和 command 互斥：handler 优先，command 为后备

- [x] Task 3: 单元测试 (AC: #10)
  - [x] 创建 `Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift`
  - [x] 测试 Shell 命令执行并返回 JSON HookOutput
  - [x] 测试非 JSON 输出降级为 HookOutput(message:)
  - [x] 测试超时终止进程并返回 nil
  - [x] 测试非零退出码返回 nil
  - [x] 测试环境变量传递
  - [x] 测试空 stdout 返回 nil
  - [x] 测试 matcher 过滤（通过 HookRegistry 集成）

- [x] Task 4: E2E 测试 (AC: #11)
  - [x] 创建 `Sources/E2ETest/ShellHookExecutionE2ETests.swift`
  - [x] E2E 测试：注册 Shell 钩子 → 触发事件 → 验证输出
  - [x] E2E 测试：Shell 钩子与函数钩子按序执行
  - [x] 更新 `Sources/E2ETest/main.swift` 添加新 Section

- [x] Task 5: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证所有现有测试仍通过
  - [x] 运行完整测试套件并报告总数

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 8（钩子系统与权限控制）的第三个 story
- **为 HookRegistry 的 execute() 方法添加 Shell 命令钩子执行能力**
- **关键目标：** 开发者可以注册 Shell 命令钩子（通过 `command` 字段），当事件触发时执行外部脚本（FR29、FR30、FR31）
- **前置依赖：** Story 8-1（HookRegistry 和类型系统）和 Story 8-2（函数钩子集成到 Agent 循环）

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `HookEvent` | `Types/HookTypes.swift` | 20 个 case 的枚举，已完成 |
| `HookInput` | `Types/HookTypes.swift` | 包含 event, toolName, toolInput, toolOutput 等，已完成 |
| `HookOutput` | `Types/HookTypes.swift` | 包含 message, permissionUpdate, block, notification，已完成 |
| `HookDefinition` | `Types/HookTypes.swift` | 包含 `command`, `handler`, `matcher`, `timeout` — **command 字段已存在** |
| `HookRegistry` | `Hooks/HookRegistry.swift` | Actor，已完成 register/execute/hasHooks/clear |
| `createHookRegistry()` | `Hooks/HookRegistry.swift` | 工厂函数，已完成 |

### TypeScript SDK 参考（关键）

TypeScript SDK 的 `executeShellHook` 函数（`hooks.ts` 第 200-250 行）：

```typescript
async function executeShellHook(
  command: string,
  input: HookInput,
  timeout: number,
): Promise<HookOutput | void> {
  return new Promise((resolve) => {
    const proc = spawn('bash', ['-c', command], {
      timeout,
      env: {
        ...process.env,
        HOOK_EVENT: input.event,
        HOOK_TOOL_NAME: input.toolName || '',
        HOOK_SESSION_ID: input.sessionId || '',
        HOOK_CWD: input.cwd || '',
      },
      stdio: ['pipe', 'pipe', 'pipe'],
    })

    // Send input as JSON on stdin
    proc.stdin?.write(JSON.stringify(input))
    proc.stdin?.end()

    const chunks: Buffer[] = []
    proc.stdout?.on('data', (d: Buffer) => chunks.push(d))

    proc.on('close', (code) => {
      if (code !== 0) {
        resolve(undefined)
        return
      }

      const stdout = Buffer.concat(chunks).toString('utf-8').trim()
      if (!stdout) {
        resolve(undefined)
        return
      }

      try {
        const output = JSON.parse(stdout) as HookOutput
        resolve(output)
      } catch {
        // Non-JSON output treated as message
        resolve({ message: stdout })
      }
    })

    proc.on('error', () => resolve(undefined))
  })
}
```

**TypeScript SDK HookRegistry.execute() 中的调用位置（hooks.ts 第 179-181 行）：**
```typescript
} else if (def.command) {
  output = await executeShellHook(def.command, input, def.timeout || 30000)
}
```

**关键行为（必须严格匹配）：**
1. 使用 `/bin/bash -c` 执行命令
2. 继承当前进程环境变量，额外设置 HOOK_* 变量
3. HookInput 作为 JSON 通过 stdin 管道传递（**不拼接在命令中** — 这是防命令注入的关键）
4. 从 stdout 读取输出，trim 后解析
5. 非 JSON 输出降级为 `{ message: stdout }`
6. 空输出返回 `undefined`（Swift 中返回 nil）
7. 非零退出码返回 `undefined`（Swift 中返回 nil）
8. 超时默认 30 秒

### 需要创建/修改的文件

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Hooks/ShellHookExecutor.swift` | **新建** | Shell 命令钩子执行器 |
| `Hooks/HookRegistry.swift` | **修改** | execute() 中添加 command 分支 |

新测试文件：
| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift` | **新建** | 单元测试 |
| `Sources/E2ETest/ShellHookExecutionE2ETests.swift` | **新建** | E2E 测试 |
| `Sources/E2ETest/main.swift` | **修改** | 添加新 Section |

### 不修改的文件

- `Types/HookTypes.swift` — 无需修改，所有类型已在 8-1 完成（包括 `command` 字段）
- `Core/Agent.swift` — 无需修改，钩子触发点已在 8-2 完成
- `Core/ToolExecutor.swift` — 无需修改，钩子集成已在 8-2 完成
- `Types/AgentTypes.swift` — 无需修改，hookRegistry 属性已在 8-2 完成
- `Types/ToolTypes.swift` — 无需修改，hookRegistry 属性已在 8-2 完成

### 关键实现细节

**1. ShellHookExecutor 设计**

```swift
import Foundation

/// Executes shell command hooks via POSIX Process.
///
/// Uses `/bin/bash -c` to execute commands, passing `HookInput` as JSON
/// through stdin and reading `HookOutput` JSON from stdout.
/// Matches the TypeScript SDK's `executeShellHook` behavior.
enum ShellHookExecutor {

    /// Execute a shell command hook.
    ///
    /// - Parameters:
    ///   - command: The shell command to execute.
    ///   - input: The hook input data to pass as JSON via stdin.
    ///   - timeoutMs: Timeout in milliseconds (default 30_000).
    /// - Returns: A `HookOutput` parsed from stdout JSON, or nil on failure/timeout.
    static func execute(
        command: String,
        input: HookInput,
        timeoutMs: Int = 30_000
    ) async -> HookOutput? {
        // 使用 withCheckedContinuation 桥接 Process 回调到 async/await
        // 参考 BashTool.swift 的实现模式
    }
}
```

**2. Process 执行模式（参考 BashTool.swift）**

BashTool.swift 使用 `Process` + `Pipe` + `withCheckedContinuation` 模式。ShellHookExecutor 应复用类似模式，但更简单（无需 stderr 分离，无需输出截断）：

```swift
await withCheckedContinuation { continuation in
    let process = Process()
    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = FileHandle.nullDevice

    // 设置环境变量
    var env = ProcessInfo.processInfo.environment
    env["HOOK_EVENT"] = input.event.rawValue
    env["HOOK_TOOL_NAME"] = input.toolName ?? ""
    env["HOOK_SESSION_ID"] = input.sessionId ?? ""
    env["HOOK_CWD"] = input.cwd ?? ""
    process.environment = env

    // 写入 JSON 到 stdin
    if let jsonData = try? JSONEncoder().encode(ShellHookInputWrapper(input)) {
        stdinPipe.fileHandleForWriting.write(jsonData)
    }
    try? stdinPipe.fileHandleForWriting.close()

    // 读取 stdout
    var stdoutData = Data()
    stdoutPipe.fileHandleForReading.readabilityHandler = { handler in
        stdoutData.append(handler.availableData)
    }

    // 超时
    DispatchQueue.global().asyncAfter(
        deadline: .now() + .milliseconds(timeoutMs)
    ) { [weak process] in
        if let process = process, process.isRunning {
            process.terminate()
        }
    }

    process.terminationHandler = { _ in
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())

        // 非零退出码 → nil
        guard process.terminationStatus == 0 else {
            continuation.resume(returning: nil)
            return
        }

        let stdoutString = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 空 stdout → nil
        guard !stdoutString.isEmpty else {
            continuation.resume(returning: nil)
            return
        }

        // 尝试 JSON 解析
        if let data = stdoutString.data(using: .utf8),
           let output = try? JSONDecoder().decode(HookOutput.self, from: data) {
            continuation.resume(returning: output)
        } else {
            // 非 JSON → message
            continuation.resume(returning: HookOutput(message: stdoutString))
        }
    }

    do {
        try process.run()
    } catch {
        continuation.resume(returning: nil)
    }
}
```

**重要：HookInput 的 JSON 编码问题**

`HookInput` 包含 `Any?` 类型字段（toolInput、toolOutput），不能直接使用 `JSONEncoder`。需要手动构建 JSON 字典：

```swift
// 手动构建 JSON（因为 HookInput 包含 Any? 字段）
var inputDict: [String: Any] = [
    "event": input.event.rawValue
]
if let toolName = input.toolName { inputDict["toolName"] = toolName }
if let sessionId = input.sessionId { inputDict["sessionId"] = sessionId }
if let cwd = input.cwd { inputDict["cwd"] = cwd }
if let toolUseId = input.toolUseId { inputDict["toolUseId"] = toolUseId }
if let error = input.error { inputDict["error"] = error }
// toolInput 和 toolOutput 保留原值（如果有）
if let toolInput = input.toolInput { inputDict["toolInput"] = toolInput }
if let toolOutput = input.toolOutput { inputDict["toolOutput"] = toolOutput }

guard let jsonData = try? JSONSerialization.data(withJSONObject: inputDict) else {
    return nil
}
```

**3. HookRegistry.execute() 修改**

当前代码（HookRegistry.swift 第 100-101 行）：
```swift
// Execute handler if present (command execution deferred to Story 8-3)
guard let handler = def.handler else { continue }
```

修改为：
```swift
// Execute handler if present, otherwise try shell command
if let handler = def.handler {
    // 现有的 handler 执行逻辑（保持不变）
    do {
        let timeoutMs = def.timeout ?? 30_000
        let timeoutNanos = UInt64(clamping: Int64(timeoutMs) * 1_000_000)
        let output = try await withThrowingTaskGroup(of: HookOutput?.self) { group in
            group.addTask {
                await handler(input)
            }
            group.addTask {
                try await _Concurrency.Task.sleep(nanoseconds: timeoutNanos)
                throw HookExecutionError.timeout
            }

            guard let first = try await group.next() else {
                group.cancelAll()
                return nil as HookOutput?
            }
            group.cancelAll()
            return first
        }
        if let output { results.append(output) }
    } catch {
        // Hook failed — continue
    }
} else if let command = def.command {
    // Shell command hook (Story 8-3)
    let timeoutMs = def.timeout ?? 30_000
    if let output = await ShellHookExecutor.execute(
        command: command,
        input: input,
        timeoutMs: timeoutMs
    ) {
        results.append(output)
    }
}
```

**4. 超时处理注意事项**

- 默认超时 30 秒（`def.timeout ?? 30_000`）— 与函数钩子一致
- 使用 `DispatchQueue.global().asyncAfter` 实现超时（与 BashTool 相同模式）
- 超时后调用 `process.terminate()` 终止进程
- 超时不影响其他钩子执行

**5. 防命令注入（NFR7）**

关键安全措施：用户数据（HookInput）通过 stdin 管道传递，**绝不拼接在命令字符串中**。这与 TS SDK 的实现一致：
- TS SDK: `proc.stdin?.write(JSON.stringify(input))` — stdin 管道
- Swift: `stdinPipe.fileHandleForWriting.write(jsonData)` — stdin 管道

`command` 字段本身来自开发者的配置，是可信的。`input` 数据（可能包含不可信内容）通过管道隔离。

### 前序 Story 的经验教训（必须遵循）

来自 Story 8-1 和 8-2 的 Dev Notes 和 Completion Notes：

1. **Actor 方法外部调用需要 `await`** — HookRegistry 的所有公共方法都是 actor 隔离的
2. **`_Concurrency.Task.sleep` 而非 `Task.sleep`** — 项目有自定义 Task 类型冲突
3. **`@unchecked Sendable` 模式** — HookInput、HookOutput、HookDefinition 都使用此模式
4. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
5. **E2E 测试** — 使用真实环境（不使用 mock）
6. **不使用 Apple 专属框架** — Foundation 和 Regex 在 macOS 和 Linux 均可用
7. **force-unwrap 禁止** — 使用 guard let / if let
8. **错误不传播** — 钩子失败静默处理，不影响智能循环（NFR17 精神）
9. **使用 actor 追踪器** — 测试中使用 actor 来追踪闭包调用
10. **整数溢出** — 使用 `UInt64(clamping:)` 防止溢出
11. **HookEvent 有 20 个 case**（不是 21）
12. **Process 回调使用 `@unchecked Sendable`** — 参考 BashTool.swift 的 ProcessOutputAccumulator
13. **ShellHookExecutor 在 actor 内部调用** — execute() 是 actor 方法，内部调用 ShellHookExecutor.execute() 需要 await
14. **HookOutput 解码** — HookOutput 使用 @unchecked Sendable，所有字段是可选的，JSONDecoder 可直接解码
15. **createHookRegistry 是 async** — 因为 actor 隔离

### 反模式警告

- **不要**将 input 数据拼接到命令字符串中 — 必须通过 stdin 管道传递（NFR7）
- **不要**使用 `posix_spawn` — 使用 Foundation `Process`（与 BashTool 一致，跨平台）
- **不要**修改 `Types/HookTypes.swift` — 所有类型定义已完成
- **不要**修改 `Core/Agent.swift` 或 `Core/ToolExecutor.swift` — 钩子集成已在 8-2 完成
- **不要**在 Hooks/ 中导入 Core/ — 违反模块边界
- **不要**在 execute 中使用 force-unwrap (`!`)
- **不要**让 Shell 钩子错误传播到智能循环 — 匹配 TS SDK 的静默处理模式
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台
- **不要**在 Shell 钩子执行中使用 `Task.sleep` — 使用 `_Concurrency.Task.sleep`
- **不要**将 ShellHookExecutor 实现为 actor — 它是无状态的，使用 enum 或 struct 作为命名空间
- **不要**忽略 stderr — 与 TS SDK 不同，Swift 版本将 stderr 丢弃到 `/dev/null`（Shell 钩子仅需 stdout）
- **不要**使用 `JSONEncoder` 编码 HookInput — 包含 `Any?` 字段，必须使用 `JSONSerialization`
- **不要**在超时后忘记清理 Pipe 的 readabilityHandler — 参考 BashTool 的清理模式

### 模块边界

```
Hooks/ShellHookExecutor.swift    → 新建：Shell 命令钩子执行器
Hooks/HookRegistry.swift          → 修改：execute() 添加 command 分支
```

新测试文件：
```
Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift   (新建)
Sources/E2ETest/ShellHookExecutionE2ETests.swift               (新建)
Sources/E2ETest/main.swift                                      (修改：添加新 Section)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 8-1 (已完成) | 依赖 — 使用其 HookRegistry、HookDefinition（command 字段）、HookInput/Output |
| 8-2 (已完成) | 依赖 — HookRegistry.execute() 的 handler 执行逻辑已就位，本 story 在其中添加 command 分支 |
| 8-4 (后续) | 并行 — 权限模式，使用 PreToolUse 钩子基础设施 |
| 8-5 (后续) | 并行 — 自定义授权回调 |
| 3-6 (已完成) | 模式参考 — BashTool.swift 的 Process 执行模式 |

### HookRegistry.swift 修改的精确位置

**execute() 方法（约第 100-101 行）：**

当前代码：
```swift
// Execute handler if present (command execution deferred to Story 8-3)
guard let handler = def.handler else { continue }
```

替换为 handler/command 双分支逻辑（见上方"关键实现细节"第 3 点）。

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift）：**

每个测试使用真实的 Shell 命令（如 `echo '{"message":"test"}'`）：
- `testExecute_validJsonOutput_returnsHookOutput` — echo JSON 验证解析
- `testExecute_nonJsonOutput_treatedAsMessage` — echo 纯文本验证降级
- `testExecute_emptyOutput_returnsNil` — 无输出验证返回 nil
- `testExecute_nonZeroExitCode_returnsNil` — `exit 1` 验证返回 nil
- `testExecute_timeout_terminatesProcess` — `sleep 60` 验证超时终止
- `testExecute_environmentVariables_set` — 通过 Shell 命令验证环境变量
- `testExecute_commandFailure_returnsNil` — 不存在的命令验证返回 nil

**单元测试 — HookRegistry 集成（Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift 或 HookRegistryTests.swift）：**
- `testExecute_commandHook_returnsOutput` — 通过 HookRegistry 注册 command 钩子并执行
- `testExecute_commandHookWithMatcher_filtersByToolName` — matcher 过滤验证
- `testExecute_mixedHandlerAndCommand_executesInOrder` — handler 和 command 混合执行顺序

**E2E 测试（Sources/E2ETest/ShellHookExecutionE2ETests.swift）：**
- 使用真实的 HookRegistry actor 和真实的 Shell 命令
- 不使用 mock（E2E 规则）
- 注册 Shell 钩子 → 触发事件 → 验证输出
- Shell 钩子与函数钩子按序执行验证

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.3 Shell 钩子执行]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD7 钩子系统 — Shell 钩子使用 Process]
- [Source: _bmad-output/planning-artifacts/prd.md#FR29 带正则匹配器的 Shell 命令钩子]
- [Source: _bmad-output/planning-artifacts/prd.md#FR30 Shell 钩子 JSON stdin/stdout 协议]
- [Source: _bmad-output/planning-artifacts/prd.md#FR31 可配置钩子超时]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR7 输入清理防命令注入]
- [Source: _bmad-output/implementation-artifacts/8-1-hook-event-types-registry.md] — Story 8-1 完成记录
- [Source: _bmad-output/implementation-artifacts/8-2-function-hook-registration-execution.md] — Story 8-2 完成记录
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/hooks.ts#executeShellHook] — TS SDK Shell 钩子执行函数
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/hooks.ts#179] — TS SDK handler/command 分支
- [Source: Sources/OpenAgentSDK/Hooks/HookRegistry.swift:100] — 当前 "command execution deferred" 注释
- [Source: Sources/OpenAgentSDK/Types/HookTypes.swift:106] — HookDefinition 包含 command 字段
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] — Process 执行模式参考

### Project Structure Notes

- **新建** `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift` — Shell 命令钩子执行器
- **修改** `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` — execute() 添加 command 分支
- **新建** `Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift` — 单元测试
- **新建** `Sources/E2ETest/ShellHookExecutionE2ETests.swift` — E2E 测试
- **修改** `Sources/E2ETest/main.swift` — 添加新 Section
- **不修改** `Types/HookTypes.swift`、`Core/Agent.swift`、`Core/ToolExecutor.swift`
- 完全对齐架构文档的目录结构和模块边界（Hooks/ 依赖 Types/，不导入 Core/ 或 Tools/）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented ShellHookExecutor as `enum` namespace using Foundation `Process` + `/bin/bash -c` pattern (matching BashTool.swift approach)
- Used `JSONSerialization` instead of `JSONEncoder` for HookInput encoding (HookInput contains `Any?` fields)
- Implemented manual JSON parsing for HookOutput (HookOutput doesn't conform to Decodable; story requires no modifications to HookTypes.swift)
- Added ShellHookOutputAccumulator with `@unchecked Sendable` pattern for thread-safe stdout capture
- Handler/command dual-branch in HookRegistry.execute(): handler takes priority, command is fallback
- All 20 unit tests pass, all 3 E2E tests pass, full suite: 1524 tests pass with 0 failures, 4 skipped
- Timeout uses DispatchQueue.global().asyncAfter matching BashTool pattern
- Input sanitization via stdin pipe (never command concatenation) -- NFR7 satisfied

### File List

**New files:**
- Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift

**Modified files:**
- Sources/OpenAgentSDK/Hooks/HookRegistry.swift

**Test files (created by ATDD phase, verified in this phase):**
- Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift (20 unit tests, all pass)
- Sources/E2ETest/ShellHookExecutionE2ETests.swift (3 E2E tests, all pass)
- Sources/E2ETest/main.swift (already updated with Section 40)

**No modifications to:**
- Types/HookTypes.swift
- Core/Agent.swift
- Core/ToolExecutor.swift

### Review Findings

- [x] [Review][Patch] Missing guard against zero/negative timeoutMs [ShellHookExecutor.swift:48] — Fixed: added `let timeoutMs = max(1, timeoutMs)` at start of execute() to match BashTool.swift pattern
