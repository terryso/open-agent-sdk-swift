import XCTest
@testable import OpenAgentSDK

// MARK: - TodoStore Tests

/// ATDD RED PHASE: Tests for Story 5.4 -- TodoStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `TodoItem` struct is defined with id, text, done, priority fields
///   - `TodoPriority` enum is defined with high, medium, low cases
///   - `TodoStoreError` enum is defined with todoNotFound(id) case
///   - `TodoStore` actor is defined with add, toggle, remove, get, list, clear methods
/// TDD Phase: RED (feature not implemented yet)
final class TodoStoreTests: XCTestCase {

    // MARK: - AC1: TodoStore Actor -- add

    /// AC1 [P0]: Adding a todo item returns a TodoItem with correct field values.
    func testAdd_returnsItemWithCorrectFields() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When: adding a todo item
        let item = await store.add(text: "Buy groceries")

        // Then: the returned item has the expected field values
        XCTAssertEqual(item.id, 1)
        XCTAssertEqual(item.text, "Buy groceries")
        XCTAssertFalse(item.done)
        XCTAssertNil(item.priority)
    }

    /// AC1 [P0]: Adding todo items auto-generates sequential integer IDs (1, 2, 3, ...).
    func testAdd_autoGeneratesSequentialIds() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When: adding multiple todo items
        let item1 = await store.add(text: "first")
        let item2 = await store.add(text: "second")
        let item3 = await store.add(text: "third")

        // Then: IDs are auto-generated in sequence
        XCTAssertEqual(item1.id, 1)
        XCTAssertEqual(item2.id, 2)
        XCTAssertEqual(item3.id, 3)
    }

    /// AC1 [P0]: Default done value for a new todo item is false.
    func testAdd_defaultDoneIsFalse() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When: adding a todo item
        let item = await store.add(text: "test")

        // Then: done is false by default
        XCTAssertFalse(item.done)
    }

    /// AC1 [P0]: Adding a todo item does not throw (pure append operation).
    func testAdd_doesNotThrow() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When/Then: adding a todo item does not throw
        let item = await store.add(text: "safe item")
        XCTAssertEqual(item.text, "safe item")
    }

    /// AC1 [P0]: Adding a todo item with priority stores the priority.
    func testAdd_withPriority_storesPriority() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When: adding a todo item with high priority
        let item = await store.add(text: "urgent task", priority: .high)

        // Then: priority is stored correctly
        XCTAssertEqual(item.priority, .high)
        XCTAssertEqual(item.text, "urgent task")
    }

    /// AC1 [P0]: Adding a todo item with medium priority stores the priority.
    func testAdd_withMediumPriority_storesPriority() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When: adding a todo item with medium priority
        let item = await store.add(text: "medium task", priority: .medium)

        // Then: priority is stored correctly
        XCTAssertEqual(item.priority, .medium)
    }

    /// AC1 [P0]: Adding a todo item with low priority stores the priority.
    func testAdd_withLowPriority_storesPriority() async throws {
        // Given: a fresh TodoStore
        let store = TodoStore()

        // When: adding a todo item with low priority
        let item = await store.add(text: "low task", priority: .low)

        // Then: priority is stored correctly
        XCTAssertEqual(item.priority, .low)
    }

    // MARK: - AC1: TodoStore Actor -- toggle

    /// AC1 [P0]: Toggling an existing todo item flips done from false to true.
    func testToggle_existingId_flipsDoneToTrue() async throws {
        // Given: a TodoStore with a todo item
        let store = TodoStore()
        _ = await store.add(text: "toggle me")

        // When: toggling the item
        let toggled = try await store.toggle(id: 1)

        // Then: done is now true
        XCTAssertTrue(toggled.done)
        XCTAssertEqual(toggled.id, 1)
        XCTAssertEqual(toggled.text, "toggle me")
    }

    /// AC1 [P0]: Toggling a completed todo item flips done back to false.
    func testToggle_completedItem_flipsDoneBackToFalse() async throws {
        // Given: a TodoStore with a completed todo item
        let store = TodoStore()
        _ = await store.add(text: "already done")
        _ = try await store.toggle(id: 1)

        // When: toggling again
        let toggled = try await store.toggle(id: 1)

        // Then: done is now false again
        XCTAssertFalse(toggled.done)
    }

    /// AC1 [P0]: Toggling a non-existent todo item throws todoNotFound.
    func testToggle_nonexistentId_throwsTodoNotFound() async {
        // Given: a TodoStore
        let store = TodoStore()

        // When/Then: toggling a non-existent item throws todoNotFound
        do {
            _ = try await store.toggle(id: 999)
            XCTFail("Should have thrown todoNotFound error")
        } catch let error as TodoStoreError {
            if case .todoNotFound(let id) = error {
                XCTAssertEqual(id, 999)
            } else {
                XCTFail("Expected todoNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC1: TodoStore Actor -- remove

    /// AC1 [P0]: Removing an existing todo item succeeds and returns the removed item.
    func testRemove_existingId_succeeds() async throws {
        // Given: a TodoStore with a todo item
        let store = TodoStore()
        _ = await store.add(text: "remove me")

        // When: removing the item
        let removed = try await store.remove(id: 1)

        // Then: the item is returned and no longer in store
        XCTAssertEqual(removed.id, 1)
        XCTAssertEqual(removed.text, "remove me")
        let found = await store.get(id: 1)
        XCTAssertNil(found)
    }

    /// AC1 [P0]: Removing a non-existent todo item throws todoNotFound.
    func testRemove_nonexistentId_throwsTodoNotFound() async {
        // Given: a TodoStore
        let store = TodoStore()

        // When/Then: removing a non-existent item throws todoNotFound
        do {
            _ = try await store.remove(id: 999)
            XCTFail("Should have thrown todoNotFound error")
        } catch let error as TodoStoreError {
            if case .todoNotFound(let id) = error {
                XCTAssertEqual(id, 999)
            } else {
                XCTFail("Expected todoNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC13: TodoStore Actor -- get

    /// AC13 [P0]: Getting an existing todo item by ID returns the item.
    func testGet_existingId_returnsItem() async throws {
        // Given: a TodoStore with a todo item
        let store = TodoStore()
        _ = await store.add(text: "find me")

        // When: getting the item by ID
        let found = await store.get(id: 1)

        // Then: the item is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, 1)
        XCTAssertEqual(found?.text, "find me")
    }

    /// AC13 [P0]: Getting a non-existent todo item by ID returns nil.
    func testGet_nonexistentId_returnsNil() async {
        // Given: a TodoStore
        let store = TodoStore()

        // When: getting an item that does not exist
        let found = await store.get(id: 999)

        // Then: nil is returned
        XCTAssertNil(found)
    }

    // MARK: - AC13: TodoStore Actor -- list

    /// AC13 [P1]: Listing todo items returns all added items sorted by id.
    func testList_returnsAllItems() async throws {
        // Given: a TodoStore with 3 todo items
        let store = TodoStore()

        _ = await store.add(text: "item-a")
        _ = await store.add(text: "item-b")
        _ = await store.add(text: "item-c")

        // When: listing all items
        let items = await store.list()

        // Then: all 3 items are returned sorted by id
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].text, "item-a")
        XCTAssertEqual(items[1].text, "item-b")
        XCTAssertEqual(items[2].text, "item-c")
    }

    /// AC13 [P1]: Listing from an empty store returns an empty array.
    func testList_emptyStore_returnsEmpty() async {
        // Given: a fresh empty TodoStore
        let store = TodoStore()

        // When: listing items
        let items = await store.list()

        // Then: result is empty
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - AC13: TodoStore Actor -- clear

    /// AC13 [P1]: Clearing the store resets all items and the counter.
    func testClear_resetsStore() async throws {
        // Given: a TodoStore with items
        let store = TodoStore()

        _ = await store.add(text: "first")
        _ = await store.add(text: "second")

        // When: clearing the store
        await store.clear()

        // Then: store is empty and counter is reset
        let items = await store.list()
        XCTAssertTrue(items.isEmpty)

        // Counter reset means next item gets id 1 again
        let newItem = await store.add(text: "after-clear")
        XCTAssertEqual(newItem.id, 1)
    }

    // MARK: - AC1: TodoStore Actor -- Thread Safety

    /// AC1 [P0]: Concurrent access to TodoStore does not crash (actor isolation).
    func testTodoStore_concurrentAccess() async throws {
        // Given: a TodoStore
        let store = TodoStore()

        // When: adding items concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...20 {
                group.addTask {
                    _ = await store.add(text: "concurrent-\(i)")
                }
            }
        }

        // Then: all 20 items were created without crash
        let items = await store.list()
        XCTAssertEqual(items.count, 20)
    }

    // MARK: - Types: TodoItem

    /// AC1 [P0]: TodoItem is Equatable.
    func testTodoItem_equality() {
        let item1 = TodoItem(id: 1, text: "test", done: false, priority: .high)
        let item2 = TodoItem(id: 1, text: "test", done: false, priority: .high)
        XCTAssertEqual(item1, item2)
    }

    /// AC1 [P0]: TodoItem is Codable (round-trip encode/decode).
    func testTodoItem_codable() throws {
        let item = TodoItem(id: 1, text: "test item", done: false, priority: .medium)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    /// AC1 [P0]: TodoItem with nil priority is Codable (round-trip).
    func testTodoItem_codable_withNilPriority() throws {
        let item = TodoItem(id: 2, text: "no priority", done: true)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)
        XCTAssertEqual(decoded, item)
        XCTAssertNil(decoded.priority)
    }

    // MARK: - Types: TodoPriority

    /// AC1 [P0]: TodoPriority has exactly high, medium, low cases.
    func testTodoPriority_allCases() {
        let allCases = TodoPriority.allCases
        XCTAssertEqual(allCases, [.high, .medium, .low])
    }

    /// AC1 [P0]: TodoPriority raw values match expected strings.
    func testTodoPriority_rawValues() {
        XCTAssertEqual(TodoPriority.high.rawValue, "high")
        XCTAssertEqual(TodoPriority.medium.rawValue, "medium")
        XCTAssertEqual(TodoPriority.low.rawValue, "low")
    }

    // MARK: - Types: TodoStoreError

    /// AC1 [P0]: TodoStoreError is Equatable.
    func testTodoStoreError_equality() {
        let error1 = TodoStoreError.todoNotFound(id: 1)
        let error2 = TodoStoreError.todoNotFound(id: 1)
        let error3 = TodoStoreError.todoNotFound(id: 2)

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    /// AC1 [P0]: TodoStoreError.todoNotFound has correct error description.
    func testTodoStoreError_todoNotFound_description() {
        let error = TodoStoreError.todoNotFound(id: 42)
        XCTAssertTrue(error.localizedDescription.contains("42"))
    }
}
