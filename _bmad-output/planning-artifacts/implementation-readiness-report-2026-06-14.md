---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-architecture-validation
  - step-04-epic-stories-review
  - step-05-cross-document-alignment
assessmentScope: Epic 29 — Claude Code Skill/Subagent Compatibility
documentsIncluded:
  prd:
    - _bmad-output/planning-artifacts/prd.md
  architecture:
    - _bmad-output/planning-artifacts/architecture.md
  epic:
    - docs/epics/epic-29-claude-code-skill-subagent-compat.md
  ux: []
  supporting:
    - _bmad-output/project-context.md
    - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift.md
excluded:
  - _bmad-output/planning-artifacts/prd-photo-agent.md  # 不同产品范围
  - _bmad-output/planning-artifacts/epics.md  # 合并历史；对 Epic 29 已被 docs/epics/epic-29-*.md 取代
verdict: READY_WITH_ACTIONS
---

# 实施就绪评估报告

**日期：** 2026-06-14
**项目：** open-agent-sdk-swift
**范围：** Epic 29 — Claude Code Skill/Subagent Compatibility
**结论：** ✅ **已就绪可实施 — 启动前需完成 4 项动作**

---

## 执行摘要

Epic 29 **结构完整、架构合理**。7 个 story 覆盖了全部 6 个既定目标，依赖关系线性且顺序清晰，epic 中所有"当前代码事实"声明都对照当前源码逐一核实为准确。启动前需要注意两个跨文档问题，但都不阻塞实施：

1. **术语冲突（低风险）**：PRD FR17 列举了 `TaskCreate/List/Update/Get/Stop/Output`（任务管理工具，由 `TaskStore` 支撑）。Epic 29 引入了一个**不同**的 `Task` 工具（Claude Code 子代理启动器，是 `Agent` 的 alias）。Story 29.1 已经规定使用 `SubAgentLauncherInput`（而非 `TaskToolInput`）作为 Swift 类型名来缓解冲突。工具名字符串 `"Task"` 与 `"TaskCreate"` 等互不冲突，因此运行时无碰撞 —— 但 PRD 应当加注。

2. **Story 29.6 deferred 字段与 Epic 17 记忆重叠**：Epic 29 计划为 `run_in_background`、`resume`、`isolation`、`team_name`、`skills` 生成诊断信息，这些字段在 `DefaultSubAgentSpawner.swift:121-122` 已确认为"已声明但运行时尚未接线"。它们**不是** Epic 17 deferred 的字段（continueRecentSession/forkSession/resumeSessionAt/toolConfig/promptSuggestions）—— 而是另外的 `AgentToolInput` 字段。无冲突，但需要意识到 Story 29.6 将为来自多个 epic 的当前未接线字段生成诊断。

---

## Step 1：文档发现 — ✅ 完成

### 评估使用的文档

| 类型 | 文件 | 状态 |
|---|---|---|
| PRD | `_bmad-output/planning-artifacts/prd.md` | 选中（主 SDK 范围，2026-04-03） |
| 架构 | `_bmad-output/planning-artifacts/architecture.md` | 选中（2026-06-09） |
| Epic | `docs/epics/epic-29-claude-code-skill-subagent-compat.md` | 选中（焦点，2026-06-14） |
| UX | — | N/A（SDK 项目） |
| 辅助 | `project-context.md`（56 条规则）、`product-brief-*.md` | 参考 |

### 排除（范围外）
- `prd-photo-agent.md` — 不同产品（Photo Agent）
- `epics.md` 合并版 — 对 Epic 29 已被 `docs/epics/epic-29-*.md` 取代
- 历史就绪报告（2026-04-03、2026-04-14）— 历史归档

---

## Step 2：PRD 分析 — ✅ 完成

### 与 Epic 29 相关的功能需求

Epic 29 跨多个 FR 领域，直接可追溯：

| FR | 描述 | Epic 29 Story 覆盖 |
|---|---|---|
| FR11 | 注册单个工具或工具层级 | 29.1（`createTaskTool()` 公开导出） |
| FR13 | `defineTool()` 自定义工具 | 29.1（共享 factory 模式） |
| FR17 | Advanced 工具：Agent、SendMessage、TaskCreate/List/... | 29.1（向 Advanced 层添加 `Task` alias）⚠️ 见冲突说明 |
| FR22 | MCP 工具执行期间可用 | 29.4（保留 `mcp__server__tool` 命名） |
| FR34 | 权限系统控制工具执行 | 29.5（共享过滤 helper） |
| FR35 | 通过 Agent 工具生成子代理 | 29.1、29.2（`Task` alias + spawner 检测） |

### 与 Epic 29 相关的非功能需求

| NFR | 描述 | Epic 29 覆盖 |
|---|---|---|
| NFR8 | 权限系统执行工具访问 | 29.4、29.5（无静默 unrestricted 回退） |
| NFR11 | 全部 34 工具在 macOS/Linux 上行为一致 | 29.7（跨平台测试） |
| NFR12 | 无 Apple 专属框架 | 关键设计约束已记录 |
| NFR17 | 工具执行失败被捕获而非传播 | 29.6（诊断而非 throws） |
| NFR22 | Core API v1.0 冻结 | 29.1 保留 `createAgentTool()` |
| NFR23 | Hooks/MCP API 标记为演进中 | 29.4 引入更丰富的 ToolDeclaration — 需要分类决策 |

### Epic 29 遵守的其他 PRD 约束
- `defineTool()` + Codable 输入（FR14）— Story 29.1 显式复用 `AgentToolInput`
- 向后兼容（PRD Phase 2 策略）— Story 29.4 强制要求为 `Skill.toolRestrictions` 提供迁移路径
- 诊断优于静默失败（NFR17 精神）— Story 29.4、29.6 对解析失败和 deferred 字段强制此行为

### PRD 对 Epic 29 范围的完整性评估
**状态：✅ 充分。** PRD 没有显式提及 Claude Code `Task()` 兼容性（它早于 Epic 29 约 2 个月），但 FR11/FR17/FR22/FR34/FR35 提供了充分的功能锚点。**建议：** 添加 FR 或修订条目，将 Claude Code workflow skill 兼容性记录为横切关注点（见下文 Action）。

---

## Step 3：架构验证 — ✅ 完成

### Epic 29 对架构决策（AD1–AD11）的符合性

| AD | 决策 | Epic 29 符合性 |
|---|---|---|
| AD1 | Actor 用于共享可变状态 | ✅ 无需新 actor；修改 `DefaultSubAgentSpawner`（final class，@unchecked Sendable） |
| AD4 | 基于协议的 Codable 工具输入 | ✅ 通过共享 factory 复用 `AgentToolInput`；新类型命名为 `SubAgentLauncherInput`（避免与 Swift `Task` 冲突） |
| AD7 | Hook event 枚举，21 个生命周期事件 | N/A — Epic 29 添加诊断而非 hook event |
| AD8 | 权限模型：枚举 + 回调拦截器 | ✅ Story 29.5 通过共享过滤 helper 复用此模式 |
| AD10 | 带关联值的类型化错误 | ✅ Story 29.4/29.6 的诊断以结构化输出形式呈现，而非 throws |

### 模块边界合规性

Epic 29 显式遵守 **Tools/ 永不 import Core/** 规则：
- `AgentTool.swift`（Tools/Advanced/）通过 `ToolContext.agentSpawner`（Types/ 协议）间接使用
- `DefaultSubAgentSpawner`（Core/）注入具体实现
- Story 29.5 的共享过滤 helper 需要确定归属 —— 候选：`Tools/ToolRegistry.swift` 或新建 `Tools/ToolDeclarationFilter.swift`

**⚠️ 架构待决项：** Story 29.5 引入可复用过滤 helper 但未指定模块位置。`Tools/` 不能 import `Core/`，但该 helper 需要同时服务于 `DefaultSubAgentSpawner.filterTools(...)`（Core/）和 `ToolRestrictionStack`（skill 执行路径）。Helper 应放在 `Types/` 或 `Tools/ToolRegistry.swift`，按现有模块方向规则供两层消费。

### 文件到 FR 的映射覆盖

架构 §"需求到结构映射"将 FR35 → `Tools/Advanced/AgentTool.swift`。Epic 29 修改的正是此文件（29.1），以及 `Core/DefaultSubAgentSpawner.swift`（29.2）、`Core/Agent.swift`（29.3、29.2）、`Types/SkillTypes.swift` + `Skills/SkillLoader.swift`（29.4）。**所有目标文件都存在于已记录的结构中。**

### 代码事实验证

Epic 29 中的 7 项"当前代码事实"声明全部对照当前源码验证：

| Epic 声明 | 验证位置 | 状态 |
|---|---|---|
| 只有 `createAgentTool()`，没有 `Task` alias | grep `createTaskTool\|name: "Task"` 返回 0 命中 | ✅ |
| `createSubAgentSpawner` 只检查 `Agent` | `Agent.swift:3232`：`tools.contains { $0.name == "Agent" }` | ✅ |
| `DefaultSubAgentSpawner.filterTools` 只移除 `Agent` | `DefaultSubAgentSpawner.swift:132`：`$0.name != "Agent"` | ✅ |
| `resolveSkillForExecution` 只拼接 prompt + args | `Agent.swift:3212-3217` | ✅ |
| `Skill.baseDir` 和 `supportingFiles` 存在 | `SkillTypes.swift:96, 103` | ✅ |
| `parseAllowedTools` 返回 `[ToolRestriction]?` | `SkillLoader.swift:326` | ✅ |
| `ToolRestriction` 使用小写 raw value | `SkillTypes.swift:12-35`（20 个 case：bash、read、write、...） | ✅ |
| Deferred 字段存在但未接线 | `DefaultSubAgentSpawner.swift:121-122` 注释 | ✅ |

**结论：Epic 29 对代码库的分析 100% 准确。**

---

## Step 4：Epic 与 Story 评审 — ✅ 完成

### Story 清单

| # | Story | 优先级 | 依赖于 | AC 数 |
|---|---|---|---|---|
| 29.1 | `Agent` / `Task` 共享子代理启动器 | P0 | — | 4 |
| 29.2 | Spawner 检测 + 子代理过滤 | P0 | 29.1 | 4 |
| 29.3 | Direct skill package context | P0 | 29.1 | 4 |
| 29.4 | 工具声明兼容模型 | P1 | 29.1 | 6 |
| 29.5 | Skill 与 subagent 共享过滤 | P1 | 29.4 | 6 |
| 29.6 | Deferred subagent 字段诊断 | P1 | 29.5 | 4 |
| 29.7 | 测试与文档 | P0 | 29.1–29.6 | 4 |

**总计：7 个 story，32 条验收标准，0 项未知。**

### Story 完整性检查

✅ **全部 story 都有：** As-a / I-want / So-that 框架、编号实施步骤、Given/When/Then 验收标准。

✅ **依赖图无环**，且与文档中描述的倾斜一致（29.1 → 29.2/29.3/29.4 → 29.5 → 29.6 → 29.7）。

✅ **Story 29.7（测试/文档）** 零歧义：指定了具体测试文件（`AgentToolTests.swift`、`DefaultSubAgentSpawnerTests`、`ExecuteSkillStreamTests`），并引用了项目规则中关于 E2E 测试使用真实环境的规则。

### 验收标准质量

全部 32 条 AC 使用 **Given/When/Then** 格式。抽样示例：

- **29.1 AC1**：Given 注册了 Task 工具 / When LLM 调用 `Task(prompt:, description:)` / Then 调用路径与 `Agent` 一致 / And 返回 child agent 文本 + tool summary ✅ 可测试
- **29.4 AC2**：Given `allowed-tools: UnknownTool` / When 加载 skill / Then 暴露诊断 / And 不被当作 unrestricted ✅ 可测试
- **29.6 AC1**：Given `run_in_background: true` / When 运行时执行 foreground / Then 显示 background 模式诊断 ✅ 可测试

**未发现歧义或不可测试的 AC。**

### 反模式检查（依据 project-context.md 规则）

| 规则 | Epic 29 符合性 |
|---|---|
| #15：禁止类型名 `Task`（Swift Concurrency 冲突） | ✅ 显式处理：使用 `SubAgentLauncherInput`，工具名字符串 `"Task"` 可以 |
| Tools/ 永不 import Core/ | ✅ 通过 `ToolContext.agentSpawner` 间接保持 |
| #4：永不从工具 handler 抛出 | ✅ Story 29.6 在 `SubAgentResult` 中暴露 deferred 字段诊断，而非 throws |
| #29：story 后补充 E2E 测试 | ✅ Story 29.7 强制要求；E2E 可选但按真实环境规则允许 |
| #51：使用 `makeTestToolContext()` helper | ⚠️ Story 29.7 暗示但未显式命名 — Story 29.7 命名了测试文件，未命名 helper |

### Deferred 范围（非目标）文档化

Epic 29 在 §延后项 中显式 deferred 了 6 项 —— **优秀的实践**。这些应当作为后续候选 epic 跟踪：

1. 文件系统 subagent loader（`.claude/agents/*.md`、`.agents/agents/*.md`）
2. 从 parent config 完整查找 MCP server reference
3. `skills` 字段完整 child registry 接线
4. background/resume/isolation/team 运行时语义
5. 细粒度 Bash 权限 pattern 执行
6. 宿主级权限 UI / 审批 workflow

---

## Step 5：跨文档对齐 — ✅ 完成

### PRD ↔ 架构 ↔ Epic 29 可追溯性矩阵

| 需求来源 | Epic 29 Story | 代码模块 | 测试文件 |
|---|---|---|---|
| FR11（注册工具） | 29.1 | `Tools/Advanced/AgentTool.swift`、`OpenAgentSDK.swift` | `AgentToolTests.swift` |
| FR17（Advanced 工具） | 29.1 | `Tools/Advanced/AgentTool.swift` | `AgentToolTests.swift` |
| FR22（MCP 工具） | 29.4 | `Types/SkillTypes.swift`、`Skills/SkillLoader.swift` | parser tests |
| FR34（权限） | 29.5 | 新的共享 filter helper | filtering tests |
| FR35（子代理） | 29.1、29.2 | `Core/Agent.swift`、`Core/DefaultSubAgentSpawner.swift` | `DefaultSubAgentSpawnerTests` |
| NFR8（权限执行） | 29.4、29.5 | filter helper、diagnostics | （多个） |
| NFR22（API 稳定性） | 29.1 | 保留 `createAgentTool()` | 向后兼容测试 |
| project-context 规则 #15（无 `Task` 类型） | 29.1 | `SubAgentLauncherInput` | n/a |

**无孤立需求。无孤立 story。**

### 与 Axion Epic 40 的边界

Epic 29 干净地将 SDK primitives 与宿主编排分离：
- **SDK Epic 29 负责**：工具 alias、spawner 检测、skill package context、declaration model、共享过滤 primitives、deferred 字段诊断
- **Axion Epic 40 负责**：tool profile 组装、slash skill guidance、MCP/web/search/domain 工具接线、端到端 `/bmad-story-pipeline` 验证

此边界记录良好，符合架构规则 —— SDK 不应硬编码宿主业务逻辑。

---

## ⚠️ 发现的问题

### 🟡 ISSUE-1：PRD 术语冲突（低风险）
**位置：** PRD FR17 vs Epic 29 Story 29.1
**详情：** PRD FR17 列举了 `TaskCreate/List/Update/Get/Stop/Output`（任务管理工具）。Epic 29 引入 `Task` 作为 Claude Code 子代理启动器 alias。同前缀，不同概念。
**Epic 中已存在的缓解：** Story 29.1 强制使用 `SubAgentLauncherInput` 作为 Swift 类型名（而非 `TaskToolInput`）。
**运行时影响：** 无 —— 工具名字符串 `"Task"` 与 `"TaskCreate"` 互不冲突。
**建议动作：** 在 PRD FR17 添加注释消歧义，或添加 FR78 风格说明澄清两个 Task 概念。

### ✅ ISSUE-2：Story 29.5 模块位置 — 已解决（2026-06-14）
**决策：** Helper 放在新文件 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`，与 Story 29.4 引入的 `ToolDeclaration` 类型同处。
**理由：**
- 必须同时被 `Core/DefaultSubAgentSpawner`（Core/）和 `Tools/SkillTool`/`ToolRestrictionStack`（Tools/）调用
- `Core/` 不依赖 `Tools/`（架构规则），所以不能放 `Tools/`
- `Tools/` 不依赖 `Core/`（架构规则），所以不能放 `Core/`
- 仅剩 `Types/` 和 `Utils/` 可行；选 `Types/` 是为了让 `ToolDeclaration` 类型与其 filter 函数物理同处，与 `ToolRestriction` 在 `Types/SkillTypes.swift` 的模式一致
**已更新到 Epic 29 Story 29.5 实施步骤中。**

### 🟢 ISSUE-3：Story 29.7 未显式引用测试 helper
**位置：** Epic 29 Story 29.7
**详情：** 命名了测试文件但未命名共享 helper（来自 `GitTestHelpers.swift` 的 `makeTestToolContext`、`makeTestSkill`）。
**影响：** 极小 —— 项目规则 #51 已作为项目上下文加载。
**建议动作：** 可选 —— 在 29.7 测试计划中添加注释引用现有 helper。

### 🟢 ISSUE-4：PRD 早于 Claude Code 兼容目标
**位置：** PRD（2026-04-03）vs Epic 29（2026-06-14）
**详情：** PRD 中没有 FR 提及 Claude Code workflow skill 兼容性 —— 此目标在 PRD 冻结后出现。
**影响：** 对 Epic 29 实施无影响；通过 FR11/FR17/FR22/FR34/FR35 的可追溯性已足够。
**建议动作：** 可选 —— 在 PRD 添加 v1.x 修订条目，记录跨宿主兼容性为后 MVP 主题。

---

## ✅ 推荐的启动前动作

| # | 动作 | 优先级 | 负责人 | 阻塞 | 状态 |
|---|---|---|---|---|---|
| 1 | 决定 Story 29.5 helper 模块位置 | P0 | Architect | Story 29.5 | ✅ 已完成 — `Types/ToolDeclaration.swift`（2026-06-14） |
| 2 | 为 Claude Code workflow skill 兼容性添加 FR 或 PRD 修订 | P1 | PM | 仅可追溯性 | 待办 |
| 3 | 在 FR17 中注释消歧义 `Task`（子代理 alias）vs `TaskCreate`（任务管理） | P2 | PM | 仅清晰度 | ✅ 已完成 — PRD 第 298 行添加术语消歧义注释（2026-06-14） |
| 4 | 在 Story 29.7 中引用现有测试 helper（`makeTestToolContext`、`makeTestSkill`） | P2 | Dev | 可选 | 待办 |

---

## 最终结论

**🟢 已就绪可实施**

Epic 29 是本项目历史上准备最充分的 epic 之一：
- 所有代码事实声明对照当前源码验证为准确
- 7 个 story × 32 条可测试 AC，无歧义
- 架构边界显式遵守
- 6 项 deferred 项目为后续 epic 文档化
- 干净的 SDK/Axion 边界

**推荐 pipeline 顺序：**
1. **先做 Action 1**（architect 决定 29.5 helper 位置）— 5 分钟决策
2. 按依赖顺序对每个 story 运行 BMAD story pipeline（`/bmad-story-pipeline` 或手动 `bmad-create-story` → `bmad-dev-story` → `bmad-testarch-trace`）
3. 从 **Story 29.1** 开始（P0，无依赖）—— 它解锁 29.2、29.3、29.4

**置信度：高。** 无阻塞性问题。四项动作都是文档/决策层面的细化，而非实施阻塞。
