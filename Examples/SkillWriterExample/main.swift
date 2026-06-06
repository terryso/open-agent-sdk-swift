// SkillWriterExample
//
// 演示如何使用 SkillWriter 将技能持久化到磁盘（SKILL.md 文件），包括：
//   1. 创建 Skill 并通过 SkillWriter.write() 写入磁盘
//   2. 读取生成的 SKILL.md 文件内容
//   3. 使用 SkillWriter.buildSKILLMd() 预览内容而不写入
//   4. 验证写入的文件结构
//
// 运行方式：swift run SkillWriterExample
// 无需 API Key — 纯本地文件操作

import Foundation
import OpenAgentSDK

@main
struct SkillWriterExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  SkillWriter Example — 技能持久化到磁盘                      ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        let tmpDir = NSTemporaryDirectory().appending("skill-writer-example-\(UUID().uuidString.prefix(8))")

        try await part1_WriteSkillToDisk(tmpDir: tmpDir)
        try await part2_BuildSKILLMdPreview()
        try await part3_WriteComplexSkill(tmpDir: tmpDir)
        cleanup(tmpDir: tmpDir)

        print("=== SkillWriterExample Completed ===")
    }

    // MARK: - Part 1: 写入技能到磁盘

    static func part1_WriteSkillToDisk(tmpDir: String) async throws {
        print("--- Part 1: Write Skill to Disk ---")
        print()

        let skill = Skill(
            name: "summarize",
            description: "Summarize a file or text into key points",
            aliases: ["sum"],
            userInvocable: true,
            promptTemplate: """
            Read the provided content and produce a concise summary with:
            1. Main topic (one sentence)
            2. Key points (bulleted list)
            3. Action items (if any)
            """
        )

        print("  Writing skill '\(skill.name)' to: \(tmpDir)")

        let skillDir = try SkillWriter.write(skill: skill, to: tmpDir)
        print("  Skill directory created: \(skillDir)")

        let skillMdPath = (skillDir as NSString).appendingPathComponent("SKILL.md")
        let content = try String(contentsOfFile: skillMdPath, encoding: .utf8)
        print()
        print("  --- Generated SKILL.md ---")
        for line in content.split(separator: "\n") {
            print("  \(line)")
        }
        print("  --- End of SKILL.md ---")
        print()
    }

    // MARK: - Part 2: 预览 SKILL.md 内容

    static func part2_BuildSKILLMdPreview() async throws {
        print("--- Part 2: Build SKILL.md Preview (no disk write) ---")
        print()

        let skill = Skill(
            name: "debug",
            description: "Debug a failing test or error: find root cause and suggest fix",
            aliases: ["dbg"],
            userInvocable: true,
            modelOverride: "claude-opus-4-6",
            promptTemplate: """
            Analyze the error and produce:
            1. Root cause analysis
            2. Suggested fix
            3. Prevention strategy
            """,
            whenToUse: "Use when the user reports a failing test, error, or unexpected behavior",
            argumentHint: "[test-name or error-message]"
        )

        let mdContent = SkillWriter.buildSKILLMd(skill)

        print("  Preview (no file created):")
        print()
        for line in mdContent.split(separator: "\n") {
            print("  \(line)")
        }
        print()
    }

    // MARK: - Part 3: 写入复杂技能

    static func part3_WriteComplexSkill(tmpDir: String) async throws {
        print("--- Part 3: Write Complex Skill with Special Characters ---")
        print()

        let skill = Skill(
            name: "deploy",
            description: "Deploy to staging: run tests, build Docker image, push and verify",
            aliases: ["ship", "release"],
            userInvocable: true,
            promptTemplate: """
            Execute the deployment pipeline:
            1. Run `npm test` — fail fast on errors
            2. Build Docker image: `docker build -t app:latest .`
            3. Push to registry: `docker push registry.example.com/app:latest`
            4. Verify health endpoint returns 200

            Environment: staging
            Region: us-west-2
            """
        )

        let skillDir = try SkillWriter.write(skill: skill, to: tmpDir)
        let skillMdPath = (skillDir as NSString).appendingPathComponent("SKILL.md")
        let content = try String(contentsOfFile: skillMdPath, encoding: .utf8)

        print("  Wrote '\(skill.name)' with aliases: \(skill.aliases.joined(separator: ", "))")
        print("  File size: \(content.utf8.count) bytes")
        print()

        // Verify directory structure
        let items = try FileManager.default.contentsOfDirectory(atPath: tmpDir)
        print("  Skills on disk: \(items)")
        print()
    }

    // MARK: - Cleanup

    static func cleanup(tmpDir: String) {
        try? FileManager.default.removeItem(atPath: tmpDir)
        print("  Cleaned up temporary directory")
        print()
    }
}
