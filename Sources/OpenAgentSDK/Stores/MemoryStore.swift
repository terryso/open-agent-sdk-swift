import Foundation

// MARK: - Shared Helpers

/// Filter, sort, and limit knowledge entries based on query parameters and max age.
///
/// Shared by both `InMemoryStore` and `FileBasedMemoryStore` to eliminate
/// duplicated filter/sort/limit logic in their `query` methods.
///
/// - Parameters:
///   - entries: The candidate entries to filter.
///   - filter: Optional filter criteria (tags, date range, limit).
///   - maxAge: Maximum entry age in seconds; entries older than this are excluded.
/// - Returns: Filtered, sorted, and limited entries.
private func filterAndSortEntries(
    _ entries: [KnowledgeEntry],
    filter: KnowledgeQueryFilter?,
    maxAge: TimeInterval
) -> [KnowledgeEntry] {
    let expiryCutoff = Date().addingTimeInterval(-maxAge)

    var results = entries.filter { entry in
        // Auto-expiry: skip entries exceeding maxAge
        guard entry.createdAt > expiryCutoff else { return false }

        // Tag filter: match entries with any of the specified tags
        if let tags = filter?.tags, !tags.isEmpty {
            guard entry.tags.contains(where: { tags.contains($0) }) else {
                return false
            }
        }

        // Date range filters
        if let olderThan = filter?.olderThan {
            guard entry.createdAt < olderThan else { return false }
        }
        if let newerThan = filter?.newerThan {
            guard entry.createdAt > newerThan else { return false }
        }

        return true
    }

    // Sort by createdAt ascending (oldest first)
    results.sort { $0.createdAt < $1.createdAt }

    // Apply limit
    if let limit = filter?.limit, limit > 0 {
        results = Array(results.prefix(limit))
    }

    return results
}

// MARK: - InMemoryStore

/// In-memory knowledge store using actor isolation.
///
/// Stores knowledge entries by domain in a volatile dictionary.
/// Entries are lost when the process exits -- use ``FileBasedMemoryStore``
/// for cross-run persistence.
public actor InMemoryStore: MemoryStoreProtocol {

    // MARK: - Properties

    private var storage: [String: [KnowledgeEntry]] = [:]

    /// Maximum age for entries in seconds. Entries older than this are
    /// automatically filtered out during query. Defaults to 30 days (2,592,000 seconds).
    public let maxAge: TimeInterval

    // MARK: - Initialization

    /// Create a new InMemoryStore.
    /// - Parameter maxAge: Maximum age for entries in seconds. Defaults to 30 days.
    public init(maxAge: TimeInterval = 2_592_000) {
        self.maxAge = maxAge
    }

    // MARK: - MemoryStoreProtocol

    public func save(domain: String, knowledge: KnowledgeEntry) async throws {
        if storage[domain] == nil {
            storage[domain] = []
        }
        storage[domain]?.append(knowledge)
    }

    public func query(domain: String, filter: KnowledgeQueryFilter?) async throws -> [KnowledgeEntry] {
        guard let entries = storage[domain] else {
            return []
        }
        return filterAndSortEntries(entries, filter: filter, maxAge: maxAge)
    }

    public func delete(domain: String, olderThan: Date) async throws -> Int {
        guard var entries = storage[domain] else {
            return 0
        }

        let originalCount = entries.count
        entries.removeAll { $0.createdAt < olderThan }
        let deletedCount = originalCount - entries.count

        if entries.isEmpty {
            storage.removeValue(forKey: domain)
        } else {
            storage[domain] = entries
        }

        return deletedCount
    }

    public func listDomains() async throws -> [String] {
        storage.keys.sorted()
    }
}

// MARK: - FileBasedMemoryStore

/// File-backed knowledge store using actor isolation.
///
/// Persists knowledge entries to disk organized by domain.
/// Each domain is stored as a JSON file at `<memoryDir>/<domain>.json`.
/// Entries are auto-loaded on initialization.
///
/// The default base directory is `~/.agent/memory/`.
/// Corrupt files are skipped with a warning log, allowing the agent to continue.
public actor FileBasedMemoryStore: MemoryStoreProtocol {

    // MARK: - Properties

    private let customMemoryDir: String?
    private var cache: [String: [KnowledgeEntry]] = [:]
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Maximum age for entries in seconds. Entries older than this are
    /// automatically filtered out during query. Defaults to 30 days (2,592,000 seconds).
    public let maxAge: TimeInterval

    // MARK: - Initialization

    /// Create a new FileBasedMemoryStore.
    /// - Parameters:
    ///   - memoryDir: Optional custom directory path for memory storage.
    ///     When nil, defaults to `~/.agent/memory/`.
    ///   - maxAge: Maximum age for entries in seconds. Defaults to 30 days.
    public init(memoryDir: String? = nil, maxAge: TimeInterval = 2_592_000) {
        self.customMemoryDir = memoryDir
        self.maxAge = maxAge

        // Load all domain files on init using a static helper
        // (actor init is nonisolated, so we cannot call actor-isolated methods)
        let memoryDir = FileBasedMemoryStore.resolveMemoryDir(customDir: memoryDir)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.cache = Self.loadAllDomainsSync(from: memoryDir, dateFormatter: dateFormatter)
    }

    // MARK: - MemoryStoreProtocol

    public func save(domain: String, knowledge: KnowledgeEntry) throws {
        try validateDomainName(domain)

        if cache[domain] == nil {
            cache[domain] = []
        }
        cache[domain]?.append(knowledge)
        try flushDomainToDisk(domain)
    }

    public func query(domain: String, filter: KnowledgeQueryFilter?) throws -> [KnowledgeEntry] {
        try validateDomainName(domain)
        guard let entries = cache[domain] else {
            return []
        }
        return filterAndSortEntries(entries, filter: filter, maxAge: maxAge)
    }

    public func delete(domain: String, olderThan: Date) throws -> Int {
        try validateDomainName(domain)
        guard var entries = cache[domain] else {
            return 0
        }

        let originalCount = entries.count
        entries.removeAll { $0.createdAt < olderThan }
        let deletedCount = originalCount - entries.count

        if entries.isEmpty {
            cache.removeValue(forKey: domain)
            removeDomainFile(domain)
        } else {
            cache[domain] = entries
            try flushDomainToDisk(domain)
        }

        return deletedCount
    }

    public func listDomains() throws -> [String] {
        cache.keys.sorted()
    }

    // MARK: - Private: Disk I/O

    /// Resolve the memory directory path (static, callable from nonisolated init).
    nonisolated private static func resolveMemoryDir(customDir: String?) -> String {
        if let custom = customDir {
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

        return (home as NSString).appendingPathComponent(".agent/memory")
    }

    /// Resolve the memory directory path (instance convenience).
    private func getMemoryDir() -> String {
        Self.resolveMemoryDir(customDir: customMemoryDir)
    }

    /// Load all domain JSON files from disk into a cache dictionary (static, for init).
    nonisolated private static func loadAllDomainsSync(
        from memoryDir: String,
        dateFormatter: ISO8601DateFormatter
    ) -> [String: [KnowledgeEntry]] {
        var result: [String: [KnowledgeEntry]] = [:]

        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(atPath: memoryDir)
        } catch {
            // Directory doesn't exist or is unreadable -- start empty
            return result
        }

        for entry in entries {
            guard entry.hasSuffix(".json") else { continue }
            // Skip files managed by downstream apps (e.g. AxionFactStore's *-facts.json)
            guard !entry.hasSuffix("-facts.json") else { continue }
            let domainName = String(entry.dropLast(5)) // Remove ".json"

            let filePath = (memoryDir as NSString).appendingPathComponent(entry)
            guard let data = FileManager.default.contents(atPath: filePath) else {
                continue
            }

            guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                Logger.shared.warn("FileBasedMemoryStore", "load_corrupt_json", data: [
                    "domain": domainName,
                    "file": entry
                ])
                continue
            }

            var loadedEntries: [KnowledgeEntry] = []
            for jsonEntry in jsonArray {
                guard let id = jsonEntry["id"] as? String,
                      let content = jsonEntry["content"] as? String,
                      let tags = jsonEntry["tags"] as? [String],
                      let createdAtStr = jsonEntry["createdAt"] as? String,
                      let createdAt = dateFormatter.date(from: createdAtStr)
                else {
                    Logger.shared.warn("FileBasedMemoryStore", "load_invalid_entry", data: [
                        "domain": domainName,
                        "entryId": jsonEntry["id"] as? String ?? "unknown"
                    ])
                    continue
                }

                let sourceRunId = jsonEntry["sourceRunId"] as? String
                let entry = KnowledgeEntry(
                    id: id,
                    content: content,
                    tags: tags,
                    createdAt: createdAt,
                    sourceRunId: sourceRunId
                )
                loadedEntries.append(entry)
            }

            if !loadedEntries.isEmpty {
                result[domainName] = loadedEntries
            }
        }

        return result
    }

    /// Write a domain's entries to disk as JSON.
    private func flushDomainToDisk(_ domain: String) throws {
        let memoryDir = getMemoryDir()
        let filePath = (memoryDir as NSString).appendingPathComponent("\(domain).json")

        guard let entries = cache[domain] else { return }

        // Serialize entries
        let jsonArray: [[String: Any]] = entries.map { entry in
            var dict: [String: Any] = [
                "id": entry.id,
                "content": entry.content,
                "tags": entry.tags,
                "createdAt": dateFormatter.string(from: entry.createdAt),
            ]
            if let sourceRunId = entry.sourceRunId {
                dict["sourceRunId"] = sourceRunId
            }
            return dict
        }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(
                withJSONObject: jsonArray,
                options: [.prettyPrinted, .sortedKeys]
            )
        } catch {
            throw SDKError.sessionError(message: "Failed to serialize memory entries for domain '\(domain)': \(error.localizedDescription)")
        }

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(
                atPath: memoryDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw SDKError.sessionError(message: "Failed to create memory directory: \(error.localizedDescription)")
        }

        // Write file with 0600 permissions
        let permissions: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        let success = FileManager.default.createFile(
            atPath: filePath,
            contents: jsonData,
            attributes: permissions
        )
        if !success {
            throw SDKError.sessionError(message: "Failed to write memory file at \(filePath)")
        }
    }

    /// Remove a domain file from disk.
    private func removeDomainFile(_ domain: String) {
        let memoryDir = getMemoryDir()
        let filePath = (memoryDir as NSString).appendingPathComponent("\(domain).json")
        try? FileManager.default.removeItem(atPath: filePath)
    }

    /// Validate that a domain name does not contain path traversal sequences.
    private func validateDomainName(_ domain: String) throws {
        try validatePathSafeIdentifier(domain, label: "Domain name")
    }
}
