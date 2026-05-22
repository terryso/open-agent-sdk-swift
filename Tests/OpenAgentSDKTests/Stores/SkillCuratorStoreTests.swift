import XCTest
@testable import OpenAgentSDK

final class SkillCuratorStoreTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("skill-curator-store-tests-\(UUID().uuidString)")
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

    func testInitialStateReturnsDefault() async {
        let store = SkillCuratorStore(skillsDir: tempDir)
        let state = await store.loadState()
        XCTAssertNil(state.lastRunAt)
        XCTAssertFalse(state.paused)
        XCTAssertEqual(state.runCount, 0)
        XCTAssertNil(state.lastRunDurationMs)
        XCTAssertTrue(state.lastErrors.isEmpty)
    }

    // MARK: - Save and Load Round-Trip

    func testSaveAndLoadRoundTrip() async throws {
        let store = SkillCuratorStore(skillsDir: tempDir)
        let date = Date(timeIntervalSince1970: 1700000000)
        let state = CuratorState(
            lastRunAt: date,
            paused: true,
            runCount: 3,
            lastRunDurationMs: 150,
            lastErrors: ["err"]
        )
        try await store.saveState(state)

        let loaded = await store.loadState()
        XCTAssertEqual(loaded, state)
    }

    // MARK: - Persistence Across Store Instances

    func testPersistenceAcrossStoreInstances() async throws {
        let store1 = SkillCuratorStore(skillsDir: tempDir)
        let state = CuratorState(
            lastRunAt: Date(),
            paused: false,
            runCount: 7,
            lastRunDurationMs: 99,
            lastErrors: []
        )
        try await store1.saveState(state)

        // Create a new store instance pointing to the same directory
        let store2 = SkillCuratorStore(skillsDir: tempDir)
        let loaded = await store2.loadState()
        XCTAssertEqual(loaded.runCount, 7)
        XCTAssertEqual(loaded.lastRunDurationMs, 99)
        XCTAssertFalse(loaded.paused)
    }

    // MARK: - getSkillsDir

    func testGetSkillsDirReturnsConfiguredPath() async {
        let store = SkillCuratorStore(skillsDir: tempDir)
        let dir = await store.getSkillsDir()
        XCTAssertEqual(dir, tempDir)
    }

    // MARK: - Atomic File Writes

    func testAtomicFileWritesProducesValidJSON() async throws {
        let store = SkillCuratorStore(skillsDir: tempDir)
        let state = CuratorState(runCount: 1)
        try await store.saveState(state)

        let filePath = (tempDir as NSString).appendingPathComponent(".curator-state.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [String: Any])
    }

    // MARK: - Load Returns Default When No File

    func testLoadReturnsDefaultWhenNoFileExists() async {
        let emptyDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("curator-empty-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(atPath: emptyDir) }

        let store = SkillCuratorStore(skillsDir: emptyDir)
        let state = await store.loadState()
        XCTAssertEqual(state, CuratorState.defaultState())
    }

    // MARK: - Overwrite State

    func testOverwriteState() async throws {
        let store = SkillCuratorStore(skillsDir: tempDir)

        let first = CuratorState(runCount: 1, lastErrors: ["first"])
        try await store.saveState(first)

        let second = CuratorState(runCount: 2, lastErrors: [])
        try await store.saveState(second)

        let loaded = await store.loadState()
        XCTAssertEqual(loaded.runCount, 2)
        XCTAssertTrue(loaded.lastErrors.isEmpty)
    }
}
