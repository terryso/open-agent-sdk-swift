import Foundation

// MARK: - ReviewMemoryInput

private struct ReviewMemoryInput: Codable {
    let domain: String
    let content: String
    let kind: String
    let confidence: Double?
}

// MARK: - createReviewMemoryTool

/// Creates the `review_save_memory` tool for the forked review agent.
///
/// Converts input to an `ExperienceSignal` → `toFact()` → `FactStore.save(domain:fact:)`.
/// Dependencies are captured in the execute closure, not passed through `ToolContext`.
///
/// - Parameter factStore: The fact store to save memories into.
/// - Returns: A `ToolProtocol` instance named `review_save_memory`.
public func createReviewMemoryTool(factStore: FactStore) -> ToolProtocol {
    defineTool(
        name: "review_save_memory",
        description: "Save a memory fact extracted from the conversation review. The review agent uses this to persist learned knowledge.",
        inputSchema: [
            "type": "object",
            "properties": [
                "domain": ["type": "string", "description": "The memory domain (e.g., 'testing', 'navigation')"],
                "content": ["type": "string", "description": "The memory content to save"],
                "kind": ["type": "string", "description": "One of: affordance, avoid, observation", "enum": ["affordance", "avoid", "observation"]],
                "confidence": ["type": "number", "description": "Confidence score 0-1 (default 0.7)"]
            ],
            "required": ["domain", "content", "kind"]
        ]
    ) { (input: ReviewMemoryInput, _: ToolContext) async -> String in
        guard !input.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{\"success\": false, \"error\": \"'domain' must not be empty\"}"
        }
        guard !input.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{\"success\": false, \"error\": \"'content' must not be empty\"}"
        }
        guard let kind = MemoryKind(rawValue: input.kind) else {
            return "{\"success\": false, \"error\": \"Invalid kind '\(input.kind)'. Must be one of: affordance, avoid, observation\"}"
        }

        let confidence = input.confidence ?? 0.7
        let signal = ExperienceSignal.create(
            domain: input.domain,
            kind: kind,
            content: input.content,
            confidence: confidence,
            source: .conversation
        )
        let fact = signal.toFact()

        do {
            try await factStore.save(domain: input.domain, fact: fact)
            return "{\"success\": true, \"message\": \"Memory saved to domain '\(input.domain)'\"}"
        } catch {
            return "{\"success\": false, \"error\": \"\(error.localizedDescription)\"}"
        }
    }
}
