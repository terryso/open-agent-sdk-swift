import Foundation

// MARK: - SkillCurator

/// Automatic curation service that periodically evaluates the skill library.
///
/// Iterates agent-created skills, evaluates lifecycle transitions via
/// ``SkillUsageTracker``, and applies transitions (unless dry-run is enabled).
/// Bundled, user-defined, hub-installed, and pinned skills are always skipped.
public struct SkillCurator: Sendable {

    /// Store for reading/writing skill usage data.
    public let usageStore: SkillUsageStore
    /// Store for persisting curator state.
    public let curatorStore: SkillCuratorStore
    /// Configuration controlling curation behavior.
    public let config: SkillCuratorConfig

    public init(
        usageStore: SkillUsageStore,
        curatorStore: SkillCuratorStore,
        config: SkillCuratorConfig = SkillCuratorConfig()
    ) {
        self.usageStore = usageStore
        self.curatorStore = curatorStore
        self.config = config
    }

    /// Whether a curation run is due based on the current state and configuration.
    ///
    /// Returns `true` when: config is enabled, state is not paused, and either
    /// no previous run exists or enough time has elapsed since the last run.
    public func shouldRun(state: CuratorState) -> Bool {
        guard config.enabled else { return false }
        guard !state.paused else { return false }
        guard let lastRun = state.lastRunAt else {
            return true
        }
        let elapsed = Date().timeIntervalSince(lastRun) / 3600.0
        return elapsed >= config.intervalHours
    }

    /// Execute one curation pass.
    ///
    /// Loads state, evaluates all agent-created skills for lifecycle transitions,
    /// applies non-dry-run transitions, and persists the updated state.
    public func run() async throws -> CuratorRunResult {
        let startTime = Date()

        var state = await curatorStore.loadState()

        guard shouldRun(state: state) else {
            return CuratorRunResult(
                dryRun: true,
                ranAt: startTime
            )
        }

        let allUsage = await usageStore.allUsage()
        let tracker = SkillUsageTracker(
            store: usageStore,
            config: SkillUsageTrackerConfig(
                staleAfterDays: config.staleAfterDays,
                archiveAfterDays: config.archiveAfterDays
            )
        )

        var transitions: [SkillLifecycleTransition] = []
        var evaluated = 0
        var skipped = 0
        var errors: [String] = []

        for (skillName, usageData) in allUsage {
            // Skip non-agentCreated provenance
            if usageData.provenance != .agentCreated {
                skipped += 1
                continue
            }

            // Skip pinned skills
            if usageData.pinned {
                skipped += 1
                continue
            }

            evaluated += 1

            do {
                if let transition = try await tracker.checkLifecycle(skillName: skillName) {
                    transitions.append(transition)

                    if !config.dryRun {
                        var updated = usageData
                        updated.lastManagedAt = Date()
                        try await usageStore.setUsage(skillName: skillName, data: updated)
                    }
                }
            } catch {
                errors.append("Error evaluating \(skillName): \(error.localizedDescription)")
            }
        }

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Persist state only when not dry-running
        if !config.dryRun {
            state.lastRunAt = Date()
            state.runCount += 1
            state.lastRunDurationMs = durationMs
            state.lastErrors = errors
            try await curatorStore.saveState(state)
        }

        return CuratorRunResult(
            transitionsApplied: transitions,
            skillsEvaluated: evaluated,
            skillsSkipped: skipped,
            errors: errors,
            durationMs: durationMs,
            dryRun: config.dryRun,
            ranAt: startTime
        )
    }

    /// Pause automatic curation.
    public func pause() async throws {
        var state = await curatorStore.loadState()
        state.paused = true
        try await curatorStore.saveState(state)
    }

    /// Resume automatic curation.
    public func resume() async throws {
        var state = await curatorStore.loadState()
        state.paused = false
        try await curatorStore.saveState(state)
    }
}
