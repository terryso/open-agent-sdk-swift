---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift.md
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift-distillate.md
documentCounts:
  briefs: 2
  research: 0
  projectDocs: 0
  projectContext: 0
classification:
  projectType: developer_tool
  domain: ai_agent_infrastructure
  complexity: medium
  projectContext: greenfield
workflowType: 'prd'
---

# 产品需求文档 - OpenAgentSDKSwift

**作者：** Nick
**日期：** 2026-04-03

## 概述

OpenAgentSDKSwift 是一个原生 Swift Package Manager 库，为 Swift 生态系统带来完整的 AI 代理能力——包括智能体循环、34 个内置工具、MCP 协议支持、会话持久化和钩子系统——所有这些都不需要将 Node.js 作为运行时依赖嵌入。

该项目源于一个具体需求：构建一个原生 macOS 应用，需要从 Swift 代码直接访问 SDK。不需要通过 Node.js 桥接，不需要仅提供 API 客户端而将 80% 的代理栈未实现的方案，也不需要依赖外部二进制文件的 CLI 封装。这是每个 Swift 开发者在想要 AI 代理能力时都会遇到的鸿沟。

该 SDK 使用符合 Swift 惯例的并发原语，将经过验证的 TypeScript 代理架构移植到 Swift：使用 actor 实现状态隔离，使用 AsyncStream 实现流式传输，使用 Codable 实现序列化。它通过 SPM 支持 macOS 13+ 和 Linux，仅有一个外部依赖（用于 MCP 协议的 mcp-swift-sdk）。功能与 TypeScript SDK 实现了一对一的平价；API 设计遵循 Swift 惯例。

**目标用户：** 构建人工智能驱动的工具和生产力应用的 macOS 应用开发者（主要），Linux 上的服务端 Swift 工程师（次要），以及在 Swift 中工作并需要从原始 API 调用转向完整代理编排的 AI/ML 工程师（第三级）。

### 独特之处

- **唯一具有完整代理能力的 Swift SDK。** 没有其他 Swift 包能在单一库中提供内置工具 + MCP + 会话持久化 + 钩子。替代方案要么是 API 客户端（仅支持消息补全），要么是 CLI 封装器（依赖外部二进制文件）。
- **经过验证的架构，可控的风险。** 智能体循环、工具系统和会话模型已在 TypeScript 生产环境中经过实战检验。实施风险已被识别并有边界：动态 JSON schema 处理、工具分发以及 shell 钩子执行映射到 Swift 的严格类型系统。
- **源于真实需求。** 这不是推测性的——它目前正阻碍着真正的原生 Mac 应用开发。每个想要 AI 代理的 Swift 开发者都面临同样的障碍。
- **最小化的依赖占用。** 只有一个外部依赖。基于 URLSession 的自定义 Anthropic API 客户端避免了社区 SDK 版本冲突和重试策略冲突。
- **多语言 SDK 家族的一部分。** TypeScript、Go、Swift——跨语言保持一致的代理理念。

## 项目分类

| 维度 | 值 |
|---|---|
| **项目类型** | 开发者工具（SDK / 库 / 包） |
| **领域** | AI 代理基础设施 |
| **复杂度** | 中等 |
| **项目背景** | 全新项目（从 TypeScript 移植） |

## 成功标准

### 用户成功

- Swift 开发者将 `OpenAgentSDK` 添加为 SPM 依赖后，能在 **15 分钟内** 按照 README 快速入门指南实现一个可工作的流式响应代理。
- API 对 Swift 开发者来说感觉自然——`async/await`、`AsyncStream<SDKMessage>` 上的 `for await` 流式传输、基于 Codable 的工具定义。无需从 TypeScript 进行心智翻译。
- 全部 34 个工具在 macOS 和 Linux 上工作方式一致——开发者的代理代码在 Mac 和 Linux 服务器上运行结果相同。
- 使用 `defineTool()` 创建自定义工具，从阅读文档到可工作的工具不超过 5 分钟。

### 商业成功

- 发布后 6 个月内获得 **200+ GitHub stars**，表明真正的开发者兴趣。
- 外部开发者贡献——核心团队之外的开发者提交 issue 和 PR。
- 6 个月内至少有 **一个第三方项目** 采用 OpenAgentSDKSwift。
- 在社区讨论中被公认为首选的 Swift 代理 SDK（Swift Forums、Reddit、X）。

### 技术成功

- 全部 34 个内置工具在 macOS 13+ 和 Linux 上通过 GitHub Actions CI 的单元测试。
- 集成测试覆盖完整的智能体循环（LLM 调用 → 工具执行 → 结果反馈 → 重复）。
- 每个 PR 都实现双平台 CI 绿灯——无平台特定回归。
- Swift-DocC 生成的 API 文档实现完全覆盖。
- 每个主要功能都有可编译和运行的工作代码示例。
- 核心代理循环和工具系统 API 在 v1.0 时冻结；钩子和 MCP API 标记为演进中。
- 语义化版本控制；Swift SDK 跟踪自己的版本，独立于 TypeScript SDK。

### 可衡量成果

| 指标 | 目标 | 时间范围 |
|---|---|---|
| 从快速入门到可工作的代理 | < 15 分钟 | 发布时 |
| 测试覆盖率（每个阶段） | 所有工具均通过单元测试 | 每个阶段 |
| 双平台 CI | 每个 PR 绿灯 | 发布时 |
| GitHub stars | 200+ | 发布后 6 个月 |
| 外部采用 | 1+ 第三方项目 | 发布后 6 个月 |
| API 稳定性 | 核心 API 在 v1.0 冻结 | 发布时 |

## 用户旅程

### 旅程 1：Sarah — macOS 应用开发者（主要用户）

**开场场景：** Sarah 正在构建一个原生 macOS 生产力应用——一个代码审查助手，能够读取 pull request、分析 diff 并发布审查评论。她一直在通过 URLSession 使用原始 Anthropic API 调用进行原型开发，但所有时间都花在重新实现工具执行、对话管理和错误处理上。她写了 2,000 行本应是库的样板代码。

**上升情节：** Sarah 发现了 OpenAgentSDKSwift。她将其添加为 SPM 依赖。README 快速入门展示了如何用 10 行 Swift 代码创建一个带流式传输的代理。她将其粘贴到 Playground 中，看到第一个代理响应流式返回。然后她注册 Read、Glob 和 Grep 工具，赋予代理文件系统访问能力——每个只需三行代码。她使用 `defineTool()` 定义了一个自定义的 `PostCommentTool`，配合 Codable 输入结构和 JSON Schema 定义。

**高潮：** Sarah 用 150 行 OpenAgentSDKSwift 调用替换了 2,000 行手写的代理基础设施。她的代理现在拥有完整的工具套件、会话持久化（用户可以恢复审查对话），以及自动压缩功能来处理长 PR 而不会耗尽上下文。她在同一周将更新发布到 TestFlight。

**结局：** Sarah 的应用感觉很流畅——流式响应通过 AsyncStream 上的 `for await` 在 SwiftUI 视图中逐 token 显示。她不再与基础设施搏斗，而是在构建功能。她的下一个想法——一个管理 GitHub issue 的代理——只花了一个下午，因为 SDK 处理了一切。

### 旅程 2：Marcus — 服务端 Swift 工程师（次要用户）

**开场场景：** Marcus 在 Linux 服务器上使用 Vapor 运行一个自动化代码分析服务。他需要一个能够检查代码仓库、运行静态分析并生成报告的代理。他一直在评估 Python 代理框架，但不想在 Swift 技术栈中添加 Python 运行时。在生产环境中部署两种语言运行时增加了监控开销、部署复杂性和团队技能分散。

**上升情节：** Marcus 将 OpenAgentSDKSwift 添加到他的 Vapor 项目的 Package.swift 中。它在 Linux 上顺利解析——没有仅限 Apple 的框架。他创建了一个代理端点，接收分析请求，生成一个带有 Bash 和 Read 工具的代理，并通过 Server-Sent Events 将进度流式返回给调用者。会话持久化意味着长时间运行的分析可以在服务器重启后继续。

**高潮：** Marcus 的服务在开发环境的 Mac 和生产环境的 Ubuntu 上运行相同的 OpenAgentSDKSwift 代码。当分析需要多轮时，自动压缩功能自动将对话保持在上下文限制内。预算跟踪防止失控的代理循环消耗过多的 API 费用。

**结局：** Marcus 将单个 Swift 二进制文件部署到生产环境——不需要 Node.js，不需要 Python，不需要进程间通信。他的团队审查和维护一个代码库。代理的工具执行通过 actor 实现线程安全，因此多个并发分析请求不会相互干扰。

### 旅程 3：Wei — 构建自定义工具的 AI/ML 工程师（第三级用户）

**开场场景：** Wei 在一个处理大型数据集的研究团队工作。他想构建一个 AI 代理，能够读取 CSV 文件、运行统计分析并生成可视化脚本。他一直在 Swift 中编写原始 API 调用，因为 Python 的代理框架对他的轻量级数据管道来说太重了。他需要一种 Swift 原生的方式来定义领域特定工具并运行代理循环。

**上升情节：** Wei 使用 `defineTool()` 创建了三个自定义工具：`AnalyzeCSV`、`RunPythonScript` 和 `GenerateChart`。每个工具都有一个 Codable 输入结构并返回结构化输出。他为代理配置了每次请求 0.50 美元的预算和最多 20 轮的限制。他接入 `PostToolUse` 生命周期事件，为他的研究论文记录工具执行指标。

**高潮：** Wei 的代理自主处理数据集——读取文件、决定运行哪些分析、解释结果并生成图表。钩子系统为他提供了每个工具调用的细粒度可观察性。当代理达到预算限制时，它优雅地返回带有成本摘要的部分结果，而不是静默失败。

**结局：** Wei 将他的数据分析代理作为内部工具发布。其他研究人员通过相同的 `defineTool()` 模式添加自己的自定义工具来扩展它。没有人需要理解智能体循环的内部原理——他们只需定义工具，SDK 处理其余的一切。

### 旅程需求摘要

| 旅程 | 揭示的需求领域 |
|---|---|
| Sarah（macOS 应用） | 流式传输、工具注册、自定义工具、会话持久化、自动压缩、SwiftUI 集成 |
| Marcus（服务端） | Linux 支持、并发代理、预算跟踪、会话恢复、SSE 流式传输 |
| Wei（AI/ML 自定义） | 自定义工具定义、钩子可观察性、预算限制、结构化工具 I/O |

## 创新与新颖模式

### 已识别的创新领域

1. **Swift 中首个完整的代理框架。** 此前没有 Swift 包将智能体循环、34 个内置工具、MCP 协议、会话持久化和钩子系统结合在一起。这对 Swift 来说是一个新范式——以前 Swift 开发者只能通过原始 API 客户端或桥接到 Node.js/Python 运行时来使用 AI。

2. **defineTool() DSL 模式。** 自定义工具 API 利用 Swift 的类型系统（Codable + JSON Schema）创建声明式工具定义体验。开发者编写一个 Codable 结构作为输入，为 LLM 提供一个 JSON Schema 字典，并实现一个闭包用于执行。这在 Swift 的严格类型和 LLM 的动态 schema 期望之间架起桥梁，而不牺牲类型安全性。

3. **跨平台代理一致性。** 相同的代理代码在 macOS（GUI 应用、CLI 工具）和 Linux（服务端）上以相同的行为运行。34 工具的分层系统让使用者只加载其平台支持的内容——Core 工具用于最小代理，Advanced 用于多代理编排，Specialist 用于 CLI/开发者工作流。

### 竞争格局

| 竞争者 | 缺少的方面 |
|---|---|
| Apple FoundationModels | 无云端 LLM、无跨平台、无 MCP、无会话持久化、仅支持 Apple Silicon |
| SwiftAgent（Swift Forums） | 仅限 Apple 平台、无 MCP、无会话持久化 |
| ClaudeCodeSDK | CLI 封装器，依赖外部二进制文件 |
| AnthropicSwiftSDK / AnthropicKit / SwiftAnthropic | 仅 API 客户端——无代理循环、工具、会话或 MCP |
| mcp-swift-sdk 变体 | 仅支持 MCP，非代理框架 |

### 验证方法

- **每个工具的单元测试** 在 macOS 和 Linux 上验证与 TypeScript SDK 的功能一致性。
- **集成测试** 通过实际工具执行来演练完整的智能体循环。
- **示例应用** 作为端到端验证：如果快速入门示例能够编译和运行，核心 SDK 就能正常工作。

### 风险缓解

| 风险 | 缓解措施 |
|---|---|
| 动态 JSON schema ↔ Codable 桥接 | 使用 `[String: Any]` JSON Schema 字典给 LLM，Codable 给 Swift 解码；从 TS Zod→JSON Schema 验证的成熟模式 |
| mcp-swift-sdk 成熟度 | 在第 6 阶段评估；备选方案是 fork+维护或原生 MCP 实现 |
| 上游 TS SDK API 变更 | Swift SDK 跟踪自己的版本；按版本评估上游变更 |
| macOS App Store 兼容性 | 记录哪些权限模式和工具子集是 App Store 安全的 |

## 开发者工具特定需求

### 平台与分发

- **包管理器：** 仅使用 Swift Package Manager (SPM)。v1.0 不支持 CocoaPods 或 Carthage。
- **模块名称：** `OpenAgentSDK`。通过 `import OpenAgentSDK` 导入。
- **平台：** macOS 13+ (Ventura)、Linux (Ubuntu 20.04+)。不需要仅限 Apple 的框架。
- **Swift 版本：** Swift 5.9+（用于并发和 typed throws 支持）。

### API 表面设计

- **Swift 惯例化：** 所有异步操作使用 `async/await`，流式传输使用 `AsyncStream<SDKMessage>`，所有可变状态存储使用 `actors`，所有可序列化类型使用 `Codable`。
- **两种消费模式：** 流式通过 `agent.stream(prompt)` 返回 `AsyncStream<SDKMessage>`，阻塞通过 `agent.prompt(prompt)` 返回最终结果。
- **工具注册：** 使用 `defineTool()` 的类型安全工具定义，Codable 输入解码，供 LLM 使用的 JSON Schema 字典。
- **错误模型：** 使用带关联值的 Swift 枚举的类型化错误。不使用强制解包或滥用可选值。

### 文档策略

- **Swift-DocC** 用于具有完整符号覆盖的 API 参考文档。
- **README** 包含目标在 15 分钟内实现首个可工作代理的快速入门指南。
- **工作示例** 覆盖每个主要功能领域：基础代理、流式传输、自定义工具、MCP、会话、钩子、子代理。
- **迁移指南** 从原始 Anthropic API 调用迁移到 OpenAgentSDKSwift（常见采用路径）。

### 代码示例覆盖

| 示例 | 演示内容 |
|---|---|
| 基础代理 | 代理创建、单次提示、响应处理 |
| 流式代理 | AsyncStream 消费、事件模式匹配 |
| 自定义工具 | defineTool()、Codable 输入、JSON Schema |
| MCP 集成 | 连接外部 MCP 服务器、暴露进程内工具 |
| 会话持久化 | 保存、加载、分叉、恢复对话 |
| 钩子系统 | 注册函数和 shell 钩子、生命周期事件 |
| 多代理 | Agent 工具、SendMessage、子代理编排 |
| 预算与权限 | 权限模式、预算跟踪、canUseTool 回调 |

## 项目范围与分阶段开发

### MVP 策略

**方法：** 平台 MVP——建立完整的开发者工具基础，实现与 TypeScript SDK 的完整功能平价。SDK 是平台；社区采用是验证信号。

### 阶段 1：MVP (v1.0)

**支持的核心用户旅程：** Sarah（macOS 应用）、Marcus（服务端）、Wei（自定义工具）。

**必备能力：**
- 具有流式和阻塞模式的智能体循环
- 跨三个层级的全部 34 个内置工具
- 自定义 Anthropic API 客户端
- MCP 客户端和进程内 MCP 服务器
- 会话持久化
- 钩子系统（21 个生命周期事件）
- 自定义工具定义
- 子代理支持
- 权限模式和预算跟踪
- 自动压缩和微压缩
- 所有管理存储（Task、Team、Worktree、Plan、Cron、Todo）
- Swift-DocC 文档
- GitHub Actions CI (macOS + Linux)
- 工作示例

**MVP 内的实施阶段：**
1. 基础——类型、API 客户端、配置、环境变量
2. 智能体循环——带流式传输、重试、自动压缩、预算跟踪的 QueryEngine
3. 工具系统——ToolRegistry、ToolBuilder、Core 层工具（10 个工具）
4. 高级工具——Agent、SendMessage、Task 工具、Team 工具、NotebookEdit
5. 专家工具——Worktree、Plan、Cron、LSP、Config、Todo、MCP Resource 工具
6. MCP 集成——MCPClientManager、InProcessMCPServer
7. 会话与钩子——SessionStore、HookRegistry、全部 21 个生命周期事件
8. 完善——文档、示例、CI 加固、性能优化

### 阶段 2：MVP 后 (v1.x)

- 性能分析和优化
- 额外的示例应用（Vapor 集成、SwiftUI 聊天视图）
- 社区要求的 API 改进
- 增强的错误消息和调试辅助
- 上游 TypeScript SDK 变更评估和采纳

### 阶段 3：扩展 (v2.0+)

- iOS/iPadOS 支持，提供有限工具集和 PlatformToolSet 协议
- FoundationModels 集成（混合本地/云端路由）
- SwiftUI 配套包（聊天视图、消息渲染器）
- Vapor/Hummingbird 中间件用于代理端点

### 风险缓解策略

| 风险类别 | 风险 | 缓解措施 |
|---|---|---|
| **技术** | 动态 JSON ↔ Codable 桥接 | 在第 3 阶段与工具系统一起验证；经过验证的模式 |
| **技术** | mcp-swift-sdk 不成熟 | 在第 6 阶段评估；fork/维护备选方案已就绪 |
| **技术** | Linux 上的 shell 钩子执行 | 在第 7 阶段早期测试；POSIX 兼容性验证 |
| **市场** | 社区采用率低 | 提供优秀的文档和示例；积极与 Swift 社区互动 |
| **市场** | TypeScript SDK 分歧 | 跟踪自己的版本；按版本评估上游变更 |
| **资源** | 单开发者带宽 | 分阶段交付；每个阶段独立可用 |

## 功能需求

### 智能体循环与 LLM 通信

- FR1：开发者可以使用系统提示词、模型选择和配置参数创建代理
- FR2：开发者可以向代理发送提示并通过 AsyncStream 接收流式响应
- FR3：开发者可以发送提示并接收包含最终结果的阻塞式响应
- FR4：代理执行完整的智能体循环：调用 LLM、解析工具使用请求、执行工具、反馈结果、重复直到完成
- FR5：代理通过提示延续从 max_tokens 响应中恢复（最多 3 次重试）
- FR6：开发者可以设置每次代理调用的最大轮次
- FR7：代理跟踪每次调用的累积 token 使用量和估计成本
- FR8：开发者可以设置每次调用的最大预算（美元）；代理在超出时优雅停止
- FR9：代理在接近上下文窗口限制时自动压缩对话
- FR10：代理微压缩超过 50,000 字符的单个工具结果

### 工具系统与执行

- FR11：开发者可以向代理注册单个工具或工具层级
- FR12：代理并发执行只读工具（最多 10 个并行），串行执行变更工具
- FR13：开发者可以使用 `defineTool()` 配合 Codable 输入类型和基于闭包的执行来创建自定义工具
- FR14：自定义工具为 LLM 消费提供 JSON Schema 定义，同时使用 Codable Swift 解码
- FR15：工具系统支持跨 Core、Advanced 和 Specialist 三个层级的 34 个内置工具
- FR16：Core 层工具包括：Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch
- FR17：Advanced 层工具包括：Agent、SendMessage、TaskCreate/List/Update/Get/Stop/Output、TeamCreate/Delete、NotebookEdit
- FR18：Specialist 层工具包括：WorktreeEnter/Exit、PlanEnter/Exit、CronCreate/Delete/List、RemoteTrigger、LSP、Config、TodoWrite、ListMcpResources、ReadMcpResource

### MCP 协议支持

- FR19：开发者可以通过 stdio 传输连接到外部 MCP 服务器
- FR20：开发者可以通过 HTTP/SSE 传输连接到外部 MCP 服务器
- FR21：开发者可以暴露进程内 MCP 工具供外部 MCP 客户端消费
- FR22：MCP 工具在执行期间与内置工具一起可供代理使用

### 会话管理

- FR23：开发者可以将代理对话保存到持久存储（JSON）
- FR24：开发者可以加载并恢复之前保存的对话
- FR25：开发者可以从任何保存点分叉对话
- FR26：开发者可以列出、重命名、标记和删除已保存的会话
- FR27：会话存储通过基于 actor 的访问实现线程安全

### 钩子系统

- FR28：开发者可以在 21 个生命周期事件上注册函数钩子（PreToolUse、PostToolUse、PostToolUseFailure、SessionStart、SessionEnd、Stop、SubagentStart、SubagentStop、UserPromptSubmit、PermissionRequest、PermissionDenied、TaskCreated、TaskCompleted、ConfigChange、CwdChanged、FileChanged、Notification、PreCompact、PostCompact、TeammateIdle）
- FR29：开发者可以在生命周期事件上注册带正则匹配器的 shell 命令钩子
- FR30：Shell 钩子通过 stdin 接收 JSON 输入，通过 stdout 返回 JSON 输出
- FR31：钩子具有可配置的超时时间（默认：30 秒）

### 权限与安全模型

- FR32：开发者可以设置六种权限模式之一：default、acceptEdits、bypassPermissions、plan、dontAsk、auto
- FR33：开发者可以提供自定义的 `canUseTool` 回调用于消费者定义的授权逻辑
- FR34：权限系统根据配置的模式控制代理可以执行哪些工具

### 多代理编排

- FR35：代理可以通过 Agent 工具生成子代理来执行委托任务
- FR36：代理可以通过 SendMessage 与队友通信
- FR37：代理可以使用 TaskCreate/List/Update/Get/Stop/Output 工具管理任务
- FR38：代理可以使用 TeamCreate/Delete 工具创建和管理团队

### 配置与环境

- FR39：开发者可以通过环境变量配置 SDK（CODEANY_API_KEY、CODEANY_MODEL、CODEANY_BASE_URL）
- FR40：开发者可以通过配置结构以编程方式配置 SDK
- FR41：SDK 通过自定义 base URL 支持多个 LLM 提供者

### 管理存储

- FR42：代理可以通过 TaskStore 管理任务（创建、列出、更新、获取、停止）
- FR43：代理可以通过 TeamStore 管理团队（创建、删除）
- FR44：代理可以通过 WorktreeStore 管理 worktree
- FR45：代理可以通过 PlanStore 管理计划
- FR46：代理可以通过 CronStore 管理定时任务
- FR47：代理可以通过 TodoStore 管理待办事项
- FR48：所有存储使用基于 actor 的线程安全访问

### 文档与开发者体验

- FR49：SDK 提供 Swift-DocC 生成的 API 文档
- FR50：SDK 为所有主要功能领域提供可工作的代码示例
- FR51：SDK 提供包含快速入门指南的 README

## 非功能需求

### 性能

- NFR1：流式响应在收到 LLM API 响应后 2 秒内开始（首个 token）
- NFR2：文件系统操作（Read、Write、Edit、Glob、Grep）对于 1MB 以下的文件在 500ms 内完成
- NFR3：代理分发最多 10 个并发只读工具执行而不阻塞
- NFR4：会话保存和加载操作对于 500 条消息以下的对话在 200ms 内完成
- NFR5：自动压缩摘要在单次 LLM 调用的延迟内完成

### 安全

- NFR6：API 密钥从不被记录、打印或包含在错误消息中
- NFR7：Shell 钩子执行对输入进行净化以防止命令注入
- NFR8：权限系统在执行前强制执行工具访问限制
- NFR9：自定义 `canUseTool` 回调接收完整的工具上下文用于授权决策
- NFR10：会话文件以仅用户可读写权限（0600）存储

### 跨平台兼容性

- NFR11：所有 34 个工具在 macOS 13+ 和 Linux (Ubuntu 20.04+) 上产生相同的行为
- NFR12：核心 SDK 功能不要求任何仅限 Apple 的框架
- NFR13：CI 管道在每个 PR 上验证双平台兼容性
- NFR14：文件路径处理是平台感知的（符合 POSIX）

### 可靠性

- NFR15：代理使用指数退避重试 LLM API 调用（最多 3 次重试）
- NFR16：预算超限条件产生优雅的错误结果，而非崩溃
- NFR17：工具执行失败被捕获并报告给代理，而不终止智能体循环
- NFR18：自动压缩在摘要化后保持对话连续性

### 集成

- NFR19：MCP 客户端连接处理服务器进程生命周期（启动、崩溃恢复、优雅关闭）
- NFR20：Anthropic API 客户端仅通过 POST /v1/messages 进行通信，支持流式传输
- NFR21：通过可配置的 base URL 支持自定义 LLM 提供者，无需修改 SDK

### API 稳定性

- NFR22：核心代理循环和工具系统 API 在 v1.0 时冻结，不会有破坏性变更
- NFR23：钩子和 MCP API 标记为演进中，可能在次要版本之间变更
- NFR24：SDK 遵循语义化版本控制（major.minor.patch）
- NFR25：Swift SDK 版本独立于 TypeScript SDK 版本
