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

    init(
        apiKey: String,
        baseURL: String?,
        parentModel: String,
        parentTools: [ToolProtocol],
        provider: LLMProvider = .anthropic,
        client: (any LLMClient)? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.parentModel = parentModel
        self.parentTools = parentTools
        self.provider = provider
        self.client = client
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
        let subTools = filterTools(allowedTools: allowedTools, disallowedTools: disallowedTools).filtered

        // 2. Resolve MCP servers from spec (reference lookup or inline)
        var resolvedMcpServers: [String: McpServerConfig] = [:]
        if let mcpServers {
            for spec in mcpServers {
                switch spec {
                case .reference:
                    // Reference lookup would require parent MCP config access.
                    // For now, references are stored but not resolved at runtime.
                    // Full runtime wiring is deferred to a future story.
                    break
                case .inline(let config):
                    // Use a deterministic key for inline configs
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
            tools: subTools.isEmpty ? nil : subTools
        )

        if !resolvedMcpServers.isEmpty { options.mcpServers = resolvedMcpServers }
        if let mode { options.permissionMode = mode }
        if let name { options.agentName = name }

        // Note: skills, runInBackground, isolation, teamName, and resume
        // are declared fields but full runtime wiring is deferred.

        // 3.5 Collect deferred-field diagnostics (Story 29.6). Surfaced on
        // SubAgentResult.fieldDiagnostics so callers can tell which fields the
        // SDK honored vs ignored. Does NOT change runtime behavior — the agent
        // still runs in the foreground, is not resumed, is not isolated, etc.
        let collectedDiagnostics = collectFieldDiagnostics(
            runInBackground: runInBackground,
            isolation: isolation,
            teamName: teamName,
            skills: skills,
            resume: resume,
            mcpServers: mcpServers
        )

        // 4. Execute and collect result
        // AC8: when nothing was collected, pass `nil` (not an empty array) so
        // downstream consumers can distinguish "no signal" from "signal ran but empty".
        let fieldDiagnosticsToPropagate: [SubAgentFieldDiagnostics]? =
            collectedDiagnostics.isEmpty ? nil : collectedDiagnostics
        return await executeAgent(prompt: prompt, options: options, fieldDiagnostics: fieldDiagnosticsToPropagate)
    }

    // MARK: - Private

    /// Collect runtime diagnostics for subagent fields that the schema accepts but the
    /// SDK does not fully wire (Story 29.6).
    ///
    /// Pure synchronous function (no throws/async) so it is trivially testable.
    /// Emits a diagnostic only when the caller actually opted into a deferred behavior:
    ///   - `run_in_background` truthy check is `== true` (a literal `false` is NOT deferred)
    ///   - string fields use a non-empty check (`""` is NOT deferred)
    ///   - `skills` uses a non-empty-array check (`[]` is NOT deferred)
    ///   - each `.reference` MCP spec emits its own diagnostic (no dedup) so observers
    ///     see every unresolved reference
    ///
    /// Appends in a FIXED deterministic order so downstream assertions are stable (AC5):
    /// `run_in_background` → `resume` → `isolation` → `team_name` → `skills` →
    /// `mcp_server_reference`. Returns an empty array when nothing is deferred; the caller
    /// decides whether to coerce `[]` → `nil` (AC8).
    private func collectFieldDiagnostics(
        runInBackground: Bool?,
        isolation: String?,
        teamName: String?,
        skills: [String]?,
        resume: String?,
        mcpServers: [AgentMcpServerSpec]?
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
        // 5. skills (non-empty array; comma-joined in order, no surrounding whitespace)
        if let skills, !skills.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "skills",
                rawValue: skills.joined(separator: ","),
                reason: .skillsWiringDeferred
            ))
        }
        // 6. mcp_server_reference — each `.reference` emits its own diagnostic (no dedup)
        if let mcpServers {
            for spec in mcpServers {
                if case .reference(let name) = spec {
                    diags.append(SubAgentFieldDiagnostics(
                        fieldName: "mcp_server_reference",
                        rawValue: name,
                        reason: .mcpReferenceResolutionDeferred
                    ))
                }
                // `.inline` configs ARE wired into the child agent's MCP config today,
                // so they never produce a diagnostic.
            }
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
        // Strip all subagent launcher tools by default to prevent recursive spawning.
        // Escape hatch (explicit recursion-allowed config) is deferred to a future story;
        // current default MUST remain "strip both" per Story 29.2 AC5.
        let launcherStripped = parentTools.filter { !SubAgentLauncherNames.contains($0.name) }

        // Convert the Claude Code-style `[String]?` inputs to declarations. `nil`/empty
        // stays `nil` so the helper treats it as "no constraint" (not "allow nothing").
        let allowedDeclarations: [ToolDeclaration]? = {
            guard let allowedTools, !allowedTools.isEmpty else { return nil }
            return ToolDeclaration.fromToolNames(allowedTools)
        }()
        let disallowedDeclarations: [ToolDeclaration]? = {
            guard let disallowedTools, !disallowedTools.isEmpty else { return nil }
            return ToolDeclaration.fromToolNames(disallowedTools)
        }()

        return filterToolsByDeclarations(
            available: launcherStripped,
            allowed: allowedDeclarations,
            disallowed: disallowedDeclarations
        )
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
