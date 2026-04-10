# Story 10.3: 阻塞式 Prompt API 示例（PromptAPIExample）

Status: done

## Story

作为 Swift 开发者，
我希望看到一个使用 `agent.prompt()` 阻塞式 API 获取完整响应的示例，
以便我理解在不需要流式传输时如何用最简单的方式调用 Agent。

## Acceptance Criteria

1. **AC1: PromptAPIExample 可编译运行** — 给定 `Examples/PromptAPIExample/main.swift`，当开发者运行 `swift build`（编译）或 `swift run PromptAPIExample`，则代码编译无错误、无警告。示例使用 `agent.prompt()` 阻塞式 API 执行查询并返回完整 `QueryResult`。

2. **AC2: 展示 agent.prompt() 阻塞式调用** — 给定 PromptAPIExample 运行中，则示例通过 `await agent.prompt("...")` 执行查询，在单次调用中获取 Agent 执行工具后的最终结果（`QueryResult`）。不使用流式 API。

3. **AC3: 展示 QueryResult 完整字段** — 给定 PromptAPIExample 运行完成，则输出展示 `result.text`（响应文本）、`result.numTurns`（轮次数）、`result.usage`（token 用量：`inputTokens`/`outputTokens`）、`result.durationMs`（耗时）、`result.totalCostUsd`（成本）、`result.status`（状态）。

4. **AC4: 展示 Agent 工具执行后的最终结果** — 给定 PromptAPIExample 运行中，Agent 注册了核心工具（如 Read、Glob），则 Agent 可能自主调用工具完成任务，`result.text` 包含综合工具结果后的完整响应。

5. **AC5: Package.executableTarget 已配置** — 给定更新后的 Package.swift，当包含 `PromptAPIExample` executableTarget，则 `swift build` 编译通过。

6. **AC6: 使用实际公共 API** — 给定所有示例代码，则所有 API 调用与当前源码中的公共 API 签名完全匹配（`createAgent`、`AgentOptions`、`agent.prompt()`、`QueryResult` 属性）。无假设性 API、无过时签名。

7. **AC7: 清晰注释和不暴露密钥** — 给定 main.swift 文件，则文件顶部有功能说明注释，关键步骤有行内注释。API 密钥使用 `"sk-..."` 占位符或从环境变量读取（NFR6）。

## Tasks / Subtasks

- [x] Task 1: 更新 Package.swift 添加 PromptAPIExample target (AC: #5)
  - [x] 在 targets 数组中添加 `.executableTarget(name: "PromptAPIExample", dependencies: ["OpenAgentSDK"], path: "Examples/PromptAPIExample")`

- [x] Task 2: 创建 Examples/PromptAPIExample/main.swift (AC: #1, #2, #3, #4, #6, #7)
  - [x] 创建目录 `Examples/PromptAPIExample/`
  - [x] 文件顶部注释：功能说明、运行方式、前提条件
  - [x] 导入 Foundation 和 OpenAgentSDK
  - [x] 从环境变量读取 API key（`ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."`）
  - [x] 使用 `createAgent(options:)` 创建 Agent，配置 AgentOptions：
    - apiKey、model（"claude-sonnet-4-6"）
    - systemPrompt：简洁的系统提示
    - maxTurns: 10
    - permissionMode: `.bypassPermissions`
    - tools: `getAllBaseTools(tier: .core)` — 注册核心工具以展示 Agent 工具执行后返回完整结果
  - [x] 使用 `await agent.prompt()` 发送查询
  - [x] 处理 QueryResult，输出所有字段：
    - `result.text` — 完整响应文本
    - `result.status` — 查询状态（QueryStatus 枚举）
    - `result.numTurns` — 轮次
    - `result.durationMs` — 耗时（ms 和秒）
    - `result.usage.inputTokens` / `result.usage.outputTokens` — token 用量
    - `result.totalCostUsd` — 估算成本
  - [x] 不使用 `try!` 或 `!` 强制解包

- [x] Task 3: 验证编译通过 (AC: #1, #5, #6)
  - [x] 运行 `swift build` 确认 PromptAPIExample 编译通过
  - [x] 验证所有 API 调用与实际公共 API 签名一致

- [x] Task 4: 运行完整测试套件确认无回归 (AC: #6)
  - [x] 运行 `swift test` 确认所有现有测试通过

## Dev Notes

### 本 Story 的定位

- Epic 10（扩展代码示例集）的第三个 Story
- **核心目标：** 创建 PromptAPIExample 示例，展示 `agent.prompt()` 阻塞式 API 的完整用法，重点展示在 Agent 执行工具后如何用单次调用获取最终结果（FR3、FR50 补充）
- **前置依赖：** Epic 1-9 全部完成，尤其 Story 9-3（已有 5 个基础示例）和 Story 10-1/10-2（已建立扩展示例模式）
- **与已有示例的区别：**
  - BasicAgent（Epic 9）：简单的阻塞式调用，无工具注册，展示最基本的用法
  - CustomSystemPromptExample（Story 10-2）：阻塞式 + 自定义系统提示 + 无工具，展示角色定制
  - **PromptAPIExample（本 Story）：阻塞式 + 核心工具注册，展示 Agent 在执行工具后返回的完整结果** — 突出"一键获取最终结果"的简洁性

### 关键公共 API 签名（必须与源码一致）

以下是从实际源码中验证的 API 签名（与 Story 10-2 Dev Notes 一致）：

**创建 Agent 并注册核心工具：**
```swift
import Foundation
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-...",
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant.",
    maxTurns: 10,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core)  // 注册 10 个核心工具
))
```

**阻塞式查询 + 完整结果处理：**
```swift
let result = await agent.prompt("Analyze the project structure...")

print("Response: \(result.text)")
print("Status: \(result.status)")           // QueryStatus 枚举: .success, .errorMaxTurns 等
print("Turns: \(result.numTurns)")
print("Duration: \(result.durationMs)ms")
print("Input tokens: \(result.usage.inputTokens)")
print("Output tokens: \(result.usage.outputTokens)")
print("Cost: $\(String(format: "%.6f", result.totalCostUsd))")
```

**QueryResult 属性（来自 AgentTypes.swift 源码）：**
- `text: String` — 助手响应文本（包含工具执行后的综合结果）
- `usage: TokenUsage` — 含 `inputTokens: Int`、`outputTokens: Int`
- `numTurns: Int` — Agent 循环轮次（如果 Agent 调用了工具，轮次 > 1）
- `durationMs: Int` — 毫秒级耗时
- `messages: [SDKMessage]` — 消息集合
- `status: QueryStatus` — `.success`、`.errorMaxTurns`、`.errorDuringExecution`、`.errorMaxBudgetUsd`
- `totalCostUsd: Double` — 美元成本

**TokenUsage 属性（来自 TokenUsage.swift 源码）：**
- `inputTokens: Int` — 输入 token
- `outputTokens: Int` — 输出 token
- `totalTokens: Int` — 计算属性，inputTokens + outputTokens

**AgentOptions 参数顺序（来自 AgentTypes.swift init 签名）：**
`apiKey, model, baseURL, provider, systemPrompt, maxTurns, maxTokens, maxBudgetUsd, thinking, permissionMode, canUseTool, cwd, tools, mcpServers, retryConfig, agentName, mailboxStore, teamStore, taskStore, worktreeStore, planStore, cronStore, todoStore, sessionStore, sessionId, hookRegistry`

**getAllBaseTools 函数：**
```swift
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol]
```

### 前序 Story 的经验教训（必须遵循）

来自 Story 10-1、10-2 和 Story 9-3 的 Dev Notes：

1. **API 密钥不暴露** — 使用 `"sk-..."` 占位符或 `ProcessInfo.processInfo.environment` 读取（NFR6）
2. **代码示例必须与实际 API 一致** — 严格对照源码验证每个 API 调用
3. **不使用 Apple 专属框架** — Foundation 在 macOS 和 Linux 均可用
4. **`import Foundation`** — 需要 ProcessInfo 时必须导入 Foundation
5. **`agent.prompt()` 返回 `QueryResult`** — 使用 `await` 异步获取，所有属性直接访问（`usage` 非 Optional）
6. **AgentOptions 参数顺序必须精确匹配** — 参照 AgentTypes.swift 中的 init 签名
7. **`permissionMode: .bypassPermissions`** — 示例中避免权限提示干扰
8. **`getAllBaseTools(tier: .core)`** — 注册全部 10 个核心工具（Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch）

### 反模式警告

- **不要**使用假设性 API — 必须与实际源码公共 API 完全一致
- **不要**暴露真实 API 密钥 — 使用 `"sk-..."` 占位符
- **不要**使用 `try!` 或 `!` 强制解包 — 使用 `guard let`、`if let`
- **不要**修改任何现有源代码 — 本 story 只添加示例文件和更新 Package.swift
- **不要**创建独立的 Package.swift — 在顶层 Package.swift 中添加 executableTarget
- **不要**使用流式 API — 本示例专门展示阻塞式 `agent.prompt()` 的简洁性
- **不要**不注册工具 — 本示例与 BasicAgent 的区别在于注册了工具，展示 Agent 自主执行工具后的完整结果
- **不要**在示例中实现复杂业务逻辑 — 保持简洁、聚焦阻塞式 API 的"一键获取完整结果"

### 模块边界

**本 story 涉及文件：**
- `Package.swift` — 修改：添加 1 个 executableTarget（PromptAPIExample）
- `Examples/PromptAPIExample/main.swift` — 新建：阻塞式 prompt API + 核心工具 + 完整结果展示

**不涉及任何现有源代码文件变更。**

```
项目根目录/
├── Package.swift                                    # 修改：添加 PromptAPIExample executableTarget
├── Examples/
│   ├── BasicAgent/main.swift                        # 不修改
│   ├── StreamingAgent/main.swift                    # 不修改
│   ├── CustomTools/main.swift                       # 不修改
│   ├── MCPIntegration/main.swift                    # 不修改
│   ├── SessionsAndHooks/main.swift                  # 不修改
│   ├── MultiToolExample/main.swift                  # 不修改
│   ├── CustomSystemPromptExample/main.swift         # 不修改
│   └── PromptAPIExample/                            # 新建目录
│       └── main.swift                               # 新建：阻塞式 Prompt API 示例
└── _bmad-output/
    └── implementation-artifacts/
        └── 10-3-prompt-api-example.md                # 本文件
```

### 测试策略

本 story 不需要单元测试。验证方式：
1. `swift build` 确认 PromptAPIExample 目标编译通过
2. 确认所有 API 调用与当前公共 API 签名匹配
3. 现有测试套件全部通过（无回归）
4. 如果环境允许（有 API key），可手动运行示例验证功能

### Project Structure Notes

- 在顶层 Package.swift 中添加 PromptAPIExample executableTarget（与现有 7 个示例一致）
- 新建 `Examples/PromptAPIExample/main.swift`
- 不涉及任何现有源代码文件变更
- 完全对齐架构文档的 `Examples/` 目录结构扩展

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.3 阻塞式 Prompt API 示例]
- [Source: _bmad-output/planning-artifacts/prd.md#FR3] — 包含最终结果的阻塞式响应
- [Source: _bmad-output/planning-artifacts/prd.md#FR50] — SDK 为所有主要功能领域提供可运行的代码示例
- [Source: _bmad-output/planning-artifacts/architecture.md#Examples 目录结构] — 架构文档定义的示例结构
- [Source: _bmad-output/project-context.md#Technology Stack & Versions]
- [Source: _bmad-output/implementation-artifacts/10-2-custom-system-prompt-example.md] — 前序 Story 的经验教训和 API 签名
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent、createAgent、prompt 实际 API
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions、QueryResult、QueryStatus 实际签名
- [Source: Sources/OpenAgentSDK/Types/TokenUsage.swift] — TokenUsage 属性（inputTokens、outputTokens、totalTokens）
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — getAllBaseTools(tier:) 函数
- [Source: Examples/BasicAgent/main.swift] — 阻塞式 prompt API 使用模式参考（已验证一致）

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.1)

### Debug Log References

- swift build --target PromptAPIExample: Build complete, 0 errors, 0 warnings
- swift test --filter PromptAPIExampleComplianceTests: 29/29 passed, 0 failures
- swift test (full suite): 1912 tests, 0 failures, 4 skipped (pre-existing)

### Completion Notes List

- Task 1: Added PromptAPIExample executableTarget to Package.swift (after CustomSystemPromptExample)
- Task 2: Created Examples/PromptAPIExample/main.swift with blocking prompt API + core tools + full QueryResult display
- Task 3: swift build --target PromptAPIExample compiled successfully with 0 errors
- Task 4: Full test suite (1912 tests) passes with 0 failures, 4 skipped (pre-existing)
- All 29 ATDD compliance tests pass (all 7 ACs verified)
- No existing source code files were modified (only Package.swift target addition and new example file)

### File List

- Package.swift (modified: added PromptAPIExample executableTarget)
- Examples/PromptAPIExample/main.swift (new: blocking prompt API example with core tools)

## Change Log

- 2026-04-10: Story 10-3 implementation complete — added PromptAPIExample demonstrating blocking agent.prompt() API with getAllBaseTools(tier: .core) tool registration and complete QueryResult field display

### Review Findings

- [x] [Review][Patch] Add status check before displaying results [Examples/PromptAPIExample/main.swift:61-65] — applied
- [x] [Review][Defer] No safety warning about destructive tools with bypassPermissions — deferred, pre-existing pattern across all examples
