# Story 15.1: SkillsExample

Status: done

## Story

As a developer,
I want a runnable example demonstrating the complete usage of the skills system,
so that I can quickly understand how to register, discover, and execute skills (FR52-FR54).

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/SkillsExample/` directory with a `main.swift` file and corresponding `SkillsExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: Built-in skills initialization** -- Given the example code, when reading the code, it demonstrates initializing all five built-in skills (commit, review, simplify, debug, test) via `BuiltInSkills` and registering them into a `SkillRegistry`.

3. **AC3: List all registered skills** -- Given the example code with registered skills, when running `swift run SkillsExample`, it outputs all registered skills showing name, description, and aliases for each.

4. **AC4: List user-invocable skills** -- Given the example code, when running the example, it outputs only user-invocable and available skills (via `registry.userInvocableSkills`), demonstrating the filtering difference from `allSkills`.

5. **AC5: Register custom skill** -- Given the example code, when reading the code, it demonstrates registering a custom skill (e.g., an "explain" skill) with its own name, description, aliases, and promptTemplate. The custom skill appears in subsequent `allSkills` output.

6. **AC6: Find skill by name and alias** -- Given the example code, when reading the code, it demonstrates using `registry.find()` to look up a skill by exact name and by alias, showing both succeed.

7. **AC7: Agent invokes skill via LLM** -- Given an Agent configured with the SkillTool and core tools, when sending a query that triggers skill usage, then the Agent discovers and executes the skill via SkillTool, and the skill's promptTemplate is injected as a new prompt.

8. **AC8: Package.swift updated** -- Given the Package.swift file, when adding the `SkillsExample` executable target, it follows the exact same pattern as existing examples (e.g., `PermissionsExample`, `CustomSystemPromptExample`).

## Tasks / Subtasks

- [x] Task 1: Create example directory and file (AC: #1, #8)
  - [x] Create `Examples/SkillsExample/main.swift`
  - [x] Add `.executableTarget(name: "SkillsExample", dependencies: ["OpenAgentSDK"], path: "Examples/SkillsExample")` to Package.swift

- [x] Task 2: Write Part 1 -- Registry and built-in skills demo (AC: #2, #3, #4)
  - [x] Create `SkillRegistry` instance
  - [x] Register all 5 built-in skills from `BuiltInSkills`
  - [x] Print all registered skills with name, description, aliases
  - [x] Print user-invocable skills, noting the filtering difference

- [x] Task 3: Write Part 2 -- Custom skill registration and lookup (AC: #5, #6)
  - [x] Define a custom `Skill` (e.g., "explain") with name, description, aliases, promptTemplate
  - [x] Register it and verify it appears in `allSkills`
  - [x] Demonstrate `registry.find("explain")` by exact name
  - [x] Demonstrate `registry.find("eli5")` by alias

- [x] Task 4: Write Part 3 -- Agent skill invocation (AC: #7)
  - [x] Create Agent with `AgentOptions` including SkillTool and core tools
  - [x] Send a query prompting the Agent to use a skill
  - [x] Print tool calls and Agent response to show skill execution
  - [x] Print query statistics (status, turns, duration, cost)

- [x] Task 5: Verify build and run (AC: #1)
  - [x] `swift build` compiles with no errors/warnings
  - [x] Manual smoke-test of `swift run SkillsExample`

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), first story
- **Core goal:** Create a runnable example demonstrating the Skills system API (SkillRegistry, Skill struct, BuiltInSkills, createSkillTool)
- **Prerequisites:** Epic 11 (Skills system) is DONE -- all types and utilities exist: `Skill`, `BuiltInSkills`, `SkillRegistry`, `ToolRestriction`, `createSkillTool()`
- **FR coverage:** FR52-FR54 (example/illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface (from Epic 11 implementation)

The following public API is already implemented and available for the example:

```swift
// Types/SkillTypes.swift
public struct Skill: Sendable {
    public let name: String
    public let description: String
    public let aliases: [String]
    public let userInvocable: Bool
    public let toolRestrictions: [ToolRestriction]?
    public let modelOverride: String?
    public let isAvailable: @Sendable () -> Bool
    public let promptTemplate: String
    public let whenToUse: String?
    public let argumentHint: String?
    public init(name:description:aliases:userInvocable:toolRestrictions:modelOverride:isAvailable:promptTemplate:whenToUse:argumentHint:)
}

public enum BuiltInSkills {
    public static var commit: Skill { get }
    public static var review: Skill { get }
    public static var simplify: Skill { get }
    public static var debug: Skill { get }
    public static var test: Skill { get }
}

public enum ToolRestriction: String, Sendable, CaseIterable { ... }

// Tools/SkillRegistry.swift
public final class SkillRegistry: @unchecked Sendable {
    public init(promptTokenBudget: Int = 500)
    public func register(_ skill: Skill)
    public func replace(_ skill: Skill)
    public func unregister(_ name: String) -> Bool
    public func find(_ name: String) -> Skill?
    public func has(_ name: String) -> Bool
    public var allSkills: [Skill] { get }
    public var userInvocableSkills: [Skill] { get }
    public func formatSkillsForPrompt() -> String
}

// Tools/Advanced/SkillTool.swift
public func createSkillTool(registry: SkillRegistry) -> ToolProtocol
```

### Example Pattern to Follow

Follow the same patterns as existing examples:

1. **API key loading** -- Use `loadDotEnv()` and `getEnv()` helper pattern from `BasicAgent/main.swift` and `PermissionsExample/main.swift`:
   ```swift
   let dotEnv = loadDotEnv()
   let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
       ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
       ?? "sk-..."
   let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
   let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
   ```

2. **Agent creation** -- Use `createAgent(options:)` with `permissionMode: .bypassPermissions` for example purposes

3. **Tool registration** -- Use `getAllBaseTools(tier: .core)` plus the SkillTool:
   ```swift
   var tools = getAllBaseTools(tier: .core)
   tools.append(createSkillTool(registry: registry))
   ```

4. **Output formatting** -- Print sections with clear headers, show statistics at the end

5. **Comment style** -- Chinese + English header comments matching existing examples (see `PermissionsExample/main.swift` and `CustomSystemPromptExample/main.swift`)

### TypeScript SDK Reference

The TypeScript SDK has `examples/12-skills.ts` which demonstrates:
1. `initBundledSkills()` -- register built-in skills
2. `getAllSkills()` -- list all skills
3. `registerSkill()` -- register custom skill
4. `getUserInvocableSkills()` -- filtered list
5. `getSkill('commit')` -- lookup by name
6. Agent query with skill invocation via streaming API

The Swift example should cover the same scenarios using Swift API conventions. Key differences:
- Swift uses `SkillRegistry` class (not module-level functions)
- Swift uses `BuiltInSkills.commit` static properties (not `initBundledSkills()`)
- Swift `createSkillTool(registry:)` creates the tool explicitly
- Swift uses `agent.prompt()` or `agent.stream()` for queries

### File Locations

```
Examples/SkillsExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add SkillsExample executable target
```

### Package.swift Change

Add after the `AdvancedMCPExample` target:

```swift
.executableTarget(
    name: "SkillsExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/SkillsExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run SkillsExample` should run and output skill listings and agent interaction
- **No new unit tests needed** -- this is an example, not production code
- The example itself serves as an integration test of the Skills API surface

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.1] -- Full acceptance criteria for SkillsExample
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11] -- Skills system design and API
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift] -- `Skill` struct, `BuiltInSkills`, `ToolRestriction` enum
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] -- `SkillRegistry` class with register/find/list methods
- [Source: Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift] -- `createSkillTool(registry:)` factory function
- [Source: Examples/BasicAgent/main.swift] -- Pattern: API key loading, agent creation, prompt/response
- [Source: Examples/PermissionsExample/main.swift] -- Pattern: multi-part example with comparison sections
- [Source: Examples/CustomSystemPromptExample/main.swift] -- Pattern: single-agent example with statistics output
- [Source: Package.swift] -- Existing executable target definitions to follow
- [Source: open-agent-sdk-typescript/examples/12-skills.ts] -- TypeScript reference implementation
- [Source: _bmad-output/project-context.md] -- Project conventions and rules
- [Source: _bmad-output/implementation-artifacts/14-5-sandbox-bash-command-filtering.md] -- Previous story (Epic 14 final)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 / GLM-5.1

### Debug Log References

No issues encountered.

### Completion Notes List

- Created Examples/SkillsExample/main.swift with a 3-part demo following existing example patterns (Chinese+English header comments, MARK sections, loadDotEnv/getEnv API key pattern)
- Part 1: Creates SkillRegistry, registers all 5 BuiltInSkills (commit, review, simplify, debug, test), prints allSkills with name/description/aliases, then prints userInvocableSkills showing the filtering difference
- Part 2: Defines custom "explain" skill with "eli5" alias and promptTemplate, registers it, verifies it appears in allSkills (6 total), demonstrates find() by exact name and by alias
- Part 3: Creates Agent with SkillTool + core tools, sends query prompting skill usage, prints response text and query statistics (status, numTurns, durationMs, totalCostUsd)
- Added SkillsExample executableTarget to Package.swift following exact same pattern as other examples
- swift build compiles with no errors/warnings
- All 38 ATDD tests pass
- Full test suite: 2698 tests passing, 0 failures, 4 skipped (expected)

### Change Log

- 2026-04-13: Created SkillsExample demonstrating SkillRegistry, BuiltInSkills, custom skill registration, find by name/alias, and Agent skill invocation via SkillTool

### File List

- Examples/SkillsExample/main.swift (NEW)
- Package.swift (MODIFIED: added SkillsExample executableTarget)

### Review Findings

- [x] [Review][Defer] Backslash line continuation in promptTemplate makes prompt harder to debug [Examples/SkillsExample/main.swift:71-72] -- deferred, style preference consistent with project patterns
- [x] [Review][Defer] No error handling around agent.prompt() call [Examples/SkillsExample/main.swift:131] -- deferred, pre-existing pattern (no example uses do/catch around agent.prompt)
- [x] [Review][Patch] testSkillsExampleDemonstratesFindByAlias includes "explain" in knownAliases list which is a skill name not an alias [Tests/OpenAgentSDKTests/Documentation/SkillsExampleComplianceTests.swift:316] -- fixed: removed "explain" from knownAliases
