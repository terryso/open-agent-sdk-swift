import Foundation

/// Metadata for a persisted session.
///
/// Contains identifying information about a session including its ID, timestamps,
/// model used, and optional summary/tag for organization.
public struct SessionMetadata: Sendable, Equatable {
    /// The unique session identifier.
    public let id: String
    /// The working directory when the session was created.
    public let cwd: String
    /// The model used in this session.
    public let model: String
    /// When the session was created.
    public let createdAt: Date
    /// When the session was last updated.
    public let updatedAt: Date
    /// Number of messages in the session transcript.
    public let messageCount: Int
    /// An optional summary or title for the session.
    public let summary: String?
    /// An optional tag for categorizing the session.
    public let tag: String?

    public init(
        id: String,
        cwd: String,
        model: String,
        createdAt: Date,
        updatedAt: Date,
        messageCount: Int,
        summary: String? = nil,
        tag: String? = nil
    ) {
        self.id = id
        self.cwd = cwd
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.summary = summary
        self.tag = tag
    }
}

/// Complete session data including messages.
///
/// Contains the full session transcript alongside its metadata. Used when loading
/// a session from ``SessionStore``.
///
/// - Note: Uses `@unchecked Sendable` because `messages` holds untyped
///   `[String: Any]` dictionaries that cannot be statically verified as Sendable.
public struct SessionData: @unchecked Sendable {
    /// The session metadata.
    public let metadata: SessionMetadata
    /// The conversation messages as raw dictionaries.
    public let messages: [[String: Any]]

    public init(metadata: SessionMetadata, messages: [[String: Any]]) {
        self.metadata = metadata
        self.messages = messages
    }
}

/// Input metadata for saving a session (subset of ``SessionMetadata`` fields).
///
/// Used by ``SessionStore/save(sessionId:messages:metadata:)`` to capture session
/// context without requiring full metadata. Timestamps and message count are generated
/// automatically during save.
public struct PartialSessionMetadata: Sendable {
    /// The working directory for the session.
    public let cwd: String
    /// The model used in the session.
    public let model: String
    /// An optional summary or title for the session.
    public let summary: String?
    /// An optional tag for categorizing the session.
    public let tag: String?

    public init(cwd: String, model: String, summary: String? = nil, tag: String? = nil) {
        self.cwd = cwd
        self.model = model
        self.summary = summary
        self.tag = tag
    }
}
