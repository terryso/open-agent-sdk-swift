import Foundation

// MARK: - ReviewScheduleConfig

/// Configuration for automatic background review scheduling.
///
/// Controls how often memory and skill reviews run after sessions, and the
/// minimum conversation length required before a review triggers.
public struct ReviewScheduleConfig: Sendable, Codable, Equatable {

    /// Trigger a memory review every N messages. Default `4`.
    public var memoryReviewInterval: Int {
        didSet { precondition(memoryReviewInterval > 0, "memoryReviewInterval must be > 0") }
    }

    /// Trigger a skill review every N messages. Default `6`.
    public var skillReviewInterval: Int {
        didSet { precondition(skillReviewInterval > 0, "skillReviewInterval must be > 0") }
    }

    /// Minimum messages in a session before any review can trigger. Default `4`.
    public var minMessagesForReview: Int {
        didSet { precondition(minMessagesForReview > 0, "minMessagesForReview must be > 0") }
    }

    /// Optional model override for the review agent.
    /// When `nil`, the review agent inherits the parent agent's model.
    public var reviewModel: String?

    public init(
        memoryReviewInterval: Int = 4,
        skillReviewInterval: Int = 6,
        minMessagesForReview: Int = 4,
        reviewModel: String? = nil
    ) {
        precondition(memoryReviewInterval > 0, "memoryReviewInterval must be > 0")
        precondition(skillReviewInterval > 0, "skillReviewInterval must be > 0")
        precondition(minMessagesForReview > 0, "minMessagesForReview must be > 0")
        self.memoryReviewInterval = memoryReviewInterval
        self.skillReviewInterval = skillReviewInterval
        self.minMessagesForReview = minMessagesForReview
        self.reviewModel = reviewModel
    }
}

// MARK: - ReviewOrchestrator

/// Orchestrates background review agents at configurable intervals.
///
/// On each session end, checks whether a memory and/or skill review should run
/// based on message count modulo the configured intervals. The hook handler
/// fires ``executeReview(parentAgent:messages:config:)`` in a detached task
/// so the review never blocks the parent agent's return.
public struct ReviewOrchestrator: Sendable {

    /// The schedule configuration controlling review intervals.
    public let scheduleConfig: ReviewScheduleConfig

    /// Fact store for persisting extracted memories.
    public let factStore: FactStore

    /// Skill registry for skill lookups and registration.
    public let skillRegistry: SkillRegistry

    /// Skill evolver for applying skill updates.
    public let skillEvolver: any SkillEvolver

    /// Usage store for skill usage data.
    public let usageStore: SkillUsageStore

    /// Root directory for skill persistence.
    public let skillsDir: String

    /// Additional tools to inject alongside the built-in review tools.
    ///
    /// Use this to extend the review agent with domain-specific memory tools
    /// (e.g., a tool that writes to MEMORY.md / USER.md alongside FactStore).
    /// These tools are appended after the five built-in review tools.
    public let additionalReviewTools: [ToolProtocol]

    public init(
        scheduleConfig: ReviewScheduleConfig,
        factStore: FactStore,
        skillRegistry: SkillRegistry,
        skillEvolver: any SkillEvolver,
        usageStore: SkillUsageStore,
        skillsDir: String,
        additionalReviewTools: [ToolProtocol] = []
    ) {
        self.scheduleConfig = scheduleConfig
        self.factStore = factStore
        self.skillRegistry = skillRegistry
        self.skillEvolver = skillEvolver
        self.usageStore = usageStore
        self.skillsDir = skillsDir
        self.additionalReviewTools = additionalReviewTools
    }

    // MARK: - shouldReview

    /// Determines whether a memory and/or skill review should run for this session.
    ///
    /// Reviews trigger when `messageCount` is exactly divisible by the configured interval
    /// AND the count meets the minimum threshold.
    public func shouldReview(
        sessionId: String,
        messageCount: Int,
        config: ReviewAgentConfig
    ) -> (memory: Bool, skill: Bool) {
        guard messageCount >= scheduleConfig.minMessagesForReview else {
            return (false, false)
        }

        let doMemory = config.reviewMemory
            && messageCount % scheduleConfig.memoryReviewInterval == 0
        let doSkill = config.reviewSkills
            && messageCount % scheduleConfig.skillReviewInterval == 0

        return (doMemory, doSkill)
    }

    // MARK: - executeReview

    /// Runs the full review pipeline: build prompt, fork agent, inject tools, execute.
    ///
    /// Returns `nil` if the review agent fails to produce a result.
    public func executeReview(
        parentAgent: Agent,
        messages: [SDKMessage],
        config: ReviewAgentConfig
    ) async -> ReviewAgentResult? {
        // 1. Build review prompt (+ optional caller suffix)
        var reviewPrompt = ReviewPromptBuilder.selectPrompt(config: config)
        if let suffix = config.promptSuffix, !suffix.isEmpty {
            reviewPrompt += "\n\n" + suffix
        }

        // 2. Fork review agent from parent
        let reviewAgent = parentAgent.createReviewAgent(config: config)

        // 3. Create and inject review tools
        let reviewTools = createReviewTools(
            factStore: factStore,
            skillRegistry: skillRegistry,
            skillEvolver: skillEvolver,
            usageStore: usageStore,
            skillsDir: skillsDir
        )
        reviewAgent.options.tools = reviewTools + additionalReviewTools

        // 4. Build conversation context
        let conversationContext = Self.formatMessagesForReview(messages)
        let fullPrompt = reviewPrompt + "\n\n---\n\n## Conversation to Review\n\n" + conversationContext

        // 5. Capture prior snapshot for summarizeActions dedup
        let priorSnapshot = messages

        // 6. Execute review
        let promptResult = await reviewAgent.prompt(fullPrompt)

        // 7. Return nil on failure
        guard promptResult.status == .success || promptResult.status == .errorMaxTurns else {
            return nil
        }

        // 8. Extract review messages from the agent
        let reviewMessages = reviewAgent.getMessages()

        // 9. Summarize actions
        let actions = Self.summarizeActions(reviewMessages, priorSnapshot: priorSnapshot)

        let memoryActions = actions.filter { $0.lowercased().contains("memory") }
        let skillActions = actions.filter { $0.lowercased().contains("skill") }

        let summary: String
        if actions.isEmpty {
            summary = "Review completed. No actions taken."
        } else {
            summary = "Review completed: " + actions.joined(separator: "; ")
        }

        return ReviewAgentResult(
            memoryChanges: memoryActions,
            skillChanges: skillActions,
            summary: summary,
            reviewMessages: reviewMessages
        )
    }

    // MARK: - summarizeActions

    /// Extracts action descriptions from review agent tool-result messages.
    ///
    /// Walks the review messages, finds tool results with `"success": true`,
    /// extracts their `"message"` field, and deduplicates against a prior snapshot.
    public static func summarizeActions(
        _ messages: [SDKMessage],
        priorSnapshot: [SDKMessage]
    ) -> [String] {
        // Build dedup sets from prior snapshot
        var priorToolCallIds = Set<String>()
        var priorContents = Set<String>()
        for msg in priorSnapshot {
            if case .toolResult(let data) = msg {
                priorToolCallIds.insert(data.toolUseId)
                priorContents.insert(data.content)
            }
        }

        var actions: [String] = []
        var seen = Set<String>()

        for msg in messages {
            guard case .toolResult(let data) = msg else { continue }
            guard !data.isError else { continue }

            // Skip messages already in prior snapshot
            if priorToolCallIds.contains(data.toolUseId) || priorContents.contains(data.content) {
                continue
            }

            // Parse JSON content
            guard let jsonData = data.content.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let success = json["success"] as? Bool,
                  success else {
                continue
            }

            guard let message = json["message"] as? String else { continue }

            // Look for action keywords
            let lower = message.lowercased()
            if lower.contains("created") || lower.contains("updated") || lower.contains("saved") || lower.contains("archived") {
                if !seen.contains(message) {
                    seen.insert(message)
                    actions.append(message)
                }
            }
        }

        return actions
    }

    // MARK: - Private Helpers

    /// Formats messages into a readable transcript for the review agent.
    private static func formatMessagesForReview(_ messages: [SDKMessage]) -> String {
        var lines: [String] = []
        for msg in messages {
            switch msg {
            case .userMessage(let data):
                lines.append("User: \(data.message)")
            case .assistant(let data):
                if !data.text.isEmpty {
                    lines.append("Assistant: \(data.text)")
                }
            case .toolResult(let data):
                lines.append("Tool Result: \(data.content)")
            default:
                break
            }
        }
        return lines.joined(separator: "\n\n")
    }
}
