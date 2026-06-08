import Foundation

/// Exports memory facts as a portable JSON bundle.
public struct MemoryBundleExportService {

    private let jsonEncoder: JSONEncoder = makeSDKJSONEncoder()

    public init() {}

    /// Export all domains from the store as a single bundle.
    public func exportAll(store: FactStore) async throws -> MemoryBundle {
        let domains = try await store.listDomains()
        var exported: [ExportedDomain] = []

        for domain in domains {
            let facts = try await store.query(domain: domain)
            if !facts.isEmpty {
                exported.append(ExportedDomain(domain: domain, facts: facts))
            }
        }

        return MemoryBundle(schemaVersion: 1, exportedAt: Date(), memories: exported)
    }

    /// Export a single domain from the store as a bundle.
    public func exportDomain(store: FactStore, domain: String) async throws -> MemoryBundle {
        let facts = try await store.query(domain: domain)
        let exported = ExportedDomain(domain: domain, facts: facts)
        return MemoryBundle(schemaVersion: 1, exportedAt: Date(), memories: [exported])
    }

    /// Write a bundle to disk as pretty-printed JSON with iso8601 dates.
    public func writeBundle(_ bundle: MemoryBundle, to url: URL) throws {
        let data = try jsonEncoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }
}
