import Foundation

// MARK: - ToolDeclarationStatus

/// Categorizes how a `ToolDeclaration` was recognized during parsing.
///
/// Story 29.4 introduces this richer status so that unknown tool names never
/// silently collapse to "unrestricted" (the legacy `Skill.toolRestrictions`
/// behavior). A declaration that cannot be mapped to the `ToolRestriction`
/// enum is still recorded with a `.unknown` status, allowing callers to
/// distinguish "explicitly declared but currently unresolvable" from
/// "no declaration at all" (which means unrestricted).
///
/// - Note: `.unknown` is **not** the same as unrestricted. It means "the
///   author explicitly named this tool, but the parser could not classify it
///   at parse time". At runtime, Story 29.5's filter may still match an
///   `.unknown` declaration against available (host-registered) tools.
public enum ToolDeclarationStatus: String, Sendable, Equatable {
    /// A built-in SDK / Claude Code LLM-facing tool name (e.g. `Bash`, `Read`,
    /// `WebSearch`, `Task`). May or may not have a corresponding
    /// `ToolRestriction` enum case (e.g. `Task` is recognized but has no enum
    /// case — see Dev Notes "ToolRestriction gap").
    case recognizedSDK

    /// An MCP namespaced tool following the `mcp__<server>__<tool>` convention
    /// (e.g. `mcp__github__list_prs`). The full namespaced name is preserved
    /// verbatim — it must not be truncated.
    case recognizedMCP

    /// A custom tool name registered by the host. Parse-time cannot distinguish
    /// "custom" from truly unknown names (the host registry is a runtime
    /// concern), so this status is reserved for future use; unresolvable names
    /// are marked `.unknown` until Story 29.5's filter reconciles them.
    case recognizedCustom

    /// The name could not be classified at parse time. It is still recorded as
    /// an explicit declaration (non-nil) so callers do not treat it as
    /// unrestricted.
    case unknown
}

// MARK: - ToolDeclaration

/// A richer, lossless representation of a single tool declaration parsed from
/// a skill's `allowed-tools` frontmatter value.
///
/// Story 29.4 introduces this model to preserve information that the legacy
/// `ToolRestriction`-only parser (`SkillLoader.parseAllowedTools`) discards:
///
/// - Raw MCP namespaced names (`mcp__github__list_prs`)
/// - Permission pattern text (`Bash(git diff:*)` — the `git diff:*` part)
/// - Unknown / custom tool names (so they never collapse to unrestricted)
///
/// Each declaration records both the original frontmatter fragment (`rawName`)
/// and a normalized form (`normalizedName`) for case-insensitive matching, plus
/// an optional `pattern` and a back-reference to the matching
/// `ToolRestriction` enum case when one exists (for backward compatibility
/// with `Skill.toolRestrictions`).
///
/// - Important: This model only describes declarations. Filtering based on it
///   is implemented in Story 29.5 (`filterToolsByDeclarations`).
public struct ToolDeclaration: Sendable, Equatable {
    /// The original frontmatter fragment, verbatim. Examples:
    /// `"mcp__github__list_prs"`, `"Bash(git diff:*)"`, `"WebSearch"`.
    public let rawName: String

    /// Lowercased, bracket-stripped base name used for case-insensitive
    /// matching. Examples: `"bash"` (from `Bash(git diff:*)`),
    /// `"mcp__github__list_prs"` (MCP full names are already normalized —
    /// never truncated), `"websearch"`.
    public let normalizedName: String

    /// The argument permission pattern captured from a `Tool(...)` form, when
    /// present. Example: `"git diff:*"` from `Bash(git diff:*)`. `nil` when
    /// the declaration has no parenthesized pattern.
    ///
    /// - Note: Patterns are preserved but **not enforced** at this layer
    ///   (fine-grained Bash pattern enforcement is a deferred epic item).
    ///   Diagnostics surface them via `ToolDeclarationDiagnostics.patternDeclarations`.
    public let pattern: String?

    /// How this declaration was classified at parse time.
    public let status: ToolDeclarationStatus

    /// The matching `ToolRestriction` enum case, when the base name maps to
    /// one. `nil` for MCP tools, unknown names, and `Task` (which is a
    /// recognized Claude Code name but has no enum case — see Dev Notes
    /// "ToolRestriction gap").
    ///
    /// Used to maintain backward compatibility with `Skill.toolRestrictions`.
    public let toolRestriction: ToolRestriction?

    /// Creates a new tool declaration.
    ///
    /// - Parameters:
    ///   - rawName: Original frontmatter fragment (e.g. `"Bash(git diff:*)"`).
    ///   - normalizedName: Lowercased, bracket-stripped base name (e.g. `"bash"`).
    ///   - pattern: Argument pattern captured from `Tool(...)`, or `nil`.
    ///   - status: How the declaration was classified at parse time.
    ///   - toolRestriction: Matching `ToolRestriction` enum case, or `nil`.
    public init(
        rawName: String,
        normalizedName: String,
        pattern: String?,
        status: ToolDeclarationStatus,
        toolRestriction: ToolRestriction?
    ) {
        self.rawName = rawName
        self.normalizedName = normalizedName
        self.pattern = pattern
        self.status = status
        self.toolRestriction = toolRestriction
    }
}

// MARK: - ToolDeclarationDiagnostics

/// Diagnostic carrier for a set of `ToolDeclaration`s, surfaced alongside the
/// declarations themselves so callers can observe information that the parser
/// preserved but cannot fully act on.
///
/// Story 29.4 introduces this as a sibling of the declarations array; Story
/// 29.5 will follow the same pattern with `ToolFilterDiagnostics` for runtime
/// filtering decisions.
public struct ToolDeclarationDiagnostics: Sendable, Equatable {
    /// Declarations whose `status == .unknown` — explicitly named by the skill
    /// author but unresolvable at parse time. These must **not** be treated as
    /// unrestricted; they are surfaced here so callers can warn or reconcile
    /// them against the host's available tools.
    public let unsupportedDeclarations: [ToolDeclaration]

    /// Declarations carrying a non-nil `pattern` (e.g. `Bash(git diff:*)`).
    /// The pattern text is preserved but **not enforced** at this layer —
    /// these surface the "parsed but not enforced" signal. Even a recognized
    /// SDK base name with a pattern appears here.
    public let patternDeclarations: [ToolDeclaration]

    /// Creates a new diagnostics carrier.
    ///
    /// - Parameters:
    ///   - unsupportedDeclarations: Declarations with `status == .unknown`.
    ///   - patternDeclarations: Declarations carrying a non-nil `pattern`.
    public init(
        unsupportedDeclarations: [ToolDeclaration],
        patternDeclarations: [ToolDeclaration]
    ) {
        self.unsupportedDeclarations = unsupportedDeclarations
        self.patternDeclarations = patternDeclarations
    }
}
