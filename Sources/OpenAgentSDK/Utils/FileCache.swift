import Foundation

// MARK: - CacheEntry

/// A single entry in the file cache.
///
/// Stores the file content, its byte size, and the time it was cached.
public struct CacheEntry: Sendable, Equatable {
    /// The file content as a UTF-8 string.
    public let content: String
    /// Size of the content in bytes.
    public let sizeBytes: Int
    /// Timestamp when this entry was created or updated.
    public let timestamp: Date

    public init(content: String, sizeBytes: Int, timestamp: Date = Date()) {
        self.content = content
        self.sizeBytes = sizeBytes
        self.timestamp = timestamp
    }
}

// MARK: - CacheStats

/// Statistics about cache operations.
///
/// All counters start at zero and are incremented as operations occur.
public struct CacheStats: Sendable, Equatable {
    /// Number of cache hits (get found an entry).
    public var hitCount: Int
    /// Number of cache misses (get did not find an entry).
    public var missCount: Int
    /// Number of entries evicted due to capacity limits.
    public var evictionCount: Int
    /// Number of entries skipped because they exceeded maxEntrySizeBytes.
    public var oversizedSkipCount: Int
    /// Number of disk reads performed (reserved for tool integration).
    public var diskReadCount: Int
    /// Current number of entries in the cache.
    public var totalEntries: Int
    /// Current total size of all cached entries in bytes.
    public var totalSizeBytes: Int

    public init(
        hitCount: Int = 0,
        missCount: Int = 0,
        evictionCount: Int = 0,
        oversizedSkipCount: Int = 0,
        diskReadCount: Int = 0,
        totalEntries: Int = 0,
        totalSizeBytes: Int = 0
    ) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.evictionCount = evictionCount
        self.oversizedSkipCount = oversizedSkipCount
        self.diskReadCount = diskReadCount
        self.totalEntries = totalEntries
        self.totalSizeBytes = totalSizeBytes
    }
}

// MARK: - ListNode

/// A node in the doubly-linked list used for LRU ordering.
///
/// Head contains the most recently accessed entries; tail contains the least.
private final class ListNode: @unchecked Sendable {
    let key: String
    var entry: CacheEntry
    var prev: ListNode?
    var next: ListNode?

    init(key: String, entry: CacheEntry) {
        self.key = key
        self.entry = entry
    }
}

// MARK: - FileCache

/// Thread-safe LRU cache for file contents.
///
/// Uses a `Dictionary` for O(1) lookup and a doubly-linked list for O(1) LRU
/// eviction. Thread safety is provided by an internal `NSLock` (not an actor)
/// because the cache is shared across multiple tool instances and needs low-latency
/// synchronous access.
///
/// ## Configuration
///
/// - `maxEntries`: Maximum number of entries (default 100).
/// - `maxSizeBytes`: Maximum total size of all cached entries (default 25 MB).
/// - `maxEntrySizeBytes`: Maximum size of a single entry (default 5 MB).
///   Entries exceeding this limit are silently skipped.
///
/// ## Path Normalization
///
/// All paths are normalized before cache lookup:
/// - `..` and `.` segments are resolved.
/// - Redundant slashes are collapsed.
/// - Symlinks are resolved via `URL.resolvingSymlinksInPath()`.
/// - On macOS, paths are compared case-insensitively via
///   `FileManager.fileSystemRepresentation`.
public final class FileCache: @unchecked Sendable {

    /// Maximum number of entries allowed in the cache.
    public let maxEntries: Int

    /// Maximum total size of all cached entries in bytes.
    public let maxSizeBytes: Int

    /// Maximum size of a single cache entry in bytes.
    /// Entries exceeding this limit are not cached.
    public let maxEntrySizeBytes: Int

    // Internal storage
    private let lock = NSLock()
    private var map: [String: ListNode] = [:]
    private var head: ListNode?   // most recently accessed
    private var tail: ListNode?   // least recently accessed
    private var _stats = CacheStats()

    /// Current cache statistics.
    public var stats: CacheStats {
        lock.lock()
        defer { lock.unlock() }
        return _stats
    }

    // MARK: - Initialization

    /// Create a FileCache with default configuration.
    ///
    /// Defaults: maxEntries=100, maxSizeBytes=25MB, maxEntrySizeBytes=5MB.
    public convenience init() {
        self.init(
            maxEntries: 100,
            maxSizeBytes: 25 * 1024 * 1024,
            maxEntrySizeBytes: 5 * 1024 * 1024
        )
    }

    /// Create a FileCache with custom configuration.
    ///
    /// - Parameters:
    ///   - maxEntries: Maximum number of cached entries.
    ///   - maxSizeBytes: Maximum total size of all cached entries in bytes.
    ///   - maxEntrySizeBytes: Maximum size of a single entry in bytes.
    public init(
        maxEntries: Int,
        maxSizeBytes: Int,
        maxEntrySizeBytes: Int
    ) {
        self.maxEntries = maxEntries
        self.maxSizeBytes = maxSizeBytes
        self.maxEntrySizeBytes = maxEntrySizeBytes
    }

    // MARK: - Public API

    /// Get cached content for a path.
    ///
    /// Normalizes the path, looks up the entry, and moves it to the head
    /// of the LRU list if found.
    ///
    /// - Parameter path: The file path to look up.
    /// - Returns: The cached content, or `nil` if not found.
    @discardableResult
    public func get(_ path: String) -> String? {
        let normalized = normalizePath(path)
        lock.lock()
        defer { lock.unlock() }

        guard let node = map[normalized] else {
            _stats.missCount += 1
            return nil
        }
        _stats.hitCount += 1
        moveToHead(node)
        return node.entry.content
    }

    /// Store content in the cache for a path.
    ///
    /// Normalizes the path, checks size limits, performs eviction if necessary,
    /// and inserts or updates the entry at the head of the LRU list.
    ///
    /// - Parameters:
    ///   - path: The file path to cache.
    ///   - content: The file content to cache.
    public func set(_ path: String, content: String) {
        let normalized = normalizePath(path)
        let sizeBytes = content.utf8.count

        lock.lock()
        defer { lock.unlock() }

        // Check single-entry size limit
        guard sizeBytes <= maxEntrySizeBytes else {
            _stats.oversizedSkipCount += 1
            return
        }

        // If updating an existing entry, remove old size contribution
        if let existingNode = map[normalized] {
            _stats.totalSizeBytes -= existingNode.entry.sizeBytes
            existingNode.entry = CacheEntry(content: content, sizeBytes: sizeBytes)
            _stats.totalSizeBytes += sizeBytes
            moveToHead(existingNode)
            // After updating, may need to evict if total exceeds maxSizeBytes
            evictIfNeeded()
            return
        }

        // New entry: evict first to make room
        let newNode = ListNode(key: normalized, entry: CacheEntry(content: content, sizeBytes: sizeBytes))
        map[normalized] = newNode
        _stats.totalSizeBytes += sizeBytes
        _stats.totalEntries += 1
        insertAtHead(newNode)
        evictIfNeeded()
    }

    /// Remove a specific path from the cache.
    ///
    /// - Parameter path: The file path to invalidate.
    public func invalidate(_ path: String) {
        let normalized = normalizePath(path)
        lock.lock()
        defer { lock.unlock() }

        guard let node = map[normalized] else {
            return
        }
        removeNode(node)
        map.removeValue(forKey: normalized)
        _stats.totalSizeBytes -= node.entry.sizeBytes
        _stats.totalEntries -= 1
    }

    /// Remove all entries from the cache.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        map.removeAll()
        head = nil
        tail = nil
        _stats.totalEntries = 0
        _stats.totalSizeBytes = 0
    }

    // MARK: - Path Normalization

    /// Normalize a file path for cache key comparison.
    ///
    /// Resolves `.`, `..`, redundant slashes, and symlinks.
    /// On macOS, handles case-insensitive file systems.
    /// Falls back gracefully if symlink resolution fails.
    private func normalizePath(_ path: String) -> String {
        // Step 1: Standardize path (resolve ., .., redundant slashes)
        let standardized = (path as NSString).standardizingPath

        // Step 2: Resolve symlinks
        let url = URL(fileURLWithPath: standardized)
        let resolved: String
        #if os(macOS)
        // On macOS, use fileSystemRepresentation for case-insensitive normalization
        // then resolve symlinks
        let fsRep = FileManager.default.fileSystemRepresentation(withPath: standardized)
        let nsPath = String(cString: fsRep)
        let resolvedUrl = URL(fileURLWithPath: nsPath).resolvingSymlinksInPath()
        resolved = resolvedUrl.path
        #else
        // On Linux, resolve symlinks using URL API
        let resolvedUrl = url.resolvingSymlinksInPath()
        resolved = resolvedUrl.path
        #endif

        // Step 3: If resolved path is empty (broken symlink), use standardized path.
        if resolved.isEmpty {
            return standardized
        }
        return resolved
    }

    // MARK: - Doubly-Linked List Operations

    /// Insert a node at the head of the list (most recently accessed).
    private func insertAtHead(_ node: ListNode) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    /// Remove a node from the linked list.
    private func removeNode(_ node: ListNode) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if node === head {
            head = node.next
        }
        if node === tail {
            tail = node.prev
        }
        node.prev = nil
        node.next = nil
    }

    /// Move an existing node to the head of the list.
    private func moveToHead(_ node: ListNode) {
        guard node !== head else { return }
        removeNode(node)
        insertAtHead(node)
    }

    /// Evict entries from the tail until capacity constraints are satisfied.
    private func evictIfNeeded() {
        // Evict while entry count exceeds max OR total size exceeds max
        while _stats.totalEntries > maxEntries || _stats.totalSizeBytes > maxSizeBytes {
            guard let tailNode = tail else { break }
            removeNode(tailNode)
            map.removeValue(forKey: tailNode.key)
            _stats.totalSizeBytes -= tailNode.entry.sizeBytes
            _stats.totalEntries -= 1
            _stats.evictionCount += 1
        }
    }
}
