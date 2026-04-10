# Story 10.2: 自定义系统提示示例（CustomSystemPromptExample）

Status: done

## Story

作为 Swift 开发者，
我希望看到使用自定义系统提示创建专业化 Agent 的示例，
以便我理解如何为特定角色定制 Agent 行为。

## Acceptance Criteria

1. **AC1: CustomSystemPromptExample 可编译运行** — 给定 `Examples/CustomSystemPromptExample/main.swift`，当开发者运行 `swift build`（编译）或 `swift run CustomSystemPromptExample`，则代码编译无错误、无警告。示例使用自定义 `systemPrompt`（如代码审查专家）创建 Agent，以专业化角色回应。

2. **AC2: 使用阻塞式 API（agent.prompt()）** — 给定 CustomSystemPromptExample 运行中，则示例使用 `agent.prompt()` 阻塞式查询，展示简单用法。通过 `await agent.prompt("...")` 获取完整 `QueryResult`，不使用流式 API。

3. **AC3: Agent 回复风格符合系统提示** — 给定 CustomSystemPromptExample 运行中，Agent 的 `systemPrompt` 明确指导回复风格和格式（如代码审查专家只回答代码相关问题，以结构化格式输出），则 Agent 回复体现系统提示中的角色设定。

4. **AC4: 展示 QueryResult 完整字段** — 给定 CustomSystemPromptExample 运行完成，则输出展示 `result.text`（响应文本）、`result.numTurns`（轮次数）、`result.usage`（token 用量：`inputTokens`/`outputTokens`）、`result.durationMs`（耗时）、`result.totalCostUsd`（成本）、`result.status`（状态）。

5. **AC5: Package.executableTarget 已配置** — 给定更新后的 Package.swift，当包含 `CustomSystemPromptExample` executableTarget，则 `swift build` 编译通过。

6. **AC6: 使用实际公共 API** — 给定所有示例代码，则所有 API 调用与当前源码中的公共 API 签名完全匹配（`createAgent`、`AgentOptions`、`agent.prompt()`、`QueryResult` 属性）。无假设性 API、无过时签名。

7. **AC7: 清晰注释和不暴露密钥** — 给定 main.swift 文件，则文件顶部有功能说明注释，关键步骤有行内注释。API 密钥使用 `"sk-..."` 占位符或从环境变量读取（NFR6）。

## Tasks / Subtasks

- [x] Task 1: 更新 Package.swift 添加 CustomSystemPromptExample target (AC: #5)
  - [x] 在 targets 数组中添加 `.executableTarget(name: "CustomSystemPromptExample", dependencies: ["OpenAgentSDK"], path: "Examples/CustomSystemPromptExample")`

- [x] Task 2: 创建 Examples/CustomSystemPromptExample/main.swift (AC: #1, #2, #3, #4, #6, #7)
  - [x] 创建目录 `Examples/CustomSystemPromptExample/`
  - [x] 文件顶部注释：功能说明、运行方式、前提条件
  - [x] 导入 Foundation 和 OpenAgentSDK
  - [x] 从环境变量读取 API key（`ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."`）
  - [x] 使用 `createAgent(options:)` 创建 Agent，配置 AgentOptions：
    - apiKey、model（"claude-sonnet-4-6"）
    - systemPrompt：专业化角色提示（如代码审查专家，明确指导回复风格和格式要求）
    - maxTurns: 5（不需要工具，简单对话即可）
    - permissionMode: `.bypassPermissions`
    - tools: nil（不注册任何工具，纯对话示例，突出系统提示效果）
  - [x] 使用 `await agent.prompt()` 发送一个与角色相关的提示
  - [x] 处理 QueryResult，输出所有字段：
    - `result.text` — 完整响应文本
    - `result.status` — 查询状态
    - `result.numTurns` — 轮次
    - `result.durationMs` — 耗时（ms 和秒）
    - `result.usage.inputTokens` / `result.usage.outputTokens` — token 用量
    - `result.totalCostUsd` — 估算成本
  - [x] 不使用 `try!` 或 `!` 强制解包

- [x] Task 3: 验证编译通过 (AC: #1, #5, #6)
  - [x] 运行 `swift build` 确认 CustomSystemPromptExample 编译通过
  - [x] 验证所有 API 调用与实际公共 API 签名一致

- [x] Task 4: 运行完整测试套件确认无回归 (AC: #6)
  - [x] 运行 `swift test` 确认所有现有测试通过

## Dev Notes

### 本 Story 的定位

- Epic 10（扩展代码示例集）的第二个 Story
- **核心目标：** 创建 CustomSystemPromptExample 示例，展示如何使用自定义 `systemPrompt` 创建专业化 Agent（FR1、FR50 补充）
- **前置依赖：** Epic 1-9 全部完成，尤其 Story 9-3（已有 5 个基础示例）和 Story 10-1（MultiToolExample，已建立扩展示例模式）
- **与 Story 10-1 的区别：** 10-1 展示多工具编排 + 流式 API；本 Story 展示系统提示定制 + 阻塞式 API。两者互补，覆盖不同 SDK 用法

### 关键公共 API 签名（必须与源码一致）

以下是从实际源码中验证的 API 签名（与 Story 10-1 Dev Notes 一致）：

**创建专业化 Agent（无工具，纯对话）：**
```swift
import Foundation
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-...",
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a senior code reviewer...",  // 自定义系统提示
    maxTurns: 5,
    permissionMode: .bypassPermissions
    // 注意：不传 tools 参数（默认为 nil），不注册任何工具
))
```

**阻塞式查询 + 完整结果处理：**
```swift
let result = await agent.prompt("Review this code snippet...")

print("Response: \(result.text)")
print("Status: \(result.status)")           // QueryStatus 枚举: .success, .errorMaxTurns 等
print("Turns: \(result.numTurns)")
print("Duration: \(result.durationMs)ms")
print("Input tokens: \(result.usage.inputTokens)")
print("Output tokens: \(result.usage.outputTokens)")
print("Cost: $\(String(format: "%.6f", result.totalCostUsd))")
```

**QueryResult 属性（来自 AgentTypes.swift 源码）：**
- `text: String` — 助手响应文本
- `usage: TokenUsage` — 含 `inputTokens: Int`、`outputTokens: Int`
- `numTurns: Int` — Agent 循环轮次
- `durationMs: Int` — 毫秒级耗时
- `messages: [SDKMessage]` — 消息集合
- `status: QueryStatus` — `.success`、`.errorMaxTurns`、`.errorDuringExecution`、`.errorMaxBudgetUsd`
- `totalCostUsd: Double` — 美元成本

**AgentOptions 参数顺序（来自 AgentTypes.swift init 签名）：**
`apiKey, model, baseURL, provider, systemPrompt, maxTurns, maxTokens, maxBudgetUsd, thinking, permissionMode, canUseTool, cwd, tools, mcpServers, retryConfig, agentName, mailboxStore, teamStore, taskStore, worktreeStore, planStore, cronStore, todoStore, sessionStore, sessionId, hookRegistry`

**注意：** `tools` 参数默认为 `nil`（不注册工具），本示例不传此参数。

### 前序 Story 的经验教训（必须遵循）

来自 Story 10-1 和 Story 9-3 的 Dev Notes：

1. **API 密钥不暴露** — 使用 `"sk-..."` 占位符或 `ProcessInfo.processInfo.environment` 读取（NFR6）
2. **代码示例必须与实际 API 一致** — 严格对照源码验证每个 API 调用
3. **不使用 Apple 专属框架** — Foundation 在 macOS 和 Linux 均可用
4. **`import Foundation`** — 需要 ProcessInfo 时必须导入 Foundation
5. **`agent.prompt()` 返回 `QueryResult`** — 使用 `await` 异步获取，所有属性直接访问（`usage` 非 Optional）
6. **AgentOptions 参数顺序必须精确匹配** — 参照 AgentTypes.swift 中的 init 签名
7. **`permissionMode: .bypassPermissions`** — 示例中避免权限提示干扰

### 反模式警告

- **不要**使用假设性 API — 必须与实际源码公共 API 完全一致
- **不要**暴露真实 API 密钥 — 使用 `"sk-..."` 占位符
- **不要**使用 `try!` 或 `!` 强制解包 — 使用 `guard let`、`if let`
- **不要**修改任何现有源代码 — 本 story 只添加示例文件和更新 Package.swift
- **不要**创建独立的 Package.swift — 在顶层 Package.swift 中添加 executableTarget
- **不要**使用流式 API — 本示例专门展示阻塞式 `agent.prompt()` 的简单用法
- **不要**注册工具 — 本示例展示纯对话能力，突出系统提示的效果
- **不要**在示例中实现复杂业务逻辑 — 保持简洁、聚焦系统提示定制

### 模块边界

**本 story 涉及文件：**
- `Package.swift` — 修改：添加 1 个 executableTarget（CustomSystemPromptExample）
- `Examples/CustomSystemPromptExample/main.swift` — 新建：自定义系统提示 + 阻塞式 API + 完整结果展示

**不涉及任何现有源代码文件变更。**

```
项目根目录/
├── Package.swift                                    # 修改：添加 CustomSystemPromptExample executableTarget
├── Examples/
│   ├── BasicAgent/main.swift                        # 不修改
│   ├── StreamingAgent/main.swift                    # 不修改
│   ├── CustomTools/main.swift                       # 不修改
│   ├── MCPIntegration/main.swift                    # 不修改
│   ├── SessionsAndHooks/main.swift                  # 不修改
│   ├── MultiToolExample/main.swift                  # 不修改
│   └── CustomSystemPromptExample/                   # 新建目录
│       └── main.swift                               # 新建：自定义系统提示示例
└── _bmad-output/
    └── implementation-artifacts/
        └── 10-2-custom-system-prompt-example.md     # 本文件
```

### 测试策略

本 story 不需要单元测试。验证方式：
1. `swift build` 确认 CustomSystemPromptExample 目标编译通过
2. 确认所有 API 调用与当前公共 API 签名匹配
3. 现有测试套件全部通过（无回归）
4. 如果环境允许（有 API key），可手动运行示例验证功能

### Project Structure Notes

- 在顶层 Package.swift 中添加 CustomSystemPromptExample executableTarget（与现有 6 个示例一致）
- 新建 `Examples/CustomSystemPromptExample/main.swift`
- 不涉及任何现有源代码文件变更
- 完全对齐架构文档的 `Examples/` 目录结构扩展

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.2 自定义系统提示示例]
- [Source: _bmad-output/planning-artifacts/prd.md#FR1] — 开发者可以通过系统提示词创建代理
- [Source: _bmad-output/planning-artifacts/prd.md#FR50] — SDK 为所有主要功能领域提供可运行的代码示例
- [Source: _bmad-output/planning-artifacts/architecture.md#Examples 目录结构] — 架构文档定义的示例结构
- [Source: _bmad-output/project-context.md#Technology Stack & Versions]
- [Source: _bmad-output/implementation-artifacts/10-1-multi-tool-example.md] — 前序 Story 的经验教训和 API 签名
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent、createAgent、prompt 实际 API
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions、QueryResult、QueryStatus 实际签名
- [Source: Examples/BasicAgent/main.swift] — 阻塞式 prompt API 使用模式参考（已验证一致）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- All 4 tasks completed successfully
- Task 1: Added CustomSystemPromptExample executableTarget to Package.swift
- Task 2: Created Examples/CustomSystemPromptExample/main.swift with code review expert system prompt, blocking prompt() API, and full QueryResult output
- Task 3: `swift build --target CustomSystemPromptExample` compiled successfully with no errors or warnings
- Task 4: Full test suite passed — 1883 tests with 0 failures and 4 skipped
- All API calls verified against actual public API signatures in AgentTypes.swift
- No force unwraps used, no real API keys exposed

### File List

- `Package.swift` — Modified: added CustomSystemPromptExample executableTarget
- `Examples/CustomSystemPromptExample/main.swift` — New: custom system prompt example with blocking prompt API

### Change Log

- 2026-04-10: Implemented Story 10-2 — CustomSystemPromptExample with code review expert system prompt, blocking agent.prompt() API, full QueryResult output display. All 1883 tests passing, no regressions.

### Review Findings
