---
project_name: 'open-agent-sdk-swift'
user_name: 'Nick'
date: '2026-04-11'
sections_completed:
  ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'quality_rules', 'workflow_rules', 'anti_patterns']
status: 'complete'
rule_count: 56
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
- **外部依赖：** `mcp-swift-sdk`（DePasqualeOrg/mcp-swift-sdk）— MCP stdio/SSE/HTTP 传输；`swift-docc-plugin`（swiftlang/swift-docc-plugin）— 开发时 DocC 文档生成；`hummingbird`（hummingbird-project/hummingbird）from 2.0.0 — HTTP API Server（SwiftNIO）
- **API 客户端：** 自定义 `AnthropicClient`（基于 URLSession），**不使用**社区 Anthropic SDK
- **参考源码：** TypeScript SDK 位于 `/Users/nick/CascadeProjects/open-agent-sdk-typescript/src/`（~53 个源文件，~7800 行）

---

## Critical Implementation Rules

### Swift 语言规则

1. **Actor 用于共享可变状态**：所有存储（SessionStore, TaskStore, TeamStore, MailboxStore, PlanStore, CronStore, TodoStore, AgentRegistry, FactStore, WorktreeStore）、MCPClientManager、HookRegistry、RunTracker、EventBroadcaster、TraceRecorder、ConcurrencyLimiter 必须是 `actor`。不可变数据类型（SDKMessage, ToolResult, TokenUsage, ConversationMessage）和配置类型（SDKConfiguration, AgentOptions）使用 `struct`。无状态计算服务（MemoryLifecycleService, TraceEventMapping, LLMExperienceExtractor, MemorySecurityScanner）也使用 `struct`。

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
   - `Utils/` → 依赖 `Types/`、`Stores/`（FactStore），`API/`（LLMClient protocol — 用于 LLMExperienceExtractor 等LLM驱动服务）
   - `API/` → 依赖 `Types/`
   - `HTTP/` → 依赖 `Types/`、`Core/`（Agent），使用 Hummingbird 2.x（SwiftNIO）
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
24. **测试组织**：`Tests/OpenAgentSDKTests/{Core,Tools,Stores,API,HTTP,Hooks,MCP,Utils,Types,Skills,Compat,Documentation}/`
25. **工具测试**：按层级分组 — `CoreToolTests.swift`、`AdvancedToolTests.swift`、`SpecialistToolTests.swift`
26. **Actor 测试**：使用 `await` 访问 actor 隔离方法
26b. **Swift 6 并发 Mock 模式**：需要可变状态的 mock 使用 `final class SharedMockState<T>: @unchecked Sendable` 包装器，通过共享引用在闭包中捕获可变状态。对于简单的可变标志，使用 `nonisolated(unsafe)`。
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

35. **项目结构**：`Sources/OpenAgentSDK/` 为主源码目录（158 个 Swift 文件），子目录为 Types/（34 文件）、API/（5 文件）、Core/（3 文件）、HTTP/（8 文件）、Tools/（43 文件，含 Core/、Advanced/、Specialist/、MCP/ 四个子目录）、Stores/（13 文件）、Hooks/（2 文件）、Utils/（39 文件）、Skills/（技能加载器）、Documentation.docc/（DocC 文档）
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
48. **不要**内联构建 JSONEncoder/JSONDecoder/ISO8601DateFormatter** — 使用 EnvUtils.swift 中的共享工厂函数（makeSDKJSONEncoder/makeSDKJSONDecoder/makeISO8601DateFormatter）
49. **不要**内联解析 LLM API 响应** — 使用 LLMResponseHelpers.swift 中的共享函数（extractFirstTextFromResponse、stripCodeFences、parseJSONToDict、parseLLMResponseAsObject/Array）
50. **不要**手写 tempDir setUp/tearDown** — 测试文件继承 TempDirTestCase 基类
51. **不要**重复实现 ToolContext 构建** — 使用 GitTestHelpers.swift 中的 makeTestToolContext()

### 共享基础设施规则

52. **EnvUtils.swift 是共享工具中心**：所有跨文件复用的纯函数工具集中在此文件，包括：目录解析（defaultHomeDir/defaultSkillsDir/defaultMemoryDir/defaultSessionsDir/defaultTracesDir/defaultApiRunsDir + resolve*Dir 函数）、文件 I/O（atomicWriteJSON、ensureDirectoryExists）、验证（validatePathSafeIdentifier）、工厂（makeISO8601DateFormatter、makeSDKJSONEncoder、makeSDKJSONDecoder）、哈希（djb2Hash）、YAML（yamlEscape、yamlQuote）、JSON（jsonStringify）、路径（normalizePath）。新写跨文件复用的纯函数工具应放入此文件。
53. **LLMResponseHelpers.swift 是 LLM 响应解析中心**：extractFirstTextFromResponse、stripCodeFences、parseJSONToDict、parseLLMResponseAsObject、parseLLMResponseAsArray。所有 LLM 驱动工具（LLMSkillEvolver、PromptEvolverEngine、LLMExperienceExtractor、Compact）使用此文件的共享函数。
54. **LLMClient.swift 包含共享 LLM 客户端基础设施**：performLLMRequest（URLError→SDKError 映射）、validateLLMHTTPResponse（HTTP 响应验证）、resolveBaseURL（URL 解析）、buildJSONPostRequest（POST 请求构建）。AnthropicClient 和 OpenAIClient 均通过这些共享函数避免重复。
55. **MCPTypes.swift 包含共享 MCP 基础设施**：schemaToMCPValue/anyToMCPValue/mcpValueToAny（MCP 值转换）、registerToolsOnMCPServer（工具注册循环）、createMCPSession（会话创建）、ToolExecutionError（错误类型）。InProcessMCPServer、MCPClientManager、AgentMCPServer 均使用这些共享函数。
56. **测试基础设施**：Tests/OpenAgentSDKTests/ 根目录包含 3 个共享测试文件：TempDirTestCase.swift（临时目录管理基类，47+ 测试文件已迁移）、GitTestHelpers.swift（makeTestToolContext/makeTestSkill/seedSkill/date/callToolForTest/createTemplateGitRepo 等）、MockURLProtocolHelpers.swift（readRequestBodyFromStream/makeMockURLSession）。新测试应使用这些共享基础设施而非重复定义。

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

Last Updated: 2026-06-09
