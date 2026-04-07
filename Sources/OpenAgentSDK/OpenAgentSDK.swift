/// OpenAgentSDK — Swift SDK for building AI agent applications.
///
/// Import this module to access all public types and protocols.
/// ```swift
/// import OpenAgentSDK
/// ```
///
/// ## Core Types
/// - ``Agent`` — AI agent for processing prompts via the Anthropic API
/// - ``createAgent(options:)`` — Factory function to create an ``Agent``
/// - ``AgentOptions`` — Agent configuration
/// - ``SDKConfiguration`` — SDK configuration from env vars or programmatic values
/// - ``SDKMessage`` — Streaming message union type
/// - ``SDKError`` — Unified error type
/// - ``TokenUsage`` — Token usage tracking
/// - ``ToolProtocol`` — Tool definition protocol
/// - ``PermissionMode`` — Permission modes
/// - ``ThinkingConfig`` — Thinking configuration
/// - ``QueryResult`` — Query result
/// - ``ModelInfo`` — Model metadata
/// - ``MODEL_PRICING`` — Pricing table
///
/// ## Tool System
/// - ``ToolProtocol`` — Tool definition protocol
/// - ``defineTool(name:description:inputSchema:isReadOnly:execute:)`` — Factory function to create tools with Codable input and String return
/// - ``defineTool(name:description:inputSchema:isReadOnly:execute:)-9hwyt`` — Factory function for tools returning ``ToolExecuteResult``
/// - ``defineTool(name:description:inputSchema:isReadOnly:execute:)-4p40y`` — Factory function for no-input tools
/// - ``ToolExecuteResult`` — Structured return type with content and isError fields
/// - ``ToolResult`` — Tool execution result with toolUseId, content, and isError
/// - ``ToolContext`` — Execution context with cwd and toolUseId
/// - ``toApiTool(_:)`` — Convert a tool to Anthropic API format
/// - ``toApiTools(_:)`` — Convert an array of tools to API format
/// - ``ToolTier`` — Tool tier enum (core, advanced, specialist)
/// - ``getAllBaseTools(tier:)`` — Get all base tools for a tier
/// - ``filterTools(tools:allowed:disallowed:)`` — Filter tools by name
/// - ``assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)`` — Assemble deduplicated tool pool
///
/// ## Stores
/// - ``TaskStore`` — Thread-safe task management actor
/// - ``MailboxStore`` — Thread-safe inter-agent messaging actor
/// - ``TeamStore`` — Thread-safe team management actor
/// - ``AgentRegistry`` — Thread-safe sub-agent registration and discovery actor
/// - ``Task`` — Task data structure
/// - ``TaskStatus`` — Task status enum
/// - ``TaskStoreError`` — Task store error type
/// - ``AgentMessage`` — Inter-agent message data structure
/// - ``AgentMessageType`` — Message type enum
/// - ``Team`` — Team data structure
/// - ``TeamMember`` — Team member data structure
/// - ``TeamRole`` — Team member role enum
/// - ``TeamStatus`` — Team status enum
/// - ``AgentRegistryEntry`` — Agent registry entry data structure
/// - ``TeamStoreError`` — Team store error type
/// - ``AgentRegistryError`` — Agent registry error type
///
/// ## Sub-Agent Spawning
/// - ``SubAgentSpawner`` — Protocol for spawning sub-agents (defined in Types/)
/// - ``SubAgentResult`` — Result from sub-agent execution
/// - ``AgentDefinition`` — Sub-agent configuration with tools and maxTurns
/// - ``createAgentTool()`` — Factory for the Agent tool
/// - ``createSendMessageTool()`` — Factory for the SendMessage tool
/// - ``createTaskCreateTool()`` — Factory for the TaskCreate tool
/// - ``createTaskListTool()`` — Factory for the TaskList tool
/// - ``createTaskUpdateTool()`` — Factory for the TaskUpdate tool
/// - ``createTaskGetTool()`` — Factory for the TaskGet tool
/// - ``createTaskStopTool()`` — Factory for the TaskStop tool
/// - ``createTaskOutputTool()`` — Factory for the TaskOutput tool
/// - ``createTeamCreateTool()`` — Factory for the TeamCreate tool
/// - ``createTeamDeleteTool()`` — Factory for the TeamDelete tool
/// - ``createNotebookEditTool()`` — Factory for the NotebookEdit tool
/// - ``createEnterWorktreeTool()`` — Factory for the EnterWorktree tool
/// - ``createExitWorktreeTool()`` — Factory for the ExitWorktree tool
///
/// ## Specialist Stores
/// - ``WorktreeStore`` — Thread-safe worktree management actor
/// - ``WorktreeEntry`` — Worktree data structure
/// - ``WorktreeStatus`` — Worktree status enum
/// - ``WorktreeStoreError`` — Worktree store error type

/// Current SDK version.
public let SDK_VERSION = "0.1.0"
