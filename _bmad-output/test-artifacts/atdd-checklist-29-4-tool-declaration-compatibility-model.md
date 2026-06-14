---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
lastStep: step-04-generate-tests
lastSaved: '2026-06-14'
storyId: '29.4'
storyKey: 29-4-tool-declaration-compatibility-model
storyFile: _bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-29-4-tool-declaration-compatibility-model.md
generatedTestFiles:
  - Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift
  - Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md
  - _bmad-output/project-context.md
---

# ATDD Red-Phase 清单 — Story 29.4: Tool Declaration Compatibility Model

- **Story ID:** 29-4
- **Epic:** 29（Claude Code Skill/Subagent Compatibility）
- **阶段:** RED（TDD 红-绿-重构）
- **模式:** yolo（自动批准）
- **日期:** 2026-06-14
- **测试文件:**
  - `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift`（扩展）
  - `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift`（扩展）
- **Story 规格:** `_bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md`

## 技术栈检测

- **检测到的栈:** backend（Swift Package Manager + XCTest，无浏览器测试层）
- **生成模式:** AI generation（backend 栈无录制模式）
- **执行模式:** sequential（Swift 后端，无 subagent/agent-team 分派）
- **测试级别:** 单元测试（解析器是纯函数，无 LLM/网络/文件 I/O 需求 —— 遵守 project-context.md #27）

## Story 范围回顾

本 story 引入三个新类型 + 一个新解析器，**不修改任何消费方**（Agent.swift / SkillTool.swift / ToolRestrictionStack / DefaultSubAgentSpawner 推迟到 29.5）：

- **NEW**: `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`
  - `ToolDeclarationStatus` enum（`.recognizedSDK` / `.recognizedMCP` / `.recognizedCustom` / `.unknown`）
  - `ToolDeclaration` struct（`rawName` / `normalizedName` / `pattern` / `status` / `toolRestriction`）
  - `ToolDeclarationDiagnostics` struct（`unsupportedDeclarations` / `patternDeclarations`）
- **MODIFY**: `Sources/OpenAgentSDK/Types/SkillTypes.swift` —— `Skill` 新增两个可选字段（带默认值 nil）
- **MODIFY**: `Sources/OpenAgentSDK/Skills/SkillLoader.swift` —— 新增 `parseToolDeclarations(_:)`，`loadSkillFromDirectory` 填充新字段，**保留** `parseAllowedTools` 完全不变（AC4 回归保护）

## Acceptance Criteria → 测试映射

| AC | 描述 | 测试名 | 套件 | 优先级 | 红? |
|----|------|--------|------|--------|-----|
| AC1 | MCP namespaced 工具声明被保留（不丢弃 `mcp__github__list_prs`） | `testParseToolDeclarations_preservesMCPNamespacedNames` | SkillLoader | P0 | YES — `Cannot find 'parseToolDeclarations' in scope`（类型/方法尚不存在） |
| AC2 | 未知工具名不 collapse 为 unrestricted（返回非 nil） | `testParseToolDeclarations_doesNotCollapseToUnrestricted` | SkillLoader | P0 | YES — 同上 |
| AC2 | 未知工具以 diagnostic 形式可见 | `testParseToolDeclarations_unknownToolNotDropped` | SkillLoader | P0 | YES — 同上 |
| AC3 | Permission pattern 文本被保留（`Bash(git diff:*)`） | `testParseToolDeclarations_preservesPatternText` | SkillLoader | P0 | YES — 同上 |
| AC3 | pattern 进入 `patternDeclarations` 诊断 | `testParseToolDeclarations_patternEntersDiagnostics` | SkillLoader | P1 | YES — 同上 |
| AC5 | 常见 SDK/Claude 工具名被识别为 `.recognizedSDK` | `testParseToolDeclarations_recognizesClaudeCodeNames` | SkillLoader | P0 | YES — 同上 |
| AC5 | `Task`（无 enum case）被识别为 SDK 名但 toolRestriction = nil | `testParseToolDeclarations_taskRecognizedButNoEnumCase` | SkillLoader | P1 | YES — 同上 |
| AC1+AC5 | 混合 known/unknown/MCP 同时识别 | `testParseToolDeclarations_mixedKnownUnknownMCP` | SkillLoader | P0 | YES — 同上 |
| 空输入语义 | `nil` / `""` 输入返回 nil（区分 unrestricted 与显式声明） | `testParseToolDeclarations_emptyAndNil` | SkillLoader | P1 | YES — 同上 |
| AC1+AC2+AC3 | `loadSkillFromDirectory` 填充新字段 + 保留旧字段 | `testLoadSkillFromDirectory_populatesToolDeclarations` | SkillLoader | P0 | YES — `Cannot find 'toolDeclarations' in scope`（字段尚不存在） |
| AC4 | 现有 `parseAllowedTools` 旧测试无回归（回归保护） | `testParseAllowedTools_WithArguments` / `testParseAllowedTools_EmptyString` / `testParseAllowedTools_Nil` / `testParseAllowedTools_UnknownToolsIgnored` | SkillLoader | P0 | NO（已存在且通过 —— 本 story 不改旧解析器，这些测试**必须**继续通过；在此记录以明确回归边界） |
| AC4 | `Skill.init` 新参数有默认值，旧调用不破坏 | `testSkill_ToolDeclarations_DefaultsToNil` | SkillTypes | P0 | YES — `Cannot find 'toolDeclarations' in scope` |
| AC4 | `Skill.init` 显式传入 `toolDeclarations` 被正确存储 | `testSkill_ToolDeclarations_ExplicitlySet` | SkillTypes | P0 | YES — 同上 |
| AC4 | `Skill.withBaseDir` 复制新字段 | `testSkill_WithBaseDir_PreservesToolDeclarations` | SkillTypes | P0 | YES — 同上 |
| AC4 | `Skill.==` 比较新字段 | `testSkill_Equality_ConsidersToolDeclarations` | SkillTypes | P0 | YES — 同上 |
| AC2 | `ToolDeclarationStatus` enum 有全部 4 个 case | `testToolDeclarationStatus_AllCases` | SkillTypes | P1 | YES — `Cannot find 'ToolDeclarationStatus' in scope` |

### 覆盖总结

- **14 个 RED 测试**（今日失败，实现后转绿）：覆盖 AC1（MCP 保留）、AC2（不静默放权 + diagnostic 可见）、AC3（pattern 保留 + 诊断）、AC5（SDK/Claude 名识别 + Task gap）、AC4（Skill 新字段向后兼容：init 默认值 / withBaseDir / == / 类型存在性），以及 `loadSkillFromDirectory` 端到端填充验证
- **4 个回归保护测试**（已存在、今日通过）：`testParseAllowedTools_*` 系列。本 story 显式不修改旧解析器（AC4），这些测试**必须**继续通过 —— 红阶段验证会确认它们不受新类型引入影响
- **AC6**（build + 全量回归）是 dev-story 关注点，非 ATDD 脚手架；绿阶段由 `bmad-dev-story` 验证
- **E2E** 推迟到 Story 29.7（project-context.md #29），本 story 不生成 E2E 脚手架

## Red-Phase 验证策略

由于本 story 引入的 `ToolDeclaration` / `ToolDeclarationStatus` / `ToolDeclarationDiagnostics` / `Skill.toolDeclarations` / `Skill.toolDeclarationDiagnostics` / `SkillLoader.parseToolDeclarations` 在源码中**尚不存在**，新测试文件在**编译阶段**就会失败（`Cannot find ... in scope`）。这是预期的 RED 行为 —— 编译失败等同于测试失败。

**验证步骤：**

1. `swift build --target OpenAgentSDK` → 预期 SUCCESS（SDK 源码未改 —— 确认功能尚未实现）
2. `swift build --build-tests` → 预期 FAILURE（新测试引用不存在的类型/方法）
3. **本 RED 阶段无需运行 `swift test`** —— 因为测试不能编译，没有运行时失败需要枚举。绿阶段实现后，所有新测试应转绿。

> 与 Story 29.3 的差异：29.3 的 RED 是运行时断言失败（类型已存在、行为未实现）；本 story 的 RED 是编译时符号缺失（类型/字段/方法尚未引入）。两者都是合法的 TDD 红相。

## 观察策略

- **`parseToolDeclarations` 是 static method** → 直接 `SkillLoader.parseToolDeclarations(...)` 调用，无 mock 需求（纯函数）
- **`loadSkillFromDirectory_populatesToolDeclarations** 复用现有 `TempDirTestCase` 基类 + `createSkillDir` helper（SkillLoaderTests.swift:15-47），通过真实文件系统创建 skill 目录 —— 这是**测试夹具**（rule #27 允许的本地临时目录操作，非外部 I/O；与现有 `testLoadSkillFromDirectory_WithAllowedTools` 一致）
- **`Skill` 类型测试** 直接构造 `Skill(...)` 实例，断言新字段，无 mock
- **无 `@testable import` 改动** —— 新类型将声明为 `public`，测试用 `@testable import OpenAgentSDK` 即可访问

## 遵循的约定

- **XCTest only**（project-context.md #23）
- **测试位置镜像源码**（rule #24）：`parseToolDeclarations` 是 SkillLoader 的 static method → 测试在 `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift`；`ToolDeclaration` / `ToolDeclarationStatus` / `Skill` 新字段在 Types/ → 扩展 `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift`
- **纯函数测试，无外部 I/O**（rule #27）：`parseToolDeclarations` 是字符串→struct 纯函数，直接调用断言；`loadSkillFromDirectory` 测试使用本地 tempdir 夹具（与现有同类测试一致）
- **无新测试文件创建**（story Task 5.3 + rule #56）：扩展现有 `SkillLoaderTests.swift` 和 `SkillTypesTests.swift`
- **无 `Task` Swift 类型引入**（rule #15）：测试中 `"Task"` 只是声明字符串值，类型名用 `ToolDeclaration`
- **无 force-unwrap**（rule #40）：每个 optional 解包用 `guard let` 或 `XCTAssertNotNil` + `?.` 链
- **Array 而非 Set**（rule #46）：declarations 顺序必须保持 frontmatter 顺序
- **无内联 JSONEncoder/Decoder**（rule #48）：解析器是纯字符串→struct 转换，无序列化
- **E2E 推迟**到 Story 29.7（rule #29）—— 本 story 不写 E2E 脚手架
- **单一职责测试**：每个测试断言一个明确的语义点（MCP 保留 / 不 collapse / pattern 保留 / SDK 识别 / 等）

## 设计决策

- **回归保护测试不重复编写**：现有 4 个 `testParseAllowedTools_*` 测试（SkillLoaderTests.swift:491-518）已经覆盖旧解析器行为。本 story 显式不修改旧解析器（AC4），故这些测试**必须**继续通过。清单中记录它们以明确回归边界，但不在本次 RED 阶段重复生成。
- **`testParseToolDeclarations_emptyAndNil` 断言 nil 返回**：这是**正确的** nil 语义区分（`nil` 输入 = 无 frontmatter 字段 = unrestricted；非空但全 unknown = 显式声明但无可用）。与 AC2 的"不静默放权"互补：空输入返回 nil 是 unrestricted，**全 unknown 输入**返回非 nil 是显式受限。两个测试配合覆盖"何时 nil 合法 / 何时 nil 是 bug"。
- **`ToolRestrictionStatus_AllCases` 测试**：story Task 1.3 定义 4 个 case（`recognizedSDK` / `recognizedMCP` / `recognizedCustom` / `unknown`）。测试断言全部存在，防止实现遗漏 case。
- **`Task` 识别但 toolRestriction = nil** 的测试（AC5 + Dev Notes "ToolRestriction gap"）：明确锁定设计决策 —— **不**给 `ToolRestriction` enum 加 `.task`，而是通过 `ToolDeclaration.toolRestriction = nil` + `status = .recognizedSDK` 表达。
- **`loadSkillFromDirectory` 端到端测试**同时断言新旧字段：`skill.toolDeclarations?.count == 3` AND `skill.toolRestrictions?.count == 3`（向后兼容，AC4）。这强制实现**两套字段并存**而非替换。

## 文件修改清单

### `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift`（扩展）
- 新增 `// MARK: - Story 29.4: Tool Declaration Compatibility` 区段（位于文件末尾，`testLoadSkillFromDirectory_WithSupportingFiles` 之后）
- 新增 9 个 `parseToolDeclarations` 单元测试
- 新增 1 个 `loadSkillFromDirectory_populatesToolDeclarations` 集成测试

### `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift`（扩展）
- 新增 `// MARK: - Story 29.4: Tool Declaration Compatibility Model` 区段（位于文件末尾）
- 新增 5 个 `Skill` 新字段 + `ToolDeclarationStatus` 测试

## 下一步

- 移交 **bmad-dev-story** 实现 GREEN 阶段：
  1. 创建 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`（Task 1.1-1.5）
  2. 扩展 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 的 `Skill` struct（Task 2.1-2.5）
  3. 在 `Sources/OpenAgentSDK/Skills/SkillLoader.swift` 新增 `parseToolDeclarations`（Task 3.1-3.6），并在 `loadSkillFromDirectory` 填充新字段（Task 4.1-4.3）
  4. 扩展 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 公共 surface 文档（Task 1.5）
  5. 验证 14 个 RED 测试全部转绿；4 个回归保护测试继续通过；运行全量 `swift test` 报告总测试数（baseline 5720）
- GREEN 完成后运行 `bmad-testarch-trace` 生成 traceability matrix
