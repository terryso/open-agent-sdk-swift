import XCTest
@testable import OpenAgentSDK

final class LLMSkillEvolverTests: XCTestCase {

    // MARK: - Mock LLM Client

    private static let sharedState = SharedMockState()

    final class SharedMockState: @unchecked Sendable {
        var capturedModel: String?
        var capturedMaxTokens: Int?
        var capturedTemperature: Double?
        var capturedSystem: String?
        var capturedMessages: [[String: Any]]?
        private let lock = NSLock()

        func record(model: String, messages: [[String: Any]], maxTokens: Int, system: String?, temperature: Double?) {
            lock.lock()
            capturedModel = model
            capturedMessages = messages
            capturedMaxTokens = maxTokens
            capturedSystem = system
            capturedTemperature = temperature
            lock.unlock()
        }

        func reset() {
            lock.lock()
            capturedModel = nil
            capturedMessages = nil
            capturedMaxTokens = nil
            capturedSystem = nil
            capturedTemperature = nil
            lock.unlock()
        }
    }

    struct MockLLMClient: LLMClient, Sendable {
        let responseText: String
        let shouldThrow: Bool

        init(responseText: String = "{}", shouldThrow: Bool = false) {
            self.responseText = responseText
            self.shouldThrow = shouldThrow
        }

        nonisolated func sendMessage(
            model: String,
            messages: [[String: Any]],
            maxTokens: Int,
            system: String?,
            tools: [[String: Any]]?,
            toolChoice: [String: Any]?,
            thinking: [String: Any]?,
            temperature: Double?
        ) async throws -> [String: Any] {
            if shouldThrow {
                throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "LLM call failed"])
            }
            LLMSkillEvolverTests.sharedState.record(
                model: model, messages: messages, maxTokens: maxTokens, system: system, temperature: temperature
            )
            return ["content": [["type": "text", "text": responseText]] as [[String: Any]]]
        }

        nonisolated func streamMessage(
            model: String,
            messages: [[String: Any]],
            maxTokens: Int,
            system: String?,
            tools: [[String: Any]]?,
            toolChoice: [String: Any]?,
            thinking: [String: Any]?,
            temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            AsyncThrowingStream { _ in }
        }
    }

    // MARK: - Helpers

    private func sampleSkill() -> Skill {
        Skill(
            name: "commit",
            description: "Create a git commit",
            aliases: ["ci"],
            toolRestrictions: [.bash, .read],
            promptTemplate: "Analyze changes and commit.",
            whenToUse: "When the user wants to commit",
            argumentHint: "[message]",
            supportingFiles: ["template.md"]
        )
    }

    private func refinementSignal(skillName: String = "commit", confidence: Double = 0.8) -> SkillSignal {
        SkillSignal.create(
            skillName: skillName,
            signalType: .refinement,
            content: "Users frequently ask for conventional commits format",
            confidence: confidence,
            source: .usageAnalysis
        )
    }

    private func deprecationSignal(skillName: String = "commit") -> SkillSignal {
        SkillSignal.create(
            skillName: skillName,
            signalType: .deprecation,
            content: "Skill is never invoked",
            confidence: 0.9,
            source: .usageAnalysis
        )
    }

    private func resetState() {
        LLMSkillEvolverTests.sharedState.reset()
    }

    // MARK: - Initialization Tests

    func testDefaultModel() {
        let evolver = LLMSkillEvolver(client: MockLLMClient())
        XCTAssertEqual(evolver.evolutionModel, "claude-haiku-4-5-20251001")
    }

    func testCustomModel() {
        let evolver = LLMSkillEvolver(client: MockLLMClient(), evolutionModel: "claude-sonnet-4-6")
        XCTAssertEqual(evolver.evolutionModel, "claude-sonnet-4-6")
    }

    // MARK: - No-Op for No Applicable Signals

    func testNoApplicableSignalsReturnsNoOp() async throws {
        let evolver = LLMSkillEvolver(client: MockLLMClient())
        let skill = sampleSkill()

        // Signal for a different skill
        let signal = SkillSignal.create(
            skillName: "other-skill",
            signalType: .refinement,
            content: "Improve something",
            confidence: 0.8,
            source: .usageAnalysis
        )

        let result = try await evolver.evolve(skill: skill, signals: [signal], config: SkillEvolutionConfig())

        XCTAssertNil(result.evolvedSkill)
        XCTAssertTrue(result.appliedSignals.isEmpty)
        XCTAssertEqual(result.skippedSignals.count, 1)
        XCTAssertTrue(result.changes.isEmpty)
    }

    func testEmptySignalsReturnsNoOp() async throws {
        let evolver = LLMSkillEvolver(client: MockLLMClient())

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [],
            config: SkillEvolutionConfig()
        )

        XCTAssertNil(result.evolvedSkill)
        XCTAssertTrue(result.appliedSignals.isEmpty)
        XCTAssertTrue(result.skippedSignals.isEmpty)
        XCTAssertTrue(result.changes.isEmpty)
    }

    // MARK: - Refinement Signal → Evolved Skill

    func testRefinementSignalProducesEvolvedSkill() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "promptTemplate": "Analyze changes using conventional commits format.",
                "whenToUse": "When the user wants to commit with conventional format"
            },
            "changes": ["Updated promptTemplate to use conventional commits", "Updated whenToUse description"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)
        let skill = sampleSkill()
        let signal = refinementSignal()

        let result = try await evolver.evolve(skill: skill, signals: [signal], config: SkillEvolutionConfig())

        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill!.promptTemplate, "Analyze changes using conventional commits format.")
        XCTAssertEqual(result.evolvedSkill!.whenToUse, "When the user wants to commit with conventional format")
        // Original fields preserved
        XCTAssertEqual(result.evolvedSkill!.name, "commit")
        XCTAssertEqual(result.evolvedSkill!.description, "Create a git commit")
        XCTAssertEqual(result.evolvedSkill!.aliases, ["ci"])
        XCTAssertEqual(result.evolvedSkill!.argumentHint, "[message]")
        XCTAssertEqual(result.appliedSignals.count, 1)
        XCTAssertEqual(result.changes.count, 2)
    }

    // MARK: - Deprecation Signal → Lifecycle State Change

    func testDeprecationSignalProducesLifecycleStateChange() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "lifecycleState": "deprecated",
                "description": "Deprecated: skill is never invoked"
            },
            "changes": ["Marked skill as deprecated due to zero usage"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)
        let signal = deprecationSignal()

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [signal],
            config: SkillEvolutionConfig()
        )

        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill!.lifecycleState, .deprecated)
        XCTAssertEqual(result.evolvedSkill!.description, "Deprecated: skill is never invoked")
        // Other fields preserved
        XCTAssertEqual(result.evolvedSkill!.name, "commit")
    }

    // MARK: - DryRun Config

    func testDryRunReturnsNilEvolvedSkillButPopulatedChanges() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "promptTemplate": "New template"
            },
            "changes": ["Would update promptTemplate"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [refinementSignal()],
            config: SkillEvolutionConfig(dryRun: true)
        )

        XCTAssertNil(result.evolvedSkill, "dryRun should produce nil evolvedSkill")
        XCTAssertEqual(result.changes.count, 1, "dryRun should still populate changes")
        XCTAssertEqual(result.appliedSignals.count, 1, "dryRun should still populate appliedSignals")
    }

    // MARK: - Signal Filtering

    func testFiltersByConfidence() async throws {
        let evolver = LLMSkillEvolver(client: MockLLMClient())

        let signal = refinementSignal(confidence: 0.2)
        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [signal],
            config: SkillEvolutionConfig(minConfidence: 0.4)
        )

        XCTAssertNil(result.evolvedSkill, "Below-threshold signal should produce no-op")
        XCTAssertTrue(result.appliedSignals.isEmpty)
        XCTAssertEqual(result.skippedSignals.count, 1)
    }

    func testFiltersByAllowedSignalTypes() async throws {
        let evolver = LLMSkillEvolver(client: MockLLMClient())
        let signal = refinementSignal()

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [signal],
            config: SkillEvolutionConfig(allowedSignalTypes: [.deprecation])
        )

        XCTAssertNil(result.evolvedSkill, "Wrong signal type should produce no-op")
        XCTAssertTrue(result.appliedSignals.isEmpty)
        XCTAssertEqual(result.skippedSignals.count, 1)
    }

    func testNewSkillSignalIsApplicableToAnySkill() async throws {
        let json = """
        {"shouldEvolve": true, "evolvedSkill": {"description": "New pattern detected"}, "changes": ["Updated description"]}
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let signal = SkillSignal.create(
            skillName: "unrelated",
            signalType: .newSkill,
            content: "Observed repeated pattern for commit",
            confidence: 0.8,
            source: .conversation
        )

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [signal],
            config: SkillEvolutionConfig()
        )

        XCTAssertEqual(result.appliedSignals.count, 1, "newSkill signals apply to any skill")
        XCTAssertNotNil(result.evolvedSkill)
    }

    // MARK: - JSON Parsing

    func testParseValidJSON() async throws {
        let json = """
        {"shouldEvolve": true, "evolvedSkill": {"promptTemplate": "new"}, "changes": ["change 1"]}
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [refinementSignal()],
            config: SkillEvolutionConfig()
        )

        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill!.promptTemplate, "new")
    }

    func testParseCodeFencedJSON() async throws {
        let json = """
        ```json
        {"shouldEvolve": true, "evolvedSkill": {"description": "fenced"}, "changes": ["change"]}
        ```
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [refinementSignal()],
            config: SkillEvolutionConfig()
        )

        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill!.description, "fenced")
    }

    func testParseMalformedJSONReturnsNoOp() async throws {
        let client = MockLLMClient(responseText: "this is not json")
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [refinementSignal()],
            config: SkillEvolutionConfig()
        )

        XCTAssertNil(result.evolvedSkill, "Malformed JSON should produce nil evolvedSkill")
        XCTAssertTrue(result.changes.isEmpty)
    }

    func testParseEmptyResponseReturnsNoOp() async throws {
        let client = MockLLMClient(responseText: "")
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [refinementSignal()],
            config: SkillEvolutionConfig()
        )

        XCTAssertNil(result.evolvedSkill)
        XCTAssertTrue(result.changes.isEmpty)
    }

    func testShouldEvolveFalseReturnsNoOp() async throws {
        let json = """
        {"shouldEvolve": false, "changes": []}
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [refinementSignal()],
            config: SkillEvolutionConfig()
        )

        XCTAssertNil(result.evolvedSkill)
        XCTAssertEqual(result.appliedSignals.count, 1, "Signals were still applied (processed)")
    }

    // MARK: - Field Merging (Partial Override)

    func testPartialOverridePreservesOriginalFields() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "argumentHint": "[message] [type]"
            },
            "changes": ["Updated argumentHint"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)
        let skill = sampleSkill()

        let result = try await evolver.evolve(skill: skill, signals: [refinementSignal()], config: SkillEvolutionConfig())

        let evolved = result.evolvedSkill!
        XCTAssertEqual(evolved.argumentHint, "[message] [type]", "LLM override should be used")
        XCTAssertEqual(evolved.promptTemplate, skill.promptTemplate, "Original promptTemplate preserved")
        XCTAssertEqual(evolved.description, skill.description, "Original description preserved")
        XCTAssertEqual(evolved.whenToUse, skill.whenToUse, "Original whenToUse preserved")
        XCTAssertEqual(evolved.aliases, skill.aliases, "Original aliases preserved")
        XCTAssertEqual(evolved.toolRestrictions, skill.toolRestrictions, "Original toolRestrictions preserved")
        XCTAssertEqual(evolved.name, skill.name, "Name is never changed")
    }

    func testToolRestrictionsOverride() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "toolRestrictions": ["bash", "read", "glob"]
            },
            "changes": ["Added glob tool"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        XCTAssertEqual(result.evolvedSkill!.toolRestrictions, [.bash, .read, .glob])
    }

    func testAliasesMerge() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "aliases": ["git-commit"]
            },
            "changes": ["Added git-commit alias"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        let aliases = result.evolvedSkill!.aliases
        XCTAssertTrue(aliases.contains("ci"), "Original alias preserved")
        XCTAssertTrue(aliases.contains("git-commit"), "New alias added")
    }

    func testSupportingFilesMerge() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "supportingFiles": ["conventions.md"]
            },
            "changes": ["Added conventions.md"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        let files = result.evolvedSkill!.supportingFiles
        XCTAssertTrue(files.contains("template.md"), "Original supporting file preserved")
        XCTAssertTrue(files.contains("conventions.md"), "New supporting file added")
    }

    // MARK: - Error Propagation

    func testPropagatesLLMError() async {
        let client = MockLLMClient(shouldThrow: true)
        let evolver = LLMSkillEvolver(client: client)

        do {
            _ = try await evolver.evolve(
                skill: sampleSkill(),
                signals: [refinementSignal()],
                config: SkillEvolutionConfig()
            )
            XCTFail("Expected error to be thrown")
        } catch let error as SDKError {
            if case .apiError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 0)
                XCTAssertTrue(message.contains("Skill evolution failed"))
            } else {
                XCTFail("Expected apiError, got \(error)")
            }
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    // MARK: - System Prompt Content Verification

    func testSystemPromptContainsSkillFields() async throws {
        resetState()
        let client = MockLLMClient(responseText: "{\"shouldEvolve\": false, \"changes\": []}")
        let evolver = LLMSkillEvolver(client: client)
        let skill = sampleSkill()

        _ = try await evolver.evolve(skill: skill, signals: [refinementSignal()], config: SkillEvolutionConfig())

        let captured = LLMSkillEvolverTests.sharedState.capturedSystem
        XCTAssertNotNil(captured)
        let prompt = captured!
        XCTAssertTrue(prompt.contains(skill.name), "System prompt should contain skill name")
        XCTAssertTrue(prompt.contains(skill.description), "System prompt should contain skill description")
        XCTAssertTrue(prompt.contains(skill.promptTemplate), "System prompt should contain promptTemplate")
        XCTAssertTrue(prompt.contains("When the user wants to commit"), "System prompt should contain whenToUse")
        XCTAssertTrue(prompt.contains("[message]"), "System prompt should contain argumentHint")
    }

    func testSystemPromptContainsSignalContext() async throws {
        resetState()
        let client = MockLLMClient(responseText: "{\"shouldEvolve\": false, \"changes\": []}")
        let evolver = LLMSkillEvolver(client: client)

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Add conventional commits",
            confidence: 0.9,
            source: .conversation
        )

        _ = try await evolver.evolve(skill: sampleSkill(), signals: [signal], config: SkillEvolutionConfig())

        let captured = LLMSkillEvolverTests.sharedState.capturedSystem!
        // Signal content is serialized inside the system prompt
        XCTAssertTrue(captured.contains("refinement"), "System prompt should include signal type")
        XCTAssertTrue(captured.contains("Add conventional commits"), "System prompt should include signal content")
        XCTAssertTrue(captured.contains("conversation"), "System prompt should include signal source")
    }

    func testSystemPromptContainsEvolutionGuidance() async throws {
        resetState()
        let client = MockLLMClient(responseText: "{\"shouldEvolve\": false, \"changes\": []}")
        let evolver = LLMSkillEvolver(client: client)

        _ = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        let prompt = LLMSkillEvolverTests.sharedState.capturedSystem!
        XCTAssertTrue(prompt.contains("refinement"), "Should contain refinement guidance")
        XCTAssertTrue(prompt.contains("deprecation"), "Should contain deprecation guidance")
        XCTAssertTrue(prompt.contains("merge"), "Should contain merge guidance")
        XCTAssertTrue(prompt.contains("split"), "Should contain split guidance")
        XCTAssertTrue(prompt.contains("newSkill"), "Should contain newSkill guidance")
        XCTAssertTrue(prompt.contains("shouldEvolve"), "Should specify output format")
        XCTAssertTrue(prompt.contains("UPDATE"), "Should contain Hermes priority")
    }

    // MARK: - LLM Parameters

    func testUsesCorrectLLMParameters() async throws {
        resetState()
        let client = MockLLMClient(responseText: "{\"shouldEvolve\": false, \"changes\": []}")
        let evolver = LLMSkillEvolver(client: client)

        _ = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        XCTAssertEqual(LLMSkillEvolverTests.sharedState.capturedModel, "claude-haiku-4-5-20251001")
        XCTAssertEqual(LLMSkillEvolverTests.sharedState.capturedMaxTokens, 2048)
        XCTAssertEqual(LLMSkillEvolverTests.sharedState.capturedTemperature, 0.3)
    }

    // MARK: - Merge and Split Signal Types

    func testMergeSignalProducesEvolvedSkill() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "description": "Combined commit and push skill",
                "promptTemplate": "Analyze changes, commit, and push to remote."
            },
            "changes": ["Merged commit with push functionality"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .merge,
            content: "Commit and push skills overlap heavily",
            confidence: 0.8,
            source: .curation
        )

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [signal], config: SkillEvolutionConfig())

        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill!.description, "Combined commit and push skill")
        XCTAssertEqual(result.appliedSignals.count, 1)
    }

    func testSplitSignalProducesEvolvedSkill() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "description": "Create a git commit (narrowed scope)",
                "promptTemplate": "Analyze staged changes only and commit."
            },
            "changes": ["Narrowed scope to staged changes only"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .split,
            content: "Skill handles too many commit variants",
            confidence: 0.75,
            source: .usageAnalysis
        )

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [signal], config: SkillEvolutionConfig())

        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill!.promptTemplate, "Analyze staged changes only and commit.")
    }

    // MARK: - Invalid ToolRestrictions

    func testInvalidToolRestrictionsIgnored() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "toolRestrictions": ["bash", "read", "invalid_tool", "glob"]
            },
            "changes": ["Added glob tool"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        let restrictions = result.evolvedSkill!.toolRestrictions!
        XCTAssertTrue(restrictions.contains(.bash))
        XCTAssertTrue(restrictions.contains(.read))
        XCTAssertTrue(restrictions.contains(.glob))
        XCTAssertEqual(restrictions.count, 3, "Invalid tool restriction should be filtered out")
    }

    // MARK: - Duplicate Alias Deduplication

    func testDuplicateAliasNotAdded() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "aliases": ["ci", "new-alias"]
            },
            "changes": ["Added new-alias"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        let aliases = result.evolvedSkill!.aliases
        let ciCount = aliases.filter { $0 == "ci" }.count
        XCTAssertEqual(ciCount, 1, "Duplicate alias should not appear twice")
        XCTAssertTrue(aliases.contains("new-alias"))
    }

    // MARK: - Duplicate Supporting File Deduplication

    func testDuplicateSupportingFileNotAdded() async throws {
        let json = """
        {
            "shouldEvolve": true,
            "evolvedSkill": {
                "supportingFiles": ["template.md", "new-file.md"]
            },
            "changes": ["Added new-file.md"]
        }
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let result = try await evolver.evolve(skill: sampleSkill(), signals: [refinementSignal()], config: SkillEvolutionConfig())

        let files = result.evolvedSkill!.supportingFiles
        let templateCount = files.filter { $0 == "template.md" }.count
        XCTAssertEqual(templateCount, 1, "Duplicate supporting file should not appear twice")
        XCTAssertTrue(files.contains("new-file.md"))
    }

    // MARK: - Mixed Signal Filtering

    func testMixedSignalsFiltersCorrectly() async throws {
        let json = """
        {"shouldEvolve": true, "evolvedSkill": {"description": "evolved"}, "changes": ["changed"]}
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let applicable = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Good signal",
            confidence: 0.8,
            source: .usageAnalysis
        )
        let wrongSkill = SkillSignal.create(
            skillName: "other",
            signalType: .refinement,
            content: "Wrong skill",
            confidence: 0.8,
            source: .usageAnalysis
        )
        let lowConfidence = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Low confidence",
            confidence: 0.1,
            source: .usageAnalysis
        )
        let wrongType = SkillSignal.create(
            skillName: "commit",
            signalType: .deprecation,
            content: "Wrong type",
            confidence: 0.8,
            source: .usageAnalysis
        )

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: [applicable, wrongSkill, lowConfidence, wrongType],
            config: SkillEvolutionConfig(allowedSignalTypes: [.refinement])
        )

        XCTAssertEqual(result.appliedSignals.count, 1, "Only applicable signal should pass")
        XCTAssertEqual(result.skippedSignals.count, 3, "Other signals should be skipped")
        XCTAssertNotNil(result.evolvedSkill)
    }

    // MARK: - Max Signals Limit

    func testRespectsMaxSignalsPerEvolution() async throws {
        let json = """
        {"shouldEvolve": true, "evolvedSkill": {"description": "evolved"}, "changes": ["changed"]}
        """
        let client = MockLLMClient(responseText: json)
        let evolver = LLMSkillEvolver(client: client)

        let signals = (0..<5).map { i in
            SkillSignal.create(
                skillName: "commit",
                signalType: .refinement,
                content: "Signal \(i)",
                confidence: 0.8,
                source: .usageAnalysis
            )
        }

        let result = try await evolver.evolve(
            skill: sampleSkill(),
            signals: signals,
            config: SkillEvolutionConfig(maxSignalsPerEvolution: 2)
        )

        XCTAssertEqual(result.appliedSignals.count, 2)
        XCTAssertEqual(result.skippedSignals.count, 3)
    }
}
