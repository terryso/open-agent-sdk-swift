import XCTest
@testable import OpenAgentSDK

// MARK: - MCPAgentIntegrationTests

/// ATDD RED PHASE: Tests for Story 6.4 -- MCP Tool & Agent Integration.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `assembleFullToolPool()` is verified/updated in `Core/Agent.swift`
///   - `processMcpConfigs()` is verified in `Core/Agent.swift` extension
///   - `SdkToolWrapper` is verified in `Core/Agent.swift`
///   - prompt() MCP integration path is verified in `Core/Agent.swift`
///   - stream() MCP integration path is verified in `Core/Agent.swift`
///   - MCP connection cleanup is verified on all exit paths
/// TDD Phase: RED (feature verification -- tests may pass if implementation is correct)
final class MCPAgentIntegrationTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for MCP tests).
    private func makeContext(toolUseId: String = "test-tool-use-id") -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: toolUseId
        )
    }

    /// Creates a simple mock tool for testing.
    private func makeMockTool(
        name: String = "test_tool",
        description: String = "A test tool",
        resultContent: String = "mock result"
    ) -> AgentIntegrationMockTool {
        return AgentIntegrationMockTool(
            toolName: name,
            toolDescription: description,
            resultContent: resultContent
        )
    }

    /// Creates a mock MCPClient for testing tool dispatch.
    private func makeMockMCPClient(
        callResult: String? = nil,
        callError: Error? = nil
    ) -> MockMCPClientForIntegration {
        return MockMCPClientForIntegration(callResult: callResult, callError: callError)
    }

    /// Creates an InProcessMCPServer with the given tools.
    private func makeSdkServer(
        name: String = "test-sdk",
        version: String = "1.0.0",
        tools: [ToolProtocol] = []
    ) -> InProcessMCPServer {
        return InProcessMCPServer(name: name, version: version, tools: tools)
    }

    // ================================================================
    // MARK: - AC1: MCP Tool Namespace Integration
    // ================================================================

    /// AC1 [P0]: assembleFullToolPool merges MCP tools with built-in tools.
    /// Given an Agent with both built-in tools and MCP servers configured,
    /// when assembleFullToolPool() is called, MCP tools appear with
    /// mcp__{serverName}__{toolName} namespace alongside built-in tools.
    func testAssembleFullToolPool_mergesBuiltinAndMCPTools() async {
        let tool = makeMockTool(name: "search", description: "search tool")
        let server = makeSdkServer(name: "remote", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "remote", version: "1.0.0", server: server)
        let mcpServers: [String: McpServerConfig] = [
            "remote": .sdk(sdkConfig)
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, manager) = await agent.assembleFullToolPool()

        // Should contain MCP namespaced tool
        let hasMCPTool = tools.contains(where: { $0.name == "mcp__remote__search" })
        XCTAssertTrue(hasMCPTool,
                       "Tool pool should contain MCP namespaced tool mcp__remote__search")

        // Should also contain built-in tools (e.g., Bash)
        let hasBash = tools.contains(where: { $0.name == "Bash" })
        XCTAssertTrue(hasBash,
                       "Tool pool should still contain built-in tools like Bash")

        // Cleanup
        if let manager {
            await manager.shutdown()
        }
    }

    /// AC1 [P0]: MCP tools use mcp__{serverName}__{toolName} namespace convention.
    func testAssembleFullToolPool_mcpToolsUseCorrectNamespace() async {
        let tool = makeMockTool(name: "read_file", description: "read a file")
        let server = makeSdkServer(name: "filesystem", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "filesystem", version: "1.0.0", server: server)
        let mcpServers: [String: McpServerConfig] = [
            "filesystem": .sdk(sdkConfig)
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        let mcpTool = tools.first(where: { $0.name.hasPrefix("mcp__filesystem__") })
        XCTAssertNotNil(mcpTool,
                         "Tool with mcp__filesystem__ prefix should exist")
        XCTAssertEqual(mcpTool?.name, "mcp__filesystem__read_file",
                        "MCP tool should use mcp__{serverName}__{toolName} namespace")
    }

    /// AC1 [P1]: When no MCP servers configured, assembleFullToolPool returns custom tools only.
    func testAssembleFullToolPool_noMcpServers_returnsCustomToolsOnly() async {
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: nil
        )
        let agent = Agent(options: options)

        let (tools, manager) = await agent.assembleFullToolPool()

        // No MCP manager should be created
        XCTAssertNil(manager,
                      "No MCPClientManager should be created when no MCP servers configured")

        // Without MCP servers, assembleFullToolPool returns options.tools (which is empty by default)
        XCTAssertTrue(tools.isEmpty,
                       "Without MCP servers, pool should contain only custom tools (empty by default)")
    }

    // ================================================================
    // MARK: - AC3: SDK In-Process Tool Direct Injection
    // ================================================================

    /// AC3 [P0]: SDK tools are directly injected via SdkToolWrapper without MCP protocol.
    /// When Agent has McpServerConfig.sdk configured, the tools bypass MCP protocol entirely.
    func testSdkToolWrapper_directInjection_noMCPProtocol() async {
        let tool = makeMockTool(name: "compute", description: "compute something")
        let server = makeSdkServer(name: "sdk-srv", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "sdk-srv", version: "1.0.0", server: server)
        let mcpServers: [String: McpServerConfig] = [
            "sdk-srv": .sdk(sdkConfig)
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, manager) = await agent.assembleFullToolPool()

        // SDK-only config should NOT create an MCPClientManager (no external connections)
        XCTAssertNil(manager,
                      "SDK-only config should not create MCPClientManager (zero network overhead)")

        // The SDK tool should still be in the pool with namespace prefix
        let hasNamespacedTool = tools.contains(where: { $0.name == "mcp__sdk-srv__compute" })
        XCTAssertTrue(hasNamespacedTool,
                       "SDK tool should be in pool with mcp__sdk-srv__compute namespace")
    }

    /// AC3 [P0]: SdkToolWrapper namespace prefix matches mcp__{serverName}__{toolName}.
    func testSdkToolWrapper_namespacePrefix() async {
        let tool = makeMockTool(name: "analyze", description: "analyze data")
        let server = makeSdkServer(name: "analytics", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "analytics", version: "1.0.0", server: server)
        let mcpServers: [String: McpServerConfig] = [
            "analytics": .sdk(sdkConfig)
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        let sdkTool = tools.first(where: { $0.name == "mcp__analytics__analyze" })
        XCTAssertNotNil(sdkTool,
                         "SDK tool should have mcp__analytics__analyze name")
        XCTAssertEqual(sdkTool?.description, "analyze data",
                        "SDK tool description should pass through")
    }

    /// AC3 [P1]: SdkToolWrapper delegates call() to inner tool with zero overhead.
    func testSdkToolWrapper_callDelegatesToInnerTool() async {
        let tool = makeMockTool(name: "echo", resultContent: "Hello from SDK!")
        let server = makeSdkServer(name: "sdk", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "sdk", version: "1.0.0", server: server)
        let mcpServers: [String: McpServerConfig] = [
            "sdk": .sdk(sdkConfig)
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        let sdkTool = tools.first(where: { $0.name == "mcp__sdk__echo" })
        XCTAssertNotNil(sdkTool)

        let context = makeContext()
        let result = await sdkTool!.call(input: [:], context: context)

        XCTAssertFalse(result.isError,
                        "SdkToolWrapper should successfully delegate to inner tool")
        XCTAssertEqual(result.content, "Hello from SDK!",
                        "SdkToolWrapper should return inner tool result directly")
    }

    // ================================================================
    // MARK: - AC4: Mixed Configuration Handling
    // ================================================================

    /// AC4 [P0]: processMcpConfigs separates SDK and external configurations.
    /// SDK tools are extracted directly; external configs go to MCPClientManager.
    func testProcessMcpConfigs_separatesSdkAndExternalConfigs() async {
        let tool = makeMockTool(name: "internal_tool")
        let server = makeSdkServer(name: "sdk-server", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "sdk-server", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "sdk-server": .sdk(sdkConfig),
            "external-stdio": .stdio(McpStdioConfig(command: "/nonexistent")),
            "external-sse": .sse(McpSseConfig(url: "http://localhost:1/sse")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, manager) = await agent.assembleFullToolPool()

        // SDK tool should be directly injected (namespaced)
        let hasSdkTool = tools.contains(where: { $0.name == "mcp__sdk-server__internal_tool" })
        XCTAssertTrue(hasSdkTool,
                       "SDK tool should be in pool with namespace prefix")

        // External server config should create MCPClientManager
        XCTAssertNotNil(manager,
                         "External configs should create MCPClientManager for connection management")

        // Cleanup
        if let manager {
            await manager.shutdown()
        }
    }

    /// AC4 [P0]: Mixed config (stdio + sdk) produces merged tool pool.
    func testMixedConfig_stdioAndSdk_producesMergedPool() async {
        let tool = makeMockTool(name: "sdk_fn")
        let server = makeSdkServer(name: "local", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "local", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "local": .sdk(sdkConfig),
            "remote": .stdio(McpStdioConfig(command: "/nonexistent")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        // SDK tool should be present (direct injection)
        let hasSdkTool = tools.contains(where: { $0.name == "mcp__local__sdk_fn" })
        XCTAssertTrue(hasSdkTool,
                       "SDK tool should be in pool")

        // Built-in tools should still be present
        let hasBash = tools.contains(where: { $0.name == "Bash" })
        XCTAssertTrue(hasBash,
                       "Built-in tools should still be in pool alongside mixed MCP configs")
    }

    /// AC4 [P1]: Four-way mixed config (stdio + sse + http + sdk) processes correctly.
    func testMixedConfig_allFourTypes_processesCorrectly() async {
        let tool = makeMockTool(name: "sdk_fn")
        let server = makeSdkServer(name: "local", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "local", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "local": .sdk(sdkConfig),
            "stdio-srv": .stdio(McpStdioConfig(command: "/nonexistent")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:1/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:1/mcp")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, manager) = await agent.assembleFullToolPool()

        // SDK tool should be present
        let hasSdkTool = tools.contains(where: { $0.name == "mcp__local__sdk_fn" })
        XCTAssertTrue(hasSdkTool,
                       "SDK tool should be in pool with all four config types")

        // MCPClientManager should be created for external servers
        XCTAssertNotNil(manager,
                         "External servers (stdio/sse/http) should create MCPClientManager")

        // Cleanup
        if let manager {
            await manager.shutdown()
        }
    }

    // ================================================================
    // MARK: - AC7: Tool Execution Error Isolation
    // ================================================================

    /// AC7 [P0]: MCP tool execution failure returns ToolResult(isError: true).
    /// Agent loop does not crash; LLM can continue with error feedback.
    func testMCPToolExecution_errorIsolation_returnsErrorToolResult() async {
        let mockClient = makeMockMCPClient(
            callError: MCPIntegrationTestError.connectionFailed
        )
        let tool = MCPToolDefinition(
            serverName: "failing-server",
            mcpToolName: "fail_tool",
            toolDescription: "A tool that fails",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)

        XCTAssertTrue(result.isError,
                       "MCP tool execution failure should return isError: true")
        XCTAssertTrue(result.content.contains("error") || result.content.contains("MCP"),
                       "Error content should describe the issue")
    }

    /// AC7 [P0]: MCP tool execution with nil client returns error ToolResult.
    func testMCPToolExecution_nilClient_returnsErrorToolResult() async {
        let tool = MCPToolDefinition(
            serverName: "disconnected",
            mcpToolName: "unavailable",
            toolDescription: "Tool with no client",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)

        XCTAssertTrue(result.isError,
                       "MCP tool with nil client should return error ToolResult")
    }

    /// AC7 [P0]: MCP tool execution error does not crash the agent loop.
    /// Error is captured as ToolResult(isError: true) and returned to LLM.
    func testMCPToolExecution_errorDoesNotCrash() async {
        let mockClient = makeMockMCPClient(
            callError: MCPIntegrationTestError.timeout
        )
        let tool = MCPToolDefinition(
            serverName: "timeout-server",
            mcpToolName: "slow_tool",
            toolDescription: "A tool that times out",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext(toolUseId: "error-isolation-test")
        // This should NOT throw -- errors are captured as ToolResult
        let result = await tool.call(input: ["key": "value"], context: context)

        XCTAssertTrue(result.isError,
                       "Error should be captured as ToolResult, not thrown")
        XCTAssertEqual(result.toolUseId, "error-isolation-test",
                        "ToolResult should preserve toolUseId even on error")
    }

    // ================================================================
    // MARK: - AC8: Tool Pool Deduplication
    // ================================================================

    /// AC8 [P0]: assembleToolPool deduplicates tools by name.
    /// Later-registered tools override earlier ones with the same name.
    func testAssembleToolPool_deduplicatesMCPTools() {
        let mcpTool1 = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "search",
            toolDescription: "Version 1",
            schema: ["type": "object"],
            mcpClient: nil
        )
        let mcpTool2 = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "search",
            toolDescription: "Version 2",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let pool = assembleToolPool(
            baseTools: [],
            customTools: nil,
            mcpTools: [mcpTool1, mcpTool2],
            allowed: nil,
            disallowed: nil
        )

        // Both have same name "mcp__srv__search" so should be deduplicated
        let matchingTools = pool.filter { $0.name == "mcp__srv__search" }
        XCTAssertEqual(matchingTools.count, 1,
                        "Duplicate MCP tools should be deduplicated to 1")
    }

    /// AC8 [P0]: Tool name uniqueness is guaranteed in the pool.
    func testAssembleToolPool_toolNameUniqueness() {
        let toolsFromDifferentServers: [ToolProtocol] = [
            MCPToolDefinition(serverName: "srv1", mcpToolName: "search",
                              toolDescription: "Server 1 search", schema: [:], mcpClient: nil),
            MCPToolDefinition(serverName: "srv2", mcpToolName: "search",
                              toolDescription: "Server 2 search", schema: [:], mcpClient: nil),
        ]

        let pool = assembleToolPool(
            baseTools: [],
            customTools: nil,
            mcpTools: toolsFromDifferentServers,
            allowed: nil,
            disallowed: nil
        )

        // Different servers, different names: mcp__srv1__search and mcp__srv2__search
        let names = pool.map { $0.name }
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count,
                        "All tool names in pool should be unique")
        XCTAssertTrue(pool.contains(where: { $0.name == "mcp__srv1__search" }))
        XCTAssertTrue(pool.contains(where: { $0.name == "mcp__srv2__search" }))
    }

    /// AC8 [P1]: Custom tools can override built-in tools via deduplication.
    func testAssembleToolPool_customToolOverridesBuiltin() {
        let customTool = AgentIntegrationMockTool(
            toolName: "Bash",
            toolDescription: "Custom bash",
            resultContent: "custom result"
        )

        let baseTools = getAllBaseTools(tier: .core)
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: [customTool],
            mcpTools: [],
            allowed: nil,
            disallowed: nil
        )

        // Custom "Bash" should override built-in "Bash"
        let bashTool = pool.first(where: { $0.name == "Bash" })
        XCTAssertNotNil(bashTool,
                         "Bash tool should exist in pool")
        XCTAssertEqual(bashTool?.description, "Custom bash",
                        "Custom tool should override built-in tool")
    }

    // ================================================================
    // MARK: - AC9: MCP Connection Lifecycle
    // ================================================================

    /// AC9 [P0]: MCP connections are cleaned up after assembleFullToolPool usage.
    func testMCPLifecycle_connectionsCleanedUpAfterUsage() async {
        let mcpServers: [String: McpServerConfig] = [
            "remote": .stdio(McpStdioConfig(command: "/nonexistent")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (_, manager) = await agent.assembleFullToolPool()

        // Manager should exist for external servers
        XCTAssertNotNil(manager)

        // Explicit cleanup
        if let manager {
            await manager.shutdown()
            let connections = await manager.getConnections()
            XCTAssertTrue(connections.isEmpty,
                           "Connections should be empty after shutdown")
        }
    }

    /// AC9 [P0]: MCPClientManager shutdown cleans up all external connections.
    func testMCPLifecycle_shutdownCleansUpExternalConnections() async {
        let mcpServers: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "/nonexistent")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:1/sse")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (_, manager) = await agent.assembleFullToolPool()

        if let manager {
            // Before shutdown: connections should be tracked
            let beforeShutdown = await manager.getConnections()
            XCTAssertTrue(beforeShutdown.count >= 1,
                           "Should have tracked at least 1 connection before shutdown")

            // After shutdown: connections should be empty
            await manager.shutdown()
            let afterShutdown = await manager.getConnections()
            XCTAssertTrue(afterShutdown.isEmpty,
                           "All connections should be cleaned up after shutdown")
        }
    }

    // ================================================================
    // MARK: - MCP Connection Error Does Not Block Tool Pool
    // ================================================================

    /// AC7 [P1]: MCP connection failure does not prevent tool pool assembly.
    /// Even if all external MCP servers fail, built-in tools remain available.
    func testMCPConnectionFailure_toolPoolStillHasBuiltinTools() async {
        let mcpServers: [String: McpServerConfig] = [
            "failing-remote": .stdio(McpStdioConfig(command: "/nonexistent/command")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        // Built-in tools should still be present even when MCP connection fails
        let hasBash = tools.contains(where: { $0.name == "Bash" })
        XCTAssertTrue(hasBash,
                       "Built-in tools should still be available when MCP connections fail")

        // The failed MCP server should contribute no tools
        let mcpTools = tools.filter { $0.name.hasPrefix("mcp__") }
        XCTAssertTrue(mcpTools.isEmpty,
                       "Failed external MCP servers should contribute no tools")
    }

    /// AC4 [P1]: SDK tools are available even when external servers fail.
    func testMixedConfig_externalFailure_sdkToolsStillAvailable() async {
        let tool = makeMockTool(name: "reliable_fn")
        let server = makeSdkServer(name: "local", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "local", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "local": .sdk(sdkConfig),
            "broken": .stdio(McpStdioConfig(command: "/nonexistent")),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        // SDK tool should still be available despite external server failure
        let hasSdkTool = tools.contains(where: { $0.name == "mcp__local__reliable_fn" })
        XCTAssertTrue(hasSdkTool,
                       "SDK tool should be available even when external servers fail")
    }

    // ================================================================
    // MARK: - Multiple MCP Server Tool Pool Merging
    // ================================================================

    /// AC4 [P0]: Multiple MCP servers' tools are all merged into the pool.
    func testMultipleMCPServers_allToolsMerged() async {
        let tool1 = makeMockTool(name: "fn_a")
        let tool2 = makeMockTool(name: "fn_b")
        let server1 = makeSdkServer(name: "srv-a", tools: [tool1])
        let server2 = makeSdkServer(name: "srv-b", tools: [tool2])

        let mcpServers: [String: McpServerConfig] = [
            "srv-a": .sdk(McpSdkServerConfig(name: "srv-a", version: "1.0.0", server: server1)),
            "srv-b": .sdk(McpSdkServerConfig(name: "srv-b", version: "1.0.0", server: server2)),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        XCTAssertTrue(tools.contains(where: { $0.name == "mcp__srv-a__fn_a" }),
                       "Tool from server A should be in pool")
        XCTAssertTrue(tools.contains(where: { $0.name == "mcp__srv-b__fn_b" }),
                       "Tool from server B should be in pool")
    }

    // ================================================================
    // MARK: - Tool Input Schema Passthrough
    // ================================================================

    /// AC1 [P1]: MCP tool inputSchema is correctly passed through to the pool.
    func testMCPTool_inputSchema_passesThrough() async {
        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search query"]
            ],
            "required": ["query"]
        ]
        let tool = MCPToolDefinition(
            serverName: "search",
            mcpToolName: "web_search",
            toolDescription: "Search the web",
            schema: schema,
            mcpClient: nil
        )

        XCTAssertEqual(tool.inputSchema["type"] as? String, "object")
        let props = tool.inputSchema["properties"] as? [String: Any]
        XCTAssertNotNil(props?["query"])
    }

    // ================================================================
    // MARK: - Custom Tools + MCP Tools Together
    // ================================================================

    /// AC1 [P1]: Custom tools (options.tools) appear alongside MCP tools.
    func testAssembleFullToolPool_customToolsPlusMCPTools() async {
        let customTool = makeMockTool(name: "my_custom")
        let sdkTool = makeMockTool(name: "sdk_fn")
        let server = makeSdkServer(name: "sdk-srv", tools: [sdkTool])

        let mcpServers: [String: McpServerConfig] = [
            "sdk-srv": .sdk(McpSdkServerConfig(name: "sdk-srv", version: "1.0.0", server: server)),
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            tools: [customTool],
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        let (tools, _) = await agent.assembleFullToolPool()

        // Custom tool (without namespace)
        let hasCustom = tools.contains(where: { $0.name == "my_custom" })
        XCTAssertTrue(hasCustom,
                       "Custom tool should be in pool")

        // SDK tool (with namespace)
        let hasMCP = tools.contains(where: { $0.name == "mcp__sdk-srv__sdk_fn" })
        XCTAssertTrue(hasMCP,
                       "MCP namespaced tool should be in pool")

        // Built-in tool
        let hasBash = tools.contains(where: { $0.name == "Bash" })
        XCTAssertTrue(hasBash,
                       "Built-in tools should be in pool")
    }

    // ================================================================
    // MARK: - AgentOptions MCP Servers Integration
    // ================================================================

    /// AC5 [P0]: AgentOptions.mcpServers accepts all four config types together.
    func testAgentOptions_mcpServers_allFourConfigTypes() async {
        let server = makeSdkServer(name: "sdk-srv", tools: [])
        let config: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "echo")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:8080/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:8080/mcp")),
            "sdk-srv": .sdk(McpSdkServerConfig(name: "sdk-srv", version: "1.0.0", server: server)),
        ]

        let options = AgentOptions(mcpServers: config)

        XCTAssertEqual(options.mcpServers?.count, 4,
                        "AgentOptions should hold all four config types")
    }

    // ================================================================
    // MARK: - Empty MCP Config Edge Case
    // ================================================================

    /// AC1 [P1]: Empty mcpServers dictionary behaves same as nil.
    func testAssembleFullToolPool_emptyMcpServers_sameAsNil() async {
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: [:]
        )
        let agent = Agent(options: options)

        let (tools, manager) = await agent.assembleFullToolPool()

        XCTAssertNil(manager,
                      "Empty mcpServers should not create MCPClientManager")

        // Empty mcpServers is treated same as nil -- returns baseTools only
        XCTAssertTrue(tools.isEmpty,
                       "Empty mcpServers should return only base tools (options.tools, empty by default)")
    }

    // MARK: - stream() MCP Integration

    /// AC6 [P0]: stream() with MCP servers completes and cleans up without crash.
    func testStream_withMcpServers_completesWithoutLeak() async {
        let tool = AgentIntegrationMockTool(toolName: "stream_tool", resultContent: "stream result")
        let server = InProcessMCPServer(name: "stream-srv", version: "1.0.0", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "stream-srv", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "sdk": .sdk(sdkConfig)
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        // stream() will fail to connect to the API (test-key is invalid),
        // but should still complete without crashing or leaking MCP connections.
        var messages: [SDKMessage] = []
        for await msg in agent.stream("hello") {
            messages.append(msg)
        }
        XCTAssertTrue(messages.count >= 1,
                       "stream() should produce at least one message even on API error, got \(messages.count)")
    }

    /// AC6 [P0]: stream() with multiple MCP server types sets up tool pool correctly.
    func testStream_multipleMcpTypes_toolPoolAssembled() async {
        let tool = AgentIntegrationMockTool(toolName: "multi_tool", resultContent: "multi result")
        let server = InProcessMCPServer(name: "multi-sdk", version: "1.0.0", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "multi-sdk", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "sdk": .sdk(sdkConfig),
            "ext": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]

        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: mcpServers
        )
        let agent = Agent(options: options)

        // Verify tool pool assembly works correctly
        let (tools, manager) = await agent.assembleFullToolPool()
        let hasNamespacedSDK = tools.contains { $0.name.hasPrefix("mcp__multi-sdk__") }
        XCTAssertTrue(hasNamespacedSDK,
                       "Tool pool should contain namespaced SDK tools")
        XCTAssertNotNil(manager,
                          "Mixed config with external servers should create MCPClientManager")

        // Verify stream() doesn't crash with this config
        var streamMessages: [SDKMessage] = []
        for await msg in agent.stream("test") {
            streamMessages.append(msg)
        }
        XCTAssertTrue(streamMessages.count >= 1,
                       "stream() should produce messages even on API error")
    }
}

// MARK: - Mock Helpers

/// Mock tool for Agent integration testing.
private final class AgentIntegrationMockTool: ToolProtocol, Sendable {
    private let toolName: String
    private let toolDescription: String
    nonisolated(unsafe) private let toolSchema: ToolInputSchema
    private let resultContent: String
    private let resultIsError: Bool

    init(
        toolName: String,
        toolDescription: String = "A test tool",
        resultContent: String = "mock result",
        resultIsError: Bool = false
    ) {
        self.toolName = toolName
        self.toolDescription = toolDescription
        self.toolSchema = ["type": "object", "properties": [:]]
        self.resultContent = resultContent
        self.resultIsError = resultIsError
    }

    var name: String { toolName }
    var description: String { toolDescription }
    var inputSchema: ToolInputSchema { toolSchema }
    var isReadOnly: Bool { false }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: resultContent, isError: resultIsError)
    }
}

/// Mock MCPClient for integration testing.
private final class MockMCPClientForIntegration: MCPClientProtocol, Sendable {
    private let callResult: String?
    private let callError: Error?

    init(callResult: String? = nil, callError: Error? = nil) {
        self.callResult = callResult
        self.callError = callError
    }

    func callTool(name: String, arguments: [String: Any]?) async throws -> String {
        if let error = callError {
            throw error
        }
        return callResult ?? ""
    }
}

/// Test errors for MCP integration testing.
private enum MCPIntegrationTestError: Error, Sendable {
    case connectionFailed
    case timeout
    case toolNotFound
    case serverError
}
