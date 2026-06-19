import XCTest
@testable import OpenAgentSDK

// MARK: - SaveSkillTool Tests

/// Unit tests for `Sources/OpenAgentSDK/Tools/Advanced/SaveSkillTool.swift`.
///
/// Covers the four concerns of the tool:
/// 1. Name validation (regex `^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$`)
/// 2. Conflict detection (only `.agentCreated` skills can be overwritten)
/// 3. Alias parsing (comma- or space-separated, empties filtered)
/// 4. Happy path (file written, registry populated, provenance set, JSON response)
///
/// Filesystem side-effects land in an isolated temp dir provided by
/// `TempDirTestCase`. `SkillUsageStore` is also pointed at the temp dir so
/// the sidecar file does not leak into the user home.
final class SaveSkillToolTests: TempDirTestCase {

    // MARK: - Helpers

    private func makeTool(
        registry: SkillRegistry,
        usageStore: SkillUsageStore
    ) -> ToolProtocol {
        createSaveSkillTool(
            skillRegistry: registry,
            usageStore: usageStore,
            skillsDir: tempDir
        )
    }

    private func call(
        tool: ToolProtocol,
        name: String,
        description: String = "desc",
        promptTemplate: String = "body",
        whenToUse: String? = nil,
        aliases: String? = nil,
        userInvocable: Bool? = nil
    ) async -> String {
        var input: [String: Any] = [
            "name": name,
            "description": description,
            "promptTemplate": promptTemplate,
        ]
        if let whenToUse { input["whenToUse"] = whenToUse }
        if let aliases { input["aliases"] = aliases }
        if let userInvocable { input["userInvocable"] = userInvocable }

        let ctx = ToolContext(cwd: tempDir)
        let result = await tool.call(input: input, context: ctx)
        return result.content
    }

    private func successRegistry() -> (SkillRegistry, SkillUsageStore) {
        (SkillRegistry(), SkillUsageStore(skillsDir: tempDir))
    }

    // MARK: - Name validation

    func testRejectsEmptyName() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "   ", description: "d", promptTemplate: "p")
        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("'name' must not be empty"))
    }

    func testRejectsUppercaseLetters() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "MySkill")
        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("Skill name must be lowercase"))
    }

    func testRejectsLeadingHyphen() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "-leading")
        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("Skill name must be lowercase"))
    }

    func testRejectsTrailingHyphen() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "trailing-")
        XCTAssertTrue(output.contains("\"success\":false"))
    }

    func testRejectsUnderscore() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "with_underscore")
        XCTAssertTrue(output.contains("\"success\":false"))
    }

    func testRejectsSpaceInName() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "two words")
        XCTAssertTrue(output.contains("\"success\":false"))
    }

    func testRejectsDotInName() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "dotted.name")
        XCTAssertTrue(output.contains("\"success\":false"))
    }

    func testAcceptsSingleCharName() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "a")
        XCTAssertTrue(output.contains("\"success\":true"))
        XCTAssertNotNil(registry.find("a"))
    }

    func testAcceptsSingleDigitName() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "0")
        XCTAssertTrue(output.contains("\"success\":true"))
    }

    func testAcceptsLowercaseAlphanumericWithHyphens() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "commit-workflow-42")
        XCTAssertTrue(output.contains("\"success\":true"))
        XCTAssertNotNil(registry.find("commit-workflow-42"))
    }

    // MARK: - Trimming

    func testNameIsWhitespaceTrimmedBeforeValidation() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(tool: tool, name: "  wrapped-name  ")
        XCTAssertTrue(output.contains("\"success\":true"))
        XCTAssertNotNil(registry.find("wrapped-name"))
    }

    // MARK: - Conflict detection

    func testRejectsOverwriteOfBundledSkill() async {
        let registry = SkillRegistry()
        let store = SkillUsageStore(skillsDir: tempDir)
        registry.register(Skill(name: "commit", description: "bundled", promptTemplate: "x"))
        try? await store.setProvenance(skillName: "commit", provenance: .bundled)

        let tool = makeTool(registry: registry, usageStore: store)
        let output = await call(tool: tool, name: "commit")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("already exists with provenance 'bundled'"))
    }

    func testRejectsOverwriteOfUserDefinedSkill() async {
        let registry = SkillRegistry()
        let store = SkillUsageStore(skillsDir: tempDir)
        registry.register(Skill(name: "my-skill", description: "manual", promptTemplate: "x"))
        try? await store.setProvenance(skillName: "my-skill", provenance: .userDefined)

        let tool = makeTool(registry: registry, usageStore: store)
        let output = await call(tool: tool, name: "my-skill")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("userDefined"))
    }

    func testAllowsOverwriteOfAgentCreatedSkill() async {
        let registry = SkillRegistry()
        let store = SkillUsageStore(skillsDir: tempDir)
        registry.register(Skill(name: "evolved", description: "v1", promptTemplate: "x"))
        try? await store.setProvenance(skillName: "evolved", provenance: .agentCreated)

        let tool = makeTool(registry: registry, usageStore: store)
        let output = await call(
            tool: tool,
            name: "evolved",
            description: "v2",
            promptTemplate: "y"
        )

        XCTAssertTrue(output.contains("\"success\":true"))
        let updated = registry.find("evolved")
        XCTAssertEqual(updated?.description, "v2")
        XCTAssertEqual(updated?.promptTemplate, "y")
    }

    // MARK: - Alias parsing

    func testAliases_nilProducesEmptyArray() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "skill-a", aliases: nil)
        XCTAssertEqual(registry.find("skill-a")?.aliases, [])
    }

    func testAliases_emptyStringProducesEmptyArray() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "skill-b", aliases: "")
        XCTAssertEqual(registry.find("skill-b")?.aliases, [])
    }

    func testAliases_singleAliasIsParsed() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "skill-c", aliases: "ci")
        XCTAssertEqual(registry.find("skill-c")?.aliases, ["ci"])
    }

    func testAliases_commaSeparatedAreSplit() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "skill-d", aliases: "ci,gc,commit")
        XCTAssertEqual(registry.find("skill-d")?.aliases, ["ci", "gc", "commit"])
    }

    func testAliases_spaceSeparatedAreSplit() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "skill-e", aliases: "ci gc commit")
        XCTAssertEqual(registry.find("skill-e")?.aliases, ["ci", "gc", "commit"])
    }

    func testAliases_mixedSeparatorsAndEmptySegmentsFiltered() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        // "a,, b, ,c" -> filter empties -> [a, b, c]
        _ = await call(tool: tool, name: "skill-f", aliases: "a,, b, ,c")
        XCTAssertEqual(registry.find("skill-f")?.aliases, ["a", "b", "c"])
    }

    // MARK: - Happy path

    func testSuccessfulCreation_persistsFileAndRegistersAndSetsProvenance() async throws {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        let output = await call(
            tool: tool,
            name: "new-skill",
            description: "desc",
            promptTemplate: "template body",
            whenToUse: "when X"
        )

        // JSON response shape
        XCTAssertTrue(output.contains("\"success\":true"))
        XCTAssertTrue(output.contains("Skill 'new-skill' created and saved"))
        XCTAssertTrue(output.contains("\"path\""))

        // Skill is in the registry with the right fields
        let registered = registry.find("new-skill")
        XCTAssertNotNil(registered)
        XCTAssertEqual(registered?.description, "desc")
        XCTAssertEqual(registered?.promptTemplate, "template body")
        XCTAssertEqual(registered?.whenToUse, "when X")

        // File on disk matches the canonical format
        let skillMdPath = (tempDir as NSString)
            .appendingPathComponent("new-skill/SKILL.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillMdPath))
        let written = try String(contentsOfFile: skillMdPath, encoding: .utf8)
        XCTAssertTrue(written.contains("name: new-skill"))
        XCTAssertTrue(written.contains("template body"))

        // Provenance flipped to .agentCreated
        let usage = await store.getUsage(skillName: "new-skill")
        XCTAssertEqual(usage.provenance, .agentCreated)
    }

    func testSuccessfulCreation_registersWithResolvedBaseDir() async throws {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "with-basedir")

        let registered = registry.find("with-basedir")
        XCTAssertNotNil(registered?.baseDir)
        XCTAssertTrue(registered?.baseDir?.hasSuffix("/with-basedir") == true)
    }

    func testSuccessfulCreation_userInvocableDefaultsToTrue() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "invocable-default", userInvocable: nil)
        XCTAssertTrue(registry.find("invocable-default")?.userInvocable ?? false)
    }

    func testSuccessfulCreation_userInvocableFalsePropagated() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "invocable-false", userInvocable: false)
        XCTAssertFalse(registry.find("invocable-false")?.userInvocable ?? true)
    }

    func testSuccessfulCreation_userInvocableTruePropagated() async {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(tool: tool, name: "invocable-true", userInvocable: true)
        XCTAssertTrue(registry.find("invocable-true")?.userInvocable ?? false)
    }

    // MARK: - Round-trip with SkillLoader

    func testWrittenSkillCanBeParsedBackBySkillLoader() async throws {
        let (registry, store) = successRegistry()
        let tool = makeTool(registry: registry, usageStore: store)

        _ = await call(
            tool: tool,
            name: "round-trip",
            description: "round trip desc",
            promptTemplate: "rt body",
            whenToUse: "rt when",
            aliases: "rt,rt2"
        )

        let loaded = SkillLoader.discoverSkills(from: [tempDir])
        let found = loaded.first(where: { $0.name == "round-trip" })
        XCTAssertNotNil(found, "SkillLoader should be able to re-parse the file SaveSkillTool wrote")
        XCTAssertEqual(found?.description, "round trip desc")
        XCTAssertEqual(found?.promptTemplate, "rt body")
    }
}
