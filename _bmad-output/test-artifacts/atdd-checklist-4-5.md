---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-07'
storyId: '4-5'
detectedStack: 'backend'
generationMode: 'ai-generation'
testFramework: 'XCTest'
---

# ATDD Test Checklist — Story 4.5: Task Tools (Create/List/Update/Get/Stop/Output)

## Test Strategy

| Level | AC | Priority | File |
|-------|-----|----------|------|
| Unit | #1 TaskCreate — create task with subject only | P0 | TaskToolsTests.swift |
| Unit | #1 TaskCreate — create task with all optional fields | P0 | TaskToolsTests.swift |
| Unit | #1 TaskCreate — default status is pending | P0 | TaskToolsTests.swift |
| Unit | #1 TaskCreate — create with initial status inProgress | P1 | TaskToolsTests.swift |
| Unit | #2 TaskList — list all tasks | P0 | TaskToolsTests.swift |
| Unit | #2 TaskList — filter by status | P0 | TaskToolsTests.swift |
| Unit | #2 TaskList — filter by owner | P0 | TaskToolsTests.swift |
| Unit | #2 TaskList — empty list returns "No tasks found" | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — update status successfully | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — update description/owner/output | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — task not found returns error | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — invalid status transition returns error | P0 | TaskToolsTests.swift |
| Unit | #4 TaskGet — get existing task with full details | P0 | TaskToolsTests.swift |
| Unit | #4 TaskGet — task not found returns error | P0 | TaskToolsTests.swift |
| Unit | #5 TaskStop — stop pending task | P0 | TaskToolsTests.swift |
| Unit | #5 TaskStop — stop with reason | P0 | TaskToolsTests.swift |
| Unit | #5 TaskStop — task not found returns error | P0 | TaskToolsTests.swift |
| Unit | #5 TaskStop — stop completed task returns transition error | P1 | TaskToolsTests.swift |
| Unit | #6 TaskOutput — get output of task | P0 | TaskToolsTests.swift |
| Unit | #6 TaskOutput — no output returns "(no output yet)" | P0 | TaskToolsTests.swift |
| Unit | #6 TaskOutput — task not found returns error | P0 | TaskToolsTests.swift |
| Unit | #7 ToolContext — taskStore field exists and is injectable | P0 | TaskToolsTests.swift |
| Unit | #7 ToolContext — backward compatible (nil default) | P0 | TaskToolsTests.swift |
| Unit | #8 Module boundary — tools do not import Core/Stores | P0 | TaskToolsTests.swift |
| Unit | #9 Error handling — toolStore nil returns error (all 6 tools) | P0 | TaskToolsTests.swift |
| Unit | #9 Error handling — never throws, always returns ToolResult | P0 | TaskToolsTests.swift |
| Unit | #10 inputSchema — TaskCreate schema matches TS SDK | P0 | TaskToolsTests.swift |
| Unit | #10 inputSchema — TaskList schema matches TS SDK | P0 | TaskToolsTests.swift |
| Unit | #10 inputSchema — TaskUpdate schema matches TS SDK | P0 | TaskToolsTests.swift |
| Unit | #10 inputSchema — TaskGet schema matches TS SDK | P0 | TaskToolsTests.swift |
| Unit | #10 inputSchema — TaskStop schema matches TS SDK | P0 | TaskToolsTests.swift |
| Unit | #10 inputSchema — TaskOutput schema matches TS SDK | P0 | TaskToolsTests.swift |
| Unit | #1 TaskCreate — factory returns valid ToolProtocol | P0 | TaskToolsTests.swift |
| Unit | #2 TaskList — factory returns valid ToolProtocol | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — factory returns valid ToolProtocol | P0 | TaskToolsTests.swift |
| Unit | #4 TaskGet — factory returns valid ToolProtocol | P0 | TaskToolsTests.swift |
| Unit | #5 TaskStop — factory returns valid ToolProtocol | P0 | TaskToolsTests.swift |
| Unit | #6 TaskOutput — factory returns valid ToolProtocol | P0 | TaskToolsTests.swift |
| Unit | #2 TaskList — isReadOnly is true | P0 | TaskToolsTests.swift |
| Unit | #4 TaskGet — isReadOnly is true | P0 | TaskToolsTests.swift |
| Unit | #6 TaskOutput — isReadOnly is true | P0 | TaskToolsTests.swift |
| Unit | #1 TaskCreate — isReadOnly is false | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — isReadOnly is false | P0 | TaskToolsTests.swift |
| Unit | #5 TaskStop — isReadOnly is false | P0 | TaskToolsTests.swift |
| Unit | #1 TaskCreate — input Codable decode | P0 | TaskToolsTests.swift |
| Unit | #3 TaskUpdate — input Codable decode | P0 | TaskToolsTests.swift |
| Unit | Integration — create then list | P1 | TaskToolsTests.swift |
| Unit | Integration — create then get then update then output | P1 | TaskToolsTests.swift |
| Unit | Integration — create then stop then output shows reason | P1 | TaskToolsTests.swift |

## Test Files Generated

1. `Tests/OpenAgentSDKTests/Tools/Advanced/TaskToolsTests.swift` — 48 tests

**Total: 48 tests**

## TDD Status: RED PHASE

All tests assert EXPECTED behavior that does not exist yet. They will FAIL until:
- `ToolContext` gains `taskStore` field in `Types/ToolTypes.swift`
- `AgentOptions` gains `taskStore` field in `Types/AgentTypes.swift`
- `createTaskCreateTool()` factory function is implemented in `Tools/Advanced/TaskCreateTool.swift`
- `createTaskListTool()` factory function is implemented in `Tools/Advanced/TaskListTool.swift`
- `createTaskUpdateTool()` factory function is implemented in `Tools/Advanced/TaskUpdateTool.swift`
- `createTaskGetTool()` factory function is implemented in `Tools/Advanced/TaskGetTool.swift`
- `createTaskStopTool()` factory function is implemented in `Tools/Advanced/TaskStopTool.swift`
- `createTaskOutputTool()` factory function is implemented in `Tools/Advanced/TaskOutputTool.swift`
- `Core/Agent.swift` injects taskStore into ToolContext at creation points
