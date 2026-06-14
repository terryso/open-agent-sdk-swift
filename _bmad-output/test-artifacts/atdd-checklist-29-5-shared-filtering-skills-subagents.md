---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-14'
storyId: '29.5'
storyKey: 29-5-shared-filtering-skills-subagents
storyFile: _bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-29-5-shared-filtering-skills-subagents.md
generatedTestFiles:
  - Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift
  - Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift
  - Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift
  - Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md
  - _bmad-output/project-context.md
---

# ATDD Red-Phase 清单 — Story 29.5: Shared Filtering for Skill and Subagent Tool Sets

- **Story ID:** 29-5
- **Epic:** 29（Claude Code Skill/Subagent Compatibility）
- **阶段:** RED（TDD 红-绿-重构）
- **模式:** yolo（自动批准）
- **日期:** 2026-06-14
- **测试文件:**
  - `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`（新建）
  - `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`（扩展 — Story 29.5 区段）
  - `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`（扩展 — Story 29.5 区段）
  - `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift`（扩展 — Story 29.5 区段）
- **Story 规格:** `_bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md`

## 技术栈检测

- **检测到的栈:** backend（Swift Package Manager + XCTest，无 package.json / playwright / cypress）
- **生成模式:** AI generation（backend 栈无录制模式）
- **执行模式:** sequential（Swift 后端，无 subagent/agent-team 分派）
- **测试级别:** 单元测试（helper 是纯函数；executeSkill 路径用 mock AnthropicClient；无真实 LLM/网络/文件 I/O —— 遵守 project-context.md #27）
- **E2E:** 推迟到 Story 29.7（project-context.md #29 + epic 29.7）—— 本 story 不生成 E2E 脚手架

## Story 范围回顾

本 story 是 Epic 29 的**消费方迁移** story：29.4 让"声明"可表达（`ToolDeclaration` 模型 + `Skill.toolDeclarations`），29.5 让"过滤"用上新声明，并打通两条独立消费路径（subagent `filterTools` 与 skill `executeSkill`）到同一 helper。

- **NEW**: `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`（同文件追加）
  - `ToolFilterDiagnostics` struct（`unmatchedDeclarations` / `patternDeclarations`）
  - `ToolFilterOptions` struct（minimal）
  - `filterToolsByDeclarations(available:allowed:disallowed:options:)` 自由函数（纯函数）
  - `ToolDeclaration.parse(_:)` static（从 SkillLoader 上提的 tokenize 单 token 逻辑）
  - `ToolDeclaration.fromToolNames(_:)` static（字符串列表 → 声明数组）
  - 移入 `tokenizeToolDeclaration` / `splitBaseAndPattern` / `isMCPNamespacedName` / `ClaudeCodeToolNames`
- **MODIFY**: `Sources/OpenAgentSDK/Skills/SkillLoader.swift` —— `parseToolDeclarations` 内部改用 `ToolDeclaration.parse`（逻辑外移，行为不变）
- **MODIFY**: `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` —— `filterTools` 用 `fromToolNames` + `filterToolsByDeclarations` 替换字符串 Set 匹配；保留 `SubAgentLauncherNames` 剥离；新增 `filterToolsWithDiagnosticsForTesting`
- **MODIFY**: `Sources/OpenAgentSDK/Core/Agent.swift` —— `executeSkill` / `executeSkillStream` 优先 `toolDeclarations`，fallback `toolRestrictions`；`assembleFullToolPool` 加 `allowedToolDeclarations` 二次过滤
- **MODIFY**: `Sources/OpenAgentSDK/Types/AgentTypes.swift` —— `AgentOptions` 新增 `allowedToolDeclarations: [ToolDeclaration]?`（默认 nil）
- **MODIFY**: `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` —— 元数据 dict 新增 `toolDeclarations` 字段
- **MODIFY**: `Sources/OpenAgentSDK/OpenAgentSDK.swift` —— Skill System 文档区段索引新类型

**不改（回归保护 / AC7）：** `ToolRegistry.filterTools`（字符串版）、`assembleToolPool`、`ToolRestrictionStack`、`parseAllowedTools`（旧）、`ToolRestriction` enum（不加 `.task`）、6 个 BuiltInSkills 的 `toolRestrictions` 初始化。

## Acceptance Criteria → 测试映射

| AC | 描述 | 测试名 | 套件 | 优先级 | 红? |
|----|------|--------|------|--------|-----|
| AC1 | `ToolFilterDiagnostics` 公开 Sendable+Equatable，含两个字段 | `testToolFilterDiagnostics_isPublicEquatableStruct` | ToolDeclarationFilter | P0 | YES — `Cannot find 'ToolFilterDiagnostics' in scope` |
| AC1 | `filterToolsByDeclarations` 可调用、返回元组 | `testFilterToolsByDeclarations_callableAndReturnsTuple` | ToolDeclarationFilter | P0 | YES — `Cannot find 'filterToolsByDeclarations' in scope` |
| AC1 | `ToolFilterOptions` 有默认 init | `testToolFilterOptions_hasDefaultInit` | ToolDeclarationFilter | P0 | YES — `Cannot find 'ToolFilterOptions' in scope` |
| AC2 | allowed 只保留匹配工具；未匹配声明进 diagnostics | `testFilter_preservesOnlyAllowedTools` | ToolDeclarationFilter | P0 | YES — `parse` 不存在 |
| AC2 | 大小写不敏感匹配 | `testFilter_caseInsensitive` | ToolDeclarationFilter | P0 | YES — 同上 |
| AC3 | MCP 声明匹配无需 enum case | `testFilter_mcpDeclaration_matchesWithoutEnumCase` | ToolDeclarationFilter | P0 | YES — 同上 |
| AC4 | 声明但无可用工具 → diagnostics，绝不 unrestricted | `testFilter_unknownDeclaration_notUnrestricted` | ToolDeclarationFilter | P0 | YES — 同上 |
| AC4 | 全部 unmatched 仍空池（红线 stress） | `testFilter_allDeclarationsUnmatched_poolStillEmpty` | ToolDeclarationFilter | P1 | YES — 同上 |
| AC2 | disallowed 优先于 allowed | `testFilter_disallowed_overridesAllowed` | ToolDeclarationFilter | P0 | YES — 同上 |
| AC2 | nil allowed 返回全部 | `testFilter_nilAllowed_returnsAll` | ToolDeclarationFilter | P0 | YES — 同上 |
| AC2 | 空 allowed 数组等同 nil | `testFilter_emptyAllowed_returnsAll` | ToolDeclarationFilter | P1 | YES — 同上 |
| AC2+pattern | pattern 声明按 base name 匹配 + 进 diagnostics | `testFilter_patternDeclaration_matchesByBaseNameAndSurfacesInDiagnostics` | ToolDeclarationFilter | P0 | YES — 同上 |
| AC2 | `fromToolNames` 保留顺序/pattern/MCP | `testFromToolNames_preservesOrderAndPatternAndMCP` | ToolDeclarationFilter | P0 | YES — `fromToolNames` 不存在 |
| AC2 | `fromToolNames([])` 返回空数组 | `testFromToolNames_empty_returnsEmptyArray` | ToolDeclarationFilter | P1 | YES — 同上 |
| AC5 | `ToolDeclaration.parse(_:)` 单 token 分类 | `testParse_singleToken_classifiesCorrectly` | ToolDeclarationFilter | P0 | YES — `parse` 不存在 |
| AC2 | 子代理 filterTools 用 declaration 路径 | `testFilterTools_declarationBased_keepsOnlyMatching` | DefaultSubAgentSpawner | P0 | YES — `filterToolsWithDiagnosticsForTesting` 不存在 |
| AC3 | 子代理保留 MCP 工具 | `testFilterTools_mcpAllowed_keepsMcp` | DefaultSubAgentSpawner | P0 | YES — 同上 |
| AC4 | 子代理声明但无可用 → 空 | `testFilterTools_unknownAllowed_notUnrestricted` | DefaultSubAgentSpawner | P0 | YES — 同上 |
| AC7 | 子代理 launcher 剥离不变（29.2 回归） | `testFilterTools_launcherStrippingStillWorks` | DefaultSubAgentSpawner | P0 | YES — 同上（wrapper 缺失致编译失败） |
| AC2+pattern | 子代理 pattern 按 base 匹配 | `testFilterTools_patternInAllowed_matchesByBaseName` | DefaultSubAgentSpawner | P0 | YES — 同上 |
| AC6 | SkillTool 元数据含 `toolDeclarations`（非空时） | `testSkillTool_toolDeclarations_includedInJSON_whenPresent` | SkillTool | P0 | YES — `fromToolNames` 不存在（编译失败） |
| AC6 | SkillTool 无声明时行为不变（向后兼容） | `testSkillTool_toolDeclarations_absent_whenSkillHasNone` | SkillTool | P0 | YES — 同上（同文件编译失败） |
| AC5 | `AgentOptions.allowedToolDeclarations` 默认 nil | `testExecuteSkill_agentOptions_allowedToolDeclarations_defaultsToNil` | ExecuteSkill | P0 | YES — `allowedToolDeclarations` 字段不存在 |
| AC5 | skill 执行设置 + 恢复 `allowedToolDeclarations` | `testExecuteSkill_toolDeclarations_appliedAndRestored` | ExecuteSkill | P0 | YES — `fromToolNames` 不存在 |
| AC5 | MCP 声明可经 helper 保留（headline 修复） | `testExecuteSkill_mcpDeclarationSurvivableViaFilterHelper` | ExecuteSkill | P0 | YES — `filterToolsByDeclarations` / `fromToolNames` 不存在 |
| AC5 | 无声明时 fallback 旧 `toolRestrictions` 路径 | `testExecuteSkill_fallsBackToToolRestrictions_whenNoDeclarations` | ExecuteSkill | P0 | YES — 同文件编译失败（`allowedToolDeclarations` 引用） |

### 覆盖总结

- **26 个 RED 测试**（今日失败，实现后转绿）：覆盖 AC1（helper/diagnostics/options 类型存在）、AC2（匹配规则核心：精确/大小写不敏感/disallowed 优先/nil+empty 边界）、AC3（MCP 无需 enum case）、AC4（不静默放权红线，单 unmatched + 全 unmatched）、AC2+pattern（pattern 按 base 匹配 + diagnostics）、AC5（AgentOptions 新字段默认值/应用/恢复/fallback + MCP 经 helper 保留）、AC6（SkillTool 元数据 richer + 向后兼容）、AC7（launcher 剥离回归保护）
- **回归保护**：现有 28 个 `ToolRestrictionStackTests`、`ToolRegistryTests.filterTools_*`、`DefaultSubAgentSpawnerTests` 29.2 的 5 个、`SkillLoaderTests.parseToolDeclarations_*` 29.4 的 10 个全部**不被本 story 改动**，绿阶段验证它们继续通过
- **AC7**（签名不变）+ **AC8**（build + 全量回归）是 dev-story 关注点；ATDD 阶段通过编译失败（feature missing）确认 RED，绿阶段由 `bmad-dev-story` 验证签名稳定 + 全量 `swift test`
- **E2E** 推迟到 Story 29.7

## Red-Phase 验证策略

由于本 story 引入的 `ToolFilterDiagnostics` / `ToolFilterOptions` / `filterToolsByDeclarations` / `ToolDeclaration.parse(_:)` / `ToolDeclaration.fromToolNames(_:)` / `DefaultSubAgentSpawner.filterToolsWithDiagnosticsForTesting` / `AgentOptions.allowedToolDeclarations` 在源码中**尚不存在**，新测试在**编译阶段**即失败（`Cannot find ... in scope` / `has no member ...`）。这是预期的 RED 行为 —— 编译失败等同于测试失败。

**已执行的验证：**

1. `swift build`（SDK 源码）→ **SUCCESS**（0 错误）—— 确认 feature 尚未实现，SDK 本身干净
2. `swift build --build-tests` → **FAILURE**（142 个错误），全部归因于本 story 待实现的符号：
   - `Cannot find 'ToolFilterDiagnostics' in scope`（4）
   - `Cannot find 'ToolFilterOptions' in scope`（4）
   - `Cannot find 'filterToolsByDeclarations' in scope`（22）
   - `has no member 'parse'`（30）—— `ToolDeclaration.parse`
   - `has no member 'fromToolNames'`（10）
   - `has no member 'filterToolsWithDiagnosticsForTesting'`（10）
   - `has no member 'allowedToolDeclarations'`（2）
   - `has no member 'recognizedMCP'`/`recognizedSDK`/`unknown`（8）—— 这些是 `ToolDeclaration.parse(...).status == .recognizedMCP` 比较的级联失败：`parse` 不存在 → `.status` 类型未知 → case 无法解析。`parse` 实现后这些自动转绿
3. **本 RED 阶段无需运行 `swift test`** —— 测试不能编译，无运行时失败可枚举。绿阶段实现后所有新测试应转绿。

> 红相模式：COMPILE-TIME（与 Story 29.4 同形）。与 29.3 的运行时断言失败红相互补，两者都是合法 TDD 红相。

## 观察策略

- **`filterToolsByDeclarations` / `parse` / `fromToolNames` 是纯函数/static method** → 直接调用断言，无 mock（rule #27）
- **`DefaultSubAgentSpawner.filterToolsWithDiagnosticsForTesting`** → 复用现有 `DefaultSubAgentSpawnerTests` 的 `createBashTool()` / `createReadTool()` / `createAgentTool()` / `createTaskTool()` / `makeMockClient()` 夹具；MCP-named 工具用本地 `defineTool(name:)` stub（无真实 MCP I/O）
- **`SkillTool` 元数据测试** → 复用现有 `SkillRegistry` + `createSkillTool(registry:)` + `ToolContext(cwd:)` 模式；构造带 `toolDeclarations` 的 `Skill` 直接 init
- **`executeSkill` 路径测试** → 复用现有 `driveExecuteSkillAndCaptureRawBody(skill:args:)` helper + `SkillRequestRecordingURLProtocol`（mock AnthropicClient，无真实网络 I/O）
- **`AgentOptions.allowedToolDeclarations`** → 直接构造 `AgentOptions(...)` 断言新字段默认 nil（向后兼容）
- **`assembleFullToolPool` 集成** → 通过 `filterToolsByDeclarations` 直接断言"MCP 声明保留"（headline 修复）。完整 LLM 驱动的工具池检查是 E2E 关注点，推迟到 29.7

## 遵循的约定

- **XCTest only**（project-context.md #23）—— 不用 Swift Testing（与现有 29.1-29.4 测试一致）
- **测试位置镜像源码**（rule #24）：`filterToolsByDeclarations` 在 `Types/ToolDeclaration.swift` → 新建 `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`；`DefaultSubAgentSpawner.filterTools` 改造 → 扩展 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`；`SkillTool` → 扩展 `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`；`executeSkill` → 扩展 `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift`
- **纯函数测试，无外部 I/O**（rule #27）：helper 是纯函数；executeSkill 路径用 mock AnthropicClient；MCP-named 工具用 `defineTool` stub
- **新建测试文件仅 `ToolDeclarationFilterTests.swift`**（全新 Types/ 层 helper，镜像源码 rule #23）；其余 3 个文件扩展（rule #56 复用现有）
- **无 `Task` Swift 类型引入**（rule #15）：测试中 `"Task"` 只是声明字符串值
- **无 force-unwrap**（rule #40）：optional 解包用 `guard let` / `XCTAssertNotNil` + `?.` 链；现有测试的 `!` 是 pre-existing pattern，本 story 不引入新的
- **Array 而非 Set**（rule #46）：declarations / filtered / diagnostics 均保持顺序（Array）；测试用 `Set()` 仅用于无序比较断言
- **无内联 JSONEncoder/Decoder 用于新逻辑**（rule #48）：SkillTool 元数据断言用现有 `JSONSerialization` 模式（与同文件其他测试一致）
- **E2E 推迟**到 Story 29.7（rule #29）
- **单一职责测试**：每个测试断言一个明确语义点

## 设计决策

- **`testExecuteSkill_toolDeclarations_appliedAndRestored` 是结构性 + 编译性红测试**：由于 `driveExecuteSkillAndCaptureRawBody` 内部构造 agent 且作用域结束，无法跨 helper 断言 `agent.options.allowedToolDeclarations` 的运行时值。红阶段的契约是**字段存在**（编译可过）+ 执行不崩。深度的运行时保留断言（在 `assembleFullToolPool` 出口检查 pool）依赖绿阶段 helper 接入，属 dev-story 范围；本测试确保字段存在 + skill 可执行（fallback 路径不被破坏）。
- **`testExecuteSkill_mcpDeclarationSurvivableViaFilterHelper` 是 headline 修复的代理测试**：完整 LLM 驱动的工具池 MCP 保留检查是 E2E（29.7）。本测试通过直接调 `filterToolsByDeclarations(available: [Bash, mcp__srv__search], allowed: [Bash, mcp__srv__search])` 断言"MCP 工具存活"——这是 `assembleFullToolPool` 在 `allowedToolDeclarations` 非空时**将**调用的同一路径。绿阶段 helper 实现后此测试转绿，证明 MCP 声明在过滤层不被丢弃。
- **`testSkillTool_toolDeclarations_absent_whenSkillHasNone` 的运行时红相**：SkillToolTests.swift 整体因 `fromToolNames`（同文件前一测试用）缺失而**编译失败**，故此测试今日也是编译红。绿阶段 `fromToolNames` 存在后，此测试转为**运行时断言**：今日 SkillTool.swift 不 emit `toolDeclarations` key（无此分支），断言通过（legacy 行为）；但 AC6 要求**当 declarations 非空时 emit**，前一测试 `testSkillTool_toolDeclarations_includedInJSON_whenPresent` 捕获该需求。两个测试配合覆盖"何时 emit / 何时缺席"。
- **回归保护测试不重复编写**：现有 28 个 `ToolRestrictionStackTests`、`ToolRegistryTests.filterTools_*`、29.2 的 5 个 `filterTools_*`、29.4 的 10 个 `parseToolDeclarations_*` 已覆盖回归面。本 story 显式不改这些路径（AC7），清单记录边界，不在 RED 阶段重复生成。
- **不生成 E2E 脚手架**：epic 明确 E2E 推迟到 29.7（rule #29）。本 story 所有测试是单元/集成级，mock 外部依赖。

## 文件修改清单

### `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`（**新建**）
- 全新文件，26 个测试中的 15 个（helper / diagnostics / options / parse / fromToolNames 纯函数测试）
- 复用项目 `defineTool(...)` 构造 stub `ToolProtocol`（无真实工具副作用）

### `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`（扩展）
- 新增 `// MARK: - Story 29.5: Declaration-Based Filtering` 区段（文件末尾，`mapQueryResultToSubAgentResult` 测试之后）
- 新增 5 个 declaration-based filter 测试 + `makeStubTool(name:)` 私有 helper

### `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`（扩展）
- 新增 `// MARK: - Story 29.5: SkillTool richer toolDeclarations metadata` 区段（文件末尾）
- 新增 2 个 SkillTool 元数据测试（richer field 存在 + 向后兼容缺席）

### `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift`（扩展）
- 新增 `// MARK: - Story 29.5: Declaration-Based Tool Filtering on the Skill Execution Path` 区段（ExecuteSkillTests 类末尾，URLProtocol 类之前）
- 新增 4 个 executeSkill 路径测试（AgentOptions 新字段默认值 / 应用恢复 / MCP 经 helper 保留 / fallback）

## 下一步

- 移交 **bmad-dev-story** 实现 GREEN 阶段：
  1. `Sources/OpenAgentSDK/Types/ToolDeclaration.swift` 追加 `ToolFilterDiagnostics` / `ToolFilterOptions` / `filterToolsByDeclarations` / `ToolDeclaration.parse` / `ToolDeclaration.fromToolNames`（Task 1, 5）
  2. `Sources/OpenAgentSDK/Skills/SkillLoader.swift` `parseToolDeclarations` 内部改用 `ToolDeclaration.parse`（Task 5.1-5.2，行为不变）
  3. `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` `filterTools` 改造 + `filterToolsWithDiagnosticsForTesting`（Task 2）
  4. `Sources/OpenAgentSDK/Types/AgentTypes.swift` `AgentOptions` 加 `allowedToolDeclarations`（Task 3.2）
  5. `Sources/OpenAgentSDK/Core/Agent.swift` `executeSkill` / `executeSkillStream` / `assembleFullToolPool` 接入（Task 3.1, 3.3-3.5）
  6. `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` 元数据增强（Task 4）
  7. `Sources/OpenAgentSDK/OpenAgentSDK.swift` 文档索引（Task 1.5）
  8. 验证 26 个 RED 测试全部转绿；现有回归测试继续通过；运行全量 `swift test` 报告总测试数（baseline 5738）
- GREEN 完成后运行 `bmad-testarch-trace` 生成 traceability matrix
- E2E 在 Story 29.7 补齐
