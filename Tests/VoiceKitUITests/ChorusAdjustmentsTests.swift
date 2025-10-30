//
//  ChorusAdjustmentsTests.swift
//  VoiceKitUITests
//
//  Verifies global adjustments do not resurrect deleted profiles and clamp correctly.
//

import XCTest
@testable import VoiceKit
@testable import VoiceKitUI

final class ChorusAdjustmentsTests: XCTestCase {

    func testAdjustmentsDoNotResurrectDeleted() {
        // Baseline with two profiles
        let profileA = TTSVoiceProfile(id: "v1", rate: 0.50, pitch: 1.0, volume: 1.0)
        let profileB = TTSVoiceProfile(id: "v2", rate: 0.60, pitch: 1.0, volume: 1.0)
        var baseline = [profileA, profileB]

        // User deletes the second one — baseline must be synced to the remaining selection.
        // This mirrors the fix in the UI: baseProfiles = selectedProfiles after deletion.
        baseline.remove(at: 1)

        // Apply global adjustments — result must not reintroduce "v2".
        let adjusted = applyChorusAdjustments(base: baseline, rateScale: 1.2, pitchOffset: 0.1)
        XCTAssertEqual(adjusted.count, 1)
        XCTAssertEqual(adjusted.first?.id, "v1")
    }

    func testRateAndPitchClamping() {
        let profile = TTSVoiceProfile(id: "v", rate: 0.95, pitch: 1.9, volume: 1.0)

        // Extreme scale tries to push beyond 1.0; pitchOffset tries to push beyond 2.0
        let adjusted = applyChorusAdjustments(base: [profile], rateScale: 2.0, pitchOffset: 0.5)
        XCTAssertEqual(adjusted.count, 1)
        let adjustedProfile = adjusted[0]
        XCTAssertLessThanOrEqual(adjustedProfile.rate, 1.0 + 1e-9)
        XCTAssertGreaterThanOrEqual(adjustedProfile.rate, 0.0 - 1e-9)
        XCTAssertLessThanOrEqual(adjustedProfile.pitch, 2.0 + 1e-6)
        XCTAssertGreaterThanOrEqual(adjustedProfile.pitch, 0.5 - 1e-6)
    }
}
