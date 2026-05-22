import Foundation
import os

// MARK: - RunRecoveryService

/// Recovers persisted run state on server restart.
/// Marks interrupted runs as failed and preserves intervention_needed runs.
public enum RunRecoveryService {

    private static let logger = os.Logger(subsystem: "com.open-agent-sdk", category: "Recovery")

    /// Recover all persisted runs from disk into the tracker.
    public static func recover(
        from tracker: RunTracker,
        persistenceService: RunPersistenceService,
        eventBroadcaster: EventBroadcaster
    ) async {
        let persistedRuns = persistenceService.loadAllPersistedRuns()
        guard !persistedRuns.isEmpty else { return }

        logger.info("Found \(persistedRuns.count) persisted run(s), recovering...")

        for var run in persistedRuns {
            switch run.status {
            // Active states → mark as failed
            case .running, .queued:
                let originalStatus = run.status.rawValue
                run.status = .failed
                run.error = "server interrupted"
                run.updatedAt = {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter.string(from: Date())
                }()
                persistenceService.persistRecordSafely(run)
                logger.info("Run \(run.runId): \(originalStatus) → failed")

            // Terminal states → preserve
            case .completed, .failed, .cancelled:
                logger.debug("Run \(run.runId): \(run.status.rawValue) — preserved")

            // intervention_needed → preserve
            case .interventionNeeded:
                logger.debug("Run \(run.runId): intervention_needed — preserved")

            // user_takeover / resuming → preserve
            case .userTakeover, .resuming:
                logger.debug("Run \(run.runId): \(run.status.rawValue) — preserved")
            }

            await tracker.restoreRun(run)

            // Restore SSE history events to replay buffer
            let events = persistenceService.loadEvents(runId: run.runId)
            if !events.isEmpty {
                await eventBroadcaster.restoreReplayBuffer(runId: run.runId, events: events)
            }
        }

        logger.info("Recovery complete.")
    }
}
