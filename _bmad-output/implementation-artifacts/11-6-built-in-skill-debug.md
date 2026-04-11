# Story 11.6: 内置技能 -- Debug

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 具有 Debug 技能，
以便它可以分析错误信息、定位根因并提供修复建议。

## Acceptance Criteria

1. **AC1: DebugSkill 注册与 promptTemplate 执行错误分析和根因定位** -- 给定 DebugSkill 已注册到 SkillRegistry，当 LLM 调用 debug 技能，则技能的 promptTemplate 指导 Agent 分析错误信息、定位根因并提供修复建议（FR53）。且 DebugSkill 的 `toolRestrictions` 包含 Read、Grep、Glob、Bash（需要运行诊断命令）。

2. **AC2: 输出包含根因分析、复现步骤和具体修复建议** -- 给定 DebugSkill 的 promptTemplate，当技能执行，则输出包含：错误根因分析、复现步骤（如适用）、具体修复建议（引用文件名和行号，格式：`path/to/file.swift:行号`）。

3. **AC3: 多根因排序** -- 给定 DebugSkill 的 promptTemplate，当技能执行并发现多个可能的根因，则 promptTemplate 指导按可能性排序输出。

## Tasks / Subtasks

- [x] Task 1: 更新 BuiltInSkills.debug 的 promptTemplate (AC: #1, #2, #3)
  - [x] 更新 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 中 `BuiltInSkills.debug` 的 `promptTemplate`
  - [x] promptTemplate 必须包含结构化调试流程：读取错误信息 → 查看相关源文件 → 运行诊断命令 → 分析根因 → 提供修复建议（AC1）
  - [x] promptTemplate 必须指导使用 Read/Grep 查看源文件、Bash 运行诊断命令（如构建命令、git log）（AC1）
  - [x] 每个发现必须引用具体文件名和行号（格式：`path/to/file.swift:行号`）（AC2）
  - [x] promptTemplate 必须要求输出根因分析、复现步骤和修复建议三个部分（AC2）
  - [x] promptTemplate 必须指导多个根因时按可能性排序（AC3）
  - [x] 更新 `description` 字段使其更精确

- [x] Task 2: 更新 BuiltInSkills.debug 的 toolRestrictions 和元数据 (AC: #1)
  - [x] 设置 `toolRestrictions: [.read, .grep, .glob, .bash]`（读取文件 + 搜索代码 + 运行诊断命令）
  - [x] 确认 `aliases: ["investigate", "diagnose"]` 保持不变
  - [x] 确认 `userInvocable: true`
  - [x] 确认 `isAvailable` 默认为 `{ true }`

- [x] Task 3: 编写单元测试 (AC: #1-#3)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift`
  - [x] 测试 BuiltInSkills.debug 的所有属性值（name、aliases、toolRestrictions、userInvocable）
  - [x] 测试 promptTemplate 包含根因分析关键词（root cause / 根因）
  - [x] 测试 promptTemplate 包含复现步骤关键词（reproduce / 复现）
  - [x] 测试 promptTemplate 包含修复建议关键词（fix / 修复 / suggestion）
  - [x] 测试 promptTemplate 包含文件名和行号引用格式要求（`file.swift:行号` 或等效）
  - [x] 测试 promptTemplate 包含多根因排序要求（possibility / likelihood / 可能性排序）
  - [x] 测试 promptTemplate 包含诊断工具使用指导（Bash / Read / Grep）
  - [x] 测试 SkillRegistry 可以注册和查找 BuiltInSkills.debug
  - [x] 测试 registry.replace() 可以覆盖 debug 技能的 promptTemplate

- [x] Task 4: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第六个 Story
- **核心目标：** 精化 Debug 技能的 promptTemplate，使其完全符合 epics.md 中的验收标准。BuiltInSkills.debug 的基础结构已在 Story 11.1 中创建，本 Story 仅需更新 promptTemplate 文本和补充单元测试
- **前置依赖：** Story 11.1（Skill 类型定义和 SkillRegistry）、Story 11.2（SkillTool 执行工具）
- **后续依赖：** 无直接后续依赖（Story 11.7 Test 技能独立实现）
- **FR 覆盖：** FR53（内置技能的 promptTemplate 指导 Agent 执行特定工作流）

### 关键发现：当前 promptTemplate 与 epics 要求的差异

**当前 promptTemplate（Story 11.1 中创建的骨架）：**
```
Debug the described issue using a systematic approach:

1. **Reproduce**: Understand and reproduce the issue
   - Read relevant error messages or logs
   - Identify the failing component

2. **Investigate**: Trace the root cause
   - Read the relevant source code
   - Add logging or use debugging tools if needed
   - Check recent changes that might have introduced the issue (`git log --oneline -20`)

3. **Hypothesize**: Form a theory about the cause
   - State your hypothesis clearly before attempting a fix

4. **Fix**: Implement the minimal fix
   - Make the smallest change that resolves the issue
   - Don't refactor unrelated code

5. **Verify**: Confirm the fix works
   - Run relevant tests
   - Check for regressions
```

**epics.md 要求（必须对齐）：**
1. toolRestrictions 包含 Read、Grep、Glob、Bash -- 当前 skeleton 缺少 toolRestrictions（为 nil），需要添加
2. 输出包含根因分析、复现步骤、修复建议（引用文件名和行号） -- 当前 skeleton 有 "Hypothesize" 和 "Fix" 但缺少明确的文件名:行号引用格式要求
3. 多个可能根因时按可能性排序 -- 当前 skeleton 完全缺少此要求

**需要修改的关键点：**
- 添加 `toolRestrictions: [.read, .grep, .glob, .bash]`
- 增加明确的文件名:行号引用格式要求（`path/to/file.swift:行号`）
- 增加多根因排序输出指令
- 将 "Fix" 和 "Verify" 步骤改为仅提供建议而非实际修改（因为 Debug 技能应定位为诊断工具，修复建议比直接修改更安全；且与 epics 骨架的"提供修复建议"一致）
- 增加构建失败和运行时崩溃两种场景的具体处理指导
- 更新 `description` 字段

### TypeScript SDK 参考映射

| Swift 类型/属性 | TypeScript 对应 | 文件 |
|---|---|---|
| `BuiltInSkills.debug` | `registerDebugSkill()` | `src/skills/bundled/debug.ts` |
| `promptTemplate` (静态字符串) | `DEBUG_PROMPT` + `getPrompt(args)` (动态) | `src/skills/bundled/debug.ts` |
| `toolRestrictions: [.read, .grep, .glob, .bash]` | 无显式 allowedTools（TS SDK 不限制） | -- |

**关键差异：**
- TS SDK 的 debug 技能不限制工具（无 `allowedTools`）。Swift 版本按 epics.md 要求限制为 Read、Grep、Glob、Bash
- TS SDK 的 `getPrompt()` 接收 `args` 参数。Swift v1.0 的 `promptTemplate` 是静态字符串
- epics.md 的 promptTemplate 骨架与当前 skeleton 有结构差异 -- epics 要求输出根因分析 + 复现步骤 + 修复建议三部分，当前 skeleton 是 Reproduce → Investigate → Hypothesize → Fix → Verify 五步流程

### 已有代码模式参考

**BuiltInSkills.debug 当前定义（SkillTypes.swift:295-325）：**
```swift
public static var debug: Skill {
    Skill(
        name: "debug",
        description: "Systematic debugging of an issue using structured investigation.",
        aliases: ["investigate", "diagnose"],
        userInvocable: true,
        promptTemplate: """
        Debug the described issue using a systematic approach:
        ...
        """
    )
}
```

本 Story 需更新 `promptTemplate` 字符串内容、`description`，并添加 `toolRestrictions`。

**Story 11.5 (Simplify) 的实现模式（应完全遵循）：**
- 仅更新 promptTemplate 文本、description 和 toolRestrictions，不修改 Skill struct / SkillRegistry / SkillTool
- 创建 `DebugSkillTests.swift` 在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 下
- 测试覆盖所有 AC，验证 promptTemplate 文本内容（不 mock 工具调用）
- 运行完整测试套件确认无回归

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- 修改：更新 `BuiltInSkills.debug` 的 `promptTemplate`、`description` 和添加 `toolRestrictions`
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift` -- 新建：单元测试

```
Sources/OpenAgentSDK/
├── Types/
│   ├── SkillTypes.swift              # 修改：BuiltInSkills.debug promptTemplate + description + toolRestrictions
│   └── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── BuiltInSkills/
│   │   ├── CommitSkillTests.swift    # 已有（Story 11.3）
│   │   ├── ReviewSkillTests.swift    # 已有（Story 11.4）
│   │   ├── SimplifySkillTests.swift  # 已有（Story 11.5）
│   │   ├── DebugSkillTests.swift     # 新建
│   │   └── ...
│   └── ...
└── ...
```

### Logger 集成约定

本 Story 不涉及新增 Logger 调用点（仅更新 promptTemplate 文本）。

### 反模式警告

- **不要**修改 Skill struct、SkillRegistry 或 SkillTool 的任何代码 -- 仅更新 BuiltInSkills.debug 的 promptTemplate 字符串、description 和 toolRestrictions
- **不要**将 DebugSkill 改为动态 prompt 生成 -- 使用静态 promptTemplate（与 TypeScript SDK v1.0 对齐）
- **不要**创建新的类型或文件来存放 promptTemplate -- 保持 BuiltInSkills.debug 作为内联定义
- **不要**修改 BuiltInSkills.commit、BuiltInSkills.review、BuiltInSkills.simplify 等其他技能 -- 它们是其他 Story 的范围
- **不要**在 promptTemplate 中指导 Agent "直接修复" 问题 -- epics 骨架要求"提供修复建议"（诊断工具定位，不是自动化修复工具）
- **不要**在测试中 mock BashTool -- 单元测试只验证 promptTemplate 文本内容，不验证工具调用行为
- **不要**遗漏"无错误信息"处理 -- promptTemplate 必须处理用户未提供具体错误信息的场景
- **不要**修改 BuiltInSkills.test 技能 -- 它是 Story 11.7 的范围

### 测试策略

单元测试覆盖所有 AC，完全遵循 CommitSkillTests / ReviewSkillTests / SimplifySkillTests 的模式：

1. **AC1 测试**：promptTemplate 包含根因分析关键词（root cause / 根因）；toolRestrictions 为 [.read, .grep, .glob, .bash]；promptTemplate 指导使用 Read/Grep 查看源文件和 Bash 运行诊断命令
2. **AC2 测试**：promptTemplate 包含文件名和行号引用格式要求（`file.swift:行号` 或等效表达）；输出结构包含根因分析、复现步骤、修复建议
3. **AC3 测试**：promptTemplate 包含多根因排序要求（按可能性/likelihood 排序）
4. **元数据测试**：验证 name、aliases（investigate, diagnose）、toolRestrictions、userInvocable 属性
5. **Registry 测试**：验证 register/find/replace 操作对 debug 技能正常工作

**测试隔离：**
- 使用 `SkillRegistry()` 创建独立注册表
- 测试 `BuiltInSkills.debug` 返回的 Skill 实例属性
- 不需要 mock LLM 或工具 -- 仅验证 promptTemplate 文本内容

### 前序 Story 学习要点

**Story 11.1 完成情况：**
- SkillTypes.swift: ToolRestriction enum (22 cases), Skill struct (Sendable), BuiltInSkills namespace (5 skills)
- SkillRegistry.swift: final class + DispatchQueue, 支持完整的注册、查找、替换、列表 API
- BuiltInSkills.debug 的骨架 promptTemplate 已存在但需要精化

**Story 11.2 完成情况：**
- SkillTool.swift: 通过 defineTool 创建，返回 JSON 格式的 ToolResult
- ToolRestrictionStack.swift: 栈模型管理工具限制
- ToolContext 新增 skillRegistry、restrictionStack、skillNestingDepth、maxSkillRecursionDepth

**Story 11.3 完成情况：**
- 仅更新了 BuiltInSkills.commit 的 promptTemplate 和 description
- 创建了 CommitSkillTests.swift（26 个测试）
- 完整测试套件: 2177 tests, 0 failures, 4 skipped
- **关键学习：** 测试只验证 promptTemplate 文本内容，不 mock 工具调用。这确保测试快速且可靠。

**Story 11.4 完成情况：**
- 仅更新了 BuiltInSkills.review 的 promptTemplate 和 description
- 创建了 ReviewSkillTests.swift（31 个测试）
- 完整测试套件: 2208 tests passing, 4 skipped, 0 failures

**Story 11.5 完成情况（本 Story 的直接参考）：**
- 仅更新了 BuiltInSkills.simplify 的 promptTemplate、description 和 toolRestrictions
- 创建了 SimplifySkillTests.swift（31 个测试）
- 完整测试套件: 2239 tests passing, 4 skipped, 0 failures
- **关键学习：** 与 Story 11.3/11.4 完全一致的模式 -- 仅更新 promptTemplate 文本，测试验证文本内容

**关键接口（本 Story 直接使用）：**
- `BuiltInSkills.debug` -- 返回 Skill 实例（值类型，每次返回新实例）
- `SkillRegistry.register(_ skill:)` -- 注册技能
- `SkillRegistry.replace(_ skill:)` -- 替换技能
- `SkillRegistry.find(_ name:) -> Skill?` -- 按名称或别名查找
- `Skill.promptTemplate` -- promptTemplate 字符串属性

### Project Structure Notes

- DebugSkillTests 放在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 目录下（已存在，Story 11.3 创建），与 CommitSkillTests、ReviewSkillTests 和 SimplifySkillTests 并列
- 完全对齐架构文档的目录结构：`Tests/OpenAgentSDKTests/Tools/` 下按功能分组

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.6] -- 验收标准和需求定义（promptTemplate 骨架和三项 AC）
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] -- Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR53] -- 内置技能功能需求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] -- 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Actor/struct 边界、命名约定、反模式
- [Source: open-agent-sdk-typescript/src/skills/bundled/debug.ts] -- TypeScript SDK Debug 技能实现（DEBUG_PROMPT 文本和注册逻辑）
- [Source: open-agent-sdk-typescript/src/skills/types.ts] -- TypeScript SDK SkillDefinition 接口
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:295-325] -- BuiltInSkills.debug 当前定义（需更新 promptTemplate、添加 toolRestrictions）
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] -- SkillRegistry（register/replace/find 用于测试）
- [Source: _bmad-output/implementation-artifacts/11-5-built-in-skill-simplify.md] -- Story 11.5 开发记录（模式参考）
- [Source: Tests/OpenAgentSDKTests/Tools/BuiltInSkills/SimplifySkillTests.swift] -- 测试模式参考

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Initial run: 19 failures, 13 passes (32 total ATDD tests)
- After promptTemplate update: 2 failures remaining
  - testAC1_PromptTemplate_DoesNotInstructDirectFix: "Do not directly implement the fix" contained "implement the fix" substring
  - testAC3_PromptTemplate_HandlesMultipleRootCauses: "multiple possible root causes" did not match "multiple root cause" substring
- Fix: Rephrased to "Do not make any code changes" and changed "multiple possible root causes" to "multiple root causes"
- Final run: 32 passes, 0 failures

### Completion Notes List

- Updated BuiltInSkills.debug promptTemplate with structured 4-step diagnostic workflow: Understand -> Gather Info -> Analyze Root Cause -> Report Findings
- Added toolRestrictions: [.read, .grep, .glob, .bash] for read-only diagnostic capability
- Updated description to reflect diagnostic/analysis purpose
- promptTemplate includes: root cause analysis, reproduction steps, suggested fix sections with file:line references
- promptTemplate handles: no error message scenario, build failure/compilation error, runtime crash/exception, multiple root causes sorted by likelihood
- All 32 ATDD tests pass; full suite: 2271 tests passing, 4 skipped, 0 failures

### File List

- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- Modified: Updated BuiltInSkills.debug promptTemplate, description, and added toolRestrictions
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift` -- No changes (ATDD tests created by testarch phase, unchanged during dev)

### Review Findings

- [x] [Review][Patch] Stale ATDD comment "All tests FAIL (TDD red phase)" in DebugSkillTests.swift:8 [Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift:8] -- fixed: updated to "All tests PASS" to match sibling skill test files

## Change Log

- 2026-04-12: Story 11.6 implementation complete. Updated BuiltInSkills.debug promptTemplate with structured diagnostic workflow, added toolRestrictions [.read, .grep, .glob, .bash], updated description. All 32 ATDD tests pass, full suite 2271 tests passing with 0 failures.
- 2026-04-12: Code review (yolo mode). 1 patch (stale ATDD comment -- fixed), 0 decision-needed, 0 deferred, 0 dismissed.
