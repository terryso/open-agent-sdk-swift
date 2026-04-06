# Product Plan: Mac Native AI Agent for Swift Developers

> **Status:** Planning
> **Created:** 2026-04-06
> **Last Updated:** 2026-04-06

---

## 1. Vision

**"给 Apple 开发者的、不绑定模型的、原生体验的 AI Agent"**

市面上所有 AI 编码工具（Claude Code、Cursor、GitHub Copilot）都是通用型 + Electron/Node.js。没有一个为 Apple 平台开发者做深度优化，也没有一个是 Mac 原生体验。

我们要做的是：**用 Swift 写的、为 Swift/iOS/macOS 开发者优化的、支持多模型的 AI Agent。**

---

## 2. Market Landscape (2026-04)

| 产品 | 形态 | 技术栈 | AI 模型 | Mac 原生 |
|------|------|--------|---------|---------|
| Claude Code | 终端 CLI | Node.js/TypeScript | Claude only | ❌ (Node) |
| Cursor | AI IDE | Electron (VS Code fork) | Claude/GPT | ❌ (Electron) |
| GitHub Copilot | IDE 插件 | VS Code/JetBrains | GPT only | ❌ (Plugin) |
| Windsurf | IDE 插件 | VS Code 扩展 | Claude/GPT | ❌ (Plugin) |
| Apple Swift Assist | Xcode 内置 | 原生 | Apple On-device | ✅ 但能力有限 |
| **我们的产品** | **终端 CLI → Mac App** | **Swift 原生** | **多模型** | **✅** |

### 竞争优势分析

```
                    Swift 专精    Mac 原生    多模型支持
Claude Code           ❌           ❌          ❌
Cursor                ❌           ❌          ✅
GitHub Copilot        ❌           ❌          ❌
Apple Swift Assist    ✅           ✅          ❌
我们的产品             ✅           ✅          ✅
```

**蓝海定位：Swift 专精 + Mac 原生 + 多模型 = 无直接竞品。**

---

## 3. Target Users

### Primary: Apple 平台独立开发者 / 小团队

- 以 Swift 为主要语言的全栈 Apple 开发者
- 使用 Xcode 作为主力 IDE
- 对 AI 辅助编码有需求，但不想离开 Mac 原生体验
- 付费意愿高（人均年订阅 $100-200 区间）

### Secondary: 企业 iOS 团队

- 需要 On-premise / 本地模型部署（金融、医疗、军工合规）
- 团队协作、代码审查自动化
- 需要 MCP 集成内部工具链

### User Persona 示例

**张明** — 独立 iOS 开发者，3 个 App 在 App Store
- 痛点：Claude Code 不理解 SwiftUI Preview 报错，Cursor 太重
- 需求：一个轻量的、理解 Apple 平台的 AI 助手
- 付费：$15-20/月

---

## 4. Product Architecture

```
┌──────────────────────────────────────────────────┐
│                  Mac Product                      │
│  ┌────────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Terminal CLI│  │SwiftUI App│  │Xcode Extension│ │
│  └─────┬──────┘  └─────┬────┘  └──────┬───────┘ │
│        └───────────┬────┴──────────────┘         │
│              ┌─────┴──────┐                       │
│              │ Product SDK│                       │
│              │ (Swift tools│                       │
│              │  Multi-model│                       │
│              │  /commands) │                       │
│              └─────┬──────┘                       │
├────────────────────┼─────────────────────────────┤
│              OpenAgentSDK (本 SDK)                 │
│  ┌────────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ LLMClient  │  │ 34 Tools │  │ Agent Loop   │ │
│  │ Protocol   │  │ +MCP+Hooks│ │ +Stream+Session│ │
│  └────────────┘  └──────────┘  └──────────────┘ │
├──────────────────────────────────────────────────┤
│              LLM Providers (云端/本地)             │
│  ┌────────┐ ┌─────┐ ┌───────┐ ┌───────────────┐ │
│  │Anthropic│ │OpenAI│ │Gemini │ │Ollama (本地)  │ │
│  └────────┘ └─────┘ └───────┘ └───────────────┘ │
└──────────────────────────────────────────────────┘
```

### SDK vs Product 边界

| 层级 | 职责 | 举例 |
|------|------|------|
| **OpenAgentSDK** | 通用 Agent 引擎 | Agent Loop, Tools, MCP, Hooks, Session, Permission |
| **Product SDK** | 产品特定逻辑 | 多模型路由, Swift 专属工具, /commands, Xcode 集成 |
| **UI Layer** | 用户交互 | Terminal CLI / SwiftUI App / Xcode Extension |

### LLMClient 架构决策

**方案 B：SDK 定义协议，产品层实现。**

```swift
// SDK 层 (OpenAgentSDK)
public protocol LLMClient: Sendable {
    func sendMessage(...) async throws -> [String: Any]
    func streamMessage(...) async throws -> AsyncThrowingStream<SSEEvent, Error>
}

public actor AnthropicClient: LLMClient { ... }  // SDK 内置

// 产品层 (Product SDK)
class OpenAIClient: LLMClient { ... }
class OllamaClient: LLMClient { ... }
class GeminiClient: LLMClient { ... }

// 多模型路由器
class ModelRouter {
    func client(for task: TaskType) -> LLMClient
    // 思考/规划 → Claude (最强)
    // 代码补全 → GPT (最快)
    // 隐私敏感 → Ollama (本地)
}
```

---

## 5. Product Roadmap

### Phase 0: SDK 完成 (当前)

**目标：** 完成 OpenAgentSDK 全部 9 个 Epic
**时间：** 正在进行中 (Epic 3 完成，Epic 4 进行中)

| Epic | 内容 | 状态 |
|------|------|------|
| Epic 1-2 | Agent 核心 + 流式 + 生产就绪 | ✅ Done |
| Epic 3 | 工具系统 + 10 核心工具 | ✅ Done |
| Epic 4 | 多 Agent 编排 | 🔄 进行中 |
| Epic 5 | 专业工具 + 存储 | 待开发 |
| Epic 6 | MCP 协议 | 待开发 |
| Epic 7 | 会话持久化 | 待开发 |
| Epic 8 | 钩子 + 权限 | 待开发 |
| Epic 9 | 文档 + 示例 | 待开发 |

**SDK 完成时的交付物：** 一个功能完整的 Swift Agent SDK，相当于 TypeScript Claude Code SDK 的全部能力。

---

### Phase 1: Terminal MVP (SDK 完成后 2-3 周)

**目标：** 可用的终端 AI 编码助手，验证核心体验

#### 1.1 基础 CLI (Week 1)

```
$ swift-agent "解释一下这个项目的架构"
$ swift-agent "给 UserService 添加缓存"
$ swift-agent "修复 #42 bug"
```

**功能清单：**
- [ ] CLI 入口 (Swift ArgumentParser)
- [ ] 对话模式 (REPL-style, 连续对话)
- [ ] 项目上下文加载 (CLAUDE.md → .swift-agent.md)
- [ ] 流式输出 (Markdown 渲染 + ANSI 颜色)
- [ ] 工具执行实时显示 (Bash 输出、文件 diff)
- [ ] AskUser 交互 (权限确认、信息收集)

#### 1.2 多模型支持 (Week 1-2)

```bash
# 配置
$ swift-agent config set model claude-sonnet-4-6
$ swift-agent config set model gpt-5
$ swift-agent config set model ollama:llama3

# 使用时切换
$ swift-agent --model gpt-5 "快速补全这个函数"
$ swift-agent --model claude-opus-4-6 "深度分析这个架构"
```

**功能清单：**
- [ ] LLMClient 协议从 SDK 抽取
- [ ] OpenAI 兼容客户端实现
- [ ] Ollama 本地客户端实现
- [ ] 配置文件多模型管理
- [ ] 模型列表/切换命令

#### 1.3 Swift 专属工具 (Week 2-3)

```bash
$ swift-agent /build          # xcodebuild + 错误解析
$ swift-agent /test           # 运行 XCTest 并解析结果
$ swift-agent /review         # Git diff 感知的代码审查
$ swift-agent /refactor       # Swift AST 感知的重构
```

**功能清单：**
- [ ] SPM 项目解析工具 (Package.swift → target map)
- [ ] xcodebuild 封装工具 (build/test/clean)
- [ ] XCTest 结果解析器
- [ ] Swift 代码风格感知 (SwiftLint 集成)
- [ ] /build, /test, /review, /refactor Slash 命令

#### 1.4 发布

- [ ] Homebrew Formula (`brew install swift-agent`)
- [ ] SPM 安装 (`swift package install swift-agent`)
- [ ] GitHub Release (二进制分发)
- [ ] 基础文档网站

**Phase 1 成功指标：**
- 自己日常使用，替代 Claude Code
- 5-10 个早期用户试用
- GitHub Star > 100

---

### Phase 2: Mac Native App (Phase 1 验证后 4-6 周)

**目标：** 从终端工具进化为 Mac 原生应用

#### 2.1 SwiftUI 主界面 (Week 1-2)

```
┌─────────────────────────────────────────────┐
│  SwiftAgent                    [模型选择▾]   │
├──────────┬──────────────────────────────────┤
│ 会话列表  │  对话视图                         │
│          │                                   │
│ > 重构登录│  🤖 我来分析一下这个架构...         │
│   Bug #42│  ```swift                         │
│   新功能  │  func process() async {           │
│          │      let result = await fetch()   │
│          │  }                                │
│          │  ```                              │
│          │                                   │
│          │  🔧 Bash: swift build             │
│          │  ✅ Build Succeeded               │
│          │                                   │
│          │  💬 _____________________________ │
└──────────┴──────────────────────────────────┘
```

**功能清单：**
- [ ] SwiftUI 窗口布局 (侧边栏 + 对话 + 详情)
- [ ] Markdown 渲染组件 (代码高亮)
- [ ] 工具执行面板 (Bash 输出流、文件 diff 视图)
- [ ] Agent 思考过程可视化
- [ ] 深色/浅色主题

#### 2.2 系统集成 (Week 3)

- [ ] Dock 栏状态指示 (Agent 工作中 / 空闲)
- [ ] macOS 通知 (任务完成推送)
- [ ] 菜单栏快捷入口
- [ ] 全局快捷键 (唤起对话)
- [ ] Finder 右键菜单 (对此文件提问)

#### 2.3 Xcode 集成 (Week 3-4)

- [ ] Xcode Source Editor Extension (选中代码 → AI 操作)
- [ ] Xcode Build Phase 集成 (构建失败自动分析)
- [ ] Xcode Debugger 集成 (崩溃日志分析)
- [ ] .xcodeproj / .xcworkspace 感知

#### 2.4 发布

- [ ] Mac App Store 审核 + 上架
- [ ] 网站落地页 (宣传 + 文档)
- [ ] Product Hunt 发布
- [ ] Swift 社区推广 (Swift Forums, Reddit r/swift)

**Phase 2 成功指标：**
- Mac App Store 评分 > 4.5
- 月活用户 > 500
- 付费转化率 > 5%

---

### Phase 3: Platform (长期)

**目标：** 从工具进化为平台

#### 3.1 MCP 生态

- [ ] MCP 工具市场 (社区贡献 Swift 专属工具)
- [ ] 官方 MCP 服务器 (Xcode MCP, Simulator MCP, TestFlight MCP)
- [ ] 企业 MCP Hub (内部工具集成)

#### 3.2 多 Agent 工作流

```
┌─────────────────────────────────────────┐
│            Team Workflow                 │
│                                          │
│  Architect Agent ──→ Design Spec         │
│       ↓                                  │
│  Coder Agent ──→ Implementation          │
│       ↓                                  │
│  Reviewer Agent ──→ Code Review          │
│       ↓                                  │
│  Tester Agent ──→ Test Suite             │
└─────────────────────────────────────────┘
```

- [ ] 预定义 Agent 团队模板
- [ ] 可视化工作流编排
- [ ] Agent 能力市场

#### 3.3 企业版

- [ ] On-premise 部署方案
- [ ] SSO/SAML 集成
- [ ] 审计日志
- [ ] 团队管理后台
- [ ] 私有模型微调支持

---

## 6. Business Model

### 定价策略

| 层级 | 价格 | 内容 |
|------|------|------|
| **Free** | $0 | 本地模型 (Ollama) + 每日限量 API 调用 |
| **Pro** | $15/月 | 无限 API 调用 + 多模型 + 优先支持 |
| **Team** | $12/人/月 | Pro + 团队协作 + 共享会话 |
| **Enterprise** | 定制 | On-premise + SSO + 审计 + 私有模型 |

### 收入模型

```
Phase 1 (Terminal MVP):     开源免费，验证产品
Phase 2 (Mac App):          Freemium 模式，$15/月 Pro
Phase 3 (Platform):         Team/Enterprise 层驱动收入
```

### 成本结构

- LLM API 成本：按用量，用户自行付费或通过我们代充（抽成 15-20%）
- 本地模型：用户自己的硬件，零边际成本
- Mac App Store：$99/年开发者费 + 30% 抽成（可用 DFM 绕过）

---

## 7. Technical Decisions Log

### TD-1: LLM 多模型架构 (2026-04-06)

**决策：** 方案 B — SDK 定义协议，产品层实现
**原因：** 保持 SDK 专注于 Anthropic，产品层自由扩展
**影响：** SDK 需要抽取 `LLMClient` 协议，但不内置非 Anthropic 客户端

### TD-2: 产品形态演进路线 (2026-04-06)

**决策：** Terminal CLI → Mac Native App → Platform
**原因：** 渐进式验证，降低风险。CLI 验证核心体验后再投入 GUI
**影响：** SDK 的 Terminal I/O 能力需要独立于 GUI

### TD-3: Swift 专精策略 (2026-04-06)

**决策：** 第一优先支持 Swift/Apple 平台，不追求通用
**原因：** 差异化壁垒。通用市场已被 Cursor/Copilot 占领
**影响：** 产品层需要 Swift 专属工具集（SPM 解析、xcodebuild、SourceKit-LSP）

---

## 8. Risk Register

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| Anthropic API 定价上涨 | 中 | 高 | 多模型支持，用户可切换 |
| Cursor 推出 Mac 原生版 | 低 | 高 | Swift 专精壁垒，更深的 Xcode 集成 |
| Apple 增强内置 Swift Assist | 高 | 中 | 走多模型+第三方路线，不与 Apple 正面竞争 |
| 本地模型质量不足 | 中 | 低 | 默认使用云端模型，本地作为可选 |
| Mac App Store 审核问题 | 中 | 低 | 同时提供 Homebrew 分发 |

---

## 9. Success Metrics

### Phase 1 (Terminal MVP)
- [ ] 自己用 Swift Agent 完成 1 个完整功能开发
- [ ] 5+ 早期用户反馈
- [ ] GitHub Star > 100
- [ ] 日活对话 > 50

### Phase 2 (Mac App)
- [ ] Mac App Store 评分 > 4.5
- [ ] 月活 > 500
- [ ] 付费用户 > 25
- [ ] MRR > $500

### Phase 3 (Platform)
- [ ] 月活 > 5,000
- [ ] 付费用户 > 250
- [ ] MRR > $5,000
- [ ] 3+ 企业客户

---

## 10. Next Steps

1. **当前：** 完成 OpenAgentSDK Epic 4-9
2. **SDK 完成后：** 抽取 LLMClient 协议 → 开始 Phase 1 Terminal MVP
3. **并行：** 在 SDK 开发中积累 Agent 使用经验，优化产品体验
