//
//  ChorusAdjustments.swift
//  VoiceKitUI
//
//  Small pure helpers extracted for testing VoiceChorusPlayground adjustments.
//

import Foundation
import VoiceKit

internal func applyChorusAdjustments(
    base: [TTSVoiceProfile],
    rateScale: Double,
    pitchOffset: Double
) -> [TTSVoiceProfile] {
    return base.map { original in
        var profile = original
        profile.rate = (profile.rate * rateScale).clamped(to: 0.0...1.0)
        profile.pitch = (profile.pitch + Float(pitchOffset)).clamped(to: 0.5...2.0)
        return profile
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
