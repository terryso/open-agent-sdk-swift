import Foundation

// MARK: - SubAgentLauncherNames

/// LLM-facing tool names that can spawn subagents.
///
/// `Agent` is the canonical SDK name; `Task` is the Claude Code-compatible alias
/// (introduced in Story 29.1). Spawner detection AND child filtering must both
/// recognize every name in this list so that:
///   1. Registering only `Task` still injects a spawner into `ToolContext`
///      (prevents the "spawner missing" runtime hole).
///   2. Both names are stripped from the child tool pool by default
///      (prevents unbounded recursive spawning).
enum SubAgentLauncherNames {
    /// Default set of subagent launcher tool names recognized by the SDK.
    /// Order does not matter (membership checks only); kept as `Array` per project rule #46.
    static let `default`: [String] = ["Agent", "Task"]

    /// Returns `true` when `toolName` is one of the default launcher names.
    static func contains(_ toolName: String) -> Bool {
        `default`.contains(toolName)
    }
}

// MARK: - SubAgentInheritanceContext

/// Parent agent context inherited by a spawned child agent.
///
/// The parent tool pool still carries concrete tool availability, but Claude Code
/// parity also requires child agents to inherit the host's configured skill
/// registry, MCP server config, cwd/env, and permission boundary.
struct SubAgentInheritanceContext: Sendable {
    var mcpServers: [String: McpServerConfig]?
    var skillRegistry: SkillRegistry?
    var permissionMode: PermissionMode?
    var canUseTool: CanUseToolFn?
    var cwd: String?
    var env: [String: String]?
    var sandbox: SandboxSettings?
    var eventBus: EventBus?
    var maxSkillRecursionDepth: Int

    static let empty = SubAgentInheritanceContext()

    init(
        mcpServers: [String: McpServerConfig]? = nil,
        skillRegistry: SkillRegistry? = nil,
        permissionMode: PermissionMode? = nil,
        canUseTool: CanUseToolFn? = nil,
        cwd: String? = nil,
        env: [String: String]? = nil,
        sandbox: SandboxSettings? = nil,
        eventBus: EventBus? = nil,
        maxSkillRecursionDepth: Int = 4
    ) {
        self.mcpServers = mcpServers
        self.skillRegistry = skillRegistry
        self.permissionMode = permissionMode
        self.canUseTool = canUseTool
        self.cwd = cwd
        self.env = env
        self.sandbox = sandbox
        self.eventBus = eventBus
        self.maxSkillRecursionDepth = maxSkillRecursionDepth
    }
}

// MARK: - DefaultSubAgentSpawner

/// Concrete implementation of ``SubAgentSpawner`` that creates real ``Agent`` instances.
///
/// This class bridges the Tools/ → Core/ boundary:
/// Tools/Advanced/AgentTool.swift uses the ``SubAgentSpawner`` protocol (defined in Types/),
/// and Core/ provides this concrete implementation via ``ToolContext/agentSpawner``.
///
/// **Architecture compliance:** Defined in Core/ (which can import Agent, AgentOptions).
/// Used in Tools/ via protocol abstraction (no Core/ import needed).
final class DefaultSubAgentSpawner: SubAgentSpawner, @unchecked Sendable {
    private let apiKey: String
    private let baseURL: String?
    private let parentModel: String
    private let parentTools: [ToolProtocol]
    private let provider: LLMProvider
    private let client: (any LLMClient)?
    private let inheritanceContext: SubAgentInheritanceContext

    init(
        apiKey: String,
        baseURL: String?,
        parentModel: String,
        parentTools: [ToolProtocol],
        provider: LLMProvider = .anthropic,
        client: (any LLMClient)? = nil,
        inheritanceContext: SubAgentInheritanceContext = .empty
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.parentModel = parentModel
        self.parentTools = parentTools
        self.provider = provider
        self.client = client
        self.inheritanceContext = inheritanceContext
    }

    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult {
        await spawn(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            maxTurns: maxTurns,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )
    }

    /// Enhanced spawn with additional sub-agent configuration parameters.
    ///
    /// Extends the base spawn with disallowedTools filtering, MCP server resolution,
    /// skills configuration, and background launch support.
    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?,
        disallowedTools: [String]?,
        mcpServers: [AgentMcpServerSpec]?,
        skills: [String]?,
        runInBackground: Bool?,
        isolation: String?,
        name: String?,
        teamName: String?,
        mode: PermissionMode?,
        resume: String?
    ) async -> SubAgentResult {
        // 1. Filter tools
        // Story 29.5: filterTools now returns (filtered, diagnostics); we currently
        // discard diagnostics at the spawner boundary (deferred-field diagnostics
        // surfacing belongs to Story 29.6).
        //
        // Story 29.7 review fix: keep the parsed declarations and pass them into
        // the child AgentOptions too. Inline MCP/default tools are assembled after
        // this parent-tool prefilter, so the child must re-apply the same
        // declaration contract to the final pool to avoid silently broadening.
        let allowedDeclarations = toolDeclarations(from: allowedTools)
        let disallowedDeclarations = toolDeclarations(from: disallowedTools)
        var subTools = filterTools(
            allowedDeclarations: allowedDeclarations,
            disallowedDeclarations: disallowedDeclarations
        ).filtered
        subTools = filterInheritedMcpTools(subTools, mcpServers: mcpServers)

        let childSkillRegistry = makeChildSkillRegistry(skills: skills)
        if let childSkillRegistry {
            subTools = replacingSkillTool(in: subTools, registry: childSkillRegistry)
        }

        // 2. Resolve MCP servers from spec.
        // Parent MCP references are already present in `parentTools` after the parent
        // agent assembles its tool pool. Keep those inherited tool instances instead
        // of reconnecting the whole server in the child, because `{ name, tools }`
        // must be able to expose a server subset without re-adding every tool.
        // Inline MCP configs are child-local and still need to be passed through.
        var resolvedMcpServers: [String: McpServerConfig] = [:]
        var unresolvedMcpReferences: [String] = []
        if let mcpServers {
            for spec in mcpServers {
                switch spec {
                case .reference(let name):
                    if !hasInheritedMcpTools(serverName: name) {
                        if let config = inheritanceContext.mcpServers?[name] {
                            resolvedMcpServers[name] = config
                        } else {
                            unresolvedMcpReferences.append(name)
                        }
                    }
                case .referenceWithTools(let name, let tools):
                    if !hasInheritedMcpTools(serverName: name) {
                        if (tools?.isEmpty ?? true), let config = inheritanceContext.mcpServers?[name] {
                            resolvedMcpServers[name] = config
                        } else {
                            unresolvedMcpReferences.append(name)
                        }
                    }
                case .inline(let config):
                    // Use a deterministic key for inline configs.
                    let key = "inline-\(resolvedMcpServers.count)"
                    resolvedMcpServers[key] = config
                }
            }
        }

        // 3. Build options
        let resolvedModel = model ?? parentModel
        let resolvedMaxTurns = maxTurns ?? 10

        var options = AgentOptions(
            apiKey: apiKey,
            model: resolvedModel,
            baseURL: baseURL,
            provider: provider,
            systemPrompt: systemPrompt,
            maxTurns: resolvedMaxTurns,
            permissionMode: mode ?? inheritanceContext.permissionMode ?? .default,
            canUseTool: inheritanceContext.canUseTool,
            cwd: inheritanceContext.cwd,
            tools: subTools.isEmpty ? nil : subTools,
            mcpServers: resolvedMcpServers.isEmpty ? nil : resolvedMcpServers,
            skillRegistry: childSkillRegistry,
            maxSkillRecursionDepth: inheritanceContext.maxSkillRecursionDepth,
            sandbox: inheritanceContext.sandbox,
            env: inheritanceContext.env,
            eventBus: inheritanceContext.eventBus
        )
        options.allowedToolDeclarations = allowedDeclarations
        options.disallowedToolDeclarations = disallowedDeclarations

        if let name { options.agentName = name }

        // Note: runInBackground, isolation, teamName, and resume
        // are declared fields but full runtime wiring is deferred.

        // 3.5 Collect deferred-field diagnostics (Story 29.6). Surfaced on
        // SubAgentResult.fieldDiagnostics so callers can tell which fields the
        // SDK honored vs ignored. Does NOT change runtime behavior — the agent
        // still runs in the foreground, is not resumed, is not isolated, etc.
        let collectedDiagnostics = collectFieldDiagnostics(
            runInBackground: runInBackground,
            isolation: isolation,
            teamName: teamName,
            resume: resume,
            unresolvedMcpReferences: unresolvedMcpReferences
        )

        // 4. Execute and collect result
        // AC8: when nothing was collected, pass `nil` (not an empty array) so
        // downstream consumers can distinguish "no signal" from "signal ran but empty".
        let fieldDiagnosticsToPropagate: [SubAgentFieldDiagnostics]? =
            collectedDiagnostics.isEmpty ? nil : collectedDiagnostics
        return await executeAgent(prompt: prompt, options: options, fieldDiagnostics: fieldDiagnosticsToPropagate)
    }

    // MARK: - Private

    private func makeChildSkillRegistry(skills: [String]?) -> SkillRegistry? {
        guard let parentRegistry = inheritanceContext.skillRegistry else { return nil }
        guard let skills else { return parentRegistry }

        let childRegistry = SkillRegistry()
        for skillName in skills {
            if let skill = parentRegistry.find(skillName) {
                childRegistry.register(skill)
            }
        }
        return childRegistry
    }

    private func replacingSkillTool(in tools: [ToolProtocol], registry: SkillRegistry) -> [ToolProtocol] {
        let replacement = createSkillTool(registry: registry)
        var replaced = false
        let mapped = tools.map { tool -> ToolProtocol in
            guard tool.name == "Skill" else { return tool }
            replaced = true
            return replacement
        }
        return replaced ? mapped : tools
    }

    private func filterInheritedMcpTools(_ tools: [ToolProtocol], mcpServers: [AgentMcpServerSpec]?) -> [ToolProtocol] {
        guard let mcpServers else { return tools }
        let filters = mcpToolFilters(from: mcpServers)
        guard !filters.isEmpty else {
            return tools.filter { Self.mcpToolParts($0.name) == nil }
        }

        return tools.filter { tool in
            guard let parts = Self.mcpToolParts(tool.name) else { return true }
            guard let allowedTools = filters[parts.server] else { return false }
            guard let allowedTools else { return true }
            return allowedTools.contains(parts.tool) || allowedTools.contains(tool.name.lowercased())
        }
    }

    private func mcpToolFilters(from specs: [AgentMcpServerSpec]) -> [String: Set<String>?] {
        var filters: [String: Set<String>?] = [:]
        for spec in specs {
            switch spec {
            case .reference(let name):
                filters.updateValue(nil, forKey: name.lowercased())
            case .referenceWithTools(let name, let tools):
                if let tools, !tools.isEmpty {
                    filters.updateValue(Set(tools.map { $0.lowercased() }), forKey: name.lowercased())
                } else {
                    filters.updateValue(nil, forKey: name.lowercased())
                }
            case .inline:
                continue
            }
        }
        return filters
    }

    private func hasInheritedMcpTools(serverName: String) -> Bool {
        let normalized = serverName.lowercased()
        return parentTools.contains { tool in
            Self.mcpToolParts(tool.name)?.server == normalized
        }
    }

    private static func mcpToolParts(_ toolName: String) -> (server: String, tool: String)? {
        guard toolName.hasPrefix("mcp__") else { return nil }
        let parts = toolName.components(separatedBy: "__")
        guard parts.count == 3, parts[0] == "mcp" else { return nil }
        let server = parts[1].lowercased()
        let tool = parts[2].lowercased()
        guard !server.isEmpty, !tool.isEmpty else { return nil }
        return (server, tool)
    }

    /// Collect runtime diagnostics for subagent fields that the schema accepts but the
    /// SDK does not fully wire (Story 29.6).
    ///
    /// Pure synchronous function (no throws/async) so it is trivially testable.
    /// Emits a diagnostic only when the caller actually opted into a deferred behavior:
    ///   - `run_in_background` truthy check is `== true` (a literal `false` is NOT deferred)
    ///   - string fields use a non-empty check (`""` is NOT deferred)
    ///   - each `.reference` MCP spec emits its own diagnostic (no dedup) so observers
    ///     see every unresolved reference
    ///
    /// Appends in a FIXED deterministic order so downstream assertions are stable (AC5):
    /// `run_in_background` → `resume` → `isolation` → `team_name` →
    /// `mcp_server_reference`. Returns an empty array when nothing is deferred; the caller
    /// decides whether to coerce `[]` → `nil` (AC8).
    private func collectFieldDiagnostics(
        runInBackground: Bool?,
        isolation: String?,
        teamName: String?,
        resume: String?,
        unresolvedMcpReferences: [String]
    ) -> [SubAgentFieldDiagnostics] {
        var diags: [SubAgentFieldDiagnostics] = []

        // 1. run_in_background (truthy only — `false` is an explicit foreground request)
        if let runInBackground, runInBackground {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "run_in_background",
                rawValue: String(runInBackground),
                reason: .backgroundExecutionNotImplemented
            ))
        }
        // 2. resume (non-empty ID)
        if let resume, !resume.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "resume",
                rawValue: resume,
                reason: .resumeNotImplemented
            ))
        }
        // 3. isolation (non-empty mode string)
        if let isolation, !isolation.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "isolation",
                rawValue: isolation,
                reason: .isolationNotImplemented
            ))
        }
        // 4. team_name (non-empty)
        if let teamName, !teamName.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "team_name",
                rawValue: teamName,
                reason: .teamCoordinationNotImplemented
            ))
        }
        // 5. mcp_server_reference — only unresolved references emit diagnostics.
        for name in unresolvedMcpReferences {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "mcp_server_reference",
                rawValue: name,
                reason: .mcpReferenceResolutionDeferred
            ))
        }

        return diags
    }

    /// Filter parent tools: strip subagent launcher tools (``SubAgentLauncherNames.default``)
    /// and apply allowed/disallowed lists.
    ///
    /// Default behavior strips BOTH `Agent` and `Task` so that a child cannot recursively
    /// spawn grandchildren without explicit host opt-in. See Story 29.2 AC5.
    ///
    /// Story 29.5: allowed/disallowed matching is delegated to the shared
    /// `filterToolsByDeclarations` helper (via `ToolDeclaration.fromToolNames`) so that
    /// subagent `tools`/`disallowedTools` use the same matching rules as skill
    /// `allowed-tools` (lowercased base-name match; MCP names work without an enum case;
    /// `Bash(git diff:*)` matches by base name; declared-but-missing tools surface in
    /// diagnostics and NEVER fall back to unrestricted). Launcher stripping stays here —
    /// the helper is single-responsibility and does not strip launchers.
    private func filterTools(allowedTools: [String]?, disallowedTools: [String]?) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics) {
        let allowedDeclarations = toolDeclarations(from: allowedTools)
        let disallowedDeclarations = toolDeclarations(from: disallowedTools)

        return filterTools(
            allowedDeclarations: allowedDeclarations,
            disallowedDeclarations: disallowedDeclarations
        )
    }

    private func filterTools(
        allowedDeclarations: [ToolDeclaration]?,
        disallowedDeclarations: [ToolDeclaration]?
    ) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics) {
        // Strip all subagent launcher tools by default to prevent recursive spawning.
        // Escape hatch (explicit recursion-allowed config) is deferred to a future story;
        // current default MUST remain "strip both" per Story 29.2 AC5.
        let launcherStripped = parentTools.filter { !SubAgentLauncherNames.contains($0.name) }

        return filterToolsByDeclarations(
            available: launcherStripped,
            allowed: allowedDeclarations,
            disallowed: disallowedDeclarations
        )
    }

    private func toolDeclarations(from toolNames: [String]?) -> [ToolDeclaration]? {
        guard let toolNames, !toolNames.isEmpty else { return nil }
        let declarations = ToolDeclaration.fromToolNames(toolNames)
        return declarations.isEmpty ? nil : declarations
    }

    /// Test-only thin wrapper around the private ``filterTools`` so unit tests can assert
    /// the filtering contract directly without driving a full `spawn` round-trip.
    ///
    /// Project rule #22 (prefer `internal`) makes this safe: `@testable import OpenAgentSDK`
    /// already has internal access; this adds only a one-line indirection, no new behavior.
    internal func filterToolsForTesting(allowedTools: [String]?, disallowedTools: [String]?) -> [ToolProtocol] {
        return filterTools(allowedTools: allowedTools, disallowedTools: disallowedTools).filtered
    }

    /// Story 29.5: test-only wrapper exposing the full `(filtered, diagnostics)`
    /// tuple. The existing ``filterToolsForTesting`` keeps its `[ToolProtocol]`
    /// return type so Story 29.2 regression tests compile unchanged; this new
    /// entry point lets 29.5 tests assert diagnostics directly.
    internal func filterToolsWithDiagnosticsForTesting(allowedTools: [String]?, disallowedTools: [String]?) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics) {
        return filterTools(allowedTools: allowedTools, disallowedTools: disallowedTools)
    }

    /// Create an Agent with the given options, execute its prompt, and return a SubAgentResult.
    ///
    /// `fieldDiagnostics` (Story 29.6) is the deferred-field diagnostics collected BEFORE the
    /// agent runs. The agent's `QueryResult` does not carry them, so they are threaded in
    /// explicitly and merged into the returned `SubAgentResult`.
    private func executeAgent(
        prompt: String,
        options: AgentOptions,
        fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil
    ) async -> SubAgentResult {
        let agent: Agent
        if let client = client {
            agent = Agent(options: options, client: client)
        } else {
            agent = Agent(options: options)
        }

        let result = await agent.prompt(prompt)
        return Self.mapQueryResultToSubAgentResult(result, fieldDiagnostics: fieldDiagnostics)
    }

    /// Maps a child agent's ``QueryResult`` to a ``SubAgentResult``.
    ///
    /// Extracted as an `internal static` so the tool-name extraction can be unit-tested
    /// directly without driving a full LLM round-trip (project rule #27: no real I/O in
    /// unit tests).
    ///
    /// Previously this dropped `QueryResult.toolPairs` and returned a hard-coded empty
    /// `toolCalls`, which made the parent's `[Tools used: ...]` summary — added in the
    /// shared subagent launcher factory (Story 29.1) — never appear for real spawns. The
    /// `AgentTool`/`TaskTool` mock-spawner tests gave false confidence because they
    /// injected `toolCalls` by hand. Surfacing the tools the sub-agent actually invoked
    /// lets the `Task` alias deliver its Claude Code-compatible contract.
    ///
    /// Story 29.6: the optional `fieldDiagnostics` parameter lets callers (notably
    /// ``executeAgent(prompt:options:fieldDiagnostics:)``) thread deferred-field
    /// diagnostics collected before the LLM call into the resulting `SubAgentResult`.
    /// Defaults to `nil` to keep existing single-arg call sites compiling (AC9).
    internal static func mapQueryResultToSubAgentResult(
        _ result: QueryResult,
        fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil
    ) -> SubAgentResult {
        let text = result.text.isEmpty
            ? "(Subagent completed with no text output)"
            : result.text
        // Preserve invocation order; keep duplicates so reviewers see repeat calls too.
        let toolNames = result.toolPairs.map { $0.toolUse.toolName }
        return SubAgentResult(
            text: text,
            toolCalls: toolNames,
            isError: result.status != .success,
            fieldDiagnostics: fieldDiagnostics
        )
    }
}
