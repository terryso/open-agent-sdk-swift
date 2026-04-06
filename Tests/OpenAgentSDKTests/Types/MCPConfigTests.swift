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
}
