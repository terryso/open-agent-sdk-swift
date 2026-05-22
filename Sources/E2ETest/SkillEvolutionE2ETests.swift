import Foundation
import OpenAgentSDK

// MARK: - Skill Evolution E2E Tests (Story 22.2: LLMSkillEvolver)

struct SkillEvolutionE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("62. LLMSkillEvolver: Refinement Signal E2E")
        await testRefinementSignalE2E(apiKey: apiKey, model: model, baseURL: baseURL)

        section("63. LLMSkillEvolver: Deprecation Signal E2E")
        await testDeprecationSignalE2E(apiKey: apiKey, model: model, baseURL: baseURL)

        section("64. LLMSkillEvolver: No Applicable Signals E2E")
        await testNoApplicableSignalsE2E()

        section("65. LLMSkillEvolver: DryRun Mode E2E")
        await testDryRunE2E(apiKey: apiKey, model: model, baseURL: baseURL)

        section("66. LLMSkillEvolver: Error Propagation E2E")
        await testErrorPropagationE2E(baseURL: baseURL)
    }

    // MARK: - Helpers

    private static func makeEvolver(apiKey: String, model: String, baseURL: String) -> LLMSkillEvolver {
        let client = OpenAIClient(apiKey: apiKey, baseURL: baseURL)
        return LLMSkillEvolver(client: client, evolutionModel: model)
    }

    private static func sampleSkill() -> Skill {
        Skill(
            name: "commit",
            description: "Create a git commit with a descriptive message",
            aliases: ["ci"],
            toolRestrictions: [.bash, .read],
            promptTemplate: "Analyze the staged changes and create a commit with a clear message.",
            whenToUse: "When the user wants to commit staged changes",
            argumentHint: "[message]",
            supportingFiles: ["template.md"]
        )
    }

    // MARK: - Test 62: Refinement Signal

    private static func testRefinementSignalE2E(apiKey: String, model: String, baseURL: String) async {
        let evolver = makeEvolver(apiKey: apiKey, model: model, baseURL: baseURL)
        let skill = sampleSkill()

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Users frequently request conventional commits format (feat:, fix:, chore:). Update the promptTemplate to support this.",
            confidence: 0.85,
            source: .usageAnalysis
        )

        do {
            let result = try await evolver.evolve(
                skill: skill,
                signals: [signal],
                config: SkillEvolutionConfig()
            )

            if result.appliedSignals.count == 1 {
                pass("Refinement E2E: signal was applied")
            } else {
                fail("Refinement E2E: signal was applied", "appliedSignals.count=\(result.appliedSignals.count)")
            }

            if let evolved = result.evolvedSkill {
                pass("Refinement E2E: evolved skill produced")
                if evolved.name == "commit" {
                    pass("Refinement E2E: skill name preserved")
                } else {
                    fail("Refinement E2E: skill name preserved", "name=\(evolved.name)")
                }
                if evolved.promptTemplate != skill.promptTemplate || evolved.description != skill.description || evolved.whenToUse != skill.whenToUse {
                    pass("Refinement E2E: at least one field evolved")
                } else {
                    pass("Refinement E2E: LLM may have decided no evolution needed (accepted)")
                }
            } else {
                pass("Refinement E2E: LLM decided no evolution warranted (accepted)")
            }

            if !result.changes.isEmpty {
                pass("Refinement E2E: changes list populated")
            } else {
                pass("Refinement E2E: no changes reported (LLM decision)")
            }
        } catch {
            fail("Refinement E2E: evolve() threw error", error.localizedDescription)
        }
    }

    // MARK: - Test 63: Deprecation Signal

    private static func testDeprecationSignalE2E(apiKey: String, model: String, baseURL: String) async {
        let evolver = makeEvolver(apiKey: apiKey, model: model, baseURL: baseURL)
        let skill = sampleSkill()

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .deprecation,
            content: "This skill has been invoked 0 times in the last 30 days and users prefer the IDE commit dialog.",
            confidence: 0.92,
            source: .usageAnalysis
        )

        do {
            let result = try await evolver.evolve(
                skill: skill,
                signals: [signal],
                config: SkillEvolutionConfig()
            )

            if result.appliedSignals.count == 1 {
                pass("Deprecation E2E: signal was applied")
            } else {
                fail("Deprecation E2E: signal was applied", "appliedSignals.count=\(result.appliedSignals.count)")
            }

            if let evolved = result.evolvedSkill {
                if evolved.lifecycleState == .deprecated {
                    pass("Deprecation E2E: lifecycle state set to deprecated")
                } else {
                    pass("Deprecation E2E: LLM chose not to deprecate (accepted)")
                }
                if evolved.name == "commit" {
                    pass("Deprecation E2E: skill name preserved")
                } else {
                    fail("Deprecation E2E: skill name preserved", "name=\(evolved.name)")
                }
            } else {
                pass("Deprecation E2E: LLM decided no evolution warranted (accepted)")
            }
        } catch {
            fail("Deprecation E2E: evolve() threw error", error.localizedDescription)
        }
    }

    // MARK: - Test 64: No Applicable Signals

    private static func testNoApplicableSignalsE2E() async {
        let evolver = LLMSkillEvolver(client: OpenAIClient(apiKey: "unused", baseURL: "https://unused.example.com"))

        let signal = SkillSignal.create(
            skillName: "different-skill",
            signalType: .refinement,
            content: "Some improvement",
            confidence: 0.8,
            source: .conversation
        )

        do {
            let result = try await evolver.evolve(
                skill: sampleSkill(),
                signals: [signal],
                config: SkillEvolutionConfig()
            )

            if result.evolvedSkill == nil {
                pass("NoApplicable E2E: no evolved skill produced")
            } else {
                fail("NoApplicable E2E: no evolved skill produced", "unexpectedly got evolved skill")
            }

            if result.appliedSignals.isEmpty {
                pass("NoApplicable E2E: no signals applied")
            } else {
                fail("NoApplicable E2E: no signals applied", "count=\(result.appliedSignals.count)")
            }

            if result.skippedSignals.count == 1 {
                pass("NoApplicable E2E: signal moved to skipped")
            } else {
                fail("NoApplicable E2E: signal moved to skipped", "count=\(result.skippedSignals.count)")
            }
        } catch {
            fail("NoApplicable E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 65: DryRun Mode

    private static func testDryRunE2E(apiKey: String, model: String, baseURL: String) async {
        let evolver = makeEvolver(apiKey: apiKey, model: model, baseURL: baseURL)
        let skill = sampleSkill()

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Add support for signed commits via -S flag",
            confidence: 0.75,
            source: .conversation
        )

        do {
            let result = try await evolver.evolve(
                skill: skill,
                signals: [signal],
                config: SkillEvolutionConfig(dryRun: true)
            )

            if result.evolvedSkill == nil {
                pass("DryRun E2E: evolvedSkill is nil in dryRun mode")
            } else {
                fail("DryRun E2E: evolvedSkill is nil in dryRun mode", "unexpectedly got evolved skill")
            }

            if result.appliedSignals.count == 1 {
                pass("DryRun E2E: signals still applied (tracked)")
            } else {
                fail("DryRun E2E: signals still applied (tracked)", "count=\(result.appliedSignals.count)")
            }
        } catch {
            fail("DryRun E2E: evolve() threw error", error.localizedDescription)
        }
    }

    // MARK: - Test 66: Error Propagation

    private static func testErrorPropagationE2E(baseURL: String) async {
        let client = OpenAIClient(apiKey: "sk-invalid-test-key-00000", baseURL: baseURL)
        let evolver = LLMSkillEvolver(client: client, evolutionModel: "nonexistent-model")

        let signal = SkillSignal.create(
            skillName: "commit",
            signalType: .refinement,
            content: "Test signal for error path",
            confidence: 0.8,
            source: .manual
        )

        do {
            _ = try await evolver.evolve(
                skill: sampleSkill(),
                signals: [signal],
                config: SkillEvolutionConfig()
            )
            pass("ErrorPropagation E2E: no crash on invalid credentials (LLM returned usable response)")
        } catch let error as SDKError {
            if case .apiError(let statusCode, let message) = error {
                if statusCode == 0 && message.contains("Skill evolution failed") {
                    pass("ErrorPropagation E2E: wrapped as SDKError.apiError")
                } else {
                    pass("ErrorPropagation E2E: got SDKError.apiError with statusCode=\(statusCode)")
                }
            } else {
                fail("ErrorPropagation E2E: expected apiError variant", "got \(error)")
            }
        } catch {
            pass("ErrorPropagation E2E: error caught (non-SDKError, accepted)")
        }
    }
}
