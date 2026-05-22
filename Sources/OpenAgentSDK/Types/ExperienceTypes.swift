import Foundation

// MARK: - ExperienceSource

/// Origin of an experience signal.
public enum ExperienceSource: String, Codable, Sendable, Equatable {
    /// Extracted from a dialogue by an extractor.
    case conversation
    /// Directly observed by the agent.
    case observation
    /// Imported from an external bundle.
    case imported
}

// MARK: - ExperienceSignal

/// A raw experience signal extracted from agent conversations.
///
/// Signals are the output of the extraction phase. They become `MemoryFact` objects only
/// after passing through validation, deduplication, and lifecycle management.
public struct ExperienceSignal: Codable, Sendable, Equatable {

    /// Deterministic identifier (djb2 hash of normalized domain + ":" + normalized content).
    public let id: String
    /// The domain this signal belongs to (e.g., "testing", "navigation").
    public let domain: String
    /// Human-readable description of the experience.
    public let content: String
    /// Classification of what kind of knowledge this signal represents.
    public let kind: MemoryKind
    /// Confidence score in the range 0–1.
    public let confidence: Double
    /// Where this signal came from.
    public let source: ExperienceSource
    /// When this signal was created.
    public let createdAt: Date
    /// Optional key-value pairs for source context (runId, sessionId, turnIndex).
    public let metadata: [String: String]?

    /// Creates a new signal with a deterministic id.
    ///
    /// Confidence is clamped to the range 0–1.
    public static func create(
        domain: String,
        kind: MemoryKind,
        content: String,
        confidence: Double = 0.5,
        source: ExperienceSource,
        metadata: [String: String]? = nil
    ) -> ExperienceSignal {
        ExperienceSignal(
            id: signalId(domain: domain, content: content),
            domain: domain,
            content: content,
            kind: kind,
            confidence: max(0, min(1, confidence)),
            source: source,
            createdAt: Date(),
            metadata: metadata
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        domain = try container.decode(String.self, forKey: .domain)
        content = try container.decode(String.self, forKey: .content)
        kind = try container.decode(MemoryKind.self, forKey: .kind)
        confidence = max(0, min(1, try container.decode(Double.self, forKey: .confidence)))
        source = try container.decode(ExperienceSource.self, forKey: .source)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }

    private init(id: String, domain: String, content: String, kind: MemoryKind, confidence: Double, source: ExperienceSource, createdAt: Date, metadata: [String: String]?) {
        self.id = id
        self.domain = domain
        self.content = content
        self.kind = kind
        self.confidence = confidence
        self.source = source
        self.createdAt = createdAt
        self.metadata = metadata
    }

    /// Converts this signal to a `MemoryFact` for storage in the FactStore.
    ///
    /// Maps `ExperienceSource.conversation` to `MemoryFactSource.observation`.
    /// Sets status to `.candidate` and `evidenceCount` to 1.
    public func toFact() -> MemoryFact {
        let factSource: MemoryFactSource = switch source {
        case .conversation: .observation
        case .observation: .observation
        case .imported: .imported
        }
        return MemoryFact.create(
            domain: domain,
            kind: kind,
            description: content,
            confidence: confidence,
            source: factSource
        )
    }

    // MARK: - Private

    /// Generate a deterministic signal id from domain and content using djb2.
    private static func signalId(domain: String, content: String) -> String {
        let normalizedDomain = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let input = normalizedDomain + ":" + normalizedContent
        return djb2Hash(input)
    }

    /// djb2 hash algorithm for deterministic string hashing.
    private static func djb2Hash(_ string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

// MARK: - ExtractionConfig

/// Configuration for experience extraction.
public struct ExtractionConfig: Sendable, Codable, Equatable {

    /// Default anti-pattern keywords derived from Hermes research.
    ///
    /// These match patterns that indicate transient or environment-dependent issues,
    /// not genuine agent experience.
    public static let defaultAntiPatternKeywords: [String] = [
        // Environment-dependent failures
        "command not found",
        "not installed",
        "no such file",
        "binary not found",
        "permission denied",
        // Transient errors
        "timeout",
        "temporary failure",
        "connection reset",
        "rate limit",
        // One-off task narratives
        "summarize today's",
        "summarize this week's",
        "what happened",
        // Negative standalone assertions
        "tool does not work",
        "cannot access",
    ]

    /// Keywords indicating anti-patterns that should be filtered from extraction.
    public let antiPatternKeywords: [String]

    /// Minimum confidence threshold. Signals below this are discarded.
    public let minSignalConfidence: Double

    /// Maximum number of signals per extraction batch.
    public let maxSignalsPerExtraction: Int

    /// Restrict extraction to a specific domain. Nil means auto-detect.
    public let domain: String?

    public init(
        antiPatternKeywords: [String] = ExtractionConfig.defaultAntiPatternKeywords,
        minSignalConfidence: Double = 0.4,
        maxSignalsPerExtraction: Int = 10,
        domain: String? = nil
    ) {
        self.antiPatternKeywords = antiPatternKeywords
        self.minSignalConfidence = minSignalConfidence
        self.maxSignalsPerExtraction = maxSignalsPerExtraction
        self.domain = domain
    }
}

// MARK: - ExtractionResult

/// Wraps the raw extraction output with metadata for auditability.
public struct ExtractionResult: Sendable, Codable, Equatable {

    /// The signals extracted from the conversation.
    public let signals: [ExperienceSignal]

    /// How many candidate signals were below threshold or matched anti-patterns.
    public let skippedCount: Int

    /// When the extraction was performed.
    public let extractionDate: Date

    /// How many messages were analyzed.
    public let sourceMessageCount: Int

    public init(
        signals: [ExperienceSignal],
        skippedCount: Int,
        extractionDate: Date,
        sourceMessageCount: Int
    ) {
        self.signals = signals
        self.skippedCount = skippedCount
        self.extractionDate = extractionDate
        self.sourceMessageCount = sourceMessageCount
    }
}

// MARK: - MemoryReviewConfig

/// Configuration for the automatic memory review hook.
///
/// Controls when and how the ``MemoryReviewHook`` extracts experience from conversations
/// at session end.
public struct MemoryReviewConfig: Sendable, Codable, Equatable {

    /// Whether memory review is enabled. Defaults to `true`.
    public var enabled: Bool

    /// Configuration for the extraction phase.
    public var extractionConfig: ExtractionConfig

    /// Minimum number of messages required to trigger a review.
    /// Conversations with fewer messages are skipped. Defaults to `4`.
    public var minMessagesForReview: Int

    /// Minimum seconds between reviews per domain. `nil` means every session.
    public var reviewInterval: TimeInterval?

    /// Restrict extraction to specific domains. `nil` means auto-detect from conversation.
    public var domains: [String]?

    public init(
        enabled: Bool = true,
        extractionConfig: ExtractionConfig = .init(),
        minMessagesForReview: Int = 4,
        reviewInterval: TimeInterval? = nil,
        domains: [String]? = nil
    ) {
        self.enabled = enabled
        self.extractionConfig = extractionConfig
        self.minMessagesForReview = minMessagesForReview
        self.reviewInterval = reviewInterval
        self.domains = domains
    }
}

// MARK: - MessageHistoryProvider

/// A closure that provides the agent's current message history.
///
/// Used by ``MemoryReviewHook`` to decouple from `Core/Agent` internals.
/// The agent wires its own message-access closure at initialization time.
public typealias MessageHistoryProvider = @Sendable () async -> [SDKMessage]

// MARK: - ExperienceExtractor Protocol

/// Protocol for extracting experience signals from agent conversations.
///
/// Conforming types analyze a sequence of `SDKMessage` values and produce
/// structured `ExperienceSignal` objects based on what was learned.
public protocol ExperienceExtractor: Sendable {
    /// Extract experience signals from a sequence of messages.
    ///
    /// - Parameters:
    ///   - messages: The messages to analyze.
    ///   - config: Configuration for the extraction (thresholds, anti-patterns, domain filter).
    /// - Returns: An `ExtractionResult` containing the extracted signals and metadata.
    func extract(from messages: [SDKMessage], config: ExtractionConfig) async throws -> ExtractionResult
}
