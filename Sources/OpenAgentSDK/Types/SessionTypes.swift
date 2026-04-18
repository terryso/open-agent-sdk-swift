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
    /// The JSONL file size in bytes (TS SDK: `fileSize?`).
    public let fileSize: Int?
    /// The first meaningful user prompt (TS SDK: `firstPrompt?`).
    public let firstPrompt: String?
    /// The git branch at the end of the session (TS SDK: `gitBranch?`).
    public let gitBranch: String?

    public init(
        id: String,
        cwd: String,
        model: String,
        createdAt: Date,
        updatedAt: Date,
        messageCount: Int,
        summary: String? = nil,
        tag: String? = nil,
        fileSize: Int? = nil,
        firstPrompt: String? = nil,
        gitBranch: String? = nil
    ) {
        self.id = id
        self.cwd = cwd
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.summary = summary
        self.tag = tag
        self.fileSize = fileSize
        self.firstPrompt = firstPrompt
        self.gitBranch = gitBranch
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

/// A typed session message from historical session data (TS SDK: `SessionMessage`).
public struct SessionMessage: Sendable, Equatable {
    /// The role that produced this message.
    public enum Role: String, Sendable, Equatable {
        case user
        case assistant
        case system
    }

    /// The role (`user`, `assistant`, or `system`).
    public let role: Role
    /// Unique identifier for this message.
    public let uuid: String?
    /// Session identifier this message belongs to.
    public let sessionId: String?
    /// The message content (type depends on role).
    public let content: String?
    /// Parent tool use ID (always `nil` in historical messages per TS SDK).
    public let parentToolUseId: String?

    public init(role: Role, uuid: String? = nil, sessionId: String? = nil, content: String? = nil, parentToolUseId: String? = nil) {
        self.role = role
        self.uuid = uuid
        self.sessionId = sessionId
        self.content = content
        self.parentToolUseId = parentToolUseId
    }

    /// Creates a typed SessionMessage from a raw dictionary.
    public init?(from dict: [String: Any]) {
        guard let roleStr = dict["type"] as? String ?? dict["role"] as? String,
              let role = Role(rawValue: roleStr) else { return nil }
        self.role = role
        self.uuid = dict["uuid"] as? String
        self.sessionId = dict["session_id"] as? String ?? dict["sessionId"] as? String
        if let msg = dict["message"] {
            self.content = msg as? String ?? String(describing: msg)
        } else {
            self.content = dict["content"] as? String
        }
        self.parentToolUseId = dict["parent_tool_use_id"] as? String ?? dict["parentToolUseId"] as? String
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
    /// The first meaningful user prompt.
    public let firstPrompt: String?
    /// The git branch at the end of the session.
    public let gitBranch: String?

    public init(cwd: String, model: String, summary: String? = nil, tag: String? = nil, firstPrompt: String? = nil, gitBranch: String? = nil) {
        self.cwd = cwd
        self.model = model
        self.summary = summary
        self.tag = tag
        self.firstPrompt = firstPrompt
        self.gitBranch = gitBranch
    }
}
