---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-04'
inputDocuments:
  - _bmad-output/implementation-artifacts/1-3-sdk-config-env-vars.md
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Tests/OpenAgentSDKTests/API/AnthropicClientTests.swift
  - Package.swift
---

# ATDD Checklist: Story 1-3 (SDK Config & Env Vars)

## TDD Red Phase (Current)

**Status:** Failing tests generated -- all tests reference `SDKConfiguration` and `SDKConfiguration.fromEnvironment()` which do not exist yet.

## Test Files Created

| File | Test Class | Count | AC Coverage |
|------|-----------|-------|-------------|
| `Tests/OpenAgentSDKTests/Utils/SDKConfigurationTests.swift` | `SDKConfigurationEnvVarTests` | 5 | AC1 |
| | `SDKConfigurationProgrammaticTests` | 4 | AC2 |
| | `SDKConfigurationDefaultsTests` | 6 | AC3 |
| | `SDKConfigurationCompilationTests` | 3 | AC4 |
| | `SDKConfigurationSecurityTests` | 5 | AC5 |
| | `SDKConfigurationAgentOptionsTests` | 7 | AC6 |
| **Total** | **6 classes** | **30 tests** | **AC1-AC6** |

## Acceptance Criteria Coverage

### AC1: Environment Variable Reading (P0) -- 5 tests
- [x] `testFromEnvironmentReadsAPIKey` -- reads CODEANY_API_KEY
- [x] `testFromEnvironmentReadsModel` -- reads CODEANY_MODEL
- [x] `testFromEnvironmentReadsBaseURL` -- reads CODEANY_BASE_URL
- [x] `testFromEnvironmentReturnsDefaultsWhenNoVarsSet` -- nil env vars yield defaults
- [x] `testFromEnvironmentReadsAllVarsAtOnce` -- all three vars read simultaneously

### AC2: Programmatic Configuration (P0) -- 4 tests
- [x] `testProgrammaticInitWithAllProperties` -- all properties set programmatically
- [x] `testProgrammaticInitMinimal` -- apiKey + model only
- [x] `testProgrammaticInitNoParameters` -- all defaults
- [x] `testSDKConfigurationIsStruct` -- value type semantics verified

### AC3: Reasonable Defaults (P0) -- 6 tests
- [x] `testDefaultModel` -- "claude-sonnet-4-6"
- [x] `testDefaultMaxTurns` -- 10
- [x] `testDefaultMaxTokens` -- 16384
- [x] `testDefaultAPIKeyIsNil` -- nil
- [x] `testDefaultBaseURLIsNil` -- nil
- [x] `testOnlyAPIKeyAndModelSet` -- remaining fields stay at defaults

### AC4: Dual Platform Compilation (P1) -- 3 tests
- [x] `testCompilesWithFoundationOnly` -- no Apple-specific imports
- [x] `testSDKConfigurationIsSendable` -- Sendable conformance verified
- [x] `testSDKConfigurationIsEquatable` -- Equatable conformance verified

### AC5: API Key Security (P0) -- 5 tests
- [x] `testDescriptionMasksAPIKey` -- description shows "***"
- [x] `testDebugDescriptionMasksAPIKey` -- debugDescription shows "***"
- [x] `testDescriptionWithNilAPIKey` -- handles nil without crash
- [x] `testDescriptionWithEmptyAPIKey` -- empty string handled
- [x] `testDescriptionMasksAPIKeyWithSpecialCharacters` -- special chars masked

### AC6: AgentOptions Integration (P0) -- 7 tests
- [x] `testAgentOptionsFromSDKConfiguration` -- convenience init works
- [x] `testAgentOptionsFromSDKConfigurationPreservesAgentDefaults` -- Agent-specific fields default
- [x] `testResolvedUsesEnvironmentAsFallback` -- env vars as fallback
- [x] `testResolvedProgrammaticOverridesTakePrecedence` -- programmatic > env
- [x] `testResolvedWithNilOverridesUsesOnlyEnvVars` -- nil overrides uses env
- [x] `testResolvedWithNoEnvVarsAndNoOverrides` -- no env, no overrides = defaults
- [x] `testResolvedPartialOverride` -- partial override, env fills rest

## Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 22 | Critical path -- env vars, programmatic config, defaults, security, integration |
| P1 | 3 | Platform compilation, protocol conformance |
| P2 | 5 | Edge cases -- nil handling, empty strings, partial overrides |
| **Total** | **30** | |

## Test Level Strategy

This is a **backend Swift** project. All tests are **unit-level** using XCTest.

- **Unit tests:** SDKConfiguration struct creation, property access, env var reading, description masking, merge/resolve logic, AgentOptions integration
- **No E2E tests:** No browser/UI component
- **No API contract tests:** SDKConfiguration is a pure data type with no network calls

## TDD Red Phase Verification

All tests are designed to **fail at compilation** because:
1. `SDKConfiguration` type does not exist yet (referenced in all 30 tests)
2. `SDKConfiguration.fromEnvironment()` static method does not exist (AC1 tests)
3. `SDKConfiguration.resolved(overrides:)` static method does not exist (AC6 tests)
4. `AgentOptions(from: SDKConfiguration)` convenience initializer does not exist (AC6 tests)
5. `debugDescription` property does not exist on SDKConfiguration (AC5 tests)

## Implementation Files Required (Green Phase)

The following source files need to be created/modified to make these tests pass:

| File | Action | Description |
|------|--------|-------------|
| `Sources/OpenAgentSDK/Types/SDKConfiguration.swift` | **Create** | SDKConfiguration struct with Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible |
| `Sources/OpenAgentSDK/Utils/EnvUtils.swift` | **Create** | Cross-platform env var reading via ProcessInfo |
| `Sources/OpenAgentSDK/Types/AgentTypes.swift` | **Modify** | Add `init(from: SDKConfiguration)` convenience initializer |
| `Sources/OpenAgentSDK/OpenAgentSDK.swift` | **Modify** | Re-export SDKConfiguration if needed |

## Next Steps (TDD Green Phase)

1. Implement `SDKConfiguration` struct in `Sources/OpenAgentSDK/Types/SDKConfiguration.swift`
2. Implement `EnvUtils` in `Sources/OpenAgentSDK/Utils/EnvUtils.swift`
3. Add `AgentOptions(from:)` convenience initializer
4. Run `swift test` -- verify all 30 tests pass (green phase)
5. Refactor if needed (refactor phase)

## Risks & Assumptions

- **Assumption:** `setenv`/`unsetenv` work correctly in test process for env var testing (standard on macOS/Linux)
- **Assumption:** `ProcessInfo.processInfo.environment` reflects `setenv` changes within the same process (verified: it does on macOS via Swift Foundation)
- **Risk:** Empty string API key handling -- story says empty/whitespace should be treated as nil, but test only checks empty string. May need additional whitespace tests during green phase.
- **Risk:** `debugDescription` requires `CustomDebugStringConvertible` conformance -- implementation must conform to both `CustomStringConvertible` and `CustomDebugStringConvertible`

## Environment Notes

- Build verified: `swift build` succeeds (base library compiles)
- Test build requires full Xcode toolchain (not just Command Line Tools) for XCTest resolution
- CI uses `swift test` on macos-15 runner with full Xcode
