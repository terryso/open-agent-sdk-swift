import Foundation

// MARK: - SkillCuratorStore

/// Actor for persisting curator state to a JSON sidecar file.
///
/// State is stored at `{skillsDir}/.curator-state.json`. Uses atomic file writes
/// to prevent corruption. Depends only on ``Types/`` for data models.
public actor SkillCuratorStore {

    // MARK: - Properties

    private let customSkillsDir: String?
    private var cachedState: CuratorState?
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

    /// Create a SkillCuratorStore backed by the given directory.
    ///
    /// - Parameter skillsDir: Optional custom directory path. Defaults to `~/.open-agent-sdk/skills/`.
    public init(skillsDir: String? = nil) {
        self.customSkillsDir = skillsDir
        self.cachedState = Self.loadSync(from: Self.resolveSkillsDir(customDir: skillsDir), decoder: {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }())
    }

    // MARK: - Public API

    /// Load the current curator state, returning the default if no persisted state exists.
    public func loadState() -> CuratorState {
        if let cached = cachedState {
            return cached
        }
        let state = Self.loadSync(from: getSkillsDir(), decoder: jsonDecoder) ?? .defaultState()
        cachedState = state
        return state
    }

    /// Persist the given curator state to disk.
    public func saveState(_ state: CuratorState) throws {
        cachedState = state
        try flushToDisk(state)
    }

    /// Returns the resolved skills directory path.
    public func getSkillsDir() -> String {
        Self.resolveSkillsDir(customDir: customSkillsDir)
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

    private func getStateFilePath() -> String {
        (getSkillsDir() as NSString).appendingPathComponent(".curator-state.json")
    }

    // MARK: - Private: Loading

    nonisolated private static func loadSync(
        from skillsDir: String,
        decoder: JSONDecoder
    ) -> CuratorState? {
        let filePath = (skillsDir as NSString).appendingPathComponent(".curator-state.json")

        guard let data = FileManager.default.contents(atPath: filePath) else {
            return nil
        }

        do {
            return try decoder.decode(CuratorState.self, from: data)
        } catch {
            Logger.shared.warn("SkillCuratorStore", "load_corrupt_json", data: [
                "file": filePath,
            ])
            return nil
        }
    }

    // MARK: - Private: Disk I/O

    private func flushToDisk(_ state: CuratorState) throws {
        let skillsDir = getSkillsDir()
        let filePath = getStateFilePath()

        let jsonData: Data
        do {
            jsonData = try jsonEncoder.encode(state)
        } catch {
            throw SDKError.sessionError(
                message: "Failed to serialize curator state: \(error.localizedDescription)"
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

        // Atomic write: write to temp file, remove existing, then move
        let tempFileName = ".curator-state.json.tmp.\(UUID().uuidString)"
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
                message: "Failed to write curator state at \(filePath): \(error.localizedDescription)"
            )
        }
    }
}
