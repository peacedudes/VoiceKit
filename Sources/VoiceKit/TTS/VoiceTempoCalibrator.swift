//
//  VoiceTempoCalibrator.swift
//  VoiceKit
//
//  Calibrates a voice's speaking rate to fit a target duration for a sample phrase.
//

import Foundation

@MainActor
public enum VoiceTempoCalibrator {

    /// Adjusts the rate of the specified voice so that speaking `phrase` takes close to `targetSeconds`.
    /// - Parameters:
    ///   - io: RealVoiceIO engine (must be @MainActor).
    ///   - voiceID: System voice identifier to calibrate.
    ///   - phrase: Sample text used for measurement (keep this fixed across voices).
    ///   - targetSeconds: Desired duration in seconds (e.g., 5.0).
    ///   - tolerance: Allowed absolute error in seconds before stopping (default 0.05).
    ///   - maxIterations: Max adjustment passes (default 3).
    ///   - bounds: Allowed rate bounds (default 0...1).
    /// - Returns: (finalRate, measuredDuration)
    @discardableResult
    public static func fitRate(
        io: RealVoiceIO,
        voiceID: String,
        phrase: String,
        targetSeconds: TimeInterval,
        tolerance: TimeInterval = 0.05,
        maxIterations: Int = 3,
        bounds: ClosedRange<Double> = 0.0...1.0
    ) async -> (finalRate: Double, measured: TimeInterval) {

        // Current profile (or a new one) for this voice
        var profile = io.getVoiceProfile(id: voiceID) ?? {
            // Seed from default if present; otherwise a reasonable mid value
            let seed = io.getDefaultVoiceProfile()?.rate ?? 0.55
            return TTSVoiceProfile(id: voiceID, rate: seed, pitch: 1.0, volume: 1.0)
        }()
        io.setVoiceProfile(profile)

        var lastMeasured: TimeInterval = 0

        for _ in 0..<maxIterations {
            // Measure
            lastMeasured = await io.speakAndMeasure(phrase, using: voiceID)

            // CI / fallback safety: if measurement is zero, stop adjustments
            if lastMeasured <= 0 {
                break
            }

            // Check tolerance
            if abs(lastMeasured - targetSeconds) <= tolerance {
                break
            }

            // Proportional update toward target
            let current = profile.rate
            // If speaking was too long (> target), increase rate; if too short, decrease.
            // current * (measured/target) moves in the right direction.
            var updated = current * (lastMeasured / max(targetSeconds, 0.0001))
            // Clamp
            if updated.isNaN || !updated.isFinite { updated = current }
            updated = min(max(updated, bounds.lowerBound), bounds.upperBound)

            // If the change is negligible, stop to avoid micro-churn
            if abs(updated - current) < 0.001 {
                break
            }

            // Apply and try again
            profile.rate = updated
            io.setVoiceProfile(profile)
        }

        return (profile.rate, lastMeasured)
    }
}
