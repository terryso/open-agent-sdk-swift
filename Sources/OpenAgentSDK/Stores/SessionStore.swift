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
    /// - Throws: ``SDKError/sessionError(message:)`` if directory creation, serialization, or file writing fails.
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
        if let tag = metadata.tag {
            metadataDict["tag"] = tag
        }
        if let firstPrompt = metadata.firstPrompt {
            metadataDict["firstPrompt"] = firstPrompt
        }
        if let gitBranch = metadata.gitBranch {
            metadataDict["gitBranch"] = gitBranch
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

        // Write fileSize back to metadata for future reads
        if let fileData = FileManager.default.contents(atPath: transcriptPath) {
            var updateDict = metadataDict
            updateDict["fileSize"] = fileData.count
            if let updateJSON = try? JSONSerialization.data(withJSONObject: ["metadata": updateDict, "messages": messages], options: [.prettyPrinted, .sortedKeys]) {
                _ = FileManager.default.createFile(atPath: transcriptPath, contents: updateJSON, attributes: permissions)
            }
        }
    }

    /// Load a session transcript from disk.
    /// - Parameters:
    ///   - sessionId: The session identifier to load.
    ///   - limit: Maximum number of messages to return. Defaults to `nil` (all messages).
    ///   - offset: Number of messages to skip from the beginning. Defaults to `nil` (start from 0).
    /// - Returns: `SessionData` if the session exists and can be deserialized, `nil` otherwise.
    public func load(sessionId: String, limit: Int? = nil, offset: Int? = nil) throws -> SessionData? {
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
            Logger.shared.warn("SessionStore", "load_corrupt_json", data: [
                "sessionId": sessionId
            ])
            return nil
        }

        // Reconstruct SessionMetadata
        guard let id = metadataDict["id"] as? String,
              let cwd = metadataDict["cwd"] as? String,
              let model = metadataDict["model"] as? String,
              let createdAtString = metadataDict["createdAt"] as? String,
              let updatedAtString = metadataDict["updatedAt"] as? String,
              let messageCount = metadataDict["messageCount"] as? Int
        else {
            let missingKeys = ["id", "cwd", "model", "createdAt", "updatedAt", "messageCount"]
                .filter { metadataDict[$0] == nil }
            Logger.shared.warn("SessionStore", "load_missing_fields", data: [
                "sessionId": sessionId,
                "missingKeys": missingKeys.joined(separator: ",")
            ])
            return nil
        }

        guard let createdAt = dateFormatter.date(from: createdAtString),
              let updatedAt = dateFormatter.date(from: updatedAtString)
        else {
            Logger.shared.warn("SessionStore", "load_malformed_dates", data: [
                "sessionId": sessionId,
                "createdAt": createdAtString,
                "updatedAt": updatedAtString,
            ])
            return nil
        }

        let summary = metadataDict["summary"] as? String
        let tag = metadataDict["tag"] as? String
        let fileSize = metadataDict["fileSize"] as? Int
        let firstPrompt = metadataDict["firstPrompt"] as? String
        let gitBranch = metadataDict["gitBranch"] as? String

        let metadata = SessionMetadata(
            id: id,
            cwd: cwd,
            model: model,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messageCount: messageCount,
            summary: summary,
            tag: tag,
            fileSize: fileSize,
            firstPrompt: firstPrompt,
            gitBranch: gitBranch
        )

        // Apply pagination
        var paginatedMessages = messagesArray
        if let off = offset, off > 0 {
            paginatedMessages = Array(paginatedMessages.dropFirst(off))
        }
        if let lim = limit, lim > 0 {
            paginatedMessages = Array(paginatedMessages.prefix(lim))
        }

        return SessionData(metadata: metadata, messages: paginatedMessages)
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

    /// Fork a session — create a copy with a new ID, optionally truncated to a specific message index.
    /// - Parameters:
    ///   - sourceSessionId: The session to fork from.
    ///   - newSessionId: Optional new session ID. Auto-generated UUID if nil.
    ///   - upToMessageIndex: Optional message index to truncate at (inclusive, 0-based).
    ///     When nil, all messages are copied.
    /// - Returns: The new session ID, or nil if source doesn't exist.
    /// - Throws: ``SDKError/sessionError(message:)`` if `upToMessageIndex` is out of range or `newSessionId` is invalid.
    public func fork(
        sourceSessionId: String,
        newSessionId: String? = nil,
        upToMessageIndex: Int? = nil
    ) throws -> String? {
        // Load source session
        guard let sourceData = try load(sessionId: sourceSessionId) else {
            return nil
        }

        // Determine messages to copy
        var forkMessages = sourceData.messages
        if let upToIndex = upToMessageIndex {
            guard upToIndex >= 0 else {
                throw SDKError.sessionError(message: "upToMessageIndex \(upToIndex) is negative")
            }
            guard upToIndex < sourceData.messages.count else {
                throw SDKError.sessionError(
                    message: "upToMessageIndex \(upToIndex) out of range (0..<\(sourceData.messages.count))"
                )
            }
            forkMessages = Array(sourceData.messages[0...upToIndex])
        }

        // Generate or use provided ID
        let forkId = newSessionId ?? UUID().uuidString

        // Validate the new session ID
        try validateSessionId(forkId)

        // Save the forked session
        let metadata = PartialSessionMetadata(
            cwd: sourceData.metadata.cwd,
            model: sourceData.metadata.model,
            summary: "Forked from session \(sourceSessionId)"
        )
        try save(sessionId: forkId, messages: forkMessages, metadata: metadata)

        return forkId
    }

    /// List all sessions, returning metadata sorted by `updatedAt` descending (most recent first).
    /// Invalid or corrupt sessions are silently skipped.
    /// - Parameters:
    ///   - limit: Maximum number of sessions to return. Defaults to `nil` (all sessions).
    ///   - includeWorktrees: Whether to include worktree sessions. Defaults to `false`.
    /// - Returns: Array of `SessionMetadata` for all valid sessions.
    public func list(limit: Int? = nil, includeWorktrees: Bool = false) throws -> [SessionMetadata] {
        let sessionsDir = getSessionsDir()

        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(atPath: sessionsDir)
        } catch {
            // Directory doesn't exist or is unreadable — return empty
            return []
        }

        var sessions: [SessionMetadata] = []
        for entry in entries {
            // Use load() to validate and extract metadata; skip on failure
            if let data = try? load(sessionId: entry) {
                sessions.append(data.metadata)
            }
        }

        // Sort by updatedAt descending (most recently updated first).
        // Use createdAt and id as tiebreakers for deterministic ordering
        // when two sessions share the same updatedAt timestamp.
        sessions.sort { a, b in
            if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id > b.id
        }

        if !includeWorktrees {
            // Filter out worktree sessions by checking for the .claude/worktrees path convention
            sessions = sessions.filter { session in
                let id = session.id.lowercased()
                return !id.contains("/.claude/worktrees/") && !id.hasPrefix("wt-")
            }
        }

        if let lim = limit, lim > 0 {
            sessions = Array(sessions.prefix(lim))
        }

        return sessions
    }

    /// Rename a session by updating its summary/title.
    /// If the session does not exist, this is a silent no-op (no error thrown).
    /// - Parameters:
    ///   - sessionId: The session identifier to rename.
    ///   - newTitle: The new title for the session.
    public func rename(sessionId: String, newTitle: String) throws {
        try validateSessionId(sessionId)
        guard let data = try load(sessionId: sessionId) else { return }

        let metadata = PartialSessionMetadata(
            cwd: data.metadata.cwd,
            model: data.metadata.model,
            summary: newTitle,
            tag: data.metadata.tag,
            firstPrompt: data.metadata.firstPrompt,
            gitBranch: data.metadata.gitBranch
        )
        try save(sessionId: sessionId, messages: data.messages, metadata: metadata)
    }

    /// Tag (or untag) a session.
    /// Pass `nil` for `tag` to remove an existing tag.
    /// If the session does not exist, this is a silent no-op (no error thrown).
    /// - Parameters:
    ///   - sessionId: The session identifier to tag.
    ///   - tag: The tag string, or `nil` to clear the tag.
    public func tag(sessionId: String, tag: String?) throws {
        try validateSessionId(sessionId)
        guard let data = try load(sessionId: sessionId) else { return }

        let metadata = PartialSessionMetadata(
            cwd: data.metadata.cwd,
            model: data.metadata.model,
            summary: data.metadata.summary,
            tag: tag,
            firstPrompt: data.metadata.firstPrompt,
            gitBranch: data.metadata.gitBranch
        )
        try save(sessionId: sessionId, messages: data.messages, metadata: metadata)
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
