import Foundation

// MARK: - SkillUsageStore

/// Thread-safe actor for persisting skill usage data to a JSON sidecar file.
///
/// Usage data is stored at `{skillsDir}/.usage.json`. The store uses atomic
/// file writes to prevent corruption. Depends only on ``Types/`` for data models.
public actor SkillUsageStore {

    // MARK: - Properties

    private let customSkillsDir: String?
    private var cache: [String: SkillUsageData] = [:]
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Initialization

    /// Create a SkillUsageStore backed by the given directory.
    ///
    /// - Parameter skillsDir: Optional custom directory path. Defaults to `~/.open-agent-sdk/skills/`.
    public init(skillsDir: String? = nil) {
        self.customSkillsDir = skillsDir
        let resolvedDir = Self.resolveSkillsDir(customDir: skillsDir)
        self.cache = Self.loadSync(from: resolvedDir, decoder: {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }())
    }

    // MARK: - Public API

    /// Get usage data for a skill. Returns default data if not tracked.
    public func getUsage(skillName: String) -> SkillUsageData {
        cache[skillName] ?? SkillUsageData(skillName: skillName)
    }

    /// Set usage data for a skill.
    public func setUsage(skillName: String, data: SkillUsageData) throws {
        cache[skillName] = data
        try flushToDisk()
    }

    /// Increment the view count and update lastViewedAt for a skill.
    public func bumpView(skillName: String) throws {
        var data = cache[skillName] ?? SkillUsageData(skillName: skillName)
        data.viewCount += 1
        data.lastViewedAt = Date()
        cache[skillName] = data
        try flushToDisk()
    }

    /// Update lastManagedAt for a skill.
    public func bumpManage(skillName: String) throws {
        var data = cache[skillName] ?? SkillUsageData(skillName: skillName)
        data.lastManagedAt = Date()
        cache[skillName] = data
        try flushToDisk()
    }

    /// Set the pinned status for a skill.
    public func setPinned(skillName: String, pinned: Bool) throws {
        var data = cache[skillName] ?? SkillUsageData(skillName: skillName)
        data.pinned = pinned
        cache[skillName] = data
        try flushToDisk()
    }

    /// Set the provenance for a skill.
    public func setProvenance(skillName: String, provenance: SkillProvenance) throws {
        var data = cache[skillName] ?? SkillUsageData(skillName: skillName)
        data.provenance = provenance
        cache[skillName] = data
        try flushToDisk()
    }

    /// Get all tracked usage data.
    public func allUsage() -> [String: SkillUsageData] {
        cache
    }

    // MARK: - Private: Path Resolution

    nonisolated private static func resolveSkillsDir(customDir: String?) -> String {
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
        return (home as NSString).appendingPathComponent(".open-agent-sdk/skills")
    }

    private func getSkillsDir() -> String {
        Self.resolveSkillsDir(customDir: customSkillsDir)
    }

    private func getUsageFilePath() -> String {
        (getSkillsDir() as NSString).appendingPathComponent(".usage.json")
    }

    // MARK: - Private: Loading

    nonisolated private static func loadSync(
        from skillsDir: String,
        decoder: JSONDecoder
    ) -> [String: SkillUsageData] {
        let filePath = (skillsDir as NSString).appendingPathComponent(".usage.json")

        guard let data = FileManager.default.contents(atPath: filePath) else {
            return [:]
        }

        do {
            return try decoder.decode([String: SkillUsageData].self, from: data)
        } catch {
            Logger.shared.warn("SkillUsageStore", "load_corrupt_json", data: [
                "file": filePath,
            ])
            return [:]
        }
    }

    // MARK: - Private: Disk I/O

    private func flushToDisk() throws {
        let skillsDir = getSkillsDir()
        let filePath = getUsageFilePath()

        let jsonData: Data
        do {
            jsonData = try jsonEncoder.encode(cache)
        } catch {
            throw SDKError.sessionError(
                message: "Failed to serialize skill usage data: \(error.localizedDescription)"
            )
        }

        do {
            try FileManager.default.createDirectory(
                atPath: skillsDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw SDKError.sessionError(
                message: "Failed to create skills directory: \(error.localizedDescription)"
            )
        }

        // Atomic write: write to temp file, then replace final location
        let tempFileName = ".usage.json.tmp.\(UUID().uuidString)"
        let tempFilePath = (skillsDir as NSString).appendingPathComponent(tempFileName)

        do {
            try jsonData.write(to: URL(fileURLWithPath: tempFilePath), options: .atomic)
            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(atPath: filePath)
            }
            try FileManager.default.moveItem(atPath: tempFilePath, toPath: filePath)
        } catch {
            try? FileManager.default.removeItem(atPath: tempFilePath)
            throw SDKError.sessionError(
                message: "Failed to write usage data at \(filePath): \(error.localizedDescription)"
            )
        }
    }
}
