import Foundation

/// Result of a file rewind operation.
///
/// Returned by ``Agent/rewindFiles(to:dryRun:)`` to describe the outcome of
/// restoring the file system to the state at a given message.
///
/// ```swift
/// let result = try await agent.rewindFiles(to: "msg_123", dryRun: true)
/// print(result.filesAffected)  // Files that would be restored
/// print(result.preview)        // true because dryRun was true
/// ```
public struct RewindResult: Sendable, Equatable {
    /// List of file paths that were (or would be) affected by the rewind.
    public let filesAffected: [String]
    /// Whether the rewind operation succeeded.
    public let success: Bool
    /// Whether this was a dry-run preview (no actual file changes made).
    public let preview: Bool

    public init(filesAffected: [String], success: Bool, preview: Bool) {
        self.filesAffected = filesAffected
        self.success = success
        self.preview = preview
    }
}
