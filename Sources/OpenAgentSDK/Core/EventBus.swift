import Foundation

// MARK: - EventBus

/// In-process event bus for broadcasting runtime events to multiple subscribers.
///
/// Uses `AsyncStream` with `.bufferingNewest(100)` to prevent slow consumers
/// from blocking publishers. Supports both full-stream and type-filtered subscriptions.
public actor EventBus {

    /// Internal subscriber entry holding the continuation and optional filter task.
    private struct Subscriber {
        let continuation: AsyncStream<any AgentEvent>.Continuation
        var filterTask: _Concurrency.Task<Void, Never>?
    }

    private var subscribers: [UUID: Subscriber] = [:]

    public init() {}

    /// Subscribe to all events.
    ///
    /// Returns a tuple of the subscriber ID (for explicit unsubscription) and
    /// an ``AsyncStream`` that delivers every published event.
    public func subscribe() -> (id: UUID, stream: AsyncStream<any AgentEvent>) {
        let id = UUID()
        let stream = AsyncStream<any AgentEvent>(bufferingPolicy: .bufferingNewest(100)) { continuation in
            subscribers[id] = Subscriber(continuation: continuation, filterTask: nil)
            continuation.onTermination = { [weak self] _ in
                _Concurrency.Task { await self?.removeSubscriber(id: id) }
            }
        }
        return (id, stream)
    }

    /// Subscribe to events of a specific type.
    ///
    /// Internally creates a full-stream subscription and filters events using a
    /// background ``Task``. When the returned stream's continuation terminates,
    /// both the filter task and the internal subscriber are cleaned up.
    public func subscribe<T: AgentEvent>(_ type: T.Type) -> AsyncStream<T> {
        let id = UUID()
        return AsyncStream<T>(bufferingPolicy: .bufferingNewest(100)) { outerContinuation in
            // Create the internal full-stream subscriber synchronously within
            // the actor by building the AsyncStream manually.
            let innerStream = AsyncStream<any AgentEvent>(bufferingPolicy: .bufferingNewest(100)) { innerContinuation in
                subscribers[id] = Subscriber(continuation: innerContinuation, filterTask: nil)
            }

            let filterTask = _Concurrency.Task {
                for await event in innerStream {
                    if let typed = event as? T {
                        outerContinuation.yield(typed)
                    }
                }
            }

            // Store the filter task for later cleanup.
            subscribers[id]?.filterTask = filterTask

            outerContinuation.onTermination = { [weak self] _ in
                filterTask.cancel()
                _Concurrency.Task { await self?.removeSubscriber(id: id) }
            }
        }
    }

    /// Publish an event to all current subscribers.
    ///
    /// If no subscribers are registered the event is silently discarded.
    public func publish(_ event: any AgentEvent) {
        for (_, subscriber) in subscribers {
            subscriber.continuation.yield(event)
        }
    }

    /// Explicitly unsubscribe by ID.
    ///
    /// Cancels any associated filter task and removes the subscriber entry.
    public func unsubscribe(_ id: UUID) {
        removeSubscriber(id: id)
    }

    // MARK: - Private

    private func removeSubscriber(id: UUID) {
        subscribers[id]?.filterTask?.cancel()
        subscribers[id]?.continuation.finish()
        subscribers.removeValue(forKey: id)
    }
}
