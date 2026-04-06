import XCTest
@testable import OpenAgentSDK

final class ToolTypesTests: XCTestCase {

    // MARK: - ToolExecuteResult

    func testToolExecuteResult_success() {
        let result = ToolExecuteResult(content: "done", isError: false)
        XCTAssertEqual(result.content, "done")
        XCTAssertFalse(result.isError)
    }

    func testToolExecuteResult_error() {
        let result = ToolExecuteResult(content: "failed", isError: true)
        XCTAssertTrue(result.isError)
    }

    func testToolExecuteResult_equality() {
        let a = ToolExecuteResult(content: "ok", isError: false)
        let b = ToolExecuteResult(content: "ok", isError: false)
        XCTAssertEqual(a, b)
    }

    func testToolExecuteResult_inequality() {
        let a = ToolExecuteResult(content: "ok", isError: false)
        let b = ToolExecuteResult(content: "ok", isError: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ToolResult

    func testToolResult_success() {
        let result = ToolResult(toolUseId: "tu_1", content: "output", isError: false)
        XCTAssertEqual(result.toolUseId, "tu_1")
        XCTAssertEqual(result.content, "output")
        XCTAssertFalse(result.isError)
    }

    func testToolResult_error() {
        let result = ToolResult(toolUseId: "tu_2", content: "error msg", isError: true)
        XCTAssertTrue(result.isError)
    }

    func testToolResult_equality() {
        let a = ToolResult(toolUseId: "tu_1", content: "x", isError: false)
        let b = ToolResult(toolUseId: "tu_1", content: "x", isError: false)
        XCTAssertEqual(a, b)
    }

    func testToolResult_inequality_differentContent() {
        let a = ToolResult(toolUseId: "tu_1", content: "a", isError: false)
        let b = ToolResult(toolUseId: "tu_1", content: "b", isError: false)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ToolContext

    func testToolContext_minimalInit() {
        let ctx = ToolContext(cwd: "/tmp")
        XCTAssertEqual(ctx.cwd, "/tmp")
        XCTAssertEqual(ctx.toolUseId, "")
        XCTAssertNil(ctx.agentSpawner)
        XCTAssertNil(ctx.mailboxStore)
        XCTAssertNil(ctx.teamStore)
        XCTAssertNil(ctx.senderName)
    }

    func testToolContext_fullInit() {
        let ctx = ToolContext(
            cwd: "/home",
            toolUseId: "tu_abc",
            agentSpawner: nil,
            mailboxStore: nil,
            teamStore: nil,
            senderName: "agent-1"
        )
        XCTAssertEqual(ctx.cwd, "/home")
        XCTAssertEqual(ctx.toolUseId, "tu_abc")
        XCTAssertEqual(ctx.senderName, "agent-1")
    }

    // MARK: - ToolProtocol conformance

    func testToolProtocol_conformance() {
        // Verify a custom type can conform to ToolProtocol
        struct MockTool: ToolProtocol, @unchecked Sendable {
            let name = "mock_tool"
            let description = "A mock tool"
            let inputSchema: ToolInputSchema = ["type": "object"]
            let isReadOnly = true

            func call(input: Any, context: ToolContext) async -> ToolResult {
                ToolResult(toolUseId: context.toolUseId, content: "mocked", isError: false)
            }
        }

        let tool = MockTool()
        XCTAssertEqual(tool.name, "mock_tool")
        XCTAssertEqual(tool.description, "A mock tool")
        XCTAssertTrue(tool.isReadOnly)
        XCTAssertEqual(tool.inputSchema["type"] as? String, "object")
    }

    func testToolProtocol_executeReturnsResult() async {
        struct EchoTool: ToolProtocol, @unchecked Sendable {
            let name = "echo"
            let description = "Echoes input"
            let inputSchema: ToolInputSchema = [:]
            let isReadOnly = true

            func call(input: Any, context: ToolContext) async -> ToolResult {
                let content = "Echo: \(input)"
                return ToolResult(toolUseId: context.toolUseId, content: content, isError: false)
            }
        }

        let tool = EchoTool()
        let ctx = ToolContext(cwd: "/tmp", toolUseId: "tu_echo")
        let result = await tool.call(input: "hello", context: ctx)
        XCTAssertEqual(result.toolUseId, "tu_echo")
        XCTAssertEqual(result.content, "Echo: hello")
        XCTAssertFalse(result.isError)
    }
}
