import XCTest
@testable import OpenAgentSDK

// MARK: - ATDD RED PHASE: Story 14.1 -- Logger Type and Injection
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - `Types/LogLevel.swift` is created with LogLevel enum
//   - `Types/LogOutput.swift` is created with LogOutput enum
//   - `Utils/Logger.swift` is created with Logger singleton class
//   - `Types/SDKConfiguration.swift` is modified to add logLevel and logOutput fields
// TDD Phase: GREEN (feature implemented)

// MARK: - Test helper for capturing log output in @Sendable closures

/// Thread-safe box for capturing log lines from @Sendable closures.
private final class LogCapture: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        lines.removeAll()
    }
}

// MARK: - LogLevel Enum Tests (AC1)

final class LogLevelEnumTests: XCTestCase {

    // MARK: - AC1: LogLevel enum exists with all required cases

    /// AC1 [P0]: LogLevel enum has all five cases: none, error, warn, info, debug.
    func testLogLevelEnum_HasAllCases() {
        let cases: [LogLevel] = [.none, .error, .warn, .info, .debug]

        XCTAssertEqual(cases.count, 5,
                       "LogLevel should have exactly 5 cases")
        // This will fail at compile time if any case is missing
        XCTAssertEqual(LogLevel.none.rawValue, 0)
        XCTAssertEqual(LogLevel.error.rawValue, 1)
        XCTAssertEqual(LogLevel.warn.rawValue, 2)
        XCTAssertEqual(LogLevel.info.rawValue, 3)
        XCTAssertEqual(LogLevel.debug.rawValue, 4)
    }

    /// AC1 [P0]: LogLevel Comparable ordering -- higher rawValue = more verbose.
    func testLogLevelEnum_ComparableOrdering() {
        XCTAssertTrue(LogLevel.debug > LogLevel.info,
                      "debug should be greater than info")
        XCTAssertTrue(LogLevel.info > LogLevel.warn,
                      "info should be greater than warn")
        XCTAssertTrue(LogLevel.warn > LogLevel.error,
                      "warn should be greater than error")
        XCTAssertTrue(LogLevel.error > LogLevel.none,
                      "error should be greater than none")
        XCTAssertTrue(LogLevel.none >= LogLevel.none,
                      "none should be equal to none")
    }

    /// AC1 [P0]: LogLevel rawValues are Int-backed with correct ordering.
    func testLogLevelEnum_RawValues() {
        XCTAssertEqual(LogLevel.none.rawValue, 0,
                       "none rawValue should be 0")
        XCTAssertEqual(LogLevel.error.rawValue, 1,
                       "error rawValue should be 1")
        XCTAssertEqual(LogLevel.warn.rawValue, 2,
                       "warn rawValue should be 2")
        XCTAssertEqual(LogLevel.info.rawValue, 3,
                       "info rawValue should be 3")
        XCTAssertEqual(LogLevel.debug.rawValue, 4,
                       "debug rawValue should be 4")
    }

    /// AC1 [P1]: LogLevel CustomStringConvertible returns lowercase names.
    func testLogLevelEnum_CustomStringConvertible() {
        XCTAssertEqual(LogLevel.none.description, "none",
                       "none description should be 'none'")
        XCTAssertEqual(LogLevel.error.description, "error",
                       "error description should be 'error'")
        XCTAssertEqual(LogLevel.warn.description, "warn",
                       "warn description should be 'warn'")
        XCTAssertEqual(LogLevel.info.description, "info",
                       "info description should be 'info'")
        XCTAssertEqual(LogLevel.debug.description, "debug",
                       "debug description should be 'debug'")
    }

    /// AC1 [P1]: LogLevel CaseIterable provides allCases in order.
    func testLogLevelEnum_CaseIterable() {
        let allCases = LogLevel.allCases
        XCTAssertEqual(allCases.count, 5,
                       "LogLevel should have 5 cases")
        XCTAssertEqual(allCases, [.none, .error, .warn, .info, .debug],
                       "allCases should be in rawValue order")
    }

    /// AC1 [P0]: LogLevel conforms to Sendable (required for Swift concurrency).
    func testLogLevelEnum_Sendable() {
        let level: LogLevel = .debug
        func expectSendable<T: Sendable>(_ value: T) -> Bool { true }
        XCTAssertTrue(expectSendable(level),
                      "LogLevel must conform to Sendable")
    }
}

// MARK: - LogOutput Enum Tests (AC2, AC3, AC4)

final class LogOutputEnumTests: XCTestCase {

    /// AC2-4 [P0]: LogOutput enum has console, file, and custom cases.
    func testLogOutputEnum_HasConsoleFileCustomCases() {
        // Verify all three cases exist at compile time
        let console: LogOutput = .console
        let file: LogOutput = .file(URL(fileURLWithPath: "/tmp/test.log"))
        let custom: LogOutput = .custom({ _ in })

        // Runtime check that they are distinct
        XCTAssertNotEqual(String(describing: console), String(describing: file))
        XCTAssertNotEqual(String(describing: console), String(describing: custom))
    }

    /// AC2 [P1]: LogOutput.console exists and can be created.
    func testLogOutputEnum_ConsoleCase() {
        let output = LogOutput.console
        XCTAssertNotNil(output,
                        "LogOutput.console should be creatable")
    }

    /// AC3 [P1]: LogOutput.file accepts a URL.
    func testLogOutputEnum_FileCase() {
        let fileURL = URL(fileURLWithPath: "/var/log/sdk.log")
        let output = LogOutput.file(fileURL)
        XCTAssertNotNil(output,
                        "LogOutput.file should accept a URL")
    }

    /// AC4 [P1]: LogOutput.custom accepts a @Sendable closure.
    func testLogOutputEnum_CustomCase() {
        let capture = LogCapture()
        let output = LogOutput.custom { jsonLine in
            capture.append(jsonLine)
        }
        XCTAssertNotNil(output,
                        "LogOutput.custom should accept a closure")
    }

    /// AC2-4 [P0]: LogOutput conforms to Sendable.
    func testLogOutputEnum_Sendable() {
        let output: LogOutput = .console
        func expectSendable<T: Sendable>(_ value: T) -> Bool { true }
        XCTAssertTrue(expectSendable(output),
                      "LogOutput must conform to Sendable")
    }
}

// MARK: - Logger Singleton Tests (AC1, AC5, AC6, AC7)

final class LoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Logger.reset()
    }

    override func tearDown() {
        Logger.reset()
        super.tearDown()
    }

    // MARK: - AC1: Logger singleton exists and is accessible

    /// AC1 [P0]: Logger.shared is accessible as a singleton.
    func testLoggerShared_IsAccessible() {
        let logger = Logger.shared
        XCTAssertNotNil(logger,
                        "Logger.shared should be accessible")
    }

    /// AC5 [P0]: Logger default level is .none (silent by default).
    func testLoggerDefaultLevelIsNone() {
        XCTAssertEqual(Logger.shared.level, .none,
                       "Default log level should be .none")
    }

    // MARK: - AC7: Test reset and injection

    /// AC7 [P0]: Logger.configure sets level and output.
    func testLoggerConfigure_SetsLevelAndOutput() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        XCTAssertEqual(Logger.shared.level, .debug,
                       "Logger level should be .debug after configure")
        // Output should be set (verify by logging and checking captured)
        Logger.shared.debug("TestModule", "TestEvent")
        XCTAssertTrue(capture.count > 0,
                      "Custom output should have captured at least one log entry")
    }

    /// AC7 [P0]: Logger.reset reverts to defaults (level .none, output .console, outputCount 0).
    func testLoggerReset_RevertsToDefaults() {
        // First configure to non-defaults
        Logger.configure(level: .debug, output: .custom { _ in })
        Logger.shared.debug("Module", "Event")

        // Reset
        Logger.reset()

        XCTAssertEqual(Logger.shared.level, .none,
                       "After reset, level should be .none")
        XCTAssertEqual(Logger.shared.outputCount, 0,
                       "After reset, outputCount should be 0")
    }

    /// AC7 [P0]: Logger outputCount starts at 0.
    func testLoggerOutputCountStartsAtZero() {
        XCTAssertEqual(Logger.shared.outputCount, 0,
                       "outputCount should start at 0")
    }

    // MARK: - AC1: Per-level logging methods

    /// AC1 [P0]: Logger.debug logs at debug level.
    func testLoggerDebugLogsAtDebugLevel() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        Logger.shared.debug("TestModule", "DebugEvent", data: ["key": "value"])

        XCTAssertEqual(capture.count, 1,
                       "Should have logged exactly one debug entry")
        XCTAssertTrue(capture.all[0].contains("debug"),
                      "Log entry should contain level 'debug'")
    }

    /// AC1 [P0]: Logger.info logs at info level.
    func testLoggerInfoLogsAtInfoLevel() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        Logger.shared.info("TestModule", "InfoEvent", data: ["key": "value"])

        XCTAssertEqual(capture.count, 1,
                       "Should have logged exactly one info entry")
        XCTAssertTrue(capture.all[0].contains("info"),
                      "Log entry should contain level 'info'")
    }

    /// AC1 [P0]: Logger.warn logs at warn level.
    func testLoggerWarnLogsAtWarnLevel() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        Logger.shared.warn("TestModule", "WarnEvent", data: ["key": "value"])

        XCTAssertEqual(capture.count, 1,
                       "Should have logged exactly one warn entry")
        XCTAssertTrue(capture.all[0].contains("warn"),
                      "Log entry should contain level 'warn'")
    }

    /// AC6 [P0]: Logger.error logs at error level.
    func testLoggerErrorLogsAtErrorLevel() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        Logger.shared.error("TestModule", "ErrorEvent", data: ["key": "value"])

        XCTAssertEqual(capture.count, 1,
                       "Should have logged exactly one error entry")
        XCTAssertTrue(capture.all[0].contains("error"),
                      "Log entry should contain level 'error'")
    }

    // MARK: - AC5: Zero overhead when disabled

    /// AC5 [P0]: When logLevel is .none, no output is produced.
    func testLoggerZeroOverheadWhenNone() {
        let capture = LogCapture()
        Logger.configure(level: .none, output: .custom { line in
            capture.append(line)
        })

        Logger.shared.debug("Module", "Event")
        Logger.shared.info("Module", "Event")
        Logger.shared.warn("Module", "Event")
        Logger.shared.error("Module", "Event")

        XCTAssertEqual(Logger.shared.outputCount, 0,
                       "outputCount should be 0 when level is .none")
        XCTAssertEqual(capture.count, 0,
                       "No output should be captured when level is .none")
    }

    /// AC1 [P0]: Logger filters messages below current level.
    func testLoggerFiltersBelowCurrentLevel() {
        let capture = LogCapture()
        Logger.configure(level: .warn, output: .custom { line in
            capture.append(line)
        })

        // error and warn should pass (>= .warn)
        Logger.shared.error("Module", "ErrorEvent")
        Logger.shared.warn("Module", "WarnEvent")
        // info and debug should be filtered out (< .warn)
        Logger.shared.info("Module", "InfoEvent")
        Logger.shared.debug("Module", "DebugEvent")

        XCTAssertEqual(capture.count, 2,
                       "Only error and warn should pass through at .warn level")
        XCTAssertEqual(Logger.shared.outputCount, 2,
                       "outputCount should be 2 for error + warn")
    }

    // MARK: - AC2: Console output (default)

    /// AC2 [P0]: Console output writes structured JSON to stderr.
    func testLoggerConsoleOutput_WritesJSONToStderr() {
        Logger.configure(level: .debug, output: .console)

        // Log a message -- we verify JSON structure via outputCount
        // (actually capturing stderr in unit tests is tricky,
        //  so we verify outputCount increments and format via custom output in other tests)
        Logger.shared.info("ConsoleTest", "ConsoleEvent", data: ["test": "value"])

        XCTAssertEqual(Logger.shared.outputCount, 1,
                       "Console output should increment outputCount")
    }

    // MARK: - AC3: File output

    /// AC3 [P0]: File output appends JSON to specified file.
    func testLoggerFileOutput_AppendsJSONToFile() {
        let tempDir = NSTemporaryDirectory()
        let logFileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent("logger-test-\(ProcessInfo.processInfo.globallyUniqueString).log")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: logFileURL)

        Logger.configure(level: .debug, output: .file(logFileURL))

        Logger.shared.info("FileTest", "FileEvent", data: ["testKey": "testValue"])

        XCTAssertEqual(Logger.shared.outputCount, 1,
                       "File output should increment outputCount")

        // Read the file and verify JSON content
        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertNotNil(content,
                        "Log file should exist and be readable")
        XCTAssertTrue(content?.contains("info") ?? false,
                      "Log file should contain 'info' level")
        XCTAssertTrue(content?.contains("FileTest") ?? false,
                      "Log file should contain module name")
        XCTAssertTrue(content?.contains("FileEvent") ?? false,
                      "Log file should contain event name")

        // Clean up
        try? FileManager.default.removeItem(at: logFileURL)
    }

    // MARK: - AC4: Custom output

    /// AC4 [P0]: Custom output passes JSON string to developer's closure.
    func testLoggerCustomOutput_PassesJSONToClosure() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        Logger.shared.info("CustomModule", "CustomEvent", data: ["key1": "val1"])

        XCTAssertEqual(capture.count, 1,
                       "Custom closure should receive exactly one log line")

        let jsonLine = capture.all[0]
        XCTAssertTrue(jsonLine.contains("timestamp"),
                      "JSON should contain 'timestamp' field")
        XCTAssertTrue(jsonLine.contains("level"),
                      "JSON should contain 'level' field")
        XCTAssertTrue(jsonLine.contains("module"),
                      "JSON should contain 'module' field")
        XCTAssertTrue(jsonLine.contains("event"),
                      "JSON should contain 'event' field")
        XCTAssertTrue(jsonLine.contains("CustomModule"),
                      "JSON should contain module name 'CustomModule'")
        XCTAssertTrue(jsonLine.contains("CustomEvent"),
                      "JSON should contain event name 'CustomEvent'")
    }

    // MARK: - AC6: Error-level logging

    /// AC6 [P0]: Error-level logging includes error details from SDKError.
    func testLoggerErrorLevel_LogsAPIErrorDetails() {
        let capture = LogCapture()
        Logger.configure(level: .error, output: .custom { line in
            capture.append(line)
        })

        let error = SDKError.apiError(statusCode: 429, message: "Rate limit exceeded")
        Logger.shared.error("APIClient", "RequestFailed", data: [
            "error.message": error.message,
            "error.statusCode": String(error.statusCode ?? 0),
        ])

        XCTAssertEqual(capture.count, 1,
                       "Should have logged exactly one error entry")
        let jsonLine = capture.all[0]
        XCTAssertTrue(jsonLine.contains("429"),
                      "Error log should contain status code 429")
        XCTAssertTrue(jsonLine.contains("Rate limit exceeded"),
                      "Error log should contain error message")
    }
}

// MARK: - SDKConfiguration Integration Tests (AC1)

final class SDKConfigurationLoggerTests: XCTestCase {

    /// AC1 [P0]: SDKConfiguration has a logLevel field with default .none.
    func testSDKConfiguration_HasLogLevelField() {
        let config = SDKConfiguration()
        XCTAssertEqual(config.logLevel, .none,
                       "Default logLevel should be .none")

        let customConfig = SDKConfiguration(logLevel: .debug)
        XCTAssertEqual(customConfig.logLevel, .debug,
                       "Custom logLevel should be .debug when set")
    }

    /// AC1 [P0]: SDKConfiguration has a logOutput field with default .console.
    func testSDKConfiguration_HasLogOutputField() {
        let config = SDKConfiguration()
        // Default should be .console
        let output = config.logOutput
        XCTAssertNotNil(output,
                        "logOutput should be set by default")

        // Custom output
        let capture = LogCapture()
        let customConfig = SDKConfiguration(logOutput: .custom { line in
            capture.append(line)
        })
        XCTAssertNotNil(customConfig.logOutput,
                        "Custom logOutput should be settable")
    }

    /// AC1 [P1]: SDKConfiguration includes logLevel in description.
    func testSDKConfiguration_LogLevelInDescription() {
        let config = SDKConfiguration(logLevel: .debug)
        let description = config.description
        XCTAssertTrue(description.contains("logLevel"),
                      "Description should mention logLevel field")
    }

    /// AC1 [P1]: SDKConfiguration includes logOutput in description.
    func testSDKConfiguration_LogOutputInDescription() {
        let config = SDKConfiguration()
        let description = config.description
        XCTAssertTrue(description.contains("logOutput"),
                      "Description should mention logOutput field")
    }

    /// AC1 [P0]: SDKConfiguration with same logLevel values are equal.
    func testSDKConfiguration_LogLevelEquality() {
        let config1 = SDKConfiguration(logLevel: .warn)
        let config2 = SDKConfiguration(logLevel: .warn)
        XCTAssertEqual(config1, config2,
                       "Configurations with same logLevel should be equal")

        let config3 = SDKConfiguration(logLevel: .debug)
        XCTAssertNotEqual(config1, config3,
                           "Configurations with different logLevel should not be equal")
    }

    /// AC1 [P1]: SDKConfiguration.resolved merges logLevel from overrides.
    func testSDKConfiguration_ResolvedMergesLogLevel() {
        let overrides = SDKConfiguration(logLevel: .info)
        let resolved = SDKConfiguration.resolved(overrides: overrides)
        XCTAssertEqual(resolved.logLevel, .info,
                       "resolved() should use override logLevel")
    }
}
