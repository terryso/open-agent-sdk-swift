---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/planning-artifacts/epics.md'
  - 'Sources/OpenAgentSDK/Utils/Logger.swift'
  - 'Sources/OpenAgentSDK/Types/LogLevel.swift'
  - 'Sources/OpenAgentSDK/Types/LogOutput.swift'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Examples/SandboxExample/main.swift'
  - 'Examples/SkillsExample/main.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/SandboxExampleComplianceTests.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/SkillsExampleComplianceTests.swift'
---

# ATDD Checklist - Epic 15, Story 3: LoggerExample

**Date:** 2026-04-13
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit / Static Analysis (Swift backend project, example compliance tests)

---

## Story Summary

Create a runnable LoggerExample program that demonstrates the logger system configuration and usage. The example should show all five log levels, console/file/custom output destinations, structured JSON format, Logger.reset(), and Agent integration with logging. This is an example/documentation story, not a new feature.

**As a** developer
**I want** a runnable example showing logger system configuration and usage
**So that** I can understand how to integrate SDK logs into my own logging pipeline (FR61, FR62)

---

## Acceptance Criteria

1. **AC1:** LoggerExample directory and main.swift exist, compiles without errors
2. **AC2:** Demonstrates all five log levels (none, error, warn, info, debug) and level filtering
3. **AC3:** Demonstrates LogOutput.console (structured JSON to stderr)
4. **AC4:** Demonstrates LogOutput.file(URL) writing to a log file
5. **AC5:** Demonstrates LogOutput.custom closure capturing logs (simulating ELK/Datadog)
6. **AC6:** Demonstrates structured JSON format (timestamp, level, module, event, data)
7. **AC7:** Demonstrates Logger.reset() and outputCount tracking
8. **AC8:** Demonstrates Agent integration with SDKConfiguration logLevel/logOutput
9. **AC9:** Package.swift has LoggerExample executableTarget
10. **AC10:** Code quality standards (comments, no force unwrap, public API signatures, no hardcoded API keys)

---

## Failing Tests Created (RED Phase)

### Compliance Tests - LoggerExampleComplianceTests (36 tests)

**File:** `Tests/OpenAgentSDKTests/Documentation/LoggerExampleComplianceTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testLoggerExampleDirectoryExists | AC1 | P0 | RED | Examples/LoggerExample/ does not exist |
| 2 | testLoggerExampleMainSwiftExists | AC1 | P0 | RED | Examples/LoggerExample/main.swift does not exist |
| 3 | testLoggerExampleImportsOpenAgentSDK | AC1 | P0 | RED | File not found |
| 4 | testLoggerExampleImportsFoundation | AC1 | P0 | RED | File not found |
| 5 | testLoggerExampleHasTopLevelDescriptionComment | AC1 | P1 | RED | File not found |
| 6 | testLoggerExampleHasMultipleInlineComments | AC1 | P1 | RED | File not found |
| 7 | testLoggerExampleHasMarkSections | AC1 | P1 | RED | File not found |
| 8 | testLoggerExampleDoesNotUseForceUnwrap | AC10 | P0 | RED | File not found |
| 9 | testPackageSwiftContainsLoggerExampleTarget | AC9 | P0 | RED | Package.swift missing LoggerExample target |
| 10 | testLoggerExampleTargetDependsOnOpenAgentSDK | AC9 | P0 | RED | Package.swift missing dependency |
| 11 | testLoggerExampleTargetSpecifiesCorrectPath | AC9 | P0 | RED | Package.swift missing path |
| 12 | testLoggerExampleDemonstratesAllLogLevels | AC2 | P0 | RED | File not found |
| 13 | testLoggerExampleDemonstratesLogLevelNone | AC2 | P0 | RED | File not found |
| 14 | testLoggerExampleDemonstratesLogLevelError | AC2 | P0 | RED | File not found |
| 15 | testLoggerExampleDemonstratesLogLevelWarn | AC2 | P0 | RED | File not found |
| 16 | testLoggerExampleDemonstratesLogLevelInfo | AC2 | P0 | RED | File not found |
| 17 | testLoggerExampleDemonstratesLogLevelDebug | AC2 | P0 | RED | File not found |
| 18 | testLoggerExampleDemonstratesLevelFiltering | AC2 | P0 | RED | File not found |
| 19 | testLoggerExampleUsesLogOutputConsole | AC3 | P0 | RED | File not found |
| 20 | testLoggerExampleUsesLogOutputFile | AC4 | P0 | RED | File not found |
| 21 | testLoggerExampleCreatesTempFileForLogging | AC4 | P1 | RED | File not found |
| 22 | testLoggerExampleUsesLogOutputCustom | AC5 | P0 | RED | File not found |
| 23 | testLoggerExampleDemonstratesCustomClosureCapture | AC5 | P0 | RED | File not found |
| 24 | testLoggerExampleDemonstratesStructuredJsonFormat | AC6 | P0 | RED | File not found |
| 25 | testLoggerExampleReferencesTimestamp | AC6 | P1 | RED | File not found |
| 26 | testLoggerExampleReferencesModule | AC6 | P1 | RED | File not found |
| 27 | testLoggerExampleReferencesEvent | AC6 | P1 | RED | File not found |
| 28 | testLoggerExampleUsesLoggerReset | AC7 | P0 | RED | File not found |
| 29 | testLoggerExampleUsesOutputCount | AC7 | P0 | RED | File not found |
| 30 | testLoggerExampleDemonstratesZeroOverheadNone | AC7 | P0 | RED | File not found |
| 31 | testLoggerExampleUsesSDKConfigurationWithLogLevel | AC8 | P0 | RED | File not found |
| 32 | testLoggerExampleCreatesAgentWithLogConfig | AC8 | P0 | RED | File not found |
| 33 | testLoggerExampleDoesNotExposeRealAPIKeys | AC10 | P0 | RED | File not found |
| 34 | testLoggerExampleUsesLoadDotEnvPattern | AC10 | P1 | RED | File not found |
| 35 | testLoggerExampleUsesGetEnvPattern | AC10 | P1 | RED | File not found |
| 36 | testLoggerExampleUsesLoggerConfigureStaticMethod | AC2 | P0 | RED | File not found |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). The LoggerExample is a documentation/example artifact, not a runtime feature. Test levels:
- **Compliance / static analysis tests** for all ACs -- verify file existence, code content, API usage patterns
- **No E2E tests** (no real LLM calls needed; compliance tests only check source code)
- **No unit tests for new logic** (no new SDK types introduced in this story)

### Approach

1. Tests verify that `Examples/LoggerExample/main.swift` exists and contains correct content
2. Content-based assertions check for specific API names (Logger, LogLevel, LogOutput, SDKConfiguration)
3. Package.swift assertions verify executableTarget configuration
4. Code quality checks (no force unwrap, no hardcoded API keys, comments)
5. Pattern matching ensures example demonstrates all log levels and output modes
6. Tests follow the same compliance-test pattern as SandboxExampleComplianceTests

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 26 | Core ACs: file existence, API usage, key demonstrations |
| P1 | 10 | Supporting: comments, edge case demonstrations, conventions |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Directory/file existence, compiles) | 7 | Compliance (file exists, imports, comments) |
| AC2 (Log levels and filtering) | 8 | Compliance (LogLevel enum values, configure, filtering) |
| AC3 (Console output) | 1 | Compliance (LogOutput.console) |
| AC4 (File output) | 2 | Compliance (LogOutput.file, temp file) |
| AC5 (Custom output) | 2 | Compliance (LogOutput.custom, closure capture) |
| AC6 (Structured JSON format) | 4 | Compliance (timestamp, level, module, event, data) |
| AC7 (Logger.reset and outputCount) | 3 | Compliance (reset, outputCount, zero overhead) |
| AC8 (Agent integration) | 2 | Compliance (SDKConfiguration logLevel, createAgent) |
| AC9 (Package.swift target) | 3 | Compliance (target, dependency, path) |
| AC10 (Code quality) | 4 | Compliance (no force unwrap, API keys, env patterns) |

---

## Implementation Checklist

### Task 1: Add LoggerExample executableTarget to Package.swift (AC: #9)

**File:** `Package.swift` (MODIFY)

**Tests this makes pass:**
- testPackageSwiftContainsLoggerExampleTarget
- testLoggerExampleTargetDependsOnOpenAgentSDK
- testLoggerExampleTargetSpecifiesCorrectPath

**Implementation steps:**
- [ ] Add `.executableTarget(name: "LoggerExample", dependencies: ["OpenAgentSDK"], path: "Examples/LoggerExample")` to targets array

### Task 2: Create Examples/LoggerExample/main.swift (AC: #1-#8, #10)

**File:** `Examples/LoggerExample/main.swift` (NEW)

**Tests this makes pass:** All 36 compliance tests

**Implementation steps:**
- [ ] Create directory `Examples/LoggerExample/`
- [ ] Create `main.swift` with top-level comment block describing the example
- [ ] Part 1: Log Levels and Console Output
  - [ ] `Logger.configure(level: .debug, output: .console)`
  - [ ] Call debug/info/warn/error with sample data
  - [ ] Show outputCount
  - [ ] Change to .warn, show filtering
  - [ ] Change to .none, show zero output
  - [ ] `Logger.reset()`
- [ ] Part 2: File and Custom Output
  - [ ] `Logger.configure(level: .info, output: .file(tempURL))`
  - [ ] Log messages, read file back
  - [ ] `Logger.reset()`
  - [ ] `Logger.configure(level: .debug, output: .custom { buffer.append($0) })`
  - [ ] Log messages, show buffer contents
  - [ ] Parse JSON to show structured fields
  - [ ] `Logger.reset()`
- [ ] Part 3: Agent with Logging
  - [ ] Configure `SDKConfiguration(logLevel: .debug, logOutput: .custom { ... })`
  - [ ] Create Agent
  - [ ] Execute query
  - [ ] Print captured log entries
  - [ ] `Logger.reset()`
- [ ] Use `loadDotEnv()` and `getEnv()` patterns for API key
- [ ] Add MARK section comments
- [ ] Add inline comments explaining each concept
- [ ] Ensure no force unwraps

### Task 3: Verify build and full test suite

- [ ] `swift build` compiles with no errors (including LoggerExample target)
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter "LoggerExampleComplianceTests"

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 36 compliance tests written in 1 test file, all failing because the example file does not exist yet
- Tests cover all 10 acceptance criteria
- Tests follow Given-When-Then format with descriptive test names
- Tests use same helper pattern as SandboxExampleComplianceTests (projectRoot, fileContent)
- Tests verify both structural (file exists, Package.swift) and content (API usage, patterns)

**Verification:**
- Tests do NOT pass (LoggerExample directory doesn't exist -- expected for RED phase)
- Failures are clean: "Examples/LoggerExample/ directory should exist"
- No crashes or unexpected behavior

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (Package.swift update) -- makes 3 tests pass
2. **Then Task 2** (Create LoggerExample/main.swift) -- makes remaining 33 tests pass
3. **Finally Task 3** -- verify full suite passes

**Key Principles:**
- Follow the SandboxExample and SkillsExample patterns for structure
- Logger, LogLevel, LogOutput already exist -- just use them
- Demonstrate all 5 log levels explicitly
- Demonstrate all 3 output modes (console, file, custom)
- Use `Logger.reset()` between demo sections
- Include inline comments explaining each logger concept
- The example should be educational -- each part should clearly demonstrate one concept

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency with existing examples)
3. Ensure the example runs correctly: `swift run LoggerExample`
4. Verify the example does not require an API key for Parts 1-2
5. Verify Part 3 (Agent integration) gracefully handles missing API key

---

## Key Risks and Assumptions

1. **Assumption: Logger, LogLevel, LogOutput are stable and public** -- Stories 14.1, 14.2 are complete with all APIs available.
2. **Assumption: Logger.shared is read-only singleton** -- Configure via `Logger.configure(level:output:)`, not by assigning to `shared`.
3. **Risk: File output temp path** -- The example should use a temp directory for file logging; avoid polluting the project directory.
4. **Risk: Agent integration part** -- The LLM-based demo part may require real API key; ensure static demos work independently.
5. **Assumption: loadDotEnv() and getEnv() helpers are available** -- Shared helpers in the Examples directory.

---

**Generated by BMad TEA Agent** - 2026-04-13
