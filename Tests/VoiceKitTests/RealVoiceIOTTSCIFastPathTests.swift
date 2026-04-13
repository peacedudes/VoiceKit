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

        io.onSpeakingChanged = { speaking in
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

    // MARK: - Silence token parsing

    func testSilenceTokenParsedCorrectly() {
        let io = RealVoiceIO()
        let parts = io.parseTextForSFXWithURLs("Ready? <silence:1.5> Go!")
        XCTAssertEqual(parts.count, 3)
        if case .text(let text) = parts[0] { XCTAssertEqual(text, "Ready? ") } else { XCTFail("expected text") }
        if case .silence(let secs) = parts[1] { XCTAssertEqual(secs, 1.5, accuracy: 0.001) } else { XCTFail("expected silence") }
        if case .text(let text) = parts[2] { XCTAssertEqual(text, " Go!") } else { XCTFail("expected text") }
    }

    func testSilenceTokenNegativeDurationIgnored() {
        let io = RealVoiceIO()
        let parts = io.parseTextForSFXWithURLs("Hello <silence:-1> world")
        // Negative duration is invalid; token is dropped and surrounding text merges as-is
        XCTAssertFalse(parts.contains { if case .silence = $0 { return true }; return false })
    }

    func testSilenceTokenMalformedValueIgnored() {
        let io = RealVoiceIO()
        let parts = io.parseTextForSFXWithURLs("Hello <silence:oops> world")
        XCTAssertFalse(parts.contains { if case .silence = $0 { return true }; return false })
    }

    func testSilenceTokenWithWhitespace() {
        let io = RealVoiceIO()
        let parts = io.parseTextForSFXWithURLs("<silence: 0.5>")
        XCTAssertEqual(parts.count, 1)
        if case .silence(let secs) = parts[0] { XCTAssertEqual(secs, 0.5, accuracy: 0.001) } else { XCTFail("expected silence") }
    }

    func testSpeakWithSilenceTokenCompletesInCI() async {
        let io = RealVoiceIO()
        // speak() with a silence token must complete without hanging in CI
        await io.speak("Hello <silence:0.01> world")
    }

    func testPauseMethodCompletesInCI() async {
        let io = RealVoiceIO()
        await io.pause(0.01)
    }
}
