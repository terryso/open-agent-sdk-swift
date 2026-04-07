import Foundation
import MCP
import Logging

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

// MARK: - MCPStdioTransport

/// Stdio transport for MCP client connections that launches external processes.
///
/// Conforms to the mcp-swift-sdk's `Transport` protocol, enabling use with
/// `MCPClient` for full MCP handshake, tool discovery, and tool execution.
///
/// Launches an external process via Foundation's `Process` and manages
/// stdin/stdout pipes for JSON-RPC communication with MCP servers.
///
/// ## Cross-Platform
/// Uses Foundation's `Process` for child process management and System's
/// `FileDescriptor` for low-level I/O. Available on macOS and Linux.
///
/// ## API Key Security (NFR6)
/// By default, `CODEANY_API_KEY` is filtered from the child process environment
/// unless explicitly included in the `McpStdioConfig.env` parameter.
public actor MCPStdioTransport: Transport {

    // MARK: - Transport Protocol Properties

    /// Logger for transport events.
    public nonisolated let logger: Logger

    /// Session ID (nil for stdio -- single connection transport).
    public nonisolated let sessionId: String? = nil

    /// Stdio supports server-to-client requests (persistent bidirectional connection).
    public nonisolated let supportsServerToClientRequests: Bool = true

    // MARK: - Private State

    /// The MCP server configuration.
    private let config: McpStdioConfig

    /// The child process.
    private var process: Process?

    /// File descriptor for reading from child's stdout.
    private var inputFd: FileDescriptor?

    /// File descriptor for writing to child's stdin.
    private var outputFd: FileDescriptor?

    /// Whether the transport is currently connected.
    private var isConnected = false

    /// Message stream for the Transport protocol's receive() method.
    private let messageStream: AsyncThrowingStream<TransportMessage, Swift.Error>

    /// Continuation for yielding received messages.
    private let messageContinuation: AsyncThrowingStream<TransportMessage, Swift.Error>.Continuation

    // MARK: - Initialization

    /// Creates a new MCPStdioTransport with the given configuration.
    ///
    /// - Parameters:
    ///   - config: The stdio MCP server configuration.
    ///   - logger: Optional logger for transport events.
    public init(config: McpStdioConfig, logger: Logger? = nil) {
        self.config = config
        self.logger = logger ?? Logger(
            label: "mcp.transport.stdio.client",
            factory: { _ in SwiftLogNoOpLogHandler() }
        )

        let (stream, continuation) = AsyncThrowingStream<TransportMessage, Swift.Error>.makeStream()
        messageStream = stream
        messageContinuation = continuation
    }

    // MARK: - Transport Protocol: Connection Lifecycle

    /// Launches the child process and starts the message reading loop.
    ///
    /// - Throws: An error if the process cannot be launched.
    public func connect() async throws {
        guard !isConnected else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.command)
        if let args = config.args {
            process.arguments = args
        }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        process.environment = getChildEnvironment()

        self.process = process

        // Launch the process
        try process.run()

        // Extract raw file descriptors from Pipe's FileHandle
        self.inputFd = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
        self.outputFd = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)

        isConnected = true
        logger.debug("MCP stdio transport connected")

        // Start background message reading loop
        _Concurrency.Task {
            await readLoop()
        }
    }

    /// Terminates the child process and cleans up resources.
    public func disconnect() async {
        guard isConnected else { return }
        isConnected = false
        messageContinuation.finish()

        // Terminate child process
        if let process, process.isRunning {
            process.terminate()
        }
        self.process = nil

        // Close file descriptors
        try? inputFd?.close()
        try? outputFd?.close()
        inputFd = nil
        outputFd = nil

        logger.debug("MCP stdio transport disconnected")
    }

    // MARK: - Transport Protocol: Send/Receive

    /// Sends a JSON-RPC message to the child process via stdin.
    ///
    /// Appends a newline delimiter for JSON-RPC stdio framing.
    ///
    /// - Parameters:
    ///   - data: The JSON-RPC message data (without trailing newline).
    ///   - options: Transport send options (ignored for stdio).
    public func send(_ data: Data, options _: TransportSendOptions) async throws {
        guard isConnected, let outputFd else {
            throw MCPError.transportError(
                NSError(domain: "MCPStdioTransport", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Not connected: output pipe not available",
                ])
            )
        }

        // Add newline as JSON-RPC stdio delimiter
        var message = data
        message.append(UInt8(ascii: "\n"))

        var remaining = message
        while !remaining.isEmpty {
            do {
                let written = try remaining.withUnsafeBytes { buffer in
                    try outputFd.write(UnsafeRawBufferPointer(buffer))
                }
                if written > 0 {
                    remaining = remaining.dropFirst(written)
                }
            } catch let error where MCPError.isResourceTemporarilyUnavailable(error) {
                try? await _Concurrency.Task.sleep(for: Duration.milliseconds(10))
                continue
            } catch {
                throw MCPError.transportError(error)
            }
        }
    }

    /// Returns the stream of incoming JSON-RPC messages from the child process.
    public func receive() -> AsyncThrowingStream<TransportMessage, Swift.Error> {
        messageStream
    }

    // MARK: - Message Reading Loop

    /// Continuously reads from the child process stdout, parses newline-delimited
    /// JSON-RPC messages, and yields them to the message stream.
    private func readLoop() async {
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var pendingData = Data()

        while isConnected, !_Concurrency.Task.isCancelled {
            guard let inputFd else { break }

            do {
                let bytesRead = try buffer.withUnsafeMutableBufferPointer { pointer in
                    try inputFd.read(into: UnsafeMutableRawBufferPointer(pointer))
                }

                if bytesRead == 0 {
                    logger.debug("EOF received from MCP server")
                    break
                }

                pendingData.append(Data(buffer[..<bytesRead]))

                // Process complete messages (newline-delimited)
                while let newlineIndex = pendingData.firstIndex(of: UInt8(ascii: "\n")) {
                    var messageData = pendingData[..<newlineIndex]
                    pendingData = pendingData[(newlineIndex + 1)...]

                    // Strip trailing carriage return for CRLF line endings
                    if messageData.last == UInt8(ascii: "\r") {
                        messageData = messageData.dropLast()
                    }

                    if !messageData.isEmpty {
                        logger.trace("Message received", metadata: ["size": "\(messageData.count)"])
                        messageContinuation.yield(TransportMessage(data: Data(messageData)))
                    }
                }
            } catch let error where MCPError.isResourceTemporarilyUnavailable(error) {
                try? await _Concurrency.Task.sleep(for: Duration.milliseconds(10))
                continue
            } catch {
                if !_Concurrency.Task.isCancelled {
                    logger.error("Read error", metadata: ["error": "\(error)"])
                }
                break
            }
        }

        messageContinuation.finish()
    }

    // MARK: - Environment Management

    /// Returns the child process environment, filtering out CODEANY_API_KEY
    /// unless explicitly configured in the MCP server config's env.
    ///
    /// This implements NFR6 (API key security).
    public func getChildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        // Always filter CODEANY_API_KEY from child process
        env.removeValue(forKey: "CODEANY_API_KEY")
        // Merge explicitly configured env vars on top
        if let configEnv = config.env {
            for (key, value) in configEnv {
                env[key] = value
            }
        }
        return env
    }

    /// Returns whether the child process is currently running.
    public var isRunning: Bool {
        process?.isRunning ?? false
    }
}

#endif
