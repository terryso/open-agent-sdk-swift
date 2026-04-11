import Foundation

// MARK: - ToolRestrictionStack

/// A stack-based manager for tool restrictions during skill execution.
///
/// When a skill with `toolRestrictions` is executed, its allowed tool set is pushed
/// onto the stack. The stack top determines which tools are available. When the skill
/// completes (even on error), the restriction is popped to restore the previous state.
///
/// This enables nested skill execution where each level has its own tool restriction set,
/// with LIFO (last-in, first-out) semantics ensuring correct restoration.
///
/// Thread safety is provided by an internal serial `DispatchQueue`, consistent with
/// ``SkillRegistry``'s concurrency strategy (low-frequency writes, high-frequency reads).
///
/// ```swift
/// let stack = ToolRestrictionStack()
/// stack.push([.bash, .read])      // Skill A: only bash and read
/// stack.push([.grep, .glob])      // Skill B (nested): only grep and glob
/// // currentAllowedToolNames returns only Grep and Glob tools
/// stack.pop()                      // Skill B done -> back to bash and read
/// stack.pop()                      // Skill A done -> full tool set
/// ```
public final class ToolRestrictionStack: @unchecked Sendable {

    /// Internal stack of restriction arrays. Empty = no restrictions.
    private var stack: [[ToolRestriction]] = []

    /// Serial queue for thread-safe access.
    private let queue = DispatchQueue(label: "com.openagentsdk.restrictionstack", attributes: [])

    /// Creates a new empty restriction stack.
    public init() {}

    /// Pushes a set of tool restrictions onto the stack.
    ///
    /// After this call, ``currentAllowedToolNames(baseTools:)`` will only return
    /// tools matching the pushed restriction set (the new stack top).
    ///
    /// - Parameter restrictions: The tool restrictions to push.
    public func push(_ restrictions: [ToolRestriction]) {
        queue.sync {
            stack.append(restrictions)
        }
    }

    /// Pops the top restriction set from the stack.
    ///
    /// If the stack is empty, this is a no-op (graceful handling for error-path recovery).
    /// After popping, ``currentAllowedToolNames(baseTools:)`` returns tools matching
    /// the new stack top (or all tools if the stack becomes empty).
    public func pop() {
        queue.sync {
            if !stack.isEmpty {
                stack.removeLast()
            }
        }
    }

    /// Returns the tools allowed by the current stack top.
    ///
    /// - If the stack is empty, returns all `baseTools` (no restrictions).
    /// - If the stack is non-empty, returns only the tools from `baseTools` whose names
    ///   match the raw values of the top restriction set (case-insensitive matching).
    ///
    /// - Parameter baseTools: The full set of available tools.
    /// - Returns: The filtered subset of tools allowed by the current restriction.
    public func currentAllowedToolNames(baseTools: [ToolProtocol]) -> [ToolProtocol] {
        queue.sync {
            guard let topRestrictions = stack.last else {
                return baseTools
            }

            // Build a set of lowercase restriction raw values for case-insensitive matching
            let allowedNames = Set(topRestrictions.map { $0.rawValue.lowercased() })

            return baseTools.filter { tool in
                allowedNames.contains(tool.name.lowercased())
            }
        }
    }

    /// Whether the stack is empty (no active restrictions).
    ///
    /// When `isEmpty` is `true`, all tools are available.
    public var isEmpty: Bool {
        queue.sync {
            stack.isEmpty
        }
    }

    /// Current nesting depth (number of pushed restriction layers).
    ///
    /// Used to track skill recursion depth — each push increments depth,
    /// each pop decrements it. Returns 0 when the stack is empty.
    public var nestingDepth: Int {
        queue.sync {
            stack.count
        }
    }
}
