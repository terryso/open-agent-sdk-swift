import Foundation

/// A single entry in the session memory FIFO queue.
///
/// Each entry captures a key piece of information extracted from conversation
/// compaction: a decision, preference, or constraint that should persist across
/// queries within the same agent process lifetime.
public struct SessionMemoryEntry: Sendable {
    /// Category of the memory entry: "decision", "preference", or "constraint".
    public let category: String
    /// One-sentence summary of the key information.
    public let summary: String
    /// Related file path or code snippet context.
    public let context: String
    /// When this entry was created.
    public let timestamp: Date

    public init(category: String, summary: String, context: String, timestamp: Date) {
        self.category = category
        self.summary = summary
        self.context = context
        self.timestamp = timestamp
    }
}

/// Manages cross-query context retention via a FIFO queue of memory entries.
///
/// Thread-safe via internal `NSLock`. Bounded to a configurable token budget
/// (default 4,000 tokens). When the budget is exceeded, oldest entries are
/// pruned first (FIFO strategy) to keep the memory within limits.
///
/// **Lifecycle:** Tied to the `Agent` instance -- not persisted across process
/// restarts. Designed as a `final class` (not actor) to avoid unnecessary
/// `await` overhead in synchronous contexts, consistent with `SkillRegistry`.
///
/// Conforms to `Sendable` because all mutable state is protected by `NSLock`.
final public class SessionMemory: @unchecked Sendable {

    private var entries: [SessionMemoryEntry] = []
    private let lock = NSLock()
    private let maxTokens: Int

    /// Default token budget for session memory.
    public static let defaultMaxTokens = 4000

    /// Create a SessionMemory with the specified token budget.
    ///
    /// - Parameter maxTokens: Maximum estimated tokens to retain. When exceeded,
    ///   oldest entries are pruned. Defaults to 4,000 tokens.
    public init(maxTokens: Int = defaultMaxTokens) {
        self.maxTokens = maxTokens
    }

    /// Append an entry to the session memory.
    ///
    /// After appending, triggers FIFO pruning if the total token count exceeds
    /// the configured budget. Oldest entries are removed first.
    ///
    /// - Parameter entry: The memory entry to append.
    public func append(_ entry: SessionMemoryEntry) {
        lock.lock()
        defer { lock.unlock() }

        entries.append(entry)
        pruneIfNeeded()
    }

    /// Format all entries as an XML block for system prompt injection.
    ///
    /// Returns a `<session-memory>` XML block containing all entries formatted
    /// as a bulleted list with category tags. Returns `nil` if no entries exist
    /// (to avoid injecting an empty block into the system prompt).
    ///
    /// - Returns: The formatted XML string, or `nil` if empty.
    public func formatForPrompt() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard !entries.isEmpty else { return nil }

        var lines: [String] = ["<session-memory>"]
        for entry in entries {
            lines.append("- [\(entry.category)] \(entry.summary)\(entry.context.isEmpty ? "" : " (\(entry.context))")")
        }
        lines.append("</session-memory>")

        return lines.joined(separator: "\n")
    }

    /// Current estimated token count across all entries.
    ///
    /// Uses `TokenEstimator.estimate(_:)` for language-aware estimation.
    ///
    /// - Returns: The total estimated token count.
    public func tokenCount() -> Int {
        lock.lock()
        defer { lock.unlock() }

        return computeTokenCount()
    }

    // MARK: - Private

    /// Compute token count without locking (caller must hold lock).
    private func computeTokenCount() -> Int {
        var total = 0
        for entry in entries {
            total += TokenEstimator.estimate(entry.category)
            total += TokenEstimator.estimate(entry.summary)
            total += TokenEstimator.estimate(entry.context)
        }
        return total
    }

    /// Prune oldest entries if total token count exceeds budget.
    /// Caller must hold `lock`.
    private func pruneIfNeeded() {
        while computeTokenCount() > maxTokens, !entries.isEmpty {
            entries.removeFirst()
        }
    }
}
