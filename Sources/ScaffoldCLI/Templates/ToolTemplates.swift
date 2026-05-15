import Foundation

extension TemplateGenerator {

    var helloWorldToolContent: String {
        """
        import Foundation
        import OpenAgentSDK

        // MARK: - Hello World Tool
        //
        // This is an example custom tool demonstrating the defineTool() API.
        // It shows:
        //   1. Codable input type definition
        //   2. JSON Schema for the input
        //   3. String return (simple) vs ToolExecuteResult (explicit success/failure)
        //
        // To add more tools:
        //   1. Define a Codable input struct (e.g. MyToolInput)
        //   2. Call defineTool() with name, description, inputSchema, and handler
        //   3. Add the tool to the tools array in main.swift

        // Input type for the hello tool
        struct HelloInput: Codable {
            let name: String
            let language: String?  // "en" or "zh", defaults to "en"
        }

        // Input type for the greeting tool
        struct GreetingInput: Codable {
            let name: String
            let title: String?  // e.g. "Dr.", "Mr."
        }

        // String return — simplest approach
        let helloTool = defineTool(
            name: "hello",
            description: "Say hello to someone. Returns a personalized greeting.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Person's name"],
                    "language": ["type": "string", "description": "Language code: 'en' (default) or 'zh'"]
                ],
                "required": ["name"]
            ],
            isReadOnly: true
        ) { (input: HelloInput, context: ToolContext) -> String in
            let lang = input.language ?? "en"
            if lang == "zh" {
                return "你好，\\(input.name)! 欢迎使用你的 Agent。"
            }
            return "Hello, \\(input.name)! Welcome to your Agent."
        }

        // ToolExecuteResult return — explicit success/failure control
        let greetingTool = defineTool(
            name: "greeting",
            description: "Generate a formal greeting. Demonstrates ToolExecuteResult usage.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Person's name"],
                    "title": ["type": "string", "description": "Person's title (e.g. 'Dr.', 'Mr.')"]
                ],
                "required": ["name"]
            ]
        ) { (input: GreetingInput, context: ToolContext) -> ToolExecuteResult in
            guard !input.name.isEmpty else {
                return ToolExecuteResult(
                    content: "Name cannot be empty",
                    isError: true
                )
            }
            let titlePrefix = input.title.map { "\\($0) " } ?? ""
            let greeting = "Greetings, \\(titlePrefix)\\(input.name)! How can I assist you today?"
            return ToolExecuteResult(content: greeting, isError: false)
        }

        // MARK: - Calculator Tool (Codable Input + ToolExecuteResult)
        //
        // Demonstrates:
        //   1. Codable input with multiple required fields
        //   2. ToolExecuteResult return with error handling
        //   3. inputSchema must match Codable struct field names and types

        struct CalculatorInput: Codable {
            let operation: String  // "add", "subtract", "multiply", "divide"
            let a: Double
            let b: Double
        }

        let calculatorTool = defineTool(
            name: "calculator",
            description: "Perform basic arithmetic: add, subtract, multiply, divide.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "operation": ["type": "string", "description": "Operation: add, subtract, multiply, or divide"],
                    "a": ["type": "number", "description": "First operand"],
                    "b": ["type": "number", "description": "Second operand"]
                ],
                "required": ["operation", "a", "b"]
            ]
        ) { (input: CalculatorInput, context: ToolContext) -> ToolExecuteResult in
            let result: Double
            switch input.operation {
            case "add": result = input.a + input.b
            case "subtract": result = input.a - input.b
            case "multiply": result = input.a * input.b
            case "divide":
                guard input.b != 0 else {
                    return ToolExecuteResult(content: "Error: Division by zero", isError: true)
                }
                result = input.a / input.b
            default:
                return ToolExecuteResult(
                    content: "Unknown operation '\\(input.operation)'. Use: add, subtract, multiply, divide",
                    isError: true
                )
            }
            return ToolExecuteResult(content: "\\(input.a) \\(input.operation) \\(input.b) = \\(result)", isError: false)
        }

        // MARK: - System Info Tool (No-Input convenience)
        //
        // Demonstrates:
        //   1. No-Input defineTool overload — no Codable struct needed
        //   2. ToolContext provides execution context (cwd, toolUseId, etc.)
        //   3. Read-only tool that gathers environment information

        let systemInfoTool = defineTool(
            name: "system_info",
            description: "Get current system and environment information.",
            inputSchema: [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ],
            isReadOnly: true
        ) { (context: ToolContext) -> String in
            let processInfo = ProcessInfo.processInfo
            return "System Information:\\n"
                + "  Host: \\(processInfo.hostName)\\n"
                + "  OS: \\(processInfo.operatingSystemVersionString)\\n"
                + "  CPUs: \\(processInfo.activeProcessorCount)\\n"
                + "  Memory: \\(processInfo.physicalMemory / 1_073_741_824) GB\\n"
                + "  Working Directory: \\(context.cwd)"
        }

        // MARK: - Config Tool (Raw Dictionary Input)
        //
        // Demonstrates:
        //   1. Raw [String: Any] input — no Codable struct
        //   2. Dynamic type handling (value can be String, Int, Bool, etc.)
        //   3. ToolExecuteResult return for explicit error reporting

        let configTool = defineTool(
            name: "get_config",
            description: "Read a configuration value by key.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "key": ["type": "string", "description": "Configuration key to look up"]
                ],
                "required": ["key"]
            ],
            isReadOnly: true
        ) { (input: [String: Any], context: ToolContext) -> ToolExecuteResult in
            guard let key = input["key"] as? String, !key.isEmpty else {
                return ToolExecuteResult(content: "Error: 'key' is required", isError: true)
            }
            // In a real app, look up from UserDefaults, file, or database
            return ToolExecuteResult(content: "Config '\\(key)' = <not implemented>", isError: false)
        }

        /// Create and return all example tools for registration in main.swift.
        func createExampleTools() -> [ToolProtocol] {
            return [helloTool, greetingTool, calculatorTool, systemInfoTool, configTool]
        }
        """
    }

    var envLoaderContent: String {
        """
        import Foundation

        // EnvLoader provides project-level .env file loading.
        //
        // OpenAgentSDK already provides loadDotEnv() and getEnv() as global functions.
        // This file documents how to use them. For advanced configuration,
        // extend this file with your own config loading logic.
        //
        // SDK-provided functions (import OpenAgentSDK):
        //   loadDotEnv() -> [String: String]
        //     Loads .env file from current directory
        //
        //   getEnv(_ key: String, from dotEnv: [String: String]) -> String?
        //     Gets value from environment, falling back to .env dictionary
        //
        // Usage in main.swift:
        //   let dotEnv = loadDotEnv()
        //   let apiKey = getEnv("MY_API_KEY", from: dotEnv) ?? "default-value"
        """
    }
}
