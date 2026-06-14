import XCTest
@testable import OpenAgentSDK

// MARK: - SkillLoader 单元测试

/// SkillLoader 文件系统技能发现与加载的单元测试。
/// 覆盖: SKILL.md 解析、frontmatter 提取、Markdown body 提取、引用路径解析、
/// 辅助文件发现、多目录扫描、去重、skillNames 过滤、畸形文件处理。
final class SkillLoaderTests: TempDirTestCase {

    // MARK: - 辅助方法

    /// 在指定目录下创建技能目录和 SKILL.md 文件
    @discardableResult
    private func createSkillDir(
        parentDir: String? = nil,
        name: String,
        frontmatter: String,
        body: String = "",
        extraFiles: [(path: String, content: String)] = []
    ) -> String {
        let dir = (parentDir ?? tempDir!) + "/" + name
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let skillContent: String
        if frontmatter.isEmpty {
            skillContent = body
        } else {
            skillContent = "---\n\(frontmatter)\n---\n\(body)"
        }
        FileManager.default.createFile(
            atPath: dir + "/SKILL.md",
            contents: skillContent.data(using: .utf8)
        )

        for extra in extraFiles {
            let fullPath = dir + "/" + extra.path
            let parentPath = (fullPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: parentPath, withIntermediateDirectories: true)
            FileManager.default.createFile(
                atPath: fullPath,
                contents: extra.content.data(using: .utf8)
            )
        }

        return dir
    }

    // MARK: - parseFrontmatter 测试

    /// 正确解析标准 YAML frontmatter
    func testParseFrontmatter_StandardYaml() {
        let content = "---\nname: my-skill\ndescription: A test skill\n---\nBody here"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["name"], "my-skill")
        XCTAssertEqual(result?["description"], "A test skill")
    }

    /// 无 frontmatter 标记时返回 nil
    func testParseFrontmatter_NoFrontmatter_ReturnsNil() {
        let content = "Just some markdown without frontmatter"
        let result = SkillLoader.parseFrontmatter(content)
        XCTAssertNil(result)
    }

    /// frontmatter 缺少结束标记时返回 nil
    func testParseFrontmatter_MissingEndDelimiter_ReturnsNil() {
        let content = "---\nname: skill\nno end marker"
        let result = SkillLoader.parseFrontmatter(content)
        XCTAssertNil(result)
    }

    /// 空 frontmatter（两个连续 ---）返回空字典
    func testParseFrontmatter_EmptyFrontmatter() {
        let content = "---\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }

    /// 带引号的 frontmatter 值 — 引号应被去除
    func testParseFrontmatter_QuotedValues() {
        let content = "---\nname: \"my skill\"\ndescription: 'A test'\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["name"], "my skill")
        XCTAssertEqual(result?["description"], "A test")
    }

    /// YAML 折叠块标量 (>) 正确解析为单行
    func testParseFrontmatter_FoldedBlockScalar() {
        let content = "---\nname: teambition\ndescription: >\n  Teambition 项目管理。用于一切与 Teambition 任务和项目相关的增删改查操作。\nmetadata:\n  version: v1\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["name"], "teambition")
        XCTAssertEqual(result?["description"], "Teambition 项目管理。用于一切与 Teambition 任务和项目相关的增删改查操作。")
    }

    /// YAML 折叠块标量多行折叠为空格连接
    func testParseFrontmatter_FoldedBlockScalar_MultipleLines() {
        let content = "---\nname: test\ndescription: >\n  Line one.\n  Line two.\n  Line three.\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["description"], "Line one. Line two. Line three.")
    }

    /// YAML 字面块标量 (|) 保留换行
    func testParseFrontmatter_LiteralBlockScalar() {
        let content = "---\nname: test\ndescription: |\n  Line one.\n  Line two.\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["description"], "Line one.\nLine two.")
    }

    /// 块标量后紧跟新键时正确终止
    func testParseFrontmatter_BlockScalar_TerminatedByNextKey() {
        let content = "---\nname: test\ndescription: >\n  Some description text.\naliases: a, b\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["description"], "Some description text.")
        XCTAssertEqual(result?["aliases"], "a, b")
    }

    /// 含 allowed-tools 的复杂 frontmatter
    func testParseFrontmatter_AllowedTools() {
        let content = "---\nname: commit\nallowed-tools: Bash, Read, Write\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["allowed-tools"], "Bash, Read, Write")
    }

    // MARK: - extractMarkdownBody 测试

    /// 正确提取 frontmatter 之后的 Markdown body
    func testExtractMarkdownBody_Standard() {
        let content = "---\nname: test\n---\nThis is the body.\nSecond line."
        let body = SkillLoader.extractMarkdownBody(content)
        XCTAssertEqual(body, "This is the body.\nSecond line.")
    }

    /// 无 frontmatter 时返回原始内容
    func testExtractMarkdownBody_NoFrontmatter() {
        let content = "Just markdown content"
        let body = SkillLoader.extractMarkdownBody(content)
        XCTAssertEqual(body, "Just markdown content")
    }

    /// frontmatter 后无 body 时返回空字符串
    func testExtractMarkdownBody_NoBody() {
        let content = "---\nname: test\n---"
        let body = SkillLoader.extractMarkdownBody(content)
        XCTAssertEqual(body, "")
    }

    /// body 保留 Markdown 格式（标题、列表、代码块）
    func testExtractMarkdownBody_PreservesFormatting() {
        let content = "---\nname: test\n---\n# Title\n\n- Item 1\n- Item 2\n\n```swift\nlet x = 1\n```"
        let body = SkillLoader.extractMarkdownBody(content)
        XCTAssertTrue(body.hasPrefix("# Title"))
        XCTAssertTrue(body.contains("```swift"))
    }

    // MARK: - resolveReferencePaths 测试

    /// 将相对 references/ 路径解析为绝对路径
    func testResolveReferencePaths_RelativeToAbsolute() {
        let body = "See [design doc](references/design.md) for details."
        let result = SkillLoader.resolveReferencePaths(in: body, baseDir: "/opt/skills/my-skill")
        XCTAssertEqual(result, "See [design doc](/opt/skills/my-skill/references/design.md) for details.")
    }

    /// 无 references 链接时保持不变
    func testResolveReferencePaths_NoReferences() {
        let body = "No links here, just text."
        let result = SkillLoader.resolveReferencePaths(in: body, baseDir: "/some/dir")
        XCTAssertEqual(result, body)
    }

    /// 多个 references 链接全部解析
    func testResolveReferencePaths_MultipleReferences() {
        let body = "[a](references/a.md) and [b](references/sub/b.md)"
        let result = SkillLoader.resolveReferencePaths(in: body, baseDir: "/skills/x")
        XCTAssertTrue(result.contains("/skills/x/references/a.md"))
        XCTAssertTrue(result.contains("/skills/x/references/sub/b.md"))
    }

    /// 非 .md 后缀的 references 链接不被替换
    func testResolveReferencePaths_NonMdNotReplaced() {
        let body = "[script](references/run.sh) is a script."
        let result = SkillLoader.resolveReferencePaths(in: body, baseDir: "/skills/x")
        // 只有 .md 后缀被替换
        XCTAssertTrue(result.contains("references/run.sh"))
    }

    // MARK: - findSupportingFiles 测试

    /// 发现 skill 目录下的辅助文件
    func testFindSupportingFiles_BasicFiles() {
        let skillDir = createSkillDir(
            name: "test-skill",
            frontmatter: "name: test",
            extraFiles: [
                (path: "references/design.md", content: "# Design"),
                (path: "scripts/setup.sh", content: "#!/bin/bash"),
            ]
        )

        let files = SkillLoader.findSupportingFiles(in: skillDir)
        XCTAssertTrue(files.contains("references/design.md"))
        XCTAssertTrue(files.contains("scripts/setup.sh"))
        // SKILL.md 不应出现在列表中
        XCTAssertFalse(files.contains("SKILL.md"))
    }

    /// 空目录返回空列表
    func testFindSupportingFiles_EmptyDirectory() {
        let skillDir = createSkillDir(name: "empty-skill", frontmatter: "name: test")
        let files = SkillLoader.findSupportingFiles(in: skillDir)
        XCTAssertTrue(files.isEmpty)
    }

    /// 辅助文件列表已排序
    func testFindSupportingFiles_Sorted() {
        let skillDir = createSkillDir(
            name: "sorted-skill",
            frontmatter: "name: test",
            extraFiles: [
                (path: "z-last.md", content: "z"),
                (path: "a-first.md", content: "a"),
                (path: "m-middle.md", content: "m"),
            ]
        )

        let files = SkillLoader.findSupportingFiles(in: skillDir)
        XCTAssertEqual(files, ["a-first.md", "m-middle.md", "z-last.md"])
    }

    /// 递归一层子目录发现文件（proxycast 模式）
    /// findSupportingFiles 只递归一层：skillDir/ -> 子目录/ -> 文件
    /// 不会进一步深入子目录的子目录
    func testFindSupportingFiles_OneLevelRecursion() {
        let skillDir = createSkillDir(
            name: "deep-skill",
            frontmatter: "name: test",
            extraFiles: [
                // 一层深：references/ 是一级子目录，design.md 是其中的文件 → 会被发现
                (path: "references/design.md", content: "doc"),
                // 两层深：references/level1/doc.md → 不会被 findSupportingFiles 发现
                (path: "references/level1/nested.md", content: "nested"),
            ]
        )

        let files = SkillLoader.findSupportingFiles(in: skillDir)
        // references/design.md：一级子目录内的文件，被发现
        XCTAssertTrue(files.contains("references/design.md"))
        // references/level1/nested.md：超过一层，不被发现
        XCTAssertFalse(files.contains("references/level1/nested.md"))
    }

    // MARK: - loadSkillFromDirectory 测试

    /// 从有效目录加载技能
    func testLoadSkillFromDirectory_Valid() {
        let skillDir = createSkillDir(
            name: "my-skill",
            frontmatter: "name: my-skill\ndescription: Test skill",
            body: "# Instructions\nDo the thing."
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.name, "my-skill")
        XCTAssertEqual(skill?.description, "Test skill")
        XCTAssertTrue(skill?.promptTemplate.hasPrefix("# Instructions") ?? false)
        XCTAssertNotNil(skill?.baseDir)
        XCTAssertEqual(skill?.baseDir, skillDir)
    }

    /// 无 SKILL.md 的目录返回 nil
    func testLoadSkillFromDirectory_NoSkillMd_ReturnsNil() {
        let dir = tempDir! + "/no-skill"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let skill = SkillLoader.loadSkillFromDirectory(dir)
        XCTAssertNil(skill)
    }

    /// SKILL.md 缺少 frontmatter 时返回 nil
    func testLoadSkillFromDirectory_NoFrontmatter_ReturnsNil() {
        let skillDir = createSkillDir(
            name: "no-frontmatter",
            frontmatter: "",
            body: "Just a body without frontmatter"
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertNil(skill)
    }

    /// frontmatter 无 name 字段时使用目录名作为技能名
    func testLoadSkillFromDirectory_FallbackToDirName() {
        let skillDir = createSkillDir(
            name: "fallback-name",
            frontmatter: "description: No name field",
            body: "Body content"
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertEqual(skill?.name, "fallback-name")
    }

    /// 正确解析 allowed-tools
    func testLoadSkillFromDirectory_WithAllowedTools() {
        let skillDir = createSkillDir(
            name: "restricted-skill",
            frontmatter: "name: restricted\nallowed-tools: Bash(npx foo:*), Read, Write",
            body: "Restricted skill"
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertNotNil(skill?.toolRestrictions)
        XCTAssertEqual(skill?.toolRestrictions?.count, 3)
        XCTAssertTrue(skill?.toolRestrictions?.contains(.bash) ?? false)
        XCTAssertTrue(skill?.toolRestrictions?.contains(.read) ?? false)
        XCTAssertTrue(skill?.toolRestrictions?.contains(.write) ?? false)
    }

    /// 正确解析 aliases（逗号和空格分隔）
    func testLoadSkillFromDirectory_WithAliases() {
        let skillDir = createSkillDir(
            name: "aliased",
            frontmatter: "name: my-skill\naliases: ms, my",
            body: "Body"
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertEqual(skill?.aliases, ["ms", "my"])
    }

    /// 解析 when-to-use 和 argument-hint
    func testLoadSkillFromDirectory_MetadataFields() {
        let skillDir = createSkillDir(
            name: "meta-skill",
            frontmatter: "name: meta\nwhen-to-use: code changes detected\nargument-hint: [message]",
            body: "Body"
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertEqual(skill?.whenToUse, "code changes detected")
        XCTAssertEqual(skill?.argumentHint, "[message]")
    }

    // MARK: - discoverSkills 测试

    /// 从单个目录发现技能
    func testDiscoverSkills_SingleDirectory() {
        let scanDir = tempDir! + "/scan-dir"
        createSkillDir(
            parentDir: scanDir,
            name: "skill-a",
            frontmatter: "name: skill-a\ndescription: Skill A",
            body: "Do A"
        )
        createSkillDir(
            parentDir: scanDir,
            name: "skill-b",
            frontmatter: "name: skill-b\ndescription: Skill B",
            body: "Do B"
        )

        let skills = SkillLoader.discoverSkills(from: [scanDir])
        XCTAssertEqual(skills.count, 2)
        let names = Set(skills.map(\.name))
        XCTAssertTrue(names.contains("skill-a"))
        XCTAssertTrue(names.contains("skill-b"))
    }

    /// 空目录返回空列表
    func testDiscoverSkills_EmptyDirectory() {
        let emptyDir = tempDir! + "/empty-dir"
        try? FileManager.default.createDirectory(atPath: emptyDir, withIntermediateDirectories: true)

        let skills = SkillLoader.discoverSkills(from: [emptyDir])
        XCTAssertTrue(skills.isEmpty)
    }

    /// 不存在的目录被跳过（不崩溃）
    func testDiscoverSkills_NonExistentDirectory() {
        let skills = SkillLoader.discoverSkills(from: ["/nonexistent/path/skills"])
        XCTAssertTrue(skills.isEmpty)
    }

    /// 多目录扫描时后出现的优先级更高（last-wins）
    func testDiscoverSkills_LastWinsPriority() {
        let dir1 = tempDir! + "/dir1"
        let dir2 = tempDir! + "/dir2"

        createSkillDir(
            parentDir: dir1,
            name: "shared-skill",
            frontmatter: "name: shared-skill\ndescription: Version from dir1",
            body: "V1 content"
        )
        createSkillDir(
            parentDir: dir2,
            name: "shared-skill",
            frontmatter: "name: shared-skill\ndescription: Version from dir2",
            body: "V2 content"
        )

        let skills = SkillLoader.discoverSkills(from: [dir1, dir2])
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.description, "Version from dir2")
        XCTAssertEqual(skills.first?.promptTemplate, "V2 content")
    }

    /// skillNames 过滤只加载白名单中的技能
    func testDiscoverSkills_SkillNameFilter() {
        let scanDir = tempDir! + "/filter-dir"
        createSkillDir(parentDir: scanDir, name: "commit", frontmatter: "name: commit", body: "Commit")
        createSkillDir(parentDir: scanDir, name: "review", frontmatter: "name: review", body: "Review")
        createSkillDir(parentDir: scanDir, name: "debug", frontmatter: "name: debug", body: "Debug")

        let skills = SkillLoader.discoverSkills(from: [scanDir], skillNames: ["commit"])
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.name, "commit")
    }

    /// skillNames 过滤器中不存在的名称被忽略
    func testDiscoverSkills_SkillNameFilter_NoMatch() {
        let scanDir = tempDir! + "/filter-dir2"
        createSkillDir(parentDir: scanDir, name: "commit", frontmatter: "name: commit", body: "Commit")

        let skills = SkillLoader.discoverSkills(from: [scanDir], skillNames: ["nonexistent"])
        XCTAssertTrue(skills.isEmpty)
    }

    /// 无 SKILL.md 的子目录被跳过
    func testDiscoverSkills_SkipsNonSkillDirectories() {
        let scanDir = tempDir! + "/mixed-dir"
        // 有效技能目录
        createSkillDir(parentDir: scanDir, name: "real-skill", frontmatter: "name: real", body: "Real")
        // 普通目录（无 SKILL.md）
        let plainDir = scanDir + "/plain-dir"
        try? FileManager.default.createDirectory(atPath: plainDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: plainDir + "/README.md", contents: "Not a skill".data(using: .utf8))

        let skills = SkillLoader.discoverSkills(from: [scanDir])
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.name, "real")
    }

    /// 符号链接去重：同一真实路径通过不同入口只加载一次
    func testDiscoverSkills_SymlinkDedup() {
        let realDir = tempDir! + "/real-skills"
        createSkillDir(parentDir: realDir, name: "my-skill", frontmatter: "name: my-skill", body: "Content")

        // 创建符号链接目录
        let linkDir = tempDir! + "/linked-skills"
        try? FileManager.default.createDirectory(atPath: linkDir, withIntermediateDirectories: true)
        let linkPath = linkDir + "/my-skill"
        let realPath = realDir + "/my-skill"
        try? FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: realPath)

        // 两个目录都扫描，但应该去重
        let skills = SkillLoader.discoverSkills(from: [realDir, linkDir])
        XCTAssertEqual(skills.count, 1, "符号链接去重后应只有 1 个技能")
    }

    // MARK: - defaultSkillDirectories 测试

    /// 默认目录列表包含预期的用户级和项目级路径
    func testDefaultSkillDirectories_ContainsExpectedPaths() {
        let dirs = SkillLoader.defaultSkillDirectories()

        // 至少应包含 home 目录下的路径
        XCTAssertFalse(dirs.isEmpty, "默认目录列表不应为空")

        // 验证包含关键路径模式
        let joined = dirs.joined(separator: ":")
        XCTAssertTrue(joined.contains(".config/agents/skills"), "应包含 .config/agents/skills")
        XCTAssertTrue(joined.contains(".agents/skills"), "应包含 .agents/skills")
        XCTAssertTrue(joined.contains(".claude/skills"), "应包含 .claude/skills")
    }

    // MARK: - parseAllowedTools 测试

    /// 正确解析带参数修饰的 allowed-tools
    func testParseAllowedTools_WithArguments() {
        let result = SkillLoader.parseAllowedTools("Bash(npx foo:*), Read, Glob")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)
        XCTAssertTrue(result?.contains(.bash) ?? false)
        XCTAssertTrue(result?.contains(.read) ?? false)
        XCTAssertTrue(result?.contains(.glob) ?? false)
    }

    /// 空字符串返回 nil
    func testParseAllowedTools_EmptyString() {
        let result = SkillLoader.parseAllowedTools("")
        XCTAssertNil(result)
    }

    /// nil 返回 nil
    func testParseAllowedTools_Nil() {
        let result = SkillLoader.parseAllowedTools(nil)
        XCTAssertNil(result)
    }

    /// 未知工具名被忽略
    func testParseAllowedTools_UnknownToolsIgnored() {
        let result = SkillLoader.parseAllowedTools("Bash, UnknownTool, Read")
        XCTAssertEqual(result?.count, 2)
        XCTAssertTrue(result?.contains(.bash) ?? false)
        XCTAssertTrue(result?.contains(.read) ?? false)
    }

    // MARK: - expandTilde 测试

    /// 展开波浪号为 HOME 目录
    func testExpandTilde_ExpandsHome() {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let result = SkillLoader.expandTilde("~/skills")
        XCTAssertEqual(result, home + "/skills")
    }

    /// 无波浪号的路径不变
    func testExpandTilde_NoTilde() {
        let result = SkillLoader.expandTilde("/absolute/path")
        XCTAssertEqual(result, "/absolute/path")
    }

    // MARK: - extractAliases 测试

    /// 正确解析逗号和空格分隔的别名
    func testExtractAliases_CommaAndSpaceSeparated() {
        let frontmatter: [String: String] = ["aliases": "ci, git-commit, gc"]
        let aliases = SkillLoader.extractAliases(frontmatter)
        XCTAssertEqual(aliases, ["ci", "git-commit", "gc"])
    }

    /// 无 aliases 字段返回空数组
    func testExtractAliases_NoAliasesField() {
        let frontmatter: [String: String] = ["name": "test"]
        let aliases = SkillLoader.extractAliases(frontmatter)
        XCTAssertTrue(aliases.isEmpty)
    }

    /// 空字符串别名被过滤
    func testExtractAliases_EmptyPartsFiltered() {
        let frontmatter: [String: String] = ["aliases": "ci, , gc"]
        let aliases = SkillLoader.extractAliases(frontmatter)
        // "ci" 和 "gc" 之间有空项被过滤
        XCTAssertFalse(aliases.contains(""))
        XCTAssertEqual(aliases.count, 2)
    }

    // MARK: - loadSkillFromDirectory 完整集成

    /// 完整集成：从带有辅助文件的目录加载
    func testLoadSkillFromDirectory_WithSupportingFiles() {
        let skillDir = createSkillDir(
            name: "full-skill",
            frontmatter: "name: full-skill\ndescription: Full integration test",
            body: "# Full Skill\n\nSee [design](references/design.md) for details.",
            extraFiles: [
                (path: "references/design.md", content: "# Design Doc"),
                (path: "scripts/run.sh", content: "#!/bin/bash"),
                (path: "templates/output.txt", content: "Template"),
            ]
        )

        let skill = SkillLoader.loadSkillFromDirectory(skillDir)
        XCTAssertNotNil(skill)

        // 辅助文件被发现
        XCTAssertFalse(skill!.supportingFiles.isEmpty)
        XCTAssertTrue(skill!.supportingFiles.contains("references/design.md"))
        XCTAssertTrue(skill!.supportingFiles.contains("scripts/run.sh"))
        XCTAssertTrue(skill!.supportingFiles.contains("templates/output.txt"))

        // body 中的引用路径被解析为绝对路径
        XCTAssertTrue(skill!.promptTemplate.contains(skillDir + "/references/design.md"))
    }

    // MARK: - Story 29.4: Tool Declaration Compatibility

    // 本区段为 Story 29.4（Tool Declaration Compatibility Model）的红阶段单元测试。
    // 解析器 parseToolDeclarations 是纯函数（字符串 → struct），无 LLM/网络/文件 I/O
    // （project-context.md #27）。所有测试直接调用 static method 断言返回值。
    //
    // 红相说明：本 story 引入的新类型（ToolDeclaration / ToolDeclarationStatus /
    // ToolDeclarationDiagnostics）、新字段（Skill.toolDeclarations /
    // Skill.toolDeclarationDiagnostics）、新方法（SkillLoader.parseToolDeclarations）
    // 在源码中尚不存在，故本区段测试在**编译阶段**即失败（Cannot find ... in scope）。
    // 这是预期的 TDD 红相 —— 绿阶段实现后全部转绿。

    // MARK: AC1 — MCP namespaced 工具声明被保留

    /// AC1 [P0]: MCP namespaced 名（`mcp__github__list_prs`）不被丢弃，
    /// 且与 SDK 工具名（WebSearch / Task）共存于声明数组。
    func testParseToolDeclarations_preservesMCPNamespacedNames() {
        // Given: frontmatter 值含 MCP namespaced 工具 + 两个 SDK 工具
        let input = "WebSearch, mcp__github__list_prs, Task"

        // When: 调用新解析器
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: 解析输出非 nil，保留全部三个名字
        XCTAssertNotNil(result, "parseToolDeclarations 必须返回非 nil 元组（即使含未知名）")
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 3, "应保留全部三个声明")

        let rawNames = declarations.map(\.rawName)
        XCTAssertTrue(rawNames.contains("mcp__github__list_prs"),
                      "MCP namespaced 名必须以完整 rawName 保留，不被截断或丢弃")
        XCTAssertTrue(rawNames.contains("WebSearch"),
                      "WebSearch 必须以 rawName 保留")
        XCTAssertTrue(rawNames.contains("Task"),
                      "Task 必须以 rawName 保留")

        // MCP 声明的 status 应为 .recognizedMCP
        let mcpDecl = declarations.first(where: { $0.rawName == "mcp__github__list_prs" })
        XCTAssertNotNil(mcpDecl, "必须能按 rawName 查到 MCP 声明")
        XCTAssertEqual(mcpDecl?.status, .recognizedMCP,
                       "mcp__github__list_prs 应被识别为 .recognizedMCP")
        // MCP 全名本身就是 normalized 形式，不应截断
        XCTAssertEqual(mcpDecl?.normalizedName, "mcp__github__list_prs",
                       "MCP normalizedName 应保留全名，不截断")
    }

    // MARK: AC2 — 未知工具名不 collapse 为 unrestricted

    /// AC2 [P0]: 仅含未知工具名时，解析输出非 nil（与旧 parseAllowedTools 返回 nil 的语义对比）。
    /// 这是本 story 修正"静默放权"bug 的核心断言。
    func testParseToolDeclarations_doesNotCollapseToUnrestricted() {
        // Given: frontmatter 值仅含一个无法识别的名字
        let input = "UnknownTool"

        // When: 调用新解析器
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: 返回非 nil（关键：旧解析器在此输入下返回 nil = unrestricted）
        XCTAssertNotNil(result,
                        "全 unknown 输入必须返回非 nil，调用方能据此区分'显式受限但无可用'与'unrestricted'")
        XCTAssertFalse(result?.declarations.isEmpty ?? true,
                       "声明数组不应为空 —— UnknownTool 必须以声明形式可见")

        // 对比：旧解析器在同一输入下应返回 nil（验证 bug 路径仍在，绿阶段不应被改动）
        let legacy = SkillLoader.parseAllowedTools(input)
        XCTAssertNil(legacy,
                     "旧 parseAllowedTools 在全 unknown 输入下返回 nil（unrestricted）—— 本 story 不改此行为，但新增非 nil 语义")
    }

    /// AC2 [P0]: 未知工具以 diagnostic 形式可见（unsupportedDeclarations 非空）。
    func testParseToolDeclarations_unknownToolNotDropped() {
        // Given: 仅含一个未知工具
        let input = "UnknownTool"

        // When: 解析
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: diagnostics.unsupportedDeclarations 含该声明
        let diagnostics = result?.diagnostics
        XCTAssertNotNil(diagnostics, "必须返回 diagnostics 载体")
        let unsupported = diagnostics?.unsupportedDeclarations ?? []
        XCTAssertEqual(unsupported.count, 1, "UnknownTool 必须出现在 unsupportedDeclarations")
        XCTAssertEqual(unsupported.first?.rawName, "UnknownTool")
        XCTAssertEqual(unsupported.first?.status, .unknown,
                       "未知工具的 status 必须为 .unknown")
    }

    // MARK: AC3 — Permission pattern 文本被保留

    /// AC3 [P0]: `Bash(git diff:*)` 的完整 pattern 文本被保留，
    /// 且 base name `Bash` 正确识别为 SDK 工具。
    func testParseToolDeclarations_preservesPatternText() {
        // Given: 含参数 pattern 的 Bash 声明
        let input = "Bash(git diff:*)"

        // When: 解析
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: declarations 保留完整 rawName（含括号 pattern）
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 1)
        let decl = declarations.first
        XCTAssertEqual(decl?.rawName, "Bash(git diff:*)",
                       "rawName 必须保留完整 pattern 文本（含括号）")
        XCTAssertEqual(decl?.pattern, "git diff:*",
                       "pattern 字段必须提取括号内的参数 pattern")
        XCTAssertEqual(decl?.normalizedName, "bash",
                       "normalizedName 应为去括号、小写化的 base name")
        XCTAssertEqual(decl?.status, .recognizedSDK,
                       "Bash 应被识别为 .recognizedSDK")
        XCTAssertEqual(decl?.toolRestriction, .bash,
                       "Bash 应映射到 ToolRestriction.bash")
    }

    /// AC3 [P1]: pattern 声明进入 diagnostics.patternDeclarations
    /// （标注"已解析但未在 pattern 粒度强制执行"）。
    func testParseToolDeclarations_patternEntersDiagnostics() {
        // Given: 含 pattern 的声明
        let input = "Bash(git diff:*)"

        // When: 解析
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: patternDeclarations 非空（即使 base 是 recognizedSDK，pattern 仍标"parsed but not enforced"）
        let patternDecls = result?.diagnostics.patternDeclarations ?? []
        XCTAssertFalse(patternDecls.isEmpty,
                       "含 pattern 的声明必须进入 patternDeclarations，标注未强制执行")
        XCTAssertEqual(patternDecls.first?.pattern, "git diff:*")
    }

    // MARK: AC5 — 常见 SDK/Claude 工具名被识别

    /// AC5 [P0]: epic 实施步骤第 3 条列出的全部 13 个 Claude Code LLM-facing 名
    /// 都被识别为 .recognizedSDK。
    func testParseToolDeclarations_recognizesClaudeCodeNames() {
        // Given: 全部 Claude Code 工具名
        let input = "Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, ToolSearch, AskUser, Skill, Agent, Task"

        // When: 解析
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: 每个名字都被识别为 .recognizedSDK
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 13,
                       "应保留全部 13 个声明")
        let allSDK = declarations.allSatisfy { $0.status == .recognizedSDK }
        XCTAssertTrue(allSDK,
                      "全部 13 个 Claude Code 名应被识别为 .recognizedSDK")

        // 抽样验证 normalized name 规范化正确
        let bashDecl = declarations.first(where: { $0.rawName == "Bash" })
        XCTAssertEqual(bashDecl?.normalizedName, "bash")
        let webFetchDecl = declarations.first(where: { $0.rawName == "WebFetch" })
        XCTAssertEqual(webFetchDecl?.normalizedName, "webfetch")
        let skillDecl = declarations.first(where: { $0.rawName == "Skill" })
        XCTAssertEqual(skillDecl?.normalizedName, "skill")

        // 可映射到 enum 的应提供 toolRestriction
        XCTAssertEqual(bashDecl?.toolRestriction, .bash)
        XCTAssertEqual(webFetchDecl?.toolRestriction, .webFetch)
        XCTAssertEqual(skillDecl?.toolRestriction, .skill)
    }

    /// AC5 [P1]: `Task` 在 ToolRestriction enum 中无对应 case（Dev Notes "ToolRestriction gap"），
    /// 但仍应被识别为 .recognizedSDK，normalizedName = "task"，toolRestriction = nil。
    func testParseToolDeclarations_taskRecognizedButNoEnumCase() {
        // Given: 仅 Task
        let input = "Task"

        // When: 解析
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: Task 被识别为 SDK 名，但 toolRestriction = nil（无 enum case）
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 1)
        let decl = declarations.first
        XCTAssertEqual(decl?.rawName, "Task")
        XCTAssertEqual(decl?.status, .recognizedSDK,
                       "Task 应被识别为 .recognizedSDK（即使 enum 无 case）")
        XCTAssertEqual(decl?.normalizedName, "task")
        XCTAssertNil(decl?.toolRestriction,
                     "Task 无对应 ToolRestriction enum case，toolRestriction 必须为 nil")
    }

    // MARK: AC1 + AC5 — 混合识别

    /// AC1 + AC5 [P0]: 混合 known/unknown/MCP 同时识别，diagnostics 正确分类。
    func testParseToolDeclarations_mixedKnownUnknownMCP() {
        // Given: 混合三种 status
        let input = "Bash, UnknownTool, mcp__srv__search"

        // When: 解析
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: 3 个 declaration，按 frontmatter 顺序保留
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 3)
        XCTAssertEqual(declarations[0].rawName, "Bash")
        XCTAssertEqual(declarations[0].status, .recognizedSDK)
        XCTAssertEqual(declarations[1].rawName, "UnknownTool")
        XCTAssertEqual(declarations[1].status, .unknown)
        XCTAssertEqual(declarations[2].rawName, "mcp__srv__search")
        XCTAssertEqual(declarations[2].status, .recognizedMCP)

        // diagnostics：unsupportedDeclarations 只含 UnknownTool
        let unsupported = result?.diagnostics.unsupportedDeclarations ?? []
        XCTAssertEqual(unsupported.count, 1)
        XCTAssertEqual(unsupported.first?.rawName, "UnknownTool")
    }

    // MARK: 空输入语义

    /// 边界 [P1]: nil 和空字符串输入返回 nil
    /// （区分 unrestricted 与显式声明：nil 输入 = 无 frontmatter 字段 = unrestricted；
    ///  非空但全 unknown = 显式声明但无可用 —— 见 testParseToolDeclarations_doesNotCollapseToUnrestricted）
    func testParseToolDeclarations_emptyAndNil() {
        // nil 输入 → nil（无声明）
        let nilResult = SkillLoader.parseToolDeclarations(nil)
        XCTAssertNil(nilResult, "nil 输入应返回 nil（无 frontmatter 字段，语义为 unrestricted）")

        // 空字符串 → nil
        let emptyResult = SkillLoader.parseToolDeclarations("")
        XCTAssertNil(emptyResult, "空字符串输入应返回 nil")
    }

    // MARK: AC1 + AC2 + AC3 — loadSkillFromDirectory 端到端填充

    /// AC1 + AC2 + AC3 + AC4 [P0]: loadSkillFromDirectory 同时填充新字段（toolDeclarations /
    /// toolDeclarationDiagnostics）与旧字段（toolRestrictions），向后兼容。
    func testLoadSkillFromDirectory_populatesToolDeclarations() {
        // Given: 含 allowed-tools（含 pattern + SDK 工具）的 skill 目录
        let skillDir = createSkillDir(
            name: "decl-skill",
            frontmatter: "name: decl\nallowed-tools: Bash(npx foo:*), Read, Write",
            body: "Skill with declarations"
        )

        // When: 加载 skill
        let skill = SkillLoader.loadSkillFromDirectory(skillDir)

        // Then: 新字段被填充
        XCTAssertNotNil(skill?.toolDeclarations,
                       "toolDeclarations 必须被 loadSkillFromDirectory 填充")
        XCTAssertEqual(skill?.toolDeclarations?.count, 3,
                       "应保留全部三个声明（含 pattern）")
        XCTAssertNotNil(skill?.toolDeclarationDiagnostics,
                       "toolDeclarationDiagnostics 必须被填充")
        XCTAssertFalse(skill?.toolDeclarationDiagnostics?.patternDeclarations.isEmpty ?? true,
                       "Bash(npx foo:*) 应进入 patternDeclarations")

        // And: 旧字段保持当前行为（AC4 向后兼容）
        XCTAssertNotNil(skill?.toolRestrictions,
                       "旧字段 toolRestrictions 必须保持填充（AC4 向后兼容）")
        XCTAssertEqual(skill?.toolRestrictions?.count, 3,
                       "旧字段应解析出 Bash / Read / Write 三个 restriction")
        XCTAssertTrue(skill?.toolRestrictions?.contains(.bash) ?? false)
        XCTAssertTrue(skill?.toolRestrictions?.contains(.read) ?? false)
        XCTAssertTrue(skill?.toolRestrictions?.contains(.write) ?? false)
    }

    // MARK: - Story 29.4 Review Fixes — Pattern / MCP Robustness

    /// Review fix [F1]: empty parens `Bash()` must NOT produce a phantom empty
    /// pattern. The declaration is still recognized as `Bash` with `pattern == nil`
    /// (so it does not pollute `patternDeclarations`).
    func testParseToolDeclarations_emptyParensProduceNoPhantomPattern() {
        // Given: an empty-pattern form
        let input = "Bash()"

        // When: parse
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: Bash is recognized, pattern is nil (not "")
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 1)
        let decl = declarations.first
        XCTAssertEqual(decl?.rawName, "Bash()")
        XCTAssertEqual(decl?.normalizedName, "bash")
        XCTAssertEqual(decl?.status, .recognizedSDK,
                       "Bash() — base Bash still recognized despite empty parens")
        XCTAssertNil(decl?.pattern,
                     "empty parens must yield pattern == nil, not \"\"")
        XCTAssertEqual(decl?.toolRestriction, .bash)
        // And: no phantom pattern declaration in diagnostics
        XCTAssertTrue(result?.diagnostics.patternDeclarations.isEmpty ?? true,
                      "Bash() must not appear in patternDeclarations (no real pattern)")
    }

    /// Review fix [F6]: unclosed paren `Bash(git diff:*` (typo missing `)`)
    /// must still recognize the `Bash` base name rather than silently demoting
    /// it to `.unknown` (which would drop a recognized tool's permission).
    func testParseToolDeclarations_unclosedParenStillRecognizesBase() {
        // Given: a Bash declaration missing its closing paren
        let input = "Bash(git diff:*"

        // When: parse
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: base Bash recognized despite the malformed form
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 1)
        let decl = declarations.first
        XCTAssertEqual(decl?.rawName, "Bash(git diff:*",
                       "rawName preserves the malformed form verbatim")
        XCTAssertEqual(decl?.normalizedName, "bash",
                       "base name Bash must be extracted despite unclosed paren")
        XCTAssertEqual(decl?.status, .recognizedSDK,
                       "Bash must remain .recognizedSDK — no silent demotion to .unknown")
        XCTAssertEqual(decl?.toolRestriction, .bash)
        XCTAssertNil(decl?.pattern,
                     "unclosed paren yields no pattern (cannot reliably extract)")
    }

    /// Review fix [F9]: MCP name with a trailing pattern
    /// (`mcp__github__list_prs(extra)`) must be classified against its bare
    /// namespaced base, with parens stripped from the normalized name so the
    /// declaration can actually match a registered MCP tool at runtime.
    func testParseToolDeclarations_mcpNameWithTrailingPatternStripsParens() {
        // Given: an MCP namespaced tool with a trailing permission pattern
        let input = "mcp__github__list_prs(extra:*)"

        // When: parse
        let result = SkillLoader.parseToolDeclarations(input)

        // Then: classified as MCP, normalized name has NO parens, pattern preserved
        let declarations = result?.declarations ?? []
        XCTAssertEqual(declarations.count, 1)
        let decl = declarations.first
        XCTAssertEqual(decl?.rawName, "mcp__github__list_prs(extra:*)")
        XCTAssertEqual(decl?.normalizedName, "mcp__github__list_prs",
                       "normalized MCP name must NOT contain parens (else runtime match fails)")
        XCTAssertEqual(decl?.status, .recognizedMCP)
        XCTAssertEqual(decl?.pattern, "extra:*",
                       "trailing pattern preserved for the MCP declaration")
        XCTAssertNil(decl?.toolRestriction)
    }
}
