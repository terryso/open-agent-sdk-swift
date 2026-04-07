import Foundation

/// Thread-safe cron store using actor isolation.
///
/// Manages cron job lifecycle: creating, deleting, and listing cron jobs.
/// All operations are actor-isolated for concurrent access safety.
public actor CronStore {

    // MARK: - Properties

    private var jobs: [String: CronJob] = [:]
    private var jobCounter: Int = 0
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Create a new cron job entry.
    ///
    /// Creates a new ``CronJob`` with auto-generated ID, `enabled` set to `true`,
    /// and the current timestamp as `createdAt`.
    ///
    /// - Parameters:
    ///   - name: The human-readable name of the cron job.
    ///   - schedule: The cron expression for scheduling (e.g., "*/5 * * * *").
    ///   - command: The command or prompt to execute when the job runs.
    /// - Returns: The newly created ``CronJob``.
    public func create(name: String, schedule: String, command: String) -> CronJob {
        jobCounter += 1
        let id = "cron_\(jobCounter)"
        let now = dateFormatter.string(from: Date())
        let job = CronJob(
            id: id,
            name: name,
            schedule: schedule,
            command: command,
            enabled: true,
            createdAt: now
        )
        jobs[id] = job
        return job
    }

    /// Delete a cron job by ID.
    ///
    /// Removes the cron job with the given ID from the store.
    ///
    /// - Parameter id: The ID of the cron job to delete.
    /// - Returns: `true` if the job was successfully deleted.
    /// - Throws: ``CronStoreError/cronJobNotFound(id:)`` if the job does not exist.
    public func delete(id: String) throws -> Bool {
        guard jobs[id] != nil else {
            throw CronStoreError.cronJobNotFound(id: id)
        }
        jobs.removeValue(forKey: id)
        return true
    }

    /// Get a cron job by ID.
    ///
    /// - Parameter id: The cron job ID to look up.
    /// - Returns: The ``CronJob`` if found, or `nil`.
    public func get(id: String) -> CronJob? {
        jobs[id]
    }

    /// List all stored cron jobs.
    ///
    /// - Returns: An array of all ``CronJob`` instances.
    public func list() -> [CronJob] {
        Array(jobs.values)
    }

    /// Clear all stored cron jobs and reset the ID counter.
    public func clear() {
        jobs.removeAll()
        jobCounter = 0
    }
}
