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

    /// Simplify skill: reviews changed code for reuse, quality, and efficiency opportunities.
    public static var simplify: Skill {
        Skill(
            name: "simplify",
            description: "Review changed code for reuse, quality, and efficiency opportunities, providing before/after comparison examples for each finding.",
            userInvocable: true,
            toolRestrictions: [.bash, .read, .grep, .glob],
            promptTemplate: """
            Analyze recently changed code for simplification opportunities across three categories. Follow these steps:

            ## Step 1: Identify changed files using git diff

            Use `git diff` to see unstaged changes and `git diff --cached` to see staged changes. Combine the results to identify all recently changed files that should be reviewed.

            If both `git diff` and `git diff --cached` return empty output (no changes detected), inform the user: "No changes to review for simplification." and stop.

            ## Step 2: Use Read, Grep, and Glob tools to analyze each changed file

            For every changed file, perform a three-category analysis:

            ### Category 1: Reuse Analysis
            Look for:
            - Duplicated code patterns that could be consolidated into shared functions or helpers
            - Existing utilities or helpers in the codebase that could replace newly written code
            - Patterns that should be extracted into shared abstractions or helper functions
            - Re-implementations of functionality that already exists elsewhere

            ### Category 2: Quality Analysis
            Look for:
            - Overly complex logic that could be simplified or decomposed
            - Poor naming or unclear intent
            - Missing edge case handling
            - Unnecessary abstractions or over-engineering
            - Dead code or unused imports

            ### Category 3: Efficiency Analysis
            Look for:
            - Unnecessary allocations or copies
            - N+1 query patterns or redundant I/O
            - Blocking operations that could be async
            - Inefficient data structures for the access pattern
            - Unnecessary re-computation

            ## Step 3: Report findings with specific file:line references and before/after comparisons

            For each finding, you MUST:
            1. Reference the exact location using the format `path/to/file.swift:行号` (file name and line number)
            2. Provide a before and after comparison example showing the current code and the simplified version

            Structure each finding as follows:

            **Finding: [Brief Title]**
            Location: `path/to/file.swift:行号`
            Category: Reuse / Quality / Efficiency
            Before (current code):
            ```
            // current implementation
            ```
            After (simplified version):
            ```
            // simplified implementation
            ```

            Group findings by category (Reuse, Quality, Efficiency) and prioritize by impact within each category.

            ## Important guidelines

            - This is a read-only analysis skill. Only analyze and report findings — do not modify any files.
            - Every finding must include both file name and line number in `path/to/file.swift:行号` format.
            - Each finding must include a before/after comparison example.
            - If no simplification opportunities are found, report: "No simplification opportunities found in the current changes."
            """
        )
    }

    /// Debug skill: analyzes errors, identifies root causes, and provides fix suggestions.
    public static var debug: Skill {
        Skill(
            name: "debug",
            description: "Analyze errors and investigate issues to identify root causes and provide diagnostic fix suggestions.",
            aliases: ["investigate", "diagnose"],
            userInvocable: true,
            toolRestrictions: [.read, .grep, .glob, .bash],
            promptTemplate: """
            Investigate and diagnose the described issue using a systematic approach. Follow these steps:

            ## Step 1: Understand the issue

            If the user has provided an error message, stack trace, or failure description, read it carefully to understand what went wrong.

            If no specific error message or failure description is provided, ask the user to describe the issue or provide relevant error output, logs, or unexpected behavior details. You can also look for recent build outputs or test results to identify what failed.

            Identify the type of issue:
            - **Build failure / compilation error**: The project fails to compile. Focus on compiler error messages, missing imports, type mismatches, and syntax errors.
            - **Runtime crash / runtime error**: The program crashes or throws an exception at runtime. Focus on stack traces, signal information, and crash logs.
            - **Logic bug / incorrect behavior**: The program runs but produces wrong results. Focus on the expected vs actual behavior.

            ## Step 2: Gather information using available tools

            Use the available tools to investigate:

            - Use **Read** to examine relevant source files identified from the error message or stack trace.
            - Use **Grep** to search for related patterns, function definitions, variable usages, or error strings across the codebase.
            - Use **Glob** to find files matching patterns mentioned in the error (e.g., file names from a stack trace).
            - Use **Bash** to run diagnostic commands such as `git log --oneline -20` to check recent changes, build commands to reproduce errors, or test commands to verify behavior.

            ## Step 3: Analyze and identify root cause

            Based on the gathered information, perform root cause analysis:

            - Trace the error from its symptom back to its origin.
            - Identify the specific code that is incorrect, missing, or misconfigured.
            - Determine why the error occurs (e.g., wrong logic, missing null check, incorrect assumption).

            **If there are multiple root causes**, list them all, sorted from most likely to least likely. For each possible root cause, explain your reasoning and the evidence that supports it. Order root causes by descending likelihood (most likely first, least likely last).

            Every finding must reference the specific file name and line number using the format: `path/to/file.swift:行号`

            ## Step 4: Report findings with structured output

            Present your findings in three sections:

            ### Root Cause
            Provide a clear explanation of the root cause (or multiple possible root causes, ordered from most likely to least likely). For each root cause, reference the exact file name and line number where the issue originates using the format `path/to/file.swift:行号`.

            ### Reproduction Steps
            Describe the steps to reproduce the issue, if applicable. Include any commands, inputs, or conditions needed to trigger the error.

            ### Suggested Fix
            For each identified root cause, provide a specific fix suggestion explaining what change should be made and why. Reference the file name and line number for each suggested fix. Do not make any code changes — only describe the recommended resolution.

            ## Important guidelines

            - This is a read-only diagnostic skill. Only investigate and report findings — do not modify any files.
            - Every finding must include both file name and line number in `path/to/file.swift:行号` format.
            - Handle build failure / compilation error scenarios by focusing on compiler error messages and type checking.
            - Handle runtime crash scenarios by focusing on stack traces, exception types, and signal information.
            - When multiple possible root causes exist, always sort them by likelihood from most likely to least likely.
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
