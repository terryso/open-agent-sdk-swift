import Foundation
import OpenAgentSDK

// MARK: - Test 23: Agent with Stores Integration

struct IntegrationTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("23. Agent with TaskStore Integration")
        await testAgentWithTaskStore(apiKey: apiKey, model: model, baseURL: baseURL)

        section("25. Agent with WorktreeStore Integration")
        await testAgentWithWorktreeStore(apiKey: apiKey, model: model, baseURL: baseURL)

        section("27. Agent with PlanStore Integration")
        await testAgentWithPlanStore(apiKey: apiKey, model: model, baseURL: baseURL)

        section("29. Agent with CronStore Integration")
        await testAgentWithCronStore(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    static func testAgentWithTaskStore(apiKey: String, model: String, baseURL: String) async {
        let taskStore = TaskStore()

        let task = await taskStore.create(subject: "Research AI", owner: "lead-agent")

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            agentName: "lead-agent",
            taskStore: taskStore
        ))

        let result = await agent.prompt("Say 'task store test ok'.")

        if result.status == .success {
            pass("Agent+TaskStore: agent created with taskStore")
        } else {
            fail("Agent+TaskStore: agent created with taskStore", "got \(result.status)")
        }

        let retrievedTask = await taskStore.get(id: task.id)
        if retrievedTask != nil && retrievedTask?.subject == "Research AI" {
            pass("Agent+TaskStore: task persists after agent run")
        } else {
            fail("Agent+TaskStore: task persists after agent run")
        }
    }

    // MARK: Test 25

    static func testAgentWithWorktreeStore(apiKey: String, model: String, baseURL: String) async {
        let worktreeStore = WorktreeStore()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            worktreeStore: worktreeStore
        ))

        let result = await agent.prompt("Say 'worktree store test ok'.")

        if result.status == .success {
            pass("Agent+WorktreeStore: agent created with worktreeStore")
        } else {
            fail("Agent+WorktreeStore: agent created with worktreeStore", "got \(result.status)")
        }

        // Verify the store is usable independently after agent run
        let list = await worktreeStore.list()
        if list.isEmpty {
            pass("Agent+WorktreeStore: store is functional and empty after agent run")
        } else {
            fail("Agent+WorktreeStore: store is functional and empty after agent run", "count: \(list.count)")
        }
    }

    // MARK: Test 27

    static func testAgentWithPlanStore(apiKey: String, model: String, baseURL: String) async {
        let planStore = PlanStore()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            planStore: planStore
        ))

        let result = await agent.prompt("Say 'plan store test ok'.")

        if result.status == .success {
            pass("Agent+PlanStore: agent created with planStore")
        } else {
            fail("Agent+PlanStore: agent created with planStore", "got \(result.status)")
        }

        // Verify store is functional after agent run
        let active = await planStore.isActive()
        let list = await planStore.list()
        if !active && list.isEmpty {
            pass("Agent+PlanStore: store is functional and unmodified after agent run")
        } else {
            fail("Agent+PlanStore: store is functional and unmodified after agent run", "active=\(active) count=\(list.count)")
        }

        // Verify plan lifecycle works after agent run
        do {
            let entry = try await planStore.enterPlanMode()
            if entry.status == .active {
                pass("Agent+PlanStore: enterPlanMode works after agent run")
            } else {
                fail("Agent+PlanStore: enterPlanMode works after agent run", "status=\(entry.status)")
            }

            let exited = try await planStore.exitPlanMode(plan: "Test plan", approved: true)
            if exited.status == .completed && exited.approved {
                pass("Agent+PlanStore: exitPlanMode works after agent run")
            } else {
                fail("Agent+PlanStore: exitPlanMode works after agent run", "status=\(exited.status) approved=\(exited.approved)")
            }
        } catch {
            fail("Agent+PlanStore: plan lifecycle works after agent run", "threw: \(error)")
        }
    }

    // MARK: Test 29

    static func testAgentWithCronStore(apiKey: String, model: String, baseURL: String) async {
        let cronStore = CronStore()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            cronStore: cronStore
        ))

        let result = await agent.prompt("Say 'cron store test ok'.")

        if result.status == .success {
            pass("Agent+CronStore: agent created with cronStore")
        } else {
            fail("Agent+CronStore: agent created with cronStore", "got \(result.status)")
        }

        // Verify store is functional after agent run
        let list = await cronStore.list()
        if list.isEmpty {
            pass("Agent+CronStore: store is functional and empty after agent run")
        } else {
            fail("Agent+CronStore: store is functional and empty after agent run", "count: \(list.count)")
        }

        // Verify cron lifecycle works after agent run
        let job = await cronStore.create(name: "Post-agent job", schedule: "0 * * * *", command: "echo hello")
        if job.id == "cron_1" && job.enabled == true {
            pass("Agent+CronStore: create works after agent run")
        } else {
            fail("Agent+CronStore: create works after agent run", "id=\(job.id) enabled=\(job.enabled)")
        }

        do {
            let deleted = try await cronStore.delete(id: job.id)
            if deleted {
                pass("Agent+CronStore: delete works after agent run")
            } else {
                fail("Agent+CronStore: delete works after agent run")
            }
        } catch {
            fail("Agent+CronStore: delete works after agent run", "threw: \(error)")
        }
    }
}
