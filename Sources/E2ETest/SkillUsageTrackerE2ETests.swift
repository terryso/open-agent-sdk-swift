import Foundation
import OpenAgentSDK

// MARK: - Skill Usage Tracker E2E Tests (Story 22.3: SkillUsageTracker & SkillUsageStore)

struct SkillUsageTrackerE2ETests {
    static func run() async {
        section("67. SkillUsageStore: Real File Persistence E2E")
        await testStoreRealPersistenceE2E()

        section("68. SkillUsageTracker: Active → Deprecated Transition E2E")
        await testActiveToDeprecatedTransitionE2E()

        section("69. SkillUsageTracker: Skip Rules & Retired Transition E2E")
        await testSkipRulesAndRetiredTransitionE2E()

        section("70. SkillUsageTracker: checkAllLifecycles Multi-Skill E2E")
        await testCheckAllLifecyclesE2E()
    }

    // MARK: - Helpers

    private static func makeTempDir() -> String {
        let dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("e2e-skill-usage-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    // MARK: - Test 67: Store Real Persistence

    private static func testStoreRealPersistenceE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            // Write data with first store instance
            let store1 = SkillUsageStore(skillsDir: tempDir)
            try await store1.bumpView(skillName: "commit")
            try await store1.bumpView(skillName: "commit")
            try await store1.bumpManage(skillName: "commit")
            try await store1.setPinned(skillName: "important", pinned: true)
            try await store1.setProvenance(skillName: "custom", provenance: .agentCreated)
            try await store1.bumpView(skillName: "custom")

            // Verify file was written
            let filePath = (tempDir as NSString).appendingPathComponent(".usage.json")
            if FileManager.default.fileExists(atPath: filePath) {
                pass("Store E2E: .usage.json file created on disk")
            } else {
                fail("Store E2E: .usage.json file created on disk", "file not found")
            }

            // Verify file content is valid JSON
            if let fileData = FileManager.default.contents(atPath: filePath),
               let json = try? JSONSerialization.jsonObject(with: fileData),
               json is [String: Any] {
                pass("Store E2E: file contains valid JSON")
            } else {
                fail("Store E2E: file contains valid JSON", "invalid JSON or file unreadable")
            }

            // Create second store instance — should read from disk
            let store2 = SkillUsageStore(skillsDir: tempDir)

            let commitUsage = await store2.getUsage(skillName: "commit")
            if commitUsage.viewCount == 2 {
                pass("Store E2E: viewCount persisted across store instances")
            } else {
                fail("Store E2E: viewCount persisted across store instances", "viewCount=\(commitUsage.viewCount)")
            }

            if commitUsage.lastManagedAt != nil {
                pass("Store E2E: lastManagedAt persisted across store instances")
            } else {
                fail("Store E2E: lastManagedAt persisted across store instances", "nil")
            }

            let importantUsage = await store2.getUsage(skillName: "important")
            if importantUsage.pinned {
                pass("Store E2E: pinned status persisted across store instances")
            } else {
                fail("Store E2E: pinned status persisted across store instances", "not pinned")
            }

            let customUsage = await store2.getUsage(skillName: "custom")
            if customUsage.provenance == .agentCreated && customUsage.viewCount == 1 {
                pass("Store E2E: provenance and viewCount persisted across store instances")
            } else {
                fail("Store E2E: provenance and viewCount persisted across store instances",
                     "provenance=\(customUsage.provenance) viewCount=\(customUsage.viewCount)")
            }

            // Unknown skill returns defaults
            let unknownUsage = await store2.getUsage(skillName: "nonexistent")
            if unknownUsage.viewCount == 0 && unknownUsage.provenance == .userDefined {
                pass("Store E2E: unknown skill returns defaults")
            } else {
                fail("Store E2E: unknown skill returns defaults",
                     "viewCount=\(unknownUsage.viewCount) provenance=\(unknownUsage.provenance)")
            }

            // allUsage returns all tracked skills
            let all = await store2.allUsage()
            if all.count == 3 && all["commit"] != nil && all["important"] != nil && all["custom"] != nil {
                pass("Store E2E: allUsage returns all tracked skills")
            } else {
                fail("Store E2E: allUsage returns all tracked skills", "count=\(all.count)")
            }
        } catch {
            fail("Store E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 68: Active → Deprecated Transition

    private static func testActiveToDeprecatedTransitionE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let store = SkillUsageStore(skillsDir: tempDir)

            // Seed a skill last viewed 32 days ago
            let staleData = SkillUsageData(
                skillName: "stale-skill",
                viewCount: 10,
                lastViewedAt: date(daysAgo: 32)
            )
            try await store.setUsage(skillName: "stale-skill", data: staleData)

            // Seed a skill last viewed 5 days ago (fresh)
            let freshData = SkillUsageData(
                skillName: "fresh-skill",
                viewCount: 10,
                lastViewedAt: date(daysAgo: 5)
            )
            try await store.setUsage(skillName: "fresh-skill", data: freshData)

            let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(staleAfterDays: 30))

            // Stale skill should transition to deprecated
            let staleTransition = try await tracker.checkLifecycle(skillName: "stale-skill")
            if let t = staleTransition {
                pass("Active→Deprecated E2E: transition returned for stale skill")
                if t.from == .active && t.to == .deprecated {
                    pass("Active→Deprecated E2E: from=.active to=.deprecated")
                } else {
                    fail("Active→Deprecated E2E: from=.active to=.deprecated", "from=\(t.from) to=\(t.to)")
                }
                if t.reason.contains("32 days") && t.reason.contains("threshold: 30 days") {
                    pass("Active→Deprecated E2E: reason contains days and threshold")
                } else {
                    fail("Active→Deprecated E2E: reason contains days and threshold", "reason=\(t.reason)")
                }
            } else {
                fail("Active→Deprecated E2E: transition returned for stale skill", "nil")
            }

            // Fresh skill should not transition
            let freshTransition = try await tracker.checkLifecycle(skillName: "fresh-skill")
            if freshTransition == nil {
                pass("Active→Deprecated E2E: fresh skill has no transition")
            } else {
                fail("Active→Deprecated E2E: fresh skill has no transition", "unexpected transition")
            }

            // Exact boundary: skill viewed exactly staleAfterDays ago
            let boundaryData = SkillUsageData(
                skillName: "boundary",
                viewCount: 5,
                lastViewedAt: date(daysAgo: 30)
            )
            try await store.setUsage(skillName: "boundary", data: boundaryData)
            let boundaryTransition = try await tracker.checkLifecycle(skillName: "boundary")
            if boundaryTransition != nil {
                pass("Active→Deprecated E2E: exact threshold boundary triggers transition")
            } else {
                fail("Active→Deprecated E2E: exact threshold boundary triggers transition", "nil")
            }

            // One day below threshold
            let almostData = SkillUsageData(
                skillName: "almost",
                viewCount: 5,
                lastViewedAt: date(daysAgo: 29)
            )
            try await store.setUsage(skillName: "almost", data: almostData)
            let almostTransition = try await tracker.checkLifecycle(skillName: "almost")
            if almostTransition == nil {
                pass("Active→Deprecated E2E: one day below threshold skips transition")
            } else {
                fail("Active→Deprecated E2E: one day below threshold skips transition", "unexpected transition")
            }

            // recordView updates usage and changes lifecycle outcome
            try await tracker.recordView(skillName: "almost")
            let afterRecordView = try await tracker.checkLifecycle(skillName: "almost")
            if afterRecordView == nil {
                pass("Active→Deprecated E2E: recordView refreshes skill, no transition")
            } else {
                fail("Active→Deprecated E2E: recordView refreshes skill, no transition", "still transitioning")
            }
        } catch {
            fail("Active→Deprecated E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 69: Skip Rules & Retired Transition

    private static func testSkipRulesAndRetiredTransitionE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let store = SkillUsageStore(skillsDir: tempDir)

            // Pinned skill: very old, but pinned → skip
            try await store.setUsage(skillName: "pinned-old", data: SkillUsageData(
                skillName: "pinned-old", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), pinned: true
            ))

            // Bundled skill: very old, but bundled provenance → skip
            try await store.setUsage(skillName: "builtin", data: SkillUsageData(
                skillName: "builtin", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), provenance: .bundled
            ))

            // Experimental (no views): skip when protectExperimental=true
            try await store.setUsage(skillName: "exp", data: SkillUsageData(
                skillName: "exp", viewCount: 0, lastViewedAt: nil
            ))

            // Deprecated → retired: viewed 95 days ago
            try await store.setUsage(skillName: "old-skill", data: SkillUsageData(
                skillName: "old-skill", viewCount: 5,
                lastViewedAt: date(daysAgo: 95)
            ))

            let tracker = SkillUsageTracker(store: store)

            // Pinned skips
            let pinnedResult = try await tracker.checkLifecycle(skillName: "pinned-old")
            if pinnedResult == nil {
                pass("Skip Rules E2E: pinned skill skips transition")
            } else {
                fail("Skip Rules E2E: pinned skill skips transition", "unexpected transition")
            }

            // Bundled skips
            let bundledResult = try await tracker.checkLifecycle(skillName: "builtin")
            if bundledResult == nil {
                pass("Skip Rules E2E: bundled skill skips transition")
            } else {
                fail("Skip Rules E2E: bundled skill skips transition", "unexpected transition")
            }

            // Experimental (no data) skips
            let expResult = try await tracker.checkLifecycle(skillName: "exp")
            if expResult == nil {
                pass("Skip Rules E2E: experimental (no-data) skill skips transition")
            } else {
                fail("Skip Rules E2E: experimental (no-data) skill skips transition", "unexpected transition")
            }

            // Deprecated → retired
            let retiredResult = try await tracker.checkLifecycle(skillName: "old-skill")
            if let t = retiredResult {
                pass("Skip Rules E2E: 95-day-old skill triggers transition")
                if t.from == .deprecated && t.to == .retired {
                    pass("Skip Rules E2E: from=.deprecated to=.retired")
                } else {
                    fail("Skip Rules E2E: from=.deprecated to=.retired", "from=\(t.from) to=\(t.to)")
                }
                if t.reason.contains("95 days") && t.reason.contains("threshold: 90 days") {
                    pass("Skip Rules E2E: retired reason contains days and threshold")
                } else {
                    fail("Skip Rules E2E: retired reason contains days and threshold", "reason=\(t.reason)")
                }
            } else {
                fail("Skip Rules E2E: 95-day-old skill triggers transition", "nil")
            }

            // recordManage updates lastManagedAt
            try await tracker.recordManage(skillName: "pinned-old")
            let usage = await store.getUsage(skillName: "pinned-old")
            if usage.lastManagedAt != nil {
                pass("Skip Rules E2E: recordManage updates lastManagedAt")
            } else {
                fail("Skip Rules E2E: recordManage updates lastManagedAt", "nil")
            }
        } catch {
            fail("Skip Rules E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 70: checkAllLifecycles Multi-Skill

    private static func testCheckAllLifecyclesE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let store = SkillUsageStore(skillsDir: tempDir)

            // Seed multiple skills with different states
            try await store.setUsage(skillName: "stale-a", data: SkillUsageData(
                skillName: "stale-a", viewCount: 5, lastViewedAt: date(daysAgo: 35)
            ))
            try await store.setUsage(skillName: "stale-b", data: SkillUsageData(
                skillName: "stale-b", viewCount: 5, lastViewedAt: date(daysAgo: 40)
            ))
            try await store.setUsage(skillName: "ancient", data: SkillUsageData(
                skillName: "ancient", viewCount: 5, lastViewedAt: date(daysAgo: 100)
            ))
            try await store.setUsage(skillName: "fresh", data: SkillUsageData(
                skillName: "fresh", viewCount: 5, lastViewedAt: date(daysAgo: 5)
            ))
            try await store.setUsage(skillName: "pinned", data: SkillUsageData(
                skillName: "pinned", viewCount: 5, lastViewedAt: date(daysAgo: 50), pinned: true
            ))
            try await store.setUsage(skillName: "bundled", data: SkillUsageData(
                skillName: "bundled", viewCount: 5, lastViewedAt: date(daysAgo: 50), provenance: .bundled
            ))

            let tracker = SkillUsageTracker(store: store, config: SkillUsageTrackerConfig(
                staleAfterDays: 30, archiveAfterDays: 90
            ))

            let transitions = try await tracker.checkAllLifecycles()

            // stale-a and stale-b should be deprecated, ancient should be retired
            if transitions.count == 3 {
                pass("checkAll E2E: 3 transitions returned (stale-a, stale-b, ancient)")
            } else {
                fail("checkAll E2E: 3 transitions returned", "count=\(transitions.count)")
            }

            if let ta = transitions["stale-a"], ta.to == .deprecated {
                pass("checkAll E2E: stale-a → deprecated")
            } else {
                fail("checkAll E2E: stale-a → deprecated", "got \(transitions["stale-a"]?.to.rawValue ?? "nil")")
            }

            if let tb = transitions["stale-b"], tb.to == .deprecated {
                pass("checkAll E2E: stale-b → deprecated")
            } else {
                fail("checkAll E2E: stale-b → deprecated", "got \(transitions["stale-b"]?.to.rawValue ?? "nil")")
            }

            if let tc = transitions["ancient"], tc.to == .retired {
                pass("checkAll E2E: ancient → retired")
            } else {
                fail("checkAll E2E: ancient → retired", "got \(transitions["ancient"]?.to.rawValue ?? "nil")")
            }

            if transitions["fresh"] == nil {
                pass("checkAll E2E: fresh skill has no transition")
            } else {
                fail("checkAll E2E: fresh skill has no transition", "unexpected transition")
            }

            if transitions["pinned"] == nil {
                pass("checkAll E2E: pinned skill has no transition")
            } else {
                fail("checkAll E2E: pinned skill has no transition", "unexpected transition")
            }

            if transitions["bundled"] == nil {
                pass("checkAll E2E: bundled skill has no transition")
            } else {
                fail("checkAll E2E: bundled skill has no transition", "unexpected transition")
            }

            // Each transition has a populated reason
            var allHaveReasons = true
            for (_, t) in transitions {
                if t.reason.isEmpty { allHaveReasons = false }
            }
            if allHaveReasons {
                pass("checkAll E2E: all transitions have non-empty reasons")
            } else {
                fail("checkAll E2E: all transitions have non-empty reasons", "some reasons empty")
            }
        } catch {
            fail("checkAll E2E: unexpected error", error.localizedDescription)
        }
    }
}
