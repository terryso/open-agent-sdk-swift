import Foundation

/// A slash command definition for API surface alignment with the TypeScript SDK.
///
/// The Swift SDK does not define slash commands (this is a TS-specific concept),
/// so ``Agent/initializationResult()`` returns an empty array for the `commands` field.
public struct SlashCommand: Sendable, Equatable {
    /// The command name (e.g., "/commit").
    public let name: String
    /// A description of what the command does.
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Account information for API surface alignment with the TypeScript SDK.
///
/// The Swift SDK does not manage accounts directly, so this type provides
/// minimal fields for compatibility.
public struct AccountInfo: Sendable, Equatable {
    /// The account identifier, if available.
    public let accountId: String?

    public init(accountId: String? = nil) {
        self.accountId = accountId
    }
}

/// Response from ``Agent/initializationResult()`` describing the agent's capabilities.
///
/// Mirrors the TypeScript SDK's `SDKControlInitializeResponse` type, providing
/// metadata about available commands, agents, models, and configuration.
///
/// ```swift
/// let result = agent.initializationResult()
/// print(result.models.count)        // Number of available models
/// print(result.agents.count)        // Number of configured sub-agents
/// print(result.commands.count)      // Always empty (TS-specific concept)
/// ```
public struct SDKControlInitializeResponse: Sendable, Equatable {
    /// Available slash commands. Always empty in the Swift SDK.
    public let commands: [SlashCommand]
    /// Configured sub-agent definitions.
    public let agents: [AgentInfo]
    /// The current output style name.
    public let outputStyle: String
    /// All available output style names.
    public let availableOutputStyles: [String]
    /// Available models from the MODEL_PRICING table.
    public let models: [ModelInfo]
    /// Account information, if available.
    public let account: AccountInfo?
    /// Whether fast mode is active.
    public let fastModeState: Bool

    public init(
        commands: [SlashCommand] = [],
        agents: [AgentInfo] = [],
        outputStyle: String = "default",
        availableOutputStyles: [String] = ["default"],
        models: [ModelInfo] = [],
        account: AccountInfo? = nil,
        fastModeState: Bool = false
    ) {
        self.commands = commands
        self.agents = agents
        self.outputStyle = outputStyle
        self.availableOutputStyles = availableOutputStyles
        self.models = models
        self.account = account
        self.fastModeState = fastModeState
    }
}
