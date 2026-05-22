import Foundation

// MARK: - RunPersistenceService

/// Disk persistence for API run state and SSE events.
/// Uses `~/.open-agent-sdk/api-runs/` directory.
/// Stateless struct — thread safety comes from atomic file writes.
public struct RunPersistenceService: Sendable {

    /// Custom base directory for testing. When nil, uses `~/.open-agent-sdk/api-runs/`.
    private let customBaseDirectory: String?

    /// Lock for thread-safe FileHandle operations during JSONL appends.
    private let fileLock: NSLock

    public init(baseDirectory: String? = nil) {
        self.customBaseDirectory = baseDirectory
        self.fileLock = NSLock()
    }

    // MARK: - Path Helpers

    /// Returns base directory for persisted runs.
    public func runsDirectory() -> String {
        if let custom = customBaseDirectory {
            return custom
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(".open-agent-sdk/api-runs")
    }

    /// Returns the run directory, creating it if needed.
    public func runDirectory(runId: String) -> String {
        let dir = (runsDirectory() as NSString).appendingPathComponent(runId)
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        return dir
    }

    // MARK: - Record Persistence

    /// Atomically write TrackedRun to api-output.json.
    func persistRecord(_ run: TrackedRun) throws {
        let dir = runDirectory(runId: run.runId)
        let finalPath = (dir as NSString).appendingPathComponent("api-output.json")
        let data = try JSONEncoder().encode(run)
        try data.write(to: URL(fileURLWithPath: finalPath), options: .atomic)
    }

    /// Append an AgentSSEEvent to api-events.jsonl.
    func persistEvent(runId: String, event: AgentSSEEvent) throws {
        let dir = runDirectory(runId: runId)
        let eventsPath = (dir as NSString).appendingPathComponent("api-events.jsonl")
        let wrapper = PersistedSSEEvent(from: event)
        var data = try JSONEncoder().encode(wrapper)
        data.append(0x0A) // newline

        fileLock.lock()
        defer { fileLock.unlock() }

        if FileManager.default.fileExists(atPath: eventsPath) {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: eventsPath))
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try data.write(to: URL(fileURLWithPath: eventsPath))
        }
    }

    // MARK: - Loading

    /// Load a single TrackedRun from api-output.json.
    func loadRecord(runId: String) -> TrackedRun? {
        let dir = (runsDirectory() as NSString).appendingPathComponent(runId)
        let path = (dir as NSString).appendingPathComponent("api-output.json")
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        else { return nil }
        return try? JSONDecoder().decode(TrackedRun.self, from: data)
    }

    /// Load all AgentSSEEvents from api-events.jsonl.
    public func loadEvents(runId: String) -> [AgentSSEEvent] {
        let dir = (runsDirectory() as NSString).appendingPathComponent(runId)
        let path = (dir as NSString).appendingPathComponent("api-events.jsonl")
        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8)
        else { return [] }

        return content.split(separator: "\n").compactMap { line -> AgentSSEEvent? in
            guard let data = line.data(using: .utf8),
                  let wrapper = try? JSONDecoder().decode(PersistedSSEEvent.self, from: data)
            else { return nil }
            return wrapper.toSSEEvent()
        }
    }

    /// Scan the runs directory and load all persisted TrackedRuns.
    func loadAllPersistedRuns() -> [TrackedRun] {
        let baseDir = runsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            atPath: baseDir
        ) else { return [] }

        return contents.compactMap { subdir -> TrackedRun? in
            loadRecord(runId: subdir)
        }
    }

    // MARK: - Safe Wrappers

    /// Persist record without throwing — logs warning on failure.
    func persistRecordSafely(_ run: TrackedRun) {
        do {
            try persistRecord(run)
        } catch {
            print("[RunPersistence] Warning: failed to persist record for run \(run.runId): \(error)")
        }
    }

    /// Persist event without throwing — logs warning on failure.
    func persistEventSafely(runId: String, event: AgentSSEEvent) {
        do {
            try persistEvent(runId: runId, event: event)
        } catch {
            print("[RunPersistence] Warning: failed to persist event for run \(runId): \(error)")
        }
    }
}
