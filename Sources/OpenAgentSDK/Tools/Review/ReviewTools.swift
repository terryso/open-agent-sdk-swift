import Foundation

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
