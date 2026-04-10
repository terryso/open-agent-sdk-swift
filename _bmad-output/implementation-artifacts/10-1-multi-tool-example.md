# Story 10.1: 多工具编排示例（MultiToolExample）

Status: done

## Story

作为 Swift 开发者，
我希望看到一个 Agent 自主组合多个工具（Glob、Bash、Read）完成复杂任务的示例，
以便我理解 Agent 如何规划和执行多步骤工作流。

## Acceptance Criteria

1. **AC1: MultiToolExample 可编译运行** — 给定 `Examples/MultiToolExample/main.swift`，当开发者运行 `swift build`（编译）或 `swift run MultiToolExample`，则代码编译无错误、无警告。示例使用 `getAllBaseTools(tier: .core)` 注册核心工具，Agent 自主编排使用 Glob 查找文件、Bash 执行命令、Read 读取内容完成多步骤任务。

2. **AC2: 使用流式 API 展示实时事件** — 给定 MultiToolExample 运行中，则示例使用 `agent.stream()` 流式查询，通过 `for await message in agent.stream(...)` 消费事件。对 `.toolUse` 事件实时输出工具名和输入参数，对 `.toolResult` 事件输出工具执行结果摘要，对 `.partialMessage` 事件输出增量文本。

3. **AC3: 展示多工具自主编排** — 给定 MultiToolExample 运行中，Agent 的系统提示引导其执行多步骤任务（如"分析当前目录结构，找出所有 Swift 文件并统计代码行数"），则 Agent 自主决定使用 Glob/Bash/Read 等工具完成。输出实时显示每个工具调用和结果。

4. **AC4: 最终输出包含任务摘要和统计** — 给定 MultiToolExample 运行完成，则最终输出包含任务结果摘要和 token 使用统计（轮次、耗时、成本、input/output tokens），使用 `.result` 事件中的数据。

5. **AC5: Package.exeutableTarget 已配置** — 给定更新后的 Package.swift，当包含 `MultiToolExample` executableTarget，则 `swift build` 编译通过。

6. **AC6: 使用实际公共 API** — 给定所有示例代码，则所有 API 调用与当前源码中的公共 API 签名完全匹配（createAgent、AgentOptions、agent.stream()、SDKMessage 模式匹配、getAllBaseTools）。无假设性 API、无过时签名。

7. **AC7: 清晰注释和不暴露密钥** — 给定 main.swift 文件，则文件顶部有功能说明注释，关键步骤有行内注释。API 密钥使用 `"sk-..."` 占位符或从环境变量读取（NFR6）。

## Tasks / Subtasks

- [x] Task 1: 更新 Package.swift 添加 MultiToolExample target (AC: #5)
  - [x] 在 targets 数组中添加 `.executableTarget(name: "MultiToolExample", dependencies: ["OpenAgentSDK"], path: "Examples/MultiToolExample")`

- [x] Task 2: 创建 Examples/MultiToolExample/main.swift (AC: #1, #2, #3, #4, #6, #7)
  - [x] 创建目录 `Examples/MultiToolExample/`
  - [x] 文件顶部注释：功能说明、运行方式、前提条件
  - [x] 导入 Foundation 和 OpenAgentSDK
  - [x] 从环境变量读取 API key（`ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."`）
  - [x] 使用 `createAgent(options:)` 创建 Agent，配置 AgentOptions：
    - apiKey、model（"claude-sonnet-4-6"）、systemPrompt（引导多工具编排的系统提示）
    - tools: `getAllBaseTools(tier: .core)` — 注册全部核心工具
    - permissionMode: `.bypassPermissions`
  - [x] 使用 `agent.stream()` 发送一个需要多步骤编排的任务提示
  - [x] 使用 `for await message in agent.stream(...)` 消费事件
  - [x] 对 `SDKMessage` 各 case 进行模式匹配：
    - `.partialMessage`: 输出增量文本
    - `.toolUse`: 输出工具名和输入参数
    - `.toolResult`: 输出工具结果摘要（截断长内容）
    - `.result`: 输出完整统计（轮次、耗时、成本、tokens）
    - `.assistant`: 输出模型信息和停止原因
    - `.system`: 输出系统事件
  - [x] 不使用 `try!` 或 `!` 强制解包

- [x] Task 3: 验证编译通过 (AC: #1, #5, #6)
  - [x] 运行 `swift build` 确认 MultiToolExample 编译通过
  - [x] 验证所有 API 调用与实际公共 API 签名一致

- [x] Task 4: 运行完整测试套件确认无回归 (AC: #6)
  - [x] 运行 `swift test` 确认所有现有测试通过

## Dev Notes

### 本 Story 的定位

- Epic 10（扩展代码示例集）的第一个 Story
- **核心目标：** 创建 MultiToolExample 示例，展示 Agent 如何自主编排多个核心工具（Glob、Bash、Read）完成复杂任务（FR50 补充）
- **前置依赖：** Epic 1-9 全部完成，尤其 Story 9-3（已有 5 个基础示例）
- **与 Story 9-3 的关系：** Story 9-3 创建了 5 个基础示例（BasicAgent、StreamingAgent、CustomTools、MCPIntegration、SessionsAndHooks），本 story 是第一个扩展示例，聚焦多工具编排场景

### 关键公共 API 签名（必须与源码一致）

以下是从实际源码和前序 Story 9-3 中验证过的 API 签名：

**创建 Agent + 注册核心工具：**
```swift
import Foundation
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-...",
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant...",
    tools: getAllBaseTools(tier: .core),  // 注册全部 10 个核心工具
    permissionMode: .bypassPermissions
))
```

**流式查询 + 事件消费：**
```swift
for await message in agent.stream("Analyze this project...") {
    switch message {
    case .partialMessage(let data):
        print(data.text, terminator: "")
    case .assistant(let data):
        print("\n[Model: \(data.model), Stop: \(data.stopReason)]")
    case .toolUse(let data):
        print("[Tool: \(data.toolName), ID: \(data.toolUseId)]")
        print("  Input: \(data.input)")
    case .toolResult(let data):
        if data.isError {
            print("[Tool Error: \(data.content)]")
        } else {
            print("[Tool Result: \(data.content.prefix(100))...]")
        }
    case .result(let data):
        print("Done: \(data.subtype), turns: \(data.numTurns), cost: $\(data.totalCostUsd)")
        if let usage = data.usage {
            print("  Input tokens: \(usage.inputTokens)")
            print("  Output tokens: \(usage.outputTokens)")
        }
    case .system(let data):
        print("[System: \(data.message)]")
    }
}
```

**核心工具列表（getAllBaseTools(tier: .core) 返回 10 个）：**
- Read (`createReadTool()`), Write (`createWriteTool()`), Edit (`createEditTool()`)
- Glob (`createGlobTool()`), Grep (`createGrepTool()`)
- Bash (`createBashTool()`), AskUser (`createAskUserTool()`), ToolSearch (`createToolSearchTool()`)
- WebFetch (`createWebFetchTool()`), WebSearch (`createWebSearchTool()`)

### 前序 Story 的经验教训（必须遵循）

来自 Story 9-3 和所有前序 Story 的 Dev Notes：

1. **API 密钥不暴露** — 使用 `"sk-..."` 占位符或 `ProcessInfo.processInfo.environment` 读取（NFR6）
2. **代码示例必须与实际 API 一致** — 严格对照源码验证每个 API 调用
3. **不使用 Apple 专属框架** — Foundation 在 macOS 和 Linux 均可用
4. **`import Foundation`** — 需要 ProcessInfo 时必须导入 Foundation
5. **SDKMessage 模式匹配使用完全限定名** — 如 `SDKMessage.ResultData.Subtype.errorMaxBudgetUsd`
6. **`.result` 事件中 `data.usage` 是 Optional** — 需 `if let usage = data.usage` 安全解包
7. **`agent.stream()` 返回 `AsyncStream<SDKMessage>`** — 使用 `for await` 消费
8. **`getAllBaseTools(tier: .core)` 返回 `[ToolProtocol]`** — 直接传给 AgentOptions 的 tools 参数

### 反模式警告

- **不要**使用假设性 API — 必须与实际源码公共 API 完全一致
- **不要**暴露真实 API 密钥 — 使用 `"sk-..."` 占位符
- **不要**使用 `try!` 或 `!` 强制解包 — 使用 `guard let`、`if let`
- **不要**修改任何现有源代码 — 本 story 只添加示例文件和更新 Package.swift
- **不要**创建独立的 Package.swift — 在顶层 Package.swift 中添加 executableTarget
- **不要**在示例中实现复杂业务逻辑 — 保持简洁、聚焦多工具编排
- **不要**使用 `Task { }` 创建非结构化并发 — 使用简单的 `for await` 消费 AsyncStream

### 模块边界

**本 story 涉及文件：**
- `Package.swift` — 修改：添加 1 个 executableTarget（MultiToolExample）
- `Examples/MultiToolExample/main.swift` — 新建：多工具编排 + 流式 API + 实时事件展示

**不涉及任何现有源代码文件变更。**

```
项目根目录/
├── Package.swift                                    # 修改：添加 MultiToolExample executableTarget
├── Examples/
│   ├── BasicAgent/main.swift                        # 不修改
│   ├── StreamingAgent/main.swift                    # 不修改
│   ├── CustomTools/main.swift                       # 不修改
│   ├── MCPIntegration/main.swift                    # 不修改
│   ├── SessionsAndHooks/main.swift                  # 不修改
│   └── MultiToolExample/                            # 新建目录
│       └── main.swift                               # 新建：多工具编排示例
└── _bmad-output/
    └── implementation-artifacts/
        └── 10-1-multi-tool-example.md               # 本文件
```

### 测试策略

本 story 不需要单元测试。验证方式：
1. `swift build` 确认 MultiToolExample 目标编译通过
2. 确认所有 API 调用与当前公共 API 签名匹配
3. 现有测试套件全部通过（无回归）
4. 如果环境允许（有 API key），可手动运行示例验证功能

### Project Structure Notes

- 在顶层 Package.swift 中添加 MultiToolExample executableTarget（与现有 5 个示例一致）
- 新建 `Examples/MultiToolExample/main.swift`
- 不涉及任何现有源代码文件变更
- 完全对齐架构文档的 `Examples/` 目录结构扩展

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.1 多工具编排示例]
- [Source: _bmad-output/planning-artifacts/prd.md#FR50] — SDK 为所有主要功能领域提供可运行的代码示例
- [Source: _bmad-output/planning-artifacts/architecture.md#Examples 目录结构] — 架构文档定义的示例结构
- [Source: _bmad-output/project-context.md#Technology Stack & Versions]
- [Source: _bmad-output/implementation-artifacts/9-3-runnable-code-examples.md] — 前序 Story 的经验教训和 API 签名
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent、createAgent、stream 实际 API
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions 实际签名
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] — SDKMessage 枚举和所有关联类型
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — getAllBaseTools(tier:)、toApiTools 函数
- [Source: Examples/StreamingAgent/main.swift] — 流式 API 使用模式参考
- [Source: Examples/BasicAgent/main.swift] — Agent 创建模式参考

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Build succeeded: `swift build --target MultiToolExample` (2.52s)
- All 1855 tests pass with 0 failures (4 skipped)

### Completion Notes List

- Task 1: Added `MultiToolExample` executableTarget to Package.swift, following existing example pattern
- Task 2: Created `Examples/MultiToolExample/main.swift` with multi-tool orchestration example
  - Uses `getAllBaseTools(tier: .core)` to register all 10 core tools
  - Streams events via `for await message in agent.stream(prompt)` with full SDKMessage pattern matching
  - Displays real-time tool calls (toolUse), results (toolResult), partial text, and final statistics
  - Includes tool call counter to track how many tools the Agent invoked
  - Handles optional `usage` with `if let` safe unwrapping (no force unwrap)
  - API key read from environment variable with "sk-..." placeholder fallback
  - Detailed header comment explaining purpose, run instructions, and prerequisites
- Task 3: Verified `swift build --target MultiToolExample` compiles with zero errors/warnings. Fixed AgentOptions parameter ordering to match actual init signature.
- Task 4: Full test suite passes: all 1855 tests, 0 failures, 4 skipped (pre-existing)

### File List

- `Package.swift` — Modified: added MultiToolExample executableTarget
- `Examples/MultiToolExample/main.swift` — New: multi-tool orchestration streaming example
- `Tests/OpenAgentSDKTests/Documentation/MultiToolExampleComplianceTests.swift` — New: 24 ATDD compliance tests for all 7 ACs

### Change Log

- 2026-04-10: Story 10-1 implementation complete — MultiToolExample with multi-tool orchestration and streaming API (GLM-5.1)
- 2026-04-10: Code review passed (GLM-5.1) — 0 blocking, 0 HIGH/MEDIUM, 1 LOW patch (file list updated), 1 LOW deferred (compliance test beyond spec scope)

### Review Findings

- [x] [Review][Patch] File List missing compliance test file — updated to include MultiToolExampleComplianceTests.swift
- [x] [Review][Defer] Compliance test file beyond original spec scope — deferred, acceptable as ATDD best practice
