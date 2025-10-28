//
//  VoiceChorusMoreTests.swift
//  VoiceKit
//
//  Additional coverage for VoiceChorus:
//  - Applies profiles before speak
//  - Speaks all profiles (including duplicate voiceIDs)
//  - Creates engines as needed via factory
//  - stop() cancels in-flight speak tasks and calls stopAll on engines
//

import XCTest
@testable import VoiceKit
import CoreGraphics

@MainActor
final class VoiceChorusMoreTests: XCTestCase {

    // Minimal fake engine for chorus tests
    @MainActor
    final class FakeChorusEngine: TTSConfigurable, VoiceIO {
        // VoiceIO callbacks (unused here)
        var onListeningChanged: ((Bool) -> Void)?
        var onTranscriptChanged: ((String) -> Void)?
        var onLevelChanged: ((CGFloat) -> Void)?
        var onTTSSpeakingChanged: ((Bool) -> Void)?
        var onTTSPulse: ((CGFloat) -> Void)?
        var onStatusMessageChanged: ((String?) -> Void)?

        // Tracking
        private(set) var profiles: [String: TTSVoiceProfile] = [:]
        private(set) var defaultProfile: TTSVoiceProfile?
        private(set) var master: Tuning = .init()
        private(set) var speaks: [(text: String, voiceID: String?)] = []
        private(set) var stopAllCalls = 0

        // Behavior
        let delaySeconds: Double
        init(delaySeconds: Double = 0) { self.delaySeconds = delaySeconds }

        // MARK: - VoiceIO
        func ensurePermissions() async throws {}
        func configureSessionIfNeeded() async throws {}
        func speak(_ text: String) async {
            speaks.append((text, defaultProfile?.id))
            // Optional delay to simulate in-flight work
            if delaySeconds > 0 {
                let steps = 5
                for _ in 0..<steps {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: UInt64((delaySeconds / Double(steps)) * 1_000_000_000))
                }
            }
        }
        func listen(timeout: TimeInterval, inactivity: TimeInterval, record: Bool) async throws -> VoiceResult {
            return VoiceResult(transcript: "", recordingURL: nil)
        }
        func prepareClip(url: URL, gainDB: Float) async throws {}
        func startPreparedClip() async throws {}
        func playClip(url: URL, gainDB: Float) async throws {}
        func stopAll() { stopAllCalls += 1 }
        func hardReset() {}

        // MARK: - TTSConfigurable
        func setVoiceProfile(_ profile: TTSVoiceProfile) { profiles[profile.id] = profile }
        func getVoiceProfile(id: String) -> TTSVoiceProfile? { profiles[id] }
        func setDefaultVoiceProfile(_ profile: TTSVoiceProfile) { defaultProfile = profile; profiles[profile.id] = profile }
        func getDefaultVoiceProfile() -> TTSVoiceProfile? { defaultProfile }
        // Current protocol requirements:
        func setTuning(_ tuning: Tuning) { self.master = tuning }
        func getTuning() -> Tuning { master }
        func speak(_ text: String, using voiceID: String?) async {
            speaks.append((text, voiceID))
            if delaySeconds > 0 {
                let steps = 5
                for _ in 0..<steps {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: UInt64((delaySeconds / Double(steps)) * 1_000_000_000))
                }
            }
        }
    }

    func testAppliesProfilesAndSpeaksAll() async throws {
        // Arrange: chorus that makes new FakeChorusEngine per profile
        var made: [FakeChorusEngine] = []
        let chorus = VoiceChorus(makeEngine: {
            let engine = FakeChorusEngine()
            made.append(engine)
            return engine
        })
        let text = "Hello"
        let p1 = TTSVoiceProfile(id: "id.alex", rate: 0.55, pitch: 1.0, volume: 1.0)
        let p2 = TTSVoiceProfile(id: "id.emily", rate: 0.65, pitch: 1.05, volume: 1.0)

        // Act
        await chorus.sing(text, withVoiceProfiles: [p1, p2])

        // Assert: two engines created
        XCTAssertEqual(made.count, 2)
        // Each engine received its profile before speaking (unwrap optionals from dict)
        guard
            let r0 = made[0].profiles[p1.id]?.rate,
            let r1 = made[1].profiles[p2.id]?.rate
        else {
            return XCTFail("Expected profiles set before speak")
        }
        XCTAssertEqual(r0, p1.rate, accuracy: 0.0001)
        XCTAssertEqual(r1, p2.rate, accuracy: 0.0001)
        // Each engine spoke with the matching voiceID
        XCTAssertEqual(made[0].speaks.last?.voiceID, p1.id)
        XCTAssertEqual(made[1].speaks.last?.voiceID, p2.id)
    }

    func testAllowsDuplicateVoiceIDs() async throws {
        var made: [FakeChorusEngine] = []
        let chorus = VoiceChorus(makeEngine: {
            let engine = FakeChorusEngine()
            made.append(engine)
            return engine
        })
        let text = "Same voice twice"
        let profileA = TTSVoiceProfile(id: "id.same", rate: 0.50, pitch: 1.0, volume: 1.0)
        let profileB = TTSVoiceProfile(id: "id.same", rate: 0.70, pitch: 0.9, volume: 1.0) // duplicate id, different settings

        await chorus.sing(text, withVoiceProfiles: [profileA, profileB])

        XCTAssertEqual(made.count, 2)
        // Both engines should have spoken, each with the (same) id
        XCTAssertEqual(made[0].speaks.count, 1)
        XCTAssertEqual(made[1].speaks.count, 1)
        XCTAssertEqual(made[0].speaks[0].voiceID, "id.same")
        XCTAssertEqual(made[1].speaks[0].voiceID, "id.same")
        // Profiles set per engine should reflect each input profile separately (unwrap optionals)
        guard
            let ra = made[0].profiles["id.same"]?.rate,
            let rb = made[1].profiles["id.same"]?.rate
        else {
            return XCTFail("Expected profiles assigned for duplicate id")
        }
        XCTAssertEqual(ra, profileA.rate, accuracy: 0.0001)
        XCTAssertEqual(rb, profileB.rate, accuracy: 0.0001)
    }

    func testCreatesEnginesAsNeededViaFactory() async throws {
        var createCount = 0
        let chorus = VoiceChorus(makeEngine: {
            createCount += 1
            return FakeChorusEngine()
        })
        let text = "Scale up engines"
        let profiles = (0..<3).map { i in
            TTSVoiceProfile(id: "id.\(i)", rate: 0.5 + Double(i) * 0.1, pitch: 1.0, volume: 1.0)
        }
        await chorus.sing(text, withVoiceProfiles: profiles)
        XCTAssertEqual(createCount, 3, "Should create one engine per profile when needed")
    }

    func testStopCancelsInFlightAndCallsStopAll() async throws {
        // Engines that take time to speak
        var made: [FakeChorusEngine] = []
        let chorus = VoiceChorus(makeEngine: {
            let engine = FakeChorusEngine(delaySeconds: 0.4)
            made.append(engine)
            return engine
        })
        let text = "Long speak"
        let p1 = TTSVoiceProfile(id: "id.A", rate: 0.5, pitch: 1.0, volume: 1.0)
        let p2 = TTSVoiceProfile(id: "id.B", rate: 0.6, pitch: 1.0, volume: 1.0)

        // Start singing but don't await; cancel shortly after
        let task = Task { @MainActor in
            await chorus.sing(text, withVoiceProfiles: [p1, p2])
        }
        // Give the tasks time to start
        try? await Task.sleep(nanoseconds: 60_000_000) // 60ms
        chorus.stop()
        // Let cancellation propagate
        _ = await task.result

        // stopAll should have been called on all created engines
        XCTAssertEqual(made.count, 2)
        XCTAssertGreaterThanOrEqual(made[0].stopAllCalls, 1)
        XCTAssertGreaterThanOrEqual(made[1].stopAllCalls, 1)
    }
}
