import Foundation
import OpenAgentSDK

// MARK: - Tests 5-8: Tool Execution

struct ToolExecutionTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("5. Custom Tool Execution (defineTool)")
        await testCustomToolExecution(apiKey: apiKey, model: model, baseURL: baseURL)

        section("6. Multiple Custom Tools")
        await testMultipleCustomTools(apiKey: apiKey, model: model, baseURL: baseURL)

        section("7. Streaming with Tool Calls")
        await testStreamingWithTools(apiKey: apiKey, model: model, baseURL: baseURL)

        section("8. Tool with Structured Result (ToolExecuteResult)")
        await testStructuredToolResult(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 5

    static func testCustomToolExecution(apiKey: String, model: String, baseURL: String) async {
        let calculatorTool = defineTool(
            name: "calculator",
            description: "Evaluates a mathematical expression and returns the result.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "expression": ["type": "string", "description": "The math expression to evaluate"]
                ],
                "required": ["expression"]
            ],
            isReadOnly: true
        ) { (input: CalculatorInput, _: ToolContext) async throws -> String in
            let expr = input.expression.replacingOccurrences(of: " ", with: "")
            let allowed = CharacterSet(charactersIn: "0123456789+-*/().")
            guard expr.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                return "Error: Invalid expression"
            }
            let nsExpr = NSExpression(format: expr)
            if let result = nsExpr.expressionValue(with: nil, context: nil) {
                return "Result: \(result)"
            }
            return "Error: Could not evaluate"
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            tools: [calculatorTool]
        ))

        let result = await agent.prompt("What is 156 * 789? Use the calculator tool to compute this exactly.")

        if result.status == .success {
            pass("Custom tool: agent returns success")
        } else {
            fail("Custom tool: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("Custom tool: agent uses multiple turns (tool call + response)")
        } else {
            fail("Custom tool: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        let digitsOnly = result.text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digitsOnly.contains("123084") {
            pass("Custom tool: correct computation result in response")
        } else {
            fail("Custom tool: correct computation result in response", "text: \(result.text.prefix(200))")
        }
    }

    // MARK: Test 6

    static func testMultipleCustomTools(apiKey: String, model: String, baseURL: String) async {
        let echoTool = defineTool(
            name: "echo",
            description: "Repeats back the message you provide.",
            inputSchema: [
                "type": "object",
                "properties": ["message": ["type": "string"]],
                "required": ["message"]
            ],
            isReadOnly: true
        ) { (input: EchoInput, _: ToolContext) async throws -> String in
            return "Echo: \(input.message)"
        }

        let reverseTool = defineTool(
            name: "reverse",
            description: "Reverses the message string.",
            inputSchema: [
                "type": "object",
                "properties": ["message": ["type": "string"]],
                "required": ["message"]
            ],
            isReadOnly: true
        ) { (input: EchoInput, _: ToolContext) async throws -> String in
            return String(input.message.reversed())
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 5,
            tools: [echoTool, reverseTool]
        ))

        let result = await agent.prompt("Use the echo tool to say 'Hello SDK', then use the reverse tool on the word 'swift'.")

        if result.status == .success {
            pass("Multiple tools: agent returns success")
        } else {
            fail("Multiple tools: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("Multiple tools: agent uses multiple turns for tool calls (numTurns=\(result.numTurns))")
        } else {
            fail("Multiple tools: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }
    }

    // MARK: Test 7

    static func testStreamingWithTools(apiKey: String, model: String, baseURL: String) async {
        let echoTool = defineTool(
            name: "echo",
            description: "Echoes back the given message.",
            inputSchema: [
                "type": "object",
                "properties": ["message": ["type": "string"]],
                "required": ["message"]
            ],
            isReadOnly: true
        ) { (input: EchoInput, _: ToolContext) async throws -> String in
            return "Echo: \(input.message)"
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 5,
            tools: [echoTool]
        ))

        var gotPartial = false
        var gotToolUse = false
        var gotToolResult = false
        var gotAssistant = false
        var gotFinalResult = false

        for await message in agent.stream("Use the echo tool with message 'stream test'") {
            switch message {
            case .partialMessage:
                gotPartial = true
            case .toolUse:
                gotToolUse = true
            case .toolResult:
                gotToolResult = true
            case .assistant:
                gotAssistant = true
            case .result:
                gotFinalResult = true
            case .system:
                break
            case .userMessage, .toolProgress, .hookStarted, .hookProgress, .hookResponse, .taskStarted, .taskProgress, .authStatus, .filesPersisted, .localCommandOutput, .promptSuggestion, .toolUseSummary:
                break
            }
        }

        if gotPartial { pass("Streaming+tools: receives partialMessage events") }
        else { fail("Streaming+tools: receives partialMessage events") }

        if gotToolUse { pass("Streaming+tools: receives toolUse events") }
        else { fail("Streaming+tools: receives toolUse events") }

        if gotToolResult { pass("Streaming+tools: receives toolResult events") }
        else { fail("Streaming+tools: receives toolResult events") }

        if gotAssistant { pass("Streaming+tools: receives assistant events") }
        else { fail("Streaming+tools: receives assistant events") }

        if gotFinalResult { pass("Streaming+tools: receives final result event") }
        else { fail("Streaming+tools: receives final result event") }
    }

    // MARK: Test 8

    static func testStructuredToolResult(apiKey: String, model: String, baseURL: String) async {
        let errorTool = defineTool(
            name: "validate_input",
            description: "Validates the provided input. Returns success or error.",
            inputSchema: [
                "type": "object",
                "properties": ["message": ["type": "string"]],
                "required": ["message"]
            ],
            isReadOnly: true
        ) { (_: EchoInput, _: ToolContext) async throws -> ToolExecuteResult in
            return ToolExecuteResult(content: "Validation failed: empty input", isError: true)
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            tools: [errorTool]
        ))

        let result = await agent.prompt("Use the validate_input tool with message 'test'.")

        if result.status == .success {
            pass("Structured result: agent handles tool error gracefully")
        } else {
            fail("Structured result: agent handles tool error gracefully", "got \(result.status)")
        }
    }
}
