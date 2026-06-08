import Foundation

// MARK: - FactFilter

/// Filter parameters for querying memory facts.
public struct FactFilter: Sendable, Equatable {
    /// Only return facts with this status. Nil means no status filter.
    public let status: MemoryFactStatus?
    /// Only return facts with this kind. Nil means no kind filter.
    public let kind: MemoryKind?

    public init(status: MemoryFactStatus? = nil, kind: MemoryKind? = nil) {
        self.status = status
        self.kind = kind
    }
}

// MARK: - FactStore

/// Thread-safe actor for persisting memory facts to disk as JSON files.
///
/// Each domain is stored as `{domain}-facts.json` in the configured memory directory.
/// On first read, legacy `KnowledgeEntry` files (`{domain}.json`) are lazily migrated
/// to the new format.
public actor FactStore {

    // MARK: - Properties

    private let customMemoryDir: String?
    private var cache: [String: [MemoryFact]] = [:]
    private let jsonEncoder = makeSDKJSONEncoder()
    private let jsonDecoder = makeSDKJSONDecoder()
    private let legacyDateFormatter = makeISO8601DateFormatter()

    // MARK: - Initialization

    /// Create a FactStore backed by the given directory.
    ///
    /// - Parameter memoryDir: Optional custom directory path. Defaults to `~/.agent/memory/`.
    public init(memoryDir: String? = nil) {
        self.customMemoryDir = memoryDir
        let resolvedDir = resolveMemoryDir(customDir: memoryDir)
        self.cache = Self.loadAllDomainsSync(from: resolvedDir, decoder: makeSDKJSONDecoder(), legacyDateFormatter: makeISO8601DateFormatter())
    }

    // MARK: - Public API

    /// Save (upsert) a single fact in the given domain.
    public func save(domain: String, fact: MemoryFact) throws {
        try validateDomainName(domain)
        try upsert(domain: domain, facts: [fact])
    }

    /// Batch save (upsert) multiple facts in the given domain.
    public func saveAll(domain: String, facts: [MemoryFact]) throws {
        try validateDomainName(domain)
        try upsert(domain: domain, facts: facts)
    }

    /// Query facts in a domain, optionally filtering by status and kind.
    public func query(domain: String, filter: FactFilter? = nil) throws -> [MemoryFact] {
        try validateDomainName(domain)

        // Check for legacy migration first
        try migrateLegacyIfNeeded(domain: domain)

        guard let facts = cache[domain] else {
            return []
        }

        var results = facts
        if let status = filter?.status {
            results = results.filter { $0.status == status }
        }
        if let kind = filter?.kind {
            results = results.filter { $0.kind == kind }
        }
        return results
    }

    /// Delete all facts in a domain and remove its file from disk.
    public func delete(domain: String) throws {
        try validateDomainName(domain)
        cache.removeValue(forKey: domain)
        removeDomainFile(domain)
    }

    /// List all domains that contain facts (both new and legacy formats).
    public func listDomains() throws -> [String] {
        let memoryDir = getMemoryDir()
        var domainSet = Set<String>()

        // Discover from cache
        domainSet.formUnion(cache.keys)

        // Scan disk for both formats
        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(atPath: memoryDir)
        } catch {
            return domainSet.sorted()
        }

        for entry in entries {
            if entry.hasSuffix("-facts.json") {
                let domain = String(entry.dropLast("-facts.json".count))
                domainSet.insert(domain)
            } else if entry.hasSuffix(".json") && !entry.hasSuffix("-facts.json") {
                let domain = String(entry.dropLast(".json".count))
                domainSet.insert(domain)
            }
        }

        return domainSet.sorted()
    }

    /// Create an immutable snapshot of the current facts for a domain.
    ///
    /// Returns a deep copy — subsequent mutations to the FactStore do not
    /// affect the snapshot. If the domain does not exist, returns a snapshot
    /// with an empty facts array.
    public func snapshot(domain: String) throws -> FrozenSnapshot {
        try validateDomainName(domain)
        try migrateLegacyIfNeeded(domain: domain)
        let facts = cache[domain] ?? []
        return FrozenSnapshot(domain: domain, facts: facts.map { $0 })
    }

    /// Restore a domain's facts from a snapshot, overwriting current state.
    ///
    /// Throws if the snapshot's domain contains path traversal characters.
    public func rollback(to snapshot: FrozenSnapshot) throws {
        try validateDomainName(snapshot.domain)
        cache[snapshot.domain] = snapshot.facts.map { $0 }
        try flushDomainToDisk(snapshot.domain)
    }

    // MARK: - Private: Upsert

    private func upsert(domain: String, facts: [MemoryFact]) throws {
        // Check for legacy migration before writing
        try migrateLegacyIfNeeded(domain: domain)

        if cache[domain] == nil {
            cache[domain] = []
        }

        for fact in facts {
            let normalized = MemoryFact.normalize(fact)
            if let idx = cache[domain]!.firstIndex(where: { $0.id == normalized.id }) {
                cache[domain]![idx] = normalized
            } else {
                cache[domain]!.append(normalized)
            }
        }

        try flushDomainToDisk(domain)
    }

    // MARK: - Private: Legacy Migration

    private func migrateLegacyIfNeeded(domain: String) throws {
        let memoryDir = getMemoryDir()
        let legacyPath = (memoryDir as NSString).appendingPathComponent("\(domain).json")

        // Only migrate if legacy file exists AND new file hasn't been written yet
        guard FileManager.default.fileExists(atPath: legacyPath),
              cache[domain] == nil else {
            return
        }

        guard let data = FileManager.default.contents(atPath: legacyPath) else { return }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            Logger.shared.warn("FactStore", "migration_corrupt_json", data: ["domain": domain])
            return
        }

        var migratedFacts: [MemoryFact] = []
        for jsonEntry in jsonArray {
            guard let id = jsonEntry["id"] as? String,
                  let content = jsonEntry["content"] as? String,
                  let createdAtStr = jsonEntry["createdAt"] as? String,
                  let createdAt = legacyDateFormatter.date(from: createdAtStr)
            else {
                continue
            }

            let tags = jsonEntry["tags"] as? [String] ?? []
            let kind: MemoryKind = tags.contains("affordance") ? .affordance :
                                   tags.contains("avoid") ? .avoid : .observation

            let fact = MemoryFact(
                id: id,
                domain: domain,
                content: content,
                status: .candidate,
                confidence: 0.5,
                evidenceCount: 1,
                source: .observation,
                kind: kind,
                createdAt: createdAt,
                lastVerifiedAt: createdAt
            )
            migratedFacts.append(fact)
        }

        if !migratedFacts.isEmpty {
            cache[domain] = migratedFacts
            // Write new format file (legacy file is NOT deleted per design)
            try flushDomainToDisk(domain)
        }
    }

    // MARK: - Private: Disk I/O

    private func getMemoryDir() -> String {
        resolveMemoryDir(customDir: customMemoryDir)
    }

    nonisolated private static func loadAllDomainsSync(
        from memoryDir: String,
        decoder: JSONDecoder,
        legacyDateFormatter: ISO8601DateFormatter
    ) -> [String: [MemoryFact]] {
        var result: [String: [MemoryFact]] = [:]

        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(atPath: memoryDir)
        } catch {
            return result
        }

        for entry in entries {
            guard entry.hasSuffix("-facts.json") else { continue }
            let domain = String(entry.dropLast("-facts.json".count))
            let filePath = (memoryDir as NSString).appendingPathComponent(entry)

            guard let data = FileManager.default.contents(atPath: filePath) else { continue }

            do {
                let facts = try decoder.decode([MemoryFact].self, from: data)
                if !facts.isEmpty {
                    result[domain] = facts
                }
            } catch {
                Logger.shared.warn("FactStore", "load_corrupt_json", data: [
                    "domain": domain,
                    "file": entry
                ])
            }
        }

        return result
    }

    private func flushDomainToDisk(_ domain: String) throws {
        let memoryDir = getMemoryDir()
        let filePath = (memoryDir as NSString).appendingPathComponent("\(domain)-facts.json")

        guard let facts = cache[domain] else { return }

        let jsonData: Data
        do {
            jsonData = try jsonEncoder.encode(facts)
        } catch {
            throw SDKError.sessionError(message: "Failed to serialize facts for domain '\(domain)': \(error.localizedDescription)")
        }

        do {
            try FileManager.default.createDirectory(
                atPath: memoryDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw SDKError.sessionError(message: "Failed to create memory directory: \(error.localizedDescription)")
        }

        do {
            try jsonData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
            throw SDKError.sessionError(message: "Failed to write facts file at \(filePath): \(error.localizedDescription)")
        }
    }

    private func removeDomainFile(_ domain: String) {
        let memoryDir = getMemoryDir()
        let filePath = (memoryDir as NSString).appendingPathComponent("\(domain)-facts.json")
        try? FileManager.default.removeItem(atPath: filePath)
    }

    private func validateDomainName(_ domain: String) throws {
        try validatePathSafeIdentifier(domain, label: "Domain name")
    }
}
