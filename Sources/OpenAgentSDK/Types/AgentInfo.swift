import Foundation

/// Information about a configured sub-agent.
///
/// Returned by ``Agent/supportedAgents()`` to describe the sub-agents
/// available for spawning.
///
/// ```swift
/// let agents = agent.supportedAgents()
/// for a in agents {
///     print("\(a.name): \(a.description ?? "no description")")
/// }
/// ```
public struct AgentInfo: Sendable, Equatable {
    /// The name of the sub-agent.
    public let name: String
    /// An optional description of the sub-agent's purpose.
    public let description: String?
    /// The model identifier the sub-agent uses, or nil to inherit the parent model.
    public let model: String?

    public init(name: String, description: String? = nil, model: String? = nil) {
        self.name = name
        self.description = description
        self.model = model
    }
}
