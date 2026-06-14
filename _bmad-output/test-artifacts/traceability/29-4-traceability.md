---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-map-criteria', 'step-04-analyze-gaps', 'step-05-gate-decision']
lastStep: 'step-05-gate-decision'
lastSaved: '2026-06-14'
storyId: '29.4'
coverageBasis: 'acceptance_criteria'
oracleResolutionMode: 'formal_requirements'
oracleConfidence: 'high'
oracleSources:
  - '_bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md'
  - '_bmad-output/test-artifacts/atdd-checklist-29-4-tool-declaration-compatibility-model.md'
  - 'Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift'
  - 'Sources/OpenAgentSDK/Types/ToolDeclaration.swift'
  - 'Sources/OpenAgentSDK/Skills/SkillLoader.swift'
  - 'Sources/OpenAgentSDK/Types/SkillTypes.swift'
externalPointerStatus: 'not_used'
gate_decision: 'PASS'
---

# 可追溯性报告：Story 29.4 — Tool Declaration Compatibility Model

## 质量门决策：PASS

**决策依据：** P0 覆盖率 100%（要求 100%），P1 覆盖率 100%（目标 90%），总体覆盖率 100%（最低 80%）。全部 6 条验收标准（AC1–AC6）均被新增的 18 个通过单元测试完整覆盖（10 个 SkillLoader ATDD + 5 个 SkillTypes ATDD + 3 个 code-review 回归修复测试），外加 4 个既有 `parseAllowedTools` 回归保护测试继续通过。本 story 引入的 `ToolDeclaration` / `ToolDeclarationStatus` / `ToolDeclarationDiagnostics` 数据模型与 `parseToolDeclarations` 解析器在 code review 阶段经过 3 层对抗式审查并应用 3 个范围内正确性修复（F1 空括号幻影 pattern、F6 未闭合括号静默降级、F9 MCP 带尾 pattern 的 normalizedName 腐化），每个修复都有对应回归测试。生产代码 `parseToolDeclarations` 与 `loadSkillFromDirectory` 双字段填充（旧 `toolRestrictions` + 新 `toolDeclarations`）已验证。全量套件 5738/5738 通过（baseline 5720 → +18）。无 Critical/High/Medium/Low 级别覆盖缺口。

## 覆盖总结

| 指标 | 值 |
|------|-----|
| 验收标准总数 (ACs) | 6 |
| 完全覆盖 | 6 (100%) |
| 部分覆盖 | 0 |
| 未覆盖 | 0 |
| 本 story 新增测试用例 | 18（含 3 个 review-fix 回归） |
| 回归保护测试（既有，继续通过） | 4（`testParseAllowedTools_*` 系列） |
| 测试失败 | 0 |
| 测试文件 | 2（SkillLoaderTests.swift + SkillTypesTests.swift） |

## 优先级覆盖

| 优先级 | 总数 | 覆盖 | 百分比 |
|--------|------|------|--------|
| P0 | 5 | 5 | 100% |
| P1 | 3 | 3 | 100% |
| P2 | 0 | 0 | N/A |
| P3 | 0 | 0 | N/A |

AC1–AC5 为功能性/行为性需求（数据模型保留与解析正确性），分类为 P0/P1（核心用户可见行为 + 设计锁定）。AC6（build + 全量回归）由执行证据满足，非单一测试方法。

## 可追溯性矩阵

### AC1: MCP namespaced 工具声明被保留（P0）

**覆盖：完整** — 3 个测试

| 测试 | 层级 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `testParseToolDeclarations_preservesMCPNamespacedNames` | Unit | PASS | AC1 核心：输入 `WebSearch, mcp__github__list_prs, Task`，断言 3 个 rawName 全部保留；MCP 声明 `status == .recognizedMCP`；`normalizedName == "mcp__github__list_prs"`（不截断） |
| `testParseToolDeclarations_mixedKnownUnknownMCP` | Unit | PASS | AC1 + AC5：混合输入 `Bash, UnknownTool, mcp__srv__search`，断言 MCP 声明保留 `rawName == "mcp__srv__search"`、`status == .recognizedMCP`、按 frontmatter 顺序 |
| `testLoadSkillFromDirectory_populatesToolDeclarations` | Unit (集成) | PASS | AC1 + AC2 + AC3 + AC4：`loadSkillFromDirectory` 端到端填充新字段 `toolDeclarations`（含 pattern + SDK 工具），`count == 3` |

**实现验证：** `Sources/OpenAgentSDK/Skills/SkillLoader.swift` — `parseToolDeclarations` 使用 "split on comma then trim" 策略保留完整 token；`isMCPNamespacedName` 识别 `mcp__<server>__<tool>` 模式（`normalizedName` 保留全名不截断，符合 project-context.md #10 MCP 命名约定）。

---

### AC2: 未知工具名不 collapse 为 unrestricted（P0）

**覆盖：完整** — 3 个测试

| 测试 | 层级 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `testParseToolDeclarations_doesNotCollapseToUnrestricted` | Unit | PASS | AC2 核心：输入 `UnknownTool`，断言 `parseToolDeclarations` 返回**非 nil**（与旧 `parseAllowedTools` 返回 nil = unrestricted 的语义对比）；同测试内还断言旧解析器在此输入下返回 nil（验证 bug 路径仍在但新解析器修正） |
| `testParseToolDeclarations_unknownToolNotDropped` | Unit | PASS | AC2 diagnostic 可见：`diagnostics.unsupportedDeclarations` 含该声明，`status == .unknown` |
| `testToolDeclarationStatus_AllCases` | Unit | PASS | AC2 + 设计锁定：`ToolDeclarationStatus` enum 4 个 case 全部存在（含 `.unknown`），防止实现遗漏 |

**实现验证：** `Sources/OpenAgentSDK/Skills/SkillLoader.swift:372-399` — `parseToolDeclarations` 关键非 nil 语义：非空输入永远返回非 nil 元组（即使全 unknown）。这是本 story 修正"静默放权"bug 的核心（epic "不静默放权"红线）。`.unknown` 含义明确："解析时无法确认"，运行时可能匹配 custom tool（29.5 filter 区分）。

---

### AC3: Permission pattern 文本被保留并标注（P0/P1）

**覆盖：完整** — 5 个测试（2 ATDD P0 + 1 ATDD P1 + 2 review-fix 回归 + 1 集成）

| 测试 | 层级 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `testParseToolDeclarations_preservesPatternText` | Unit (P0) | PASS | AC3 核心：输入 `Bash(git diff:*)`，断言 `rawName == "Bash(git diff:*)"`（保留完整含括号）、`pattern == "git diff:*"`（提取括号内 pattern）、`normalizedName == "bash"`（base name 正确）、`status == .recognizedSDK`、`toolRestriction == .bash` |
| `testParseToolDeclarations_patternEntersDiagnostics` | Unit (P1) | PASS | AC3 pattern 诊断：`diagnostics.patternDeclarations` 非空（标注"已解析但未在 pattern 粒度强制执行"），`pattern == "git diff:*"` |
| `testParseToolDeclarations_emptyParensProduceNoPhantomPattern` | Unit (review-fix F1) | PASS | AC3 鲁棒性：空括号 `Bash()` 不产生幻影空 pattern；`pattern == nil`，不污染 `patternDeclarations` |
| `testParseToolDeclarations_unclosedParenStillRecognizesBase` | Unit (review-fix F6) | PASS | AC3 鲁棒性：未闭合括号 `Bash(git diff:*` 仍识别 base `Bash` 为 `.recognizedSDK`（不静默降级为 `.unknown`） |
| `testLoadSkillFromDirectory_populatesToolDeclarations` | Unit (集成) | PASS | AC3 + AC4：`patternDeclarations` 非空（`Bash(npx foo:*)` 进入 pattern 诊断） |

**实现验证：** `Sources/OpenAgentSDK/Skills/SkillLoader.swift` — `splitBaseAndPattern` 与 `tokenizeToolDeclaration` 实现 pattern 提取；review-fix F1/F6 修复了空括号与未闭合括号的边界情况。Pattern 保留语义符合 epic 延后项第 5 条（fine-grained enforcement 推迟，本 story 只保留文本并标注）。

---

### AC4: 向后兼容 —— 现有 `Skill.toolRestrictions` 字段与全部消费者无回归（P0）

**覆盖：完整** — 9 个测试（4 新增 SkillTypes + 4 既有 parseAllowedTools 回归 + 1 集成）

| 测试 | 层级 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `testSkill_ToolDeclarations_DefaultsToNil` | Unit | PASS | AC4 核心：`Skill.init` 新参数有默认值 nil，仅用必需字段创建的 Skill 新字段为 nil；旧字段 `toolRestrictions` 行为不变 |
| `testSkill_ToolDeclarations_ExplicitlySet` | Unit | PASS | AC4：新参数可显式传入并被正确存储（`count == 2`，含 Bash + MCP 声明） |
| `testSkill_WithBaseDir_PreservesToolDeclarations` | Unit | PASS | AC4：`withBaseDir` 复制新字段 `toolDeclarations` + `toolDeclarationDiagnostics` |
| `testSkill_Equality_ConsidersToolDeclarations` | Unit | PASS | AC4：`==` 比较新字段（不同 declarations 的 Skill 不相等；相同 declarations 的相等） |
| `testParseAllowedTools_WithArguments` | Unit (既有) | PASS | AC4 回归保护：旧解析器 `Bash(npx foo:*), Read, Glob` → `[.bash, .read, .glob]` |
| `testParseAllowedTools_EmptyString` | Unit (既有) | PASS | AC4 回归保护：空字符串 → nil |
| `testParseAllowedTools_Nil` | Unit (既有) | PASS | AC4 回归保护：nil → nil |
| `testParseAllowedTools_UnknownToolsIgnored` | Unit (既有) | PASS | AC4 回归保护：未知工具被忽略（旧行为保留，本 story 不改旧解析器） |
| `testLoadSkillFromDirectory_populatesToolDeclarations` | Unit (集成) | PASS | AC4 端到端：`loadSkillFromDirectory` **同时**填充新字段（`toolDeclarations?.count == 3`）与旧字段（`toolRestrictions?.count == 3`，含 `.bash/.read/.write`），双字段并存 |

**实现验证：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` — `Skill.init` 新增两参数位于 `toolRestrictions` 之后、`modelOverride` 之前，带默认 nil → 所有现有调用方（6 BuiltInSkills + 测试 helper + SkillLoader）保持编译
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift:99-100` — `loadSkillFromDirectory` 同时调用旧 `parseAllowedTools`（填充 `toolRestrictions`）与新 `parseToolDeclarations`（填充 `toolDeclarations` + `toolDeclarationDiagnostics`）
- 消费方未改动（Agent.swift / SkillTool.swift / ToolRestrictionStack / DefaultSubAgentSpawner 推迟到 29.5）
- `ToolRestriction` enum 未加 `.task` case（Dev Notes "ToolRestriction gap" 合规）

---

### AC5: 常见 SDK/Claude 工具名被识别（P0/P1）

**覆盖：完整** — 2 个测试 + 1 个 review-fix（MCP 带 pattern）

| 测试 | 层级 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `testParseToolDeclarations_recognizesClaudeCodeNames` | Unit (P0) | PASS | AC5 核心：epic 实施步骤第 3 条全部 13 个 Claude Code LLM-facing 名（`Read/Write/Edit/Glob/Grep/Bash/WebFetch/WebSearch/ToolSearch/AskUser/Skill/Agent/Task`）都被识别为 `.recognizedSDK`；抽样验证 `normalizedName` 规范化正确（`bash`/`webfetch`/`skill`）；可映射 enum 的提供 `toolRestriction`（`.bash`/`.webFetch`/`.skill`） |
| `testParseToolDeclarations_taskRecognizedButNoEnumCase` | Unit (P1) | PASS | AC5 + 设计锁定：`Task` 在 `ToolRestriction` enum 无 case，但 `status == .recognizedSDK`、`normalizedName == "task"`、`toolRestriction == nil`（遵守 Dev Notes "ToolRestriction gap"，不加 enum case） |
| `testParseToolDeclarations_mcpNameWithTrailingPatternStripsParens` | Unit (review-fix F9) | PASS | AC5 + AC1 鲁棒性：MCP 名带尾 pattern `mcp__github__list_prs(extra:*)` 的 `normalizedName` 去括号（`mcp__github__list_prs`），否则运行时无法匹配注册的 MCP 工具 |

**实现验证：** `Sources/OpenAgentSDK/Skills/SkillLoader.swift` — `ClaudeCodeToolNames` 私有命名空间通过 `restrictionByLowercasedName` 字典做 case-insensitive 查找（解决 `webFetch` camelCase rawValue vs `WebFetch` PascalCase frontmatter 不匹配问题）；`knownClaudeCodeOnly` 处理 `Task`（无 enum case 但标 `.recognizedSDK`）。

---

### AC6: Build 与全量回归（P0）

**覆盖：完整** — 执行证据（无独立测试方法）

| 测试 | 层级 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `swift build` | Build | PASS | 零新警告（per dev log + parent agent 验证） |
| `swift test`（全量套件） | Regression | PASS | 5738/5738 通过；baseline 5720 → +18（10 SkillLoader ATDD + 5 SkillTypes ATDD + 3 review-fix 回归） |

**证据：** `_bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md` "Dev Agent Record" 与 "Change Log" 记录最终测试数 5738（code review 后）。无 Swift 编译器引入名为 `Task` 的类型（rule #15 合规）。`ToolRestrictionStackTests`（28 个测试）、`ExecuteSkillTests` / `ExecuteSkillStreamTests`、`SkillToolTests`、既有 `SkillLoaderTests`（~35 个）全部继续通过（无回归）。

---

## 覆盖启发式

- 无测试的端点：0（N/A — 解析器是纯函数，非 HTTP API surface）
- Auth 负路径缺口：0（N/A）
- 仅 Happy-path 的标准：0（负路径 AC2-unknown + AC3-emptyParens/unclosedParen/MCP-with-pattern 全部覆盖）
- UI journey/state 缺口：0（N/A — Types/ 数据模型层，无 UI）

## 缺口分析

| 严重度 | 数量 | 条目 |
|--------|------|------|
| Critical (P0) | 0 | — |
| High (P1) | 0 | — |
| Medium (P2) | 0 | — |
| Low (P3) | 0 | — |

**仅单元测试覆盖（可接受，E2E 推迟到 Story 29.7）：**
- AC1–AC5：仅单元级覆盖；E2E 测试按 project rule #29 与 story Task 5.5 推迟。Epic 29.7（Tests and Documentation）是 skill/subagent 兼容性路径的明确 E2E 目标。

## 缺口与建议

1. **无阻塞项。** 全部 P0 标准达成；P1+ 全覆盖。
2. **E2E 覆盖推迟到 Story 29.7**（per project rule #29 + story Task 5.5 + epic 29.7 节）。
3. **推迟到 Story 29.5 的项（非阻塞，code review 识别的 5 个延后 findings）：**
   - MCP tool name 含 `__`（如 `mcp__server__tool__sub`）的精确识别（当前宽松 `^mcp__.+__.+$` 接受）
   - 括号内含逗号的 pattern（如 `Bash(a, b)`）的切分（当前逗号切分会误切）
   - 重复声明的去重（当前保留全部，含重复）
   - 畸形括号形式（如 `Bash)(`）的进一步鲁棒性
   - `filterToolsByDeclarations` 共享过滤 helper 的实现（本 story 仅引入数据模型 + 解析器，29.5 消费）
4. **`ToolDeclarationStatus.recognizedCustom` 当前未被解析器产生**（所有非 MCP/非 SDK 名标 `.unknown`）。这是 Dev Notes 明确的设计决策（a）：解析时无法知道 host 注册的自定义工具，由 29.5 filter 在运行时按 available tools 升级。`.recognizedCustom` case 仍存在于 enum（AC2 `testToolDeclarationStatus_AllCases` 验证），为 29.5 预留。

## 质量门标准验证

| 标准 | 要求 | 实际 | 状态 |
|------|------|------|------|
| P0 覆盖率 | 100% | 100% | MET |
| P1 覆盖率（PASS 目标） | 90% | 100% | MET |
| P1 覆盖率（最低） | 80% | 100% | MET |
| 总体覆盖率（最低） | 80% | 100% | MET |

**质量门决策：PASS** — 发布批准；覆盖达标。Story 29.4 status `done` 正确（code-review 步骤设置，本 trace 确认）。

## 下一步行动

- **Story 29-4 status**：`done`（code-review 步骤设置；本 PASS 门确认）。保持 `done`。
- **`sprint-status.yaml`**：`29-4-tool-declaration-compatibility-model: done` — 正确且不变。
- **解锁**：Story 29.5（Shared filtering — `filterToolsByDeclarations`）— 直接依赖本 story 的 `ToolDeclaration` 模型与 `parseToolDeclarations` 解析器。29.5 将在 `Types/ToolDeclaration.swift` 同文件加 filter 函数 + `ToolFilterDiagnostics`，并切换消费方（Agent.swift / SkillTool.swift / ToolRestrictionStack / DefaultSubAgentSpawner）到 `toolDeclarations`。
- **建议**：可选运行 `bmad-testarch-test-review` 评估测试质量。Epic 29 完成后运行 retrospective。
