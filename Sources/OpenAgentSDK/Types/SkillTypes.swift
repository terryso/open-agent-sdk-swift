import Foundation

// MARK: - ToolRestriction

/// Enumerates tool names that can be restricted in a skill definition.
///
/// When a `Skill` has `toolRestrictions` set to a non-nil array, only the
/// listed tools are available during skill execution. A `nil` value means
/// all tools are available (no restrictions).
///
/// The raw value of each case matches the tool name string used internally.
public enum ToolRestriction: String, Sendable, CaseIterable {
    case bash
    case read
    case write
    case edit
    case glob
    case grep
    case webFetch
    case webSearch
    case askUser
    case toolSearch
    case agent
    case sendMessage
    case taskCreate
    case taskList
    case taskUpdate
    case taskGet
    case taskStop
    case taskOutput
    case teamCreate
    case teamDelete
    case notebookEdit
    case skill
}

// MARK: - Skill

/// A reusable prompt template that extends agent capabilities.
///
/// Skills provide specialized capabilities by injecting context-specific
/// prompts with optional tool restrictions and model overrides.
///
/// `Skill` is a value type (struct). This guarantees that once a skill
/// instance is captured by a consumer, subsequent `replace` operations on
/// the registry do not affect the captured instance.
///
/// ```swift
/// let commitSkill = Skill(
///     name: "commit",
///     description: "Create a git commit",
///     promptTemplate: "...",
///     toolRestrictions: [.bash, .read, .write]
/// )
/// ```
public struct Skill: Sendable {
    /// Unique skill name (e.g., "commit", "review").
    public let name: String

    /// Human-readable description of what the skill does.
    public let description: String

    /// Alternative names for the skill (e.g., ["ci"] for commit).
    public let aliases: [String]

    /// Whether the skill can be invoked by users via /command.
    public let userInvocable: Bool

    /// Tools the skill is allowed to use. `nil` means all tools are available.
    public let toolRestrictions: [ToolRestriction]?

    /// Model override for this skill (e.g., "claude-opus-4-6").
    public let modelOverride: String?

    /// Runtime check for whether the skill is available in the current environment.
    /// Defaults to `{ true }`.
    ///
    /// - Note: Stored as a closure for runtime flexibility. The closure is
    ///   `@Sendable` to ensure thread safety.
    public let isAvailable: @Sendable () -> Bool

    /// The prompt template injected when the skill is invoked.
    public let promptTemplate: String

    /// Description of when the model should invoke this skill (used in system prompt).
    public let whenToUse: String?

    /// Hint for expected arguments (e.g., "[message]" for commit).
    public let argumentHint: String?

    /// Creates a new skill definition.
    ///
    /// - Parameters:
    ///   - name: Unique skill name.
    ///   - description: Human-readable description.
    ///   - aliases: Alternative names for lookup.
    ///   - userInvocable: Whether users can invoke via /command. Defaults to `true`.
    ///   - toolRestrictions: Allowed tools. `nil` means all tools. Defaults to `nil`.
    ///   - modelOverride: Model to use during execution. Defaults to `nil`.
    ///   - isAvailable: Runtime availability check. Defaults to `{ true }`.
    ///   - promptTemplate: The prompt template string.
    ///   - whenToUse: When to invoke this skill (for system prompt).
    ///   - argumentHint: Hint for expected arguments.
    public init(
        name: String,
        description: String = "",
        aliases: [String] = [],
        userInvocable: Bool = true,
        toolRestrictions: [ToolRestriction]? = nil,
        modelOverride: String? = nil,
        isAvailable: @escaping @Sendable () -> Bool = { true },
        promptTemplate: String,
        whenToUse: String? = nil,
        argumentHint: String? = nil
    ) {
        self.name = name
        self.description = description
        self.aliases = aliases
        self.userInvocable = userInvocable
        self.toolRestrictions = toolRestrictions
        self.modelOverride = modelOverride
        self.isAvailable = isAvailable
        self.promptTemplate = promptTemplate
        self.whenToUse = whenToUse
        self.argumentHint = argumentHint
    }
}

// MARK: - BuiltInSkills

/// Convenience namespace for accessing default built-in skill definitions.
///
/// Use `BuiltInSkills.commit`, `BuiltInSkills.review`, etc. to get pre-configured
/// `Skill` instances. Each property returns a new value instance, so consumers
/// can modify without affecting the defaults.
///
/// ```swift
/// let registry = SkillRegistry()
/// registry.register(BuiltInSkills.commit)
/// ```
public enum BuiltInSkills {
    /// Commit skill: analyzes changes and suggests a well-crafted commit message.
    public static var commit: Skill {
        Skill(
            name: "commit",
            description: "Analyze staged and unstaged changes, then suggest a well-crafted git commit message.",
            aliases: ["ci"],
            userInvocable: true,
            toolRestrictions: [.bash, .read, .glob, .grep],
            promptTemplate: """
            Analyze the current changes and suggest a git commit message. Follow these steps:

            1. Run `git status --short` to get a concise overview of changed files.
            2. Run `git diff --cached` to inspect staged changes.
            3. If `git diff --cached` is empty (nothing is staged), check for unstaged changes:
               - Run `git diff` to see unstaged changes.
               - If unstaged changes exist, inform the user: "No staged changes found. Please run `git add` on the relevant files first." and list the specific unstaged files.
               - If no changes exist at all (both `git diff --cached` and `git diff` are empty), inform the user: "Nothing to commit — no changes detected." and suggest creating or modifying files first.
            4. If staged changes exist, analyze them and draft a commit message:
               - Use imperative mood (e.g., "Add feature" not "Added feature").
               - Keep the first line (title) under 72 characters.
               - For complex changes, use a multi-paragraph format: title + blank line + body with details.
               - Summarize the "why" not just the "what".

            Do NOT actually execute `git commit`. Only output the suggested commit message.
            Do NOT push to remote unless explicitly asked.
            """
        )
    }

    /// Review skill: reviews code changes across five dimensions with severity-ordered output.
    public static var review: Skill {
        Skill(
            name: "review",
            description: "Review code changes for correctness, security, performance, style, and test coverage issues, with findings ordered by severity.",
            aliases: ["review-pr", "cr"],
            userInvocable: true,
            toolRestrictions: [.bash, .read, .glob, .grep],
            promptTemplate: """
            Review the current code changes for potential issues. Follow these steps:

            ## Step 1: Obtain the diff using the three-level change acquisition strategy

            Try each level in priority order and use the FIRST one that returns output:

            1. `git diff` — unstaged changes (highest priority)
            2. `git diff --cached` — staged but uncommitted changes
            3. `git diff HEAD~1` — changes in the most recent commit

            If all three commands return empty output (no changes to review), inform the user that there are no changes to review and stop.

            ## Step 2: Analyze each changed file across five dimensions

            For every file in the diff, analyze:

            - **Correctness**: Logic errors, edge cases, off-by-one errors, incorrect algorithms, missing null checks
            - **Security**: Injection vulnerabilities, authentication issues, data exposure, hardcoded secrets, improper input validation
            - **Performance**: N+1 queries, unnecessary allocations, blocking I/O, inefficient data structures, redundant computation
            - **Style**: Naming conventions, consistency with surrounding code, readability, Swift idioms, proper access control
            - **Testing coverage**: Are the changes adequately covered by tests? Are edge cases tested? Are new paths exercised?

            ## Step 3: Report findings ordered by severity

            Present all findings grouped and ordered by severity (highest to lowest):

            1. **Security** — vulnerabilities, auth issues, data exposure
            2. **Correctness** — logic errors, incorrect behavior
            3. **Performance** — inefficient patterns, resource waste
            4. **Style** — readability, naming, consistency
            5. **Testing** — missing test coverage, untested edge cases

            For each finding, use the exact format: `path/to/file.swift:行号` (file:line) to reference the specific location.

            Be specific: always include the file name and line number for every finding, and suggest concrete fixes.
            """
        )
    }

    /// Simplify skill: reviews changed code for reuse, quality, and efficiency.
    public static var simplify: Skill {
        Skill(
            name: "simplify",
            description: "Review changed code for reuse, quality, and efficiency, then fix any issues found.",
            userInvocable: true,
            promptTemplate: """
            Review the recently changed code for three categories of improvements. Launch 3 parallel Agent sub-tasks:

            ## Task 1: Reuse Analysis
            Look for:
            - Duplicated code that could be consolidated
            - Existing utilities or helpers that could replace new code
            - Patterns that should be extracted into shared functions
            - Re-implementations of functionality that already exists elsewhere

            ## Task 2: Code Quality
            Look for:
            - Overly complex logic that could be simplified
            - Poor naming or unclear intent
            - Missing edge case handling
            - Unnecessary abstractions or over-engineering
            - Dead code or unused imports

            ## Task 3: Efficiency
            Look for:
            - Unnecessary allocations or copies
            - N+1 query patterns or redundant I/O
            - Blocking operations that could be async
            - Inefficient data structures for the access pattern
            - Unnecessary re-computation

            After all three analyses complete, fix any issues found. Prioritize by impact.
            """
        )
    }

    /// Debug skill: systematic debugging of an issue using structured investigation.
    public static var debug: Skill {
        Skill(
            name: "debug",
            description: "Systematic debugging of an issue using structured investigation.",
            aliases: ["investigate", "diagnose"],
            userInvocable: true,
            promptTemplate: """
            Debug the described issue using a systematic approach:

            1. **Reproduce**: Understand and reproduce the issue
               - Read relevant error messages or logs
               - Identify the failing component

            2. **Investigate**: Trace the root cause
               - Read the relevant source code
               - Add logging or use debugging tools if needed
               - Check recent changes that might have introduced the issue (`git log --oneline -20`)

            3. **Hypothesize**: Form a theory about the cause
               - State your hypothesis clearly before attempting a fix

            4. **Fix**: Implement the minimal fix
               - Make the smallest change that resolves the issue
               - Don't refactor unrelated code

            5. **Verify**: Confirm the fix works
               - Run relevant tests
               - Check for regressions
            """
        )
    }

    /// Test skill: runs tests and analyzes failures.
    ///
    /// The `isAvailable` closure checks whether a test framework is present
    /// in the current working directory.
    public static var test: Skill {
        Skill(
            name: "test",
            description: "Run tests and analyze failures, fixing any issues found.",
            aliases: ["run-tests"],
            userInvocable: true,
            toolRestrictions: [.bash, .read, .write, .edit, .glob, .grep],
            isAvailable: {
                // Check for common test framework indicators in the current directory
                let cwd = FileManager.default.currentDirectoryPath
                let testIndicators = [
                    "Package.swift",     // Swift PM
                    "pytest.ini",        // Python pytest
                    "jest.config",       // JavaScript Jest
                    "vitest.config",     // JavaScript Vitest
                    "Cargo.toml",        // Rust cargo test
                    "go.mod",            // Go test
                ]
                for indicator in testIndicators {
                    let path = cwd + "/" + indicator
                    if FileManager.default.fileExists(atPath: path) {
                        return true
                    }
                }
                return false
            },
            promptTemplate: """
            Run the project's test suite and analyze the results:

            1. **Discover**: Find the test runner configuration
               - Look for Package.swift, jest.config, vitest.config, pytest.ini, etc.
               - Identify the appropriate test command

            2. **Execute**: Run the tests
               - Run the full test suite or specific tests if specified
               - Capture output including failures and errors

            3. **Analyze**: If tests fail:
               - Read the failing test to understand what it expects
               - Read the source code being tested
               - Identify why the test is failing
               - Fix the issue (in tests or source as appropriate)

            4. **Re-verify**: Run the failing tests again to confirm the fix
            """
        )
    }
}
