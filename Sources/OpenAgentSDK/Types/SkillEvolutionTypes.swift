import Foundation

// MARK: - SkillSignalType

/// Types of evolution signals that can drive skill changes.
public enum SkillSignalType: String, Codable, Sendable, Equatable, CaseIterable {
    /// Improve promptTemplate based on usage feedback.
    case refinement
    /// Skill is never used or always fails, suggest removal.
    case deprecation
    /// Two skills overlap, suggest combining.
    case merge
    /// One skill is too broad, suggest splitting.
    case split
    /// Observed repeated pattern that should become a skill.
    case newSkill
}

// MARK: - SkillEvolutionSource

/// Origin of a skill evolution signal.
public enum SkillEvolutionSource: String, Codable, Sendable, Equatable {
    /// Derived from usage tracking data.
    case usageAnalysis
    /// Extracted from agent dialogue.
    case conversation
    /// Suggested by curator algorithm.
    case curation
    /// User-requested change.
    case manual
}

// MARK: - SkillSignal

/// A signal describing an opportunity to evolve a skill.
///
/// Signals are produced by usage analysis, conversation extraction, or manual
/// curation. They are consumed by ``SkillEvolver`` implementations to produce
/// evolved skill definitions.
public struct SkillSignal: Codable, Sendable, Equatable {

    /// Deterministic identifier (djb2 hash of skillName + signalType raw value).
    public let id: String
    /// The skill this signal relates to.
    public let skillName: String
    /// Classification of the evolution opportunity.
    public let signalType: SkillSignalType
    /// Human-readable description of the evolution opportunity.
    public let content: String
    /// Confidence score in the range 0–1.
    public let confidence: Double
    /// Where this signal came from.
    public let source: SkillEvolutionSource
    /// When this signal was created.
    public let createdAt: Date
    /// Optional key-value pairs for context (sessionId, turnIndex, etc.).
    public let metadata: [String: String]?

    /// Creates a new signal with a deterministic id.
    ///
    /// Confidence is clamped to the range 0–1.
    public static func create(
        skillName: String,
        signalType: SkillSignalType,
        content: String,
        confidence: Double = 0.5,
        source: SkillEvolutionSource,
        metadata: [String: String]? = nil
    ) -> SkillSignal {
        SkillSignal(
            id: signalId(skillName: skillName, signalType: signalType),
            skillName: skillName,
            signalType: signalType,
            content: content,
            confidence: max(0, min(1, confidence)),
            source: source,
            createdAt: Date(),
            metadata: metadata
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        skillName = try container.decode(String.self, forKey: .skillName)
        signalType = try container.decode(SkillSignalType.self, forKey: .signalType)
        content = try container.decode(String.self, forKey: .content)
        confidence = max(0, min(1, try container.decode(Double.self, forKey: .confidence)))
        source = try container.decode(SkillEvolutionSource.self, forKey: .source)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }

    private init(id: String, skillName: String, signalType: SkillSignalType, content: String, confidence: Double, source: SkillEvolutionSource, createdAt: Date, metadata: [String: String]?) {
        self.id = id
        self.skillName = skillName
        self.signalType = signalType
        self.content = content
        self.confidence = confidence
        self.source = source
        self.createdAt = createdAt
        self.metadata = metadata
    }

    /// Returns `true` if this signal applies to the given skill.
    ///
    /// A signal applies when its `skillName` matches the skill's `name`, or
    /// when the signal type is `.newSkill` (which applies to any context).
    public func isApplicable(to skill: Skill) -> Bool {
        signalType == .newSkill || skillName == skill.name
    }

    // MARK: - Private

    private static func signalId(skillName: String, signalType: SkillSignalType) -> String {
        let normalized = skillName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let input = normalized + ":" + signalType.rawValue
        return djb2Hash(input)
    }

    private static func djb2Hash(_ string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

// MARK: - SkillEvolutionConfig

/// Configuration for a skill evolution pass.
public struct SkillEvolutionConfig: Sendable, Codable, Equatable {

    /// Maximum signals processed per evolution call. Defaults to 5.
    public let maxSignalsPerEvolution: Int

    /// Ignore signals below this confidence. Defaults to 0.4.
    public let minConfidence: Double

    /// Restrict to specific signal types. `nil` means all types. Defaults to `nil`.
    public let allowedSignalTypes: [SkillSignalType]?

    /// When `true`, compute the result but don't apply changes. Defaults to `false`.
    public let dryRun: Bool

    /// When `true`, the evolution produces a new skill without modifying the input. Defaults to `true`.
    public let preserveOriginal: Bool

    public init(
        maxSignalsPerEvolution: Int = 5,
        minConfidence: Double = 0.4,
        allowedSignalTypes: [SkillSignalType]? = nil,
        dryRun: Bool = false,
        preserveOriginal: Bool = true
    ) {
        self.maxSignalsPerEvolution = maxSignalsPerEvolution
        self.minConfidence = minConfidence
        self.allowedSignalTypes = allowedSignalTypes
        self.dryRun = dryRun
        self.preserveOriginal = preserveOriginal
    }
}

// MARK: - SkillEvolutionResult

/// Wraps the evolution output with full audit metadata.
public struct SkillEvolutionResult: Sendable, Equatable {

    /// The evolved skill, or `nil` if no evolution was warranted.
    public let evolvedSkill: Skill?
    /// Which signals were used in the evolution.
    public let appliedSignals: [SkillSignal]
    /// Which signals were below threshold or filtered.
    public let skippedSignals: [SkillSignal]
    /// Human-readable descriptions of what changed.
    public let changes: [String]
    /// When the evolution was performed.
    public let evolutionDate: Date

    public init(
        evolvedSkill: Skill?,
        appliedSignals: [SkillSignal],
        skippedSignals: [SkillSignal],
        changes: [String],
        evolutionDate: Date = Date()
    ) {
        self.evolvedSkill = evolvedSkill
        self.appliedSignals = appliedSignals
        self.skippedSignals = skippedSignals
        self.changes = changes
        self.evolutionDate = evolutionDate
    }
}

// MARK: - SkillEvolutionResult Codable

extension SkillEvolutionResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case evolvedSkill, appliedSignals, skippedSignals, changes, evolutionDate
    }

    private struct CodableSkill: Codable {
        let name: String
        let description: String
        let aliases: [String]
        let userInvocable: Bool
        let toolRestrictions: [ToolRestriction]?
        let modelOverride: String?
        let promptTemplate: String
        let whenToUse: String?
        let argumentHint: String?
        let baseDir: String?
        let supportingFiles: [String]
        let lifecycleState: SkillLifecycleState?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let codableSkill = try container.decodeIfPresent(CodableSkill.self, forKey: .evolvedSkill) {
            evolvedSkill = Skill(
                name: codableSkill.name,
                description: codableSkill.description,
                aliases: codableSkill.aliases,
                userInvocable: codableSkill.userInvocable,
                toolRestrictions: codableSkill.toolRestrictions,
                modelOverride: codableSkill.modelOverride,
                promptTemplate: codableSkill.promptTemplate,
                whenToUse: codableSkill.whenToUse,
                argumentHint: codableSkill.argumentHint,
                baseDir: codableSkill.baseDir,
                supportingFiles: codableSkill.supportingFiles,
                lifecycleState: codableSkill.lifecycleState
            )
        } else {
            evolvedSkill = nil
        }
        appliedSignals = try container.decode([SkillSignal].self, forKey: .appliedSignals)
        skippedSignals = try container.decode([SkillSignal].self, forKey: .skippedSignals)
        changes = try container.decode([String].self, forKey: .changes)
        evolutionDate = try container.decode(Date.self, forKey: .evolutionDate)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let skill = evolvedSkill {
            let codableSkill = CodableSkill(
                name: skill.name,
                description: skill.description,
                aliases: skill.aliases,
                userInvocable: skill.userInvocable,
                toolRestrictions: skill.toolRestrictions,
                modelOverride: skill.modelOverride,
                promptTemplate: skill.promptTemplate,
                whenToUse: skill.whenToUse,
                argumentHint: skill.argumentHint,
                baseDir: skill.baseDir,
                supportingFiles: skill.supportingFiles,
                lifecycleState: skill.lifecycleState
            )
            try container.encode(codableSkill, forKey: .evolvedSkill)
        } else {
            try container.encodeNil(forKey: .evolvedSkill)
        }
        try container.encode(appliedSignals, forKey: .appliedSignals)
        try container.encode(skippedSignals, forKey: .skippedSignals)
        try container.encode(changes, forKey: .changes)
        try container.encode(evolutionDate, forKey: .evolutionDate)
    }
}

// MARK: - SkillLifecycleState

/// Lifecycle states for a skill.
public enum SkillLifecycleState: String, Codable, Sendable, Equatable, CaseIterable {
    /// In use and performing well.
    case active
    /// Flagged for removal, still functional.
    case deprecated
    /// Newly created, not yet validated.
    case experimental
    /// Removed from active use, may be archived.
    case retired
}

// MARK: - SkillProvenance

/// Origin of a skill definition.
public enum SkillProvenance: String, Codable, Sendable, Equatable, CaseIterable {
    /// Created by an agent through evolution.
    case agentCreated
    /// Built-in skill shipped with SDK.
    case bundled
    /// Manually created by a developer.
    case userDefined
    /// Installed from a skill hub/package.
    case hubInstalled
}

// MARK: - SkillUsageData

/// Tracks usage metrics and lifecycle metadata for a single skill.
public struct SkillUsageData: Codable, Sendable, Equatable {

    /// The skill name this data tracks.
    public let skillName: String
    /// Number of times the skill has been viewed/invoked.
    public var viewCount: Int
    /// When the skill was last viewed.
    public var lastViewedAt: Date?
    /// When the skill was last managed (edited, configured).
    public var lastManagedAt: Date?
    /// Whether the skill is pinned (protected from auto-transitions).
    public var pinned: Bool
    /// How this skill originated.
    public var provenance: SkillProvenance

    public init(
        skillName: String,
        viewCount: Int = 0,
        lastViewedAt: Date? = nil,
        lastManagedAt: Date? = nil,
        pinned: Bool = false,
        provenance: SkillProvenance = .userDefined
    ) {
        self.skillName = skillName
        self.viewCount = viewCount
        self.lastViewedAt = lastViewedAt
        self.lastManagedAt = lastManagedAt
        self.pinned = pinned
        self.provenance = provenance
    }

    /// Derives the current lifecycle state from usage data.
    ///
    /// Uses fixed thresholds (30 days → deprecated, 90 days → retired) for quick lookups.
    /// Note: ``SkillUsageTracker`` uses its own configurable thresholds via ``SkillUsageTrackerConfig``,
    /// so this computed property may diverge from the tracker's evaluation. This property is
    /// a convenience approximation, not the authoritative lifecycle state.
    public var currentLifecycleState: SkillLifecycleState {
        if viewCount == 0 && lastViewedAt == nil {
            return .experimental
        }
        guard let lastView = lastViewedAt else {
            return .experimental
        }
        let daysSinceView = Calendar.current.dateComponents([.day], from: lastView, to: Date()).day ?? 0
        if daysSinceView >= 90 {
            return .retired
        }
        if daysSinceView >= 30 {
            return .deprecated
        }
        return .active
    }
}

// MARK: - SkillUsageTrackerConfig

/// Configuration for the skill usage tracker's lifecycle evaluation thresholds.
public struct SkillUsageTrackerConfig: Sendable, Codable, Equatable {

    /// Days without a view before transitioning active → deprecated. Defaults to 30.
    public let staleAfterDays: Int

    /// Days without a view before transitioning deprecated → retired. Defaults to 90.
    public let archiveAfterDays: Int

    /// When true, experimental skills skip lifecycle transitions. Defaults to true.
    ///
    /// Note: Currently has no effect because experimental skills (viewCount==0, lastViewedAt==nil)
    /// are always caught by the "no data" rule regardless of this flag. Will become meaningful
    /// once `SkillUsageData` supports an explicit stored lifecycle state.
    public let protectExperimental: Bool

    public init(
        staleAfterDays: Int = 30,
        archiveAfterDays: Int = 90,
        protectExperimental: Bool = true
    ) {
        precondition(staleAfterDays > 0, "staleAfterDays must be positive")
        precondition(archiveAfterDays > staleAfterDays, "archiveAfterDays must be greater than staleAfterDays")
        self.staleAfterDays = staleAfterDays
        self.archiveAfterDays = archiveAfterDays
        self.protectExperimental = protectExperimental
    }
}

// MARK: - SkillLifecycleTransition

/// Describes a proposed lifecycle state change for a skill.
public struct SkillLifecycleTransition: Sendable, Codable, Equatable {

    /// The skill being transitioned.
    public let skillName: String
    /// The current lifecycle state.
    public let from: SkillLifecycleState
    /// The proposed new lifecycle state.
    public let to: SkillLifecycleState
    /// Human-readable explanation of why the transition is proposed.
    public let reason: String
    /// When this evaluation was performed.
    public let evaluatedAt: Date

    public init(
        skillName: String,
        from: SkillLifecycleState,
        to: SkillLifecycleState,
        reason: String,
        evaluatedAt: Date = Date()
    ) {
        self.skillName = skillName
        self.from = from
        self.to = to
        self.reason = reason
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - SkillEvolver Protocol

/// Protocol for evolving a skill based on collected signals.
///
/// Conforming types take a single skill and a set of signals, then produce
/// an evolved skill definition (or a no-op result if no evolution is warranted).
public protocol SkillEvolver: Sendable {
    /// Evolve a skill based on the provided signals.
    ///
    /// - Parameters:
    ///   - skill: The skill to evolve.
    ///   - signals: Signals describing evolution opportunities.
    ///   - config: Configuration controlling the evolution pass.
    /// - Returns: A ``SkillEvolutionResult`` with the evolved skill and audit metadata.
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult
}
