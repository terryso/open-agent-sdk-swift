import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - ATDD RED PHASE: Story 17-9 Sandbox Config Enhancement
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - SandboxNetworkConfig struct with 7 fields is added to SandboxSettings.swift
//   - RipgrepConfig struct with 2 fields is added to SandboxSettings.swift
//   - 6 new fields are added to SandboxSettings (network, ripgrep, autoAllowBashIfSandboxed,
//     allowUnsandboxedCommands, ignoreViolations, enableWeakerNestedSandbox)
//   - SandboxSettings.init() updated with backward-compatible defaults for all new fields
//   - SandboxSettings.description updated to include new fields
//   - BashTool wires autoAllowBashIfSandboxed behavior
//
// TDD Phase: RED (feature not implemented yet)

// MARK: - AC1: SandboxNetworkConfig Type Tests

final class SandboxNetworkConfigATDDTests: XCTestCase {

    /// AC1 [P0]: SandboxNetworkConfig can be created with default values.
    func testSandboxNetworkConfig_defaultInit_hasSafeDefaults() {
        let config = SandboxNetworkConfig()

        XCTAssertEqual(config.allowedDomains, [],
                       "Default allowedDomains should be empty")
        XCTAssertEqual(config.allowManagedDomainsOnly, false,
                       "Default allowManagedDomainsOnly should be false")
        XCTAssertEqual(config.allowLocalBinding, false,
                       "Default allowLocalBinding should be false")
        XCTAssertEqual(config.allowUnixSockets, false,
                       "Default allowUnixSockets should be false")
        XCTAssertEqual(config.allowAllUnixSockets, false,
                       "Default allowAllUnixSockets should be false")
        XCTAssertNil(config.httpProxyPort,
                      "Default httpProxyPort should be nil")
        XCTAssertNil(config.socksProxyPort,
                      "Default socksProxyPort should be nil")
    }

    /// AC1 [P0]: SandboxNetworkConfig can be created with all 7 fields explicitly set.
    func testSandboxNetworkConfig_explicitInit_allFieldsSet() {
        let config = SandboxNetworkConfig(
            allowedDomains: ["example.com", "api.example.com"],
            allowManagedDomainsOnly: true,
            allowLocalBinding: true,
            allowUnixSockets: true,
            allowAllUnixSockets: false,
            httpProxyPort: 8080,
            socksProxyPort: 1080
        )

        XCTAssertEqual(config.allowedDomains, ["example.com", "api.example.com"])
        XCTAssertEqual(config.allowManagedDomainsOnly, true)
        XCTAssertEqual(config.allowLocalBinding, true)
        XCTAssertEqual(config.allowUnixSockets, true)
        XCTAssertEqual(config.allowAllUnixSockets, false)
        XCTAssertEqual(config.httpProxyPort, 8080)
        XCTAssertEqual(config.socksProxyPort, 1080)
    }

    /// AC1 [P0]: SandboxNetworkConfig conforms to Sendable.
    func testSandboxNetworkConfig_conformsToSendable() {
        let config = SandboxNetworkConfig()
        // Will fail to compile if SandboxNetworkConfig does not conform to Sendable
        let _: any Sendable = config
    }

    /// AC1 [P0]: SandboxNetworkConfig conforms to Equatable.
    func testSandboxNetworkConfig_conformsToEquatable() {
        let a = SandboxNetworkConfig(allowedDomains: ["example.com"])
        let b = SandboxNetworkConfig(allowedDomains: ["example.com"])
        let c = SandboxNetworkConfig(allowedDomains: ["other.com"])

        XCTAssertEqual(a, b,
                       "Same SandboxNetworkConfig values should be equal")
        XCTAssertNotEqual(a, c,
                           "Different SandboxNetworkConfig values should not be equal")
    }

    /// AC1 [P1]: SandboxNetworkConfig with partial configuration (only proxy ports).
    func testSandboxNetworkConfig_partialConfig_proxyPortsOnly() {
        let config = SandboxNetworkConfig(
            httpProxyPort: 3128,
            socksProxyPort: 9050
        )

        XCTAssertEqual(config.allowedDomains, [],
                       "Unset allowedDomains should default to empty")
        XCTAssertEqual(config.allowManagedDomainsOnly, false)
        XCTAssertEqual(config.httpProxyPort, 3128)
        XCTAssertEqual(config.socksProxyPort, 9050)
    }

    /// AC1 [P1]: SandboxNetworkConfig with nil proxy ports.
    func testSandboxNetworkConfig_nilProxyPorts() {
        let config = SandboxNetworkConfig(
            allowedDomains: ["trusted.com"],
            httpProxyPort: nil,
            socksProxyPort: nil
        )

        XCTAssertEqual(config.allowedDomains, ["trusted.com"])
        XCTAssertNil(config.httpProxyPort)
        XCTAssertNil(config.socksProxyPort)
    }

    /// AC1 [P0]: SandboxNetworkConfig has exactly 7 fields matching TS SDK.
    func testSandboxNetworkConfig_hasSevenFields() {
        let config = SandboxNetworkConfig(
            allowedDomains: ["a.com"],
            allowManagedDomainsOnly: true,
            allowLocalBinding: true,
            allowUnixSockets: true,
            allowAllUnixSockets: true,
            httpProxyPort: 8080,
            socksProxyPort: 1080
        )

        // Access all 7 fields to verify they exist at compile time
        let _ = config.allowedDomains         // 1
        let _ = config.allowManagedDomainsOnly // 2
        let _ = config.allowLocalBinding       // 3
        let _ = config.allowUnixSockets        // 4
        let _ = config.allowAllUnixSockets     // 5
        let _ = config.httpProxyPort           // 6
        let _ = config.socksProxyPort          // 7
    }
}

// MARK: - AC7: RipgrepConfig Type Tests

final class RipgrepConfigATDDTests: XCTestCase {

    /// AC7 [P0]: RipgrepConfig can be created with command field.
    func testRipgrepConfig_initWithCommand() {
        let config = RipgrepConfig(command: "/usr/local/bin/rg")

        XCTAssertEqual(config.command, "/usr/local/bin/rg",
                       "RipgrepConfig.command should match TS ripgrep.command")
        XCTAssertNil(config.args,
                      "Default args should be nil")
    }

    /// AC7 [P0]: RipgrepConfig can be created with command and args.
    func testRipgrepConfig_initWithCommandAndArgs() {
        let config = RipgrepConfig(command: "rg", args: ["--no-filename", "--max-count", "10"])

        XCTAssertEqual(config.command, "rg")
        XCTAssertEqual(config.args, ["--no-filename", "--max-count", "10"])
    }

    /// AC7 [P0]: RipgrepConfig conforms to Sendable.
    func testRipgrepConfig_conformsToSendable() {
        let config = RipgrepConfig(command: "rg")
        // Will fail to compile if RipgrepConfig does not conform to Sendable
        let _: any Sendable = config
    }

    /// AC7 [P0]: RipgrepConfig conforms to Equatable.
    func testRipgrepConfig_conformsToEquatable() {
        let a = RipgrepConfig(command: "rg", args: ["-i"])
        let b = RipgrepConfig(command: "rg", args: ["-i"])
        let c = RipgrepConfig(command: "rg")
        let d = RipgrepConfig(command: "rg", args: ["-v"])

        XCTAssertEqual(a, b,
                       "Same RipgrepConfig values should be equal")
        XCTAssertNotEqual(a, c,
                           "RipgrepConfig with args should not equal one without")
        XCTAssertNotEqual(a, d,
                           "Different args should not be equal")
    }

    /// AC7 [P1]: RipgrepConfig with empty args array is distinct from nil args.
    func testRipgrepConfig_emptyArgs_vsNilArgs() {
        let withEmpty = RipgrepConfig(command: "rg", args: [])
        let withNil = RipgrepConfig(command: "rg", args: nil)

        XCTAssertNotEqual(withEmpty, withNil,
                           "Empty args array should not equal nil args")
    }
}

// MARK: - AC2-AC6, AC8: SandboxSettings New Fields Tests

final class SandboxSettingsNewFieldsATDDTests: XCTestCase {

    /// AC2 [P0]: SandboxSettings has network field of type SandboxNetworkConfig?.
    func testSandboxSettings_hasNetworkField_defaultNil() {
        let settings = SandboxSettings()
        XCTAssertNil(settings.network,
                      "Default network field should be nil")
    }

    /// AC2 [P0]: SandboxSettings can be created with network config.
    func testSandboxSettings_canSetNetworkConfig() {
        let network = SandboxNetworkConfig(
            allowedDomains: ["api.example.com"],
            allowManagedDomainsOnly: true
        )
        let settings = SandboxSettings(network: network)

        XCTAssertNotNil(settings.network,
                         "network should be settable")
        XCTAssertEqual(settings.network?.allowedDomains, ["api.example.com"])
        XCTAssertEqual(settings.network?.allowManagedDomainsOnly, true)
    }

    /// AC3 [P0]: SandboxSettings has autoAllowBashIfSandboxed field defaulting to false.
    func testSandboxSettings_hasAutoAllowBashIfSandboxed_defaultFalse() {
        let settings = SandboxSettings()
        XCTAssertEqual(settings.autoAllowBashIfSandboxed, false,
                       "Default autoAllowBashIfSandboxed should be false")
    }

    /// AC3 [P0]: SandboxSettings can set autoAllowBashIfSandboxed to true.
    func testSandboxSettings_canSetAutoAllowBashIfSandboxed() {
        let settings = SandboxSettings(autoAllowBashIfSandboxed: true)
        XCTAssertEqual(settings.autoAllowBashIfSandboxed, true,
                       "autoAllowBashIfSandboxed should be settable to true")
    }

    /// AC4 [P0]: SandboxSettings has allowUnsandboxedCommands field defaulting to false.
    func testSandboxSettings_hasAllowUnsandboxedCommands_defaultFalse() {
        let settings = SandboxSettings()
        XCTAssertEqual(settings.allowUnsandboxedCommands, false,
                       "Default allowUnsandboxedCommands should be false")
    }

    /// AC4 [P0]: SandboxSettings can set allowUnsandboxedCommands to true.
    func testSandboxSettings_canSetAllowUnsandboxedCommands() {
        let settings = SandboxSettings(allowUnsandboxedCommands: true)
        XCTAssertEqual(settings.allowUnsandboxedCommands, true)
    }

    /// AC5 [P0]: SandboxSettings has ignoreViolations field defaulting to nil.
    func testSandboxSettings_hasIgnoreViolations_defaultNil() {
        let settings = SandboxSettings()
        XCTAssertNil(settings.ignoreViolations,
                      "Default ignoreViolations should be nil")
    }

    /// AC5 [P0]: SandboxSettings can set ignoreViolations with category-based suppression.
    func testSandboxSettings_canSetIgnoreViolations() {
        let violations: [String: [String]] = [
            "file": ["/tmp/*", "/var/log/*"],
            "network": ["localhost", "127.0.0.1"]
        ]
        let settings = SandboxSettings(ignoreViolations: violations)

        XCTAssertNotNil(settings.ignoreViolations)
        XCTAssertEqual(settings.ignoreViolations?["file"], ["/tmp/*", "/var/log/*"])
        XCTAssertEqual(settings.ignoreViolations?["network"], ["localhost", "127.0.0.1"])
    }

    /// AC6 [P0]: SandboxSettings has enableWeakerNestedSandbox field defaulting to false.
    func testSandboxSettings_hasEnableWeakerNestedSandbox_defaultFalse() {
        let settings = SandboxSettings()
        XCTAssertEqual(settings.enableWeakerNestedSandbox, false,
                       "Default enableWeakerNestedSandbox should be false")
    }

    /// AC6 [P0]: SandboxSettings can set enableWeakerNestedSandbox to true.
    func testSandboxSettings_canSetEnableWeakerNestedSandbox() {
        let settings = SandboxSettings(enableWeakerNestedSandbox: true)
        XCTAssertEqual(settings.enableWeakerNestedSandbox, true)
    }

    /// AC7 [P0]: SandboxSettings has ripgrep field of type RipgrepConfig?.
    func testSandboxSettings_hasRipgrepField_defaultNil() {
        let settings = SandboxSettings()
        XCTAssertNil(settings.ripgrep,
                      "Default ripgrep field should be nil")
    }

    /// AC7 [P0]: SandboxSettings can be created with ripgrep config.
    func testSandboxSettings_canSetRipgrepConfig() {
        let rg = RipgrepConfig(command: "/usr/local/bin/rg", args: ["--hidden"])
        let settings = SandboxSettings(ripgrep: rg)

        XCTAssertNotNil(settings.ripgrep)
        XCTAssertEqual(settings.ripgrep?.command, "/usr/local/bin/rg")
        XCTAssertEqual(settings.ripgrep?.args, ["--hidden"])
    }

    /// AC8 [P0]: SandboxSettings backward-compatible init -- no-arg init still works.
    func testSandboxSettings_noArgInit_backwardCompatible() {
        // This must compile and work exactly as before with no changes to call sites
        let settings = SandboxSettings()

        XCTAssertEqual(settings.allowedReadPaths, [])
        XCTAssertEqual(settings.allowedWritePaths, [])
        XCTAssertEqual(settings.deniedPaths, [])
        XCTAssertEqual(settings.deniedCommands, [])
        XCTAssertNil(settings.allowedCommands)
        XCTAssertEqual(settings.allowNestedSandbox, false)
        // New fields should all have defaults
        XCTAssertNil(settings.network)
        XCTAssertEqual(settings.autoAllowBashIfSandboxed, false)
        XCTAssertEqual(settings.allowUnsandboxedCommands, false)
        XCTAssertNil(settings.ignoreViolations)
        XCTAssertEqual(settings.enableWeakerNestedSandbox, false)
        XCTAssertNil(settings.ripgrep)
    }

    /// AC8 [P0]: SandboxSettings init with all new fields at once.
    func testSandboxSettings_initWithAllNewFields() {
        let network = SandboxNetworkConfig(allowedDomains: ["api.trusted.com"])
        let rg = RipgrepConfig(command: "rg", args: ["-i"])
        let violations: [String: [String]] = ["file": ["/tmp/*"]]

        let settings = SandboxSettings(
            allowedReadPaths: ["/project/"],
            allowedWritePaths: ["/project/build/"],
            deniedPaths: ["/etc/"],
            deniedCommands: ["rm"],
            allowedCommands: nil,
            allowNestedSandbox: true,
            autoAllowBashIfSandboxed: true,
            allowUnsandboxedCommands: false,
            ignoreViolations: violations,
            enableWeakerNestedSandbox: true,
            network: network,
            ripgrep: rg
        )

        // Original fields
        XCTAssertEqual(settings.allowedReadPaths, ["/project/"])
        XCTAssertEqual(settings.allowedWritePaths, ["/project/build/"])
        XCTAssertEqual(settings.deniedPaths, ["/etc/"])
        XCTAssertEqual(settings.deniedCommands, ["rm"])
        XCTAssertNil(settings.allowedCommands)
        XCTAssertEqual(settings.allowNestedSandbox, true)

        // New fields
        XCTAssertEqual(settings.autoAllowBashIfSandboxed, true)
        XCTAssertEqual(settings.allowUnsandboxedCommands, false)
        XCTAssertEqual(settings.ignoreViolations?["file"], ["/tmp/*"])
        XCTAssertEqual(settings.enableWeakerNestedSandbox, true)
        XCTAssertEqual(settings.network?.allowedDomains, ["api.trusted.com"])
        XCTAssertEqual(settings.ripgrep?.command, "rg")
    }

    /// AC8 [P1]: SandboxSettings init preserves original parameter order (old fields first).
    func testSandboxSettings_initParameterOrder_preserved() {
        // Existing call sites use: allowedReadPaths, allowedWritePaths, deniedPaths,
        // deniedCommands, allowedCommands, allowNestedSandbox
        // This test verifies that order is unchanged
        let settings = SandboxSettings(
            allowedReadPaths: ["/a/"],
            allowedWritePaths: ["/b/"],
            deniedPaths: ["/c/"],
            deniedCommands: ["rm"],
            allowedCommands: ["git"],
            allowNestedSandbox: true
        )

        XCTAssertEqual(settings.allowedReadPaths, ["/a/"])
        XCTAssertEqual(settings.allowedWritePaths, ["/b/"])
        XCTAssertEqual(settings.deniedPaths, ["/c/"])
        XCTAssertEqual(settings.deniedCommands, ["rm"])
        XCTAssertEqual(settings.allowedCommands, ["git"])
        XCTAssertEqual(settings.allowNestedSandbox, true)
    }

    /// AC8 [P0]: SandboxSettings field count includes all 12 fields (6 existing + 6 new).
    func testSandboxSettings_hasTwelveFields() {
        let settings = SandboxSettings(
            allowedReadPaths: ["/a/"],
            allowedWritePaths: ["/b/"],
            deniedPaths: ["/c/"],
            deniedCommands: ["rm"],
            allowedCommands: ["git"],
            allowNestedSandbox: true,
            autoAllowBashIfSandboxed: true,
            allowUnsandboxedCommands: true,
            ignoreViolations: ["file": ["/tmp/*"]],
            enableWeakerNestedSandbox: true,
            network: SandboxNetworkConfig(),
            ripgrep: RipgrepConfig(command: "rg")
        )

        // Access all 12 fields to verify they exist at compile time
        let _ = settings.allowedReadPaths          // 1 (existing)
        let _ = settings.allowedWritePaths         // 2 (existing)
        let _ = settings.deniedPaths               // 3 (existing)
        let _ = settings.deniedCommands            // 4 (existing)
        let _ = settings.allowedCommands           // 5 (existing)
        let _ = settings.allowNestedSandbox        // 6 (existing)
        let _ = settings.autoAllowBashIfSandboxed   // 7 (new)
        let _ = settings.allowUnsandboxedCommands    // 8 (new)
        let _ = settings.ignoreViolations            // 9 (new)
        let _ = settings.enableWeakerNestedSandbox   // 10 (new)
        let _ = settings.network                     // 11 (new)
        let _ = settings.ripgrep                     // 12 (new)
    }
}

// MARK: - AC8: SandboxSettings Description Update Tests

final class SandboxSettingsDescriptionATDDTests: XCTestCase {

    /// AC8 [P1]: SandboxSettings.description includes network field when set.
    func testSandboxSettings_description_includesNetwork() {
        let network = SandboxNetworkConfig(allowedDomains: ["example.com"])
        let settings = SandboxSettings(network: network)
        let desc = settings.description

        XCTAssertTrue(desc.contains("network"),
                       "Description should include network when set: \(desc)")
    }

    /// AC8 [P1]: SandboxSettings.description includes autoAllowBashIfSandboxed when true.
    func testSandboxSettings_description_includesAutoAllowBashIfSandboxed() {
        let settings = SandboxSettings(autoAllowBashIfSandboxed: true)
        let desc = settings.description

        XCTAssertTrue(desc.contains("autoAllowBashIfSandboxed") || desc.contains("AutoAllow"),
                       "Description should include autoAllowBashIfSandboxed when true: \(desc)")
    }

    /// AC8 [P1]: SandboxSettings.description includes ripgrep when set.
    func testSandboxSettings_description_includesRipgrep() {
        let settings = SandboxSettings(ripgrep: RipgrepConfig(command: "rg"))
        let desc = settings.description

        XCTAssertTrue(desc.contains("ripgrep") || desc.contains("Ripgrep"),
                       "Description should include ripgrep when set: \(desc)")
    }

    /// AC8 [P1]: SandboxSettings.description includes ignoreViolations when set.
    func testSandboxSettings_description_includesIgnoreViolations() {
        let settings = SandboxSettings(ignoreViolations: ["file": ["/tmp/*"]])
        let desc = settings.description

        XCTAssertTrue(desc.contains("ignoreViolations") || desc.contains("IgnoreViolations"),
                       "Description should include ignoreViolations when set: \(desc)")
    }

    /// AC8 [P1]: SandboxSettings.description includes enableWeakerNestedSandbox when true.
    func testSandboxSettings_description_includesEnableWeakerNestedSandbox() {
        let settings = SandboxSettings(enableWeakerNestedSandbox: true)
        let desc = settings.description

        XCTAssertTrue(desc.contains("enableWeakerNestedSandbox") || desc.contains("WeakerNested"),
                       "Description should include enableWeakerNestedSandbox when true: \(desc)")
    }
}

// MARK: - AC6: enableWeakerNestedSandbox vs allowNestedSandbox Distinction Tests

final class SandboxNestedSandboxDistinctionATDDTests: XCTestCase {

    /// AC6 [P0]: enableWeakerNestedSandbox and allowNestedSandbox are independent fields.
    func testNestedSandboxFields_areIndependent() {
        let neither = SandboxSettings()
        XCTAssertEqual(neither.allowNestedSandbox, false)
        XCTAssertEqual(neither.enableWeakerNestedSandbox, false)

        let allowOnly = SandboxSettings(allowNestedSandbox: true)
        XCTAssertEqual(allowOnly.allowNestedSandbox, true)
        XCTAssertEqual(allowOnly.enableWeakerNestedSandbox, false)

        let weakerOnly = SandboxSettings(enableWeakerNestedSandbox: true)
        XCTAssertEqual(weakerOnly.allowNestedSandbox, false)
        XCTAssertEqual(weakerOnly.enableWeakerNestedSandbox, true)

        let both = SandboxSettings(allowNestedSandbox: true, enableWeakerNestedSandbox: true)
        XCTAssertEqual(both.allowNestedSandbox, true)
        XCTAssertEqual(both.enableWeakerNestedSandbox, true)
    }

    /// AC6 [P0]: allowNestedSandbox controls whether nested sandbox is allowed at all.
    /// enableWeakerNestedSandbox controls whether nested sandbox can have weaker restrictions.
    /// Different semantics -- both must be kept.
    func testNestedSandboxFields_differentSemantics() {
        // Per story: allowNestedSandbox = whether nested sandbox is allowed at all
        // enableWeakerNestedSandbox = whether nested sandbox can use weaker restrictions
        let settings = SandboxSettings(
            allowNestedSandbox: true,
            enableWeakerNestedSandbox: false
        )

        XCTAssertTrue(settings.allowNestedSandbox,
                       "Nested sandbox allowed, but restrictions cannot be weakened")
        XCTAssertFalse(settings.enableWeakerNestedSandbox,
                        "Weaker nested sandbox is explicitly disabled")
    }
}

// MARK: - AC9: autoAllowBashIfSandboxed Behavior Tests

final class AutoAllowBashIfSandboxedATDDTests: XCTestCase {

    /// AC9 [P0]: When autoAllowBashIfSandboxed is true and sandbox is non-nil,
    /// BashTool should bypass the canUseTool permission check.
    /// This test verifies the field exists and can be used to signal auto-approval.
    func testAutoAllowBashIfSandboxed_canBeUsedAsPermissionBypassSignal() {
        let settings = SandboxSettings(
            deniedCommands: ["rm"],
            autoAllowBashIfSandboxed: true
        )

        XCTAssertTrue(settings.autoAllowBashIfSandboxed,
                       "autoAllowBashIfSandboxed must be readable for BashTool bypass logic")
        XCTAssertEqual(settings.deniedCommands, ["rm"],
                       "SandboxChecker still enforces command restrictions regardless of autoAllow")
    }

    /// AC9 [P0]: When autoAllowBashIfSandboxed is true, SandboxChecker still blocks denied commands.
    func testAutoAllowBashIfSandboxed_doesNotBypassSandboxChecker() {
        let settings = SandboxSettings(
            deniedCommands: ["rm"],
            autoAllowBashIfSandboxed: true
        )

        // SandboxChecker enforcement must still work
        let allowed = SandboxChecker.isCommandAllowed("git", settings: settings)
        let denied = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertTrue(allowed,
                       "git should be allowed (not in denied list)")
        XCTAssertFalse(denied,
                        "rm should still be blocked by SandboxChecker even with autoAllowBashIfSandboxed")
    }

    /// AC9 [P0]: When autoAllowBashIfSandboxed is false (default), behavior is unchanged.
    func testAutoAllowBashIfSandboxed_false_preservesExistingBehavior() {
        let settings = SandboxSettings(
            deniedCommands: ["rm"],
            autoAllowBashIfSandboxed: false
        )

        XCTAssertFalse(settings.autoAllowBashIfSandboxed)
        XCTAssertFalse(SandboxChecker.isCommandAllowed("rm", settings: settings),
                        "Denied commands should still be blocked when autoAllow is false")
    }

    /// AC9 [P1]: ToolContext with sandbox having autoAllowBashIfSandboxed=true signals bypass.
    func testToolContext_sandboxWithAutoAllow_signalsPermissionBypass() {
        let settings = SandboxSettings(
            deniedCommands: [],
            autoAllowBashIfSandboxed: true
        )
        let context = ToolContext(cwd: "/tmp", sandbox: settings)

        XCTAssertNotNil(context.sandbox)
        XCTAssertEqual(context.sandbox?.autoAllowBashIfSandboxed, true,
                       "ToolContext.sandbox must carry autoAllowBashIfSandboxed for BashTool bypass")
    }
}

// MARK: - AC5: ignoreViolations Edge Cases

final class IgnoreViolationsATDDTests: XCTestCase {

    /// AC5 [P1]: ignoreViolations with multiple categories.
    func testIgnoreViolations_multipleCategories() {
        let violations: [String: [String]] = [
            "file": ["/tmp/*", "/var/log/*"],
            "network": ["localhost"],
            "command": ["rm"]
        ]
        let settings = SandboxSettings(ignoreViolations: violations)

        XCTAssertEqual(settings.ignoreViolations?.count, 3)
        XCTAssertEqual(settings.ignoreViolations?["file"]?.count, 2)
        XCTAssertEqual(settings.ignoreViolations?["network"], ["localhost"])
        XCTAssertEqual(settings.ignoreViolations?["command"], ["rm"])
    }

    /// AC5 [P1]: ignoreViolations with empty dictionary is distinct from nil.
    func testIgnoreViolations_emptyDict_vsNil() {
        let withEmpty = SandboxSettings(ignoreViolations: [:])
        let withNil = SandboxSettings()

        XCTAssertNotNil(withEmpty.ignoreViolations,
                         "Empty dict is not nil")
        XCTAssertNil(withNil.ignoreViolations,
                      "Default is nil")
        XCTAssertEqual(withEmpty.ignoreViolations?.count, 0)
    }

    /// AC5 [P1]: ignoreViolations with empty array values.
    func testIgnoreViolations_emptyArrayValues() {
        let violations: [String: [String]] = ["file": []]
        let settings = SandboxSettings(ignoreViolations: violations)

        XCTAssertEqual(settings.ignoreViolations?["file"], [],
                       "Empty array value is valid")
    }
}

// MARK: - AC2: SandboxSettings.network Integration Tests

final class SandboxNetworkIntegrationATDDTests: XCTestCase {

    /// AC2 [P0]: SandboxSettings.network with full configuration preserves all values.
    func testSandboxSettings_network_fullConfiguration() {
        let network = SandboxNetworkConfig(
            allowedDomains: ["api.example.com", "cdn.example.com"],
            allowManagedDomainsOnly: true,
            allowLocalBinding: false,
            allowUnixSockets: true,
            allowAllUnixSockets: false,
            httpProxyPort: 3128,
            socksProxyPort: 9050
        )
        let settings = SandboxSettings(
            deniedCommands: ["curl"],
            network: network
        )

        XCTAssertEqual(settings.deniedCommands, ["curl"])
        XCTAssertNotNil(settings.network)
        XCTAssertEqual(settings.network?.allowedDomains.count, 2)
        XCTAssertEqual(settings.network?.allowManagedDomainsOnly, true)
        XCTAssertEqual(settings.network?.allowLocalBinding, false)
        XCTAssertEqual(settings.network?.httpProxyPort, 3128)
    }

    /// AC2 [P1]: SandboxSettings equality includes network field.
    func testSandboxSettings_equality_includesNetwork() {
        let net1 = SandboxNetworkConfig(allowedDomains: ["a.com"])
        let net2 = SandboxNetworkConfig(allowedDomains: ["a.com"])
        let net3 = SandboxNetworkConfig(allowedDomains: ["b.com"])

        let a = SandboxSettings(network: net1)
        let b = SandboxSettings(network: net2)
        let c = SandboxSettings(network: net3)

        XCTAssertEqual(a, b,
                       "Settings with same network should be equal")
        XCTAssertNotEqual(a, c,
                           "Settings with different network should not be equal")
    }

    /// AC2 [P1]: SandboxSettings equality includes ripgrep field.
    func testSandboxSettings_equality_includesRipgrep() {
        let rg1 = RipgrepConfig(command: "rg", args: ["-i"])
        let rg2 = RipgrepConfig(command: "rg", args: ["-i"])
        let rg3 = RipgrepConfig(command: "rg", args: ["-v"])

        let a = SandboxSettings(ripgrep: rg1)
        let b = SandboxSettings(ripgrep: rg2)
        let c = SandboxSettings(ripgrep: rg3)

        XCTAssertEqual(a, b,
                       "Settings with same ripgrep should be equal")
        XCTAssertNotEqual(a, c,
                           "Settings with different ripgrep should not be equal")
    }
}
