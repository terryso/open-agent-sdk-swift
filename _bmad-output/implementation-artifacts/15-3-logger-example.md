# Story 15.3: LoggerExample

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a runnable example demonstrating the logger system configuration and usage,
so that I can understand how to integrate SDK logs into my own logging pipeline (FR61-FR62).

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/LoggerExample/` directory with a `main.swift` file and corresponding `LoggerExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: Log levels demonstrated** -- Given the example code, when reading the code, it demonstrates all five log levels (`none`, `error`, `warn`, `info`, `debug`) and shows how changing levels filters which messages are output.

3. **AC3: Console output** -- Given the example code, when reading the code, it demonstrates `LogOutput.console` (default) writing structured JSON to stderr.

4. **AC4: File output** -- Given the example code, when reading the code, it demonstrates `LogOutput.file(URL)` writing structured JSON lines to a log file.

5. **AC5: Custom output handler** -- Given the example code, when reading the code, it demonstrates `LogOutput.custom { jsonLine in ... }` capturing logs with a closure (simulating ELK/Datadog integration).

6. **AC6: Structured JSON format** -- Given the example code, when running Parts 1-3 (which use `Logger.shared` directly), each log line is valid JSON with fields: `timestamp` (ISO 8601), `level` (string), `module` (string), `event` (string), `data` (key-value dict).

7. **AC7: Logger.reset() and outputCount** -- Given the example code, it demonstrates calling `Logger.reset()` to clear state and shows `outputCount` tracking the number of emitted log entries.

8. **AC8: Agent integration** -- Given an Agent configured with `SDKConfiguration(logLevel: .debug, logOutput: .custom { ... })`, when the Agent executes a query, the custom handler receives structured log entries including `llm_response` and `tool_result` events.

9. **AC9: Package.swift updated** -- Given the Package.swift file, when adding the `LoggerExample` executable target, it follows the exact same pattern as existing examples (e.g., `SandboxExample`, `SkillsExample`).

## Tasks / Subtasks

- [x] Task 1: Create example directory and file (AC: #1, #9)
  - [x] Create `Examples/LoggerExample/main.swift`
  - [x] Add `.executableTarget(name: "LoggerExample", dependencies: ["OpenAgentSDK"], path: "Examples/LoggerExample")` to Package.swift

- [x] Task 2: Write Part 1 -- Log Levels and Console Output (AC: #2, #3, #6, #7)
  - [x] Configure `Logger.configure(level: .debug, output: .console)`
  - [x] Call `Logger.shared.debug/info/warn/error` with sample module/event/data
  - [x] Show `outputCount` after logging
  - [x] Demonstrate level filtering: set `.warn`, show only warn+error emitted
  - [x] Demonstrate `.none` level: show `outputCount == 0`
  - [x] Call `Logger.reset()` to restore defaults

- [x] Task 3: Write Part 2 -- File and Custom Output (AC: #4, #5, #6)
  - [x] Configure `Logger.configure(level: .info, output: .file(URL))` with a temp file
  - [x] Log a few messages, read back file contents, print the JSON lines
  - [x] Configure `Logger.configure(level: .debug, output: .custom { buffer.append($0) })`
  - [x] Log messages, show custom handler captured them
  - [x] Parse a JSON line to show the structured fields (timestamp, level, module, event, data)
  - [x] Call `Logger.reset()`

- [x] Task 4: Write Part 3 -- Agent with Logging (AC: #8)
  - [x] Configure `AgentOptions(logLevel: .debug, logOutput: .custom { ... })` with a buffer
  - [x] Create Agent with the config
  - [x] Execute a simple query
  - [x] Print captured log entries showing `llm_response` / `tool_result` events
  - [x] Call `Logger.reset()` to clean up

- [x] Task 5: Verify build (AC: #1)
  - [x] `swift build` compiles with no errors/warnings
  - [x] Manual smoke-test of `swift run LoggerExample`

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), third story
- **Core goal:** Create a runnable example demonstrating the Logger system API (`Logger`, `LogLevel`, `LogOutput`)
- **Prerequisites:** Epic 14 (Logger system) is DONE -- all types exist
- **FR coverage:** FR61-FR62 (example/illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface (from Epic 14 implementation)

The following public API is already implemented and available for the example:

```swift
// Types/LogLevel.swift
public enum LogLevel: Int, Comparable, CaseIterable, Sendable {
    case none = 0
    case error = 1
    case warn = 2
    case info = 3
    case debug = 4
}

// Types/LogOutput.swift
public enum LogOutput: Sendable {
    case console                                           // writes to stderr
    case file(URL)                                         // appends to file
    case custom(@Sendable (String) -> Void)                // custom handler
}

// Utils/Logger.swift
public final class Logger: @unchecked Sendable {
    public static let shared: Logger                       // singleton (read-only)
    public private(set) var level: LogLevel
    public private(set) var outputCount: Int

    public static func configure(level: LogLevel, output: LogOutput)
    public static func reset()

    public func debug(_ module: String, _ event: String, data: [String: String] = [:])
    public func info(_ module: String, _ event: String, data: [String: String] = [:])
    public func warn(_ module: String, _ event: String, data: [String: String] = [:])
    public func error(_ module: String, _ event: String, data: [String: String] = [:])
}

// Types/SDKConfiguration.swift
public struct SDKConfiguration: Sendable {
    public var logLevel: LogLevel          // default: .none
    public var logOutput: LogOutput        // default: .console
    public init(logLevel:logOutput:...)
}
```

### Example Pattern to Follow

Follow the exact same patterns as existing examples (SkillsExample, SandboxExample):

1. **Header comment** -- Chinese + English header block listing what the example demonstrates
2. **API key loading** -- Use `loadDotEnv()` and `getEnv()` helper pattern:
   ```swift
   let dotEnv = loadDotEnv()
   let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
       ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
       ?? "sk-..."
   let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
   let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
   ```
3. **MARK sections** -- Use `// MARK: - Part N: Title` for each section
4. **Agent creation** -- Use `createAgent(options:)` with `permissionMode: .bypassPermissions`
5. **Output formatting** -- Print sections with clear headers, show pass/fail results

### Important Implementation Details

1. **Parts 1 & 2 work without an API key** -- The Logger API can be called directly via `Logger.shared` without any Agent or LLM call. Only Part 3 (Agent integration) requires a valid API key.

2. **Logger.reset() is essential between parts** -- Each part should start with `Logger.reset()` to clear the `outputCount` and level. Without reset, the previous part's state leaks into the next.

3. **Console output goes to stderr** -- When using `LogOutput.console`, log lines are written to stderr (FileHandle.standardError). The example should note this so developers understand why print() and log output go to different streams.

4. **File output creates/overwrites** -- `Logger.dispatchOutput` creates the file if it doesn't exist, or appends if it does. Use a temporary file URL to avoid polluting the project directory.

5. **Custom handler receives raw JSON strings** -- The `.custom` closure receives the raw JSON line string. The example should parse one with `JSONSerialization.jsonObject(with:)` to demonstrate the structured fields.

6. **LogLevel ordering matters** -- `LogLevel` conforms to `Comparable` via rawValue. `.debug` (4) > `.info` (3) > `.warn` (2) > `.error` (1) > `.none` (0). Setting level to `.warn` means only `.warn` and `.error` messages pass through.

7. **outputCount is cumulative** -- `outputCount` increments on every emitted log line. Reset it with `Logger.reset()` between demo sections.

### Example Structure (3 Parts)

```
Part 1: Log Levels and Console Output
  - Logger.configure(level: .debug, output: .console)
  - Log at all four levels (debug/info/warn/error) with sample data
  - Print outputCount
  - Change to .warn level, log again, show only warn+error pass
  - Change to .none, log, show outputCount stays 0
  - Logger.reset()

Part 2: File and Custom Output
  - Logger.configure(level: .info, output: .file(tempURL))
  - Log messages, read file back, print JSON lines
  - Logger.reset()
  - Logger.configure(level: .debug, output: .custom { buffer.append($0) })
  - Log messages, show buffer contents
  - Parse one JSON line to show structured fields
  - Logger.reset()

Part 3: Agent with Logging
  - Configure SDKConfiguration with logLevel: .debug, logOutput: .custom { ... }
  - Create Agent with the config
  - Execute simple query
  - Print captured log entries (llm_response, tool_result events)
  - Logger.reset()
```

### File Locations

```
Examples/LoggerExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add LoggerExample executable target
```

### Package.swift Change

Add after the `SandboxExample` target:

```swift
.executableTarget(
    name: "LoggerExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/LoggerExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run LoggerExample` should output logger demos
- **No new unit tests needed** -- this is an example, not production code
- The example itself serves as an integration test of the Logger API surface
- Note: Parts 1 and 2 work without an API key. Only Part 3 requires a valid API key.

### Previous Story Intelligence (Story 15.2: SandboxExample)

- **Pattern confirmed:** Chinese + English header comment block, MARK sections, `loadDotEnv()`/`getEnv()` for API key, `createAgent` with `permissionMode: .bypassPermissions`
- **File structure:** Single `main.swift` file in `Examples/<Name>/` directory
- **Package.swift pattern:** `.executableTarget(name: "...", dependencies: ["OpenAgentSDK"], path: "Examples/...")`
- **Build verified:** `swift build` compiles with no errors/warnings
- **Important lesson from 15-2:** Some utility types (SandboxChecker, SandboxPathNormalizer) were `internal` and had to be made `public`. Logger is already `public final class`, LogLevel is `public enum`, LogOutput is `public enum` -- all accessible from examples without changes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.3] -- Full acceptance criteria for LoggerExample
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 14 Stories 14.1-14.2] -- Logger system design and API
- [Source: Sources/OpenAgentSDK/Utils/Logger.swift] -- `Logger` class with configure/reset/debug/info/warn/error
- [Source: Sources/OpenAgentSDK/Types/LogLevel.swift] -- `LogLevel` enum (none/error/warn/info/debug)
- [Source: Sources/OpenAgentSDK/Types/LogOutput.swift] -- `LogOutput` enum (console/file/custom)
- [Source: Sources/OpenAgentSDK/Types/SDKConfiguration.swift] -- `SDKConfiguration.logLevel` and `logOutput` fields
- [Source: Examples/SandboxExample/main.swift] -- Pattern: Chinese+English header, MARK sections, 3-part structure
- [Source: Examples/SkillsExample/main.swift] -- Pattern: agent creation, query stats
- [Source: Package.swift] -- Existing executable target definitions to follow

## Dev Agent Record

### Agent Model Used

GLM-5.1 (via Claude Code Agent SDK)

### Debug Log References

### Completion Notes List

- Task 1: Created Examples/LoggerExample/main.swift and added executable target to Package.swift following SandboxExample pattern.
- Task 2: Part 1 demonstrates all 5 LogLevel values (.debug/.info/.warn/.error/.none), Logger.configure(), outputCount tracking, and level filtering with assertions.
- Task 3: Part 2 demonstrates LogOutput.file (writing to temp file, reading back), LogOutput.custom (capturing via LogBuffer class), and JSON parsing to show structured fields (timestamp, level, module, event, data).
- Task 4: Part 3 creates Agent with AgentOptions(logLevel: .debug, logOutput: .custom {...}) and captures runtime log events (llm_response, tool_result). Used LogBuffer class (thread-safe via NSLock) instead of mutable array to satisfy Sendable closure requirements.
- Task 5: swift build compiles with 0 errors and 0 warnings. All 2774 tests pass (0 failures, 4 skipped).
- Design decision: Used AgentOptions.logLevel/logOutput directly instead of SDKConfiguration since AgentOptions exposes these fields directly and is the standard pattern for agent creation.
- Design decision: Created LogBuffer class for thread-safe log capture in @Sendable closures. Used in both Part 2 (custom output) and Part 3 (agent integration).

### File List

- Examples/LoggerExample/main.swift (NEW)
- Package.swift (MODIFIED - added LoggerExample executable target)
- Tests/OpenAgentSDKTests/Documentation/LoggerExampleComplianceTests.swift (NEW - 36 compliance tests)
