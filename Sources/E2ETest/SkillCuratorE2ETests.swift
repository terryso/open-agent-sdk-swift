import Foundation
import OpenAgentSDK

// MARK: - Skill Curator E2E Tests (Story 22.4: SkillCurator & SkillCuratorStore)

struct SkillCuratorE2ETests {
    static func run() async {
        section("71. SkillCuratorStore: Real File Persistence E2E")
        await testStoreRealPersistenceE2E()

        section("72. SkillCurator: Full Curation Pass E2E")
        await testFullCurationPassE2E()

        section("73. SkillCurator: Skip Rules E2E")
        await testSkipRulesE2E()

        section("74. SkillCurator: dryRun Mode E2E")
        await testDryRunModeE2E()

        section("75. SkillCurator: pause/resume E2E")
        await testPauseResumeE2E()
    }

    // MARK: - Helpers

    private static func makeTempDir() -> String {
        let dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("e2e-skill-curator-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    // MARK: - Test 71: Store Real Persistence

    private static func testStoreRealPersistenceE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            // Save state with first store instance
            let store1 = SkillCuratorStore(skillsDir: tempDir)
            let savedState = CuratorState(
                lastRunAt: Date(timeIntervalSince1970: 1700000000),
                paused: false,
                runCount: 5,
                lastRunDurationMs: 142,
                lastErrors: ["warning: skill-X eval failed"]
            )
            try await store1.saveState(savedState)

            // Verify file was written
            let filePath = (tempDir as NSString).appendingPathComponent(".curator-state.json")
            if FileManager.default.fileExists(atPath: filePath) {
                pass("CuratorStore E2E: .curator-state.json file created on disk")
            } else {
                fail("CuratorStore E2E: .curator-state.json file created on disk", "file not found")
            }

            // Verify file content is valid JSON with expected keys
            if let fileData = FileManager.default.contents(atPath: filePath),
               let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
                pass("CuratorStore E2E: file contains valid JSON object")

                if let runCount = json["runCount"] as? Int, runCount == 5 {
                    pass("CuratorStore E2E: runCount serialized correctly")
                } else {
                    fail("CuratorStore E2E: runCount serialized correctly", "got \(json["runCount"] ?? "nil")")
                }

                if let paused = json["paused"] as? Bool, !paused {
                    pass("CuratorStore E2E: paused serialized correctly")
                } else {
                    fail("CuratorStore E2E: paused serialized correctly", "got \(json["paused"] ?? "nil")")
                }

                if let errors = json["lastErrors"] as? [String], errors.count == 1 {
                    pass("CuratorStore E2E: lastErrors serialized correctly")
                } else {
                    fail("CuratorStore E2E: lastErrors serialized correctly", "got \(json["lastErrors"] ?? "nil")")
                }
            } else {
                fail("CuratorStore E2E: file contains valid JSON object", "invalid JSON or file unreadable")
            }

            // Create second store instance — should read from disk
            let store2 = SkillCuratorStore(skillsDir: tempDir)
            let loaded = await store2.loadState()

            if loaded.runCount == 5 {
                pass("CuratorStore E2E: runCount persisted across store instances")
            } else {
                fail("CuratorStore E2E: runCount persisted across store instances", "runCount=\(loaded.runCount)")
            }

            if loaded.lastRunDurationMs == 142 {
                pass("CuratorStore E2E: lastRunDurationMs persisted across store instances")
            } else {
                fail("CuratorStore E2E: lastRunDurationMs persisted across store instances", "got \(String(describing: loaded.lastRunDurationMs))")
            }

            if !loaded.paused {
                pass("CuratorStore E2E: paused=false persisted across store instances")
            } else {
                fail("CuratorStore E2E: paused=false persisted across store instances", "got true")
            }

            if loaded.lastErrors.count == 1 && loaded.lastErrors[0] == "warning: skill-X eval failed" {
                pass("CuratorStore E2E: lastErrors persisted across store instances")
            } else {
                fail("CuratorStore E2E: lastErrors persisted across store instances", "got \(loaded.lastErrors)")
            }

            // Default state when no file exists
            let emptyDir = makeTempDir()
            defer { cleanup(emptyDir) }
            let store3 = SkillCuratorStore(skillsDir: emptyDir)
            let defaultState = await store3.loadState()
            if defaultState.runCount == 0 && defaultState.lastRunAt == nil {
                pass("CuratorStore E2E: default state returned when no file exists")
            } else {
                fail("CuratorStore E2E: default state returned when no file exists",
                     "runCount=\(defaultState.runCount) lastRunAt=\(String(describing: defaultState.lastRunAt))")
            }
        } catch {
            fail("CuratorStore E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 72: Full Curation Pass

    private static func testFullCurationPassE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let usageStore = SkillUsageStore(skillsDir: tempDir)
            let curatorStore = SkillCuratorStore(skillsDir: tempDir)

            // Seed an agent-created stale skill (35 days ago → should transition to deprecated)
            try await usageStore.setUsage(skillName: "agent-stale", data: SkillUsageData(
                skillName: "agent-stale", viewCount: 10,
                lastViewedAt: date(daysAgo: 35), provenance: .agentCreated
            ))

            // Seed an agent-created fresh skill (5 days ago → no transition)
            try await usageStore.setUsage(skillName: "agent-fresh", data: SkillUsageData(
                skillName: "agent-fresh", viewCount: 10,
                lastViewedAt: date(daysAgo: 5), provenance: .agentCreated
            ))

            let curator = SkillCurator(
                usageStore: usageStore,
                curatorStore: curatorStore,
                config: SkillCuratorConfig(intervalHours: 0.001)
            )

            let result = try await curator.run()

            // Result should not be dryRun
            if !result.dryRun {
                pass("Curation E2E: result is not dryRun")
            } else {
                fail("Curation E2E: result is not dryRun", "dryRun=true")
            }

            // Two skills evaluated
            if result.skillsEvaluated == 2 {
                pass("Curation E2E: 2 skills evaluated (agent-stale + agent-fresh)")
            } else {
                fail("Curation E2E: 2 skills evaluated", "evaluated=\(result.skillsEvaluated)")
            }

            // One transition for the stale skill
            if result.transitionsApplied.count == 1 {
                pass("Curation E2E: 1 transition computed")
            } else {
                fail("Curation E2E: 1 transition computed", "count=\(result.transitionsApplied.count)")
            }

            if let t = result.transitionsApplied.first {
                if t.skillName == "agent-stale" {
                    pass("Curation E2E: transition targets agent-stale")
                } else {
                    fail("Curation E2E: transition targets agent-stale", "skillName=\(t.skillName)")
                }
                if t.to == .deprecated {
                    pass("Curation E2E: stale skill transitions to deprecated")
                } else {
                    fail("Curation E2E: stale skill transitions to deprecated", "to=\(t.to)")
                }
                if t.from == .active {
                    pass("Curation E2E: transition from active")
                } else {
                    fail("Curation E2E: transition from active", "from=\(t.from)")
                }
            }

            // No errors
            if result.errors.isEmpty {
                pass("Curation E2E: no errors during run")
            } else {
                fail("Curation E2E: no errors during run", "errors=\(result.errors)")
            }

            // Duration is positive
            if result.durationMs >= 0 {
                pass("Curation E2E: durationMs is non-negative")
            } else {
                fail("Curation E2E: durationMs is non-negative", "durationMs=\(result.durationMs)")
            }

            // State was persisted after the run
            let state = await curatorStore.loadState()
            if state.runCount == 1 {
                pass("Curation E2E: runCount incremented to 1")
            } else {
                fail("Curation E2E: runCount incremented to 1", "runCount=\(state.runCount)")
            }

            if state.lastRunAt != nil {
                pass("Curation E2E: lastRunAt set after run")
            } else {
                fail("Curation E2E: lastRunAt set after run", "nil")
            }

            if state.lastRunDurationMs != nil {
                pass("Curation E2E: lastRunDurationMs set after run")
            } else {
                fail("Curation E2E: lastRunDurationMs set after run", "nil")
            }

            // Empty store produces no transitions
            let emptyDir = makeTempDir()
            defer { cleanup(emptyDir) }
            let emptyUsageStore = SkillUsageStore(skillsDir: emptyDir)
            let emptyCuratorStore = SkillCuratorStore(skillsDir: emptyDir)
            let emptyCurator = SkillCurator(
                usageStore: emptyUsageStore,
                curatorStore: emptyCuratorStore,
                config: SkillCuratorConfig(intervalHours: 0.001)
            )
            let emptyResult = try await emptyCurator.run()
            if emptyResult.transitionsApplied.isEmpty && emptyResult.skillsEvaluated == 0 {
                pass("Curation E2E: empty store produces no transitions")
            } else {
                fail("Curation E2E: empty store produces no transitions",
                     "evaluated=\(emptyResult.skillsEvaluated) transitions=\(emptyResult.transitionsApplied.count)")
            }
        } catch {
            fail("Curation E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 73: Skip Rules

    private static func testSkipRulesE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let usageStore = SkillUsageStore(skillsDir: tempDir)
            let curatorStore = SkillCuratorStore(skillsDir: tempDir)

            // Bundled skill: very old but bundled → skip
            try await usageStore.setUsage(skillName: "bundled-old", data: SkillUsageData(
                skillName: "bundled-old", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), provenance: .bundled
            ))

            // User-defined skill: very old → skip
            try await usageStore.setUsage(skillName: "user-old", data: SkillUsageData(
                skillName: "user-old", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), provenance: .userDefined
            ))

            // Hub-installed skill: very old → skip
            try await usageStore.setUsage(skillName: "hub-old", data: SkillUsageData(
                skillName: "hub-old", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), provenance: .hubInstalled
            ))

            // Pinned agent-created: very old but pinned → skip
            try await usageStore.setUsage(skillName: "pinned-old", data: SkillUsageData(
                skillName: "pinned-old", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), pinned: true, provenance: .agentCreated
            ))

            let curator = SkillCurator(
                usageStore: usageStore,
                curatorStore: curatorStore,
                config: SkillCuratorConfig(intervalHours: 0.001)
            )

            let result = try await curator.run()

            // All 4 skills should be skipped
            if result.skillsSkipped == 4 {
                pass("SkipRules E2E: 4 skills skipped (bundled + user + hub + pinned)")
            } else {
                fail("SkipRules E2E: 4 skills skipped", "skipped=\(result.skillsSkipped)")
            }

            // No skills evaluated
            if result.skillsEvaluated == 0 {
                pass("SkipRules E2E: 0 skills evaluated")
            } else {
                fail("SkipRules E2E: 0 skills evaluated", "evaluated=\(result.skillsEvaluated)")
            }

            // No transitions
            if result.transitionsApplied.isEmpty {
                pass("SkipRules E2E: no transitions applied")
            } else {
                fail("SkipRules E2E: no transitions applied", "count=\(result.transitionsApplied.count)")
            }

            // No errors
            if result.errors.isEmpty {
                pass("SkipRules E2E: no errors")
            } else {
                fail("SkipRules E2E: no errors", "errors=\(result.errors)")
            }

            // Mixed: some eligible, some skipped
            let mixedDir = makeTempDir()
            defer { cleanup(mixedDir) }
            let mixedUsage = SkillUsageStore(skillsDir: mixedDir)
            let mixedCuratorStore = SkillCuratorStore(skillsDir: mixedDir)

            // Agent-created stale → should be evaluated + transition
            try await mixedUsage.setUsage(skillName: "eligible-stale", data: SkillUsageData(
                skillName: "eligible-stale", viewCount: 5,
                lastViewedAt: date(daysAgo: 35), provenance: .agentCreated
            ))
            // Bundled → skipped
            try await mixedUsage.setUsage(skillName: "bundled-skill", data: SkillUsageData(
                skillName: "bundled-skill", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), provenance: .bundled
            ))
            // Pinned agent → skipped
            try await mixedUsage.setUsage(skillName: "pinned-agent", data: SkillUsageData(
                skillName: "pinned-agent", viewCount: 5,
                lastViewedAt: date(daysAgo: 100), pinned: true, provenance: .agentCreated
            ))
            // Agent fresh → evaluated, no transition
            try await mixedUsage.setUsage(skillName: "agent-fresh", data: SkillUsageData(
                skillName: "agent-fresh", viewCount: 5,
                lastViewedAt: date(daysAgo: 5), provenance: .agentCreated
            ))

            let mixedCurator = SkillCurator(
                usageStore: mixedUsage,
                curatorStore: mixedCuratorStore,
                config: SkillCuratorConfig(intervalHours: 0.001)
            )
            let mixedResult = try await mixedCurator.run()

            if mixedResult.skillsEvaluated == 2 {
                pass("SkipRules E2E: mixed - 2 evaluated (eligible-stale + agent-fresh)")
            } else {
                fail("SkipRules E2E: mixed - 2 evaluated", "evaluated=\(mixedResult.skillsEvaluated)")
            }

            if mixedResult.skillsSkipped == 2 {
                pass("SkipRules E2E: mixed - 2 skipped (bundled + pinned)")
            } else {
                fail("SkipRules E2E: mixed - 2 skipped", "skipped=\(mixedResult.skillsSkipped)")
            }

            if mixedResult.transitionsApplied.count == 1 {
                pass("SkipRules E2E: mixed - 1 transition (eligible-stale)")
            } else {
                fail("SkipRules E2E: mixed - 1 transition", "count=\(mixedResult.transitionsApplied.count)")
            }
        } catch {
            fail("SkipRules E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 74: dryRun Mode

    private static func testDryRunModeE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let usageStore = SkillUsageStore(skillsDir: tempDir)
            let curatorStore = SkillCuratorStore(skillsDir: tempDir)

            // Seed an agent-created stale skill
            try await usageStore.setUsage(skillName: "stale-skill", data: SkillUsageData(
                skillName: "stale-skill", viewCount: 10,
                lastViewedAt: date(daysAgo: 35), provenance: .agentCreated
            ))

            let curator = SkillCurator(
                usageStore: usageStore,
                curatorStore: curatorStore,
                config: SkillCuratorConfig(intervalHours: 0.001, dryRun: true)
            )

            let result = try await curator.run()

            // Result should be marked dryRun
            if result.dryRun {
                pass("dryRun E2E: result is marked dryRun")
            } else {
                fail("dryRun E2E: result is marked dryRun", "dryRun=false")
            }

            // Transitions are still computed
            if result.transitionsApplied.count == 1 {
                pass("dryRun E2E: transitions computed (1)")
            } else {
                fail("dryRun E2E: transitions computed (1)", "count=\(result.transitionsApplied.count)")
            }

            if result.skillsEvaluated == 1 {
                pass("dryRun E2E: skills evaluated")
            } else {
                fail("dryRun E2E: skills evaluated", "evaluated=\(result.skillsEvaluated)")
            }

            // State should NOT be persisted in dry-run mode
            let state = await curatorStore.loadState()
            if state.runCount == 0 {
                pass("dryRun E2E: runCount not incremented (still 0)")
            } else {
                fail("dryRun E2E: runCount not incremented", "runCount=\(state.runCount)")
            }

            if state.lastRunAt == nil {
                pass("dryRun E2E: lastRunAt not set")
            } else {
                fail("dryRun E2E: lastRunAt not set", "was set")
            }

            // Verify no state file was written (or it still has default content)
            let filePath = (tempDir as NSString).appendingPathComponent(".curator-state.json")
            if !FileManager.default.fileExists(atPath: filePath) {
                pass("dryRun E2E: no state file written to disk")
            } else {
                // File might exist from store initialization, check content
                if let data = FileManager.default.contents(atPath: filePath),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let runCount = json["runCount"] as? Int, runCount == 0 {
                    pass("dryRun E2E: state file still has default content")
                } else {
                    fail("dryRun E2E: state file still has default content", "file was modified")
                }
            }

            // Run again with dryRun=false — state should now persist
            let curatorReal = SkillCurator(
                usageStore: usageStore,
                curatorStore: curatorStore,
                config: SkillCuratorConfig(intervalHours: 0.001, dryRun: false)
            )
            _ = try await curatorReal.run()
            let stateAfterReal = await curatorStore.loadState()
            if stateAfterReal.runCount == 1 {
                pass("dryRun E2E: subsequent non-dryRun run persists state")
            } else {
                fail("dryRun E2E: subsequent non-dryRun run persists state", "runCount=\(stateAfterReal.runCount)")
            }
        } catch {
            fail("dryRun E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 75: pause/resume

    private static func testPauseResumeE2E() async {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        do {
            let usageStore = SkillUsageStore(skillsDir: tempDir)
            let curatorStore = SkillCuratorStore(skillsDir: tempDir)

            let curator = SkillCurator(
                usageStore: usageStore,
                curatorStore: curatorStore,
                config: SkillCuratorConfig(intervalHours: 0.001)
            )

            // Pause
            try await curator.pause()
            let pausedState = await curatorStore.loadState()
            if pausedState.paused {
                pass("pause/resume E2E: curator paused")
            } else {
                fail("pause/resume E2E: curator paused", "paused=false")
            }

            // Paused state should produce dryRun result
            let pausedResult = try await curator.run()
            if pausedResult.dryRun && pausedResult.transitionsApplied.isEmpty {
                pass("pause/resume E2E: paused curator returns empty dryRun result")
            } else {
                fail("pause/resume E2E: paused curator returns empty dryRun result",
                     "dryRun=\(pausedResult.dryRun) transitions=\(pausedResult.transitionsApplied.count)")
            }

            // Resume
            try await curator.resume()
            let resumedState = await curatorStore.loadState()
            if !resumedState.paused {
                pass("pause/resume E2E: curator resumed")
            } else {
                fail("pause/resume E2E: curator resumed", "still paused")
            }

            // After resume, run should execute normally
            // Seed a stale skill to verify the run actually executes
            try await usageStore.setUsage(skillName: "post-resume-skill", data: SkillUsageData(
                skillName: "post-resume-skill", viewCount: 5,
                lastViewedAt: date(daysAgo: 35), provenance: .agentCreated
            ))

            let postResumeResult = try await curator.run()
            if !postResumeResult.dryRun && postResumeResult.skillsEvaluated >= 1 {
                pass("pause/resume E2E: resumed curator executes curation pass")
            } else {
                fail("pause/resume E2E: resumed curator executes curation pass",
                     "dryRun=\(postResumeResult.dryRun) evaluated=\(postResumeResult.skillsEvaluated)")
            }

            // Verify state file reflects the pause/resume toggling
            let filePath = (tempDir as NSString).appendingPathComponent(".curator-state.json")
            if let data = FileManager.default.contents(atPath: filePath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let paused = json["paused"] as? Bool, !paused {
                pass("pause/resume E2E: persisted state shows paused=false after resume")
            } else {
                fail("pause/resume E2E: persisted state shows paused=false after resume", "check failed")
            }
        } catch {
            fail("pause/resume E2E: unexpected error", error.localizedDescription)
        }
    }
}
