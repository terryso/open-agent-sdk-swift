import Foundation

/// Thread-safe task store using actor isolation.
public actor TaskStore {

    // MARK: - Properties

    private var tasks: [String: Task] = [:]
    private var taskCounter: Int = 0
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Create a new task.
    /// - Returns: The created task with auto-generated ID and timestamps.
    public func create(
        subject: String,
        description: String? = nil,
        owner: String? = nil,
        status: TaskStatus = .pending
    ) -> Task {
        taskCounter += 1
        let id = "task_\(taskCounter)"
        let now = dateFormatter.string(from: Date())
        let task = Task(
            id: id,
            subject: subject,
            description: description,
            status: status,
            owner: owner,
            createdAt: now,
            updatedAt: now
        )
        tasks[id] = task
        return task
    }

    /// List tasks, optionally filtered by status and/or owner.
    public func list(status: TaskStatus? = nil, owner: String? = nil) -> [Task] {
        var result = Array(tasks.values)

        if let status {
            result = result.filter { $0.status == status }
        }
        if let owner {
            result = result.filter { $0.owner == owner }
        }

        return result
    }

    /// Get a task by ID.
    public func get(id: String) -> Task? {
        return tasks[id]
    }

    /// Update a task's fields.
    /// - Throws: ``TaskStoreError/taskNotFound`` if the task does not exist.
    /// - Throws: ``TaskStoreError/invalidStatusTransition`` if the status transition is invalid.
    public func update(
        id: String,
        status: TaskStatus? = nil,
        description: String? = nil,
        owner: String? = nil,
        output: String? = nil
    ) throws -> Task {
        guard var task = tasks[id] else {
            throw TaskStoreError.taskNotFound(id: id)
        }

        if let newStatus = status {
            guard isValidTransition(from: task.status, to: newStatus) else {
                throw TaskStoreError.invalidStatusTransition(from: task.status, to: newStatus)
            }
            task.status = newStatus
        }
        if let description { task.description = description }
        if let owner { task.owner = owner }
        if let output { task.output = output }
        task.updatedAt = dateFormatter.string(from: Date())

        tasks[id] = task
        return task
    }

    /// Delete a task by ID.
    /// - Returns: `true` if the task was found and deleted, `false` otherwise.
    public func delete(id: String) -> Bool {
        guard tasks[id] != nil else { return false }
        tasks.removeValue(forKey: id)
        return true
    }

    /// Clear all tasks and reset the ID counter.
    public func clear() {
        tasks.removeAll()
        taskCounter = 0
    }

    // MARK: - Private

    /// Valid state transitions:
    /// - pending / inProgress -> any status
    /// - completed, failed, cancelled -> terminal (no transitions)
    private func isValidTransition(from: TaskStatus, to: TaskStatus) -> Bool {
        switch from {
        case .pending, .inProgress:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }
}
