import Foundation

/// Errors that can occur during bundle import.
public enum MemoryBundleError: Error, Equatable, Sendable {
    case invalidBundle(reason: String)
}

/// Result of a bundle import operation.
public struct ImportResult: Equatable, Sendable {
    public let domainsProcessed: Int
    public let factsImported: Int
    public let factsMerged: Int
    public let errors: [String]

    public init(domainsProcessed: Int, factsImported: Int, factsMerged: Int, errors: [String] = []) {
        self.domainsProcessed = domainsProcessed
        self.factsImported = factsImported
        self.factsMerged = factsMerged
        self.errors = errors
    }
}

/// Imports memory facts from a bundle, downgrading and merging with existing data.
public struct MemoryBundleImportService {

    private let jsonDecoder: JSONDecoder = makeSDKJSONDecoder()

    public init() {}

    /// Import all facts from a bundle into the store.
    ///
    /// Imported facts are downgraded: status forced to candidate, confidence capped at 0.55,
    /// source marked as imported. Matching existing facts by id are merged (stronger status wins,
    /// max confidence, evidence deduplication keeping latest 5).
    public func importBundle(from url: URL, store: FactStore) async throws -> ImportResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MemoryBundleError.invalidBundle(reason: "Cannot read file: \(error.localizedDescription)")
        }

        return try await importBundle(from: data, store: store)
    }

    /// Import all facts from raw bundle data.
    public func importBundle(from data: Data, store: FactStore) async throws -> ImportResult {
        let bundle: MemoryBundle
        do {
            bundle = try jsonDecoder.decode(MemoryBundle.self, from: data)
        } catch {
            throw MemoryBundleError.invalidBundle(reason: "Invalid JSON: \(error.localizedDescription)")
        }

        guard bundle.schemaVersion == 1 else {
            throw MemoryBundleError.invalidBundle(reason: "Unsupported schema_version: \(bundle.schemaVersion)")
        }

        var domainsProcessed = 0
        var factsImported = 0
        var factsMerged = 0
        var errors: [String] = []

        for exportedDomain in bundle.memories {
            domainsProcessed += 1
            let domain = exportedDomain.domain
            let existingFacts = (try? await store.query(domain: domain)) ?? []

            for fact in exportedDomain.facts {
                let downgraded = downgrade(fact)

                if let match = existingFacts.first(where: { $0.id == fact.id }) {
                    let merged = mergeImported(existing: match, incoming: downgraded)
                    do {
                        try await store.save(domain: domain, fact: merged)
                        factsMerged += 1
                    } catch {
                        errors.append("Domain \(domain), fact \(fact.id): \(error.localizedDescription)")
                    }
                } else {
                    do {
                        try await store.save(domain: domain, fact: downgraded)
                        factsImported += 1
                    } catch {
                        errors.append("Domain \(domain), fact \(fact.id): \(error.localizedDescription)")
                    }
                }
            }
        }

        return ImportResult(
            domainsProcessed: domainsProcessed,
            factsImported: factsImported,
            factsMerged: factsMerged,
            errors: errors
        )
    }

    // MARK: - Private

    /// Downgrade an imported fact: force candidate, cap confidence, mark as imported.
    private func downgrade(_ fact: MemoryFact) -> MemoryFact {
        MemoryFact(
            id: fact.id,
            domain: fact.domain,
            content: fact.content,
            status: .candidate,
            confidence: min(fact.confidence, 0.55),
            evidenceCount: fact.evidenceCount,
            source: .imported,
            kind: fact.kind,
            createdAt: fact.createdAt,
            lastVerifiedAt: fact.lastVerifiedAt
        )
    }

    /// Merge an imported fact with an existing one: stronger status wins, max confidence,
    /// evidence dedup (keep latest 5).
    private func mergeImported(existing: MemoryFact, incoming: MemoryFact) -> MemoryFact {
        // Stronger status wins: active > candidate > retired
        let strongerStatus: MemoryFactStatus = {
            let order: [MemoryFactStatus] = [.active, .candidate, .retired]
            let existingIdx = order.firstIndex(of: existing.status) ?? 2
            let incomingIdx = order.firstIndex(of: incoming.status) ?? 2
            return existingIdx <= incomingIdx ? existing.status : incoming.status
        }()

        let mergedEvidence = min(existing.evidenceCount + incoming.evidenceCount, 5)

        return MemoryFact(
            id: existing.id,
            domain: existing.domain,
            content: incoming.content.isEmpty ? existing.content : incoming.content,
            status: strongerStatus,
            confidence: max(existing.confidence, incoming.confidence),
            evidenceCount: mergedEvidence,
            source: existing.source,
            kind: existing.kind,
            createdAt: existing.createdAt,
            lastVerifiedAt: max(existing.lastVerifiedAt, incoming.lastVerifiedAt)
        )
    }
}
