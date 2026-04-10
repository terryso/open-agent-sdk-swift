import XCTest
import MCP
@testable import OpenAgentSDK
import Logging

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

// MARK: - MCPStdioTransport Unit Tests

final class MCPStdioTransportTests: XCTestCase {

    // MARK: - Initialization

    func testInit_withDefaultLogger() async {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)
        _ = transport
    }

    func testInit_withCustomLogger() async {
        let config = McpStdioConfig(command: "echo")
        let logger = Logger(label: "test.transport")
        let transport = MCPStdioTransport(config: config, logger: logger)
        _ = transport
    }

    // MARK: - Transport Protocol Properties

    func testSessionId_isNil() async {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)

        XCTAssertNil(transport.sessionId, "Stdio transport should have nil sessionId")
    }

    func testSupportsServerToClientRequests_isTrue() async {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)

        XCTAssertTrue(transport.supportsServerToClientRequests,
                       "Stdio transport supports server-to-client requests")
    }

    func testLogger_isNonisolated() async {
        let config = McpStdioConfig(command: "echo")
        let customLogger = Logger(label: "test.logger")
        let transport = MCPStdioTransport(config: config, logger: customLogger)

        // Logger should be accessible without await (nonisolated)
        let _ = transport.logger
    }

    // MARK: - Connection Lifecycle

    func testConnect_launchesProcessAndSetsConnected() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()

        let running = await transport.isRunning
        XCTAssertTrue(running, "Process should be running after connect")

        await transport.disconnect()
    }

    func testConnect_idempotent_doesNotCrashOnDoubleConnect() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        try await transport.connect()

        let running = await transport.isRunning
        XCTAssertTrue(running)

        await transport.disconnect()
    }

    func testDisconnect_terminatesProcess() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        let runningBefore = await transport.isRunning
        XCTAssertTrue(runningBefore)

        await transport.disconnect()

        let runningAfter = await transport.isRunning
        XCTAssertFalse(runningAfter, "Process should not be running after disconnect")
    }

    func testDisconnect_idempotent_doesNotCrashOnDoubleDisconnect() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        await transport.disconnect()
        await transport.disconnect()
    }

    func testDisconnect_withoutConnect_doesNotCrash() async {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)

        await transport.disconnect()
    }

    // MARK: - Send/Receive

    func testSend_andReceive_roundTrip() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()

        let message = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
        """
        let messageData = Data(message.utf8)

        try await transport.send(messageData, options: TransportSendOptions())

        let stream = await transport.receive()
        var receivedData: Data?
        for try await msg in stream {
            receivedData = msg.data
            break
        }

        await transport.disconnect()

        XCTAssertNotNil(receivedData, "Should receive a response from cat process")

        let receivedString = String(data: receivedData!, encoding: .utf8)
        XCTAssertEqual(receivedString, message)
    }

    func testSend_whenNotConnected_throwsError() async {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)

        do {
            try await transport.send(Data("test".utf8), options: TransportSendOptions())
            XCTFail("Should throw when not connected")
        } catch {
            // Expected
        }
    }

    func testReceive_returnsMessageStream() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()

        let stream = await transport.receive()
        XCTAssertNotNil(stream)

        await transport.disconnect()
    }

    // MARK: - Environment Management

    func testGetChildEnvironment_filtersApiKey() async {
        setenv("CODEANY_API_KEY", "super-secret-key", 1)
        defer { unsetenv("CODEANY_API_KEY") }

        let config = McpStdioConfig(command: "env")
        let transport = MCPStdioTransport(config: config)

        let env = await transport.getChildEnvironment()
        XCTAssertNil(env["CODEANY_API_KEY"], "CODEANY_API_KEY should be filtered from child env")
    }

    func testGetChildEnvironment_preservesOtherEnvVars() async {
        setenv("MCP_TEST_PRESERVE", "keep-this", 1)
        defer { unsetenv("MCP_TEST_PRESERVE") }

        let config = McpStdioConfig(command: "env")
        let transport = MCPStdioTransport(config: config)

        let env = await transport.getChildEnvironment()
        XCTAssertEqual(env["MCP_TEST_PRESERVE"], "keep-this")
    }

    func testGetChildEnvironment_mergesExplicitEnvVars() async {
        let config = McpStdioConfig(
            command: "env",
            env: ["MY_TOOL_VAR": "tool-value", "PATH_OVERRIDE": "/custom"]
        )
        let transport = MCPStdioTransport(config: config)

        let env = await transport.getChildEnvironment()
        XCTAssertEqual(env["MY_TOOL_VAR"], "tool-value")
        XCTAssertEqual(env["PATH_OVERRIDE"], "/custom")
    }

    func testGetChildEnvironment_explicitEnvOverridesSystemEnv() async {
        setenv("MCP_TEST_OVERRIDE", "original", 1)
        defer { unsetenv("MCP_TEST_OVERRIDE") }

        let config = McpStdioConfig(
            command: "env",
            env: ["MCP_TEST_OVERRIDE": "overridden"]
        )
        let transport = MCPStdioTransport(config: config)

        let env = await transport.getChildEnvironment()
        XCTAssertEqual(env["MCP_TEST_OVERRIDE"], "overridden",
                         "Explicit env should override system env")
    }

    func testGetChildEnvironment_withNilEnv_noExtraVars() async {
        let config = McpStdioConfig(command: "env", env: nil)
        let transport = MCPStdioTransport(config: config)

        let env = await transport.getChildEnvironment()
        XCTAssertNotNil(env["PATH"], "Should inherit PATH from system")
    }

    // MARK: - Executable Resolution (via connect)

    func testConnect_absolutePath() async throws {
        let config = McpStdioConfig(command: "/bin/echo")
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        let running = await transport.isRunning
        XCTAssertTrue(running)
        await transport.disconnect()
    }

    func testConnect_commandOnPath() async throws {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        let running = await transport.isRunning
        XCTAssertTrue(running)
        await transport.disconnect()
    }

    func testConnect_withArguments() async throws {
        let config = McpStdioConfig(command: "echo", args: ["hello", "world"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        let running = await transport.isRunning
        XCTAssertTrue(running)
        await transport.disconnect()
    }

    func testConnect_withNilArguments() async throws {
        let config = McpStdioConfig(command: "cat", args: nil)
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        let running = await transport.isRunning
        XCTAssertTrue(running)
        await transport.disconnect()
    }

    // MARK: - isRunning

    func testIsRunning_beforeConnect_isFalse() async {
        let config = McpStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)

        let running = await transport.isRunning
        XCTAssertFalse(running, "Should not be running before connect")
    }

    func testIsRunning_afterConnect_isTrue() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        let running = await transport.isRunning
        XCTAssertTrue(running)

        await transport.disconnect()
    }

    func testIsRunning_afterDisconnect_isFalse() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()
        await transport.disconnect()

        let running = await transport.isRunning
        XCTAssertFalse(running)
    }

    // MARK: - Multiple Messages

    func testSendMultipleMessages_andReceiveAll() async throws {
        let config = McpStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()

        let messages = [
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}",
            "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"list\"}",
            "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"call\"}",
        ]

        for msg in messages {
            try await transport.send(Data(msg.utf8), options: TransportSendOptions())
        }

        let stream = await transport.receive()
        var received: [String] = []
        for try await msg in stream {
            if let str = String(data: msg.data, encoding: .utf8) {
                received.append(str)
            }
            if received.count == messages.count { break }
        }

        await transport.disconnect()

        XCTAssertEqual(received.count, messages.count, "Should receive all sent messages")
    }

    // MARK: - Process Termination on EOF

    func testReceive_finishesWhenProcessExits() async throws {
        let config = McpStdioConfig(command: "echo", args: ["hello"])
        let transport = MCPStdioTransport(config: config)

        try await transport.connect()

        let stream = await transport.receive()
        var received: [Data] = []
        for try await msg in stream {
            received.append(msg.data)
        }

        await transport.disconnect()

        if let data = received.first, let str = String(data: data, encoding: .utf8) {
            XCTAssertEqual(str, "hello")
        }
    }
}

#endif
