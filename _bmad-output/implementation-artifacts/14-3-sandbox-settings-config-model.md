# Story 14.3: SandboxSettings Configuration Model

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want to configure sandbox restrictions for my Agent (command blocklist/allowlist, filesystem read/write path rules),
so that in production environments I can control what the Agent is allowed to do (FR63).

## Acceptance Criteria

1. **AC1: SandboxSettings struct with all restriction fields** -- Given `SandboxSettings` struct is defined in `Types/`, when a developer creates an instance, then it supports: `allowedReadPaths: [String]`, `allowedWritePaths: [String]`, `deniedPaths: [String]`, `deniedCommands: [String]`, `allowedCommands: [String]?`, `allowNestedSandbox: Bool`. Default initializer provides empty arrays and `nil` for `allowedCommands` (no restrictions by default) (FR63).

2. **AC2: Path matching uses normalized prefix matching** -- Given `SandboxSettings` with `allowedReadPaths: ["/project/"]`, when path matching is performed, then `/project/src/file.swift` matches (prefix), `/project-backup/file.swift` does NOT match (not a path-segment prefix). Paths are resolved (symlinks, `..` traversal) before matching, consistent with Story 14.4 requirements.

3. **AC3: Command blocklist (default mode)** -- Given `SandboxSettings(deniedCommands: ["rm", "sudo", "chmod"])`, when BashTool executes `git status`, then `git` is not in the denied list and the command proceeds. When BashTool executes `rm -rf /tmp/test`, then it returns `SDKError.permissionDenied(tool: "Bash", reason: "command 'rm' is denied by sandbox policy")`.

4. **AC4: Command allowlist mode** -- Given `SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])`, when set to a non-nil value, then allowlist mode is active and takes precedence over `deniedCommands`. Only listed commands are permitted; all others are denied.

5. **AC5: SDKConfiguration integration** -- Given `SDKConfiguration` gains a `sandbox: SandboxSettings?` field (default: `nil` = no sandbox), when a developer sets `config.sandbox = SandboxSettings(deniedCommands: ["rm"])`, then the settings propagate through `AgentOptions` to the Agent and are accessible to tools.

6. **AC6: AgentOptions passthrough** -- Given `AgentOptions` gains a `sandbox: SandboxSettings?` field (default: `nil`), when the Agent initializes, it stores the sandbox settings and makes them available to ToolExecutor and individual tool executions via `ToolContext`.

7. **AC7: Path normalization utility** -- Given a `SandboxPathNormalizer` utility (internal, in `Utils/`), when paths like `/project/../etc/passwd` or symlinked paths are normalized, then the resolved absolute path is returned using `URL.resolvingSymlinksInPath()` and `FileManager` APIs (NOT POSIX `realpath`). This utility is used by both this story's matching logic and by Stories 14.4/14.5.

8. **AC8: SandboxChecker utility** -- Given an internal `SandboxChecker` class/struct, when `SandboxChecker.isPathAllowed(_:for:settings:)` or `SandboxChecker.isCommandAllowed(_:settings:)` is called, then the method returns a `Result` or throws `SDKError.permissionDenied` using the rules defined in the acceptance criteria. This encapsulates all sandbox enforcement logic so Stories 14.4/14.5 only need to call one method.

## Tasks / Subtasks

- [x] Task 1: Define SandboxSettings struct (AC: #1, #2)
  - [x] Create `Sources/OpenAgentSDK/Types/SandboxSettings.swift`
  - [x] Define `public struct SandboxSettings: Sendable, Equatable, CustomStringConvertible`
  - [x] Fields: `allowedReadPaths: [String]`, `allowedWritePaths: [String]`, `deniedPaths: [String]`, `deniedCommands: [String]`, `allowedCommands: [String]?`, `allowNestedSandbox: Bool`
  - [x] All fields default to empty arrays / `nil` / `false` (no restrictions)
  - [x] Implement `CustomStringConvertible` for debugging
  - [x] Implement path prefix matching method: `func isPathAllowed(_ path: String, for operation: SandboxOperation) -> Bool` where `SandboxOperation` is an enum: `.read`, `.write`
  - [x] Prefix matching logic: normalize both the configured path and the input path, then check if the input path starts with the configured path (ensuring path-segment boundary: `/project/` matches `/project/src/file.swift` but NOT `/project-backup/file.swift`)

- [x] Task 2: Create SandboxPathNormalizer utility (AC: #7)
  - [x] Create `Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift`
  - [x] Define `enum SandboxPathNormalizer` (caseless enum, static methods only)
  - [x] Implement `static func normalize(_ path: String) -> String` using:
    - `URL(fileURLWithPath:).resolvingSymlinksInPath().path` for symlink resolution
    - `FileManager.default.fileSystemRepresentation` for case-insensitive filesystem handling on macOS
    - Standardize to absolute path (resolve `..`, `.`, trailing slashes)
  - [x] On normalization failure (broken symlink, etc.), return the original path (do NOT crash)
  - [x] Cross-platform: use `FileManager` API, NOT POSIX `realpath` (per architecture cross-platform path rules)

- [x] Task 3: Create SandboxChecker utility (AC: #3, #4, #8)
  - [x] Create `Sources/OpenAgentSDK/Utils/SandboxChecker.swift`
  - [x] Define `enum SandboxChecker` (caseless enum, static methods only)
  - [x] Implement `static func isPathAllowed(_ path: String, for operation: SandboxOperation, settings: SandboxSettings) -> Bool`
    - If `settings` has no path restrictions (all arrays empty), return `true`
    - Normalize the path using `SandboxPathNormalizer.normalize()`
    - For `.read` operation: check against `allowedReadPaths` (if non-empty, path must match at least one; if empty, all reads allowed) AND check against `deniedPaths` (must not match any)
    - For `.write` operation: check against `allowedWritePaths` (if non-empty, path must match at least one; if empty, all writes allowed) AND check against `deniedPaths`
  - [x] Implement `static func isCommandAllowed(_ command: String, settings: SandboxSettings) -> Bool`
    - Extract basename from command (e.g., `/usr/bin/rm` -> `rm`), strip leading `\` and quotes
    - If `allowedCommands` is non-nil (allowlist mode): return `true` only if basename is in the list
    - Otherwise (blocklist mode): return `true` only if basename is NOT in `deniedCommands`
    - If no command restrictions are configured, return `true`
  - [x] Implement `static func checkPath(_:for:settings:) throws` that calls `isPathAllowed` and throws `SDKError.permissionDenied` if denied
  - [x] Implement `static func checkCommand(_:settings:) throws` that calls `isCommandAllowed` and throws `SDKError.permissionDenied` if denied
  - [x] Error messages follow the convention: "path '/...' is outside allowed read/write scope" and "command '...' is denied by sandbox policy"

- [x] Task 4: Integrate SandboxSettings into SDKConfiguration (AC: #5)
  - [x] Add `public var sandbox: SandboxSettings?` field to `SDKConfiguration` (default: `nil`)
  - [x] Add parameter to `init()` with default `nil`
  - [x] Include in `description` and `debugDescription`
  - [x] Include in `resolved(overrides:)` merge logic
  - [x] Equatable conformance is synthesized automatically (struct of Equatable fields)

- [x] Task 5: Integrate SandboxSettings into AgentOptions (AC: #6)
  - [x] Add `public var sandbox: SandboxSettings?` field to `AgentOptions` (default: `nil`)
  - [x] Add parameter to both `init()` methods with default `nil`
  - [x] The field passes through from config to options to Agent

- [x] Task 6: Integrate SandboxSettings into Agent and ToolContext (AC: #6)
  - [x] In `Agent.init(options:)`, store `options.sandbox` as a stored property
  - [x] In `ToolContext` struct, add `sandbox: SandboxSettings?` field so tools can access it during execution
  - [x] Ensure the sandbox is propagated when `ToolContext` is created in `ToolExecutor`

- [x] Task 7: Write unit tests (AC: #1-#8)
  - [x] Create `Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift`
  - [x] Test AC1: Create SandboxSettings with various field combinations, verify defaults
  - [x] Test AC2: Path prefix matching with boundary cases (`/project/` matches `/project/src/file.swift`, does NOT match `/project-backup/file.swift`; `/project` matches `/project/file.swift`)
  - [x] Test AC3: Command blocklist -- `git` allowed when denied is `["rm"]`, `rm` denied
  - [x] Test AC4: Command allowlist -- when `allowedCommands = ["git"]`, only `git` is allowed, `rm` is denied; blocklist is ignored
  - [x] Test AC5: SDKConfiguration with sandbox field, verify description and resolved merge
  - [x] Test AC6: AgentOptions with sandbox field, verify passthrough
  - [x] Test AC7: SandboxPathNormalizer with `..` traversal, symlinks (if testable), relative paths
  - [x] Test AC8: SandboxChecker.isPathAllowed and isCommandAllowed return correct bools; checkPath/checkCommand throw SDKError.permissionDenied on denial
  - [x] Test edge cases: empty settings (no restrictions), nil sandbox (no restrictions), path with trailing slash, command with full path (`/usr/bin/rm`)

- [x] Task 8: Verify build and full test suite
  - [x] `swift build` compiles with no errors
  - [x] `swift test` all pass, no regressions

## Dev Notes

### Position in Epic and Project

- **Epic 14** (Runtime Protection: Logging & Sandbox), third story
- **Core goal:** Define the `SandboxSettings` data model and the `SandboxChecker` enforcement utility that Stories 14.4 and 14.5 will consume. This story does NOT modify BashTool, FileReadTool, FileWriteTool, or FileEditTool -- it only creates the types and utilities.
- **Prerequisites:** Stories 14.1 and 14.2 (Logger) are DONE -- use Logger for sandbox denial logging at `.info` level.
- **FR coverage:** FR63 (developer-configurable sandbox restrictions: command exclusion list, filesystem read/write rules)
- **NFR coverage:** NFR27 (sandbox path and command checks complete within 1ms -- not blocking tool execution hot path)

### Critical Design Decisions

**SandboxSettings as a struct (not actor):**
- SandboxSettings is an immutable configuration type -- created once, read many times
- Matches the pattern of `SDKConfiguration`, `AgentOptions`, `ThinkingConfig` (all structs)
- No shared mutable state, so no actor needed
- The `SandboxChecker` is a stateless utility (caseless enum with static methods)

**SandboxChecker as caseless enum with static methods:**
- Stateless utility -- takes settings as a parameter, no stored state
- Similar pattern to `TokenEstimator` (caseless enum with static methods)
- Can be called from any context without initialization
- Stories 14.4 and 14.5 will call `SandboxChecker.checkPath()` and `SandboxChecker.checkCommand()` before tool execution

**allowedCommands as Optional (nil = no allowlist):**
- When `nil`, blocklist mode is active (default, backward compatible)
- When set to a non-nil array (even empty), allowlist mode is active
- This design makes the default behavior "no restrictions" (both fields empty/nil)
- `allowedCommands: []` means "no commands allowed" (most restrictive)

**Path matching is prefix-based with segment boundary:**
- `/project/` matches `/project/src/file.swift` (trailing slash ensures segment boundary)
- `/project` (no trailing slash) matches `/project/file.swift` AND `/project-backup/file.swift`
- To avoid the latter, configured paths should always have trailing slashes, OR the matcher should add a path separator check
- Implementation: normalize both paths, then check `resolvedInput.hasPrefix(configuredPath)` where `configuredPath` ends with `/`

**Error type uses existing SDKError.permissionDenied:**
- `SDKError.permissionDenied(tool: "Bash", reason: "command 'rm' is denied by sandbox policy")`
- `SDKError.permissionDenied(tool: "Read", reason: "path '/etc/passwd' is outside allowed read scope")`
- This reuses the existing permission error from Epic 8 (Story 8.4/8.5)
- The sandbox check happens BEFORE the permission system check -- sandbox is a hard constraint

### What This Story Does NOT Do

- Does NOT modify BashTool, FileReadTool, FileWriteTool, or FileEditTool (Stories 14.4, 14.5)
- Does NOT add network restrictions (explicitly out of scope per epics: "network allowlist not in this Epic scope")
- Does NOT add sub-shell/pipe bypass detection (that's Story 14.5's advanced command filtering)
- Does NOT change the permission system (Epic 8) -- sandbox is a separate layer that runs before permissions

### Integration Points for Stories 14.4 and 14.5

After this story, the following pattern will be used in Stories 14.4/14.5:

```swift
// In FileReadTool (Story 14.4):
if let sandbox = context.sandbox {
    try SandboxChecker.checkPath(input.filePath, for: .read, settings: sandbox)
}
// Proceed with normal file read...

// In BashTool (Story 14.5):
if let sandbox = context.sandbox {
    try SandboxChecker.checkCommand(input.command, settings: sandbox)
}
// Proceed with normal command execution...
```

### Logger Integration

Add Logger calls for sandbox denials at `.info` level (not debug -- denials are important events):
```swift
Logger.shared.info("SandboxChecker", "sandbox_denial", data: [
    "type": "command", // or "path_read", "path_write"
    "value": commandName,
    "reason": "denied by sandbox policy"
])
```

### File Locations

```
Sources/OpenAgentSDK/
  Types/
    SandboxSettings.swift     # NEW: SandboxSettings struct + SandboxOperation enum
    SDKConfiguration.swift    # MODIFY: add sandbox: SandboxSettings? field
    AgentTypes.swift          # MODIFY: add sandbox: SandboxSettings? to AgentOptions
  Utils/
    SandboxPathNormalizer.swift  # NEW: path normalization for sandbox
    SandboxChecker.swift         # NEW: enforcement logic (static methods)
Tests/OpenAgentSDKTests/
  Utils/
    SandboxSettingsTests.swift   # NEW: comprehensive tests
```

### Existing Code to Modify

1. **`Sources/OpenAgentSDK/Types/SDKConfiguration.swift`** -- Add `sandbox: SandboxSettings?` field with default `nil`. Add to init parameters, description, debugDescription, resolved() merge.

2. **`Sources/OpenAgentSDK/Types/AgentTypes.swift`** -- Add `sandbox: SandboxSettings?` field to `AgentOptions` (default `nil`). Add to both init methods.

3. **`Sources/OpenAgentSDK/Core/Agent.swift`** -- Store `options.sandbox` and propagate to ToolContext.

4. **`Sources/OpenAgentSDK/Types/ToolTypes.swift`** (or wherever `ToolContext` is defined) -- Add `sandbox: SandboxSettings?` field to `ToolContext`.

### Module Boundary Compliance

- `Types/SandboxSettings.swift` -- Leaf node, no outbound dependencies (except Foundation). Correct.
- `Utils/SandboxPathNormalizer.swift` -- Depends on Foundation only. Correct.
- `Utils/SandboxChecker.swift` -- Depends on `Types/SandboxSettings`, `Types/ErrorTypes`, `Utils/SandboxPathNormalizer`, `Utils/Logger`. Correct per architecture: Utils depends on Types.
- SDKConfiguration modification is in `Types/` -- no boundary issue.
- AgentOptions modification is in `Types/` -- no boundary issue.

### TypeScript SDK Reference

The TypeScript SDK's `SandboxSettings` in `src/types.ts` is simpler. The Swift SDK adds:
- Separate read/write path lists (TS has a single `allowedPaths`)
- `allowNestedSandbox` flag
- `SandboxPathNormalizer` as a first-class utility
- `SandboxChecker` encapsulation (TS does inline checks)

Do NOT replicate the TS SDK's simpler model -- the Swift design is intentional for stronger security.

### Testing Strategy

- Use `XCTAssertTrue/False` for `SandboxChecker.isPathAllowed` and `isCommandAllowed` (pure functions, no mocks needed)
- Use `XCTAssertThrows` for `checkPath` and `checkCommand` methods that throw `SDKError.permissionDenied`
- Use temporary directories for path normalization tests (avoid hardcoded paths)
- Test Logger output using the capture pattern from Story 14.1:
  ```swift
  var logBuffer: [String] = []
  Logger.configure(level: .info, output: .custom { line in logBuffer.append(line) })
  // trigger sandbox denial...
  // verify logBuffer contains expected entry
  ```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 14.3] -- Full acceptance criteria for SandboxSettings
- [Source: _bmad-output/planning-artifacts/epics.md#Story 14.4] -- Filesystem sandbox enforcement (consumer of this story's types)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 14.5] -- Bash command filtering (consumer of this story's types)
- [Source: _bmad-output/planning-artifacts/epics.md#Cross-Epic Implementation Conventions] -- Cross-platform path handling rules
- [Source: _bmad-output/planning-artifacts/architecture.md#AD10] -- SDKError model (permissionDenied case)
- [Source: _bmad-output/planning-artifacts/architecture.md#Module Boundaries] -- Types/ as leaf nodes, Utils/ depends on Types/
- [Source: _bmad-output/implementation-artifacts/14-1-logger-type-and-injection.md] -- Logger API for sandbox denial logging
- [Source: _bmad-output/implementation-artifacts/14-2-structured-log-output.md] -- Structured log event format
- [Source: Sources/OpenAgentSDK/Types/SDKConfiguration.swift] -- Config to extend with sandbox field
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] -- AgentOptions to extend with sandbox field
- [Source: Sources/OpenAgentSDK/Types/ErrorTypes.swift] -- SDKError.permissionDenied for sandbox denials

### Project Structure Notes

- New files follow the established pattern: types in `Types/`, utilities in `Utils/`, tests mirror source structure
- SandboxSettings is a struct (not actor) matching SDKConfiguration, AgentOptions patterns
- SandboxChecker is a caseless enum with static methods matching TokenEstimator pattern
- No new directories needed

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Task 1: Created `SandboxSettings` struct with all 6 fields, `SandboxOperation` enum, `CustomStringConvertible` conformance, and static `isPathAllowed`/`isCommandAllowed` methods with prefix matching and segment boundary enforcement.
- Task 2: Created `SandboxPathNormalizer` caseless enum with `normalize()` using `URL(fileURLWithPath:).resolvingSymlinksInPath().path`. Handles empty paths gracefully.
- Task 3: Created `SandboxChecker` caseless enum delegating to `SandboxSettings` static methods. `checkPath`/`checkCommand` throw `SDKError.permissionDenied` with proper error messages. Logger integration at `.info` level for denials.
- Task 4: Added `sandbox: SandboxSettings?` to `SDKConfiguration` (field, init param, description, debugDescription, resolved merge).
- Task 5: Added `sandbox: SandboxSettings?` to `AgentOptions` (both init methods, propagated from config).
- Task 6: Added `sandbox: SandboxSettings?` to `ToolContext` (field, init param, `withToolUseId()`, `withSkillContext()`). Propagated from `AgentOptions` in both `prompt()` and `stream()` paths in `Agent.swift`.
- Task 7: All 57 ATDD tests were pre-written by TEA agent. All pass.
- Task 8: Build clean. Full suite: 2580 tests passing, 0 failures, 4 skipped.

### File List

**New files:**
- Sources/OpenAgentSDK/Types/SandboxSettings.swift
- Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift
- Sources/OpenAgentSDK/Utils/SandboxChecker.swift

**Modified files:**
- Sources/OpenAgentSDK/Types/SDKConfiguration.swift
- Sources/OpenAgentSDK/Types/AgentTypes.swift
- Sources/OpenAgentSDK/Types/ToolTypes.swift
- Sources/OpenAgentSDK/Core/Agent.swift

**Pre-existing test file (ATDD RED phase):**
- Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift

### Change Log

- 2026-04-13: Implemented SandboxSettings configuration model (Story 14.3) -- all 8 tasks complete, 57 ATDD tests passing, 2580 total tests passing with 0 regressions.
- 2026-04-13: Code review (yolo mode) -- found and fixed 2 issues: (1) critical bug in extractCommandBasename not splitting command arguments, (2) module boundary violation with Types/ depending on Utils/. Moved enforcement logic from SandboxSettings to SandboxChecker, added argument-splitting. 2582 tests passing.
