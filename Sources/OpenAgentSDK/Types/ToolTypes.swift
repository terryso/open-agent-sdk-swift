import Foundation

/// JSON Schema dictionary type for tool input definitions.
public typealias ToolInputSchema = [String: Any]

/// Protocol defining a tool that can be executed by the agent.
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }
    var isReadOnly: Bool { get }

    func call(input: Any, context: ToolContext) async -> ToolResult
}

/// Result returned from a tool execution.
public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public init(toolUseId: String, content: String, isError: Bool) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Structured result returned by tool execution closures that need to
/// explicitly signal success or error.
public struct ToolExecuteResult: Sendable, Equatable {
    public let content: String
    public let isError: Bool

    public init(content: String, isError: Bool) {
        self.content = content
        self.isError = isError
    }
}

/// Context provided to tool executions.
public struct ToolContext: Sendable {
    public let cwd: String
    public let toolUseId: String
    /// Optional sub-agent spawner for tools that need to create child agents.
    /// Set by Core/ when AgentTool is registered. Nil when sub-agent spawning
    /// is not available (e.g., no Agent tool in the tool set).
    public let agentSpawner: (any SubAgentSpawner)?

    public init(cwd: String, toolUseId: String = "", agentSpawner: (any SubAgentSpawner)? = nil) {
        self.cwd = cwd
        self.toolUseId = toolUseId
        self.agentSpawner = agentSpawner
    }
}
