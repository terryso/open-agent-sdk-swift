# Story 15.2: SandboxExample

Status: review

## Story

As a developer,
I want a runnable example demonstrating sandbox configuration and enforcement,
so that I can understand how to restrict Agent operations in production environments (FR63-FR64).

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/SandboxExample/` directory with a `main.swift` file and corresponding `SandboxExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: Filesystem path restrictions** -- Given the example code, when reading the code, it demonstrates configuring `SandboxSettings(allowedReadPaths: ["/project/"], allowedWritePaths: [], deniedPaths: [])` and verifying that read operations within allowed paths succeed while reads outside the sandbox are denied.

3. **AC3: Command blocklist (deniedCommands)** -- Given the example code, when reading the code, it demonstrates configuring `SandboxSettings(deniedCommands: ["rm", "sudo"])` and showing that blocked commands are intercepted while safe commands execute normally.

4. **AC4: Command allowlist (allowedCommands)** -- Given the example code, when reading the code, it demonstrates configuring `SandboxSettings(allowedCommands: ["git", "swift"])` and showing that only whitelisted commands execute while all others are denied.

5. **AC5: Path traversal and symlink protection** -- Given the example code, when reading the code, it demonstrates using `SandboxPathNormalizer.normalize()` to resolve `..` traversal and symlink-based escape attempts.

6. **AC6: Shell metacharacter detection** -- Given the example code, when reading the code, it demonstrates that `SandboxChecker` detects bypass attempts like `bash -c "rm ..."`, `$(rm ...)`, `\rm`, and `"rm"`.

7. **AC7: Agent with sandbox** -- Given an Agent configured with `AgentOptions(sandbox: settings)`, when the Agent attempts sandbox-violating operations via tools, then `permissionDenied` errors are returned and captured gracefully.

8. **AC8: Package.swift updated** -- Given the Package.swift file, when adding the `SandboxExample` executable target, it follows the exact same pattern as existing examples (e.g., `SkillsExample`, `PermissionsExample`).

## Tasks / Subtasks

- [x] Task 1: Create example directory and file (AC: #1, #8)
  - [x] Create `Examples/SandboxExample/main.swift`
  - [x] Add `.executableTarget(name: "SandboxExample", dependencies: ["OpenAgentSDK"], path: "Examples/SandboxExample")` to Package.swift

- [x] Task 2: Write Part 1 -- SandboxSettings and path checking demo (AC: #2, #5)
  - [x] Create `SandboxSettings` with `allowedReadPaths` and show allowed vs denied paths
  - [x] Create `SandboxSettings` with `deniedPaths` and show denied path behavior
  - [x] Demonstrate `SandboxPathNormalizer.normalize()` resolving `..` traversal
  - [x] Demonstrate `SandboxChecker.isPathAllowed()` for read and write operations
  - [x] Print results showing pass/fail for each check

- [x] Task 3: Write Part 2 -- Command filtering demo (AC: #3, #4, #6)
  - [x] Create `SandboxSettings(deniedCommands: ["rm", "sudo"])` and test blocked/allowed commands
  - [x] Create `SandboxSettings(allowedCommands: ["git", "swift"])` and test allowlist behavior
  - [x] Demonstrate basename extraction: `/usr/bin/rm` -> `rm`
  - [x] Demonstrate shell metacharacter detection: `bash -c`, `$(...)`, `\rm`, `"rm"`
  - [x] Print results showing pass/fail for each check

- [x] Task 4: Write Part 3 -- Agent with sandbox integration (AC: #7)
  - [x] Create Agent with `sandbox` in `AgentOptions` combining path and command restrictions
  - [x] Send a query that attempts sandbox-violating operations
  - [x] Show `permissionDenied` errors being captured and handled
  - [x] Print query statistics and error details

- [x] Task 5: Verify build (AC: #1)
  - [x] `swift build` compiles with no errors/warnings
  - [x] Manual smoke-test of `swift run SandboxExample`

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), second story
- **Core goal:** Create a runnable example demonstrating the Sandbox system API (`SandboxSettings`, `SandboxChecker`, `SandboxPathNormalizer`, `SandboxOperation`)
- **Prerequisites:** Epic 14 (Sandbox system) is DONE -- all types and utilities exist
- **FR coverage:** FR63-FR64 (example/illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface (from Epic 14 implementation)

The following public API is already implemented and available for the example:

```swift
// Types/SandboxSettings.swift
public struct SandboxSettings: Sendable, Equatable, CustomStringConvertible {
    public var allowedReadPaths: [String]
    public var allowedWritePaths: [String]
    public var deniedPaths: [String]
    public var deniedCommands: [String]
    public var allowedCommands: [String]?  // nil = blocklist mode, non-nil = allowlist mode
    public var allowNestedSandbox: Bool
    public init(allowedReadPaths:allowedWritePaths:deniedPaths:deniedCommands:allowedCommands:allowNestedSandbox:)
    public var description: String { get }
}

public enum SandboxOperation: String, Sendable, Equatable {
    case read
    case write
}

// Utils/SandboxChecker.swift
enum SandboxChecker {
    public static func isPathAllowed(_ path: String, for operation: SandboxOperation, settings: SandboxSettings) -> Bool
    public static func checkPath(_ path: String, for operation: SandboxOperation, settings: SandboxSettings) throws
    public static func isCommandAllowed(_ command: String, settings: SandboxSettings) -> Bool
    public static func checkCommand(_ command: String, settings: SandboxSettings) throws
}

// Utils/SandboxPathNormalizer.swift
enum SandboxPathNormalizer {
    public static func normalize(_ path: String) -> String
}

// Types/AgentTypes.swift -- sandbox field in AgentOptions
public struct AgentOptions: Sendable {
    public var sandbox: SandboxSettings?
    // ... other fields
}

// Types/SDKConfiguration.swift -- sandbox field in SDKConfiguration
public struct SDKConfiguration: Sendable {
    public var sandbox: SandboxSettings?
    // ... other fields
}

// Types/ErrorTypes.swift
public enum SDKError: Error, Sendable {
    case permissionDenied(tool: String, reason: String)
}
```

### Example Pattern to Follow

Follow the exact same patterns as existing examples (especially SkillsExample and PermissionsExample):

1. **API key loading** -- Use `loadDotEnv()` and `getEnv()` helper pattern:
   ```swift
   let dotEnv = loadDotEnv()
   let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
       ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
       ?? "sk-..."
   let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
   let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
   ```

2. **Agent creation** -- Use `createAgent(options:)` with `permissionMode: .bypassPermissions` for example purposes

3. **Output formatting** -- Print sections with clear headers, show pass/fail results

4. **Comment style** -- Chinese + English header comments matching existing examples (see `SkillsExample/main.swift` and `PermissionsExample/main.swift`)

### Important Implementation Details

1. **This example can demonstrate SandboxChecker API directly** -- Unlike other examples that require an LLM call, the sandbox API (`SandboxChecker.isPathAllowed`, `SandboxChecker.isCommandAllowed`) can be called directly without needing an Agent. The Agent integration in Part 3 shows how sandbox settings flow through the system when tools are executed.

2. **SandboxChecker is an internal enum** -- Check whether `SandboxChecker` is `public` or `internal`. If internal, the example may need to use `@testable import` or the example may need to go through the Agent API instead. Based on the source code review, `isPathAllowed`, `checkPath`, `isCommandAllowed`, and `checkCommand` are all `public static` methods, so they are accessible from examples.

3. **SandboxPathNormalizer is also public** -- The `normalize(_:)` method is public and can be called directly in the example.

4. **No real file system operations needed** -- The example can demonstrate sandbox checking with hypothetical paths (e.g., "/project/src/file.swift", "/etc/passwd") without actually creating or reading those files. `SandboxChecker.isPathAllowed` and `SandboxChecker.isCommandAllowed` are pure logic checks.

5. **Agent sandbox integration** -- When `AgentOptions.sandbox` is set, the sandbox settings are passed to the `ToolContext` for each tool execution. The tools (FileReadTool, FileWriteTool, FileEditTool, BashTool) call `SandboxChecker.checkPath` or `SandboxChecker.checkCommand` internally before executing. The example should show this end-to-end by configuring an Agent with sandbox settings and observing that tool calls are blocked.

### Example Structure (3 Parts)

```
Part 1: Path Restrictions
  - Create SandboxSettings with allowedReadPaths
  - Test isPathAllowed for paths inside/outside sandbox
  - Show SandboxPathNormalizer.normalize() resolving ".." traversal
  - Show path checking for read vs write operations

Part 2: Command Filtering
  - Create SandboxSettings with deniedCommands (blocklist mode)
  - Test isCommandAllowed for blocked and safe commands
  - Create SandboxSettings with allowedCommands (allowlist mode)
  - Test allowlist vs blocklist behavior difference
  - Demonstrate shell metacharacter detection (bash -c, $(), \rm, "rm")
  - Show extractCommandBasename behavior (/usr/bin/rm -> rm)

Part 3: Agent with Sandbox
  - Create Agent with sandbox settings in AgentOptions
  - Send a query that triggers tool calls affected by sandbox
  - Show permissionDenied errors being caught and handled
  - Print query statistics
```

### File Locations

```
Examples/SandboxExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add SandboxExample executable target
```

### Package.swift Change

Add after the `SkillsExample` target (which was added in Story 15.1):

```swift
.executableTarget(
    name: "SandboxExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/SandboxExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run SandboxExample` should run and output sandbox check results
- **No new unit tests needed** -- this is an example, not production code
- The example itself serves as an integration test of the Sandbox API surface
- Note: Parts 1 and 2 (direct API calls) will work without an API key. Only Part 3 (Agent interaction) requires a valid API key.

### Previous Story Intelligence (Story 15.1: SkillsExample)

- **Pattern established:** Chinese + English header comment block, MARK sections, `loadDotEnv()`/`getEnv()` for API key, `createAgent` with `permissionMode: .bypassPermissions`
- **File structure:** Single `main.swift` file in `Examples/<Name>/` directory
- **Package.swift pattern:** `.executableTarget(name: "...", dependencies: ["OpenAgentSDK"], path: "Examples/...")`
- **Build verified:** `swift build` compiles with no errors/warnings
- **All 2698 tests passing** as of Story 15.1 completion

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.2] -- Full acceptance criteria for SandboxExample
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 14] -- Sandbox system design and API
- [Source: Sources/OpenAgentSDK/Types/SandboxSettings.swift] -- `SandboxSettings` struct, `SandboxOperation` enum
- [Source: Sources/OpenAgentSDK/Utils/SandboxChecker.swift] -- `SandboxChecker` with isPathAllowed/checkPath/isCommandAllowed/checkCommand
- [Source: Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift] -- `SandboxPathNormalizer.normalize()`
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- `AgentOptions.sandbox` field
- [Source: Sources/OpenAgentSDK/Types/SDKConfiguration.swift] -- `SDKConfiguration.sandbox` field
- [Source: Sources/OpenAgentSDK/Types/ErrorTypes.swift] -- `SDKError.permissionDenied(tool:reason:)`
- [Source: Examples/SkillsExample/main.swift] -- Pattern: Chinese+English header, MARK sections, agent creation, query stats
- [Source: Examples/PermissionsExample/main.swift] -- Pattern: multi-part example with comparison sections
- [Source: Package.swift] -- Existing executable target definitions to follow
- [Source: _bmad-output/implementation-artifacts/15-1-skills-example.md] -- Previous story (Story 15.1) learnings and patterns

## Dev Agent Record

### Agent Model Used

GLM-5.1 (via Claude Code Agent SDK)

### Debug Log References

### Completion Notes List

- Task 1: Created Examples/SandboxExample/main.swift with 3-part structure (path restrictions, command filtering, agent integration). Added executable target to Package.swift following SkillsExample pattern.
- Task 2: Part 1 demonstrates SandboxSettings with allowedReadPaths, allowedWritePaths, deniedPaths. Shows SandboxPathNormalizer.normalize() resolving ".." traversal and segment boundary enforcement. SandboxChecker.isPathAllowed() tested for read and write operations.
- Task 3: Part 2 demonstrates blocklist mode (deniedCommands: ["rm", "sudo"]) and allowlist mode (allowedCommands: ["git", "swift"]). Shows shell metacharacter detection for bash -c, $(), \rm, "rm". Demonstrates extractCommandBasename.
- Task 4: Part 3 creates Agent with sandbox settings in AgentOptions, sends query that triggers sandbox violation (reading /etc/passwd), shows permissionDenied errors captured gracefully.
- Task 5: swift build succeeds with no errors and no new warnings. Build time: ~1.7s (incremental).
- Additional: Made SandboxChecker, SandboxPathNormalizer public enums (were internal), and extractCommandBasename public method. These were required for the example to access the sandbox API from outside the module.

### File List

- Examples/SandboxExample/main.swift (NEW)
- Package.swift (MODIFIED - added SandboxExample executable target)
- Sources/OpenAgentSDK/Utils/SandboxChecker.swift (MODIFIED - made enum and extractCommandBasename public)
- Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift (MODIFIED - made enum public)

## Change Log

- 2026-04-13: Implemented SandboxExample with 3-part demo (path restrictions, command filtering, agent sandbox integration). Made SandboxChecker/SandboxPathNormalizer public for external API access.
