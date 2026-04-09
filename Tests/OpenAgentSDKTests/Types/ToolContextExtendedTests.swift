import XCTest
@testable import OpenAgentSDK

/// Extended tests for ToolContext covering withToolUseId and store injection.
final class ToolContextExtendedTests: XCTestCase {

    // MARK: - withToolUseId

    func testWithToolUseId_updatesId() {
        let ctx = ToolContext(cwd: "/tmp", toolUseId: "old-id")
        let updated = ctx.withToolUseId("new-id")

        XCTAssertEqual(updated.toolUseId, "new-id")
        XCTAssertEqual(updated.cwd, "/tmp")
    }

    func testWithToolUseId_preservesCwd() {
        let ctx = ToolContext(cwd: "/home/user/project")
        let updated = ctx.withToolUseId("tu-123")

        XCTAssertEqual(updated.cwd, "/home/user/project")
    }

    func testWithToolUseId_preservesStores() async {
        let mailbox = MailboxStore()
        let teamStore = TeamStore()
        let taskStore = TaskStore()
        let worktreeStore = WorktreeStore()
        let planStore = PlanStore()
        let cronStore = CronStore()
        let todoStore = TodoStore()
        let sessionStore = SessionStore()
        let hookRegistry = HookRegistry()

        let ctx = ToolContext(
            cwd: "/project",
            toolUseId: "old",
            mailboxStore: mailbox,
            teamStore: teamStore,
            taskStore: taskStore,
            worktreeStore: worktreeStore,
            planStore: planStore,
            cronStore: cronStore,
            todoStore: todoStore,
            hookRegistry: hookRegistry
        )

        let updated = ctx.withToolUseId("new")

        XCTAssertEqual(updated.toolUseId, "new")
        XCTAssertNotNil(updated.mailboxStore)
        XCTAssertNotNil(updated.teamStore)
        XCTAssertNotNil(updated.taskStore)
        XCTAssertNotNil(updated.worktreeStore)
        XCTAssertNotNil(updated.planStore)
        XCTAssertNotNil(updated.cronStore)
        XCTAssertNotNil(updated.todoStore)
        XCTAssertNotNil(updated.hookRegistry)
    }

    func testWithToolUseId_preservesSpawner() {
        let spawner = MockContextSpawner(result: SubAgentResult(text: "ok"))
        let ctx = ToolContext(cwd: "/tmp", agentSpawner: spawner)
        let updated = ctx.withToolUseId("new-id")

        XCTAssertNotNil(updated.agentSpawner)
    }

    func testWithToolUseId_preservesSenderName() {
        let ctx = ToolContext(cwd: "/tmp", senderName: "agent-1")
        let updated = ctx.withToolUseId("new-id")

        XCTAssertEqual(updated.senderName, "agent-1")
    }

    func testWithToolUseId_preservesPermissionMode() {
        let ctx = ToolContext(cwd: "/tmp", permissionMode: .auto)
        let updated = ctx.withToolUseId("new-id")

        XCTAssertEqual(updated.permissionMode, .auto)
    }

    // MARK: - Store Injection

    func testToolContext_withAllStores() async {
        let mailbox = MailboxStore()
        let teamStore = TeamStore()
        let taskStore = TaskStore()
        let worktreeStore = WorktreeStore()
        let planStore = PlanStore()
        let cronStore = CronStore()
        let todoStore = TodoStore()

        let ctx = ToolContext(
            cwd: "/root",
            toolUseId: "tu-all",
            mailboxStore: mailbox,
            teamStore: teamStore,
            taskStore: taskStore,
            worktreeStore: worktreeStore,
            planStore: planStore,
            cronStore: cronStore,
            todoStore: todoStore
        )

        // Verify all stores are injected
        XCTAssertNotNil(ctx.mailboxStore)
        XCTAssertNotNil(ctx.teamStore)
        XCTAssertNotNil(ctx.taskStore)
        XCTAssertNotNil(ctx.worktreeStore)
        XCTAssertNotNil(ctx.planStore)
        XCTAssertNotNil(ctx.cronStore)
        XCTAssertNotNil(ctx.todoStore)

        // Verify stores are functional
        _ = await taskStore.create(subject: "Test", description: "Test task")
        let tasks = await taskStore.list()
        XCTAssertEqual(tasks.count, 1)
    }

    // MARK: - HookRegistry Injection

    func testToolContext_withHookRegistry() async {
        let registry = HookRegistry()
        let ctx = ToolContext(cwd: "/tmp", hookRegistry: registry)

        XCTAssertNotNil(ctx.hookRegistry)
    }

    // MARK: - Permission Injection

    func testToolContext_withPermissionMode() {
        let modes: [PermissionMode] = [.default, .auto, .bypassPermissions]
        for mode in modes {
            let ctx = ToolContext(cwd: "/tmp", permissionMode: mode)
            XCTAssertEqual(ctx.permissionMode, mode)
        }
    }

    func testToolContext_withCanUseTool() {
        let callback: CanUseToolFn = { _, _, _ in CanUseToolResult.allow() }
        let ctx = ToolContext(cwd: "/tmp", canUseTool: callback)

        XCTAssertNotNil(ctx.canUseTool)
    }

    // MARK: - Default Values

    func testToolContext_allOptionalsDefaultToNil() {
        let ctx = ToolContext(cwd: "/tmp")

        XCTAssertNil(ctx.agentSpawner)
        XCTAssertNil(ctx.mailboxStore)
        XCTAssertNil(ctx.teamStore)
        XCTAssertNil(ctx.senderName)
        XCTAssertNil(ctx.taskStore)
        XCTAssertNil(ctx.worktreeStore)
        XCTAssertNil(ctx.planStore)
        XCTAssertNil(ctx.cronStore)
        XCTAssertNil(ctx.todoStore)
        XCTAssertNil(ctx.hookRegistry)
        XCTAssertNil(ctx.permissionMode)
        XCTAssertNil(ctx.canUseTool)
    }

    // MARK: - Multiple withToolUseId calls

    func testWithToolUseId_multipleCalls() {
        let ctx = ToolContext(cwd: "/tmp", toolUseId: "id-0")
        let ctx1 = ctx.withToolUseId("id-1")
        let ctx2 = ctx1.withToolUseId("id-2")

        XCTAssertEqual(ctx.toolUseId, "id-0")
        XCTAssertEqual(ctx1.toolUseId, "id-1")
        XCTAssertEqual(ctx2.toolUseId, "id-2")
        // Original is immutable
    }
}

// MARK: - Mock Spawner

private final class MockContextSpawner: SubAgentSpawner {
    let result: SubAgentResult

    init(result: SubAgentResult) {
        self.result = result
    }

    func spawn(prompt: String, model: String?, systemPrompt: String?, allowedTools: [String]?, maxTurns: Int?) async -> SubAgentResult {
        return result
    }
}
