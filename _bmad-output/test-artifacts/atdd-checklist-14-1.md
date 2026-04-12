---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/14-1-logger-type-and-injection.md'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ErrorTypes.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Tests/OpenAgentSDKTests/Utils/SDKConfigurationTests.swift'
  - 'Tests/OpenAgentSDKTests/Utils/CompactTests.swift'
---

# ATDD Checklist - Epic 14, Story 1: Logger Type and Injection

**Date:** 2026-04-12
**Author:** Nick (TEA Agent)
**Primary Test Level:** Unit (Swift backend project, XCTest)

---

## Story Summary

Establish the Logger type system (LogLevel enum, LogOutput enum, LogEntry struct, Logger singleton) and integrate it into SDKConfiguration so that developers can configure log levels and output destinations. All SDK components (Agent, QueryEngine, ToolExecutor) will log through Logger.shared.

**As a** developer
**I want** to configure the SDK's log level and inject a Logger through SDKConfiguration
**So that** I can get detailed logs during development and keep production silent

---

## Acceptance Criteria

1. **AC1:** LogLevel enum and SDKConfiguration integration -- `SDKConfiguration` gains `logLevel: LogLevel` and `logOutput: LogOutput` fields; setting `config.logLevel = .debug` results in `Logger.shared.level == .debug`; Agent, QueryEngine, ToolExecutor log through `Logger.shared` (FR61)
2. **AC2:** Console output (default) -- `config.logOutput = .console` writes structured JSON to stderr
3. **AC3:** File output -- `config.logOutput = .file(URL)` appends structured JSON to specified file
4. **AC4:** Custom output -- `config.logOutput = .custom { jsonLine in ... }` passes JSON string to developer's closure (FR62)
5. **AC5:** Zero overhead when disabled -- `logLevel = .none` produces `Logger.shared.outputCount == 0`; guards use conditional checks
6. **AC6:** Error-level logging -- `logLevel = .error` outputs one entry with `error.message`, `error.statusCode`, `error.context` when `SDKError.apiError` occurs
7. **AC7:** Test reset and injection -- `Logger.reset()` clears `outputCount` and reverts to `.none`; test injection via `Logger.configure(level:output:)`

---

## Failing Tests Created (RED Phase)

### Unit Tests (28 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/LoggerTests.swift` (~720 lines)

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testLogLevelEnum_HasAllCases | AC1 | P0 | RED | `LogLevel` type not found |
| 2 | testLogLevelEnum_ComparableOrdering | AC1 | P0 | RED | `LogLevel` does not conform to `Comparable` |
| 3 | testLogLevelEnum_RawValues | AC1 | P0 | RED | `LogLevel` raw values not found |
| 4 | testLogLevelEnum_CustomStringConvertible | AC1 | P1 | RED | `LogLevel` does not conform to `CustomStringConvertible` |
| 5 | testLogLevelEnum_CaseIterable | AC1 | P1 | RED | `LogLevel` does not conform to `CaseIterable` |
| 6 | testLogLevelEnum_Sendable | AC1 | P0 | RED | `LogLevel` does not conform to `Sendable` |
| 7 | testLogOutputEnum_HasConsoleFileCustomCases | AC2-4 | P0 | RED | `LogOutput` type not found |
| 8 | testLogOutputEnum_ConsoleCase | AC2 | P1 | RED | `LogOutput.console` not found |
| 9 | testLogOutputEnum_FileCase | AC3 | P1 | RED | `LogOutput.file(URL)` not found |
| 10 | testLogOutputEnum_CustomCase | AC4 | P1 | RED | `LogOutput.custom` closure case not found |
| 11 | testLogOutputEnum_Sendable | AC2-4 | P0 | RED | `LogOutput` does not conform to `Sendable` |
| 12 | testLoggerShared_IsAccessible | AC1 | P0 | RED | `Logger.shared` not found |
| 13 | testLoggerDefaultLevelIsNone | AC5 | P0 | RED | `Logger` type or `level` property not found |
| 14 | testLoggerConfigure_SetsLevelAndOutput | AC7 | P0 | RED | `Logger.configure(level:output:)` not found |
| 15 | testLoggerReset_RevertsToDefaults | AC7 | P0 | RED | `Logger.reset()` not found |
| 16 | testLoggerOutputCountStartsAtZero | AC7 | P0 | RED | `Logger.shared.outputCount` not found |
| 17 | testLoggerDebugLogsAtDebugLevel | AC1 | P0 | RED | `Logger.shared.debug(...)` not found |
| 18 | testLoggerInfoLogsAtInfoLevel | AC1 | P0 | RED | `Logger.shared.info(...)` not found |
| 19 | testLoggerWarnLogsAtWarnLevel | AC1 | P0 | RED | `Logger.shared.warn(...)` not found |
| 20 | testLoggerErrorLogsAtErrorLevel | AC6 | P0 | RED | `Logger.shared.error(...)` not found |
| 21 | testLoggerZeroOverheadWhenNone | AC5 | P0 | RED | Logger methods not found / outputCount assertion fails |
| 22 | testLoggerFiltersBelowCurrentLevel | AC1 | P0 | RED | Level filtering not implemented |
| 23 | testLoggerConsoleOutput_WritesJSONToStderr | AC2 | P0 | RED | Console output not implemented |
| 24 | testLoggerFileOutput_AppendsJSONToFile | AC3 | P0 | RED | File output not implemented |
| 25 | testLoggerCustomOutput_PassesJSONToClosure | AC4 | P0 | RED | Custom output not implemented |
| 26 | testLoggerErrorLevel_LogsAPIErrorDetails | AC6 | P0 | RED | Error log entry field extraction not implemented |
| 27 | testSDKConfiguration_HasLogLevelField | AC1 | P0 | RED | `SDKConfiguration.logLevel` field not found |
| 28 | testSDKConfiguration_HasLogOutputField | AC1 | P0 | RED | `SDKConfiguration.logOutput` field not found |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). Test levels:
- **Unit tests** for type definitions (`LogLevel`, `LogOutput`, `LogEntry`)
- **Unit tests** for Logger singleton behavior (configure, reset, output, filtering)
- **Unit tests** for SDKConfiguration integration (new fields, defaults)
- **No E2E tests** (no UI component, no browser)

### Priority Assignments

- **P0** (must-have): Core types exist, Logger singleton works, level filtering, zero-overhead when disabled, all three output modes, SDKConfiguration integration
- **P1** (should-have): Protocol conformances (`CustomStringConvertible`, `CaseIterable`), individual output case details
- **P2** (nice-to-have): Edge cases around concurrent access, file output error handling

---

## Implementation Checklist

### Test: testLogLevelEnum_HasAllCases (P0, AC1)

**Tasks to make this test pass:**

- [ ] Create `Sources/OpenAgentSDK/Types/LogLevel.swift`
- [ ] Define `public enum LogLevel: Int, Comparable, CaseIterable, Sendable` with cases: `none = 0, error = 1, warn = 2, info = 3, debug = 4`
- [ ] Implement `Comparable` based on rawValue
- [ ] Run test: `swift test --filter LogLevelEnum_HasAllCases`

### Test: testLogLevelEnum_ComparableOrdering (P0, AC1)

**Tasks to make this test pass:**

- [ ] Ensure `Comparable` conformance compares `rawValue` values (higher = more verbose)
- [ ] Run test: `swift test --filter testLogLevelEnum_ComparableOrdering`

### Test: testLogLevelEnum_RawValues (P0, AC1)

**Tasks to make this test pass:**

- [ ] Set rawValues: `none=0, error=1, warn=2, info=3, debug=4`
- [ ] Run test: `swift test --filter testLogLevelEnum_RawValues`

### Test: testLogLevelEnum_CustomStringConvertible (P1, AC1)

**Tasks to make this test pass:**

- [ ] Implement `CustomStringConvertible` returning lowercase name strings
- [ ] Run test: `swift test --filter testLogLevelEnum_CustomStringConvertible`

### Test: testLogLevelEnum_CaseIterable (P1, AC1)

**Tasks to make this test pass:**

- [ ] Ensure `CaseIterable` conformance with `allCases` in order
- [ ] Run test: `swift test --filter testLogLevelEnum_CaseIterable`

### Test: testLogLevelEnum_Sendable (P0, AC1)

**Tasks to make this test pass:**

- [ ] Ensure `LogLevel` conforms to `Sendable` (enum with Int rawValue is inherently Sendable)
- [ ] Run test: `swift test --filter testLogLevelEnum_Sendable`

### Test: testLogOutputEnum_HasConsoleFileCustomCases (P0, AC2-4)

**Tasks to make this test pass:**

- [ ] Create `Sources/OpenAgentSDK/Types/LogOutput.swift`
- [ ] Define `public enum LogOutput: Sendable` with cases: `.console`, `.file(URL)`, `.custom(@Sendable (String) -> Void)`
- [ ] Run test: `swift test --filter testLogOutputEnum_HasConsoleFileCustomCases`

### Test: testLogOutputEnum_ConsoleCase (P1, AC2)

**Tasks to make this test pass:**

- [ ] Ensure `.console` case exists and is the default
- [ ] Run test: `swift test --filter testLogOutputEnum_ConsoleCase`

### Test: testLogOutputEnum_FileCase (P1, AC3)

**Tasks to make this test pass:**

- [ ] Ensure `.file(URL)` case accepts file URL
- [ ] Run test: `swift test --filter testLogOutputEnum_FileCase`

### Test: testLogOutputEnum_CustomCase (P1, AC4)

**Tasks to make this test pass:**

- [ ] Ensure `.custom(@Sendable (String) -> Void)` case accepts closure
- [ ] Run test: `swift test --filter testLogOutputEnum_CustomCase`

### Test: testLogOutputEnum_Sendable (P0, AC2-4)

**Tasks to make this test pass:**

- [ ] Ensure all cases are `Sendable` (closures marked `@Sendable`)
- [ ] Run test: `swift test --filter testLogOutputEnum_Sendable`

### Test: testLoggerShared_IsAccessible (P0, AC1)

**Tasks to make this test pass:**

- [ ] Create `Sources/OpenAgentSDK/Utils/Logger.swift`
- [ ] Define `public final class Logger` with `public static let shared: Logger`
- [ ] Run test: `swift test --filter testLoggerShared_IsAccessible`

### Test: testLoggerDefaultLevelIsNone (P0, AC5)

**Tasks to make this test pass:**

- [ ] Default `level` property to `.none`
- [ ] Run test: `swift test --filter testLoggerDefaultLevelIsNone`

### Test: testLoggerConfigure_SetsLevelAndOutput (P0, AC7)

**Tasks to make this test pass:**

- [ ] Implement `public static func configure(level: LogLevel, output: LogOutput)`
- [ ] Run test: `swift test --filter testLoggerConfigure_SetsLevelAndOutput`

### Test: testLoggerReset_RevertsToDefaults (P0, AC7)

**Tasks to make this test pass:**

- [ ] Implement `public static func reset()` to restore defaults
- [ ] Run test: `swift test --filter testLoggerReset_RevertsToDefaults`

### Test: testLoggerOutputCountStartsAtZero (P0, AC7)

**Tasks to make this test pass:**

- [ ] Add `public private(set) var outputCount: Int` initialized to 0
- [ ] Run test: `swift test --filter testLoggerOutputCountStartsAtZero`

### Tests: testLoggerDebugLogsAtDebugLevel through testLoggerErrorLogsAtErrorLevel (P0, AC1/AC6)

**Tasks to make this test pass:**

- [ ] Implement per-level convenience methods: `error()`, `warn()`, `info()`, `debug()`
- [ ] Each method guards on current level before logging
- [ ] Core log method creates entry and dispatches to current `LogOutput`
- [ ] Run tests: `swift test --filter testLogger`

### Test: testLoggerZeroOverheadWhenNone (P0, AC5)

**Tasks to make this test pass:**

- [ ] Ensure guard `level != .none` early-returns in all log methods
- [ ] Run test: `swift test --filter testLoggerZeroOverheadWhenNone`

### Test: testLoggerFiltersBelowCurrentLevel (P0, AC1)

**Tasks to make this test pass:**

- [ ] Implement level filtering: only log if `self.level >= messageLevel`
- [ ] Run test: `swift test --filter testLoggerFiltersBelowCurrentLevel`

### Test: testLoggerConsoleOutput_WritesJSONToStderr (P0, AC2)

**Tasks to make this test pass:**

- [ ] Implement `.console` output writing JSON to `FileHandle.standardError`
- [ ] Run test: `swift test --filter testLoggerConsoleOutput_WritesJSONToStderr`

### Test: testLoggerFileOutput_AppendsJSONToFile (P0, AC3)

**Tasks to make this test pass:**

- [ ] Implement `.file(URL)` output appending JSON lines to file
- [ ] Run test: `swift test --filter testLoggerFileOutput_AppendsJSONToFile`

### Test: testLoggerCustomOutput_PassesJSONToClosure (P0, AC4)

**Tasks to make this test pass:**

- [ ] Implement `.custom` output passing JSON string to developer's closure
- [ ] Run test: `swift test --filter testLoggerCustomOutput_PassesJSONToClosure`

### Test: testLoggerErrorLevel_LogsAPIErrorDetails (P0, AC6)

**Tasks to make this test pass:**

- [ ] Log entry includes `error.message`, `error.statusCode` from `SDKError.apiError`
- [ ] Run test: `swift test --filter testLoggerErrorLevel_LogsAPIErrorDetails`

### Test: testSDKConfiguration_HasLogLevelField (P0, AC1)

**Tasks to make this test pass:**

- [ ] Add `public var logLevel: LogLevel` to `SDKConfiguration` with default `.none`
- [ ] Add to init, description, debugDescription, resolved(), Equatable
- [ ] Run test: `swift test --filter testSDKConfiguration_HasLogLevelField`

### Test: testSDKConfiguration_HasLogOutputField (P0, AC1)

**Tasks to make this test pass:**

- [ ] Add `public var logOutput: LogOutput` to `SDKConfiguration` with default `.console`
- [ ] Add to init, description, debugDescription, resolved(), Equatable
- [ ] Run test: `swift test --filter testSDKConfiguration_HasLogOutputField`

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter LoggerTests

# Run all failing tests for LogLevel
swift test --filter LogLevelEnum

# Run all failing tests for LogOutput
swift test --filter LogOutputEnum

# Run specific test file
swift test --filter LoggerTests.swift
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All 28 tests written and designed to fail
- Tests cover all 7 acceptance criteria
- Tests follow XCTest patterns consistent with existing codebase
- Implementation checklist maps each test to concrete tasks

**Verification:**

- All tests will fail due to missing `LogLevel`, `LogOutput`, `Logger` types and missing `SDKConfiguration` fields
- Failure messages are clear: "cannot find 'LogLevel' in scope", "value of type 'SDKConfiguration' has no member 'logLevel'"

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. Start with `LogLevel` enum (Tests 1-6)
2. Create `LogOutput` enum (Tests 7-11)
3. Implement `Logger` singleton (Tests 12-26)
4. Integrate into `SDKConfiguration` (Tests 27-28)
5. Integrate into `Agent.init` (no dedicated test, but Logger.configure called)
6. Run full test suite to verify no regressions

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Verify all 28 tests pass
2. Review Logger for thread safety (NSLock usage)
3. Ensure JSON output format is consistent
4. Run `swift test` for full regression suite

---

## Next Steps

1. **Share this checklist and failing tests** with the dev workflow
2. **Run failing tests** to confirm RED phase: `swift test --filter LoggerTests`
3. **Begin implementation** using implementation checklist as guide
4. **Work one test group at a time** (LogLevel -> LogOutput -> Logger -> SDKConfiguration)
5. **Run full test suite** after all tests pass to check for regressions
6. **When refactoring complete**, update story status

---

## Knowledge Base References Applied

- **component-tdd.md** - TDD strategies for component-level testing
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test, determinism, isolation)
- **data-factories.md** - Factory patterns for test data generation
- **test-levels-framework.md** - Test level selection (unit vs integration vs E2E)
- **test-healing-patterns.md** - Patterns for resilient tests

---

## Notes

- Logger as `final class` with `NSLock` follows the pattern established by `FileCache`, `GitContextCollector`, `ProjectDocumentDiscovery`, and `SessionMemory`
- `LogLevel` uses `Int` rawValue for `Comparable` (higher = more verbose)
- `LogOutput.custom` closures always compare as equal in `Equatable` (closures cannot be compared)
- `LogEntry.toJSON()` uses `[String: String]` for data dictionary to maintain Sendable conformance
- All tests use `setUp()` and `tearDown()` to call `Logger.reset()` for test isolation

---

**Generated by BMad TEA Agent** - 2026-04-12
