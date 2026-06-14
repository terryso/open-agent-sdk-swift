// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OpenAgentSDK",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "OpenAgentSDK",
            targets: ["OpenAgentSDK"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/terryso/swift-mcp.git",
            from: "2.0.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "2.0.0"
        ),
    ],
    targets: [
        .target(
            name: "OpenAgentSDK",
            dependencies: [
                .product(name: "MCP", package: "swift-mcp"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Sources/OpenAgentSDK"
        ),
        .testTarget(
            name: "OpenAgentSDKTests",
            dependencies: ["OpenAgentSDK",
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Tests/OpenAgentSDKTests"
        ),
        .executableTarget(
            name: "E2ETest",
            dependencies: ["OpenAgentSDK",
                .product(name: "MCP", package: "swift-mcp"),
            ],
            path: "Sources/E2ETest"
        ),
        .executableTarget(
            name: "BasicAgent",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/BasicAgent"
        ),
        .executableTarget(
            name: "StreamingAgent",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/StreamingAgent"
        ),
        .executableTarget(
            name: "CustomTools",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CustomTools"
        ),
        .executableTarget(
            name: "MCPIntegration",
            dependencies: ["OpenAgentSDK",
                .product(name: "MCP", package: "swift-mcp"),
            ],
            path: "Examples/MCPIntegration"
        ),
        .executableTarget(
            name: "SessionsAndHooks",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SessionsAndHooks"
        ),
        .executableTarget(
            name: "MultiToolExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/MultiToolExample"
        ),
        .executableTarget(
            name: "CustomSystemPromptExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CustomSystemPromptExample"
        ),
        .executableTarget(
            name: "PromptAPIExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/PromptAPIExample"
        ),
        .executableTarget(
            name: "SubagentExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SubagentExample"
        ),
        .executableTarget(
            name: "PermissionsExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/PermissionsExample"
        ),
        .executableTarget(
            name: "AdvancedMCPExample",
            dependencies: ["OpenAgentSDK",
                .product(name: "MCP", package: "swift-mcp"),
            ],
            path: "Examples/AdvancedMCPExample"
        ),
        .executableTarget(
            name: "SkillsExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SkillsExample"
        ),
        .executableTarget(
            name: "SandboxExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SandboxExample"
        ),
        .executableTarget(
            name: "LoggerExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/LoggerExample"
        ),
        .executableTarget(
            name: "ModelSwitchingExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/ModelSwitchingExample"
        ),
        .executableTarget(
            name: "QueryAbortExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/QueryAbortExample"
        ),
        .executableTarget(
            name: "ContextInjectionExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/ContextInjectionExample"
        ),
        .executableTarget(
            name: "MultiTurnExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/MultiTurnExample"
        ),
        .executableTarget(
            name: "OpenAICompatExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/OpenAICompatExample"
        ),
        .executableTarget(
            name: "PolyvLiveExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/PolyvLiveExample"
        ),
        .executableTarget(
            name: "ExecuteSkillExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/ExecuteSkillExample"
        ),
        .executableTarget(
            name: "CompatCoreQuery",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatCoreQuery"
        ),
        .executableTarget(
            name: "CompatToolSystem",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatToolSystem"
        ),
        .executableTarget(
            name: "CompatMessageTypes",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatMessageTypes"
        ),
        .executableTarget(
            name: "CompatHooks",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatHooks"
        ),
        .executableTarget(
            name: "CompatMCP",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatMCP"
        ),
        .executableTarget(
            name: "CompatSessions",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatSessions"
        ),
        .executableTarget(
            name: "CompatQueryMethods",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatQueryMethods"
        ),
        .executableTarget(
            name: "CompatOptions",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatOptions"
        ),
        .executableTarget(
            name: "CompatPermissions",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatPermissions"
        ),
        .executableTarget(
            name: "CompatSubagents",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatSubagents"
        ),
        .executableTarget(
            name: "CompatThinkingModel",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatThinkingModel"
        ),
        .executableTarget(
            name: "CompatSandbox",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CompatSandbox"
        ),
        .executableTarget(
            name: "MemoryStoreExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/MemoryStoreExample"
        ),
        .executableTarget(
            name: "SelfEvolutionExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SelfEvolutionExample"
        ),
        .executableTarget(
            name: "AgentMCPServerExample",
            dependencies: ["OpenAgentSDK",
                .product(name: "MCP", package: "swift-mcp"),
            ],
            path: "Examples/AgentMCPServerExample"
        ),
        .executableTarget(
            name: "PauseProtocolExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/PauseProtocolExample"
        ),
        .executableTarget(
            name: "AgentHTTPServerExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/AgentHTTPServerExample"
        ),
        .executableTarget(
            name: "CostTrackerExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/CostTrackerExample"
        ),
        .executableTarget(
            name: "EventBusExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/EventBusExample"
        ),
        .executableTarget(
            name: "AgentEventBusExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/AgentEventBusExample"
        ),
        .executableTarget(
            name: "SSEBridgeExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SSEBridgeExample"
        ),
        .executableTarget(
            name: "SkillWriterExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/SkillWriterExample"
        ),
        .executableTarget(
            name: "ReviewOrchestratorExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/ReviewOrchestratorExample"
        ),
        .executableTarget(
            name: "EnvInjectionExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/EnvInjectionExample"
        ),
        .executableTarget(
            name: "MessageSummaryExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/MessageSummaryExample"
        ),
        .executableTarget(
            name: "ClaudeCodeCompatExample",
            dependencies: ["OpenAgentSDK"],
            path: "Examples/ClaudeCodeCompatExample"
        ),
        .executableTarget(
            name: "ScaffoldCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ScaffoldCLI"
        ),
        .testTarget(
            name: "ScaffoldCLITests",
            dependencies: ["ScaffoldCLI"],
            path: "Tests/ScaffoldCLITests"
        ),
    ]
)
