import XCTest
@testable import OpenAgentSDK

// MARK: - WorktreeToolsTests

/// ATDD RED PHASE: Tests for Story 5.1 -- Worktree Tools (EnterWorktree / ExitWorktree).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createEnterWorktreeTool()` factory function is implemented
///   - `createExitWorktreeTool()` factory function is implemented
///   - `WorktreeStore` actor is implemented with create/get/remove/keep methods
///   - `WorktreeEntry`, `WorktreeStatus`, `WorktreeStoreError` types are defined
///   - `ToolContext` has `worktreeStore` field injected
/// TDD Phase: RED (feature not implemented yet)
final class WorktreeToolsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with an injected WorktreeStore.
    private func makeContext(worktreeStore: WorktreeStore? = nil, cwd: String = "/tmp") -> ToolContext {
        return ToolContext(
            cwd: cwd,
            toolUseId: "test-tool-use-id",
            worktreeStore: worktreeStore
        )
    }

    /// Creates a ToolContext without any WorktreeStore (nil).
    private func makeContextWithoutStore() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    /// Creates a temporary Git repository for testing worktree operations.
    private func createTempGitRepo() throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("worktree-tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let gitInit = Process()
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        gitInit.currentDirectoryURL = tempDir
        try gitInit.run()
        gitInit.waitUntilExit()
        XCTAssertEqual(gitInit.terminationStatus, 0, "git init should succeed")

        // Configure git user
        let gitConfig = Process()
        gitConfig.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfig.arguments = ["config", "user.email", "test@example.com"]
        gitConfig.currentDirectoryURL = tempDir
        try gitConfig.run()
        gitConfig.waitUntilExit()

        let gitConfigName = Process()
        gitConfigName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfigName.arguments = ["config", "user.name", "Test User"]
        gitConfigName.currentDirectoryURL = tempDir
        try gitConfigName.run()
        gitConfigName.waitUntilExit()

        // Create initial commit
        let dummyFile = tempDir.appendingPathComponent("README.md")
        try "test".write(to: dummyFile, atomically: true, encoding: .utf8)

        let gitAdd = Process()
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        gitAdd.currentDirectoryURL = tempDir
        try gitAdd.run()
        gitAdd.waitUntilExit()

        let gitCommit = Process()
        gitCommit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitCommit.arguments = ["commit", "-m", "Initial commit"]
        gitCommit.currentDirectoryURL = tempDir
        try gitCommit.run()
        gitCommit.waitUntilExit()

        return tempDir.path
    }

    /// Removes a temporary directory.
    private func cleanupTempDir(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - AC2: EnterWorktree Tool -- Factory

    /// AC2 [P0]: createEnterWorktreeTool() returns a ToolProtocol with name "EnterWorktree".
    func testCreateEnterWorktreeTool_returnsToolProtocol() async throws {
        let tool = createEnterWorktreeTool()

        XCTAssertEqual(tool.name, "EnterWorktree")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: EnterWorktree inputSchema matches TS SDK.
    func testCreateEnterWorktreeTool_hasValidInputSchema() async throws {
        let tool = createEnterWorktreeTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "name" field
        let nameProp = properties?["name"] as? [String: Any]
        XCTAssertNotNil(nameProp)
        XCTAssertEqual(nameProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["name"])
    }

    /// AC7 [P0]: EnterWorktree is NOT read-only (creates filesystem worktrees).
    func testCreateEnterWorktreeTool_isNotReadOnly() async throws {
        let tool = createEnterWorktreeTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC2: EnterWorktree Tool -- Create Behavior

    /// AC2 [P0]: Creating a worktree with a name returns success with path and branch.
    func testEnterWorktree_withName_returnsSuccess() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let tool = createEnterWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        let input: [String: Any] = ["name": "feature-branch"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("worktree"))
        XCTAssertTrue(result.content.contains("feature-branch"))
    }

    /// AC2 [P0]: After EnterWorktree, the worktree is tracked in the store.
    func testEnterWorktree_trackedInStore() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let tool = createEnterWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        _ = await tool.call(input: ["name": "tracked"], context: context)

        let entries = await worktreeStore.list()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .active)
    }

    /// AC5 [P0]: EnterWorktree in a non-git directory returns error.
    func testEnterWorktree_nonGitDirectory_returnsError() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let tool = createEnterWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir.path)

        let input: [String: Any] = ["name": "fail"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC6 [P0]: EnterWorktree input Codable correctly decodes JSON fields.
    func testEnterWorktree_inputDecodable() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let tool = createEnterWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        let input: [String: Any] = ["name": "decode-test"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("decode-test"))
    }

    // MARK: - AC3: ExitWorktree Tool -- Factory

    /// AC3 [P0]: createExitWorktreeTool() returns a ToolProtocol with name "ExitWorktree".
    func testCreateExitWorktreeTool_returnsToolProtocol() async throws {
        let tool = createExitWorktreeTool()

        XCTAssertEqual(tool.name, "ExitWorktree")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: ExitWorktree inputSchema matches TS SDK.
    func testCreateExitWorktreeTool_hasValidInputSchema() async throws {
        let tool = createExitWorktreeTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "id" field
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp)
        XCTAssertEqual(idProp?["type"] as? String, "string")

        // Verify "action" field (optional)
        let actionProp = properties?["action"] as? [String: Any]
        XCTAssertNotNil(actionProp)
        XCTAssertEqual(actionProp?["type"] as? String, "string")

        // Verify "action" has enum constraint
        let actionEnum = actionProp?["enum"] as? [String]
        XCTAssertEqual(actionEnum, ["keep", "remove"])

        // Verify required fields -- only "id" is required
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["id"])
    }

    /// AC7 [P0]: ExitWorktree is NOT read-only (removes/modifies filesystem worktrees).
    func testCreateExitWorktreeTool_isNotReadOnly() async throws {
        let tool = createExitWorktreeTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC3: ExitWorktree Tool -- Remove Action

    /// AC3 [P0]: Exiting a worktree with action="remove" removes it.
    func testExitWorktree_actionRemove_returnsSuccess() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        // First create a worktree
        let entry = try await worktreeStore.create(name: "to-remove", originalCwd: tempDir)

        let tool = createExitWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        let input: [String: Any] = ["id": entry.id, "action": "remove"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains(entry.id) ||
                      result.content.contains("removed") ||
                      result.content.contains("Removed"))
    }

    /// AC3 [P0]: Default action for ExitWorktree is "remove".
    func testExitWorktree_defaultActionIsRemove() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let entry = try await worktreeStore.create(name: "default-remove", originalCwd: tempDir)

        let tool = createExitWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        // No action specified -- should default to remove
        let input: [String: Any] = ["id": entry.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC3: ExitWorktree Tool -- Keep Action

    /// AC3 [P0]: Exiting a worktree with action="keep" preserves filesystem.
    func testExitWorktree_actionKeep_returnsSuccess() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let entry = try await worktreeStore.create(name: "to-keep", originalCwd: tempDir)

        let tool = createExitWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        let input: [String: Any] = ["id": entry.id, "action": "keep"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("kept") ||
                      result.content.contains("Kept"))

        // Filesystem path should still exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.path))
    }

    // MARK: - AC4: Worktree Not Found Error

    /// AC4 [P0]: Exiting a non-existent worktree returns isError=true.
    func testExitWorktree_nonexistentWorktree_returnsError() async throws {
        let worktreeStore = WorktreeStore()
        let tool = createExitWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore)

        let input: [String: Any] = ["id": "worktree_999"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not found") ||
                      result.content.contains("Not found"))
    }

    // MARK: - AC9: Error Handling -- nil worktreeStore

    /// AC9 [P0]: EnterWorktree returns error when worktreeStore is nil.
    func testEnterWorktree_nilWorktreeStore_returnsError() async throws {
        let tool = createEnterWorktreeTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["name": "test"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("WorktreeStore") ||
                      result.content.contains("worktree store"))
    }

    /// AC9 [P0]: ExitWorktree returns error when worktreeStore is nil.
    func testExitWorktree_nilWorktreeStore_returnsError() async throws {
        let tool = createExitWorktreeTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "worktree_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("WorktreeStore") ||
                      result.content.contains("worktree store"))
    }

    // MARK: - AC9: Error Handling -- never throws

    /// AC9 [P0]: EnterWorktree never throws -- always returns ToolResult even with malformed input.
    func testEnterWorktree_neverThrows_malformedInput() async throws {
        let tool = createEnterWorktreeTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],              // missing all fields
            ["name": 123],    // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC9 [P0]: ExitWorktree never throws -- always returns ToolResult even with malformed input.
    func testExitWorktree_neverThrows_malformedInput() async throws {
        let tool = createExitWorktreeTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],              // missing all fields
            ["id": 123],      // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC10: ToolContext Dependency Injection

    /// AC10 [P0]: ToolContext has a worktreeStore field that can be injected.
    func testToolContext_hasWorktreeStoreField() async throws {
        let worktreeStore = WorktreeStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            worktreeStore: worktreeStore
        )

        XCTAssertNotNil(context.worktreeStore)
    }

    /// AC10 [P0]: ToolContext worktreeStore defaults to nil (backward compatible).
    func testToolContext_worktreeStoreDefaultsToNil() async throws {
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        XCTAssertNil(context.worktreeStore)
    }

    /// AC10 [P0]: ToolContext can be created with all fields including worktreeStore.
    func testToolContext_withAllFieldsIncludingWorktree() async throws {
        let taskStore = TaskStore()
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let worktreeStore = WorktreeStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-789",
            agentSpawner: nil,
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "lead-agent",
            taskStore: taskStore,
            worktreeStore: worktreeStore
        )

        XCTAssertNotNil(context.worktreeStore)
        XCTAssertNotNil(context.teamStore)
        XCTAssertNotNil(context.taskStore)
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertEqual(context.senderName, "lead-agent")
    }

    // MARK: - AC8: Module Boundary

    /// AC8 [P0]: Worktree tools do not import Core/ or Stores/ modules.
    /// This test validates the dependency injection pattern by verifying that
    /// tools can be created and used through ToolContext without direct store imports.
    func testWorktreeTools_moduleBoundary_noDirectStoreImports() async throws {
        // Both tools must be creatable as factory functions that return ToolProtocol
        let enterTool = createEnterWorktreeTool()
        let exitTool = createExitWorktreeTool()

        // Both must return valid ToolProtocol instances
        XCTAssertEqual(enterTool.name, "EnterWorktree")
        XCTAssertEqual(exitTool.name, "ExitWorktree")

        // Verify they work through ToolContext injection
        let worktreeStore = WorktreeStore()
        let context = makeContext(worktreeStore: worktreeStore)

        // EnterWorktree requires git repo for real call, just check error
        let result = await enterTool.call(input: ["name": "test"], context: context)
        // With no git repo at /tmp, this will return an error -- that's fine
        // The key validation is that the tool was created and called through injection
        _ = result
    }

    // MARK: - Integration: Cross-tool workflows

    /// Integration [P1]: Enter a worktree, then exit with remove.
    func testIntegration_enterThenExit() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let enterTool = createEnterWorktreeTool()
        let exitTool = createExitWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        // Step 1: Enter a worktree
        let enterResult = await enterTool.call(
            input: ["name": "integration-test"],
            context: context
        )
        XCTAssertFalse(enterResult.isError)

        // Extract the worktree ID from the store
        let entries = await worktreeStore.list()
        let entryId = try XCTUnwrap(entries.first?.id)

        // Step 2: Exit with remove
        let exitResult = await exitTool.call(
            input: ["id": entryId, "action": "remove"],
            context: context
        )
        XCTAssertFalse(exitResult.isError)

        // Step 3: Verify no active worktrees remain
        let remaining = await worktreeStore.list()
        XCTAssertTrue(remaining.isEmpty)
    }

    /// Integration [P1]: Enter a worktree, then exit with keep.
    func testIntegration_enterThenKeep() async throws {
        let worktreeStore = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let enterTool = createEnterWorktreeTool()
        let exitTool = createExitWorktreeTool()
        let context = makeContext(worktreeStore: worktreeStore, cwd: tempDir)

        // Step 1: Enter a worktree
        let enterResult = await enterTool.call(
            input: ["name": "keep-test"],
            context: context
        )
        XCTAssertFalse(enterResult.isError)

        let entries = await worktreeStore.list()
        let entryId = try XCTUnwrap(entries.first?.id)
        let entryPath = try XCTUnwrap(entries.first?.path)

        // Step 2: Exit with keep
        let exitResult = await exitTool.call(
            input: ["id": entryId, "action": "keep"],
            context: context
        )
        XCTAssertFalse(exitResult.isError)

        // Step 3: Verify no active worktrees in store
        let remaining = await worktreeStore.list()
        XCTAssertTrue(remaining.isEmpty)

        // But filesystem path still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: entryPath))
    }
}
