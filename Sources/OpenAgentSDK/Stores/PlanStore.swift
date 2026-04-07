import Foundation

/// Thread-safe plan store using actor isolation.
///
/// Manages plan lifecycle: entering plan mode, exiting with plan content,
/// and tracking plan history. All operations are actor-isolated for
/// concurrent access safety.
public actor PlanStore {

    // MARK: - Properties

    private var plans: [String: PlanEntry] = [:]
    private var planCounter: Int = 0
    private var activePlanId: String? = nil
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Enter plan mode, creating a new active plan entry.
    ///
    /// Creates a new ``PlanEntry`` with auto-generated ID, `active` status,
    /// and the current timestamp. Only one plan can be active at a time.
    ///
    /// - Returns: The newly created ``PlanEntry``.
    /// - Throws: ``PlanStoreError/alreadyInPlanMode`` if a plan is already active.
    public func enterPlanMode() throws -> PlanEntry {
        guard activePlanId == nil else {
            throw PlanStoreError.alreadyInPlanMode
        }
        planCounter += 1
        let id = "plan_\(planCounter)"
        let now = dateFormatter.string(from: Date())
        let entry = PlanEntry(
            id: id,
            content: nil,
            approved: false,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
        plans[id] = entry
        activePlanId = id
        return entry
    }

    /// Exit plan mode, finalizing the active plan with content and approval status.
    ///
    /// Updates the active plan entry with the provided content and approval flag,
    /// then sets the status to `completed` and clears the active plan reference.
    ///
    /// - Parameters:
    ///   - plan: The plan content text, or `nil` if no content was provided.
    ///   - approved: Whether the plan is approved. Defaults to `true` when `nil`.
    /// - Returns: The finalized ``PlanEntry``.
    /// - Throws: ``PlanStoreError/noActivePlan`` if no plan is currently active.
    public func exitPlanMode(plan: String?, approved: Bool?) throws -> PlanEntry {
        guard let activeId = activePlanId,
              var entry = plans[activeId] else {
            throw PlanStoreError.noActivePlan
        }
        let now = dateFormatter.string(from: Date())
        entry.content = plan
        entry.approved = approved ?? true
        entry.status = .completed
        entry.updatedAt = now
        plans[activeId] = entry
        activePlanId = nil
        return entry
    }

    /// Get the currently active plan entry, if any.
    ///
    /// - Returns: The active ``PlanEntry``, or `nil` if no plan is active.
    public func getCurrentPlan() -> PlanEntry? {
        guard let activeId = activePlanId else { return nil }
        return plans[activeId]
    }

    /// Check whether a plan is currently active.
    ///
    /// - Returns: `true` if a plan is active, `false` otherwise.
    public func isActive() -> Bool {
        activePlanId != nil
    }

    /// Get a plan entry by ID.
    ///
    /// - Parameter id: The plan ID to look up.
    /// - Returns: The ``PlanEntry`` if found, or `nil`.
    public func get(id: String) -> PlanEntry? {
        plans[id]
    }

    /// List all stored plan entries.
    ///
    /// - Returns: An array of all ``PlanEntry`` instances.
    public func list() -> [PlanEntry] {
        Array(plans.values)
    }

    /// Clear all stored plans and reset the ID counter.
    public func clear() {
        plans.removeAll()
        planCounter = 0
        activePlanId = nil
    }
}
