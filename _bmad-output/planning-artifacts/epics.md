---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
---

# OpenAgentSDKSwift - Epic 分解

## 概述

本文档提供了 OpenAgentSDKSwift 的完整 Epic 和 Story 分解，将 PRD 和架构需求分解为可实施的 Story。

## 需求清单

### 功能需求

FR1: 开发者可以通过系统提示词、模型选择和配置参数创建 Agent
FR2: 开发者可以通过 AsyncStream 发送提示词并接收流式响应
FR3: 开发者可以发送提示词并接收包含最终结果的阻塞式响应
FR4: Agent 执行完整的智能循环：调用 LLM、解析工具使用请求、执行工具、反馈结果、重复直至完成
FR5: Agent 通过发送续接提示从 max_tokens 响应中恢复（最多重试 3 次）
FR6: 开发者可以设置每次 Agent 调用的最大轮次
FR7: Agent 追踪每次调用的累积 token 使用量和预估成本
FR8: 开发者可以设置每次调用的最大预算（美元）；超出时 Agent 优雅停止
FR9: Agent 在接近上下文窗口限制时自动压缩对话
FR10: Agent 对超过 50,000 字符的单个工具结果进行微压缩
FR11: 开发者可以向 Agent 注册单个工具或工具层级
FR12: Agent 并发执行只读工具（最多 10 个并行）并串行执行变更工具
FR13: 开发者可以使用 defineTool() 创建自定义工具，支持 Codable 输入类型和基于闭包的执行
FR14: 自定义工具为 LLM 提供 JSON Schema 定义，同时支持 Codable Swift 解码
FR15: 工具系统支持三个层级（核心、高级、专业）共 34 个内置工具
FR16: 核心层工具包括：Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch
FR17: 高级层工具包括：Agent、SendMessage、TaskCreate/List/Update/Get/Stop/Output、TeamCreate/Delete、NotebookEdit
FR18: 专业层工具包括：WorktreeEnter/Exit、PlanEnter/Exit、CronCreate/Delete/List、RemoteTrigger、LSP、Config、TodoWrite、ListMcpResources、ReadMcpResource
FR19: 开发者可以通过 stdio 传输连接外部 MCP 服务器
FR20: 开发者可以通过 HTTP/SSE 传输连接外部 MCP 服务器
FR21: 开发者可以暴露进程内 MCP 工具供外部 MCP 客户端使用
FR22: MCP 工具在执行期间与内置工具一起对 Agent 可用
FR23: 开发者可以将 Agent 对话保存到持久存储（JSON）
FR24: 开发者可以加载并恢复之前保存的对话
FR25: 开发者可以从任何保存点分叉对话
FR26: 开发者可以列出、重命名、标记和删除已保存的会话
FR27: 会话存储通过基于 Actor 的访问实现线程安全
FR28: 开发者可以在 21 个生命周期事件上注册函数钩子
FR29: 开发者可以在生命周期事件上注册带正则匹配器的 Shell 命令钩子
FR30: Shell 钩子通过 stdin 接收 JSON 输入，通过 stdout 返回 JSON 输出
FR31: 钩子具有可配置的超时时间（默认：30 秒）
FR32: 开发者可以设置六种权限模式之一：default、acceptEdits、bypassPermissions、plan、dontAsk、auto
FR33: 开发者可以提供自定义 canUseTool 回调来实现消费者定义的授权逻辑
FR34: 权限系统根据配置的模式控制 Agent 可以执行哪些工具
FR35: Agent 可以通过 Agent 工具生成子 Agent 来执行委托任务
FR36: Agent 可以通过 SendMessage 与团队成员通信
FR37: Agent 可以使用 TaskCreate/List/Update/Get/Stop/Output 工具管理任务
FR38: Agent 可以使用 TeamCreate/Delete 工具创建和管理团队
FR39: 开发者可以通过环境变量（CODEANY_API_KEY、CODEANY_MODEL、CODEANY_BASE_URL）配置 SDK
FR40: 开发者可以通过配置结构体以编程方式配置 SDK
FR41: SDK 通过自定义 Base URL 支持多个 LLM 提供商
FR42: Agent 可以通过 TaskStore 管理任务（创建、列出、更新、获取、停止）
FR43: Agent 可以通过 TeamStore 管理团队（创建、删除）
FR44: Agent 可以通过 WorktreeStore 管理 Worktree
FR45: Agent 可以通过 PlanStore 管理计划
FR46: Agent 可以通过 CronStore 管理定时任务
FR47: Agent 可以通过 TodoStore 管理 Todo
FR48: 所有存储使用基于 Actor 的线程安全访问
FR49: SDK 提供 Swift-DocC 生成的 API 文档
FR50: SDK 为所有主要功能领域提供可运行的代码示例
FR51: SDK 提供包含快速入门指南的 README

### 非功能需求

NFR1: 流式响应在 LLM API 响应到达后 2 秒内开始（首 token）
NFR2: 文件系统操作工具（Read、Write、Edit、Glob、Grep）对 1MB 以下文件在 500ms 内完成
NFR3: Agent 调度最多 10 个并发只读工具执行而不阻塞
NFR4: 500 条消息以下的会话保存和加载操作在 200ms 内完成
NFR5: 自动压缩摘要在单次 LLM 调用的延迟内完成
NFR6: API 密钥不会被记录、打印或包含在错误消息中
NFR7: Shell 钩子执行对输入进行清理以防止命令注入
NFR8: 权限系统在执行前强制执行工具访问限制
NFR9: 自定义 canUseTool 回调接收完整的工具上下文用于授权决策
NFR10: 会话文件以仅用户可读写权限（0600）存储
NFR11: 所有 34 个工具在 macOS 13+ 和 Linux（Ubuntu 20.04+）上产生相同行为
NFR12: 核心 SDK 功能不需要 Apple 专属框架
NFR13: CI 流水线在每个 PR 上验证双平台兼容性
NFR14: 文件路径处理是平台感知的（符合 POSIX 标准）
NFR15: Agent 以指数退避方式重试 LLM API 调用（最多 3 次）
NFR16: 预算超限条件产生优雅的错误结果，而非崩溃
NFR17: 工具执行失败被捕获并报告给 Agent，不会终止智能循环
NFR18: 自动压缩在摘要后保持对话连续性
NFR19: MCP 客户端连接处理服务器进程生命周期（启动、崩溃恢复、优雅关闭）
NFR20: Anthropic API 客户端仅通过 POST /v1/messages 通信，支持流式传输
NFR21: 通过可配置的 Base URL 支持自定义 LLM 提供商，无需修改 SDK
NFR22: 核心 Agent 循环和工具系统 API 在 v1.0 冻结，不会有破坏性变更
NFR23: 钩子和 MCP API 标记为演进中的，可能在次要版本之间变更
NFR24: SDK 遵循语义化版本控制（major.minor.patch）
NFR25: Swift SDK 版本独立于 TypeScript SDK 版本

### 附加需求

- 启动模板：Swift SPM 初始化（`swift package init --type library --name OpenAgentSDK`）— 无外部启动模板
- 单一外部依赖：mcp-swift-sdk（DePasqualeOrg/mcp-swift-sdk）用于 MCP stdio/HTTP/SSE
- 自定义 AnthropicClient：基于 URLSession，仅 POST /v1/messages，不使用社区 Anthropic SDK
- Swift 5.9+、macOS 13+、Linux（Ubuntu 20.04+），不使用 Apple 专属框架
- 模块名称：OpenAgentSDK，仅通过 SPM 分发
- 基于 Actor 的并发模型用于所有可变存储和 QueryEngine
- 基于协议的工具系统，支持 Codable 输入解码和 JSON Schema 字典供 LLM 使用
- 类型化错误模型，带关联值（SDKError 枚举）
- 预算追踪，带模型定价查找表
- POSIX shell 执行用于钩子（macOS 使用 Process，Linux 使用 posix_spawn）
- 对话压缩：自动压缩 + 微压缩
- 实现优先级：基础 → 核心引擎 → 工具系统 → 高级工具 → 专业工具 → MCP → 会话与钩子 → 收尾
- 8 个 Actor 存储：SessionStore、TaskStore、TeamStore、MailboxStore、PlanStore、CronStore、TodoStore、AgentRegistry
- 模块边界：Types/（叶子）→ API/ → Core/ → Tools/、Stores/、Hooks/（独立于 Core）
- JSON ↔ Codable 边界：原始 [String: Any] 用于 LLM 通信，Codable 用于 Swift 内部和持久化

### UX 设计需求

_未找到 UX 设计文档 — 这是一个纯 SDK 库，没有用户界面。_

### FR 覆盖映射

FR1: Epic 1 - 通过系统提示词、模型、配置创建 Agent
FR2: Epic 2 - 通过 AsyncStream 流式响应
FR3: Epic 1 - 包含最终结果的阻塞式响应
FR4: Epic 1 - 完整智能循环执行
FR5: Epic 2 - 通过续接提示从 max_tokens 恢复
FR6: Epic 1 - 每次调用的最大轮次
FR7: Epic 2 - 累积 token 使用量和成本追踪
FR8: Epic 2 - 最大预算强制执行与优雅停止
FR9: Epic 2 - 接近上下文限制时自动压缩对话
FR10: Epic 2 - 微压缩大型工具结果（>50k 字符）
FR11: Epic 3 - 注册工具和工具层级
FR12: Epic 3 - 并发只读 / 串行变更工具执行
FR13: Epic 3 - 使用 defineTool() 和 Codable 的自定义工具
FR14: Epic 3 - LLM 的 JSON Schema + Swift 的 Codable
FR15: Epic 3 - 三个层级的 34 个内置工具
FR16: Epic 3 - 核心层：Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch
FR17: Epic 4 - 高级层：Agent、SendMessage、Task*、Team*、NotebookEdit
FR18: Epic 5 - 专业层：Worktree、Plan、Cron、LSP、Config、Todo、MCP Resources
FR19: Epic 6 - MCP stdio 传输
FR20: Epic 6 - MCP HTTP/SSE 传输
FR21: Epic 6 - 供外部客户端的进程内 MCP 服务器
FR22: Epic 6 - MCP 工具与内置工具并列
FR23: Epic 7 - 将对话保存到 JSON 存储
FR24: Epic 7 - 加载并恢复已保存的对话
FR25: Epic 7 - 从任何保存点分叉对话
FR26: Epic 7 - 列出、重命名、标记、删除会话
FR27: Epic 7 - 通过 Actor 实现线程安全的会话存储
FR28: Epic 8 - 21 个生命周期事件上的函数钩子
FR29: Epic 8 - 带正则匹配器的 Shell 命令钩子
FR30: Epic 8 - Shell 钩子 JSON stdin/stdout 协议
FR31: Epic 8 - 可配置的钩子超时（默认 30 秒）
FR32: Epic 8 - 六种权限模式
FR33: Epic 8 - 自定义 canUseTool 授权回调
FR34: Epic 8 - 基于权限的工具访问控制
FR35: Epic 4 - 通过 Agent 工具生成子 Agent
FR36: Epic 4 - Agent 间 SendMessage 通信
FR37: Epic 4 - 任务管理工具（Create/List/Update/Get/Stop/Output）
FR38: Epic 4 - 团队管理工具（Create/Delete）
FR39: Epic 1 - 环境变量配置
FR40: Epic 1 - 编程式配置结构体
FR41: Epic 1 - 通过自定义 Base URL 的多个 LLM 提供商
FR42: Epic 4 - TaskStore 用于任务状态管理
FR43: Epic 4 - TeamStore 用于团队状态管理
FR44: Epic 5 - WorktreeStore
FR45: Epic 5 - PlanStore
FR46: Epic 5 - CronStore
FR47: Epic 5 - TodoStore
FR48: Epic 5 - 基于 Actor 的线程安全存储
FR49: Epic 9 - Swift-DocC API 文档
FR50: Epic 9 - 所有功能的可运行代码示例
FR51: Epic 9 - 包含快速入门指南的 README

## Epic 列表

### Epic 1: 基础设施与 Agent 设置
开发者可以创建配置好的 Agent，发送提示词，并通过完整的智能循环接收响应。SDK 通过 SPM 初始化，环境变量可用，编程式配置可用。这是"Hello World"级 Epic — 完成后，开发者拥有一个能与 LLM 对话的工作 Agent。
**覆盖的 FR：** FR1、FR3、FR4、FR6、FR39、FR40、FR41

### Epic 2: 流式响应与生产就绪 Agent
开发者可以通过 AsyncStream 实时流式接收 Agent 响应，追踪 token 使用量和成本，强制执行预算，从 max_tokens 限制中恢复，并自动压缩对话。Agent 具备优雅的错误处理和资源管理能力，达到生产就绪状态。
**覆盖的 FR：** FR2、FR5、FR7、FR8、FR9、FR10

### Epic 3: 工具系统与核心工具
开发者可以向 Agent 注册内置工具和自定义工具。工具系统支持 Codable 输入类型、供 LLM 使用的 JSON Schema 定义、只读工具的并发执行和变更工具的串行执行。全部 10 个核心工具（Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch）均已实现并可用。
**覆盖的 FR：** FR11、FR12、FR13、FR14、FR15、FR16

### Epic 4: 多 Agent 编排
开发者的 Agent 可以生成子 Agent 执行委托任务，通过 SendMessage 在 Agent 间通信，并通过专用存储管理任务和团队。高级工具层级（Agent、SendMessage、Task*、Team*、NotebookEdit）完成，支持多 Agent 工作流。
**覆盖的 FR：** FR17、FR35、FR36、FR37、FR38、FR42、FR43

### Epic 5: 专业工具与管理存储
开发者的 Agent 可以访问完整的专业工具层级（Worktree、Plan、Cron、LSP、Config、Todo、MCP Resources）及所有后端 Actor 存储（WorktreeStore、PlanStore、CronStore、TodoStore）。完整的 34 个工具套件现已可用。
**覆盖的 FR：** FR18、FR44、FR45、FR46、FR47、FR48

### Epic 6: MCP 协议集成
开发者可以通过 stdio 和 HTTP/SSE 传输连接外部 MCP 服务器，并暴露进程内工具供外部 MCP 客户端使用。MCP 工具在 Agent 执行期间与内置工具无缝集成。
**覆盖的 FR：** FR19、FR20、FR21、FR22

### Epic 7: 会话持久化
开发者可以将 Agent 对话保存到 JSON 文件，加载并恢复它们，从任何点分叉，并通过线程安全的基于 Actor 的存储管理会话（列出、重命名、标记、删除）。
**覆盖的 FR：** FR23、FR24、FR25、FR26、FR27

### Epic 8: 钩子系统与权限控制
开发者可以在 21 个 Agent 生命周期事件上注册函数和 Shell 钩子，通过六种权限模式控制工具执行，并提供自定义授权回调。钩子支持可配置的超时时间，Shell 命令通过 JSON stdin/stdout 通信。
**覆盖的 FR：** FR28、FR29、FR30、FR31、FR32、FR33、FR34

### Epic 9: 文档与开发者体验
开发者拥有完整的 Swift-DocC 生成的 API 文档（覆盖所有符号）、每个主要功能领域的可运行代码示例，以及一份能在 15 分钟内让开发者从 SPM 依赖到运行 Agent 的 README 快速入门指南。
**覆盖的 FR：** FR49、FR50、FR51

---

## Epic 1: 基础设施与 Agent 设置

开发者可以创建配置好的 Agent，发送提示词，并通过完整的智能循环接收响应。SDK 通过 SPM 初始化，环境变量可用，编程式配置可用。

### Story 1.1: SPM 包与核心类型系统

作为 Swift 开发者，
我希望将 OpenAgentSDK 作为 SPM 依赖添加并导入到我的项目中，
以便我可以开始使用该 SDK 构建人工智能应用。

**验收标准：**

**给定** 一个带有 Package.swift 的 Swift 项目
**当** 开发者添加 `.package(url: "...", from: "1.0.0")` 和 `.target(name: "App", dependencies: ["OpenAgentSDK"])`
**则** `import OpenAgentSDK` 编译无错误
**且** 模块暴露核心类型：SDKMessage、SDKError、TokenUsage、ToolProtocol、PermissionMode、ThinkingConfig、AgentOptions、QueryResult、ModelInfo

**给定** SDK 已导入
**当** 开发者引用 SDKError 的各个 case
**则** 所有错误域可用：apiError、toolExecutionError、budgetExceeded、maxTurnsExceeded、sessionError、mcpConnectionError、permissionDenied、abortError
**且** 每个 case 都有带描述信息的关联值

### Story 1.2: 自定义 Anthropic API 客户端

作为开发者，
我希望 SDK 使用自定义客户端与 Anthropic API 通信，
以便我的 Agent 可以发送消息并接收响应，而无需依赖社区 SDK。

**验收标准：**

**给定** 一个配置了 API 密钥的 AnthropicClient
**当** 客户端发送带有有效消息的 POST /v1/messages 请求
**则** API 返回包含内容块和使用量信息的响应
**且** API 密钥不会被记录、打印或包含在错误消息中（NFR6）

**给定** 一个配置了自定义 Base URL 的 AnthropicClient
**当** 客户端发出 API 请求
**则** 请求被发送到自定义 Base URL 而非 api.anthropic.com（FR41）

**给定** API 返回流式响应
**当** 客户端处理 SSE 流
**则** 内容块在到达时被增量解析
**且** 流式传输在 API 响应到达后 2 秒内开始（NFR1）

### Story 1.3: SDK 配置与环境变量

作为开发者，
我希望通过环境变量或编程式结构体配置 SDK，
以便我可以设置 API 密钥、模型选择和 Base URL 而无需硬编码值。

**验收标准：**

**给定** 环境变量 CODEANY_API_KEY、CODEANY_MODEL 和 CODEANY_BASE_URL 已设置
**当** SDK 初始化其配置
**则** 值从 ProcessInfo.processInfo（macOS）/ getenv（Linux）读取并应用（FR39）

**给定** 开发者以编程方式创建 SDKConfiguration 结构体
**当** 他们设置 apiKey、model、baseURL、maxTurns 和 maxTokens
**则** 配置被应用到 Agent，不依赖任何环境变量（FR40）

**给定** 开发者仅设置 apiKey 和 model
**当** 访问其余配置属性
**则** 应用合理的默认值：maxTurns=10、maxTokens=16384、model="claude-sonnet-4-6"

### Story 1.4: Agent 创建与配置

作为开发者，
我希望通过系统提示词和配置选项创建 Agent，
以便我可以为特定用例自定义 Agent 行为。

**验收标准：**

**给定** 有效的 AgentOptions，包含系统提示词、模型和 maxTurns
**当** 开发者调用 createAgent(options:)
**则** 返回一个具有指定配置的 Agent 实例（FR1）

**给定** 使用默认选项创建的 Agent
**当** 开发者检查 Agent 的配置
**则** 应用默认值：model="claude-sonnet-4-6"、maxTurns=10、maxTokens=16384

**给定** 使用自定义系统提示词创建的 Agent
**当** Agent 处理一个提示词
**则** 系统提示词作为第一条消息包含在 API 请求中

### Story 1.5: 智能循环与阻塞式响应

作为开发者，
我希望向 Agent 发送提示词并接收最终的完整响应，
以便我可以在单次调用中获取完全处理后的 Agent 结果。

**验收标准：**

**给定** 未注册任何工具的 Agent
**当** 开发者调用 agent.prompt("解释 Swift 并发")
**则** 智能循环执行：发送消息给 LLM、接收响应、返回最终结果（FR4）
**且** 响应包含助手的文本内容和使用量统计（FR3）

**给定** 配置了 maxTurns=5 的 Agent
**当** 智能循环执行并达到 5 轮
**则** 循环停止并返回带有 maxTurnsExceeded 状态的结果（FR6）

**给定** LLM 返回 stop_reason="end_turn" 的响应
**当** 智能循环处理此响应
**则** 循环终止并返回完整响应

---

## Epic 2: 流式响应与生产就绪 Agent

开发者可以实时流式接收 Agent 响应，追踪成本，强制执行预算，从错误中恢复，并自动压缩对话。

### Story 2.1: 通过 AsyncStream 流式响应

作为开发者，
我希望将 Agent 响应作为实时事件流消费，
以便我可以在应用 UI 中展示渐进式结果。

**验收标准：**

**给定** 使用有效配置创建的 Agent
**当** 开发者调用 agent.stream("分析这段代码")
**则** 立即返回 AsyncStream<SDKMessage>（FR2）
**且** SDKMessage 事件在从 LLM 到达时被产出

**给定** 活跃的 AsyncStream<SDKMessage>
**当** Agent 处理流式响应
**则** 流发出类型化事件：文本增量、工具使用开始、工具结果、使用量更新和完成
**且** 开发者可以使用 `case let` 对 SDKMessage 的各个 case 进行模式匹配

**给定** 遇到 API 错误的活跃流
**当** 从 LLM 接收到错误
**则** 在流上发出错误事件，流优雅终止

### Story 2.2: Token 使用量与成本追踪

作为开发者，
我希望追踪每次调用的累积 token 使用量和预估成本，
以便我可以监控和控制我的 API 支出。

**验收标准：**

**给定** 正在执行智能循环的 Agent
**当** 每次 LLM API 调用完成
**则** 输入和输出 token 计数在使用量追踪器中累积（FR7）
**且** 使用 MODEL_PRICING 查找表计算预估成本

**给定** 完成的 Agent 调用
**当** 开发者检查 QueryResult
**则** 总输入 token、输出 token 和以美元计的预估成本可用

**给定** Agent 依次使用不同模型
**当** 计算成本
**则** 每个模型的定价根据其 token 成本正确应用

### Story 2.3: 预算强制执行

作为开发者，
我希望设置每次 Agent 调用的最大美元预算，
以便失控的 Agent 循环不会耗尽我的 API 额度。

**验收标准：**

**给定** 配置了 maxBudgetUSD=0.50 的 Agent
**当** 执行期间累积成本超过 $0.50
**则** 智能循环立即停止（FR8）
**且** 返回带有成本摘要和使用轮次的优雅错误结果（NFR16）
**且** 应用不会崩溃

**给定** 未配置预算限制的 Agent
**当** Agent 执行
**则** 追踪成本但不执行预算检查

### Story 2.4: LLM API 重试与 max_tokens 恢复

作为开发者，
我希望 Agent 重试失败的 API 调用并从 max_tokens 响应中恢复，
以便瞬态错误和上下文限制不会终止我的 Agent 会话。

**验收标准：**

**给定** 因瞬态错误（429、500、502、503）失败的 LLM API 调用
**当** 错误被重试机制捕获
**则** 请求以指数退避方式重试，最多 3 次（NFR15）
**且** SDK 不会崩溃或在错误消息中暴露 API 密钥

**给定** stop_reason="max_tokens" 的 LLM 响应
**当** 智能循环处理此响应
**则** 发送续接提示以恢复生成（FR5）
**且** 对话从截断处继续
**且** 在返回部分结果前最多重试 3 次

### Story 2.5: 对话自动压缩

作为开发者，
我希望 Agent 在接近上下文限制时自动压缩对话，
以便长对话可以无需人工干预地继续。

**验收标准：**

**给定** 接近上下文窗口阈值的 Agent 对话
**当** 下一次 LLM 调用将超出限制
**则** 通过 LLM 调用对对话进行摘要，并用摘要替换历史记录（FR9）
**且** 摘要后保持对话连续性（NFR18）

**给定** 自动压缩操作正在进行
**当** 压缩完成
**则** 压缩后的对话包含一个注明压缩事件的系统消息
**且** 智能循环使用压缩后的历史继续

### Story 2.6: 工具结果微压缩

作为开发者，
我希望 Agent 自动压缩大型工具结果，
以便单个工具输出不会消耗过多上下文。

**验收标准：**

**给定** 返回超过 50,000 字符结果的工具执行
**当** 结果被添加到对话中
**则** 结果被自动微压缩为保留关键信息的摘要（FR10）
**且** 压缩后的结果被清楚地标记为已截断

**给定** 50,000 字符以下的工具结果
**当** 结果被添加到对话中
**则** 不执行微压缩，包含完整结果

---

## Epic 3: 工具系统与核心工具

开发者可以注册内置工具和自定义工具。工具系统支持 Codable 输入类型、JSON Schema 和并发/串行执行。全部 10 个核心工具已实现。

### Story 3.1: 工具协议与注册表

作为开发者，
我希望向 Agent 注册单个工具或工具层级，
以便 LLM 知道哪些工具可用于执行。

**验收标准：**

**给定** 未注册任何工具的 Agent
**当** 开发者注册一个符合 ToolProtocol 的单个工具
**则** 工具出现在发送给 LLM 的工具定义中（FR11）

**给定** 已注册工具的 Agent
**当** 开发者注册"core"工具层级
**则** 所有 10 个核心工具一次性注册
**且** 工具定义包含每个工具的名称、描述和 inputSchema（FR15）

**给定** 已注册工具的 Agent
**当** 开发者按名称模式过滤工具
**则** 仅匹配的工具包含在工具定义中

### Story 3.2: 使用 defineTool() 的自定义工具定义

作为开发者，
我希望创建带有 Codable 输入类型和基于闭包执行的自定义工具，
以便我可以用领域特定能力扩展我的 Agent。

**验收标准：**

**给定** 定义工具输入的 Codable 结构体（例如 struct CSVInput: Codable）
**当** 开发者使用名称、描述、JSON Schema 和执行闭包调用 defineTool
**则** 创建一个符合 ToolProtocol 的工具（FR13）
**且** 工具在执行闭包中接受 Codable 解码的输入
**且** JSON Schema 提供给 LLM 用于工具调用（FR14）

**给定** 使用 defineTool() 定义的自定义工具
**当** LLM 使用 JSON 输入请求该工具
**则** JSON 被解码为 Codable 结构体并传递给执行闭包
**且** 工具的 ToolResult 返回给智能循环

### Story 3.3: 带并发/串行调度的工具执行器

作为开发者，
我希望 Agent 并发执行只读工具并串行执行变更工具，
以便文件系统操作安全的同时最大化吞吐量。

**验收标准：**

**给定** 在单轮中请求多个只读工具（Read、Glob、Grep）的 Agent
**当** 工具执行器调度它们
**则** 最多 10 个只读工具通过 TaskGroup 并发执行（FR12、NFR3）
**且** 所有结果被收集并反馈给 LLM

**给定** 在单轮中请求变更工具（Write、Edit、Bash）的 Agent
**当** 工具执行器调度它们
**则** 变更工具按顺序串行执行
**且** 每个变更完成后才开始下一个

**给定** 因异常而失败的工具执行
**当** 错误被工具执行器捕获
**则** 错误被捕获为 is_error=true 的 ToolResult 并返回给 Agent（NFR17）
**且** 智能循环继续运行而不崩溃

### Story 3.4: 核心文件工具（Read、Write、Edit）

作为开发者，
我希望我的 Agent 可以在文件系统上读取、创建和修改文件，
以便它可以处理源代码和配置文件。

**验收标准：**

**给定** Read 工具已注册
**当** LLM 请求读取有效路径的文件
**则** 文件内容以字符串形式返回
**且** 1MB 以下的文件操作在 500ms 内完成（NFR2）

**给定** Write 工具已注册
**当** LLM 请求将内容写入文件路径
**则** 文件被创建或以指定内容覆盖
**且** 如果父目录不存在则自动创建

**给定** Edit 工具已注册
**当** LLM 请求替换现有文件中的字符串
**则** 仅匹配的部分被替换，文件被更新
**且** 如果未找到旧字符串则编辑优雅失败

**给定** 任何操作路径的文件工具
**当** 路径包含特殊字符或是相对路径
**则** 使用符合 POSIX 标准的处理正确解析路径（NFR14）

### Story 3.5: 核心搜索工具（Glob、Grep）

作为开发者，
我希望我的 Agent 可以按名称模式搜索文件和搜索文件内容，
以便它可以在项目中查找相关文件和代码。

**验收标准：**

**给定** Glob 工具已注册
**当** LLM 请求 glob 模式如 "**/*.swift"
**则** 返回按修改时间排序的匹配文件路径
**且** 对于典型项目大小搜索在 500ms 内完成（NFR2）

**给定** Grep 工具已注册
**当** LLM 请求在文件中搜索正则表达式模式
**则** 返回带有文件路径和行号的匹配行
**且** 搜索支持文件类型过滤和目录范围限定

### Story 3.6: 核心系统工具（Bash、AskUser、ToolSearch）

作为开发者，
我希望我的 Agent 可以执行 Shell 命令、向我提问以及搜索可用工具，
以便它可以执行系统操作并在执行期间与我交互。

**验收标准：**

**给定** Bash 工具已注册
**当** LLM 请求执行 Shell 命令
**则** 命令通过 POSIX shell 执行，捕获 stdout/stderr
**且** 命令具有可配置的超时时间和工作目录

**给定** AskUser 工具已注册
**当** LLM 在执行期间需要用户输入
**则** 显示问题并将用户的响应返回给 Agent

**给定** ToolSearch 工具已注册
**当** LLM 请求搜索可用工具
**则** 返回匹配的工具名称和描述，帮助 LLM 选择合适的工具

### Story 3.7: 核心网络工具（WebFetch、WebSearch）

作为开发者，
我希望我的 Agent 可以获取网页内容和执行网络搜索，
以便它可以访问互联网上的信息。

**验收标准：**

**给定** WebFetch 工具已注册
**当** LLM 请求获取 URL
**则** 页面内容以文本或 Markdown 形式获取并返回
**且** 请求具有可配置的超时时间

**给定** WebSearch 工具已注册
**当** LLM 请求网络搜索查询
**则** 返回带有标题、URL 和摘要的搜索结果
**且** 结果限制为可配置的最大数量

---

## Epic 4: 多 Agent 编排

开发者的 Agent 可以生成子 Agent，通过消息通信，并通过专用存储管理任务和团队。

### Story 4.1: TaskStore 与 MailboxStore 基础

作为开发者，
我希望 Agent 通过线程安全的存储管理任务和交换消息，
以便多 Agent 工作流可以可靠地协调。

**验收标准：**

**给定** TaskStore Actor
**当** 任务被并发创建、更新、列出和获取
**则** 所有操作通过 Actor 隔离实现线程安全（FR42、FR48）
**且** 任务状态转换（pending → in_progress → completed）被强制执行

**给定** MailboxStore Actor
**当** Agent 之间互相发送消息
**则** 消息按接收者排队并按顺序投递
**且** 存储安全处理来自多个 Agent 的并发访问

### Story 4.2: TeamStore 与 AgentRegistry

作为开发者，
我希望 Agent 可以创建团队和注册子 Agent，
以便我可以编排协同工作的 Agent 组。

**验收标准：**

**给定** TeamStore Actor
**当** 创建带有成员的团队以及删除团队
**则** 团队状态以线程安全方式管理（FR43、FR48）
**且** 可以列出团队成员并识别其角色

**给定** AgentRegistry Actor
**当** 子 Agent 被生成并注册自身
**则** 注册表按名称和 ID 追踪所有活跃 Agent
**且** Agent 可以通过注册表互相发现

### Story 4.3: Agent 工具（子 Agent 生成）

作为开发者，
我希望我的 Agent 可以生成子 Agent 执行委托任务，
以便复杂任务可以跨专业 Agent 并行化。

**验收标准：**

**给定** Agent 工具已注册
**当** 父 Agent 请求使用特定提示词生成子 Agent
**则** 创建新 Agent 并执行委托任务（FR35）
**且** 子 Agent 的结果返回给父 Agent

**给定** 正在执行委托任务的子 Agent
**当** 子 Agent 完成或失败
**则** 父 Agent 接收结果或错误并继续其循环

### Story 4.4: SendMessage 工具

作为开发者，
我希望 Agent 可以通过发送消息与团队成员通信，
以便多 Agent 团队可以协调其工作。

**验收标准：**

**给定** SendMessage 工具已注册且存在团队
**当** Agent 按名称向队友发送消息
**则** 消息通过 MailboxStore 投递（FR36）
**且** 接收 Agent 可以读取和处理消息

**给定** Agent 发送广播消息
**当** 消息被发送给所有队友
**则** 每个队友在其邮箱中收到消息

### Story 4.5: 任务工具（Create/List/Update/Get/Stop/Output）

作为开发者，
我希望我的 Agent 使用专用工具管理任务，
以便复杂的多步骤工作可以被追踪和协调。

**验收标准：**

**给定** TaskCreate 工具已注册
**当** LLM 请求创建带有标题和描述的任务
**则** 在 TaskStore 中创建状态为 "pending" 的新任务（FR37）

**给定** TaskList 工具已注册
**当** LLM 请求列出任务
**则** 返回所有任务及其状态和负责人

**给定** TaskUpdate 工具已注册
**当** LLM 请求将任务状态更新为 "in_progress" 或 "completed"
**则** 任务状态在 TaskStore 中更新

**给定** TaskGet、TaskStop 和 TaskOutput 工具已注册
**当** LLM 请求任务详情、停止任务或获取输出
**则** 每个操作对 TaskStore 正确执行

### Story 4.6: 团队工具（Create/Delete）

作为开发者，
我希望我的 Agent 可以创建和管理 Agent 团队，
以便我可以组织多 Agent 工作流。

**验收标准：**

**给定** TeamCreate 工具已注册
**当** LLM 请求创建带有名称和描述的团队
**则** 在 TeamStore 中创建新团队（FR38）

**给定** TeamDelete 工具已注册
**当** LLM 请求删除团队
**则** 团队及其状态从 TeamStore 中移除
**且** 所有活跃团队成员收到删除通知

### Story 4.7: NotebookEdit 工具

作为开发者，
我希望我的 Agent 可以编辑 Jupyter Notebook 单元格，
以便它可以处理数据科学工作流。

**验收标准：**

**给定** NotebookEdit 工具已注册
**当** LLM 请求编辑 .ipynb 文件中的单元格
**则** 指定的单元格被替换、插入或删除（FR17）

**给定** edit_mode=insert 的 NotebookEdit 工具
**当** LLM 请求插入新单元格
**则** 在指定位置添加新的代码或 Markdown 单元格

---

## Epic 5: 专业工具与管理存储

开发者的 Agent 可以访问专业工具及所有后端 Actor 存储。

### Story 5.1: WorktreeStore 与 Worktree 工具

作为开发者，
我希望我的 Agent 可以管理 Git Worktree，
以便它可以在仓库的隔离副本上工作。

**验收标准：**

**给定** WorktreeStore Actor 和 WorktreeEnter/Exit 工具已注册
**当** LLM 请求使用给定名称进入 Worktree
**则** 创建新的 Git Worktree，工作目录切换到它（FR44）
**且** 存储以线程安全方式追踪活跃的 Worktree 状态（FR48）

**给定** 活跃的 Worktree
**当** LLM 请求退出 Worktree
**则** Worktree 可选地保留或移除，会话返回原始目录

### Story 5.2: PlanStore 与 Plan 工具

作为开发者，
我希望我的 Agent 可以创建和管理实施计划，
以便复杂任务可以被分解为结构化步骤。

**验收标准：**

**给定** PlanStore Actor 和 PlanEnter/Exit 工具已注册
**当** LLM 请求进入计划模式
**则** 在 PlanStore 中创建计划，Agent 进入计划审查模式（FR45）
**且** 计划状态转换以线程安全方式管理（FR48）

**给定** 活跃的计划
**当** LLM 请求退出计划模式
**则** 计划被最终确定，Agent 返回正常执行模式

### Story 5.3: CronStore 与 Cron 工具

作为开发者，
我希望我的 Agent 可以创建和管理定时任务，
以便它可以设置周期性或一次性提醒。

**验收标准：**

**给定** CronStore Actor 和 CronCreate/Delete/List 工具已注册
**当** LLM 请求创建带有调度和提示词的定时任务
**则** 任务连同其 cron 表达式存储在 CronStore 中（FR46）
**且** 定时任务状态以线程安全方式管理（FR48）

**给定** 现有的定时任务
**当** LLM 请求列出或删除它们
**则** 操作对 CronStore 正确执行

### Story 5.4: TodoStore 与 TodoWrite 工具

作为开发者，
我希望我的 Agent 可以管理待办事项，
以便它可以追踪和更新任务进度。

**验收标准：**

**给定** TodoStore Actor 和 TodoWrite 工具已注册
**当** LLM 请求写入待办事项
**则** 事项被存储在 TodoStore 中管理（FR47）
**且** 待办事项状态以线程安全方式管理（FR48）

**给定** 现有的待办事项
**当** LLM 请求更新完成状态或删除事项
**则** TodoStore 正确反映变更

### Story 5.5: LSP 工具

作为开发者，
我希望我的 Agent 可以与语言服务器协议（LSP）服务器交互，
以便它可以获得代码智能功能，如跳转到定义和查找引用。

**验收标准：**

**给定** LSP 工具已注册且配置了 LSP 服务器
**当** LLM 请求跳转到定义或查找引用操作
**则** 查询 LSP 服务器并返回结果（FR18）

**给定** 未配置服务器的 LSP 工具
**当** LLM 请求 LSP 操作
**则** 返回描述性错误，指示没有可用的服务器

### Story 5.6: Config 工具与 RemoteTrigger 工具

作为开发者，
我希望我的 Agent 可以管理 SDK 配置和触发远程操作，
以便它可以调整设置并与外部系统交互。

**验收标准：**

**给定** Config 工具已注册
**当** LLM 请求读取或更新 SDK 配置
**则** 配置变更被应用并持久化（FR18）

**给定** RemoteTrigger 工具已注册
**当** LLM 请求触发远程操作
**则** 触发器被执行并返回结果（FR18）

### Story 5.7: MCP 资源工具（ListMcpResources、ReadMcpResource）

作为开发者，
我希望我的 Agent 可以列出和读取 MCP 资源，
以便它可以访问 MCP 服务器暴露的资源。

**验收标准：**

**给定** ListMcpResources 工具已注册且已连接 MCP 服务器
**当** LLM 请求列出可用资源
**则** 返回 MCP 服务器暴露的资源（FR18）

**给定** ReadMcpResource 工具已注册
**当** LLM 请求读取特定的 MCP 资源
**则** 从 MCP 服务器获取资源内容并返回

---

## Epic 6: MCP 协议集成

开发者可以连接外部 MCP 服务器并通过 MCP 暴露进程内工具。

### Story 6.1: MCP 客户端管理器与 Stdio 传输

作为开发者，
我希望通过 stdio 传输连接外部 MCP 服务器，
以便我的 Agent 可以使用外部进程提供的工具。

**验收标准：**

**给定** 配置了 stdio 服务器配置的 MCPClientManager Actor
**当** 管理器建立连接
**则** 外部进程启动，MCP 握手完成（FR19）
**且** 服务器进程生命周期被管理（启动、崩溃恢复、优雅关闭）（NFR19）

**给定** 通过 stdio 连接的 MCP 服务器
**当** 服务器进程崩溃
**则** MCPClientManager 检测到故障并尝试恢复或报告断开连接

### Story 6.2: MCP HTTP/SSE 传输

作为开发者，
我希望通过 HTTP/SSE 传输连接外部 MCP 服务器，
以便我的 Agent 可以使用远程服务提供的工具。

**验收标准：**

**给定** 配置了 HTTP/SSE 服务器配置的 MCPClientManager Actor
**当** 管理器建立连接
**则** HTTP 连接打开，MCP 握手完成（FR20）
**且** 接收服务器发起消息的 SSE 事件

**给定** 通过 HTTP/SSE 连接的 MCP 服务器
**当** 连接断开
**则** 管理器优雅处理重连而不崩溃

### Story 6.3: 进程内 MCP 服务器

作为开发者，
我希望将 Agent 的工具暴露为 MCP 服务器，
以便外部 MCP 客户端可以使用我的工具。

**验收标准：**

**给定** 带有已注册工具的 InProcessMCPServer
**当** 外部 MCP 客户端连接
**则** 服务器通过 MCP 协议暴露工具（FR21）
**且** 来自客户端的工具执行请求被分派到已注册的工具

### Story 6.4: MCP 工具与 Agent 集成

作为开发者，
我希望 MCP 工具在 Agent 执行期间与内置工具一起出现，
以便 Agent 无缝使用本地和远程工具。

**验收标准：**

**给定** 同时拥有内置工具和已连接 MCP 服务器的 Agent
**当** 工具池被组装
**则** MCP 工具以 `mcp__{serverName}__{toolName}` 的命名空间包含在工具定义中（FR22）

**给定** 有 MCP 工具可用的正在执行的 Agent
**当** LLM 请求 MCP 工具
**则** 工具通过 MCPClientManager 分派，结果返回给智能循环

---

## Epic 7: 会话持久化

开发者可以保存、加载、分叉和管理 Agent 对话，具备线程安全的存储。

### Story 7.1: SessionStore Actor 与 JSON 持久化

作为开发者，
我希望将 Agent 对话保存到 JSON 文件，
以便对话状态可以在应用重启后持久保存。

**验收标准：**

**给定** SessionStore Actor
**当** 使用会话 ID 保存对话
**则** 转录被序列化到 `~/.open-agent-sdk/sessions/{sessionId}/transcript.json`（FR23）
**且** 文件以仅用户权限（0600）存储（NFR10）
**且** 500 条消息以下的对话操作在 200ms 内完成（NFR4）

**给定** SessionStore 处理并发保存请求
**当** 多个 Agent 同时保存
**则** 所有保存正确完成，无数据损坏（FR27）

### Story 7.2: 会话加载与恢复

作为开发者，
我希望加载并恢复之前保存的对话，
以便 Agent 可以从上次中断的地方继续。

**验收标准：**

**给定** 之前保存的会话
**当** 开发者按 ID 加载会话
**则** 消息历史被反序列化，Agent 以完整上下文恢复（FR24）
**且** 加载的消息与当前智能循环兼容

### Story 7.3: 会话分叉

作为开发者，
我希望从任何保存点分叉对话，
以便我可以探索替代路径而不丢失原始对话。

**验收标准：**

**给定** 带有多条消息的已保存会话
**当** 开发者从特定消息索引分叉
**则** 使用分叉点之前的消息创建新会话（FR25）
**且** 原始会话不变
**且** 分叉的会话具有新的唯一 ID

### Story 7.4: 会话管理（列出、重命名、标记、删除）

作为开发者，
我希望可以列出、重命名、标记和删除已保存的会话，
以便我可以组织和管理我的对话历史。

**验收标准：**

**给定** 多个已保存的会话
**当** 开发者列出会话
**则** 返回所有会话及其元数据（ID、日期、消息数、标签）（FR26）

**给定** 现有会话
**当** 开发者重命名或标记会话
**则** 会话元数据被更新，不修改转录

**给定** 现有会话
**当** 开发者删除会话
**则** 会话目录及其所有文件被移除

---

## Epic 8: 钩子系统与权限控制

开发者可以在生命周期事件上注册钩子并通过权限模式控制工具执行。

### Story 8.1: 钩子事件类型与注册表

作为开发者，
我希望在 21 个 Agent 生命周期事件上注册钩子，
以便我可以观察和响应 Agent 行为。

**验收标准：**

**给定** HookRegistry Actor
**当** 开发者在生命周期事件（如 PostToolUse）上注册函数钩子
**则** 钩子被存储，在事件触发时将被调用（FR28）
**且** 所有 21 个事件可作为类型化枚举 case 使用，支持编译时穷举检查

**给定** 在 PreToolUse 上注册的钩子
**当** Agent 即将执行工具
**则** 钩子被调用，传入工具名称和输入
**且** 钩子的返回值可以允许、拒绝或修改执行

### Story 8.2: 函数钩子注册与执行

作为开发者，
我希望在生命周期事件上注册异步函数钩子，
以便我可以在 Agent 执行期间运行自定义逻辑。

**验收标准：**

**给定** 在 SessionStart 上注册的函数钩子
**当** 新的 Agent 会话开始
**则** 钩子接收会话上下文并可以执行初始化逻辑

**给定** 在同一事件上注册的多个钩子
**当** 事件触发
**则** 所有钩子按注册顺序执行
**且** 每个钩子接收前一个钩子的输出（如适用）

### Story 8.3: Shell 钩子执行

作为开发者，
我希望注册带正则匹配器的 Shell 命令钩子，
以便我可以运行外部脚本以响应 Agent 事件。

**验收标准：**

**给定** 在 PostToolUse 上注册了带正则匹配器的 Shell 钩子
**当** 事件触发且工具名称匹配正则表达式
**则** 通过 POSIX 进程生成执行 Shell 命令（FR29）
**且** 钩子通过 stdin 接收 JSON 格式的事件数据，通过 stdout 返回 JSON 输出（FR30）

**给定** 30 秒超时的 Shell 钩子
**当** Shell 命令超过超时时间
**则** 进程被终止并记录超时错误（FR31）

**给定** 包含特殊字符的 Shell 钩子输入
**当** 输入传递给 Shell 命令
**则** 输入被清理以防止命令注入（NFR7）

### Story 8.4: 权限模式

作为开发者，
我希望设置六种权限模式之一来控制工具执行，
以便我可以限制 Agent 允许执行的操作。

**验收标准：**

**给定** 配置了 permissionMode = .bypassPermissions 的 Agent
**当** LLM 请求任何工具
**则** 工具直接执行，无需提示（FR32）

**给定** 配置了 permissionMode = .default 的 Agent
**当** 请求变更工具（Write、Edit、Bash）
**则** 权限系统强制执行默认授权流程（FR34、NFR8）

**给定** 所有六种权限模式（default、acceptEdits、bypassPermissions、plan、dontAsk、auto）
**当** 开发者选择每种模式
**则** 权限行为与模式规范匹配

### Story 8.5: 自定义授权回调

作为开发者，
我希望提供自定义的 canUseTool 回调，
以便我可以为工具执行实现自己的授权逻辑。

**验收标准：**

**给定** 带有自定义 canUseTool 闭包的 Agent
**当** LLM 请求执行工具
**则** 闭包被调用，传入工具定义和输入（FR33、NFR9）
**且** 闭包的 CanUseToolResult 决定是允许、拒绝还是提示用户

**给定** 拒绝执行的 canUseTool 回调
**当** LLM 请求被拒绝的工具
**则** 工具不执行，向 Agent 返回权限拒绝错误

---

## Epic 9: 文档与开发者体验

开发者拥有完整的 API 文档、可运行的示例和快速入门 README。

### Story 9.1: Swift-DocC API 文档

作为开发者，
我希望有全面的 Swift-DocC 生成的 API 文档，
以便我可以理解 SDK 中的每个公共类型、方法和属性。

**验收标准：**

**给定** 带有 DocC 注释的 SDK 源代码
**当** Swift-DocC 生成文档
**则** 所有公共类型、协议、方法和属性都有文档（FR49）
**且** 文档包含关键 API 的使用示例

### Story 9.2: README 与快速入门指南

作为开发者，
我希望有包含快速入门指南的 README，
以便我可以在 15 分钟内从 SPM 依赖到运行 Agent。

**验收标准：**

**给定** 仓库根目录中的 README.md
**当** 新开发者阅读快速入门部分
**则** 他们可以添加 SPM 依赖、配置 API 密钥、创建 Agent 并获取响应（FR51）
**且** 对于 Swift 开发者，整个过程在 15 分钟以内

**给定** README
**当** 开发者查找高级用法
**则** 提供指向示例和 DocC 文档的链接

### Story 9.3: 可运行的代码示例

作为开发者，
我希望为所有主要功能领域提供可运行的代码示例，
以便我可以通过修改真实代码来学习。

**验收标准：**

**给定** Examples/ 目录
**当** 开发者编译并运行任何示例
**则** 编译无错误并演示文档描述的功能（FR50）

**给定** 以下示例存在：
- BasicAgent：Agent 创建、单次提示、响应处理
- StreamingAgent：AsyncStream 消费、事件模式匹配
- CustomTools：defineTool()、Codable 输入、JSON Schema
- MCPIntegration：连接 MCP 服务器、暴露进程内工具
- SessionsAndHooks：保存/加载会话、注册钩子
**当** 开发者运行每个示例
**则** 每个示例端到端演示其功能领域
