---
title: '文件系统技能加载器'
type: 'feature'
created: '2026-04-15'
status: 'in-progress'
context:
  - '{project-root}/Sources/OpenAgentSDK/Types/SkillTypes.swift'
  - '{project-root}/Sources/OpenAgentSDK/Tools/SkillRegistry.swift'
  - '{project-root}/Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## 意图

**问题：** SDK 目前只支持编程式技能注册。用户必须手动解析 SKILL.md 文件并构造 `Skill` 实例（如 PolyvLiveExample 所示）。这套逻辑应该内化到 SDK 核心中。

**方案：** 添加 `SkillLoader` 工具，从标准目录或用户指定目录自动发现和加载基于 SKILL.md 的技能包。只加载 SKILL.md 的 Markdown body 作为 prompt，不预先加载任何附属文件。技能目录中除 SKILL.md 外的所有文件（references/、scripts/、templates/、assets/ 等子目录）都被扫描为 `supportingFiles` 路径列表，但内容不加载——Agent 按需通过 Read/Bash 工具访问。多个目录中可能出现同名技能，通过按优先级顺序扫描 + `FileManager.standardizingPath` 去重实现项目级覆盖用户级。`AgentOptions` 新增 `skillDirectories` 和 `skillNames` 参数，让 Agent 创建时可指定技能来源和过滤范围，Agent 初始化时自动完成发现、注册和 SkillTool 注入。

## 边界与约束

**必须遵守：**
- 渐进式披露：只加载 SKILL.md body，绝不预先加载 references/scripts/templates 等附属文件的内容
- 扫描技能目录下所有附属文件（递归一层子目录），记录为 `supportingFiles` 路径列表（不加载内容）
- 将 body 中的相对 `references/` 路径解析为绝对路径
- 按优先级扫描目录：项目级目录覆盖用户级目录（后扫描的优先）
- 同名技能去重：使用 `FileManager.standardizingPath` 解析真实路径，避免软链接导致的重复加载；同目录内同名技能后者覆盖前者
- Agent 创建时可指定 `skillDirectories`（技能来源）和 `skillNames`（技能过滤），不指定时使用默认目录且不过滤
- 线程安全：SkillLoader 是无状态工具，方法为纯函数
- 优雅的错误处理：无效技能跳过并发出警告，不会导致整体失败
- 保持向后兼容：现有 `Skill` 结构体、`SkillRegistry` 和 `SkillTool` 无需改动即可正常工作

**需要确认：**
- 无。方案已由 proxycast 参考实现充分验证。

**禁止：**
- 不加载参考文件内容到 prompt（禁止预加载）
- 不添加超出基本 frontmatter 解析的 SKILL.md 校验
- 不实现技能版本管理或自动升级
- 不添加基于 MCP 的技能加载
- 不添加远程技能目录支持
- 不实现工作流步骤或执行模式

## I/O 与边界情况矩阵

| 场景 | 输入 / 状态 | 预期输出 / 行为 | 错误处理 |
|------|------------|----------------|----------|
| 标准目录中有有效技能 | `~/.agents/skills/polyv-live-cli/SKILL.md` 存在且含 frontmatter | 返回 `Skill`，包含解析后的 name、description、allowed-tools、路径已解析的 body、baseDir | N/A |
| 多个目录有同名技能 | `~/.claude/skills/foo/SKILL.md` 和 `$PWD/.agents/skills/foo/SKILL.md` 同时存在 | 项目级（`$PWD`）版本胜出；通过 `standardizingPath` 去重，软链接指向同一实际文件时不重复加载 | N/A |
| `skillNames` 过滤 | `skillNames: ["polyv-live-cli"]`，registry 中有 5 个技能 | Agent 只能发现和调用 `polyv-live-cli` | N/A |
| `skillDirectories` 自定义 | `skillDirectories: ["/opt/custom-skills"]` | 只从指定目录加载，不扫描默认目录 | N/A |
| `skillDirectories` 和 `skillNames` 组合 | 两者都指定 | 先从指定目录发现技能，再按 skillNames 过滤 | N/A |
| SKILL.md 格式错误（缺少 frontmatter） | SKILL.md 没有 `---` 分隔符 | 跳过该技能 | 记录警告，其他技能继续加载 |
| 空技能目录 | `~/.agents/skills/` 存在但没有含 SKILL.md 的子目录 | 返回空数组 | N/A |
| 技能目录含 scripts/、templates/ 等子目录 | `my-skill/scripts/run.sh` 和 `my-skill/templates/base.txt` 存在 | 文件路径被列入 `supportingFiles`；内容不被加载 | N/A |
| SKILL.md 含 references/ 目录 | body 中包含 `[文档](references/api.md)` | 路径被解析为 `/绝对路径/references/api.md`；references 文件也出现在 `supportingFiles` 中 | N/A |
| 无标准目录存在 | 扫描目录均不存在 | 返回空数组 | N/A |
| 编程式技能（无文件系统） | `Skill(name: "x", promptTemplate: "...")` | `baseDir` 为 nil；与之前完全一致 | N/A |

</frozen-after-approval>

## 代码地图

- `Sources/OpenAgentSDK/Types/SkillTypes.swift` — `Skill` 结构体：添加 `baseDir: String?` 和 `supportingFiles: [String]` 字段
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` — `AgentOptions` 结构体：添加 `skillDirectories: [String]?` 和 `skillNames: [String]?` 字段
- `Sources/OpenAgentSDK/Tools/SkillRegistry.swift` — 添加 `registerDiscoveredSkills(from:skillNames:)` 便捷方法
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` — 在技能工具的 JSON 结果中包含 `baseDir` 和 `supportingFiles` 清单
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift` — 新增：文件系统技能发现和加载
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 导出新的公共 API（文档引用）
- `Tests/OpenAgentSDKTests/SkillLoaderTests.swift` — 新增：发现、解析、路径解析的单元测试

## 任务与验收

**执行：**
- [ ] `Sources/OpenAgentSDK/Skills/SkillLoader.swift` — 创建 `SkillLoader`，包含 `discoverSkills(from:)`、`loadSkillFromDirectory()` 和 `findSupportingFiles()` 函数，参考 proxycast 的 `skills_extension.rs` 模式：多目录扫描（5 个标准目录或用户指定目录按优先级排列）、SKILL.md frontmatter 解析、参考路径解析为绝对路径、附属文件发现（递归一层子目录，收集路径但不加载内容）、同名技能按目录优先级去重（后扫描覆盖先扫描，`standardizingPath` 避免软链接重复）、渐进式披露（仅 body）。
- [ ] `Sources/OpenAgentSDK/Types/SkillTypes.swift` — 在 `Skill` 结构体中添加 `baseDir: String?`（默认 nil）和 `supportingFiles: [String]`（默认空数组）。更新 `init()` 接受这两个参数。
- [ ] `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 在 `AgentOptions` 中添加 `skillDirectories: [String]?`（自定义技能目录）和 `skillNames: [String]?`（技能过滤白名单）。Agent 初始化时根据这两个参数自动发现、注册技能并注入 SkillTool。
- [ ] `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` — 当技能有非 nil 的 baseDir 时，在 JSON 结果中包含 `baseDir` 和 `supportingFiles`（相对路径列表），让 Agent 知道参考文件和脚本的位置。
- [ ] `Sources/OpenAgentSDK/Tools/SkillRegistry.swift` — 添加 `registerDiscoveredSkills(from:skillNames:)`，调用 SkillLoader 发现技能，按 skillNames 过滤后注册。
- [ ] `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 添加新公共 API 的文档引用。
- [ ] `Tests/OpenAgentSDKTests/SkillLoaderTests.swift` — 单元测试覆盖：frontmatter 解析、body 提取、参考路径解析、附属文件发现（含 scripts/templates/references 子目录）、多目录扫描与覆盖优先级、同名技能去重（含软链接场景）、skillNames 过滤、格式错误的 SKILL.md 处理、空目录、带 baseDir 和 supportingFiles 的 Skill 集成。

**验收标准：**
- 给定标准技能目录中存在有效的 SKILL.md 文件，当调用 `discoverSkills()` 时，返回所有有效技能，包含正确的 name、description、allowed-tools、已解析的参考路径、baseDir 和 supportingFiles
- 给定 `Skill` 结构体通过编程方式初始化，`baseDir` 为 nil 且 `supportingFiles` 为空数组，所有现有代码正常工作
- 给定技能含 references/ 和 scripts/ 目录，加载后只有 body 在 promptTemplate 中，参考路径为绝对路径，supportingFiles 包含所有附属文件的相对路径
- 给定多个目录包含同名技能，发现后项目级目录的版本胜出，软链接指向同一文件时不重复加载
- 给定 `skillNames: ["polyv-live-cli"]`，registry 只注册指定名称的技能
- 给定格式错误的 SKILL.md，发现运行时该技能被跳过而不崩溃

## 规格变更日志

## 设计说明

**扫描顺序（参考 proxycast 的 `skills_extension.rs`）：**
```
$PWD/.claude/skills        ← 项目级，最高优先级
$PWD/.agents/skills        ← 项目级
~/.claude/skills           ← 用户级
~/.agents/skills           ← 用户级
~/.config/agents/skills    ← 用户级，最低优先级
```
后扫描目录的技能覆盖先扫描的（Dictionary 插入 = 后者胜出）。

**去重机制：** 使用 `FileManager.default.fileSystemRepresentation(withPath:)` 或 `URL.resolvingSymlinksInPath()` 获取真实路径，避免软链接导致同名技能被重复加载。发现流程：
1. 遍历所有目录，收集 `(normalizedPath, Skill)` 对
2. 同一 normalizedPath 的技能不重复加载
3. 同名技能按目录优先级后者覆盖前者

**AgentOptions 集成：** `AgentOptions` 新增 `skillDirectories` 和 `skillNames`：
- `skillDirectories` 为 nil 时使用 5 个默认目录
- `skillDirectories` 非空时只扫描指定目录（用户完全控制来源）
- `skillNames` 为 nil 时注册所有发现的技能
- `skillNames` 非空时只注册指定名称的技能（白名单过滤）
- Agent 初始化时自动调用发现 → 过滤 → 注册 → 创建 SkillTool 并注入工具集

**附属文件发现** 参考 proxycast 的 `find_supporting_files()`：扫描技能目录（递归一层子目录），收集所有非 SKILL.md 文件的路径作为 `supportingFiles`。包括 references/、scripts/、templates/、assets/ 等所有子目录中的文件。只记录路径，不加载内容。Agent 收到 supportingFiles 列表后，根据需要通过 Read/Bash 工具按需访问。

**参考路径解析** 使用正则匹配 `](references/xxx.md)` 模式并替换为绝对路径。这是渐进式披露的关键机制：Agent 在 prompt 中看到绝对路径，通过 Read 工具按需加载。

## 验证

**命令：**
- `swift build --target OpenAgentSDK` — 预期：编译无错误
- `swift test` — 预期：所有现有 + 新测试通过（3051+ 测试，0 失败）
- `swift build --target PolyvLiveExample` — 预期：示例在 API 变更后仍可编译
