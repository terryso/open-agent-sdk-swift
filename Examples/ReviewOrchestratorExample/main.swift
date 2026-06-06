// ReviewOrchestratorExample
//
// 演示 ReviewOrchestrator 的配置与调度逻辑，包括：
//   1. ReviewScheduleConfig — 控制审查触发间隔
//   2. ReviewAgentConfig.promptSuffix — 扩展审查 prompt
//   3. ReviewOrchestrator.additionalReviewTools — 注入自定义审查工具
//   4. shouldReview() — 判断是否触发 memory/skill 审查
//   5. ReviewOrchestrator 完整初始化与调度模拟
//
// 运行方式：swift run ReviewOrchestratorExample
// 无需 API Key — 仅演示配置与调度逻辑

import Foundation
import OpenAgentSDK

@main
struct ReviewOrchestratorExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  ReviewOrchestrator Example — 审查调度与配置                  ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        try await part1_ReviewScheduleConfig()
        try await part2_PromptSuffix()
        try await part3_AdditionalReviewTools()
        try await part4_ShouldReviewSimulation()
    }

    // MARK: - Part 1: ReviewScheduleConfig

    static func part1_ReviewScheduleConfig() async throws {
        print("--- Part 1: ReviewScheduleConfig ---")
        print()

        let config = ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4,
            reviewModel: "claude-haiku-4-5-20251001"
        )

        print("  Memory review every \(config.memoryReviewInterval) messages")
        print("  Skill review every \(config.skillReviewInterval) messages")
        print("  Min messages for review: \(config.minMessagesForReview)")
        print("  Review model: \(config.reviewModel ?? "(inherits parent)")")
        print()
    }

    // MARK: - Part 2: promptSuffix

    static func part2_PromptSuffix() async throws {
        print("--- Part 2: ReviewAgentConfig with promptSuffix ---")
        print()

        // 默认配置 — 无 prompt 扩展
        let defaultConfig = ReviewAgentConfig()
        print("  Default promptSuffix: \(defaultConfig.promptSuffix ?? "(none)")")

        // 自定义配置 — 添加 prompt 扩展指导审查 agent 使用额外工具
        let customConfig = ReviewAgentConfig(
            reviewMemory: true,
            reviewSkills: true,
            maxTurns: 20,
            promptSuffix: """
            Additional instructions:
            - Also check for outdated API patterns and suggest modernizations
            - If you find deprecated tool usage, update the relevant skills
            - Write a summary to MEMORY.md for each significant finding
            """
        )

        print()
        print("  Custom promptSuffix (first 80 chars):")
        let suffix = customConfig.promptSuffix ?? ""
        let preview = String(suffix.prefix(80))
        print("    \(preview)\(suffix.count > 80 ? "..." : "")")
        print()
        print("  Max turns: \(customConfig.maxTurns)")
        print("  Allowed tools: \(customConfig.allowedTools)")
        print()
    }

    // MARK: - Part 3: additionalReviewTools

    static func part3_AdditionalReviewTools() async throws {
        print("--- Part 3: additionalReviewTools ---")
        print()

        // 创建一个自定义审查工具，写入 MEMORY.md
        let memoryWriterTool = defineTool(
            name: "write_memory_md",
            description: "Append a section to MEMORY.md for long-term agent context",
            inputSchema: [
                "type": "object",
                "properties": [
                    "section": ["type": "string", "description": "Section title"],
                    "content": ["type": "string", "description": "Section content in markdown"]
                ],
                "required": ["section", "content"]
            ],
            isReadOnly: false
        ) { (input: MemoryWriterInput, context: ToolContext) -> String in
            return "Wrote section '\(input.section)' to MEMORY.md"
        }

        // 创建 ReviewOrchestrator 并注入额外工具
        let factStore = FactStore(memoryDir: "/tmp/example-facts")
        let registry = SkillRegistry()
        let usageStore = SkillUsageStore()

        let _ = ReviewOrchestrator(
            scheduleConfig: ReviewScheduleConfig(),
            factStore: factStore,
            skillRegistry: registry,
            skillEvolver: MockSkillEvolver(),
            usageStore: usageStore,
            skillsDir: "/tmp/example-skills",
            additionalReviewTools: [memoryWriterTool]
        )

        print("  Built-in review tools (5):")
        print("    - review_save_memory")
        print("    - review_update_skill")
        print("    - review_create_skill")
        print("    - review_add_skill_file")
        print("    - curator_archive_skill")
        print()
        print("  Additional review tools (1):")
        print("    - write_memory_md (custom tool for MEMORY.md)")
        print()
        print("  Total tools available to review agent: 6")
        print()

        // ReviewAgentConfig 需要将自定义工具名加入 allowedTools
        let extendedConfig = ReviewAgentConfig(
            allowedTools: [
                "review_save_memory",
                "review_update_skill",
                "review_create_skill",
                "review_add_skill_file",
                "curator_archive_skill",
                "write_memory_md",
            ],
            promptSuffix: "Use write_memory_md to persist important findings to MEMORY.md."
        )

        print("  Extended allowedTools: \(extendedConfig.allowedTools)")
        print()
    }

    // MARK: - Part 4: shouldReview 模拟

    static func part4_ShouldReviewSimulation() async throws {
        print("--- Part 4: shouldReview() Simulation ---")
        print()

        let schedule = ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        )

        let factStore = FactStore(memoryDir: "/tmp/example-facts")
        let registry = SkillRegistry()
        let usageStore = SkillUsageStore()

        let orchestrator = ReviewOrchestrator(
            scheduleConfig: schedule,
            factStore: factStore,
            skillRegistry: registry,
            skillEvolver: MockSkillEvolver(),
            usageStore: usageStore,
            skillsDir: "/tmp/example-skills"
        )

        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)

        print("  Simulating message counts (interval: memory=4, skill=6, min=4):")
        print()

        for msgCount in [2, 4, 6, 8, 10, 12] {
            let result = orchestrator.shouldReview(
                sessionId: "sess-example",
                messageCount: msgCount,
                config: config
            )
            let memoryFlag = result.memory ? "YES" : "no"
            let skillFlag = result.skill ? "YES" : "no"
            print("  \(msgCount) messages → memory review: \(memoryFlag), skill review: \(skillFlag)")
        }

        print()
    }
}

// MARK: - Helper Types

private struct MemoryWriterInput: Codable {
    let section: String
    let content: String
}

/// Mock skill evolver for example purposes.
private struct MockSkillEvolver: SkillEvolver {
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        SkillEvolutionResult(evolvedSkill: nil, appliedSignals: [], skippedSignals: [], changes: [])
    }
}
