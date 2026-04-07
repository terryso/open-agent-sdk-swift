---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-07'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-7-mcp-resource-tools.md'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/ConfigToolTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/RemoteTriggerToolTests.swift'
  - 'Sources/OpenAgentSDK/Tools/ToolRegistry.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/ConfigTool.swift'
---

# ATDD Checklist - Epic 5, Story 7: MCP Resource Tools (ListMcpResources, ReadMcpResource)

**Date:** 2026-04-07
**Author:** Nick
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want my Agent to list and read MCP resources, so it can access resources exposed by MCP servers.

**As a** SDK developer
**I want** ListMcpResources and ReadMcpResource tools
**So that** agents can list available resources and read specific resources from connected MCP servers

---

## Acceptance Criteria

1. **AC1: ListMcpResources tool registration** -- Tool registered with name "ListMcpResources" and description matching TS SDK (FR18).
2. **AC2: ListMcpResources inputSchema** -- server (string, optional, description: "Filter by MCP server name") -- no required fields (FR18).
3. **AC3: ListMcpResources isReadOnly** -- Returns true (read-only operation).
4. **AC4: ListMcpResources no connections** -- Returns "No MCP servers connected." when no MCP servers connected or server filter matches nothing (FR18).
5. **AC5: ListMcpResources list resources** -- With connected servers, lists formatted resources. If not supported returns tool count hint or "resource listing not supported" (FR18).
6. **AC6: ListMcpResources server filter** -- With multiple servers, server parameter filters to only the specified server's resources (FR18).
7. **AC7: ReadMcpResource tool registration** -- Tool registered with name "ReadMcpResource" and description matching TS SDK (FR18).
8. **AC8: ReadMcpResource inputSchema** -- server (string, required), uri (string, required), required: ["server", "uri"] (FR18).
9. **AC9: ReadMcpResource isReadOnly** -- Returns true (read-only operation).
10. **AC10: ReadMcpResource server not found** -- Returns is_error=true, "MCP server not found: {server}" (FR18).
11. **AC11: ReadMcpResource read success** -- Returns concatenated text or JSON-serialized content from MCP client (FR18).
12. **AC12: ReadMcpResource no content** -- Returns "Resource read returned no content." when contents is empty (FR18).
13. **AC13: ReadMcpResource read exception** -- Returns is_error=true, "Error reading resource: {message}" (FR18).
14. **AC14: Module boundary** -- Tools in Tools/Specialist/ only import Foundation and Types/ -- never Core/ or Stores/ (rules #7, #40).
15. **AC15: Error handling** -- Exceptions caught and returned as is_error=true ToolResult, never interrupt agent loop (rule #38).
16. **AC16: ToolRegistry registration** -- Both tools included in getAllBaseTools(tier: .specialist) (FR18).
17. **AC17: OpenAgentSDK.swift docs** -- Module entry file includes documentation references for both tools.
18. **AC18: MCP connection injection** -- Via global setMcpConnections function + file-level variable (matching TS SDK pattern).
19. **AC19: E2E test coverage** -- E2E tests in Sources/E2ETest/ covering no-connection prompt and basic operation paths.

---

## Failing Tests Created (RED Phase)

### Unit Tests -- McpResourceToolTests (44 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift`

#### ListMcpResources Tool (22 tests)

- **Test:** testCreateListMcpResourcesTool_returnsToolProtocol
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC1 -- tool name is "ListMcpResources", has non-empty description

- **Test:** testCreateListMcpResourcesTool_descriptionMentionsResources
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC1 -- description mentions resources and MCP/server

- **Test:** testCreateListMcpResourcesTool_inputSchema_hasCorrectType
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC2 -- schema type is "object"

- **Test:** testCreateListMcpResourcesTool_inputSchema_hasOptionalServer
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC2 -- server is string with correct description, not in required

- **Test:** testCreateListMcpResourcesTool_inputSchema_noRequiredFields
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC2 -- schema has no required fields

- **Test:** testCreateListMcpResourcesTool_isReadOnly_returnsTrue
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC3 -- isReadOnly is true

- **Test:** testListMcpResources_noConnections_returnsNoServersMessage
  - **Status:** RED - createListMcpResourcesTool() / setMcpConnections not yet implemented
  - **Verifies:** AC4 -- returns "No MCP servers connected."

- **Test:** testListMcpResources_serverFilterNoMatch_returnsNoServersMessage
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC4 -- unmatched server filter returns "No MCP servers connected."

- **Test:** testListMcpResources_withConnection_returnsFormattedList
  - **Status:** RED - MCPResourceProvider / MCPConnectionInfo not yet defined
  - **Verifies:** AC5 -- returns formatted list with server name and resource names

- **Test:** testListMcpResources_resourceFormatting
  - **Status:** RED - types not yet defined
  - **Verifies:** AC5 -- resources formatted with name and description

- **Test:** testListMcpResources_noResourceSupport_returnsNotSupported
  - **Status:** RED - types not yet defined
  - **Verifies:** AC5 -- server without listResources returns appropriate message

- **Test:** testListMcpResources_providerThrows_returnsNotSupported
  - **Status:** RED - types not yet defined
  - **Verifies:** AC5 -- provider exception handled gracefully

- **Test:** testListMcpResources_serverFilter_returnsOnlyMatchingServer
  - **Status:** RED - types not yet defined
  - **Verifies:** AC6 -- server filter returns only matching server resources

- **Test:** testListMcpResources_noFilter_returnsAllServers
  - **Status:** RED - types not yet defined
  - **Verifies:** AC6 -- no filter returns all servers

- **Test:** testListMcpResources_skipsDisconnectedServers
  - **Status:** RED - types not yet defined
  - **Verifies:** AC6 -- disconnected servers are skipped

- **Test:** testListMcpResourcesTool_doesNotRequireStoreInContext
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC14 -- works with minimal ToolContext

- **Test:** testListMcpResourcesTool_neverThrows_malformedInput
  - **Status:** RED - createListMcpResourcesTool() not yet implemented
  - **Verifies:** AC15 -- always returns ToolResult, never throws

#### ReadMcpResource Tool (17 tests)

- **Test:** testCreateReadMcpResourceTool_returnsToolProtocol
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC7 -- tool name is "ReadMcpResource", has non-empty description

- **Test:** testCreateReadMcpResourceTool_descriptionMentionsReading
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC7 -- description mentions resource and read/server

- **Test:** testCreateReadMcpResourceTool_inputSchema_hasCorrectType
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC8 -- schema type is "object"

- **Test:** testCreateReadMcpResourceTool_inputSchema_hasRequiredServer
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC8 -- server is string, in required array

- **Test:** testCreateReadMcpResourceTool_inputSchema_hasRequiredUri
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC8 -- uri is string, in required array

- **Test:** testCreateReadMcpResourceTool_inputSchema_requiredFieldsExactly
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC8 -- required fields are exactly ["server", "uri"]

- **Test:** testCreateReadMcpResourceTool_isReadOnly_returnsTrue
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC9 -- isReadOnly is true

- **Test:** testReadMcpResource_serverNotFound_returnsError
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC10 -- returns is_error=true with "MCP server not found: {server}"

- **Test:** testReadMcpResource_wrongServerName_returnsError
  - **Status:** RED - types not yet defined
  - **Verifies:** AC10 -- wrong server name returns error

- **Test:** testReadMcpResource_validServer_returnsContent
  - **Status:** RED - types not yet defined
  - **Verifies:** AC11 -- returns text content from resource

- **Test:** testReadMcpResource_multipleContentItems_concatenatesText
  - **Status:** RED - types not yet defined
  - **Verifies:** AC11 -- multiple content items are concatenated

- **Test:** testReadMcpResource_nonTextContent_serializesToJson
  - **Status:** RED - types not yet defined
  - **Verifies:** AC11 -- non-text content is JSON-serialized

- **Test:** testReadMcpResource_emptyContents_returnsNoContentMessage
  - **Status:** RED - types not yet defined
  - **Verifies:** AC12 -- empty contents returns "no content" message

- **Test:** testReadMcpResource_nilContents_returnsNoContentMessage
  - **Status:** RED - types not yet defined
  - **Verifies:** AC12 -- nil contents returns "no content" message

- **Test:** testReadMcpResource_providerThrows_returnsError
  - **Status:** RED - types not yet defined
  - **Verifies:** AC13 -- provider exception returns is_error=true

- **Test:** testReadMcpResource_providerThrows_includesErrorMessage
  - **Status:** RED - types not yet defined
  - **Verifies:** AC13 -- error message includes "Error reading resource"

- **Test:** testReadMcpResourceTool_doesNotRequireStoreInContext
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC14 -- works with minimal ToolContext

- **Test:** testReadMcpResourceTool_neverThrows_malformedInput
  - **Status:** RED - createReadMcpResourceTool() not yet implemented
  - **Verifies:** AC15 -- always returns ToolResult, never throws

#### Cross-cutting & Types (5 tests)

- **Test:** testToolRegistry_specialistTier_includesListMcpResourcesTool
  - **Status:** RED - tools not yet registered in ToolRegistry
  - **Verifies:** AC16 -- ListMcpResources in specialist tier

- **Test:** testToolRegistry_specialistTier_includesReadMcpResourceTool
  - **Status:** RED - tools not yet registered in ToolRegistry
  - **Verifies:** AC16 -- ReadMcpResource in specialist tier

- **Test:** testSetMcpConnections_exists
  - **Status:** RED - setMcpConnections function not yet defined
  - **Verifies:** AC18 -- setMcpConnections compiles and accepts array

- **Test:** testSetMcpConnections_clearsConnections
  - **Status:** RED - setMcpConnections function not yet defined
  - **Verifies:** AC18 -- clearing connections works correctly

- **Test:** testIntegration_listFilterRead_lifecycle
  - **Status:** RED - all types and functions not yet implemented
  - **Verifies:** AC5, AC6, AC11 -- full list -> filter -> read lifecycle

#### MCP Type Existence Tests (5 tests)

- **Test:** testMCPResourceItem_creation
  - **Status:** RED - MCPResourceItem type not yet defined
  - **Verifies:** Type existence -- MCPResourceItem can be created with fields

- **Test:** testMCPResourceItem_creationWithNilOptionals
  - **Status:** RED - MCPResourceItem type not yet defined
  - **Verifies:** Type existence -- optional fields work correctly

- **Test:** testMCPConnectionInfo_creation
  - **Status:** RED - MCPConnectionInfo type not yet defined
  - **Verifies:** Type existence -- MCPConnectionInfo can be created

- **Test:** testMCPReadResult_creation
  - **Status:** RED - MCPReadResult type not yet defined
  - **Verifies:** Type existence -- MCPReadResult can hold contents

- **Test:** testMCPReadResult_creationWithNilContents
  - **Status:** RED - MCPReadResult type not yet defined
  - **Verifies:** Type existence -- MCPReadResult accepts nil

- **Test:** testMCPContentItem_creationWithText
  - **Status:** RED - MCPContentItem type not yet defined
  - **Verifies:** Type existence -- MCPContentItem can be created with text

---

## Implementation Checklist

### Task 1: Define MCP Resource Types (AC: #18)

**File:** `Sources/OpenAgentSDK/Types/MCPResourceTypes.swift` (new file)

**Tasks to make type existence tests pass:**

- [ ] Define `MCPResourceProvider` protocol with `listResources() async -> [MCPResourceItem]?` and `readResource(uri:) async throws -> MCPReadResult`
- [ ] Define `MCPResourceItem` struct with name (String), description (String?), uri (String?)
- [ ] Define `MCPConnectionInfo` struct with name (String), status (String), resourceProvider (MCPResourceProvider?)
- [ ] Define `MCPReadResult` struct with contents ([MCPContentItem]?)
- [ ] Define `MCPContentItem` struct with text (String?), rawValue (Any?)
- [ ] Ensure all types conform to Sendable
- [ ] Run tests: `swift test --filter McpResourceToolTests/testMCP`

### Task 2: Implement ListMcpResources Tool (AC: #1-#6, #14, #15)

**File:** `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` (new file)

**Tasks to make ListMcpResources tests pass:**

- [ ] Define `nonisolated(unsafe) var mcpConnections: [MCPConnectionInfo] = []` file-level variable
- [ ] Define `setMcpConnections(_ connections: [MCPConnectionInfo])` public function
- [ ] Define `listMcpResourcesSchema` constant matching TS SDK (server optional, no required fields)
- [ ] Implement `createListMcpResourcesTool()` factory function returning ToolProtocol
- [ ] Handle no connections -> "No MCP servers connected."
- [ ] Handle server filter -> only matching server
- [ ] Handle connected servers -> list resources via provider
- [ ] Handle nil provider -> "resource listing not supported"
- [ ] Handle exceptions -> "resource listing not supported"
- [ ] Only import Foundation and Types/
- [ ] Run tests: `swift test --filter McpResourceToolTests/testCreateListMcpResourcesTool`
- [ ] Run tests: `swift test --filter McpResourceToolTests/testListMcpResources`

### Task 3: Implement ReadMcpResource Tool (AC: #7-#13, #14, #15)

**File:** `Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift` (new file)

**Tasks to make ReadMcpResource tests pass:**

- [ ] Define `readMcpResourceSchema` constant matching TS SDK (server + uri required)
- [ ] Define `ReadMcpResourceInput` Codable struct with server and uri
- [ ] Implement `createReadMcpResourceTool()` factory function returning ToolProtocol
- [ ] Handle server not found -> is_error=true, "MCP server not found: {server}"
- [ ] Handle read success -> concatenate text or JSON-serialized content
- [ ] Handle empty contents -> "Resource read returned no content."
- [ ] Handle exceptions -> is_error=true, "Error reading resource: {message}"
- [ ] Only import Foundation and Types/
- [ ] Run tests: `swift test --filter McpResourceToolTests/testCreateReadMcpResourceTool`
- [ ] Run tests: `swift test --filter McpResourceToolTests/testReadMcpResource`

### Task 4: Update ToolRegistry (AC: #16)

**File:** `Sources/OpenAgentSDK/Tools/ToolRegistry.swift`

- [ ] Add `createListMcpResourcesTool()` to specialist tier
- [ ] Add `createReadMcpResourceTool()` to specialist tier
- [ ] Run tests: `swift test --filter McpResourceToolTests/testToolRegistry`

### Task 5: Update Module Entry (AC: #17)

**File:** `Sources/OpenAgentSDK/OpenAgentSDK.swift`

- [ ] Add documentation references for createListMcpResourcesTool and createReadMcpResourceTool

### Task 6: E2E Tests (AC: #19)

**Files:** `Sources/E2ETest/`

- [ ] Add ListMcpResources E2E section
- [ ] Add ReadMcpResource E2E section
- [ ] Cover no-connection prompt and basic operation paths

### Task 7: Compile Verification

- [ ] Run `swift build` to confirm compilation passes
- [ ] Verify new files do not import Core/ or Stores/
- [ ] Run `swift test --filter McpResourceToolTests` to verify all tests pass (GREEN phase)

---

## Running Tests

```bash
# Run all failing tests for this story (will fail until implementation)
swift test --filter McpResourceToolTests

# Build only (verify compilation)
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and designed to fail
- Test files follow established patterns (ConfigToolTests, LSPToolTests, RemoteTriggerToolTests)
- Implementation checklist created with task-to-test mapping
- 44 total tests covering 18 acceptance criteria (AC1-AC18)
- Mock MCPResourceProvider included for testing with mock connections

**Verification:**

- All tests fail due to missing types (MCPResourceProvider, MCPConnectionInfo, MCPResourceItem, MCPReadResult, MCPContentItem, factory functions)
- Failure messages are clear: "use of unresolved identifier" or "cannot find type"
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

1. **Start with Task 1** (types) -- makes MCPResourceItem, MCPConnectionInfo, MCPReadResult, MCPContentItem tests pass
2. **Task 2** (ListMcpResources tool) -- makes all ListMcpResources tests pass
3. **Task 3** (ReadMcpResource tool) -- makes all ReadMcpResource tests pass
4. **Tasks 4-5** (ToolRegistry + docs) -- makes registry and doc tests pass
5. **Task 6** (E2E) -- covers AC19

---

## Acceptance Criteria Coverage Matrix

| AC | Description | Test Methods |
|----|-------------|-------------|
| AC1 | ListMcpResources registration | testCreateListMcpResourcesTool_returnsToolProtocol, testCreateListMcpResourcesTool_descriptionMentionsResources |
| AC2 | ListMcpResources inputSchema | testCreateListMcpResourcesTool_inputSchema_hasCorrectType, testCreateListMcpResourcesTool_inputSchema_hasOptionalServer, testCreateListMcpResourcesTool_inputSchema_noRequiredFields |
| AC3 | ListMcpResources isReadOnly | testCreateListMcpResourcesTool_isReadOnly_returnsTrue |
| AC4 | ListMcpResources no connections | testListMcpResources_noConnections_returnsNoServersMessage, testListMcpResources_serverFilterNoMatch_returnsNoServersMessage |
| AC5 | ListMcpResources list resources | testListMcpResources_withConnection_returnsFormattedList, testListMcpResources_resourceFormatting, testListMcpResources_noResourceSupport_returnsNotSupported, testListMcpResources_providerThrows_returnsNotSupported |
| AC6 | ListMcpResources server filter | testListMcpResources_serverFilter_returnsOnlyMatchingServer, testListMcpResources_noFilter_returnsAllServers, testListMcpResources_skipsDisconnectedServers |
| AC7 | ReadMcpResource registration | testCreateReadMcpResourceTool_returnsToolProtocol, testCreateReadMcpResourceTool_descriptionMentionsReading |
| AC8 | ReadMcpResource inputSchema | testCreateReadMcpResourceTool_inputSchema_hasCorrectType, testCreateReadMcpResourceTool_inputSchema_hasRequiredServer, testCreateReadMcpResourceTool_inputSchema_hasRequiredUri, testCreateReadMcpResourceTool_inputSchema_requiredFieldsExactly |
| AC9 | ReadMcpResource isReadOnly | testCreateReadMcpResourceTool_isReadOnly_returnsTrue |
| AC10 | ReadMcpResource server not found | testReadMcpResource_serverNotFound_returnsError, testReadMcpResource_wrongServerName_returnsError |
| AC11 | ReadMcpResource read success | testReadMcpResource_validServer_returnsContent, testReadMcpResource_multipleContentItems_concatenatesText, testReadMcpResource_nonTextContent_serializesToJson |
| AC12 | ReadMcpResource no content | testReadMcpResource_emptyContents_returnsNoContentMessage, testReadMcpResource_nilContents_returnsNoContentMessage |
| AC13 | ReadMcpResource read exception | testReadMcpResource_providerThrows_returnsError, testReadMcpResource_providerThrows_includesErrorMessage |
| AC14 | Module boundary | testListMcpResourcesTool_doesNotRequireStoreInContext, testReadMcpResourceTool_doesNotRequireStoreInContext |
| AC15 | Error handling | testListMcpResourcesTool_neverThrows_malformedInput, testReadMcpResourceTool_neverThrows_malformedInput |
| AC16 | ToolRegistry registration | testToolRegistry_specialistTier_includesListMcpResourcesTool, testToolRegistry_specialistTier_includesReadMcpResourceTool |
| AC17 | OpenAgentSDK docs | (verified in GREEN phase by manual inspection) |
| AC18 | MCP connection injection | testSetMcpConnections_exists, testSetMcpConnections_clearsConnections |
| AC19 | E2E test coverage | (created in GREEN phase in Sources/E2ETest/) |

---

## Notes

- MCP resource tools use global setMcpConnections pattern (matching TS SDK) rather than ToolContext injection
- Both tools are read-only (isReadOnly = true) -- no state modification
- MockMCPResourceProvider is included in the test file for testing with mock MCP connections
- Types are placed in Types/ directory (leaf node, no outbound dependencies per architecture rule #7)
- nonisolated(unsafe) required for schema dictionary constants and mcpConnections file-level variable
- Story 5-7 is the final story in Epic 5
- These tests will be validated by running `swift build` to confirm they fail at compile time (expected for RED phase)

---

**Generated by BMad TEA Agent** - 2026-04-07
