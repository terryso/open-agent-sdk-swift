# Story 11.5: 内置技能 -- Simplify

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 具有 Simplify 技能，
以便它可以审查变更代码的复用性、质量和效率。

## Acceptance Criteria

1. **AC1: SimplifySkill 注册与 promptTemplate 执行复用性/质量/效率审查** -- 给定 SimplifySkill 已注册到 SkillRegistry，当 LLM 调用 simplify 技能，则技能的 promptTemplate 指导 Agent 审查变更代码的复用性、质量和效率（FR53）。且 SimplifySkill 的 `toolRestrictions` 限定为 Read、Grep、Glob（只读工具）。

2. **AC2: 输出结构包含三类发现并引用具体位置** -- 给定 SimplifySkill 的 promptTemplate，当技能执行，则输出结构包含：重复代码模式、过度复杂的逻辑、可提取的抽象（具体引用文件名和行号，格式：`path/to/file.swift:行号`）。

3. **AC3: 每个发现提供简化前后对比示例** -- 给定 SimplifySkill 的 promptTemplate，当技能执行并发现可简化项，则 promptTemplate 指导对每个发现提供简化前后的对比示例。

## Tasks / Subtasks

- [x] Task 1: 更新 BuiltInSkills.simplify 的 promptTemplate (AC: #1, #2, #3)
  - [x] 更新 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 中 `BuiltInSkills.simplify` 的 `promptTemplate`
  - [x] promptTemplate 必须包含三类分析：复用性（重复代码、已有工具替代、可提取抽象）、质量（过度复杂逻辑、命名不当、边界缺失、过度工程）、效率（不必要分配、N+1 模式、阻塞操作、低效数据结构）（AC1）
  - [x] promptTemplate 必须使用 git diff/git diff --cached 识别变更文件（只读操作）（AC1）
  - [x] 每个发现必须引用具体文件名和行号（格式：`path/to/file.swift:行号`）（AC2）
  - [x] promptTemplate 必须要求为每个发现提供简化前后对比示例（AC3）
  - [x] 更新 `description` 字段使其更精确

- [x] Task 2: 更新 BuiltInSkills.simplify 的 toolRestrictions 和元数据 (AC: #1)
  - [x] 确认 `toolRestrictions: [.read, .grep, .glob]`（只读工具，不能修改文件）
  - [x] 确认 `aliases` 设置（如有）
  - [x] 确认 `userInvocable: true`
  - [x] 确认 `isAvailable` 默认为 `{ true }`

- [x] Task 3: 编写单元测试 (AC: #1-#3)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/SimplifySkillTests.swift`
  - [x] 测试 BuiltInSkills.simplify 的所有属性值（name、aliases、toolRestrictions、userInvocable）
  - [x] 测试 promptTemplate 包含三类分析关键词（复用/reuse、质量/quality、效率/efficiency）
  - [x] 测试 promptTemplate 包含文件名和行号引用格式要求
  - [x] 测试 promptTemplate 包含简化前后对比示例要求
  - [x] 测试 promptTemplate 包含变更文件识别策略（git diff / git diff --cached）
  - [x] 测试 SkillRegistry 可以注册和查找 BuiltInSkills.simplify
  - [x] 测试 registry.replace() 可以覆盖 simplify 技能的 promptTemplate

- [x] Task 4: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第五个 Story
- **核心目标：** 精化 Simplify 技能的 promptTemplate，使其完全符合 epics.md 中的验收标准。BuiltInSkills.simplify 的基础结构已在 Story 11.1 中创建，本 Story 仅需更新 promptTemplate 文本和补充单元测试
- **前置依赖：** Story 11.1（Skill 类型定义和 SkillRegistry）、Story 11.2（SkillTool 执行工具）
- **后续依赖：** 无直接后续依赖（Story 11.6-11.7 为其他内置技能，独立实现）
- **FR 覆盖：** FR53（内置技能的 promptTemplate 指导 Agent 执行特定工作流）

### 关键发现：当前 promptTemplate 与 epics 要求的差异

**当前 promptTemplate（Story 11.1 中创建的骨架）：**
```
Review the recently changed code for three categories of improvements. Launch 3 parallel Agent sub-tasks:

## Task 1: Reuse Analysis
Look for:
- Duplicated code that could be consolidated
- Existing utilities or helpers that could replace new code
- Patterns that should be extracted into shared functions
- Re-implementations of functionality that already exists elsewhere

## Task 2: Code Quality
Look for:
- Overly complex logic that could be simplified
- Poor naming or unclear intent
- Missing edge case handling
- Unnecessary abstractions or over-engineering
- Dead code or unused imports

## Task 3: Efficiency
Look for:
- Unnecessary allocations or copies
- N+1 query patterns or redundant I/O
- Blocking operations that could be async
- Inefficient data structures for the access pattern
- Unnecessary re-computation

After all three analyses complete, fix any issues found. Prioritize by impact.
```

**epics.md 要求（必须对齐）：**
1. toolRestrictions 限定为 Read、Grep、Glob（只读工具） -- 当前 skeleton 末尾有 "fix any issues found" 但工具限制确保不能修改文件
2. 输出结构包含三类发现（重复代码模式、过度复杂的逻辑、可提取的抽象），具体引用文件名和行号 -- 当前 skeleton 有三类但缺少行号引用格式要求和"可提取的抽象"具体表述
3. 每个发现提供简化前后对比示例 -- 当前 skeleton 完全缺少此要求
4. 变更文件识别策略使用 git diff / git diff --cached -- 当前 skeleton 未提及如何获取变更文件列表

**需要修改的关键点：**
- 增加 git diff / git diff --cached 识别变更文件的步骤
- 增加 Read、Grep、Glob 只读工具使用指导（而非"Launch 3 parallel Agent sub-tasks"）
- 增加明确的文件名:行号引用格式要求
- 增加"为每个发现提供简化前后对比示例"的指令
- 修改尾部指令，从 "fix any issues found" 改为仅分析和报告（因为 toolRestrictions 为只读）
- 增加无变更时的处理指令

### TypeScript SDK 参考映射

| Swift 类型/属性 | TypeScript 对应 | 文件 |
|---|---|---|
| `BuiltInSkills.simplify` | `registerSimplifySkill()` | `src/skills/bundled/simplify.ts` |
| `promptTemplate` (静态字符串) | `SIMPLIFY_PROMPT` + `getPrompt(args)` (动态) | `src/skills/bundled/simplify.ts` |
| `toolRestrictions: [.read, .grep, .glob]` | 无显式 allowedTools（TS SDK 不限制） | -- |

**关键差异：**
- TS SDK 的 simplify 技能不限制工具（无 `allowedTools`），允许修复发现的问题。Swift 版本按 epics.md 要求限制为只读工具（Read、Grep、Glob），因此 promptTemplate 末尾不能指导 Agent "修复"问题，仅分析和报告
- TS SDK 的 `getPrompt()` 接收 `args` 参数，可追加 `Additional Focus`。Swift v1.0 的 `promptTemplate` 是静态字符串，`args` 由 SkillTool 在运行时处理
- TS SDK 的 SIMPLIFY_PROMPT 文本与 Swift 当前骨架几乎一致 -- 本 Story 需要对齐 epics.md 骨架的要求（行号引用、对比示例）

### 已有代码模式参考

**BuiltInSkills.simplify 当前定义（SkillTypes.swift:219-254）：**
```swift
public static var simplify: Skill {
    Skill(
        name: "simplify",
        description: "Review changed code for reuse, quality, and efficiency, then fix any issues found.",
        userInvocable: true,
        promptTemplate: """
        Review the recently changed code for three categories of improvements...
        """
    )
}
```

本 Story 需更新 `promptTemplate` 字符串内容和 `description`。注意 `description` 中的 "then fix any issues found" 应移除（因为只读工具不能修复）。

**Story 11.4 (Review) 的实现模式（应完全遵循）：**
- 仅更新 promptTemplate 文本和 description，不修改 Skill struct / SkillRegistry / SkillTool
- 创建 `SimplifySkillTests.swift` 在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 下
- 测试覆盖所有 AC，验证 promptTemplate 文本内容（不 mock 工具调用）
- 运行完整测试套件确认无回归

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- 修改：更新 `BuiltInSkills.simplify` 的 `promptTemplate` 和 `description`
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/SimplifySkillTests.swift` -- 新建：单元测试

```
Sources/OpenAgentSDK/
├── Types/
│   ├── SkillTypes.swift              # 修改：BuiltInSkills.simplify promptTemplate + description
│   └── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── BuiltInSkills/
│   │   ├── CommitSkillTests.swift    # 已有（Story 11.3）
│   │   ├── ReviewSkillTests.swift    # 已有（Story 11.4）
│   │   ├── SimplifySkillTests.swift  # 新建
│   │   └── ...
│   └── ...
└── ...
```

### Logger 集成约定

本 Story 不涉及新增 Logger 调用点（仅更新 promptTemplate 文本）。

### 反模式警告

- **不要**修改 Skill struct、SkillRegistry 或 SkillTool 的任何代码 -- 仅更新 BuiltInSkills.simplify 的 promptTemplate 字符串和 description
- **不要**将 SimplifySkill 改为动态 prompt 生成 -- 使用静态 promptTemplate（与 TypeScript SDK v1.0 对齐）
- **不要**创建新的类型或文件来存放 promptTemplate -- 保持 BuiltInSkills.simplify 作为内联定义
- **不要**修改 BuiltInSkills.commit、BuiltInSkills.review 等其他技能 -- 它们是其他 Story 的范围
- **不要**在 promptTemplate 中指导 Agent "修复" 问题 -- toolRestrictions 为只读（Read、Grep、Glob），只能分析和报告
- **不要**在测试中 mock BashTool -- 单元测试只验证 promptTemplate 文本内容，不验证工具调用行为
- **不要**遗漏"无变更"处理 -- promptTemplate 必须处理 git diff 输出为空的情况

### 测试策略

单元测试覆盖所有 AC，完全遵循 CommitSkillTests / ReviewSkillTests 的模式：

1. **AC1 测试**：promptTemplate 包含三类分析关键词（复用/reuse/duplicated、质量/quality/complex、效率/efficiency/unnecessary）；toolRestrictions 为 [.read, .grep, .glob]
2. **AC2 测试**：promptTemplate 包含文件名和行号引用格式要求（`file.swift:行号` 或等效表达）；输出结构包含重复代码模式、过度复杂逻辑、可提取抽象
3. **AC3 测试**：promptTemplate 包含简化前后对比示例要求
4. **元数据测试**：验证 name、aliases（如有）、toolRestrictions、userInvocable 属性
5. **Registry 测试**：验证 register/find/replace 操作对 simplify 技能正常工作

**测试隔离：**
- 使用 `SkillRegistry()` 创建独立注册表
- 测试 `BuiltInSkills.simplify` 返回的 Skill 实例属性
- 不需要 mock LLM 或工具 -- 仅验证 promptTemplate 文本内容

### 前序 Story 学习要点

**Story 11.1 完成情况：**
- SkillTypes.swift: ToolRestriction enum (22 cases), Skill struct (Sendable), BuiltInSkills namespace (5 skills)
- SkillRegistry.swift: final class + DispatchQueue, 支持完整的注册、查找、替换、列表 API
- BuiltInSkills.simplify 的骨架 promptTemplate 已存在但需要精化

**Story 11.2 完成情况：**
- SkillTool.swift: 通过 defineTool 创建，返回 JSON 格式的 ToolResult
- ToolRestrictionStack.swift: 栈模型管理工具限制
- ToolContext 新增 skillRegistry、restrictionStack、skillNestingDepth、maxSkillRecursionDepth

**Story 11.3 完成情况：**
- 仅更新了 BuiltInSkills.commit 的 promptTemplate 和 description
- 创建了 CommitSkillTests.swift（26 个测试）
- 完整测试套件: 2177 tests, 0 failures, 4 skipped
- **关键学习：** 测试只验证 promptTemplate 文本内容，不 mock 工具调用。这确保测试快速且可靠。

**Story 11.4 完成情况（本 Story 的直接参考）：**
- 仅更新了 BuiltInSkills.review 的 promptTemplate 和 description
- 创建了 ReviewSkillTests.swift（31 个测试）
- 完整测试套件: 2208 tests passing, 4 skipped, 0 failures
- **关键学习：** 与 Story 11.3 完全一致的模式 -- 仅更新 promptTemplate 文本，测试验证文本内容

**关键接口（本 Story 直接使用）：**
- `BuiltInSkills.simplify` -- 返回 Skill 实例（值类型，每次返回新实例）
- `SkillRegistry.register(_ skill:)` -- 注册技能
- `SkillRegistry.replace(_ skill:)` -- 替换技能
- `SkillRegistry.find(_ name:) -> Skill?` -- 按名称或别名查找
- `Skill.promptTemplate` -- promptTemplate 字符串属性

### Project Structure Notes

- SimplifySkillTests 放在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 目录下（已存在，Story 11.3 创建），与 CommitSkillTests 和 ReviewSkillTests 并列
- 完全对齐架构文档的目录结构：`Tests/OpenAgentSDKTests/Tools/` 下按功能分组

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.5] -- 验收标准和需求定义（promptTemplate 骨架和三项 AC）
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] -- Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR53] -- 内置技能功能需求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] -- 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Actor/struct 边界、命名约定、反模式
- [Source: open-agent-sdk-typescript/src/skills/bundled/simplify.ts] -- TypeScript SDK Simplify 技能实现（SIMPLIFY_PROMPT 文本和注册逻辑）
- [Source: open-agent-sdk-typescript/src/skills/types.ts] -- TypeScript SDK SkillDefinition 接口
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift] -- BuiltInSkills.simplify 当前定义（需更新 promptTemplate）
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] -- SkillRegistry（register/replace/find 用于测试）
- [Source: _bmad-output/implementation-artifacts/11-3-built-in-skill-commit.md] -- Story 11.3 开发记录（模式参考）
- [Source: _bmad-output/implementation-artifacts/11-4-built-in-skill-review.md] -- Story 11.4 开发记录（模式参考）
- [Source: Tests/OpenAgentSDKTests/Tools/BuiltInSkills/ReviewSkillTests.swift] -- 测试模式参考

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.1)

### Debug Log References

N/A -- all 31 ATDD tests passed on first implementation attempt.

### Completion Notes List

- Updated `BuiltInSkills.simplify` promptTemplate in SkillTypes.swift: replaced old skeleton (3 parallel sub-tasks + "fix any issues found") with new read-only analysis template
- Added `toolRestrictions: [.read, .grep, .glob]` (read-only tools only, no bash/write/edit)
- Updated `description` to remove "then fix any issues found" and add "providing before/after comparison examples"
- New promptTemplate structure: Step 1 (git diff/git diff --cached for changed files) -> Step 2 (three-category analysis with Read/Grep/Glob) -> Step 3 (report findings with file:line references and before/after comparisons)
- Handles no-changes scenario: informs user and stops when git diff returns empty
- All 31 ATDD tests pass (0 failures)
- Full test suite: 2239 tests passing, 4 skipped, 0 failures (up from 2208 with +31 new SimplifySkill tests)

### File List

- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- Modified: updated BuiltInSkills.simplify promptTemplate, description, and toolRestrictions
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/SimplifySkillTests.swift` -- Existing (created by ATDD phase): 31 unit tests covering AC1-AC3
