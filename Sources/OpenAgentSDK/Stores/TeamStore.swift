import Foundation

/// Thread-safe team store using actor isolation.
public actor TeamStore {

    // MARK: - Properties

    private var teams: [String: Team] = [:]
    private var teamCounter: Int = 0
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Create a new team.
    /// - Returns: The created team with auto-generated ID and timestamps.
    public func create(
        name: String,
        members: [TeamMember] = [],
        leaderId: String = "self"
    ) -> Team {
        teamCounter += 1
        let id = "team_\(teamCounter)"
        let now = dateFormatter.string(from: Date())
        let team = Team(
            id: id,
            name: name,
            members: members,
            leaderId: leaderId,
            createdAt: now,
            status: .active
        )
        teams[id] = team
        return team
    }

    /// Get a team by ID.
    public func get(id: String) -> Team? {
        return teams[id]
    }

    /// List teams, optionally filtered by status.
    public func list(status: TeamStatus? = nil) -> [Team] {
        var result = Array(teams.values)
        if let status {
            result = result.filter { $0.status == status }
        }
        return result
    }

    /// Delete (disband) a team by ID.
    /// - Throws: ``TeamStoreError/teamNotFound`` if the team does not exist.
    /// - Throws: ``TeamStoreError/teamAlreadyDisbanded`` if the team is already disbanded.
    public func delete(id: String) throws -> Bool {
        guard var team = teams[id] else {
            throw TeamStoreError.teamNotFound(id: id)
        }
        guard team.status != .disbanded else {
            throw TeamStoreError.teamAlreadyDisbanded(id: id)
        }
        team.status = .disbanded
        teams[id] = team
        return true
    }

    /// Add a member to an active team.
    /// - Throws: ``TeamStoreError/teamNotFound`` if the team does not exist.
    /// - Throws: ``TeamStoreError/teamAlreadyDisbanded`` if the team is disbanded.
    public func addMember(teamId: String, member: TeamMember) throws -> Team {
        guard var team = teams[teamId] else {
            throw TeamStoreError.teamNotFound(id: teamId)
        }
        guard team.status == .active else {
            throw TeamStoreError.teamAlreadyDisbanded(id: teamId)
        }
        team.members.append(member)
        teams[teamId] = team
        return team
    }

    /// Remove a member from a team by name.
    /// - Throws: ``TeamStoreError/teamNotFound`` if the team does not exist.
    /// - Throws: ``TeamStoreError/memberNotFound`` if the member is not in the team.
    public func removeMember(teamId: String, agentName: String) throws -> Team {
        guard var team = teams[teamId] else {
            throw TeamStoreError.teamNotFound(id: teamId)
        }
        guard team.status == .active else {
            throw TeamStoreError.teamAlreadyDisbanded(id: teamId)
        }
        let initialCount = team.members.count
        team.members.removeAll { $0.name == agentName }
        guard team.members.count < initialCount else {
            throw TeamStoreError.memberNotFound(teamId: teamId, memberName: agentName)
        }
        teams[teamId] = team
        return team
    }

    /// Find the active team that contains a given agent.
    public func getTeamForAgent(agentName: String) -> Team? {
        return teams.values.first { team in
            team.status == .active && team.members.contains { $0.name == agentName }
        }
    }

    /// Clear all teams and reset the ID counter.
    public func clear() {
        teams.removeAll()
        teamCounter = 0
    }
}
