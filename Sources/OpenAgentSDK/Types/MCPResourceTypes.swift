import Foundation

// MARK: - MCPResourceProvider Protocol

/// Protocol for MCP resource operations.
///
/// Implemented by MCP connections that support resource listing and reading.
/// Used by MCP resource tools to access server-provided resources.
public protocol MCPResourceProvider: Sendable {
    /// List available resources from the MCP server.
    ///
    /// - Returns: An array of available resources, or `nil` if the server
    ///   does not support resource listing.
    func listResources() async -> [MCPResourceItem]?

    /// Read a specific resource by URI from the MCP server.
    ///
    /// - Parameter uri: The URI of the resource to read.
    /// - Returns: The resource content.
    func readResource(uri: String) async throws -> MCPReadResult
}

// MARK: - MCPResourceItem

/// Represents a single resource exposed by an MCP server.
public struct MCPResourceItem: Sendable {
    /// The resource name.
    public let name: String
    /// An optional description of the resource.
    public let description: String?
    /// The URI for accessing the resource.
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
    /// The content items returned by the resource read operation.
    public let contents: [MCPContentItem]?

    public init(contents: [MCPContentItem]?) {
        self.contents = contents
    }
}

// MARK: - MCPContentItem

/// A single content item within an MCP resource read result.
///
/// - Note: Uses `@unchecked Sendable` because `rawValue` is an opaque `Any?` payload
///   that is immutable after construction.
public struct MCPContentItem: @unchecked Sendable {
    /// The text content of the item, if available.
    public let text: String?
    /// The raw value of the content item.
    public let rawValue: Any?

    public init(text: String? = nil, rawValue: Any? = nil) {
        self.text = text
        self.rawValue = rawValue
    }
}

// MARK: - MCPConnectionInfo

/// Minimal MCP connection info for resource tools.
///
/// Contains connection metadata and an optional resource provider for
/// accessing server resources.
public struct MCPConnectionInfo: Sendable {
    /// The connection name.
    public let name: String
    /// The connection status string (e.g., "connected", "disconnected").
    public let status: String
    /// The resource provider for this connection, if available.
    public let resourceProvider: (any MCPResourceProvider)?

    public init(name: String, status: String, resourceProvider: (any MCPResourceProvider)? = nil) {
        self.name = name
        self.status = status
        self.resourceProvider = resourceProvider
    }
}
