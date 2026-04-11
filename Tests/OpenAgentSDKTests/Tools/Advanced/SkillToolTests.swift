import XCTest
@testable import OpenAgentSDK

// MARK: - SkillTool Tests (Story 11.2, ATDD RED PHASE)

/// ATDD RED PHASE: Tests for Story 11.2 -- SkillTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createSkillTool(registry:)` factory function is implemented in Tools/Advanced/SkillTool.swift
///   - `SkillToolInput` Codable struct is defined (skill: String, args: String?)
///   - `ToolContext` gains `skillRegistry`, `restrictionStack`, `skillNestingDepth`, `maxSkillRecursionDepth` fields
///   - `ToolRestrictionStack` class is implemented in Tools/ToolRestrictionStack.swift
///   - `AgentOptions` gains `skillRegistry` and `maxSkillRecursionDepth` fields
/// TDD Phase: RED (feature not implemented yet)
final class SkillToolTests: XCTestCase {

    // MARK: - Helper: Create a test skill

    /// Creates a simple skill for testing.
    private func makeSkill(
        name: String = "test_skill",
        description: String = "A test skill",
        aliases: [String] = [],
        userInvocable: Bool = true,
        toolRestrictions: [ToolRestriction]? = nil,
        modelOverride: String? = nil,
        isAvailable: @escaping @Sendable () -> Bool = { true },
        promptTemplate: String = "Test prompt template"
    ) -> Skill {
        Skill(
            name: name,
            description: description,
            aliases: aliases,
            userInvocable: userInvocable,
            toolRestrictions: toolRestrictions,
            modelOverride: modelOverride,
            isAvailable: isAvailable,
            promptTemplate: promptTemplate
        )
    }

    // MARK: - AC1: SkillTool Registration and LLM Discovery

    /// AC1 [P0]: createSkillTool returns a valid ToolProtocol with name "Skill".
    func testCreateSkillTool_returnsToolProtocol() async throws {
        // Given: a registry with a registered skill
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit"))

        // When: creating the Skill tool
        let tool = createSkillTool(registry: registry)

        // Then: it is a valid ToolProtocol
        XCTAssertEqual(tool.name, "Skill")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertFalse(tool.isReadOnly)
    }

    /// AC1 [P0]: SkillTool has a valid inputSchema with "skill" and "args" fields.
    func testCreateSkillTool_hasValidInputSchema() async throws {
        // Given: a registry
        let registry = SkillRegistry()

        // When: creating the Skill tool
        let tool = createSkillTool(registry: registry)

        // Then: inputSchema has the expected structure
        let schema = tool.inputSchema
        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertNotNil(properties?["skill"])
        XCTAssertNotNil(properties?["args"])

        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["skill"])
    }

    /// AC1 [P0]: SkillTool finds a registered skill and returns JSON with promptTemplate.
    func testSkillTool_findsSkillAndReturnsJSON() async throws {
        // Given: a registry with a skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "commit",
            promptTemplate: "Create a git commit"
        ))

        // When: calling the SkillTool with skill name "commit"
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "commit"]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful and contains expected JSON fields
        XCTAssertFalse(result.isError, "Expected successful result, got error: \(result.content)")

        // Parse JSON content
        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["commandName"] as? String, "commit")
        XCTAssertEqual(json["prompt"] as? String, "Create a git commit")
    }

    /// AC1 [P0]: SkillTool returns error for non-existent skill.
    func testSkillTool_nonExistentSkill_returnsError() async throws {
        // Given: a registry without the requested skill
        let registry = SkillRegistry()

        // When: calling the SkillTool with non-existent skill name
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "nonexistent"]
        let result = await tool.call(input: input, context: context)

        // Then: result is an error
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not found") || result.content.contains("not registered"),
                       "Error should mention skill not found, got: \(result.content)")
    }

    /// AC1 [P1]: SkillTool returns error for unavailable skill (isAvailable returns false).
    func testSkillTool_unavailableSkill_returnsError() async throws {
        // Given: a registry with an unavailable skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "unavailable",
            isAvailable: { false }
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "unavailable"]
        let result = await tool.call(input: input, context: context)

        // Then: result is an error about availability
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not available") || result.content.contains("unavailable"),
                       "Error should mention unavailability, got: \(result.content)")
    }

    /// AC1 [P1]: SkillTool resolves skill by alias.
    func testSkillTool_resolvesByAlias() async throws {
        // Given: a registry with a skill with alias "ci"
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "commit",
            aliases: ["ci"],
            promptTemplate: "Create a commit"
        ))

        // When: calling the SkillTool with alias "ci"
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "ci"]
        let result = await tool.call(input: input, context: context)

        // Then: skill is found via alias
        XCTAssertFalse(result.isError, "Expected successful result, got error: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(json["commandName"] as? String, "commit")
    }

    // MARK: - AC4: Model Override

    /// AC4 [P0]: SkillTool returns model field when skill has modelOverride.
    func testSkillTool_modelOverride_includedInJSON() async throws {
        // Given: a registry with a skill that has modelOverride
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "opus-review",
            modelOverride: "claude-opus-4-6",
            promptTemplate: "Review code with opus"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "opus-review"]
        let result = await tool.call(input: input, context: context)

        // Then: JSON contains model field
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "claude-opus-4-6")
    }

    /// AC4 [P1]: SkillTool omits model field when skill has no modelOverride.
    func testSkillTool_noModelOverride_noModelField() async throws {
        // Given: a registry with a skill without modelOverride
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "basic-skill",
            modelOverride: nil,
            promptTemplate: "Do something basic"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "basic-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: JSON does not contain model field (or it is null)
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        // model should either be absent or null
        if let model = json["model"] {
            XCTAssertNil(model, "model should be nil when no override, got: \(model)")
        }
    }

    // MARK: - AC5: Self-Reference Cycle Prevention

    /// AC5 [P0]: SkillTool returns error when skill restricts .skill (self-reference).
    func testSkillTool_selfReferenceRestriction_returnsError() async throws {
        // Given: a registry with a skill that restricts .skill (itself)
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "cyclic-skill",
            toolRestrictions: [.bash, .read, .skill],
            promptTemplate: "Do something cyclic"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "cyclic-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: result is an error about self-reference
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("cannot restrict") || result.content.contains("Skill cannot restrict SkillTool itself"),
                       "Error should mention self-reference prevention, got: \(result.content)")
    }

    /// AC5 [P1]: Skill that restricts tools but NOT .skill should work fine.
    func testSkillTool_nonSelfRestriction_succeeds() async throws {
        // Given: a registry with a skill that restricts tools but not .skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "safe-skill",
            toolRestrictions: [.bash, .read, .glob],
            promptTemplate: "Do something safe"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "safe-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")
    }

    // MARK: - AC7: Recursion Depth Limit

    /// AC7 [P0]: SkillTool returns error when nesting depth exceeds maximum.
    func testSkillTool_recursionDepthExceeded_returnsError() async throws {
        // Given: a registry with a skill and context at max depth
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "nested-skill",
            promptTemplate: "Nested"
        ))

        // When: calling with context where skillNestingDepth >= maxSkillRecursionDepth
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            skillNestingDepth: 4,
            maxSkillRecursionDepth: 4
        )
        let input: [String: Any] = ["skill": "nested-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: result is an error about recursion depth
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("recursion depth exceeded") || result.content.contains("maximum nesting depth"),
                       "Error should mention recursion depth, got: \(result.content)")
    }

    /// AC7 [P1]: SkillTool succeeds when within depth limit.
    func testSkillTool_withinDepthLimit_succeeds() async throws {
        // Given: a registry with a skill and context below max depth
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "ok-skill",
            promptTemplate: "OK"
        ))

        // When: calling with depth 3 and max 4
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            skillNestingDepth: 3,
            maxSkillRecursionDepth: 4
        )
        let input: [String: Any] = ["skill": "ok-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")
    }

    /// AC7 [P1]: SkillTool uses default max depth of 4 when not configured.
    func testSkillTool_defaultMaxDepth_is4() async throws {
        // Given: a registry with a skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "skill-at-depth3",
            promptTemplate: "Template"
        ))

        // When: calling with default context (no depth fields set)
        // Default: skillNestingDepth=0, maxSkillRecursionDepth=4
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "skill-at-depth3"]
        let result = await tool.call(input: input, context: context)

        // Then: at depth 0, should succeed (well within limit of 4)
        XCTAssertFalse(result.isError, "Expected success at depth 0, got: \(result.content)")
    }

    // MARK: - AC2: Tool Restriction Stack (via SkillTool)

    /// AC2 [P0]: SkillTool returns allowedTools field when skill has toolRestrictions.
    func testSkillTool_toolRestrictions_includedInJSON() async throws {
        // Given: a registry with a skill with tool restrictions
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "restricted-skill",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Do restricted things"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "restricted-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: JSON contains allowedTools
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let allowedTools = json["allowedTools"] as? [String]
        XCTAssertNotNil(allowedTools, "allowedTools should be present")
        XCTAssertEqual(Set(allowedTools!), Set(["bash", "read"]))
    }

    /// AC2 [P1]: Skill without toolRestrictions omits allowedTools or returns null.
    func testSkillTool_noRestrictions_noAllowedToolsField() async throws {
        // Given: a registry with a skill without restrictions
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "unrestricted-skill",
            toolRestrictions: nil,
            promptTemplate: "Do anything"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "unrestricted-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: allowedTools is null or absent
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        if let allowedTools = json["allowedTools"] {
            XCTAssertNil(allowedTools, "allowedTools should be nil when no restrictions, got: \(allowedTools)")
        }
    }

    // MARK: - AC8: Turn Budget Sharing

    /// AC8 [P0]: SkillTool does not allocate independent turn budget.
    /// Verify the SkillTool result does not contain turnBudget or maxTurns fields.
    func testSkillTool_noIndependentTurnBudget() async throws {
        // Given: a registry with a skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "budget-skill",
            promptTemplate: "Do budget things"
        ))

        // When: calling the SkillTool
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "budget-skill"]
        let result = await tool.call(input: input, context: context)

        // Then: result JSON should not have turnBudget or maxTurns
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertNil(json["turnBudget"], "SkillTool should not allocate independent turn budget")
        XCTAssertNil(json["maxTurns"], "SkillTool should not set independent maxTurns")
    }

    // MARK: - Integration: Optional args parameter

    /// [P1]: SkillTool accepts optional args parameter.
    func testSkillTool_optionalArgs_acceptedInInput() async throws {
        // Given: a registry with a skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "args-skill",
            promptTemplate: "Process with args"
        ))

        // When: calling with both skill and args
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "args-skill", "args": "some arguments here"]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")
    }

    // MARK: - Integration: BuiltInSkills

    /// [P1]: SkillTool works with BuiltInSkills.commit.
    func testSkillTool_withBuiltInCommitSkill() async throws {
        // Given: a registry with BuiltInSkills.commit
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.commit)

        // When: calling the SkillTool with "commit"
        let tool = createSkillTool(registry: registry)
        let context = ToolContext(cwd: "/tmp")
        let input: [String: Any] = ["skill": "commit"]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful and contains the commit prompt
        XCTAssertFalse(result.isError, "Expected success, got: \(result.content)")

        let jsonData = result.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(json["commandName"] as? String, "commit")
        XCTAssertNotNil(json["prompt"] as? String)
        XCTAssertTrue((json["prompt"] as? String)?.contains("git commit") ?? false,
                        "Prompt should contain 'git commit'")

        // Commit skill has toolRestrictions
        let allowedTools = json["allowedTools"] as? [String]
        XCTAssertNotNil(allowedTools)
        XCTAssertTrue(allowedTools!.contains("bash"))
        XCTAssertTrue(allowedTools!.contains("read"))
    }
}
