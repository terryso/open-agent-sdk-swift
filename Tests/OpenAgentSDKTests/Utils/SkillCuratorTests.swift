import XCTest
@testable import OpenAgentSDK

final class SkillCuratorTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("skill-curator-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeUsageStore() -> SkillUsageStore {
        SkillUsageStore(skillsDir: tempDir)
    }

    private func makeCuratorStore() -> SkillCuratorStore {
        SkillCuratorStore(skillsDir: tempDir)
    }

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    private func seedSkill(
        store: SkillUsageStore,
        name: String,
        viewCount: Int = 10,
        lastViewedAt: Date?,
        pinned: Bool = false,
        provenance: SkillProvenance = .agentCreated
    ) async throws {
        let data = SkillUsageData(
            skillName: name,
            viewCount: viewCount,
            lastViewedAt: lastViewedAt,
            pinned: pinned,
            provenance: provenance
        )
        try await store.setUsage(skillName: name, data: data)
    }

    // MARK: - shouldRun

    func testShouldRunWhenEnabledAndNoLastRun() async {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(enabled: true)
        )
        let state = CuratorState.defaultState()
        XCTAssertTrue(curator.shouldRun(state: state))
    }

    func testShouldNotRunWhenDisabled() async {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(enabled: false)
        )
        let state = CuratorState.defaultState()
        XCTAssertFalse(curator.shouldRun(state: state))
    }

    func testShouldNotRunWhenPaused() async {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(enabled: true)
        )
        let state = CuratorState(paused: true)
        XCTAssertFalse(curator.shouldRun(state: state))
    }

    func testShouldNotRunWhenIntervalNotReached() async {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(intervalHours: 168.0)
        )
        let state = CuratorState(lastRunAt: Date())
        XCTAssertFalse(curator.shouldRun(state: state))
    }

    func testShouldRunWhenIntervalExceeded() async {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(intervalHours: 1.0)
        )
        // Last run 2 hours ago — exceeds 1 hour interval
        let state = CuratorState(lastRunAt: Date().addingTimeInterval(-7200))
        XCTAssertTrue(curator.shouldRun(state: state))
    }

    // MARK: - Full Curation Pass

    func testRunTransitionsAgentCreatedStaleSkills() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        // Seed an agent-created stale skill
        try await seedSkill(
            store: usageStore, name: "old-agent-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 35)
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertFalse(result.dryRun)
        XCTAssertEqual(result.skillsEvaluated, 1)
        XCTAssertEqual(result.transitionsApplied.count, 1)
        XCTAssertEqual(result.transitionsApplied.first?.skillName, "old-agent-skill")
        XCTAssertEqual(result.transitionsApplied.first?.to, .deprecated)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testRunSkipsBundledSkills() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedSkill(
            store: usageStore, name: "bundled-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 100),
            provenance: .bundled
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertEqual(result.skillsEvaluated, 0)
        XCTAssertEqual(result.skillsSkipped, 1)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
    }

    func testRunSkipsUserDefinedSkills() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedSkill(
            store: usageStore, name: "user-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 100),
            provenance: .userDefined
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertEqual(result.skillsSkipped, 1)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
    }

    func testRunSkipsHubInstalledSkills() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedSkill(
            store: usageStore, name: "hub-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 100),
            provenance: .hubInstalled
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertEqual(result.skillsSkipped, 1)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
    }

    func testRunSkipsPinnedSkills() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedSkill(
            store: usageStore, name: "pinned-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 100),
            pinned: true,
            provenance: .agentCreated
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertEqual(result.skillsSkipped, 1)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
    }

    // MARK: - dryRun Mode

    func testDryRunModeComputesButDoesNotApplyTransitions() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedSkill(
            store: usageStore, name: "stale-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 35)
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001, dryRun: true)
        )

        let result = try await curator.run()
        XCTAssertTrue(result.dryRun)
        XCTAssertEqual(result.transitionsApplied.count, 1)
        XCTAssertEqual(result.skillsEvaluated, 1)

        // State should NOT be persisted in dry-run mode
        let state = await curatorStore.loadState()
        XCTAssertEqual(state.runCount, 0, "Dry run should not increment runCount")
    }

    // MARK: - Run Returns Empty When ShouldRun Is False

    func testRunReturnsEmptyWhenShouldRunFalse() async throws {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(intervalHours: 168.0)
        )

        // Default state has lastRunAt=nil, so shouldRun returns true for fresh state.
        // Force the condition by saving a recent state.
        let curatorStore = makeCuratorStore()
        try await curatorStore.saveState(CuratorState(lastRunAt: Date()))

        let curator2 = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 168.0)
        )

        let result = try await curator2.run()
        XCTAssertTrue(result.dryRun)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
        XCTAssertEqual(result.skillsEvaluated, 0)
    }

    // MARK: - Pause and Resume

    func testPauseAndResume() async throws {
        let curatorStore = makeCuratorStore()
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: curatorStore,
            config: SkillCuratorConfig()
        )

        try await curator.pause()
        let pausedState = await curatorStore.loadState()
        XCTAssertTrue(pausedState.paused)

        try await curator.resume()
        let resumedState = await curatorStore.loadState()
        XCTAssertFalse(resumedState.paused)
    }

    func testPausedStatePreventsRun() async throws {
        let curatorStore = makeCuratorStore()
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        try await curator.pause()

        let result = try await curator.run()
        XCTAssertTrue(result.dryRun)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
    }

    // MARK: - State Persistence After Run

    func testRunPersistsState() async throws {
        let curatorStore = makeCuratorStore()
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        _ = try await curator.run()

        let state = await curatorStore.loadState()
        XCTAssertEqual(state.runCount, 1)
        XCTAssertNotNil(state.lastRunAt)
        XCTAssertNotNil(state.lastRunDurationMs)
    }

    // MARK: - Empty Store

    func testRunOnEmptyStore() async throws {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertEqual(result.skillsEvaluated, 0)
        XCTAssertEqual(result.skillsSkipped, 0)
        XCTAssertTrue(result.transitionsApplied.isEmpty)
    }

    // MARK: - Mixed Skills

    func testRunWithMixedSkillTypes() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        // Agent-created stale → should transition
        try await seedSkill(
            store: usageStore, name: "agent-stale",
            viewCount: 5, lastViewedAt: date(daysAgo: 35)
        )

        // Agent-created fresh → no transition
        try await seedSkill(
            store: usageStore, name: "agent-fresh",
            viewCount: 5, lastViewedAt: date(daysAgo: 5)
        )

        // Bundled stale → skipped
        try await seedSkill(
            store: usageStore, name: "bundled-stale",
            viewCount: 5, lastViewedAt: date(daysAgo: 100),
            provenance: .bundled
        )

        // Pinned agent → skipped
        try await seedSkill(
            store: usageStore, name: "pinned-agent",
            viewCount: 5, lastViewedAt: date(daysAgo: 100),
            pinned: true
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertEqual(result.skillsEvaluated, 2) // agent-stale + agent-fresh
        XCTAssertEqual(result.skillsSkipped, 2) // bundled-stale + pinned-agent
        XCTAssertEqual(result.transitionsApplied.count, 1)
        XCTAssertEqual(result.transitionsApplied.first?.skillName, "agent-stale")
    }

    // MARK: - Error Collection

    func testRunCollectsNoErrorsForCleanRun() async throws {
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testRunCollectsNoErrorsWithValidSkills() async throws {
        let usageStore = makeUsageStore()
        try await seedSkill(
            store: usageStore, name: "valid-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 5)
        )

        let curator = SkillCurator(
            usageStore: usageStore,
            curatorStore: makeCuratorStore(),
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        let result = try await curator.run()
        XCTAssertTrue(result.errors.isEmpty, "No errors should occur for valid skills")
        XCTAssertEqual(result.skillsEvaluated, 1)
    }

    // MARK: - Multiple Runs

    func testMultipleRunsIncrementRunCount() async throws {
        let curatorStore = makeCuratorStore()

        // Use a tiny interval; after each run, manually regress lastRunAt
        // so the next run passes the shouldRun check.
        let curator = SkillCurator(
            usageStore: makeUsageStore(),
            curatorStore: curatorStore,
            config: SkillCuratorConfig(intervalHours: 0.001)
        )

        _ = try await curator.run()

        // Manually set lastRunAt far enough back for next run
        try await curatorStore.saveState(CuratorState(
            lastRunAt: Date().addingTimeInterval(-10),
            runCount: 1
        ))

        _ = try await curator.run()

        try await curatorStore.saveState(CuratorState(
            lastRunAt: Date().addingTimeInterval(-10),
            runCount: 2
        ))

        _ = try await curator.run()

        let state = await curatorStore.loadState()
        XCTAssertEqual(state.runCount, 3)
    }
}
