---
project_name: 'open-agent-sdk-swift'
user_name: 'Nick'
date: '2026-04-11'
sections_completed:
  ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'quality_rules', 'workflow_rules', 'anti_patterns']
status: 'complete'
rule_count: 48
optimized_for_llm: true
---

# Project Context for AI Agents - OpenAgentSDKSwift

_本文档包含 AI 代理在实现代码时必须遵循的关键规则和模式。专注于代理容易忽略的非显而易见的细节。_

---

## Technology Stack & Versions

- **语言：** Swift 5.9+（支持 typed throws）
- **最低平台：** macOS 13+、Linux (Ubuntu 20.04+)
- **构建系统：** Swift Package Manager（仅限 SPM，不支持 CocoaPods/Carthage）
- **测试框架：** XCTest（Swift 内置）
- **文档：** Swift-DocC
- **模块名：** `OpenAgentSDK`（单目标库）
- **外部依赖：** `mcp-swift-sdk`（DePasqualeOrg/mcp-swift-sdk）— MCP stdio/SSE/HTTP 传输；`swift-docc-plugin`（swiftlang/swift-docc-plugin）— 开发时 DocC 文档生成
- **API 客户端：** 自定义 `AnthropicClient`（基于 URLSession），**不使用**社区 Anthropic SDK
- **参考源码：** TypeScript SDK 位于 `/Users/nick/CascadeProjects/open-agent-sdk-typescript/src/`（~53 个源文件，~7800 行）

---

## Critical Implementation Rules

### Swift 语言规则

1. **Actor 用于共享可变状态**：所有存储（SessionStore, TaskStore, TeamStore, MailboxStore, PlanStore, CronStore, TodoStore, AgentRegistry, ConfigStore）、QueryEngine、MCPClientManager、HookRegistry 必须是 `actor`。不可变数据类型（SDKMessage, ToolResult, TokenUsage, ConversationMessage）和配置类型（SDKConfiguration, AgentOptions）使用 `struct`。

2. **结构化并发**：工具执行使用 `TaskGroup`（只读工具，上限 10 个并发）+ 串行 `for` 循环（变更操作）。使用 `AsyncStream<SDKMessage>` 进行流式传输。

3. **禁止 force-unwrap**：不使用 `!` 进行 optional 解包。一律使用 `guard let` 或 `if let`。

4. **错误模型**：使用带关联值的嵌套枚举 `SDKError`。工具执行错误在 `ToolResult(is_error: true)` 中捕获返回，**永不**从工具处理程序内部 throw 导致循环中断。

5. **Codable 与原始 JSON 边界**：
   - Swift 端：`Codable`（工具输入解码、会话序列化）
   - LLM 端：`[String: Any]` 原始 JSON 字典（API 请求/响应、工具 inputSchema）
   - **不要**将 Codable 用于 LLM API 通信

6. **Typed throws (Swift 5.9+)**：在适当的异步上下文中使用 `throws(SDKError)` 风格。

### 架构规则

7. **模块边界严格单向依赖**：
   - `Types/` → 无出站依赖（叶节点）
   - `Utils/` → 无出站依赖（叶节点，Compact 例外可临时调用 API/AnthropicClient）
   - `API/` → 依赖 `Types/`
   - `Core/` → 依赖 `Types/`、`API/`、`Utils/`
   - `Tools/` → 依赖 `Types/`、`Utils/`，**永不**导入 `Core/`
   - `Stores/` → 依赖 `Types/`，**永不**导入 `Core/`
   - `Hooks/` → 依赖 `Types/`，**永不**导入 `Core/` 或 `Tools/`
   - `MCP/` → 依赖 `Types/` + 外部 mcp-swift-sdk

8. **Core/ 是唯一编排器**：Tools/、Stores/、Hooks/ 独立于核心循环 — 它们只定义行为，从不驱动它。

9. **工具协议**：所有工具符合 `ToolProtocol`（name, description, inputSchema, call(), isReadOnly）。自定义工具通过 `defineTool<Input: Codable>()` 创建。

10. **MCP 命名空间**：MCP 工具使用 `mcp__{serverName}__{toolName}` 命名约定。

11. **流式管道**：`AsyncStream<SDKMessage>` 在并发调度中保持事件顺序。消费者使用 `for await` 循环。

### 命名约定

12. **类型和协议**：PascalCase — `QueryEngine`、`ToolProtocol`、`SessionStore`
13. **函数和变量**：camelCase — `estimateCost()`、`compactConversation()`
14. **常量和环境变量**：SNAKE_CASE — `AUTOCOMPACT_BUFFER_TOKENS`、`CODEANY_API_KEY`
15. **工具实现后缀**：`*Tool` — `BashTool`、`FileReadTool`、`GlobTool`
16. **文件命名**：PascalCase，每个类型一个文件 — `QueryEngine.swift`、`SessionStore.swift`
17. **API JSON 字段**：snake_case（匹配 Anthropic API）— `input_tokens`、`tool_use_id`、`stop_reason`
18. **Swift 内部属性**：camelCase — `inputTokens`、`toolUseId`、`stopReason`
19. **SDKMessage 类型字段**：snake_case（匹配 TS SDK）— `type`、`session_id`、`num_turns`

### 访问控制

20. **public**：Agent、createAgent()、query()、defineTool()、所有公共类型、ToolProtocol
21. **internal**：QueryEngine 状态、消息历史、使用量跟踪、存储实现细节、工具执行分派、权限检查
22. 优先使用 `internal` 防止意外依赖

### 测试规则

23. **测试框架**：XCTest，测试目录结构镜像源码结构
24. **测试组织**：`Tests/OpenAgentSDKTests/{Core,Tools,Stores,API,Hooks,MCP,Utils}/`
25. **工具测试**：按层级分组 — `CoreToolTests.swift`、`AdvancedToolTests.swift`、`SpecialistToolTests.swift`
26. **Actor 测试**：使用 `await` 访问 actor 隔离方法
27. **无 mock 外部 API**：AnthropicClient 测试使用自定义的 mock URL 协议或 URLProtocol 子类
28. **错误路径测试**：每个 actor 存储和 QueryEngine 必须测试错误传播路径
29. **故事完成后必须补充 E2E 测试**：每个故事实现完成后，必须在 `Sources/E2ETest/`（29 个测试文件）中补充对应的 E2E 测试，至少包含 happy path 的验收测试

### 代码质量规则

30. **import 组织**：顶级公共 API 从 `OpenAgentSDK.swift`（模块入口点）重新导出。内部使用相对导入。
31. **无循环依赖**：工具永远不直接导入 API 类型。
32. **Utils/ 扁平结构**：没有嵌套子目录。
33. **配置默认值**：显式默认 — `maxTurns: 10`、`maxTokens: 16384`、`model: "claude-sonnet-4-6"`。
34. **环境变量**：通过 `ProcessInfo.processInfo`（或 Linux 上 `getenv`）解析，可为空时返回 nil。

### 开发工作流规则

35. **项目结构**：`Sources/OpenAgentSDK/` 为主源码目录（75 个 Swift 文件），子目录为 Types/（15 文件）、API/（5 文件）、Core/（3 文件）、Tools/（36 文件，含 Core/、Advanced/、Specialist/、MCP/ 四个子目录）、Stores/（9 文件）、Hooks/（2 文件）、Utils/（4 文件）、MCP/（预留空目录）、Documentation.docc/（DocC 文档）
36. **不使用 Apple 专属框架**：代码必须同时在 macOS 和 Linux 上运行。使用 Foundation 和 POSIX API。
37. **POSIX shell 执行**：使用 `Process`（macOS Foundation）/ `posix_spawn`（Linux）执行 shell 钩子，通过 stdin JSON 输入、stdout JSON 输出。
38. **会话存储路径**：`~/.open-agent-sdk/sessions/{sessionId}/transcript.json`

### 关键反模式和禁忌

39. **不要**从工具处理程序内部 throw 错误 — 在 ToolResult 中捕获返回
40. **不要**使用 force-unwrap (`!`) — 使用 guard let / if let
41. **不要**在 Tools/ 中导入 Core/ — 违反模块边界
42. **不要**将 Codable 用于 LLM API 通信 — 使用原始 `[String: Any]` 字典
43. **不要**使用社区 Anthropic SDK — 使用自定义 AnthropicClient actor
44. **不要**使用 Apple 专属框架（UIKit, AppKit, Combine 等）— 必须跨平台
45. **不要**对可变共享状态使用 struct/class — 必须是 actor
46. **不要**将 Set 用于有序集合 — 使用 Array（工具列表、消息历史）
47. **不要**在工具中使用 async let 或 unstructured Task — 使用 TaskGroup 的结构化并发

---

## Usage Guidelines

**For AI Agents:**

- 实现代码前先阅读本文件
- 严格遵循所有规则
- 有疑问时选择更严格的选项
- 参考架构文档 `_bmad-output/planning-artifacts/architecture.md` 获取完整设计细节
- 参考 TypeScript SDK `/Users/nick/CascadeProjects/open-agent-sdk-typescript/src/` 了解实现参考

**For Humans:**

- 保持文件精简，聚焦代理需求
- 技术栈变化时更新
- 定期审查过时规则
- 规则变得显而易见时移除

Last Updated: 2026-04-11
