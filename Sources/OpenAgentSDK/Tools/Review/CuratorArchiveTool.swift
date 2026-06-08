import Foundation

// MARK: - CuratorArchiveInput

private struct CuratorArchiveInput: Codable {
    let skillName: String
    let absorbedInto: String?
}

// MARK: - createCuratorArchiveTool

/// Creates the `curator_archive_skill` tool for the curator agent.
///
/// Archives a skill by moving its directory to `.archived/` and unregistering it from
/// the skill registry. Records the merge relationship in `SkillUsageData.absorbedInto`.
/// Only agent-created skills that are not pinned may be archived.
///
/// If the skill's `baseDir` is outside `skillsDir` (e.g., `~/.claude/skills/`), falls
/// back to registry-level retirement without moving files.
///
/// - Parameters:
///   - skillRegistry: The registry to look up and unregister skills.
///   - usageStore: The store for reading/writing skill usage data.
///   - skillsDir: Root skills directory (e.g., `~/.axion/skills`).
/// - Returns: A `ToolProtocol` instance named `curator_archive_skill`.
public func createCuratorArchiveTool(
    skillRegistry: SkillRegistry,
    usageStore: SkillUsageStore,
    skillsDir: String
) -> ToolProtocol {
    defineTool(
        name: "curator_archive_skill",
        description: "Archive a skill by retiring it. Optionally record which umbrella skill absorbed its content. Only agent-created, non-pinned skills can be archived.",
        inputSchema: [
            "type": "object",
            "properties": [
                "skillName": ["type": "string", "description": "Name of the skill to archive"],
                "absorbedInto": ["type": "string", "description": "Optional name of the umbrella skill that absorbed this skill's content. Omit or empty for pruning with no merge target."]
            ],
            "required": ["skillName"]
        ]
    ) { (input: CuratorArchiveInput, _: ToolContext) async -> String in
        let skillName = input.skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let err = requireNonEmptyInput(skillName, field: "skillName") { return err }

        let usageData = await usageStore.getUsage(skillName: skillName)

        if usageData.provenance != .agentCreated {
            return reviewErrorResponse("Cannot archive non-agent-created skill")
        }

        if usageData.pinned {
            return reviewErrorResponse("Cannot archive pinned skill")
        }

        guard let skill = skillRegistry.find(skillName) else {
            return reviewErrorResponse("Skill '\(skillName)' not found")
        }

        let absorbedValue = input.absorbedInto?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAbsorbed = (absorbedValue?.isEmpty ?? true) ? nil : absorbedValue

        // Try to move directory to .archived/ if baseDir is under skillsDir
        var archivedViaMove = false
        if let baseDir = skill.baseDir, baseDir.hasPrefix(skillsDir) {
            let archivedDir = (skillsDir as NSString).appendingPathComponent(".archived")
            let destPath = (archivedDir as NSString).appendingPathComponent(skillName)

            do {
                try FileManager.default.createDirectory(
                    atPath: archivedDir,
                    withIntermediateDirectories: true
                )
                // Remove existing archived version if any
                if FileManager.default.fileExists(atPath: destPath) {
                    try FileManager.default.removeItem(atPath: destPath)
                }
                try FileManager.default.moveItem(atPath: baseDir, toPath: destPath)
                archivedViaMove = true
            } catch {
                // Fall through to registry-only retirement
            }
        }

        // Unregister from registry
        skillRegistry.unregister(skillName)

        // Update usage data
        var updatedData = usageData
        updatedData.absorbedInto = resolvedAbsorbed
        updatedData.lastManagedAt = Date()
        do {
            try await usageStore.setUsage(skillName: skillName, data: updatedData)
        } catch {
            return reviewErrorResponse("Failed to persist archive data: \(error.localizedDescription)")
        }

        return reviewJSONResponse([
            "success": true,
            "message": "Skill '\(skillName)' archived\(archivedViaMove ? " (moved to .archived/)" : " (registry only)")",
            "absorbedInto": resolvedAbsorbed as Any
        ] as [String: Any])
    }
}
