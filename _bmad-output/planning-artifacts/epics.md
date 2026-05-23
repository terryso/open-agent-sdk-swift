---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-10-epic-design
  - step-10-story-creation
  - step-10-final-validation
  - step-16-epic-design
  - step-16-story-creation
  - step-21-epic-design
  - step-22-epic-design
  - step-23-epic-design
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

### 功能需求（高级能力）

FR52: 开发者可以注册、查找、发现和执行技能（Skills），技能是包含提示词模板、工具限制和模型覆盖的高层抽象——用户场景：开发者希望通过一个 `/commit` 命令让 Agent 自动分析变更并生成规范提交，而非手动编写多步提示
FR53: SDK 提供 5 个内置技能（Commit、Review、Simplify、Debug、Test），每个技能封装特定工作流的提示词模板和工具范围——用户场景：开发者输入 `/review` 即可获得多维度代码审查，无需自行编排 Read、Grep、Bash 工具链
FR54: 技能通过 SkillTool 作为工具被 LLM 发现和执行，支持工具限制和模型覆盖——用户场景：LLM 在对话中自动识别用户意图并调用合适的技能，而非仅暴露原始工具
FR55: SDK 维护文件内容 LRU 缓存（可配置条目数和大小限制），避免重复文件 I/O——用户场景：Agent 在一次会话中多次读取同一文件时，响应延迟从磁盘 I/O 降低到内存查找
FR56: 文件缓存支持变更检测，写入/编辑操作自动使对应缓存条目失效——用户场景：Agent 先读后写同一文件，写入后再次读取能获取最新内容，不会返回过期缓存
FR57: Agent 自动注入 Git 状态（分支、commits、status、git user）到系统提示——用户场景：开发者问"帮我提交代码"，Agent 已知道当前分支和变更状态，无需手动提供上下文
FR58: SDK 自动发现并加载项目级指令文件（CLAUDE.md、AGENT.md）——用户场景：团队在项目中放置 CLAUDE.md 定义代码规范，Agent 自动遵守这些规范，无需每次在提示中重复
FR59: 开发者可以在 Agent 会话中动态切换 LLM 模型——用户场景：简单问答用快速模型节省成本，复杂推理切换到强力模型，无需重启会话
FR60: 开发者可以中断正在执行的 Agent 查询，获得已生成的部分结果——用户场景：Agent 执行了 5 分钟还在跑，开发者中断后仍能看到前 3 轮的工具调用结果
FR61: SDK 提供可配置的日志级别（none、error、warn、info、debug）——用户场景：开发时开启 debug 排查工具调用链路，生产时设为 error 仅记录异常
FR62: SDK 输出结构化日志（时间戳、级别、模块、事件类型、数据）——用户场景：运维团队将 SDK 日志接入 ELK/Datadog 等聚合系统，通过结构化字段过滤和搜索
FR63: 开发者可以配置沙盒限制（命令排除列表、文件系统读写规则）——用户场景：部署 Agent 到生产环境时，限制其只能读写 /data/ 目录，防止误操作系统文件
FR64: 沙盒限制在 Bash 和文件工具中被强制执行——用户场景：即使 LLM 请求执行 `rm -rf /`，沙盒层在工具执行前拦截并返回权限错误
FR65: 工具支持 annotation 元数据（readOnly、destructive、idempotent、openWorld），权限系统据此做硬性门控——用户场景：权限模式为 .default 时，readOnly 工具自动放行，destructive 工具必须用户确认
FR66: SDK 提供 JSON Schema 生成工具，支持从带元数据标注的 Swift 类型生成 LLM 工具参数描述——用户场景：开发者定义 `struct WeatherInput: ToolSchemaEncodable`，自动获得准确的 JSON Schema，无需手写
FR67: 对话压缩支持三层体系：micro-compact（单工具结果）→ auto-compact（整个对话）→ session memory（进程内跨查询上下文保留）——用户场景：Agent 在一次长会话中处理了 20 个文件，session memory 保留关键决策摘要，后续查询不需要重新分析

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
NFR26: FileCache 查找延迟为 O(1)（哈希表 + 双向链表 LRU）→ Story 12.1 验收标准：缓存命中时 `cache.stats.hitCount` 增加，无磁盘 I/O
NFR27: 沙盒路径和命令检查在 1ms 内完成（不阻塞工具执行热路径）→ Story 14.4/14.5 验收标准：沙盒检查在工具执行前同步完成
NFR28: Logger 输出在调用线程同步完成时不阻塞超过 1ms（.file 模式使用异步写入队列）→ Story 14.1 验收标准：日志检查使用条件判断，开销可忽略不计
NFR29: 技能注册和查找在 5ms 内完成（SkillRegistry 初始化不涉及 I/O）→ Story 11.1 验收标准：SkillRegistry 为内存字典，不涉及 I/O
NFR30: Session Memory FIFO 剪枝在 10ms 内完成（不阻塞查询启动）→ Story 13.3 验收标准：FIFO 策略丢弃最早条目

### 附加需求

- 启动模板：Swift SPM 初始化（`swift package init --type library --name OpenAgentSDK`）— 无外部启动模板
- 两个外部依赖：mcp-swift-sdk（DePasqualeOrg/mcp-swift-sdk）用于 MCP stdio/HTTP/SSE；swift-syntax 用于 `@ToolSchema` Macro 编译时展开（仅编译时依赖，不增加运行时体积）
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
FR50: Epic 9 + Epic 10 - 所有功能的可运行代码示例（Epic 9 覆盖基础，Epic 10 覆盖高级功能）
FR51: Epic 9 - 包含快速入门指南的 README
FR65: Epic 3 - 工具 annotation 元数据（Story 3.8: Tool Annotation 元数据）
FR66: Epic 3 - Schema 转换工具（Story 3.9: JSON Schema 生成工具）
FR52: Epic 11 - 技能注册与发现（Story 11.1: Skill 类型定义与 SkillRegistry）
FR53: Epic 11 - 内置技能 — Story 11.3（Commit）、Story 11.4（Review）、Story 11.5（Simplify）、Story 11.6（Debug）、Story 11.7（Test）
FR54: Epic 11 - 技能执行与上下文（Story 11.2: SkillTool 技能执行工具）
FR55: Epic 12 - 文件 LRU 缓存（Story 12.1: FileCache LRU 缓存实现）
FR56: Epic 12 - 缓存失效与变更检测（Story 12.1: FileCache LRU 缓存实现 + Story 12.2: 缓存集成）
FR57: Epic 12 - 自动 Git 状态注入（Story 12.3: Git 状态注入）
FR58: Epic 12 - 项目文档发现（Story 12.4: 项目文档发现）
FR59: Epic 13 - 运行时模型切换（Story 13.1: 运行时动态模型切换）
FR60: Epic 13 - 查询中断（Story 13.2: Query 级别中断）
FR61: Epic 14 - 调试模式配置（Story 14.1: Logger 类型与注入）
FR62: Epic 14 - 结构化日志输出（Story 14.2: 结构化日志输出）
FR63: Epic 14 - 沙盒配置（Story 14.3: SandboxSettings 配置模型）
FR64: Epic 14 - 文件系统与命令限制（Story 14.4: 文件系统沙盒 + Story 14.5: Bash 命令过滤）
FR67: Epic 13 - 跨查询上下文保留（Story 13.3: Session Memory 压缩层，增强 Epic 2 的 FR9/FR10 基础实现）

## 跨 Epic 实现约定

以下约定适用于所有 Epic（包括已完成的 Epic 1-10 和新增的 Epic 11-14），实施时应统一遵循：

### Logger 集成约定（为 Epic 14 预留）

所有 Epic 的 Story 实现应在关键路径预留 `Logger.shared` 调用点，确保 Epic 14 Logger 实现后无需侵入式修改。具体规则：

- **调用模式：** 使用 `guard Logger.shared.level != .none else { return }` 守卫后调用日志方法，确保 `logLevel = .none` 时零开销
- **预留位置（Epic 3）：** annotation 门控（Story 3.8）、Schema 生成（Story 3.9）
- **预留位置（Epic 11）：** 技能注册、发现、执行
- **预留位置（Epic 12）：** 缓存命中/未命中、缓存淘汰、Git 状态注入、项目文档加载
- **预留位置（Epic 13）：** 模型切换、查询中断、压缩触发、Session Memory 条目添加/淘汰
- **预实现方案：** 在 Epic 14 完成前，`Logger.shared` 使用空实现（所有方法为 no-op），不引入编译错误

### 跨平台路径处理

所有涉及文件路径的 Story（Epic 12、Epic 14）必须：
- 使用 `FileManager` API 而非 POSIX `realpath`（后者在 Windows 不可用）
- 在 Darwin（macOS）上通过 `FileManager.fileSystemRepresentation` 处理大小写不敏感
- 在 Linux 上依赖 POSIX 标准路径解析
- 符号链接解析使用 `URL.resolvingSymlinksInPath()`

---

## Epic 列表

### Epic 1: 基础设施与 Agent 设置
开发者可以创建配置好的 Agent，发送提示词，并通过完整的智能循环接收响应。SDK 通过 SPM 初始化，环境变量可用，编程式配置可用。这是"Hello World"级 Epic — 完成后，开发者拥有一个能与 LLM 对话的工作 Agent。
**覆盖的 FR：** FR1、FR3、FR4、FR6、FR39、FR40、FR41

### Epic 2: 流式响应与生产就绪 Agent
开发者可以通过 AsyncStream 实时流式接收 Agent 响应，追踪 token 使用量和成本，强制执行预算，从 max_tokens 限制中恢复，并自动压缩对话。Agent 具备优雅的错误处理和资源管理能力，达到生产就绪状态。
**覆盖的 FR：** FR2、FR5、FR7、FR8、FR9、FR10
> **注意：** FR9（auto-compact）和 FR10（micro-compact）在本 Epic 中实现基础版本，Epic 13 Story 13.3 将扩展为三层压缩体系（micro-compact → auto-compact → session memory）。

### Epic 3: 工具系统与核心工具
开发者可以向 Agent 注册内置工具和自定义工具。工具系统支持 Codable 输入类型、供 LLM 使用的 JSON Schema 定义、只读工具的并发执行和变更工具的串行执行。全部 10 个核心工具（Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch）均已实现并可用。工具支持 annotation 元数据用于权限系统硬性门控，以及通过 Swift Macro 自动生成 JSON Schema。
**覆盖的 FR：** FR11、FR12、FR13、FR14、FR15、FR16、FR65、FR66

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

### Epic 10: 扩展代码示例集
开发者可以通过 6 个新的可运行示例学习 SDK 的高级功能——多工具编排、自定义系统提示、阻塞式 API、子代理委派、权限控制和高级 MCP 集成。这些示例补充 Epic 9 的 5 个基础示例，实现 FR50 对所有主要功能领域的完整覆盖。
**覆盖的 FR：** FR50（补充）

### Epic 11: 技能系统
开发者可以注册、发现和执行技能（Skills）。技能是比工具更高层的抽象，包含提示词模板、工具限制、模型覆盖和运行时可用性检查。包含 Commit、Review、Simplify、Debug、Test 五个内置技能。
**覆盖的 FR：** FR52、FR53、FR54
**依赖：** Epic 3（工具系统必须先完成）
**参考：** `open-agent-sdk-typescript` 仓库 `src/skills/`、`src/tools/skill-tool.ts`、`src/tools/types.ts`、`src/tool-helper.ts`（基于 main 分支截至 2026-04 的实现；实施时应以具体 commit hash 锚定）

### Epic 12: 文件缓存与上下文注入
Agent 通过 LRU 缓存避免重复文件 I/O，追踪文件变更状态用于压缩差异对比。自动注入 Git 状态和项目文档到系统提示，为 LLM 提供执行环境感知。缓存和上下文注入是性能优化和智能提示的基础设施。
**覆盖的 FR：** FR55、FR56、FR57、FR58
**依赖：** Epic 3（工具系统，FileReadTool/FileWriteTool/FileEditTool 必须存在）、Epic 2（Story 12.2 的 auto-compact 集成需要 Epic 2 的压缩基础）
**参考：** `open-agent-sdk-typescript` 仓库 `src/utils/fileCache.ts`、`src/utils/context.ts`（基于 main 分支截至 2026-04 的实现）

### Epic 13: 会话生命周期管理
开发者可以在会话中动态切换 LLM 模型、中断正在执行的查询、以及通过三层压缩体系管理上下文。增强 Agent 的灵活性、用户控制力和长对话支持。
**覆盖的 FR：** FR59、FR60、FR67
**依赖：** Epic 2（流式响应和智能循环必须先完成）、Epic 12（缓存集成用于压缩差异）
**参考：** `open-agent-sdk-typescript` 仓库 `src/agent.ts`、`src/engine.ts`、`src/utils/compact.ts`（基于 main 分支截至 2026-04 的实现）

### Epic 14: 运行时防护（日志与沙盒）
SDK 提供可配置的调试日志系统和沙盒执行环境。日志系统支持多级别和结构化输出，帮助开发调试和生产诊断。沙盒限制 Agent 的 Bash 命令和文件系统操作范围，增强生产环境安全性。
**覆盖的 FR：** FR61、FR62、FR63、FR64
**依赖：** Epic 3（工具系统，BashTool/FileReadTool 等需要存在才能注入沙盒检查）
**参考：** `open-agent-sdk-typescript` 仓库 `src/types.ts`（SandboxSettings、debug 配置）（基于 main 分支截至 2026-04 的实现）

### Epic 15: SDK Examples 补充
为 Epic 11-14 已实现的功能补充可运行的示例程序，覆盖技能系统、沙盒配置、日志系统、模型切换、查询中断、上下文注入、多轮对话和 OpenAI 兼容 API。补充 Epic 10 未覆盖的高级功能示例，实现 FR50 对所有主要功能领域的完整覆盖。
**覆盖的 FR：** FR50（补充），FR52-FR64 的示例化
**依赖：** Epic 11（技能系统）、Epic 12（文件缓存与上下文注入）、Epic 13（会话生命周期管理）、Epic 14（运行时防护）

### Epic 19: Axion Phase 2 驱动的 SDK 新能力

Axion（macOS 桌面自动化 Agent）在 Phase 2 开发中识别出 3 个所有 Agent 应用都需要的通用能力，从 Axion 的业务需求中提炼并下沉到 SDK：(1) 跨运行知识积累（Memory Store）；(2) Agent 作为 MCP Server 暴露给外部调用者；(3) 结构化的人机协作暂停协议。

**覆盖的 FR（新增）：** FR68、FR69、FR70
**依赖：** Epic 1（Agent 基础）、Epic 6（MCP 协议集成）、Epic 7（会话持久化）
**来源：** Axion Phase 2 需求分析，识别为 SDK 通用能力的应用层特有需求

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

### Story 3.8: Tool Annotation 元数据

作为开发者，
我希望为工具添加 annotation 元数据，
以便权限系统根据工具特性做硬性门控。

**验收标准：**

**给定** ToolProtocol 新增 `annotations: ToolAnnotations?` 字段
**当** 工具注册时提供 `ToolAnnotations(readOnly: true, destructive: false, idempotent: true, openWorld: false)`
**则** annotations 出现在发送给 LLM 的工具定义中（FR65）

**给定** `readOnly: true` 的工具（如 Glob、Grep、Read）
**当** 权限模式为 `.default`
**则** 工具直接执行，不需要用户确认

> **依赖说明：** 本 Story 仅定义 `ToolAnnotations` 数据模型和 annotation 注入到工具定义的逻辑。基于 annotation 的权限门控行为（如下方的 `.allowed`/`.requiresConfirmation`/`.blocked` 判断）在 Epic 8（权限系统）中实现完整语义。Epic 3 实施时，可使用简单的 `canExecute(tool:)` stub 方法（默认返回 `.allowed`），Epic 8 实施时替换为完整的权限门控实现。

**给定** `destructive: true` 的工具（如 Bash、Write）
**当** 权限模式为 `.default`（Epic 8 完整实现后）
**则** 用户确认后才执行，拒绝则返回 `permissionDenied` 错误（硬性门控，非 LLM 提示）

**给定** `destructive: true` 的工具
**当** 权限模式为 `.bypassPermissions`
**则** 工具直接执行，跳过用户确认（annotation 不覆盖显式绕过）

**给定** 任意工具（包括 `readOnly: true`）
**当** 权限模式为 `.plan`
**则** 所有工具返回 `.blocked`（plan 模式下禁止执行任何工具，仅规划）

**给定** `destructive: true` 的工具
**当** 权限模式为 `.acceptEdits`
**则** 文件编辑/写入类工具直接执行，Bash 仍需确认

### Story 3.9: JSON Schema 生成工具

作为开发者，
我希望有一个工具函数从带元数据标注的 Swift 类型生成 JSON Schema，
以便自定义工具的参数定义不需要手写 Schema。

> **设计决策：** 使用 Swift Macro（`@ToolSchema` attached macro）而非属性包装器（property wrapper）。属性包装器会改变存储属性的结构（包装为 `ToolSchema<String>` 类型），破坏 `Codable` 自动合成，需要手动实现 `init(from:)` / `encode(to:)`。Swift Macro 在编译时展开为原始存储属性 + `static var _toolSchemaProperties` 元数据字典，不改变类型布局，Codable 自动合成完全不受影响。项目已要求 Swift 5.9+，Macro 支持满足。

**验收标准：**

**给定** 遵循 `ToolSchemaEncodable` 协议的 Swift 结构体，使用 `@ToolSchema` attached macro
```swift
struct WeatherInput: ToolSchemaEncodable {
    @ToolSchema(description: "城市名称")
    var city: String
    @ToolSchema(description: "温度单位")
    var unit: String?  // Optional → 非必需属性
}
```
**当** 开发者调用 `WeatherInput.jsonSchema`
**则** 返回包含 `"properties": {"city": {"type": "string", "description": "城市名称"}, "unit": {"type": "string", "description": "温度单位"}}` 的字典
**且** `"required": ["city"]`（仅非 Optional 字段）（FR66）

**给定** 包含数组和枚举类型的 `ToolSchemaEncodable`
```swift
struct SearchInput: ToolSchemaEncodable {
    @ToolSchema(description: "搜索路径列表")
    var paths: [String]
    @ToolSchema(description: "搜索模式")
    var mode: SearchMode  // 枚举类型
}
enum SearchMode: String, ToolSchemaEncodable {
    case exact
    case fuzzy
}
```
**当** 生成 Schema
**则** `paths` 映射为 `"type": "array", "items": {"type": "string"}, "description": "搜索路径列表"`
**且** `mode` 映射为 `"type": "string", "enum": ["exact", "fuzzy"], "description": "搜索模式"`

**给定** 包含嵌套类型的 `ToolSchemaEncodable`
```swift
struct Location: ToolSchemaEncodable {
    var lat: Double
    var lng: Double
}
struct GeoSearchInput: ToolSchemaEncodable {
    var location: Location
    var radius: Double
}
```
**当** 生成 Schema
**则** `location` 属性递归展开为 `"type": "object", "properties": {"lat": {"type": "number"}, "lng": {"type": "number"}}`

**给定** `ToolSchemaEncodable` 协议要求
**当** 开发者尝试让不遵循协议的 Codable 类型生成 Schema
**则** 编译时错误，不产生运行时问题

**给定** 使用 `@ToolSchema` macro 的 `ToolSchemaEncodable` 结构体同时声明遵循 `Codable`
**当** 执行 `JSONEncoder().encode(instance)` 和 `JSONDecoder().decode(WeatherInput.self, from: data)`
**则** 正常工作（Macro 展开不改变存储属性布局，Codable 自动合成不受影响）
**且** `@ToolSchema` macro 生成的 `_toolSchemaProperties` 静态属性不参与 Codable 编解码

**给定** `@ToolSchema` macro 的实现（在 `OpenAgentSchemaMacros` macro target 中）
**当** 编译期展开
**则** 为每个标注属性生成元数据条目（name、type、description、isOptional）
**且** 未标注 `@ToolSchema` 的存储属性仍出现在 schema 的 `properties` 中（仅包含 `type` 字段，无 `description`），确保 schema 完整覆盖所有 Codable 属性
**且** 生成 `static var jsonSchema: [String: Any]` 计算属性，组装完整 JSON Schema
**且** 嵌套 `ToolSchemaEncodable` 类型的 Schema 通过递归调用 `NestedType.jsonSchema` 生成

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

---

## Epic 10: 扩展代码示例集

开发者可以通过 6 个新的可运行示例学习 SDK 的高级功能——多工具编排、自定义系统提示、阻塞式 API、子代理委派、权限控制和高级 MCP 集成。

### Story 10.1: 多工具编排示例（MultiToolExample）

作为 Swift 开发者，
我希望看到一个 Agent 自主组合多个工具（Glob、Bash、Read）完成复杂任务的示例，
以便我理解 Agent 如何规划和执行多步骤工作流。

**验收标准：**

**给定** Examples/MultiToolExample/ 目录下有一个可执行的 Swift 文件
**当** 开发者运行 `swift run MultiToolExample`
**则** Agent 使用 Glob 查找文件、Bash 执行命令、Read 读取内容，自主编排多步骤任务
**且** 输出实时显示每个工具调用（工具名和输入参数）
**且** 最终输出任务摘要和 token 使用统计
**且** 示例使用流式 API（`agent.stream()`）消费事件

**给定** Package.swift 中的 MultiToolExample 可执行目标
**当** 执行 `swift build` 编译项目
**则** 编译无错误，无警告

### Story 10.2: 自定义系统提示示例（CustomSystemPromptExample）

作为 Swift 开发者，
我希望看到使用自定义系统提示创建专业化 Agent 的示例，
以便我理解如何为特定角色定制 Agent 行为。

**验收标准：**

**给定** Examples/CustomSystemPromptExample/ 目录下有一个可执行的 Swift 文件
**当** 开发者运行 `swift run CustomSystemPromptExample`
**则** Agent 使用自定义 systemPrompt（如代码审查专家），以专业化角色回应
**且** Agent 的回复风格和格式符合系统提示中的指导要求
**且** 示例使用阻塞式 API（`agent.prompt()`）展示简单用法

**给定** Package.swift 中的 CustomSystemPromptExample 可执行目标
**当** 执行 `swift build` 编译项目
**则** 编译无错误，无警告

### Story 10.3: 阻塞式 Prompt API 示例（PromptAPIExample）

作为 Swift 开发者，
我希望看到一个使用 `agent.prompt()` 阻塞式 API 获取完整响应的示例，
以便我理解在不需要流式传输时如何用最简单的方式调用 Agent。

**验收标准：**

**给定** Examples/PromptAPIExample/ 目录下有一个可执行的 Swift 文件
**当** 开发者运行 `swift run PromptAPIExample`
**则** Agent 通过 `agent.prompt()` 执行查询并返回完整的 QueryResult
**且** 输出展示 result.text（响应文本）、result.numTurns（轮次数）、result.usage（token 用量）、result.durationMs（耗时）
**且** 示例展示如何在单次调用中获取 Agent 执行工具后的最终结果

**给定** Package.swift 中的 PromptAPIExample 可执行目标
**当** 执行 `swift build` 编译项目
**则** 编译无错误，无警告

### Story 10.4: 子代理委派示例（SubagentExample）

作为 Swift 开发者，
我希望看到一个主 Agent 委派子代理执行专门任务的示例，
以便我理解如何构建多 Agent 编排工作流。

**验收标准：**

**给定** Examples/SubagentExample/ 目录下有一个可执行的 Swift 文件
**当** 开发者运行 `swift run SubagentExample`
**则** 主 Agent 使用 Agent 工具生成一个带有自定义提示的子代理
**且** 子代理仅使用受限的工具集（如 Read、Glob、Grep）
**且** 子代理的结果返回给主 Agent，主代理基于子代理结果生成最终回复
**且** 示例使用流式 API 展示子代理的实时执行过程

**给定** Package.swift 中的 SubagentExample 可执行目标
**当** 执行 `swift build` 编译项目
**则** 编译无错误，无警告

### Story 10.5: 权限与受限 Agent 示例（PermissionsExample）

作为 Swift 开发者，
我希望看到一个创建受限 Agent 的示例（如只读 Agent），
以便我理解如何通过权限模式和工具白名单控制 Agent 的执行能力。

**验收标准：**

**给定** Examples/PermissionsExample/ 目录下有一个可执行的 Swift 文件
**当** 开发者运行 `swift run PermissionsExample`
**则** 示例创建一个只允许使用 Read、Glob、Grep 工具的受限 Agent
**且** Agent 可以正常执行被允许的只读操作
**且** 示例展示 `allowedTools` 配置如何限制 Agent 的工具访问范围
**且** 示例对比展示 `permissionMode: .bypassPermissions` 模式下的行为差异

**给定** Package.swift 中的 PermissionsExample 可执行目标
**当** 执行 `swift build` 编译项目
**则** 编译无错误，无警告

### Story 10.6: 高级 MCP 工具示例（AdvancedMCPExample）

作为 Swift 开发者，
我希望看到一个使用 `createSdkMcpServer()` 创建进程内 MCP 服务器并注册自定义工具的示例，
以便我理解如何通过 MCP 协议构建和暴露自定义工具集。

**验收标准：**

**给定** Examples/AdvancedMCPExample/ 目录下有一个可执行的 Swift 文件
**当** 开发者运行 `swift run AdvancedMCPExample`
**则** 示例使用 `tool()` 或 `defineTool()` 创建带 Codable 输入的自定义工具（如天气查询、单位转换）
**且** 示例使用 `createSdkMcpServer()` 将工具打包为进程内 MCP 服务器
**且** Agent 通过 `mcpServers` 配置连接进程内服务器并使用 MCP 工具
**且** MCP 工具以 `mcp__{serverName}__{toolName}` 命名空间被调用
**且** 示例展示工具返回错误时的处理方式

**给定** Package.swift 中的 AdvancedMCPExample 可执行目标
**当** 执行 `swift build` 编译项目
**则** 编译无错误，无警告

---

## Epic 11: 技能系统

开发者可以注册、发现和执行技能（Skills）。技能是比工具更高层的抽象，包含提示词模板、工具限制、模型覆盖和运行时可用性检查。包含 Commit、Review、Simplify、Debug、Test 五个内置技能。

> **命名约定：** 所有内置技能（如 CommitSkill、ReviewSkill 等）均为 `Skill` struct 的预配置实例，通过 `BuiltInSkills.commit` 等静态属性提供便利访问。开发者可使用 `BuiltInSkills.commit` 获取默认技能，或直接 `Skill(name: "commit", ...)` 创建自定义版本后通过 `registry.replace()` 覆盖。

**覆盖的 FR：** FR52、FR53、FR54
**依赖：** Epic 3（工具系统必须先完成）

### Story 11.1: Skill 类型定义与 SkillRegistry

作为开发者，
我希望定义技能类型并通过 SkillRegistry 管理技能，
以便我可以注册、查找和列出所有可用技能。

**验收标准：**

**给定** Skill struct 定义，包含 name、description、aliases、userInvocable、toolRestrictions、modelOverride、isAvailable（`() -> Bool` 闭包）、promptTemplate 字段
**当** 开发者创建技能定义
**则** `Skill(name: "commit", promptTemplate: "...", toolRestrictions: [.bash, .read, .write])` 编译无错误
**且** 技能结构体是值类型（struct），不使用 Actor（注册是一次性操作，查询是只读的）

**给定** SkillRegistry（`final class`，内部维护 `[String: Skill]` 字典，线程安全通过内部串行 `DispatchQueue` 保护）
**当** 开发者调用 `registry.register(commitSkill)`
**则** `registry.find("commit")` 返回该技能
**且** `registry.find("ci")` 通过别名也能找到（如果注册了别名）

**给定** 已注册的技能（如 CommitSkill）
**当** 开发者调用 `registry.replace(CommitSkill(name: "commit", promptTemplate: "自定义..."))` 替换 promptTemplate
**则** `registry.find("commit")` 返回更新后的技能定义
**且** 已在执行中的技能实例不受影响（值类型语义保证隔离）

**给定** 已注册 3 个技能（其中 2 个 userInvocable=true）
**当** 开发者调用 `registry.userInvocableSkills`
**则** 返回恰好 2 个技能

**给定** 已注册技能
**当** 开发者调用 `registry.formatSkillsForPrompt()`
**则** 返回的文本不超过 500 token（使用 `TokenEstimator.estimate()` 估算，超出时截断尾部技能描述）
**且** 文本包含每个技能的名称、描述和调用方式

**给定** 注册了 `isAvailable` 返回 `false` 的技能（如 TestSkill 在没有测试框架时不可用）
**当** 开发者调用 `registry.userInvocableSkills` 或 `registry.formatSkillsForPrompt()`
**则** 不可用的技能被排除在结果之外
**且** `registry.find("test")` 仍可找到该技能（查找不过滤可用性）
**且** SkillTool 执行不可用技能时返回 `SDKError.invalidConfiguration("Skill 'test' is not available in current environment")`

### Story 11.2: SkillTool 技能执行工具

作为开发者，
我希望 Agent 通过 SkillTool 调用已注册的技能，
以便技能可以作为工具被 LLM 发现和执行。

**验收标准：**

**给定** SkillTool 已注册且 SkillRegistry 中有技能
**当** LLM 返回 tool_use 块请求执行 `skill` 工具，参数 `{"name": "commit"}`
**则** SkillTool 调用 `registry.find("commit")`，获取 promptTemplate，将该模板作为新提示注入 Agent（FR54）

> **轮次预算说明：** 技能执行**共享**当前查询的 `maxTurns` 轮次预算（不分配独立预算）。技能内的工具调用轮次计入查询总轮次。这确保技能不会导致无限循环——查询级 `maxTurns` 始终是硬上限。

**给定** 带有 `toolRestrictions: [.bash, .read]` 的技能
**当** 技能执行
**则** `ToolExecutor.getAvailableTools()` 仅返回 [.bash, .read]，其他工具被临时隐藏
**且** 工具限制通过**栈模型**管理：执行技能时 push 受限工具集到栈顶，执行完毕后 pop 恢复到栈中下一层（或完整集合）

**给定** 技能 A（toolRestrictions: [.bash, .read]）执行中嵌套调用技能 B（toolRestrictions: [.grep, .glob]）
**当** 技能 B 执行
**则** 栈顶为 B 的限制集 [.grep, .glob]，A 的限制集 [.bash, .read] 在栈下一层
**且** 技能 B 完成后 pop，恢复到 A 的限制集 [.bash, .read]
**且** 技能 A 完成后 pop，恢复到完整工具集

**给定** 带有 `modelOverride: "claude-opus-4-6"` 的技能
**当** 技能执行
**则** 发送给 API 的请求中 `model` 字段为 "claude-opus-4-6"（验证实际请求参数，非内部状态）
**且** 技能执行完毕后，后续 API 请求的 `model` 恢复为 Agent 默认模型

**给定** SkillTool 尝试执行 `toolRestrictions` 中包含 SkillTool 自身的技能
**当** 技能执行
**则** 抛出 `SDKError.invalidConfiguration("Skill cannot restrict SkillTool itself")` 防止循环

**给定** 带有 `toolRestrictions: [.bash, .read]` 的技能正在执行
**当** 技能执行中途抛出错误（LLM 超时、网络故障）
**则** 工具限制栈仍正确 pop（使用 `defer` 或 `try/finally` 等价机制），恢复到上一层（异常路径不泄露受限状态）
**且** 错误正常向上传播

**给定** 技能 A 的 promptTemplate 指导 LLM 调用技能 B，技能 B 的 promptTemplate 又调用技能 A（直接或间接循环）
**当** SkillTool 检测到嵌套技能调用深度超过 4 层（即 A→B→C→D→A 模式在第五层被拦截）
**则** 抛出 `SDKError.invalidConfiguration("Skill recursion depth exceeded: maximum nesting depth is 4")` 防止间接循环
**且** 深度限制可配置为 `SDKConfiguration.maxSkillRecursionDepth`（默认值 4，允许 A→B→C→D 合法嵌套，同时拦截 A→B→C→D→A 等循环）

### Story 11.3: 内置技能 — Commit

作为开发者，
我希望 Agent 具有 Git Commit 技能，
以便它可以分析变更并生成规范的提交信息。

**验收标准：**

**给定** CommitSkill 已注册
**当** LLM 调用 commit 技能
**则** 技能的 promptTemplate 指导 Agent 执行 `git status --short`、`git diff --cached` 和 `git diff`（未暂存变更）（FR53）

**给定** 有未暂存变更但没有暂存变更（`git diff --cached` 为空，`git diff` 有输出）
**当** commit 技能执行
**则** Agent 输出"没有暂存的变更，请先 git add 相关文件"并列出未暂存的具体文件

**给定** 没有暂存变更且没有未暂存变更（`git diff --cached` 和 `git diff` 输出均为空）
**当** commit 技能执行
**则** Agent 输出"没有暂存的变更，请先 git add 相关文件"并建议具体文件

**给定** 有暂存变更
**当** commit 技能生成提交信息
**则** 提交信息的 promptTemplate 可被开发者通过 `registry.replace(CommitSkill(name: "commit", promptTemplate: "自定义..."))` 覆盖
**且** 默认模板指导生成祈使语气、标题不超过 72 字符的提交信息

> **默认 promptTemplate 骨架（Commit）：**
> ```
> 你是一个提交信息生成助手。执行以下步骤：
> 1. 运行 `git status --short` 查看变更文件列表
> 2. 运行 `git diff --cached` 查看已暂存的变更（如果为空，运行 `git diff` 查看未暂存变更，并提示用户需要先 git add）
> 3. 如果没有任何变更（两个 diff 都为空），告知用户没有需要提交的内容
> 4. 分析暂存的变更内容，生成规范的提交信息：
>    - 使用祈使语气（如 "add feature" 而非 "added feature"）
>    - 标题行不超过 72 字符
>    - 如果变更涉及多个关注点，使用多段提交信息（标题 + 空行 + 详细说明）
>    - 不要实际执行 git commit，只输出建议的提交信息
> ```

### Story 11.4: 内置技能 — Review

作为开发者，
我希望 Agent 具有 Code Review 技能，
以便它可以多维度审查代码变更。

**验收标准：**

**给定** ReviewSkill 已注册
**当** LLM 调用 review 技能
**则** 技能的 promptTemplate 指导 Agent 从正确性、安全性、性能、风格和测试覆盖率五个维度审查代码（FR53）

**给定** 代码变更（git diff 输出）
**当** review 技能执行
**则** promptTemplate 要求审查结果引用具体文件名和行号（如 `src/main.swift:42`）

> **默认 promptTemplate 骨架（Review）：**
> ```
> 你是一个严格的代码审查专家。对当前变更进行多维度审查：
> 1. 运行 `git diff` 获取未暂存变更，或 `git diff --cached` 获取已暂存变更
> 2. 如果没有变更，运行 `git diff HEAD~1` 查看最近一次提交
> 3. 从以下五个维度审查每个变更：
>    - 正确性：逻辑是否正确，边界条件是否处理
>    - 安全性：是否存在注入、XSS、敏感信息泄露等安全风险
>    - 性能：是否存在不必要的性能开销（N+1 查询、重复计算等）
>    - 风格：是否遵循项目代码规范和 Swift惯用写法
>    - 测试覆盖率：变更是否有对应测试，测试是否覆盖关键路径
> 4. 每个发现必须引用具体文件名和行号（格式：`path/to/file.swift:行号`）
> 5. 按严重程度排序（安全 > 正确性 > 性能 > 风格 > 测试）
> ```

### Story 11.5: 内置技能 — Simplify

作为开发者，
我希望 Agent 具有 Simplify 技能，
以便它可以审查变更代码的复用性、质量和效率。

**验收标准：**

**给定** SimplifySkill 已注册
**当** LLM 调用 simplify 技能
**则** promptTemplate 指导 Agent 审查变更代码的复用性、质量和效率（FR53）
**且** SimplifySkill 的 `toolRestrictions` 限定为 Read、Grep、Glob（只读工具）

**给定** SimplifySkill 的 promptTemplate
**当** 技能执行
**则** 输出结构包含：重复代码模式、过度复杂的逻辑、可提取的抽象（具体引用文件名和行号）

> **默认 promptTemplate 骨架（Simplify）：**
> ```
> 你是一个代码简化专家。审查当前工作目录中最近变更的文件：
> 1. 运行 `git diff` 或 `git diff --cached` 识别变更文件
> 2. 使用 Read、Grep、Glob 工具（仅只读工具）分析代码
> 3. 识别以下问题：
>    - 重复代码模式：相同或相似逻辑出现在多个位置
>    - 过度复杂的逻辑：可以简化的条件嵌套、过长的方法、不必要的间接层
>    - 可提取的抽象：多个地方共享的模式可以提取为公共函数或类型
> 4. 每个发现必须引用具体文件名和行号（格式：`path/to/file.swift:行号`）
> 5. 对于每个发现，提供简化前后的对比示例
> ```

### Story 11.6: 内置技能 — Debug

作为开发者，
我希望 Agent 具有 Debug 技能，
以便它可以分析错误信息、定位根因并提供修复建议。

**验收标准：**

**给定** DebugSkill 已注册
**当** LLM 调用 debug 技能
**则** promptTemplate 指导 Agent 分析错误信息、定位根因并提供修复建议
**且** DebugSkill 的 `toolRestrictions` 包含 Read、Grep、Glob、Bash（需要运行诊断命令）

**给定** DebugSkill 的 promptTemplate
**当** 技能执行
**则** 输出包含：错误根因分析、复现步骤（如适用）、具体修复建议（引用文件名和行号）

> **默认 promptTemplate 骨架（Debug）：**
> ```
> 你是一个调试专家。分析用户提供的错误信息并定位根因：
> 1. 使用 Read 工具查看相关源文件，Grep 搜索相关代码模式
> 2. 如果错误涉及构建失败，运行 Bash 执行构建命令获取完整错误输出
> 3. 如果错误涉及运行时崩溃，查看堆栈跟踪中的文件和行号
> 4. 分析完成后提供：
>    - 根因分析：解释错误发生的根本原因
>    - 复现步骤：如何可靠地复现该错误（如适用）
>    - 修复建议：具体的代码修改方案，引用文件名和行号
> 5. 如果有多个可能的根因，按可能性排序
> ```

### Story 11.7: 内置技能 — Test

作为开发者，
我希望 Agent 具有 Test 技能，
以便它可以生成和执行测试用例。

**验收标准：**

**给定** TestSkill 已注册
**当** LLM 调用 test 技能
**则** promptTemplate 指导 Agent 生成和执行测试用例
**且** TestSkill 的 `toolRestrictions` 包含 Read、Write、Glob、Grep、Bash（需要创建测试文件并运行）

**给定** TestSkill 的 promptTemplate
**当** 技能执行
**则** 输出包含：生成的测试代码、测试执行结果、覆盖率建议

**给定** 当前环境没有测试框架
**当** TestSkill 检查 `isAvailable`
**则** 返回 `false`（配合 Story 11.1 的可用性过滤）

> **默认 promptTemplate 骨架（Test）：**
> ```
> 你是一个测试工程师。为指定代码生成和执行测试用例：
> 1. 使用 Read 工具读取需要测试的源文件，理解其公共 API 和行为
> 2. 使用 Glob 查找是否已有测试文件（如 `Tests/` 目录下的对应文件）
> 3. 分析代码的公共方法和关键路径，生成测试用例覆盖：
>    - 正常路径（happy path）
>    - 边界条件
>    - 错误处理路径
> 4. 使用 Write 工具创建测试文件（如不存在）或更新现有测试文件
> 5. 使用 Bash 工具运行测试（`swift test` 或 `xcodebuild test`）
> 6. 报告测试执行结果和覆盖率建议
> ```

---

## Epic 12: 文件缓存与上下文注入

Agent 通过 LRU 缓存避免重复文件 I/O，追踪文件变更状态用于压缩差异对比。自动注入 Git 状态和项目文档到系统提示。缓存和上下文注入是性能优化和智能提示的基础设施。

**覆盖的 FR：** FR55、FR56、FR57、FR58
**依赖：** Epic 3（工具系统，FileReadTool/FileWriteTool/FileEditTool 必须存在）、Epic 2（Story 12.2 的 auto-compact 集成需要 Epic 2 的压缩基础）

### Story 12.1: FileCache LRU 缓存实现

作为开发者，
我希望 SDK 维护一个文件内容的 LRU 缓存，
以便重复读取相同文件时不需要重新访问磁盘。

**验收标准：**

**给定** FileCache 实现（`final class`，内部使用 `NSLock` 保护并发访问，因为被多个工具实例共享；默认 maxEntries=100，maxSizeBytes=25*1024*1024，maxEntrySizeBytes=5*1024*1024，均可通过 init 参数配置）
**当** FileReadTool 首次读取 `/project/src/main.swift`
**则** 文件内容被缓存，`cache.stats.missCount == 1`
**且** 超过 `maxEntrySizeBytes`（默认 5MB）的单个文件不缓存（直接从磁盘读取，记录 `cache.stats.oversizedSkipCount`），防止单个大文件占满缓存
**且** 缓存总大小超过 `maxSizeBytes` 时触发 LRU 淘汰，直到总大小回到限制以下

**给定** `SDKConfiguration.fileCacheMaxEntries`、`SDKConfiguration.fileCacheMaxSizeBytes` 和 `SDKConfiguration.fileCacheMaxEntrySizeBytes` 可在初始化时覆盖默认值
**当** 开发者通过 SDKConfiguration 设置自定义缓存参数
**则** FileCache 使用自定义参数创建

**给定** 已缓存的文件 `/project/src/main.swift`
**当** 再次读取同一文件
**则** 返回缓存内容，`cache.stats.hitCount == 1`，无磁盘 I/O（FR55）

> **阈值选择依据：** maxEntries=100 基于典型 Agent 会话中频繁访问的文件数量（核心源码 + 配置 + 测试文件）。maxSizeBytes=25MB 基于服务器端 Agent 进程的典型可用内存。maxEntrySizeBytes=5MB 确保单个大文件（如大型 JSON、生成文件）不会驱逐多个常用的小文件。

**给定** 已满的 FileCache（100 条目）
**当** 读取第 101 个文件
**则** `cache.stats.evictionCount` 增加 1
**且** 被淘汰的是最久未访问的条目

**给定** 文件被 FileWriteTool 或 FileEditTool 修改
**当** 修改完成
**则** `cache.get(modifiedFilePath)` 返回 nil（条目已失效）（FR56）

**给定** 路径 `/project/../project/src/main.swift`
**当** FileCache 标准化路径
**则** `cache.get("/project/../project/src/main.swift")` 与 `cache.get("/project/src/main.swift")` 命中同一缓存条目

**给定** 符号链接 `/project/link` → `/project/real/`
**当** FileCache 解析路径
**则** `cache.get("/project/link/file.swift")` 与 `cache.get("/project/real/file.swift")` 命中同一缓存条目

**给定** 符号链接 `/project/link` 指向已被删除的目标
**当** FileCache 解析路径
**则** `URL.resolvingSymlinksInPath()` 解析失败，缓存查找 miss 并回退到直接磁盘读取
**且** 如果磁盘读取也失败，返回标准文件不存在错误（不因符号链接解析失败而崩溃）

**给定** macOS 大小写不敏感文件系统上的路径 `/Project/Src/Main.swift`
**当** 与 `/project/src/main.swift` 比较
**则** 路径标准化后解析为同一实际路径（通过 `FileManager.fileSystemRepresentation` + `URL.resolvingSymlinksInPath()`，不使用 POSIX `realpath`）

### Story 12.2: 缓存与工具和压缩集成

作为开发者，
我希望文件缓存与工具执行和对话压缩深度集成，
以便缓存数据服务于性能优化和上下文管理。

**验收标准：**

**给定** FileReadTool 支持部分读取（offset=100, limit=50）
**当** 完整文件（1000 行）已缓存
**则** 返回第 100-149 行，无磁盘访问
**且** `cache.stats.diskReadCount` 不增加

**给定** 自动压缩执行
**当** 压缩逻辑调用 `cache.getModifiedFiles(since: lastCompactTime)`
**则** 返回自上次压缩后被写入或编辑过的文件路径列表
**且** 列表可用于生成压缩差异摘要

**给定** Agent 会话结束
**当** 调用 `cache.clear()`
**则** `cache.stats.totalEntries == 0`
**且** 缓存占用的内存被释放

### Story 12.3: Git 状态注入

作为开发者，
我希望 Agent 自动感知当前 Git 仓库状态，
以便 LLM 在执行任务时具备代码库上下文感知。

**验收标准：**

**给定** Agent 在 Git 仓库中执行
**当** 查询开始（`agent.stream("帮我提交代码")`）
**则** 发送给 LLM 的系统提示包含格式化文本块：
  ```
  <git-context>
  Branch: feature/skills
  Main branch: main
  Git user: nick
  Status:
  M src/Skills.swift
  A src/SkillRegistry.swift
  Recent commits:
  - abc1234: add skill registry
  - def5678: initial tool system
  </git-context>
  ```
  （FR57）

**给定** Agent 不在 Git 仓库中（`git rev-parse --git-dir` 返回非零退出码）
**当** 查询开始
**则** 系统提示不包含 `<git-context>` 块
**且** 查询正常执行，不报错

**给定** `git status --short` 输出超过 2000 字符
**当** 注入 Git 状态
**则** 截断到 2000 字符并附加 `...（输出已截断，共 N 个文件变更）`

**给定** 连续两次查询（间隔小于 `SDKConfiguration.gitCacheTTL`，默认 5 秒）
**当** 第二次查询开始
**则** 使用缓存的 Git 状态（`Process` 不被调用第二次）
**且** 如果距离上次缓存超过 TTL，重新执行 git 命令刷新缓存
**且** 开发者可设置 `config.gitCacheTTL = 0` 禁用缓存（每次查询都刷新）

### Story 12.4: 项目文档发现（CLAUDE.md / AGENT.md）

作为开发者，
我希望 SDK 自动发现和加载项目级指令文件，
以便 LLM 获得项目特定的行为指导。

> **项目根目录发现规则：**
> 1. 优先使用 `SDKConfiguration.projectRoot`（如果开发者显式设置）
> 2. 若未设置，从当前工作目录（`FileManager.default.currentDirectoryPath`）向上遍历，查找第一个包含 `.git` 目录的父目录作为项目根目录
> 3. 若未找到 `.git` 目录，使用当前工作目录作为项目根目录
> 4. 项目根目录在 Agent 实例生命周期内不变（不监听文件系统变化）

**验收标准：**

**给定** 项目根目录存在 `CLAUDE.md`（内容 500 字符）
**当** Agent 初始化
**则** 系统提示包含 `<project-instructions>` 块，内容为 CLAUDE.md 全文（FR58）

**给定** 用户主目录 `~/.claude/CLAUDE.md`（全局指令，200 字符）和项目目录 `CLAUDE.md`（300 字符）
**当** Agent 初始化
**则** 系统提示中全局指令在 `<global-instructions>` 块，项目级指令在 `<project-instructions>` 块
**且** 两个块不重复

**给定** 项目根目录同时存在 `CLAUDE.md` 和 `AGENT.md` 两个文件
**当** Agent 初始化
**则** 两个文件的内容合并到 `<project-instructions>` 块中（CLAUDE.md 在前，AGENT.md 在后）
**且** 如果只有一个文件存在，仅加载该文件

**给定** 开发者设置 `config.projectRoot = "/custom/project/path"`
**当** Agent 初始化
**则** 从 `/custom/project/path` 查找指令文件，不从当前工作目录向上遍历

**给定** CLAUDE.md 文件大小超过 100KB
**当** Agent 初始化
**则** 保留文件前 100KB 内容，尾部截断并附加 `<!-- 文件过大，已截断，原大小 N KB -->`
**且** 不影响系统提示的其他部分

**给定** CLAUDE.md 文件包含非 UTF-8 编码
**当** Agent 初始化
**则** 记录 `warn` 级别日志"无法读取 CLAUDE.md：编码错误"，跳过注入
**且** 不影响查询执行

---

## Epic 13: 会话生命周期管理

开发者可以在会话中动态切换 LLM 模型、中断正在执行的查询、以及通过三层压缩体系管理上下文。增强 Agent 的灵活性、用户控制力和长对话支持。

**覆盖的 FR：** FR59、FR60、FR67
**依赖：** Epic 2（流式响应和智能循环必须先完成）、Epic 12（缓存集成用于压缩差异）

### Story 13.1: 运行时动态模型切换

作为开发者，
我希望在 Agent 会话中动态切换 LLM 模型，
以便我可以根据任务需要选择最合适的模型。

**验收标准：**

**给定** 使用 "claude-sonnet-4-6" 模型创建的 Agent
**当** 开发者调用 `agent.switchModel("claude-opus-4-6")`
**则** 方法返回 `Void`，无错误
**且** 后续 `agent.stream(...)` 发送的 API 请求中 `model` 字段为 "claude-opus-4-6"（FR59）

**给定** 模型从 "claude-sonnet-4-6" 切换到 "claude-opus-4-6"
**当** 查询完成后检查 `result.usage`
**则** `result.usage.costBreakdown` 包含两个条目：sonnet 的 token 计数和 opus 的 token 计数
**且** 总成本 = sonnet 成本 + opus 成本

**给定** 开发者调用 `agent.switchModel("")`（空字符串）
**当** 方法执行
**则** 抛出 `SDKError.invalidConfiguration("Model name cannot be empty")`
**且** Agent 当前模型不变，会话不中断

**给定** 开发者调用 `agent.switchModel("some-new-model-name")`（非空但非预知模型）
**当** 方法执行
**则** 方法成功返回（不使用白名单验证，允许未来新模型名称）
**且** 如果 API 返回 404 错误，错误在下次查询时正常报告

### Story 13.2: Query 级别中断（Abort）

作为开发者，
我希望可以中断正在执行的 Agent 查询，
以便长时间运行的任务可以被用户主动取消。

**验收标准：**

**给定** Agent 正在执行查询（使用 `Task { agent.stream(...) }`）
**当** 开发者取消该 Task（`task.cancel()`）
**则** 当前 LLM HTTP 请求被取消
**且** 工具执行收到 `CancellationError` 并停止
**且** 返回 `QueryResult` 包含 `isCancelled: true`、已完成轮次的结果和部分文本（FR60）

**给定** FileWriteTool 正在写入文件时收到取消信号
**当** 中断到达
**则** 如果文件是新创建的，删除该文件（回滚）
**且** 如果文件是覆盖写入的，保留原始文件不变（写入到临时文件，未 rename）
**且** 返回的 `QueryResult.toolResults` 包含已成功完成的工具结果

**给定** FileEditTool 正在编辑文件时收到取消信号
**当** 中断到达
**则** 编辑前已备份原始文件内容（内存或临时文件），中断时恢复原始内容
**且** 如果备份时尚未开始写入，无需恢复（文件未被修改）

**给定** 流式响应（`AsyncStream<SDKMessage>`）被中断
**当** 取消信号到达
**则** AsyncStream 发出最后一个 `SDKMessage.cancelled` 事件
**且** AsyncStream 正常 finish（消费者不收到错误）

### Story 13.3: Session Memory 压缩层

作为开发者，
我希望 Agent 在长对话中维护跨查询的关键上下文，
以便后续查询不需要重新分析已知信息。

**验收标准：**

**给定** Agent 在同一进程中执行了多次查询
**当** 第二次查询开始
**则** 系统提示包含 `<session-memory>` 块，内容为之前查询的关键决策和发现摘要（FR67）

**给定** 三层压缩体系
**当** 单个工具结果超过 50,000 字符
**则** 触发 micro-compact（压缩该工具结果）

**给定** 三层压缩体系
**当** 整个对话 token 数达到上下文窗口的 80%
**则** 触发 auto-compact（压缩整个对话为摘要）

**给定** 三层压缩体系
**当** auto-compact 完成后
**则** 关键决策和用户偏好被提取到 Session Memory
**且** Session Memory 是进程内的（不跨进程重启持久化，随 Agent 实例生命周期存在）
**且** Session Memory 总大小不超过 4,000 token
**且** 当 Session Memory 超过 4,000 token 时，采用 FIFO 策略丢弃最早的条目（保留最新的决策）

> **Session Memory 提取机制：** auto-compact 完成后，使用一次 LLM 调用从摘要中提取关键信息。提取 prompt 要求 LLM 输出固定格式 JSON 数组，每个条目包含 `category`（decision/preference/constraint）、`summary`（一句话摘要）、`context`（相关文件或代码片段）。提取结果追加到 SessionMemory 的 FIFO 队列。如果 auto-compact 产生的摘要本身已足够简短（<200 字符），可跳过提取步骤直接将摘要作为单条目存入。

> **Token 计数机制：** Session Memory 的 token 预算使用**语言感知的字符近似估算**，封装为 `TokenEstimator.estimate(text:)` 静态方法。估算规则：(1) 对 ASCII 字符（英文、代码、标点）使用 1 token ≈ 4 字符（`utf8.count / 4`）；(2) 对 CJK 字符（中文、日文、韩文）使用 1 token ≈ 1.5 字符（`unicodeScalars.filter { CharacterSet(charactersIn: "\\u{4E00}"..."\\u{9FFF}").contains($0) }.count` 计数后 × 1.5）；(3) 混合文本按字符类别分段估算后求和。此近似对 Claude 模型的实际 tokenizer 有约 ±20% 偏差，但满足以下约束：(1) 零外部依赖——无需引入 tiktoken 或其他 tokenizer 库；(2) 足够用于 4,000 token 的预算限制（偏差约 ±800 token，不导致上下文溢出）；(3) 如果未来需要精确计数，可替换为 API 响应中的 `usage.inputTokens` 字段。

---

## Epic 14: 运行时防护（日志与沙盒）

SDK 提供可配置的调试日志系统和沙盒执行环境。日志系统支持多级别和结构化输出，帮助开发调试和生产诊断。沙盒限制 Agent 的 Bash 命令和文件系统操作范围，增强生产环境安全性。

**覆盖的 FR：** FR61、FR62、FR63、FR64
**依赖：** Epic 3（工具系统）

### Story 14.1: Logger 类型与注入

作为开发者，
我希望可以配置 SDK 的日志级别并通过 SDKConfiguration 注入 Logger，
以便在开发时获取详细日志，在生产时保持静默。

**验收标准：**

**给定** `SDKConfiguration` 新增 `logLevel: LogLevel` 字段（枚举：none、error、warn、info、debug）和 `logOutput: LogOutput` 字段
**当** 开发者设置 `config.logLevel = .debug`
**则** `Logger.shared.level == .debug`
**且** Agent、QueryEngine、ToolExecutor 均通过 `Logger.shared` 输出日志（FR61）

**给定** `config.logOutput = .console`（默认）
**当** Logger 输出日志
**则** 结构化 JSON 写入 stderr

**给定** `config.logOutput = .file(URL(fileURLWithPath: "/var/log/sdk.log"))`
**当** Logger 输出日志
**则** 结构化 JSON 追加写入指定文件

**给定** `config.logOutput = .custom { jsonLine in myLogHandler(jsonLine) }`
**当** Logger 输出日志
**则** JSON 字符串传递给自定义闭包，开发者可集成到 ELK/Datadog 等系统（FR62）

**给定** `logLevel = .none`
**当** Agent 执行完整查询
**则** `Logger.shared.outputCount == 0`
**且** 日志检查使用条件判断（`guard level != .none else { return }`），开销可忽略不计（单次方法调用量级）

**给定** `logLevel = .error`
**当** 发生 `SDKError.apiError`
**则** Logger 输出一条包含 `error.message`、`error.statusCode`、`error.context` 的日志

**给定** 单元测试环境
**当** 测试调用 `Logger.reset()`
**则** `Logger.shared.outputCount == 0`，日志级别恢复为 `.none`
**且** 支持测试注入：`Logger.configure(level: .debug, output: .custom { lines in testBuffer.append(lines) })`

> **API 设计说明：** `Logger.shared` 为只读单例访问（`static let shared`），不直接赋值。配置通过 `Logger.configure(level:output:)` 静态方法注入，内部替换 shared 实例的配置。测试环境通过 `Logger.reset()` 恢复默认状态。这避免了 `Logger.shared` 同时作为读属性和可写变量的语义冲突。

### Story 14.2: 结构化日志输出

作为开发者，
我希望 SDK 输出结构化的日志信息，
以便我可以将其集成到日志聚合系统中。

**验收标准：**

**给定** Logger 输出一条日志
**当** 格式化为结构化输出
**则** 包含字段：`timestamp`（ISO 8601）、`level`（字符串）、`module`（"Agent"/"ToolExecutor"/"QueryEngine"）、`event`（"llm_request"/"tool_execute"/"compact"）、`data`（键值字典）（FR62）

**给定** Agent 查询执行，`logLevel = .debug`
**当** 每轮 LLM 调用完成
**则** Logger 输出：`event: "llm_response"`，`data: {"inputTokens": 1234, "outputTokens": 567, "durationMs": 890, "model": "claude-sonnet-4-6"}`

**给定** 工具执行，`logLevel = .debug`
**当** 工具完成
**则** Logger 输出：`event: "tool_result"`，`data: {"tool": "Read", "inputSize": 50, "durationMs": 12, "outputSize": 3400}`

### Story 14.3: SandboxSettings 配置模型

作为开发者，
我希望可以为 Agent 配置沙盒限制，
以便在生产环境中控制 Agent 的操作范围。

**验收标准：**

**给定** `SandboxSettings` 结构体定义
**当** 开发者配置沙盒
**则** 支持以下限制项（FR63）：
  - 文件系统：`allowedReadPaths: [String]`、`allowedWritePaths: [String]`、`deniedPaths: [String]`
  - 命令黑名单：`deniedCommands: [String]`（如 `["rm", "sudo", "chmod"]`，默认模式）
  - 命令白名单：`allowedCommands: [String]?`（如 `["git", "swift", "xcodebuild"]`，设为非 nil 时启用白名单模式，优先于黑名单）
  - 嵌套沙盒弱化：`allowNestedSandbox: Bool`
**且** 路径匹配使用标准化后的前缀匹配（`/project/` 匹配 `/project/src/file.swift`，不匹配 `/project-backup/`）
**且** 匹配前必须先解析符号链接和 `..` 路径遍历，再与允许列表前缀比对（与 Story 14.4 一致）

**给定** 沙盒配置被应用到 Agent
**当** BashTool 执行 `git status`
**则** 检查 `deniedCommands` 列表，`git` 不在列表中，命令正常执行

**给定** 沙盒配置 `deniedCommands: ["rm"]`
**当** BashTool 执行 `rm -rf /tmp/test`
**则** 返回 `SDKError.permissionDenied("命令 'rm' 被沙盒规则拒绝")`

> **范围说明：** 网络白名单（域名级别限制）不在本 Epic 范围内。Swift URLSession 不原生支持域名白名单，实现需要自定义 URLProtocol 或代理层，复杂度超出 v1.0 范围。如果未来需要网络限制，应创建独立 Epic。

### Story 14.4: 文件系统沙盒强制执行

作为开发者，
我希望沙盒限制在文件工具中被强制执行，
以便 Agent 不能读写指定范围外的文件。

**验收标准：**

**给定** `SandboxSettings(allowedReadPaths: ["/project/"], allowedWritePaths: [], deniedPaths: [])`
**当** FileReadTool 读取 `/project/src/file.swift`
**则** 返回文件内容，无错误

**给定** 上述沙盒配置
**当** FileReadTool 读取 `/etc/passwd`
**则** 返回 `SDKError.permissionDenied("路径 '/etc/passwd' 不在允许读取的范围内")`

**给定** 上述沙盒配置
**当** FileWriteTool 尝试写入 `/project/new-file.swift`
**则** 返回 `SDKError.permissionDenied("路径 '/project/new-file.swift' 不在允许写入的范围内")`

**给定** 符号链接 `/project/link` → `/tmp/secret`
**当** FileReadTool 读取 `/project/link/data.txt`
**则** 路径解析到实际路径 `/tmp/secret/data.txt` 后检查沙盒规则
**且** 返回 `permissionDenied` 错误（符号链接不能逃逸沙盒）

**给定** 路径 `/project/subdir/../../../etc/passwd`
**当** FileReadTool 处理该路径
**则** 路径标准化后解析为 `/etc/passwd`
**且** 返回 `permissionDenied` 错误（路径遍历不能逃逸沙盒）

### Story 14.5: 沙盒与 Bash 命令过滤集成

作为开发者，
我希望沙盒的命令限制在 Bash 工具中被强制执行，
以便危险命令被拦截，同时允许安全命令正常执行。

> **设计决策：** 支持两种模式——**黑名单**（`deniedCommands`，默认模式，向后兼容）和**白名单**（`allowedCommands`，推荐用于生产环境）。白名单模式下，仅列出的命令可执行，其余全部拒绝。两种模式都提取命令的 basename 进行匹配（`/usr/bin/rm` → `rm`），并拦截 Shell 元字符绕过。黑名单是 best-effort 防护，文档中明确声明其局限性；白名单提供强安全保障。

**验收标准：**

**给定** `SandboxSettings(deniedCommands: ["rm", "sudo", "curl"])`（黑名单模式）
**当** BashTool 收到 `rm -rf /tmp/test`
**则** 返回 `SDKError.permissionDenied("命令 'rm' 被沙盒规则拒绝")`

**给定** 上述配置
**当** BashTool 收到 `/usr/bin/rm -rf /tmp/test`（使用完整路径绕过）
**则** 提取 basename 为 `rm`，返回 `permissionDenied` 错误

**给定** `SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])`（白名单模式）
**当** BashTool 收到 `git status`
**则** `git` 在白名单中，命令正常执行

**给定** 上述白名单配置
**当** BashTool 收到 `rm -rf /tmp/test`
**则** `rm` 不在白名单中，返回 `permissionDenied` 错误

**给定** 黑名单或白名单配置
**当** BashTool 收到以下绕过尝试：
  - `bash -c "rm -rf /tmp"`（通过 bash 子 shell）
  - `sh -c "rm -rf /tmp"`（通过 sh 子 shell）
  - `$(rm -rf /tmp)`（命令替换）
  - `\rm -rf /tmp`（转义绕过）
  - `"rm" -rf /tmp`（引号绕过）
**则** Shell 元字符检测逻辑识别这些模式：
  - 如果命令以 `bash -c` / `sh -c` / `zsh -c` 开头，且内部命令包含被拒绝的命令，返回 `permissionDenied`
  - 命令中包含 `$(...)` 或 `` `...` `` 命令替换时，对替换内容中的命令名同样执行过滤
  - 命令名去除前导 `\` 和引号后再进行匹配
**且** 如果元字符解析无法确定安全性，默认拒绝并返回 `permissionDenied("命令包含无法解析的 Shell 元字符")`

> **已知局限性：** 黑名单模式是 best-effort 防护，无法覆盖所有绕过向量。以下攻击路径不在黑名单防护范围内：(1) 管道攻击（`echo payload | bash`）；(2) 通过解释器逃逸（`python -c "..."`、`node -e "..."`）；(3) `exec` 内建命令；(4) 利用合法命令的破坏性能力（如 `find / -delete`）。**生产环境应使用白名单模式**（`allowedCommands`）获得强安全保障。文档和 API 注释中必须明确声明此局限性。

**给定** 同时设置了 `allowedCommands` 和 `deniedCommands`
**当** BashTool 执行
**则** `allowedCommands` 优先（白名单模式生效，`deniedCommands` 被忽略）

**给定** 两者都未设置
**当** BashTool 执行任意命令
**则** 无命令过滤（沙盒不影响命令执行）

---

## Epic 15: SDK Examples 补充

为 Epic 11-14 中已实现的功能补充可运行的示例程序，让开发者通过实际代码理解 SDK 的 Skills 系统、运行时防护（日志与沙盒）、会话生命周期管理和文件缓存等高级功能。每个示例是独立的可执行程序，遵循现有 Examples 目录的模式。

**覆盖的 FR：** FR52-FR64 的示例化（非新功能实现）
**依赖：** Epic 11（技能系统）、Epic 12（文件缓存与上下文注入）、Epic 13（会话生命周期管理）、Epic 14（运行时防护）

### Story 15.1: SkillsExample

作为开发者，
我希望有一个可运行的示例展示技能系统的完整用法，
以便我可以快速理解如何注册、发现和执行技能。

**验收标准：**

**给定** SkillsExample 目录已创建
**当** 运行 `swift run SkillsExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 初始化内置技能（commit、review、simplify、debug、test）
- 列出所有已注册技能（名称、描述、别名）
- 列出用户可调用技能（userInvocable 过滤）
- 注册自定义技能（如 explain 技能）
- 通过 `getSkill()` 查找特定技能
- 通过 Agent 查询调用技能（LLM 使用 Skill 工具）

**给定** 自定义技能注册代码
**当** 运行示例
**则** 自定义技能被成功注册到 SkillRegistry
**且** 后续 `getAllSkills()` 返回包含自定义技能的列表

**给定** Agent 配置了 SkillTool 和核心工具
**当** 向 Agent 发送包含技能调用的查询
**则** Agent 通过 SkillTool 发现并执行技能
**且** 技能的 promptTemplate 作为新提示注入 Agent

> **参考实现：** TypeScript SDK 的 `examples/12-skills.ts`

### Story 15.2: SandboxExample

作为开发者，
我希望有一个可运行的示例展示沙盒配置和强制执行，
以便我可以了解如何在生产环境中限制 Agent 的操作范围。

**验收标准：**

**给定** SandboxExample 目录已创建
**当** 运行 `swift run SandboxExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 配置文件系统路径限制（allowedReadPaths、allowedWritePaths、deniedPaths）
- 配置命令黑名单（deniedCommands）拒绝危险命令
- 配置命令白名单（allowedCommands）仅允许安全命令
- 展示路径遍历防护和符号链接解析
- 展示 Shell 元字符检测（bash -c、命令替换等绕过尝试）

**给定** 配置 `SandboxSettings(allowedReadPaths: ["/project/"], allowedWritePaths: [])`
**当** Agent 尝试读取沙盒外文件
**则** 返回 `permissionDenied` 错误
**且** 示例输出展示错误被正确捕获和处理

**给定** 配置 `SandboxSettings(deniedCommands: ["rm", "sudo"])`
**当** Agent 尝试执行 `rm -rf /tmp/test`
**则** 命令被拦截
**且** 示例输出展示黑名单工作原理

**给定** 配置 `SandboxSettings(allowedCommands: ["git", "swift"])`
**当** Agent 尝试执行 `git status` 和 `rm -rf /tmp`
**则** git 命令被允许，rm 命令被拒绝
**且** 示例输出展示白名单与黑名单的区别

### Story 15.3: LoggerExample

作为开发者，
我希望有一个可运行的示例展示日志系统的配置和使用，
以便我可以了解如何将 SDK 日志集成到自己的日志系统中。

**验收标准：**

**给定** LoggerExample 目录已创建
**当** 运行 `swift run LoggerExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 配置日志级别（none、error、warn、info、debug）
- 配置日志输出到控制台（stderr）
- 配置日志输出到文件
- 配置自定义日志输出（闭包，集成到 ELK/Datadog 等）
- 展示结构化 JSON 日志格式（timestamp、level、module、event、data）
- 使用 `Logger.reset()` 重置状态

**给定** `config.logLevel = .debug`
**当** Agent 执行完整查询
**则** 控制台输出包含 `llm_response` 和 `tool_result` 等事件的结构化日志

**给定** `config.logOutput = .custom { jsonLine in buffer.append(jsonLine) }`
**当** Agent 执行查询
**则** 自定义闭包接收到结构化 JSON 字符串
**且** 示例输出展示如何在自定义处理中使用日志数据

**给定** `config.logLevel = .none`
**当** Agent 执行完整查询
**则** 无日志输出（零开销验证）

### Story 15.4: ModelSwitchingExample

作为开发者，
我希望有一个可运行的示例展示运行时动态模型切换，
以便我可以根据任务需要选择最合适的模型。

**验收标准：**

**给定** ModelSwitchingExample 目录已创建
**当** 运行 `swift run ModelSwitchingExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 使用默认模型（如 claude-sonnet-4-6）创建 Agent
- 执行第一次查询
- 调用 `agent.switchModel("claude-opus-4-6")` 切换模型
- 执行第二次查询（使用新模型）
- 查看成本细分（包含两个模型的 token 计数）
- 验证空字符串模型名称的错误处理

**给定** 模型从 sonnet 切换到 opus
**当** 两次查询完成后检查 `result.usage`
**则** `costBreakdown` 包含两个模型的独立计数
**且** 示例输出展示各模型的 token 使用量和成本

**给定** 调用 `agent.switchModel("")`
**当** 方法执行
**则** 抛出 `SDKError.invalidConfiguration`
**且** 示例展示 try/catch 错误处理模式

### Story 15.5: QueryAbortExample

作为开发者，
我希望有一个可运行的示例展示如何中断正在执行的查询，
以便我可以了解如何在长时间运行的任务中实现用户取消功能。

**验收标准：**

**给定** QueryAbortExample 目录已创建
**当** 运行 `swift run QueryAbortExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 使用 Swift Task 启动 Agent 查询
- 使用 `Task.cancel()` 或 `agent.interrupt()` 取消查询
- 处理 `QueryResult.isCancelled` 和部分结果
- 使用流式 API（AsyncStream）观察取消事件

**给定** Agent 正在执行多轮工具调用
**当** 取消信号到达
**则** 当前 HTTP 请求被取消，工具执行停止
**且** 返回的 QueryResult 包含已完成轮次的结果
**且** 示例输出展示部分结果的处理方式

**给定** 流式响应被中断
**当** 取消信号到达
**则** AsyncStream 发出 `SDKMessage.cancelled` 事件后正常结束
**且** 示例输出展示流式取消的处理

### Story 15.6: ContextInjectionExample

作为开发者，
我希望有一个可运行的示例展示文件缓存和上下文注入功能，
以便我可以了解 SDK 如何自动为 LLM 提供项目上下文。

**验收标准：**

**给定** ContextInjectionExample 目录已创建
**当** 运行 `swift run ContextInjectionExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 配置 FileCache 参数（maxEntries、maxSizeBytes、maxEntrySizeBytes）
- 展示缓存命中率统计（hitCount、missCount、evictionCount）
- 展示 Git 状态自动注入（`<git-context>` 块）
- 展示项目文档发现（CLAUDE.md / AGENT.md 的 `<project-instructions>` 块）
- 展示自定义项目根目录配置（`config.projectRoot`）
- 展示缓存失效（写入文件后缓存条目失效）

**给定** FileCache 配置完成
**当** Agent 连续读取同一文件
**则** 第二次读取命中缓存（无磁盘 I/O）
**且** 示例输出展示缓存统计信息

**给定** 项目目录存在 CLAUDE.md 文件
**当** Agent 初始化
**则** 系统提示包含 `<project-instructions>` 块
**且** 示例展示项目指令如何影响 Agent 行为

### Story 15.7: MultiTurnExample

作为开发者，
我希望有一个可运行的示例展示多轮对话，
以便我可以了解如何与 Agent 进行持续交互。

**验收标准：**

**给定** MultiTurnExample 目录已创建
**当** 运行 `swift run MultiTurnExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 创建 Agent 并执行第一轮查询（建立上下文）
- 使用同一 Agent 执行第二轮查询（引用第一轮的内容）
- 使用 `agent.getMessages()` 获取会话历史
- 展示 Agent 在多轮对话中的上下文记忆能力

**给定** Agent 第一轮被告知 "我的名字是 Nick"
**当** 第二轮询问 "我叫什么名字？"
**则** Agent 回答 "Nick"
**且** 示例输出展示跨查询的上下文保持

> **参考实现：** TypeScript SDK 的 `examples/03-multi-turn.ts`

### Story 15.8: OpenAICompatExample

作为开发者，
我希望有一个可运行的示例展示如何使用 OpenAI 兼容 API，
以便我可以在非 Anthropic 后端（DeepSeek、Qwen、vLLM、Ollama 等）上使用 SDK。

**验收标准：**

**给定** OpenAICompatExample 目录已创建
**当** 运行 `swift run OpenAICompatExample`
**则** 示例编译并运行无错误

**给定** 示例代码
**当** 阅读代码
**则** 演示以下场景：
- 使用 `provider: .openai` 配置 Agent
- 设置 `baseURL` 指向兼容端点
- 使用环境变量配置（CODEANY_API_KEY、CODEANY_BASE_URL、CODEANY_MODEL）
- 展示与 Anthropic 提供者的对比配置

**给定** 配置 `provider: .openai, baseURL: "https://open.bigmodel.cn/api/coding/paas/v4"`
**当** Agent 执行查询
**则** 请求发送到指定端点
**且** 示例输出展示成功响应

> **参考实现：** TypeScript SDK 的 `examples/14-openai-compat.ts`

---

## Epic 16: 官方 TypeScript SDK 兼容性验证

通过编写覆盖官方 TypeScript SDK 所有用法模式的示例程序，系统性验证 Swift SDK 的 API 兼容性。每个示例既是文档也是兼容性测试——如果某个用法在 Swift SDK 中不支持，示例中记录缺失点和改造方案。

**目标来源：** 官方 TypeScript SDK 文档 https://code.claude.com/docs/en/agent-sdk/typescript
**覆盖的 FR：** FR50（补充）— 兼容性验证示例
**依赖：** Epic 1-14（所有基础功能必须已实现）

### 兼容性矩阵

下表映射 TypeScript SDK 的每个主要 API 到 Swift SDK 的等价实现，每个 Story 验证一组映射：

| TypeScript SDK | Swift SDK | Story |
|---|---|---|
| `query({ prompt, options })` | `agent.stream()` / `agent.prompt()` | 16.1 |
| `tool()` + Zod schema | `defineTool()` + Codable | 16.2 |
| `createSdkMcpServer()` | InProcessMCPServer | 16.5 |
| `listSessions()` / `getSessionMessages()` 等 | SessionStore 方法 | 16.6 |
| Query object methods (15+) | Agent/Query 方法 | 16.7 |
| `Options` (40+ 字段) | `AgentOptions` / `SDKConfiguration` | 16.8 |
| `SDKMessage` (20+ 子类型) | `SDKMessage` enum cases | 16.3 |
| 18 HookEvent + HookInput 类型 | HookRegistry + HookInput | 16.4 |
| 6 PermissionMode + CanUseTool | PermissionMode + CanUseToolFn | 16.9 |
| 4 McpServerConfig 类型 | McpTransportConfig | 16.5 |
| AgentDefinition + Agent 工具 | SubAgentSpawner | 16.10 |
| ThinkingConfig / effort | ThinkingConfig | 16.11 |
| SandboxSettings | SandboxSettings | 16.12 |
| `outputFormat` (structured output) | 待验证 | 16.8 |
| `streamInput()` (multi-turn) | 待验证 | 16.8 |
| `plugins` | 待验证 | 16.8 |
| `settingSources` | 待验证 | 16.8 |
| `promptSuggestions` | 待验证 | 16.8 |
| `enableFileCheckpointing` + `rewindFiles()` | 待验证 | 16.8 |

### Story 16.1: Core Query API 兼容性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 `query()` 等价 API 与 TypeScript SDK 的核心用法完全兼容，
以便开发者可以无缝迁移 TypeScript 代码到 Swift。

**验收标准：**

**给定** 一个 TypeScript SDK 的基本用法示例：
```typescript
// TS: 基本查询
for await (const message of query({ prompt: "Hello" })) {
  if (message.type === "result") console.log(message.result);
}
```
**当** 用 Swift SDK 编写等价代码
**则** `agent.stream("Hello")` 产生等效的 `SDKMessage` 事件流
**且** `.result` case 包含 `result` 字符串和 `totalCostUsd`、`usage`、`numTurns` 字段

**给定** TypeScript SDK 的阻塞式用法（通过收集所有消息获取最终结果）
**当** 用 Swift SDK 的 `agent.prompt()` 调用
**则** 返回 `QueryResult` 包含与 TS `SDKResultMessage` 等价的所有字段：`result`、`isError`、`numTurns`、`totalCostUsd`、`usage`、`durationMs`、`stopReason`、`modelUsage`（按模型分类的使用量）

**给定** TypeScript SDK 支持 `prompt` 为 `string | AsyncIterable<SDKUserMessage>`
**当** 检查 Swift SDK 的 prompt 参数
**则** 验证是否支持 `String` 和流式输入两种模式
**如果不支持流式 prompt** → 记录为兼容性缺口，需在 Query 层添加 `streamInput()` 等价方法

**给定** 示例 `Examples/CompatCoreQuery/` 目录
**当** 运行 `swift run CompatCoreQuery`
**则** 示例演示以下 TypeScript SDK 等价用法：
  - 基本 string prompt 查询（阻塞式和流式）
  - 捕获 `SDKResultMessage`（成功和错误子类型）
  - 捕获 `SDKSystemMessage`（init 子类型）并提取 `session_id`
  - 多轮查询（使用相同 Agent 实例）
  - 查询中断（AbortController / Task.cancel()）

> **参考：** TS SDK 文档 `query()` 函数、`SDKResultMessage`、`SDKSystemMessage` 类型

### Story 16.2: 工具系统兼容性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的工具定义和执行与 TypeScript SDK 完全兼容，
以便 TypeScript SDK 的所有工具用法都能在 Swift 中实现。

**验收标准：**

**给定** TypeScript SDK 的 `tool()` 函数用法：
```typescript
const searchTool = tool("search", "Search the web",
  { query: z.string() },
  async ({ query }) => ({ content: [{ type: "text", text: `Results: ${query}` }] }),
  { annotations: { readOnlyHint: true, openWorldHint: true } }
);
```
**当** 用 Swift SDK 的 `defineTool()` 编写等价代码
**则** 工具定义包含 `name`、`description`、`inputSchema`、执行闭包
**且** `ToolAnnotations` 包含 `readOnly`、`destructive`、`idempotent`、`openWorld` 四个字段
**且** 工具执行返回 `ToolResult` 与 TS `CallToolResult` 结构兼容（`content` 数组 + `isError`）

**给定** TypeScript SDK 的 `createSdkMcpServer()` 用法：
```typescript
const server = createSdkMcpServer({
  name: "my-server", version: "1.0",
  tools: [searchTool]
});
```
**当** 用 Swift SDK 编写等价代码
**则** 验证进程内 MCP 服务器创建是否支持 `tools` 数组参数
**如果不支持** → 记录缺口，需在 MCP 模块添加 `createSdkMcpServer()` 等价函数

**给定** TypeScript SDK 的内置工具列表（20 个）：Agent、AskUserQuestion、Bash、Monitor、TaskOutput、Edit、Read、Write、Glob、Grep、TaskStop、NotebookEdit、WebFetch、WebSearch、TodoWrite、ExitPlanMode、ListMcpResources、ReadMcpResource、Config、EnterWorktree
**当** 逐一检查 Swift SDK 的工具注册表
**则** 每个工具在 Swift 中都有等价实现
**且** 每个工具的 `inputSchema` 字段名称和类型与 TS SDK `ToolInputSchemas` 一致

**给定** TypeScript SDK 的工具输出类型（`ToolOutputSchemas`）
**当** 检查 Swift SDK 的 `ToolResult`
**则** 每个 TS 工具输出类型在 Swift 中有对应结构（例如 `ReadOutput` 包含 `type` 鉴别字段：text/image/notebook/pdf/parts）

**给定** 示例 `Examples/CompatToolSystem/` 目录
**当** 运行 `swift run CompatToolSystem`
**则** 示例演示：
  - 自定义工具定义（含 annotations）
  - `createSdkMcpServer()` 等价用法（如支持）
  - 每个内置工具的输入参数验证（与 TS SDK ToolInputSchemas 对比）
  - 工具输出结构验证（与 TS SDK ToolOutputSchemas 对比）
  - `ToolAnnotations` 对权限系统行为的影响

> **参考：** TS SDK 文档 `tool()`、`createSdkMcpServer()`、`ToolInputSchemas`、`ToolOutputSchemas`、`ToolAnnotations`

### Story 16.3: 消息类型完整性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 `SDKMessage` 包含 TypeScript SDK 的所有消息子类型，
以便消费消息流的代码能正确处理所有事件。

**验收标准：**

**给定** TypeScript SDK 的完整 `SDKMessage` 联合类型（20 种）：
  - `SDKAssistantMessage`（type: "assistant"，含 `uuid`、`session_id`、`message`、`parent_tool_use_id`、`error`）
  - `SDKUserMessage`（type: "user"，含 `uuid`、`session_id`、`message`、`parent_tool_use_id`、`isSynthetic`、`tool_use_result`）
  - `SDKResultMessage`（type: "result"，两种子类型：success 和 error_*）
  - `SDKSystemMessage`（type: "system"，subtype: "init"）
  - `SDKPartialAssistantMessage`（type: "stream_event"）
  - `SDKCompactBoundaryMessage`（type: "system"，subtype: "compact_boundary"）
  - `SDKStatusMessage`（type: "system"，subtype: "status"）
  - `SDKTaskNotificationMessage`（type: "system"，subtype: "task_notification"）
  - `SDKTaskStartedMessage`（type: "system"，subtype: "task_started"）
  - `SDKTaskProgressMessage`（type: "system"，subtype: "task_progress"）
  - `SDKToolProgressMessage`（type: "tool_progress"）
  - `SDKHookStartedMessage`（type: "system"，subtype: "hook_started"）
  - `SDKHookProgressMessage`（type: "system"，subtype: "hook_progress"）
  - `SDKHookResponseMessage`（type: "system"，subtype: "hook_response"）
  - `SDKAuthStatusMessage`（type: "auth_status"）
  - `SDKFilesPersistedEvent`（type: "system"，subtype: "files_persisted"）
  - `SDKRateLimitEvent`（type: "rate_limit_event"）
  - `SDKLocalCommandOutputMessage`（type: "system"，subtype: "local_command_output"）
  - `SDKPromptSuggestionMessage`（type: "prompt_suggestion"）
  - `SDKToolUseSummaryMessage`（type: "tool_use_summary"）
**当** 逐一检查 Swift SDK 的 `SDKMessage` enum
**则** 每种消息类型都有对应的 Swift case
**且** 每个 case 的关联值包含 TS SDK 文档中定义的所有字段
**如果缺少某种类型** → 记录缺口，列出需要新增的 case 和关联值字段

**给定** `SDKResultMessage` 的成功子类型
**当** 检查 Swift 等价类型
**则** 包含字段：`result`、`durationMs`、`durationApiMs`、`isError`、`numTurns`、`stopReason`、`totalCostUsd`、`usage`、`modelUsage`、`permissionDenials`、`structuredOutput`

**给定** `SDKResultMessage` 的错误子类型
**当** 检查 Swift 等价类型
**则** 包含错误子类型：`error_max_turns`、`error_during_execution`、`error_max_budget_usd`、`error_max_structured_output_retries`
**且** 错误子类型包含 `errors: [String]` 字段

**给定** `SDKAssistantMessage` 的 `error` 字段
**当** 检查 Swift 等价
**则** 支持错误类型：`authentication_failed`、`billing_error`、`rate_limit`、`invalid_request`、`server_error`、`max_output_tokens`、`unknown`

**给定** 示例 `Examples/CompatMessageTypes/` 目录
**当** 运行 `swift run CompatMessageTypes`
**则** 示例执行一个完整查询，使用 `switch` 遍历 `SDKMessage` 的所有 case
**且** 对每种消息类型打印其字段值，验证与 TS SDK 的字段名和结构一致
**且** 输出一份兼容性报告：`[PASS]` 或 `[MISSING: 需要新增的字段/类型]`

> **参考：** TS SDK 文档 Message Types 全部小节

### Story 16.4: Hook 系统完整性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 Hook 系统覆盖 TypeScript SDK 的所有 18 个事件和对应的输入/输出类型，
以便所有 Hook 用法都能从 TypeScript 迁移到 Swift。

**验收标准：**

**给定** TypeScript SDK 的 18 个 HookEvent：
  `PreToolUse`、`PostToolUse`、`PostToolUseFailure`、`Notification`、`UserPromptSubmit`、`SessionStart`、`SessionEnd`、`Stop`、`SubagentStart`、`SubagentStop`、`PreCompact`、`PermissionRequest`、`Setup`、`TeammateIdle`、`TaskCompleted`、`ConfigChange`、`WorktreeCreate`、`WorktreeRemove`
**当** 逐一检查 Swift SDK 的 HookEvent 枚举
**则** 每个事件都有对应的 case
**如果缺少某个事件** → 记录缺口

**给定** 每个 HookEvent 的专用 HookInput 类型
**当** 检查 Swift SDK 的等价输入结构
**则** 每种 HookInput 包含 TS SDK 文档中的所有字段：
  - `BaseHookInput`：`session_id`、`transcript_path`、`cwd`、`permission_mode`、`agent_id`、`agent_type`
  - `PreToolUseHookInput`：+ `tool_name`、`tool_input`、`tool_use_id`
  - `PostToolUseHookInput`：+ `tool_name`、`tool_input`、`tool_response`、`tool_use_id`
  - `StopHookInput`：+ `stop_hook_active`、`last_assistant_message`
  - `SubagentStartHookInput`：+ `agent_id`、`agent_type`
  - `SubagentStopHookInput`：+ `agent_id`、`agent_transcript_path`、`agent_type`、`last_assistant_message`
  - `PreCompactHookInput`：+ `trigger`（"manual"/"auto"）、`custom_instructions`
  - `PermissionRequestHookInput`：+ `tool_name`、`tool_input`、`permission_suggestions`
  - 以及其余所有 HookInput 类型

**给定** TypeScript SDK 的 `HookCallbackMatcher`（`matcher?` 正则 + `hooks` 数组 + `timeout?`）
**当** 检查 Swift SDK 的等价注册 API
**则** 支持 matcher 过滤、多个 hook 回调和超时配置

**给定** TypeScript SDK 的 `SyncHookJSONOutput`（含 `decision`、`systemMessage`、`reason`、`hookSpecificOutput` 等字段）
**当** 检查 Swift SDK 的 HookOutput
**则** 每种 `hookSpecificOutput` 变体都有对应实现：
  - PreToolUse：`permissionDecision`（allow/deny/ask）、`updatedInput`、`additionalContext`
  - PostToolUse：`updatedMCPToolOutput`、`additionalContext`
  - PermissionRequest：`decision`（allow 带 `updatedInput`/`updatedPermissions`，或 deny 带 `message`/`interrupt`）
  - UserPromptSubmit/SessionStart/Setup/SubagentStart：`additionalContext`

**给定** 示例 `Examples/CompatHooks/` 目录
**当** 运行 `swift run CompatHooks`
**则** 示例为每种 HookEvent 注册一个回调
**且** 每个回调打印接收到的 HookInput 字段
**且** PreToolUse hook 演示 `decision: "block"` 拦截工具执行
**且** PostToolUse hook 演示审计日志记录
**且** 输出兼容性报告：每个事件的 `[PASS]` / `[MISSING]` 状态

> **参考：** TS SDK 文档 Hook Types 全部小节

### Story 16.5: MCP 集成完整性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 MCP 集成支持 TypeScript SDK 的所有服务器配置类型和运行时管理操作，
以便所有 MCP 用法都能在 Swift 中使用。

**验收标准：**

**给定** TypeScript SDK 的 5 种 McpServerConfig：
  - `McpStdioServerConfig`：`type: "stdio"`、`command`、`args`、`env`
  - `McpSSEServerConfig`：`type: "sse"`、`url`、`headers`
  - `McpHttpServerConfig`：`type: "http"`、`url`、`headers`
  - `McpSdkServerConfigWithInstance`：`type: "sdk"`、`name`、`instance`
  - `McpClaudeAIProxyServerConfig`：`type: "claudeai-proxy"`、`url`、`id`
**当** 逐一检查 Swift SDK 的 MCP 配置类型
**则** 每种传输类型都有对应实现
**如果缺少某种类型** → 记录缺口

**给定** TypeScript SDK 的 MCP 运行时操作：
  - `mcpServerStatus()` → 返回服务器连接状态和工具列表
  - `reconnectMcpServer(serverName)` → 重连指定服务器
  - `toggleMcpServer(serverName, enabled)` → 启用/禁用服务器
  - `setMcpServers(servers)` → 动态替换 MCP 服务器集（返回 added/removed/errors）
**当** 检查 Swift SDK 的 MCP 管理接口
**则** 每个操作都有对应方法
**如果缺少** → 记录缺口

**给定** TypeScript SDK 的 `McpServerStatus` 类型：
```typescript
{ name, status: "connected"|"failed"|"needs-auth"|"pending"|"disabled",
  serverInfo?, error?, config?, scope?, tools?: [{name, description?, annotations?}] }
```
**当** 检查 Swift SDK 的等价类型
**则** 包含所有字段，特别是 `tools` 数组含 `annotations`

**给定** TypeScript SDK 的 `ListMcpResources` / `ReadMcpResource` 工具用法
**当** 通过 Swift SDK 调用
**则** 输入/输出结构与 TS SDK 的 `ListMcpResourcesInput` / `ReadMcpResourceInput` / 对应 Output 类型一致

**给定** 示例 `Examples/CompatMCP/` 目录
**当** 运行 `swift run CompatMCP`
**则** 示例演示：
  - 配置 stdio MCP 服务器
  - 配置 SSE/HTTP MCP 服务器（如支持）
  - 创建进程内 MCP 服务器（createSdkMcpServer 等价）
  - 动态管理服务器（添加/移除/重连）
  - 查询服务器状态和工具列表
  - 使用 MCP 工具（`mcp__{server}__{tool}` 命名空间）
  - MCP 资源操作（list/read）

> **参考：** TS SDK 文档 McpServerConfig、AgentMcpServerSpec、McpServerStatus

### Story 16.6: 会话管理完整性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的会话管理 API 覆盖 TypeScript SDK 的所有会话操作，
以便所有会话相关功能都能在 Swift 中使用。

**验收标准：**

**给定** TypeScript SDK 的 5 个会话管理函数：
  - `listSessions({ dir?, limit?, includeWorktrees? })` → `SDKSessionInfo[]`
  - `getSessionMessages(sessionId, { dir?, limit?, offset? })` → `SessionMessage[]`
  - `getSessionInfo(sessionId, { dir? })` → `SDKSessionInfo | undefined`
  - `renameSession(sessionId, title, { dir? })` → `void`
  - `tagSession(sessionId, tag | null, { dir? })` → `void`
**当** 逐一检查 Swift SDK 的 SessionStore 或等价 API
**则** 每个函数都有对应的 Swift 方法
**且** 参数名和语义一致

**给定** TypeScript SDK 的 `SDKSessionInfo` 类型：
```typescript
{ sessionId, summary, lastModified, fileSize?, customTitle?,
  firstPrompt?, gitBranch?, cwd?, tag?, createdAt? }
```
**当** 检查 Swift SDK 的等价类型
**则** 包含所有字段

**给定** TypeScript SDK 的 `SessionMessage` 类型：
```typescript
{ type: "user"|"assistant", uuid, session_id, message, parent_tool_use_id: null }
```
**当** 检查 Swift SDK 的等价类型
**则** 包含所有字段

**给定** TypeScript SDK 的会话恢复选项：
  - `resume: sessionId`（恢复会话）
  - `continue: true`（继续最近会话）
  - `forkSession: true`（分叉而非继续）
  - `resumeSessionAt: messageUUID`（从指定消息恢复）
  - `sessionId: uuid`（使用指定 ID）
  - `persistSession: false`（禁用持久化）
**当** 逐一检查 Swift SDK 的 AgentOptions
**则** 每个选项都有对应的 Swift 配置字段
**如果缺少** → 记录缺口

**给定** 示例 `Examples/CompatSessions/` 目录
**当** 运行 `swift run CompatSessions`
**则** 示例演示：
  - 创建会话并获取 session_id
  - 列出所有会话（含过滤和排序）
  - 获取会话消息（含分页）
  - 获取单个会话信息
  - 重命名和标记会话
  - 恢复会话（resume）
  - 分叉会话（fork）
  - 禁用会话持久化
  - 跨查询上下文保持

> **参考：** TS SDK 文档 `listSessions()`、`getSessionMessages()`、`getSessionInfo()`、`renameSession()`、`tagSession()`

### Story 16.7: Query 对象方法兼容性验证

作为 SDK 开发者，
我希望验证 Swift SDK 提供与 TypeScript SDK Query 对象等价的所有运行时控制方法，
以便开发者可以在查询过程中动态控制 Agent 行为。

**验收标准：**

**给定** TypeScript SDK 的 Query 对象方法（16 个）：

| 方法 | 描述 | 验证点 |
|---|---|---|
| `interrupt()` | 中断查询（仅流式输入模式） | 是否支持流式模式下的中断 |
| `rewindFiles(userMessageId, { dryRun? })` | 恢复文件到指定消息时的状态 | 需要 enableFileCheckpointing |
| `setPermissionMode(mode)` | 动态切换权限模式 | 是否支持运行时切换 |
| `setModel(model?)` | 动态切换模型 | 对比 agent.switchModel() |
| `initializationResult()` | 获取完整初始化结果 | 返回 commands/agents/models/account |
| `supportedCommands()` | 获取可用 slash 命令 | 返回 SlashCommand[] |
| `supportedModels()` | 获取可用模型列表 | 返回 ModelInfo[] |
| `supportedAgents()` | 获取可用 subagents | 返回 AgentInfo[] |
| `mcpServerStatus()` | 获取 MCP 服务器状态 | 返回每个服务器的连接状态 |
| `reconnectMcpServer(name)` | 重连 MCP 服务器 | 按名称重连 |
| `toggleMcpServer(name, enabled)` | 启用/禁用 MCP 服务器 | 运行时切换 |
| `setMcpServers(servers)` | 动态替换 MCP 服务器集 | 返回 added/removed/errors |
| `streamInput(stream)` | 流式输入（多轮对话） | AsyncIterable 输入 |
| `stopTask(taskId)` | 停止后台任务 | 按 ID 停止 |
| `close()` | 关闭查询并清理资源 | 强制终止 |

**当** 逐一检查 Swift SDK 的 Agent/Query/Stream 相关 API
**则** 每个方法都有对应的 Swift 实现
**如果缺少** → 记录缺口和改造方案

**给定** `SDKControlInitializeResponse` 类型：
```typescript
{ commands: SlashCommand[], agents: AgentInfo[], output_style,
  available_output_styles: string[], models: ModelInfo[], account: AccountInfo, fast_mode_state? }
```
**当** 检查 Swift SDK 的等价
**则** 包含所有字段

**给定** 示例 `Examples/CompatQueryMethods/` 目录
**当** 运行 `swift run CompatQueryMethods`
**则** 示例演示每个 Query 方法（或记录缺失）：
  - 获取初始化结果
  - 查询支持的命令/模型/agents
  - 动态切换模型和权限模式
  - 管理 MCP 服务器状态
  - 流式输入多轮对话
  - 停止后台任务
  - 文件回滚（checkpointing）
  - 关闭查询
**且** 输出每个方法的兼容性状态：`[PASS]` / `[MISSING: 改造方案]`

> **参考：** TS SDK 文档 Query object、SDKControlInitializeResponse

### Story 16.8: Agent Options 完整参数验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 `AgentOptions` / `SDKConfiguration` 覆盖 TypeScript SDK 的所有 Options 字段，
以便开发者迁移时不需要妥协功能。

**验收标准：**

**给定** TypeScript SDK 的完整 Options 字段列表，按优先级分组：

**核心配置（必须支持）：**
  - `allowedTools: string[]` — 工具白名单
  - `disallowedTools: string[]` — 工具黑名单
  - `maxTurns: number` — 最大轮次
  - `maxBudgetUsd: number` — 最大预算
  - `model: string` — 模型选择
  - `fallbackModel: string` — 备用模型
  - `systemPrompt: string | { type: 'preset', preset: 'claude_code', append?: string }` — 系统提示词
  - `permissionMode: PermissionMode` — 权限模式（6 种）
  - `canUseTool: CanUseTool` — 自定义授权回调
  - `cwd: string` — 工作目录
  - `env: Record<string, string>` — 环境变量
  - `mcpServers: Record<string, McpServerConfig>` — MCP 服务器

**高级配置（重要但非阻塞）：**
  - `thinking: ThinkingConfig` — 思考配置（adaptive/enabled/disabled）
  - `effort: 'low' | 'medium' | 'high' | 'max'` — 努力级别
  - `hooks: Partial<Record<HookEvent, HookCallbackMatcher[]>>` — 钩子配置
  - `sandbox: SandboxSettings` — 沙盒配置
  - `agents: Record<string, AgentDefinition>` — subagent 定义
  - `toolConfig: ToolConfig` — 工具行为配置
  - `outputFormat: { type: 'json_schema', schema }` — 结构化输出
  - `includePartialMessages: boolean` — 部分消息流
  - `promptSuggestions: boolean` — 提示建议

**会话配置：**
  - `resume: string` / `continue: boolean` / `forkSession: boolean` / `resumeSessionAt: string`
  - `sessionId: string` / `persistSession: boolean`

**扩展配置（按需支持）：**
  - `settingSources: SettingSource[]` — 文件系统设置源（user/project/local）
  - `plugins: SdkPluginConfig[]` — 插件加载
  - `betas: SdkBeta[]` — Beta 功能
  - `executable: 'bun' | 'deno' | 'node'` — 运行时选择（Swift 不适用，标记 N/A）
  - `spawnClaudeCodeProcess` — 自定义进程生成（Swift 不适用，标记 N/A）
  - `additionalDirectories: string[]` — 额外目录
  - `debug: boolean` / `debugFile: string` — 调试模式
  - `stderr: (data: string) => void` — stderr 回调
  - `strictMcpConfig: boolean` — 严格 MCP 验证
  - `extraArgs: Record<string, string | null>` — 额外参数

**当** 逐一检查 Swift SDK 的 AgentOptions / SDKConfiguration
**则** 核心配置的每个字段都有对应的 Swift 属性
**且** 高级配置大部分有对应
**且** 扩展配置中不适用的标记为 N/A
**对于每个缺失的字段** → 记录缺口和改造方案

**给定** TypeScript SDK 的 `ThinkingConfig` 类型：
```typescript
{ type: "adaptive" } | { type: "enabled", budgetTokens?: number } | { type: "disabled" }
```
**当** 检查 Swift SDK 的 ThinkingConfig
**则** 支持三种类型
**且** `effort` 级别与 ThinkingConfig 正确联动

**给定** TypeScript SDK 的 `outputFormat` 用法（结构化输出）
**当** 检查 Swift SDK
**则** 验证是否支持 JSON Schema 定义输出格式
**如果不支持** → 记录缺口，设计 `outputFormat` 等价配置

**给定** TypeScript SDK 的 `systemPrompt` preset 模式：
```typescript
systemPrompt: { type: "preset", preset: "claude_code", append: "额外指令" }
```
**当** 检查 Swift SDK
**则** 验证是否支持 preset 模式和 append 扩展
**如果不支持** → 记录缺口

**给定** 示例 `Examples/CompatOptions/` 目录
**当** 运行 `swift run CompatOptions`
**则** 示例为每个 Options 字段设置值并验证生效
**且** 输出字段级别的兼容性矩阵：`[PASS]` / `[N/A]` / `[MISSING: 改造方案]`

> **参考：** TS SDK 文档 Options、ThinkingConfig、SettingSource、ToolConfig、SdkPluginConfig

### Story 16.9: 权限系统完整性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的权限系统完全覆盖 TypeScript SDK 的所有权限类型和操作，
以便所有权限控制模式都能在 Swift 中使用。

**验收标准：**

**给定** TypeScript SDK 的 6 种 PermissionMode：
  `default`、`acceptEdits`、`bypassPermissions`、`plan`、`dontAsk`、`auto`
**当** 逐一测试 Swift SDK 的每种模式
**则** 每种模式的行为与 TS SDK 文档描述一致

**给定** TypeScript SDK 的 `CanUseTool` 回调：
```typescript
(toolName, input, { signal, suggestions, blockedPath, decisionReason, toolUseID, agentID }) =>
  Promise<PermissionResult>
```
**当** 检查 Swift SDK 的 CanUseToolFn
**则** 参数包含所有选项字段
**且** `PermissionResult` 支持两种变体：
  - `{ behavior: "allow", updatedInput?, updatedPermissions?, toolUseID? }`
  - `{ behavior: "deny", message, interrupt?, toolUseID? }`

**给定** TypeScript SDK 的 `PermissionUpdate` 操作类型：
  - `addRules` / `replaceRules` / `removeRules`（含 `rules: PermissionRuleValue[]`、`behavior: PermissionBehavior`、`destination`）
  - `setMode`（含 `mode: PermissionMode`、`destination`）
  - `addDirectories` / `removeDirectories`（含 `directories`、`destination`）
**当** 检查 Swift SDK 的等价类型
**则** 每种操作类型都有对应实现
**且** `PermissionBehavior` 支持 allow/deny/ask
**且** `PermissionUpdateDestination` 支持 userSettings/projectSettings/localSettings/session/cliArg
**如果缺少** → 记录缺口

**给定** TypeScript SDK 的 `allowDangerouslySkipPermissions` 选项
**当** 检查 Swift SDK
**则** 验证 bypassPermissions 模式是否需要显式确认

**给定** 示例 `Examples/CompatPermissions/` 目录
**当** 运行 `swift run CompatPermissions`
**则** 示例演示：
  - 6 种权限模式的行为差异
  - canUseTool 回调（allow/deny/modify input）
  - PermissionUpdate 操作
  - 权限建议（suggestions）处理
  - disallowedTools 优先级验证
**且** 输出兼容性报告

> **参考：** TS SDK 文档 PermissionMode、CanUseTool、PermissionResult、PermissionUpdate、PermissionBehavior

### Story 16.10: Subagent 系统兼容性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 subagent 系统完全覆盖 TypeScript SDK 的 AgentDefinition 和 Agent 工具用法，
以便所有多 Agent 编排模式都能在 Swift 中使用。

**验收标准：**

**给定** TypeScript SDK 的 `AgentDefinition` 类型：
```typescript
{ description: string, tools?: string[], disallowedTools?: string[], prompt: string,
  model?: "sonnet"|"opus"|"haiku"|"inherit", mcpServers?: AgentMcpServerSpec[],
  skills?: string[], maxTurns?: number, criticalSystemReminder_EXPERIMENTAL?: string }
```
**当** 检查 Swift SDK 的 AgentDefinition 等价类型
**则** 包含所有字段
**且** `model` 支持 sonnet/opus/haiku/inherit 四个值
**且** `mcpServers` 支持引用父级服务器名和内联配置两种模式
**如果缺少字段** → 记录缺口

**给定** TypeScript SDK 的 Agent 工具输入类型：
```typescript
{ description, prompt, subagent_type, model?, resume?, run_in_background?,
  max_turns?, name?, team_name?, mode?, isolation?: "worktree" }
```
**当** 检查 Swift SDK 的 AgentTool 输入
**则** 包含所有字段，特别是 `run_in_background`、`mode`、`isolation: "worktree"`

**给定** TypeScript SDK 的 Agent 工具输出类型（三种状态）：
  - `status: "completed"`（含 `agentId`、`content`、`totalToolUseCount`、`totalDurationMs`、`totalTokens`、`usage`、`prompt`）
  - `status: "async_launched"`（含 `agentId`、`description`、`prompt`、`outputFile`、`canReadOutputFile?`）
  - `status: "sub_agent_entered"`（含 `description`、`message`）
**当** 检查 Swift SDK 的 AgentTool 输出
**则** 支持三种状态的鉴别
**如果缺少** → 记录缺口

**给定** TypeScript SDK 的 subagent hook 事件：`SubagentStart`、`SubagentStop`
**当** 在 Swift SDK 中注册 subagent 相关 hook
**则** hook 接收到完整的 `SubagentStartHookInput` / `SubagentStopHookInput`

**给定** 示例 `Examples/CompatSubagents/` 目录
**当** 运行 `swift run CompatSubagents`
**则** 示例演示：
  - 编程式定义 subagent（AgentDefinition）
  - 限制 subagent 的工具集
  - subagent 使用独立模型
  - subagent 使用独立 MCP 服务器
  - 后台 subagent（async_launched）
  - SubagentStart/SubagentStop hook
  - subagent 结果聚合到父 Agent

> **参考：** TS SDK 文档 AgentDefinition、AgentMcpServerSpec、AgentInput、AgentOutput

### Story 16.11: Thinking & Model 配置兼容性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 ThinkingConfig 和模型配置与 TypeScript SDK 完全兼容，
以便开发者可以精确控制 LLM 的推理行为。

**验收标准：**

**给定** TypeScript SDK 的 `ThinkingConfig` 三种模式：
  - `{ type: "adaptive" }` — 模型自动决定推理深度（Opus 4.6+ 默认）
  - `{ type: "enabled", budgetTokens?: number }` — 固定推理 token 预算
  - `{ type: "disabled" }` — 禁用扩展推理
**当** 逐一测试 Swift SDK 的 ThinkingConfig
**则** 三种模式都正确传递到 API 请求
**且** `adaptive` 模式在支持的模型上自动启用
**且** `budgetTokens` 正确限制推理 token 数量

**给定** TypeScript SDK 的 `effort` 参数：`'low' | 'medium' | 'high' | 'max'`
**当** 在 Swift SDK 中设置 effort 级别
**则** effort 与 ThinkingConfig 正确联动
**如果不支持** → 记录缺口

**给定** TypeScript SDK 的 `ModelInfo` 类型：
```typescript
{ value, displayName, description, supportsEffort?, supportedEffortLevels?,
  supportsAdaptiveThinking?, supportsFastMode? }
```
**当** 检查 Swift SDK 的 ModelInfo
**则** 包含所有字段

**给定** TypeScript SDK 的 `ModelUsage` 类型：
```typescript
{ inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens,
  webSearchRequests, costUSD, contextWindow, maxOutputTokens }
```
**当** 检查 Swift SDK 的等价类型
**则** 包含所有字段，特别是 `cacheReadInputTokens`、`cacheCreationInputTokens`、`webSearchRequests`

**给定** TypeScript SDK 的 `fallbackModel` 选项
**当** 主模型请求失败
**则** SDK 自动切换到备用模型
**如果不支持** → 记录缺口

**给定** 示例 `Examples/CompatThinkingModel/` 目录
**当** 运行 `swift run CompatThinkingModel`
**则** 示例演示：
  - 三种 ThinkingConfig 模式
  - effort 级别与 thinking 的联动
  - 动态模型切换（运行时）
  - fallbackModel 行为
  - 模型使用量追踪（按模型分类）
  - 缓存 token 追踪

> **参考：** TS SDK 文档 ThinkingConfig、ModelInfo、ModelUsage、effort

### Story 16.12: Sandbox 配置兼容性验证

作为 SDK 开发者，
我希望验证 Swift SDK 的 Sandbox 配置完全覆盖 TypeScript SDK 的所有沙盒选项，
以便所有安全控制都能在 Swift 中使用。

**验收标准：**

**给定** TypeScript SDK 的 `SandboxSettings` 完整类型：
```typescript
{ enabled?, autoAllowBashIfSandboxed?, excludedCommands?, allowUnsandboxedCommands?,
  network?: SandboxNetworkConfig, filesystem?: SandboxFilesystemConfig,
  ignoreViolations?, enableWeakerNestedSandbox?, ripgrep? }
```
**当** 检查 Swift SDK 的 SandboxSettings
**则** 包含所有顶层字段

**给定** `SandboxNetworkConfig`：
```typescript
{ allowedDomains?, allowManagedDomainsOnly?, allowLocalBinding?,
  allowUnixSockets?, allowAllUnixSockets?, httpProxyPort?, socksProxyPort? }
```
**当** 检查 Swift SDK 的等价
**则** 包含所有字段
**注：** 网络沙盒是可选功能，Epic 14 范围内不含网络限制。如未实现，记录为 v2.0 候选。

**给定** `SandboxFilesystemConfig`：
```typescript
{ allowWrite?: string[], denyWrite?: string[], denyRead?: string[] }
```
**当** 检查 Swift SDK 的等价
**则** 包含所有字段

**给定** TypeScript SDK 的 unsandboxed fallback 模式：
```typescript
// dangerouslyDisableSandbox: true 在 BashInput 中 → 回退到 canUseTool 权限系统
```
**当** 检查 Swift SDK
**则** BashTool 支持 `dangerouslyDisableSandbox` 输入
**且** 启用时回退到 canUseTool 回调
**如果不支持** → 记录缺口

**给定** 示例 `Examples/CompatSandbox/` 目录
**当** 运行 `swift run CompatSandbox`
**则** 示例演示：
  - 完整 SandboxSettings 配置
  - 文件系统读写限制
  - 命令黑名单/白名单
  - `autoAllowBashIfSandboxed` 行为
  - `excludedCommands` vs `allowUnsandboxedCommands` 区别
  - `dangerouslyDisableSandbox` 回退到 canUseTool
  - 违规忽略规则

> **参考：** TS SDK 文档 SandboxSettings、SandboxNetworkConfig、SandboxFilesystemConfig

### 兼容性报告格式

每个 Story 的示例程序必须输出标准化的兼容性报告，格式如下：

```
=== TypeScript SDK 兼容性报告 ===
Story: 16.N - [Story 名称]
日期: YYYY-MM-DD

[核心配置]
✅ allowedTools: 与 TS SDK 兼容
✅ disallowedTools: 与 TS SDK 兼容
❌ outputFormat: 缺失 — 需要在 AgentOptions 中添加 outputFormat 字段
⚠️  effort: 部分支持 — 缺少 'max' 级别
⬚ executable: N/A (Swift 不适用)

总计: 28 PASS, 3 MISSING, 1 PARTIAL, 5 N/A
```

### 改造优先级

验证完成后，根据报告按以下优先级改造：
1. **P0 — 核心 API 缺失**：影响基本用法的功能（如消息类型缺失、Options 字段缺失）
2. **P1 — 高级功能缺失**：影响特定场景的功能（如 structured output、streaming input）
3. **P2 — 增强功能缺失**：提升体验但非必须的功能（如 promptSuggestions、plugins）
4. **N/A — 不适用**：TypeScript 特有的功能（如 executable、spawnClaudeCodeProcess）

---

## Epic 17: 官方 TypeScript SDK 功能对齐

基于 Epic 16 兼容性验证发现的 ~100+ 个 MISSING/PARTIAL 功能缺口，系统性补齐 Swift SDK 与官方 TypeScript SDK 的功能差异。每个 Story 聚焦一个功能域，实现缺失类型、补全字段、增加新方法，使 Swift SDK 达到与 TS SDK 的功能等价。

**目标来源：** Epic 16 兼容性报告（12 个 Story）、官方 TS SDK 文档 https://code.claude.com/docs/en/agent-sdk/typescript
**覆盖的 FR：** FR1-FR24（详见下方）
**依赖：** Epic 1-16（所有基础功能和兼容性验证必须已完成）

### 功能需求映射

| FR | Story | 描述 |
|---|---|---|
| FR1 | 17-1 | 添加 12 个缺失的 SDKMessage 类型/子类型 |
| FR2 | 17-1 | 补全现有消息类型的缺失字段 |
| FR3 | 17-3 | ToolAnnotations 类型（4 个 hint 字段） |
| FR4 | 17-3 | ToolResult 类型化内容数组 |
| FR5 | 17-3 | BashInput.run_in_background |
| FR6 | 17-4 | 3 个缺失 Hook 事件 |
| FR7 | 17-4 | HookInput 字段补全 |
| FR8 | 17-4 | HookOutput 字段补全 |
| FR9 | 17-2 | 14 个缺失 AgentOptions 字段 |
| FR10 | 17-5 | PermissionUpdate 6 种操作 |
| FR11 | 17-5 | CanUseTool 回调参数扩展 |
| FR12 | 17-5 | SDKPermissionDenial 类型 |
| FR13 | 17-6 | AgentDefinition 缺失字段 |
| FR14 | 17-6 | AgentInput 缺失字段 |
| FR15 | 17-6 | AgentOutput 三态判定 |
| FR16 | 17-7 | 4 个会话恢复选项 |
| FR17 | 17-8 | McpClaudeAIProxyServerConfig |
| FR18 | 17-8 | MCP 运行时管理操作 |
| FR19 | 17-9 | SandboxNetworkConfig（7 个字段） |
| FR20 | 17-9 | 5 个缺失 SandboxSettings 字段 |
| FR21 | 17-10 | 9 个缺失查询方法 |
| FR22 | 17-11 | effort 级别支持 |
| FR23 | 17-11 | ModelInfo 字段补全 |
| FR24 | 17-11 | fallbackModel 行为 |

### 非功能需求

- **NFR1：** 所有新增类型和字段必须维持 `Sendable` 一致性
- **NFR2：** 所有新增 public API 必须有 Swift-DocC 文档
- **NFR3：** 所有变更必须通过现有测试套件（3400+ tests）零回归
- **NFR4：** 新消息类型必须集成到现有 `AsyncStream<SDKMessage>` 管道
- **NFR5：** 所有新增 AgentOptions 字段必须为 optional 以保持向后兼容

### Story 17.1: SDKMessage 类型增强

作为 SDK 开发者，
我希望补齐 Swift SDK 的 `SDKMessage` 类型系统，使其覆盖 TypeScript SDK 的全部 20 种消息类型和完整字段，
以便消费消息流的代码能正确处理所有事件。

**验收标准：**

**给定** TypeScript SDK 有 20 种消息类型，其中 12 种在 Swift SDK 中完全缺失
**当** 在 SDKMessage enum 中添加缺失的 case
**则** 新增 `.userMessage(UserMessageData)`、`.toolProgress(ToolProgressData)`、`.hookStarted(HookStartedData)`、`.hookProgress(HookProgressData)`、`.hookResponse(HookResponseData)`、`.taskStarted(TaskStartedData)`、`.taskProgress(TaskProgressData)`、`.authStatus(AuthStatusData)`、`.filesPersisted(FilesPersistedData)`、`.localCommandOutput(LocalCommandOutputData)`、`.promptSuggestion(PromptSuggestionData)`、`.toolUseSummary(ToolUseSummaryData)`
**且** 每个新类型的关联值包含 TS SDK 文档定义的所有字段
**且** 所有新类型遵循 `Sendable` 协议

**给定** 现有 AssistantData 缺少 `uuid`、`sessionId`、`parentToolUseId`、`error` 字段
**当** 在 AssistantData 中添加这些字段
**则** 字段类型与 TS SDK 一致（`error` 支持 7 种错误子类型：authenticationFailed、billingError、rateLimit、invalidRequest、serverError、maxOutputTokens、unknown）
**且** 字段均为 optional 以保持向后兼容

**给定** 现有 ResultData 缺少 `structuredOutput`、`permissionDenials`、`modelUsage` 字段和 `errorMaxStructuredOutputRetries` 子类型
**当** 在 ResultData 中添加这些字段和子类型
**则** `structuredOutput` 类型为 `Any?`（JSON 兼容）
**且** `permissionDenials` 类型为 `[SDKPermissionDenial]`
**且** `modelUsage` 与 `costBreakdown` 共存（命名不同但都可用）

**给定** 现有 SystemData.init 缺少 `sessionId`、`tools`、`model`、`permissionMode`、`mcpServers`、`cwd` 字段
**当** 在 SystemData 中添加 init 专属字段
**则** 使用独立的 `SystemInitData` 结构或通过 optional 字段扩展 SystemData
**且** 流式查询时这些字段被正确填充

**给定** 现有 PartialData 缺少 `parentToolUseId`、`uuid`、`sessionId` 字段
**当** 在 PartialData 中添加这些字段
**则** 所有字段为 optional，不影响现有用法

> **参考：** Story 16-3 兼容性报告、TS SDK Message Types 文档

### Story 17.2: AgentOptions 完整参数

作为 SDK 开发者，
我希望补齐 Swift SDK 的 `AgentOptions` 中缺失的 TS SDK Options 字段，
以便开发者迁移时不需要妥协功能。

**验收标准：**

**给定** TS SDK 有 12 个核心配置字段，Swift 缺少 `fallbackModel`、`env`、`allowedTools`、`disallowedTools`
**当** 在 AgentOptions 中添加这些字段
**则** `fallbackModel: String?` — 主模型失败时自动切换
**且** `env: [String: String]?` — 注入环境变量
**且** `allowedTools: [String]?` — 工具白名单
**且** `disallowedTools: [String]?` — 工具黑名单（优先级高于 allowedTools 和 permissionMode）

**给定** TS SDK 有 9 个高级配置字段，Swift 缺少 `effort`、`toolConfig`、`outputFormat`、`includePartialMessages`、`promptSuggestions`
**当** 在 AgentOptions 中添加这些字段
**则** `effort: EffortLevel?` — 支持 low/medium/high/max
**且** `outputFormat: OutputFormat?` — 支持 `{ type: "json_schema", schema: [String: Any] }`
**且** `includePartialMessages: Bool` — 控制是否发送 partial message 事件（默认 true）
**且** `promptSuggestions: Bool` — 控制是否生成提示建议

**给定** TS SDK 有 6 个会话配置字段，Swift 缺少 `continue`、`forkSession`、`resumeSessionAt`、`persistSession`
**当** 在 AgentOptions 中添加这些字段
**则** `continueRecentSession: Bool` — 继续最近的会话
**且** `forkSession: Bool` — 分叉而非继续
**且** `resumeSessionAt: String?` — 从指定消息 UUID 恢复
**且** `persistSession: Bool` — 是否持久化会话（默认 true）

**给定** TS SDK 的 `systemPrompt` 支持 preset 模式
**当** 检查 Swift 的 systemPrompt 类型
**则** 支持 `String` 和 `SystemPromptConfig.preset(name:append:)` 两种模式

> **参考：** Story 16-8 兼容性报告、TS SDK Options 文档

### Story 17.3: 工具系统增强

作为 SDK 开发者，
我希望补齐 Swift SDK 工具系统中缺失的 ToolAnnotations、类型化 ToolResult 和 BashInput.run_in_background，
以便 Swift SDK 的工具系统达到 TS SDK 功能等价。

**验收标准：**

**给定** TS SDK 的 `ToolAnnotations` 包含 4 个 hint 字段
**当** 在 Swift SDK 中添加 `ToolAnnotations` 结构
**则** 包含 `readOnlyHint: Bool`、`destructiveHint: Bool`、`idempotentHint: Bool`、`openWorldHint: Bool`
**且** `ToolProtocol` 添加可选的 `annotations: ToolAnnotations?` 属性
**且** `defineTool()` 支持 annotations 参数

**给定** TS SDK 的 `CallToolResult.content` 是类型化数组
**当** 扩展 Swift SDK 的 `ToolResult.content`
**则** 支持 `ToolContent` 类型数组（`.text(String)`、`.image(data:mimeType:)`、`.resource(uri:name:)`）
**且** 现有 `content: String` 保持向后兼容（通过便捷属性）
**且** `ToolExecuteResult` 同步支持类型化内容

**给定** TS SDK 的 BashInput 有 `run_in_background` 字段
**当** 在 Swift 的 BashInput 中添加此字段
**则** `runInBackground: Bool?` — 命令在后台执行
**且** 后台执行返回 backgroundTaskId 用于后续管理

> **参考：** Story 16-2 兼容性报告、TS SDK tool()、ToolAnnotations 文档

### Story 17.4: Hook 系统增强

作为 SDK 开发者，
我希望补齐 Swift SDK Hook 系统中缺失的 3 个事件和 HookInput/Output 字段，
以便所有 Hook 用法都能从 TS 迁移到 Swift。

**验收标准：**

**给定** TS SDK 有 18 个 HookEvent，Swift 缺少 `setup`、`worktreeCreate`、`worktreeRemove`
**当** 在 HookEvent enum 中添加这 3 个 case
**则** HookEvent.CaseIterable 自动更新
**且** 每个新事件都有对应的 HookInput 字段

**给定** HookInput 缺少 `transcriptPath`、`permissionMode`、`agentId`、`agentType` 等字段
**当** 扩展 HookInput 结构
**则** 添加 `transcriptPath: String?`、`permissionMode: String?`、`agentId: String?`、`agentType: String?`
**且** Per-event 专用字段：`stopHookActive`、`lastAssistantMessage`、`trigger`、`customInstructions`、`permissionSuggestions`、`isInterrupt`

**给定** HookOutput 缺少 `systemMessage`、`reason`、`updatedInput`、`additionalContext` 等字段
**当** 扩展 HookOutput 结构
**则** PreToolUse output 支持 `permissionDecision`、`updatedInput`、`additionalContext`
**且** PostToolUse output 支持 `updatedMCPToolOutput`、`additionalContext`
**且** PermissionRequest output 支持 `decision` (allow/deny)

> **参考：** Story 16-4 兼容性报告、TS SDK Hook Types 文档

### Story 17.5: 权限系统增强

作为 SDK 开发者，
我希望补齐 Swift SDK 权限系统中缺失的 PermissionUpdate 操作、CanUseTool 扩展参数和 PermissionDenial 类型，
以便所有权限控制模式都能在 Swift 中使用。

**验收标准：**

**给定** TS SDK 有 6 种 PermissionUpdate 操作
**当** 在 Swift SDK 中添加 `PermissionUpdate` 类型
**则** 支持 `addRules`、`replaceRules`、`removeRules`（含 `rules`、`behavior: allow/deny/ask`）
**且** 支持 `setMode`（含 `mode: PermissionMode`）
**且** 支持 `addDirectories`、`removeDirectories`
**且** 每种操作支持 `destination`（userSettings/projectSettings/localSettings/session/cliArg）

**给定** CanUseToolFn 回调缺少 `signal`、`suggestions`、`blockedPath`、`decisionReason`、`toolUseID`、`agentID` 参数
**当** 扩展 CanUseToolFn 的上下文参数
**则** `ToolPermissionContext` 包含所有 TS SDK 等价字段
**且** 返回结果支持 `updatedPermissions` 和 `toolUseID`

**给定** TS SDK 有 `SDKPermissionDenial` 类型
**当** 在 Swift SDK 中添加此类型
**则** 包含 `toolName: String`、`toolUseId: String`、`toolInput: [String: Any]`
**且** 在 ResultData.permissionDenials 中正确填充

> **参考：** Story 16-9 兼容性报告、TS SDK PermissionMode、PermissionUpdate 文档

### Story 17.6: 子代理系统增强

作为 SDK 开发者，
我希望补齐 Swift SDK 子代理系统中缺失的 AgentDefinition 字段、AgentInput 字段和 AgentOutput 三态判定，
以便所有多 Agent 编排模式都能在 Swift 中使用。

**验收标准：**

**给定** AgentDefinition 缺少 `mcpServers`、`skills`、`criticalSystemReminder_EXPERIMENTAL` 字段
**当** 在 AgentDefinition 中添加这些字段
**则** `mcpServers: [AgentMcpServerSpec]?` — 支持 string 引用和 inline 配置两种模式
**且** `skills: [String]?` — 预加载技能名称列表
**且** `criticalSystemReminderExperimental: String?` — 实验性系统提醒

**给定** AgentInput 缺少 `run_in_background`、`isolation`、`name`、`team_name`、`mode` 字段
**当** 在 AgentTool 输入中添加这些字段
**则** `runInBackground: Bool?` — 后台执行 subagent
**且** `isolation: String?` — 支持 "worktree" 隔离模式
**且** `name: String?` — subagent 名称
**且** `teamName: String?` — 团队名称
**且** `mode: PermissionMode?` — subagent 权限模式

**给定** TS SDK 的 AgentOutput 有三种状态
**当** 在 Swift SDK 中实现 AgentOutput 三态判定
**则** `.completed` — 含 agentId、content、totalToolUseCount、totalDurationMs、totalTokens、usage、prompt
**且** `.asyncLaunched` — 含 agentId、description、prompt、outputFile、canReadOutputFile
**且** `.subAgentEntered` — 含 description、message

> **参考：** Story 16-10 兼容性报告、TS SDK AgentDefinition、AgentOutput 文档

### Story 17.7: 会话管理增强

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 4 个会话恢复选项，
以便开发者可以灵活控制会话生命周期。

**验收标准：**

**给定** TS SDK 支持 `continue: true` 继续最近会话
**当** 在 AgentOptions 中添加 `continueRecentSession: Bool`
**则** 设为 true 时，Agent 自动加载最近的会话历史
**且** 如果没有可恢复的会话，按新会话处理（不报错）

**给定** TS SDK 支持 `forkSession: true` 分叉会话
**当** 在 AgentOptions 中添加 `forkSession: Bool`
**则** 设为 true 时，创建会话副本而非直接修改原会话
**且** 原会话保持不变

**给定** TS SDK 支持 `resumeSessionAt: messageUUID` 从指定消息恢复
**当** 在 AgentOptions 中添加 `resumeSessionAt: String?`
**则** 加载会话历史截至指定 UUID 的消息
**且** 如果 UUID 不存在，从最近的消息恢复

**给定** TS SDK 支持 `persistSession: false` 禁用持久化
**当** 在 AgentOptions 中添加 `persistSession: Bool`
**则** 默认为 true（与现有行为一致）
**且** 设为 false 时，会话仅在内存中，不写入磁盘

> **参考：** Story 16-6 兼容性报告、TS SDK Session Management 文档

### Story 17.8: MCP 集成增强

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 ClaudeAI Proxy 配置和 MCP 运行时管理操作，
以便所有 MCP 用法都能在 Swift 中使用。

**验收标准：**

**给定** TS SDK 有 `McpClaudeAIProxyServerConfig`（type: "claudeai-proxy"）
**当** 在 Swift SDK 中添加此配置类型
**则** 包含 `url: String`、`id: String` 字段
**且** 可通过 `McpServerConfig.claudeAIProxy(url:id:)` 创建

**给定** TS SDK 有 4 个 MCP 运行时管理操作
**当** 在 Swift SDK 中添加这些方法
**则** `agent.mcpServerStatus() -> [String: McpServerStatus]` — 返回所有服务器状态
**且** `agent.reconnectMcpServer(name: String) async throws` — 重连指定服务器
**且** `agent.toggleMcpServer(name: String, enabled: Bool) async throws` — 启用/禁用
**且** `agent.setMcpServers(_ servers: [String: McpServerConfig]) async throws -> McpServerUpdateResult` — 动态替换服务器集

**给定** McpServerStatus 包含连接状态和工具列表
**当** 实现 McpServerStatus 类型
**则** 状态值：connected、failed、needsAuth、pending、disabled
**且** 包含 serverInfo、error、tools（含 annotations）

> **参考：** Story 16-5 兼容性报告、TS SDK McpServerConfig 文档

### Story 17.9: 沙盒配置增强

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 SandboxNetworkConfig 和 5 个 SandboxSettings 字段，
以便所有安全控制都能在 Swift 中使用。

**验收标准：**

**给定** TS SDK 有 `SandboxNetworkConfig`（7 个字段）
**当** 在 Swift SDK 中添加此类型
**则** 包含 `allowedDomains: [String]`、`allowManagedDomainsOnly: Bool`、`allowLocalBinding: Bool`、`allowUnixSockets: Bool`、`allowAllUnixSockets: Bool`、`httpProxyPort: Int?`、`socksProxyPort: Int?`
**且** SandboxSettings 添加 `network: SandboxNetworkConfig?` 字段

**给定** SandboxSettings 缺少 `autoAllowBashIfSandboxed`、`allowUnsandboxedCommands`、`ignoreViolations`、`enableWeakerNestedSandbox`、`ripgrep` 字段
**当** 在 SandboxSettings 中添加这些字段
**则** `autoAllowBashIfSandboxed: Bool` — 沙盒启用时自动批准 Bash
**且** `allowUnsandboxedCommands: Bool` — 允许模型请求非沙盒执行
**且** `ignoreViolations: [String: [String]]?` — 按类别忽略违规规则
**且** `enableWeakerNestedSandbox: Bool` — 嵌套沙盒降级
**且** `ripgrep: RipgrepConfig?` — 自定义 ripgrep 配置

**给定** `autoAllowBashIfSandboxed = true` 时 BashTool 自动执行
**当** 设置 sandbox.enabled + autoAllowBashIfSandboxed
**则** Bash 工具跳过 canUseTool 检查直接执行
**且** 命令仍在沙盒环境中运行

> **参考：** Story 16-12 兼容性报告、TS SDK SandboxSettings 文档

### Story 17.10: 查询方法增强

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 9 个查询控制方法，
以便开发者可以在查询过程中动态控制 Agent 行为。

**验收标准：**

**给定** TS SDK 有 `rewindFiles(msgId, { dryRun? })` 方法
**当** 在 Swift SDK 中添加 `agent.rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> RewindResult`
**则** 将文件系统恢复到指定消息时的状态
**且** dryRun 模式只返回预览不实际修改

**给定** TS SDK 有 `streamInput(stream)` 流式输入方法
**当** 在 Swift SDK 中添加 `agent.streamInput(_ input: AsyncStream<String>) -> AsyncStream<SDKMessage>`
**则** 支持多轮流式对话输入
**且** 输入流结束时自动触发最终响应

**给定** TS SDK 有 `stopTask(taskId)` 方法
**当** 在 Swift SDK 中添加 `agent.stopTask(taskId: String) async throws`
**则** 按 ID 停止后台任务
**且** 返回任务的部分输出

**给定** TS SDK 有 `close()` 方法
**当** 在 Swift SDK 中添加 `agent.close() async throws`
**则** 强制终止查询并清理资源
**且** 后续查询调用会抛出错误

**给定** TS SDK 有 `initializationResult()`、`supportedCommands()`、`supportedModels()`、`supportedAgents()`、`setMaxThinkingTokens()` 方法
**当** 在 Swift SDK 中添加对应方法
**则** `initializationResult()` 返回 `SDKControlInitializeResponse`
**且** `supportedModels()` 返回 `[ModelInfo]`
**且** `supportedAgents()` 返回 `[AgentInfo]`
**且** `setMaxThinkingTokens(_ n: Int?)` 动态调整思考 token 预算

> **参考：** Story 16-7 兼容性报告、TS SDK Query object 文档

### Story 17.11: Thinking 和模型配置增强

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 effort 级别、ModelInfo 字段和 fallbackModel 行为，
以便开发者可以精确控制 LLM 的推理行为。

**验收标准：**

**给定** TS SDK 支持 effort 参数（low/medium/high/max）
**当** 在 Swift SDK 中添加 `EffortLevel` 枚举
**则** 支持 `.low`、`.medium`、`.high`、`.max` 四个值
**且** effort 与 ThinkingConfig 正确联动（effort 自动映射到 thinking budget）
**且** AgentOptions.effort 字段正确传递到 API 请求

**给定** ModelInfo 缺少 `displayName`、`description`、`supportsEffort`、`supportedEffortLevels`、`supportsAdaptiveThinking`、`supportsFastMode` 字段
**当** 在 ModelInfo 中添加这些字段
**则** 所有字段为 optional 以保持兼容
**且** `supportsEffort: Bool?` 标识模型是否支持 effort 控制
**且** `supportedEffortLevels: [EffortLevel]?` 列出可用级别

**给定** TS SDK 支持 fallbackModel 行为
**当** 实现主模型失败自动切换
**则** `AgentOptions.fallbackModel` 指定备用模型名
**且** 主模型返回错误时自动重试备用模型
**且** 重试使用相同的消息上下文
**且** 切换事件通过 `AsyncStream<SDKMessage>` 通知

> **参考：** Story 16-11 兼容性报告、TS SDK ThinkingConfig、ModelInfo 文档

---

## Epic 18: 示例与官方 SDK 完全对齐

在 Epic 17 完成功能缺口填补后，回到 Epic 16 创建的 12 个 Compat* 兼容性验证示例，更新每个示例使其反映填补后的最新状态。核心工作是将兼容性报告中的 `[MISSING]` 条目更新为 `[PASS]`，删除已不再适用的缺口记录，并确保每个示例的兼容性报告准确反映当前 Swift SDK 与 TS SDK 的对齐程度。

**目标来源：** Epic 16（12 个 Compat* 示例）+ Epic 17（功能填补）
**依赖：** Epic 17 全部完成后执行
**核心原则：** 每个 Story 对应一个 Epic 16 示例的更新，粒度 1:1

### Story 18.1: 更新 CompatCoreQuery 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatCoreQuery/` 使其反映 Epic 17 填补后的兼容性状态，
以便兼容性报告准确展示 Swift SDK 与 TS SDK 的对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-1（消息类型增强）和 17-2（AgentOptions 完整参数）已完成
**当** 重新运行 `CompatCoreQuery` 示例
**则** SystemData.init 的 session_id/tools/model/permissionMode/mcpServers/cwd 字段标记为 `[PASS]`
**且** ResultData 的 structuredOutput/permissionDenials/modelUsage/errors 字段标记为 `[PASS]`
**且** durationApiMs 如未实现仍标记为 `[MISSING]`
**且** 兼容性报告的 pass rate 提升

> **依赖：** 17-1, 17-2

### Story 18.2: 更新 CompatToolSystem 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatToolSystem/` 使其反映 Epic 17 填补后的兼容性状态，
以便工具系统兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-3（工具系统增强）已完成
**当** 重新运行 `CompatToolSystem` 示例
**则** ToolAnnotations 的 4 个 hint 字段标记为 `[PASS]`
**且** ToolResult 类型化内容数组标记为 `[PASS]`
**且** BashInput.run_in_background 标记为 `[PASS]`
**且** 兼容性报告的 pass rate 提升

> **依赖：** 17-3

### Story 18.3: 更新 CompatMessageTypes 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatMessageTypes/` 使其反映 Epic 17 填补后的兼容性状态，
以便消息类型兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-1（SDKMessage 类型增强）已完成
**当** 重新运行 `CompatMessageTypes` 示例
**则** 12 个缺失消息类型现在标记为 `[PASS]`（userMessage, toolProgress, hookStarted/Progress/Response, taskStarted/Progress, authStatus, filesPersisted, localCommandOutput, promptSuggestion, toolUseSummary）
**且** AssistantData 的 uuid/sessionId/parentToolUseId/error 标记为 `[PASS]`
**且** ResultData 的 structuredOutput/permissionDenials 标记为 `[PASS]`
**且** PartialData 的 parentToolUseId/uuid/sessionId 标记为 `[PASS]`
**且** 兼容性报告从 8 PARTIAL + 12 MISSING 改善为更高 pass rate

> **依赖：** 17-1

### Story 18.4: 更新 CompatHooks 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatHooks/` 使其反映 Epic 17 填补后的兼容性状态，
以便 Hook 系统兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-4（Hook 系统增强）已完成
**当** 重新运行 `CompatHooks` 示例
**则** setup/worktreeCreate/worktreeRemove 事件标记为 `[PASS]`
**且** HookInput 缺失字段（transcriptPath, permissionMode, agentId, agentType 等）标记为 `[PASS]`
**且** HookOutput 缺失字段（systemMessage, reason, updatedInput, additionalContext 等）标记为 `[PASS]`

> **依赖：** 17-4

### Story 18.5: 更新 CompatMCP 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatMCP/` 使其反映 Epic 17 填补后的兼容性状态，
以便 MCP 集成兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-8（MCP 集成增强）已完成
**当** 重新运行 `CompatMCP` 示例
**则** McpClaudeAIProxyServerConfig 标记为 `[PASS]`
**且** mcpServerStatus/reconnectMcpServer/toggleMcpServer/setMcpServers 标记为 `[PASS]`
**且** McpServerStatus 类型标记为 `[PASS]`

> **依赖：** 17-8

### Story 18.6: 更新 CompatSessions 示例

作为 SDK 开发者，
**且** MCP 运行时管理操作（reconnectMcpServer, toggleMcpServer, setMcpServers）标记为 `[PASS]` 

> **依赖：** 17-8

### Story 18.6: 更新 CompatSessions 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatSessions/` 使其反映 Epic 17 填补后的兼容性状态，
以便会话管理兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-7（会话管理增强）已完成
**当** 重新运行 `CompatSessions` 示例
**则** continueRecentSession/forkSession/resumeSessionAt/persistSession 标记为 `[PASS]`
**且** 会话恢复功能实际可用（示例中演示恢复/分叉/禁用持久化）

> **依赖：** 17-7

### Story 18.7: 更新 CompatQueryMethods 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatQueryMethods/` 使其反映 Epic 17 填补后的兼容性状态，
以便查询方法兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-10（查询方法增强）已完成
**当** 重新运行 `CompatQueryMethods` 示例
**则** rewindFiles/streamInput/stopTask/close/initializationResult/supportedModels/supportedAgents/setMaxThinkingTokens 标记为 `[PASS]`
**且** 兼容性报告的 pass rate 显著提升

> **依赖：** 17-10

### Story 18.8: 更新 CompatOptions 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatOptions/` 使其反映 Epic 17 填补后的兼容性状态，
以便 Agent Options 兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-2（AgentOptions 完整参数）已完成
**当** 重新运行 `CompatOptions` 示例
**则** fallbackModel/env/effort/outputFormat/includePartialMessages/promptSuggestions 标记为 `[PASS]`
**且** continueRecentSession/forkSession/resumeSessionAt/persistSession 标记为 `[PASS]`
**且** allowedTools/disallowedTools 标记为 `[PASS]`

> **依赖：** 17-2

### Story 18.9: 更新 CompatPermissions 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatPermissions/` 使其反映 Epic 17 填补后的兼容性状态，
以便权限系统兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-5（权限系统增强）已完成
**当** 重新运行 `CompatPermissions` 示例
**则** PermissionUpdate 6 种操作标记为 `[PASS]`
**且** CanUseTool 扩展参数（signal, suggestions, blockedPath 等）标记为 `[PASS]`
**且** SDKPermissionDenial 类型标记为 `[PASS]`
**且** PermissionUpdateDestination 5 种目标标记为 `[PASS]`

> **依赖：** 17-5

### Story 18.10: 更新 CompatSubagents 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatSubagents/` 使其反映 Epic 17 填补后的兼容性状态，
以便子代理系统兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-6（子代理系统增强）已完成
**当** 重新运行 `CompatSubagents` 示例
**则** AgentDefinition 的 mcpServers/skills/criticalSystemReminderExperimental 标记为 `[PASS]`
**且** AgentInput 的 runInBackground/isolation/name/teamName/mode 标记为 `[PASS]`
**且** AgentOutput 三态判定标记为 `[PASS]`

> **依赖：** 17-6

### Story 18.11: 更新 CompatThinkingModel 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatThinkingModel/` 使其反映 Epic 17 填补后的兼容性状态，
以便 Thinking/Model 配置兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-11（Thinking 和模型配置增强）已完成
**当** 重新运行 `CompatThinkingModel` 示例
**则** EffortLevel 4 个级别标记为 `[PASS]`
**且** ModelInfo 补全字段（displayName, description, supportsEffort 等）标记为 `[PASS]`
**且** fallbackModel 行为标记为 `[PASS]`

> **依赖：** 17-11

### Story 18.12: 更新 CompatSandbox 示例

作为 SDK 开发者，
我希望更新 `Examples/CompatSandbox/` 使其反映 Epic 17 填补后的兼容性状态，
以便沙盒配置兼容性报告准确展示对齐程度。

**验收标准：**

**给定** Epic 17 的 Story 17-9（沙盒配置增强）已完成
**当** 重新运行 `CompatSandbox` 示例
**则** SandboxNetworkConfig 7 个字段标记为 `[PASS]`
**且** autoAllowBashIfSandboxed/allowUnsandboxedCommands/ignoreViolations/enableWeakerNestedSandbox/ripgrep 标记为 `[PASS]`
**且** autoAllowBashIfSandboxed 行为验证通过

> **依赖：** 17-9

---

## Epic 19: Axion Phase 2 驱动的 SDK 新能力

Axion（macOS 桌面自动化 Agent）在 Phase 2 开发中识别出 3 个所有 Agent 应用都需要的通用能力。这些能力从 Axion 的业务需求中提炼，下沉到 SDK 成为公共 API，Axion 作为第一个消费者验证。

**覆盖的 FR（新增）：** FR68、FR69、FR70
**依赖：** Epic 1（Agent 基础）、Epic 6（MCP 协议集成）、Epic 7（会话持久化）
**来源：** Axion Phase 2 需求分析

### Story 19.1: Cross-run Memory Store

作为 SDK 开发者，
我希望 SDK 提供跨运行的知识积累存储，
以便所有 Agent 应用可以在多次执行之间保留和复用结构化经验。

**背景：** SDK 已有 SessionStore（持久化对话历史）和 SessionMemory（会话内对话压缩），但没有跨运行的结构化知识积累。Axion 需要记住"Calculator 的按钮布局""Finder 导航到 /tmp 的最可靠路径"，这种经验对所有反复运行的 Agent 都有价值 — 代码 Agent 记住项目结构，测试 Agent 记住脆弱测试。

**验收标准：**

**给定** MemoryStore 协议定义
**当** 检查公共 API
**则** 包含 `save(domain:knowledge:)`、`query(domain:filter:)`、`delete(domain:olderThan:)`、`listDomains()` 方法

**给定** `InMemoryStore`（默认实现）
**当** 调用 `save(domain: "calculator", knowledge: entry)`
**则** 知识条目按 domain 分类存储，包含 content、tags、createdAt、sourceRunId 字段

**给定** `FileBasedMemoryStore`（持久化实现）
**当** 存储知识到磁盘
**则** 按 domain 组织文件（如 `~/.agent/memory/calculator.json`），启动时自动加载

**给定** 知识条目超过 `maxAge`（默认 30 天）
**当** 下次查询时
**则** 自动清理过期条目

**给定** AgentOptions 配置 `memoryStore`
**当** Agent 执行 prompt/stream
**则** MemoryStore 可通过 ToolContext.memoryStore 访问，供自定义工具读写

**给定** 知识条目损坏
**当** 加载 FileBasedMemoryStore
**则** 跳过损坏条目，记录 warning 日志，不阻塞 Agent 执行

**新增 FR68:** 开发者可以通过 MemoryStore 协议实现跨运行的结构化知识积累，SDK 提供 InMemoryStore（默认）和 FileBasedMemoryStore（持久化）两种实现

### Story 19.2: Agent-as-MCP-Server

作为 SDK 开发者，
我希望 SDK 提供将 Agent 暴露为 MCP stdio server 的能力，
以便外部工具和 Agent 可以通过标准 MCP 协议调用 SDK Agent。

**背景：** SDK 已有 MCPClientManager（连接 MCP server）和 InProcessMCPServer（进程内 server），但没有将 Agent 本身暴露为 MCP stdio server 的能力。Axion 需要运行 `axion mcp` 让 Claude Code 等外部 Agent 通过 MCP 协议调用桌面操作。这不是 Axion 特有需求 — 任何 SDK 构建的 Agent 都可能需要被其他 Agent 调用。

**验收标准：**

**给定** `AgentMCPServer` 类
**当** 调用 `AgentMCPServer.run(agent:agent)`
**则** 通过 stdin/stdout 暴露 MCP JSON-RPC 协议

**给定** AgentMCPServer 收到 MCP initialize 请求
**当** 握手完成
**则** 声明 Agent 的工具列表和 server 能力

**给定** 外部调用者发送 tools/list
**当** AgentMCPServer 响应
**则** 返回 Agent 可用的工具列表（含 Agent 自定义工具 + MCP 工具）

**给定** 外部调用者发送 tool_call
**当** 指定工具名和参数
**则** AgentMCPServer 将其包装为 Agent 的工具调用，执行后返回结果

**给定** 外部调用者发送自定义方法 `agent/prompt`
**当** 包含 task 文本
**则** 启动完整的 Agent stream 执行，通过 SSE 或分块 tool_result 返回进度

**给定** AgentMCPServer 运行中，stdin 收到 EOF
**当** 管道关闭
**则** 等待运行中的任务完成（最多 30 秒），然后优雅退出

**给定** 外部调用者 Claude Code 的 MCP 配置
**当** 配置 `{"mcpServers": {"my-agent": {"command": "my-app", "args": ["mcp"]}}}`
**则** Claude Code 可发现和调用 Agent 的工具

**新增 FR69:** 开发者可以通过 AgentMCPServer 将 Agent 暴露为 MCP stdio server，外部调用者可通过标准 MCP 协议发现工具、调用工具、提交任务

### Story 19.3: Human-in-the-loop Pause Protocol

作为 SDK 开发者，
我希望 SDK 提供结构化的 Agent 暂停/恢复协议，
以便 Agent 在无法自主完成时可以暂停等待人类介入，人类完成后恢复执行。

**背景：** SDK 已有 `interrupt()`（停止 Agent）和 `canUseTool` callback（工具审批），但没有"暂停 → 等人 → 恢复"的结构化协议。Axion 的 Takeover（自动化受阻时暂停，用户手动完成后恢复）是通用模式 — 每个 Agent 都会遇到"我搞不定了，人来接手"的时刻。Claude Code 的 plan approval 也有同样的暂停模式。

**验收标准：**

**给定** `Agent.pause(reason:)` 方法
**当** Agent 在执行中调用 pause
**则** Agent 进入 `paused` 状态，停止工具执行，通过 SDKMessage.system(.paused(PausedData)) 通知消费者

**给定** Agent 处于 paused 状态
**当** 消费者调用 `Agent.resume(context:)`
**则** Agent 恢复执行，resume 中的 context 字符串注入到下一轮对话作为"人类已完成以下操作"的上下文

**给定** Agent 处于 paused 状态
**当** 消费者调用 `Agent.abort()`
**则** Agent 进入 `cancelled` 状态，返回已执行步骤的摘要

**给定** Agent paused 超过 `pauseTimeoutMs`（默认 300000ms = 5 分钟）
**当** 超时
**则** Agent 自动进入 `cancelled` 状态，SDKMessage.system(.pausedTimeout) 通知消费者

**给定** SDKMessage 新增 `.paused` 和 `.pausedTimeout` case
**当** 消费者消费 AsyncStream<SDKMessage>
**则** PausedData 包含 reason（暂停原因）、pausedAt（时间戳）、canResume（是否可恢复）

**给定** 内置工具 `pause_for_human`
**当** LLM 在执行中调用此工具，参数 `{ reason: "找不到目标窗口" }`
**则** 等效于调用 Agent.pause(reason:)，触发暂停协议

**新增 FR70:** 开发者可以通过 Agent.pause/resume/abort 实现 Agent 的人机协作暂停，LLM 可通过内置 pause_for_human 工具主动请求人类介入

---

## Epic 20: Agent HTTP API Server、Cost/Trace 服务与增强 Memory

Axion（macOS 桌面自动化 Agent）作为 SDK 旗舰应用，经过 20 个 Epic 的迭代，AxionCLI 已膨胀至 11,499 行。深度分析发现约 50%（~7,000 行）是通用 Agent 基础设施，任何基于 SDK 的 Agent 项目都会需要。这些能力应下沉到 SDK，使 SDK 从"Agent 引擎"进化为"Agent 全栈框架"。

**覆盖的 FR（新增）：** FR71、FR72、FR73、FR74
**依赖：** Epic 1（Agent 基础）、Epic 6（MCP 协议）、Epic 7（会话持久化）、Epic 19（Memory Store、AgentMCPServer、Pause Protocol）
**来源：** Axion Phase 6 深度分析 — `/Users/nick/CascadeProjects/axion/_bmad-output/implementation-artifacts/spec-axion-deep-analysis-sdk-extraction.md`

### Story 20.1: AgentHTTPServer — Agent 的 HTTP API Server

作为 SDK 开发者，
我希望 SDK 提供开箱即用的 HTTP API Server，
以便任何 Agent 可以通过 REST + SSE 对外暴露服务，无需每个项目自己实现。

**背景：** SDK 已有 `AgentMCPServer`（通过 MCP 协议暴露 Agent），但没有 HTTP API 模式。Axion 实现了完整的 HTTP Server（Hummingbird）：POST /runs 提交任务、GET /runs/{id}/events SSE 实时推送、GET /runs 列表、GET /health 健康检查、GET /v1/capabilities 能力发现。这套 API 模式对所有需要 GUI/外部集成的 Agent 项目通用 — 不仅是桌面 Agent，也包括代码 Agent、数据分析 Agent 等。

**Axion 参考实现：** `/Users/nick/CascadeProjects/axion/Sources/AxionCLI/API/` — `AxionAPI.swift`（路由定义）、`EventBroadcaster.swift`（SSE 扇出）、`RunPersistenceService.swift`（JSONL 持久化）、`RunRecoveryService.swift`（崩溃恢复）、`AuthMiddleware.swift`（认证中间件）、`APITypes.swift`（数据模型）

**验收标准：**

**给定** `AgentHTTPServer` 类
**当** 使用 `AgentHTTPServer(agent:agent, host:"127.0.0.1", port:4242)` 创建
**则** 提供 REST + SSE 端点：POST /v1/runs、GET /v1/runs、GET /v1/runs/{id}、GET /v1/runs/{id}/events (SSE)、GET /v1/health

**给定** POST /v1/runs 请求 `{"task": "分析数据"}`
**当** Server 收到请求
**则** 后台启动 Agent 执行，立即返回 202 + `{"run_id": "...", "status": "running"}`

**给定** GET /v1/runs/{id}/events SSE 连接
**当** Agent 执行中
**则** 实时推送 stepStarted、stepCompleted、runCompleted 等 SSE 事件，支持 late-joiner replay

**给定** `RunTracker`（Actor 隔离的 Run 生命周期状态机）
**当** 跟踪 run 状态转换
**则** 状态机支持：queued → running → completed/failed/cancelled/intervention_needed

**给定** `EventBroadcaster`（Actor 隔离的 SSE 扇出）
**当** 多个 SSE 客户端订阅同一 run
**则** 所有客户端同时收到事件，replay buffer 支持后到者补看历史

**给定** `RunPersistenceService`（JSONL 文件持久化）
**当** Run 状态变更
**则** 原子写入 api-output.json + 追加 api-events.jsonl，崩溃后可恢复

**给定** `ConcurrencyLimiter`（异步信号量）
**当** 并发 Run 数达到上限
**则** 新请求排队等待，释放后自动执行

**给定** `AuthMiddleware`（Bearer Token 认证）
**当** Server 配置 authKey
**则** 所有 /v1/* 端点需要 Authorization: Bearer <key>，未认证返回 401

**给定** `RunRecoveryService`
**当** Server 重启
**则** 扫描 api-runs/ 目录，将 interrupted runs 标记为 failed，保持 intervention_needed 不变

**新增 FR71:** 开发者可以通过 AgentHTTPServer 将 Agent 暴露为 HTTP API Server，提供 REST + SSE 端点，支持 Run 追踪、并发限制、认证和崩溃恢复

### Story 20.2: CostTracker 与 TraceRecorder — Agent 运行时可观测性

作为 SDK 开发者，
我希望 SDK 提供内置的 Cost 追踪和 Trace 记录服务，
以便所有 Agent 项目可以零配置获得运行时成本控制和执行可观测性。

**背景：** SDK 已有 `TokenUsage`（token 计数）和 `MODEL_PRICING`（模型定价），但没有 Run 级别的成本累计和预算控制。SDK 已有 `onRunComplete` 回调，但没有执行过程中的 Trace 事件记录。Axion 实现了 `CostTracker`（token、美元成本、截图预算追踪）和 `TraceRecorder`（JSONL 格式的执行 Trace），这些都是通用需求。

**Axion 参考实现：** `/Users/nick/CascadeProjects/axion/Sources/AxionCLI/Services/CostTracker.swift`（成本追踪）、`/Users/nick/CascadeProjects/axion/Sources/AxionCLI/Trace/TraceRecorder.swift`（JSONL Trace 记录）

**验收标准：**

**给定** `CostTracker`（Sendable struct）
**当** Agent 执行中消耗 token
**则** 累计 inputTokens、outputTokens、cacheReadTokens、totalCostUsd，支持 screenshotBudget 限制

**给定** CostTracker 超过 maxBudgetUsd 或 maxScreenshots
**当** Agent 执行下一步
**则** 通过 SDK 的 `maxBudgetUsd` 或自定义 Hook 触发停止

**给定** CostTracker 数据
**当** Run 完成
**则** 通过 `RunCompleteContext` 暴露完整的 cost 摘要，供 `onRunComplete` 回调使用

**给定** `TraceRecorder`（Actor 隔离）
**当** Agent 执行中
**则** 记录 JSONL 格式的 Trace 事件（ts、event、payload），支持自定义事件名

**给定** `AgentOptions.traceBaseURL`（可选）
**当** 配置 Trace 输出目录
**则** Trace 文件写入 `{traceBaseURL}/{runId}/trace.jsonl`，默认不开启

**给定** `AgentOptions.traceEnabled`（Bool，默认 false）
**当** 设置为 true
**则** Agent 自动将 SDKMessage 流转为 Trace 事件写入文件

**新增 FR72:** 开发者可以通过 CostTracker 追踪 Run 级别的 Token/Cost/截图预算，通过 TraceRecorder 记录 JSONL 执行 Trace

### Story 20.3: 增强 Memory — Fact-based 生命周期与分类

作为 SDK 开发者，
我希望 SDK 提供基于 Fact 的增强 Memory 系统，
以便所有 Agent 可以积累和复用带证据支撑的结构化经验，而不是简单的文本记录。

**背景：** SDK 已有 `MemoryStoreProtocol`（save/query/delete/listDomains）和 `KnowledgeEntry`（content + tags + sourceRunId），这是 Phase 2 Epic 19 加入的基础能力。Axion 在此基础上构建了更高级的系统：`AppMemoryFact` 带 candidate→active→retired 生命周期、evidenceCount 驱动的置信度、affordance/avoid/observation 三类分类、以及 Bundle 导入导出。这些增强对所有反复运行的 Agent 通用 — 代码 Agent 可以记住 affordance（项目可用的 test runner）和 avoid（已知会导致 flaky test 的文件）。

**Axion 参考实现：** `/Users/nick/CascadeProjects/axion/Sources/AxionCLI/Memory/` — `AppMemoryFact.swift`（Fact 模型）、`MemoryFactStore.swift`（Fact 持久化）、`MemoryLifecycleService.swift`（生命周期管理）、`MemoryContextProvider.swift`（Prompt 注入）、`MemoryBundleExportService.swift`/`MemoryBundleImportService.swift`（Bundle 导入导出）

**验收标准：**

**给定** `MemoryFact` 模型
**当** 创建 Fact
**则** 包含 factId（djb2 确定性 hash）、domain、content、status（candidate/active/retired）、confidence（0-1）、evidenceCount、source（observation/imported）、kind（affordance/avoid/observation）、createdAt、lastVerifiedAt

**给定** `FactStore`（Actor 隔离的 Fact 持久化）
**当** 按域名查询 Facts
**则** 返回排序后的 Fact 列表，支持惰性迁移（读旧 KnowledgeEntry 时自动转为 MemoryFact）

**给定** `MemoryLifecycleService`
**当** Fact 的 evidenceCount >= 2 且 confidence >= 0.65
**则** 自动从 candidate 提升为 active

**给定** active Fact 超过 30 天未被验证
**当** Lifecycle 检查
**则** 降级为 retired；retired Fact 再次被观察到时恢复为 candidate

**给定** `MemoryContextProvider`
**当** 构建 System Prompt 注入
**则** 按 affordance（推荐路径）、avoid（注意事项）、observation（环境备注）三类分类，每类最多 5 条（按 confidence 降序），附带 "soft hints, not hard rules" 声明

**给定** `MemoryBundleExportService`
**当** 导出 Memory
**则** 支持全量导出或按 domain 过滤，输出包含 facts + metadata 的 JSON Bundle

**给定** `MemoryBundleImportService`
**当** 导入外部 Memory Bundle
**则** 所有 imported facts 降级为 candidate，confidence 封顶 0.55，source 标记为 imported

**新增 FR73:** 开发者可以通过 Fact-based Memory 系统实现带证据支撑的结构化经验积累，支持 candidate→active→retired 生命周期、三类分类注入 Prompt、以及 Bundle 导入导出

### Story 20.4: SDKMessage 输出格式化协议

作为 SDK 开发者，
我希望 SDK 提供结构化的 SDKMessage 输出格式化协议，
以便所有 Agent 项目可以轻松将 SDK 消息流转换为终端输出、JSON 输出或自定义格式。

**背景：** SDK 已有 `SDKMessage` 枚举（17 种 case），但没有内置的输出格式化。Axion 实现了 `SDKMessageOutputHandler` 协议及其 Terminal/JSON 实现，将 SDK 消息流转为人类可读的终端输出和结构化 JSON。这套协议对所有 CLI 模式的 Agent 项目通用。

**Axion 参考实现：** `/Users/nick/CascadeProjects/axion/Sources/AxionCLI/Commands/SDKOutputHandlers.swift`（Terminal/JSON 输出处理器）

**验收标准：**

**给定** `SDKMessageOutputHandler` 协议
**当** 定义
**则** 包含 `handle(_ message: SDKMessage)` 方法，接收 SDK 消息流并格式化输出

**给定** `TerminalOutputHandler`（SDK 内置实现）
**当** 收到 `.toolUse` 消息
**则** 输出 `步骤 {n}: {tool} — 开始执行`

**给定** `TerminalOutputHandler`
**当** 收到 `.result` 消息
**则** 输出任务完成摘要（总步数、耗时、重规划次数）

**给定** `JSONOutputHandler`（SDK 内置实现）
**当** 收到任何 SDKMessage
**则** 累积状态，`finalize()` 时输出完整 JSON 结构

**新增 FR74:** 开发者可以通过 SDKMessageOutputHandler 协议实现自定义输出格式，SDK 提供 Terminal 和 JSON 两种内置实现

---

## 设计哲学（从 Hermes 学到的）

> 以下 Epic 21–23 基于 Hermes Agent 自进化机制深度解析系列的研究成果，为 OpenAgentSDK 规划分层、渐进式的自进化能力。

1. **积极但克制** — 鼓励学习但明确划定边界（反模式清单）
2. **可逆性优先** — 只归档不删除，用 replace 而非覆盖
3. **成本意识** — 利用前缀缓存、辅助模型、间隔触发
4. **可选而非强制** — 每层都可以独立开关
5. **纵深防御** — 安全扫描在写入时和加载时都执行

---

## Epic 21: 记忆进化 — ExperienceExtractor 与自动审查

**目标：** 让 Agent 在会话结束时自动从对话中提炼值得持久化的经验，写入 FactStore。

**价值：** 用户花了 30 分钟教的偏好，下次对话全忘了——这是架构缺陷，不是模型能力问题。记忆进化是闭环学习的基础。

**覆盖的 FR（新增）：** FR75
**依赖：** Epic 19（Memory Store）、Epic 20（增强 Memory — Fact-based 生命周期与分类）

### Story 21.1: ExperienceExtractor 协议与信号模型

定义从对话中提取经验的抽象接口和数据模型。

**产出：**
- `ExperienceSignal` struct — 经验信号（内容、领域、类型、置信度）
- `ExperienceExtractor` protocol — 抽象接口，输入 `[SDKMessage]`，输出 `[ExperienceSignal]`
- `ExtractionConfig` — 配置项（反模式清单、信号阈值）

**Hermes 参考：**
- `agent/background_review.py` — `_MEMORY_REVIEW_PROMPT` 和 `_COMBINED_REVIEW_PROMPT` 定义了审查逻辑
  - 重点关注：审查 prompt 的两段式结构（记忆审查 + 技能审查）
  - 记忆审查聚焦两类信号：用户身份（persona, preferences）和用户期望（work style, behavior）
  - 组合审查 prompt 的格式和措辞（"Be ACTIVE" vs "Nothing to save" 的平衡）

**现有 SDK 基础：**
- `Types/MemoryFact.swift` — `MemoryFact` 已有完整的生命周期（candidate→active→retired）、置信度、证据计数
- `Types/MemoryTypes.swift` — `KnowledgeEntry` 和 `MemoryStoreProtocol` 已定义存储抽象
- `Stores/FactStore.swift` — 持久化存储已实现（actor、JSON 文件、legacy 迁移）

### Story 21.2: LLMExperienceExtractor — LLM 驱动的经验提取器

用 LLM 调用来从对话中提取经验信号的内置实现。

**产出：**
- `LLMExperienceExtractor` — 基于 LLM 的 ExperienceExtractor 实现
- 审查 prompt 模板（包含反模式清单）
- 冻结快照模式：提取结果写入磁盘但不刷新当前 system prompt

**Hermes 参考：**
- `agent/background_review.py:1-145` — 完整的后台审查实现
  - `_MEMORY_THREAT_PATTERNS` (第 34-37 行) — 提示注入检测模式
  - `_COMBINED_REVIEW_PROMPT` — 组合审查 prompt，同时处理记忆和技能
  - **反模式清单**（第 121-144 行）：
    - 环境依赖的失败（missing binaries, command not found）
    - 负面断言（"browser tools do not work"）
    - 一次性瞬态错误（重试就好的那种）
    - 一次性任务叙述（"summarize today's market"）
  - **关键措辞**："If a tool failed because of setup state, capture the FIX — never 'this tool does not work' as a standalone constraint"
- `tools/memory_tool.py:67-100` — 记忆安全扫描
  - `_MEMORY_THREAT_PATTERNS` — 写入时的威胁模式检测（prompt injection, exfil, SSH backdoor）
  - `_INVISIBLE_CHARS` — 不可见 Unicode 字符检测
  - `_scan_memory_content()` — 写入时扫描函数

**现有 SDK 基础：**
- `API/LLMClient.swift` — 可复用现有 LLM 客户端做提取
- `Utils/MemoryContextProvider.swift` — 已有将 facts 格式化为 prompt 的能力

### Story 21.3: ReviewHook — sessionEnd 自动审查接入

将 ExperienceExtractor 接入 HookRegistry 的 `sessionEnd` 事件，完成记忆进化的闭环。

**产出：**
- `MemoryReviewHook` — 注册到 `sessionEnd` 的 hook 实现
- 间隔控制：不是每次会话都审查，通过配置控制间隔
- 操作摘要：审查完成后生成人类可读的摘要

**Hermes 参考：**
- `agent/background_review.py:1-40` — 触发条件和间隔控制
  - `_memory_nudge_interval` 和 `_skill_nudge_interval` — 审查间隔配置
  - 三个条件同时满足才触发：有最终回复、对话未中断、达到审查间隔
- `agent/background_review.py` — `spawn_background_review()` 函数
  - Fork 审查代理，继承父代理的 `model`, `provider`, `api_key`, `base_url`
  - **前缀缓存共享**：`review_agent._cached_system_prompt = agent._cached_system_prompt`
  - `session_start` 和 `session_id` 固定以保证缓存一致
  - 审查代理工具白名单：只允许 `memory`, `skill_manage`, `skill_view`, `skills_list`
  - `summarize_background_review_actions()` — 提取人类可读的操作摘要

**现有 SDK 基础：**
- `Hooks/HookRegistry.swift` — 已有 `sessionEnd` 事件
- `Types/HookTypes.swift` — `HookEvent.sessionEnd` 已定义

### Story 21.4: 记忆安全扫描与冻结快照

防止记忆被武器化，确保前缀缓存不被破坏。

**产出：**
- 写入时扫描：威胁模式检测（prompt injection、exfil、SSH backdoor）
- 加载时扫描：系统提示词构建时扫描所有注入的上下文
- 不可见 Unicode 字符检测
- 冻结快照模式：会话中写入 fact 不刷新 system prompt

**Hermes 参考：**
- `tools/memory_tool.py:67-100` — 完整的安全扫描实现
  - `_MEMORY_THREAT_PATTERNS` — 13 种威胁模式
  - `_INVISIBLE_CHARS` — 6 种不可见 Unicode 字符
  - `_scan_memory_content()` — 写入时扫描
  - `_INVISIBLE_CHARS` 集合 — U+200B, U+200C, U+200D, U+2060, U+FEFF, U+202A-E
- `tools/memory_tool.py` (docstring) — 冻结快照设计说明
  - "Mid-session writes update files on disk immediately (durable) but do NOT change the system prompt — this preserves the prefix cache for the entire session."
- `agent/background_review.py:70-75` — 缓存继承实现
  - 审查代理继承 `_cached_system_prompt`、`session_start`、`session_id`
  - 字节级一致保证前缀缓存命中
  - PR #17276 分析：约 26% 端到端成本降低

**现有 SDK 基础：**
- `Stores/FactStore.swift` — 已有 `validateDomainName()` 做路径遍历防护
- `Utils/MemoryContextProvider.swift` — 系统提示词注入的入口

**新增 FR75:** 开发者可以通过 ExperienceExtractor 从对话中自动提取经验，通过 MemoryReviewHook 在会话结束时触发审查，通过安全扫描防止记忆被武器化

---

## Epic 22: 技能进化 — SkillEvolver 与生命周期管理

**目标：** 让 Agent 能从对话中自动创建、更新、归档技能，实现「从经验中提炼可复用的操作指南」。

**价值：** 记忆解决「你是谁、世界是什么样的」，技能解决「这类事该怎么做」。技能是 Agent 的程序性知识——跨会话可复用的操作指南。

**覆盖的 FR（新增）：** FR76
**依赖：** Epic 11（技能系统）、Epic 21（ExperienceExtractor）

### Story 22.1: SkillSignal 模型与 SkillEvolver 协议

定义技能变更信号和进化器接口。

**产出：**
- `SkillSignal` struct — 技能变更信号（skillName、signalType、content、confidence、source）
- `SkillEvolver` protocol — 技能进化器抽象接口
- `SkillLifecycleState` — active / deprecated / experimental / retired 状态机

**Hermes 参考：**
- `tools/skill_usage.py:1-100` — 技能生命周期管理
  - `STATE_ACTIVE`, `STATE_STALE`, `STATE_ARCHIVED` — 三态定义
  - `_usage_file()` → `~/.hermes/skills/.usage.json` — 使用追踪 sidecar 文件
  - 设计决策：sidecar 而非 frontmatter，"keeps operational telemetry out of user-authored SKILL.md content"
  - `provenance` 字段：`agent_created` / `bundled` / `hub_installed` — 来源追踪
  - 原子写入：`tempfile + os.replace` 模式
  - 文件锁：`fcntl` (Unix) / `msvcrt` (Windows) 跨进程序列化
- `tools/skill_manager_tool.py:1-80` — 技能管理工具
  - 动作定义：`create`, `edit`, `patch`, `delete`, `write_file`, `remove_file`
  - 目录布局：`~/.hermes/skills/<skill>/SKILL.md + references/ + templates/ + scripts/`
  - 安全扫描：`skills_guard.scan_skill()` 对外部安装的技能

**现有 SDK 基础：**
- `Types/SkillTypes.swift` — `Skill` struct 已有 `baseDir`, `supportingFiles` 字段
- `Tools/SkillRegistry.swift` — 已有技能注册和查找
- `Skills/SkillLoader.swift` — 已有从文件系统加载技能

### Story 22.2: LLMSkillEvolver — LLM 驱动的技能进化

用 LLM 调用来识别技能信号并执行技能变更。

**产出：**
- `LLMSkillEvolver` — 基于 LLM 的 SkillEvolver 实现
- 技能审查 prompt（类级命名约束、优先修补策略、用户偏好嵌入）
- 内存中 Skill 字段合并（promptTemplate、description、whenToUse 等字段级别的 partial override，不涉及文件系统操作）

**Hermes 参考：**
- `agent/background_review.py:45-145` — `_SKILL_REVIEW_PROMPT` 完整内容
  - **触发信号**（4 类）：
    1. 风格纠正（"stop doing X", "too verbose"）
    2. 流程纠正（"先写测试再写代码"）
    3. 新技术（workaround、debugging path）
    4. 技能过时（loaded skill turned out wrong）
  - **优先级顺序**：
    1. UPDATE A CURRENTLY-LOADED SKILL
    2. UPDATE AN EXISTING UMBRELLA
    3. ADD A SUPPORT FILE
    4. CREATE A NEW CLASS-LEVEL UMBRELLA（最后手段）
  - **类级命名约束**：名称不能是 PR number、error string、feature codename
  - **用户偏好嵌入**：preferences belong in SKILL.md body, not just in memory
  - **三种支持文件**：`references/`（参考文档）、`templates/`（模板）、`scripts/`（脚本）
- `tools/skill_manager_tool.py:1-80` — 技能文件操作
  - `skill_manage(action="create/edit/patch/delete/write_file/remove_file")`
  - `_guard_agent_created_enabled()` — 代理创建的技能安全扫描开关
  - `_security_scan_skill()` — 安全扫描函数

### Story 22.3: SkillUsageTracker — 使用追踪与生命周期转换

追踪技能使用频率，自动执行生命周期状态转换。

**产出：**
- `SkillUsageTracker` — 追踪 view_count、last_viewed_at、last_managed_at
- 生命周期转换：active → deprecated（30天）→ retired（90天）
- Pinned 技能跳过所有自动转换
- 使用追踪 sidecar 文件（与技能内容分离）

**Hermes 参考：**
- `tools/skill_usage.py:1-100` — 完整的使用追踪实现
  - `bump_view(skill_name)` — 增加查看计数
  - `bump_manage(skill_name)` — 更新管理时间戳
  - `get_usage(skill_name)` — 获取使用数据
  - `get_provenance(skill_name)` — 获取技能来源
  - `set_provenance(skill_name, provenance)` — 设置来源
  - `_usage_file_lock()` — 文件锁（fcntl/msvcrt）
  - 原子写入：`tempfile + os.replace`（`.usage.json`）
  - 追踪字段：`view_count`, `last_viewed_at`, `last_managed_at`, `state`, `pinned`, `provenance`

**现有 SDK 基础：**
- `Types/SkillTypes.swift` — `Skill` struct 可扩展 lifecycle state

### Story 22.4: Curator — 自动策展人

在 Agent 空闲时自动整理技能库：合并重叠、归档过期、修补技能。

**产出：**
- `SkillCurator` — 策展人服务
- 触发条件：代理空闲 + 距上次策展超过配置间隔（默认 7 天）
- 安全边界：只操作 agent_created 技能，不碰内置/Hub/用户 pinned 技能
- 策展状态持久化（last_run_at、paused、run_count）
- dry-run 模式

**Hermes 参考：**
- `agent/curator.py:1-200` — Curator 完整实现
  - `_default_state()` — 默认状态（last_run_at, paused, run_count）
  - `load_state()` / `save_state()` — 状态持久化（JSON + 原子写入）
  - `is_enabled()` — 默认开启
  - `get_interval_hours()` — 默认 7 天（168 小时）
  - `get_min_idle_hours()` — 默认 2 小时
  - `get_stale_after_days()` — 默认 30 天
  - `get_archive_after_days()` — 默认 90 天
  - `should_run_now()` — 判断是否该运行
  - `_strip_aux_credential()` — 辅助模型凭据处理
  - 不变量：只操作 agent_created 技能、永不自动删除、pinned 跳过转换

**新增 FR76:** 开发者可以通过 SkillEvolver 从对话中自动进化技能，通过 SkillUsageTracker 追踪使用频率并执行生命周期转换，通过 SkillCurator 自动策展技能库

---

## Epic 23: 高级进化 — 插件生态（可选）

**目标：** 提供插件化的高级自进化能力，让开发者按需集成。

**价值：** 会话搜索、prompt 进化优化等是锦上添花的能力，不适合纳入核心 SDK，更适合作为可插拔模块。

**覆盖的 FR（新增）：** FR77
**依赖：** Epic 21（ExperienceExtractor）、Epic 22（SkillEvolver）

### Story 23.1: SelfEvolutionPlugin 协议与插件注册

定义自进化插件的统一接入协议。

**产出：**
- `SelfEvolutionPlugin` protocol — 统一接口
- `PluginRegistry` — 插件注册和生命周期管理
- 插件配置 schema（`AgentOptions` 中新增 `evolutionPlugins` 字段）

**Hermes 参考：**
- `tools/memory_tool.py` 中 `MemoryProvider` 抽象类（博客文章第二篇提到）
  - `initialize(session_id)` — 会话初始化
  - `system_prompt_block()` — 注入系统提示词
  - `prefetch(query)` — 每轮预取
  - `sync_turn(user_msg, assistant_resp)` — 每轮同步
  - `get_tool_schemas()` / `handle_tool_call()` — 工具暴露
  - `on_session_end(messages)` — 会话结束钩子
  - `on_pre_compress(messages)` — 压缩前提取
  - **一家一限制**：只允许一个外部记忆提供商

**现有 SDK 基础：**
- `Hooks/HookRegistry.swift` — 已有插件式 hook 注册机制
- `Tools/MCP/MCPClientManager.swift` — MCP 外部工具集成的模式可参考

### Story 23.2: SessionSearchPlugin — 会话全文搜索

基于 SQLite FTS5 的会话搜索，让 Agent 回溯过往所有对话。

**产出：**
- `SessionSearchPlugin` — FTS5 全文搜索插件
- 三种搜索模式：发现（关键词）、滚动（特定会话浏览）、浏览（最近会话）
- 搜索结果带上下文窗口（匹配片段前后各 5 条消息）
- 零 LLM 成本（纯数据库操作）
- 暴露为 MCP 工具或内置工具

**Hermes 参考：**
- `agent/trajectory.py` — 会话存储和搜索（博客第五篇提到）
  - SQLite 数据库存储所有对话
  - FTS5 全文搜索引擎
  - `session_search(query=)` — 关键词搜索
  - `session_search(session_id=, around_message_id=)` — 会话内浏览
  - `session_search()` — 最近会话列表
  - 搜索结果结构：匹配片段 + 前后 5 条消息 + 会话开头 3 条 + 会话结尾 3 条

**现有 SDK 基础：**
- `Stores/SessionStore.swift` — 已有会话持久化
- `HTTP/RunPersistenceService.swift` — Run 持久化
- `Utils/TraceRecorder.swift` — JSONL 轨迹记录

### Story 23.3: PromptEvolverPlugin — 进化式 Prompt 优化

用进化算法优化 skill 的 promptTemplate，提升技能质量。

**产出：**
- `PromptEvolverPlugin` — 可选的 prompt 进化优化插件
- Organism（有机体）/ Evaluator（评估者）/ Mutator（变异者）三组件
- 进化参数配置（种群大小、轮次、适应度函数）
- 适配 `Skill.promptTemplate` 作为进化目标

**Hermes 参考：**
- `agent/trajectory.py` + 可选技能 — Darwinian Evolver（博客第五篇提到）
  - 来源：Imbue Research 的 `darwinian_evolver`
  - 工作流：初始种群 → 评估适应度 → 选择最优 → LLM 变异 → 重复 N 轮
  - Organism：被进化的对象（prompt 模板、正则、SQL、代码）
  - Evaluator：打分函数 [0, 1]，区分"可训练失败"和"保留失败"
  - Mutator：LLM 基于失败案例生成变体
  - 成本：50-500 次 LLM 调用/次，适用于值得优化的 prompt

**新增 FR77:** 开发者可以通过插件机制按需集成高级自进化能力，包括会话全文搜索和进化式 Prompt 优化

---

## 自进化架构总览

```
┌─────────────────────────────────────────────────────────┐
│                   OpenAgentSDK                          │
│                                                         │
│  ┌───────────────────────┐  ┌────────────────────────┐  │
│  │  Epic 21: 记忆进化     │  │  Epic 22: 技能进化      │  │
│  │                       │  │                        │  │
│  │  ExperienceExtractor  │  │  SkillEvolver          │  │
│  │  LLMExperienceExtract │  │  LLMSkillEvolver       │  │
│  │  MemoryReviewHook     │  │  SkillUsageTracker     │  │
│  │  记忆安全扫描          │  │  SkillCurator          │  │
│  │  冻结快照模式          │  │  生命周期管理           │  │
│  └───────────┬───────────┘  └────────────┬───────────┘  │
│              │                           │              │
│              └──────────┬────────────────┘              │
│                         │                               │
│              ┌──────────┴──────────┐                    │
│              │    HookRegistry     │                    │
│              │  sessionEnd hook    │                    │
│              │  postToolUse hook   │                    │
│              └─────────────────────┘                    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Epic 23: 高级进化插件（可选）                     │    │
│  │  SessionSearchPlugin                             │    │
│  │  PromptEvolverPlugin                             │    │
│  │  ExternalMemoryPlugin (via MCP)                  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## 自进化能力对照（Hermes vs SDK）

| 自进化能力 | Hermes 实现 | SDK 现状 | Epic |
|-----------|------------|---------|------|
| 持久记忆存储 | MEMORY.md + USER.md | `FactStore` + `MemoryFact` ✅ | 21 |
| 经验提取引擎 | background_review.py | `LLMExperienceExtractor` + `ExperienceExtractor` protocol ✅ | 21 |
| 记忆安全扫描 | memory_tool.py threat patterns | `MemorySecurityScanner` + `SecurityScanResult` ✅ | 21 |
| 冻结快照模式 | 会话开始注入、中途不刷新 | `FrozenSnapshot` + `FactStore.snapshot/rollback` ✅ | 21 |
| 技能定义与加载 | SKILL.md + SkillLoader | `Skill` + `SkillRegistry` ✅ | 22 |
| 技能自动创建/更新 | skill_manage + background review | 缺 ❌ | 22 |
| 技能使用追踪 | skill_usage.py sidecar | 缺 ❌ | 22 |
| 技能生命周期 | active→stale→archived | 缺 ❌ | 22 |
| 自动策展 | curator.py | 缺 ❌ | 22 |
| 会话搜索 | SQLite FTS5 | 缺 ❌ | 23 |
| Prompt 进化 | Darwinian Evolver | 缺 ❌ | 23 |
| 轨迹压缩 | trajectory_compressor.py | `TraceRecorder` 部分 ✅ | 23 |

## Hermes 关键源码索引

| 文件 | 路径 | 核心内容 |
|------|------|---------|
| 后台审查 | `agent/background_review.py` | `_MEMORY_REVIEW_PROMPT`, `_SKILL_REVIEW_PROMPT`, `_COMBINED_REVIEW_PROMPT`, fork 逻辑 |
| 记忆工具 | `tools/memory_tool.py` | 安全扫描、冻结快照、`§` 分隔符、字符限制 |
| 技能管理 | `tools/skill_manager_tool.py` | create/edit/patch/delete/write_file 动作 |
| 技能使用 | `tools/skill_usage.py` | 生命周期状态、使用追踪、文件锁、原子写入 |
| 策展人 | `agent/curator.py` | 间隔触发、策展状态、安全边界、dry-run |
| 轨迹压缩 | `trajectory_compressor.py` | 训练数据准备、结构化摘要 |

---

## Epic 24: 后台审查代理 — 闭环学习核心引擎

**目标：** 实现 Hermes 式后台审查代理，使 SDK 具备"每次对话后 fork 一个隔离 Agent 回放并学习"的核心闭环能力。补齐 Epic 21–23 留下的关键缺口——PluginRegistry 只能在进程内同步调用，无法 fork 独立 Agent 实例执行审查。

**价值：** 没有 forked review agent，SDK 的自进化只是"hook 链上跑一个 LLM 调用"——不是真正的闭环。Hermes 的闭环核心是：**对话结束 → fork 一个工具受限的审查 Agent → 回放对话快照 → 提取记忆/技能 → 下次对话自动加载**。这个闭环让 Agent 越用越懂用户，越用越擅长。

**为什么现在做：**
- Epic 21–23 已完成所有基础类型（ExperienceSignal、SkillSignal、PluginResult）和工具（LLMExperienceExtractor、LLMSkillEvolver、MemoryReviewHook、SkillCurator、PromptEvolverPlugin）
- 但这些工具都是"被调用"的——没有一个"主动调度"的审查 Agent 来串联它们
- 当前 PluginRegistry.dispatch() 在 sessionEnd 阶段只执行内存中的插件逻辑，不能启动独立 Agent、不能限制工具权限、不能共享前缀缓存
- Axion 作为 SDK 旗舰参考实现，已经到了需要这个闭环才能体现差异化价值的阶段

**覆盖的 FR（新增）：** FR78
**依赖：** Epic 21（ExperienceExtractor、FactStore）、Epic 22（SkillEvolver、SkillUsageTracker）、Epic 23（SelfEvolutionPlugin、PluginRegistry）

**Hermes 本地路径：** `/Users/nick/CascadeProjects/hermes-agent`

### 缺口分析：Hermes 闭环 vs SDK 现状

| 闭环环节 | Hermes 实现 | SDK 现状 | 差距 |
|----------|------------|---------|------|
| 触发时机 | conversation_loop.py 末尾，有间隔控制 | HookRegistry .sessionEnd 已有 | ✅ 触发点已有 |
| 审查执行 | fork AIAgent 实例（独立模型调用循环） | PluginRegistry.dispatch() 进程内调用 | ❌ 无独立 Agent |
| 工具限制 | 白名单（memory + skill_manage + skill_view） | 无工具限制机制 | ❌ 无工具白名单 |
| 前缀缓存 | 继承父 Agent 的 _cached_system_prompt | 无缓存共享 API | ❌ 无缓存共享 |
| 审查 prompt | 精心设计的 _COMBINED_REVIEW_PROMPT | MemoryReviewHook 有提取 prompt，但无"审查 Agent 级"的完整 prompt | ⚠️ 部分覆盖 |
| 审查结果 | 操作摘要通知用户 | 无 | ❌ 无通知机制 |
| 审查间隔 | _memory_nudge_interval / _skill_nudge_interval | 无间隔控制 | ❌ 无间隔控制 |

### 关键设计约束

实施前必须理解以下约束，它们影响 Story 之间如何组装：

**1. SDK Agent 是 class（引用类型）** — `Agent` 是 `@unchecked Sendable` class（`Sources/OpenAgentSDK/Core/Agent.swift:18`）。fork 一个审查 Agent 意味着创建一个新的 `Agent` 实例，不是 struct copy。两个实例共享同一个 `LLMClient`（通过 `AgentOptions.client` 注入或从 `apiKey` 新建）。

**2. SDK 没有线程（thread），只有 Task** — Hermes 用 Python `threading.Thread` 做 daemon thread。Swift 的对应物是 `Task.detached { ... }`（后台异步执行，不阻塞父 Agent）。审查 Agent 应该在 detached task 中运行，父 Agent 的 `prompt()` / `stream()` 返回后审查仍在后台执行。

**3. 工具白名单通过 AgentOptions 已有字段实现** — `AgentOptions.allowedTools: [String]?`（`AgentTypes.swift:357`）和 `AgentOptions.disallowedTools: [String]?`（`AgentTypes.swift:362`）已经存在。审查 Agent 不需要新的过滤机制——只需要在 `AgentOptions` 中设置 `allowedTools` 为白名单列表即可。不需要 `ReviewToolFilter` 或 `canUseTool` hack。

**4. 审查 Agent 的工具不是 SDK 内置工具** — SDK 的 `defineTool` 注册工具是给主 Agent 用的。审查 Agent 需要的是 **4 个专用审查工具**（save_memory、update_skill、create_skill、add_skill_file），它们调用 SDK 已有的 `FactStore` / `SkillEvolver` API，不经过 MCP。这些工具用 `defineTool` 定义后传入审查 Agent 的 `AgentOptions.tools`。

**5. 前缀缓存共享需要共享 LLMClient** — Anthropic 的前缀缓存是 HTTP 级别的：如果两个请求的 system prompt 前缀字节级一致，第二个请求命中缓存。审查 Agent 要命中缓存，需要：(a) 使用同一个 `LLMClient`（共享 HTTP 连接和缓存 key），(b) 使用完全相同的 system prompt。不需要 `_cachedSystemPrompt` 属性暴露——只需要在构造审查 Agent 的 `AgentOptions` 时传入与父 Agent 相同的 `systemPrompt` 字符串。

### Story 24.1: ReviewAgent — 独立审查 Agent 工厂

创建一个工厂方法，从父 Agent fork 出一个工具受限的审查 Agent 实例，并构建审查 prompt。

**产出：**

`Sources/OpenAgentSDK/Utils/ReviewAgent.swift`：
- `ReviewAgentConfig`（struct, Sendable, Codable）：
  ```swift
  public struct ReviewAgentConfig: Sendable, Codable {
      public let reviewMemory: Bool       // 是否审查记忆（默认 true）
      public let reviewSkills: Bool       // 是否审查技能（默认 true）
      public let maxTurns: Int            // 审查 Agent 最大轮次（默认 16，与 Hermes 一致）
      public let allowedTools: [String]   // 工具白名单
  }
  ```
- `ReviewAgentResult`（struct, Sendable）：
  ```swift
  public struct ReviewAgentResult: Sendable {
      public let memoryChanges: [String]      // 记忆变更描述列表
      public let skillChanges: [String]       // 技能变更描述列表
      public let summary: String              // 人类可读的操作摘要
      public let reviewMessages: [SDKMessage] // 审查 Agent 的完整消息历史
  }
  ```
- `Agent.createReviewAgent(config:)` — 从父 Agent fork 审查实例：
  - **继承项**：model, provider, apiKey/baseURL, systemPrompt, LLMClient（共享引用）
  - **不继承项**：tools（用审查专用工具替换）, hookRegistry（审查不触发用户 hooks）, maxTurns（用审查配置的值）, permissionMode（设为 .bypassPermissions）
  - **新建项**：独立的 sessionId（`review-{parentSessionId}`）
- `ReviewPromptBuilder`（enum, 无实例）：
  - `static func memoryReviewPrompt() -> String` — 记忆审查 prompt
  - `static func skillReviewPrompt() -> String` — 技能审查 prompt
  - `static func combinedReviewPrompt() -> String` — 组合审查 prompt（默认使用）
  - prompt 内容翻译自 Hermes，保留核心逻辑但适配 SDK 术语（如用 "domain" 替代 "memory target"，用 "Skill" 替代 "SKILL.md"）

**Hermes 参考：**
- `/Users/nick/CascadeProjects/hermes-agent/agent/background_review.py`（582 行）
  - 行 30–145：`_MEMORY_REVIEW_PROMPT`、`_SKILL_REVIEW_PROMPT`、`_COMBINED_REVIEW_PROMPT` — 三个审查 prompt 完整文本，**必须逐行翻译为 Swift 版本**
  - 行 393–405：fork AIAgent 配置 — `max_iterations=16, quiet_mode=True, parent_session_id=agent.session_id, skip_memory=True`
  - 行 406–440：审查 Agent 继承项 — `_memory_write_origin`, `_memory_store`, `_memory_enabled`, `_user_profile_enabled`, `_cached_system_prompt`, `session_start`, `session_id`
  - 行 448–453：工具白名单 — `get_tool_definitions(enabled_toolsets=["memory", "skills"])`
  - 行 462–471：审查执行 — `review_agent.run_conversation(user_message=prompt + constraint, conversation_history=messages_snapshot)`
  - 行 496–505：操作摘要 — `summarize_background_review_actions()` 提取 tool_result 中的操作信息，格式化为人类可读摘要
  - 行 547–572：`spawn_background_review_thread()` — 构建 thread target + prompt

**现有 SDK 基础：**
- `Sources/OpenAgentSDK/Core/Agent.swift:18` — `Agent` class（@unchecked Sendable）
- `Sources/OpenAgentSDK/Core/Agent.swift:125–160` — `Agent.init(options:)` / `Agent.init(definition:options:)` 工厂方法
- `Sources/OpenAgentSDK/Core/Agent.swift:1035` — `Agent.prompt(_ text:)` 审查 Agent 可用此方法执行单次审查
- `Sources/OpenAgentSDK/Core/Agent.swift:1792` — `Agent.stream(_ text:)` 审查 Agent 也可用流式执行
- `Sources/OpenAgentSDK/Types/AgentTypes.swift:229` — `AgentOptions` struct（所有配置字段）
- `Sources/OpenAgentSDK/Types/AgentTypes.swift:357–362` — `allowedTools` / `disallowedTools` 已有工具过滤字段
- `Sources/OpenAgentSDK/Types/AgentTypes.swift:297` — `sessionId` 字段（审查 Agent 设置为 `review-{parent}`）
- `Sources/OpenAgentSDK/LLM/LLMClient.swift` — `LLMClient` 可在两个 Agent 实例间共享（审查 Agent 继承父 Agent 的 client 引用）

### Story 24.2: ReviewTools — 审查专用工具集

定义 4 个审查专用工具，作为审查 Agent 唯一可调用的工具。这些工具直接调用 SDK 已有的 `FactStore` / `SkillEvolver` API，不经过 MCP。

**产出：**

`Sources/OpenAgentSDK/Tools/Review/` 目录：
- `ReviewMemoryTool.swift` — `review_save_memory` 工具：
  - 参数：`domain: String`, `content: String`, `kind: String`（affordance/avoid/observation）, `confidence: Double`
  - 实现：调用 `FactStore.save(domain:fact:)` 保存 `ExperienceSignal.toFact()`
  - 返回：`{"success": true, "message": "Memory saved to domain '{domain}'"}`
- `ReviewSkillUpdateTool.swift` — `review_update_skill` 工具：
  - 参数：`skillName: String`, `updates: String`（JSON，可含 promptTemplate/description/whenToUse/argumentHint）, `reason: String`
  - 实现：构造 `SkillSignal`，调用 `SkillEvolver.evolve(skill:signals:config:)`
  - 返回：`{"success": true, "message": "Skill '{skillName}' updated", "changes": [...]}`
- `ReviewSkillCreateTool.swift` — `review_create_skill` 工具：
  - 参数：`name: String`, `description: String`, `promptTemplate: String`, `whenToUse: String?`
  - 实现：构造 `Skill` 实例，通过 `SkillRegistry` 注册
  - 返回：`{"success": true, "message": "Skill '{name}' created"}`
- `ReviewSkillFileTool.swift` — `review_add_skill_file` 工具：
  - 参数：`skillName: String`, `filePath: String`, `content: String`
  - 实现：在技能目录下创建支持文件（references/templates/scripts 前缀）
  - 返回：`{"success": true, "message": "File added to skill '{skillName}'"}`

**设计要点：**
- 每个工具用 `defineTool` 定义，返回 JSON 字符串（与 Hermes 的 tool_result 格式一致）
- 工具名以 `review_` 前缀命名，与主 Agent 的工具名不冲突
- 工具构造时注入 `FactStore` / `SkillEvolver` / `SkillRegistry` 实例（依赖注入，不单例）
- 所有工具操作完成后返回标准化的 JSON，供 `summarizeActions()` 解析

**Hermes 参考：**
- `/Users/nick/CascadeProjects/hermes-agent/tools/memory_tool.py`（586 行）
  - 行 1–60：`memory(action=add/replace/remove/read, target=memory/user)` 工具定义
  - 行 61–120：安全扫描 `_MEMORY_THREAT_PATTERNS`（审查工具无需重复，`MemorySecurityScanner` 已覆盖）
  - 行 121–200：`§` 分隔符格式和字符限制
- `/Users/nick/CascadeProjects/hermes-agent/tools/skill_manager_tool.py`（931 行）
  - 行 1–80：`skill_manage(action=create/edit/patch/delete/write_file/remove_file)` 工具定义
  - 行 80–200：文件操作（references/templates/scripts 目录布局）
  - 行 200–300：`_guard_agent_created_enabled()` 安全扫描开关
  - 行 300–400：`_security_scan_skill()` 安全扫描函数

**现有 SDK 基础：**
- `Sources/OpenAgentSDK/Tools/` — `defineTool` 工具定义模式
- `Sources/OpenAgentSDK/Types/ExperienceTypes.swift:346` — `ExperienceExtractor` protocol
- `Sources/OpenAgentSDK/Types/SkillEvolutionTypes.swift:540` — `SkillEvolver` protocol
- `Sources/OpenAgentSDK/Utils/LLMExperienceExtractor.swift` — `LLMExperienceExtractor` 可被审查工具内部调用
- `Sources/OpenAgentSDK/Utils/LLMSkillEvolver.swift` — `LLMSkillEvolver` 可被审查工具内部调用
- `Sources/OpenAgentSDK/Memory/FactStore.swift` — `FactStore.save(domain:fact:)` 持久化接口
- `Sources/OpenAgentSDK/Tools/SkillRegistry.swift` — `SkillRegistry` 注册和查找

### Story 24.3: ReviewOrchestrator — 审查调度与间隔控制

实现审查的触发、间隔控制和后台执行机制。将审查 Agent 的创建、执行、结果收集编排为一个完整流程。

**产出：**

`Sources/OpenAgentSDK/Utils/ReviewOrchestrator.swift`：
- `ReviewScheduleConfig`（struct, Sendable, Codable）：
  ```swift
  public struct ReviewScheduleConfig: Sendable, Codable {
      public var memoryReviewInterval: Int    // 每隔多少条消息触发记忆审查（默认 4）
      public var skillReviewInterval: Int     // 每隔多少条消息触发技能审查（默认 6）
      public var minMessagesForReview: Int    // 最少消息数（默认 4）
      public var reviewModel: String?         // 审查模型（nil = 继承父 Agent）
  }
  ```
- `ReviewOrchestrator`（struct, Sendable）：
  - `init(scheduleConfig:factStore:skillRegistry:skillEvolver:)` — 注入依赖
  - `shouldReview(sessionId:messageCount:config:) -> (memory: Bool, skill: Bool)` — 间隔判断
  - `func executeReview(parentAgent:Agent, messages:[SDKMessage], config:ReviewAgentConfig) async -> ReviewAgentResult?` — 完整审查流程：
    1. 调用 `ReviewPromptBuilder` 构建审查 prompt
    2. 调用 `Agent.createReviewAgent(config:)` fork 审查 Agent
    3. 在 `Task.detached` 中执行 `reviewAgent.prompt(reviewPrompt)` — 不阻塞父 Agent
    4. 从审查 Agent 的消息历史中提取操作摘要
    5. 返回 `ReviewAgentResult`
  - `static func summarizeActions(_ messages: [SDKMessage], priorSnapshot: [SDKMessage]) -> [String]` — 从审查消息中提取操作描述
- `ReviewOrchestrator` 注册到 `HookRegistry.sessionEnd`：
  - 在 `Agent.init` 中检查 `AgentOptions.reviewScheduleConfig` 是否存在
  - 如果存在，注册 `.sessionEnd` hook 调用 `orchestrator.executeReview()`
  - hook handler 返回 `HookOutput(additionalContext: summary)` 将摘要注入输出流

**Hermes 参考：**
- `/Users/nick/CascadeProjects/hermes-agent/agent/background_review.py`（582 行）
  - 行 347–370：触发条件检查 — `_memory_nudge_interval` / `_skill_nudge_interval` 间隔判断
  - 行 547–572：`spawn_background_review_thread()` — 构建 thread target
  - 行 569–571：`_target()` 调用 `_run_review_in_thread(agent, messages_snapshot, prompt)` — 后台执行
  - 行 496–505：`summarize_background_review_actions()` — 操作摘要提取逻辑：
    ```python
    # 遍历审查消息，提取 tool_result 中 success=True 的操作
    # 跳过 messages_snapshot 中已有的旧操作（避免重复）
    # 返回去重后的操作列表
    ```
  - 行 501–513：摘要通知 — `agent._safe_print(f"💾 Self-improvement review: {summary}")`
- `/Users/nick/CascadeProjects/hermes-agent/agent/conversation_loop.py` — 触发入口（在 `_spawn_background_review` 调用处）

**现有 SDK 基础：**
- `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` — `.sessionEnd` hook 注册和执行
- `Sources/OpenAgentSDK/Core/Agent.swift:217–236` — Agent.init 中已有 `.sessionEnd` hook 注册逻辑（MemoryReviewHook 的注册方式，审查 hook 可参照此模式）
- `Sources/OpenAgentSDK/Core/Agent.swift:1479–1487` — `prompt()` 结尾触发 `.sessionEnd`，传入 `HookInput`（含消息历史）
- `Sources/OpenAgentSDK/Core/Agent.swift:1751–1758` — `stream()` 结尾同样触发 `.sessionEnd`
- `Sources/OpenAgentSDK/Types/HookTypes.swift:42–44` — `.preCompact` / `.postCompact` hook 事件类型

**Swift 并发模型映射：**
```
Hermes: threading.Thread(daemon=True, target=_target)
SDK:    Task.detached { await executeReview(...) }

Hermes: messages_snapshot = list(messages)（拷贝）
SDK:    let snapshot = messages（Swift Array 是 value type，自动拷贝）

Hermes: suppress_status_output = True
SDK:    审查 Agent 的 AgentOptions 不设 hookRegistry + permissionMode = .bypassPermissions
```

### Story 24.4: PrefixCacheSharing — 前缀缓存共享

确保审查 Agent 的 API 请求命中 Anthropic/OpenRouter 的前缀缓存，降低审查成本。

**产出：**

不新增独立文件。修改 `Agent.createReviewAgent(config:)` 的实现逻辑：

- **核心策略**：审查 Agent 的 `AgentOptions.systemPrompt` 必须与父 Agent 完全一致（字节级）
  - 从父 Agent 的 `systemPrompt` 属性直接复制（公开只读属性，`Agent.swift:29`）
  - 不注入时间戳、sessionId 等会变化的内容到 systemPrompt 中
  - 如果父 Agent 的 systemPrompt 是动态构建的（含时间戳），审查 Agent 必须使用父 Agent **实际发送的** systemPrompt 快照，而非重新构建
- **LLMClient 共享**：审查 Agent 复用父 Agent 的 `LLMClient` 实例（引用共享），确保 HTTP 连接和缓存 key 一致
- **缓存验证**：添加 `Logger.shared.debug("ReviewAgent", "prefix_cache_sharing", data: ["parentModel": ..., "reviewModel": ..., "systemPromptHash": ...])` 用于调试缓存命中率
- **成本追踪**：在 `AgentOptions` 新增 `agentLabel: String?` 字段（默认 nil），审查 Agent 设为 `"review"`。`CostTracker` 按 `agentLabel` 区分主 Agent 和审查 Agent 的 token 使用量

**Hermes 参考：**
- `/Users/nick/CascadeProjects/hermes-agent/agent/background_review.py:421–440` — 前缀缓存共享实现
  - 行 421–430：注释解释为什么要共享缓存——审查 Agent 如果重建 system prompt（新的时间戳、新的 sessionId、不同的工具集），前缀缓存 key 不匹配，缓存命中率暴跌
  - 行 431：`review_agent._cached_system_prompt = agent._cached_system_prompt` — 直接赋值字节级一致的 prompt
  - 行 433–440：`review_agent.session_start = agent.session_start` + `review_agent.session_id = agent.session_id` — 防御性固定，确保即使有代码路径绕过缓存直接重建 prompt，仍然字节级一致
  - **效果**：PR #17276 分析约 26% 端到端成本降低

**现有 SDK 基础：**
- `Sources/OpenAgentSDK/Core/Agent.swift:29` — `public let systemPrompt: String?` 公开只读，可直接复制
- `Sources/OpenAgentSDK/Core/Agent.swift:165` — `private init(mergedOptions:client:)` 内部初始化器，`systemPrompt` 从 `mergedOptions.systemPrompt` 获取
- `Sources/OpenAgentSDK/LLM/LLMClient.swift` — `LLMClient` 实例可在两个 Agent 间共享
- `Sources/OpenAgentSDK/Core/Agent.swift:109` — 已有 `compactState` 跟踪压缩状态

**新增 FR78:** 开发者可以通过 ReviewOrchestrator 在每次对话结束后自动 fork 一个工具受限的审查 Agent，审查 Agent 继承父 Agent 的 systemPrompt 命中前缀缓存降低成本，回放对话快照并通过 4 个专用审查工具提取记忆/技能，生成操作摘要通知用户。审查有间隔控制，不是每次都触发。审查在 detached task 中执行，失败不阻塞主对话。

---

## Epic 24 补充说明

### 为什么这是独立 Epic 而不是 Epic 23 的延续

Epic 21–23 构建了自进化的"砖块"（类型、协议、工具）。Epic 24 构建的是"建筑师"——把这些砖块组装成闭环的调度引擎。两者是不同抽象层的工作：

- Epic 21–23：定义"能做什么"（extract experience, evolve skill, search sessions）
- Epic 24：定义"谁来做、什么时候做、在什么限制下做"

### Story 间的依赖关系

```
24.1 ReviewAgent（P0）
  ├── 定义 ReviewAgentConfig、ReviewAgentResult、ReviewPromptBuilder
  └── 定义 Agent.createReviewAgent() 工厂方法
        │
        ├──► 24.2 ReviewTools（P0）— 审查 Agent 的 allowedTools 引用这 4 个工具
        │
        └──► 24.3 ReviewOrchestrator（P1）— 调用 createReviewAgent() + 在 sessionEnd hook 中编排
              │
              └──► 24.4 PrefixCacheSharing（P2）— 修改 createReviewAgent() 的 systemPrompt 传递逻辑
```

建议实施顺序：24.1 → 24.2 → 24.3 → 24.4。24.1 和 24.2 可以并行开发（接口先行），24.3 依赖两者完成，24.4 最后做。

### 实现优先级

| Story | 优先级 | 理由 |
|-------|--------|------|
| 24.1 ReviewAgent | P0 | 闭环的核心——没有独立审查 Agent，其他都没有意义 |
| 24.2 ReviewTools | P0 | 审查 Agent 的手脚——没有工具它什么都做不了 |
| 24.3 ReviewOrchestrator | P1 | 调度和间隔控制——控制成本和频率 |
| 24.4 PrefixCacheSharing | P2 | 成本优化——重要但不影响闭环建立 |

### 更新后的自进化能力对照

| 自进化能力 | Hermes 实现 | SDK 现状 | Epic |
|-----------|------------|---------|------|
| 持久记忆存储 | MEMORY.md + USER.md | `FactStore` + `MemoryFact` ✅ | 21 |
| 经验提取引擎 | background_review.py | `LLMExperienceExtractor` + `ExperienceExtractor` protocol ✅ | 21 |
| 记忆安全扫描 | memory_tool.py threat patterns | `MemorySecurityScanner` + `SecurityScanResult` ✅ | 21 |
| 冻结快照模式 | 会话开始注入、中途不刷新 | `FrozenSnapshot` + `FactStore.snapshot/rollback` ✅ | 21 |
| 技能定义与加载 | SKILL.md + SkillLoader | `Skill` + `SkillRegistry` ✅ | 22 |
| 技能自动创建/更新 | skill_manage + background review | `LLMSkillEvolver` + `SkillSignal` ✅ | 22 |
| 技能使用追踪 | skill_usage.py sidecar | `SkillUsageTracker` + `SkillUsageData` ✅ | 22 |
| 技能生命周期 | active→stale→archived | `SkillLifecycleState` + transitions ✅ | 22 |
| 自动策展 | curator.py | `SkillCurator` + `SkillCuratorStore` ✅ | 22 |
| 会话搜索 | SQLite FTS5 | `SessionSearchPlugin` + `SessionSearchEngine` ✅ | 23 |
| Prompt 进化 | Darwinian Evolver（种群变异） | `PromptEvolverPlugin`（单次 LLM 分析）⚠️ | 23 |
| 上下文压缩 | 结构化摘要（75% 阈值） | `Compact.swift` + auto-compact ✅ | 核心SDK |
| **后台审查 Agent** | **fork + 工具白名单 + 前缀缓存共享** | **缺 ❌** | **24** |
| **审查专用工具** | **memory/skill tools** | **缺 ❌** | **24** |
| **审查调度间隔** | **nudge_interval** | **缺 ❌** | **24** |
| **前缀缓存共享** | **_cached_system_prompt 继承** | **缺 ❌** | **24** |
