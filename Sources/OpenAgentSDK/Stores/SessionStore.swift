import Foundation

/// Thread-safe session store using actor isolation.
/// Persists session transcripts to JSON files at `~/.open-agent-sdk/sessions/{sessionId}/transcript.json`.
public actor SessionStore {

    // MARK: - Properties

    private let customSessionsDir: String?
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    /// Create a new SessionStore.
    /// - Parameter sessionsDir: Optional custom directory path for session storage.
    ///   When nil, defaults to `~/.open-agent-sdk/sessions/`.
    public init(sessionsDir: String? = nil) {
        self.customSessionsDir = sessionsDir
    }

    // MARK: - Public API

    /// Save a session transcript to disk.
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session.
    ///   - messages: Conversation messages as `[String: Any]` dictionaries.
    ///   - metadata: Partial metadata for the session (cwd, model, summary).
    /// - Throws: ``SDKError/sessionError`` if directory creation, serialization, or file writing fails.
    public func save(
        sessionId: String,
        messages: [[String: Any]],
        metadata: PartialSessionMetadata
    ) throws {
        try validateSessionId(sessionId)
        let sessionPath = getSessionPath(sessionId)
        let now = dateFormatter.string(from: Date())

        // Preserve original createdAt on re-save
        let existingCreatedAt = loadExistingCreatedAt(sessionId: sessionId, sessionPath: sessionPath)

        // Build the session dictionary for JSON serialization
        var metadataDict: [String: Any] = [
            "id": sessionId,
            "cwd": metadata.cwd,
            "model": metadata.model,
            "createdAt": existingCreatedAt ?? now,
            "updatedAt": now,
            "messageCount": messages.count,
        ]
        if let summary = metadata.summary {
            metadataDict["summary"] = summary
        }

        let sessionDict: [String: Any] = [
            "metadata": metadataDict,
            "messages": messages,
        ]

        // Create session directory (mkdir -p equivalent)
        do {
            try FileManager.default.createDirectory(
                atPath: sessionPath,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw SDKError.sessionError(message: "Failed to create session directory: \(error.localizedDescription)")
        }

        // Serialize to JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(
                withJSONObject: sessionDict,
                options: [.prettyPrinted, .sortedKeys]
            )
        } catch {
            throw SDKError.sessionError(message: "Failed to serialize session data: \(error.localizedDescription)")
        }

        // Write file with 0600 permissions
        let transcriptPath = (sessionPath as NSString).appendingPathComponent("transcript.json")
        let permissions: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        let success = FileManager.default.createFile(
            atPath: transcriptPath,
            contents: jsonData,
            attributes: permissions
        )
        if !success {
            throw SDKError.sessionError(message: "Failed to write transcript file at \(transcriptPath)")
        }
    }

    /// Load a session transcript from disk.
    /// - Parameter sessionId: The session identifier to load.
    /// - Returns: `SessionData` if the session exists and can be deserialized, `nil` otherwise.
    public func load(sessionId: String) throws -> SessionData? {
        try validateSessionId(sessionId)
        let sessionPath = getSessionPath(sessionId)
        let transcriptPath = (sessionPath as NSString).appendingPathComponent("transcript.json")

        // Read file contents
        guard let data = FileManager.default.contents(atPath: transcriptPath) else {
            return nil
        }

        // Deserialize JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = jsonObject as? [String: Any],
              let metadataDict = dict["metadata"] as? [String: Any],
              let messagesArray = dict["messages"] as? [[String: Any]]
        else {
            return nil
        }

        // Reconstruct SessionMetadata
        guard let id = metadataDict["id"] as? String,
              let cwd = metadataDict["cwd"] as? String,
              let model = metadataDict["model"] as? String,
              let createdAt = metadataDict["createdAt"] as? String,
              let updatedAt = metadataDict["updatedAt"] as? String,
              let messageCount = metadataDict["messageCount"] as? Int
        else {
            return nil
        }

        let summary = metadataDict["summary"] as? String

        let metadata = SessionMetadata(
            id: id,
            cwd: cwd,
            model: model,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messageCount: messageCount,
            summary: summary
        )

        return SessionData(metadata: metadata, messages: messagesArray)
    }

    /// Delete a session directory and all its files.
    /// - Parameter sessionId: The session identifier to delete.
    /// - Returns: `true` if the session was found and deleted, `false` otherwise.
    public func delete(sessionId: String) throws -> Bool {
        try validateSessionId(sessionId)
        let sessionPath = getSessionPath(sessionId)

        guard FileManager.default.fileExists(atPath: sessionPath) else {
            return false
        }

        do {
            try FileManager.default.removeItem(atPath: sessionPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private

    /// Resolve the sessions directory path.
    /// Uses custom directory if provided, otherwise defaults to `~/.open-agent-sdk/sessions/`.
    private func getSessionsDir() -> String {
        if let custom = customSessionsDir {
            return custom
        }

        let home: String
        #if os(Linux)
        if let homeEnv = getenv("HOME") {
            home = String(cString: homeEnv)
        } else {
            home = "/tmp"
        }
        #else
        home = NSHomeDirectory()
        #endif

        return (home as NSString).appendingPathComponent(".open-agent-sdk/sessions")
    }

    /// Validate that a sessionId does not contain path traversal sequences.
    private func validateSessionId(_ sessionId: String) throws {
        guard !sessionId.isEmpty else {
            throw SDKError.sessionError(message: "Session ID must not be empty")
        }
        let forbidden = ["/", "\\", ".."]
        for component in forbidden {
            if sessionId.contains(component) {
                throw SDKError.sessionError(message: "Session ID contains invalid character: '\(component)'")
            }
        }
    }

    /// Get the full path for a specific session directory.
    private func getSessionPath(_ sessionId: String) -> String {
        return (getSessionsDir() as NSString).appendingPathComponent(sessionId)
    }

    /// Read the createdAt timestamp from an existing session file, if present.
    private func loadExistingCreatedAt(sessionId: String, sessionPath: String) -> String? {
        let transcriptPath = (sessionPath as NSString).appendingPathComponent("transcript.json")
        guard let data = FileManager.default.contents(atPath: transcriptPath),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = jsonObject as? [String: Any],
              let metadataDict = dict["metadata"] as? [String: Any],
              let createdAt = metadataDict["createdAt"] as? String
        else {
            return nil
        }
        return createdAt
    }
}
