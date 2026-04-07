import Foundation
import OpenAgentSDK

// MARK: - Tests 17-20: Store Operations

struct StoreTests {
    static func run() async {
        section("17. TaskStore Operations")
        await testTaskStoreOperations()

        section("18. TeamStore Operations")
        await testTeamStoreOperations()

        section("19. MailboxStore Operations")
        await testMailboxStoreOperations()

        section("20. AgentRegistry Operations")
        await testAgentRegistryOperations()

        section("24. WorktreeStore Operations")
        await testWorktreeStoreOperations()

        section("26. PlanStore Operations")
        await testPlanStoreOperations()
    }

    // MARK: Test 17

    static func testTaskStoreOperations() async {
        let store = TaskStore()

        let task = await store.create(subject: "Test task", description: "A test", owner: "agent-1")
        if !task.id.isEmpty && task.subject == "Test task" {
            pass("TaskStore: create returns task with id and subject")
        } else {
            fail("TaskStore: create returns task with id and subject")
        }

        let retrieved = await store.get(id: task.id)
        if retrieved?.id == task.id {
            pass("TaskStore: get retrieves created task")
        } else {
            fail("TaskStore: get retrieves created task")
        }

        let list = await store.list()
        if list.count == 1 {
            pass("TaskStore: list returns created tasks")
        } else {
            fail("TaskStore: list returns created tasks", "count: \(list.count)")
        }

        do {
            let updated = try await store.update(id: task.id, status: .inProgress, description: "Updated")
            if updated.status == .inProgress && updated.description == "Updated" {
                pass("TaskStore: update modifies task fields")
            } else {
                fail("TaskStore: update modifies task fields")
            }
        } catch {
            fail("TaskStore: update modifies task fields", "threw: \(error)")
        }

        let pendingList = await store.list(status: .pending)
        let inProgressList = await store.list(status: .inProgress)
        if pendingList.isEmpty && inProgressList.count == 1 {
            pass("TaskStore: list with status filter works")
        } else {
            fail("TaskStore: list with status filter works", "pending: \(pendingList.count), inProgress: \(inProgressList.count)")
        }

        let deleted = await store.delete(id: task.id)
        if deleted {
            pass("TaskStore: delete removes task")
        } else {
            fail("TaskStore: delete removes task")
        }

        let afterDelete = await store.get(id: task.id)
        if afterDelete == nil {
            pass("TaskStore: get returns nil after delete")
        } else {
            fail("TaskStore: get returns nil after delete")
        }

        _ = await store.create(subject: "Task A")
        _ = await store.create(subject: "Task B")
        await store.clear()
        let afterClear = await store.list()
        if afterClear.isEmpty {
            pass("TaskStore: clear removes all tasks")
        } else {
            fail("TaskStore: clear removes all tasks", "count: \(afterClear.count)")
        }
    }

    // MARK: Test 18

    static func testTeamStoreOperations() async {
        let store = TeamStore()

        let team = await store.create(name: "Alpha Team")
        if !team.id.isEmpty && team.name == "Alpha Team" && team.status == .active {
            pass("TeamStore: create returns team with id, name, and active status")
        } else {
            fail("TeamStore: create returns team with id, name, and active status")
        }

        let retrieved = await store.get(id: team.id)
        if retrieved?.id == team.id {
            pass("TeamStore: get retrieves created team")
        } else {
            fail("TeamStore: get retrieves created team")
        }

        let list = await store.list()
        if list.count == 1 {
            pass("TeamStore: list returns teams")
        } else {
            fail("TeamStore: list returns teams", "count: \(list.count)")
        }

        let member = TeamMember(name: "agent-1", role: .member)
        do {
            let _ = try await store.addMember(teamId: team.id, member: member)
            pass("TeamStore: addMember succeeds")
        } catch {
            fail("TeamStore: addMember succeeds", "threw: \(error)")
        }
        let withMember = await store.get(id: team.id)
        if withMember?.members.count == 1 && withMember?.members.first?.name == "agent-1" {
            pass("TeamStore: member added correctly")
        } else {
            fail("TeamStore: member added correctly")
        }

        let teamForAgent = await store.getTeamForAgent(agentName: "agent-1")
        if teamForAgent?.id == team.id {
            pass("TeamStore: getTeamForAgent finds correct team")
        } else {
            fail("TeamStore: getTeamForAgent finds correct team")
        }

        do {
            let _ = try await store.removeMember(teamId: team.id, agentName: "agent-1")
            pass("TeamStore: removeMember succeeds")
        } catch {
            fail("TeamStore: removeMember succeeds", "threw: \(error)")
        }
        let afterRemove = await store.get(id: team.id)
        if afterRemove?.members.isEmpty == true {
            pass("TeamStore: member removed correctly")
        } else {
            fail("TeamStore: member removed correctly")
        }

        do {
            let disbanded = try await store.delete(id: team.id)
            if disbanded {
                pass("TeamStore: delete disbands team")
            } else {
                fail("TeamStore: delete disbands team")
            }
        } catch {
            fail("TeamStore: delete disbands team", "threw: \(error)")
        }

        let disbandedTeam = await store.get(id: team.id)
        if disbandedTeam?.status == .disbanded {
            pass("TeamStore: disbanded team has .disbanded status")
        } else {
            fail("TeamStore: disbanded team has .disbanded status", "status: \(String(describing: disbandedTeam?.status))")
        }

        let activeList = await store.list(status: .active)
        if activeList.isEmpty {
            pass("TeamStore: list(.active) excludes disbanded teams")
        } else {
            fail("TeamStore: list(.active) excludes disbanded teams", "count: \(activeList.count)")
        }

        _ = await store.create(name: "Team B")
        await store.clear()
        let afterClear = await store.list()
        if afterClear.isEmpty {
            pass("TeamStore: clear removes all teams")
        } else {
            fail("TeamStore: clear removes all teams", "count: \(afterClear.count)")
        }
    }

    // MARK: Test 19

    static func testMailboxStoreOperations() async {
        let store = MailboxStore()

        await store.send(from: "agent-1", to: "agent-2", content: "Hello from agent-1")
        let hasMsg = await store.hasMessages(for: "agent-2")
        if hasMsg {
            pass("MailboxStore: send makes hasMessages return true")
        } else {
            fail("MailboxStore: send makes hasMessages return true")
        }

        let messages = await store.read(agentName: "agent-2")
        if messages.count == 1 && messages[0].content == "Hello from agent-1" && messages[0].from == "agent-1" {
            pass("MailboxStore: read returns correct messages")
        } else {
            fail("MailboxStore: read returns correct messages", "count: \(messages.count)")
        }

        let secondRead = await store.read(agentName: "agent-2")
        if secondRead.isEmpty {
            pass("MailboxStore: read clears mailbox")
        } else {
            fail("MailboxStore: read clears mailbox", "count: \(secondRead.count)")
        }

        await store.broadcast(from: "agent-1", content: "Broadcast message")
        let agent2Msgs = await store.read(agentName: "agent-2")
        if agent2Msgs.count == 1 && agent2Msgs[0].content == "Broadcast message" {
            pass("MailboxStore: broadcast delivers to all agents")
        } else {
            fail("MailboxStore: broadcast delivers to all agents")
        }

        await store.send(from: "a", to: "b", content: "msg1")
        await store.send(from: "a", to: "c", content: "msg2")
        await store.clearAll()
        let hasB = await store.hasMessages(for: "b")
        let hasC = await store.hasMessages(for: "c")
        if !hasB && !hasC {
            pass("MailboxStore: clearAll removes all messages")
        } else {
            fail("MailboxStore: clearAll removes all messages")
        }

        await store.send(from: "a", to: "b", content: "text msg", type: .text)
        await store.send(from: "a", to: "b", content: "shutdown", type: .shutdownRequest)
        let typedMsgs = await store.read(agentName: "b")
        if typedMsgs.count == 2 && typedMsgs[0].type == .text && typedMsgs[1].type == .shutdownRequest {
            pass("MailboxStore: message types preserved")
        } else {
            fail("MailboxStore: message types preserved", "count: \(typedMsgs.count)")
        }
    }

    // MARK: Test 20

    static func testAgentRegistryOperations() async {
        let registry = AgentRegistry()

        let entry1 = try? await registry.register(agentId: "agent-1", name: "Worker", agentType: "worker")
        let entry = await registry.getByName(name: "Worker")
        if entry?.agentId == "agent-1" && entry?.name == "Worker" && entry1 != nil {
            pass("AgentRegistry: register and getByName work")
        } else {
            fail("AgentRegistry: register and getByName work")
        }

        let byId = await registry.get(agentId: "agent-1")
        if byId?.name == "Worker" {
            pass("AgentRegistry: get by ID works")
        } else {
            fail("AgentRegistry: get by ID works")
        }

        _ = try? await registry.register(agentId: "agent-2", name: "Manager", agentType: "manager")
        let entries = await registry.list()
        if entries.count == 2 {
            pass("AgentRegistry: list returns registered agents")
        } else {
            fail("AgentRegistry: list returns registered agents", "count: \(entries.count)")
        }

        let workers = await registry.listByType(agentType: "worker")
        if workers.count == 1 && workers[0].name == "Worker" {
            pass("AgentRegistry: listByType filters correctly")
        } else {
            fail("AgentRegistry: listByType filters correctly", "count: \(workers.count)")
        }

        let dup = try? await registry.register(agentId: "agent-3", name: "Worker", agentType: "worker")
        if dup == nil {
            pass("AgentRegistry: duplicate name rejected")
        } else {
            fail("AgentRegistry: duplicate name rejected")
        }

        let removed = await registry.unregister(agentId: "agent-1")
        let afterUnregister = await registry.getByName(name: "Worker")
        if removed && afterUnregister == nil {
            pass("AgentRegistry: unregister removes agent")
        } else {
            fail("AgentRegistry: unregister removes agent")
        }

        await registry.clear()
        let afterClear = await registry.list()
        if afterClear.isEmpty {
            pass("AgentRegistry: clear removes all agents")
        } else {
            fail("AgentRegistry: clear removes all agents")
        }
    }

    // MARK: Test 24

    static func testWorktreeStoreOperations() async {
        let store = WorktreeStore()

        // Create a temp git repo for worktree operations
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "e2e-worktree-store-\(UUID().uuidString)", isDirectory: true
        )
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Initialize git repo with an initial commit (worktrees need at least one commit)
        let gitInit = Process()
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        gitInit.currentDirectoryURL = tmpDir
        try? gitInit.run()
        gitInit.waitUntilExit()

        let gitConfig = Process()
        gitConfig.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfig.arguments = ["config", "user.email", "e2e@test.com"]
        gitConfig.currentDirectoryURL = tmpDir
        try? gitConfig.run()
        gitConfig.waitUntilExit()

        let gitConfigName = Process()
        gitConfigName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfigName.arguments = ["config", "user.name", "E2E Test"]
        gitConfigName.currentDirectoryURL = tmpDir
        try? gitConfigName.run()
        gitConfigName.waitUntilExit()

        let readmePath = tmpDir.appendingPathComponent("README.md")
        try? "test".write(to: readmePath, atomically: true, encoding: .utf8)

        let gitAdd = Process()
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        gitAdd.currentDirectoryURL = tmpDir
        try? gitAdd.run()
        gitAdd.waitUntilExit()

        let gitCommit = Process()
        gitCommit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitCommit.arguments = ["commit", "-m", "Initial commit"]
        gitCommit.currentDirectoryURL = tmpDir
        try? gitCommit.run()
        gitCommit.waitUntilExit()

        let cwd = tmpDir.path

        // Test create
        let entry: WorktreeEntry
        do {
            entry = try await store.create(name: "test-wt", originalCwd: cwd)
            if !entry.id.isEmpty && entry.path.contains("test-wt") && entry.branch == "worktree-test-wt" {
                pass("WorktreeStore: create returns entry with id, path, and branch")
            } else {
                fail("WorktreeStore: create returns entry with id, path, and branch", "id=\(entry.id) path=\(entry.path) branch=\(entry.branch)")
            }
        } catch {
            fail("WorktreeStore: create returns entry with id, path, and branch", "threw: \(error)")
            // Cleanup and return
            try? FileManager.default.removeItem(at: tmpDir)
            return
        }

        // Test get
        let retrieved = await store.get(id: entry.id)
        if retrieved?.id == entry.id && retrieved?.status == .active {
            pass("WorktreeStore: get retrieves created worktree")
        } else {
            fail("WorktreeStore: get retrieves created worktree")
        }

        // Test list
        let list = await store.list()
        if list.count == 1 {
            pass("WorktreeStore: list returns created worktrees")
        } else {
            fail("WorktreeStore: list returns created worktrees", "count: \(list.count)")
        }

        // Test keep (remove tracking only, leave filesystem)
        do {
            let kept = try await store.keep(id: entry.id)
            if kept {
                pass("WorktreeStore: keep removes tracking")
            } else {
                fail("WorktreeStore: keep removes tracking")
            }
        } catch {
            fail("WorktreeStore: keep removes tracking", "threw: \(error)")
        }

        let afterKeep = await store.get(id: entry.id)
        if afterKeep == nil {
            pass("WorktreeStore: get returns nil after keep")
        } else {
            fail("WorktreeStore: get returns nil after keep")
        }

        // Test create + remove (full lifecycle)
        do {
            let entry2 = try await store.create(name: "test-wt2", originalCwd: cwd)
            let removed = try await store.remove(id: entry2.id)
            if removed {
                pass("WorktreeStore: remove deletes worktree and tracking")
            } else {
                fail("WorktreeStore: remove deletes worktree and tracking")
            }
        } catch {
            fail("WorktreeStore: remove deletes worktree and tracking", "threw: \(error)")
        }

        // Test clear
        do {
            _ = try await store.create(name: "test-wt3", originalCwd: cwd)
        } catch {
            fail("WorktreeStore: setup for clear test failed", "threw: \(error)")
        }
        await store.clear()
        let afterClear = await store.list()
        if afterClear.isEmpty {
            pass("WorktreeStore: clear removes all entries")
        } else {
            fail("WorktreeStore: clear removes all entries", "count: \(afterClear.count)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: Test 26

    static func testPlanStoreOperations() async {
        let store = PlanStore()

        // Initially not active
        let initialActive = await store.isActive()
        let initialPlan = await store.getCurrentPlan()
        if !initialActive && initialPlan == nil {
            pass("PlanStore: initially not active and no current plan")
        } else {
            fail("PlanStore: initially not active and no current plan", "active=\(initialActive) plan=\(String(describing: initialPlan))")
        }

        // Enter plan mode
        let entry: PlanEntry
        do {
            entry = try await store.enterPlanMode()
            if entry.id.hasPrefix("plan_") && entry.status == .active && !entry.approved && entry.content == nil {
                pass("PlanStore: enterPlanMode creates active plan entry")
            } else {
                fail("PlanStore: enterPlanMode creates active plan entry", "id=\(entry.id) status=\(entry.status)")
            }
        } catch {
            fail("PlanStore: enterPlanMode creates active plan entry", "threw: \(error)")
            return
        }

        // isActive and getCurrentPlan
        let active = await store.isActive()
        let currentPlan = await store.getCurrentPlan()
        if active && currentPlan?.id == entry.id {
            pass("PlanStore: isActive returns true after enter, getCurrentPlan returns entry")
        } else {
            fail("PlanStore: isActive returns true after enter, getCurrentPlan returns entry")
        }

        // Duplicate enter throws
        do {
            _ = try await store.enterPlanMode()
            fail("PlanStore: duplicate enterPlanMode throws alreadyInPlanMode")
        } catch let error as PlanStoreError {
            if case .alreadyInPlanMode = error {
                pass("PlanStore: duplicate enterPlanMode throws alreadyInPlanMode")
            } else {
                fail("PlanStore: duplicate enterPlanMode throws alreadyInPlanMode", "wrong error: \(error)")
            }
        } catch {
            fail("PlanStore: duplicate enterPlanMode throws alreadyInPlanMode", "threw: \(error)")
        }

        // Exit plan mode with plan content and approved flag
        do {
            let exited = try await store.exitPlanMode(plan: "1. Step A\n2. Step B", approved: true)
            if exited.content == "1. Step A\n2. Step B" && exited.approved && exited.status == .completed {
                pass("PlanStore: exitPlanMode finalizes plan with content and approval")
            } else {
                fail("PlanStore: exitPlanMode finalizes plan with content and approval", "content=\(String(describing: exited.content)) approved=\(exited.approved) status=\(exited.status)")
            }
        } catch {
            fail("PlanStore: exitPlanMode finalizes plan with content and approval", "threw: \(error)")
        }

        // After exit, not active
        let afterExit = await store.isActive()
        let afterExitPlan = await store.getCurrentPlan()
        if !afterExit && afterExitPlan == nil {
            pass("PlanStore: not active after exit")
        } else {
            fail("PlanStore: not active after exit", "active=\(afterExit)")
        }

        // Exit without active plan throws
        do {
            _ = try await store.exitPlanMode(plan: nil, approved: nil)
            fail("PlanStore: exitPlanMode without active plan throws noActivePlan")
        } catch let error as PlanStoreError {
            if case .noActivePlan = error {
                pass("PlanStore: exitPlanMode without active plan throws noActivePlan")
            } else {
                fail("PlanStore: exitPlanMode without active plan throws noActivePlan", "wrong error: \(error)")
            }
        } catch {
            fail("PlanStore: exitPlanMode without active plan throws noActivePlan", "threw: \(error)")
        }

        // List contains the completed plan
        let list = await store.list()
        if list.count == 1 && list[0].status == .completed {
            pass("PlanStore: list returns completed plan")
        } else {
            fail("PlanStore: list returns completed plan", "count: \(list.count)")
        }

        // Get by ID
        let retrieved = await store.get(id: entry.id)
        if retrieved?.id == entry.id && retrieved?.status == .completed {
            pass("PlanStore: get retrieves completed plan by ID")
        } else {
            fail("PlanStore: get retrieves completed plan by ID")
        }

        // Get nonexistent returns nil
        let notFound = await store.get(id: "plan_999")
        if notFound == nil {
            pass("PlanStore: get returns nil for nonexistent ID")
        } else {
            fail("PlanStore: get returns nil for nonexistent ID")
        }

        // Clear
        await store.clear()
        let afterClear = await store.list()
        let activeAfterClear = await store.isActive()
        if afterClear.isEmpty && !activeAfterClear {
            pass("PlanStore: clear resets all state")
        } else {
            fail("PlanStore: clear resets all state", "count: \(afterClear.count) active=\(activeAfterClear)")
        }
    }
}
