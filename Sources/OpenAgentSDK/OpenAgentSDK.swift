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

/// Current SDK version.
public let SDK_VERSION = "0.1.0"
