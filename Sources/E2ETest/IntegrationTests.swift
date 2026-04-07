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

        section("31. Agent with TodoStore Integration")
        await testAgentWithTodoStore(apiKey: apiKey, model: model, baseURL: baseURL)

        section("32. LLM-Driven TodoWrite Tool Invocation")
        await testLLMDrivenTodoWriteTool(apiKey: apiKey, model: model, baseURL: baseURL)

        section("33. TodoWrite Tool Direct Handler Tests")
        await testTodoWriteToolDirectHandler()
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

    // MARK: Test 31

    static func testAgentWithTodoStore(apiKey: String, model: String, baseURL: String) async {
        let todoStore = TodoStore()

        _ = await todoStore.add(text: "Review PR", priority: .high)

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1,
            todoStore: todoStore
        ))

        let result = await agent.prompt("Say 'todo store test ok'.")

        if result.status == .success {
            pass("Agent+TodoStore: agent created with todoStore")
        } else {
            fail("Agent+TodoStore: agent created with todoStore", "got \(result.status)")
        }

        let items = await todoStore.list()
        if items.count == 1 && items[0].text == "Review PR" && items[0].priority == .high {
            pass("Agent+TodoStore: todo persists after agent run")
        } else {
            fail("Agent+TodoStore: todo persists after agent run", "count=\(items.count)")
        }

        // Verify todo lifecycle works after agent run
        let newItem = await todoStore.add(text: "Post-agent task")
        if newItem.id == 2 && newItem.done == false {
            pass("Agent+TodoStore: add works after agent run")
        } else {
            fail("Agent+TodoStore: add works after agent run", "id=\(newItem.id) done=\(newItem.done)")
        }

        do {
            let toggled = try await todoStore.toggle(id: 1)
            if toggled.done == true {
                pass("Agent+TodoStore: toggle works after agent run")
            } else {
                fail("Agent+TodoStore: toggle works after agent run", "done=\(toggled.done)")
            }
        } catch {
            fail("Agent+TodoStore: toggle works after agent run", "threw: \(error)")
        }

        do {
            let removed = try await todoStore.remove(id: 2)
            if removed.id == 2 {
                pass("Agent+TodoStore: remove works after agent run")
            } else {
                fail("Agent+TodoStore: remove works after agent run")
            }
        } catch {
            fail("Agent+TodoStore: remove works after agent run", "threw: \(error)")
        }

        await todoStore.clear()
        let afterClear = await todoStore.list()
        if afterClear.isEmpty {
            pass("Agent+TodoStore: clear works after agent run")
        } else {
            fail("Agent+TodoStore: clear works after agent run", "count=\(afterClear.count)")
        }
    }

    // MARK: Test 32

    static func testLLMDrivenTodoWriteTool(apiKey: String, model: String, baseURL: String) async {
        let todoStore = TodoStore()

        // Pre-populate a todo so the agent can list and toggle it
        _ = await todoStore.add(text: "Review PR", priority: .high)

        let todoTool = createTodoWriteTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 5,
            tools: [todoTool],
            todoStore: todoStore
        ))

        // Ask LLM to use the TodoWrite tool to add a new item
        let result = await agent.prompt(
            "Use the TodoWrite tool to add a new todo with text 'Deploy to staging' and priority high. " +
            "Then list all todos."
        )

        if result.status == .success {
            pass("LLM+TodoWrite: agent returns success")
        } else {
            fail("LLM+TodoWrite: agent returns success", "got \(result.status)")
        }

        // The LLM should have used at least 2 turns (tool call + response)
        if result.numTurns >= 2 {
            pass("LLM+TodoWrite: agent uses multiple turns")
        } else {
            fail("LLM+TodoWrite: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        // Verify the store now has at least the pre-existing + new item
        let items = await todoStore.list()
        if items.count >= 2 {
            pass("LLM+TodoWrite: store has items after LLM tool call")
        } else {
            fail("LLM+TodoWrite: store has items after LLM tool call", "count=\(items.count)")
        }

        // Verify the new item exists (LLM added "Deploy to staging")
        let deployItem = items.first(where: { $0.text.lowercased().contains("deploy") })
        if deployItem != nil {
            pass("LLM+TodoWrite: LLM-added item found in store")
        } else {
            fail("LLM+TodoWrite: LLM-added item found in store", "items: \(items.map { $0.text })")
        }

        // Verify the pre-existing item is still there
        let reviewItem = items.first(where: { $0.text == "Review PR" })
        if reviewItem != nil && reviewItem?.priority == .high {
            pass("LLM+TodoWrite: pre-existing item preserved")
        } else {
            fail("LLM+TodoWrite: pre-existing item preserved")
        }
    }

    // MARK: Test 33

    static func testTodoWriteToolDirectHandler() async {
        let todoStore = TodoStore()
        let context = ToolContext(cwd: "/tmp", todoStore: todoStore)

        let tool = createTodoWriteTool()

        // Test: tool metadata
        if tool.name == "TodoWrite" {
            pass("TodoWrite direct: tool name is TodoWrite")
        } else {
            fail("TodoWrite direct: tool name is TodoWrite", "got \(tool.name)")
        }
        if !tool.isReadOnly {
            pass("TodoWrite direct: isReadOnly returns false")
        } else {
            fail("TodoWrite direct: isReadOnly returns false")
        }

        // Test: add without store → error
        let nilContext = ToolContext(cwd: "/tmp", todoStore: nil)
        let addNoStore = await tool.call(input: ["action": "add", "text": "test"] as [String: Any], context: nilContext)
        if addNoStore.isError == true {
            pass("TodoWrite direct: add without store returns error")
        } else {
            fail("TodoWrite direct: add without store returns error")
        }

        // Test: add with text and priority
        let addResult = await tool.call(input: ["action": "add", "text": "Write tests", "priority": "high"] as [String: Any], context: context)
        if addResult.isError == false && addResult.content.contains("#1") {
            pass("TodoWrite direct: add returns item id")
        } else {
            fail("TodoWrite direct: add returns item id", "content=\(addResult.content)")
        }

        // Test: add without text → error
        let addNoText = await tool.call(input: ["action": "add"] as [String: Any], context: context)
        if addNoText.isError == true {
            pass("TodoWrite direct: add without text returns error")
        } else {
            fail("TodoWrite direct: add without text returns error")
        }

        // Test: add second item (no priority)
        _ = await tool.call(input: ["action": "add", "text": "Second task"] as [String: Any], context: context)

        // Test: list shows both items with priority
        let listResult = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        if listResult.isError == false && listResult.content.contains("#1") && listResult.content.contains("#2") {
            pass("TodoWrite direct: list returns all items")
        } else {
            fail("TodoWrite direct: list returns all items", "content=\(listResult.content)")
        }
        if listResult.content.contains("high") {
            pass("TodoWrite direct: list shows priority")
        } else {
            fail("TodoWrite direct: list shows priority", "content=\(listResult.content)")
        }

        // Test: toggle marks completed
        let toggleResult = await tool.call(input: ["action": "toggle", "id": 1] as [String: Any], context: context)
        if toggleResult.isError == false && toggleResult.content.contains("completed") {
            pass("TodoWrite direct: toggle marks completed")
        } else {
            fail("TodoWrite direct: toggle marks completed", "content=\(toggleResult.content)")
        }

        // Test: toggle reopens
        let toggleBack = await tool.call(input: ["action": "toggle", "id": 1] as [String: Any], context: context)
        if toggleBack.isError == false && toggleBack.content.contains("reopened") {
            pass("TodoWrite direct: toggle reopens item")
        } else {
            fail("TodoWrite direct: toggle reopens item", "content=\(toggleBack.content)")
        }

        // Test: toggle without id → error
        let toggleNoId = await tool.call(input: ["action": "toggle"] as [String: Any], context: context)
        if toggleNoId.isError == true {
            pass("TodoWrite direct: toggle without id returns error")
        } else {
            fail("TodoWrite direct: toggle without id returns error")
        }

        // Test: toggle nonexistent → error
        let toggleNotFound = await tool.call(input: ["action": "toggle", "id": 999] as [String: Any], context: context)
        if toggleNotFound.isError == true {
            pass("TodoWrite direct: toggle nonexistent returns error")
        } else {
            fail("TodoWrite direct: toggle nonexistent returns error")
        }

        // Test: remove
        let removeResult = await tool.call(input: ["action": "remove", "id": 2] as [String: Any], context: context)
        if removeResult.isError == false && removeResult.content.contains("removed") {
            pass("TodoWrite direct: remove deletes item")
        } else {
            fail("TodoWrite direct: remove deletes item", "content=\(removeResult.content)")
        }

        // Test: remove without id → error
        let removeNoId = await tool.call(input: ["action": "remove"] as [String: Any], context: context)
        if removeNoId.isError == true {
            pass("TodoWrite direct: remove without id returns error")
        } else {
            fail("TodoWrite direct: remove without id returns error")
        }

        // Test: remove nonexistent → error
        let removeNotFound = await tool.call(input: ["action": "remove", "id": 999] as [String: Any], context: context)
        if removeNotFound.isError == true {
            pass("TodoWrite direct: remove nonexistent returns error")
        } else {
            fail("TodoWrite direct: remove nonexistent returns error")
        }

        // Test: clear
        let clearResult = await tool.call(input: ["action": "clear"] as [String: Any], context: context)
        if clearResult.isError == false && clearResult.content.contains("cleared") {
            pass("TodoWrite direct: clear removes all")
        } else {
            fail("TodoWrite direct: clear removes all", "content=\(clearResult.content)")
        }

        // Test: list after clear shows empty
        let listAfterClear = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        if listAfterClear.isError == false && listAfterClear.content.contains("No todos") {
            pass("TodoWrite direct: list after clear shows empty")
        } else {
            fail("TodoWrite direct: list after clear shows empty", "content=\(listAfterClear.content)")
        }

        // Test: unknown action → error
        let unknownResult = await tool.call(input: ["action": "jump"] as [String: Any], context: context)
        if unknownResult.isError == true && unknownResult.content.contains("Unknown") {
            pass("TodoWrite direct: unknown action returns error")
        } else {
            fail("TodoWrite direct: unknown action returns error", "content=\(unknownResult.content)")
        }

        // Test: add with all priority levels
        _ = await tool.call(input: ["action": "add", "text": "Low task", "priority": "low"] as [String: Any], context: context)
        _ = await tool.call(input: ["action": "add", "text": "Med task", "priority": "medium"] as [String: Any], context: context)
        _ = await tool.call(input: ["action": "add", "text": "High task", "priority": "high"] as [String: Any], context: context)
        let prioList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        if prioList.isError == false && prioList.content.contains("low") && prioList.content.contains("medium") && prioList.content.contains("high") {
            pass("TodoWrite direct: all priority levels displayed in list")
        } else {
            fail("TodoWrite direct: all priority levels displayed in list", "content=\(prioList.content)")
        }

        // Test: list checkbox formatting (toggle one, verify [x] and [ ])
        _ = await tool.call(input: ["action": "toggle", "id": 1] as [String: Any], context: context)
        let checkList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        if checkList.content.contains("[x]") && checkList.content.contains("[ ]") {
            pass("TodoWrite direct: list shows checkbox formatting")
        } else {
            fail("TodoWrite direct: list shows checkbox formatting", "content=\(checkList.content)")
        }
    }
}
