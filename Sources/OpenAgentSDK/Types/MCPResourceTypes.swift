import Foundation

// MARK: - MCPResourceProvider Protocol

/// Protocol for MCP resource operations.
/// Will be implemented by MCPClientManager's connections in Epic 6.
public protocol MCPResourceProvider: Sendable {
    /// List available resources from the MCP server.
    /// Returns nil if the server does not support resource listing.
    func listResources() async -> [MCPResourceItem]?

    /// Read a specific resource by URI from the MCP server.
    func readResource(uri: String) async throws -> MCPReadResult
}

// MARK: - MCPResourceItem

/// Represents a single resource exposed by an MCP server.
public struct MCPResourceItem: Sendable {
    public let name: String
    public let description: String?
    public let uri: String?

    public init(name: String, description: String? = nil, uri: String? = nil) {
        self.name = name
        self.description = description
        self.uri = uri
    }
}

// MARK: - MCPReadResult

/// Result of reading an MCP resource.
public struct MCPReadResult: Sendable {
    public let contents: [MCPContentItem]?

    public init(contents: [MCPContentItem]?) {
        self.contents = contents
    }
}

// MARK: - MCPContentItem

/// A single content item within an MCP resource read result.
/// Uses @unchecked Sendable because rawValue is an opaque Any payload
/// that is immutable after construction and never shared across threads.
public struct MCPContentItem: @unchecked Sendable {
    public let text: String?
    public let rawValue: Any?

    public init(text: String? = nil, rawValue: Any? = nil) {
        self.text = text
        self.rawValue = rawValue
    }
}

// MARK: - MCPConnectionInfo

/// Minimal MCP connection info for resource tools.
/// Will be replaced/enhanced by Epic 6's MCPClientManager implementation.
public struct MCPConnectionInfo: Sendable {
    public let name: String
    public let status: String  // "connected", "disconnected"
    public let resourceProvider: (any MCPResourceProvider)?

    public init(name: String, status: String, resourceProvider: (any MCPResourceProvider)? = nil) {
        self.name = name
        self.status = status
        self.resourceProvider = resourceProvider
    }
}
