import Foundation

extension Agent {

    /// Creates a forked, tool-restricted review agent from this parent agent.
    ///
    /// The review agent inherits the parent's model, provider, credentials, system prompt,
    /// and ``LLMClient`` (shared reference for prefix cache sharing). It runs with a
    /// restricted tool set limited to review-specific tools and bypasses all permission checks.
    ///
    /// The review agent does **not** inherit the parent's tools, hooks, skills, MCP servers,
    /// or stores — these are explicitly set to `nil` so the review agent operates in isolation.
    ///
    /// - Parameter config: Configuration controlling what the review agent examines
    ///   and which tools it may use.
    /// - Returns: A new ``Agent`` instance configured for background review.
    public func createReviewAgent(config: ReviewAgentConfig) -> Agent {
        var reviewOptions = AgentOptions(
            apiKey: options.apiKey,
            model: model,
            baseURL: options.baseURL,
            provider: options.provider,
            systemPrompt: systemPrompt,
            maxTurns: config.maxTurns,
            maxBudgetUsd: options.maxBudgetUsd,
            permissionMode: .bypassPermissions,
            tools: [],
            mcpServers: nil,
            agentName: "review-agent",
            sessionId: "review-\(options.sessionId ?? UUID().uuidString)",
            hookRegistry: nil,
            skillRegistry: nil,
            allowedTools: config.allowedTools
        )
        // Explicitly nil out stores and other non-inherited fields
        reviewOptions.mailboxStore = nil
        reviewOptions.teamStore = nil
        reviewOptions.taskStore = nil
        reviewOptions.worktreeStore = nil
        reviewOptions.planStore = nil
        reviewOptions.cronStore = nil
        reviewOptions.todoStore = nil
        reviewOptions.memoryStore = nil
        reviewOptions.sessionStore = nil
        reviewOptions.canUseTool = nil
        reviewOptions.skillDirectories = nil
        reviewOptions.skillNames = nil
        reviewOptions.memoryReviewConfig = nil
        reviewOptions.securityConfig = nil
        reviewOptions.evolutionPlugins = nil

        return Agent(options: reviewOptions, client: client)
    }
}
