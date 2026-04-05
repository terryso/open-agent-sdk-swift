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

/// Current SDK version.
public let SDK_VERSION = "0.1.0"
