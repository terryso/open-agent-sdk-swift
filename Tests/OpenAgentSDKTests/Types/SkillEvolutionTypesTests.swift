import XCTest
@testable import OpenAgentSDK

final class SkillEvolutionTypesTests: XCTestCase {

    // MARK: - SkillSignalType

    func testSkillSignalTypeCases() {
        XCTAssertEqual(SkillSignalType.allCases.count, 5)
        XCTAssertEqual(SkillSignalType.refinement.rawValue, "refinement")
        XCTAssertEqual(SkillSignalType.deprecation.rawValue, "deprecation")
        XCTAssertEqual(SkillSignalType.merge.rawValue, "merge")
        XCTAssertEqual(SkillSignalType.split.rawValue, "split")
        XCTAssertEqual(SkillSignalType.newSkill.rawValue, "newSkill")
    }

    // MARK: - SkillEvolutionSource

    func testSkillEvolutionSourceCases() {
        XCTAssertEqual(SkillEvolutionSource.usageAnalysis.rawValue, "usageAnalysis")
        XCTAssertEqual(SkillEvolutionSource.conversation.rawValue, "conversation")
        XCTAssertEqual(SkillEvolutionSource.curation.rawValue, "curation")
        XCTAssertEqual(SkillEvolutionSource.manual.rawValue, "manual")
    }

    // MARK: - SkillSignal.create() determinism

    func testSkillSignalCreateDeterministic() {
        let a = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Improve error handling",
            source: .conversation
        )
        let b = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Improve error handling",
            source: .conversation
        )
        XCTAssertEqual(a.id, b.id)
    }

    func testSkillSignalCreateDifferentInputsProduceDifferentIds() {
        let a = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "A",
            source: .conversation
        )
        let b = SkillSignal.create(
            skillName: "review",
            signalType: .refinement,
            content: "A",
            source: .conversation
        )
        XCTAssertNotEqual(a.id, b.id)
    }

    func testSkillSignalCreateNormalizedSkillName() {
        let upper = SkillSignal.create(
            skillName: "Commit",
            signalType: .refinement,
            content: "test",
            source: .manual
        )
        let lower = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "test",
            source: .manual
        )
        XCTAssertEqual(upper.id, lower.id, "Skill name should be normalized for id generation")
    }

    func testSkillSignalCreateTrimmedSkillName() {
        let padded = SkillSignal.create(
            skillName: "  commit  ",
            signalType: .refinement,
            content: "test",
            source: .manual
        )
        let clean = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "test",
            source: .manual
        )
        XCTAssertEqual(padded.id, clean.id, "Skill name should be trimmed for id generation")
    }

    // MARK: - SkillSignal confidence clamping

    func testSkillSignalConfidenceClampedNegative() {
        let signal = SkillSignal.create(
            skillName: "test",
            signalType: .refinement,
            content: "test",
            confidence: -0.5,
            source: .manual
        )
        XCTAssertEqual(signal.confidence, 0.0)
    }

    func testSkillSignalConfidenceClampedAboveOne() {
        let signal = SkillSignal.create(
            skillName: "test",
            signalType: .refinement,
            content: "test",
            confidence: 2.0,
            source: .manual
        )
        XCTAssertEqual(signal.confidence, 1.0)
    }

    func testSkillSignalConfidenceDefault() {
        let signal = SkillSignal.create(
            skillName: "test",
            signalType: .refinement,
            content: "test",
            source: .manual
        )
        XCTAssertEqual(signal.confidence, 0.5)
    }

    func testSkillSignalConfidenceValid() {
        let signal = SkillSignal.create(
            skillName: "test",
            signalType: .refinement,
            content: "test",
            confidence: 0.8,
            source: .manual
        )
        XCTAssertEqual(signal.confidence, 0.8)
    }

    // MARK: - SkillSignal.isApplicable(to:)

    func testSkillSignalIsApplicableMatchingName() {
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Improve",
            source: .conversation
        )
        let skill = Skill(name: "commit", promptTemplate: "tpl")
        XCTAssertTrue(signal.isApplicable(to: skill))
    }

    func testSkillSignalIsApplicableNonMatchingName() {
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Improve",
            source: .conversation
        )
        let skill = Skill(name: "review", promptTemplate: "tpl")
        XCTAssertFalse(signal.isApplicable(to: skill))
    }

    func testSkillSignalIsApplicableNewSkillWildcard() {
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .newSkill,
            content: "Pattern observed",
            source: .conversation
        )
        let skill = Skill(name: "review", promptTemplate: "tpl")
        XCTAssertTrue(signal.isApplicable(to: skill))
    }

    // MARK: - SkillEvolutionConfig defaults

    func testSkillEvolutionConfigDefaults() {
        let config = SkillEvolutionConfig()
        XCTAssertEqual(config.maxSignalsPerEvolution, 5)
        XCTAssertEqual(config.minConfidence, 0.4)
        XCTAssertNil(config.allowedSignalTypes)
        XCTAssertFalse(config.dryRun)
        XCTAssertTrue(config.preserveOriginal)
    }

    func testSkillEvolutionConfigCustomInit() {
        let config = SkillEvolutionConfig(
            maxSignalsPerEvolution: 10,
            minConfidence: 0.7,
            allowedSignalTypes: [.refinement, .deprecation],
            dryRun: true,
            preserveOriginal: false
        )
        XCTAssertEqual(config.maxSignalsPerEvolution, 10)
        XCTAssertEqual(config.minConfidence, 0.7)
        XCTAssertEqual(config.allowedSignalTypes, [.refinement, .deprecation])
        XCTAssertTrue(config.dryRun)
        XCTAssertFalse(config.preserveOriginal)
    }

    // MARK: - SkillEvolutionResult construction

    func testSkillEvolutionResultWithEvolvedSkill() {
        let skill = Skill(name: "commit", promptTemplate: "improved template")
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Update",
            source: .conversation
        )
        let result = SkillEvolutionResult(
            evolvedSkill: skill,
            appliedSignals: [signal],
            skippedSignals: [],
            changes: ["Updated promptTemplate"]
        )
        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.evolvedSkill?.name, "commit")
        XCTAssertEqual(result.appliedSignals.count, 1)
        XCTAssertTrue(result.skippedSignals.isEmpty)
        XCTAssertEqual(result.changes, ["Updated promptTemplate"])
    }

    func testSkillEvolutionResultNoEvolution() {
        let result = SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [],
            skippedSignals: [],
            changes: []
        )
        XCTAssertNil(result.evolvedSkill)
        XCTAssertTrue(result.changes.isEmpty)
    }

    // MARK: - SkillLifecycleState

    func testSkillLifecycleStateCases() {
        XCTAssertEqual(SkillLifecycleState.allCases.count, 4)
        XCTAssertEqual(SkillLifecycleState.active.rawValue, "active")
        XCTAssertEqual(SkillLifecycleState.deprecated.rawValue, "deprecated")
        XCTAssertEqual(SkillLifecycleState.experimental.rawValue, "experimental")
        XCTAssertEqual(SkillLifecycleState.retired.rawValue, "retired")
    }

    // MARK: - Skill lifecycleState field

    func testSkillLifecycleStateDefaultNil() {
        let skill = Skill(name: "test", promptTemplate: "tpl")
        XCTAssertNil(skill.lifecycleState)
    }

    func testSkillLifecycleStateExplicit() {
        let skill = Skill(name: "test", promptTemplate: "tpl", lifecycleState: .experimental)
        XCTAssertEqual(skill.lifecycleState, .experimental)
    }

    func testSkillEqualityWithLifecycleState() {
        let a = Skill(name: "test", promptTemplate: "tpl", lifecycleState: .deprecated)
        let b = Skill(name: "test", promptTemplate: "tpl", lifecycleState: .deprecated)
        XCTAssertEqual(a, b)
    }

    func testSkillInequalityWithLifecycleState() {
        let a = Skill(name: "test", promptTemplate: "tpl", lifecycleState: .active)
        let b = Skill(name: "test", promptTemplate: "tpl", lifecycleState: .retired)
        XCTAssertNotEqual(a, b)
    }

    func testSkillEqualityIgnoresIsAvailable() {
        let a = Skill(name: "test", isAvailable: { true }, promptTemplate: "tpl")
        let b = Skill(name: "test", isAvailable: { false }, promptTemplate: "tpl")
        XCTAssertEqual(a, b, "Skills with different isAvailable closures should still be equal")
    }

    // MARK: - SkillSignal Codable round-trip

    func testSkillSignalCodableRoundTrip() throws {
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Improve error handling",
            confidence: 0.75,
            source: .conversation,
            metadata: ["sessionId": "abc123", "turnIndex": "3"]
        )
        let data = try JSONEncoder().encode(signal)
        let decoded = try JSONDecoder().decode(SkillSignal.self, from: data)
        XCTAssertEqual(decoded.id, signal.id)
        XCTAssertEqual(decoded.skillName, signal.skillName)
        XCTAssertEqual(decoded.signalType, signal.signalType)
        XCTAssertEqual(decoded.content, signal.content)
        XCTAssertEqual(decoded.confidence, signal.confidence)
        XCTAssertEqual(decoded.source, signal.source)
        XCTAssertEqual(decoded.metadata, signal.metadata)
        // createdAt is preserved through Codable round-trip
        XCTAssertEqual(decoded.createdAt.timeIntervalSinceReferenceDate, signal.createdAt.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }

    func testSkillSignalCodableNilMetadata() throws {
        let signal = SkillSignal.create(
            skillName: "review",
            signalType: .deprecation,
            content: "Never used",
            source: .usageAnalysis
        )
        let data = try JSONEncoder().encode(signal)
        let decoded = try JSONDecoder().decode(SkillSignal.self, from: data)
        XCTAssertNil(decoded.metadata)
    }

    func testSkillSignalDecoderClampsConfidence() throws {
        let json = """
        {"id":"test","skillName":"x","signalType":"refinement","content":"c","confidence":-5.0,"source":"manual","createdAt":0.0}
        """
        let decoded = try JSONDecoder().decode(SkillSignal.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded.confidence, 0.0)
    }

    func testSkillSignalDecoderClampsConfidenceAboveOne() throws {
        let json = """
        {"id":"test","skillName":"x","signalType":"refinement","content":"c","confidence":99.0,"source":"manual","createdAt":0.0}
        """
        let decoded = try JSONDecoder().decode(SkillSignal.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded.confidence, 1.0)
    }

    func testSkillSignalEmptyStrings() {
        let signal = SkillSignal.create(
            skillName: "",
            signalType: .newSkill,
            content: "",
            source: .manual
        )
        XCTAssertEqual(signal.skillName, "")
        XCTAssertEqual(signal.content, "")
    }

    // MARK: - SkillEvolutionConfig Codable

    func testSkillEvolutionConfigCodableDefaults() throws {
        let config = SkillEvolutionConfig()
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SkillEvolutionConfig.self, from: data)
        XCTAssertEqual(decoded.maxSignalsPerEvolution, 5)
        XCTAssertEqual(decoded.minConfidence, 0.4)
        XCTAssertNil(decoded.allowedSignalTypes)
        XCTAssertFalse(decoded.dryRun)
        XCTAssertTrue(decoded.preserveOriginal)
    }

    func testSkillEvolutionConfigCodableCustom() throws {
        let config = SkillEvolutionConfig(
            maxSignalsPerEvolution: 3,
            minConfidence: 0.8,
            allowedSignalTypes: [.merge, .split],
            dryRun: true,
            preserveOriginal: false
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SkillEvolutionConfig.self, from: data)
        XCTAssertEqual(decoded.maxSignalsPerEvolution, 3)
        XCTAssertEqual(decoded.minConfidence, 0.8)
        XCTAssertEqual(decoded.allowedSignalTypes, [.merge, .split])
        XCTAssertTrue(decoded.dryRun)
        XCTAssertFalse(decoded.preserveOriginal)
    }

    // MARK: - SkillEvolutionResult Codable

    func testSkillEvolutionResultCodableWithSkill() throws {
        let skill = Skill(
            name: "commit",
            description: "Create commit",
            aliases: ["ci"],
            userInvocable: true,
            toolRestrictions: [.bash, .read],
            modelOverride: nil,
            promptTemplate: "Analyze and commit",
            whenToUse: "When committing",
            argumentHint: "[msg]",
            baseDir: nil,
            supportingFiles: [],
            lifecycleState: .experimental
        )
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Better template",
            confidence: 0.9,
            source: .curation
        )
        let result = SkillEvolutionResult(
            evolvedSkill: skill,
            appliedSignals: [signal],
            skippedSignals: [],
            changes: ["Updated promptTemplate"]
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(SkillEvolutionResult.self, from: data)
        XCTAssertNotNil(decoded.evolvedSkill)
        XCTAssertEqual(decoded.evolvedSkill?.name, "commit")
        XCTAssertEqual(decoded.evolvedSkill?.lifecycleState, .experimental)
        XCTAssertEqual(decoded.appliedSignals.count, 1)
        XCTAssertEqual(decoded.appliedSignals.first?.confidence, 0.9)
        XCTAssertTrue(decoded.skippedSignals.isEmpty)
        XCTAssertEqual(decoded.changes, ["Updated promptTemplate"])
    }

    func testSkillEvolutionResultCodableNilSkill() throws {
        let result = SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [],
            skippedSignals: [],
            changes: []
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(SkillEvolutionResult.self, from: data)
        XCTAssertNil(decoded.evolvedSkill)
        XCTAssertTrue(decoded.appliedSignals.isEmpty)
        XCTAssertTrue(decoded.changes.isEmpty)
    }

    func testSkillEvolutionResultCodableWithSkippedSignals() throws {
        let applied = SkillSignal.create(
            skillName: "commit", signalType: .refinement,
            content: "High", confidence: 0.9, source: .conversation
        )
        let skipped = SkillSignal.create(
            skillName: "commit", signalType: .deprecation,
            content: "Low", confidence: 0.1, source: .usageAnalysis
        )
        let result = SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [applied],
            skippedSignals: [skipped],
            changes: []
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(SkillEvolutionResult.self, from: data)
        XCTAssertNil(decoded.evolvedSkill)
        XCTAssertEqual(decoded.appliedSignals.count, 1)
        XCTAssertEqual(decoded.appliedSignals.first?.content, "High")
        XCTAssertEqual(decoded.skippedSignals.count, 1)
        XCTAssertEqual(decoded.skippedSignals.first?.content, "Low")
    }

    func testSkillEvolutionResultEvolutionDateDefault() {
        let before = Date()
        let result = SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [],
            skippedSignals: [],
            changes: []
        )
        let after = Date()
        XCTAssertGreaterThanOrEqual(result.evolutionDate, before)
        XCTAssertLessThanOrEqual(result.evolutionDate, after)
    }

    func testSkillEvolutionResultMixedSignals() {
        let highSignal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "A",
            confidence: 0.9,
            source: .conversation
        )
        let lowSignal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "B",
            confidence: 0.1,
            source: .conversation
        )
        let result = SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [highSignal],
            skippedSignals: [lowSignal],
            changes: []
        )
        XCTAssertEqual(result.appliedSignals.count, 1)
        XCTAssertEqual(result.skippedSignals.count, 1)
        XCTAssertEqual(result.appliedSignals.first?.content, "A")
        XCTAssertEqual(result.skippedSignals.first?.content, "B")
    }

    // MARK: - SkillLifecycleState Codable

    func testSkillLifecycleStateCodableRoundTrip() throws {
        for state in SkillLifecycleState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(SkillLifecycleState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - Mock SkillEvolver with config filtering integration

    func testMockSkillEvolverFiltersByConfidence() async throws {
        let evolver = MockSkillEvolver()
        let skill = Skill(name: "commit", promptTemplate: "old")
        let high = SkillSignal.create(
            skillName: "commit", signalType: .refinement,
            content: "Good", confidence: 0.9, source: .conversation
        )
        let low = SkillSignal.create(
            skillName: "commit", signalType: .refinement,
            content: "Weak", confidence: 0.1, source: .conversation
        )
        let config = SkillEvolutionConfig(minConfidence: 0.5)
        let result = try await evolver.evolve(skill: skill, signals: [high, low], config: config)
        XCTAssertEqual(result.appliedSignals.count, 1)
        XCTAssertEqual(result.appliedSignals.first?.content, "Good")
        XCTAssertEqual(result.skippedSignals.count, 1)
        XCTAssertEqual(result.skippedSignals.first?.content, "Weak")
    }

    func testMockSkillEvolverFiltersByAllowedSignalTypes() async throws {
        let evolver = MockSkillEvolver()
        let skill = Skill(name: "commit", promptTemplate: "old")
        let refinement = SkillSignal.create(
            skillName: "commit", signalType: .refinement,
            content: "Allowed", confidence: 0.9, source: .conversation
        )
        let deprecation = SkillSignal.create(
            skillName: "commit", signalType: .deprecation,
            content: "Blocked", confidence: 0.9, source: .conversation
        )
        let config = SkillEvolutionConfig(
            minConfidence: 0.5,
            allowedSignalTypes: [.refinement]
        )
        let result = try await evolver.evolve(skill: skill, signals: [refinement, deprecation], config: config)
        XCTAssertEqual(result.appliedSignals.count, 1)
        XCTAssertEqual(result.appliedSignals.first?.signalType, .refinement)
        XCTAssertEqual(result.skippedSignals.count, 1)
        XCTAssertEqual(result.skippedSignals.first?.signalType, .deprecation)
    }

    // MARK: - SkillProvenance

    func testSkillProvenanceCases() {
        XCTAssertEqual(SkillProvenance.allCases.count, 4)
        XCTAssertEqual(SkillProvenance.agentCreated.rawValue, "agentCreated")
        XCTAssertEqual(SkillProvenance.bundled.rawValue, "bundled")
        XCTAssertEqual(SkillProvenance.userDefined.rawValue, "userDefined")
        XCTAssertEqual(SkillProvenance.hubInstalled.rawValue, "hubInstalled")
    }

    // MARK: - SkillUsageData

    func testSkillUsageDataDefaults() {
        let data = SkillUsageData(skillName: "test")
        XCTAssertEqual(data.skillName, "test")
        XCTAssertEqual(data.viewCount, 0)
        XCTAssertNil(data.lastViewedAt)
        XCTAssertNil(data.lastManagedAt)
        XCTAssertFalse(data.pinned)
        XCTAssertEqual(data.provenance, .userDefined)
    }

    func testSkillUsageDataCustomInit() {
        let date = Date()
        let data = SkillUsageData(
            skillName: "commit",
            viewCount: 5,
            lastViewedAt: date,
            lastManagedAt: date,
            pinned: true,
            provenance: .bundled
        )
        XCTAssertEqual(data.skillName, "commit")
        XCTAssertEqual(data.viewCount, 5)
        XCTAssertEqual(data.lastViewedAt, date)
        XCTAssertEqual(data.lastManagedAt, date)
        XCTAssertTrue(data.pinned)
        XCTAssertEqual(data.provenance, .bundled)
    }

    func testSkillUsageDataCodableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let data = SkillUsageData(
            skillName: "review",
            viewCount: 42,
            lastViewedAt: date,
            lastManagedAt: date,
            pinned: true,
            provenance: .agentCreated
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SkillUsageData.self, from: jsonData)
        XCTAssertEqual(decoded, data)
    }

    func testSkillUsageDataCurrentLifecycleStateNoViews() {
        let data = SkillUsageData(skillName: "new")
        XCTAssertEqual(data.currentLifecycleState, .experimental)
    }

    func testSkillUsageDataCurrentLifecycleStateRecent() {
        let data = SkillUsageData(skillName: "active", viewCount: 10, lastViewedAt: Date())
        XCTAssertEqual(data.currentLifecycleState, .active)
    }

    // MARK: - SkillUsageTrackerConfig

    func testSkillUsageTrackerConfigDefaults() {
        let config = SkillUsageTrackerConfig()
        XCTAssertEqual(config.staleAfterDays, 30)
        XCTAssertEqual(config.archiveAfterDays, 90)
        XCTAssertTrue(config.protectExperimental)
    }

    func testSkillUsageTrackerConfigCustomInit() {
        let config = SkillUsageTrackerConfig(
            staleAfterDays: 14,
            archiveAfterDays: 60,
            protectExperimental: false
        )
        XCTAssertEqual(config.staleAfterDays, 14)
        XCTAssertEqual(config.archiveAfterDays, 60)
        XCTAssertFalse(config.protectExperimental)
    }

    func testSkillUsageTrackerConfigCodableRoundTrip() throws {
        let config = SkillUsageTrackerConfig(staleAfterDays: 7, archiveAfterDays: 30, protectExperimental: false)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SkillUsageTrackerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - SkillLifecycleTransition

    func testSkillLifecycleTransitionConstruction() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let transition = SkillLifecycleTransition(
            skillName: "old-skill",
            from: .active,
            to: .deprecated,
            reason: "Skill not viewed for 35 days (threshold: 30 days)",
            evaluatedAt: date
        )
        XCTAssertEqual(transition.skillName, "old-skill")
        XCTAssertEqual(transition.from, .active)
        XCTAssertEqual(transition.to, .deprecated)
        XCTAssertEqual(transition.reason, "Skill not viewed for 35 days (threshold: 30 days)")
        XCTAssertEqual(transition.evaluatedAt, date)
    }

    func testSkillLifecycleTransitionCodableRoundTrip() throws {
        let transition = SkillLifecycleTransition(
            skillName: "test",
            from: .deprecated,
            to: .retired,
            reason: "No longer used"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(transition)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SkillLifecycleTransition.self, from: data)
        XCTAssertEqual(decoded.skillName, transition.skillName)
        XCTAssertEqual(decoded.from, transition.from)
        XCTAssertEqual(decoded.to, transition.to)
        XCTAssertEqual(decoded.reason, transition.reason)
    }

    // MARK: - CuratorState

    func testCuratorStateDefaults() {
        let state = CuratorState.defaultState()
        XCTAssertNil(state.lastRunAt)
        XCTAssertFalse(state.paused)
        XCTAssertEqual(state.runCount, 0)
        XCTAssertNil(state.lastRunDurationMs)
        XCTAssertTrue(state.lastErrors.isEmpty)
    }

    func testCuratorStateCustomInit() {
        let date = Date()
        let state = CuratorState(
            lastRunAt: date,
            paused: true,
            runCount: 3,
            lastRunDurationMs: 142,
            lastErrors: ["err1"]
        )
        XCTAssertEqual(state.lastRunAt, date)
        XCTAssertTrue(state.paused)
        XCTAssertEqual(state.runCount, 3)
        XCTAssertEqual(state.lastRunDurationMs, 142)
        XCTAssertEqual(state.lastErrors, ["err1"])
    }

    func testCuratorStateCodableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let state = CuratorState(
            lastRunAt: date,
            paused: true,
            runCount: 5,
            lastRunDurationMs: 200,
            lastErrors: ["error A", "error B"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CuratorState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testCuratorStateDefaultStateIsEqualToInit() {
        let a = CuratorState.defaultState()
        let b = CuratorState()
        XCTAssertEqual(a, b)
    }

    // MARK: - SkillCuratorConfig

    func testSkillCuratorConfigDefaults() {
        let config = SkillCuratorConfig()
        XCTAssertEqual(config.intervalHours, 168.0)
        XCTAssertEqual(config.minIdleHours, 2.0)
        XCTAssertEqual(config.staleAfterDays, 30)
        XCTAssertEqual(config.archiveAfterDays, 90)
        XCTAssertFalse(config.dryRun)
        XCTAssertTrue(config.enabled)
    }

    func testSkillCuratorConfigCustomInit() {
        let config = SkillCuratorConfig(
            intervalHours: 24.0,
            minIdleHours: 1.0,
            staleAfterDays: 14,
            archiveAfterDays: 60,
            dryRun: true,
            enabled: false
        )
        XCTAssertEqual(config.intervalHours, 24.0)
        XCTAssertEqual(config.minIdleHours, 1.0)
        XCTAssertEqual(config.staleAfterDays, 14)
        XCTAssertEqual(config.archiveAfterDays, 60)
        XCTAssertTrue(config.dryRun)
        XCTAssertFalse(config.enabled)
    }

    func testSkillCuratorConfigCodableRoundTrip() throws {
        let config = SkillCuratorConfig(
            intervalHours: 48.0,
            minIdleHours: 0.5,
            staleAfterDays: 7,
            archiveAfterDays: 30,
            dryRun: true,
            enabled: false
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SkillCuratorConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testSkillCuratorConfigValidationBoundaryMinIdleZero() {
        let config = SkillCuratorConfig(minIdleHours: 0)
        XCTAssertEqual(config.minIdleHours, 0)
    }

    func testSkillCuratorConfigValidationBoundaryArchiveOneMoreThanStale() {
        let config = SkillCuratorConfig(staleAfterDays: 30, archiveAfterDays: 31)
        XCTAssertEqual(config.archiveAfterDays, 31)
    }

    // Note: precondition validation for invalid configs (intervalHours<=0,
    // minIdleHours<0, staleAfterDays<=0, archiveAfterDays<=staleAfterDays)
    // is enforced at runtime via precondition() calls and cannot be tested
    // in-process since they trap the process. The guards exist in the
    // implementation and fire at runtime.

    // MARK: - CuratorRunResult

    func testCuratorRunResultDefaults() {
        let result = CuratorRunResult()
        XCTAssertTrue(result.transitionsApplied.isEmpty)
        XCTAssertEqual(result.skillsEvaluated, 0)
        XCTAssertEqual(result.skillsSkipped, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.durationMs, 0)
        XCTAssertFalse(result.dryRun)
    }

    func testCuratorRunResultCustomInit() {
        let transition = SkillLifecycleTransition(
            skillName: "old",
            from: .active,
            to: .deprecated,
            reason: "stale"
        )
        let result = CuratorRunResult(
            transitionsApplied: [transition],
            skillsEvaluated: 5,
            skillsSkipped: 3,
            errors: ["err"],
            durationMs: 100,
            dryRun: true,
            ranAt: Date(timeIntervalSince1970: 1700000000)
        )
        XCTAssertEqual(result.transitionsApplied.count, 1)
        XCTAssertEqual(result.skillsEvaluated, 5)
        XCTAssertEqual(result.skillsSkipped, 3)
        XCTAssertEqual(result.errors, ["err"])
        XCTAssertEqual(result.durationMs, 100)
        XCTAssertTrue(result.dryRun)
    }

    func testCuratorRunResultCodableRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let transition = SkillLifecycleTransition(
            skillName: "test",
            from: .deprecated,
            to: .retired,
            reason: "archived",
            evaluatedAt: fixedDate
        )
        let result = CuratorRunResult(
            transitionsApplied: [transition],
            skillsEvaluated: 2,
            skillsSkipped: 1,
            errors: [],
            durationMs: 50,
            dryRun: false,
            ranAt: fixedDate
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CuratorRunResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    // MARK: - Mock SkillEvolver conformance (protocol is implementable)

    func testMockSkillEvolverConformance() async throws {
        let evolver = MockSkillEvolver()
        let skill = Skill(name: "commit", promptTemplate: "old")
        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Improve",
            source: .conversation
        )
        let config = SkillEvolutionConfig()
        let result = try await evolver.evolve(skill: skill, signals: [signal], config: config)
        XCTAssertNotNil(result.evolvedSkill)
        XCTAssertEqual(result.appliedSignals.count, 1)
    }
}

// MARK: - Mock SkillEvolver

private struct MockSkillEvolver: SkillEvolver {
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        let filtered = signals.filter { signal in
            guard signal.confidence >= config.minConfidence else { return false }
            if let allowed = config.allowedSignalTypes {
                return allowed.contains(signal.signalType)
            }
            return true
        }
        let skipped = signals.filter { signal in
            if signal.confidence < config.minConfidence { return true }
            if let allowed = config.allowedSignalTypes {
                return !allowed.contains(signal.signalType)
            }
            return false
        }
        let evolved = Skill(
            name: skill.name,
            description: skill.description,
            aliases: skill.aliases,
            userInvocable: skill.userInvocable,
            toolRestrictions: skill.toolRestrictions,
            modelOverride: skill.modelOverride,
            promptTemplate: skill.promptTemplate + " [evolved]",
            whenToUse: skill.whenToUse,
            argumentHint: skill.argumentHint,
            baseDir: skill.baseDir,
            supportingFiles: skill.supportingFiles,
            lifecycleState: skill.lifecycleState
        )
        return SkillEvolutionResult(
            evolvedSkill: evolved,
            appliedSignals: filtered,
            skippedSignals: skipped,
            changes: ["Updated promptTemplate"]
        )
    }
}
