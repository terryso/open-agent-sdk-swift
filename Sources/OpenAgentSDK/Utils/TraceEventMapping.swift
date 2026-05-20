import Foundation

/// Maps ``SDKMessage`` variants to trace event tuples for ``TraceRecorder``.
///
/// Pure functions with no state — the agent loop calls ``traceEvent(from:stepIndex:)``
/// for each yielded SDKMessage and writes the result (if non-nil) to the recorder.
public enum TraceEventMapping {
    /// Map an SDKMessage to a trace event name and payload.
    ///
    /// Mapping:
    /// - `.toolUse` → `("step_start", ["tool": name, "toolUseId": id])`
    /// - `.toolResult` → `("step_done", ["tool": content-preview, "success": !isError, "toolUseId": id])`
    /// - `.result` → `("run_done", ["status": subtype, "durationMs": ms])`
    /// - `.assistant` → `nil` (accumulated internally, not a trace event)
    ///
    /// All other cases return `nil` — they are not useful for traces.
    public static func traceEvent(from message: SDKMessage, stepIndex: Int? = nil) -> (event: String, payload: [String: Any])? {
        switch message {
        case .toolUse(let data):
            var payload: [String: Any] = [
                "tool": data.toolName,
                "toolUseId": data.toolUseId
            ]
            if let idx = stepIndex { payload["index"] = idx }
            return ("step_start", payload)

        case .toolResult(let data):
            var payload: [String: Any] = [
                "success": !data.isError,
                "toolUseId": data.toolUseId
            ]
            if let idx = stepIndex { payload["index"] = idx }
            return ("step_done", payload)

        case .result(let data):
            return ("run_done", [
                "status": data.subtype.rawValue,
                "totalSteps": data.numTurns,
                "durationMs": data.durationMs,
                "totalCostUsd": data.totalCostUsd
            ])

        default:
            return nil
        }
    }
}
