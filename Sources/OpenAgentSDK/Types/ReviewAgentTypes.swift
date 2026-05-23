import Foundation

// MARK: - ReviewAgentConfig

/// Configuration for creating a forked review agent.
///
/// Controls what the review agent examines (memory, skills, or both),
/// how many turns it may take, and which tools it may use.
public struct ReviewAgentConfig: Sendable, Codable, Equatable {

    /// Whether to review memory (user facts, preferences). Defaults to `true`.
    public var reviewMemory: Bool

    /// Whether to review skills (technique capture, skill updates). Defaults to `true`.
    public var reviewSkills: Bool

    /// Maximum number of agent loop turns for the review agent. Defaults to `16`.
    /// Must be greater than zero.
    public var maxTurns: Int {
        didSet { precondition(maxTurns > 0, "ReviewAgentConfig.maxTurns must be greater than zero") }
    }

    /// Tool names the review agent is allowed to use. Defaults to the four review tools.
    /// Must be non-empty.
    public var allowedTools: [String] {
        didSet { precondition(!allowedTools.isEmpty, "ReviewAgentConfig.allowedTools must not be empty") }
    }

    public init(
        reviewMemory: Bool = true,
        reviewSkills: Bool = true,
        maxTurns: Int = 16,
        allowedTools: [String] = [
            "review_save_memory",
            "review_update_skill",
            "review_create_skill",
            "review_add_skill_file",
        ]
    ) {
        precondition(maxTurns > 0, "ReviewAgentConfig.maxTurns must be greater than zero")
        precondition(!allowedTools.isEmpty, "ReviewAgentConfig.allowedTools must not be empty")
        self.reviewMemory = reviewMemory
        self.reviewSkills = reviewSkills
        self.maxTurns = maxTurns
        self.allowedTools = allowedTools
    }
}

// MARK: - ReviewAgentResult

/// The outcome of a review agent run.
///
/// Contains lists of memory and skill changes made, along with a summary
/// and the full message history from the review session.
public struct ReviewAgentResult: Sendable, Equatable {

    /// Descriptions of memory changes made during the review.
    public let memoryChanges: [String]

    /// Descriptions of skill changes made during the review.
    public let skillChanges: [String]

    /// Human-readable summary of what the review agent found and did.
    public let summary: String

    /// The full message history from the review agent session.
    public let reviewMessages: [SDKMessage]

    public init(
        memoryChanges: [String],
        skillChanges: [String],
        summary: String,
        reviewMessages: [SDKMessage]
    ) {
        self.memoryChanges = memoryChanges
        self.skillChanges = skillChanges
        self.summary = summary
        self.reviewMessages = reviewMessages
    }

    /// Convenience factory when the review produced no changes.
    public static func noChanges(summary: String) -> ReviewAgentResult {
        ReviewAgentResult(
            memoryChanges: [],
            skillChanges: [],
            summary: summary,
            reviewMessages: []
        )
    }
}
