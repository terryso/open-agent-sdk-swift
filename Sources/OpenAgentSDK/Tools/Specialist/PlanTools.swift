import Foundation

// MARK: - EnterPlanMode Input

/// Input type for the EnterPlanMode tool.
///
/// EnterPlanMode has no input fields (empty properties).
private struct EnterPlanModeInput: Codable {}

// MARK: - ExitPlanMode Input

/// Input type for the ExitPlanMode tool.
///
/// Field names match the TS SDK's ExitPlanMode schema.
private struct ExitPlanModeInput: Codable {
    let plan: String?
    let approved: Bool?
}

// MARK: - EnterPlanMode Schema

private nonisolated(unsafe) let enterPlanModeSchema: ToolInputSchema = [
    "type": "object",
    "properties": [:] as [String: Any]
]

// MARK: - ExitPlanMode Schema

private nonisolated(unsafe) let exitPlanModeSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "plan": [
            "type": "string",
            "description": "The completed plan"
        ] as [String: Any],
        "approved": [
            "type": "boolean",
            "description": "Whether the plan is approved for execution"
        ] as [String: Any],
    ] as [String: Any]
]

// MARK: - EnterPlanMode Factory Function

/// Creates the EnterPlanMode tool for entering plan/design mode.
///
/// The EnterPlanMode tool creates a new plan entry in the ``PlanStore``,
/// putting the agent into plan review mode. In plan mode, the agent focuses
/// on designing the approach before executing.
///
/// **Architecture:** This tool uses ``ToolContext/planStore`` (injected by Core/)
/// to access plan management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the EnterPlanMode tool.
public func createEnterPlanModeTool() -> ToolProtocol {
    return defineTool(
        name: "EnterPlanMode",
        description: "Enter plan/design mode for complex tasks. In plan mode, the agent focuses on designing the approach before executing.",
        inputSchema: enterPlanModeSchema,
        isReadOnly: false
    ) { (input: EnterPlanModeInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let planStore = context.planStore else {
            return ToolExecuteResult(content: "Error: PlanStore not available.", isError: true)
        }
        do {
            _ = try await planStore.enterPlanMode()
            return ToolExecuteResult(
                content: "Entered plan mode. Design your approach before executing. Use ExitPlanMode when the plan is ready.",
                isError: false
            )
        } catch let error as PlanStoreError {
            if case .alreadyInPlanMode = error {
                return ToolExecuteResult(content: "Already in plan mode.", isError: false)
            }
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        } catch {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - ExitPlanMode Factory Function

/// Creates the ExitPlanMode tool for exiting plan mode with a completed plan.
///
/// The ExitPlanMode tool finalizes the active plan with optional content and
/// an approval flag, then returns the agent to normal execution mode.
///
/// **Architecture:** This tool uses ``ToolContext/planStore`` (injected by Core/)
/// to access plan management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the ExitPlanMode tool.
public func createExitPlanModeTool() -> ToolProtocol {
    return defineTool(
        name: "ExitPlanMode",
        description: "Exit plan mode with a completed plan. The plan will be recorded and execution can proceed.",
        inputSchema: exitPlanModeSchema,
        isReadOnly: false
    ) { (input: ExitPlanModeInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let planStore = context.planStore else {
            return ToolExecuteResult(content: "Error: PlanStore not available.", isError: true)
        }
        do {
            let entry = try await planStore.exitPlanMode(plan: input.plan, approved: input.approved)
            let status = entry.approved ? "approved" : "pending approval"
            var content = "Plan mode exited. Plan status: \(status)."
            if let plan = entry.content {
                content += "\n\nPlan:\n\(plan)"
            }
            return ToolExecuteResult(content: content, isError: false)
        } catch let error as PlanStoreError {
            if case .noActivePlan = error {
                return ToolExecuteResult(content: "Not in plan mode.", isError: true)
            }
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        } catch {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}
