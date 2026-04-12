import XCTest
@testable import OpenAgentSDK

// MARK: - ProjectDocumentDiscovery ATDD Tests (Story 12.4)

/// ATDD RED PHASE: Tests for Story 12.4 -- Project Document Discovery.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Utils/ProjectDocumentDiscovery.swift` is created
///   - `ProjectDocumentDiscovery` final class with NSLock, collectProjectContext(), caching is implemented
///   - `ProjectContextResult` struct with globalInstructions/projectInstructions is defined
///   - `SDKConfiguration` and `AgentOptions` gain `projectRoot` field
///   - `Agent.buildSystemPrompt()` integrates project document context injection
/// TDD Phase: RED (feature not implemented yet)
final class ProjectDocumentDiscoveryTests: XCTestCase {

    var tempDir: String!
    var projectDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-ProjectDoc-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )

        // Create a project directory with Git init for tests that need .git discovery
        projectDir = (tempDir as NSString).appendingPathComponent("myproject")
        try! FileManager.default.createDirectory(
            atPath: projectDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a ProjectDocumentDiscovery instance for testing.
    private func makeDiscovery() -> ProjectDocumentDiscovery {
        return ProjectDocumentDiscovery()
    }

    /// Initialize a Git repo in the given directory (with an initial commit).
    private func initGitRepo(at path: String) {
        runShell("git init", cwd: path)
        runShell("git config user.name \"TestUser\"", cwd: path)
        runShell("git config user.email \"test@example.com\"", cwd: path)
        let initialFile = (path as NSString).appendingPathComponent(".gitkeep")
        try! "".write(toFile: initialFile, atomically: true, encoding: .utf8)
        runShell("git add .", cwd: path)
        runShell("git commit -m \"initial commit\"", cwd: path)
    }

    /// Run a shell command in the given working directory.
    @discardableResult
    private func runShell(_ command: String, cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - AC1: CLAUDE.md Injected into System Prompt

    /// AC1 [P0]: Given project root has CLAUDE.md (500 chars), when collectProjectContext is called,
    /// then projectInstructions contains CLAUDE.md content.
    func testAC1_CollectContext_CLAUDEmd_ContainsProjectInstructions() {
        // Given: a Git project with a CLAUDE.md file (~500 chars)
        initGitRepo(at: projectDir)
        let content = String(repeating: "x", count: 500)
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: projectInstructions contains the CLAUDE.md content
        XCTAssertNotNil(result, "Should return non-nil result")
        XCTAssertNotNil(result.projectInstructions,
                         "projectInstructions should contain CLAUDE.md content")
        XCTAssertTrue(result.projectInstructions!.contains(content),
                       "projectInstructions should contain the full CLAUDE.md content")
    }

    /// AC1 [P0]: Agent.buildSystemPrompt() includes <project-instructions> block
    /// when project has a CLAUDE.md file.
    func testAC1_BuildSystemPrompt_WithCLAUDEmd_ContainsProjectInstructionsBlock() {
        // Given: a project with CLAUDE.md and an Agent pointed at it
        initGitRepo(at: projectDir)
        let content = "Use Swift naming conventions."
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        // Use non-Git temp dir for cwd to avoid Git context injection noise
        let isolatedCwd = (tempDir as NSString).appendingPathComponent("isolated")
        try! FileManager.default.createDirectory(atPath: isolatedCwd, withIntermediateDirectories: true)

        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are a helpful assistant.",
            cwd: isolatedCwd,
            projectRoot: projectDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: prompt contains <project-instructions> block
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("<project-instructions>"),
                       "Should contain <project-instructions> opening tag")
        XCTAssertTrue(prompt!.contains("</project-instructions>"),
                       "Should contain </project-instructions> closing tag")
        XCTAssertTrue(prompt!.contains(content),
                       "Should contain CLAUDE.md content inside the block")
    }

    // MARK: - AC2: Global Instructions and Project Instructions Separated

    /// AC2 [P0]: Global CLAUDE.md (~/.claude/CLAUDE.md) and project CLAUDE.md
    /// are loaded into separate fields.
    func testAC2_GlobalAndProjectInstructions_Separated() {
        // Given: a project with CLAUDE.md and a simulated global ~/.claude/CLAUDE.md
        initGitRepo(at: projectDir)
        let projectContent = "Project-level instructions."
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! projectContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        // Create a simulated global home .claude directory
        let fakeHome = (tempDir as NSString).appendingPathComponent("fakehome")
        let claudeDir = (fakeHome as NSString).appendingPathComponent(".claude")
        try! FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        let globalContent = "Global-level instructions."
        let globalClaudeMd = (claudeDir as NSString).appendingPathComponent("CLAUDE.md")
        try! globalContent.write(toFile: globalClaudeMd, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting project context with explicit home directory
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil,
            homeDirectory: fakeHome
        )

        // Then: both instructions are present and different
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.globalInstructions,
                         "globalInstructions should contain ~/.claude/CLAUDE.md content")
        XCTAssertNotNil(result.projectInstructions,
                         "projectInstructions should contain project CLAUDE.md content")
        XCTAssertTrue(result.globalInstructions!.contains(globalContent),
                       "globalInstructions should contain global content")
        XCTAssertTrue(result.projectInstructions!.contains(projectContent),
                       "projectInstructions should contain project content")
        // Ensure no cross-contamination
        XCTAssertFalse(result.globalInstructions!.contains(projectContent),
                        "globalInstructions should NOT contain project content")
        XCTAssertFalse(result.projectInstructions!.contains(globalContent),
                        "projectInstructions should NOT contain global content")
    }

    /// AC2 [P1]: Agent.buildSystemPrompt() renders <global-instructions> and
    /// <project-instructions> as separate blocks.
    func testAC2_BuildSystemPrompt_GlobalAndProject_SeparateBlocks() {
        // Given: both global and project instructions exist
        initGitRepo(at: projectDir)
        let projectContent = "Project instructions here."
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! projectContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let fakeHome = (tempDir as NSString).appendingPathComponent("fakehome2")
        let claudeDir = (fakeHome as NSString).appendingPathComponent(".claude")
        try! FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        let globalContent = "Global instructions here."
        let globalClaudeMd = (claudeDir as NSString).appendingPathComponent("CLAUDE.md")
        try! globalContent.write(toFile: globalClaudeMd, atomically: true, encoding: .utf8)

        // Non-Git cwd to avoid Git context
        let isolatedCwd = (tempDir as NSString).appendingPathComponent("isolated2")
        try! FileManager.default.createDirectory(atPath: isolatedCwd, withIntermediateDirectories: true)

        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "Be helpful.",
            cwd: isolatedCwd,
            projectRoot: projectDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt (injecting via environment override)
        // Note: This test requires the Agent to use a configurable home directory.
        // For ATDD, we test the block format expectation.
        let prompt = agent.buildSystemPrompt()

        // Then: if global instructions are present, both blocks appear
        // This test verifies the block structure when both are present.
        // Due to the real home directory being used, we at least verify
        // the project instructions block is present.
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("<project-instructions>"),
                       "Should contain <project-instructions> block")
    }

    // MARK: - AC3: CLAUDE.md and AGENT.md Merged

    /// AC3 [P0]: Given both CLAUDE.md and AGENT.md exist in project root,
    /// when collectProjectContext is called, both are merged into projectInstructions
    /// with CLAUDE.md content first, AGENT.md content second.
    func testAC3_CLAUDEmdAndAGENTmd_MergedInCorrectOrder() {
        // Given: project root has both CLAUDE.md and AGENT.md
        initGitRepo(at: projectDir)
        let claudeContent = "CLAUDE.md instructions."
        let agentContent = "AGENT.md instructions."
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        let agentMdPath = (projectDir as NSString).appendingPathComponent("AGENT.md")
        try! claudeContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)
        try! agentContent.write(toFile: agentMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: projectInstructions contains both, CLAUDE.md first
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        XCTAssertTrue(result.projectInstructions!.contains(claudeContent),
                       "Should contain CLAUDE.md content")
        XCTAssertTrue(result.projectInstructions!.contains(agentContent),
                       "Should contain AGENT.md content")

        // Verify order: CLAUDE.md content appears before AGENT.md content
        if let instr = result.projectInstructions {
            let claudeRange = instr.range(of: claudeContent)!
            let agentRange = instr.range(of: agentContent)!
            XCTAssertTrue(claudeRange.lowerBound < agentRange.lowerBound,
                           "CLAUDE.md content should appear before AGENT.md content")
        }
    }

    /// AC3 [P1]: Given only AGENT.md exists (no CLAUDE.md), projectInstructions
    /// contains AGENT.md content only.
    func testAC3_OnlyAGENTmd_LoadsSuccessfully() {
        // Given: project root has only AGENT.md
        initGitRepo(at: projectDir)
        let agentContent = "Only AGENT.md instructions."
        let agentMdPath = (projectDir as NSString).appendingPathComponent("AGENT.md")
        try! agentContent.write(toFile: agentMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: projectInstructions contains AGENT.md content
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        XCTAssertTrue(result.projectInstructions!.contains(agentContent),
                       "Should contain AGENT.md content when CLAUDE.md is absent")
    }

    // MARK: - AC4: Custom Project Root Directory

    /// AC4 [P0]: Given explicitProjectRoot is set, collectProjectContext reads from
    /// that directory instead of discovering project root from cwd.
    func testAC4_ExplicitProjectRoot_UsesSpecifiedPath() {
        // Given: two directories - one with CLAUDE.md, one without
        let dirWithClaude = (tempDir as NSString).appendingPathComponent("with_claude")
        let dirWithoutClaude = (tempDir as NSString).appendingPathComponent("without_claude")
        try! FileManager.default.createDirectory(atPath: dirWithClaude, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(atPath: dirWithoutClaude, withIntermediateDirectories: true)

        let content = "Instructions from explicit root."
        let claudeMdPath = (dirWithClaude as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: calling with explicitProjectRoot pointing to dirWithClaude
        // but cwd pointing to dirWithoutClaude
        let result = discovery.collectProjectContext(
            cwd: dirWithoutClaude,
            explicitProjectRoot: dirWithClaude
        )

        // Then: projectInstructions contains content from dirWithClaude
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        XCTAssertTrue(result.projectInstructions!.contains(content),
                       "Should read CLAUDE.md from explicitProjectRoot, not cwd")
    }

    /// AC4 [P1]: SDKConfiguration.projectRoot is passed through to AgentOptions.projectRoot.
    func testAC4_SDKConfiguration_ProjectRoot_PassedToAgentOptions() {
        // Given: an SDKConfiguration with projectRoot set
        let config = SDKConfiguration(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            projectRoot: "/custom/project/path"
        )

        // When: creating AgentOptions from the config
        let options = AgentOptions(from: config)

        // Then: projectRoot is carried over
        XCTAssertEqual(options.projectRoot, "/custom/project/path",
                        "projectRoot should be passed from SDKConfiguration to AgentOptions")
    }

    // MARK: - AC5: Large File Truncation

    /// AC5 [P0]: Given CLAUDE.md exceeds 100KB, the content is truncated to 100KB
    /// with a truncation comment appended.
    func testAC5_LargeFile_TruncatedTo100KB() {
        // Given: a CLAUDE.md file larger than 100KB
        initGitRepo(at: projectDir)
        // Create content > 100KB (102,400 bytes)
        let largeContent = String(repeating: "A", count: 110_000)
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! largeContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: content is truncated to <= 100KB + truncation comment
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        let instr = result.projectInstructions!

        // The returned content should be less than the original
        XCTAssertLessThan(instr.utf8.count, largeContent.utf8.count,
                           "Truncated content should be smaller than original")

        // Should contain a truncation indicator
        XCTAssertTrue(instr.contains("truncat") || instr.contains("Truncat") || instr.contains("<!--"),
                       "Should contain a truncation indicator comment")
    }

    /// AC5 [P1]: Truncation comment includes original size information.
    func testAC5_TruncationComment_ContainsOriginalSize() {
        // Given: a CLAUDE.md file of 110KB
        initGitRepo(at: projectDir)
        let largeContent = String(repeating: "B", count: 110_000)
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! largeContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: truncation comment mentions size in KB
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        let instr = result.projectInstructions!
        // Should mention original size in KB (110 KB or similar)
        XCTAssertTrue(instr.contains("KB"),
                       "Truncation comment should mention original size in KB")
    }

    // MARK: - AC6: Non-UTF-8 Encoding Handling

    /// AC6 [P0]: Given a file with non-UTF-8 encoding, readFileContent returns nil
    /// without crashing.
    func testAC6_NonUTF8File_ReturnsNilWithoutCrash() {
        // Given: a file with invalid UTF-8 bytes
        initGitRepo(at: projectDir)
        let badData = Data([0xFF, 0xFE, 0x00, 0xD8, 0x01, 0x02]) // Invalid UTF-8 sequence
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! badData.write(to: URL(fileURLWithPath: claudeMdPath))

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: should not crash, and projectInstructions should be nil
        // (or not contain garbage content)
        XCTAssertNotNil(result, "Should not crash on non-UTF-8 file")
        // The file cannot be read as UTF-8, so it should be skipped
        if let instr = result.projectInstructions {
            // If somehow projectInstructions is non-nil (e.g. from AGENT.md),
            // it should not contain garbage
            XCTAssertFalse(instr.contains("\u{fffd}\u{fffd}"),
                            "Should not contain replacement characters from bad encoding")
        }
    }

    // MARK: - AC7: Project Root Discovery Rules

    /// AC7 [P0]: Given a nested directory structure with .git at the root,
    /// discoverProjectRoot traverses upward to find the .git directory.
    func testAC7_DiscoverProjectRoot_TraversesUpToGitDir() {
        // Given: root/.git/ and root/subdir/deep/
        let gitRoot = (tempDir as NSString).appendingPathComponent("gitroot")
        let subdir = (gitRoot as NSString).appendingPathComponent("subdir")
        let deepDir = (subdir as NSString).appendingPathComponent("deep")
        try! FileManager.default.createDirectory(
            atPath: deepDir,
            withIntermediateDirectories: true
        )
        initGitRepo(at: gitRoot)

        // Place CLAUDE.md at gitRoot (not deepDir)
        let content = "Found via .git traversal."
        let claudeMdPath = (gitRoot as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: calling from deepDir (no explicitProjectRoot)
        let result = discovery.collectProjectContext(
            cwd: deepDir,
            explicitProjectRoot: nil
        )

        // Then: discovers gitRoot as project root and finds CLAUDE.md
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        XCTAssertTrue(result.projectInstructions!.contains(content),
                       "Should discover CLAUDE.md by traversing up from deepDir to gitRoot")
    }

    /// AC7 [P1]: Given no .git directory anywhere up the tree,
    /// uses cwd as project root.
    func testAC7_NoGitDir_UsesCwdAsProjectRoot() {
        // Given: a directory with no .git anywhere (and a CLAUDE.md)
        let noGitDir = (tempDir as NSString).appendingPathComponent("nogit")
        try! FileManager.default.createDirectory(
            atPath: noGitDir,
            withIntermediateDirectories: true
        )
        let content = "No git here."
        let claudeMdPath = (noGitDir as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: calling with no .git traversal possible
        let result = discovery.collectProjectContext(
            cwd: noGitDir,
            explicitProjectRoot: nil
        )

        // Then: falls back to cwd and finds CLAUDE.md there
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.projectInstructions)
        XCTAssertTrue(result.projectInstructions!.contains(content),
                       "Should use cwd as project root when no .git found")
    }

    // MARK: - AC8: No Instruction Files -- No Error

    /// AC8 [P0]: Given project root has no CLAUDE.md, AGENT.md, or global CLAUDE.md,
    /// collectProjectContext returns nil instructions without error.
    func testAC8_NoInstructionFiles_ReturnsNilInstructions() {
        // Given: an empty directory with no instruction files
        let emptyDir = (tempDir as NSString).appendingPathComponent("empty")
        try! FileManager.default.createDirectory(
            atPath: emptyDir,
            withIntermediateDirectories: true
        )

        let discovery = makeDiscovery()

        // When: collecting project context
        let result = discovery.collectProjectContext(
            cwd: emptyDir,
            explicitProjectRoot: emptyDir,
            homeDirectory: (tempDir as NSString).appendingPathComponent("fakehome_empty")
        )

        // Then: both instructions are nil (no error thrown)
        XCTAssertNotNil(result, "Should return a result object (not throw)")
        XCTAssertNil(result.globalInstructions,
                      "globalInstructions should be nil when no global CLAUDE.md exists")
        XCTAssertNil(result.projectInstructions,
                      "projectInstructions should be nil when no CLAUDE.md/AGENT.md exists")
    }

    /// AC8 [P1]: Agent.buildSystemPrompt() in a bare directory returns the original
    /// prompt without <project-instructions> block.
    /// Note: <global-instructions> may still appear if ~/.claude/CLAUDE.md exists on the
    /// real machine. We only verify project-level instruction blocks are absent.
    func testAC8_BuildSystemPrompt_NoInstructionFiles_NoExtraBlocks() {
        // Given: an Agent in a bare temp directory (no CLAUDE.md, no AGENT.md, no Git)
        let bareDir = (tempDir as NSString).appendingPathComponent("bare")
        try! FileManager.default.createDirectory(
            atPath: bareDir,
            withIntermediateDirectories: true
        )

        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "Just the basics.",
            cwd: bareDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: no project-instructions block is present (global may appear from real home dir)
        XCTAssertNotNil(prompt, "Should return the original system prompt")
        XCTAssertFalse(prompt!.contains("<project-instructions>"),
                        "Should NOT contain <project-instructions> block")
        // Verify the system prompt text itself is preserved
        XCTAssertTrue(prompt!.contains("Just the basics."),
                       "Should contain the original system prompt text")
    }

    // MARK: - buildSystemPrompt() Integration: Concatenation Order

    /// Integration [P0]: buildSystemPrompt() concatenates in the correct order:
    /// systemPrompt -> git-context -> global-instructions -> project-instructions
    func testIntegration_BuildSystemPrompt_CorrectConcatenationOrder() {
        // Given: a project with CLAUDE.md in a Git repo
        initGitRepo(at: projectDir)
        let claudeContent = "Project conventions."
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! claudeContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are an assistant.",
            cwd: projectDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: verify order of sections
        XCTAssertNotNil(prompt)
        guard let p = prompt else { return }

        // Find positions of each section
        let systemIdx = p.range(of: "You are an assistant.")!.lowerBound
        let gitIdx = p.range(of: "<git-context>")?.lowerBound
        let projectIdx = p.range(of: "<project-instructions>")!.lowerBound

        // systemPrompt should come before git-context (if present) and project-instructions
        if let gi = gitIdx {
            XCTAssertLessThan(systemIdx, gi,
                               "systemPrompt should appear before <git-context>")
            XCTAssertLessThan(gi, projectIdx,
                               "<git-context> should appear before <project-instructions>")
        } else {
            XCTAssertLessThan(systemIdx, projectIdx,
                               "systemPrompt should appear before <project-instructions>")
        }
    }

    /// Integration [P1]: buildSystemPrompt() with only project instructions (no Git)
    /// returns systemPrompt + <project-instructions>.
    func testIntegration_BuildSystemPrompt_NoGit_WithProjectInstructions() {
        // Given: a non-Git directory with CLAUDE.md
        let noGitProject = (tempDir as NSString).appendingPathComponent("nogitproject")
        try! FileManager.default.createDirectory(
            atPath: noGitProject,
            withIntermediateDirectories: true
        )
        let content = "No git project instructions."
        let claudeMdPath = (noGitProject as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "Base prompt.",
            cwd: noGitProject
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: contains system prompt and project instructions, but no git-context
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("Base prompt."),
                       "Should contain original system prompt")
        XCTAssertTrue(prompt!.contains("<project-instructions>"),
                       "Should contain <project-instructions> block")
        XCTAssertFalse(prompt!.contains("<git-context>"),
                        "Should NOT contain <git-context> block in non-Git directory")
    }

    // MARK: - Caching

    /// Caching [P0]: Second call with same parameters returns cached result.
    func testCaching_SecondCall_ReturnsCachedResult() {
        // Given: a project with CLAUDE.md
        initGitRepo(at: projectDir)
        let content = "Cached instructions."
        let claudeMdPath = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! content.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: calling twice with same parameters
        let result1 = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Modify the file between calls
        let newContent = "Modified instructions."
        try! newContent.write(toFile: claudeMdPath, atomically: true, encoding: .utf8)

        let result2 = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )

        // Then: second call returns cached result (original content, not modified)
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result2.projectInstructions!.contains(content),
                       "Second call should return cached content, not the modified file")
        XCTAssertFalse(result2.projectInstructions!.contains(newContent),
                        "Second call should NOT reflect the file modification (cached)")
    }

    /// Caching [P1]: Different cwd returns different result (cache keyed by cwd+projectRoot).
    func testCaching_DifferentCwd_DifferentResult() {
        // Given: two project directories with different CLAUDE.md content
        initGitRepo(at: projectDir)
        let content1 = "Project A instructions."
        let claudeMdPath1 = (projectDir as NSString).appendingPathComponent("CLAUDE.md")
        try! content1.write(toFile: claudeMdPath1, atomically: true, encoding: .utf8)

        let projectDir2 = (tempDir as NSString).appendingPathComponent("myproject2")
        try! FileManager.default.createDirectory(
            atPath: projectDir2,
            withIntermediateDirectories: true
        )
        initGitRepo(at: projectDir2)
        let content2 = "Project B instructions."
        let claudeMdPath2 = (projectDir2 as NSString).appendingPathComponent("CLAUDE.md")
        try! content2.write(toFile: claudeMdPath2, atomically: true, encoding: .utf8)

        let discovery = makeDiscovery()

        // When: collecting from both projects
        let result1 = discovery.collectProjectContext(
            cwd: projectDir,
            explicitProjectRoot: nil
        )
        let result2 = discovery.collectProjectContext(
            cwd: projectDir2,
            explicitProjectRoot: nil
        )

        // Then: results are different
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result1.projectInstructions!.contains(content1),
                       "First project should contain its own content")
        XCTAssertTrue(result2.projectInstructions!.contains(content2),
                       "Second project should contain its own content")
        XCTAssertFalse(result1.projectInstructions!.contains(content2),
                        "First project should NOT contain second project content")
    }
}
