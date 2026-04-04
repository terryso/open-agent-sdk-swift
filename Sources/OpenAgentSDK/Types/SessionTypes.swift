import Foundation

/// Metadata for a persisted session.
public struct SessionMetadata: Sendable, Equatable {
    public let id: String
    public let cwd: String
    public let model: String
    public let createdAt: String
    public let updatedAt: String
    public let messageCount: Int
    public let summary: String?

    public init(
        id: String,
        cwd: String,
        model: String,
        createdAt: String,
        updatedAt: String,
        messageCount: Int,
        summary: String? = nil
    ) {
        self.id = id
        self.cwd = cwd
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.summary = summary
    }
}

/// Complete session data including messages.
/// Note: Uses `@unchecked Sendable` because `messages` holds untyped
/// `[String: Any]` dictionaries that cannot be statically verified as Sendable.
public struct SessionData: @unchecked Sendable {
    public let metadata: SessionMetadata
    public let messages: [[String: Any]]

    public init(metadata: SessionMetadata, messages: [[String: Any]]) {
        self.metadata = metadata
        self.messages = messages
    }
}
