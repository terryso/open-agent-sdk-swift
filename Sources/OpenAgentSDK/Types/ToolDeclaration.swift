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
    /// `"mcp__github__list_prs"` (MCP full names are lowercased but never
    /// truncated), `"websearch"`.
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

// MARK: - Single-token parser (Story 29.5)

/// Story 29.5 lifts the parsing logic previously held privately in
/// `SkillLoader` up to the `ToolDeclaration` type itself, so that both
/// `SkillLoader.parseToolDeclarations` (frontmatter comma-list form) and the
/// new `ToolDeclaration.fromToolNames(_:)` (subagent `[String]` form) share one
/// tokenizer. This keeps `ToolDeclaration` a self-contained "declaration +
/// parse + filter" module (Epic 29 module-location decision).
extension ToolDeclaration {

    /// Parses a single frontmatter / subagent tool-name token into a
    /// `ToolDeclaration`.
    ///
    /// Handles three shapes (mirrors `SkillLoader.tokenizeToolDeclaration`):
    /// 1. MCP namespaced: `mcp__<server>__<tool>` → `.recognizedMCP`
    /// 2. Pattern form: `Bash(git diff:*)` → split base/pattern, classify base
    /// 3. Plain name: `Read` / `Task` / `UnknownTool` → classify by lookup
    ///
    /// - Parameter token: A single trimmed tool-name fragment (no surrounding
    ///   commas or whitespace).
    /// - Returns: A classified `ToolDeclaration`.
    public static func parse(_ token: String) -> ToolDeclaration {
        let rawName = token

        // Split base name and optional `(...)` pattern BEFORE the MCP check so
        // that an MCP name with a trailing pattern (`mcp__github__list_prs(extra)`)
        // is classified against its bare namespaced base.
        let (baseName, pattern) = ToolDeclaration.splitBaseAndPattern(token)

        // Detect MCP namespaced form against the base name (pattern already split off).
        if ToolDeclaration.isMCPNamespacedName(baseName) {
            // Story 29.5 review: `MCPToolDefinition.name` is `mcp__{server}__{tool}`
            // with server/tool casing preserved verbatim from the MCP server, and
            // `filterToolsByDeclarations` compares against `tool.name.lowercased()`.
            // To keep matching case-insensitive (consistent with the legacy
            // `ToolRegistry.filterTools` and the SDK/unknown branches below), we
            // lowercase the MCP name here too. The original case is still
            // recoverable via `rawName`.
            return ToolDeclaration(
                rawName: rawName,
                normalizedName: baseName.lowercased(),
                pattern: pattern,
                status: .recognizedMCP,
                toolRestriction: nil
            )
        }

        let lowercasedBase = baseName.lowercased()

        // Recognized Claude Code LLM-facing name? (may or may not have enum case)
        if let restriction = ToolDeclaration.restrictionForLowercasedName(lowercasedBase) {
            return ToolDeclaration(
                rawName: rawName,
                normalizedName: lowercasedBase,
                pattern: pattern,
                status: .recognizedSDK,
                toolRestriction: restriction
            )
        }

        // Known Claude Code name without an enum case (e.g. `Task`).
        if ToolDeclaration.isKnownClaudeCodeName(lowercasedBase) {
            return ToolDeclaration(
                rawName: rawName,
                normalizedName: lowercasedBase,
                pattern: pattern,
                status: .recognizedSDK,
                toolRestriction: nil
            )
        }

        // Unresolvable — still recorded (non-nil tuple) so caller does not
        // treat the skill as unrestricted.
        return ToolDeclaration(
            rawName: rawName,
            normalizedName: lowercasedBase,
            pattern: pattern,
            status: .unknown,
            toolRestriction: nil
        )
    }

    /// Builds `[ToolDeclaration]` from a list of tool-name strings (the shape a
    /// subagent `allowed_tools: [...]` fragment arrives in). One declaration is
    /// produced per non-empty, non-whitespace input name, preserving order.
    /// Empty/whitespace entries are skipped so they do not surface as phantom
    /// `.unknown` diagnostics. Empty input yields an empty array (never nil).
    public static func fromToolNames(_ names: [String]) -> [ToolDeclaration] {
        return names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ToolDeclaration.parse($0) }
    }

    // MARK: File-private tokenizer helpers (lifted from SkillLoader, Story 29.5)

    /// Returns `true` when `name` matches the MCP namespaced convention
    /// `mcp__<server>__<tool>` (server/tool names may not themselves contain
    /// `__`, per `MCPToolDefinition`'s precondition).
    private static func isMCPNamespacedName(_ name: String) -> Bool {
        guard name.hasPrefix("mcp__") else { return false }
        let afterPrefix = String(name.dropFirst("mcp__".count))
        // Must contain exactly one more `__` separator.
        let parts = afterPrefix.components(separatedBy: "__")
        guard parts.count == 2 else { return false }
        let server = parts[0]
        let tool = parts[1]
        return !server.isEmpty && !tool.isEmpty
    }

    /// Splits a token into `(baseName, pattern)`. For `Bash(git diff:*)` →
    /// `("Bash", "git diff:*")`. For `Read` → `("Read", nil)`.
    ///
    /// Edge cases handled (Story 29.4 review):
    /// - `Bash()` (empty parens) → `("Bash", nil)` — empty pattern is not real.
    /// - `Bash(` (unclosed paren) → `("Bash", nil)` — dangling `(` stripped from base.
    private static func splitBaseAndPattern(_ token: String) -> (base: String, pattern: String?) {
        guard let openParen = token.firstIndex(of: "(") else {
            // No opening paren at all — plain name.
            return (token, nil)
        }
        let base = String(token[..<openParen])
        // Need a closing paren at the end to treat the interior as a pattern.
        guard token.last == ")" else {
            // Unclosed paren (e.g. `Bash(git diff:*`). Strip the dangling `(` so
            // the base name stays recognizable, but record no pattern.
            return (base, nil)
        }
        let patternStart = token.index(after: openParen)
        let patternEnd = token.index(before: token.endIndex)
        guard patternStart < patternEnd else {
            // Empty parens `Bash()` — treat as no pattern.
            return (base, nil)
        }
        let pattern = String(token[patternStart..<patternEnd])
        return (base, pattern)
    }

    /// Lowercased name → ToolRestriction. Covers all enum cases the parser
    /// should recognize. Kept in sync with `ToolRestriction.allCases`.
    private static let restrictionByLowercasedName: [String: ToolRestriction] = {
        var map: [String: ToolRestriction] = [:]
        for restriction in ToolRestriction.allCases {
            map[restriction.rawValue.lowercased()] = restriction
        }
        return map
    }()

    /// Claude Code names recognized as SDK names but without an enum case
    /// (currently just `Task`, per the "ToolRestriction gap" design decision).
    private static let knownClaudeCodeOnly: Set<String> = ["task"]

    /// Lowercased set of all recognized Claude Code LLM-facing names.
    private static let knownLowercased: Set<String> = {
        var set = Set(restrictionByLowercasedName.keys)
        set.formUnion(knownClaudeCodeOnly)
        return set
    }()

    private static func restrictionForLowercasedName(_ lowercasedName: String) -> ToolRestriction? {
        restrictionByLowercasedName[lowercasedName]
    }

    private static func isKnownClaudeCodeName(_ lowercasedName: String) -> Bool {
        knownLowercased.contains(lowercasedName)
    }
}

// MARK: - ToolFilterOptions / ToolFilterDiagnostics (Story 29.5)

/// Minimal options bag for ``filterToolsByDeclarations``. Story 29.5 keeps this
/// intentionally small — the helper does NOT strip subagent launcher names
/// (that is the caller's responsibility, e.g. `DefaultSubAgentSpawner` strips
/// via `SubAgentLauncherNames` before calling the helper, preserving Story
/// 29.2's behavior). The helper has a single responsibility: allowed/disallowed
/// declaration matching against available tools.
public struct ToolFilterOptions: Sendable, Equatable {
    /// Creates an options bag. No configurable fields in Story 29.5 (kept for
    /// API stability and forward extension).
    public init() {}
}

/// Diagnostic carrier returned by ``filterToolsByDeclarations`` alongside the
/// filtered tool pool.
///
/// Mirrors the structure of `ToolDeclarationDiagnostics` but reflects
/// **runtime** filtering decisions (which declarations actually matched the
/// host's available tools) rather than parse-time classification.
///
/// - Note: Per Epic 29's "不静默放权" (never silently unrestricted) red line,
///   when an allowed declaration fails to match any available tool it is
///   surfaced here rather than collapsing the pool to unrestricted.
public struct ToolFilterDiagnostics: Sendable, Equatable {
    /// Declarations (from `allowed`) that did not match any available tool.
    /// This includes both `.unknown` status declarations with no host-registered
    /// custom tool by that name, and `.recognizedSDK` / `.recognizedMCP`
    /// declarations whose tool is simply not present in the available pool.
    public let unmatchedDeclarations: [ToolDeclaration]

    /// Declarations (from `allowed` + `disallowed`) carrying a non-nil `pattern`
    /// ("parsed but not enforced"). Fine-grained Bash pattern enforcement is a
    /// deferred epic item; this list lets hosts observe and warn.
    public let patternDeclarations: [ToolDeclaration]

    /// Creates a new diagnostics carrier.
    ///
    /// - Parameters:
    ///   - unmatchedDeclarations: Allowed declarations with no available match.
    ///   - patternDeclarations: Declarations carrying a non-nil pattern.
    public init(
        unmatchedDeclarations: [ToolDeclaration],
        patternDeclarations: [ToolDeclaration]
    ) {
        self.unmatchedDeclarations = unmatchedDeclarations
        self.patternDeclarations = patternDeclarations
    }
}

/// Filters an available tool pool against allowed / disallowed
/// `ToolDeclaration`s using lowercased base-name matching.
///
/// This is the shared helper introduced by Story 29.5 that unifies the
/// filtering rules used by:
///   1. **Direct skill execution** (`Skill.toolDeclarations` via
///      `Agent.executeSkill` / `executeSkillStream`).
///   2. **Spawned subagents** (`DefaultSubAgentSpawner.filterTools`, converting
///      the incoming `[String]?` via `ToolDeclaration.fromToolNames`).
///
/// Matching rules:
///   - For each available tool, `tool.name.lowercased()` is compared against the
///     declaration's `normalizedName` (which is already lowercased). This is
///     exact, case-insensitive matching after normalization — so `Bash(git
///     diff:*)` matches a tool named `Bash` (base name `bash`), and
///     `mcp__srv__search` matches an MCP tool without requiring a
///     `ToolRestriction` enum case.
///   - When `allowed` is `nil` or empty, the allow filter is a no-op (returns
///     all available tools).
///   - `disallowed` overrides `allowed` — a tool present in both is removed.
///
/// **Critical (Epic 29 "不静默放权" red line):** when `allowed` is non-empty,
/// the filtered result contains **only** matching tools. If every allowed
/// declaration is unmatched, the result is an **empty** pool plus diagnostics —
/// NEVER the full `available` set. Callers must inspect
/// `diagnostics.unmatchedDeclarations` to observe the mismatch.
///
/// - Important: This helper does NOT strip subagent launcher tools (`Agent` /
///   `Task`). Callers that need that behavior (e.g. `DefaultSubAgentSpawner`)
///   must strip them before calling.
///
/// - Parameters:
///   - available: The full tool pool the declarations are matched against.
///   - allowed: Optional allow-list of declarations. `nil` / empty = no allow
///     constraint.
///   - disallowed: Optional deny-list of declarations. `nil` / empty = no deny
///     constraint. Takes priority over `allowed`.
///   - options: Optional `ToolFilterOptions`. Currently unused; reserved for
///     future extension.
/// - Returns: A `(filtered, diagnostics)` tuple.
public func filterToolsByDeclarations(
    available: [ToolProtocol],
    allowed: [ToolDeclaration]?,
    disallowed: [ToolDeclaration]?,
    options: ToolFilterOptions? = nil
) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics) {
    _ = options ?? ToolFilterOptions()

    // Lowercased available tool names for matching (Array preserves order;
    // Set used internally only for O(1) lookup, project rule #46 for the result).
    let availableNormalizedNames = available.map { $0.name.lowercased() }
    let availableNameSet = Set(availableNormalizedNames)

    // 1. Apply allow filter.
    var filtered: [ToolProtocol]
    if let allowed, !allowed.isEmpty {
        let allowedNormalized = allowed.map { $0.normalizedName }
        let allowedSet = Set(allowedNormalized)
        filtered = available.filter { allowedSet.contains($0.name.lowercased()) }
    } else {
        filtered = available
    }

    // 2. Apply disallowed filter (priority over allowed).
    if let disallowed, !disallowed.isEmpty {
        let disallowedSet = Set(disallowed.map { $0.normalizedName })
        filtered = filtered.filter { !disallowedSet.contains($0.name.lowercased()) }
    }

    // 3. Build diagnostics.
    // unmatchedDeclarations: allowed declarations whose normalizedName does not
    // appear in available tool names.
    var unmatched: [ToolDeclaration] = []
    if let allowed, !allowed.isEmpty {
        for declaration in allowed {
            if !availableNameSet.contains(declaration.normalizedName) {
                unmatched.append(declaration)
            }
        }
    }

    // patternDeclarations: declarations (allowed + disallowed) carrying a non-nil
    // pattern, preserving order, de-duplicated by rawName to avoid double-counting
    // the same declaration appearing in both lists.
    var patternDecls: [ToolDeclaration] = []
    var seenPatternRawNames = Set<String>()
    let sources = (allowed ?? []) + (disallowed ?? [])
    for declaration in sources {
        guard declaration.pattern != nil else { continue }
        if seenPatternRawNames.contains(declaration.rawName) { continue }
        seenPatternRawNames.insert(declaration.rawName)
        patternDecls.append(declaration)
    }

    let diagnostics = ToolFilterDiagnostics(
        unmatchedDeclarations: unmatched,
        patternDeclarations: patternDecls
    )

    return (filtered, diagnostics)
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
