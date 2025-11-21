//
//  RealVoiceIOTTSCIFastPathTests.swift
//  VoiceKit
//
//  Verifies speak() fast-path behavior under CI override (no AVSpeech hang).
//

import XCTest
@testable import VoiceKit
import TestSupport

@MainActor
internal final class RealVoiceIOTTSCIFastPathTests: TestSupport.QoSNeutralizingTestCase {
    override func setUp() {
        super.setUp()
        setenv("VOICEKIT_FORCE_CI", "true", 1)
    }
    override func tearDown() {
        unsetenv("VOICEKIT_FORCE_CI")
        super.tearDown()
    }

    func testSpeakFastPathTogglesCallbacks() async throws {
        let io = RealVoiceIO()

        var toggles: [Bool] = []
        let exp = XCTestExpectation(description: "speaking toggled false")

        io.onTTSSpeakingChanged = { speaking in
            toggles.append(speaking)
            if speaking == false {
                exp.fulfill()
            }
        }

        // Minimal profile setup
        let alex = TTSVoiceProfile(id: "com.apple.speech.synthesis.voice.Alex", rate: 0.6, pitch: 1.0, volume: 1.0)
        io.setDefaultVoiceProfile(alex)

        await io.speak("Hello, CI.")

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(toggles.first, true, "Should toggle true first")
        XCTAssertEqual(toggles.last, false, "Should toggle false at end")
    }
}
