# Story 12.3: Git 状态注入

Status: done

## Story

作为开发者，
我希望 Agent 自动感知当前 Git 仓库状态，
以便 LLM 在执行任务时具备代码库上下文感知。

## Acceptance Criteria

1. **AC1: Git 上下文注入到系统提示** -- 给定 Agent 在 Git 仓库中执行，当查询开始（`agent.stream("帮我提交代码")`），则发送给 LLM 的系统提示包含格式化文本块：
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

2. **AC2: 非 Git 仓库时无报错** -- 给定 Agent 不在 Git 仓库中（`git rev-parse --git-dir` 返回非零退出码），当查询开始，则系统提示不包含 `<git-context>` 块，且查询正常执行，不报错。

3. **AC3: Git 状态截断** -- 给定 `git status --short` 输出超过 2000 字符，当注入 Git 状态，则截断到 2000 字符并附加 `...（输出已截断，共 N 个文件变更）`。

4. **AC4: Git 状态缓存 TTL** -- 给定连续两次查询（间隔小于 `SDKConfiguration.gitCacheTTL`，默认 5 秒），当第二次查询开始，则使用缓存的 Git 状态（`Process` 不被调用第二次）。如果距离上次缓存超过 TTL，重新执行 git 命令刷新缓存。开发者可设置 `config.gitCacheTTL = 0` 禁用缓存（每次查询都刷新）。

## Tasks / Subtasks

- [x] Task 1: 创建 GitContextCollector 工具类 (AC: #1, #2, #3, #4)
  - [x] 在 `Sources/OpenAgentSDK/Utils/` 下创建 `GitContextCollector.swift`
  - [x] 实现 `public final class GitContextCollector: @unchecked Sendable`（使用 NSLock 保护缓存状态，与 FileCache 模式一致）
  - [x] 实现私有方法 `private func runGitCommand(_ command: String, cwd: String, timeoutMs: Int = 5000) -> String?` -- 通过 `Process` 执行 git 命令，返回 trimmed output，失败返回 nil
  - [x] 实现私有方法 `private func detectMainBranch(cwd: String) -> String?` -- 运行 `git branch -l main master`，优先返回 "main"
  - [x] 实现核心方法 `public func collectGitContext(cwd: String, ttl: TimeInterval) -> String?` -- 检查缓存 TTL，未过期则返回缓存；过期则重新收集并更新缓存
  - [x] `collectGitContext` 内部流程：(1) `git rev-parse --git-dir` 验证仓库 (2) `git rev-parse --abbrev-ref HEAD` 获取分支 (3) `detectMainBranch()` (4) `git config user.name` (5) `git status --short`（超过 2000 字符截断） (6) `git rev-parse HEAD` + `git log --oneline -5 --no-decorate` 获取最近提交 (7) 拼接为 `<git-context>...</git-context>` 格式
  - [x] 缓存状态：`private var cachedContext: String?`，`private var cachedCwd: String?`，`private var cacheTimestamp: Date = .distantPast`，受 `lock` 保护

- [x] Task 2: 添加 SDKConfiguration 和 AgentOptions 配置参数 (AC: #4)
  - [x] 在 `SDKConfiguration` 添加 `public var gitCacheTTL: TimeInterval`（默认 5.0 秒）
  - [x] 在 `SDKConfiguration.init()` 添加 `gitCacheTTL` 参数（默认 5.0）
  - [x] 更新 `SDKConfiguration.resolved()` 传递 `gitCacheTTL`
  - [x] 更新 `SDKConfiguration.description` 和 `debugDescription` 包含新字段
  - [x] 在 `AgentOptions` 添加 `public var gitCacheTTL: TimeInterval`（默认 5.0 秒）
  - [x] 在 `AgentOptions.init()` 添加 `gitCacheTTL` 参数（默认 5.0）
  - [x] 更新 `AgentOptions.init(from:)` 从 `SDKConfiguration` 读取 `gitCacheTTL`

- [x] Task 3: 修改 Agent.buildSystemPrompt() 集成 Git 上下文 (AC: #1, #2)
  - [x] 在 `Agent` 类中添加 `private let gitContextCollector = GitContextCollector()` 实例属性（per-agent 缓存，生命周期与 Agent 实例相同）
  - [x] 修改 `buildSystemPrompt()` 方法：调用 `gitContextCollector.collectGitContext(cwd:ttl:)` 获取 Git 上下文
  - [x] 如果 `systemPrompt` 存在且 Git 上下文存在，将 `<git-context>` 块追加到 systemPrompt 末尾（用换行分隔）
  - [x] 如果 `systemPrompt` 为 nil 但 Git 上下文存在，直接返回 Git 上下文作为系统提示
  - [x] 如果 Git 上下文为 nil（非 Git 仓库），返回原始 systemPrompt 不变
  - [x] 在 `stream()` 方法中确保 `capturedSystemPrompt` 使用更新后的 `buildSystemPrompt()`（当前第 502 行已使用 `buildSystemPrompt()`，只需确保 Git 上下文被包含）

- [x] Task 4: 编写单元测试 (AC: #1, #2, #3, #4)
  - [x] 在 `Tests/OpenAgentSDKTests/Utils/` 下创建 `GitContextCollectorTests.swift`
  - [x] 测试 AC1：在 Git 仓库中调用 collectGitContext，验证返回包含 `<git-context>` 块、Branch、Main branch、Git user、Status、Recent commits
  - [x] 测试 AC2：在临时非 Git 目录中调用 collectGitContext，验证返回 nil
  - [x] 测试 AC3：创建大量文件变更使 status 输出超过 2000 字符，验证截断和附加消息
  - [x] 测试 AC4：连续两次调用 collectGitContext（间隔 < TTL），验证第二次不调用 Process（可通过检查耗时验证）；等待 TTL 过期后再调用，验证重新收集
  - [x] 测试 `gitCacheTTL = 0` 时每次调用都重新收集
  - [x] 测试 `buildSystemPrompt()` 在有/无 systemPrompt 情况下的拼接逻辑

- [x] Task 5: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- **Epic 12**（文件缓存与上下文注入）的第三个 Story
- **核心目标：** 实现自动 Git 状态注入到系统提示，让 LLM 在执行任务时具备代码库上下文感知（当前分支、变更状态、最近提交等）
- **前置依赖：** Epic 1-11 已完成（基础设施、工具系统、技能系统等均已就绪）
- **前置依赖：** Story 12.1（FileCache LRU 缓存）、Story 12.2（缓存集成）已完成 -- 本 Story 不直接依赖它们，但同属 Epic 12
- **后续 Story：** Story 12.4（项目文档发现 CLAUDE.md/AGENT.md）
- **FR 覆盖：** FR57（Agent 自动注入 Git 状态到系统提示）

### 关键设计决策

**GitContextCollector 作为独立类（非 Context.swift 模块）：**
- 架构文档预期 `Utils/Context.swift` 用于"系统/用户上下文提取（git、项目文件）"
- 但 TypeScript SDK 的 `context.ts` 包含 Git 状态 + 项目文档发现两个职责
- Swift 实现将这两个职责拆分为独立的工具类（GitContextCollector 和 Story 12.4 的 ProjectDocumentDiscovery），每个类职责单一
- 可选：创建 `Utils/Context.swift` 作为统一入口调用 GitContextCollector 和 ProjectDocumentDiscovery，但 Story 12.3 先只实现 GitContextCollector

**GitContextCollector 线程安全设计：**
- 使用 `final class` + `@unchecked Sendable` + `NSLock` 模式（与 FileCache 一致）
- 缓存状态（cachedContext、cachedCwd、cacheTimestamp）受 lock 保护
- `runGitCommand()` 内部同步执行 Process（阻塞调用线程），外部调用者需注意不要在主线程调用
- TTL 缓存检查在 lock 内完成，避免竞态条件

**Git 命令执行策略：**
- 使用 `Process`（Foundation）执行 git 命令，设置 timeout（默认 5 秒）
- 所有命令通过 `git -C <cwd>` 或 `Process.currentDirectoryURL` 在指定 cwd 执行
- 每个命令独立 try/catch，单个命令失败不阻止其他命令执行
- `git rev-parse --git-dir` 作为仓库验证的第一步，失败立即返回 nil（非 Git 仓库）
- `git log` 仅在 `git rev-parse HEAD` 成功后执行（新仓库可能没有提交）

**系统提示注入位置：**
- Git 上下文通过 `<git-context>...</git-context>` XML 标签包裹
- 注入到系统提示末尾（不是用户消息），确保 LLM 在所有轮次都能看到
- 当前 `Agent.buildSystemPrompt()` 直接返回 `options.systemPrompt`，需要修改为追加 Git 上下文
- `stream()` 方法在 `capturedSystemPrompt = buildSystemPrompt()` 处调用，因此只需修改 `buildSystemPrompt()` 即可同时影响 prompt() 和 stream()

**缓存策略：**
- 缓存 key 为 cwd（工作目录），不同 cwd 使用不同缓存
- TTL 默认 5 秒，基于以下考量：Agent 在单次查询中可能多次调用 buildSystemPrompt()（max_tokens 恢复时），但 Git 状态在查询间通常不变
- 缓存在 Agent 实例级别，Agent 释放时缓存自动释放
- `gitCacheTTL = 0` 禁用缓存，每次调用都重新执行 git 命令

### TypeScript SDK 参考映射

| Swift 功能 | TypeScript 对应 | 文件 |
|---|---|---|
| `GitContextCollector` | `getGitStatus()` + `getSystemContext()` | `src/utils/context.ts` |
| `runGitCommand()` | `gitExec()` 内部闭包 | `src/utils/context.ts:31` |
| `detectMainBranch()` | `detectMainBranch()` | `src/utils/context.ts:84` |
| `<git-context>` 格式化 | `parts.join('\n\n')` + `gitStatus:` 前缀 | `src/utils/context.ts:156` |
| 缓存 TTL | `cachedGitStatus` + `cachedGitStatusCwd`（无 TTL，永久缓存直到 clearContextCache()） | `src/utils/context.ts:17-18` |
| `collectGitContext()` | `getGitStatus()` | `src/utils/context.ts:23` |

**关键差异：**
- TS SDK 使用永久缓存（`clearContextCache()` 手动清除），Swift 版本增加 TTL 机制（更智能的缓存刷新）
- TS SDK 的 `getSystemContext()` 包含 gitStatus + 未来可能的更多上下文，Swift 版本先用 `<git-context>` 标签包裹（与 epics.md 规范一致）
- TS SDK 的 `getUserContext()` 包含日期和项目文档（Story 12.4），本 Story 只处理 Git 状态
- TS SDK 使用 `execSync`（同步），Swift 使用 `Process`（同步但通过 Foundation API）

### 已有代码分析

**Agent.swift（需修改）：**
- `buildSystemPrompt()`（第 164-166 行）：当前直接返回 `options.systemPrompt`，需要追加 Git 上下文
- `prompt()`（第 191 行起）：第 258 行 `let retrySystemPrompt = self.buildSystemPrompt()` -- 修改 buildSystemPrompt 即可
- `stream()`（第 494 行起）：第 502 行 `let capturedSystemPrompt = buildSystemPrompt()` -- 修改 buildSystemPrompt 即可
- 需要添加 `gitContextCollector` 实例属性
- 需要从 `options` 读取 `gitCacheTTL`
- **注意：** `stream()` 中 `capturedSystemPrompt` 在闭包外捕获，Git 上下文在查询开始时生成一次，不会在查询中刷新（这是正确行为）

**SDKConfiguration.swift（需修改）：**
- 添加 `gitCacheTTL: TimeInterval` 字段
- 更新 init、resolved()、description/debugDescription
- 默认值 5.0 秒

**AgentTypes.swift（需修改）：**
- AgentOptions 添加 `gitCacheTTL: TimeInterval` 字段
- 更新 init、init(from:)
- 默认值 5.0 秒

**Utils/ 目录（当前文件）：**
```
Sources/OpenAgentSDK/Utils/
├── Compact.swift
├── EnvUtils.swift
├── FileCache.swift
├── Retry.swift
└── Tokens.swift
```
- 新增 `GitContextCollector.swift`

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Utils/GitContextCollector.swift` -- **新建**：Git 状态收集与缓存
- `Sources/OpenAgentSDK/Types/SDKConfiguration.swift` -- **修改**：添加 gitCacheTTL 字段
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- **修改**：AgentOptions 添加 gitCacheTTL 字段
- `Sources/OpenAgentSDK/Core/Agent.swift` -- **修改**：buildSystemPrompt() 集成 Git 上下文
- `Tests/OpenAgentSDKTests/Utils/GitContextCollectorTests.swift` -- **新建**：Git 上下文收集测试

```
Sources/OpenAgentSDK/
├── Utils/
│   ├── GitContextCollector.swift     # 新建：Git 状态收集、格式化、缓存
│   ├── FileCache.swift              # 不修改（同层工具类参考）
│   └── ...
├── Types/
│   ├── SDKConfiguration.swift       # 修改：+ gitCacheTTL 字段
│   ├── AgentTypes.swift             # 修改：AgentOptions + gitCacheTTL 字段
│   └── ...
├── Core/
│   ├── Agent.swift                  # 修改：buildSystemPrompt() + Git 上下文注入
│   └── ...
└── ...

Tests/OpenAgentSDKTests/
├── Utils/
│   ├── GitContextCollectorTests.swift  # 新建：Git 上下文收集器测试
│   └── ...
└── ...
```

### Logger 集成约定

为 Epic 14 Logger 预留调用点：
- **预留位置：**
  - Git 仓库检测：`Logger.shared.debug("GitContextCollector: detected git repo", data: ["cwd": cwd])`
  - 非 Git 仓库：`Logger.shared.debug("GitContextCollector: not a git repo", data: ["cwd": cwd])`
  - 缓存命中：`Logger.shared.debug("GitContextCollector: cache hit", data: ["age": elapsed, "ttl": ttl])`
  - 缓存过期：`Logger.shared.debug("GitContextCollector: cache expired, refreshing", data: ["age": elapsed])`
  - 注入系统提示：`Logger.shared.info("Git context injected into system prompt", data: ["length": context.count])`
- **预实现方案：** `Logger.shared` 当前为空实现（no-op），不引入编译错误

### 反模式警告

- **不要**将 `GitContextCollector` 设计为 `actor` -- 它不需要跨 Agent 共享，per-agent 实例使用 `NSLock` 即可（与 FileCache 模式一致）
- **不要**在 `Utils/` 中导入 `Core/` -- 违反模块边界（Utils 是叶节点）
- **不要**将 Git 上下文注入到用户消息中 -- 必须注入到系统提示（LLM 在所有轮次都能看到）
- **不要**在每次 API 调用时都执行 git 命令 -- 使用 TTL 缓存避免性能问题
- **不要**在 `Process` 执行中使用无限超时 -- 默认 5 秒超时防止 git 命令挂起
- **不要**让 `runGitCommand()` 在失败时抛出错误 -- 返回 nil 让调用者优雅处理（与 TS SDK 模式一致）
- **不要**忘记在 `stream()` 的 `capturedSystemPrompt` 中包含 Git 上下文 -- 它在闭包外通过 `buildSystemPrompt()` 捕获，确保 `buildSystemPrompt()` 正确集成即可
- **不要**使用 POSIX `realpath` 进行路径标准化 -- 使用 `FileManager` 和 `URL.resolvingSymlinksInPath()`（跨平台约定）
- **不要**在 `buildSystemPrompt()` 中使用 async/await -- 当前方法是同步的，`GitContextCollector` 的 `collectGitContext()` 也应设计为同步方法（Process 同步执行）
- **不要**将 `git status` 的完整输出直接注入 -- 必须检查并截断超过 2000 字符的输出

### 测试策略

**AC1 测试（Git 上下文注入）：**
- 使用 `FileManager.default.createTemporaryDirectory()` 创建临时目录
- 在临时目录中 `git init` + 创建文件 + `git add` + `git commit`
- 修改一个文件使其出现在 `git status` 中
- 调用 `collectGitContext(cwd: tempDir, ttl: 5)`
- 验证返回字符串包含 `<git-context>`、`Branch:`、`Main branch:`、`Git user:`、`Status:`、`Recent commits:`

**AC2 测试（非 Git 仓库）：**
- 使用临时非 Git 目录
- 调用 `collectGitContext(cwd: tempDir, ttl: 5)`
- 验证返回 nil

**AC3 测试（截断）：**
- 在 Git 仓库中创建大量文件（>100 个），使 `git status --short` 输出超过 2000 字符
- 调用 `collectGitContext`
- 验证 Status 部分截断到 2000 字符并包含截断消息

**AC4 测试（TTL 缓存）：**
- 创建 Git 仓库，调用 `collectGitContext`
- 立即再次调用（间隔 < TTL），验证返回相同结果且耗时接近 0（缓存命中）
- 等待 TTL 过期后再次调用，验证重新收集（耗时较长）

**buildSystemPrompt 测试：**
- 创建 Agent（有/无 systemPrompt）
- 验证 buildSystemPrompt() 在 Git 仓库中返回包含 `<git-context>` 的字符串
- 验证 buildSystemPrompt() 在非 Git 目录中返回原始 systemPrompt

### 前序 Story 学习要点

**Story 12.2 完成情况：**
- 完整测试套件：2361 tests passing, 4 skipped, 0 failures
- Code Review 修复：(1) fileCache 未传递到 compactConversation 的 Agent.swift 调用点，已修复
- Code Review 发现：modifiedPaths 在 FileCache 中无限增长，已记录为 deferred
- **关键教训：** Agent.swift 中新增参数时，必须同时更新 `prompt()` 和 `stream()` 两个方法的所有调用点

**Story 12.1 完成情况：**
- FileCache 使用 `final class` + `@unchecked Sendable` + `NSLock` 模式
- FileCache per-query 创建（在 prompt/stream 方法体内）
- SDKConfiguration 和 AgentOptions 都需要添加新字段

**关键代码模式：**
- Agent.swift 的 `buildSystemPrompt()` 在 `prompt()` 和 `stream()` 中都被调用
- `stream()` 方法使用 captured 变量模式（第 496-534 行），在闭包外捕获值
- 新增配置字段需要同时更新 `SDKConfiguration.init()`、`SDKConfiguration.resolved()`、`AgentOptions.init()`、`AgentOptions.init(from:)`
- 测试文件命名约定：`Tests/OpenAgentSDKTests/Utils/` 下按工具类命名

### Project Structure Notes

- GitContextCollector.swift 放在 `Sources/OpenAgentSDK/Utils/` 目录下（叶节点模块，无出站依赖）
- Utils/ 目录现有 5 个文件（Compact、EnvUtils、FileCache、Retry、Tokens），本 Story 新增 1 个
- 测试文件放在 `Tests/OpenAgentSDKTests/Utils/` 目录下
- 不需要修改 `Tools/`、`Stores/`、`Hooks/` 目录

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 12.3] -- 验收标准（4 个 AC：Git 上下文注入、非 Git 无报错、截断、TTL 缓存）
- [Source: _bmad-output/planning-artifacts/epics.md#FR57] -- Git 状态注入功能需求
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 12 文件缓存与上下文注入] -- Epic 级别上下文
- [Source: _bmad-output/implementation-artifacts/12-2-cache-tool-and-compaction-integration.md] -- 前序 Story 完成记录
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L164] -- 当前 buildSystemPrompt() 实现
- [Source: Sources/OpenAgentSDK/Types/SDKConfiguration.swift] -- 当前 SDKConfiguration 定义
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- 当前 AgentOptions 定义
- [Source: Sources/OpenAgentSDK/Utils/FileCache.swift] -- 线程安全 final class + NSLock 参考模式
- [Source: open-agent-sdk-typescript/src/utils/context.ts] -- TypeScript SDK Git 状态收集参考
- [Source: _bmad-output/planning-artifacts/architecture.md#AD9] -- 基于结构体的配置决策
- [Source: _bmad-output/project-context.md] -- 项目级 AI 代理规则

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No blockers encountered during implementation.

### Completion Notes List

- Implemented GitContextCollector as `final class` + `@unchecked Sendable` + `NSLock` pattern (consistent with FileCache)
- Git context collected via 6 Process-executed commands: rev-parse --git-dir, rev-parse --abbrev-ref HEAD, branch -l main/master, config user.name, status --short, log --oneline -5
- Status output truncated at 2000 chars with file count message when exceeded
- Cache uses normalized cwd as key with configurable TTL (default 5.0 seconds)
- Agent.buildSystemPrompt() now appends `<git-context>` block to system prompt (or uses as standalone when no system prompt set)
- Fixed 3 existing tests in AgentLoopTests.swift that needed cwd isolation from Git context: testSystemPromptIncludedInAPIRequest, testNoSystemPromptExcludesSystemFromRequest, testDurationIsMeasuredInMilliseconds
- All 16 ATDD tests pass (TDD GREEN phase complete)
- Full test suite: 2377 tests passing, 4 skipped, 0 failures

## Change Log

- 2026-04-12: Story implementation complete -- GitContextCollector class with TTL caching, SDKConfiguration/AgentOptions gitCacheTTL field, Agent.buildSystemPrompt() integration, 16 ATDD tests passing, 2377 total tests passing with 0 regressions

- Sources/OpenAgentSDK/Utils/GitContextCollector.swift -- NEW: Git status collection, formatting, and TTL caching
- Sources/OpenAgentSDK/Types/SDKConfiguration.swift -- MODIFIED: Added gitCacheTTL field (default 5.0)
- Sources/OpenAgentSDK/Types/AgentTypes.swift -- MODIFIED: Added gitCacheTTL field to AgentOptions (default 5.0)
- Sources/OpenAgentSDK/Core/Agent.swift -- MODIFIED: Added gitContextCollector instance, updated buildSystemPrompt() to inject Git context
- Tests/OpenAgentSDKTests/Utils/GitContextCollectorTests.swift -- Existing ATDD tests (16 tests, all passing)
- Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift -- MODIFIED: Updated 3 tests to isolate from Git context with non-Git temp directories
