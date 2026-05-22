import Foundation

// MARK: - SkillUsageTracker

/// Stateless computation service that evaluates skill lifecycle transitions
/// based on usage data.
///
/// Delegates all persistence to the injected ``SkillUsageStore``.
/// This struct holds no mutable state — it reads data, computes transitions,
/// and returns results. The caller decides what to do with transitions.
public struct SkillUsageTracker: Sendable {

    /// The store used for reading and writing usage data.
    public let store: SkillUsageStore

    /// Configuration controlling lifecycle evaluation thresholds.
    public let config: SkillUsageTrackerConfig

    public init(store: SkillUsageStore, config: SkillUsageTrackerConfig = SkillUsageTrackerConfig()) {
        self.store = store
        self.config = config
    }

    /// Record a view/invocation of a skill.
    public func recordView(skillName: String) async throws {
        try await store.bumpView(skillName: skillName)
    }

    /// Record a management action (edit, configure) on a skill.
    public func recordManage(skillName: String) async throws {
        try await store.bumpManage(skillName: skillName)
    }

    /// Evaluate whether a lifecycle transition is warranted for a skill.
    ///
    /// Returns `nil` if no transition is needed. Evaluation follows these rules:
    /// 1. Pinned skills skip all transitions.
    /// 2. Bundled skills skip all transitions.
    /// 3. Experimental skills skip when `protectExperimental` is true.
    /// 4. Skills with zero views and no lastViewedAt skip (not enough data).
    /// 5. Skills stale for `archiveAfterDays` transition to retired (from deprecated).
    /// 6. Skills stale for `staleAfterDays` transition to deprecated (from active).
    public func checkLifecycle(skillName: String) async throws -> SkillLifecycleTransition? {
        let data = await store.getUsage(skillName: skillName)

        // Rule (a): pinned skills skip
        if data.pinned {
            return nil
        }

        // Rule (b): bundled provenance skips
        if data.provenance == .bundled {
            return nil
        }

        // Rule (c): experimental skills skip when protected
        // (determined before looking at days since view)
        if data.viewCount == 0 && data.lastViewedAt == nil && config.protectExperimental {
            return nil
        }

        // Rule (d): no data (never viewed)
        if data.viewCount == 0 && data.lastViewedAt == nil {
            return nil
        }

        guard let lastViewedAt = data.lastViewedAt else {
            return nil
        }

        let daysSinceView = Calendar.current.dateComponents([.day], from: lastViewedAt, to: Date()).day ?? 0

        // Rule (f): deprecated → retired (check first — higher threshold)
        if daysSinceView >= config.archiveAfterDays {
            return SkillLifecycleTransition(
                skillName: skillName,
                from: .deprecated,
                to: .retired,
                reason: "Skill not viewed for \(daysSinceView) days (threshold: \(config.archiveAfterDays) days)"
            )
        }

        // Rule (e): active → deprecated
        if daysSinceView >= config.staleAfterDays {
            return SkillLifecycleTransition(
                skillName: skillName,
                from: .active,
                to: .deprecated,
                reason: "Skill not viewed for \(daysSinceView) days (threshold: \(config.staleAfterDays) days)"
            )
        }

        // Rule (g): no transition warranted
        return nil
    }

    /// Evaluate lifecycle transitions for all tracked skills.
    public func checkAllLifecycles() async throws -> [String: SkillLifecycleTransition] {
        let allData = await store.allUsage()
        var transitions: [String: SkillLifecycleTransition] = [:]

        for skillName in allData.keys {
            if let transition = try await checkLifecycle(skillName: skillName) {
                transitions[skillName] = transition
            }
        }

        return transitions
    }
}
