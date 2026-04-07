import Foundation

/// Thread-safe todo store using actor isolation.
///
/// Manages todo item lifecycle: adding, toggling, removing, listing, and clearing items.
/// All operations are actor-isolated for concurrent access safety.
public actor TodoStore {

    // MARK: - Properties

    private var items: [Int: TodoItem] = [:]
    private var counter: Int = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Add a new todo item.
    ///
    /// Creates a new ``TodoItem`` with auto-generated ID, `done` set to `false`,
    /// and the given text and optional priority.
    ///
    /// - Parameters:
    ///   - text: The text description of the todo item.
    ///   - priority: Optional priority level (high, medium, low).
    /// - Returns: The newly created ``TodoItem``.
    public func add(text: String, priority: TodoPriority? = nil) -> TodoItem {
        counter += 1
        let item = TodoItem(id: counter, text: text, done: false, priority: priority)
        items[counter] = item
        return item
    }

    /// Toggle the done status of a todo item.
    ///
    /// Flips the `done` flag on the item with the given ID.
    ///
    /// - Parameter id: The ID of the todo item to toggle.
    /// - Returns: The updated ``TodoItem`` with flipped `done` status.
    /// - Throws: ``TodoStoreError/todoNotFound(id:)`` if the item does not exist.
    @discardableResult
    public func toggle(id: Int) throws -> TodoItem {
        guard let item = items[id] else {
            throw TodoStoreError.todoNotFound(id: id)
        }
        let toggled = TodoItem(id: item.id, text: item.text, done: !item.done, priority: item.priority)
        items[id] = toggled
        return toggled
    }

    /// Remove a todo item by ID.
    ///
    /// Removes the todo item with the given ID from the store.
    ///
    /// - Parameter id: The ID of the todo item to remove.
    /// - Returns: The removed ``TodoItem``.
    /// - Throws: ``TodoStoreError/todoNotFound(id:)`` if the item does not exist.
    @discardableResult
    public func remove(id: Int) throws -> TodoItem {
        guard let item = items.removeValue(forKey: id) else {
            throw TodoStoreError.todoNotFound(id: id)
        }
        return item
    }

    /// Get a todo item by ID.
    ///
    /// - Parameter id: The todo item ID to look up.
    /// - Returns: The ``TodoItem`` if found, or `nil`.
    public func get(id: Int) -> TodoItem? {
        items[id]
    }

    /// List all stored todo items sorted by ID.
    ///
    /// - Returns: An array of all ``TodoItem`` instances sorted by ID.
    public func list() -> [TodoItem] {
        Array(items.values).sorted { $0.id < $1.id }
    }

    /// Clear all stored todo items and reset the ID counter.
    public func clear() {
        items.removeAll()
        counter = 0
    }
}
