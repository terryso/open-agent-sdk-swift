import Foundation

/// Thread-safe agent registry for sub-agent discovery.
public actor AgentRegistry {

    // MARK: - Properties

    private var agents: [String: AgentRegistryEntry] = [:]  // agentId -> entry
    private var nameIndex: [String: String] = [:]  // name -> agentId (reverse index)
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Register a new agent. Throws if name is already taken.
    /// - Throws: ``AgentRegistryError/duplicateAgentName(name:)`` if an agent with the same name exists.
    public func register(
        agentId: String,
        name: String,
        agentType: String
    ) throws -> AgentRegistryEntry {
        if nameIndex[name] != nil {
            throw AgentRegistryError.duplicateAgentName(name: name)
        }

        let entry = AgentRegistryEntry(
            agentId: agentId,
            name: name,
            agentType: agentType,
            registeredAt: dateFormatter.string(from: Date())
        )
        agents[agentId] = entry
        nameIndex[name] = agentId
        return entry
    }

    /// Unregister an agent by ID.
    /// - Returns: `true` if the agent was found and removed, `false` otherwise.
    public func unregister(agentId: String) -> Bool {
        guard let entry = agents[agentId] else { return false }
        nameIndex.removeValue(forKey: entry.name)
        agents.removeValue(forKey: agentId)
        return true
    }

    /// Get an agent by ID.
    public func get(agentId: String) -> AgentRegistryEntry? {
        return agents[agentId]
    }

    /// Get an agent by name (uses reverse index for O(1) lookup).
    public func getByName(name: String) -> AgentRegistryEntry? {
        guard let agentId = nameIndex[name] else { return nil }
        return agents[agentId]
    }

    /// List all registered agents.
    public func list() -> [AgentRegistryEntry] {
        return Array(agents.values)
    }

    /// List agents filtered by type.
    public func listByType(agentType: String) -> [AgentRegistryEntry] {
        return agents.values.filter { $0.agentType == agentType }
    }

    /// Clear all registered agents and reset the name index.
    public func clear() {
        agents.removeAll()
        nameIndex.removeAll()
    }
}
