import Foundation

// MARK: - SkillRegistry

/// Thread-safe registry for managing skill definitions.
///
/// `SkillRegistry` uses an internal serial `DispatchQueue` to protect
/// concurrent access to the underlying dictionaries, avoiding the need
/// for `await` at every call site (unlike an actor-based approach).
///
/// Skills are maintained in insertion order. When iterating via `allSkills`,
/// `userInvocableSkills`, or `formatSkillsForPrompt()`, the order matches
/// the registration order.
///
/// ```swift
/// let registry = SkillRegistry()
/// registry.register(BuiltInSkills.commit)
/// let skill = registry.find("commit")
/// let prompt = registry.formatSkillsForPrompt()
/// ```
public final class SkillRegistry: @unchecked Sendable {

    /// Internal skill store: name -> Skill.
    private var skills: [String: Skill] = [:]

    /// Insertion-ordered list of skill names.
    private var orderedNames: [String] = []

    /// Alias -> skill name mapping.
    private var aliases: [String: String] = [:]

    /// Serial queue for thread-safe access.
    private let queue = DispatchQueue(label: "com.openagentsdk.skillregistry", attributes: [])

    /// Token budget for `formatSkillsForPrompt()` in tokens (500 tokens * 4 chars/token = 2000 chars).
    private let promptTokenBudget: Int

    /// Creates a new skill registry.
    ///
    /// - Parameter promptTokenBudget: Maximum token budget for `formatSkillsForPrompt()`.
    ///   Defaults to 500 tokens. Each token is estimated as ~4 ASCII characters.
    public init(promptTokenBudget: Int = 500) {
        self.promptTokenBudget = promptTokenBudget
    }

    // MARK: - Registration

    /// Registers a skill definition and its aliases.
    ///
    /// If a skill with the same name already exists, it is replaced in-place
    /// (preserving its original insertion order position).
    ///
    /// - Parameter skill: The skill to register.
    public func register(_ skill: Skill) {
        queue.sync {
            // Clean up old aliases if replacing an existing skill
            if let existing = skills[skill.name] {
                for alias in existing.aliases {
                    aliases.removeValue(forKey: alias)
                }
            }

            // Track insertion order (only for new skills)
            if skills[skill.name] == nil {
                orderedNames.append(skill.name)
            }

            skills[skill.name] = skill

            // Register aliases
            for alias in skill.aliases {
                aliases[alias] = skill.name
            }
        }
    }

    /// Replaces an already-registered skill with an updated definition.
    ///
    /// Value-type semantics guarantee that any previously-captured `Skill`
    /// instances are not affected by this operation. The skill retains its
    /// original insertion order position.
    ///
    /// - Parameter skill: The updated skill definition.
    public func replace(_ skill: Skill) {
        queue.sync {
            // Remove old aliases before registering new ones
            if let existing = skills[skill.name] {
                for alias in existing.aliases {
                    aliases.removeValue(forKey: alias)
                }
            }

            // Track insertion order (only for new skills)
            if skills[skill.name] == nil {
                orderedNames.append(skill.name)
            }

            skills[skill.name] = skill

            // Register new aliases
            for alias in skill.aliases {
                aliases[alias] = skill.name
            }
        }
    }

    /// Removes a skill by name.
    ///
    /// Also removes any associated aliases.
    ///
    /// - Parameter name: The skill name to remove.
    /// - Returns: `true` if the skill was found and removed, `false` otherwise.
    @discardableResult
    public func unregister(_ name: String) -> Bool {
        queue.sync {
            guard let skill = skills.removeValue(forKey: name) else {
                return false
            }

            // Remove from ordered list
            orderedNames.removeAll { $0 == name }

            // Remove associated aliases
            for alias in skill.aliases {
                aliases.removeValue(forKey: alias)
            }

            return true
        }
    }

    /// Removes all registered skills and aliases.
    ///
    /// Primarily useful for testing.
    public func clear() {
        queue.sync {
            skills.removeAll()
            orderedNames.removeAll()
            aliases.removeAll()
        }
    }

    // MARK: - Lookup

    /// Finds a skill by name or alias.
    ///
    /// - Parameter name: The skill name or alias to look up.
    /// - Returns: The matching skill, or `nil` if not found.
    /// - Note: This method does NOT filter by `isAvailable`. Callers that need
    ///   availability filtering should check `skill.isAvailable()` on the result.
    public func find(_ name: String) -> Skill? {
        queue.sync {
            // Direct lookup
            if let direct = skills[name] {
                return direct
            }

            // Alias lookup
            if let resolved = aliases[name], let skill = skills[resolved] {
                return skill
            }

            return nil
        }
    }

    /// Checks whether a skill exists by name or alias.
    ///
    /// - Parameter name: The skill name or alias to check.
    /// - Returns: `true` if the skill is registered.
    public func has(_ name: String) -> Bool {
        queue.sync {
            skills[name] != nil || aliases[name] != nil
        }
    }

    /// Returns all registered skills in insertion order.
    ///
    /// - Returns: An array of all registered skills, regardless of availability.
    public var allSkills: [Skill] {
        queue.sync {
            orderedNames.compactMap { skills[$0] }
        }
    }

    /// Returns all user-invocable skills that are also available, in insertion order.
    ///
    /// Filters by `userInvocable == true` AND `isAvailable() == true`.
    ///
    /// - Returns: An array of user-invocable, available skills.
    public var userInvocableSkills: [Skill] {
        queue.sync {
            orderedNames.compactMap { name -> Skill? in
                guard let skill = skills[name],
                      skill.userInvocable,
                      skill.isAvailable() else {
                    return nil
                }
                return skill
            }
        }
    }

    // MARK: - Filesystem Discovery

    /// Discovers skills from the filesystem and registers them.
    ///
    /// Uses `SkillLoader` to scan directories and register discovered skills.
    /// When `skillNames` is set, only skills matching the whitelist are registered.
    ///
    /// - Parameters:
    ///   - directories: Directories to scan. When `nil`, uses default skill directories.
    ///   - skillNames: Optional whitelist of skill names. When `nil`, all discovered skills are registered.
    /// - Returns: The number of skills successfully registered.
    @discardableResult
    public func registerDiscoveredSkills(
        from directories: [String]? = nil,
        skillNames: [String]? = nil
    ) -> Int {
        let skills = SkillLoader.discoverSkills(from: directories, skillNames: skillNames)
        for skill in skills {
            register(skill)
        }
        return skills.count
    }

    // MARK: - Prompt Formatting

    /// Formats the skills listing for system prompt injection.
    ///
    /// Uses a token budget to avoid bloating the context window. Skills are
    /// listed in insertion order, and when the budget is exceeded, trailing
    /// skills are truncated. Only `userInvocable` and `isAvailable()` skills
    /// are included.
    ///
    /// Each skill is formatted as:
    /// ```
    /// - {name}: {description}
    /// ```
    /// If `whenToUse` is set, it appends ` TRIGGER when: {whenToUse}`.
    ///
    /// - Returns: A formatted string listing available skills, or an empty
    ///   string if no user-invocable skills are available.
    public func formatSkillsForPrompt() -> String {
        let invocable = userInvocableSkills
        if invocable.isEmpty { return "" }

        // Simple token estimation: ~4 chars per token (ASCII), ~1.5 chars per token (CJK)
        // Using utf8.count / 4 as a simple approximation
        let charBudget = promptTokenBudget * 4
        let maxDescChars = 250

        var lines: [String] = []
        var usedChars = 0

        for skill in invocable {
            let desc: String
            if skill.description.count > maxDescChars {
                desc = String(skill.description.prefix(maxDescChars)) + "..."
            } else {
                desc = skill.description
            }

            let triggerSuffix = skill.whenToUse.map { " TRIGGER when: \($0)" } ?? ""
            let argSuffix = skill.argumentHint.map { " \($0)" } ?? ""
            let line = "- \(skill.name)\(argSuffix): \(desc)\(triggerSuffix)"

            if usedChars + line.utf8.count > charBudget { break }
            lines.append(line)
            usedChars += line.utf8.count
        }

        return lines.joined(separator: "\n")
    }
}
