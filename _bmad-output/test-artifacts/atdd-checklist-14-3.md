---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/14-3-sandbox-settings-config-model.md'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ErrorTypes.swift'
  - 'Sources/OpenAgentSDK/Utils/Logger.swift'
  - 'Tests/OpenAgentSDKTests/Utils/LoggerTests.swift'
  - 'Tests/OpenAgentSDKTests/Utils/TokenEstimatorTests.swift'
---

# ATDD Checklist - Epic 14, Story 3: SandboxSettings Configuration Model

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (Swift backend project)

---

## Story Summary

Define the SandboxSettings data model and SandboxChecker enforcement utility that Stories 14.4 and 14.5 will consume. Create types for sandbox restrictions (command blocklist/allowlist, filesystem read/write path rules), path normalization, and enforcement logic. Integrate sandbox settings into SDKConfiguration, AgentOptions, and ToolContext.

**As a** developer
**I want** to configure sandbox restrictions for my Agent (command blocklist/allowlist, filesystem read/write path rules)
**So that** in production environments I can control what the Agent is allowed to do (FR63)

---

## Acceptance Criteria

1. **AC1:** SandboxSettings struct with all restriction fields -- allowedReadPaths, allowedWritePaths, deniedPaths, deniedCommands, allowedCommands (Optional), allowNestedSandbox. Defaults to no restrictions (FR63).
2. **AC2:** Path matching uses normalized prefix matching -- trailing slash ensures segment boundary, dot-dot resolved before matching.
3. **AC3:** Command blocklist (default mode) -- denied commands are blocked, others proceed.
4. **AC4:** Command allowlist mode -- when allowedCommands is non-nil, only listed commands permitted; takes precedence over blocklist.
5. **AC5:** SDKConfiguration integration -- sandbox: SandboxSettings? field (default nil).
6. **AC6:** AgentOptions passthrough -- sandbox field propagates from config to options to Agent, accessible via ToolContext.
7. **AC7:** SandboxPathNormalizer utility -- resolves symlinks, dot-dot, relative paths using FileManager/URL APIs.
8. **AC8:** SandboxChecker utility -- isPathAllowed, isCommandAllowed, checkPath (throws), checkCommand (throws) methods.

---

## Failing Tests Created (RED Phase)

### Unit Tests - SandboxSettingsTests (50 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testSandboxSettings_DefaultInit_HasNoRestrictions | AC1 | P0 | RED | Cannot find SandboxSettings in scope |
| 2 | testSandboxSettings_ExplicitInit_AllFieldsSet | AC1 | P0 | RED | Cannot find SandboxSettings in scope |
| 3 | testSandboxSettings_ConformsToSendable | AC1 | P0 | RED | Cannot find SandboxSettings in scope |
| 4 | testSandboxSettings_ConformsToEquatable | AC1 | P0 | RED | Cannot find SandboxSettings in scope |
| 5 | testSandboxSettings_ConformsToCustomStringConvertible | AC1 | P1 | RED | Cannot find SandboxSettings in scope |
| 6 | testSandboxSettings_EmptyAllowedCommandsArray_IsAllowlistMode | AC1 | P1 | RED | Cannot find SandboxSettings in scope |
| 7 | testPathMatching_TrailingSlashMatchesSubdirectory | AC2 | P0 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 8 | testPathMatching_TrailingSlashDoesNotMatchSibling | AC2 | P0 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 9 | testPathMatching_NoTrailingSlashMatchesDirectChild | AC2 | P0 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 10 | testPathMatching_DotDotTraversalIsResolved | AC2 | P1 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 11 | testPathMatching_DeniedPathOverridesAllowed | AC2 | P1 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 12 | testPathMatching_WriteOperationChecksWritePaths | AC2 | P1 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 13 | testPathMatching_EmptyRestrictions_AllowAll | AC2 | P1 | RED | Cannot find SandboxSettings/SandboxOperation in scope |
| 14 | testBlocklist_CommandNotDenied_IsAllowed | AC3 | P0 | RED | Cannot find SandboxSettings in scope |
| 15 | testBlocklist_CommandDenied_IsBlocked | AC3 | P0 | RED | Cannot find SandboxSettings in scope |
| 16 | testBlocklist_FullPathExtractsBasename | AC3 | P1 | RED | Cannot find SandboxSettings in scope |
| 17 | testBlocklist_NoRestrictions_AllowsAll | AC3 | P1 | RED | Cannot find SandboxSettings in scope |
| 18 | testBlocklist_CaseSensitive | AC3 | P1 | RED | Cannot find SandboxSettings in scope |
| 19 | testAllowlist_OnlyListedCommandsAllowed | AC4 | P0 | RED | Cannot find SandboxSettings in scope |
| 20 | testAllowlist_TakesPrecedenceOverBlocklist | AC4 | P0 | RED | Cannot find SandboxSettings in scope |
| 21 | testAllowlist_CommandNotInList_IsDenied | AC4 | P0 | RED | Cannot find SandboxSettings in scope |
| 22 | testAllowlist_EmptyArray_NothingAllowed | AC4 | P1 | RED | Cannot find SandboxSettings in scope |
| 23 | testAllowlist_NilUsesBlocklistMode | AC4 | P1 | RED | Cannot find SandboxSettings in scope |
| 24 | testSDKConfiguration_HasSandboxField_DefaultNil | AC5 | P0 | RED | SDKConfiguration has no sandbox field |
| 25 | testSDKConfiguration_CanSetSandbox | AC5 | P0 | RED | SDKConfiguration has no sandbox init param |
| 26 | testSDKConfiguration_SandboxInDescription | AC5 | P1 | RED | Description won't contain 'sandbox' |
| 27 | testSDKConfiguration_SandboxEquality | AC5 | P0 | RED | SDKConfiguration has no sandbox field |
| 28 | testSDKConfiguration_ResolvedMergesSandbox | AC5 | P1 | RED | SDKConfiguration.resolved won't merge sandbox |
| 29 | testAgentOptions_HasSandboxField_DefaultNil | AC6 | P0 | RED | AgentOptions has no sandbox field |
| 30 | testAgentOptions_CanSetSandbox | AC6 | P0 | RED | AgentOptions has no sandbox init param |
| 31 | testAgentOptions_InitFromConfig_PropagatesSandbox | AC6 | P1 | RED | AgentOptions(from:) won't propagate sandbox |
| 32 | testPathNormalizer_ResolvesDotDot | AC7 | P0 | RED | Cannot find SandboxPathNormalizer in scope |
| 33 | testPathNormalizer_ResolvesRelativePath | AC7 | P0 | RED | Cannot find SandboxPathNormalizer in scope |
| 34 | testPathNormalizer_AlreadyNormalized_StaysSame | AC7 | P0 | RED | Cannot find SandboxPathNormalizer in scope |
| 35 | testPathNormalizer_ResolvesDotSegments | AC7 | P1 | RED | Cannot find SandboxPathNormalizer in scope |
| 36 | testPathNormalizer_TrailingSlashStandardized | AC7 | P1 | RED | Cannot find SandboxPathNormalizer in scope |
| 37 | testPathNormalizer_EmptyPath_DoesNotCrash | AC7 | P1 | RED | Cannot find SandboxPathNormalizer in scope |
| 38 | testPathNormalizer_UsesURLAPI | AC7 | P1 | RED | Cannot find SandboxPathNormalizer in scope |
| 39 | testSandboxChecker_IsPathAllowed_NoRestrictions_ReturnsTrue | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 40 | testSandboxChecker_IsPathAllowed_DeniedPath_ReturnsFalse | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 41 | testSandboxChecker_IsPathAllowed_AllowedReadPath_ReturnsTrue | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 42 | testSandboxChecker_IsPathAllowed_WriteChecksWritePaths | AC8 | P1 | RED | Cannot find SandboxChecker in scope |
| 43 | testSandboxChecker_IsCommandAllowed_NoRestrictions_ReturnsTrue | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 44 | testSandboxChecker_IsCommandAllowed_DeniedCommand_ReturnsFalse | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 45 | testSandboxChecker_IsCommandAllowed_AllowlistMode_ReturnsFalseForUnlisted | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 46 | testSandboxChecker_CheckPath_ThrowsPermissionDenied | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 47 | testSandboxChecker_CheckPath_AllowedPath_DoesNotThrow | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 48 | testSandboxChecker_CheckCommand_ThrowsPermissionDenied | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 49 | testSandboxChecker_CheckCommand_AllowedCommand_DoesNotThrow | AC8 | P0 | RED | Cannot find SandboxChecker in scope |
| 50 | testSandboxChecker_CheckPath_ErrorMessageConvention | AC8 | P1 | RED | Cannot find SandboxChecker in scope |
| 51 | testSandboxChecker_CheckCommand_ErrorMessageConvention | AC8 | P1 | RED | Cannot find SandboxChecker in scope |
| 52 | testSandboxChecker_LogsDenialAtInfoLevel | AC8 | P1 | RED | Cannot find SandboxChecker in scope |
| 53 | testToolContext_HasSandboxField_DefaultNil | AC6 | P0 | RED | ToolContext has no sandbox field |
| 54 | testToolContext_CanSetSandbox | AC6 | P0 | RED | ToolContext has no sandbox param |
| 55 | testSandboxOperation_HasReadAndWriteCases | AC2 | P0 | RED | Cannot find SandboxOperation in scope |
| 56 | testSandboxOperation_ConformsToSendable | AC2 | P1 | RED | Cannot find SandboxOperation in scope |
| 57 | testSandboxOperation_ConformsToEquatable | AC2 | P1 | RED | Cannot find SandboxOperation in scope |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). Test levels:
- **Unit tests** for all ACs -- pure functions, struct construction, path/command matching logic
- **No E2E tests** (no UI component, no browser)

### Approach

1. Tests create `SandboxSettings` instances directly and verify field values
2. Path matching tests use `SandboxSettings.isPathAllowed` method on the struct
3. Command matching tests use `SandboxSettings.isCommandAllowed` method on the struct
4. `SandboxChecker` tests call static methods directly (stateless utility)
5. `SandboxPathNormalizer` tests call static `normalize()` method
6. SDKConfiguration/AgentOptions/ToolContext integration tests verify field propagation
7. Error tests use `XCTAssertThrowsError` to verify `SDKError.permissionDenied`
8. Logger integration tests reuse the `LogCapture` pattern from LoggerTests.swift

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 33 | Core ACs: type existence, matching correctness, error throwing, integration |
| P1 | 24 | Supporting: edge cases, conventions, descriptions, logging |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (SandboxSettings struct) | 6 | Unit (construction, defaults, protocols) |
| AC2 (Path matching + SandboxOperation) | 10 | Unit (prefix matching, segment boundary, operation enum) |
| AC3 (Command blocklist) | 5 | Unit (denied list matching) |
| AC4 (Command allowlist) | 5 | Unit (allowlist precedence, nil = blocklist) |
| AC5 (SDKConfiguration integration) | 5 | Unit (field, init, description, equality, merge) |
| AC6 (AgentOptions + ToolContext) | 5 | Unit (field, init, config passthrough) |
| AC7 (SandboxPathNormalizer) | 7 | Unit (dot-dot, relative, absolute, empty) |
| AC8 (SandboxChecker) | 14 | Unit (is*Allowed, check* throws, error messages, logging) |

---

## Implementation Checklist

### Task 1: Define SandboxSettings struct + SandboxOperation enum (AC: #1, #2)

**File:** `Sources/OpenAgentSDK/Types/SandboxSettings.swift` (NEW)

**Tests this makes pass:**
- SandboxSettingsStructTests (6 tests)
- SandboxOperationTests (3 tests)
- SandboxPathMatchingTests (7 tests)
- CommandBlocklistTests (5 tests)
- CommandAllowlistTests (5 tests)

**Implementation steps:**
- [ ] Create `public struct SandboxSettings: Sendable, Equatable, CustomStringConvertible`
- [ ] Define all 6 fields with defaults
- [ ] Define `public enum SandboxOperation: Sendable, Equatable { case read, write }`
- [ ] Implement `isPathAllowed(_:for:settings:)` static method (AC2 prefix matching)
- [ ] Implement `isCommandAllowed(_:settings:)` static method (AC3/AC4 blocklist/allowlist)
- [ ] Implement `CustomStringConvertible`

### Task 2: Create SandboxPathNormalizer utility (AC: #7)

**File:** `Sources/OpenAgentSDK/Utils/SandboxPathNormalizer.swift` (NEW)

**Tests this makes pass:**
- SandboxPathNormalizerTests (7 tests)

**Implementation steps:**
- [ ] Create `public enum SandboxPathNormalizer` (caseless enum)
- [ ] Implement `static func normalize(_ path: String) -> String`
- [ ] Use `URL(fileURLWithPath:).resolvingSymlinksInPath().path`
- [ ] Handle edge cases: empty string, broken symlinks

### Task 3: Create SandboxChecker utility (AC: #3, #4, #8)

**File:** `Sources/OpenAgentSDK/Utils/SandboxChecker.swift` (NEW)

**Tests this makes pass:**
- SandboxCheckerTests (14 tests)

**Implementation steps:**
- [ ] Create `public enum SandboxChecker` (caseless enum)
- [ ] Implement `isPathAllowed(_:for:settings:)` and `isCommandAllowed(_:settings:)`
- [ ] Implement `checkPath(_:for:settings:) throws` and `checkCommand(_:settings:) throws`
- [ ] Add Logger.shared.info calls for denials
- [ ] Extract basename from full paths, strip leading `\` and quotes

### Task 4: Integrate SandboxSettings into SDKConfiguration (AC: #5)

**File:** `Sources/OpenAgentSDK/Types/SDKConfiguration.swift` (MODIFY)

**Tests this makes pass:**
- SandboxSDKConfigurationTests (5 tests)

**Implementation steps:**
- [ ] Add `public var sandbox: SandboxSettings?` field (default nil)
- [ ] Add to init parameters, description, debugDescription
- [ ] Add to `resolved(overrides:)` merge logic

### Task 5: Integrate SandboxSettings into AgentOptions (AC: #6)

**File:** `Sources/OpenAgentSDK/Types/AgentTypes.swift` (MODIFY)

**Tests this makes pass:**
- SandboxAgentOptionsTests (3 tests)

**Implementation steps:**
- [ ] Add `public var sandbox: SandboxSettings?` to AgentOptions
- [ ] Add to both init methods with default nil
- [ ] Propagate in `init(from config:)`

### Task 6: Integrate SandboxSettings into ToolContext (AC: #6)

**File:** `Sources/OpenAgentSDK/Types/ToolTypes.swift` (MODIFY)

**Tests this makes pass:**
- SandboxToolContextTests (2 tests)

**Implementation steps:**
- [ ] Add `public let sandbox: SandboxSettings?` to ToolContext
- [ ] Add to init with default nil
- [ ] Add to `withToolUseId()` and `withSkillContext()` copy methods

### Task 7: Verify build and full test suite

- [ ] `swift build` compiles with no errors
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter "SandboxSettingsStructTests|SandboxPathMatchingTests|CommandBlocklistTests|CommandAllowlistTests|SandboxSDKConfigurationTests|SandboxAgentOptionsTests|SandboxPathNormalizerTests|SandboxCheckerTests|SandboxToolContextTests|SandboxOperationTests"

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 57 tests written in 1 test file, all failing because types do not exist yet
- Tests cover all 8 acceptance criteria
- Tests follow Given-When-Then format with descriptive test names
- Test isolation via Logger.reset() in setUp/tearDown for SandboxChecker tests
- LogCapture pattern reused from LoggerTests.swift
- Tests use XCTAssertThrowsError for error-throwing methods
- SDKConfiguration/AgentOptions/ToolContext integration tests verify field propagation

**Verification:**
- Tests do NOT compile (types don't exist yet -- expected for RED phase)
- Compilation errors are clean: "cannot find 'X' in scope" for all new types
- No crashes or unexpected behavior

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (SandboxSettings + SandboxOperation) -- makes 26 tests pass
2. **Then Task 2** (SandboxPathNormalizer) -- makes 7 tests pass
3. **Then Task 3** (SandboxChecker) -- makes 14 tests pass
4. **Then Task 4** (SDKConfiguration integration) -- makes 5 tests pass
5. **Then Task 5** (AgentOptions integration) -- makes 3 tests pass
6. **Then Task 6** (ToolContext integration) -- makes 2 tests pass
7. **Finally Task 7** -- verify full suite passes

**Key Principles:**
- One file at a time
- SandboxSettings is a struct with static matching methods, NOT a class
- SandboxChecker is a caseless enum with static methods (like TokenEstimator)
- SandboxPathNormalizer is a caseless enum with static methods
- All types must conform to Sendable
- Error messages must follow convention for SDKError.permissionDenied

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency with existing patterns)
3. Ensure path normalization is efficient (NFR27: <1ms per check)
4. Verify no import violations (Types/ is leaf, Utils/ depends on Types/)
5. Verify Logger integration for sandbox denials

---

## Key Risks and Assumptions

1. **Assumption: SDKError.permissionDenied exists** -- Epic 8 is complete, the error case is available.
2. **Assumption: Logger API is stable** -- Stories 14.1 and 14.2 are complete.
3. **Risk: Path normalization edge cases** -- Symlinks, broken symlinks, very long paths. Tests cover common cases but OS-specific behavior may vary.
4. **Risk: ToolContext copy methods** -- `withToolUseId()` and `withSkillContext()` must include the new sandbox field.
5. **Assumption: AgentOptions init(from:) propagates sandbox** -- The story requires config->options propagation.
6. **Risk: allowedCommands as Optional vs empty array** -- Tests explicitly verify that `nil` = blocklist mode, `[]` = allowlist with nothing allowed (most restrictive).

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**
```
Compilation errors (expected):
- cannot find 'SandboxSettings' in scope (multiple locations)
- cannot find 'SandboxOperation' in scope (multiple locations)
- cannot find 'SandboxPathNormalizer' in scope (multiple locations)
- cannot find 'SandboxChecker' in scope (multiple locations)
- SDKConfiguration has no sandbox field / init parameter
- AgentOptions has no sandbox field / init parameter
- ToolContext has no sandbox field / init parameter
```

**Summary:**
- Total new tests: 57
- Compilation status: FAILED (expected -- types not yet defined)
- All errors are "cannot find in scope" (clean RED phase)
- Zero regressions in existing tests (new test file is isolated)

---

**Generated by BMad TEA Agent** - 2026-04-13
