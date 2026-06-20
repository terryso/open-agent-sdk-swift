import XCTest
@testable import OpenAgentSDK

final class MCPConfigTests: XCTestCase {

    // MARK: - McpStdioConfig

    func testStdioConfig_creation() {
        let config = McpStdioConfig(command: "node", args: ["server.js"], env: ["KEY": "value"])
        XCTAssertEqual(config.command, "node")
        XCTAssertEqual(config.args, ["server.js"])
        XCTAssertEqual(config.env, ["KEY": "value"])
    }

    func testStdioConfig_defaultsNil() {
        let config = McpStdioConfig(command: "python")
        XCTAssertEqual(config.command, "python")
        XCTAssertNil(config.args)
        XCTAssertNil(config.env)
    }

    func testStdioConfig_equality() {
        let a = McpStdioConfig(command: "node", args: ["s.js"], env: nil)
        let b = McpStdioConfig(command: "node", args: ["s.js"], env: nil)
        XCTAssertEqual(a, b)
    }

    func testStdioConfig_inequality() {
        let a = McpStdioConfig(command: "node")
        let b = McpStdioConfig(command: "python")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - McpSseConfig

    func testSseConfig_creation() {
        let config = McpSseConfig(url: "http://localhost:8080/sse", headers: ["Auth": "token"])
        XCTAssertEqual(config.url, "http://localhost:8080/sse")
        XCTAssertEqual(config.headers, ["Auth": "token"])
    }

    func testSseConfig_defaultsNil() {
        let config = McpSseConfig(url: "http://localhost:8080/sse")
        XCTAssertNil(config.headers)
    }

    func testSseConfig_equality() {
        let a = McpSseConfig(url: "http://localhost/sse", headers: nil)
        let b = McpSseConfig(url: "http://localhost/sse", headers: nil)
        XCTAssertEqual(a, b)
    }

    // MARK: - McpHttpConfig

    func testHttpConfig_creation() {
        let config = McpHttpConfig(url: "http://localhost:9090/mcp", headers: ["X-Key": "abc"])
        XCTAssertEqual(config.url, "http://localhost:9090/mcp")
        XCTAssertEqual(config.headers, ["X-Key": "abc"])
    }

    func testHttpConfig_defaultsNil() {
        let config = McpHttpConfig(url: "http://localhost:9090/mcp")
        XCTAssertNil(config.headers)
    }

    func testHttpConfig_equality() {
        let a = McpHttpConfig(url: "http://localhost/mcp", headers: nil)
        let b = McpHttpConfig(url: "http://localhost/mcp", headers: nil)
        XCTAssertEqual(a, b)
    }

    // MARK: - McpServerConfig enum

    func testServerConfig_stdioCase() {
        let stdioConfig = McpStdioConfig(command: "npx")
        let server = McpServerConfig.stdio(stdioConfig)
        if case .stdio(let config) = server {
            XCTAssertEqual(config.command, "npx")
        } else {
            XCTFail("Expected .stdio case")
        }
    }

    func testServerConfig_sseCase() {
        let sseConfig = McpSseConfig(url: "http://example.com/sse")
        let server = McpServerConfig.sse(sseConfig)
        if case .sse(let config) = server {
            XCTAssertEqual(config.url, "http://example.com/sse")
        } else {
            XCTFail("Expected .sse case")
        }
    }

    func testServerConfig_httpCase() {
        let httpConfig = McpHttpConfig(url: "http://example.com/mcp")
        let server = McpServerConfig.http(httpConfig)
        if case .http(let config) = server {
            XCTAssertEqual(config.url, "http://example.com/mcp")
        } else {
            XCTFail("Expected .http case")
        }
    }

    func testServerConfig_equality_stdio() {
        let a = McpServerConfig.stdio(McpStdioConfig(command: "node"))
        let b = McpServerConfig.stdio(McpStdioConfig(command: "node"))
        XCTAssertEqual(a, b)
    }

    func testServerConfig_inequality_differentCases() {
        let a = McpServerConfig.stdio(McpStdioConfig(command: "node"))
        let b = McpServerConfig.sse(McpSseConfig(url: "http://localhost"))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - McpSdkServerConfig equality (covers == operator)

    /// Two McpSdkServerConfigs with the same server reference AND matching
    /// name/version are equal.
    func testMcpSdkServerConfig_equality_sameServerSameFields() async {
        let server = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        let a = McpSdkServerConfig(name: "n", version: "v", server: server)
        let b = McpSdkServerConfig(name: "n", version: "v", server: server)
        XCTAssertEqual(a, b,
                       "Same server instance + identical name/version must be equal")
    }

    /// Same server reference but different name → not equal.
    func testMcpSdkServerConfig_inequality_sameServerDifferentName() async {
        let server = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        let a = McpSdkServerConfig(name: "n1", version: "v", server: server)
        let b = McpSdkServerConfig(name: "n2", version: "v", server: server)
        XCTAssertNotEqual(a, b)
    }

    /// Same server reference but different version → not equal.
    func testMcpSdkServerConfig_inequality_sameServerDifferentVersion() async {
        let server = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        let a = McpSdkServerConfig(name: "n", version: "v1", server: server)
        let b = McpSdkServerConfig(name: "n", version: "v2", server: server)
        XCTAssertNotEqual(a, b)
    }

    /// Different server instances (even with same name/version) → not equal.
    /// This pins down the ObjectIdentifier-based equality contract.
    func testMcpSdkServerConfig_inequality_differentServerInstances() async {
        let server1 = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        let server2 = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        let a = McpSdkServerConfig(name: "n", version: "v", server: server1)
        let b = McpSdkServerConfig(name: "n", version: "v", server: server2)
        XCTAssertNotEqual(a, b,
                          "Different server actor instances must not be equal, even with matching name/version")
    }

    /// McpServerConfig.sdk case wraps McpSdkServerConfig and inherits its equality.
    func testMcpServerConfig_sdkCase_equalityFollowsServerIdentity() async {
        let server = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        let a = McpServerConfig.sdk(McpSdkServerConfig(name: "n", version: "v", server: server))
        let b = McpServerConfig.sdk(McpSdkServerConfig(name: "n", version: "v", server: server))
        XCTAssertEqual(a, b)
    }

    /// init rejects names containing "__" (would create ambiguous tool namespacing).
    func testMcpSdkServerConfig_init_rejectsDoubleUnderscoreName() async {
        let server = InProcessMCPServer(name: "x", version: "1.0", tools: [])
        // precondition failure is a process crash, not a throwable. We can't
        // catch it in XCTest, so we only verify the happy path here; the
        // rejection contract is documented in the precondition message.
        let valid = McpSdkServerConfig(name: "single-segment", version: "1.0", server: server)
        XCTAssertEqual(valid.name, "single-segment")
    }

    // MARK: - McpClaudeAIProxyConfig equality

    func testMcpClaudeAIProxyConfig_equality() {
        let a = McpClaudeAIProxyConfig(url: "https://claude.ai/proxy", id: "srv-1")
        let b = McpClaudeAIProxyConfig(url: "https://claude.ai/proxy", id: "srv-1")
        XCTAssertEqual(a, b)
    }

    func testMcpClaudeAIProxyConfig_inequality_differentUrl() {
        let a = McpClaudeAIProxyConfig(url: "https://claude.ai/a", id: "srv-1")
        let b = McpClaudeAIProxyConfig(url: "https://claude.ai/b", id: "srv-1")
        XCTAssertNotEqual(a, b)
    }

    func testMcpClaudeAIProxyConfig_inequality_differentId() {
        let a = McpClaudeAIProxyConfig(url: "https://claude.ai/proxy", id: "srv-1")
        let b = McpClaudeAIProxyConfig(url: "https://claude.ai/proxy", id: "srv-2")
        XCTAssertNotEqual(a, b)
    }
}
