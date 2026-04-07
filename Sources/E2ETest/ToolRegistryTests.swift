import Foundation
import OpenAgentSDK

// MARK: - Tests 15-16: Tool Registry & Assembly

struct ToolRegistryTests {
    static func run() {
        section("15. Tool Registry Operations")
        testToolRegistry()

        section("16. Tool Pool Assembly & Filtering")
        testToolPoolAssembly()
    }

    // MARK: Test 15

    static func testToolRegistry() {
        let coreTools = getAllBaseTools(tier: .core)

        if coreTools.count == 10 {
            pass("Tool registry: getAllBaseTools(.core) returns 10 tools")
        } else {
            fail("Tool registry: getAllBaseTools(.core) returns 10 tools", "got \(coreTools.count)")
        }

        let toolNames = Set(coreTools.map { $0.name })
        let expectedNames: Set<String> = [
            "Read", "Write", "Edit", "Glob", "Grep",
            "Bash", "AskUser", "ToolSearch", "WebFetch", "WebSearch"
        ]
        if toolNames == expectedNames {
            pass("Tool registry: all expected tool names present")
        } else {
            fail("Tool registry: all expected tool names present",
                 "missing: \(expectedNames.subtracting(toolNames)), extra: \(toolNames.subtracting(expectedNames))")
        }

        let advancedTools = getAllBaseTools(tier: .advanced)
        if advancedTools.isEmpty {
            pass("Tool registry: getAllBaseTools(.advanced) returns empty")
        } else {
            fail("Tool registry: getAllBaseTools(.advanced) returns empty")
        }

        var allValid = true
        for tool in coreTools {
            if tool.name.isEmpty || tool.description.isEmpty {
                allValid = false
                break
            }
        }
        if allValid {
            pass("Tool registry: all tools have non-empty name and description")
        } else {
            fail("Tool registry: all tools have non-empty name and description")
        }

        if let firstTool = coreTools.first {
            let apiTool = toApiTool(firstTool)
            if apiTool["name"] != nil && apiTool["description"] != nil && apiTool["input_schema"] != nil {
                pass("Tool registry: toApiTool produces correct format")
            } else {
                fail("Tool registry: toApiTool produces correct format")
            }
        }

        let apiTools = toApiTools(coreTools)
        if apiTools.count == coreTools.count {
            pass("Tool registry: toApiTools preserves count")
        } else {
            fail("Tool registry: toApiTools preserves count")
        }
    }

    // MARK: Test 16

    static func testToolPoolAssembly() {
        let baseTools = getAllBaseTools(tier: .core)

        struct TestInput: Codable { let value: String }

        let customTool = defineTool(
            name: "custom_test",
            description: "A test tool",
            inputSchema: ["type": "object", "properties": ["value": ["type": "string"]]],
            isReadOnly: true
        ) { (_: TestInput, _: ToolContext) async throws -> String in "ok" }

        let pool = assembleToolPool(
            baseTools: baseTools, customTools: [customTool],
            mcpTools: nil, allowed: nil, disallowed: nil
        )
        if pool.count == 11 {
            pass("Tool assembly: pool has 11 tools (10 base + 1 custom)")
        } else {
            fail("Tool assembly: pool has 11 tools", "got \(pool.count)")
        }

        let overrideTool = defineTool(
            name: "Read",
            description: "Custom read override",
            inputSchema: ["type": "object", "properties": ["path": ["type": "string"]]],
            isReadOnly: true
        ) { (_: TestInput, _: ToolContext) async throws -> String in "custom read" }

        let dedupedPool = assembleToolPool(
            baseTools: baseTools, customTools: [overrideTool],
            mcpTools: nil, allowed: nil, disallowed: nil
        )
        let readTool = dedupedPool.first { $0.name == "Read" }
        if readTool?.description == "Custom read override" {
            pass("Tool assembly: custom tool overrides base tool by name")
        } else {
            fail("Tool assembly: custom tool overrides base tool by name")
        }

        let filtered = filterTools(tools: baseTools, allowed: ["Read", "Write"], disallowed: nil)
        if filtered.count == 2 && filtered.allSatisfy({ ["Read", "Write"].contains($0.name) }) {
            pass("Tool filtering: allowed filter works")
        } else {
            fail("Tool filtering: allowed filter works", "got \(filtered.map { $0.name })")
        }

        let disallowed = filterTools(tools: baseTools, allowed: nil, disallowed: ["Bash"])
        if disallowed.count == 9 && !disallowed.contains(where: { $0.name == "Bash" }) {
            pass("Tool filtering: disallowed filter works")
        } else {
            fail("Tool filtering: disallowed filter works", "got \(disallowed.count) tools")
        }

        let combined = filterTools(tools: baseTools, allowed: ["Read", "Write", "Bash"], disallowed: ["Bash"])
        if combined.count == 2 && combined.allSatisfy({ ["Read", "Write"].contains($0.name) }) {
            pass("Tool filtering: disallowed overrides allowed")
        } else {
            fail("Tool filtering: disallowed overrides allowed", "got \(combined.map { $0.name })")
        }
    }
}
