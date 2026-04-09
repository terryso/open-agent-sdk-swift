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

        section("34. LSP Tool Direct Handler Tests")
        await testLSPToolDirectHandler()

        section("35. Config Tool Direct Handler Tests")
        await testConfigToolDirectHandler()

        section("36. RemoteTrigger Tool Direct Handler Tests")
        await testRemoteTriggerToolDirectHandler()
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

        let todoTool = createTodoWriteTool()

        // --- Sub-test A: LLM adds a todo item ---
        let addAgent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [todoTool],
            todoStore: todoStore
        ))

        let addResult = await addAgent.prompt(
            "Use the TodoWrite tool with action \"add\" to create a todo with text \"Deploy to staging\" and priority \"high\"."
        )

        if addResult.status == .success {
            pass("LLM+TodoWrite: add agent returns success")
        } else {
            fail("LLM+TodoWrite: add agent returns success", "got \(addResult.status)")
        }

        // Verify at least one item was added by the LLM
        let items = await todoStore.list()
        if items.count >= 1 {
            pass("LLM+TodoWrite: store has item after LLM add call")
        } else {
            fail("LLM+TodoWrite: store has item after LLM add call", "count=\(items.count)")
        }

        // Verify the item text contains "deploy" (case-insensitive, LLM may rephrase)
        let addedItem = items.first(where: { $0.text.lowercased().contains("deploy") })
        if addedItem != nil {
            pass("LLM+TodoWrite: LLM-added item contains 'deploy'")
        } else {
            fail("LLM+TodoWrite: LLM-added item contains 'deploy'", "items: \(items.map { $0.text })")
        }

        // --- Sub-test B: LLM lists todos ---
        // Pre-add an item to guarantee the list has content
        _ = await todoStore.add(text: "Review PR", priority: .high)

        let listAgent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [todoTool],
            todoStore: todoStore
        ))

        let listResult = await listAgent.prompt(
            "Use the TodoWrite tool with action \"list\" to show all current todos."
        )

        if listResult.status == .success {
            pass("LLM+TodoWrite: list agent returns success")
        } else {
            fail("LLM+TodoWrite: list agent returns success", "got \(listResult.status)")
        }

        if listResult.numTurns >= 2 {
            pass("LLM+TodoWrite: list uses multiple turns (tool call + response)")
        } else {
            fail("LLM+TodoWrite: list uses multiple turns", "numTurns=\(listResult.numTurns)")
        }

        // The response text should mention the pre-existing item
        let respLower = listResult.text.lowercased()
        if respLower.contains("review pr") || respLower.contains("review") {
            pass("LLM+TodoWrite: list response mentions existing todo")
        } else {
            fail("LLM+TodoWrite: list response mentions existing todo", "text: \(listResult.text.prefix(200))")
        }

        // --- Sub-test C: LLM toggles a todo ---
        let itemId = items.first(where: { $0.text.lowercased().contains("deploy") })?.id ?? 1

        let toggleAgent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [todoTool],
            todoStore: todoStore
        ))

        let toggleResult = await toggleAgent.prompt(
            "Use the TodoWrite tool with action \"toggle\" and id \(itemId) to mark that todo as completed."
        )

        if toggleResult.status == .success {
            pass("LLM+TodoWrite: toggle agent returns success")
        } else {
            fail("LLM+TodoWrite: toggle agent returns success", "got \(toggleResult.status)")
        }

        // Verify the item was toggled
        let toggledItem = await todoStore.get(id: itemId)
        if toggledItem?.done == true {
            pass("LLM+TodoWrite: item toggled to done")
        } else {
            fail("LLM+TodoWrite: item toggled to done", "done=\(String(describing: toggledItem?.done))")
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

    // MARK: Test 34

    static func testLSPToolDirectHandler() async {
        let tool = createLSPTool()
        let context = ToolContext(cwd: "/tmp")

        // Test: tool metadata
        if tool.name == "LSP" {
            pass("LSP direct: tool name is LSP")
        } else {
            fail("LSP direct: tool name is LSP", "got \(tool.name)")
        }
        if tool.isReadOnly {
            pass("LSP direct: isReadOnly returns true")
        } else {
            fail("LSP direct: isReadOnly returns true")
        }

        // Test: hover returns hint message
        let hoverResult = await tool.call(input: ["operation": "hover"] as [String: Any], context: context)
        if hoverResult.isError == false && hoverResult.content.lowercased().contains("language server") {
            pass("LSP direct: hover returns language server hint")
        } else {
            fail("LSP direct: hover returns language server hint", "content=\(hoverResult.content)")
        }

        // Test: documentSymbol with temp file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "e2e-lsp-\(UUID().uuidString)", isDirectory: true
        )
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileContent = """
        public struct MyTestStruct {
            func hello() -> String { return "hi" }
        }
        """
        let filePath = tempDir.appendingPathComponent("Test.swift").path
        try? fileContent.write(toFile: filePath, atomically: true, encoding: .utf8)

        let symbolContext = ToolContext(cwd: tempDir.path)
        let symbolResult = await tool.call(
            input: ["operation": "documentSymbol", "file_path": filePath] as [String: Any],
            context: symbolContext
        )
        if symbolResult.isError == false && (symbolResult.content.contains("MyTestStruct") || symbolResult.content.contains("hello")) {
            pass("LSP direct: documentSymbol finds symbols in file")
        } else {
            fail("LSP direct: documentSymbol finds symbols in file", "content=\(symbolResult.content)")
        }

        // Test: workspaceSymbol
        let wsResult = await tool.call(
            input: ["operation": "workspaceSymbol", "query": "MyTestStruct"] as [String: Any],
            context: symbolContext
        )
        if wsResult.isError == false && wsResult.content.contains("MyTestStruct") {
            pass("LSP direct: workspaceSymbol finds matching symbols")
        } else {
            fail("LSP direct: workspaceSymbol finds matching symbols", "content=\(wsResult.content)")
        }

        // Test: unknown operation returns language server hint
        let unknownResult = await tool.call(
            input: ["operation": "prepareCallHierarchy"] as [String: Any],
            context: context
        )
        if unknownResult.isError == false && unknownResult.content.contains("requires a running language server") {
            pass("LSP direct: unknown operation returns language server hint")
        } else {
            fail("LSP direct: unknown operation returns language server hint", "content=\(unknownResult.content)")
        }

        // Test: missing parameters return error
        let missingParams = await tool.call(
            input: ["operation": "documentSymbol"] as [String: Any],
            context: context
        )
        if missingParams.isError == true {
            pass("LSP direct: missing file_path returns error")
        } else {
            fail("LSP direct: missing file_path returns error", "content=\(missingParams.content)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: Test 35

    static func testConfigToolDirectHandler() async {
        let tool = createConfigTool()
        let context = ToolContext(cwd: "/tmp", toolUseId: "e2e-config-test")

        // Test: tool metadata
        if tool.name == "Config" {
            pass("Config direct: tool name is Config")
        } else {
            fail("Config direct: tool name is Config", "got \(tool.name)")
        }
        if !tool.isReadOnly {
            pass("Config direct: isReadOnly returns false")
        } else {
            fail("Config direct: isReadOnly returns false")
        }

        // Test: list initially empty
        let listEmpty = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        if listEmpty.isError == false && listEmpty.content.contains("No config values set") {
            pass("Config direct: list empty returns 'No config values set'")
        } else {
            fail("Config direct: list empty returns 'No config values set'", "content=\(listEmpty.content)")
        }

        // Test: set a value
        let setResult = await tool.call(input: ["action": "set", "key": "theme", "value": "dark"] as [String: Any], context: context)
        if setResult.isError == false && setResult.content.contains("theme") {
            pass("Config direct: set stores value")
        } else {
            fail("Config direct: set stores value", "content=\(setResult.content)")
        }

        // Test: get the value back
        let getResult = await tool.call(input: ["action": "get", "key": "theme"] as [String: Any], context: context)
        if getResult.isError == false && getResult.content.contains("dark") {
            pass("Config direct: get retrieves stored value")
        } else {
            fail("Config direct: get retrieves stored value", "content=\(getResult.content)")
        }

        // Test: list shows the entry
        let listResult = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        if listResult.isError == false && listResult.content.contains("theme") {
            pass("Config direct: list shows stored entry")
        } else {
            fail("Config direct: list shows stored entry", "content=\(listResult.content)")
        }

        // Test: get non-existent key
        let getNotFound = await tool.call(input: ["action": "get", "key": "nonexistent"] as [String: Any], context: context)
        if getNotFound.isError == false && getNotFound.content.contains("not found") {
            pass("Config direct: get non-existent key returns 'not found'")
        } else {
            fail("Config direct: get non-existent key returns 'not found'", "content=\(getNotFound.content)")
        }

        // Test: set without key returns error
        let setNoKey = await tool.call(input: ["action": "set", "value": "x"] as [String: Any], context: context)
        if setNoKey.isError == true {
            pass("Config direct: set without key returns error")
        } else {
            fail("Config direct: set without key returns error", "content=\(setNoKey.content)")
        }

        // Test: get without key returns error
        let getNoKey = await tool.call(input: ["action": "get"] as [String: Any], context: context)
        if getNoKey.isError == true {
            pass("Config direct: get without key returns error")
        } else {
            fail("Config direct: get without key returns error", "content=\(getNoKey.content)")
        }

        // Test: unknown action returns error
        let unknownAction = await tool.call(input: ["action": "delete"] as [String: Any], context: context)
        if unknownAction.isError == true && unknownAction.content.contains("Unknown action") {
            pass("Config direct: unknown action returns error")
        } else {
            fail("Config direct: unknown action returns error", "content=\(unknownAction.content)")
        }
    }

    // MARK: Test 36

    static func testRemoteTriggerToolDirectHandler() async {
        let tool = createRemoteTriggerTool()
        let context = ToolContext(cwd: "/tmp", toolUseId: "e2e-remote-trigger-test")

        // Test: tool metadata
        if tool.name == "RemoteTrigger" {
            pass("RemoteTrigger direct: tool name is RemoteTrigger")
        } else {
            fail("RemoteTrigger direct: tool name is RemoteTrigger", "got \(tool.name)")
        }
        if !tool.isReadOnly {
            pass("RemoteTrigger direct: isReadOnly returns false")
        } else {
            fail("RemoteTrigger direct: isReadOnly returns false")
        }

        // Test: all actions return stub message
        let actions = ["list", "get", "create", "update", "run"]
        for action in actions {
            let input: [String: Any] = ["action": action, "id": "trigger-1"]
            let result = await tool.call(input: input, context: context)
            let expected = "RemoteTrigger \(action)"
            if result.isError == false && result.content.contains(expected) && result.content.contains("remote backend") {
                pass("RemoteTrigger direct: \(action) returns stub message")
            } else {
                fail("RemoteTrigger direct: \(action) returns stub message", "content=\(result.content)")
            }
        }
    }
}
