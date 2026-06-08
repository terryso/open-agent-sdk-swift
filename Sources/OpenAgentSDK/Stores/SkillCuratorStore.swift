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
        self.cachedState = Self.loadSync(from: resolveSkillsDir(customDir: skillsDir), decoder: {
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
        resolveSkillsDir(customDir: customSkillsDir)
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

        let jsonData: Data
        do {
            jsonData = try jsonEncoder.encode(state)
        } catch {
            throw SDKError.sessionError(
                message: "Failed to serialize curator state: \(error.localizedDescription)"
            )
        }

        try atomicWriteJSON(data: jsonData, toDirectory: skillsDir, fileName: ".curator-state.json", contentType: "curator state")
    }
}
