//
//  ChorusAdjustmentsTests.swift
//  VoiceKitUITests
//
//  Verifies global adjustments do not resurrect deleted profiles and clamp correctly.
//

import XCTest
@testable import VoiceKitCore
@testable import VoiceKitUI

final class ChorusAdjustmentsTests: XCTestCase {

    func testAdjustmentsDoNotResurrectDeleted() {
        // Baseline with two profiles
        let a = TTSVoiceProfile(id: "v1", rate: 0.50, pitch: 1.0, volume: 1.0)
        let b = TTSVoiceProfile(id: "v2", rate: 0.60, pitch: 1.0, volume: 1.0)
        var baseline = [a, b]

        // User deletes the second one — baseline must be synced to the remaining selection.
        // This mirrors the fix in the UI: baseProfiles = selectedProfiles after deletion.
        baseline.remove(at: 1)

        // Apply global adjustments — result must not reintroduce "v2".
        let adjusted = applyChorusAdjustments(base: baseline, rateScale: 1.2, pitchOffset: 0.1)
        XCTAssertEqual(adjusted.count, 1)
        XCTAssertEqual(adjusted.first?.id, "v1")
    }

    func testRateAndPitchClamping() {
        let p = TTSVoiceProfile(id: "v", rate: 0.95, pitch: 1.9, volume: 1.0)

        // Extreme scale tries to push beyond 1.0; pitchOffset tries to push beyond 2.0
        let adjusted = applyChorusAdjustments(base: [p], rateScale: 2.0, pitchOffset: 0.5)
        XCTAssertEqual(adjusted.count, 1)
        let q = adjusted[0]
        XCTAssertLessThanOrEqual(q.rate, 1.0 + 1e-9)
        XCTAssertGreaterThanOrEqual(q.rate, 0.0 - 1e-9)
        XCTAssertLessThanOrEqual(q.pitch, 2.0 + 1e-6)
        XCTAssertGreaterThanOrEqual(q.pitch, 0.5 - 1e-6)
    }
}
