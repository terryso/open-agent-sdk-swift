# Story 11.4: 内置技能 -- Review

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 具有 Code Review 技能，
以便它可以多维度审查代码变更。

## Acceptance Criteria

1. **AC1: ReviewSkill 注册与 promptTemplate 执行多维度审查** -- 给定 ReviewSkill 已注册到 SkillRegistry，当 LLM 调用 review 技能，则技能的 promptTemplate 指导 Agent 从正确性、安全性、性能、风格和测试覆盖率五个维度审查代码（FR53）。

2. **AC2: 审查结果引用具体位置** -- 给定代码变更（git diff 输出），当 review 技能执行，则 promptTemplate 要求审查结果引用具体文件名和行号（如 `src/main.swift:42`）。

3. **AC3: 多种变更源获取策略** -- 给定不同的 Git 状态，当 review 技能执行，则 promptTemplate 指导 Agent 按 `git diff`（未暂存）-> `git diff --cached`（已暂存）-> `git diff HEAD~1`（最近提交）的优先级获取变更内容。

4. **AC4: 按严重程度排序输出** -- 给定审查发现多个问题，当 review 技能输出结果，则 promptTemplate 指导按严重程度排序（安全 > 正确性 > 性能 > 风格 > 测试）。

## Tasks / Subtasks

- [x] Task 1: 更新 BuiltInSkills.review 的 promptTemplate (AC: #1, #2, #3, #4)
  - [x] 更新 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 中 `BuiltInSkills.review` 的 `promptTemplate`
  - [x] promptTemplate 必须包含五个审查维度：正确性、安全性、性能、风格、测试覆盖率（AC1）
  - [x] 每个发现必须引用具体文件名和行号（格式：`path/to/file.swift:行号`）（AC2）
  - [x] 包含三级变更获取策略：`git diff` -> `git diff --cached` -> `git diff HEAD~1`（AC3）
  - [x] 输出按严重程度排序：安全 > 正确性 > 性能 > 风格 > 测试（AC4）
  - [x] 更新 `description` 字段使其更精确

- [x] Task 2: 更新 BuiltInSkills.review 的 toolRestrictions 和元数据 (AC: #1)
  - [x] 确认 `toolRestrictions: [.bash, .read, .glob, .grep]` 覆盖 git 命令执行和文件分析需求
  - [x] 确认 `aliases: ["review-pr", "cr"]` 正确
  - [x] 确认 `userInvocable: true`
  - [x] 确认 `isAvailable` 默认为 `{ true }`

- [x] Task 3: 编写单元测试 (AC: #1-#4)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/ReviewSkillTests.swift`
  - [x] 测试 BuiltInSkills.review 的所有属性值（name、aliases、toolRestrictions、userInvocable）
  - [x] 测试 promptTemplate 包含五个审查维度关键词
  - [x] 测试 promptTemplate 包含文件名和行号引用格式要求
  - [x] 测试 promptTemplate 包含三级变更获取策略（git diff、git diff --cached、git diff HEAD~1）
  - [x] 测试 promptTemplate 包含按严重程度排序的指令
  - [x] 测试 SkillRegistry 可以注册和查找 BuiltInSkills.review
  - [x] 测试 registry.replace() 可以覆盖 review 技能的 promptTemplate

- [x] Task 4: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第四个 Story
- **核心目标：** 精化 Review 技能的 promptTemplate，使其完全符合 epics.md 中的验收标准。BuiltInSkills.review 的基础结构已在 Story 11.1 中创建，本 Story 仅需更新 promptTemplate 文本和补充单元测试
- **前置依赖：** Story 11.1（Skill 类型定义和 SkillRegistry）、Story 11.2（SkillTool 执行工具）
- **后续依赖：** 无直接后续依赖（Story 11.5-11.7 为其他内置技能，独立实现）
- **FR 覆盖：** FR53（内置技能的 promptTemplate 指导 Agent 执行特定工作流）

### 关键发现：当前 promptTemplate 与 epics 要求的差异

**当前 promptTemplate（Story 11.1 中创建的骨架）：**
```
Review the current code changes for potential issues. Follow these steps:

1. Run `git diff` to see uncommitted changes, or `git diff main...HEAD` for branch changes
2. For each changed file, analyze:
   - **Correctness**: Logic errors, edge cases, off-by-one errors
   - **Security**: Injection vulnerabilities, auth issues, data exposure
   - **Performance**: N+1 queries, unnecessary allocations, blocking I/O
   - **Style**: Naming, consistency with surrounding code, readability
   - **Testing**: Are the changes adequately tested?
3. Provide a summary with:
   - Critical issues (must fix)
   - Suggestions (nice to have)
   - Questions (need clarification)

Be specific: reference file names, line numbers, and suggest fixes.
```

**epics.md 要求（必须对齐）：**
1. 三级变更获取策略：`git diff`（未暂存）-> `git diff --cached`（已暂存）-> `git diff HEAD~1`（最近提交）-- 当前仅使用 `git diff` 和 `git diff main...HEAD`
2. 每个发现必须引用具体文件名和行号（格式：`path/to/file.swift:行号`）-- 当前有"reference file names, line numbers"但缺少明确格式要求
3. 按严重程度排序：安全 > 正确性 > 性能 > 风格 > 测试 -- 当前按 Critical/Suggestions/Questions 分类，不符合要求
4. 五个维度与 epics 一致（正确性、安全性、性能、风格、测试覆盖率）-- 当前缺少"测试覆盖率"维度的明确表述

**需要修改的关键点：**
- 步骤 1 改为三级变更获取策略（与 epics 的骨架对齐）
- 增加明确的文件名:行号引用格式要求
- 增加 Swift 惯用写法要求（风格维度）
- 输出按严重程度排序替代当前的 Critical/Suggestions/Questions 分类
- 增加无变更时的处理指令

### TypeScript SDK 参考映射

| Swift 类型/属性 | TypeScript 对应 | 文件 |
|---|---|---|
| `BuiltInSkills.review` | `registerReviewSkill()` | `src/skills/bundled/review.ts` |
| `promptTemplate` (静态字符串) | `REVIEW_PROMPT` + `getPrompt(args)` (动态) | `src/skills/bundled/review.ts` |
| `toolRestrictions: [.bash, .read, .glob, .grep]` | `allowedTools: ['Bash', 'Read', 'Glob', 'Grep']` | `src/skills/bundled/review.ts` |
| `aliases: ["review-pr", "cr"]` | `aliases: ['review-pr', 'cr']` | `src/skills/bundled/review.ts` |

**关键差异：**
- TS SDK 的 `getPrompt()` 接收 `args` 参数，可追加 `Focus area: ${args}`。Swift v1.0 的 `promptTemplate` 是静态字符串，`args` 由 SkillTool 在运行时处理
- TS SDK 的 REVIEW_PROMPT 文本与 Swift 当前骨架几乎一致，但两者都不完全匹配 epics.md 的要求 -- 本 Story 需要对齐 epics 骨架
- TS SDK 使用 `allowedTools` 白名单，Swift 使用 `toolRestrictions`（语义相同，仅命名差异）

### 已有代码模式参考

**BuiltInSkills.review 当前定义（SkillTypes.swift:172-197）：**
```swift
public static var review: Skill {
    Skill(
        name: "review",
        description: "Review code changes for correctness, security, performance, and style issues.",
        aliases: ["review-pr", "cr"],
        userInvocable: true,
        toolRestrictions: [.bash, .read, .glob, .grep],
        promptTemplate: """
        Review the current code changes for potential issues. Follow these steps:
        ...
        """
    )
}
```

本 Story 仅需更新 `promptTemplate` 字符串内容和 `description`，不改变结构、其他属性或类型定义。

**SkillRegistry 的 replace 方法（已在 11.1 中实现）：**
```swift
registry.replace(Skill(name: "review", promptTemplate: "自定义模板..."))
```
这是 AC 隐含验证 -- 开发者可以通过 replace 覆盖 promptTemplate。

**Story 11.3 (Commit) 的实现模式（应完全遵循）：**
- 仅更新 promptTemplate 文本，不修改 Skill struct / SkillRegistry / SkillTool
- 创建 `ReviewSkillTests.swift` 在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 下
- 测试覆盖所有 AC，验证 promptTemplate 文本内容（不 mock 工具调用）
- 运行完整测试套件确认无回归

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- 修改：更新 `BuiltInSkills.review` 的 `promptTemplate` 和 `description`
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/ReviewSkillTests.swift` -- 新建：单元测试

```
Sources/OpenAgentSDK/
├── Types/
│   ├── SkillTypes.swift              # 修改：BuiltInSkills.review promptTemplate + description
│   └── ...
└── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── BuiltInSkills/
│   │   ├── CommitSkillTests.swift    # 已有（Story 11.3）
│   │   ├── ReviewSkillTests.swift    # 新建
│   │   └── ...
│   └── ...
└── ...
```

### Logger 集成约定

本 Story 不涉及新增 Logger 调用点（仅更新 promptTemplate 文本）。

### 反模式警告

- **不要**修改 Skill struct、SkillRegistry 或 SkillTool 的任何代码 -- 仅更新 BuiltInSkills.review 的 promptTemplate 字符串和 description
- **不要**将 ReviewSkill 改为动态 prompt 生成 -- 使用静态 promptTemplate（与 TypeScript SDK v1.0 对齐）
- **不要**创建新的类型或文件来存放 promptTemplate -- 保持 BuiltInSkills.review 作为内联定义
- **不要**修改 BuiltInSkills.commit、BuiltInSkills.simplify 等其他技能 -- 它们是其他 Story 的范围
- **不要**在 promptTemplate 中使用 `git diff main...HEAD` -- epics 骨架使用 `git diff HEAD~1` 获取最近提交
- **不要**在测试中 mock BashTool -- 单元测试只验证 promptTemplate 文本内容，不验证工具调用行为
- **不要**遗漏"无变更"处理 -- promptTemplate 必须处理 git diff 输出为空的情况

### 测试策略

单元测试覆盖所有 AC，完全遵循 CommitSkillTests 的模式：

1. **AC1 测试**：promptTemplate 包含五个审查维度关键词（正确性/correctness、安全性/security、性能/performance、风格/style、测试覆盖率/testing coverage）
2. **AC2 测试**：promptTemplate 包含文件名和行号引用格式要求（`file.swift:行号` 或等效表达）
3. **AC3 测试**：promptTemplate 包含三级变更获取策略（`git diff`、`git diff --cached`、`git diff HEAD~1`）
4. **AC4 测试**：promptTemplate 包含按严重程度排序的指令（安全 > 正确性 > 性能 > 风格 > 测试）
5. **元数据测试**：验证 name、aliases、toolRestrictions、userInvocable 属性
6. **Registry 测试**：验证 register/find/replace 操作对 review 技能正常工作

**测试隔离：**
- 使用 `SkillRegistry()` 创建独立注册表
- 测试 `BuiltInSkills.review` 返回的 Skill 实例属性
- 不需要 mock LLM 或工具 -- 仅验证 promptTemplate 文本内容

### 前序 Story 学习要点

**Story 11.1 完成情况：**
- SkillTypes.swift: ToolRestriction enum (22 cases), Skill struct (Sendable), BuiltInSkills namespace (5 skills)
- SkillRegistry.swift: final class + DispatchQueue, 支持完整的注册、查找、替换、列表 API
- BuiltInSkills.review 的骨架 promptTemplate 已存在但需要精化

**Story 11.2 完成情况：**
- SkillTool.swift: 通过 defineTool 创建，返回 JSON 格式的 ToolResult
- ToolRestrictionStack.swift: 栈模型管理工具限制
- ToolContext 新增 skillRegistry、restrictionStack、skillNestingDepth、maxSkillRecursionDepth

**Story 11.3 完成情况（本 Story 的直接参考）：**
- 仅更新了 BuiltInSkills.commit 的 promptTemplate 和 description
- 创建了 CommitSkillTests.swift（26 个测试）
- 完整测试套件: 2177 tests, 0 failures, 4 skipped
- **关键学习：** 测试只验证 promptTemplate 文本内容，不 mock 工具调用。这确保测试快速且可靠。

**关键接口（本 Story 直接使用）：**
- `BuiltInSkills.review` -- 返回 Skill 实例（值类型，每次返回新实例）
- `SkillRegistry.register(_ skill:)` -- 注册技能
- `SkillRegistry.replace(_ skill:)` -- 替换技能
- `SkillRegistry.find(_ name:) -> Skill?` -- 按名称或别名查找
- `Skill.promptTemplate` -- promptTemplate 字符串属性

### Project Structure Notes

- ReviewSkillTests 放在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 目录下（已存在，Story 11.3 创建），与 CommitSkillTests 并列
- 完全对齐架构文档的目录结构：`Tests/OpenAgentSDKTests/Tools/` 下按功能分组

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.4] -- 验收标准和需求定义（promptTemplate 骨架和四项 AC）
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] -- Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR53] -- 内置技能功能需求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] -- 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Actor/struct 边界、命名约定、反模式
- [Source: open-agent-sdk-typescript/src/skills/bundled/review.ts] -- TypeScript SDK Review 技能实现（REVIEW_PROMPT 文本和注册逻辑）
- [Source: open-agent-sdk-typescript/src/skills/types.ts] -- TypeScript SDK SkillDefinition 接口
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift] -- BuiltInSkills.review 当前定义（需更新 promptTemplate）
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] -- SkillRegistry（register/replace/find 用于测试）
- [Source: _bmad-output/implementation-artifacts/11-3-built-in-skill-commit.md] -- Story 11.3 开发记录（模式参考）
- [Source: Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift] -- 测试模式参考

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

None.

### Completion Notes List

- Updated `BuiltInSkills.review` promptTemplate in `Sources/OpenAgentSDK/Types/SkillTypes.swift` to meet all four ACs:
  - AC1: Five review dimensions (correctness, security, performance, style, testing coverage) explicitly listed with analysis instructions
  - AC2: File:line format (`path/to/file.swift:行号`) explicitly required for every finding
  - AC3: Three-level change acquisition strategy (`git diff` -> `git diff --cached` -> `git diff HEAD~1`) with cascading fallback and no-changes handling
  - AC4: Severity-ordered output (Security > Correctness > Performance > Style > Testing) replaces old Critical/Suggestions/Questions format
- Updated `description` field to mention all five dimensions including test coverage
- Confirmed toolRestrictions, aliases, userInvocable, and isAlready all correct (no changes needed)
- All 12 previously failing ReviewSkillTests now pass
- Full test suite: 2208 tests passing, 4 skipped, 0 failures

### File List

- `Sources/OpenAgentSDK/Types/SkillTypes.swift` — modified: updated `BuiltInSkills.review` promptTemplate and description
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/ReviewSkillTests.swift` — existing: 31 ATDD tests (all passing)

### Change Log

- 2026-04-11: Story 11.4 implementation complete. Refined review skill promptTemplate for multi-dimensional review with severity-ordered output.
- 2026-04-11: Code review passed (yolo mode). All 4 ACs verified. 0 patch findings, 2 deferred (binary/conflict diff guidance, untracked file handling), 4 dismissed.

### Review Findings

- [x] [Review][Defer] No guidance for binary/conflict diffs in promptTemplate — deferred, pre-existing (epics skeleton does not mention binary diffs)
- [x] [Review][Defer] Missing untracked file handling in three-level strategy — deferred, pre-existing (epics skeleton uses same strategy without untracked file support)
