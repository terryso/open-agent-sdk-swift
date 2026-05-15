import Foundation

extension TemplateGenerator {

    var safetyHooksContent: String {
        """
        import Foundation
        import OpenAgentSDK

        // MARK: - Safety Hooks Example
        //
        // Hooks intercept agent lifecycle events to enforce security policies,
        // add auditing, or modify behavior. The HookRegistry is an actor that
        // safely manages hook registration and execution.
        //
        // Hook flow: Agent → HookRegistry.execute() → matcher filter → handler
        //
        // Handler return values:
        //   nil          → allow (pass through)
        //   HookOutput   → block/approve with optional message

        // MARK: - Single Hook Registration

        /// Example: Block dangerous tools (click, type_text) outside working hours.
        /// Demonstrates register(.preToolUse) + matcher regex + HookOutput.
        func registerSafetyHooks(_ registry: HookRegistry) async {
            // Pre-tool hook — runs before each tool execution
            await registry.register(.preToolUse, definition: HookDefinition(
                // handler is called when matcher matches the tool name
                handler: { input in
                    // Inspect the tool being called
                    guard let toolName = input.toolName else { return nil }

                    // Example: block destructive operations (return HookOutput with block=true)
                    // Return nil to allow the tool call to proceed
                    print("[SafetyHook] Tool call: \\(toolName)")

                    // To block:
                    // return HookOutput(
                    //     decision: .block,
                    //     message: "Tool '\\(toolName)' is blocked by safety policy"
                    // )

                    // To allow with logging:
                    return nil
                },
                // matcher is a regex applied to toolName; nil matches all tools
                matcher: "click|type_text|delete_file"
            ))

            // Post-tool hook — runs after each tool completes successfully
            await registry.register(.postToolUse, definition: HookDefinition(
                handler: { input in
                    if let toolName = input.toolName {
                        print("[AuditHook] Tool completed: \\(toolName)")
                    }
                    return nil  // Post hooks don't block
                }
            ))

            // Post-tool failure hook — runs when a tool throws an error
            await registry.register(.postToolUseFailure, definition: HookDefinition(
                handler: { input in
                    print("[ErrorHook] Tool failed: \\(input.toolName ?? "unknown") — \\(input.error ?? "no details")")
                    return nil
                }
            ))
        }

        // MARK: - Batch Registration from Config

        /// Example: Register multiple hooks at once using registerFromConfig().
        func registerHooksFromConfig(_ registry: HookRegistry) async {
            await registry.registerFromConfig([
                "preToolUse": [
                    // Block all delete operations
                    HookDefinition(
                        handler: { input in
                            HookOutput(
                                decision: .block,
                                message: "Delete operations are not allowed"
                            )
                        },
                        matcher: ".*delete.*"
                    ),
                    // Log all MCP tool calls
                    HookDefinition(
                        handler: { input in
                            print("[MCP Audit] \\(input.toolName ?? "unknown") called")
                            return nil
                        },
                        matcher: "mcp__.*"
                    ),
                ],
                "sessionStart": [
                    HookDefinition(
                        handler: { input in
                            print("[Session] Agent session started")
                            return nil
                        }
                    )
                ],
                "sessionEnd": [
                    HookDefinition(
                        handler: { input in
                            print("[Session] Agent session ended")
                            return nil
                        }
                    )
                ],
            ])
        }

        // MARK: - Usage in main.swift
        //
        // let registry = HookRegistry()
        // await registerSafetyHooks(registry)
        // // or: await registerHooksFromConfig(registry)
        //
        // let agent = createAgent(options: AgentOptions(
        //     // ... other options
        //     hookRegistry: registry
        // ))
        """
    }
}
