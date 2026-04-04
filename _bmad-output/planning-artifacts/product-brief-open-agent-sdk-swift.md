---
title: "Product Brief: OpenAgentSDKSwift"
status: "complete"
created: "2026-04-03"
updated: "2026-04-03T12:00:00Z"
inputs:
  - ~/.claude/plans/hazy-tumbling-globe.md
  - open-agent-sdk-typescript (source project)
---

# 产品简报：OpenAgentSDKSwift

## 概述

OpenAgentSDKSwift 是一个原生 Swift 包，将 Open Agent SDK 的全部能力引入 Swift 生态系统。它将经过验证的 TypeScript Agent SDK 移植到 Swift，使 macOS 应用开发者和服务器端 Swift 工程师能够构建具备 34 个内置工具、MCP 协议支持、会话持久化和钩子系统的 AI Agent 应用——无需将 Node.js 作为运行时依赖嵌入。

如今，希望获得 AI Agent 能力的 Swift 开发者面临一个艰难的选择：通过 Node.js 桥接、接受仅处理 API 调用的有限社区 SDK，或者从零开始构建一切。目前不存在生产级 Swift Agent 框架。OpenAgentSDKSwift 通过提供一套经过实战检验的 Agent 架构来弥补这一空白——该架构在 TypeScript 中已被验证，现在作为 Swift 的一等公民，使用 async/await、actors 和 AsyncStream 实现。

AI Agent 框架市场正以超过 45% 的年复合增长率增长（Grand View Research，2025），然而所有主要产品都以 TypeScript 或 Python 为优先。随着 Apple 的 FoundationModels 框架确立了 Swift 作为 AI 平台的地位，以及服务器端 Swift 采用的加速，推出一个面向 Apple 平台和 Linux 后端的原生 Swift Agent SDK 的时机已经成熟。

## 问题

构建 AI 驱动应用的 Swift 开发者面临三大叠加的困境：

1. **不存在原生 Agent SDK。** 所有主要 Agent 框架——Anthropic Agent SDK、OpenAI Agents SDK、LangGraph、CrewAI——都仅支持 TypeScript 或 Python。Swift 开发者被排除在外。Apple 的 FoundationModels 框架支持在 Apple Silicon 上进行带工具调用的设备端推理，但它不提供云 LLM 访问、跨平台支持、MCP 协议或 Agent 应用所需的丰富工具生态系统。

2. **通过 Node.js 桥接是不可接受的。** 目前最接近的方案是在 Swift 代码旁边嵌入 Node.js 运行时。这增加了部署复杂性、内存开销和脆弱的进程间通信。对于生产级 macOS 应用和服务器部署来说，这是行不通的。

3. **社区 Swift SDK 只是 API 客户端，而非 Agent 框架。** 像 AnthropicSwiftSDK、AnthropicKit 和 SwiftAnthropic 这样的项目可以处理消息补全和流式传输，但它们不能运行 Agent 循环、执行工具、管理会话或支持 MCP。开发者仍然需要自行构建 80% 的系统。像 ClaudeCodeSDK 这样的 CLI 包装器依赖于外部二进制文件，而不是提供独立的 Agent 原语。

现状的代价是实实在在的：开发者要么放弃 Swift 进行 AI 开发，要么花费数周时间重新实现 TypeScript SDK 已经做好的功能。

## 解决方案

OpenAgentSDKSwift 是一个 Swift Package Manager 库（`OpenAgentSDK`），以原生 Swift 提供完整的 Agent 技术栈：

- **Agent 循环** — 核心 QueryEngine 运行完整周期：调用 LLM、解析工具使用请求、执行工具、回传结果、重复。通过 `AsyncStream<SDKMessage>` 流式传输，通过 `prompt()` 阻塞调用。
- **34 个内置工具** — 按三个层级组织，使用者只需加载所需工具：
  - **核心层**（任何 Agent 必备）：Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch
  - **高级层**（多 Agent 编排）：Agent、SendMessage、Task 工具（Create/List/Update/Get/Stop/Output）、Team 工具（Create/Delete）、NotebookEdit
  - **专业层**（CLI/开发者工作流）：Worktree、Plan、Cron、RemoteTrigger、LSP、Config、TodoWrite、MCP Resource 工具
  所有层级打包在同一个包中；使用者通过工具注册按需选择。
- **MCP 协议支持** — 连接外部 MCP 服务器（stdio/HTTP）并暴露进程内 MCP 工具。使 Swift 开发者能够使用不断增长的 MCP 生态系统。基于 mcp-swift-sdk 构建。
- **会话持久化** — 基于 JSON 的对话存储，支持保存、加载、分叉和恢复。通过 Swift actors 实现线程安全。
- **钩子系统** — 21 个生命周期事件（工具使用前后、会话开始/结束、子 Agent 生命周期等），支持函数和 shell 命令钩子。
- **自定义工具** — 使用 `defineTool()` 通过闭包定义工具，支持 Codable 输入解码和 JSON Schema 定义。
- **多提供商 LLM 路由** — 默认使用 Anthropic Claude，支持通过自定义 base URL 接入第三方提供商。
- **权限和安全模型** — 六种权限模式（default、acceptEdits、bypassPermissions、plan、dontAsk、auto）控制 Agent 可执行的工具。自定义 `canUseTool` 回调允许使用者定义授权逻辑。专为沙盒化 macOS 应用环境设计。

所有设计都符合 Swift 惯用模式：async/await、actors 用于状态隔离、Codable 用于序列化、面向协议的工具系统，以及 `for await` 模式匹配流式事件。

## 独特之处

1. **唯一具备完整 Agent 能力的 Swift SDK。** 没有其他 Swift 包能在单一库中提供内置工具 + MCP + 会话持久化 + 钩子。最接近的替代方案是 API 客户端（仅支持消息补全）或 CLI 包装器（依赖外部二进制文件）。Apple 的 FoundationModels 涵盖设备端工具调用，但不包括云 LLM、跨平台部署或 MCP。

2. **经过验证的架构，可控的移植风险。** 这是一个工作正常的 TypeScript SDK 的移植，架构已知——Agent 循环、工具系统和会话模型已在生产环境中经过实战检验。Swift 移植存在实现风险（特别是在动态 JSON Schema 处理、工具分发以及将钩子 shell 执行模型转换为 Swift 严格类型系统方面），但设计是经过验证的，且风险面已被识别。

3. **最小化依赖。** 一个外部依赖（DePasqualeOrg/mcp-swift-sdk，用于 MCP 协议）。Anthropic API 客户端基于 URLSession 自行构建。没有社区 Anthropic SDK 版本冲突，没有传递依赖噩梦。mcp-swift-sdk 依赖的成熟度和功能覆盖将在第六阶段进行评估；如果不够理想，备选方案是分叉维护或原生实现 MCP 协议。

4. **天然跨平台。** 通过 SPM 支持 macOS 13+ 和 Linux。无需 Apple 专用框架。适用于原生 macOS 应用和服务器端 Swift 部署。

5. **多语言 SDK 家族的一部分。** TypeScript SDK 已有 Go 移植版本。OpenAgentSDKSwift 将该家族扩展到 Swift，各语言间保持一致的 API 理念。

## 目标用户

**主要用户：macOS 应用开发者**，构建 AI 驱动的工具、编辑器或生产力应用，需要 Agent 能力但不想向终端用户附带 Node.js 运行时。对他们来说，成功意味着添加一个 SPM 依赖就能在几分钟内运行一个完整的 Agent。

**次要用户：服务器端 Swift 工程师**，在 Linux（Vapor、Hummingbird）上构建 AI 后端服务、聊天机器人或自动化工作流。对他们来说，成功意味着在服务器上使用与 macOS 工具相同的 SDK。

**第三类用户：AI/ML 工程师**，在 Swift 中工作，希望从原始 API 调用迈向完整的 Agent 编排，包括工具使用、会话管理和 MCP 集成。

## 成功标准

- **功能对等** — 所有 34 个工具在 macOS 和 Linux 上均通过单元测试，行为与 TypeScript SDK 一致
- **Swift 原生体验** — API 使用 async/await、AsyncStream、Codable 和 actors；熟悉 Swift 并发的开发者会感到自然。README 快速入门指南可在 15 分钟内产出可运行的 Agent
- **双平台 CI** — GitHub Actions 测试在 macOS 和 Linux 上均对每个 PR 通过
- **文档** — Swift-DocC 生成的文档，每个主要功能都有可运行的示例，包含快速入门的 README
- **社区信号** — 发布后 6 个月内获得 200+ GitHub star；来自外部开发者的 issue/PR；至少被一个第三方项目采用
- **测试覆盖** — 每阶段单元测试，Agent 循环集成测试（第三阶段起），示例编译在 CI 中验证
- **API 稳定性** — 核心 Agent 循环和工具系统 API 在 v1.0 时冻结；钩子和 MCP API 标记为演进中。采用语义化版本控制；Swift SDK 版本独立于 TypeScript SDK 版本

## 范围

**纳入 v1.0：**
- 全部 34 个内置工具，具备完整测试覆盖
- Anthropic Claude API 客户端（流式 + 阻塞）
- MCP 客户端和进程内 MCP 服务器
- 会话持久化（JSON 文件存储）
- 钩子系统（21 个生命周期事件，函数 + shell 钩子）
- 通过 `defineTool()` 自定义工具定义
- 子 Agent 支持（Agent 工具、SendMessage）
- 权限模式和预算追踪
- Auto-compact 和 micro-compact
- Task/Team/Worktree/Plan/Cron 管理存储
- Swift-DocC 文档
- GitHub Actions CI（macOS + Linux）
- 所有主要功能的可运行示例

**排除于 v1.0：**
- iOS/iPadOS/visionOS 支持（可行但推迟——需要审核工具在文件系统/进程沙盒约束下的兼容性；计划在 v1.1 中实现）
- Windows 平台支持
- IDE 扩展（VS Code、Xcode 插件）
- SwiftUI 配套包（聊天视图、消息渲染器）
- 托管服务或云部署
- 可视化 UI 或仪表板
- 微调模型托管
- Token 计费或使用量计量服务
- FoundationModels 集成（混合本地/云路由）

## 愿景

在 2-3 年内，OpenAgentSDKSwift 将成为在 Swift 中构建 AI Agent 应用的标准方式——每个 Swift 开发者在需要 Agent 能力时首选的库，正如 Vapor 之于 Web 服务器，Core Data 之于持久化。

它通过提供云 LLM 访问、跨平台支持（macOS、Linux，最终包括 iOS）和完整的 MCP 生态系统，来补充 Apple 的 FoundationModels 在设备端推理方面的能力。LLM 提供商抽象从第一天起就设计为支持基于协议的 `ModelProvider`，可以将 FoundationModels 与云提供商一起封装，从而在 SDK 成熟时实现混合本地/云 Agent 编排。

随着 AI Agent 市场的增长，SDK 将从工具使用编排演进到多 Agent 协作、自主工作流以及在 Swift 基础设施上的生产级 Agent 部署。多语言 SDK 家族（TypeScript、Go、Swift）将成为重视技术栈一致性的开发者首选的开源 Agent SDK。
