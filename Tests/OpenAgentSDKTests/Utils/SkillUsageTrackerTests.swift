import XCTest
@testable import OpenAgentSDK

final class SkillUsageTrackerTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("skill-usage-tracker-tests-\(UUID().uuidString)")
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

    private func makeStore() -> SkillUsageStore {
        SkillUsageStore(skillsDir: tempDir)
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
        provenance: SkillProvenance = .userDefined
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

    // MARK: - Active → Deprecated after staleAfterDays

    func testActiveToDeprecatedAfterStaleAfterDays() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "stale", viewCount: 5, lastViewedAt: date(daysAgo: 32))

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 30))
        let transition = try await tracker.checkLifecycle(skillName: "stale")

        XCTAssertNotNil(transition)
        XCTAssertEqual(transition?.from, .active)
        XCTAssertEqual(transition?.to, .deprecated)
        XCTAssertTrue(transition?.reason.contains("32 days") == true)
        XCTAssertTrue(transition?.reason.contains("threshold: 30 days") == true)
    }

    // MARK: - Deprecated → Retired after archiveAfterDays

    func testDeprecatedToRetiredAfterArchiveAfterDays() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "old", viewCount: 5, lastViewedAt: date(daysAgo: 95))

        let tracker = SkillUsageTracker(store: store)
        let transition = try await tracker.checkLifecycle(skillName: "old")

        XCTAssertNotNil(transition)
        XCTAssertEqual(transition?.from, .deprecated)
        XCTAssertEqual(transition?.to, .retired)
        XCTAssertTrue(transition?.reason.contains("threshold: 90 days") == true)
    }

    // MARK: - Pinned skill skips transition

    func testPinnedSkillSkipsTransition() async throws {
        let store = makeStore()
        try await seedSkill(
            store: store, name: "pinned-skill",
            viewCount: 5, lastViewedAt: date(daysAgo: 100), pinned: true
        )

        let tracker = SkillUsageTracker(store: store)
        let transition = try await tracker.checkLifecycle(skillName: "pinned-skill")
        XCTAssertNil(transition)
    }

    // MARK: - Bundled skill skips transition

    func testBundledSkillSkipsTransition() async throws {
        let store = makeStore()
        try await seedSkill(
            store: store, name: "builtin",
            viewCount: 5, lastViewedAt: date(daysAgo: 100), provenance: .bundled
        )

        let tracker = SkillUsageTracker(store: store)
        let transition = try await tracker.checkLifecycle(skillName: "builtin")
        XCTAssertNil(transition)
    }

    // MARK: - Experimental skill skips when protectExperimental is true

    func testExperimentalSkillSkipsWhenProtected() async throws {
        let store = makeStore()
        // A skill with viewCount=0 and no lastViewedAt is experimental
        try await seedSkill(store: store, name: "exp", viewCount: 0, lastViewedAt: nil)

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(protectExperimental: true))
        let transition = try await tracker.checkLifecycle(skillName: "exp")
        XCTAssertNil(transition)
    }

    // MARK: - No-data skill (never viewed) skips transition

    func testNoDataSkillSkipsTransition() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "new", viewCount: 0, lastViewedAt: nil)

        let tracker = SkillUsageTracker(store: store)
        let transition = try await tracker.checkLifecycle(skillName: "new")
        XCTAssertNil(transition)
    }

    // MARK: - Active skill within threshold (no transition)

    func testActiveSkillWithinThreshold() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "fresh", viewCount: 10, lastViewedAt: date(daysAgo: 5))

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 30))
        let transition = try await tracker.checkLifecycle(skillName: "fresh")
        XCTAssertNil(transition)
    }

    // MARK: - checkAllLifecycles returns multiple transitions

    func testCheckAllLifecyclesReturnsMultipleTransitions() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "stale1", viewCount: 5, lastViewedAt: date(daysAgo: 35))
        try await seedSkill(store: store, name: "stale2", viewCount: 5, lastViewedAt: date(daysAgo: 40))
        try await seedSkill(store: store, name: "fresh", viewCount: 5, lastViewedAt: date(daysAgo: 5))
        try await seedSkill(store: store, name: "pinned", viewCount: 5, lastViewedAt: date(daysAgo: 100), pinned: true)

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 30))
        let transitions = try await tracker.checkAllLifecycles()

        XCTAssertEqual(transitions.count, 2)
        XCTAssertEqual(transitions["stale1"]?.to, .deprecated)
        XCTAssertEqual(transitions["stale2"]?.to, .deprecated)
        XCTAssertNil(transitions["fresh"])
        XCTAssertNil(transitions["pinned"])
    }

    // MARK: - Custom config with different staleAfterDays

    func testCustomConfigWithDifferentStaleAfterDays() async throws {
        let store = makeStore()
        // Skill last viewed 10 days ago — should be stale with staleAfterDays=7
        try await seedSkill(store: store, name: "weekly", viewCount: 5, lastViewedAt: date(daysAgo: 10))

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 7))
        let transition = try await tracker.checkLifecycle(skillName: "weekly")

        XCTAssertNotNil(transition)
        XCTAssertEqual(transition?.to, .deprecated)
        XCTAssertTrue(transition?.reason.contains("threshold: 7 days") == true)
    }

    // MARK: - recordView delegates to store

    func testRecordViewDelegatesToStore() async throws {
        let store = makeStore()
        let tracker = SkillUsageTracker(store: store)

        try await tracker.recordView(skillName: "commit")
        let usage = await store.getUsage(skillName: "commit")
        XCTAssertEqual(usage.viewCount, 1)
    }

    // MARK: - recordManage delegates to store

    func testRecordManageDelegatesToStore() async throws {
        let store = makeStore()
        let tracker = SkillUsageTracker(store: store)

        try await tracker.recordManage(skillName: "review")
        let usage = await store.getUsage(skillName: "review")
        XCTAssertNotNil(usage.lastManagedAt)
    }

    // MARK: - Skill at exact threshold boundary triggers transition

    func testExactThresholdBoundaryTriggersTransition() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "boundary", viewCount: 5, lastViewedAt: date(daysAgo: 30))

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 30))
        let transition = try await tracker.checkLifecycle(skillName: "boundary")

        XCTAssertNotNil(transition, "Skill at exactly staleAfterDays should trigger transition")
        XCTAssertEqual(transition?.to, .deprecated)
    }

    // MARK: - Skill one day below threshold does not transition

    func testOneDayBelowThresholdNoTransition() async throws {
        let store = makeStore()
        try await seedSkill(store: store, name: "almost-stale", viewCount: 5, lastViewedAt: date(daysAgo: 29))

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 30))
        let transition = try await tracker.checkLifecycle(skillName: "almost-stale")
        XCTAssertNil(transition)
    }

    // MARK: - Experimental unprotected transitions

    func testExperimentalUnprotectedStillSkipsDueToNoDataRule() async throws {
        let store = makeStore()
        // A skill with viewCount=0, lastViewedAt=nil is experimental
        // But with protectExperimental=false and days since view >= staleAfterDays...
        // Actually, viewCount==0 && lastViewedAt==nil always returns nil (rule d).
        // So we need an experimental skill that HAS been viewed but is still in experimental range.
        // currentLifecycleState returns .active for recently viewed skills, not experimental.
        // The only way to get .experimental from currentLifecycleState is viewCount==0 && lastViewedAt==nil.
        // That case is caught by rule (d) before rule (c). So this test verifies the ordering:
        // protectExperimental doesn't matter because rule (d) catches it first.
        try await seedSkill(store: store, name: "exp", viewCount: 0, lastViewedAt: nil)

        let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(protectExperimental: false))
        let transition = try await tracker.checkLifecycle(skillName: "exp")
        XCTAssertNil(transition, "Rule (d) catches no-data before rule (c)")
    }
}
