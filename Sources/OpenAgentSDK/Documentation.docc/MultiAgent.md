# Multi-Agent Orchestration

Coordinate multiple agents working together on complex tasks.

## Overview

OpenAgentSDK provides built-in support for multi-agent coordination through stores for tasks, teams, mailboxes, and agent discovery. Agents can spawn sub-agents, exchange messages, manage shared tasks, and organize into teams.

## Sub-Agent Spawning

The Agent tool allows an agent to spawn child agents that run independently. Sub-agents inherit configuration from the parent but can be customized:

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    tools: getAllBaseTools(tier: .core) + [createAgentTool()]
))

// The parent agent can now use the Agent tool to spawn sub-agents
let result = await agent.prompt(
    "Create a sub-agent to research quantum computing and summarize the findings"
)
```

Sub-agent behavior is configured via ``AgentDefinition``:

```swift
public struct AgentDefinition: Sendable {
    public let name: String
    public let description: String?
    public let model: String?
    public let systemPrompt: String?
    public let tools: [String]?        // nil = inherit all parent tools
    public let maxTurns: Int?          // nil = default 10
}
```

## Inter-Agent Messaging

### MailboxStore

``MailboxStore`` provides thread-safe inter-agent messaging. Agents send and receive messages asynchronously:

```swift
let mailbox = MailboxStore()

// Agent A sends a message to Agent B
await mailbox.send(from: "researcher", to: "writer", content: "Research complete")

// Agent B reads pending messages (and clears mailbox)
let messages = await mailbox.read(agentName: "writer")
for msg in messages {
    print("From: \(msg.from), Content: \(msg.content)")
}
```

### SendMessageTool

The ``createSendMessageTool()`` factory creates a tool that lets agents send messages:

```swift
let sendMsgTool = createSendMessageTool()

let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    agentName: "researcher",
    mailboxStore: mailbox,
    teamStore: teamStore,
    tools: [sendMsgTool]
))
```

Messages are typed via ``AgentMessageType``: `text`, `shutdownRequest`, `shutdownResponse`, and `planApprovalResponse`.

## Task Management

### TaskStore

``TaskStore`` manages shared tasks across agents:

```swift
let taskStore = TaskStore()

// Create a task
let task = await taskStore.create(
    subject: "Analyze dataset",
    description: "Run statistical analysis on the provided data",
    owner: "analyst"
)

// List tasks
let allTasks = await taskStore.list()
let myTasks = await taskStore.list(owner: "analyst")

// Update task status
let updated = try await taskStore.update(id: task.id, status: .inProgress)

// Complete the task
let completed = try await taskStore.update(
    id: task.id,
    status: .completed,
    output: "Analysis complete: mean=42.5, std=3.2"
)
```

Task lifecycle follows this state machine:

```
pending -> inProgress -> completed
                      -> failed
                      -> cancelled
```

Terminal states (`completed`, `failed`, `cancelled`) cannot transition further.

### Task Tools

Factory functions create tools for task management:

- ``createTaskCreateTool()`` — Create tasks
- ``createTaskListTool()`` — List tasks with optional filters
- ``createTaskUpdateTool()`` — Update task status, description, output
- ``createTaskGetTool()`` — Get a single task by ID
- ``createTaskStopTool()`` — Stop a running task
- ``createTaskOutputTool()`` — Append output to a task

## Team Management

### TeamStore

``TeamStore`` manages teams of agents with leader/member roles:

```swift
let teamStore = TeamStore()

// Create a team
let team = await teamStore.create(
    name: "Research Team",
    members: [
        TeamMember(name: "lead", role: .leader),
        TeamMember(name: "analyst", role: .member),
        TeamMember(name: "writer", role: .member)
    ],
    leaderId: "lead"
)

// Add a member
let updated = try await teamStore.addMember(
    teamId: team.id,
    member: TeamMember(name: "reviewer", role: .member)
)

// Disband the team
try await teamStore.delete(id: team.id)
```

### AgentRegistry

``AgentRegistry`` tracks active sub-agents for discovery:

```swift
let registry = AgentRegistry()

// Register an agent
let entry = try await registry.register(
    agentId: "agent-001",
    name: "researcher",
    agentType: "worker"
)

// Look up by name (O(1) via reverse index)
let found = await registry.getByName(name: "researcher")

// List agents by type
let workers = await registry.listByType(agentType: "worker")
```

### Team Tools

- ``createTeamCreateTool()`` — Create a new team
- ``createTeamDeleteTool()`` — Disband a team

## Orchestration Patterns

### Pipeline Pattern

Chain agents in sequence, passing results forward:

```swift
// Agent 1: Research
let researcher = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    agentName: "researcher",
    systemPrompt: "You are a research specialist."
))

// Agent 2: Writing
let writer = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    agentName: "writer",
    systemPrompt: "You are a technical writer."
))

let research = await researcher.prompt("Research Swift concurrency")
let article = await writer.prompt("Write an article based on: \(research.text)")
```

### Coordinator Pattern

A lead agent delegates to specialized sub-agents using the Agent tool:

```swift
let coordinator = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    tools: getAllBaseTools(tier: .core) + [
        createAgentTool(),
        createSendMessageTool(),
        createTaskCreateTool(),
        createTaskListTool()
    ],
    mailboxStore: mailbox,
    taskStore: taskStore,
    teamStore: teamStore
))
```

### Best Practices

1. **Name your agents** — Set ``AgentOptions/agentName`` for clear message routing.
2. **Use system prompts** — Give each agent a clear role and boundaries.
3. **Limit tool sets** — Only provide tools relevant to the agent's role.
4. **Set maxTurns** — Prevent runaway sub-agents with reasonable turn limits.
5. **Handle errors gracefully** — Check ``SubAgentResult/isError`` from sub-agent spawns.
