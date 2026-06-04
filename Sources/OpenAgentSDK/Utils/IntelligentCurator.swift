import Foundation

// MARK: - CuratorConsolidation

/// A skill that was consolidated (merged) into an umbrella skill.
public struct CuratorConsolidation: Sendable, Codable, Equatable {
    /// The skill that was archived.
    public let from: String
    /// The umbrella skill that absorbed the content.
    public let into: String
    /// Why the consolidation happened.
    public let reason: String

    public init(from: String, into: String, reason: String) {
        self.from = from
        self.into = into
        self.reason = reason
    }
}

// MARK: - CuratorPruning

/// A skill that was pruned (archived with no merge target).
public struct CuratorPruning: Sendable, Codable, Equatable {
    /// The skill that was archived.
    public let name: String
    /// Why the skill was pruned.
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }
}

// MARK: - IntelligentCuratorResult

/// Result of an intelligent curation pass (mechanical + LLM phases).
public struct IntelligentCuratorResult: Sendable {
    /// Result from the mechanical Phase 1 (SkillCurator.run()).
    public let mechanicalResult: CuratorRunResult
    /// Result from the LLM Phase 2, or nil if skipped/failed.
    public let llmResult: ReviewAgentResult?
    /// Skills consolidated into umbrella skills by the LLM.
    public let consolidations: [CuratorConsolidation]
    /// Skills pruned (archived with no merge target) by the LLM.
    public let prunings: [CuratorPruning]
    /// Total wall-clock duration in milliseconds.
    public let durationMs: Int
    /// Whether this was a dry run.
    public let dryRun: Bool
    /// Error description if Phase 2 failed, nil otherwise.
    public let error: String?

    public init(
        mechanicalResult: CuratorRunResult,
        llmResult: ReviewAgentResult? = nil,
        consolidations: [CuratorConsolidation] = [],
        prunings: [CuratorPruning] = [],
        durationMs: Int,
        dryRun: Bool,
        error: String? = nil
    ) {
        self.mechanicalResult = mechanicalResult
        self.llmResult = llmResult
        self.consolidations = consolidations
        self.prunings = prunings
        self.durationMs = durationMs
        self.dryRun = dryRun
        self.error = error
    }
}

// MARK: - IntelligentCurator

/// LLM-driven intelligent curation executor.
///
/// Executes a two-phase curation pipeline:
/// 1. **Mechanical phase**: runs ``SkillCurator`` for automatic lifecycle state transitions.
/// 2. **Intelligent phase**: forks a curator agent to perform LLM-driven consolidation,
///    merging narrow agent-created skills into class-level umbrella skills.
public struct IntelligentCurator: Sendable {

    /// Mechanical curation executor (Epic 22).
    public let skillCurator: SkillCurator
    /// Fact store for review tool dependency.
    public let factStore: FactStore
    /// Skill registry for skill library operations.
    public let skillRegistry: SkillRegistry
    /// Skill evolver for review tool dependency.
    public let skillEvolver: any SkillEvolver
    /// Usage data store (archive tool dependency + candidate list building).
    public let usageStore: SkillUsageStore
    /// Curator state persistence store.
    public let curatorStore: SkillCuratorStore
    /// Root directory for skill persistence.
    public let skillsDir: String

    public init(
        skillCurator: SkillCurator,
        factStore: FactStore,
        skillRegistry: SkillRegistry,
        skillEvolver: any SkillEvolver,
        usageStore: SkillUsageStore,
        curatorStore: SkillCuratorStore,
        skillsDir: String
    ) {
        self.skillCurator = skillCurator
        self.factStore = factStore
        self.skillRegistry = skillRegistry
        self.skillEvolver = skillEvolver
        self.usageStore = usageStore
        self.curatorStore = curatorStore
        self.skillsDir = skillsDir
    }

    /// Execute the two-phase curation pipeline.
    ///
    /// Phase 1 runs mechanical lifecycle transitions via ``SkillCurator``.
    /// Phase 2 forks a curator agent for LLM-driven consolidation (skipped if no candidates).
    ///
    /// - Parameters:
    ///   - parentAgent: The parent agent to fork the curator from (shares LLM client for prefix cache).
    ///   - dryRun: When `true`, uses the dry-run prompt and the SkillCurator's own dryRun config.
    /// - Returns: An ``IntelligentCuratorResult`` with both phase outcomes.
    public func execute(
        parentAgent: Agent,
        dryRun: Bool = false
    ) async throws -> IntelligentCuratorResult {
        let startTime = Date()
        Logger.shared.debug("IntelligentCurator", "phase1_start", data: [
            "dryRun": dryRun.description,
        ])

        // Phase 1: Mechanical curation
        let mechanicalResult = try await skillCurator.run()

        // Build candidate list for Phase 2
        let allUsage = await usageStore.allUsage()
        let candidateList = CuratorPromptBuilder.buildCandidateList(usageData: allUsage)

        let noCandidateMarker = "No agent-created skills to review."
        guard candidateList != noCandidateMarker else {
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            Logger.shared.debug("IntelligentCurator", "no_candidates_fast_path", data: [
                "durationMs": durationMs.description,
                "skillsEvaluated": mechanicalResult.skillsEvaluated.description,
            ])
            return IntelligentCuratorResult(
                mechanicalResult: mechanicalResult,
                durationMs: durationMs,
                dryRun: dryRun
            )
        }

        Logger.shared.debug("IntelligentCurator", "phase2_start", data: [
            "candidateList": candidateList,
            "dryRun": dryRun.description,
        ])

        // Phase 2: LLM curation
        do {
            let reviewConfig = ReviewAgentConfig(
                reviewMemory: false,
                reviewSkills: true,
                maxTurns: 200
            )

            let curatorAgent = parentAgent.createReviewAgent(config: reviewConfig)

            let reviewTools = createReviewTools(
                factStore: factStore,
                skillRegistry: skillRegistry,
                skillEvolver: skillEvolver,
                usageStore: usageStore,
                skillsDir: skillsDir
            )
            curatorAgent.options.tools = reviewTools

            let prompt = dryRun
                ? CuratorPromptBuilder.dryRunPrompt()
                : CuratorPromptBuilder.curationPrompt()
            let fullPrompt = prompt + "\n\n---\n\n" + candidateList

            let promptResult = await curatorAgent.prompt(fullPrompt)

            guard promptResult.status == .success || promptResult.status == .errorMaxTurns else {
                let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                Logger.shared.debug("IntelligentCurator", "phase2_agent_failed", data: [
                    "status": promptResult.status.rawValue,
                    "durationMs": durationMs.description,
                ])
                return IntelligentCuratorResult(
                    mechanicalResult: mechanicalResult,
                    durationMs: durationMs,
                    dryRun: dryRun,
                    error: "Curator agent failed with status: \(promptResult.status.rawValue)"
                )
            }

            let reviewMessages = curatorAgent.getMessages()
            let assistantText = promptResult.text.isEmpty
                ? extractAssistantText(from: reviewMessages)
                : promptResult.text

            let (consolidations, prunings) = Self.parseYAMLSummary(from: assistantText)

            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            Logger.shared.debug("IntelligentCurator", "phase2_complete", data: [
                "consolidations": consolidations.count.description,
                "prunings": prunings.count.description,
                "durationMs": durationMs.description,
                "maxTurnsHit": (promptResult.status == .errorMaxTurns).description,
            ])

            let llmResult = ReviewAgentResult(
                memoryChanges: [],
                skillChanges: [],
                summary: assistantText,
                reviewMessages: reviewMessages
            )

            return IntelligentCuratorResult(
                mechanicalResult: mechanicalResult,
                llmResult: llmResult,
                consolidations: consolidations,
                prunings: prunings,
                durationMs: durationMs,
                dryRun: dryRun,
                error: promptResult.status == .errorMaxTurns
                    ? "Curator agent reached max turns (\(reviewConfig.maxTurns)); output may be incomplete."
                    : nil
            )
        } catch {
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            Logger.shared.debug("IntelligentCurator", "phase2_error", data: [
                "error": error.localizedDescription,
                "durationMs": durationMs.description,
            ])
            return IntelligentCuratorResult(
                mechanicalResult: mechanicalResult,
                durationMs: durationMs,
                dryRun: dryRun,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Private Helpers

    /// Extracts the last assistant text from the message history.
    private func extractAssistantText(from messages: [SDKMessage]) -> String {
        for msg in messages.reversed() {
            if case .assistant(let data) = msg, !data.text.isEmpty {
                return data.text
            }
        }
        return ""
    }

    /// Parses the YAML structured summary block from the curator's text output.
    ///
    /// Looks for a ```yaml block containing `consolidations:` and `prunings:` sections.
    /// Uses simple string matching — no YAML library dependency.
    static func parseYAMLSummary(from text: String) -> (consolidations: [CuratorConsolidation], prunings: [CuratorPruning]) {
        // Find the yaml code block
        guard let yamlStart = text.range(of: "```yaml"),
              let yamlEnd = text.range(of: "```", range: yamlStart.upperBound..<text.endIndex)
        else {
            return ([], [])
        }

        let yamlContent = String(text[yamlStart.upperBound..<yamlEnd.lowerBound])

        var consolidations: [CuratorConsolidation] = []
        var prunings: [CuratorPruning] = []

        // Parse consolidations section
        if let consolidationsRange = yamlContent.range(of: "consolidations:") {
            let afterConsolidations = String(yamlContent[consolidationsRange.upperBound...])
            let sectionEnd = afterConsolidations.range(of: "prunings:")?.lowerBound ?? afterConsolidations.endIndex
            let section = String(afterConsolidations[..<sectionEnd])

            consolidations = parseConsolidationEntries(section)
        }

        // Parse prunings section
        if let pruningsRange = yamlContent.range(of: "prunings:") {
            let afterPrunings = String(yamlContent[pruningsRange.upperBound...])
            prunings = parsePruningEntries(afterPrunings)
        }

        if consolidations.isEmpty && prunings.isEmpty {
            Logger.shared.debug("IntelligentCurator", "yaml_parse_empty_result", data: [
                "yamlContentLength": yamlContent.count.description,
            ])
        }

        return (consolidations, prunings)
    }

    /// Parses `- from: X\n  into: Y\n  reason: Z` entries from a YAML section.
    static func parseConsolidationEntries(_ section: String) -> [CuratorConsolidation] {
        var results: [CuratorConsolidation] = []
        let entries = section.components(separatedBy: "- from:")

        for entry in entries.dropFirst() {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fromValue = String(trimmed.split(separator: "\n", maxSplits: 1)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            let intoValue = extractYAMLValue(from: trimmed, key: "into:")
            let reasonValue = extractYAMLValue(from: trimmed, key: "reason:")

            if let into = intoValue, let reason = reasonValue {
                results.append(CuratorConsolidation(
                    from: fromValue,
                    into: into,
                    reason: reason
                ))
            }
        }

        return results
    }

    /// Parses `- name: X\n  reason: Y` entries from a YAML section.
    static func parsePruningEntries(_ section: String) -> [CuratorPruning] {
        var results: [CuratorPruning] = []
        let entries = section.components(separatedBy: "- name:")

        for entry in entries.dropFirst() {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let nameValue = String(trimmed.split(separator: "\n", maxSplits: 1)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            let reasonValue = extractYAMLValue(from: trimmed, key: "reason:")

            if let reason = reasonValue {
                results.append(CuratorPruning(
                    name: nameValue,
                    reason: reason
                ))
            }
        }

        return results
    }

    /// Extracts a value following a YAML key (e.g., "into: value").
    private static func extractYAMLValue(from text: String, key: String) -> String? {
        guard let range = text.range(of: key) else { return nil }
        let afterKey = text[range.upperBound...]
        let value = afterKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.map { String($0) }
    }
}
