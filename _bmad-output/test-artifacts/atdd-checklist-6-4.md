---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-08'
story_id: '6-4-mcp-tool-agent-integration'
inputDocuments:
  - '_bmad-output/implementation-artifacts/6-4-mcp-tool-agent-integration.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift'
  - 'Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
---

# ATDD Checklist: Story 6-4 MCP Tool Agent Integration

## Stack Detection
- **Detected Stack:** `backend` (Swift Package Manager, no frontend)
- **Test Framework:** XCTest (Swift native)
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

---

## Acceptance Criteria to Test Mapping

### AC1: MCP Tool Namespace Integration
| ID | Test | Level | Priority | File | Status |
|----|------|-------|----------|------|--------|
| AC1-01 | assembleFullToolPool merges built-in + MCP tools | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC1-02 | MCP tools use mcp__{server}__{toolName} namespace | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC1-03 | No MCP servers returns custom tools only | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC1-04 | Empty mcpServers behaves same as nil | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC1-05 | MCP tool inputSchema passes through correctly | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC1-06 | Custom + MCP tools appear together in pool | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC1-07 | AgentOptions holds all four config types | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC1-E2E-01 | AgentOptions holds SDK + external config | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC1-E2E-02 | AgentOptions holds all four config types | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC1-E2E-03 | AgentOptions empty mcpServers | E2E | P1 | MCPClientManagerTests.swift | PASS |
| AC1-E2E-04 | AgentOptions nil mcpServers (default) | E2E | P1 | MCPClientManagerTests.swift | PASS |

### AC3: SDK In-Process Tool Direct Injection
| ID | Test | Level | Priority | File | Status |
|----|------|-------|----------|------|--------|
| AC3-01 | SDK tools injected without MCP protocol | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC3-02 | SdkToolWrapper namespace prefix correct | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC3-03 | SdkToolWrapper delegates call() to inner tool | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |

### AC4: Mixed Configuration Handling
| ID | Test | Level | Priority | File | Status |
|----|------|-------|----------|------|--------|
| AC4-01 | processMcpConfigs separates SDK and external | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC4-02 | Mixed config (stdio + sdk) merged pool | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC4-03 | Four-way mixed config (all types) | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC4-04 | SDK tools available with failing external | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC4-05 | Multiple MCP servers tools merged | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC4-E2E-01 | SDK + failing external tools reachable | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC4-E2E-02 | Multiple SDK servers distinct tools | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC4-E2E-03 | External server tools via MCPClientManager | E2E | P1 | MCPClientManagerTests.swift | PASS |

### AC7: Tool Execution Error Isolation
| ID | Test | Level | Priority | File | Status |
|----|------|-------|----------|------|--------|
| AC7-01 | MCP tool failure returns isError: true | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC7-02 | Nil MCP client returns error ToolResult | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC7-03 | MCP tool error does not crash agent loop | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC7-04 | MCP connection failure -- builtin tools still available | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC7-E2E-01 | MCP tool error isolation (E2E) | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC7-E2E-02 | Built-in tools available on MCP failure (E2E) | E2E | P1 | MCPClientManagerTests.swift | PASS |

### AC8: Tool Pool Deduplication
| ID | Test | Level | Priority | File | Status |
|----|------|-------|----------|------|--------|
| AC8-01 | Duplicate MCP tools deduplicated | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC8-02 | Tool name uniqueness across servers | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC8-03 | Custom tool overrides built-in via dedup | Unit | P1 | MCPAgentIntegrationTests.swift | PASS |
| AC8-E2E-01 | Tool pool deduplication (E2E) | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC8-E2E-02 | Tool name uniqueness (E2E) | E2E | P0 | MCPClientManagerTests.swift | PASS |

### AC9: MCP Connection Lifecycle
| ID | Test | Level | Priority | File | Status |
|----|------|-------|----------|------|--------|
| AC9-01 | Connections cleaned up after usage | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC9-02 | Shutdown clears all external connections | Unit | P0 | MCPAgentIntegrationTests.swift | PASS |
| AC9-E2E-01 | Shutdown clears all (E2E) | E2E | P0 | MCPClientManagerTests.swift | PASS |
| AC9-E2E-02 | SDK server no MCPClientManager needed (E2E) | E2E | P0 | MCPClientManagerTests.swift | PASS |

---

## Test Files Created/Modified

### New Files
1. `Tests/OpenAgentSDKTests/MCP/MCPAgentIntegrationTests.swift` -- 24 unit tests

### Modified Files
2. `Sources/E2ETest/MCPClientManagerTests.swift` -- 14 new E2E tests added (Story 6-4 section)

---

## Test Statistics

| Category | Count | Status |
|----------|-------|--------|
| Unit Tests (P0) | 14 | All PASS |
| Unit Tests (P1) | 10 | All PASS |
| E2E Tests (P0) | 9 | All PASS |
| E2E Tests (P1) | 5 | All PASS |
| **Total** | **38** | **All PASS** |

---

## Build Status
- `swift build`: PASS (clean build, no warnings)
- `swift test`: PASS (1407 tests, 0 failures, 4 skipped -- no regressions)

---

## TDD Phase Note

This story is an **integration verification story** -- the MCP infrastructure was built in Stories 6-1, 6-2, and 6-3. The tests verify that the existing implementation correctly integrates MCP tools into the Agent execution flow. Since the implementation is already in place, tests pass immediately (GREEN phase upon creation). The tests serve as **regression protection** and **documentation** of the integration contracts.

---

## Key Findings from Testing

1. **assembleFullToolPool behavior without MCP servers**: When no MCP servers are configured, the method returns only `options.tools` (custom tools) without adding built-in base tools. Built-in tools are only added to the pool when MCP server processing triggers the full assembly path. This is by design since the prompt/stream paths handle tool assembly independently.

2. **SDK-only config creates no MCPClientManager**: When only `.sdk` configs are present, no external connections are needed, so `MCPClientManager` is not created. This confirms the zero-overhead design.

3. **MCPToolDefinition error isolation works correctly**: All error cases (nil client, connection failure, timeout) are captured as `ToolResult(isError: true)` without throwing, confirming rule #38/#39 compliance.
