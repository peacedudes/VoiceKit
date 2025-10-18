//
//  PermissionBridgeCITests.swift
//  VoiceKit
//
//  Ensures permission helpers short-circuit under CI override.
//

import XCTest
@testable import VoiceKitCore
@preconcurrency import Speech

final class PermissionBridgeCITests: XCTestCase {
    override func setUp() {
        super.setUp()
        setenv("VOICEKIT_FORCE_CI", "true", 1)
    }
    override func tearDown() {
        unsetenv("VOICEKIT_FORCE_CI")
        super.tearDown()
    }

    func testAwaitSpeechAuthAuthorizedInCI() async {
        let status = await PermissionBridge.awaitSpeechAuth()
        XCTAssertEqual(status, .authorized)
    }

    func testAwaitMicPermissionTrueInCI() async {
        let granted = await PermissionBridge.awaitMicPermission()
        XCTAssertTrue(granted)
    }
}
