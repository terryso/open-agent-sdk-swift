// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OpenAgentSDK",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "OpenAgentSDK",
            targets: ["OpenAgentSDK"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/DePasqualeOrg/mcp-swift-sdk.git",
            from: "0.1.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "OpenAgentSDK",
            dependencies: [
                .product(name: "MCP", package: "mcp-swift-sdk"),
            ],
            path: "Sources/OpenAgentSDK"
        ),
        .testTarget(
            name: "OpenAgentSDKTests",
            dependencies: ["OpenAgentSDK"],
            path: "Tests/OpenAgentSDKTests"
        ),
        .executableTarget(
            name: "E2ETest",
            dependencies: ["OpenAgentSDK",
                .product(name: "MCP", package: "mcp-swift-sdk"),
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
                .product(name: "MCP", package: "mcp-swift-sdk"),
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
                .product(name: "MCP", package: "mcp-swift-sdk"),
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
    ]
)
