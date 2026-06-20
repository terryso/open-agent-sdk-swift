import Foundation
import MCP

// MARK: - AgentMCPServer

/// Actor that exposes an Agent's tools as an MCP stdio server.
///
/// External MCP clients (like Claude Code) can discover and invoke
/// the Agent's tools via the standard MCP protocol over stdin/stdout.
/// When initialized with an Agent via ``run(agent:)``, the special
/// `agent_prompt` tool enables full autonomous task execution.
///
/// ## Usage
///
/// ```swift
/// let agent = createAgent(options: myOptions)
/// let (tools, _) = await agent.assembleFullToolPool()
/// let server = AgentMCPServer(name: "my-agent", tools: tools)
/// try await server.run(agent: agent)
/// ```
///
/// ## Testing
///
/// For in-process testing without real stdio I/O, use ``createSession()``:
///
/// ```swift
/// let server = AgentMCPServer(name: "test", tools: [myTool])
/// let (mcpServer, transport) = try await server.createSession()
/// let client = Client(name: "test-client", version: "1.0.0")
/// try await client.connect(transport: transport)
/// ```
///
/// Module boundary compliance: Only imports Foundation, MCP, and Types/ (via same-module access).
public actor AgentMCPServer {

    // MARK: - Properties

    /// Server name for MCP identification.
    public let name: String

    /// Server version.
    public let version: String

    /// The tools to expose via MCP protocol.
    private let tools: [ToolProtocol]

    /// Working directory for ToolContext.
    private let cwd: String

    /// Optional Agent for the `agent_prompt` tool execution.
    /// Set via ``run(agent:)`` before the server starts.
    private var agent: Agent?

    /// Internal MCPServer instance (created on first use).
    private var mcpServer: MCPServer?

    // MARK: - Initialization

    /// Creates a new AgentMCPServer with the given configuration.
    ///
    /// - Parameters:
    ///   - name: The server name for MCP identification.
    ///   - version: The server version. Defaults to "1.0.0".
    ///   - tools: The tools to expose via MCP protocol.
    ///   - cwd: Working directory for ToolContext. Defaults to current working directory.
    public init(
        name: String,
        version: String = "1.0.0",
        tools: [ToolProtocol],
        cwd: String? = nil
    ) {
        self.name = name
        self.version = version
        self.tools = tools
        self.cwd = cwd ?? FileManager.default.currentDirectoryPath
    }

    // MARK: - Session Management

    /// Creates a new MCP session with a connected InMemoryTransport pair.
    ///
    /// Each call creates a fresh Server instance sharing the same tool definitions,
    /// supporting multiple concurrent clients. The session is fully started and ready
    /// for an MCP client to connect via the returned transport.
    ///
    /// - Returns: A tuple of (Server, InMemoryTransport) where the transport is the
    ///   client-side of a connected pair. Connect an MCP `Client` to this transport.
    public func createSession() async throws -> (Server, InMemoryTransport) {
        let server = await getOrCreateMCPServer()
        return try await createMCPSession(server)
    }

    // MARK: - Stdio Server

    /// Runs the MCP server with stdio transport, exposing the Agent's tools.
    ///
    /// The provided agent is used by the `agent_prompt` tool for full
    /// autonomous task execution. Blocks until stdin receives EOF.
    ///
    /// - Parameter agent: The Agent to expose via the `agent_prompt` tool.
    public func run(agent: Agent) async throws {
        self.agent = agent
        let mcpServer = await getOrCreateMCPServer()
        let session = await mcpServer.createSession()
        let transport = StdioTransport()
        try await session.start(transport: transport)
        await session.waitUntilCompleted()
    }

    /// Internal: sets the Agent without starting the stdio transport.
    ///
    /// `run(agent:)` blocks on `StdioTransport` and cannot be used in unit
    /// tests. This entry point lets tests inject an Agent so they can
    /// exercise the agent_prompt handler's success and error branches via
    /// `createSession()` + MCP client calls.
    internal func setAgentForTesting(_ agent: Agent) {
        self.agent = agent
    }

    /// Runs the MCP server with stdio transport, exposing only the registered tools.
    ///
    /// The `agent_prompt` tool is registered but returns an error when called,
    /// since no agent is configured. Use ``run(agent:)`` to enable full agent execution.
    public func run() async throws {
        let mcpServer = await getOrCreateMCPServer()
        let session = await mcpServer.createSession()
        let transport = StdioTransport()
        try await session.start(transport: transport)
        await session.waitUntilCompleted()
    }

    // MARK: - Private Helpers

    /// Lazily creates and caches the MCPServer instance, registering all tools.
    private func getOrCreateMCPServer() async -> MCPServer {
        if let existing = mcpServer {
            return existing
        }

        let server = MCPServer(name: name, version: version)

        // Register each ToolProtocol tool as a closure-based MCP tool
        await registerToolsOnMCPServer(tools, server: server, cwd: cwd) { toolName, error in
            Logger.shared.error("AgentMCPServer", "Failed to register tool '\(toolName)': \(error)")
        }

        // Register the special agent_prompt tool
        let agentPromptSchema: Value = .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string("The task for the agent to execute")
                ])
            ]),
            "required": .array([.string("task")])
        ])

        // Capture agent reference for the closure.
        // Agent is set via run(agent:) before getOrCreateMCPServer() is called.
        let capturedAgent = agent

        do {
            try await server.register(
                name: "agent_prompt",
                description: "Submit a task to the agent for full autonomous execution. The agent will use all its tools to complete the task.",
                inputSchema: agentPromptSchema
            ) { (args: [String: Value], context: HandlerContext) async throws -> String in
                guard let taskValue = args["task"], case .string(let task) = taskValue else {
                    throw ToolExecutionError(message: "Missing required 'task' parameter")
                }
                guard let agent = capturedAgent else {
                    throw ToolExecutionError(message: "No agent configured. Use run(agent:) to provide an agent for task execution.")
                }
                let result = await agent.prompt(task)
                if result.status == .errorDuringExecution, let errors = result.errors {
                    throw ToolExecutionError(message: errors.joined(separator: "; "))
                }
                return result.text
            }
        } catch {
            Logger.shared.error("AgentMCPServer", "Failed to register agent_prompt tool: \(error)")
        }

        mcpServer = server
        return server
    }

    // MARK: - Schema Conversion

}
