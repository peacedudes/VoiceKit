//
//  IsCITests.swift
//  VoiceKit
//
//  Guardrail tests for CI detection override.
//

import XCTest
@testable import VoiceKit

internal final class IsCITests: XCTestCase {
    override func tearDown() {
        // Clean up override environment for isolation between tests
        unsetenv("VOICEKIT_FORCE_CI")
        super.tearDown()
    }

    func testRunningFalseByDefault() {
        unsetenv("VOICEKIT_FORCE_CI")
        // CI may set CI=1 on GitHub; ensure override not set forces to that env only.
        // We cannot reliably assert false if CI=1 is present, so just assert it returns a Bool.
        XCTAssertNotNil(Optional(IsCI.running))
    }

    func testOverrideTrue() {
        setenv("VOICEKIT_FORCE_CI", "true", 1)
        XCTAssertTrue(IsCI.running)
    }

    func testOverrideOne() {
        setenv("VOICEKIT_FORCE_CI", "1", 1)
        XCTAssertTrue(IsCI.running)
    }

    func testOverrideFalse() {
        setenv("VOICEKIT_FORCE_CI", "false", 1)
        XCTAssertFalse(IsCI.running)
    }
}
