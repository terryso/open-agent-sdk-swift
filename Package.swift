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
    ]
)
