import Foundation

// MARK: - Private Error

private enum HookExecutionError: Error {
    case timeout
}

// MARK: - HookRegistry Actor

/// Thread-safe registry for managing hook handlers across Agent lifecycle events.
///
/// `HookRegistry` is an `actor` that maintains a mapping of `[HookEvent: [HookDefinition]]`,
/// ensuring all registration and execution operations are performed with Actor isolation
/// for thread safety (FR28, FR48).
///
/// Usage:
/// ```swift
/// let registry = HookRegistry()
/// await registry.register(.preToolUse, definition: HookDefinition(handler: { input in
///     return HookOutput(block: true, message: "Blocked")
/// }))
/// let results = await registry.execute(.preToolUse, input: hookInput)
/// ```
public actor HookRegistry {

    // MARK: - Properties

    /// Internal mapping of events to registered hook definitions.
    private var hooks: [HookEvent: [HookDefinition]] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Registration

    /// Registers a hook definition for a specific lifecycle event.
    ///
    /// Hooks are appended to the event's definition array, preserving registration order.
    ///
    /// - Parameters:
    ///   - event: The lifecycle event to register the hook on.
    ///   - definition: The hook definition containing handler, matcher, and timeout.
    public func register(_ event: HookEvent, definition: HookDefinition) {
        hooks[event, default: []].append(definition)
    }

    /// Registers hooks from a configuration dictionary.
    ///
    /// Iterates over the config dictionary, registering hooks for valid event names.
    /// Invalid event names (keys that don't match any `HookEvent` rawValue) are silently skipped.
    ///
    /// - Parameter config: A dictionary mapping event name strings to arrays of hook definitions.
    public func registerFromConfig(_ config: [String: [HookDefinition]]) {
        for (eventString, definitions) in config {
            guard let event = HookEvent(rawValue: eventString) else { continue }
            hooks[event, default: []].append(contentsOf: definitions)
        }
    }

    // MARK: - Execution

    /// Executes all registered hooks for the given event, filtered by matcher.
    ///
    /// Hooks are executed sequentially in registration order. Each hook's `matcher` regex
    /// is checked against `input.toolName` — if the matcher is non-nil and the tool name
    /// doesn't match, the hook is skipped.
    ///
    /// Timeout handling: If a hook's `timeout` (in milliseconds) is exceeded, the hook is
    /// cancelled and returns no result. Other hooks continue executing unaffected.
    ///
    /// Individual hook failures are caught and do not interrupt execution of subsequent hooks.
    ///
    /// - Parameters:
    ///   - event: The lifecycle event to execute hooks for.
    ///   - input: The input data provided to each hook handler.
    /// - Returns: An array of non-nil `HookOutput` results from executed hooks.
    public func execute(_ event: HookEvent, input: HookInput) async -> [HookOutput] {
        guard let definitions = hooks[event] else { return [] }
        var results: [HookOutput] = []

        for def in definitions {
            // Matcher filtering: skip if matcher doesn't match toolName
            if let matcher = def.matcher {
                if let toolName = input.toolName {
                    do {
                        let regex = try Regex(matcher)
                        if !toolName.contains(regex) { continue }
                    } catch {
                        // Invalid regex pattern — skip this hook
                        continue
                    }
                } else {
                    // matcher is set but toolName is nil — skip
                    continue
                }
            }

            // Execute handler if present (command execution deferred to Story 8-3)
            guard let handler = def.handler else { continue }

            do {
                let timeoutMs = def.timeout ?? 30_000
                let timeoutNanos = UInt64(clamping: Int64(timeoutMs) * 1_000_000)
                let output = try await withThrowingTaskGroup(of: HookOutput?.self) { group in
                    group.addTask {
                        await handler(input)
                    }
                    group.addTask {
                        try await _Concurrency.Task.sleep(nanoseconds: timeoutNanos)
                        throw HookExecutionError.timeout
                    }

                    guard let first = try await group.next() else {
                        group.cancelAll()
                        return nil as HookOutput?
                    }
                    group.cancelAll()
                    return first
                }
                if let output { results.append(output) }
            } catch {
                // Hook failed (including timeout) — log and continue
                // Matches TS SDK behavior: errors are caught, not propagated
            }
        }

        return results
    }

    // MARK: - Query & Management

    /// Returns whether the given event has any registered hooks.
    ///
    /// - Parameter event: The lifecycle event to check.
    /// - Returns: `true` if at least one hook is registered for the event.
    public func hasHooks(_ event: HookEvent) -> Bool {
        (hooks[event]?.count ?? 0) > 0
    }

    /// Removes all registered hooks for all events.
    public func clear() {
        hooks.removeAll()
    }
}

// MARK: - Factory Function

/// Create a hook registry with optional configuration.
///
/// This is a convenience factory function aligned with the TypeScript SDK's
/// `createHookRegistry()` API. When a config dictionary is provided, hooks
/// are registered for all valid event name keys.
///
/// - Parameter config: Optional dictionary mapping event name strings to arrays
///   of hook definitions. Invalid event names are silently skipped.
/// - Returns: A configured `HookRegistry` instance.
public func createHookRegistry(config: [String: [HookDefinition]]? = nil) async -> HookRegistry {
    let registry = HookRegistry()
    if let config {
        await registry.registerFromConfig(config)
    }
    return registry
}
