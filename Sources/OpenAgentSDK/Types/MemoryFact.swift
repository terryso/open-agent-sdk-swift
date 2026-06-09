import Foundation

// MARK: - MemoryFactStatus

/// Lifecycle status of a memory fact.
public enum MemoryFactStatus: String, Codable, Sendable, Equatable, CaseIterable {
    /// Newly observed, awaiting enough evidence to become active.
    case candidate
    /// Confirmed by sufficient evidence.
    case active
    /// Stale — not verified recently; can be reactivated.
    case retired
}

// MARK: - MemoryFactSource

/// Origin of a memory fact.
public enum MemoryFactSource: String, Codable, Sendable, Equatable {
    /// Observed directly by an agent during a run.
    case observation
    /// Imported from an external bundle.
    case imported
}

// MARK: - MemoryKind

/// Classification of what kind of knowledge a fact represents.
public enum MemoryKind: String, Codable, Sendable, Equatable, CaseIterable {
    /// A recommended path or approach.
    case affordance
    /// Something to avoid or be cautious about.
    case avoid
    /// A general observation about the environment.
    case observation
}

// MARK: - MemoryFact

/// A structured piece of experience accumulated by an agent, backed by evidence.
///
/// Facts have a lifecycle: they start as `candidate`, can be promoted to `active`
/// once enough evidence accumulates, and eventually `retired` if not verified.
public struct MemoryFact: Codable, Sendable, Equatable {

    /// Deterministic identifier (djb2 hash of kind + normalized description).
    public let id: String
    /// The domain this fact belongs to (e.g., "navigation", "testing").
    public let domain: String
    /// Human-readable description of the fact.
    public let content: String
    /// Current lifecycle status.
    public let status: MemoryFactStatus
    /// Confidence score in the range 0–1.
    public let confidence: Double
    /// Number of independent observations supporting this fact.
    public let evidenceCount: Int
    /// Where this fact came from.
    public let source: MemoryFactSource
    /// Classification of the fact.
    public let kind: MemoryKind
    /// When this fact was first created.
    public let createdAt: Date
    /// When this fact was last verified.
    public let lastVerifiedAt: Date

    public init(
        id: String,
        domain: String,
        content: String,
        status: MemoryFactStatus,
        confidence: Double,
        evidenceCount: Int,
        source: MemoryFactSource,
        kind: MemoryKind,
        createdAt: Date,
        lastVerifiedAt: Date
    ) {
        self.id = id
        self.domain = domain
        self.content = content
        self.status = status
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.source = source
        self.kind = kind
        self.createdAt = createdAt
        self.lastVerifiedAt = lastVerifiedAt
    }

    /// Create a new fact with a deterministic id and sensible defaults.
    public static func create(
        domain: String,
        kind: MemoryKind,
        description: String,
        confidence: Double = 0.5,
        source: MemoryFactSource = .observation
    ) -> MemoryFact {
        let now = Date()
        return MemoryFact(
            id: factId(kind: kind, description: description),
            domain: domain,
            content: description,
            status: .candidate,
            confidence: max(0, min(1, confidence)),
            evidenceCount: 1,
            source: source,
            kind: kind,
            createdAt: now,
            lastVerifiedAt: now
        )
    }

    /// Generate a deterministic fact id from kind and normalized description using djb2.
    public static func factId(kind: MemoryKind, description: String) -> String {
        let normalized = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let input = kind.rawValue + ":" + normalized
        return djb2Hash(input)
    }

    /// Normalize a fact — clamp confidence to 0–1 and evidenceCount to >= 0.
    public static func normalize(_ fact: MemoryFact) -> MemoryFact {
        MemoryFact(
            id: fact.id,
            domain: fact.domain,
            content: fact.content,
            status: fact.status,
            confidence: max(0, min(1, fact.confidence)),
            evidenceCount: max(0, fact.evidenceCount),
            source: fact.source,
            kind: fact.kind,
            createdAt: fact.createdAt,
            lastVerifiedAt: fact.lastVerifiedAt
        )
    }

}
