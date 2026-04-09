import Foundation
import OpenAgentSDK

// MARK: - LLM-Driven Specialist Tools E2E Tests (Cron, Plan, Config)

struct SpecialistToolsE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("52. LLM-Driven CronCreate Tool")
        await testLLMDrivenCronCreate(apiKey: apiKey, model: model, baseURL: baseURL)

        section("53. LLM-Driven CronList Tool")
        await testLLMDrivenCronList(apiKey: apiKey, model: model, baseURL: baseURL)

        section("54. LLM-Driven CronDelete Tool")
        await testLLMDrivenCronDelete(apiKey: apiKey, model: model, baseURL: baseURL)

        section("55. LLM-Driven EnterPlanMode Tool")
        await testLLMDrivenEnterPlanMode(apiKey: apiKey, model: model, baseURL: baseURL)

        section("56. LLM-Driven ExitPlanMode Tool")
        await testLLMDrivenExitPlanMode(apiKey: apiKey, model: model, baseURL: baseURL)

        section("57. LLM-Driven Config Tool")
        await testLLMDrivenConfigTool(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 52 - CronCreate

    static func testLLMDrivenCronCreate(apiKey: String, model: String, baseURL: String) async {
        let cronStore = CronStore()
        let createTool = createCronCreateTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [createTool],
            cronStore: cronStore
        ))

        let result = await agent.prompt(
            "Use the CronCreate tool to create a cron job named \"health-check\" with schedule \"*/5 * * * *\" and command \"curl -s http://localhost:8080/health\"."
        )

        if result.status == .success {
            pass("LLM+CronCreate: agent returns success")
        } else {
            fail("LLM+CronCreate: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("LLM+CronCreate: agent uses multiple turns")
        } else {
            fail("LLM+CronCreate: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        let jobs = await cronStore.list()
        if jobs.count >= 1 {
            pass("LLM+CronCreate: cron job was created in store")
        } else {
            fail("LLM+CronCreate: cron job was created in store", "count=\(jobs.count)")
        }

        let jobName = jobs.first?.name.lowercased() ?? ""
        if jobName.contains("health") {
            pass("LLM+CronCreate: job name contains expected text")
        } else {
            fail("LLM+CronCreate: job name contains expected text", "name: \(jobs.first?.name ?? "nil")")
        }
    }

    // MARK: Test 53 - CronList

    static func testLLMDrivenCronList(apiKey: String, model: String, baseURL: String) async {
        let cronStore = CronStore()
        _ = await cronStore.create(name: "backup-job", schedule: "0 2 * * *", command: "backup.sh")

        let listTool = createCronListTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            tools: [listTool],
            cronStore: cronStore
        ))

        let result = await agent.prompt(
            "Use the CronList tool to list all cron jobs."
        )

        if result.status == .success {
            pass("LLM+CronList: agent returns success")
        } else {
            fail("LLM+CronList: agent returns success", "got \(result.status)")
        }

        let lower = result.text.lowercased()
        if lower.contains("backup") {
            pass("LLM+CronList: response mentions existing cron job")
        } else {
            fail("LLM+CronList: response mentions existing cron job", "text: \(result.text.prefix(200))")
        }
    }

    // MARK: Test 54 - CronDelete

    static func testLLMDrivenCronDelete(apiKey: String, model: String, baseURL: String) async {
        let cronStore = CronStore()
        let job = await cronStore.create(name: "temp-job", schedule: "0 * * * *", command: "echo temp")

        let deleteTool = createCronDeleteTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [deleteTool],
            cronStore: cronStore
        ))

        let result = await agent.prompt(
            "Use the CronDelete tool to delete cron job with id \(job.id)."
        )

        if result.status == .success {
            pass("LLM+CronDelete: agent returns success")
        } else {
            fail("LLM+CronDelete: agent returns success", "got \(result.status)")
        }

        let deleted = await cronStore.get(id: job.id)
        if deleted == nil {
            pass("LLM+CronDelete: job was deleted from store")
        } else {
            fail("LLM+CronDelete: job was deleted from store")
        }
    }

    // MARK: Test 55 - EnterPlanMode

    static func testLLMDrivenEnterPlanMode(apiKey: String, model: String, baseURL: String) async {
        let planStore = PlanStore()
        let enterTool = createEnterPlanModeTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [enterTool],
            planStore: planStore
        ))

        let result = await agent.prompt(
            "Use the EnterPlanMode tool to enter plan mode."
        )

        if result.status == .success {
            pass("LLM+EnterPlanMode: agent returns success")
        } else {
            fail("LLM+EnterPlanMode: agent returns success", "got \(result.status)")
        }

        let active = await planStore.isActive()
        if active {
            pass("LLM+EnterPlanMode: plan store is now active")
        } else {
            fail("LLM+EnterPlanMode: plan store is now active")
        }
    }

    // MARK: Test 56 - ExitPlanMode

    static func testLLMDrivenExitPlanMode(apiKey: String, model: String, baseURL: String) async {
        let planStore = PlanStore()
        _ = try? await planStore.enterPlanMode()

        let exitTool = createExitPlanModeTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [exitTool],
            planStore: planStore
        ))

        let result = await agent.prompt(
            "Use the ExitPlanMode tool to exit plan mode with the plan \"Implement feature X with tests\" and approved set to true."
        )

        if result.status == .success {
            pass("LLM+ExitPlanMode: agent returns success")
        } else {
            fail("LLM+ExitPlanMode: agent returns success", "got \(result.status)")
        }

        let active = await planStore.isActive()
        if !active {
            pass("LLM+ExitPlanMode: plan store is no longer active")
        } else {
            fail("LLM+ExitPlanMode: plan store is no longer active")
        }

        let plans = await planStore.list()
        if plans.count >= 1 {
            pass("LLM+ExitPlanMode: completed plan recorded in store")
        } else {
            fail("LLM+ExitPlanMode: completed plan recorded in store", "count=\(plans.count)")
        }
    }

    // MARK: Test 57 - Config Tool

    static func testLLMDrivenConfigTool(apiKey: String, model: String, baseURL: String) async {
        let configTool = createConfigTool()

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [configTool]
        ))

        // First: set a config value
        let setResult = await agent.prompt(
            "Use the Config tool with action \"set\" to set key \"theme\" to value \"dark\"."
        )

        if setResult.status == .success {
            pass("LLM+Config set: agent returns success")
        } else {
            fail("LLM+Config set: agent returns success", "got \(setResult.status)")
        }

        let setLower = setResult.text.lowercased()
        if setLower.contains("theme") || setLower.contains("config") {
            pass("LLM+Config set: response mentions config operation")
        } else {
            fail("LLM+Config set: response mentions config operation", "text: \(setResult.text.prefix(200))")
        }

        // Second: get the config value back
        let agent2 = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            tools: [configTool]
        ))

        let getResult = await agent2.prompt(
            "Use the Config tool with action \"get\" to get the value for key \"theme\"."
        )

        if getResult.status == .success {
            pass("LLM+Config get: agent returns success")
        } else {
            fail("LLM+Config get: agent returns success", "got \(getResult.status)")
        }

        let getLower = getResult.text.lowercased()
        if getLower.contains("dark") {
            pass("LLM+Config get: response contains stored value")
        } else {
            fail("LLM+Config get: response contains stored value", "text: \(getResult.text.prefix(200))")
        }
    }
}
