import Foundation

// MARK: - CuratorToolCall

/// Captures a single tool invocation from the LLM curation phase.
public struct CuratorToolCall: Sendable, Codable, Equatable {
    /// The name of the tool invoked.
    public let toolName: String
    /// The raw JSON input passed to the tool.
    public let input: String
    /// The content returned by the tool.
    public let result: String
    /// Whether the tool execution resulted in an error.
    public let isError: Bool

    public init(toolName: String, input: String, result: String, isError: Bool) {
        self.toolName = toolName
        self.input = input
        self.result = result
        self.isError = isError
    }
}

// MARK: - CuratorRunReport

/// A structured report produced after curation executes.
///
/// This is a presentation layer over ``IntelligentCuratorResult`` that provides
/// human-readable Markdown and machine-readable YAML output.
public struct CuratorRunReport: Sendable, Equatable {
    /// When the curation run started.
    public let startedAt: Date
    /// Wall-clock duration in milliseconds.
    public let durationMs: Int
    /// Mechanical phase transitions applied by ``SkillCurator``.
    public let autoTransitions: [SkillLifecycleTransition]
    /// LLM-driven merges (from, into, reason).
    public let consolidations: [CuratorConsolidation]
    /// LLM-driven archives (name, reason).
    public let prunings: [CuratorPruning]
    /// All tool invocations from the LLM phase.
    public let toolCalls: [CuratorToolCall]
    /// Error description if the run failed.
    public let error: String?
    /// Whether this was a dry run.
    public let dryRun: Bool
    /// Total skill count before curation.
    public let skillsBefore: Int
    /// Total skill count after curation.
    public let skillsAfter: Int

    public init(
        startedAt: Date = Date(),
        durationMs: Int = 0,
        autoTransitions: [SkillLifecycleTransition] = [],
        consolidations: [CuratorConsolidation] = [],
        prunings: [CuratorPruning] = [],
        toolCalls: [CuratorToolCall] = [],
        error: String? = nil,
        dryRun: Bool = false,
        skillsBefore: Int = 0,
        skillsAfter: Int = 0
    ) {
        self.startedAt = startedAt
        self.durationMs = durationMs
        self.autoTransitions = autoTransitions
        self.consolidations = consolidations
        self.prunings = prunings
        self.toolCalls = toolCalls
        self.error = error
        self.dryRun = dryRun
        self.skillsBefore = skillsBefore
        self.skillsAfter = skillsAfter
    }

    /// Creates a report by extracting fields from an ``IntelligentCuratorResult``.
    public init(from intelligentCuratorResult: IntelligentCuratorResult) {
        self.startedAt = intelligentCuratorResult.mechanicalResult.ranAt
        self.durationMs = intelligentCuratorResult.durationMs
        self.autoTransitions = intelligentCuratorResult.mechanicalResult.transitionsApplied
        self.consolidations = intelligentCuratorResult.consolidations
        self.prunings = intelligentCuratorResult.prunings
        self.toolCalls = Self.extractToolCalls(from: intelligentCuratorResult.llmResult?.reviewMessages ?? [])
        self.error = intelligentCuratorResult.error
        self.dryRun = intelligentCuratorResult.dryRun
        let before = intelligentCuratorResult.mechanicalResult.skillsEvaluated
            + intelligentCuratorResult.mechanicalResult.skillsSkipped
        self.skillsBefore = before
        self.skillsAfter = before - intelligentCuratorResult.consolidations.count
            - intelligentCuratorResult.prunings.count
    }

    // MARK: - renderMarkdown()

    /// Generates a human-readable Markdown report.
    public func renderMarkdown() -> String {
        let isoDate = makeISO8601DateFormatter().string(from: startedAt)
        let secs = durationMs / 1000
        let durLabel = secs >= 60 ? "\(secs / 60)m \(secs % 60)s" : "\(secs)s"

        let hasChanges = !consolidations.isEmpty || !prunings.isEmpty

        if !hasChanges && error == nil && autoTransitions.isEmpty {
            let prefix = dryRun ? "[DRY RUN] " : ""
            return "\(prefix)# Curator run — \(isoDate)\n\nNo changes — skill library is already well-organized.\n"
        }

        var lines: [String] = []
        let prefix = dryRun ? "[DRY RUN] " : ""
        lines.append("\(prefix)# Curator run — \(isoDate)\n")
        let delta = skillsAfter - skillsBefore
        let deltaStr = delta == 0 ? "0" : "\(delta)"
        lines.append("Duration: \(durLabel) · Skills: \(skillsBefore) → \(skillsAfter) (\(deltaStr))\n")

        if let error {
            lines.append("> Error: \(error)\n")
        }

        // Auto-transitions
        if !autoTransitions.isEmpty {
            lines.append("## Auto-transitions\n")
            let toDeprecated = autoTransitions.filter { $0.to == .deprecated }.count
            let toRetired = autoTransitions.filter { $0.to == .retired }.count
            let reactivated = autoTransitions.filter { $0.to == .active && $0.from != .active }.count
            let appliedLabel = dryRun ? "would apply" : "applied"
            lines.append("- transitions \(appliedLabel): \(autoTransitions.count)")
            lines.append("- marked stale: \(toDeprecated)")
            lines.append("- archived: \(toRetired)")
            lines.append("- reactivated: \(reactivated)")
            lines.append("")
        }

        // LLM consolidation pass
        let llmVerb = dryRun ? "would consolidate" : "consolidated"
        let pruneVerb = dryRun ? "would archive" : "archived"

        if !toolCalls.isEmpty || !consolidations.isEmpty || !prunings.isEmpty {
            lines.append("## LLM consolidation pass\n")
            lines.append("- tool calls: \(toolCalls.count)")
            lines.append("- \(llmVerb) into umbrellas: \(consolidations.count)")
            lines.append("- \(pruneVerb) for staleness: \(prunings.count)")
            lines.append("")
        }

        // Consolidated list
        if !consolidations.isEmpty {
            lines.append("### Consolidated into umbrella skills (\(consolidations.count))\n")
            for c in consolidations {
                let verb = dryRun ? "would merge" : "merged"
                lines.append("- `\(c.from)` → \(verb) into `\(c.into)` — \(c.reason)")
            }
            lines.append("")
        }

        // Pruned list
        if !prunings.isEmpty {
            lines.append("### Pruned — archived for staleness (\(prunings.count))\n")
            for p in prunings {
                let verb = dryRun ? "would archive" : "archived"
                lines.append("- `\(p.name)` — \(verb): \(p.reason)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - renderYAML()

    /// Generates structured YAML output compatible with the Hermes format.
    public func renderYAML() -> String {
        var lines: [String] = []

        if dryRun {
            lines.append("dry_run: true")
        }

        if let error {
            lines.append("error: \"\(yamlEscape(error))\"")
        }

        lines.append("consolidations:")
        if consolidations.isEmpty {
            lines.append("  []")
        } else {
            for c in consolidations {
                lines.append("  - from: \(yamlQuote(c.from))")
                lines.append("    into: \(yamlQuote(c.into))")
                lines.append("    reason: \"\(yamlEscape(c.reason))\"")
            }
        }

        lines.append("prunings:")
        if prunings.isEmpty {
            lines.append("  []")
        } else {
            for p in prunings {
                lines.append("  - name: \(yamlQuote(p.name))")
                lines.append("    reason: \"\(yamlEscape(p.reason))\"")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private Helpers

    private static func extractToolCalls(from messages: [SDKMessage]) -> [CuratorToolCall] {
        var toolCalls: [CuratorToolCall] = []
        var pendingToolUse: [String: SDKMessage.ToolUseData] = [:]

        for msg in messages {
            switch msg {
            case .toolUse(let data):
                pendingToolUse[data.toolUseId] = data
            case .toolResult(let data):
                if let useData = pendingToolUse[data.toolUseId] {
                    toolCalls.append(CuratorToolCall(
                        toolName: useData.toolName,
                        input: useData.input,
                        result: data.content,
                        isError: data.isError
                    ))
                    pendingToolUse.removeValue(forKey: data.toolUseId)
                }
            default:
                break
            }
        }

        return toolCalls
    }

}
