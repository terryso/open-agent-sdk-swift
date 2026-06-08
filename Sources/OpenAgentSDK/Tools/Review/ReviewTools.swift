import Foundation

/// Builds a JSON error response string for review tools.
///
/// Convenience wrapper around ``reviewJSONResponse(_:)`` for the common error pattern
/// used by all review tool guard clauses and error paths.
///
/// - Parameter message: The error description.
/// - Returns: A JSON string like `{"success":false,"error":"message"}`.
func reviewErrorResponse(_ message: String) -> String {
    reviewJSONResponse(["success": false, "error": message] as [String: Any])
}

/// Validates that a string input is non-empty after trimming whitespace.
///
/// Used by all review tools for the common "field must not be empty" guard pattern.
/// Returns the error response string if the value is empty, or nil if valid.
///
/// - Parameters:
///   - value: The input string to validate.
///   - field: The field name for the error message (e.g., "name", "skillName").
/// - Returns: An error response string if empty, or nil if valid.
func requireNonEmptyInput(_ value: String, field: String) -> String? {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return reviewErrorResponse("'\(field)' must not be empty")
    }
    return nil
}

/// Builds a JSON response string using JSONSerialization for safe encoding of user-provided values.
func reviewJSONResponse(_ fields: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: fields),
          let result = String(data: data, encoding: .utf8) else {
        return "{\"success\": false, \"error\": \"JSON encoding failed\"}"
    }
    return result
}

// MARK: - createReviewTools

/// Creates all five review tools for injection into a forked review agent.
///
/// This is the single entry point for `ReviewOrchestrator` (Story 24.3) to
/// create the tool set and pass it into the review Agent.
///
/// - Parameters:
///   - factStore: The fact store for saving memory facts.
///   - skillRegistry: The registry for skill lookups, registration, and replacement.
///   - skillEvolver: The evolver for applying skill updates.
///   - usageStore: The store for reading/writing skill usage data (used by CuratorArchiveTool).
///   - skillsDir: Root directory for skill persistence (e.g., `~/.axion/skills`).
/// - Returns: An array of five `ToolProtocol` instances: review_save_memory,
///   review_update_skill, review_create_skill, review_add_skill_file, and
///   curator_archive_skill.
public func createReviewTools(
    factStore: FactStore,
    skillRegistry: SkillRegistry,
    skillEvolver: any SkillEvolver,
    usageStore: SkillUsageStore,
    skillsDir: String
) -> [ToolProtocol] {
    [
        createReviewMemoryTool(factStore: factStore),
        createReviewSkillUpdateTool(skillRegistry: skillRegistry, skillEvolver: skillEvolver, skillsDir: skillsDir),
        createReviewSkillCreateTool(skillRegistry: skillRegistry, usageStore: usageStore, skillsDir: skillsDir),
        createReviewSkillFileTool(skillRegistry: skillRegistry, skillsDir: skillsDir),
        createCuratorArchiveTool(skillRegistry: skillRegistry, usageStore: usageStore, skillsDir: skillsDir),
    ]
}
