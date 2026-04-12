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

    /// Logger for transport events (SwiftLog, not SDK's Logger).
    public nonisolated let logger: Logging.Logger

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
    public init(config: McpStdioConfig, logger: Logging.Logger? = nil) {
        self.config = config
        self.logger = logger ?? Logging.Logger(
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
        let resolvedURL = resolveExecutable(config.command)
        process.executableURL = resolvedURL
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

        // Start background read loop in a detached task so blocking I/O
        // does not hold actor isolation (preventing disconnect() from running)
        startReadLoop()
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

    /// Starts the read loop in a detached task so blocking I/O does not hold actor isolation.
    ///
    /// Captures the file descriptor and continuation before spawning the detached task,
    /// ensuring the actor remains responsive to `disconnect()` calls.
    private func startReadLoop() {
        guard let inputFd else { return }
        let rawFd = inputFd.rawValue
        let continuation = messageContinuation
        let log = logger

        _Concurrency.Task.detached {
            let bufferSize = 4096
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var pendingData = Data()

            while true {
                do {
                    let bytesRead = try buffer.withUnsafeMutableBufferPointer { pointer in
                        try FileDescriptor(rawValue: rawFd).read(
                            into: UnsafeMutableRawBufferPointer(pointer)
                        )
                    }

                    if bytesRead == 0 {
                        log.debug("EOF received from MCP server")
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
                            log.trace("Message received", metadata: ["size": Logging.Logger.MetadataValue.string("\(messageData.count)")])
                            continuation.yield(TransportMessage(data: Data(messageData)))
                        }
                    }
                } catch let error where MCPError.isResourceTemporarilyUnavailable(error) {
                    try? await _Concurrency.Task.sleep(for: Duration.milliseconds(10))
                    continue
                } catch {
                    if !_Concurrency.Task.isCancelled {
                        log.error("Read error", metadata: ["error": Logging.Logger.MetadataValue.string("\(error)")])
                    }
                    break
                }
            }

            continuation.finish()
        }
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

    // MARK: - Executable Resolution

    /// Resolves a command string to an executable URL.
    ///
    /// If the command looks like an absolute path, it is used directly.
    /// Otherwise, it is searched for on the user's PATH using `which`.
    /// Falls back to treating the command as a file path if lookup fails.
    private func resolveExecutable(_ command: String) -> URL {
        // Absolute path — use as-is
        if command.hasPrefix("/") {
            return URL(fileURLWithPath: command)
        }

        // Try to resolve via PATH
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = [command]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice
        do {
            try which.run()
            which.waitUntilExit()
            if which.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            logger.debug("which lookup failed, falling back to file path", metadata: ["command": Logging.Logger.MetadataValue.string(command)])
        }

        return URL(fileURLWithPath: command)
    }
}

#endif
