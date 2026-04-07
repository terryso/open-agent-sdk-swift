import Foundation
import OpenAgentSDK

// MARK: - Tests: MCP Resource Tools (ListMcpResources, ReadMcpResource)

struct McpResourceToolTests {
    static func run() async {
        section("MCP Resource Tools: Registration & Schema")
        testMcpResourceToolRegistration()
        testMcpResourceToolSchemas()

        section("MCP Resource Tools: No Connections")
        await testListMcpResourcesNoConnections()
        await testReadMcpResourceServerNotFound()

        section("MCP Resource Tools: ToolRegistry")
        testMcpResourceToolsInSpecialistTier()
    }

    // MARK: Registration

    static func testMcpResourceToolRegistration() {
        let listTool = createListMcpResourcesTool()
        if listTool.name == "ListMcpResources" && !listTool.description.isEmpty {
            pass("ListMcpResources tool registered with correct name and non-empty description")
        } else {
            fail("ListMcpResources tool registration", "name=\(listTool.name)")
        }

        if listTool.isReadOnly {
            pass("ListMcpResources isReadOnly is true")
        } else {
            fail("ListMcpResources isReadOnly is true")
        }

        let readTool = createReadMcpResourceTool()
        if readTool.name == "ReadMcpResource" && !readTool.description.isEmpty {
            pass("ReadMcpResource tool registered with correct name and non-empty description")
        } else {
            fail("ReadMcpResource tool registration", "name=\(readTool.name)")
        }

        if readTool.isReadOnly {
            pass("ReadMcpResource isReadOnly is true")
        } else {
            fail("ReadMcpResource isReadOnly is true")
        }
    }

    // MARK: Schemas

    static func testMcpResourceToolSchemas() {
        let listTool = createListMcpResourcesTool()
        let listSchema = listTool.inputSchema

        if listSchema["type"] as? String == "object" {
            pass("ListMcpResources inputSchema type is 'object'")
        } else {
            fail("ListMcpResources inputSchema type is 'object'")
        }

        let listProps = listSchema["properties"] as? [String: Any]
        if listProps?["server"] != nil {
            pass("ListMcpResources inputSchema has 'server' property")
        } else {
            fail("ListMcpResources inputSchema has 'server' property")
        }

        let listRequired = listSchema["required"] as? [String] ?? []
        if listRequired.isEmpty {
            pass("ListMcpResources has no required fields")
        } else {
            fail("ListMcpResources has no required fields", "got: \(listRequired)")
        }

        let readTool = createReadMcpResourceTool()
        let readSchema = readTool.inputSchema

        let readRequired = readSchema["required"] as? [String] ?? []
        if Set(readRequired) == Set(["server", "uri"]) {
            pass("ReadMcpResource required fields are [server, uri]")
        } else {
            fail("ReadMcpResource required fields are [server, uri]", "got: \(readRequired)")
        }
    }

    // MARK: No Connections

    static func testListMcpResourcesNoConnections() async {
        setMcpConnections([])

        let tool = createListMcpResourcesTool()
        let context = ToolContext(cwd: "/tmp", toolUseId: "e2e-list-test")

        let result = await tool.call(input: [:], context: context)

        if !result.isError && result.content.contains("No MCP servers connected") {
            pass("ListMcpResources returns 'No MCP servers connected' when empty")
        } else {
            fail("ListMcpResources returns 'No MCP servers connected' when empty",
                 "isError=\(result.isError), content='\(result.content)'")
        }
    }

    static func testReadMcpResourceServerNotFound() async {
        setMcpConnections([])

        let tool = createReadMcpResourceTool()
        let context = ToolContext(cwd: "/tmp", toolUseId: "e2e-read-test")

        let result = await tool.call(
            input: ["server": "nonexistent", "uri": "file:///test.txt"],
            context: context
        )

        if result.isError && result.content.contains("MCP server not found") {
            pass("ReadMcpResource returns error for nonexistent server")
        } else {
            fail("ReadMcpResource returns error for nonexistent server",
                 "isError=\(result.isError), content='\(result.content)'")
        }
    }

    // MARK: ToolRegistry

    static func testMcpResourceToolsInSpecialistTier() {
        let tools = getAllBaseTools(tier: .specialist)
        let names = Set(tools.map { $0.name })

        if names.contains("ListMcpResources") {
            pass("Specialist tier includes ListMcpResources")
        } else {
            fail("Specialist tier includes ListMcpResources")
        }

        if names.contains("ReadMcpResource") {
            pass("Specialist tier includes ReadMcpResource")
        } else {
            fail("Specialist tier includes ReadMcpResource")
        }
    }
}
