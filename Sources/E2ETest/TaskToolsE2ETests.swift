import Foundation
import OpenAgentSDK

// MARK: - LLM-Driven Task Tools E2E Tests

struct TaskToolsE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("49. LLM-Driven TaskCreate Tool")
        await testLLMDrivenTaskCreate(apiKey: apiKey, model: model, baseURL: baseURL)

        section("50. LLM-Driven TaskList Tool")
        await testLLMDrivenTaskList(apiKey: apiKey, model: model, baseURL: baseURL)

        section("51. LLM-Driven TaskUpdate Tool")
        await testLLMDrivenTaskUpdate(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 49 - TaskCreate

    static func testLLMDrivenTaskCreate(apiKey: String, model: String, baseURL: String) async {
        let taskStore = TaskStore()
        let createTool = createTaskCreateTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [createTool],
            taskStore: taskStore
        ))

        let result = await agent.prompt(
            "Use the TaskCreate tool to create a new task with subject \"Write unit tests\" and description \"Cover all edge cases\"."
        )

        if result.status == .success {
            pass("LLM+TaskCreate: agent returns success")
        } else {
            fail("LLM+TaskCreate: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("LLM+TaskCreate: agent uses multiple turns")
        } else {
            fail("LLM+TaskCreate: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        let tasks = await taskStore.list(status: nil, owner: nil)
        if tasks.count >= 1 {
            pass("LLM+TaskCreate: task was created in store")
        } else {
            fail("LLM+TaskCreate: task was created in store", "count=\(tasks.count)")
        }

        let taskText = tasks.first?.subject.lowercased() ?? ""
        if taskText.contains("test") || taskText.contains("unit") {
            pass("LLM+TaskCreate: task subject contains expected text")
        } else {
            fail("LLM+TaskCreate: task subject contains expected text", "subject: \(tasks.first?.subject ?? "nil")")
        }
    }

    // MARK: Test 50 - TaskList

    static func testLLMDrivenTaskList(apiKey: String, model: String, baseURL: String) async {
        let taskStore = TaskStore()
        _ = await taskStore.create(subject: "Pre-existing task", description: "Created before agent", owner: "e2e-test")

        let listTool = createTaskListTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            tools: [listTool],
            taskStore: taskStore
        ))

        let result = await agent.prompt(
            "Use the TaskList tool to list all current tasks."
        )

        if result.status == .success {
            pass("LLM+TaskList: agent returns success")
        } else {
            fail("LLM+TaskList: agent returns success", "got \(result.status)")
        }

        let lower = result.text.lowercased()
        if lower.contains("pre-existing") || lower.contains("task") {
            pass("LLM+TaskList: response mentions existing task")
        } else {
            fail("LLM+TaskList: response mentions existing task", "text: \(result.text.prefix(200))")
        }
    }

    // MARK: Test 51 - TaskUpdate

    static func testLLMDrivenTaskUpdate(apiKey: String, model: String, baseURL: String) async {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Update this task", description: "Change status", owner: "e2e-test")

        let updateTool = createTaskUpdateTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [updateTool],
            taskStore: taskStore
        ))

        let result = await agent.prompt(
            "Use the TaskUpdate tool to update task \(task.id) with status \"in_progress\"."
        )

        if result.status == .success {
            pass("LLM+TaskUpdate: agent returns success")
        } else {
            fail("LLM+TaskUpdate: agent returns success", "got \(result.status)")
        }

        let updatedTask = await taskStore.get(id: task.id)
        if updatedTask?.status == .inProgress {
            pass("LLM+TaskUpdate: task status was updated to in_progress")
        } else {
            fail("LLM+TaskUpdate: task status was updated to in_progress", "status: \(String(describing: updatedTask?.status))")
        }
    }
}
