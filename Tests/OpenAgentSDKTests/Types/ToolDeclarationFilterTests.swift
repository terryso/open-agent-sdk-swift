import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - ToolDeclarationFilterTests (Story 29.5)

/// ATDD RED PHASE: Tests for Story 29.5 -- the reusable `filterToolsByDeclarations`
/// helper, `ToolFilterDiagnostics` carrier, and `ToolDeclaration.fromToolNames(_:)`
/// convenience constructor, all to be added in `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`.
///
/// Story 29.5 unifies the filtering rules used by **direct skills** (`allowed-tools`
/// frontmatter) and **spawned subagents** (`tools` / `disallowedTools`) behind a single
/// declaration-based matcher, so that the same declaration means the same thing in both
/// consumption paths. The helper is a pure function (no I/O, no actor, no global state —
/// project-context.md #27) that:
///
///   1. Matches `available` tools against `allowed` / `disallowed` `ToolDeclaration`s
///      using lowercased, base-name comparison (so `Bash(git diff:*)` still matches a
///      tool named `Bash`, and `mcp__srv__search` matches an MCP tool without requiring
///      a `ToolRestriction` enum case).
///   2. Returns a `ToolFilterDiagnostics` carrying unmatched declarations (declared but
///      no available tool matched) and pattern declarations (parsed but not enforced).
///   3. **Never** falls back to "unrestricted" when `allowed` is non-empty — even if
///      every declaration is unmatched, the filtered result is an empty pool, not the
///      full `available` set (Epic 29 "不静默放权" red line).
///
/// All tests below assert EXPECTED behavior. They will FAIL until:
///   - `public struct ToolFilterDiagnostics: Sendable, Equatable` exists in
///     `Sources/OpenAgentSDK/Types/ToolDeclaration.swift` with fields
///     `unmatchedDeclarations: [ToolDeclaration]` and `patternDeclarations: [ToolDeclaration]`.
///   - `public struct ToolFilterOptions: Sendable, Equatable` exists (minimal).
///   - `public func filterToolsByDeclarations(available:allowed:disallowed:options:)`
///     exists in the same file.
///   - `public static func ToolDeclaration.fromToolNames(_:) -> [ToolDeclaration]`
///     exists (and the supporting `ToolDeclaration.parse(_:)` single-token parser that
///     Story 29.5 Task 5 lifts out of `SkillLoader`).
///   - `public static func ToolDeclaration.parse(_ name: String) -> ToolDeclaration`
///     exists (single-token parser lifted from SkillLoader.tokenizeToolDeclaration).
///
/// TDD Phase: RED (feature not implemented yet)
///
/// Red mode: COMPILE-TIME — the new free function, structs, and static methods are not
/// yet defined, so this file fails to compile with `Cannot find '...' in scope`.
/// This is the expected TDD red phase; green-phase implementation makes them compile
/// and pass.
final class ToolDeclarationFilterTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal `ToolProtocol` with a fixed name, used to populate the
    /// `available` tool pool without pulling in real tool side effects.
    ///
    /// Pure helper: no network, filesystem, or shell interaction.
    private func makeTool(name: String) -> ToolProtocol {
        return defineTool(
            name: name,
            description: "stub tool for filter test",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { _, _ in
            ToolExecuteResult(content: "stub", isError: false)
        }
    }

    /// Convenience: builds a tool and wraps it in a single-element array.
    private func makeTools(_ names: String...) -> [ToolProtocol] {
        return names.map { makeTool(name: $0) }
    }

    // MARK: AC1 — Helper 函数存在并位于正确模块

    /// AC1 [P0]: `ToolFilterDiagnostics` is a public Sendable+Equatable struct with the
    /// two required fields. Verifies the carrier type compiles and is constructible.
    func testToolFilterDiagnostics_isPublicEquatableStruct() {
        let empty = ToolFilterDiagnostics(
            unmatchedDeclarations: [],
            patternDeclarations: []
        )
        XCTAssertEqual(empty.unmatchedDeclarations, [], "Empty init must produce empty arrays")
        XCTAssertEqual(empty.patternDeclarations, [], "Empty init must produce empty arrays")
        XCTAssertEqual(empty, ToolFilterDiagnostics(unmatchedDeclarations: [], patternDeclarations: []),
                       "Equatable conformance must hold for equal instances")
    }

    /// AC1 [P0]: `filterToolsByDeclarations` exists, is callable, and returns a tuple
    /// whose `filtered` and `diagnostics` members are accessible. Sanity-shape test.
    func testFilterToolsByDeclarations_callableAndReturnsTuple() {
        let available = makeTools("Bash", "Read")
        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: nil,
            disallowed: nil
        )
        XCTAssertEqual(filtered.count, 2, "nil allowed must return all available tools")
        XCTAssertEqual(diagnostics.unmatchedDeclarations.count, 0)
        XCTAssertEqual(diagnostics.patternDeclarations.count, 0)
    }

    /// AC1 [P0]: `ToolFilterOptions` exists and has a no-argument default initializer.
    func testToolFilterOptions_hasDefaultInit() {
        let opts = ToolFilterOptions()
        // Options is minimal in this story; existence + default init is the contract.
        XCTAssertEqual(opts, ToolFilterOptions(), "ToolFilterOptions default init must be Equatable-stable")
    }

    // MARK: AC2 — 子代理工具池按 declarations 过滤（匹配规则核心）

    /// AC2 [P0]: allowed declarations preserve only matching tools; unmatched declared
    /// names surface in diagnostics. `Read` matches an available tool, `Grep` does not.
    func testFilter_preservesOnlyAllowedTools() {
        let available = makeTools("Bash", "Read", "Write")
        let allowed: [ToolDeclaration] = [
            ToolDeclaration.parse("Read"),
            ToolDeclaration.parse("Grep"),
        ]

        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: nil
        )

        let names = filtered.map { $0.name }
        XCTAssertEqual(names, ["Read"], "Only Read matches; Bash/Write must be filtered out")
        XCTAssertEqual(
            diagnostics.unmatchedDeclarations.map(\.rawName),
            ["Grep"],
            "Grep was declared but no available tool matched -> must surface as unmatched"
        )
    }

    /// AC2 [P0]: Filtering is case-insensitive — a tool named `Bash` matches a
    /// declaration `bash`. Fixes the case-sensitivity bug in the legacy
    /// `DefaultSubAgentSpawner.filterTools` Set-based matcher.
    func testFilter_caseInsensitive() {
        let available = makeTools("Bash")
        let allowed: [ToolDeclaration] = [ToolDeclaration.parse("bash")]

        let (filtered, _) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: nil
        )

        XCTAssertEqual(filtered.map { $0.name }, ["Bash"],
                       "Lowercased declaration must match an uppercased tool name")
    }

    // MARK: AC3 — MCP 工具声明匹配无需 enum case

    /// AC3 [P0]: An MCP namespaced declaration (`mcp__srv__search`) matches an available
    /// MCP-named tool **without** requiring a `ToolRestriction` enum case. The
    /// declaration's `toolRestriction` is `nil` but it is still matched.
    func testFilter_mcpDeclaration_matchesWithoutEnumCase() {
        let available = makeTools("mcp__srv__search")
        let allowed: [ToolDeclaration] = [ToolDeclaration.parse("mcp__srv__search")]

        // Sanity: the parsed MCP declaration must NOT map to an enum case.
        XCTAssertEqual(allowed.first?.status, .recognizedMCP,
                       "MCP declaration must parse as .recognizedMCP")
        XCTAssertNil(allowed.first?.toolRestriction,
                     "MCP declaration must have nil toolRestriction (no enum case)")

        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: nil
        )

        XCTAssertEqual(filtered.map { $0.name }, ["mcp__srv__search"],
                       "MCP tool must be retained when declared and available")
        XCTAssertTrue(diagnostics.unmatchedDeclarations.isEmpty,
                      "Matched MCP declaration must NOT appear in unmatchedDeclarations")
    }

    // MARK: AC4 — 声明了但无可用工具 → diagnostics，绝不 unrestricted

    /// AC4 [P0]: A declared-but-unavailable tool (`PhantomTool`) surfaces in
    /// `unmatchedDeclarations` and the filtered pool is **empty** — never the full
    /// available set. This is the Epic 29 "不静默放权" red line.
    func testFilter_unknownDeclaration_notUnrestricted() {
        let available = makeTools("Bash", "Read")
        let allowed: [ToolDeclaration] = [ToolDeclaration.parse("PhantomTool")]

        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: nil
        )

        XCTAssertTrue(filtered.isEmpty,
                      "Filtered pool must be empty when no declaration matches — never unrestricted")
        XCTAssertEqual(diagnostics.unmatchedDeclarations.map(\.rawName), ["PhantomTool"],
                       "PhantomTool must surface as unmatched so the host can observe it")
    }

    /// AC4 [P1]: When ALL allowed declarations are unmatched, the pool is still empty
    /// (not unrestricted). Stress test for the red line with multiple missing tools.
    func testFilter_allDeclarationsUnmatched_poolStillEmpty() {
        let available = makeTools("Bash", "Read", "Write")
        let allowed: [ToolDeclaration] = [
            ToolDeclaration.parse("Ghost"),
            ToolDeclaration.parse("Phantom"),
        ]

        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: nil
        )

        XCTAssertTrue(filtered.isEmpty, "All-unmatched allowed must yield empty pool, not full available")
        XCTAssertEqual(Set(diagnostics.unmatchedDeclarations.map(\.rawName)),
                       Set(["Ghost", "Phantom"]),
                       "Both unmatched declarations must surface")
    }

    // MARK: disallowed 优先级 + nil/empty 边界

    /// AC2 [P0]: disallowed overrides allowed — a tool present in both lists is removed.
    /// Mirrors the legacy `DefaultSubAgentSpawner.filterTools` precedence contract.
    func testFilter_disallowed_overridesAllowed() {
        let available = makeTools("Bash", "Read")
        let allowed: [ToolDeclaration] = [
            ToolDeclaration.parse("Bash"),
            ToolDeclaration.parse("Read"),
        ]
        let disallowed: [ToolDeclaration] = [ToolDeclaration.parse("Bash")]

        let (filtered, _) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: disallowed
        )

        XCTAssertEqual(filtered.map { $0.name }, ["Read"],
                       "disallowed must remove Bash even though it is also allowed")
    }

    /// AC2 [P0]: nil allowed returns the full available pool (no allow constraint).
    func testFilter_nilAllowed_returnsAll() {
        let available = makeTools("Bash", "Read")

        let (filtered, _) = filterToolsByDeclarations(
            available: available,
            allowed: nil,
            disallowed: nil
        )

        XCTAssertEqual(Set(filtered.map { $0.name }), Set(["Bash", "Read"]),
                       "nil allowed must be a no-op (return all available)")
    }

    /// AC2 [P1]: empty allowed array is treated the same as nil (no constraint).
    func testFilter_emptyAllowed_returnsAll() {
        let available = makeTools("Bash", "Read")

        let (filtered, _) = filterToolsByDeclarations(
            available: available,
            allowed: [],
            disallowed: nil
        )

        XCTAssertEqual(Set(filtered.map { $0.name }), Set(["Bash", "Read"]),
                       "Empty allowed must be equivalent to nil — not 'allow nothing'")
    }

    // MARK: Pattern 处理（不强制，仅诊断）

    /// AC2 + pattern [P0]: A pattern declaration `Bash(git diff:*)` matches an available
    /// tool by its base name `Bash`, and surfaces in `patternDeclarations` ("parsed but
    /// not enforced"). Pattern enforcement is a deferred epic item.
    func testFilter_patternDeclaration_matchesByBaseNameAndSurfacesInDiagnostics() {
        let available = makeTools("Bash")
        let allowed: [ToolDeclaration] = [ToolDeclaration.parse("Bash(git diff:*)")]

        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: allowed,
            disallowed: nil
        )

        XCTAssertEqual(filtered.map { $0.name }, ["Bash"],
                       "Pattern declaration must match available Bash by base name")
        XCTAssertEqual(diagnostics.patternDeclarations.count, 1,
                       "Pattern declaration must surface in patternDeclarations")
        XCTAssertEqual(diagnostics.patternDeclarations.first?.pattern, "git diff:*",
                       "Pattern text must be preserved in diagnostics")
    }

    // MARK: fromToolNames — 字符串列表 → 声明数组

    /// AC2 [P0]: `ToolDeclaration.fromToolNames(_:)` preserves order, pattern, and MCP
    /// classification across a mixed input list (mirrors the real subagent
    /// `allowed_tools: [...]` shape that arrives as `[String]`).
    func testFromToolNames_preservesOrderAndPatternAndMCP() {
        let names = ["Read", "Bash(git diff:*)", "mcp__srv__search"]
        let declarations = ToolDeclaration.fromToolNames(names)

        XCTAssertEqual(declarations.count, 3, "fromToolNames must produce one declaration per name")
        XCTAssertEqual(declarations.map(\.rawName), names,
                       "rawName order must match input order")
        XCTAssertEqual(declarations[0].normalizedName, "read")
        XCTAssertEqual(declarations[1].normalizedName, "bash")
        XCTAssertEqual(declarations[1].pattern, "git diff:*",
                       "Pattern must be preserved through fromToolNames")
        XCTAssertEqual(declarations[2].status, .recognizedMCP,
                       "MCP namespaced name must classify as .recognizedMCP")
    }

    /// AC2 [P1]: `fromToolNames([])` returns an empty array (never nil).
    func testFromToolNames_empty_returnsEmptyArray() {
        let declarations = ToolDeclaration.fromToolNames([])
        XCTAssertTrue(declarations.isEmpty, "Empty input must yield empty declaration array")
    }

    // MARK: Story 29.5 review — regression tests for fixes applied during code review

    /// Review fix (CRITICAL): an MCP declaration with mixed-case server/tool
    /// names must still match an available MCP tool whose name has different
    /// casing, because `filterToolsByDeclarations` lowercases available names.
    /// `MCPToolDefinition.name` preserves the original server/tool casing
    /// verbatim from the MCP server, so the declaration's `normalizedName`
    /// must also be lowercased for case-insensitive matching to hold.
    func testFilter_mcpDeclaration_mixedCase_matchesCaseInsensitive() {
        // Declaration uses mixed case (as a skill author might type it).
        let declaration = ToolDeclaration.parse("mcp__GitHub__ListPRs")
        XCTAssertEqual(declaration.status, .recognizedMCP,
                       "Mixed-case MCP name must still classify as .recognizedMCP")
        XCTAssertEqual(declaration.normalizedName, "mcp__github__listprs",
                       "MCP normalizedName must be lowercased to match the filter's lowercased available set")

        // Available tool name has different casing (typical: host registers with original case).
        let available = makeTools("mcp__github__listprs")

        let (filtered, diagnostics) = filterToolsByDeclarations(
            available: available,
            allowed: [declaration],
            disallowed: nil
        )

        XCTAssertEqual(filtered.map { $0.name }, ["mcp__github__listprs"],
                       "Mixed-case MCP declaration must match differently-cased available MCP tool")
        XCTAssertTrue(diagnostics.unmatchedDeclarations.isEmpty,
                      "Matched MCP declaration must not appear in unmatchedDeclarations")
    }

    /// Review fix (CRITICAL): cross-casing variant — declaration lowercased,
    /// available mixed-case. Both directions must work.
    func testFilter_mcpDeclaration_lowercasedDeclaration_matchesMixedCaseAvailable() {
        let declaration = ToolDeclaration.parse("mcp__github__listprs")
        let available = makeTools("mcp__GitHub__ListPRs")

        let (filtered, _) = filterToolsByDeclarations(
            available: available,
            allowed: [declaration],
            disallowed: nil
        )

        XCTAssertEqual(filtered.map { $0.name }, ["mcp__GitHub__ListPRs"],
                       "Lowercased MCP declaration must match mixed-case available MCP tool")
    }

    /// Review fix (HIGH): `fromToolNames` filters empty and whitespace-only
    /// entries so they do not produce phantom `.unknown` declarations that
    /// pollute `unmatchedDeclarations`.
    func testFromToolNames_skipsEmptyAndWhitespaceEntries() {
        let names = ["Read", "", "   ", "\t", "Write"]
        let declarations = ToolDeclaration.fromToolNames(names)

        XCTAssertEqual(declarations.map(\.rawName), ["Read", "Write"],
                       "Empty/whitespace-only entries must be skipped by fromToolNames")
        XCTAssertEqual(declarations.count, 2,
                       "Only non-empty entries must produce declarations")
    }

    /// Review fix (HIGH): `fromToolNames` trims surrounding whitespace from
    /// otherwise valid tokens (subagent `tools` lists from hosts may be sloppy).
    func testFromToolNames_trimsSurroundingWhitespace() {
        let names = ["  Read  ", "\tBash\t"]
        let declarations = ToolDeclaration.fromToolNames(names)

        XCTAssertEqual(declarations.map(\.rawName), ["Read", "Bash"],
                       "Surrounding whitespace must be trimmed before parsing")
        XCTAssertEqual(declarations[0].normalizedName, "read")
        XCTAssertEqual(declarations[1].normalizedName, "bash")
    }

    /// AC5 [P0]: `ToolDeclaration.parse(_:)` single-token parser classifies SDK names,
    /// MCP names, patterns, and unknown names. This is the unit lifted from SkillLoader
    /// by Task 5 so that both `parseToolDeclarations` and `fromToolNames` share one
    /// tokenizer.
    func testParse_singleToken_classifiesCorrectly() {
        // Recognized SDK name
        let bash = ToolDeclaration.parse("Bash")
        XCTAssertEqual(bash.normalizedName, "bash")
        XCTAssertEqual(bash.status, .recognizedSDK)
        XCTAssertNotNil(bash.toolRestriction)

        // Pattern form
        let patterned = ToolDeclaration.parse("Bash(git diff:*)")
        XCTAssertEqual(patterned.normalizedName, "bash")
        XCTAssertEqual(patterned.pattern, "git diff:*")

        // MCP namespaced
        let mcp = ToolDeclaration.parse("mcp__srv__search")
        XCTAssertEqual(mcp.status, .recognizedMCP)
        XCTAssertNil(mcp.toolRestriction)

        // Unknown
        let unknown = ToolDeclaration.parse("PhantomTool")
        XCTAssertEqual(unknown.status, .unknown)
        XCTAssertNil(unknown.toolRestriction)
    }
}
