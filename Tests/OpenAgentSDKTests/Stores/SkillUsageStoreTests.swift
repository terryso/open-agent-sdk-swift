import XCTest
@testable import OpenAgentSDK

final class SkillUsageStoreTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("skill-usage-store-tests-\(UUID().uuidString)")
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

    // MARK: - Initial State

    func testInitialStateReturnsDefaultForUnknownSkill() async {
        let store = SkillUsageStore(skillsDir: tempDir)
        let usage = await store.getUsage(skillName: "unknown")
        XCTAssertEqual(usage.skillName, "unknown")
        XCTAssertEqual(usage.viewCount, 0)
        XCTAssertNil(usage.lastViewedAt)
        XCTAssertFalse(usage.pinned)
        XCTAssertEqual(usage.provenance, .userDefined)
    }

    func testAllUsageEmptyInitially() async {
        let store = SkillUsageStore(skillsDir: tempDir)
        let all = await store.allUsage()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - bumpView

    func testBumpViewIncrementsCount() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.bumpView(skillName: "commit")

        let usage = await store.getUsage(skillName: "commit")
        XCTAssertEqual(usage.viewCount, 1)
        XCTAssertNotNil(usage.lastViewedAt)
    }

    func testBumpViewMultipleTimes() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.bumpView(skillName: "commit")
        try await store.bumpView(skillName: "commit")
        try await store.bumpView(skillName: "commit")

        let usage = await store.getUsage(skillName: "commit")
        XCTAssertEqual(usage.viewCount, 3)
    }

    // MARK: - bumpManage

    func testBumpManageUpdatesTimestamp() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.bumpManage(skillName: "review")

        let usage = await store.getUsage(skillName: "review")
        XCTAssertNotNil(usage.lastManagedAt)
    }

    // MARK: - setPinned

    func testSetPinned() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.setPinned(skillName: "important", pinned: true)

        var usage = await store.getUsage(skillName: "important")
        XCTAssertTrue(usage.pinned)

        try await store.setPinned(skillName: "important", pinned: false)
        usage = await store.getUsage(skillName: "important")
        XCTAssertFalse(usage.pinned)
    }

    // MARK: - setProvenance

    func testSetProvenance() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.setProvenance(skillName: "builtin", provenance: .bundled)

        let usage = await store.getUsage(skillName: "builtin")
        XCTAssertEqual(usage.provenance, .bundled)
    }

    // MARK: - setUsage

    func testSetUsageOverwrites() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        let data = SkillUsageData(
            skillName: "custom",
            viewCount: 100,
            pinned: true,
            provenance: .agentCreated
        )
        try await store.setUsage(skillName: "custom", data: data)

        let usage = await store.getUsage(skillName: "custom")
        XCTAssertEqual(usage.viewCount, 100)
        XCTAssertTrue(usage.pinned)
        XCTAssertEqual(usage.provenance, .agentCreated)
    }

    // MARK: - Persistence Across Store Instances

    func testPersistenceAcrossStoreInstances() async throws {
        // Write with first store
        let store1 = SkillUsageStore(skillsDir: tempDir)
        try await store1.bumpView(skillName: "commit")
        try await store1.bumpView(skillName: "commit")
        try await store1.setPinned(skillName: "important", pinned: true)

        // Read with second store (same directory)
        let store2 = SkillUsageStore(skillsDir: tempDir)
        let commitUsage = await store2.getUsage(skillName: "commit")
        XCTAssertEqual(commitUsage.viewCount, 2)

        let importantUsage = await store2.getUsage(skillName: "important")
        XCTAssertTrue(importantUsage.pinned)
    }

    // MARK: - Atomic File Writes

    func testAtomicFileWritesProducesValidJSON() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.bumpView(skillName: "test-skill")

        // Verify the file exists and is valid JSON
        let filePath = (tempDir as NSString).appendingPathComponent(".usage.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [String: Any])
    }

    // MARK: - allUsage

    func testAllUsageReturnsAllTrackedSkills() async throws {
        let store = SkillUsageStore(skillsDir: tempDir)
        try await store.bumpView(skillName: "a")
        try await store.bumpView(skillName: "b")
        try await store.bumpView(skillName: "c")

        let all = await store.allUsage()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all["a"]?.viewCount, 1)
        XCTAssertEqual(all["b"]?.viewCount, 1)
        XCTAssertEqual(all["c"]?.viewCount, 1)
    }
}
