# Story 14.5: Sandbox Bash Command Filtering

Status: done

## Story

As a developer,
I want sandbox command restrictions enforced in the Bash tool,
so that dangerous commands are intercepted while safe commands execute normally (FR64).

## Acceptance Criteria

1. **AC1: Blocklist mode denies listed commands** -- Given `SandboxSettings(deniedCommands: ["rm", "sudo", "curl"])`, when BashTool receives `rm -rf /tmp/test`, then it returns `SDKError.permissionDenied(tool: "Bash", reason: "command 'rm' is denied by sandbox policy")`.

2. **AC2: Blocklist extracts basename from full path** -- Given `SandboxSettings(deniedCommands: ["rm"])`, when BashTool receives `/usr/bin/rm -rf /tmp/test`, then it extracts basename `rm` and returns `permissionDenied`.

3. **AC3: Allowlist mode permits only listed commands** -- Given `SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])`, when BashTool receives `git status`, then `git` is in the allowlist and the command executes normally.

4. **AC4: Allowlist mode denies unlisted commands** -- Given `SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])`, when BashTool receives `rm -rf /tmp/test`, then `rm` is not in the allowlist and it returns `permissionDenied`.

5. **AC5: Shell metacharacter bypass prevention -- subshell** -- Given blocklist or allowlist config, when BashTool receives `bash -c "rm -rf /tmp"` or `sh -c "rm -rf /tmp"` or `zsh -c "rm -rf /tmp"`, then the inner command is inspected, and if it contains a denied command, returns `permissionDenied`.

6. **AC6: Shell metacharacter bypass prevention -- command substitution** -- Given blocklist config, when BashTool receives `$(rm -rf /tmp)` or `` `rm -rf /tmp` ``, then the substitution content is inspected, and if it contains a denied command, returns `permissionDenied`.

7. **AC7: Shell metacharacter bypass prevention -- escape and quote** -- Given blocklist config with `deniedCommands: ["rm"]`, when BashTool receives `\rm -rf /tmp` or `"rm" -rf /tmp`, then the command name is stripped of leading `\` and surrounding quotes, matched against `rm`, and returns `permissionDenied`.

8. **AC8: Unparseable metacharacters default-deny** -- Given blocklist or allowlist config, when BashTool receives a command with unparseable shell metacharacters, then it returns `permissionDenied("command contains unparseable shell metacharacters")`.

9. **AC9: Allowlist takes precedence over blocklist** -- Given `SandboxSettings(deniedCommands: ["rm"], allowedCommands: ["git", "swift"])`, when BashTool executes, then allowlist mode is active and `deniedCommands` is ignored. `git` is allowed, `swift` is allowed, `rm` is denied, `ls` is denied.

10. **AC10: No restrictions = no filtering** -- Given `context.sandbox == nil` or sandbox with empty `deniedCommands` and `allowedCommands == nil`, when BashTool executes any command, then no command filtering occurs (backward compatibility).

11. **AC11: Sandbox check happens BEFORE process execution** -- Given a sandbox that denies the command, when BashTool is invoked, then the sandbox check throws before `Process.run()` is called. No process is spawned.

12. **AC12: Known limitations documented** -- The API documentation for sandbox command filtering explicitly states that blocklist mode is best-effort and lists the known bypass vectors (pipes, interpreter escape, exec, legitimate destructive commands). Production environments should use allowlist mode.

## Tasks / Subtasks

- [x] Task 1: Implement `checkShellMetacharacters` in SandboxChecker (AC: #5, #6, #7, #8)
  - [x] Add a new static method to `SandboxChecker` that detects and handles shell metacharacter bypass attempts
  - [x] Detect `bash -c` / `sh -c` / `zsh -c` patterns: extract the inner command string and recursively check it against the sandbox rules
  - [x] Detect `$(...)` and backtick command substitution patterns: extract the inner content and check it
  - [x] Strip leading `\` and surrounding quotes from command names before matching
  - [x] If metacharacters cannot be reliably parsed, return `false` (deny by default)
  - [x] This method should be called BEFORE the existing `isCommandAllowed`/`checkCommand` flow

- [x] Task 2: Integrate sandbox command check into BashTool (AC: #1, #2, #3, #4, #9, #10, #11)
  - [x] In `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`, insert sandbox check immediately after extracting `input.command` and BEFORE `executeBashProcess()`
  - [x] Pattern: `if let sandbox = context.sandbox { try SandboxChecker.checkCommand(input.command, settings: sandbox) }`
  - [x] The existing `SandboxChecker.checkCommand()` already handles basename extraction, allowlist/blocklist logic, and Logger integration

- [x] Task 3: Enhance `SandboxChecker.checkCommand()` to call metacharacter detection (AC: #5, #6, #7, #8)
  - [x] In `Sources/OpenAgentSDK/Utils/SandboxChecker.swift`, update `checkCommand()` to call the new metacharacter detection before the basename-based allowlist/blocklist check
  - [x] Flow: (1) metacharacter detection -> (2) basename extraction -> (3) allowlist/blocklist match
  - [x] If metacharacter detection returns a denial, skip the basename check and throw immediately

- [x] Task 4: Write unit tests (AC: #1-#12)
  - [x] Create `Tests/OpenAgentSDKTests/Tools/BashSandboxTests.swift`
  - [x] Test AC1: blocklist denies listed command
  - [x] Test AC2: blocklist extracts basename from full path
  - [x] Test AC3: allowlist permits listed command
  - [x] Test AC4: allowlist denies unlisted command
  - [x] Test AC5: subshell bypass prevention (`bash -c`, `sh -c`, `zsh -c`)
  - [x] Test AC6: command substitution bypass prevention (`$(...)`, backticks)
  - [x] Test AC7: escape and quote bypass prevention (`\rm`, `"rm"`)
  - [x] Test AC8: unparseable metacharacters default-deny
  - [x] Test AC9: allowlist precedence over blocklist
  - [x] Test AC10: no sandbox = no filtering
  - [x] Test AC11: sandbox check before process execution (no process spawned)
  - [x] Test AC12: verify doc comments on public API mention limitations

- [x] Task 5: Verify build and full test suite
  - [x] `swift build` compiles with no errors
  - [x] `swift test` all pass, no regressions

## Dev Notes

### Position in Epic and Project

- **Epic 14** (Runtime Protection: Logging & Sandbox), fifth and final story
- **Core goal:** Integrate `SandboxChecker.checkCommand()` into BashTool so that sandbox command restrictions (allowlist/blocklist) are enforced before any shell process is spawned
- **Prerequisites:** Stories 14.1 and 14.2 (Logger) are DONE. Story 14.3 (SandboxSettings + SandboxChecker + SandboxPathNormalizer) is DONE. Story 14.4 (filesystem sandbox) is DONE -- all types and utilities exist and are tested
- **FR coverage:** FR64 (sandbox restrictions enforced in Bash and file tools -- this story covers Bash; Story 14.4 covered file tools)
- **NFR coverage:** NFR27 (sandbox path and command checks complete within 1ms -- not blocking tool execution hot path)

### Critical Design Decisions

**SandboxChecker.checkCommand() already exists (from Story 14.3):**
- The method already handles basename extraction, allowlist/blocklist mode switching, and Logger integration
- Story 14.3 code review fixed a bug in `extractCommandBasename` where it wasn't splitting command arguments properly -- this was fixed
- The existing `extractCommandBasename` strips `\`, quotes, extracts first token, and gets basename from paths
- What's missing: shell metacharacter detection for subshell invocations, command substitutions, and other bypass vectors

**Shell metacharacter detection -- what to add:**
The epics spec requires handling these specific bypass vectors:
1. `bash -c "rm -rf /tmp"` -- subshell with shell name prefix
2. `sh -c "rm -rf /tmp"` -- same with `sh`
3. `zsh -c "rm -rf /tmp"` -- same with `zsh`
4. `$(rm -rf /tmp)` -- command substitution in expression context
5. `` `rm -rf /tmp` `` -- backtick command substitution
6. `\rm -rf /tmp` -- escape bypass (ALREADY handled by `extractCommandBasename`)
7. `"rm" -rf /tmp` -- quote bypass (ALREADY handled by `extractCommandBasename`)

Items 6 and 7 are already handled by the existing `extractCommandBasename()`. The new logic needed is for items 1-5.

**Known limitations (must be documented in API comments):**
- Blocklist mode is best-effort; these bypass vectors are NOT covered:
  - Pipe attacks (`echo payload | bash`)
  - Interpreter escape (`python -c "..."`, `node -e "..."`)
  - `exec` built-in
  - Legitimate commands with destructive capabilities (`find / -delete`)
- Production environments should use allowlist mode for strong security

**Metacharacter detection strategy:**
- Parse the command string BEFORE extracting the basename
- If the command starts with a known shell binary (`bash`, `sh`, `zsh`) followed by `-c`, extract the quoted string argument and recursively check it
- If the command contains `$(...)` or backtick patterns, extract the inner content and check it
- If parsing is ambiguous or unreliable, default to deny
- The detection must be fast (< 1ms per call, NFR27)

**Sandbox check placement -- BEFORE process execution:**
- In BashTool, the check must happen before `executeBashProcess()` is called
- This ensures no process is spawned for denied commands
- The check uses `try` which propagates to the defineTool closure's error handling
- ToolExecutor catches the error and converts to `ToolResult(is_error: true)`

**Empty SandboxSettings = no restrictions (backward compatibility):**
- `SandboxChecker.isCommandAllowed()` already returns `true` when `deniedCommands.isEmpty && allowedCommands == nil`
- No filtering occurs when no sandbox is configured or when sandbox has no command restrictions
- This matches the pattern from Story 14.4 (filesystem sandbox)

### What This Story Does NOT Do

- Does NOT modify any file tools (done in Story 14.4)
- Does NOT create new data types -- SandboxSettings already has all needed fields
- Does NOT modify SandboxSettings struct -- it already has `deniedCommands` and `allowedCommands`
- Does NOT add network restrictions (explicitly out of scope per epics spec)
- Does NOT implement pipe attack prevention, interpreter escape prevention, or exec prevention (known limitations documented)

### Previous Story Intelligence

**Key learnings from Story 14.3 (SandboxSettings + SandboxChecker):**
- `SandboxChecker` is a caseless enum with static methods -- call directly: `SandboxChecker.checkCommand(command, settings: sandbox)`
- `SandboxChecker.checkCommand()` throws `SDKError.permissionDenied(tool: "Bash", reason: ...)` on denial
- Logger integration is already built into `SandboxChecker.checkCommand()` -- it logs denials at `.info` level automatically
- `ToolContext.sandbox` is already populated (Story 14.3 propagated it from AgentOptions)
- `extractCommandBasename` already strips `\`, quotes, extracts first token, gets basename from paths
- Code review found and fixed a bug where `extractCommandBasename` wasn't splitting command arguments -- this is now fixed

**Key learnings from Story 14.4 (Filesystem Sandbox):**
- The integration pattern is `if let sandbox = context.sandbox { try SandboxChecker.check*(...) }`
- Error handling flow: tool closure `throws` -> ToolExecutor catches -> converts to `ToolResult(is_error: true)`
- Empty SandboxSettings arrays mean "no restrictions" (not "deny everything")
- Tests should check `result.isError == true` and `result.content` contains denial text
- `defineTool()` closures use `async throws` so throws propagate correctly
- The `guard !accumulator.resumed` pattern in BashTool's continuation must not be affected by the sandbox check (check happens before continuation creation)

**Files created in Stories 14.3/14.4 that this story consumes:**
- `Sources/OpenAgentSDK/Types/SandboxSettings.swift` -- data model with `deniedCommands` and `allowedCommands` fields (no changes needed)
- `Sources/OpenAgentSDK/Utils/SandboxChecker.swift` -- enforcement logic with `checkCommand()` and `extractCommandBasename()` (ENHANCE: add metacharacter detection)
- `Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift` -- path normalization (no changes needed)
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- Bash tool (MODIFY: add sandbox check)

### Integration Pattern (Exact Code)

In BashTool, the sandbox check should be placed right after extracting `input.command` and before calling `executeBashProcess()`:

```swift
// In the defineTool closure, after extracting input and timeout:
if let sandbox = context.sandbox {
    try SandboxChecker.checkCommand(input.command, settings: sandbox)
}

return await executeBashProcess(
    command: input.command,
    cwd: context.cwd,
    timeoutMs: timeoutMs
)
```

### Shell Metacharacter Detection Algorithm

The enhanced `checkCommand` flow should be:

```
1. Check for shell metacharacter patterns:
   a. If command starts with "bash -c", "sh -c", "zsh -c", "dash -c", "ksh -c":
      - Extract the argument after -c (respecting quotes)
      - Recursively call checkCommand on the extracted argument
      - If the recursive check denies, deny this command too
   b. If command contains "$( ... )" or backtick patterns:
      - Extract the content inside the substitution
      - Check if the content contains a denied command (or isn't in allowlist)
      - If denied, deny this command
   c. If parsing is ambiguous:
      - Deny by default (return permissionDenied with "unparseable shell metacharacters")

2. Existing flow (already implemented):
   a. Extract basename from command via extractCommandBasename()
   b. If allowlist mode: check basename is in allowedCommands
   c. If blocklist mode: check basename is NOT in deniedCommands
```

### Error Handling Flow

1. Tool closure calls `try SandboxChecker.checkCommand(...)` -- this throws `SDKError.permissionDenied`
2. The `defineTool()` closure is `async throws` -- so the throw propagates
3. `ToolExecutor` catches the error and converts to `ToolResult(is_error: true)`
4. The error message reaches the LLM as a tool error, which it can reason about

This is the same flow as Story 14.4 (filesystem sandbox).

### File Locations

```
Sources/OpenAgentSDK/Utils/
  SandboxChecker.swift              # ENHANCE: add shell metacharacter detection
Sources/OpenAgentSDK/Tools/Core/
  BashTool.swift                    # MODIFY: add sandbox check before process execution
Tests/OpenAgentSDKTests/Tools/
  BashSandboxTests.swift            # NEW: Bash command sandbox tests
```

### Module Boundary Compliance

- `BashTool.swift` is in `Tools/Core/` -- already depends on `Types/` and `Utils/`
- `SandboxChecker.swift` is in `Utils/` -- Tools depend on Utils (per architecture: "Tools/ -> depends on Types/, Utils/")
- No new cross-boundary dependencies introduced

### Testing Strategy

**Unit tests using direct BashChecker/SandboxChecker invocation:**
- Test `SandboxChecker.checkCommand()` directly with various command strings and sandbox configs
- Test shell metacharacter detection logic with crafted command strings
- Test BashTool integration by creating tool with sandbox context and calling `tool.call(input:context:)`
- Verify `ToolResult.isError == true` and content contains denial text

**Test helper pattern:**
```swift
// Test SandboxChecker directly
let settings = SandboxSettings(deniedCommands: ["rm"])
XCTAssertFalse(SandboxChecker.isCommandAllowed("rm -rf /tmp", settings: settings))
XCTAssertTrue(SandboxChecker.isCommandAllowed("ls -la", settings: settings))

// Test BashTool with sandbox context
let tool = createBashTool()
let sandbox = SandboxSettings(deniedCommands: ["rm"])
let context = ToolContext(cwd: "/tmp", sandbox: sandbox)
// ... call tool and verify result
```

**Important:** For BashTool integration tests, since `tool.call(input:context:)` catches errors internally, the sandbox denial will be returned as `ToolResult(is_error: true, content: "... permissionDenied ...")` -- NOT as a thrown error.

### Performance Considerations (NFR27)

- The sandbox check is a string parsing operation -- no I/O, no process spawning
- `extractCommandBasename()` uses simple string operations -- < 0.1ms
- Shell metacharacter detection adds regex or string scanning -- < 0.5ms for typical commands
- Total sandbox overhead: < 1ms per BashTool invocation (well within NFR27)
- When `context.sandbox == nil`, the check is skipped entirely (zero overhead)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 14.5] -- Full acceptance criteria for Bash command filtering
- [Source: _bmad-output/planning-artifacts/epics.md#Story 14.3] -- SandboxSettings configuration model (prerequisite)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 14.4] -- Filesystem sandbox enforcement (sibling story)
- [Source: _bmad-output/planning-artifacts/epics.md#NFR27] -- Sandbox checks complete within 1ms
- [Source: _bmad-output/planning-artifacts/epics.md#FR64] -- Sandbox restrictions enforced in Bash and file tools
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] -- Tool system protocol (ToolProtocol, ToolContext)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD10] -- SDKError with associated values
- [Source: _bmad-output/planning-artifacts/architecture.md#Module Boundaries] -- Tools/ depends on Types/, Utils/
- [Source: _bmad-output/implementation-artifacts/14-3-sandbox-settings-config-model.md] -- Previous story with SandboxSettings, SandboxChecker, SandboxPathNormalizer
- [Source: _bmad-output/implementation-artifacts/14-4-filesystem-sandbox-enforcement.md] -- Previous story with file tool sandbox integration
- [Source: Sources/OpenAgentSDK/Utils/SandboxChecker.swift] -- Enforcement utility with `checkCommand()` and `extractCommandBasename()` static methods
- [Source: Sources/OpenAgentSDK/Types/SandboxSettings.swift] -- SandboxSettings struct with `deniedCommands` and `allowedCommands`
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] -- BashTool to modify (add sandbox check)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

- Initial RED phase confirmed: BashBlocklistTests.testBlocklist_deniesListedCommand failed as expected
- Deeply nested metacharacter handling initially returned `nil` from extractSubshellCommand instead of denying -- fixed by introducing SubshellExtraction enum with `.unparseable` case

### Completion Notes List

- Implemented shell metacharacter detection in SandboxChecker with three-phase checking: (1) no-restriction fast path, (2) metacharacter detection, (3) basename extraction + allowlist/blocklist matching
- Added SubshellExtraction enum to properly distinguish between "not a subshell", "valid inner command", and "unparseable" states
- Supports bash, sh, zsh, dash, ksh subshell detection via `-c` flag parsing
- Supports $() and backtick command substitution detection
- Deeply nested subshell patterns (e.g. `bash -c "bash -c 'rm -rf /tmp'"`) are denied by default as unparseable
- Escape/quote stripping handled by existing extractCommandBasename (no changes needed for \rm, "rm", 'rm')
- Integrated sandbox check into BashTool before executeBashProcess() -- follows same pattern as Story 14.4 filesystem sandbox
- Updated isCommandAllowed() to also check metacharacters so both throwing and non-throwing paths are consistent
- Added API documentation to SandboxChecker type describing known limitations of blocklist mode
- All 48 Bash sandbox tests pass (integration + unit level)
- Full test suite: 2656 tests, 0 failures, 4 skipped

### File List

- Sources/OpenAgentSDK/Utils/SandboxChecker.swift -- MODIFIED: added checkShellMetacharacters(), extractSubshellCommand(), extractCommandSubstitution(), SubshellExtraction enum; updated checkCommand() and isCommandAllowed() for metacharacter detection; added known limitations API documentation
- Sources/OpenAgentSDK/Tools/Core/BashTool.swift -- MODIFIED: added sandbox command check before executeBashProcess()
- Tests/OpenAgentSDKTests/Tools/BashSandboxTests.swift -- PRE-EXISTING: ATDD tests (all 48 now passing)

### Review Findings

- [x] [Review][Patch] `-c` flag detection required space-surrounded literal match, missing tab-separated args [Sources/OpenAgentSDK/Utils/SandboxChecker.swift:339-347] -- FIXED: replaced literal `" -c "` search with whitespace-aware character scan
- [x] [Review][Patch] `-c` flag detection required space-surrounded literal match, missing tab-separated args [Sources/OpenAgentSDK/Utils/SandboxChecker.swift:339-347] -- FIXED: replaced literal `" -c "` search with whitespace-aware character scan
- [x] [Review][Patch] Single `$()`/backtick pair checked -- only first substitution inspected, `$(rm) && $(sudo ...)` would miss the second [Sources/OpenAgentSDK/Utils/SandboxChecker.swift:401-427] -- FIXED in checkpoint review: `extractCommandSubstitution` now returns all matches

## Change Log

- 2026-04-13: Story created with comprehensive context for Bash command filtering implementation.
- 2026-04-13: Implementation complete. All 5 tasks done, all 12 ACs satisfied, 2656 tests passing (0 regressions).
- 2026-04-13: Code review completed. 1 patch applied (`-c` flag whitespace flexibility), 1 known limitation deferred, 3 findings dismissed as noise. All 51 sandbox tests passing post-patch.
- 2026-04-13: Checkpoint review fixed deferred multi-substitution gap. `extractCommandSubstitution` now returns all matches. 4 new tests added. 2660 tests passing (0 regressions).
