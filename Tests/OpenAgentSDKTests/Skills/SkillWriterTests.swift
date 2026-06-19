import XCTest
@testable import OpenAgentSDK

// MARK: - SkillWriter Tests

/// Unit tests for `Sources/OpenAgentSDK/Skills/SkillWriter.swift`.
///
/// Covers the pure `buildSKILLMd(_:)` formatter exhaustively, and exercises
/// `write(skill:to:)` against an isolated temp directory to verify directory
/// creation, file contents, and overwrite behavior.
final class SkillWriterTests: TempDirTestCase {

    // MARK: - buildSKILLMd: minimal skill

    func testBuildSKILLMd_minimalSkillHasNameAndPromptOnly() {
        let skill = Skill(name: "commit", promptTemplate: "do the thing")
        let content = SkillWriter.buildSKILLMd(skill)

        XCTAssertTrue(content.hasPrefix("---\n"))
        XCTAssertTrue(content.contains("name: commit\n"))
        XCTAssertTrue(content.hasSuffix("---\n\ndo the thing"))
    }

    func testBuildSKILLMd_omitsDescriptionWhenEmpty() {
        let skill = Skill(name: "x", description: "", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertFalse(content.contains("description:"))
    }

    func testBuildSKILLMd_omitsWhenToUseWhenNil() {
        let skill = Skill(name: "x", promptTemplate: "body", whenToUse: nil)
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertFalse(content.contains("when-to-use:"))
    }

    func testBuildSKILLMd_omitsWhenToUseWhenEmpty() {
        let skill = Skill(name: "x", promptTemplate: "body", whenToUse: "")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertFalse(content.contains("when-to-use:"))
    }

    func testBuildSKILLMd_omitsArgumentHintWhenNil() {
        let skill = Skill(name: "x", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertFalse(content.contains("argument-hint:"))
    }

    func testBuildSKILLMd_omitsAliasesWhenEmpty() {
        let skill = Skill(name: "x", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertFalse(content.contains("aliases:"))
    }

    func testBuildSKILLMd_omitsModelOverrideWhenNil() {
        let skill = Skill(name: "x", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertFalse(content.contains("model:"))
    }

    // MARK: - buildSKILLMd: full skill

    func testBuildSKILLMd_includesAllOptionalFieldsWhenPresent() {
        let skill = Skill(
            name: "commit-workflow",
            description: "Create a git commit",
            aliases: ["ci", "gc"],
            modelOverride: "claude-sonnet-4-6",
            promptTemplate: "commit template body",
            whenToUse: "When the user asks to commit",
            argumentHint: "[message]"
        )
        let content = SkillWriter.buildSKILLMd(skill)

        XCTAssertTrue(content.contains("name: commit-workflow\n"))
        XCTAssertTrue(content.contains("description:"))
        XCTAssertTrue(content.contains("when-to-use:"))
        XCTAssertTrue(content.contains("argument-hint:"))
        XCTAssertTrue(content.contains("aliases: ci, gc\n"))
        XCTAssertTrue(content.contains("model: claude-sonnet-4-6\n"))
        XCTAssertTrue(content.hasSuffix("---\n\ncommit template body"))
    }

    // MARK: - buildSKILLMd: YAML quoting (via yamlQuote)

    func testBuildSKILLMd_quotesDescriptionWithColon() {
        // Descriptions containing ':' must be quoted (YAML reserved).
        let skill = Skill(
            name: "x",
            description: "when: something happens",
            promptTemplate: "body"
        )
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertTrue(content.contains("description: \"when: something happens\"\n"))
    }

    func testBuildSKILLMd_quotesDescriptionWithNewline() {
        let skill = Skill(
            name: "x",
            description: "line one\nline two",
            promptTemplate: "body"
        )
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertTrue(content.contains("\"line one"))
    }

    func testBuildSKILLMd_quotesYAMLReservedDescription() {
        // Bare 'true', 'false', 'null' etc. would otherwise parse as non-strings.
        let skill = Skill(name: "x", description: "true", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertTrue(content.contains("description: \"true\""))
    }

    func testBuildSKILLMd_doesNotQuoteSimpleDescription() {
        let skill = Skill(name: "x", description: "simple text", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertTrue(content.contains("description: simple text\n"))
    }

    // MARK: - buildSKILLMd: frontmatter structure

    func testBuildSKILLMd_frontmatterHasExactlyTwoFenceMarkers() {
        let skill = Skill(name: "x", promptTemplate: "body")
        let content = SkillWriter.buildSKILLMd(skill)
        let occurrences = content.components(separatedBy: "---\n").count - 1
        XCTAssertEqual(occurrences, 2, "frontmatter should have exactly one open and one close fence")
    }

    func testBuildSKILLMd_promptTemplateFollowsBlankLineAfterCloseFence() {
        let skill = Skill(name: "x", promptTemplate: "BODY")
        let content = SkillWriter.buildSKILLMd(skill)
        XCTAssertTrue(content.contains("---\n\nBODY"))
    }

    // MARK: - write(skill:to:)

    func testWrite_createsSkillDirectoryAndSKILLMdFile() throws {
        let skill = Skill(name: "my-skill", promptTemplate: "body")
        let skillDir = try SkillWriter.write(skill: skill, to: tempDir)

        XCTAssertEqual(skillDir, (tempDir as NSString).appendingPathComponent("my-skill"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillDir))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (skillDir as NSString).appendingPathComponent("SKILL.md")))
    }

    func testWrite_createsNestedMissingDirectories() throws {
        let nestedRoot = (tempDir as NSString).appendingPathComponent("a/b/c")
        let skill = Skill(name: "x", promptTemplate: "body")
        let skillDir = try SkillWriter.write(skill: skill, to: nestedRoot)

        XCTAssertTrue(FileManager.default.fileExists(atPath: (skillDir as NSString).appendingPathComponent("SKILL.md")))
    }

    func testWrite_fileContentsMatchBuildSKILLMd() throws {
        let skill = Skill(
            name: "x",
            description: "desc",
            promptTemplate: "the body",
            whenToUse: "when needed"
        )
        let skillDir = try SkillWriter.write(skill: skill, to: tempDir)
        let skillMdPath = (skillDir as NSString).appendingPathComponent("SKILL.md")

        let written = try String(contentsOfFile: skillMdPath, encoding: .utf8)
        XCTAssertEqual(written, SkillWriter.buildSKILLMd(skill))
    }

    func testWrite_overwritesExistingSKILLMd() throws {
        let skill = Skill(name: "x", promptTemplate: "first version")
        let skillDir = try SkillWriter.write(skill: skill, to: tempDir)
        let skillMdPath = (skillDir as NSString).appendingPathComponent("SKILL.md")

        // Second write replaces the file with new content.
        let updated = Skill(name: "x", promptTemplate: "second version")
        _ = try SkillWriter.write(skill: updated, to: tempDir)

        let written = try String(contentsOfFile: skillMdPath, encoding: .utf8)
        XCTAssertTrue(written.contains("second version"))
        XCTAssertFalse(written.contains("first version"))
    }

    func testWrite_setsDirectoryPermissionsTo755() throws {
        let skill = Skill(name: "x", promptTemplate: "body")
        let skillDir = try SkillWriter.write(skill: skill, to: tempDir)

        let attrs = try FileManager.default.attributesOfItem(atPath: skillDir)
        let posix = attrs[.posixPermissions] as? NSNumber
        XCTAssertEqual(posix?.int16Value, 0o755)
    }

    func testWrite_throwsWhenSkillsDirIsAFile() throws {
        // Create a file at the path we want to use as a directory root.
        let fileAsRoot = (tempDir as NSString).appendingPathComponent("iamafile")
        try "blocker".write(toFile: fileAsRoot, atomically: true, encoding: .utf8)

        let skill = Skill(name: "x", promptTemplate: "body")
        XCTAssertThrowsError(try SkillWriter.write(skill: skill, to: fileAsRoot))
    }

    func testWrite_returnsPathForSingleCharName() throws {
        // The smallest legal name; ensures path join is correct.
        let skill = Skill(name: "a", promptTemplate: "body")
        let skillDir = try SkillWriter.write(skill: skill, to: tempDir)
        XCTAssertTrue(skillDir.hasSuffix("/a"))
    }
}
