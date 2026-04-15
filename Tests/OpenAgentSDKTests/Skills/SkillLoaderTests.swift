import XCTest
@testable import OpenAgentSDK

// MARK: - SkillLoader 单元测试

/// SkillLoader 文件系统技能发现与加载的单元测试。
/// 覆盖: SKILL.md 解析、frontmatter 提取、Markdown body 提取、引用路径解析、
/// 辅助文件发现、多目录扫描、去重、skillNames 过滤、畸形文件处理。
final class SkillLoaderTests: XCTestCase {

    // MARK: - 测试临时目录

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "SkillLoaderTests_\(ProcessInfo.processInfo.globallyUniqueString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

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

    /// 带引号的 frontmatter 值
    func testParseFrontmatter_QuotedValues() {
        let content = "---\nname: \"my skill\"\ndescription: 'A test'\n---\nBody"
        let result = SkillLoader.parseFrontmatter(content)

        XCTAssertEqual(result?["name"], "\"my skill\"")
        XCTAssertEqual(result?["description"], "'A test'")
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
}
