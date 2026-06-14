---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-map-criteria', 'step-04-analyze-gaps', 'step-05-gate-decision']
lastStep: 'step-05-gate-decision'
lastSaved: '2026-06-14'
storyId: '29.5'
storyKey: 29-5-shared-filtering-skills-subagents
storyFile: _bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-29-5-shared-filtering-skills-subagents.md
coverageBasis: 'acceptance_criteria'
oracleResolutionMode: 'formal_requirements'
oracleConfidence: 'high'
oracleSources:
  - '_bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md'
  - '_bmad-output/test-artifacts/atdd-checklist-29-5-shared-filtering-skills-subagents.md'
  - 'Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift'
  - 'Sources/OpenAgentSDK/Types/ToolDeclaration.swift'
  - 'Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
externalPointerStatus: 'not_used'
tempCoverageMatrixPath: '/tmp/tea-trace-coverage-matrix-29-5.json'
gate_decision: 'PASS'
collection_mode: 'yolo'
---

# 可追溯性报告：Story 29.5 — Shared Filtering for Skill and Subagent Tool Sets

## 质量门决策：PASS

**决策依据：** P0 覆盖率 100%（要求 100%），P1 覆盖率 100%（目标 90%），总体覆盖率 100%（最低 80%）。全部 8 条验收标准（AC1–AC8）均被 31 个新增通过的单元测试完整覆盖（26 个 ATDD 红相测试 + 5 个 code-review 回归修复测试），外加既有回归保护套件继续通过（`ToolRestrictionStackTests` 28 个、`ToolRegistryTests.filterTools_*`、`SkillLoaderTests.parseToolDeclarations_*` 29.4 的 10 个、`DefaultSubAgentSpawnerTests` 29.2 的 `filterTools_*` 5 个、`ExecuteSkillTests` / `ExecuteSkillStreamTests` 既有）。

本 story 引入的 `filterToolsByDeclarations` helper、`ToolFilterDiagnostics` / `ToolFilterOptions` 载体、`DefaultSubAgentSpawner.filterTools` 改造、`executeSkill` / `executeSkillStream` 消费方迁移、`assembleFullToolPool` 集成、SkillTool 元数据增强、`ToolDeclaration.parse` / `fromToolNames` 解析器上提，全部经过 3 层对抗式 code review（Blind Hunter / Edge Case Hunter / Acceptance Auditor），应用 3 个范围内正确性修复：

- **CRITICAL** — MCP `normalizedName` 大小写不对称导致 AC3 对混合大小写 MCP 名失效（`mcp__GitHub__ListPRs` 永不匹配 lowercased 可用集合）
- **HIGH** — declaration 路径未清空 `options.allowedTools` 导致双重过滤回归（宿主预设 allowlist 时 MCP 工具在 `applyAllowedDeclarations` 看到前被剥离）
- **HIGH** — `fromToolNames` 未过滤空/whitespace token 产生幻影 `.unknown` 声明

每个修复都有专门回归测试。Epic 29 全部 5 条红线经 Acceptance Auditor 验证遵守。全量套件 5769/5769 通过（baseline 5738 → +26 ATDD +5 review 回归 = +31）。Story 状态 `done`。无 Critical / High / Medium / Low 级别覆盖缺口。

---

## 覆盖总结

| 指标 | 值 |
|------|-----|
| 验收标准总数 (ACs) | 8 |
| 完全覆盖 | 8 (100%) |
| 部分覆盖 | 0 |
| 未覆盖 | 0 |
| 本 story 新增测试用例 | 31（26 ATDD + 5 code-review 回归） |
| 既有回归保护套件（继续通过） | `ToolRestrictionStackTests` (28) + `ToolRegistryTests.filterTools_*` + `SkillLoaderTests.parseToolDeclarations_*` (10) + `DefaultSubAgentSpawnerTests.filterTools_*` 29.2 (5) |
| 测试失败 | 0 |
| 测试文件 | 4 |

## 优先级覆盖

| 优先级 | 总数 | 覆盖 | 百分比 |
|--------|------|------|--------|
| P0 | 6 | 6 | 100% |
| P1 | 2 | 2 | 100% |
| P2 | 0 | 0 | N/A |
| P3 | 0 | 0 | N/A |

AC1–AC6 为功能性/行为性需求（helper 存在性、过滤规则、MCP 匹配、不静默放权红线、skill 执行路径迁移、SkillTool 元数据），分类为 P0（核心用户可见行为 + Epic 红线）。AC7（向后兼容无回归）与 AC8（build + 全量回归）兼具行为性与执行证据，分类 P0/P1。

## 覆盖基础

- **coverageBasis:** `acceptance_criteria`
- **oracleResolutionMode:** `formal_requirements`（story 文件 + ATDD checklist 显式 AC1–AC8 + Tasks/Subtasks）
- **oracleConfidence:** high（8 条正式 AC，每条 Given/When/Then 完整）
- **externalPointerStatus:** `not_used`

---

## 可追溯性矩阵

### AC1: Helper 函数存在并位于正确模块（P0）

**覆盖：完整** — 3 个测试

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testToolFilterDiagnostics_isPublicEquatableStruct` | ToolDeclarationFilterTests.swift:75 | Unit | PASS | 验证 `ToolFilterDiagnostics` 是 public Sendable+Equatable struct，含 `unmatchedDeclarations` + `patternDeclarations` 两字段可构造 |
| `testFilterToolsByDeclarations_callableAndReturnsTuple` | ToolDeclarationFilterTests.swift:88 | Unit | PASS | 验证 `filterToolsByDeclarations(available:allowed:disallowed:options:)` 可调用并返回 `(filtered, diagnostics)` 元组 |
| `testToolFilterOptions_hasDefaultInit` | ToolDeclarationFilterTests.swift:101 | Unit | PASS | 验证 `ToolFilterOptions` 有默认 init（向后兼容最小配置） |

### AC2: 子代理工具池按 declarations 过滤（P0）

**覆盖：完整** — 11 个测试（核心匹配规则 + 边界 + 转换）

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testFilter_preservesOnlyAllowedTools` | ToolDeclarationFilterTests.swift:111 | Unit | PASS | available=[Bash,Read,Write] allowed=[Read,Grep] → filtered==[Read]，Grep 进 unmatchedDeclarations |
| `testFilter_caseInsensitive` | ToolDeclarationFilterTests.swift:136 | Unit | PASS | allowed=["bash"] 匹配 tool "Bash"（修复 29.2 字符串版大小写敏感 bug） |
| `testFilter_disallowed_overridesAllowed` | ToolDeclarationFilterTests.swift:223 | Unit | PASS | allowed=[Bash,Read] disallowed=[Bash] → filtered==[Read]，disallowed 优先级高于 allowed |
| `testFilter_nilAllowed_returnsAll` | ToolDeclarationFilterTests.swift:242 | Unit | PASS | allowed=nil → filtered==available（无约束） |
| `testFilter_emptyAllowed_returnsAll` | ToolDeclarationFilterTests.swift:256 | Unit | PASS | allowed=[] 等同 nil，返回全部 |
| `testFilter_patternDeclaration_matchesByBaseNameAndSurfacesInDiagnostics` | ToolDeclarationFilterTests.swift:274 | Unit | PASS | allowed=["Bash(git diff:*)"] available=[Bash] → filtered==[Bash]（按 base name 匹配），pattern 进 diagnostics |
| `testFromToolNames_preservesOrderAndPatternAndMCP` | ToolDeclarationFilterTests.swift:297 | Unit | PASS | `fromToolNames(["Read","Bash(git diff:*)","mcp__srv__search"])` 顺序保持 + pattern 保留 + MCP 识别 |
| `testFromToolNames_empty_returnsEmptyArray` | ToolDeclarationFilterTests.swift:313 | Unit | PASS | 空数组输入返回空数组 |
| `testFilterTools_declarationBased_keepsOnlyMatching` | DefaultSubAgentSpawnerTests.swift:481 | Unit | PASS | 父池=[Bash,Read,Write,Agent] allowedTools=["Read","Grep"] → filtered==[Read]，Agent 被 SubAgentLauncherNames 剥离 |
| `testFilterTools_launcherStrippingStillWorks` | DefaultSubAgentSpawnerTests.swift:573 | Unit | PASS | allowedTools=nil → [Bash,Agent,Task] → filtered==[Bash]（29.2 行为不变，AC7 回归保护） |
| `testFilterTools_patternInAllowed_matchesByBaseName` | DefaultSubAgentSpawnerTests.swift:604 | Unit | PASS | allowedTools=["Bash(git diff:*)"] → filtered 含 Bash（修复 29.2 pattern 字符串全等失配 bug） |

### AC3: MCP 工具声明匹配无需 enum case（P0）

**覆盖：完整** — 5 个测试（含 2 个 CRITICAL review-fix 回归）

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testFilter_mcpDeclaration_matchesWithoutEnumCase` | ToolDeclarationFilterTests.swift:155 | Unit | PASS | allowed=[mcp__srv__search] available 含同名 MCP 工具 → filtered 保留，status==.recognizedMCP，toolRestriction==nil |
| `testFilter_mcpDeclaration_mixedCase_matchesCaseInsensitive` | ToolDeclarationFilterTests.swift:326 | Unit | PASS | **CRITICAL review-fix**：声明 `mcp__GitHub__ListPRs` 匹配可用 `mcp__github__listprs`，normalizedName 已 lowercased |
| `testFilter_mcpDeclaration_lowercasedDeclaration_matchesMixedCaseAvailable` | ToolDeclarationFilterTests.swift:351 | Unit | PASS | **CRITICAL review-fix 交叉变体**：声明 lowercased 匹配可用 mixed-case，两方向都工作 |
| `testFilterTools_mcpAllowed_keepsMcp` | DefaultSubAgentSpawnerTests.swift:513 | Unit | PASS | 子代理父池含 MCP 工具，allowedTools=["mcp__srv__search"] → 保留 |
| `testExecuteSkill_mcpDeclarationSurvivableViaFilterHelper` | ExecuteSkillTests.swift:376 | Unit | PASS | **headline 修复代理测试**：声明含 MCP + available 含 MCP → 经 `filterToolsByDeclarations` 保留（`assembleFullToolPool` 出口的同一路径） |

### AC4: 声明了但无可用工具 → diagnostics，绝不 unrestricted（P0）

**覆盖：完整** — 4 个测试（单 unmatched + 全 unmatched + 幻影 token）

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testFilter_unknownDeclaration_notUnrestricted` | ToolDeclarationFilterTests.swift:182 | Unit | PASS | allowed=[PhantomTool] available=[Bash,Read] → filtered==[]（绝不返回全部 available），unmatched 含 PhantomTool |
| `testFilter_allDeclarationsUnmatched_poolStillEmpty` | ToolDeclarationFilterTests.swift:200 | Unit | PASS | 红线 stress：全部 unmatched → filtered 仍为空，绝不 unrestricted 回退 |
| `testFilterTools_unknownAllowed_notUnrestricted` | DefaultSubAgentSpawnerTests.swift:547 | Unit | PASS | 子代理路径同红线：allowedTools=["PhantomTool"] → filtered==[] |
| `testFromToolNames_skipsEmptyAndWhitespaceEntries` | ToolDeclarationFilterTests.swift:368 | Unit | PASS | **HIGH review-fix**：`["Read","","   ","\t","Write"]` → 跳过空/whitespace token，避免幻影 `.unknown` 声明污染 unmatchedDeclarations |

### AC5: skill 执行路径消费 toolDeclarations（29.4 消费方迁移）（P0）

**覆盖：完整** — 5 个测试（含 1 个 HIGH review-fix 回归）

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testExecuteSkill_agentOptions_allowedToolDeclarations_defaultsToNil` | ExecuteSkillTests.swift:325 | Unit | PASS | `AgentOptions.allowedToolDeclarations` 默认 nil，既有 AgentOptions 构造保持编译 |
| `testExecuteSkill_toolDeclarations_appliedAndRestored` | ExecuteSkillTests.swift:339 | Unit | PASS | skill 有 toolDeclarations 时执行期间设置 + 完成后恢复 nil（mock AnthropicClient 无真实 LLM） |
| `testExecuteSkill_mcpDeclarationSurvivableViaFilterHelper` | ExecuteSkillTests.swift:376 | Unit | PASS | headline 修复：声明含 MCP 工具，经 helper 保留（旧 toolRestrictions 路径会丢弃） |
| `testExecuteSkill_fallsBackToToolRestrictions_whenNoDeclarations` | ExecuteSkillTests.swift:413 | Unit | PASS | programmatic skill（toolDeclarations==nil）走旧 toolRestrictions fallback，行为不变 |
| `testExecuteSkill_declarationPath_clearsAndRestoresLegacyAllowedTools` | ExecuteSkillTests.swift:443 | Unit | PASS | **HIGH review-fix**：declaration 路径清空 `options.allowedTools` 防止双重过滤；完成后恢复宿主原值（深行为断言） |

### AC6: SkillTool 元数据暴露 richer 声明（P0）

**覆盖：完整** — 2 个测试（何时 emit / 何时缺席）

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testSkillTool_toolDeclarations_includedInJSON_whenPresent` | SkillToolTests.swift:469 | Unit | PASS | skill 有 toolDeclarations → JSON 含 `toolDeclarations` 数组（每声明 rawName/normalizedName/status/pattern/hasToolRestriction）+ 向后兼容 `allowedTools` rawValues |
| `testSkillTool_toolDeclarations_absent_whenSkillHasNone` | SkillToolTests.swift:532 | Unit | PASS | skill 无 toolDeclarations（nil）→ JSON 行为如现状（只暴露 allowedTools rawValue，无新 key） |

### AC7: 向后兼容 —— 现有行为无回归（P0/P1）

**覆盖：完整** — 5 个 29.5 新增回归保护测试 + 既有套件全部继续通过

| 测试 | 文件 | 层级 | 状态 | 覆盖说明 |
|------|------|------|------|----------|
| `testFilterTools_launcherStrippingStillWorks` | DefaultSubAgentSpawnerTests.swift:573 | Unit | PASS | 29.2 launcher 剥离回归：allowedTools=nil → [Bash,Agent,Task] → filtered==[Bash] |
| `testSkillTool_toolDeclarations_absent_whenSkillHasNone` | SkillToolTests.swift:532 | Unit | PASS | SkillTool 向后兼容（无 declarations 时行为不变） |
| `testExecuteSkill_fallsBackToToolRestrictions_whenNoDeclarations` | ExecuteSkillTests.swift:413 | Unit | PASS | executeSkill 旧路径 fallback 保留 |
| `testExecuteSkill_declarationPath_clearsAndRestoresLegacyAllowedTools` | ExecuteSkillTests.swift:443 | Unit | PASS | declaration 路径宿主 allowedTools 完整保存恢复 |
| `testFromToolNames_trimsSurroundingWhitespace` | ToolDeclarationFilterTests.swift:380 | Unit | PASS | **HIGH review-fix**：宿主传 sloppy tool 名（"  Read  "）被 trim，避免正常名被误判 unknown |
| 既有 `ToolRestrictionStackTests` (28) | ToolRestrictionStackTests.swift | Unit | PASS | 28 个 stack 测试继续通过（helper 不替代 enum-based stack） |
| 既有 `ToolRegistryTests.filterTools_*` | ToolRegistryTests.swift | Unit | PASS | Tools/ 层字符串版 `filterTools` 签名不变，AC7 红线 |
| 既有 `SkillLoaderTests.parseToolDeclarations_*` (10) | SkillLoaderTests.swift | Unit | PASS | 29.4 的 10 个解析测试继续通过（Task 5 仅移动代码位置，行为不变） |
| 既有 `DefaultSubAgentSpawnerTests.filterTools_*` 29.2 (5) | DefaultSubAgentSpawnerTests.swift | Unit | PASS | 29.2 的 `filterToolsForTesting` 签名保留，5 个测试继续通过 |
| 既有 `ExecuteSkillTests` / `ExecuteSkillStreamTests` 现有 | 同文件 | Unit | PASS | executeSkill 既有 programmatic skill 测试走 fallback 路径 |

### AC8: Build 与全量回归（P0）

**覆盖：完整** — 执行证据

| 测试 / 命令 | 类型 | 状态 | 覆盖说明 |
|------|------|------|----------|
| `swift build` | 构建 | PASS | 零新警告（82 个既有 warning 全部在无关代码路径：execute 结果未用、Agent.swift 未用变量） |
| `swift test` | 全量套件 | PASS | 5769/5769 通过（baseline 5738 → +26 ATDD +5 review 回归 = +31，与新增数完全吻合） |
| `swift test --filter "ToolDeclarationFilterTests\|DefaultSubAgentSpawnerTests\|ExecuteSkillTests\|ExecuteSkillStreamTests\|SkillToolTests\|SkillLoaderTests\|ToolRegistryTests\|SkillTypesTests"` | 定向 | PASS | 185 测试 0 失败（覆盖 29.5 直接 + 邻近回归面） |

---

## 覆盖缺口分析

### Critical (P0) 缺口：0
### High (P1) 缺口：0
### Medium (P2) 缺口：0
### Low (P3) 缺口：0

**覆盖率 100%，无任何级别缺口。**

## 覆盖启发式检查

| 启发式 | 状态 | 说明 |
|--------|------|------|
| API 端点覆盖 | N/A | 本 story 是 Swift SDK 库层过滤 helper，无 API 端点 |
| Auth/authz 负路径 | N/A | 工具过滤非鉴权流 |
| 错误路径覆盖 | present | AC4 "声明但无可用工具" 是错误路径，4 个测试覆盖（含全 unmatched stress + 幻影 token） |
| UI journey E2E | not_applicable | 非 UI story |
| UI 状态覆盖 | not_applicable | 非 UI story |

## 测试去重清单

| 文件 | 测试数 | 层级 | skipped | fixme | pending |
|------|--------|------|---------|-------|---------|
| `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` | 19 | Unit | 0 | 0 | 0 |
| `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` (29.5 区段) | 5 | Unit | 0 | 0 | 0 |
| `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift` (29.5 区段) | 2 | Unit | 0 | 0 | 0 |
| `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift` (29.5 区段) | 5 | Unit | 0 | 0 | 0 |
| **合计** | **31** | Unit | **0** | **0** | **0** |

## Code Review 修复 → 回归测试映射

| 严重度 | 发现 | 修复位置 | 对应回归测试 |
|--------|------|----------|--------------|
| CRITICAL | MCP `normalizedName` 大小写不对称破坏 AC3 对混合大小写 MCP 名 | `ToolDeclaration.swift:149`（MCP 分支 lowercased baseName） | `testFilter_mcpDeclaration_mixedCase_matchesCaseInsensitive` + `testFilter_mcpDeclaration_lowercasedDeclaration_matchesMixedCaseAvailable` |
| HIGH | declaration 路径未清空 `options.allowedTools` 致双重过滤回归 | `Agent.swift:1288` + `:1360`（declaration 分支设 allowedTools=nil） | `testExecuteSkill_declarationPath_clearsAndRestoresLegacyAllowedTools` |
| HIGH | `fromToolNames` 未过滤空/whitespace token 产生幻影 unknown 声明 | `ToolDeclaration.swift:195`（trim + filter empty） | `testFromToolNames_skipsEmptyAndWhitespaceEntries` + `testFromToolNames_trimsSurroundingWhitespace` |

## Epic 29 红线验证（Acceptance Auditor 确认）

1. ✅ `ToolRegistry.filterTools`（Tools/ 层）签名不变，未删除（`Sources/OpenAgentSDK/Tools/ToolRegistry.swift:113`）
2. ✅ 未给 `ToolRestriction` enum 加 `.task` case — `Task` 通过 `knownClaudeCodeOnly = ["task"]` 字符串集匹配（`ToolDeclaration.swift:255`）
3. ✅ Launcher 剥离保留在 `DefaultSubAgentSpawner`（line 172），helper 内零 launcher 逻辑
4. ✅ allowed declarations 全部 unmatched 时 helper 返回空池（`ToolDeclaration.swift:381` `available.filter { allowedSet.contains(...) }`），绝不 unrestricted 回退
5. ✅ 兄弟代码路径一致 — `executeSkill` / `executeSkillStream` / `assembleFullToolPool` 全部经 `applyAllowedDeclarations` → `filterToolsByDeclarations`；两条 skill 路径均 save/restore `savedAllowedDeclarations`

## 推迟项（deferred to later stories）

| 推迟项 | 目标 story | 说明 |
|--------|-----------|------|
| Fine-grained Bash permission pattern enforcement | Epic 延后项第 5 条（29.7+） | 本 story 仅保留 pattern 文本进 diagnostics |
| Deferred field diagnostics（run_in_background / resume / isolation / team_name / skills / MCP reference） | 29.6 | SubAgentResult 结构化诊断 surfacing |
| E2E 测试（含完整 LLM 驱动 assembleFullToolPool MCP 保留检查） | 29.7 | project-context.md #29 |
| executeSkillStream 并发 options 恢复竞态 | 架构后续 | 预存在（allowedTools），本 story 克隆给 allowedToolDeclarations，未引入新竞态类别 |
| MCP 名含 `__` / stray `)` 边缘情况 | follow-up | 需 parser 语义决策 + 更广测试语料 |
| patternDeclarations 去重 / unmatchedDeclarations 去重 | follow-up | 美观性，过滤行为正确 |

## 建议

1. **(FOLLOWUP)** Story 29.7 补充 E2E：完整 LLM 驱动的 `assembleFullToolPool` MCP 保留检查。当前由 `testExecuteSkill_mcpDeclarationSurvivableViaFilterHelper` 通过直接调 `filterToolsByDeclarations`（`assembleFullToolPool` 出口的同一路径）做结构化代理验证。
2. **(LOW)** 可选运行 `bmad-testarch-test-review` 评估 31 个测试的内部质量（断言强度、命名一致性）。
3. **(DEFER)** Story 29.6 启动时，复用本 story 的 `ToolFilterDiagnostics` 模式扩展到 deferred field diagnostics。

## 参考工件

- Story 文件：`_bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md`
- ATDD checklist：`_bmad-output/test-artifacts/atdd-checklist-29-5-shared-filtering-skills-subagents.md`
- Gate decision JSON：`_bmad-output/test-artifacts/traceability/29-5-gate-decision.json`
- E2E trace summary JSON：`_bmad-output/test-artifacts/traceability/29-5-e2e-trace-summary.json`
- 上游 story 29.4 trace：`_bmad-output/test-artifacts/traceability/29-4-traceability.md`
