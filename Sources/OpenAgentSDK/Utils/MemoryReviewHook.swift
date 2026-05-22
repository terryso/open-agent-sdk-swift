import Foundation

/// Reference wrapper for mutable interval-tracking state shared with a `@Sendable` closure.
private final class IntervalTracker: @unchecked Sendable {
    var lastReviewByDomain: [String: Date] = [:]
}

/// Hook that automatically extracts experience from conversations at session end.
///
/// Registers on the `.sessionEnd` hook event. When the agent completes a query,
/// the hook fetches messages, checks thresholds, runs extraction, saves facts,
/// and returns a human-readable summary.
///
/// Error handling is non-blocking: extraction failures are logged but do not
/// crash the agent or block the hook chain.
public struct MemoryReviewHook: Sendable {

    /// The extractor used to analyze conversations.
    public let extractor: any ExperienceExtractor

    /// The store where extracted facts are persisted.
    public let factStore: FactStore

    /// Configuration for this hook.
    public let config: MemoryReviewConfig

    /// Closure providing the agent's current message history.
    public let messageProvider: MessageHistoryProvider

    public init(
        extractor: any ExperienceExtractor,
        factStore: FactStore,
        config: MemoryReviewConfig,
        messageProvider: @escaping MessageHistoryProvider
    ) {
        self.extractor = extractor
        self.factStore = factStore
        self.config = config
        self.messageProvider = messageProvider
    }

    /// Creates a hook handler closure suitable for registration with `HookRegistry`.
    ///
    /// The returned closure captures state for interval tracking and is safe to
    /// register on `.sessionEnd`.
    public func makeHandler() -> @Sendable (HookInput) async -> HookOutput? {
        let tracker = IntervalTracker()

        return { [extractor, factStore, config, messageProvider] _ in
            guard config.enabled else { return nil }

            let messages = await messageProvider()

            guard messages.count >= config.minMessagesForReview else { return nil }

            let result: ExtractionResult
            do {
                result = try await extractor.extract(from: messages, config: config.extractionConfig)
            } catch {
                Logger.shared.warn("MemoryReviewHook", "extraction_failed", data: [
                    "error": error.localizedDescription,
                ])
                return nil
            }

            guard !result.signals.isEmpty else {
                return HookOutput(additionalContext: "Memory review: no extractable experience found in this session.")
            }

            // Save facts grouped by domain
            var savedDomains = Set<String>()
            var totalSaved = 0
            var domainFiltered = 0
            for signal in result.signals {
                let domain = signal.domain

                // Domain filter: skip signals not in the allowed set
                if let allowedDomains = config.domains, !allowedDomains.contains(domain) {
                    domainFiltered += 1
                    continue
                }

                let fact = signal.toFact()

                // Interval check per domain
                if let interval = config.reviewInterval {
                    if let lastReview = tracker.lastReviewByDomain[domain] {
                        guard Date().timeIntervalSince(lastReview) >= interval else {
                            continue
                        }
                    }
                }

                do {
                    try await factStore.save(domain: domain, fact: fact)
                    savedDomains.insert(domain)
                    totalSaved += 1
                    tracker.lastReviewByDomain[domain] = Date()
                } catch {
                    Logger.shared.warn("MemoryReviewHook", "fact_save_failed", data: [
                        "domain": domain,
                        "error": error.localizedDescription,
                    ])
                }
            }

            if totalSaved == 0 {
                return HookOutput(additionalContext: "Memory review: no extractable experience found in this session.")
            }

            let domainList = savedDomains.sorted().joined(separator: ", ")
            let filteredTotal = result.skippedCount + domainFiltered
            let summary = "Memory review: extracted \(totalSaved) experience signals (\(filteredTotal) filtered) from \(messages.count) messages. Domains: \(domainList)."
            return HookOutput(additionalContext: summary)
        }
    }
}
